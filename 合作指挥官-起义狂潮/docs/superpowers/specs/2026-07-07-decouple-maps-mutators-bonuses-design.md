# 地图/因子/加成与指挥官解耦设计

**日期**：2026-07-07
**状态**：已批准，待实施
**目标**：将地图依赖、因子、加成三个系统与指挥官硬编码解耦，改为 JSON 配置驱动，方便后续扩展新指挥官。延续子系统 A（天赋系统）的 JSON→生成器→galaxy 架构模式。

## 一、现状问题（7 个耦合点）

| 编号 | 耦合点 | 现状位置 | 影响 |
|---|---|---|---|
| 1 | 指挥官 if-else 链（控制台皮肤） | `LibE0EAE146.galaxy` 行 193-268 `Initialize` | 新增指挥官必须改 galaxy |
| 2 | 指挥官 if-else 链（RuntimeInit） | `LibE0EAE146.galaxy` 行 1697-1769 `InitializeBase` | 新增指挥官必须改 galaxy |
| 3 | 加成硬编码指挥官 power | `LibE0EAE146.galaxy` 行 1310-1343 `GenericBonusApplyPassives` | 加成与指挥官强耦合 |
| 4 | 地图 ID 硬编码资源表 | `LibE0EAE146.galaxy` 行 304-365 | 新增地图必须改 galaxy |
| 5 | 因子 ID 双份维护 | galaxy 69 个 + PowerShell 69 个白名单 | 易漂移 |
| 6 | 加成 ID 双份维护 | galaxy 11 个 + webui 12 个 | 易漂移 |
| 7 | 地图特殊标志硬编码 | `LibE0EAE146.galaxy` 行 367-373、450-458 | 新增地图必须改 galaxy |

## 二、方案选择

**采用 JSON 配置 + 生成器方案**（与天赋系统架构一致）：
- JSON 单一数据源 → PowerShell 生成器 → galaxy 分发代码
- 优点：与天赋系统架构一致；新增内容只改 JSON；galaxy 无硬编码
- 缺点：需写生成器；改 galaxy 运行时分发逻辑

## 三、设计详情

### 3.1 指挥官注册表（解决耦合点 1、2）

**配置** `Shared/Commanders/<Commander>.json`（19 个文件）：
```json
{
  "runtime_name": "TerranRaynor",
  "display_name": "雷诺",
  "race": "Terran",
  "console_skin": "ConsoleTerran_Default",
  "runtime_init": "RaynorRuntimeInit",
  "special_init": [],
  "supply_bonus": 0
}
```

**字段说明**：
- `runtime_name`：运行时指挥官名（Bank 通信用）
- `console_skin`：控制台皮肤 ID
- `runtime_init`：RuntimeInit 函数名（生成器映射到 `gf_RaynorRuntimeInit` 调用）
- `special_init`：特殊初始化逻辑数组，每项 `{type, args}`，支持的 type：
  - `create_caster_unit`：创建指挥官施法单位（Tychus 的 CoopCasterTychus）
  - `init_veterancy`：初始化老兵系统（Mengsk）
  - `init_squad`：初始化小队系统（Tychus 的 TychusSquadInitTrigger）
  - `add_supply`：加人口上限（Dehaka +60）
- `supply_bonus`：初始人口加成（Dehaka=60，其他=0）

**特殊指挥官处理**：
- Abathur/AbathurCustom 共用 `AbathurRuntimeInit`，配置文件各自独立
- AbathurReborn 用 `AbathurRebornRuntimeInit`
- Mira/Horner/HanHorner/HanAndHorner 共用 `HornerRuntimeInit`，JSON 用 `aliases` 字段
- TestZerg 用 `TestZergRuntimeInit`
- Raynor 别名 `TerranRaynor`（galaxy 内部两种写法都存在）

**生成器** `scripts/build-commander-registry.ps1`：
- 读取 `Shared/Commanders/*.json`
- 生成 `LibE0EAE146_CommanderRegistry.galaxy`：
  - `gf_CommanderConsoleSkin(string cmdr)` → 返回皮肤字符串
  - `gf_CommanderRuntimeInit(int player, string cmdr)` → dispatcher
  - `gf_CommanderApplySpecialInit(int player, string cmdr, bool rpg)` → 应用 special_init
- 生成 `Shared/Commanders/_registry.json`（供 web-launcher 读取）

**galaxy 改造**：
- `LibE0EAE146.galaxy` `Initialize` 行 193-268：18 个 if-else 分支 → `gf_CommanderConsoleSkin(gv_commander)` + `gf_CommanderApplySpecialInit(1, gv_commander, lp_rpg)`
- `InitializeBase` 行 1697-1769：22 个 if-else 分支 → `gf_CommanderRuntimeInit(lp_player, gv_commander)`

### 3.2 加成效果独立化（解决耦合点 3、6）

**配置** `Shared/GenericBonuses.json`（单一文件）：
```json
{
  "bonuses": [
    {
      "id": "GuardianShell",
      "name": "守护者之壳",
      "type": "toggle",
      "upgrades": ["SOAHeroicShield"]
    },
    {
      "id": "CreepRegeneration",
      "name": "菌毯回血",
      "type": "toggle",
      "upgrades": ["K5CreepBonuses", "KerriganCreepBonusesCoop"],
      "extra_calls": ["libKPVP_gf_apply_kerrigan_creep_bonus"]
    },
    {
      "id": "ChronoBoost",
      "name": "时空加速",
      "type": "toggle",
      "upgrades": ["SOAMapWideChrono", "KaraxSOAChronoPassive", "SOAMapWideChronoUpgrade"]
    },
    {
      "id": "MechanicalRepair",
      "name": "机械维修",
      "type": "toggle",
      "upgrades": ["SOARepairBeam"]
    },
    {
      "id": "AbathurBiomassDrop",
      "name": "生物质掉落",
      "type": "toggle",
      "extra_calls": ["EnableAbathurBiomassForGenericBonus"]
    },
    {
      "id": "DoubleMinerals",
      "name": "矿物倍率",
      "type": "level",
      "max_level": 9
    },
    {
      "id": "DoubleVespene",
      "name": "瓦斯倍率",
      "type": "level",
      "max_level": 9
    },
    {
      "id": "RichResources",
      "name": "高产矿脉",
      "type": "toggle"
    },
    {
      "id": "AllyEarlyDamageReduction",
      "name": "盟友开局减伤",
      "type": "toggle"
    },
    {
      "id": "AllySustainBoost",
      "name": "盟友持续强化",
      "type": "toggle"
    },
    {
      "id": "MaxSupply50",
      "name": "人口上限+50",
      "type": "toggle"
    }
  ]
}
```

**设计原则**：
- 加成定义里**只写 upgrade/behavior ID 和函数调用，不写"这是某指挥官的 power"**
- 加成与指挥官彻底解耦：加成不知道 SOAHeroicShield 来自阿塔尼斯
- `extra_calls` 中的函数名由生成器映射到 galaxy 函数调用（函数签名必须一致）

**生成器** `scripts/build-generic-bonus-catalog.ps1`：
- 读取 `Shared/GenericBonuses.json`
- 生成 `LibE0EAE146_GenericBonusCatalog.galaxy`：
  - `gf_GenericBonusType(string bonusId)` → toggle / level
  - `gf_GenericBonusMaxLevel(string bonusId)` → max_level
  - `gf_GenericBonusUpgrades(string bonusId, int index)` → 按索引返回 upgrade ID
  - `gf_ApplyGenericBonusPassive(int player, string bonusId)` → 激活 upgrades + 执行 extra_calls

**galaxy 改造**：
- `LibE0EAE146.galaxy` `GenericBonusApplyPassives` 行 1310-1343：硬编码 6 个指挥官 power → 改为遍历 catalog 调用 `gf_ApplyGenericBonusPassive`
- 加成 ID 列表由 catalog 提供，galaxy 不再硬编码 11 个 ID

### 3.3 地图元数据外置（解决耦合点 4、7）

**配置** `Shared/Maps/<mapId>.json`（24+ 个文件）：
```json
{
  "map_id": "traynor01_7vs1",
  "start_minerals": 200,
  "start_vespene": 0,
  "start_supplies": 0,
  "needs_pre_init_rpg": true,
  "needs_unit_event_null": false,
  "uses_shared_ally": false,
  "second_unit_offset": null
}
```

**特殊字段**：
- `second_unit_offset`：null（默认）或 `{"method":"polar","offset":6.0,"angle":45.0}` 或 `{"method":"point_id","value":789749215}` 或 `{"method":"polar","offset":8.0,"angle":-45.0}`（Horner 系列）
- `needs_pre_init_rpg`：traynor01 / ttosh03b / tvalerian01 = true
- `needs_unit_event_null`：tvalerian03 = true
- `uses_shared_ally`：thanson01 / thanson03a = true

**生成器** `scripts/build-map-metadata.ps1`：
- 读取 `Shared/Maps/*.json`
- 生成 `LibE0EAE146_MapMetadata.galaxy`：
  - `gf_MapStartMinerals(string mapId)` → int
  - `gf_MapStartVespene(string mapId)` → int
  - `gf_MapStartSuppliesMade(string mapId)` → int
  - `gf_MapNeedsPreInitializeRpg(string mapId)` → bool
  - `gf_MapNeedsUnitEventNullVariableInvalid(string mapId)` → bool
  - `gf_MapUsesSharedPlayerCampaignAlly(string mapId)` → bool
  - `gf_MapSecondUnitPoint(string mapId, point basePoint)` → point（处理 second_unit_offset）

**galaxy 改造**：
- `LibE0EAE146.galaxy` 行 304-365（24 张图资源表）→ 调用 `gf_MapStartMinerals/Vespene/Supplies`
- 行 367-369、371-373、450-458 的硬编码 if-else → 调用 `gf_MapNeeds*` / `gf_MapUsesSharedPlayerCampaignAlly`
- `InitializeMapBaseScenario` 行 281-295 的 secondUnit 逻辑 → 调用 `gf_MapSecondUnitPoint`

### 3.4 因子 ID 单一来源（解决耦合点 5）

**数据源**：`Mods/kit_mutations.SC2Mod/Base.SC2Data/GameData/Mutators_*.xml`（因子定义已在此，是天然单一来源）

**生成器** `scripts/build-mutator-catalog.ps1`：
- 从 kit_mutations mod 的 XML 提取所有 `<Instances Id="...">` 的 ID
- 生成 `LibE0EAE146_MutatorCatalog.galaxy`：
  - `gv_mutatorIdCount` → int（总数）
  - `gv_mutatorIds[N]` → string 数组（按顺序）
  - `gf_MutatorIdByIndex(int index)` → string
  - `gf_MutatorIndexById(string id)` → int（-1 表示未找到）
- 同时输出 `Shared/Mutators/mutator-ids.json`（供 PowerShell 读取白名单）

**galaxy 改造**：
- `LibE0EAE146_MutatorRuntime.galaxy` 行 5-6 常量 + 行 20-91 `MutatorRuntimeId` + 行 93-153 `MutatorRuntimeAttributeId` → 改为 include catalog 提供的数组
- 保留 preset 分组（行 155-166）和启动逻辑（行 217-280）不变

**PowerShell 改造**：
- `campaignxcore-bank.ps1` `Set-CampaignXCoreMutatorPreset` 行 585-600 白名单 → 改为从 `Shared/Mutators/mutator-ids.json` 读取

## 四、文件结构

```
Shared/
├── Commanders/           # 新增：指挥官注册表（19 个 JSON）
│   ├── Raynor.json
│   ├── Kerrigan.json
│   └── ...
├── GenericBonuses.json   # 新增：加成定义（单一 JSON）
├── Maps/                 # 新增：地图元数据（24+ 个 JSON）
│   ├── traynor01_7vs1.json
│   └── ...
├── Mutators/
│   └── mutator-ids.json  # 新增：由生成器从 kit_mutations XML 提取
└── Talents/              # 已有：天赋配置（子系统 A）

scripts/
├── build-commander-registry.ps1        # 新增
├── build-generic-bonus-catalog.ps1     # 新增
├── build-map-metadata.ps1              # 新增
└── build-mutator-catalog.ps1           # 新增

Mods/7vs1/CoopZeroPop.SC2Mod/Base.SC2Data/
├── LibE0EAE146_CommanderRegistry.galaxy    # 新增（生成）
├── LibE0EAE146_GenericBonusCatalog.galaxy  # 新增（生成）
├── LibE0EAE146_MapMetadata.galaxy          # 新增（生成）
├── LibE0EAE146_MutatorCatalog.galaxy       # 新增（生成）
├── LibE0EAE146.galaxy                      # 改造：删除硬编码 if-else
├── LibE0EAE146_MutatorRuntime.galaxy       # 改造：用 catalog 替换硬编码
└── LibE0EAE146_h.galaxy                    # 改造：新增函数声明
```

## 五、明确排除项

- **DocumentHeader 二进制依赖**：维持现状，不自动化（风险高、收益低，启动脚本已兜底）
- **MapScript.galaxy 内的指挥官硬编码**（如 traynor01 的 Mengsk 分支）：地图级剧情逻辑，保留
- **ttosh02_7vs1 × Kerrigan 交叉硬编码**：地图特殊逻辑，保留
- **因子预设分组**（preset 1-3 含哪些）：保留 galaxy 硬编码，平衡设计非数据
- **web-launcher UI 改造**：现有 UI 已支持因子/加成选择，仅需数据源对齐（commanders-loader 读取 _registry.json，mutators-loader 已扫描 XML）

## 六、实施顺序

1. **指挥官注册表**：JSON + 生成器 + galaxy 改造（Initialize + InitializeBase）
2. **加成效果独立化**：JSON + 生成器 + galaxy 改造（GenericBonusApplyPassives）
3. **地图元数据外置**：JSON + 生成器 + galaxy 改造（资源表 + 特殊标志）
4. **因子 ID 单一来源**：生成器 + galaxy 改造（MutatorRuntime）+ PowerShell 改造
5. **web-launcher 数据源对齐**：commanders-loader 读 _registry.json
6. **测试验证**：Raynor/Abathur/Artanis/Dehaka/Fenix + Tychus（特殊初始化）+ Mengsk（特殊初始化）
7. **git commit + push**

## 七、风险与缓解

| 风险 | 缓解 |
|---|---|
| 生成器 galaxy 代码编译错误 | 每个子系统完成后立即重新生成并测试 |
| special_init 函数签名不匹配 | 生成器只调用已知签名的函数，extra_calls 在 galaxy 中用 if-else 分发到固定函数集 |
| 地图元数据遗漏 | 从 galaxy 硬编码表逐条迁移，生成器校验 JSON 覆盖所有 mapId |
| 因子 XML 解析失败 | 生成器宽容解析，缺失字段用默认值 |
| 删除 if-else 后 RuntimeInit 漏调用 | 生成器输出的 dispatcher 必须覆盖所有 JSON 配置的 runtime_init |

## 八、测试策略

1. **静态验证**：JSON Schema 校验 + galaxy 编译检查
2. **单子系统测试**：每完成一个子系统就用代表指挥官测试
3. **特殊初始化测试**：Tychus（CoopCasterTychus 创建）、Mengsk（Veterancy 初始化）、Dehaka（+60 人口）
4. **加成测试**：启用 GuardianShell/ChronoBoost 等验证升级激活
5. **地图测试**：traynor01（PreInitRpg）、thanson01（SharedAlly）、tvalerian03（特殊点位）
6. **因子测试**：启用 1-2 个因子验证生效
7. **全量测试**：batch-test-commanders.ps1
