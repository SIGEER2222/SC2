# RM_Map3_Pest_Control

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/RM_Map3_Pest_Control.SC2Map` |
| 类型 | 测试/第三方 |
| MapScript.galaxy 行数 | 2125 |
| 触发器总数(gt_*_Func) | 60 |
| 全局变量数(gv_) | 23 |
| include 库 | `TriggerLibs/NativeLib` |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 10 |
| `unitgroup` | 9 |
| `int[]` | 3 |
| `abilcmd` | 1 |

本图特有变量(23 个):

- `unitgroup gv_teamSpieler3`
- `unitgroup gv_teamSpieler4`
- `unitgroup gv_teamSpieler5`
- `int gv_gebieteC3BCbernommen`
- `int gv_diffdialog`
- `int[] gv_diffdialogbutton`
- `int gv_difficulty`
- `unitgroup gv_gruppeKaserne`
- `unitgroup gv_gruppeHeld`
- `unitgroup gv_gruppeVersorgung`
- `unitgroup gv_gruppeForschung`
- `unitgroup gv_gruppeWaffenfabrik2`
- `unitgroup gv_gruppeLuftWaffenfabrik`
- `int gv_lokiDrohnenAnzahl`
- `int gv_maxAnzahlFlammer`
- `int gv_anzahlFlammer`
- `abilcmd gv_fC3A4higkeitJimySpawnMarines`
- `int gv_maxAnzahlWarpigs`
- `int gv_anzahlWarpigs`
- `int gv_maxAnzahlPredators`
- `int gv_anzahlPredators`
- `int[] gv_hauptmissionen`
- `int[] gv_nebenmissionen`

## 触发器清单

### 初始化(1)

- `gt_InitialisierungSpieler` — Initialisierung Spieler

### 其他(59)

- `gt_Spieler3Teamzusammenstellung` — Spieler 3 Teamzusammenstellung
- `gt_Spieler4Teamzusammenstellung` — Spieler 4 Teamzusammenstellung
- `gt_Spieler5Teamzusammenstellung` — Spieler 5 Teamzusammenstellung
- `gt_Spieler3angriff` — Spieler 3 angriff
- `gt_Spieler4angriff` — Spieler 4 angriff
- `gt_Spieler5angriff` — Spieler 5 angriff
- `gt_nC3A4chstesZiel1` — n??chstes Ziel 1
- `gt_nC3A4chstesZiel2` — n??chstes Ziel 2
- `gt_Variableninitalisierung`
- `gt_CPUBaubeschrC3A4nkungen` — CPU Baubeschr??nkungen
- `gt_GUI`
- `gt_SchwierigkeitgewC3A4hlt` — Schwierigkeit gew??hlt
- `gt_KartenbezogeneEinstellungen` — Kartenbezogene Einstellungen
- `gt_AlleBereicheC3BCbernommen` — Alle Bereiche ??bernommen
- `gt_Video`
- `gt_Fin`
- `gt_Jemandwichtigesstirbt` — Jemand wichtiges stirbt
- `gt_Kasernengruppe`
- `gt_Kasernen`
- `gt_Heldengruppe`
- `gt_Held`
- `gt_Versorgungsgruppe`
- `gt_Versorgung`
- `gt_Forschungsgruppe`
- `gt_Forschung`
- `gt_GruppeaC3BCbernehmen` — Gruppe a ??bernehmen
- `gt_Gruppebtreffen` — Gruppe b treffen
- `gt_GruppebC3BCbernehmen` — Gruppe b ??bernehmen
- `gt_Waffenfabrikgruppe2` — Waffenfabrikgruppe 2
- `gt_Waffenfabrik2` — Waffenfabrik 2
- `gt_LuftWaffenfabrikgruppe`
- `gt_LuftWaffenfabrik`
- `gt_HangarbeschrC3A4nkung` — Hangarbeschr??nkung
- `gt_Drohnestirbt` — Drohne stirbt
- `gt_TychusSpawnedFlammerisborn` — Tychus Spawned Flammer is born
- `gt_TychusSpawnedFlammerDies` — Tychus Spawned Flammer Dies
- `gt_NewWeapon` — New Weapon
- `gt_FC3A4higkeitenabschalten` — F??higkeiten abschalten
- `gt_Plasmagungefunden` — Plasmagun gefunden
- `gt_Granaten`
- `gt_RaynorSpawnedMarineisborn` — Raynor Spawned Marine is born
- `gt_RaynorSpawnedMarineDies` — Raynor Spawned Marine Dies
- `gt_TimeBombexplosion` — Time-Bomb explosion
- `gt_TimeBombabschalten` — Time-Bomb abschalten
- `gt_Snpierabschalten` — Snpier abschalten
- `gt_Snipergewehrgefunden` — Snipergewehr gefunden
- `gt_Getarnt`
- `gt_Enttarnt`
- `gt_ToshSpawnedPredatorisborn` — Tosh Spawned Predator is born
- `gt_ToshSpawnedPredatorDies` — Tosh Spawned Predator Dies
- `gt_VideoalleMissionen` — Video + alle Missionen
- `gt_KasernenC3BCbernommen` — Kasernen ??bernommen
- `gt_GeldC3BCbernommen` — Geld ??bernommen
- `gt_HirnC3BCbernommen` — Hirn ??bernommen
- `gt_FahrzeugeC3BCbernommen` — Fahrzeuge ??bernommen
- `gt_FlugzeugeC3BCbernommen` — Flugzeuge ??bernommen
- `gt_NeuerHeld` — Neuer Held
- `gt_TruppA` — Trupp A
- `gt_TruppB` — Trupp B

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

本图不属于 _7vs1 战役改造框架,未做公共/特有触发器区分,请直接参考上方触发器清单。

