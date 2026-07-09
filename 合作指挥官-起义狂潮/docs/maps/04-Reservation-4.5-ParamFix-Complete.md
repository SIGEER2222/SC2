# 04-Reservation-4.5-ParamFix-Complete

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/04-Reservation-4.5-ParamFix-Complete.SC2Map` |
| 类型 | 测试/第三方 |
| MapScript.galaxy 行数 | 3854 |
| 触发器总数(gt_*_Func) | 79 |
| 全局变量数(gv_) | 30 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib` |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `unit` | 13 |
| `int` | 10 |
| `bool` | 5 |
| `actor` | 2 |

本图特有变量(30 个):

- `bool gv_diffEasy`
- `bool gv_diffNormal`
- `bool gv_diffHard`
- `int gv_difficultySelectorV`
- `int gv_difficultyText`
- `int gv_difficultEasy`
- `int gv_difficultNormal`
- `int gv_difficultHard`
- `unit gv_kaiser`
- `bool gv_flashButtonKaisercharge`
- `bool gv_flashButtonPrimalRoar`
- `unit gv_kaiserClaw1`
- `unit gv_kaiserClaw2`
- `int gv_numberofSilos`
- `actor gv_actorDebris`
- `int gv_actorDebris2`
- `actor gv_actorRocks1`
- `int gv_actorRocks2`
- `unit gv_nydus01`
- `unit gv_nydus02`
- `unit gv_nydus03`
- `unit gv_teaBone`
- `unit gv_kerrigan`
- `unit gv_dropship`
- `int gv_objective1`
- `int gv_objective2`
- `unit gv_henshinFX`
- `unit gv_endingJane`
- `unit gv_endingTerry`
- `unit gv_lastMarine`

## 触发器清单

### 初始化(4)

- `gt_IntroMusic2`
- `gt_StartGame`
- `gt_FinalIntroA` — Final Intro A
- `gt_FinalIntroB` — Final Intro B

### 进攻波次(16)

- `gt_Patrol01` — Patrol 01
- `gt_Patrol02a` — Patrol 02 a
- `gt_Patrol02b` — Patrol 02 b
- `gt_Attack01Zergling` — Attack01 - Zergling
- `gt_Attack02Rocksa` — Attack02 - Rocks a
- `gt_Attack02Rocksb` — Attack02 - Rocks b
- `gt_Attack03`
- `gt_Attack04Ultralisk` — Attack04 - Ultralisk!
- `gt_Attack05Mutalisk` — Attack05 - Mutalisk
- `gt_Attack06Infested` — Attack06 - Infested
- `gt_Nydus01` — Nydus 01
- `gt_Nydus01KeepSpawning` — Nydus 01 (Keep Spawning)
- `gt_Nydus02` — Nydus 02
- `gt_Nydus02KeepSpawning` — Nydus 02 (Keep Spawning)
- `gt_Nydus03` — Nydus 03
- `gt_Nydus03KeepSpawning` — Nydus 03 (Keep Spawning)

### 其他(59)

- `gt_OverrideSettings`
- `gt_DifficultySelector`
- `gt_DifficultySelectedNormal`
- `gt_DifficultySelectedHard`
- `gt_StartHealthHard`
- `gt_StartHealthNormal`
- `gt_Bridges`
- `gt_MissionFailedTeaBoneDies` — MissionFailed - Tea Bone Dies
- `gt_MissionFailedKaiserDies` — MissionFailed - Kaiser Dies
- `gt_MissionFailedFriendlyFire` — MissionFailed - Friendly Fire
- `gt_TeachKaiserCharge` — Teach - Kaiser Charge!
- `gt_ButtonFlashKaiserchargeOff` — Button Flash Kaisercharge Off
- `gt_ButtonFlashKaiserchargeOn` — Button Flash Kaisercharge On
- `gt_ButtonPrimalRoarOff` — Button Primal Roar Off
- `gt_ButtonPrimalRoarOn` — Button Primal Roar On
- `gt_KaiserPrimalRoar` — Kaiser Primal Roar
- `gt_MissionObjectivesNukes`
- `gt_NukeSilosObjectiveUpdate` — Nuke Silos Objective Update
- `gt_TossSpectreEnterNukeSilosBlokA` — Toss Spectre Enter Nuke Silos Blok A
- `gt_HintsStart`
- `gt_HintsHealth`
- `gt_TIPDebris` — TIP - Debris
- `gt_TIPRocks` — TIP - Rocks
- `gt_HealAll`
- `gt_HealAllText`
- `gt_HealAllTextRepeat` — HealAllText Repeat
- `gt_Upgrades`
- `gt_DestructableSupply6General`
- `gt_alliances`
- `gt_Stranded01a` — Stranded 01a
- `gt_Stranded01b` — Stranded 01b
- `gt_Stranded02a` — Stranded 02a
- `gt_Stranded02b` — Stranded 02b
- `gt_Stranded03a` — Stranded 03a
- `gt_Stranded03b` — Stranded 03b
- `gt_Stranded04` — Stranded 04
- `gt_WeaponchangeTeaBoneRapidDefault` — Weaponchange Tea Bone Rapid-Default
- `gt_WeaponchangeTeaBoneSingleRocket` — Weaponchange Tea Bone Single-Rocket
- `gt_WeaponchangeTeaBonePenetrateFlame` — Weaponchange Tea Bone Penetrate-Flame
- `gt_Invincible`
- `gt_UnInvincible`
- `gt_Taunt`
- `gt_MissionCompleteHiveDestroyed` — Mission Complete - Hive Destroyed
- `gt_MissionCompleteHiveDestroyedskIPPED` — Mission Complete - Hive Destroyed- skIPPED
- `gt_BorderShip`
- `gt_CinematicInit`
- `gt_Dropship`
- `gt_DropshipRemove`
- `gt_Dream01a` — Dream 01a
- `gt_Dream01b` — Dream 01b
- `gt_Dream02a` — Dream 02a
- `gt_Dream02b` — Dream 02b
- `gt_Dream03a` — Dream 03a
- `gt_Dream03b` — Dream 03b
- `gt_EndingCinematic2` — EndingCinematic 2
- `gt_MissionAccomplished`
- `gt_EndingCinematic`
- `gt_EndingCinPt1` — EndingCin Pt.1
- `gt_EndingSkip`

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

本图不属于 _7vs1 战役改造框架,未做公共/特有触发器区分,请直接参考上方触发器清单。

