# SC2 项目结构与依赖关系

## 目录概览

```
E:\Code\MyMod\SC2\
├── 合作指挥官-起义狂潮/          # 主项目目录（运行时）
│   ├── Maps/                    # 7vs1 合作指挥官地图
│   ├── Mods/                    # Mod 文件
│   │   └── 7vs1/
│   │       ├── CommanderCatalog.SC2Mod   # 指挥官数据扩展
│   │       └── CoopZeroPop.SC2Mod        # 核心游戏逻辑
│   └── kit_mutations.SC2Mod    # 突变因子 Mod
├── sc2-data-trigger/            # 官方数据镜像（参考用）
│   └── mods/                    # core/swarm/void/liberty 等官方 Mod 数据
└── scripts/                     # 构建和验证脚本
```

## Maps 依赖关系

所有 7vs1 地图位于 `合作指挥官-起义狂潮/Maps/`，共 29 张地图：

| 地图前缀 | 地图数量 | 示例 |
|---------|---------|------|
| thanson | 3 | thanson01_7vs1.SC2Map |
| thorner | 5 | thorner01_7vs1.SC2Map |
| traynor | 3 | traynor01_7vs1.SC2Map |
| ttosh | 4 | ttosh01_7vs1.SC2Map |
| ttychus | 5 | ttychus01_7vs1.SC2Map |
| tvalerian | 3 | tvalerian01_7vs1.SC2Map |
| tzeratul | 3 | tzeratul02_7vs1.SC2Map |
| 67vs1 | 1 | 67vs1_2023.SC2Map |

### 地图公共依赖

所有地图的 DocumentInfo 中声明了相同的依赖：

```xml
<Dependencies>
    <Value>bnet:自由之翼剧情 (战役)/0.0/999,file:Campaigns/LibertyStory.SC2Campaign</Value>
    <Value>bnet:自由之翼 (Mod)/0.0/999,file:Mods/Liberty.SC2Mod</Value>
    <Value>file:Mods/7vs1/CoopZeroPop.SC2Mod</Value>
    <Value>file:Mods/7vs1/CommanderCatalog.SC2Mod</Value>
    <Value>file:Mods/kit_mutations.SC2Mod</Value>
</Dependencies>
```

## Mod 依赖关系

### 依赖层级图

```
┌─────────────────────────────────────────────────────────────────┐
│                        7vs1 Maps                                │
│  (thanson01-03, thorner01-05, traynor01-03, ttosh01-03, etc.)  │
└────────────────────────────┬────────────────────────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐
│ LibertyStory    │  │ Liberty         │  │ kit_mutations      │
│ .SC2Campaign    │  │ .SC2Mod         │  │ .SC2Mod            │
│ (官方战役)       │  │ (官方Mod)        │  │ (突变因子)          │
└─────────────────┘  └─────────────────┘  └──────────┬──────────┘
                                                     │
                                                     ▼
                                          ┌─────────────────────┐
                                          │ Void.SC2Campaign    │
                                          │ (官方虚空战役)        │
                                          └─────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   CoopZeroPop.SC2Mod                            │
│                   (核心游戏逻辑 Mod)                              │
└────────────────────────────┬────────────────────────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
┌─────────────────┐  ┌─────────────────┐
│ VoidMulti       │  │ StarCoop        │
│ .SC2Mod         │  │ .SC2Mod         │
│ (虚空多人Mod)     │  │ (合作指挥官核心)   │
└─────────────────┘  └─────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                  CommanderCatalog.SC2Mod                         │
│                  (指挥官数据扩展 Mod)                             │
└────────────────────────────┬────────────────────────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
┌─────────────────┐  ┌─────────────────┐
│ VoidMulti       │  │ StarCoop        │
│ .SC2Mod         │  │ .SC2Mod         │
└─────────────────┘  └─────────────────┘
```

### Mod 详细说明

#### 1. CoopZeroPop.SC2Mod
- **路径**: `合作指挥官-起义狂潮/Mods/7vs1/CoopZeroPop.SC2Mod`
- **类型**: ExtensionMod（扩展Mod）
- **内容**:
  - `Base.SC2Data/GameData/` - 游戏数据（AbilData, UnitData, BehaviorData 等）
  - `Base.SC2Data/TriggerLibs/` - AI 触发器库
  - `Base.SC2Data/Lib*.galaxy` - Galaxy 脚本（约30个库文件）
  - `Triggers/` - 触发器文件
  - `zhCN.SC2Data/` - 中文本地化
- **依赖**:
  - VoidMulti.SC2Mod
  - StarCoop.SC2Mod

#### 2. CommanderCatalog.SC2Mod
- **路径**: `合作指挥官-起义狂潮/Mods/7vs1/CommanderCatalog.SC2Mod`
- **类型**: ExtensionMod（扩展Mod）
- **内容**:
  - `Base.SC2Data/GameData/` - 指挥官特定数据（分指挥官 XML 文件）
  - `zhCN.SC2Data/` - 中文本地化
- **依赖**:
  - VoidMulti.SC2Mod
  - StarCoop.SC2Mod
- **包含数据**:
  - AbilData_*.xml (Abathur, Horner, Kerrigan, Nova, Raynor, Stetmann)
  - UnitData_*.xml (各指挥官单位)
  - BehaviorData_*.xml
  - EffectData_*.xml
  - UpgradeData_*.xml
  - RequirementData_*.xml

#### 3. kit_mutations.SC2Mod
- **路径**: `合作指挥官-起义狂潮/Mods/kit_mutations.SC2Mod`
- **内容**:
  - `Base.SC2Data/GameData/Mutators_*.xml` - 突变因子数据（14个分类文件）
  - `Base.SC2Data/UI/Layout/` - 突变因子界面布局
  - `Triggers/` - 突变因子触发器
  - `zhCN.SC2Data/` - 中文本地化
- **依赖**:
  - Void.SC2Campaign

## sc2-data-trigger 目录说明

位于 `sc2-data-trigger/mods/`，包含官方数据的**只读镜像**，用于参考和开发：

| Mod 名称 | 用途 |
|---------|------|
| core.sc2mod | 核心游戏数据（GameData + TriggerLibs） |
| swarm.sc2mod | 虫群之心资料片数据 |
| void.sc2mod | 虚空之遗资料片数据 |
| liberty.sc2mod | 自由之翼资料片数据 |
| alliedcommanders.sc2mod | 合作指挥官联盟触发器库 |
| challenges.sc2mod | 挑战数据 |
| balancemulti.sc2mod | 多人平衡数据 |
| libertymulti.sc2mod | 自由之翼多人数据 |
| swarmmulti.sc2mod | 虫群之心多人数据 |
| mutators/*.sc2mod | 100+ 突变因子 Mod |

**注意**: 此目录不参与运行时加载，仅供数据参考和触发器开发。

## Galaxy 脚本架构

CoopZeroPop.SC2Mod 中的主要 Galaxy 库：

| 库文件 | 用途 |
|-------|------|
| LibE0EAE146.galaxy | 主运行时库（包含各指挥官 Runtime） |
| LibE0EAE146_*.galaxy | 各指挥官专用运行时 |
| LibKCOR.galaxy | 指挥官相关核心库 |
| LibKPVP.galaxy | PVP 指挥官系统 |
| LibCOMI.galaxy | 合作指挥官界面库（位于 sc2-data-trigger） |
| LibCOMU.galaxy | 合作指挥官通用库 |

## 数据文件分布

### GameData XML 文件位置

| 数据类型 | CommanderCatalog | CoopZeroPop |
|---------|-----------------|-------------|
| AbilData | ✓ (分指挥官) | ✓ |
| UnitData | ✓ (分指挥官) | ✓ |
| BehaviorData | ✓ (分指挥官) | ✓ |
| EffectData | ✓ (分指挥官) | ✓ |
| UpgradeData | ✓ (分指挥官) | ✓ |
| RequirementData | ✓ | ✓ |

## 关键路径汇总

| 资源类型 | 路径 |
|---------|------|
| 地图根目录 | `合作指挥官-起义狂潮/Maps/` |
| Mod 根目录 | `合作指挥官-起义狂潮/Mods/` |
| 核心 Mod | `合作指挥官-起义狂潮/Mods/7vs1/CoopZeroPop.SC2Mod/` |
| 指挥官数据 | `合作指挥官-起义狂潮/Mods/7vs1/CommanderCatalog.SC2Mod/Base.SC2Data/GameData/` |
| 突变因子 | `合作指挥官-起义狂潮/Mods/kit_mutations.SC2Mod/` |
| 官方数据参考 | `sc2-data-trigger/mods/` |
| 构建脚本 | `合作指挥官-起义狂潮/scripts/` |

## 加载顺序（运行时）

1. 官方基础: LibertyStory.SC2Campaign, Liberty.SC2Mod
2. 官方扩展: VoidMulti.SC2Mod, StarCoop.SC2Mod, Void.SC2Campaign
3. 自定义 Mod: CommanderCatalog.SC2Mod → CoopZeroPop.SC2Mod → kit_mutations.SC2Mod
4. 地图文件: *_7vs1.SC2Map

---
生成时间: 2026-06-28
