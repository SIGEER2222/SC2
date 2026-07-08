# 架构重构：三层分离与 CoopZeroPop 废弃

**日期**：2026-07-08
**状态**：设计已确认，待实施
**分支**：fix_003

## 背景与动机

当前 `CoopZeroPop.SC2Mod` 承载了过多职责：PVP 框架、指挥官专属代码、天赋系统、因子系统、英雄复活等混杂在一起。其中 PVP 四主库（LibKPVP/LibKCOR/LibKCUI/LibKMIS）形成闭环依赖集群，且 LibKMIS 反向依赖 Dehaka 指挥官库，架构脆弱。

用户期望：
1. CoopZeroPop 最终不需要再被依赖
2. PVP 框架和 PVP 调度层用不到，应移除
3. 抽出一个最小 core 层，因子、指挥官依赖于它
4. CommanderStartSquads 拆到各指挥官，或放到指挥官与地图之间的衔接层

## 设计决策

| 决策点 | 选择 |
|--------|------|
| core 层范围 | 最小核心（XCoreMod + 基础设施 + 天赋 + 因子） |
| PVP 库处理 | 彻底消除依赖（自有实现替代） |
| 共享功能组织 | StartSquads 拆到各指挥官，SOA+英雄合并为衔接层 |
| 架构方案 | 方案 A：新建 CoreRuntime + CommanderBridge，废弃 CoopZeroPop |

## 三层架构

```
CoreRuntime.SC2Mod (最小核心)
  依赖: VoidMulti + StarCoop (官方)
  内容:
  ├── XCoreMod (Lib67C0F0E7) — 面板/UI 基础
  ├── 基础设施 (自有实现替代 PVP)
  │   ├── MAXPLAYERS 常量
  │   ├── CommanderPlayers() 玩家组
  │   └── PrimaryCommander() Bank 读取
  ├── 天赋系统 (HexTalents/TalentCatalog/TalentSystem)
  ├── 因子系统 (MutatorCatalog/MutatorRuntime)
  └── 主库框架 (LibE0EAE146 聚合入口)
      ├── CommanderRegistry (自动生成)
      ├── ProgressionRewards
      ├── RuntimeSafety
      ├── ExcludeF2
      ├── MapMetadata (自动生成)
      └── GenericBonusCatalog (自动生成)

CommanderBridge.SC2Mod (衔接层)
  依赖: CoreRuntime
  内容:
  ├── SOA Targeting (从 LibE0EAE146 + KMIS 迁移，自有实现)
  └── 英雄复活/建筑 (HeroRevive/HeroStructures)

各 CommanderUnits_*.SC2Mod (依赖 Core + Bridge)
  ├── 各指挥官 Runtime + StartSquads (拆分迁移)
  └── 各指挥官哈希库 (Nova/Swann/Tychus/Stetmann/Stukov/Mengsk/Dehaka)
```

### 依赖规则
- **CoreRuntime** — 只依赖官方 mod，无项目内 mod 依赖
- **CommanderBridge** — 依赖 CoreRuntime
- **CommanderUnits_*** — 依赖 CoreRuntime + CommanderBridge
- **地图** — 依赖 CoreRuntime + Bridge + 所需 CommanderUnits

## CoreRuntime 内部结构

### galaxy 文件清单

```
CoreRuntime.SC2Mod/Base.SC2Data/
├── GameData/                          ← 从 CoopZeroPop 迁移（14 个 XML）
│   ├── GameData.xml                   ← 改造：只保留 Tychus (81FF3B49) 注册
│   └── ...其余 13 个 XML 原样迁移
│
├── LibE0EAE146.galaxy                 ← 主库聚合入口（改造）
├── LibE0EAE146_h.galaxy               ← 头文件（改造：MAXPLAYERS 自有化）
├── Lib67C0F0E7.galaxy + _h            ← XCoreMod（改造：KCUI 面板变量自有声明）
│
├── LibE0EAE146_CommanderRegistry.galaxy   ← 自动生成，原样迁移
├── LibE0EAE146_ProgressionRewards.galaxy  ← 原样迁移
├── LibE0EAE146_RuntimeSafety.galaxy       ← 改造：自有 PrimaryCommander()
├── LibE0EAE146_ExcludeF2.galaxy           ← 改造：移除 Mira include
├── LibE0EAE146_MapMetadata.galaxy         ← 自动生成，原样迁移
├── LibE0EAE146_GenericBonusCatalog.galaxy ← 改造：自有 kerrigan_creep_bonus
│
├── LibE0EAE146_HexTalents.galaxy          ← 天赋系统，原样迁移
├── LibE0EAE146_TalentCatalog.galaxy       ← 自动生成，原样迁移
├── LibE0EAE146_TalentSystem.galaxy        ← 原样迁移
│
├── LibE0EAE146_MutatorCatalog.galaxy      ← 自动生成，原样迁移
├── LibE0EAE146_MutatorRuntime.galaxy      ← 原样迁移
│
├── LibE0EAE146_CoreInfra.galaxy           ← 新建：自有基础设施
│   ├── const int gv_MAXPLAYERS = 15
│   ├── playergroup gv_commanderPlayers
│   ├── gf_CommanderPlayers() → playergroup
│   ├── gf_ActiveCommanderForPlayer(int) → string
│   ├── gf_PrimaryCommander() → string
│   └── gf_CommanderHeroStructureType(string) → string
│
├── LibE0EAE146_MapInitBonus.galaxy        ← 新建：从 jimu 库迁移
│   ├── 触发器：开局 500 矿物/250 气体
│   ├── 触发器：人族兵营解锁
│   └── 触发器：ZeroSupply 补给机制
│
├── LibE0EAE146_KerriganCreepBonus.galaxy  ← 新建：从 LibKPVP 迁移
│   └── gf_apply_kerrigan_creep_bonus(int player)
│
├── LibE0EAE146_IzshaRuntime.galaxy        ← 暂留（无对应 mod）
├── LibE0EAE146_TestZergRuntime.galaxy     ← 暂留（无对应 mod）
│
└── TriggerLibs/                      ← 原样迁移（AI 库）
```

### GameData.xml 改造

```xml
<CGame id="Dflt">
    <TriggerLibs Id="81FF3B49"/>      <!-- Tychus 库，仍需注册 -->
    <UnlimitedPause value="0"/>
</CGame>
```

### XCoreMod 解耦

在 `Lib67C0F0E7_h.galaxy` 声明自有占位变量替代 KCUI 全局变量，初始值为 `c_invalidDialogControlId`，使 `CU_HideLegacyGlobalCastingPanel` 函数变为自动跳过的 noop。

### 主库 include 链改造

移除 8 个指挥官哈希库和 Mira 的 include（由 launch 脚本从各 CommanderUnits mod 注入）。新增 CoreInfra、MapInitBonus、KerriganCreepBonus。Bridge 和各 Runtime 的 include 保留（launch 脚本注入）。

## CommanderBridge 内部结构

```
CommanderBridge.SC2Mod/Base.SC2Data/
├── LibE0EAE146_SOATargeting.galaxy    ← 从 LibE0EAE146.galaxy 行 1876-2210 迁移
│   ├── 8 个触发器函数（ForceOff/Deactivated/PointChosen/DirectionChosen/EffectFired/Cancel/CancelFromUI/ThermalLanceActivated）
│   ├── SOA 全局变量集（从 LibKMIS 迁移，约 30 个）
│   ├── 4 个核心函数（ModeEnter/Exit/Cancel/CleanupActorsAndUnits，从 LibKMIS 迁移）
│   └── 瞄准 UI 函数（从 LibKCUI 迁移：SetCharges/SetInstructionText/TriggeringPlayer/Cancel）
│
├── LibE0EAE146_HeroRevive.galaxy      ← 从 CoopZeroPop 原样迁移
└── LibE0EAE146_HeroStructures.galaxy  ← 改造：使用 CoreInfra 的 gf_CommanderHeroStructureType()
```

## CommanderStartSquads 拆分

`LibE0EAE146_CommanderStartSquads.galaxy` 当前包含：
- 框架部分：`CommanderPanelInit`（调用 lib67C0F0E7 GPInit）
- 各指挥官开局小队：`RaynorCreateMapStartSquad`、`AbathurCreateMapStartSquad` 等

### 拆分方案
- **框架部分**（CommanderPanelInit 等）→ 保留在 CoreRuntime 的一个精简文件中
- **各指挥官 CreateMapStartSquad 函数** → 迁移到各指挥官 Runtime 文件（在对应 CommanderUnits mod 中）

## 指挥官哈希库迁移

8 个哈希库从 CoopZeroPop 迁移到对应 CommanderUnits mod：

| 哈希库 | 指挥官 | 目标 mod |
|--------|--------|----------|
| Lib0940FFB7 + _h | Nova | CommanderUnits_Nova |
| Lib4B62E36B + _h | Swann | CommanderUnits_Swann |
| Lib81FF3B49 + _h | Tychus | CommanderUnits_TychusXM |
| Lib975E2FE9 + _h | Stetmann | CommanderUnits_Stetmann |
| LibBE3BBD9F + _h | Stukov | CommanderUnits_Stukov |
| LibC0F50AA6 + _h | Mengsk | CommanderUnits_Mengsk |
| LibDF8E6945 + _h | Dehaka | CommanderUnits_Dehaka |
| LibKPVP_Swann.galaxy | Swann | CommanderUnits_Swann |

Mira (LibDA886FA0) 为死代码，直接删除。

## 死代码清理

| 文件 | 性质 | 处理 |
|------|------|------|
| LibDA886FA0 + _h (Mira) | 死代码，零调用 | 删除 |
| Lib9D73E10C + _h (中文乱码) | 死代码，零调用 | 删除 |
| LibB7B23F0D + _h (SCV) | 死代码，零调用 | 删除 |
| LibA1BA7A9F (Abathur 存根) | 死代码，零调用 | 删除 |
| Lib45C3A6C3 + _h (jimu) | 3 个活跃触发器 | 逻辑迁移到 MapInitBonus，原文件删除 |
| LibKPVP + _h + Commander + Swann | PVP 库 | 删除（逻辑迁移到 CoreInfra/KerriganCreepBonus） |
| LibKCOR + _h | PVP 库 | 删除 |
| LibKCUI + _h | PVP 库 | 删除（瞄准 UI 迁移到 Bridge） |
| LibKMIS + _h | PVP 库 | 删除（SOA 迁移到 Bridge） |

## PVP 依赖消除清单

~117 处调用，按替代方式分组：

| 替代方式 | 调用数 | 说明 |
|----------|--------|------|
| MAXPLAYERS 常量替换 | 45 | LibE0EAE146_h 中 `libKCOR_gv_cCC_MAXPLAYERS` → `libE0EAE146_gv_MAXPLAYERS` |
| XCoreMod 面板变量声明 | 6 | Lib67C0F0E7 声明自有占位变量 |
| CoreInfra 玩家组函数 | 3 | `libKCOR_gf_CommanderPlayers()` → `libE0EAE146_gf_CommanderPlayers()` |
| CoreInfra 英雄建筑查询 | 1 | `libKCOR_gf_CC_CommanderHeroStructureType` → CoreInfra |
| CoreInfra PrimaryCommander | 1 | `libKPVP_gf_CodexPrimaryCommanderName()` → CoreInfra |
| KerriganCreepBonus 迁移 | 1 | `libKPVP_gf_apply_kerrigan_creep_bonus` → 自有文件 |
| Bridge SOA 全局变量 | 40+ | `libKMIS_gv_cM_SoA*` → Bridge 自有变量 |
| Bridge SOA 函数 | 4 | `libKMIS_gf_CM_SoATargeting*` → Bridge 自有函数 |
| Bridge 瞄准 UI 函数 | 7 | `libKCUI_gf_CU_Targeting*` → Bridge 自有函数 |
| Bridge 触发器引用 | 2 | `libKMIS_gt_CM_HeroDied` → Bridge 自有触发器或移除 |

## launch 脚本改造

`launch-7vs1-coop-test.ps1` 的 `Resolve-ExtensionSource` 当前指向 CoopZeroPop，改为指向 CoreRuntime。

`RuntimeBaseRoots` 自动扫描已包含 CommanderUnits_*，需新增 CommanderBridge 的 Base.SC2Data。

`Get-SplitCatalogModDependencies` 需将 CoopZeroPop 替换为 CoreRuntime + CommanderBridge。

## 测试策略

每个阶段完成后立即游戏内测试：
1. CoreRuntime 建立后测试（单指挥官）
2. Bridge 建立后测试（含 SOA 的指挥官如 Stukov）
3. 哈希库迁移后测试（多指挥官 Default preset）
4. CoopZeroPop 删除后测试（最终验证）

## 实施阶段

1. **阶段 1**：创建 CoreRuntime mod，迁移框架文件 + 新建 CoreInfra/MapInitBonus/KerriganCreepBonus
2. **阶段 2**：解耦 XCoreMod（KCUI 面板变量）+ 主库 MAXPLAYERS 替换
3. **阶段 3**：创建 CommanderBridge mod，迁移 SOA + 英雄复活/建筑
4. **阶段 4**：迁移 8 个指挥官哈希库到对应 CommanderUnits mod
5. **阶段 5**：拆分 CommanderStartSquads
6. **阶段 6**：清理死代码 + 删除 CoopZeroPop
7. **阶段 7**：更新 launch 脚本和依赖配置
8. **阶段 8**：最终测试与提交
