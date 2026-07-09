# RM_Map2_Fall_again

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/RM_Map2_Fall_again.SC2Map` |
| 类型 | 测试/第三方 |
| MapScript.galaxy 行数 | 1672 |
| 触发器总数(gt_*_Func) | 52 |
| 全局变量数(gv_) | 27 |
| include 库 | `TriggerLibs/NativeLib` |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `timer` | 10 |
| `int` | 8 |
| `int[]` | 3 |
| `fixed` | 1 |
| `abilcmd` | 1 |
| `unit` | 1 |
| `revealer` | 1 |
| `unit[]` | 1 |
| `timer[]` | 1 |

本图特有变量(27 个):

- `int gv_diffdialog`
- `int[] gv_diffdialogbutton`
- `int gv_difficulty`
- `timer gv_spawntimer`
- `fixed gv_zergEnergie`
- `int gv_maxAnzahlFlammer`
- `int gv_anzahlFlammer`
- `abilcmd gv_fC3A4higkeitJimySpawnMarines`
- `unit gv_einheitJimy1`
- `int gv_maxAnzahlWarpigs`
- `int gv_anzahlWarpigs`
- `int gv_maxAnzahlPredators`
- `int gv_anzahlPredators`
- `int[] gv_hauptmissionen`
- `int[] gv_nebenmissionen`
- `timer gv_timerStart1`
- `timer gv_timerStart2`
- `timer gv_timerStart3`
- `revealer gv_aufdeckerStart`
- `timer gv_timerPredators1`
- `timer gv_timerPredators2`
- `timer gv_timerPredators3`
- `unit[] gv_predEnemy`
- `timer gv_timerGolem`
- `timer gv_hilfenaht`
- `timer gv_klotimer1`
- `timer[] gv_klotimer`

## 触发器清单

### 其他(52)

- `gt_Variableninitalisierung`
- `gt_SpielStarteinstellungen` — Spiel Starteinstellungen
- `gt_GUI`
- `gt_SchwierigkeitgewC3A4hlt` — Schwierigkeit gew??hlt
- `gt_Ziel`
- `gt_Jemandwichtigesstirbt` — Jemand wichtiges stirbt
- `gt_Jemandwichtigesstirbt2` — Jemand wichtiges stirbt 2
- `gt_SpawnGruppe1` — Spawn Gruppe 1
- `gt_Welleabspawn` — Welle a+b   (spawn)
- `gt_Welleabspawn2` — Welle a+b   (spawn) 2
- `gt_Spawnerstirbt` — Spawner stirbt
- `gt_TychusSpawnedFlammerisborn` — Tychus Spawned Flammer is born
- `gt_TychusSpawnedFlammerDies` — Tychus Spawned Flammer Dies
- `gt_Waffebeistart` — Waffe bei start
- `gt_Granaten`
- `gt_RaynorSpawnedMarineisborn` — Raynor Spawned Marine is born
- `gt_RaynorSpawnedMarineDies` — Raynor Spawned Marine Dies
- `gt_Looseit` — Loose it
- `gt_Gotit` — Got it
- `gt_Getarnt`
- `gt_Enttarnt`
- `gt_ToshSpawnedPredatorisborn` — Tosh Spawned Predator is born
- `gt_ToshSpawnedPredatorDies` — Tosh Spawned Predator Dies
- `gt_Tip1` — Tip 1
- `gt_Tip2` — Tip 2
- `gt_RaynortrifftHybrid` — Raynor trifft Hybrid
- `gt_Start1`
- `gt_Start12` — Start1 2
- `gt_Start13` — Start1 3
- `gt_Start14` — Start1 4
- `gt_Start15` — Start1 5
- `gt_Start16` — Start1 6
- `gt_Start17` — Start1 7
- `gt_Start2Mission0` — Start 2 + Mission 0
- `gt_Start22` — Start 2 2
- `gt_Predsverstecken` — Preds verstecken
- `gt_Predators1` — Predators 1
- `gt_Predators2` — Predators 2
- `gt_Predators22` — Predators 2 2
- `gt_Predators3Verwundbarkeit` — Predators 3 + Verwundbarkeit
- `gt_Unsterblich`
- `gt_GolemEntdeckt` — Golem Entdeckt
- `gt_GolemEntdeckt2` — Golem Entdeckt 2
- `gt_Hy`
- `gt_WiedersehenmachtfreudeMission2KI3` — Wiedersehen macht freude + Mission 2 + KI 3
- `gt_VersteckeTaurenbeiKlo` — Verstecke Tauren bei Klo
- `gt_Klo1` — Klo 1
- `gt_Klo2Mission1` — Klo 2 + Mission 1
- `gt_HomeSweetHome` — Home Sweet Home
- `gt_EineHandwC3A4schtdieAndereKiStartZerg` — Eine Hand w??scht die Andere + Ki Start Zerg
- `gt_Hilfekommt` — Hilfe kommt
- `gt_Hybridforschung`

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

本图不属于 _7vs1 战役改造框架,未做公共/特有触发器区分,请直接参考上方触发器清单。

