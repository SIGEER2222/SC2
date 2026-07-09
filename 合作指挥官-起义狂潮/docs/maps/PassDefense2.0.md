# PassDefense2.0

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/PassDefense2.0.SC2Map` |
| 类型 | 测试/第三方 |
| MapScript.galaxy 行数 | 1627 |
| 触发器总数(gt_*_Func) | 48 |
| 全局变量数(gv_) | 7 |
| include 库 | `TriggerLibs/NativeLib` |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 2 |
| `int[]` | 2 |
| `bool` | 1 |
| `unit` | 1 |
| `timer` | 1 |

本图特有变量(7 个):

- `bool gv_nydusBool`
- `unit gv_cSS`
- `int gv_counter`
- `int[] gv_object`
- `timer gv_time`
- `int gv_lBoard`
- `int[] gv_kills`

## 触发器清单

### 初始化(2)

- `gt_Initial`
- `gt_Initials2Wontons` — Initials2 (Wonton's)

### 进攻波次(3)

- `gt_Megawave`
- `gt_DeathNydus` — Death Nydus
- `gt_Endwave`

### 其他(43)

- `gt_Barrack1`
- `gt_Barrack2`
- `gt_Starport`
- `gt_TerranRein` — Terran Rein
- `gt_Loss`
- `gt_Loss2`
- `gt_Worm5`
- `gt_Worm4`
- `gt_Worm3`
- `gt_Worm2`
- `gt_Worm1`
- `gt_RearDefault` — Rear Default
- `gt__300Spawn` — 300Spawn
- `gt_Muts`
- `gt_CaveSpawn` — Cave Spawn
- `gt_SS1`
- `gt_SS2`
- `gt_Hive`
- `gt_DefaultLings` — Default Lings
- `gt_MassLings` — Mass Lings
- `gt_Hydras`
- `gt_Ultras`
- `gt_RoachSpawn` — Roach Spawn
- `gt_DeathCaster` — Death Caster
- `gt_DeathUltra` — Death Ultra
- `gt_DeathSpire` — Death Spire
- `gt_DeathSS1` — Death SS1
- `gt_DeathSS2` — Death SS2
- `gt_DeathHive` — Death Hive
- `gt_RoachDeath`
- `gt_Whipcrack`
- `gt_CornerMuts`
- `gt_EndCave`
- `gt_SuppDep`
- `gt_SuppDep2`
- `gt_SuppDep3`
- `gt_SuppDep4`
- `gt_SuppDep5`
- `gt_CiniTestTriggerDeletebeforefull` — CiniTestTrigger (Delete before full)
- `gt_Level`
- `gt_Leaver`
- `gt_Time`
- `gt_KillAdd` — Kill Add

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

本图不属于 _7vs1 战役改造框架,未做公共/特有触发器区分,请直接参考上方触发器清单。

