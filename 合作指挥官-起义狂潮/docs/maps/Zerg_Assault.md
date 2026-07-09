# Zerg_Assault

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/Zerg_Assault.SC2Map` |
| 类型 | 测试/第三方 |
| MapScript.galaxy 行数 | 1889 |
| 触发器总数(gt_*_Func) | 41 |
| 全局变量数(gv_) | 23 |
| include 库 | `TriggerLibs/NativeLib` |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 13 |
| `unitgroup` | 5 |
| `playergroup` | 5 |

本图特有变量(23 个):

- `unitgroup gv_alphaSpawn`
- `unitgroup gv_bravoSpawn`
- `unitgroup gv_charlieSpawn`
- `unitgroup gv_deltaSpawn`
- `int gv_alphaDifficulty`
- `int gv_bravoDifficulty`
- `int gv_charlieDifficulty`
- `int gv_deltaDifficulty`
- `int gv_alphaSelected`
- `int gv_bravoSelected`
- `int gv_charlieSelected`
- `int gv_deltaSelected`
- `int gv_p1Selection`
- `int gv_p2Selection`
- `int gv_p3Selection`
- `int gv_p4Selection`
- `int gv_lingsToAttackNorth`
- `unitgroup gv_lingsToAttackNorthGroup`
- `playergroup gv_alpha`
- `playergroup gv_bravo`
- `playergroup gv_charlie`
- `playergroup gv_delta`
- `playergroup gv_allPlayers`

## 触发器清单

### 进攻波次(2)

- `gt_Attack`
- `gt_NorthAttack` — North Attack

### 其他(39)

- `gt_AlphaMedium` — Alpha Medium
- `gt_BravoMedium` — Bravo Medium
- `gt_CharlieMedium` — Charlie Medium
- `gt_DeltaMedium` — Delta Medium
- `gt_AlphaHard` — Alpha Hard
- `gt_BravoHard` — Bravo Hard
- `gt_CharlieHard` — Charlie Hard
- `gt_DeltaHard` — Delta Hard
- `gt_UnitDead` — Unit Dead
- `gt_ElapsedTwo` — Elapsed Two
- `gt_Dialogs`
- `gt_EndGame` — End Game
- `gt_DestroyMainBase` — Destroy Main Base
- `gt_RescuableTank` — Rescuable Tank
- `gt_RescuingTank` — Rescuing Tank
- `gt_RescueableHellion` — Rescueable Hellion
- `gt_RescuingHellion` — Rescuing Hellion
- `gt_RescueableViking` — Rescueable Viking
- `gt_RescuingViking` — Rescuing Viking
- `gt_RescueableThor` — Rescueable Thor
- `gt_RescuingThor` — Rescuing Thor
- `gt_RescueableBC` — Rescueable BC
- `gt_RescuingBC` — Rescuing BC
- `gt_Spawn`
- `gt_NorthRandomize` — North Randomize
- `gt_UnitDies` — Unit Dies
- `gt_Disallow`
- `gt_View`
- `gt_Select`
- `gt_MapInitialization` — Map Initialization
- `gt_Alliances`
- `gt_TeamLocations` — Team Locations
- `gt_ClearMessage` — Clear Message
- `gt_CamerasStart` — Cameras Start
- `gt_RedCamFix` — Red Cam Fix
- `gt_BlueCamFix` — Blue Cam Fix
- `gt_TealCamFix` — Teal Cam Fix
- `gt_PurpleCamFix` — Purple Cam Fix
- `gt_References`

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

本图不属于 _7vs1 战役改造框架,未做公共/特有触发器区分,请直接参考上方触发器清单。

