# ttychus03_7vs1(莫比斯代理人)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/ttychus03_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 2764 |
| 触发器总数(gt_*_Func) | 61 |
| 全局变量数(gv_) | 21 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`LibA070801C`、`Lib67C0F0E7`、`LibE0EAE146` |
| 起始晶体矿 | 300 |
| 起始高能瓦斯 | 100 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 12 |
| `bool` | 4 |
| `unit` | 3 |
| `unitgroup` | 2 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(19 个):

- `int gv_p01_USER`
- `int gv_p02_ZERG`
- `int gv_p03_MOEBIUS`
- `int gv_p05_ZERG_BASE`
- `int gv_p06_MOEBIUS_SEC_FORCE`
- `int gv_p07_ZERG_KERRIGAN`
- `int gv_p08_NEUTRAL_CITY`
- `int gv_p09_MOEBIUSLAB`
- `int gv_p10_LEVIATHANBROOD`
- `int gv_p11_SCAVENGERS`
- `int gv_p12_RAVAGERS`
- `unit gv_uNIT_KERRIGAN`
- `bool gv_state`
- `int gv_u`
- `unitgroup gv_tG`
- `unit gv_t`
- `bool gv_victoryCinematicCompleted`
- `unitgroup gv_victoryHiddenUnitGroup`
- `unit gv_briefingKerrigan`

## 触发器清单

### 初始化(19)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03Units` — Init 03 Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_CreateMedivacIntro` — Create Medivac Intro
- `gt_TransmissionMedivacIntroQ` — Transmission - Medivac Intro Q
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene00DropPods` — Briefing Scene 00 Drop Pods
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingKerrgianSpawn` — Briefing Kerrgian Spawn
- `gt_BriefingCameraShake` — Briefing Camera Shake

### 进攻波次(5)

- `gt_ZergP05AttackWavesBase` — Zerg P05 Attack Waves - Base
- `gt_P2AttackWaves` — P2 Attack Waves
- `gt_P5AttackWaves` — P5 Attack Waves
- `gt_P10LeviathanAttackWaves` — P10 Leviathan Attack Waves
- `gt_VictoryNydusSpawn` — Victory Nydus Spawn

### 胜负(12)

- `gt_Victory`
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatPrimaryObjectiveFailed` — Defeat Primary Objective Failed
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictoryBaseLiftoff` — Victory Base Liftoff

### 对白提示(14)

- `gt_KerriganCalculatingETAQ` — Kerrigan - Calculating ETA Q
- `gt_KerriganTauntsRaynor1Q` — Kerrigan - Taunts Raynor 1 Q
- `gt_KerriganTauntsRaynor2Q` — Kerrigan - Taunts Raynor 2 Q
- `gt_KerriganTauntsRaynor3Q` — Kerrigan - Taunts Raynor 3 Q
- `gt_KerriganApproachesSite1Q` — Kerrigan - Approaches Site 1 Q
- `gt_KerriganApproachesSite2Q` — Kerrigan - Approaches Site 2 Q
- `gt_KerriganApproachesSite3Q` — Kerrigan - Approaches Site 3 Q
- `gt_BaseRetaliationDialogueQ` — Base - Retaliation Dialogue Q
- `gt_TransmissionMissionStartQ` — Transmission - Mission Start Q
- `gt_TransmissionBrutaliskFoundQ` — Transmission - Brutalisk Found Q
- `gt_TransmissionCoreIsDestroyedQ` — Transmission - Core Is Destroyed Q
- `gt_TransmissionSite1MilitiaRescuedQ` — Transmission - Site 1 Militia Rescued Q
- `gt_TransmissionSite2MilitiaRescuedQ` — Transmission - Site 2 Militia Rescued Q
- `gt_TransmissionSite3MilitiaRescuedQ` — Transmission - Site 3 Militia Rescued Q

### 其他(11)

- `gt_bon1`
- `gt_Bon2`
- `gt__6p1` — 6p1
- `gt__6p2` — 6p2
- `gt__6p3` — 6p3
- `gt__6p4` — 6p4
- `gt__6p5` — 6p5
- `gt__6p6` — 6p6
- `gt_Main`
- `gt_Kerrigan`
- `gt_StartAI` — Start AI

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 51 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_bon1`
- `gt_Bon2`
- `gt__6p1` — 6p1
- `gt__6p2` — 6p2
- `gt__6p3` — 6p3
- `gt__6p4` — 6p4
- `gt__6p5` — 6p5
- `gt__6p6` — 6p6
- `gt_Main`
- `gt_CreateMedivacIntro` — Create Medivac Intro
- `gt_Kerrigan`
- `gt_KerriganCalculatingETAQ` — Kerrigan - Calculating ETA Q
- `gt_KerriganTauntsRaynor1Q` — Kerrigan - Taunts Raynor 1 Q
- `gt_KerriganTauntsRaynor2Q` — Kerrigan - Taunts Raynor 2 Q
- `gt_KerriganTauntsRaynor3Q` — Kerrigan - Taunts Raynor 3 Q
- `gt_KerriganApproachesSite1Q` — Kerrigan - Approaches Site 1 Q
- `gt_KerriganApproachesSite2Q` — Kerrigan - Approaches Site 2 Q
- `gt_KerriganApproachesSite3Q` — Kerrigan - Approaches Site 3 Q
- `gt_BaseRetaliationDialogueQ` — Base - Retaliation Dialogue Q
- `gt_TransmissionMissionStartQ` — Transmission - Mission Start Q
- `gt_TransmissionMedivacIntroQ` — Transmission - Medivac Intro Q
- `gt_TransmissionBrutaliskFoundQ` — Transmission - Brutalisk Found Q
- `gt_TransmissionCoreIsDestroyedQ` — Transmission - Core Is Destroyed Q
- `gt_TransmissionSite1MilitiaRescuedQ` — Transmission - Site 1 Militia Rescued Q
- `gt_TransmissionSite2MilitiaRescuedQ` — Transmission - Site 2 Militia Rescued Q
- `gt_TransmissionSite3MilitiaRescuedQ` — Transmission - Site 3 Militia Rescued Q
- `gt_StartAI` — Start AI
- `gt_ZergP05AttackWavesBase` — Zerg P05 Attack Waves - Base
- `gt_P2AttackWaves` — P2 Attack Waves
- `gt_P5AttackWaves` — P5 Attack Waves
- `gt_P10LeviathanAttackWaves` — P10 Leviathan Attack Waves
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatPrimaryObjectiveFailed` — Defeat Primary Objective Failed
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictoryNydusSpawn` — Victory Nydus Spawn
- `gt_VictoryBaseLiftoff` — Victory Base Liftoff
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene00DropPods` — Briefing Scene 00 Drop Pods
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingKerrgianSpawn` — Briefing Kerrgian Spawn
- `gt_BriefingCameraShake` — Briefing Camera Shake

