# RuntimeProbe Bank 协议

- 版本：0.1.0 (Phase 0 协议定稿)
- 时间戳：2026-07-12
- 状态：草案
- 关联文档：`docs/经验总结/SC2-API自动进图自检方案选型-2026-07-12.md`

## 1. 目的

定义游戏内触发器与外部 Python Probe Runner 之间的双向数据协议，用于 SC2 合作指挥官、7vs1 测试地图、重生虫心战役地图的运行时自检。

协议载体为独立 Bank 文件 `RuntimeProbe.SC2Bank`，与 Neuro 业务 Bank 解耦，但可复用 Neuro 的 Bank 监听、原子写入、心跳判断、进程监控等基础设施。

## 2. 设计原则

1. **独立 Bank**：不污染 Neuro 业务 Bank，诊断协议与玩游戏动作协议分离。
2. **ASCII 优先**：Bank 内部 key、section、action_id、assertion_id、变量名保持 ASCII，避免 Galaxy 编码问题。
3. **心跳单调**：`probe_state.heartbeat` 必须单调递增，Python 端据此判断游戏是否在运行。
4. **unknown 显式**：无法稳定获取的字段必须标为 `unknown`，不能静默当成通过。
5. **动作幂等**：每个 probe action 带 `action_id`，触发器端去重，避免重复执行。
6. **三段式差异**：报告必须能输出 `Expected from DataCenter` / `Static effective Catalog` / `Runtime observed fact` 三段对比。

## 3. Bank 文件位置

```
C:\Users\<user>\Documents\StarCraft II\Banks\RuntimeProbe.SC2Bank
```

- 路径由 Python Runner 配置，默认与 Neuro Bank 同目录。
- Bank 必须由地图 BankList.xml 预声明，否则游戏不会加载。
- Bank 文件由触发器写入，Python 端只读 + 写 `probe_actions` section。

## 4. 通信流程

```
游戏内触发器(Galaxy)                 Python Probe Runner
        │                                │
        │  1. 写入 probe_state/units/     │
        │     producers/abilities/        │
        │     upgrades/assertions         │
        │  ─────────────────────────────> │
        │  (Bank 文件变更)                 │
        │                                │
        │                                │  2. watchdog 监测文件变更
        │                                │  3. parse_bank_file() 解析
        │                                │  4. normalize_probe.py 归一化 JSON
        │                                │  5. compare_expected.py 对比 DataCenter
        │                                │  6. 输出 VerificationReport
        │                                │
        │                                │  7. write probe_actions section
        │  <───────────────────────────── │
        │  8. 触发器读取 probe_actions     │
        │  9. 执行诊断动作(spawn/train/dump)│
        │ 10. 清除 probe_actions flags     │
        │ 11. 写入新的 probe_* 结果        │
        │                                │
```

## 5. Section 定义

### 5.1 probe_state

基础心跳与运行信息，触发器每帧或每秒写入。

| Key | 类型 | 说明 |
|-----|------|------|
| `run_id` | string | 本次启动的唯一 ID（Python 启动时生成，写入 Bank 后触发器回读） |
| `composition_id` | string | 组合配置 ID（commander + map + deps） |
| `map_id` | string | 地图标识 |
| `map_path` | string | 地图路径 |
| `commander_id` | string | 指挥官 ID |
| `player_id` | int | 玩家 ID（通常 1） |
| `game_time` | int | 游戏时间（秒） |
| `game_loop` | int | 游戏循环数 |
| `phase` | string | 阶段：`loading`/`in_mission`/`transition`/`ended` |
| `heartbeat` | int | 心跳值，单调递增 |
| `is_paused` | flag | 是否暂停 |
| `is_in_mission` | flag | 是否在任务中 |
| `script_error_count` | int | ScriptError 计数 |
| `loaded_mods` | string | 实际加载的依赖链（逗号分隔） |

**心跳规则**：
- 触发器每秒 +1，溢出回绕到 0。
- Python 端若 2.5 秒内 heartbeat 未变化，判定为暂停或卡死。
- `script_error_count > 0` 时，报告必须标记 `script_error_free = false`。

### 5.2 probe_units

单位与建筑摘要，触发器定期扫描全图单位写出。

每个单位类型一行，key 格式为 `u_<player_id>_<unit_type_id>`，value 为 `string`，内容为逗号分隔字段：

```
u_1_Marine=count:5,completed:5,in_progress:0,life_avg:45.0,energy_avg:0.0,owner:1,is_structure:0,is_worker:0
u_1_Barracks=count:2,completed:2,in_progress:0,life_avg:1500.0,energy_avg:0.0,owner:1,is_structure:1,is_worker:0
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `count` | int | 总数量 |
| `completed_count` | int | 已完成数量 |
| `in_progress_count` | int | 建造中数量 |
| `life_summary` | string | 生命摘要（avg/min/max） |
| `energy_summary` | string | 能量摘要 |
| `owner` | int | 所有者玩家 ID |
| `is_structure` | flag | 是否建筑 |
| `is_worker` | flag | 是否农民 |

**用途**：
- 判断初始单位、建筑、刷怪、测试生产结果是否符合预期。
- 发现"造出来的不是目标单位"或"单位 ID 被父依赖覆盖"。

### 5.3 probe_producers

生产建筑与可训练项，触发器扫描生产建筑的命令卡写出。

每个生产建筑一行，key 格式为 `p_<player_id>_<producer_catalog_id>`，value 为 `string`：

```
p_1_BarracksRaynor=trainable:MarineRaynor,MarauderRaynor;blocked:Ghost;queue:MarineRaynor,MarineRaynor;last_order:TrainMarineRaynor
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `producer_unit_id` | string | 生产建筑单位类型 ID |
| `producer_catalog_id` | string | 生产建筑 Catalog ID |
| `producer_count` | int | 该建筑数量 |
| `trainable_unit_ids` | string | 可训练单位列表（分号分隔） |
| `blocked_unit_ids` | string | 被锁定的单位列表 |
| `active_queue` | string | 当前训练队列 |
| `last_order_ability` | string | 最后一个订单能力 ID |

**用途**：
- 直接回答"兵营为什么造不出预期兵"。
- 区分缺按钮、Requirement 锁定、Ability 被覆盖、训练队列异常。

### 5.4 probe_abilities

关键单位能力与命令卡，触发器对指定单位 dump 命令卡。

每个单位类型一行，key 格式为 `a_<player_id>_<unit_type_id>`，value 为 `string`：

```
a_1_MarineRaynor=abilities:Attack,Patk,Stop,Move,HoldPos;buttons:AttackCard,StopCard,MoveCard;autocast:StimPack=0;missing_expected:None
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `unit_type_id` | string | 单位类型 ID |
| `ability_ids` | string | 能力列表（分号分隔） |
| `command_card_button_ids` | string | 命令卡按钮列表 |
| `missing_expected_ability_ids` | string | 缺失的预期能力 |
| `missing_expected_button_ids` | string | 缺失的预期按钮 |
| `autocast_flags` | string | 自动施法状态（key=value） |

**用途**：
- 发现"造出来的兵没有技能"。
- 对比 DataCenter 中定义的 expected abilities。
- 对比静态 XML 与运行时实际可见按钮。

### 5.5 probe_upgrades

科技与升级状态，触发器扫描玩家升级列表。

每个升级一行，key 格式为 `up_<player_id>_<upgrade_id>`，value 为 `string`：

```
up_1_TerranInfantryWeaponsLevel1=researched:0,available:1,in_progress:0,blocked_reason:None,affected:MarineRaynor,MarauderRaynor
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `upgrade_id` | string | 升级 ID |
| `researched` | flag | 是否已研究 |
| `available` | flag | 是否可研究 |
| `in_progress` | flag | 是否研究中 |
| `blocked_reason` | string | 被锁定原因 |
| `affected_unit_ids` | string | 受影响的单位列表 |

**用途**：
- 发现战役科技与指挥官科技对不上。
- 尤其适合鸡翅战役这类升级错位明显的地图。

### 5.6 probe_assertions

游戏内断言结果，触发器端直接输出判断结果。

每个断言一行，key 格式为 `as_<assertion_id>`，value 为 `string`：

```
as_raynor_marine_trainable=severity:critical,status:fail,expected:MarineRaynor,actual:None,message:BarracksRaynor cannot train MarineRaynor,source:probe_producers
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `assertion_id` | string | 断言 ID（ASCII） |
| `severity` | string | 严重级：`info`/`warning`/`error`/`critical` |
| `status` | string | 状态：`pass`/`fail`/`unknown` |
| `expected` | string | 期望值 |
| `actual` | string | 实际值 |
| `message` | string | 人类可读消息 |
| `source` | string | 断言来源（probe section 名） |

**用途**：
- 触发器端直接输出判断结果，Python 端不需要理解所有 Galaxy 细节。
- Python 端聚合所有 assertion 状态，生成最终报告。

### 5.7 probe_actions

外部请求触发器执行的诊断动作，Python 写入，触发器读取执行后清除。

每个动作一行，key 格式为 `do_<action_id>`，value 为 `string`：

```
do_0001=action:spawn_unit,target_player:1,target_unit:MarineRaynor,count:1,location:50,50
do_0002=action:try_train_unit,target_player:1,producer:BarracksRaynor,unit:MarineRaynor
do_0003=action:dump_command_card,target_player:1,unit_type:MarineRaynor
do_0004=action:try_research_upgrade,target_player:1,upgrade:TerranInfantryWeaponsLevel1
do_0005=action:dump_unit_abilities,target_player:1,unit_type:VultureRaynor
do_0006=action:dump_player_upgrades,target_player:1
do_0007=action:advance_test_phase,target_player:1,phase:production_test
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `action_id` | string | 动作 ID（ASCII，单调递增） |
| `action` | string | 动作类型 |
| `target_player` | int | 目标玩家 |
| `target_unit` | string | 目标单位类型 |
| `target_upgrade` | string | 目标升级 |
| `producer` | string | 生产建筑 |
| `args` | string | 其他参数 |

**支持的动作**：

| 动作 | 说明 | Phase |
|------|------|-------|
| `spawn_unit` | 生成单位 | Phase 1 |
| `select_producer` | 选择生产建筑 | Phase 2 |
| `try_train_unit` | 尝试训练单位 | Phase 2 |
| `try_research_upgrade` | 尝试研究升级 | Phase 3 |
| `dump_command_card` | dump 命令卡 | Phase 3 |
| `dump_player_upgrades` | dump 玩家升级 | Phase 3 |
| `dump_unit_abilities` | dump 单位能力 | Phase 3 |
| `advance_test_phase` | 推进测试阶段 | Phase 2 |

**执行规则**：
- 触发器读取 `probe_actions` section，对每个 `do_<action_id>` 执行对应动作。
- 执行完毕后删除该 key（或置 flag=0）。
- 执行结果写入对应的 `probe_*` section。
- Python 端写入时带 `action_id`，触发器端去重，避免重复执行。

## 6. 值类型约定

Bank XML 支持的值类型（与 Neuro 项目一致）：

| 类型 | XML 属性 | Python 类型 | 示例 |
|------|---------|------------|------|
| 布尔 | `flag="1"` / `flag="0"` | bool | `<Value flag="1"/>` |
| 整数 | `int="123"` | int | `<Value int="123"/>` |
| 定点数 | `fixed="1.5"` | float | `<Value fixed="1.500000"/>` |
| 字符串 | `string="text"` | str | `<Value string="MarineRaynor"/>` |
| 文本 | `text="..."` | str | `<Value text="long text"/>` |

复杂结构（如 probe_units 的多字段）统一用 `string` 类型，内容为逗号分隔的 `key:value` 对，字段间用 `,` 分隔，列表用 `;` 分隔。

## 7. Bank 文件示例

```xml
<?xml version="1.0" encoding="utf-8"?>
<Bank version="1">
  <Section name="probe_state">
    <Key name="run_id"><Value string="run-20260712-0001"/></Key>
    <Key name="composition_id"><Value string="raynor-traynor01-7vs1"/></Key>
    <Key name="map_id"><Value string="traynor01_7vs1"/></Key>
    <Key name="map_path"><Value string="Maps/traynor01_7vs1.SC2Map"/></Key>
    <Key name="commander_id"><Value string="Raynor"/></Key>
    <Key name="player_id"><Value int="1"/></Key>
    <Key name="game_time"><Value int="15"/></Key>
    <Key name="game_loop"><Value int="960"/></Key>
    <Key name="phase"><Value string="in_mission"/></Key>
    <Key name="heartbeat"><Value int="15"/></Key>
    <Key name="is_paused"><Value flag="0"/></Key>
    <Key name="is_in_mission"><Value flag="1"/></Key>
    <Key name="script_error_count"><Value int="0"/></Key>
    <Key name="loaded_mods"><Value string="CoreRuntime,Raynor,7vs1"/></Key>
  </Section>

  <Section name="probe_units">
    <Key name="u_1_SCVRaynor"><Value string="count:12,completed:12,in_progress:0,life_avg:45.0,energy_avg:0.0,owner:1,is_structure:0,is_worker:1"/></Key>
    <Key name="u_1_CommandCenterRaynor"><Value string="count:1,completed:1,in_progress:0,life_avg:1500.0,energy_avg:0.0,owner:1,is_structure:1,is_worker:0"/></Key>
    <Key name="u_1_BarracksRaynor"><Value string="count:1,completed:1,in_progress:0,life_avg:1500.0,energy_avg:0.0,owner:1,is_structure:1,is_worker:0"/></Key>
    <Key name="u_1_MarineRaynor"><Value string="count:3,completed:3,in_progress:0,life_avg:45.0,energy_avg:0.0,owner:1,is_structure:0,is_worker:0"/></Key>
  </Section>

  <Section name="probe_producers">
    <Key name="p_1_BarracksRaynor"><Value string="trainable:MarineRaynor,MarauderRaynor;blocked:Ghost;queue:MarineRaynor;last_order:TrainMarineRaynor"/></Key>
  </Section>

  <Section name="probe_abilities">
    <Key name="a_1_MarineRaynor"><Value string="abilities:Attack,Patk,Stop,Move,HoldPos,StimPack;buttons:AttackCard,StopCard,MoveCard,StimCard;autocast:StimPack=0;missing_expected:None"/></Key>
  </Section>

  <Section name="probe_upgrades">
    <Key name="up_1_TerranInfantryWeaponsLevel1"><Value string="researched:0,available:1,in_progress:0,blocked_reason:None,affected:MarineRaynor,MarauderRaynor"/></Key>
  </Section>

  <Section name="probe_assertions">
    <Key name="as_raynor_marine_trainable"><Value string="severity:critical,status:pass,expected:MarineRaynor,actual:MarineRaynor,message:BarracksRaynor can train MarineRaynor,source:probe_producers"/></Key>
    <Key name="as_raynor_marauder_trainable"><Value string="severity:critical,status:pass,expected:MarauderRaynor,actual:MarauderRaynor,message:BarracksRaynor can train MarauderRaynor,source:probe_producers"/></Key>
  </Section>

  <Section name="probe_actions">
    <!-- Python 写入，触发器读取后清除 -->
  </Section>
</Bank>
```

## 8. Python 端写入规范

Python 端只写 `probe_actions` section，不直接修改其他 section。

写入时必须：
1. 使用 `asyncio.Lock` 序列化写入，避免并发竞争。
2. 原子替换写入（先写临时文件再重命名）。
3. 仅在 `heartbeat` 变化后的 0.3 秒窗口内写入，确保游戏正在处理。
4. 每个 action 带 `action_id`，格式为 4 位数字字符串（`0001`-`9999`）。

写入示例：

```python
updates = {
    "probe_actions": {
        "do_0001": "action:spawn_unit,target_player:1,target_unit:MarineRaynor,count:1,location:50,50"
    }
}
write_bank_values(bank_file_path, updates)
```

## 9. 触发器端写入规范

触发器端负责写入所有 `probe_*` section（除 `probe_actions`），并读取执行 `probe_actions`。

触发器端必须：
1. 每秒更新 `probe_state.heartbeat`。
2. 每 2 秒扫描全图单位，更新 `probe_units`。
3. 每 5 秒扫描生产建筑，更新 `probe_producers`。
4. 收到 `probe_actions` 后，在下一个触发周期执行，执行完毕删除对应 key。
5. 执行动作后，将结果写入对应 `probe_*` section。
6. 所有 key 和 value 使用 ASCII，变量名保持 ASCII。

## 10. VerificationReport 输出

Python 端解析 Bank 后，生成结构化 JSON 报告：

```json
{
  "run_id": "run-20260712-0001",
  "composition_id": "raynor-traynor01-7vs1",
  "timestamp": "2026-07-12T15:30:00",
  "status": {
    "launch_pass": true,
    "map_loaded": true,
    "probe_complete": true,
    "static_match": true,
    "runtime_assertions_pass": true,
    "script_error_free": true
  },
  "probe_state": { ... },
  "probe_units": [ ... ],
  "probe_producers": [ ... ],
  "probe_abilities": [ ... ],
  "probe_upgrades": [ ... ],
  "probe_assertions": [ ... ],
  "diffs": [
    {
      "unit_type_id": "MarineRaynor",
      "expected_from_datacenter": ["MarineRaynor"],
      "static_effective_catalog": ["MarineRaynor"],
      "runtime_observed": ["MarineRaynor"],
      "match": true
    }
  ]
}
```

**状态定义**：

| 状态 | 说明 | 判定条件 |
|------|------|---------|
| `launch_pass` | 进程启动成功 | SC2 进程启动且 API 可连接 |
| `map_loaded` | Bank 心跳出现 | heartbeat >= 1 |
| `probe_complete` | 诊断阶段完成 | probe_state.phase == "in_mission" 且 probe_units 非空 |
| `static_match` | 静态期望与运行时匹配 | 所有 diff.match == true |
| `runtime_assertions_pass` | 触发器断言通过 | 所有 assertion.status == "pass" |
| `script_error_free` | 未发现 ScriptError | script_error_count == 0 |

## 11. 最小诊断案例：Raynor Marine/Marauder/Vulture

以 Raynor 指挥官在 7vs1 测试地图为例，验证协议覆盖能力：

### 期望（来自 DataCenter）

| 生产建筑 | 可训练单位 | 缺失则报警 |
|---------|-----------|-----------|
| BarracksRaynor | MarineRaynor, MarauderRaynor | critical |
| FactoryRaynor | VultureRaynor, SiegeTankRaynor | critical |
| StarportRaynor | MedivacRaynor | warning |

### 运行时事实（Bank 报告）

```xml
<Section name="probe_producers">
  <Key name="p_1_BarracksRaynor"><Value string="trainable:MarineRaynor,MarauderRaynor;blocked:;queue:;last_order:None"/></Key>
  <Key name="p_1_FactoryRaynor"><Value string="trainable:VultureRaynor,SiegeTankRaynor;blocked:;queue:;last_order:None"/></Key>
  <Key name="p_1_StarportRaynor"><Value string="trainable:MedivacRaynor;blocked:;queue:;last_order:None"/></Key>
</Section>
```

### 三段式差异

```json
{
  "diffs": [
    {
      "producer": "BarracksRaynor",
      "expected_from_datacenter": ["MarineRaynor", "MarauderRaynor"],
      "static_effective_catalog": ["MarineRaynor", "MarauderRaynor"],
      "runtime_observed": ["MarineRaynor", "MarauderRaynor"],
      "match": true
    },
    {
      "producer": "FactoryRaynor",
      "expected_from_datacenter": ["VultureRaynor", "SiegeTankRaynor"],
      "static_effective_catalog": ["VultureRaynor", "SiegeTankRaynor"],
      "runtime_observed": ["VultureRaynor", "SiegeTankRaynor"],
      "match": true
    }
  ]
}
```

### 断言

```json
{
  "probe_assertions": [
    {
      "assertion_id": "raynor_marine_trainable",
      "severity": "critical",
      "status": "pass",
      "expected": "MarineRaynor",
      "actual": "MarineRaynor",
      "message": "BarracksRaynor can train MarineRaynor",
      "source": "probe_producers"
    },
    {
      "assertion_id": "raynor_vulture_trainable",
      "severity": "critical",
      "status": "pass",
      "expected": "VultureRaynor",
      "actual": "VultureRaynor",
      "message": "FactoryRaynor can train VultureRaynor",
      "source": "probe_producers"
    }
  ]
}
```

协议能完整覆盖此最小诊断案例。

## 12. 与 Neuro 的关系

```
NeuroBridge
  负责 LLM 玩游戏和动作协议
  使用 NeuroIntegration.SC2Bank

RuntimeProbeBridge
  负责工程自检和诊断协议
  使用 RuntimeProbe.SC2Bank

Shared Bank Runtime
  复用 Bank 监听、原子写入、心跳、进程监控、超时、报告
  位于 scripts/runtime-probe/bank_io.py
```

- 没有 Neuro 时也能跑自检。
- 有 Neuro 时，AI 可以读取 RuntimeProbe 报告后决定下一步。
- 便宜模型可以只处理 RuntimeProbe JSON，不必理解整套地图工程。

## 13. 与 DataCenter 的关系

RuntimeProbe 不维护"正确答案"，正确答案来自数据中心：

1. `DataCenter.json`：组合、依赖、包、Adapter、预期能力。
2. CommanderPackage：指挥官规范定义。
3. CompositionPlan：某次地图 + 指挥官组合的有效计划。
4. 静态扫描：Catalog trace / diagnose-unit / effective dependency 结果。
5. RuntimeProbe：进图后的事实。

自检逻辑输出"三段式差异"：
- Expected from DataCenter
- Static effective Catalog
- Runtime observed fact

据此判断问题位于：
- 数据中心期望错了。
- 依赖链选错了。
- Catalog 被父级或地图覆盖了。
- Galaxy 运行时改掉了。
- 触发器诊断漏报。

## 14. 风险与处理

| 风险 | 处理 |
|------|------|
| Bank IO 延迟和竞争 | 复用 Neuro 的原子写入、锁、watchdog、合成事件机制；所有 probe action 带 action_id |
| 触发器写入能力有限 | 第一阶段只写最容易取得的数据；难取的数据用动作式探针获取；无法获取标为 unknown |
| 地图和依赖覆盖 | 每份报告记录有效依赖链；区分父级 Mod、指挥官 Mod、Adapter、地图本地覆盖；RuntimeProbe 未加载时报告失败 |
| ScriptError | 内部 ID、变量名保持 ASCII；改 Galaxy 前先跑 checker |

## 15. 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 0.1.0 | 2026-07-12 | Phase 0 协议定稿，定义 7 个 section 和最小诊断案例 |

## 16. 后续 Phase

| Phase | 产物 | 验收 |
|-------|------|------|
| Phase 1 | RuntimeProbe.SC2Mod + Python Bank watcher + NoActionProbe 报告 | 启动 7vs1 测试地图后能拿到心跳、玩家、初始单位、建筑、已研究升级 |
| Phase 2 | try_train_unit probe action + producer dump | 能对兵营/工厂/星港输出可生产项，能发现"期望可造但运行时不可造"的单位 |
| Phase 3 | dump_unit_abilities + dump_command_card + try_research_upgrade | 能发现单位缺技能、按钮不显示、自动施法状态错误、科技升级对不上 |
| Phase 4 | 可选 RequestObservation 采集器 + 交叉校验 | 能确认 Bank 中的单位数量和 SC2API 观测数量是否一致 |
| Phase 5 | 组合矩阵 + VerificationReport 汇总 | 能批量找出哪些地图缺 RuntimeProbe 支持，按失败类型输出待修复清单 |
