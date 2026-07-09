# tzeratul03_7vs1(未来回响)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/tzeratul03_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 4237 |
| 触发器总数(gt_*_Func) | 81 |
| 全局变量数(gv_) | 59 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`LibA070801C`、`Lib67C0F0E7`、`LibE0EAE146` |
| 起始晶体矿 | 默认 |
| 起始高能瓦斯 | 默认 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | `second_unit_offset(point_id=2109449659)` |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 23 |
| `unitgroup` | 11 |
| `unit` | 8 |
| `bool` | 6 |
| `actor` | 3 |
| `timer` | 3 |
| `sound` | 1 |
| `soundlink` | 1 |
| `playergroup` | 1 |
| `region` | 1 |
| `fixed` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(57 个):

- `int gv_p01_USER`
- `int gv_p02_ZERG_LOW_GROUND_AI`
- `int gv_p03_ZERG_NORTH`
- `int gv_p04_ZERG_EAST`
- `int gv_p05_ZERG_LOW_GROUND_NOAI`
- `int gv_p06_VOID_SEEKER`
- `int gv_p07_INFESTED`
- `int gv_p08_OVERMIND_REMAINS`
- `int gv_p09_Frenzied`
- `int gv_p10_ABANDONED_STRUCTURES`
- `int gv_p14_LIBRARIANS`
- `unit gv_zeratul`
- `bool gv_rainOn`
- `unitgroup gv_stage1InactivesGroup`
- `unitgroup gv_overlordWanderGroup`
- `unitgroup gv_pathingBlockerGroup`
- `unitgroup gv_protossProbeGroup`
- `unitgroup gv_infestedWarpGateGroup`
- `actor gv_observerPingModel`
- `actor gv_northGatePingModel`
- `actor gv_southGatePingModel`
- `sound gv_music`
- `soundlink gv_music2`
- `int gv_zergFrenzyTransmissionIncrement`
- `unitgroup gv_zerglingRush`
- `playergroup gv_lowGroundZergPlayers`
- `int gv_beaconPingNexus`
- `region gv_nydusSpawnRegions`
- `fixed gv_nydusWormHP`
- `timer gv_zergFrenzyTimer`
- `timer gv_zergFrenzyWarningTimer`
- `int gv_pingNydusWormP03`
- `int gv_pingNydusWormP04`
- `int gv_zergWormFrenzyTimerWindow`
- `unit gv_nydusWormP03`
- `unit gv_nydusWormP04`
- `int gv_waveCount`
- `bool gv_hardInsaneIgnoreWaypoints`
- `int gv_beaconPingBanelings`
- `int gv_beaconPingLurkers`
- `int gv_beaconPingMutalisks`
- `int gv_beaconPingZerglings`
- `int gv_allyKills`
- `timer gv_achievementHardTimer`
- `unit gv_briefingUltra1`
- `unit gv_briefingUltra2`
- `unit gv_briefingUltra3`
- `bool gv_midColossusCinematicCompleted`
- `unitgroup gv_midColossusHiddenGroup`
- `unitgroup gv_midColossusZergActiveGroup`
- `bool gv_victoryCinematicCompleted`
- `unit gv_victoryTassadarS1`
- `unit gv_victoryLarvaS2`
- `unitgroup gv_victoryZergGroupS2`
- `unitgroup gv_victoryZergGroupS4`
- `unitgroup gv_victoryHiddenUnitGroup`
- `int gv_victoryCurrentTransmission`

## 触发器清单

### 初始化(18)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03Units` — Init 03 Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGameStage1` — Start Game - Stage 1
- `gt_StartGameStage2` — Start Game - Stage 2
- `gt_TransmissionZeratulIntroQ` — Transmission - Zeratul Intro Q
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene00Hydralisks` — Briefing Scene 00 Hydralisks
- `gt_BriefingScene00WanderingZerg` — Briefing Scene 00 Wandering Zerg
- `gt_BriefingScene01Ultras` — Briefing Scene 01 Ultras
- `gt_BriefingScene01WanderingZerg` — Briefing Scene 01 Wandering Zerg

### 进攻波次(8)

- `gt_AfterZerglingAttack` — After Zergling Attack
- `gt_AfterZerglingAttackFailsafe` — After Zergling Attack Failsafe
- `gt_LibrariansAttackWaves` — Librarians Attack Waves
- `gt_P2JormungandAttackWaves` — P2 Jormungand Attack Waves
- `gt_P3LeviathanAttackWaves` — P3 Leviathan Attack Waves
- `gt_P4TiamatAttackWaves` — P4 Tiamat Attack Waves
- `gt_P5SurturAttackWaves` — P5 Surtur Attack Waves
- `gt_P7InfestedAttackWaves` — P7 Infested Attack Waves

### 胜负(18)

- `gt_VictoryOvermindTendrilsCompleted` — Victory Overmind Tendrils Completed
- `gt_Victory`
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatZeratulDies` — Defeat Zeratul Dies
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictoryCineFinalTendrilSetup` — Victory Cine - Final Tendril Setup
- `gt_VictoryCineFinalTendrilScene1` — Victory Cine - Final Tendril - Scene 1
- `gt_VictoryCineFinalTendrilScene2` — Victory Cine - Final Tendril - Scene 2
- `gt_VictoryCineFinalTendrilScene3` — Victory Cine - Final Tendril - Scene 3
- `gt_VictoryCineFinalTendrilScene4` — Victory Cine - Final Tendril - Scene 4
- `gt_VictoryCineFinalTendrilCinematicEnd` — Victory Cine - Final Tendril Cinematic End
- `gt_VictoryCineFinalTendrilCleanup` — Victory Cine - Final Tendril Cleanup
- `gt_VictoryCineScene2Stuff` — Victory Cine - Scene 2 Stuff
- `gt_VictoryCineScene4Stuff` — Victory Cine - Scene 4 Stuff
- `gt_VictoryCineSkipped` — Victory Cine - Skipped

### 对白提示(9)

- `gt_TransmissionZeratulFindsObserverQ` — Transmission - Zeratul Finds Observer Q
- `gt_TransmissionZeratulGetstoBaseQ` — Transmission - Zeratul Gets to Base Q
- `gt_TransmissionZerglingRushColossiQ` — Transmission - Zergling Rush Colossi Q
- `gt_TransmissionZergFrenzyIncomingQ` — Transmission - Zerg Frenzy Incoming Q
- `gt_TransmissionGettoOvermindRemainsQ` — Transmission - Get to Overmind Remains Q
- `gt_TransmissionUseObserversQ` — Transmission - Use Observers Q
- `gt_TransmissionZeratulReachesTendrilsQ` — Transmission - Zeratul Reaches Tendrils Q
- `gt_TransmissionHighTemplarWarpedInQ` — Transmission - High Templar Warped In Q
- `gt_MidCineQ` — Mid Cine Q

### 其他(28)

- `gt_bon1`
- `gt_bon2`
- `gt_stage2`
- `gt_Stage2Init` — Stage 2 Init
- `gt_RainCycling` — Rain Cycling
- `gt_ChangeOwnerofZeratul` — Change Owner of Zeratul
- `gt_ZeratulFindsObserver` — Zeratul Finds Observer
- `gt_OverlordWandering` — Overlord Wandering
- `gt_InfestedBunkersDestroyed` — Infested Bunkers Destroyed
- `gt_ResourcePickups` — Resource Pickups
- `gt_InfestedMarineClearer` — Infested Marine Clearer
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_AlliedBulliesSurtur` — Allied Bullies - Surtur
- `gt_AlliedBulliesExpo` — Allied Bullies - Expo
- `gt_AlliedBulliesInfested` — Allied Bullies - Infested
- `gt_StartAI` — Start AI
- `gt_ZergFrenzyTimerInitialization` — Zerg Frenzy Timer Initialization
- `gt_OvermindTendrilBeaconZerglingsSW` — Overmind Tendril Beacon - Zerglings (SW)
- `gt_OvermindTendrilBeaconMutalisksNW` — Overmind Tendril Beacon - Mutalisks (NW)
- `gt_OvermindTendrilBeaconLurkersSE` — Overmind Tendril Beacon - Lurkers (SE)
- `gt_OvermindTendrilBeaconBanelingsNE` — Overmind Tendril Beacon - Banelings (NE)
- `gt_ReleaseControlofZeratul` — Release Control of Zeratul
- `gt_AllyKills` — Ally Kills
- `gt_MidCineSetup` — Mid Cine Setup
- `gt_MidCineCinematic` — Mid Cine Cinematic
- `gt_MidCineCinematicEnd` — Mid Cine Cinematic End
- `gt_MidCineCleanup` — Mid Cine Cleanup
- `gt_MidCineZergActions` — Mid Cine - Zerg Actions

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 71 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGameStage1` — Start Game - Stage 1
- `gt_bon1`
- `gt_bon2`
- `gt_stage2`
- `gt_StartGameStage2` — Start Game - Stage 2
- `gt_Stage2Init` — Stage 2 Init
- `gt_RainCycling` — Rain Cycling
- `gt_ChangeOwnerofZeratul` — Change Owner of Zeratul
- `gt_ZeratulFindsObserver` — Zeratul Finds Observer
- `gt_AfterZerglingAttack` — After Zergling Attack
- `gt_AfterZerglingAttackFailsafe` — After Zergling Attack Failsafe
- `gt_OverlordWandering` — Overlord Wandering
- `gt_InfestedBunkersDestroyed` — Infested Bunkers Destroyed
- `gt_ResourcePickups` — Resource Pickups
- `gt_LibrariansAttackWaves` — Librarians Attack Waves
- `gt_P2JormungandAttackWaves` — P2 Jormungand Attack Waves
- `gt_P3LeviathanAttackWaves` — P3 Leviathan Attack Waves
- `gt_P4TiamatAttackWaves` — P4 Tiamat Attack Waves
- `gt_P5SurturAttackWaves` — P5 Surtur Attack Waves
- `gt_P7InfestedAttackWaves` — P7 Infested Attack Waves
- `gt_InfestedMarineClearer` — Infested Marine Clearer
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_AlliedBulliesSurtur` — Allied Bullies - Surtur
- `gt_AlliedBulliesExpo` — Allied Bullies - Expo
- `gt_AlliedBulliesInfested` — Allied Bullies - Infested
- `gt_StartAI` — Start AI
- `gt_ZergFrenzyTimerInitialization` — Zerg Frenzy Timer Initialization
- `gt_OvermindTendrilBeaconZerglingsSW` — Overmind Tendril Beacon - Zerglings (SW)
- `gt_OvermindTendrilBeaconMutalisksNW` — Overmind Tendril Beacon - Mutalisks (NW)
- `gt_OvermindTendrilBeaconLurkersSE` — Overmind Tendril Beacon - Lurkers (SE)
- `gt_OvermindTendrilBeaconBanelingsNE` — Overmind Tendril Beacon - Banelings (NE)
- `gt_ReleaseControlofZeratul` — Release Control of Zeratul
- `gt_TransmissionZeratulIntroQ` — Transmission - Zeratul Intro Q
- `gt_TransmissionZeratulFindsObserverQ` — Transmission - Zeratul Finds Observer Q
- `gt_TransmissionZeratulGetstoBaseQ` — Transmission - Zeratul Gets to Base Q
- `gt_TransmissionZerglingRushColossiQ` — Transmission - Zergling Rush Colossi Q
- `gt_TransmissionZergFrenzyIncomingQ` — Transmission - Zerg Frenzy Incoming Q
- `gt_TransmissionGettoOvermindRemainsQ` — Transmission - Get to Overmind Remains Q
- `gt_TransmissionUseObserversQ` — Transmission - Use Observers Q
- `gt_TransmissionZeratulReachesTendrilsQ` — Transmission - Zeratul Reaches Tendrils Q
- `gt_TransmissionHighTemplarWarpedInQ` — Transmission - High Templar Warped In Q
- `gt_AllyKills` — Ally Kills
- `gt_VictoryOvermindTendrilsCompleted` — Victory Overmind Tendrils Completed
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatZeratulDies` — Defeat Zeratul Dies
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene00Hydralisks` — Briefing Scene 00 Hydralisks
- `gt_BriefingScene00WanderingZerg` — Briefing Scene 00 Wandering Zerg
- `gt_BriefingScene01Ultras` — Briefing Scene 01 Ultras
- `gt_BriefingScene01WanderingZerg` — Briefing Scene 01 Wandering Zerg
- `gt_MidCineQ` — Mid Cine Q
- `gt_MidCineSetup` — Mid Cine Setup
- `gt_MidCineCinematic` — Mid Cine Cinematic
- `gt_MidCineCinematicEnd` — Mid Cine Cinematic End
- `gt_MidCineCleanup` — Mid Cine Cleanup
- `gt_MidCineZergActions` — Mid Cine - Zerg Actions
- `gt_VictoryCineFinalTendrilSetup` — Victory Cine - Final Tendril Setup
- `gt_VictoryCineFinalTendrilScene1` — Victory Cine - Final Tendril - Scene 1
- `gt_VictoryCineFinalTendrilScene2` — Victory Cine - Final Tendril - Scene 2
- `gt_VictoryCineFinalTendrilScene3` — Victory Cine - Final Tendril - Scene 3
- `gt_VictoryCineFinalTendrilScene4` — Victory Cine - Final Tendril - Scene 4
- `gt_VictoryCineFinalTendrilCinematicEnd` — Victory Cine - Final Tendril Cinematic End
- `gt_VictoryCineFinalTendrilCleanup` — Victory Cine - Final Tendril Cleanup
- `gt_VictoryCineScene2Stuff` — Victory Cine - Scene 2 Stuff
- `gt_VictoryCineScene4Stuff` — Victory Cine - Scene 4 Stuff
- `gt_VictoryCineSkipped` — Victory Cine - Skipped

