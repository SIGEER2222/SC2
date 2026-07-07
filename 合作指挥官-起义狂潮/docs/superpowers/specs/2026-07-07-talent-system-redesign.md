# 指挥官天赋系统重构设计

**日期**：2026-07-07
**状态**：已批准，待实施
**目标**：废除威望 3 选 1 掩码逻辑和精通 6 槽固定槽位，统一为 JSON 配置驱动的天赋系统。威望效果完全融入天赋（负面去除），精通改为可加点的特殊天赋节点，无点数限制（全选/满级）。

## 一、现状问题

### 1.1 威望系统（Prestige）
- **机制**：3 位掩码（0-7）控制 3 个威望槽启用，`PrestigeBonusMask` Bank 键
- **问题**：
  - 3 位掩码扩展困难（最多 3 个威望）
  - 3 选 1 互斥限制玩家选择
  - 负面效果（Closure 函数）通过 `Prestige4`/`AllPositiveFusion` Profile 绕过，逻辑复杂
- **影响范围**：18 个原生指挥官 × 3 威望 = 54 个威望节点

### 1.2 精通系统（Mastery）
- **机制**：6 槽 × 0-30 级，`Mastery0`~`Mastery5` Bank 键，3 组对立二选一（category 1/2/3）
- **问题**：
  - 6 槽固定，无法扩展
  - category 二选一限制选择
  - 与威望有交叉引用（威望 supplement 可挂到精通 Upgrade 上）
- **影响范围**：18 个原生指挥官 × 6 精通 = 108 个精通节点

### 1.3 HexTalents（海克斯天赋）
- **机制**：27 个通用天赋，32 位掩码 `StartTalentMask`，`TNX_xxx` Upgrade + `TNX_Ability_total` Behavior
- **状态**：独立系统，与威望/精通并行
- **处理**：保留为"通用天赋"类别，纳入新系统统一管理

## 二、新天赋系统设计

### 2.1 核心概念

**天赋节点（Talent Node）** 是统一的最小单位，分三种类型：
- **switch（开关型）**：源于威望，选择即生效（level=1），无负面效果
- **level（加点型）**：源于精通，可加点（0-30 级），每点提升效果
- **common（通用型）**：源于 HexTalents，选择即生效，所有指挥官共享

### 2.2 数据模型（JSON 配置驱动）

每个指挥官一个 JSON 配置文件，位于 `Shared/Talents/<Commander>.json`：

```json
{
  "schema_version": 2,
  "commander": "TerranRaynor",
  "display_name": "雷诺",
  "talents": [
    {
      "id": "RaynorBio",
      "type": "switch",
      "name": "死水元帅",
      "description": "生物战斗单位的生命值提高100%",
      "category": "prestige",
      "upgrades": ["CommanderPrestigeRaynorBio"],
      "supplement_upgrades": [
        {
          "target": "ShieldWall",
          "supplements": ["CommanderPrestigeRaynorBioMarineUpgrade"]
        },
        {
          "target": "FirebatJuggernautPlating",
          "supplements": ["CommanderPrestigeRaynorBioFirebatUpgrade"]
        }
      ],
      "enable_units": [],
      "disable_units": [],
      "enable_abils": [],
      "disable_abils": [],
      "extra_options": [
        {
          "id": "BioSuperStim",
          "name": "强化兴奋剂",
          "description": "启用强化版兴奋剂",
          "type": "toggle",
          "default": false,
          "upgrades": ["CommanderPrestigeRaynorBioSuperStim"]
        }
      ]
    },
    {
      "id": "RaynorResearchCost",
      "type": "level",
      "name": "研究成本",
      "description": "每点降低研究成本",
      "category": "mastery",
      "max_level": 30,
      "upgrade": "MasteryRaynorResearchCost",
      "point_increment": 2,
      "value_format": "-~A~%"
    }
  ]
}
```

### 2.3 JSON Schema 字段说明

**顶层字段**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `schema_version` | int | 固定 2（新格式） |
| `commander` | string | 运行时指挥官名（如 `TerranRaynor`） |
| `display_name` | string | 显示名 |
| `talents` | array | 天赋节点列表 |

**天赋节点通用字段**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 唯一标识（如 `RaynorBio`） |
| `type` | string | `switch` / `level` / `common` |
| `name` | string | 显示名 |
| `description` | string | 描述文本 |
| `category` | string | `prestige` / `mastery` / `common` |

**switch 型专属字段**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `upgrades` | string[] | 选择后激活的 Upgrade ID 列表（含 primary_upgrade + secondary_upgrades_shared + secondary_upgrades_self） |
| `suppress_upgrades` | string[] | 选择后需要抑制（隐藏）的 Upgrade ID 列表 |
| `supplement_upgrades` | array | 把 supplement Upgrade 挂到已存在的目标 Upgrade 上（格式：`{target, supplements[]}`） |
| `enable_units` / `disable_units` | string[] | 启用/禁用单位 |
| `enable_abils` / `disable_abils` | array | 启用/禁用能力（格式：`{abil, cmd}`） |
| `extra_options` | array | 额外开关选项（格式：`{id, name, description, type, default, upgrades[]}`） |

**level 型专属字段**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `max_level` | int | 最大等级（默认 30） |
| `upgrade` | string | 对应的 Upgrade ID |
| `point_increment` | float | 每点增量 |
| `value_format` | string | 显示格式 |

**common 型专属字段**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `upgrades` | string[] | 选择后激活的 Upgrade ID（TNX_xxx） |
| `behavior` | string | 对应的 Behavior ID（如 `TNX_Ability_total`） |

### 2.4 Bank 存储格式

**Section**：`CommanderTalents`（新 Section，取代 `CommanderPower` 中的威望/精通键）

**键格式**：
- 开关型：`<Commander>.<TalentId>` = `1`（选中）或不写（未选）
- 加点型：`<Commander>.<TalentId>` = `<level>`（0-30）
- extra_options：`<Commander>.<TalentId>.<OptionId>` = `1`

**示例**：
```
[CommanderTalents]
TerranRaynor.RaynorBio=1
TerranRaynor.RaynorBio.BioSuperStim=1
TerranRaynor.RaynorMechAfterburners=1
TerranRaynor.RaynorAir=1
TerranRaynor.RaynorResearchCost=30
TerranRaynor.RaynorDropPodHaste=30
...
```

### 2.5 Alenger 指挥官处理

Alenger 指挥官（无威望/精通）的 JSON 配置为空 `talents` 数组：
```json
{
  "schema_version": 2,
  "commander": "TerranAlenger3",
  "display_name": "疯批帝国",
  "talents": []
}
```

## 三、galaxy 运行时实现

### 3.1 新增文件

**`LibE0EAE146_TalentSystem.galaxy`** — 天赋系统核心运行时

核心 API：
```galaxy
// 从 Bank 读取天赋选择状态
int libE0EAE146_gf_TalentLevel(string lp_commander, string lp_talentId);

// 应用所有天赋（替代旧 ApplyGeneratedProfile）
void libE0EAE146_gf_ApplyTalents(int lp_player, string lp_commander);

// 内部：应用 switch 型天赋
void libE0EAE146_gf_ApplySwitchTalent(int lp_player, string lp_commander, string lp_talentId);

// 内部：应用 level 型天赋
void libE0EAE146_gf_ApplyLevelTalent(int lp_player, string lp_commander, string lp_talentId);
```

### 3.2 天赋配置加载

由于 galaxy 脚本无法直接读 JSON，需要预生成 galaxy 配置代码。

galaxy 不支持复杂数据结构（无 struct、无嵌套数组），因此采用 **UserData catalog + galaxy 查询函数** 方案：

**方案**：在 `TalentCatalogData.xml` 中用 `CUserData` 定义天赋节点，galaxy 通过 `UserDataGetString`/`UserDataGetInt` 查询。

**`GameData/TalentCatalogData.xml`**（自动生成）：
```xml
<?xml version="1.0" encoding="utf-8"?>
<Catalog>
    <!-- 自动生成，勿手改。数据源：Shared/Talents/*.json -->
    <CUserData id="TalentRaynorBio">
        <EditorCategories value="Race:Terran"/>
        <Fields index="Type" value="switch"/>
        <Fields index="Category" value="prestige"/>
        <Fields index="Upgrade0" value="CommanderPrestigeRaynorBio"/>
        <Fields index="SupplementTarget0" value="ShieldWall"/>
        <Fields index="SupplementUpgrade0" value="CommanderPrestigeRaynorBioMarineUpgrade"/>
        ...
    </CUserData>
    <CUserData id="TalentRaynorResearchCost">
        <Fields index="Type" value="level"/>
        <Fields index="Category" value="mastery"/>
        <Fields index="MaxLevel" value="30"/>
        <Fields index="Upgrade" value="MasteryRaynorResearchCost"/>
        ...
    </CUserData>
</Catalog>
```

**galaxy 查询**（`LibE0EAE146_TalentSystem.galaxy` 中）：
```galaxy
// 通过 UserDataGet* 查询天赋配置
string libE0EAE146_gf_TalentField(string lp_talentId, string lp_field) {
    return UserDataGetString("TalentCatalog", lp_talentId, lp_field, 1);
}

int libE0EAE146_gf_TalentFieldInt(string lp_talentId, string lp_field) {
    return UserDataGetInt("TalentCatalog", lp_talentId, lp_field, 1);
}
```

**生成脚本**：`scripts/build-talent-catalog.ps1`
- 读取 `Shared/Talents/*.json`
- 生成 `TalentCatalogData.xml`（CUserData 定义）
- 注册到 CoopZeroPop 的 GameData.xml
- 每次修改 JSON 后重跑此脚本

### 3.3 应用流程

```
gf_Initialize
  └── gf_ApplyTalents(player, gv_commander)
       ├── BankLoad("CampaignXCore", 1)
       ├── 遍历该指挥官的所有天赋节点
       ├── switch 型：若 Bank 值=1，激活 upgrades + supplements + enable/disable
       ├── level 型：读 Bank 值作为 upgrade level
       └── common 型：同 switch，额外给单位加 behavior
```

### 3.4 废弃代码清理

**删除**：
- `LibE0EAE146_CommanderPowerProfile.galaxy` 中的威望掩码逻辑（`gf_CommanderPowerPrestigeMask`、`gf_CommanderPowerPrestigeBonusMask` 等）
- `LibE0EAE146_CommanderPowerGenerated.galaxy` 中的 `Apply*Prestiges` 和 `Apply*Masteries` 函数（由新系统替代）
- `LibE0EAE146_CommanderPowerGeneratedClosure.galaxy`（负面效果，完全删除）
- `commander-power-metadata.json` 中的 `prestiges` 和 `masteries` 字段（保留 `bank_keys` 等其他字段）

**保留**：
- `LibE0EAE146_HexTalents.galaxy`（作为 common 型天赋的运行时基础）
- `Apply*Level` 函数（等级解锁，与天赋无关）
- Bank 的 `CommanderPower` Section 中的 `Profile` 键（兼容性，但不再影响逻辑）

## 四、webui 改造

### 4.1 天赋选择界面

**新组件**：`web-launcher/components/talent-tree.js`

功能：
- 读取 `Shared/Talents/<Commander>.json` 配置
- 按类别分组展示（prestige/mastery/common）
- switch 型：点击切换选中/未选
- level 型：+/- 按钮调整等级（0-max_level）
- extra_options：嵌套开关
- 无点数限制，全部可选/可满级

### 4.2 状态持久化

**localStorage 键**：`talent-selections`

格式：
```json
{
  "TerranRaynor": {
    "RaynorBio": {"selected": true, "options": {"BioSuperStim": true}},
    "RaynorResearchCost": {"level": 30},
    "RaynorMechAfterburners": {"selected": true}
  }
}
```

### 4.3 启动参数构造

**`launch-args-builder.mjs`** 修改：
- 移除旧的 `prestigeSelections`、`prestigeBonusMask`、`masteries` 参数
- 新增 `talentSelections` 参数（`string[]` 数组，格式同 PowerShell：`["RaynorBio=1","RaynorResearchCost=30",...]`）

**`launch-7vs1-coop-test.ps1`** 修改：
- 移除 `CommanderPowerPrestigeBonusMask`、`CommanderPowerPrestigePointIndex`、`CommanderPowerMastery0~5` 等参数
- 新增 `TalentSelections` 参数（`[string[]]` 数组，格式 `@("<TalentId>=<value>", ...)`，如 `@("RaynorBio=1","RaynorResearchCost=30","RaynorBio.BioSuperStim=1")`）

**`campaignxcore-bank.ps1`** 修改：
- 移除 `Set-CampaignXCoreCommanderPowerPreset` 中的威望/精通写入逻辑
- 新增 `Set-CampaignXCoreTalentSelections` 函数，写入 `CommanderTalents` Section（格式：键 `<Commander>.<TalentId>` = 值）

## 五、迁移计划

### 5.1 数据迁移

**自动迁移脚本**：`scripts/migrate-prestige-to-talents.ps1`

从 `commander-power-metadata.json` 提取所有威望/精通定义，生成 `Shared/Talents/<Commander>.json`：

| 旧字段 | 新字段 |
|--------|--------|
| `prestiges[].primary_upgrade` | `talents[].upgrades[0]` |
| `prestiges[].secondary_upgrades_shared/self` | `talents[].upgrades[1..]` |
| `prestiges[].upgrade_supplements` | `talents[].supplement_upgrades` |
| `prestiges[].enable/disable_units/abils` | `talents[].enable/disable_units/abils` |
| `prestiges[].extra_options` | `talents[].extra_options` |
| `prestiges[].tooltip` 中的优点部分 | `talents[].description`（去除缺点） |
| `masteries[].upgrade` | `talents[].upgrade` |
| `masteries[].point_increments[0]` | `talents[].point_increment` |
| `masteries[].value_format` | `talents[].value_format` |

**负面效果处理**：直接去除，只保留优点描述。

### 5.2 HexTalents 迁移

将 27 个 HexTalents 提取为 `Shared/Talents/_Common.json`（所有指挥官共享）：
- `type`: `common`
- `category`: `common`
- `upgrades`: `["TNX_012"]` 等
- 保留 `TNX_Ability_total` behavior 机制

**掩码替代**：原 `StartTalentMask` 32 位掩码废弃。每个 HexTalent 作为一个独立 switch 型天赋节点，通过 Bank `CommanderTalents` Section 的 `_Common.<TalentId>=1` 键控制启用。webui 选择后写入 Bank，galaxy 运行时遍历 `_Common.json` 的 27 个节点，读 Bank 决定是否激活。

### 5.3 指挥官清单

需迁移的 18 个原生指挥官：
Raynor, Kerrigan, Artanis, Swann, Zagara, Vorazun, Karax, Abathur, Alarak, Nova, Stukov, Fenix, Dehaka, Horner, Tychus, Zeratul, Stetmann, Mengsk

空配置的 5 个指挥官：
Izsha, RaynorX, AbathurReborn, TestZerg, Alenger3

## 六、实施顺序

1. **创建 JSON Schema 和示例文件**（Raynor + Kerrigan 两个示例）
2. **写迁移脚本**（`migrate-prestige-to-talents.ps1`），生成所有 18 个指挥官的 JSON
3. **写 TalentCatalog 生成脚本**（`build-talent-catalog.ps1`），编译 JSON 为 `TalentCatalogData.xml`（CUserData 定义）
4. **实现 galaxy 运行时**（`LibE0EAE146_TalentSystem.galaxy`，通过 UserDataGet* 查询配置）
5. **改造 webui**（新天赋选择界面 + 状态持久化）
6. **改造启动链**（`launch-7vs1-coop-test.ps1` + `campaignxcore-bank.ps1`）
7. **删除旧代码**（威望掩码/精通槽/Closure 等）
8. **测试验证**（Raynor/Kerrigan/Stetmann/Tychus/Alenger3 五个代表）
9. **git commit + push**

## 七、风险与缓解

| 风险 | 缓解 |
|------|------|
| JSON → galaxy 配置编译错误 | 先用 Raynor 单指挥官验证编译链路 |
| Bank 格式变化导致旧存档不兼容 | 这是预期行为（完全替代旧系统），无需兼容 |
| webui 改造工作量大 | 复用现有组件结构，仅改数据源和交互逻辑 |
| supplement_upgrades 机制复杂 | 保留原有 Upgrade ID，仅改应用入口 |
| 删除旧代码可能遗漏引用 | 全局搜索 `Prestige` / `Mastery` 关键字确认 |

## 八、测试策略

1. **静态验证**：JSON Schema 校验 + galaxy 编译检查
2. **单指挥官测试**：Raynor（威望+精通+extra_options）、Kerrigan（supplement 挂精通）、Stetmann（完整实现）、Tychus（XM 系列）、Alenger3（空配置）
3. **全量测试**：batch-test-commanders.ps1 测试所有 19 个指挥官
4. **webui 测试**：验证天赋选择 → Bank 写入 → 游戏内应用完整链路

## 九、后续扩展

本设计为子系统 A，后续子系统依赖：
- **子系统 B（解耦）**：天赋系统独立后，更易与地图/因子/加成解耦
- **子系统 C（Alenger 扩展）**：Alenger 空配置即可接入，新 Alenger 指挥官无需改天赋代码
- **子系统 D（平衡）**：天赋 Upgrade 可作为平衡调整的统一入口
