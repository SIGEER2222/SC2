# AIRO 单位替换系统设计

**日期**: 2026-07-11
**状态**: 设计完成，待用户审核
**关联**: AIRO Campaign Launcher (`scripts/airo/launch-airo-campaign.ps1`)

## 背景与问题

### 问题描述

当 AIRO 启动器在原版 WoL 战役地图（如 `traynor01.SC2Map`）上叠加 7vs1 指挥官时，出现两类问题：

1. **混单位问题**: 地图预放置的玩家 1 原版 Terran 单位（Command Center、SCV、Barracks 等）与 7vs1 CoreRuntime 创建的指挥官单位（如 Kerrigan 的 Hatchery、Drone）在同一位置共存，导致两套单位叠加。

2. **空投/救援小队未替换**: 地图触发器动态创建的原版单位（如 `gt_RiksvilleTownSquareDropPods` 空投的 `IronWarrior`、`gt_P1Rescues` 救援的 Marine/Firebat）仍然是 WoL 原版 Terran 单位，与指挥官种族不一致。

### 根因分析

7vs1 CoreRuntime 的设计假设是：原生 7vs1 地图不预放置玩家基地单位，由 `libE0EAE146_gf_InitializeBase` 负责创建全部起始单位。当系统被注入到原版 WoL 战役地图时：

- `gt_Init03Units` 不创建单位（只分组预放置单位），但地图 Objects 文件已预放置了玩家 1 的 Terran 基地
- AIRO 启动器注入的 `libE0EAE146_gf_InitializeMapBaseScenario` 在 `PlayerStartLocation(1)` 叠加创建指挥官单位
- 7vs1 系统**完全没有单位替换/删除机制** — 不清理原版单位，不替换动态创建的单位

### 影响范围

- 起始位置：原版 Terran 基地 + 指挥官基地共存
- 动态单位：空投小队、救援小队仍为原版 Terran 单位
- 玩家体验：种族不一致，操作混乱

## 设计目标

1. **消除混单位**: 起始位置只保留指挥官种族的建筑和单位
2. **替换动态单位**: 空投小队、救援小队等单位替换为指挥官对应单位
3. **事件触发式**: 不在开局一次性替换，而是在单位创建事件触发时按需替换
4. **可扩展**: 映射表支持所有 18 个指挥官，便于后续扩展
5. **非侵入式**: 不修改 CoreRuntime 或 CommanderUnits mod，作为独立适配层

## 架构设计

### 总体架构

创建独立 galaxy 库 `LibAIROAdapter.galaxy`，作为 AIRO 地图与 7vs1 CoreRuntime 之间的适配层。类似于 `RebornMapAdapter` 的角色，但专注于单位替换。

```
[地图 MapScript.galaxy]
  ├── gt_Init01Technology
  ├── gt_Init02Players
  ├── gt_Init03Units             ← 地图预放置单位被分组到变量
  │
  ├── libE0EAE146_gf_Initialize  ← 7vs1 加载 Bank、设置 commander
  ├── libE0EAE146_gf_InitializeMapBaseScenario  ← 创建指挥官基地单位
  │
  ├── libAIROAdapter_gf_InitUnitReplacement  ← 【新增】启动单位替换系统
  │   ├── 清理起始位置原版单位（一次性）
  │   └── 注册单位创建事件监听器（持续）
  │
  ├── gt_Init04Music
  └── ...
```

### 组件设计

#### 组件 1: `LibAIROAdapter.galaxy` — 单位替换核心库

**职责**: 提供单位替换的映射查询和执行逻辑

**文件位置**: `Mods/AIRO/AIROAdapter.SC2Mod/Base.SC2Data/LibAIROAdapter.galaxy`

**依赖**:
- `LibE0EAE146`（CoreRuntime，读取 `libE0EAE146_gv_commander`）
- `LibNtve`（原生库，单位操作 API）

**核心函数**:

```galaxy
// 初始化单位替换系统（在 CoreRuntime 初始化之后调用）
void libAIROAdapter_gf_InitUnitReplacement ();

// 查询原版单位对应的指挥官替换单位
// 返回空字符串表示无替换（保留原版单位）
string libAIROAdapter_gf_GetReplacementUnit (string lp_originalUnit, string lp_commander);

// 清理起始位置附近的原版单位（一次性）
void libAIROAdapter_gf_CleanupStartLocationUnits ();

// 单位创建事件处理函数（由触发器调用）
bool libAIROAdapter_gt_UnitCreated_Func (bool testConds, bool runActions);
```

#### 组件 2: 起始单位清理逻辑

**触发时机**: `libAIROAdapter_gf_InitUnitReplacement` 调用时（CoreRuntime 初始化之后）

**逻辑**:

```galaxy
void libAIROAdapter_gf_CleanupStartLocationUnits () {
    point lv_start = PlayerStartLocation(1);
    region lv_startRegion = RegionCircle(lv_start, 25.0);
    
    // 获取起始位置附近玩家 1 的所有单位
    unitgroup lv_units = UnitGroup(null, 1, lv_startRegion, UnitFilter(0, 0, (1 << 0), (1 << 1)), 0);
    unit lv_u;
    
    while (true) {
        lv_u = UnitGroupPickRandomUnit(lv_units, true);
        if (lv_u == null) { break; }
        
        string lv_type = UnitGetType(lv_u);
        string lv_replacement = libAIROAdapter_gf_GetReplacementUnit(lv_type, libE0EAE146_gv_commander);
        
        if (lv_replacement != "" && lv_replacement != lv_type) {
            // 有替换单位 → 删除原版单位（CoreRuntime 已在附近创建了指挥官单位）
            UnitRemove(lv_u);
        }
        // 无替换单位 → 保留原版单位（如地图场景物件、装饰单位）
    }
}
```

**清理范围**: 起始位置半径 25 格内的玩家 1 单位

**清理条件**:
- 单位类型在替换映射表中有对应项
- 替换后的单位类型与原版不同（避免误删指挥官已创建的单位）

**安全机制**:
- 只清理玩家 1 的单位（不影响敌方、盟友）
- 只清理有映射表条目的单位类型（不误删场景物件）
- 跳过指挥官已创建的单位（类型相同则跳过）

#### 组件 3: 事件触发式单位替换

**触发器**: `libAIROAdapter_gt_UnitCreated`

**注册逻辑**:

```galaxy
void libAIROAdapter_gf_InitUnitReplacement () {
    // 1. 先执行一次性起始单位清理
    libAIROAdapter_gf_CleanupStartLocationUnits();
    
    // 2. 注册单位创建事件监听器
    libAIROAdapter_gt_UnitCreated = TriggerCreate("libAIROAdapter_gt_UnitCreated_Func");
    TriggerAddEventUnitCreated(libAIROAdapter_gt_UnitCreated, 1, null, null);
    // 监听玩家 1 的所有单位创建事件
}
```

**事件处理逻辑**:

```galaxy
bool libAIROAdapter_gt_UnitCreated_Func (bool testConds, bool runActions) {
    unit lv_createdUnit = EventUnitCreatedUnit();
    string lv_type = UnitGetType(lv_createdUnit);
    string lv_replacement = libAIROAdapter_gf_GetReplacementUnit(lv_type, libE0EAE146_gv_commander);
    
    if (lv_replacement == "" || lv_replacement == lv_type) {
        return true;  // 无替换，保留原版单位
    }
    
    // 安全检查：替换后的单位必须在 catalog 中有效
    if (!CatalogEntryIsValid(c_gameCatalogUnit, lv_replacement)) {
        return true;  // 替换单位无效，保留原版
    }
    
    // 执行替换：在同一位置创建指挥官单位，删除原版单位
    point lv_pos = UnitGetPosition(lv_createdUnit);
    fixed lv_facing = UnitGetFacing(lv_createdUnit);
    
    libNtve_gf_CreateUnitsWithDefaultFacing(1, lv_replacement, c_unitIgnore, 1, lv_pos);
    unit lv_newUnit = UnitLastCreated();
    UnitSetFacing(lv_newUnit, lv_facing, 0.0);
    
    // 转移命令队列（如果有）
    // 注意：SC2 没有直接转移命令队列的 API，这里是尽力而为
    
    UnitRemove(lv_createdUnit);
    
    return true;
}
```

**替换策略**:
- 监听玩家 1 的**所有**单位创建事件
- 只有在映射表中有对应条目时才替换
- 替换单位在原单位位置创建，朝向保持一致
- 无效的替换单位（`CatalogEntryIsValid=0`）跳过，保留原版

**防重入机制**:
- 替换创建的新单位也会触发 `UnitCreated` 事件
- 如果新单位类型在映射表中也有条目，可能导致无限循环
- **解决方案**: 在映射表中，指挥官单位不应映射回其他单位（映射是单向的：原版→指挥官）

#### 组件 4: 单位映射表

**设计原则**:
- 分两大类：建筑类（起始单位）和战斗单位类（动态单位）
- 每个指挥官一个分支，无映射时返回空字符串（保留原版）
- 参考 `libE0EAE146_gf_CommanderAchUnit` 的现有映射逻辑

**映射函数**:

```galaxy
string libAIROAdapter_gf_GetReplacementUnit (string lp_originalUnit, string lp_commander) {
    // === 建筑类（起始单位清理用） ===
    if (lp_originalUnit == "CommandCenter") {
        if (lp_commander == "Kerrigan") return "HatcheryKerrigan";
        if (lp_commander == "Artanis") return "NexusArtanis";
        if (lp_commander == "Raynor") return "CommandCenterRaynor";
        // ... 其他指挥官
    }
    if (lp_originalUnit == "Barracks") {
        if (lp_commander == "Kerrigan") return "HatcheryKerrigan";  // Kerrigan 用主基地生产
        if (lp_commander == "Artanis") return "GatewayArtanis";
        if (lp_commander == "Raynor") return "BarracksRaynor";
    }
    if (lp_originalUnit == "SupplyDepot") {
        if (lp_commander == "Kerrigan") return "OverlordKerrigan";  // 虫族人口是单位
        if (lp_commander == "Artanis") return "PylonArtanis";
        if (lp_commander == "Raynor") return "SupplyDepotRaynor";
    }
    if (lp_originalUnit == "Refinery") {
        if (lp_commander == "Kerrigan") return "ExtractorKerrigan";
        if (lp_commander == "Artanis") return "AssimilatorArtanis";
        if (lp_commander == "Raynor") return "RefineryRaynor";
    }
    
    // === 战斗单位类（动态单位替换用） ===
    if (lp_originalUnit == "Marine") {
        if (lp_commander == "Kerrigan") return "ZerglingKerrigan";
        if (lp_commander == "Artanis") return "ZealotArtanis";
        if (lp_commander == "Raynor") return "MarineRaynor";
    }
    if (lp_originalUnit == "Marauder") {
        if (lp_commander == "Kerrigan") return "RoachKerrigan";
        if (lp_commander == "Artanis") return "StalkerArtanis";
        if (lp_commander == "Raynor") return "MarauderRaynor";
    }
    if (lp_originalUnit == "Firebat") {
        if (lp_commander == "Kerrigan") return "BanelingKerrigan";
        if (lp_commander == "Artanis") return "HighTemplarArtanis";
        if (lp_commander == "Raynor") return "FirebatRaynor";
    }
    if (lp_originalUnit == "Medic") {
        if (lp_commander == "Kerrigan") return "QueenKerrigan";
        if (lp_commander == "Artanis") return "MedivacArtanis";
        if (lp_commander == "Raynor") return "MedicRaynor";
    }
    if (lp_originalUnit == "IronWarrior") {
        // IronWarrior 是空投小队的特殊单位
        if (lp_commander == "Kerrigan") return "HydraliskKerrigan";
        if (lp_commander == "Artanis") return "DragoonArtanis";
        if (lp_commander == "Raynor") return "MarauderRaynor";
    }
    if (lp_originalUnit == "SCV") {
        if (lp_commander == "Kerrigan") return "DroneKerrigan";
        if (lp_commander == "Artanis") return "ProbeArtanis";
        if (lp_commander == "Raynor") return "SCVRaynor";
    }
    
    // 无映射 → 返回空字符串，保留原版单位
    return "";
}
```

**映射表扩展策略**:
- 第一阶段只实现 Kerrigan、Artanis、Raynor 三个指挥官的映射（覆盖三个种族）
- 后续根据需要扩展其他指挥官
- 每个指挥官的映射参考其 `CommanderAchUnit` 和 `TechFilter` 中的单位列表

### 集成方式

#### 启动器修改

在 `launch-airo-campaign.ps1` 的 galaxy 注入部分，额外注入 `LibAIROAdapter.galaxy`：

```powershell
# 6. Inject AIROAdapter galaxy file
$airoAdapterBaseData = Join-Path $ProjRoot "Mods\AIRO\AIROAdapter.SC2Mod\Base.SC2Data"
if (Test-Path $airoAdapterBaseData) {
    $adapterGalaxyFiles = Get-ChildItem $airoAdapterBaseData -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
    foreach ($gf in $adapterGalaxyFiles) {
        $dst = Join-Path $mapLiveBaseData $gf.Name
        [System.IO.File]::Copy($gf.FullName, $dst, $true)
    }
}
```

#### MapScript.galaxy 补丁

在 `gt_Init03Units` 之后的 CoreRuntime 初始化调用之后，添加 AIROAdapter 初始化：

```powershell
# 在现有的 CoreRuntime init 注入之后追加
$adapterInitCall = "    libAIROAdapter_gf_InitUnitReplacement();`n"
```

修改后的注入顺序：

```galaxy
TriggerExecute(gt_Init03Units, true, true);
// AIRO: 7vs1 commander overlay initialization
libE0EAE146_gf_Initialize(true);
libE0EAE146_gf_InitializeMapBaseScenario("traynor01");
// AIRO: 单位替换系统初始化
libAIROAdapter_gf_InitUnitReplacement();
```

#### 依赖配置

在 `airo-dependencies.json` 中添加 AIROAdapter mod 依赖：

```json
{
  "commanderBaseDependencyPaths": [
    "file:Mods/7vs1/CoreRuntime.SC2Mod",
    "file:Mods/7vs1/CommanderBridge.SC2Mod",
    "file:Mods/7vs1/kit_mutations.SC2Mod",
    "file:Mods/AIRO/AIROAdapter.SC2Mod"
  ]
}
```

### 数据流

```
1. 启动器同步 mod + 地图 + 注入 galaxy + patch MapScript
2. 游戏启动，MapInit 触发器执行
3. gt_Init02Players → 设置联盟和科技
4. gt_Init03Units → 地图预放置单位被分组到变量（单位已存在于地图上）
5. libE0EAE146_gf_Initialize → 加载 Bank，设置 libE0EAE146_gv_commander = "Kerrigan"
6. libE0EAE146_gf_InitializeMapBaseScenario → 在 PlayerStartLocation(1) 创建 Hatchery/Drone/Overlord
7. libAIROAdapter_gf_InitUnitReplacement:
   a. CleanupStartLocationUnits → 扫描起始位置 25 格内玩家 1 单位
      - 发现 CommandCenter → 查映射表 → Kerrigan 替换为 HatcheryKerrigan
      - 但 HatcheryKerrigan 已由步骤 6 创建 → 删除 CommandCenter（避免重复）
      - 发现 SCV → 查映射表 → Kerrigan 替换为 DroneKerrigan → 删除 SCV
      - 发现 Barracks → 查映射表 → Kerrigan 替换为 HatcheryKerrigan
      - 但 Barracks 不在起始位置 25 格内（通常在更远的位置）→ 不清理
   b. 注册 UnitCreated 事件监听器
8. 游戏进行中，gt_RiksvilleTownSquareDropPods 触发
   → 创建 IronWarrior → 触发 UnitCreated 事件
   → 查映射表 → Kerrigan 替换为 HydraliskKerrigan
   → 在 IronWarrior 位置创建 HydraliskKerrigan，删除 IronWarrior
9. gt_P1Rescues 触发
   → 救援玩家 7 的 Marine 给玩家 1 → 触发 UnitCreated 事件
   → 查映射表 → Kerrigan 替换为 ZerglingKerrigan
   → 创建 ZerglingKerrigan，删除 Marine
```

### 错误处理

1. **替换单位无效**: `CatalogEntryIsValid` 检查失败时，保留原版单位，不崩溃
2. **Bank 加载失败**: 如果 `libE0EAE146_gv_commander` 为空，映射函数返回空字符串，所有单位保留原版
3. **重入保护**: 映射表是单向的（原版→指挥官），指挥官单位不会映射回其他单位
4. **性能**: 事件监听器只处理玩家 1 的单位创建，不影响其他玩家

### 边界情况

1. **原版模式（RevolutionOverdrive）**: 不加载 AIROAdapter，不执行任何替换
2. **无映射的指挥官**: 映射函数返回空字符串，所有单位保留原版（等于当前行为）
3. **地图场景物件**: 不在映射表中的单位类型（如 Civilian、CivilianFemale）保留原版
4. **玩家 1 以外的单位**: 事件监听器只监听玩家 1，不影响敌方和盟友单位

## 测试计划

### 单元测试（手动验证）

1. **Kerrigan + traynor01**:
   - 起始位置应只有 Hatchery/Drone/Overlord，无 CommandCenter/SCV
   - 空投小队应为 HydraliskKerrigan，非 IronWarrior
   - 救援小队应为 ZerglingKerrigan，非 Marine

2. **Artanis + traynor01**:
   - 起始位置应只有 Nexus/Probe，无 CommandCenter/SCV
   - 空投小队应为 DragoonArtanis

3. **Raynor + traynor01**:
   - 起始位置应只有 CommandCenterRaynor/SCVRaynor
   - 不应出现原版 CommandCenter/SCV

4. **原版模式（RevolutionOverdrive）**:
   - 不加载 AIROAdapter
   - 所有单位保持原版 Terran

### ScriptError 日志验证

- 无 `BarracksRaynor` 等单位类型无效错误
- 无 `libAIROAdapter` 相关的编译错误
- 无重入循环导致的无限触发错误

## 实施步骤

1. 创建 `Mods/AIRO/AIROAdapter.SC2Mod/` 目录结构
2. 编写 `LibAIROAdapter.galaxy`（映射表 + 清理逻辑 + 事件监听）
3. 创建 mod 的 `modinfo.xml` 和 `GameData.xml`
4. 修改 `launch-airo-campaign.ps1`：
   - 添加 AIROAdapter galaxy 注入步骤
   - 在 MapScript patch 中添加 `libAIROAdapter_gf_InitUnitReplacement()` 调用
5. 修改 `airo-dependencies.json`：添加 AIROAdapter mod 依赖
6. 进图测试 Kerrigan + traynor01
7. 验证混单位消除 + 空投小队替换
8. git commit + push

## 风险与限制

1. **映射表完整性**: 初版只覆盖三个指挥官（Kerrigan/Artanis/Raynor），其他指挥官会保留原版单位
2. **建筑位置冲突**: 清理原版建筑后，指挥官建筑可能不在最优位置（CoreRuntime 在 PlayerStartLocation 创建，原版建筑可能在附近其他位置）
3. **触发器时序**: 如果某些地图触发器在 `gt_Init03Units` 之前创建玩家 1 单位，清理逻辑可能遗漏
4. **单位属性转移**: 替换单位时无法完全保留原版单位的命令队列、生命值、经验值等状态
5. **galaxy 库依赖**: LibAIROAdapter 依赖 LibE0EAE146，必须在 MapScript 中正确 include 和 InitLib
