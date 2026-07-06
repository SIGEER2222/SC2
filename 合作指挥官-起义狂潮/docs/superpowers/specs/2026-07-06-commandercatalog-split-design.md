# CommanderCatalog.SC2Mod 按职能水平分层拆分设计

**日期**：2026-07-06
**状态**：已批准，待实施
**目标**：将混杂的 `Mods/7vs1/CommanderCatalog.SC2Mod` 拆分为职责清晰的多个 mod，便于后续扩展。

## 一、现状问题

`CommanderCatalog.SC2Mod` 当前承载约 121 个 XML 文件（3.96 MB）+ 7 个本地化文本文件（220 KB），远超 README 声明的"小型目录补丁"定位。混杂内容：

| 类别 | 文件数 | 性质 |
|------|--------|------|
| Reborn 系列 | 10 | 属于 crys_the_swarm_reborn mod 的数据 |
| HexTalents | 2 | Hex 天赋系统 |
| Stetmann 完整实现 | 24 | 含 Race/Skin/Reward 等完整指挥官数据 |
| TychusXM 完整实现 | 22 | 含 CommanderData/ModData |
| 其他指挥官部分数据 | ~30 | Abathur/Kerrigan/Nova/Raynor/RaynorX/Horner + 11 个单 UnitData 文件 |
| Shared 共享单位 | 10 | 跨指挥官共享 |
| 通用无后缀文件 | 10 | Raynor 基础补丁（SCVRaynor/UpgradeToOrbitalRaynor），未在 GameData.xml 引用 |

**关键发现**：
- `.SC2Mod` 包会自动加载 `GameData/` 目录下所有 XML，GameData.xml 的显式引用列表（48 个）不完整，但不影响加载。
- `crys_the_swarm_reborn` mod 不在本地，Reborn 数据无法回迁。
- `CoopZeroPop.SC2Mod` 是运行时大本营（含 `LibE0EAE146.galaxy` 主库 + 各指挥官 Runtime + HexTalents 运行时），与 CommanderCatalog 是"运行时 vs 目录数据"的分工。

## 二、拆分结构

6 个新 mod，均放在 `Mods/7vs1/`：

### 2.1 BaseCatalogPatch.SC2Mod
- **职责**：通用基础补丁
- **内容**：10 个无后缀文件
  - `AbilData.xml`（UpgradeToOrbitalRaynor、TerranBuildRaynor 等）
  - `ActorData.xml`（SCVRaynor、SCVSwann、ArtanisReviveBeacon 等）
  - `BehaviorData.xml`、`ButtonData.xml`、`EffectData.xml`、`MoverData.xml`
  - `RequirementData.xml`、`RequirementNodeData.xml`
  - `UnitData.xml`（Adept、Armory 等基础单位补丁）
  - `UpgradeData.xml`
- **依赖**：`VoidMulti + StarCoop`

### 2.2 CommanderUnits.SC2Mod
- **职责**：轻量指挥官单位数据
- **内容**（约 41 文件）：
  - 多文件指挥官：Abathur(7)、Kerrigan(7)、Nova(7)、Raynor(2)、RaynorX(5)、Horner(2)
  - 单 UnitData 文件指挥官：Alarak、Artanis、Dehaka、Fenix、Karax、Mengsk、Stukov、Swann、Vorazun、Zagara、Zeratul（11）
- **依赖**：`VoidMulti + StarCoop + BaseCatalogPatch`

### 2.3 CommanderUnits_Stetmann.SC2Mod
- **职责**：Stetmann 完整实现
- **内容**（24 文件）：`*Data_Stetmann.xml`
  - Abil/Actor/AttachMethod/Behavior/Button/DataCollection/Effect/Footprint/Model/Mover/PlayerResponse/Race/Requirement/RequirementNode/Reward/Skin/Sound/TargetSort/Turret/Unit/Upgrade/UserData/Validator/Weapon
- **依赖**：`VoidMulti + StarCoop + BaseCatalogPatch`

### 2.4 CommanderUnits_TychusXM.SC2Mod
- **职责**：TychusXM 完整实现
- **内容**（22 文件）：`*Data_TychusXM.xml`
  - Abil/Accumulator/Actor/AttachMethod/Behavior/Button/CommanderData/Effect/GameData/Model/ModData/Mover/Requirement/RequirementNode/Skin/Sound/TargetSort/Turret/Unit/Upgrade/UserData/Validator/Weapon
- **依赖**：`VoidMulti + StarCoop + BaseCatalogPatch`
- **注意**：`GameData_TychusXM.xml` 里的 `<TriggerLibs Id="81FF3B49"/>` 迁移到 CoopZeroPop 的 GameData.xml（galaxy 库 `Lib81FF3B49.galaxy` 在 CoopZeroPop）。`ModData_TychusXM.xml` 为空 `<Catalog/>`，随 TychusXM mod 保留。

### 2.5 SharedUnits.SC2Mod
- **职责**：跨指挥官共享单位
- **内容**（10 文件）：`UnitData_Shared_*.xml`
  - InfestedTerran、Neutral_H、Neutral_I_M、Neutral_N_Z、Protoss、PurifierZerg、Terran_A_G、Terran_H、Terran_I_V、Zerg
- **依赖**：`VoidMulti + StarCoop`

### 2.6 ExternalRefs.SC2Mod
- **职责**：外部扩展数据
- **内容**（12 文件）：
  - Reborn 系列(10)：Actor/Behavior/Button/Effect/Model/Requirement/RequirementNode/Unit/Upgrade/Weapon `_Reborn.xml`
  - HexTalents(2)：Behavior/Upgrade `_HexTalents.xml`
- **依赖**：`VoidMulti + StarCoop`

## 三、依赖关系图

```
BaseCatalogPatch          → VoidMulti + StarCoop
CommanderUnits            → VoidMulti + StarCoop + BaseCatalogPatch
CommanderUnits_Stetmann   → VoidMulti + StarCoop + BaseCatalogPatch
CommanderUnits_TychusXM   → VoidMulti + StarCoop + BaseCatalogPatch
SharedUnits               → VoidMulti + StarCoop
ExternalRefs              → VoidMulti + StarCoop
```

各 mod 平级，靠引擎自动合并 GameData 目录 XML。BaseCatalogPatch 作为基础补丁被指挥官 mod 引用，确保 SCVRaynor 等基础单位先定义。

## 四、同步修改 launch-7vs1-coop-test.ps1

| 位置 | 当前逻辑 | 拆分后 |
|------|----------|--------|
| `Resolve-CommanderCatalogSource`（L110-113） | 返回单个 mod 路径 | 改为返回 6 个新 mod 路径数组 |
| 地图依赖添加（L1227） | `Add-DependencyUnique ... CommanderCatalog.SC2Mod` | 替换为 6 个新 mod 依赖 |
| `Validate-LiveBaseTestlineInstall`（L1007-1009） | 校验 CommanderCatalog 依赖存在 | 改为校验 6 个新 mod 依赖存在 |
| `Merge-LiveCommanderCatalogUnitData` 调用（L1268） | 单目录合并 UnitData*.xml | 改为多目录扫描合并，聚合产物写入 BaseCatalogPatch |

### Merge-LiveCommanderCatalogUnitData 改造细节

当前函数（L227-320）：
- 读取 CommanderCatalog 的 `UnitData.xml` 作为基础
- 扫描同目录所有 `UnitData*.xml`，按 id 合并/替换到基础
- 移除 Stetmann prestige lock buttons
- 写回 `UnitData.xml`

改造后：
- 接收多个 mod 的 GameData 目录路径数组
- 按顺序扫描每个目录的 `UnitData*.xml`
- 合并到 BaseCatalogPatch 的 `UnitData.xml`（作为聚合目标）
- 保留 Stetmann prestige lock 移除逻辑

## 五、本地化文本拆分

CommanderCatalog 的 `enUS.SC2Data/LocalizedData/` 和 `zhCN.SC2Data/LocalizedData/` 下有 4 个文件各约 220KB：
- `GameStrings.txt`、`ObjectStrings.txt`、`GameHotkeys.txt`、`TriggerStrings.txt`

**拆分策略**：
- 按 key 前缀/内容判断归属，拆分到各 mod 的对应本地化文件
- 无法判断归属的 key 暂留 BaseCatalogPatch
- 拆分后全量 grep 校验 key 覆盖率

## 六、新 mod 基础设施文件

每个新 mod 需要：
- `DocumentInfo`：XML，声明依赖
- `DocumentHeader`：二进制，含依赖信息。从 CommanderCatalog 复制后用 `Set-DocumentHeaderDependencies` 改写
- `ComponentList.SC2Components`：声明组件
- `GameData.version`、`GameText.version`、`DocumentInfo.version`：版本文件
- `Base.SC2Data/GameData/GameData.xml`：可为空 `<Catalog/>` 或仅声明 TriggerLibs

## 七、原 CommanderCatalog.SC2Mod 处理

拆分完成并测试通过后**删除原 mod**。不保留空壳，避免歧义。

## 八、风险与缓解

| 风险 | 缓解 |
|------|------|
| Merge-LiveCommanderCatalogUnitData 改造错误导致单位合并异常 | 改造后对比合并产物与拆分前的 UnitData.xml 差异 |
| 本地化 key 拆分遗漏导致文字缺失 | 拆分后全量 grep 校验 key 覆盖 |
| TriggerLibs 注册迁移后 galaxy 库加载失败 | 先在 CoopZeroPop 添加注册，测试通过后再从 TychusXM mod 移除 |
| DocumentHeader 二进制改写错误 | 使用启动脚本已有的 `Set-DocumentHeaderDependencies` 函数 |

## 九、测试策略

拆分完成后运行 `launch-7vs1-coop-test.ps1`，验证：
1. 地图加载无 ScriptError，游戏进程存活 >120s
2. SCVRaynor 建造面板完整（Barracks/Factory/Starport 等）
3. Stetmann 技能按钮正常（PowerTowerOvercharge 等）
4. TychusXM 单位可生产
5. Reborn 单位（如 Brutalisk）可生成
6. HexTalents 升级可研究

## 十、实施顺序

1. 创建 6 个新 mod 目录结构 + 基础设施文件
2. 按 2.1-2.6 分类移动 XML 文件
3. 迁移 TriggerLibs 注册到 CoopZeroPop
4. 拆分本地化文本
5. 改造 `launch-7vs1-coop-test.ps1`（4 处修改）
6. 删除原 CommanderCatalog.SC2Mod
7. 运行 7vs1 测试链验证
8. git commit + push
