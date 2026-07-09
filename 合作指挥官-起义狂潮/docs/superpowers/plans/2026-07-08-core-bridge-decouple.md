# 三层分离与 CoopZeroPop 废弃 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 CoopZeroPop.SC2Mod 拆分为 CoreRuntime + CommanderBridge 三层架构，彻底移除 PVP 四主库依赖，清理死代码。

**Architecture:** 新建 CoreRuntime.SC2Mod（最小核心：XCoreMod + 基础设施 + 天赋 + 因子）和 CommanderBridge.SC2Mod（衔接层：SOA Targeting + 英雄复活/建筑），废弃并删除 CoopZeroPop.SC2Mod。各指挥官哈希库迁移到对应 CommanderUnits mod。

**Tech Stack:** SC2 galaxy 脚本、PowerShell 启动脚本、file-ops 包装脚本

**设计文档**：`docs/superpowers/specs/2026-07-08-core-bridge-decouple-design.md`

**硬约束**：
- 文件操作必须用 `c:\Users\22448\.trae-cn\skills\file-ops\scripts\trae-*.ps1` 包装脚本
- git add 必须用 `trae-add.ps1`，禁止 `git add .`
- 每个阶段结束后必须游戏内测试（launch-7vs1-coop-test.ps1 + wait-for-game-ready.ps1）
- commit 消息用中文
- 测试通过后才能进入下一阶段

**测试方法**：
```powershell
# 启动测试（单指挥官或 preset）
powershell -NoProfile -ExecutionPolicy Bypass -File "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\launch-7vs1-coop-test.ps1" -Commanders @("ZergAbathur") -ForceStopSc2BeforeInstall
# 等待结果（exit 0 = 成功）
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\wait-for-game-ready.ps1"
```

**工作区根目录**：`e:\Code\MyMod\SC2\合作指挥官-起义狂潮`
**Mod 根目录**：`e:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods\7vs1`

---

## Task 1: 创建 CoreRuntime mod 骨架

**Files:**
- Create: `Mods/7vs1/CoreRuntime.SC2Mod/DocumentInfo`
- Create: `Mods/7vs1/CoreRuntime.SC2Mod/Base.SC2Data/GameData/GameData.xml`

- [x] **Step 1: 创建 DocumentInfo**

创建 `Mods/7vs1/CoreRuntime.SC2Mod/DocumentInfo`，依赖官方 mod：
```xml
<?xml version="1.0" encoding="utf-8"?>
<DocInfo>
    <Flags>
        <Value>ExtensionMod</Value>
    </Flags>
    <Dependencies>
        <Value>bnet:Void Multi (Mod)/0.0/999,file:Mods/VoidMulti.SC2Mod</Value>
        <Value>bnet:Co-op Mission/0.0/999,file:Mods/StarCoop/StarCoop.SC2Mod</Value>
    </Dependencies>
    <HowToPlayBasic>
        <ListType>
            <Value>Plain</Value>
        </ListType>
    </HowToPlayBasic>
    <HowToPlayAdvanced>
        <ListType>
            <Value>Plain</Value>
        </ListType>
    </HowToPlayAdvanced>
</DocInfo>
```

- [x] **Step 2: 创建 GameData.xml（精简版，只注册 Tychus）**

创建 `Mods/7vs1/CoreRuntime.SC2Mod/Base.SC2Data/GameData/GameData.xml`：
```xml
<?xml version="1.0" encoding="utf-8"?>
<Catalog>
    <CGame id="Dflt">
        <TriggerLibs Id="81FF3B49"/>
        <UnlimitedPause value="0"/>
    </CGame>
</Catalog>
```

- [x] **Step 3: Commit**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "c:\Users\22448\.trae-cn\skills\file-ops\scripts\trae-add.ps1" "合作指挥官-起义狂潮/Mods/7vs1/CoreRuntime.SC2Mod/DocumentInfo" "合作指挥官-起义狂潮/Mods/7vs1/CoreRuntime.SC2Mod/Base.SC2Data/GameData/GameData.xml"
git commit -m "创建 CoreRuntime mod 骨架"
```

---

## Task 2: 迁移框架 galaxy 文件到 CoreRuntime

将 CoopZeroPop 中的框架/共享 galaxy 文件复制到 CoreRuntime。此阶段只做物理复制，不做内容改造（改造在后续 Task）。

**Files:**
- Copy: CoopZeroPop → CoreRuntime 的 17 个 galaxy 文件 + TriggerLibs 目录 + 13 个 XML 文件

- [x] **Step 1: 复制 XML 数据文件（13 个，排除 GameData.xml）**

用 trae-cp.ps1 将以下文件从 CoopZeroPop 复制到 CoreRuntime：
AbilData.xml, ActorData.xml, BehaviorData.xml, ButtonData.xml, EffectData.xml, GameUIData.xml, RequirementData.xml, RequirementNodeData.xml, UnitData.xml, UpgradeData.xml, UserData.xml, ValidatorData.xml, WeaponData.xml

- [x] **Step 2: 复制 XCoreMod（Lib67C0F0E7 + _h）**

- [x] **Step 3: 复制框架 galaxy 文件（11 个）**

LibE0EAE146.galaxy, LibE0EAE146_h.galaxy, LibE0EAE146_CommanderRegistry.galaxy, LibE0EAE146_ProgressionRewards.galaxy, LibE0EAE146_RuntimeSafety.galaxy, LibE0EAE146_ExcludeF2.galaxy, LibE0EAE146_MapMetadata.galaxy, LibE0EAE146_GenericBonusCatalog.galaxy, LibE0EAE146_IzshaRuntime.galaxy, LibE0EAE146_TestZergRuntime.galaxy, LibE0EAE146_CommanderStartSquads.galaxy

- [x] **Step 4: 复制天赋系统（3 个）**

LibE0EAE146_HexTalents.galaxy, LibE0EAE146_TalentCatalog.galaxy, LibE0EAE146_TalentSystem.galaxy

- [x] **Step 5: 复制因子系统（2 个）**

LibE0EAE146_MutatorCatalog.galaxy, LibE0EAE146_MutatorRuntime.galaxy

- [x] **Step 6: 复制英雄复活/建筑（2 个，后续移到 Bridge）**

LibE0EAE146_HeroRevive.galaxy, LibE0EAE146_HeroStructures.galaxy

- [x] **Step 7: 复制 Tychus 哈希库（Lib81FF3B49 + _h）**

- [x] **Step 8: 复制 TriggerLibs 目录（AI 库）**

- [x] **Step 9: Commit**

```powershell
# 批量 trae-add（列出所有新文件）
git commit -m "迁移框架 galaxy 文件到 CoreRuntime（物理复制，未改造）"
```

---

## Task 3: 新建 CoreInfra/MapInitBonus/KerriganCreepBonus

创建 3 个新的 galaxy 文件，提供 PVP 库的自有替代实现。

**Files:**
- Create: `Mods/7vs1/CoreRuntime.SC2Mod/Base.SC2Data/LibE0EAE146_CoreInfra.galaxy`
- Create: `Mods/7vs1/CoreRuntime.SC2Mod/Base.SC2Data/LibE0EAE146_MapInitBonus.galaxy`
- Create: `Mods/7vs1/CoreRuntime.SC2Mod/Base.SC2Data/LibE0EAE146_KerriganCreepBonus.galaxy`

- [x] **Step 1: 创建 LibE0EAE146_CoreInfra.galaxy**

提供 MAXPLAYERS 常量、CommanderPlayers() 玩家组、PrimaryCommander() Bank 读取、CommanderHeroStructureType() 查询。内容从 LibKCOR 和 LibKPVP 中提取相关函数体。

- [x] **Step 2: 创建 LibE0EAE146_MapInitBonus.galaxy**

从 Lib45C3A6C3 (jimu) 迁移 3 个触发器：开局资源、兵营解锁、ZeroSupply 补给。

- [x] **Step 3: 创建 LibE0EAE146_KerriganCreepBonus.galaxy**

从 LibKPVP 迁移 `gf_apply_kerrigan_creep_bonus` 函数（约 50 行）。

- [x] **Step 4: Commit**

---

## Task 4: 解耦 XCoreMod 和主库的 PVP 依赖

改造 CoreRuntime 中的文件，替换所有 PVP 库调用。

**Files:**
- Modify: `CoreRuntime/Base.SC2Data/Lib67C0F0E7_h.galaxy` — 声明 KCUI 面板占位变量
- Modify: `CoreRuntime/Base.SC2Data/Lib67C0F0E7.galaxy` — 替换 libKCUI_ 调用
- Modify: `CoreRuntime/Base.SC2Data/LibE0EAE146_h.galaxy` — 替换 libKCOR_gv_cCC_MAXPLAYERS
- Modify: `CoreRuntime/Base.SC2Data/LibE0EAE146.galaxy` — include 改造 + 替换 PVP 调用
- Modify: `CoreRuntime/Base.SC2Data/LibE0EAE146_RuntimeSafety.galaxy` — 替换 libKPVP_ 调用
- Modify: `CoreRuntime/Base.SC2Data/LibE0EAE146_GenericBonusCatalog.galaxy` — 替换 libKPVP_ 调用
- Modify: `CoreRuntime/Base.SC2Data/LibE0EAE146_HeroStructures.galaxy` — 替换 libKCOR_ 调用
- Modify: `CoreRuntime/Base.SC2Data/LibE0EAE146_ExcludeF2.galaxy` — 移除 Mira include
- Modify: `CoreRuntime/Base.SC2Data/LibE0EAE146_CommanderStartSquads.galaxy` — 替换 libKMIS_ 调用

- [x] **Step 1: Lib67C0F0E7_h.galaxy 声明 KCUI 面板占位变量**

添加 3 个全局变量数组，初始化为 c_invalidDialogControlId。

- [x] **Step 2: Lib67C0F0E7.galaxy 替换 libKCUI_ 调用**

6 处 `libKCUI_gv_cU_*` 替换为 `lib67C0F0E7_gv_legacy*`。

- [x] **Step 3: LibE0EAE146_h.galaxy 替换 MAXPLAYERS**

约 45 处 `libKCOR_gv_cCC_MAXPLAYERS` 替换为 `libE0EAE146_gv_MAXPLAYERS`。

- [x] **Step 4: LibE0EAE146.galaxy include 链改造**

移除 8 个哈希库 + Mira 的 include。新增 CoreInfra、MapInitBonus、KerriganCreepBonus 的 include。移除 SOA Targeting 相关代码段（行 1876-2210，移到 Bridge）。

- [x] **Step 5: RuntimeSafety 替换 libKPVP_ 调用**

`libKPVP_gf_CodexPrimaryCommanderName()` → `libE0EAE146_gf_PrimaryCommander()`。

- [x] **Step 6: GenericBonusCatalog 替换 libKPVP_ 调用**

`libKPVP_gf_apply_kerrigan_creep_bonus()` → `libE0EAE146_gf_apply_kerrigan_creep_bonus()`。

- [x] **Step 7: HeroStructures 替换 libKCOR_ 调用**

`libKCOR_gf_CC_CommanderHeroStructureType(libKCOR_gf_ActiveCommanderForPlayer(...))` → `libE0EAE146_gf_CommanderHeroStructureType(libE0EAE146_gf_ActiveCommanderForPlayer(...))`。

- [x] **Step 8: ExcludeF2 移除 Mira include**

删除 `include "LibDA886FA0"` 行。

- [x] **Step 9: CommanderStartSquads 替换 libKMIS_ 调用**

`TriggerEnable(libKMIS_gt_CM_HeroDied, false)` → 使用自有触发器或移除。

- [x] **Step 10: Commit**

---

## Task 5: 创建 CommanderBridge mod

> 已由远端提交 149976ce「创建 CommanderBridge mod 并迁移 SOA Targeting 代码」完成；本地在其基础上补齐了 Bridge 与 CoreRuntime 主库的 include/Init 接线及残留 PVP 前缀替换（见文末补充说明）。

**Files:**
- Create: `Mods/7vs1/CommanderBridge.SC2Mod/DocumentInfo`
- Create: `Mods/7vs1/CommanderBridge.SC2Mod/Base.SC2Data/LibE0EAE146_SOATargeting.galaxy`
- Create: `Mods/7vs1/CommanderBridge.SC2Mod/Base.SC2Data/LibE0EAE146_HeroRevive.galaxy`
- Create: `Mods/7vs1/CommanderBridge.SC2Mod/Base.SC2Data/LibE0EAE146_HeroStructures.galaxy`

- [x] **Step 1: 创建 DocumentInfo**（依赖 CoreRuntime）

- [x] **Step 2: 创建 SOATargeting.galaxy**

从 LibE0EAE146.galaxy 行 1876-2210 迁移 8 个触发器函数。从 LibKMIS 迁移 SOA 全局变量集（约 30 个）和 4 个核心函数。从 LibKCUI 迁移 4 个瞄准 UI 函数。所有 `libKMIS_`/`libKCOR_`/`libKCUI_` 前缀替换为 `libE0EAE146_`。

- [x] **Step 3: 迁移 HeroRevive.galaxy**

从 CoreRuntime 复制（Task 2 已复制到 CoreRuntime，现移到 Bridge）。

- [x] **Step 4: 迁移 HeroStructures.galaxy**

从 CoreRuntime 移到 Bridge（改造后的版本）。

- [x] **Step 5: 从 CoreRuntime 删除 HeroRevive/HeroStructures**（已移到 Bridge）

- [x] **Step 6: Commit**

---

## Task 6: 迁移指挥官哈希库到各 CommanderUnits mod

将 7 个哈希库（Mira 已确认死代码，直接删除不迁移）从 CoopZeroPop 迁移到对应 CommanderUnits mod。Swann 的 LibKPVP_Swann 也一并迁移。

**Files:**
- Move: Lib0940FFB7 + _h → CommanderUnits_Nova
- Move: Lib4B62E36B + _h → CommanderUnits_Swann
- Move: LibKPVP_Swann.galaxy → CommanderUnits_Swann（改造：移除 LibKPVP_h 依赖）
- Move: Lib975E2FE9 + _h → CommanderUnits_Stetmann
- Move: LibBE3BBD9F + _h → CommanderUnits_Stukov
- Move: LibC0F50AA6 + _h → CommanderUnits_Mengsk
- Move: LibDF8E6945 + _h → CommanderUnits_Dehaka

注意：Tychus (Lib81FF3B49) 已在 Task 2 复制到 CoreRuntime（因 GameData.xml 注册需保留在 Core）。

- [x] **Step 1-7: 逐个迁移哈希库**

用 trae-mv.ps1 移动每个库文件。

- [x] **Step 8: 改造 LibKPVP_Swann 移除 LibKPVP_h 依赖**

- [x] **Step 9: Commit**

---

## Task 7: 拆分 CommanderStartSquads

将 `LibE0EAE146_CommanderStartSquads.galaxy` 的各指挥官 CreateMapStartSquad 函数迁移到各指挥官 Runtime 文件。框架部分（CommanderPanelInit）保留在 CoreRuntime。

**Files:**
- Modify: `CoreRuntime/Base.SC2Data/LibE0EAE146_CommanderStartSquads.galaxy` — 只保留框架
- Modify: 各 `CommanderUnits_*/Base.SC2Data/LibE0EAE146_*Runtime.galaxy` — 添加对应 CreateMapStartSquad

- [x] **Step 1: 分析 CommanderStartSquads 的函数边界**

Grep 搜索所有 `gf_.*CreateMapStartSquad` 函数定义，确认每个属于哪个指挥官。

- [x] **Step 2-N: 逐指挥官迁移 CreateMapStartSquad 函数**

- [x] **Step N+1: Commit**

---

## Task 8: 更新 launch 脚本

**Files:**
- Modify: `scripts/launch-7vs1-coop-test.ps1`

- [x] **Step 1: Resolve-ExtensionSource 改为 CoreRuntime**

将 `CoopZeroPop.SC2Mod` 替换为 `CoreRuntime.SC2Mod`。

- [x] **Step 2: Get-SplitCatalogModDependencies 替换 CoopZeroPop**

将 `file:Mods/7vs1/CoopZeroPop.SC2Mod` 替换为 `file:Mods/7vs1/CoreRuntime.SC2Mod` 和 `file:Mods/7vs1/CommanderBridge.SC2Mod`。

- [x] **Step 3: RuntimeBaseRoots 添加 CommanderBridge**

在自动扫描 CommanderUnits_* 的基础上，添加 CommanderBridge 的 Base.SC2Data。

- [x] **Step 4: workspaceDependencySkips 更新**

将 `file:Mods/7vs1/CoopZeroPop.SC2Mod` 替换为 `file:Mods/7vs1/CoreRuntime.SC2Mod`。

- [x] **Step 5: Commit**

---

## Task 9: 清理死代码 + 删除 CoopZeroPop

**Files:**
- Delete: `Mods/7vs1/CoopZeroPop.SC2Mod/`（整个目录）
- Delete: CoreRuntime 中的 PVP 库文件（LibKPVP*, LibKCOR*, LibKCUI*, LibKMIS*）
- Delete: CoreRuntime 中的死代码（LibDA886FA0*, Lib9D73E10C*, LibB7B23F0D*, LibA1BA7A9F, Lib45C3A6C3*）

注意：此 Task 必须在 Task 1-8 全部完成并测试通过后执行。

- [ ] **Step 1: 删除 CoreRuntime 中的 PVP 库文件**

LibKPVP.galaxy, LibKPVP_h.galaxy, LibKPVP_Commander.galaxy, LibKPVP_Swann.galaxy（如未被 Task 6 迁移）, LibKCOR.galaxy, LibKCOR_h.galaxy, LibKCUI.galaxy, LibKCUI_h.galaxy, LibKMIS.galaxy, LibKMIS_h.galaxy

- [ ] **Step 2: 删除 CoreRuntime 中的死代码**

LibDA886FA0.galaxy, LibDA886FA0_h.galaxy, Lib9D73E10C.galaxy, Lib9D73E10C_h.galaxy, LibB7B23F0D.galaxy, LibB7B23F0D_h.galaxy, LibA1BA7A9F.galaxy, Lib45C3A6C3.galaxy, Lib45C3A6C3_h.galaxy

- [ ] **Step 3: 删除 CoopZeroPop.SC2Mod 整个目录**

用 trae-rmdir.ps1 删除。

- [ ] **Step 4: 清理 CoreRuntime GameData.xml 中已移除的 TriggerLibs 注册**

确认 GameData.xml 只保留 `<TriggerLibs Id="81FF3B49"/>`。

- [ ] **Step 5: Commit**

---

## Task 10: 最终测试与提交

- [ ] **Step 1: 单指挥官测试（ZergAbathur）**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\launch-7vs1-coop-test.ps1" -Commanders @("ZergAbathur") -ForceStopSc2BeforeInstall
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\wait-for-game-ready.ps1"
```
Expected: exit 0，Alerts.txt 出现，无致命 ScriptError

- [ ] **Step 2: 多指挥官测试（Default preset）**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\launch-7vs1-coop-test.ps1" -Preset "Default" -ForceStopSc2BeforeInstall
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\wait-for-game-ready.ps1"
```
Expected: exit 0，Alerts.txt 出现，无致命 ScriptError

- [ ] **Step 3: Stukov 测试（验证 SOA Targeting）**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\launch-7vs1-coop-test.ps1" -Commanders @("ZergStukov") -ForceStopSc2BeforeInstall
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\wait-for-game-ready.ps1"
```

- [ ] **Step 4: git pull + commit + push**

---

## 注意事项

1. **galaxy 编译限制**：galaxy 文件接近解析限制时应拆分，不要无限添加
2. **include 解析**：galaxy include 在地图编译时从同一目录解析，launch 脚本负责将各 mod 的 galaxy 文件复制到地图 Base.SC2Data
3. **测试时机**：Task 4（解耦）和 Task 9（删除 CoopZeroPop）是高风险点，必须充分测试
4. **回滚策略**：每个 Task 都有独立 commit，如发现问题可 git revert 回滚
5. **PVP 函数迁移**：从 PVP 库迁移函数时，必须完整复制函数体，不能只复制声明

## 执行环境补充说明（2026-07-08）

- **Task 9（清理死代码 + 删除 CoopZeroPop）与 Task 10（游戏内测试）未执行**：本机没有安装 StarCraft II，无法运行 launch-7vs1-coop-test.ps1 / wait-for-game-ready.ps1 做游戏内验证；按计划要求「Task 9 必须在 Task 1-8 全部完成并测试通过后执行」，这两个 Task 留待有游戏环境的机器完成。CoopZeroPop.SC2Mod 目录保持原样未动。
- Task 1-5 由远端提交完成（Task 5 为远端提交 149976ce）；Task 6-8 在本机以文件操作完成，并用 scripts/galaxy-checker 做静态检查替代游戏内测试（改动文件无新增 error 级 issue，仅存在与 CoopZeroPop 原代码一致的历史告警）。
