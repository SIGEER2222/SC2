# 建造面板完整性自我检测方案

> 日期：2026-07-22
> 作者：AI 助手
> 状态：设计阶段，待用户确认

## 1. 背景与问题

### 1.1 问题现象

疯批帝国（Alenger3）指挥官在亡者之夜地图上，建筑和训练面板按钮缺失：

- 前哨基地（3diguoqianshaojidi）只显示训练劳工按钮，缺失火炮/象/天空之盾/战列舰按钮
- 皇家要塞（3huangjiayaosai）有相同问题
- 7-10 号和 7-21 号两次声称"已解决"都是错误的

### 1.2 根因

1. **CardLayouts 未挂载**：UnitData.xml 中建筑的 CardLayouts 没有挂载对应的 Train/Build 按钮。这是真正的根因。
2. **之前诊断不可靠**：
   - `TechTreeAbilityAllow=True` 只证明 TechTree 层允许，**不证明 UI 按钮显示**
   - `UnitOrderIsValid` 检查命令可下发性，**不检查 UI 按钮存在性**
   - Galaxy API 没有"查询 CommandCard 按钮列表"的直接接口
3. **Bank 诊断数据误导**：`worker_build` 和 `command_card` 数据来自 ability 层枚举，无法反映 CardLayouts 挂载状态

### 1.3 参考案例

**2026-06-27 Swann SCV 修复**（用户确认解决）：
- 核心是重组 CardLayouts 按钮布局
- 关键操作：`<CardLayouts index="1" removed="1" />` 移除父类继承 + 重新定义 TBl1/TBl2
- 修改文件：UnitData_Swann.xml + AbilData.xml

### 1.4 目标

设计一个能**自我检测建造面板完整性**的方案，避免再次出现"声称已解决但实际未解决"的情况。方案需复用隔壁 Neuro 正在做的命令交互能力。

## 2. 方案架构

### 2.1 双层检测架构

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: 静态分析器（Python，无需进图）                     │
│  - 解析 UnitData.xml 的 CardLayouts                        │
│  - 解析 AbilData.xml 的 Build/Train 定义                   │
│  - 对比找出缺失的按钮挂载                                   │
│  - 输出: missing_buttons.json                              │
│  - 门禁: 有缺失 → fail                                    │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: 运行时验证器（Galaxy + Python，需进图）           │
│  - 通过 NeuroIntegration Bank IPC 选中单位                  │
│  - 枚举单位 ability 列表（UnitAbilityCount/Get）           │
│  - 尝试下发建造/训练命令（order_selected action）           │
│  - 验证命令是否成功执行                                     │
│  - 输出: runtime_verification.json                         │
│  - 门禁: 按钮不可点击 → fail                               │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: 综合报告                                          │
│  - 对比 Layer 1 静态缺失 vs Layer 2 运行时状态             │
│  - 分类: 配置缺失 / 运行时锁定 / 状态正常                  │
│  - 输出: final_report.md                                   │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 核心设计原则

1. **静态优先**：Layer 1 无需进图，可在 CI 或提交前运行，快速发现配置问题
2. **运行时佐证**：Layer 2 通过实际命令验证，避免"静态正确但运行时不工作"
3. **复用 Neuro 能力**：Layer 2 使用 NeuroIntegration 的 Bank IPC 和已有 action（select_unit_type + order_selected）
4. **参数化**：不硬编码单位类型，支持任意指挥官的任意建筑

## 3. Layer 1: 静态分析器

### 3.1 目标

在不进图的情况下，检测 CardLayouts 配置完整性。

### 3.2 输入

- `UnitData.xml`（建筑的 CardLayouts 定义）
- `AbilData.xml`（Build/Train 能力定义）

### 3.3 处理逻辑

```
1. 解析 AbilData.xml
   对每个 CAbilBuild/CAbilTrain:
     - 提取 id
     - 提取所有 InfoArray index="BuildX"/"TrainX" 的 Unit 值
     - 记录 State 属性（Suppressed/Restricted/无）
     - 记录 Requirements

2. 解析 UnitData.xml
   对每个 CUnit（建筑）:
     - 提取 AbilArray 中引用的 Build/Train 技能 ID
     - 提取 CardLayouts 中 LayoutButtons 的 AbilCmd
     - 解析 AbilCmd 格式 "3xunlian1,Train10" → abil=3xunlian1, cmd=Train10

3. 对比
   对每个建筑:
     对其引用的每个 Build/Train 技能:
       查找 AbilData 中该技能的所有 Build/Train 索引
       检查每个索引是否在 CardLayouts 中有对应 LayoutButtons
       如果缺失 → 记录为 issue

4. 输出 missing_buttons.json
```

### 3.4 输出格式

```json
{
  "mod": "Alenger3",
  "mod_path": "sc2-porting-workspace/projects/cmre-porting/packages/Mods/7vs1/Alenger3.SC2Mod",
  "timestamp": "2026-07-22T08:30:00",
  "summary": {
    "total_buildings_checked": 8,
    "buildings_with_issues": 2,
    "total_missing_buttons": 8,
    "verdict": "fail"
  },
  "issues": [
    {
      "unit": "3diguoqianshaojidi",
      "unit_name": "前哨基地",
      "ability": "3xunlian1",
      "defined_trains": ["Train1", "Train10", "Train11", "Train12", "Train13"],
      "mounted_trains": ["Train1"],
      "missing_trains": [
        {"index": "Train10", "unit": "3RAAPhuopao", "name": "火炮"},
        {"index": "Train11", "unit": "3xiang", "name": "象"},
        {"index": "Train12", "unit": "3tiankongzhidun", "name": "天空之盾"},
        {"index": "Train13", "unit": "3huangjiawuweijizhanliejian", "name": "皇家无畏级战列舰"}
      ]
    }
  ]
}
```

### 3.5 实现细节

**文件位置**：`scripts/diagnostics/static_panel_analyzer.py`

**依赖**：Python 标准库 `xml.etree.ElementTree`、`json`、`argparse`

**命令行**：
```bash
python scripts/diagnostics/static_panel_analyzer.py \
  --mod-path "sc2-porting-workspace/projects/cmre-porting/packages/Mods/7vs1/Alenger3.SC2Mod" \
  --output "out/diagnostics/missing_buttons.json"
```

**单位名称映射**：从 `LocalizedData.xml` 读取，或维护一个静态映射表

## 4. Layer 2: 运行时验证器

### 4.1 目标

进图后通过 NeuroIntegration Bank IPC 实际验证按钮可点击性。

### 4.2 依赖

- NeuroIntegration 库（LibEFA54406）- Bank IPC 基础
- LibPortingObserver 的 `select_unit_type` 和 `order_selected` action
- RuntimeProbe 的 Bank 诊断

### 4.3 已有 Action（直接复用）

| Action | 参数 | 用途 | 来源 |
|--------|------|------|------|
| `select_unit_type` | arg_1=单位类型ID | 选中单位 | LibPortingObserver.galaxy |
| `order_selected` | arg_1=ability ID, arg_2=目标单位类型(可选) | 下发命令 | LibPortingObserver.galaxy |

### 4.4 新增 Galaxy 函数

#### 4.4.1 `libPortingObserver_gf_DumpCommandCard(string lp_unitType)`

**目标**：参数化的命令卡片枚举，替代硬编码的 `PublishAlengerCommandCardDump`

**逻辑**：
```galaxy
void libPortingObserver_gf_DumpCommandCard(string lp_unitType) {
    unitgroup lv_structs;
    unit lv_producer;
    int lv_abilityCount;
    int lv_i;
    string lv_abilityId;
    string lv_context;
    bool lv_canIssue;

    lv_structs = UnitGroup(lp_unitType, c_playerAny, RegionEntireMap(),
        UnitFilter(0, 0, 0, (1 << (c_targetFilterDead - 32)) | (1 << (c_targetFilterHidden - 32))), 0);

    if (UnitGroupCount(lv_structs, c_unitCountAll) == 0) {
        libPortingObserver_gf_Publish("command_card_dump",
            "unit=" + lp_unitType + "; error=unit_not_found", true);
        return;
    }

    lv_producer = UnitGroupUnit(lv_structs, 1);
    lv_abilityCount = UnitAbilityCount(lv_producer);

    lv_context = "unit=" + lp_unitType + "; ability_count=" + IntToString(lv_abilityCount) + "; abilities:";
    for (lv_i = 1; lv_i <= lv_abilityCount; lv_i += 1) {
        lv_abilityId = UnitAbilityGet(lv_producer, lv_i);
        lv_canIssue = UnitOrderIsValid(lv_producer, Order(AbilityCommand(lv_abilityId, 0)));
        lv_context = lv_context + " " + lv_abilityId + "(" + (lv_canIssue ? "T" : "F") + ");";
    }

    libPortingObserver_gf_Publish("command_card_dump", lv_context, true);
}
```

#### 4.4.2 `libPortingObserver_gf_VerifyBuildButton(string lp_unitType, string lp_abilId, int lp_cmd)`

**目标**：验证单个建造/训练按钮是否可点击

**逻辑**：
```galaxy
string libPortingObserver_gf_VerifyBuildButton(string lp_unitType, string lp_abilId, int lp_cmd) {
    unitgroup lv_structs;
    unit lv_producer;
    order lv_order;
    bool lv_valid;
    point lv_pos;
    string lv_result;

    lv_structs = UnitGroup(lp_unitType, c_playerAny, RegionEntireMap(),
        UnitFilter(0, 0, 0, (1 << (c_targetFilterDead - 32)) | (1 << (c_targetFilterHidden - 32))), 0);

    if (UnitGroupCount(lv_structs, c_unitCountAll) == 0) {
        return "fail:unit_not_found";
    }

    lv_producer = UnitGroupUnit(lv_structs, 1);
    lv_order = Order(AbilityCommand(lp_abilId, lp_cmd));

    // 对于 Build 类命令，需要设置目标点
    if (StringEqual(lp_abilId, "3jianzao1") || StringEqual(lp_abilId, "3jianzao2")) {
        lv_pos = UnitGetPosition(lv_producer);
        OrderSetTargetPoint(lv_order, lv_pos);
    }

    lv_valid = UnitOrderIsValid(lv_producer, lv_order);
    if (lv_valid) {
        lv_result = "pass:order_valid";
    } else {
        lv_result = "fail:order_invalid";
    }

    return lv_result;
}
```

### 4.5 新增 NeuroIntegration Action

#### `verify_build_panel`

**注册**：在 `LibPortingObserver.galaxy` 的 RegisterActions 函数中添加

```galaxy
libEFA54406_gf_create_action_1_arg("verify_build_panel", true,
    "验证指定建筑的建造/训练面板完整性，返回缺失的按钮列表",
    -1,
    "string", "建筑单位类型ID，如 3diguoqianshaojidi");
```

**处理逻辑**（在 action 执行触发器中）：
```galaxy
if (libEFA54406_gv_doAction_verify_build_panel) {
    libEFA54406_gv_doAction_verify_build_panel = false;
    libPortingObserver_gf_DumpCommandCard(libEFA54406_gv_doAction_verify_build_panel_arg_1);
    libEFA54406_gv_active = libEFA54406_gv_active + 1;
    BankSave(libEFA54406_gv_bank);
}
```

### 4.6 Python 端验证流程

**文件位置**：`scripts/diagnostics/runtime_verifier.py`

**流程**：
```python
1. 读取 missing_buttons.json（Layer 1 输出）
2. 如果无缺失 → 直接 pass，跳过运行时验证
3. 如果有缺失 → 进图后执行运行时验证:
   a. 对每个缺失按钮的建筑:
      - 写 Bank: do_action/select_unit_type=true, arg_1=建筑ID
      - 轮询 flag 清除（最长 8s）
      - 写 Bank: do_action/verify_build_panel=true, arg_1=建筑ID
      - 轮询 flag 清除
      - 读 Bank: game_context/command_card_dump
   b. 解析 command_card_dump，对比 ability 列表
   c. 对每个缺失的按钮:
      - 写 Bank: do_action/order_selected=true, arg_1=技能ID, arg_2=目标单位
      - 轮询 flag 清除
      - 读 Bank: game_context/action_result
      - 记录结果
4. 输出 runtime_verification.json
```

### 4.7 输出格式

```json
{
  "mod": "Alenger3",
  "map": "亡者之夜",
  "timestamp": "2026-07-22T09:00:00",
  "summary": {
    "buildings_verified": 2,
    "buttons_verified": 8,
    "passed": 8,
    "failed": 0,
    "verdict": "pass"
  },
  "verification_results": [
    {
      "unit": "3diguoqianshaojidi",
      "unit_name": "前哨基地",
      "ability_count_runtime": 12,
      "abilities_runtime": ["3xunlian1", "3shengkong1", ...],
      "build_attempts": [
        {
          "train_index": "Train10",
          "target_unit": "3RAAPhuopao",
          "order_valid": true,
          "result": "pass:order_valid"
        }
      ]
    }
  ]
}
```

## 5. Layer 3: 综合报告

### 5.1 对比逻辑

| Layer 1 静态 | Layer 2 运行时 | 判定 | 说明 |
|--------------|---------------|------|------|
| 缺失 | 不可点击 | **配置缺失** | 需修复 CardLayouts |
| 缺失 | 可点击 | **不一致** | 需调查（可能是父类继承） |
| 挂载 | 不可点击 | **运行时锁定** | 需检查 Requirements/State |
| 挂载 | 可点击 | **正常** | 无问题 |

### 5.2 输出

**文件位置**：`out/diagnostics/final_report.md`

**格式**：
```markdown
# 建造面板完整性检测报告

## 检测摘要
- 检测时间：2026-07-22 09:00:00
- Mod：Alenger3
- 地图：亡者之夜
- 总体判定：**PASS** / **FAIL**

## Layer 1: 静态分析
- 检查建筑数：8
- 有问题建筑数：0
- 缺失按钮数：0
- 判定：PASS

## Layer 2: 运行时验证
- 验证建筑数：8
- 验证按钮数：45
- 通过：45
- 失败：0
- 判定：PASS

## 详细结果
[表格：建筑 | 按钮 | 静态状态 | 运行时状态 | 判定]
```

## 6. 集成到启动器

### 6.1 修改 launch-cmre-alenger.ps1

在现有流程后添加验证步骤：

```powershell
# 现有流程
1. 启动游戏
2. 等待 Game Loading Complete
3. 等待 120s 确认无 ScriptError

# 【新增】Phase 1: 静态分析
Write-Host "=== Phase 1: Static Panel Analysis ==="
python scripts/diagnostics/static_panel_analyzer.py \
    --mod-path "$modPath" \
    --output "out/diagnostics/missing_buttons.json"

$staticResult = Get-Content "out/diagnostics/missing_buttons.json" | ConvertFrom-Json
if ($staticResult.summary.verdict -eq "fail") {
    Write-Host "STATIC FAIL: Missing buttons detected" -ForegroundColor Red
    # 不退出，继续运行时验证
}

# 【新增】Phase 2: 运行时验证
Write-Host "=== Phase 2: Runtime Verification ==="
python scripts/diagnostics/runtime_verifier.py \
    --bank-file "C:\Users\22448\Documents\StarCraft II\Banks\NeuroIntegration.SC2Bank" \
    --missing-buttons "out/diagnostics/missing_buttons.json" \
    --output "out/diagnostics/runtime_verification.json"

# 【新增】Phase 3: 综合报告
Write-Host "=== Phase 3: Final Report ==="
python scripts/diagnostics/generate_report.py \
    --static "out/diagnostics/missing_buttons.json" \
    --runtime "out/diagnostics/runtime_verification.json" \
    --output "out/diagnostics/final_report.md"

# 门禁
if ($staticResult.summary.verdict -eq "fail" -or $runtimeResult.summary.verdict -eq "fail") {
    Write-Host "VERIFICATION FAILED" -ForegroundColor Red
    exit 1
}
```

### 6.2 验证门禁

| 阶段 | 判定 | 动作 |
|------|------|------|
| 静态分析 | fail | 警告，继续运行时验证 |
| 运行时验证 | fail | 阻止 commit |
| 综合报告 | fail | 需修复后重新验证 |

## 7. 文件结构

```
scripts/diagnostics/
├── static_panel_analyzer.py    # Layer 1: 静态分析器
├── runtime_verifier.py         # Layer 2: 运行时验证器
├── bank_ipc_client.py          # Bank IPC 客户端（复用 bank_file_io.py）
├── generate_report.py          # Layer 3: 综合报告生成
└── verify_panel.py             # 主入口：串联 Layer 1 + 2 + 3

out/diagnostics/
├── missing_buttons.json        # Layer 1 输出
├── runtime_verification.json   # Layer 2 输出
└── final_report.md             # Layer 3 输出

合作指挥官-起义狂潮/Mods/RuntimeProbe/RuntimeProbe.SC2Mod/Base.SC2Data/
└── LibRuntimeProbe.galaxy      # 【修改】添加参数化命令卡片枚举函数

sc2-porting-workspace/projects/cmre-porting/runtime/
└── LibPortingObserver.galaxy   # 【修改】添加 verify_build_panel action
```

## 8. 实施步骤

### Phase 1: 静态分析器（不依赖游戏）

**目标**：实现 Layer 1，快速发现 CardLayouts 配置问题

**任务**：
1. 创建 `scripts/diagnostics/static_panel_analyzer.py`
2. 实现 XML 解析和对比逻辑
3. 对当前 Alenger3 运行，验证输出（应输出 0 个缺失，因已修复）
4. 人为删除一个 LayoutButtons，验证能检测到

**验收标准**：
- 能正确解析 UnitData.xml 和 AbilData.xml
- 能检测到缺失的 Train/Build 按钮挂载
- 输出格式符合 JSON schema

### Phase 2: 运行时验证器（依赖 NeuroIntegration）

**目标**：实现 Layer 2，通过 Bank IPC 实际验证按钮可点击性

**任务**：
1. 修改 `LibPortingObserver.galaxy`：
   - 添加 `libPortingObserver_gf_DumpCommandCard(lp_unitType)` 函数
   - 添加 `verify_build_panel` action 注册和处理
2. 创建 `scripts/diagnostics/runtime_verifier.py`：
   - 复用 `bank_file_io.py` 的 Bank IPC 客户端
   - 实现 select_unit_type + verify_build_panel 调用流程
3. 进图测试，验证 Bank IPC 通信正常

**验收标准**：
- 能通过 Bank IPC 选中指定单位
- 能获取单位命令卡片 ability 列表
- 能尝试下发建造/训练命令并获取结果

### Phase 3: 综合报告与集成

**目标**：实现 Layer 3，集成到启动器

**任务**：
1. 创建 `scripts/diagnostics/generate_report.py`
2. 创建 `scripts/diagnostics/verify_panel.py`（主入口）
3. 修改 `launch-cmre-alenger.ps1`，集成验证步骤
4. 添加验证门禁逻辑

**验收标准**：
- 启动器能自动运行验证
- 门禁逻辑正确（fail 时阻止 commit）
- 报告格式清晰易读

### Phase 4: 回归测试

**目标**：对其他指挥官运行验证器，确保不误报

**任务**：
1. 对 Raynor 指挥官运行静态分析器
2. 对 Swann 指挥官运行静态分析器
3. 确认已修复的 Swann 不报缺失
4. 确认配置完整的指挥官不误报

## 9. 风险与限制

### 9.1 已知限制

1. **Layer 2 不是真正的 UI 按钮检测**：`UnitAbilityCount`/`UnitAbilityGet` 枚举的是 ability 层，不是 UI CommandCard 按钮列表。但通常两者一致，且 `UnitOrderIsValid` 能反映按钮可用性。
2. **Galaxy API 限制**：无法直接读取 CommandCard 布局。Layer 1 的静态分析是唯一能检测 CardLayouts 挂载的方式。
3. **Bank IPC 延迟**：每次 action 调用需要 0.5-8s 轮询，验证多个按钮会比较慢。

### 9.2 风险

1. **父类继承复杂性**：如果建筑有 `parent="SCV"`，CardLayouts 会继承父类布局，静态分析需要处理继承关系。
2. **多 mod 合并**：Alenger3 mod 可能依赖其他 mod，静态分析需要合并所有依赖 mod 的 UnitData.xml。
3. **运行时修改**：某些 mod 会在运行时动态修改 CardLayouts，静态分析无法检测。

### 9.3 缓解措施

1. 对父类继承：静态分析器支持 `--resolve-inheritance` 选项，递归解析父类
2. 对多 mod 合并：静态分析器支持 `--include-deps` 选项，自动合并依赖 mod
3. 对运行时修改：Layer 2 运行时验证作为最终保障

## 10. 与 Neuro 命令交互的复用关系

### 10.1 直接复用

| Neuro 能力 | 用途 | 本方案使用方式 |
|-----------|------|---------------|
| Bank IPC 协议 | 双向通信 | Python 端写入 do_action，读取 game_context |
| `select_unit_type` action | 选中单位 | 选中待验证的建筑 |
| `order_selected` action | 下发命令 | 尝试点击建造/训练按钮 |
| `libPortingObserver_gf_Publish` | 推送上下文 | 读取命令卡片枚举结果 |

### 10.2 扩展新增

| 新增内容 | 位置 | 说明 |
|---------|------|------|
| `verify_build_panel` action | LibPortingObserver.galaxy | 触发命令卡片枚举 |
| `DumpCommandCard(lp_unitType)` | LibPortingObserver.galaxy | 参数化枚举函数 |
| `VerifyBuildButton(unitType, abilId, cmd)` | LibPortingObserver.galaxy | 单按钮验证函数 |

### 10.3 不复用的部分

- **NeuroRuntime HTTP API**：只读查询，本方案需要写入命令，不适用
- **LLM 决策**：本方案是确定性验证，不需要 LLM 参与
- **force_action**：本方案是主动验证，不需要强制 LLM 选择

## 11. 后续扩展

### 11.1 支持更多指挥官

当前方案针对 Alenger3 设计，但架构支持任意指挥官：
- 静态分析器接受 `--mod-path` 参数，可指向任意 CommanderUnits mod
- 运行时验证器通过 Bank IPC，与指挥官无关

### 11.2 CI/CD 集成

静态分析器可集成到 git pre-commit hook：
```bash
#!/bin/bash
python scripts/diagnostics/static_panel_analyzer.py --mod-path "$1" --check-only
if [ $? -ne 0 ]; then
    echo "CardLayouts check failed"
    exit 1
fi
```

### 11.3 单位生产链路验证

扩展 Layer 2，验证完整生产链路：
- 建造建筑 → 训练单位 → 单位出现在地图上
- 研究升级 → 升级生效

## 12. 待确认事项

1. **文档位置**：当前放在 `docs/build-panel-self-check-plan-2026-07-22.md`，是否合适？
2. **脚本位置**：`scripts/diagnostics/` 目录是否合适？还是放在 `sc2-porting-workspace/scripts/diagnostics/`？
3. **实施优先级**：是否先实现 Layer 1（静态分析器），再实现 Layer 2（运行时验证器）？
4. **Neuro 依赖**：Layer 2 依赖 NeuroIntegration mod 是否已加载。是否所有测试地图都加载了这个 mod？
5. **Galaxy 函数位置**：新增的 `DumpCommandCard` 和 `VerifyBuildButton` 放在 LibPortingObserver.galaxy 还是 LibRuntimeProbe.galaxy？
