# Reborn 依赖按需加载设计

## 背景

Reborn 战役地图（zexpedition/zevolution 系列）当前启动时加载 37 条依赖，其中 Alenger 系列 24 条占 65%。根因是 `LibE0EAE146_AdapterBootstrap.galaxy` 硬编码 include 了全部 11 个 Alenger adapter，galaxy 编译期解析要求所有被 include 的文件必须存在，导致所有 Alenger mod 必须作为依赖。

CoreRuntime.SC2Mod 的架构约束要求只依赖官方 mod（VoidMulti/StarCoop），不应包含项目内部 mod 依赖。当前 AdapterBootstrap 违反了这一约束。

## 目标

- CoreRuntime 移除所有 Alenger 相关代码，回归纯净（只依赖 VoidMulti + StarCoop）
- Alenger mod 按选中的指挥官动态加载：选 Raynor 时 0 个 Alenger 依赖，选 Alenger3 时只加载 3 个
- Campaign 依赖按地图动态选择
- 总依赖数从 37 降到 ~13（选非 Alenger）或 ~16（选 Alenger）

## 架构

### 当前结构

```
CoreRuntime.SC2Mod
  ├── LibE0EAE146.galaxy                    (第54行 include AdapterBootstrap, 第1906行调用 InitLib)
  ├── LibE0EAE146_AdapterBootstrap.galaxy   (实体: include LibA1ADAPTER ~ LibA13ADAPTER)
  └── LibE0EAE146_AdapterBootstrap_h.galaxy
```

调用链：`MapScript InitLibs → LibE0EAE146_InitLib → libE0EAE146_AdapterBootstrap_InitLib → 所有 Alenger adapter InitLib`

### 拆分后结构

```
CoreRuntime.SC2Mod (纯净, 只依赖 VoidMulti+StarCoop)
  └── LibE0EAE146.galaxy                    (移除 include AdapterBootstrap + 移除 InitLib 调用)

RebornMapAdapter.SC2Mod (承接 Alenger 初始化)
  ├── RebornMapAdapter.galaxy               (添加 include AlengerBootstrap_h, OnAfterUnitsInit 中调用 InitLib)
  ├── LibRebornAdapter_AlengerBootstrap_h.galaxy  (静态头文件, 声明 InitLib)
  └── LibRebornAdapter_AlengerBootstrap.galaxy    (generated, 只 include 选中的 Alenger adapter)
```

调用链：`RebornMapAdapter.OnAfterUnitsInit → libRebornAdapter_AlengerBootstrap_InitLib → 选中的 Alenger adapter InitLib`

## 组件改动

### 1. CoreRuntime.SC2Mod

- 删除 `LibE0EAE146_AdapterBootstrap.galaxy`
- 删除 `LibE0EAE146_AdapterBootstrap_h.galaxy`
- `LibE0EAE146.galaxy`：
  - 移除第 54 行 `include "LibE0EAE146_AdapterBootstrap"`
  - 移除第 1906 行 `libE0EAE146_AdapterBootstrap_InitLib();`

### 2. RebornMapAdapter.SC2Mod

新增静态头文件 `LibRebornAdapter_AlengerBootstrap_h.galaxy`：

```galaxy
// Library: RebornAdapter AlengerBootstrap Header
void libRebornAdapter_AlengerBootstrap_InitLib ();
```

修改 `RebornMapAdapter.galaxy`：
- 添加 `include "LibRebornAdapter_AlengerBootstrap_h"`
- `OnAfterUnitsInit` 中在 `libE0EAE146_gf_Initialize` 之前调用 `libRebornAdapter_AlengerBootstrap_InitLib()`

```galaxy
void libRebornAdapter_OnAfterUnitsInit () {
    point lv_startPoint;
    string lv_commander;

    lv_startPoint = PlayerStartLocation(1);
    lv_commander = libRebornAdapter_GetCommanderForPlayer(1);

    libRebornAdapter_AlengerBootstrap_InitLib();  // 新增: Alenger adapter 初始化
    libE0EAE146_gf_Initialize(true);
    libE0EAE146_gf_CommanderRuntimeInit(1, lv_commander, lv_startPoint, true);
}
```

新增 generated 文件 `LibRebornAdapter_AlengerBootstrap.galaxy`：
- 选 Alenger3：`include "LibA3ADAPTER"` + 调用 `libA3ADAPTER_InitLib()`
- 选 Raynor：空 InitLib（不 include 任何 Alenger adapter）

### 3. launcher 修改

#### bootstrapGenerator.mjs 扩展

新增 `generateAlengerBootstrap(commander, alengerMapping)` 函数：
- 输入：选中的 commander id + commanderToAlenger 映射
- 输出：generated `LibRebornAdapter_AlengerBootstrap.galaxy` 内容
- commander 不在映射中 → 生成空壳
- commander 在映射中 → 生成只 include 对应 adapter 的实体

#### launcher-plan.ps1 修改

- L2 层改为按 commanderToAlenger 映射过滤
- 选非 Alenger → L2 为空
- 选 Alenger3 → L2 只有 AlengerCommon + Alenger3 + Alenger3Adapter
- galaxy 注入列表添加 generated AlengerBootstrap 文件

#### reborn-dependencies.json 修改

- `baseDependencyPaths` 移除 Campaign 依赖（改由 mapCampaigns 提供）
- 新增 `mapCampaigns` 映射

#### alenger-mods.json 修改

- 新增 `commanderToAlenger` 映射表
- `mods` 和 `dependencyPaths` 保留作为全量参考（不再全量加载）

## 配置

### commanderToAlenger 映射（alenger-mods.json）

```json
"commanderToAlenger": {
  "Alenger1":  ["AlengerCommon", "Alenger1", "Alenger1Adapter"],
  "Alenger3":  ["AlengerCommon", "Alenger3", "Alenger3Adapter"],
  "Alenger6":  ["AlengerCommon", "Alenger6", "Alenger6Adapter"],
  "Alenger8":  ["AlengerCommon", "Alenger8", "Alenger8Runtime", "Alenger8Adapter"],
  "Alenger9":  ["AlengerCommon", "Alenger9", "Alenger9Adapter"],
  "Alenger2":  ["AlengerCommon", "Alenger2", "Alenger2Adapter"],
  "Alenger7":  ["AlengerCommon", "Alenger7", "Alenger7Adapter"],
  "Alenger10": ["AlengerCommon", "Alenger10", "Alenger10Adapter"],
  "Alenger11": ["AlengerCommon", "Alenger11", "Alenger11Adapter"],
  "Alenger12": ["AlengerCommon", "Alenger12", "Alenger12Adapter"],
  "Alenger13": ["AlengerCommon", "Alenger13", "Alenger13Adapter"]
}
```

### mapCampaigns 映射（reborn-dependencies.json）

```json
"mapCampaigns": {
  "zexpedition03_reborn_port":       ["bnet:Void Story (Campaign)/0.0/999,file:Campaigns/VoidStory.SC2Campaign"],
  "zevolutionbaneling2_reborn_port": ["bnet:Void Story (Campaign)/0.0/999,file:Campaigns/VoidStory.SC2Campaign"]
}
```

## 数据流

### 选 Alenger3

```
1. launcher 读取 commander=TerranAlenger3
2. 查 commanderToAlenger → ["AlengerCommon", "Alenger3", "Alenger3Adapter"]
3. bootstrapGenerator 生成 LibRebornAdapter_AlengerBootstrap.galaxy:
     include "LibA3ADAPTER_h"
     include "LibA3ADAPTER"
     void libRebornAdapter_AlengerBootstrap_InitLib() {
         libA3ADAPTER_InitLib();
     }
4. 注入该文件到地图 Base.SC2Data
5. 只同步 3 个 Alenger mod 到 live
6. DocumentHeader 依赖 = baseDeps(9, 移除campaign) + 3 Alenger + 1 campaign = 13 条
```

### 选 Raynor

```
1. commander=TerranRaynor → commanderToAlenger 无匹配 → 空列表
2. 生成空壳 LibRebornAdapter_AlengerBootstrap.galaxy:
     void libRebornAdapter_AlengerBootstrap_InitLib() {}
3. 不同步任何 Alenger mod
4. DocumentHeader 依赖 = baseDeps(9, 移除campaign) + 1 CommanderUnits_Raynor + 1 campaign = 11 条
```

## 错误处理

| 场景 | 处理 |
|------|------|
| commander 不在 commanderToAlenger 映射中 | 视为非 Alenger，生成空壳 bootstrap |
| Alenger mod 文件缺失 | bootstrapGenerator 跳过该 adapter，警告 |
| mapCampaigns 无匹配地图 | 回退到 baseDependencyPaths 的 campaign |
| generated bootstrap 编译失败 | galaxy-checker 在注入后静态校验，报错阻塞 |

## 测试策略

### 1. 单元测试（bootstrapGenerator.test.mjs 扩展）

- 选 Raynor → 生成空壳 bootstrap（无 Alenger include）
- 选 Alenger3 → 生成只含 LibA3ADAPTER 的 bootstrap
- 选 Alenger8 → 生成含 LibA8ADAPTER 的 bootstrap（验证 Alenger8Runtime 额外 mod）
- 未知 commander → 生成空壳

### 2. launcher-plan 稳定性测试

- 选 Raynor → plan 无 Alenger 依赖
- 选 Alenger3 → plan 只有 3 个 Alenger 依赖
- 两次运行 JSON 一致

### 3. 进图回归测试

- Raynor × zexpedition03：无 ScriptError，游戏正常加载
- Alenger3 × zexpedition03：无 ScriptError，Alenger3 单位可生产
- 验证 DocumentHeader 依赖数 ≤ 16

### 4. galaxy-checker 校验

- 注入后运行 galaxy-checker，确认无 "函数已声明但尚未定义" 错误

## 依赖数对比

| 场景 | 当前 | 优化后 | 减少 |
|------|------|--------|------|
| 选 Raynor | 37 | 11 | 26 |
| 选 Alenger3 | 37 | 13 | 24 |
| 选 Alenger8 | 37 | 14 | 23 |

> 注：baseDeps(9) = 3 Reborn核心 + 1 kit_mutations + 5 7vs1基础。Campaign 按地图选 1 条。Alenger8 额外含 Alenger8Runtime。
