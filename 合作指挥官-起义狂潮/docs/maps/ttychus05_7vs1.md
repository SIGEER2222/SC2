# ttychus05_7vs1(虚空巨口)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/ttychus05_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 5947 |
| 触发器总数(gt_*_Func) | 107 |
| 全局变量数(gv_) | 68 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`TriggerLibs/SwarmLib`、`LibA070801C`、`Lib67C0F0E7`、`LibC0F50AA6`、`LibE0EAE146` |
| 起始晶体矿 | 1000 |
| 起始高能瓦斯 | 400 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 21 |
| `unitgroup` | 12 |
| `unit` | 12 |
| `bool` | 9 |
| `timer` | 4 |
| `region` | 3 |
| `playergroup` | 2 |
| `fixed` | 2 |
| `actor` | 1 |
| `region[]` | 1 |
| `point` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(66 个):

- `int gv_pLAYER_01_USER`
- `int gv_pLAYER_02_NYON`
- `int gv_pLAYER_03_PHASESMITHS`
- `int gv_pLAYER_04_SCIONS`
- `int gv_pLAYER_05_WORLDSHIP`
- `int gv_pLAYER_06_DEATHFLEET`
- `int gv_pLAYER_07_Prisoners`
- `int gv_pLAYER8_ELITEGUARD`
- `int gv_pLAYER9_WORLDSHIPFORWARD`
- `int gv_pLAYER10_HARBINGERS`
- `int gv_pLAYER11_FORWARDGUARD`
- `int gv_pLAYER12_HONORGUARD`
- `int gv_pLAYER13_DOMINION`
- `int gv_pLAYER14_NERAZIM`
- `actor gv_outhouse`
- `playergroup gv_fORCEGOOD_GUYS`
- `playergroup gv_fORCEBADGUYS`
- `unitgroup gv_gROUPUnitsnotinstart`
- `unitgroup gv_gROUPEmitters`
- `unit gv_uNIT_Toss02_SUPERWARPGATE`
- `unit gv_uNITVault`
- `fixed gv_daMuddaShipShields`
- `fixed gv_daMuddaShipLife`
- `region gv_mapAreaNormal`
- `unitgroup gv_gROUPLZEnemies`
- `timer gv_warpPrismTimer`
- `bool gv_fLAGCanIbemeannow`
- `unit gv_uNITWarpPrismN`
- `unit gv_uNITWarpPrismE`
- `unit gv_uNITWarpPrismW`
- `unit gv_uNITWarpPrismNW`
- `unit gv_uNITWarpPrismNE`
- `int gv_cOUNTERWarpinWave`
- `timer gv_tIMERVortexCooldown`
- `unit gv_uNITDaMothership`
- `int gv_dominionKills`
- `int gv_nerazimKills`
- `int gv_statRipFieldEmittersDestroyed`
- `unit gv_victoryArtifact`
- `region gv_voidRiftSpawns`
- `region[] gv_prismRegions`
- `unit gv_prismSuperWarpGate`
- `region gv_availablePrismRegions`
- `int gv_prismIntensity`
- `int gv_prismCycle`
- `timer gv_distractionTimer`
- `point gv_waypointArray`
- `bool gv_distractionOver`
- `int gv_globalForgeIntensity`
- `bool gv_introCinematicCompleted`
- `unitgroup gv_introHiddenProtossGroup`
- `unitgroup gv_introCineProtossGroup`
- `unit gv_introStalker01`
- `unit gv_introStalker02`
- `bool gv_baseMidCinematicCompleted`
- `unitgroup gv_baseMidHiddenUnitGroup`
- `bool gv_prisonersMidCinematicCompleted`
- `unitgroup gv_prisonersMidHiddenTerranGroup`
- `unitgroup gv_prisonersMidHiddenProtossGroup`
- `bool gv_mothershipMidCinematicCompleted`
- `unitgroup gv_mothershipMidHiddenUnitGroup`
- `unitgroup gv_mothershipMidRipFieldGroup`
- `unitgroup gv_mothershipMidSpawnedUnitGroup`
- `timer gv_nyonArrivalTimer`
- `bool gv_victoryCinematicCompleted`
- `unitgroup gv_victoryHiddenUnitGroup`

## 触发器清单

### 初始化(21)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03Units` — Init 03 Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_StartGameStage1` — Start Game - Stage 1
- `gt_StartGameStage2` — Start Game - Stage 2
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene00CamerasMovementandPings` — Briefing Scene 00 Cameras Movement and Pings
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene01Yamato` — Briefing Scene 01 Yamato
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_IntroQ` — Intro Q
- `gt_IntroSetup` — Intro Setup
- `gt_IntroCinematic` — Intro Cinematic
- `gt_IntroCinematicEnd` — Intro Cinematic End
- `gt_IntroCleanup` — Intro Cleanup
- `gt_IntroScene` — Intro Scene

### 进攻波次(15)

- `gt_MothershipProximityAttack` — Mothership - Proximity Attack
- `gt_P13DominionAttacks` — P13 Dominion Attacks
- `gt_P14NerazimAttackWaves` — P14 Nerazim Attack Waves
- `gt_MothershipWarpInAttack` — Mothership - Warp In Attack
- `gt_DestroyNydusandPrismPings` — Destroy Nydus and Prism Pings
- `gt_StartAIWaves` — Start AI Waves
- `gt_P6DeathFleetAttackWaves` — P6 Death Fleet Attack Waves
- `gt_P11ForwardGuardAttackWaves` — P11 Forward Guard Attack Waves
- `gt_P9WorldshipForwardGuardAttackWaves` — P9  Worldship Forward Guard Attack Waves
- `gt_P3SmithAttackWaves` — P3 Smith Attack Waves
- `gt_P4ScionsAttackWaves` — P4 Scions Attack Waves
- `gt_P10HarbingersAttackWaves` — P10 Harbingers Attack Waves
- `gt_P12HonorGuardAttackWaves` — P12 Honor Guard Attack Waves
- `gt_P8EliteGuardAttackWaves` — P8 Elite Guard Attack Waves
- `gt_WaveShadowFX` — Wave Shadow FX

### 胜负(12)

- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatLZUnitsDead` — Defeat LZ Units Dead
- `gt_VictoryRetrieveArtifactCompleted` — Victory Retrieve Artifact Completed
- `gt_Victory`
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

### 对白提示(8)

- `gt_PrisonDialogueQ` — Prison Dialogue Q
- `gt_MothershipDeathQ` — Mothership - Death Q
- `gt_ResourcePickupDialogueQ` — Resource Pickup - Dialogue Q
- `gt_ResourcesLowDialogueQ` — Resources Low Dialogue Q
- `gt_NyonPrismDropRepeatTransmission` — Nyon Prism Drop Repeat Transmission
- `gt_BaseMidQ` — Base Mid Q
- `gt_PrisonersMidQ` — Prisoners-Mid Q
- `gt_MothershipMidQ` — Mothership-Mid Q

### 其他(51)

- `gt_Stage2`
- `gt_Prisonrelease4` — Prison release 4
- `gt_StartWarpPrizmDrops` — Start Warp Prizm Drops
- `gt_WarpPrizmDropsWarpSpawner` — Warp Prizm Drops - Warp Spawner
- `gt_WarpPrizmDropN1` — Warp Prizm Drop - N1
- `gt_WarpPrizmDropN2` — Warp Prizm Drop - N2
- `gt_WarpPrizmDropS1` — Warp Prizm Drop - S1
- `gt_WarpPrizmDropS2` — Warp Prizm Drop - S2
- `gt_WarpPrizmDropS3` — Warp Prizm Drop - S3
- `gt_MothershipCreate` — Mothership - Create
- `gt_MothershipWarmholeVAULT` — Mothership - Warmhole VAULT
- `gt_MothershipWarmhole75health` — Mothership - Warmhole 75% health
- `gt_MothershipWarmhole30health` — Mothership - Warmhole 30% health
- `gt_ResourcePickups` — Resource Pickups
- `gt_AllyKillCounter` — Ally Kill Counter
- `gt_NerazimExpo` — Nerazim Expo
- `gt_NerazimForward1` — Nerazim Forward 1
- `gt_NerazimForward2` — Nerazim Forward 2
- `gt_NerazimForward3` — Nerazim Forward 3
- `gt_DominionForward1` — Dominion Forward 1
- `gt_DominionForward2` — Dominion Forward 2
- `gt_DominionForward3` — Dominion Forward 3
- `gt_MidIsland` — Mid Island
- `gt_ExtendTopBridges` — Extend Top Bridges
- `gt_ExtendCenterSouthBridges` — Extend Center South Bridges
- `gt_ExtendMidBridges` — Extend Mid Bridges
- `gt_ExtendCenterNEBridges` — Extend Center NE Bridges
- `gt_ExtendCenterLeftBridges` — Extend Center Left Bridges
- `gt_VoidRiftSpawns` — Void Rift Spawns
- `gt_PrismSpawns` — Prism Spawns
- `gt_NyonReinforcementsSuicide` — Nyon Reinforcements Suicide
- `gt_StartAI` — Start AI
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_ExarchDeadKillRifts` — Exarch Dead - Kill Rifts
- `gt_DistractionEnds`
- `gt_ClearForgePing` — Clear Forge Ping
- `gt_BaseMidSetup` — Base Mid Setup
- `gt_BaseMidCinematic` — Base Mid Cinematic
- `gt_BaseMidCinematicEnd` — Base Mid Cinematic End
- `gt_BaseMidCleanup` — Base Mid Cleanup
- `gt_PrisonersMidSetup` — Prisoners-Mid Setup
- `gt_PrisonersMidCinematic` — Prisoners-Mid Cinematic
- `gt_PrisonersMidCinematicEnd` — Prisoners-Mid Cinematic End
- `gt_PrisonersMidCleanup` — Prisoners-Mid Cleanup
- `gt_MothershipMidQAltermate` — Mothership-Mid Q Altermate
- `gt_MothershipMidSetup` — Mothership-Mid Setup
- `gt_MothershipMidCinematic` — Mothership-Mid Cinematic
- `gt_MothershipMidCinematicEnd` — Mothership-Mid Cinematic End
- `gt_MothershipMidCleanup` — Mothership-Mid Cleanup
- `gt_MothershipMidVault` — Mothership Mid Vault
- `gt_MothershipMidArrival` — Mothership Mid Arrival

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 97 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_StartGameStage1` — Start Game - Stage 1
- `gt_Stage2`
- `gt_StartGameStage2` — Start Game - Stage 2
- `gt_Prisonrelease4` — Prison release 4
- `gt_PrisonDialogueQ` — Prison Dialogue Q
- `gt_StartWarpPrizmDrops` — Start Warp Prizm Drops
- `gt_WarpPrizmDropsWarpSpawner` — Warp Prizm Drops - Warp Spawner
- `gt_WarpPrizmDropN1` — Warp Prizm Drop - N1
- `gt_WarpPrizmDropN2` — Warp Prizm Drop - N2
- `gt_WarpPrizmDropS1` — Warp Prizm Drop - S1
- `gt_WarpPrizmDropS2` — Warp Prizm Drop - S2
- `gt_WarpPrizmDropS3` — Warp Prizm Drop - S3
- `gt_MothershipCreate` — Mothership - Create
- `gt_MothershipProximityAttack` — Mothership - Proximity Attack
- `gt_MothershipWarmholeVAULT` — Mothership - Warmhole VAULT
- `gt_MothershipWarmhole75health` — Mothership - Warmhole 75% health
- `gt_MothershipWarmhole30health` — Mothership - Warmhole 30% health
- `gt_MothershipDeathQ` — Mothership - Death Q
- `gt_ResourcePickups` — Resource Pickups
- `gt_ResourcePickupDialogueQ` — Resource Pickup - Dialogue Q
- `gt_ResourcesLowDialogueQ` — Resources Low Dialogue Q
- `gt_AllyKillCounter` — Ally Kill Counter
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatLZUnitsDead` — Defeat LZ Units Dead
- `gt_VictoryRetrieveArtifactCompleted` — Victory Retrieve Artifact Completed
- `gt_NerazimExpo` — Nerazim Expo
- `gt_NerazimForward1` — Nerazim Forward 1
- `gt_NerazimForward2` — Nerazim Forward 2
- `gt_NerazimForward3` — Nerazim Forward 3
- `gt_DominionForward1` — Dominion Forward 1
- `gt_DominionForward2` — Dominion Forward 2
- `gt_DominionForward3` — Dominion Forward 3
- `gt_MidIsland` — Mid Island
- `gt_P13DominionAttacks` — P13 Dominion Attacks
- `gt_P14NerazimAttackWaves` — P14 Nerazim Attack Waves
- `gt_ExtendTopBridges` — Extend Top Bridges
- `gt_ExtendCenterSouthBridges` — Extend Center South Bridges
- `gt_ExtendMidBridges` — Extend Mid Bridges
- `gt_ExtendCenterNEBridges` — Extend Center NE Bridges
- `gt_ExtendCenterLeftBridges` — Extend Center Left Bridges
- `gt_MothershipWarpInAttack` — Mothership - Warp In Attack
- `gt_VoidRiftSpawns` — Void Rift Spawns
- `gt_DestroyNydusandPrismPings` — Destroy Nydus and Prism Pings
- `gt_PrismSpawns` — Prism Spawns
- `gt_NyonReinforcementsSuicide` — Nyon Reinforcements Suicide
- `gt_NyonPrismDropRepeatTransmission` — Nyon Prism Drop Repeat Transmission
- `gt_StartAI` — Start AI
- `gt_StartAIWaves` — Start AI Waves
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_P6DeathFleetAttackWaves` — P6 Death Fleet Attack Waves
- `gt_P11ForwardGuardAttackWaves` — P11 Forward Guard Attack Waves
- `gt_P9WorldshipForwardGuardAttackWaves` — P9  Worldship Forward Guard Attack Waves
- `gt_P3SmithAttackWaves` — P3 Smith Attack Waves
- `gt_P4ScionsAttackWaves` — P4 Scions Attack Waves
- `gt_P10HarbingersAttackWaves` — P10 Harbingers Attack Waves
- `gt_P12HonorGuardAttackWaves` — P12 Honor Guard Attack Waves
- `gt_P8EliteGuardAttackWaves` — P8 Elite Guard Attack Waves
- `gt_ExarchDeadKillRifts` — Exarch Dead - Kill Rifts
- `gt_DistractionEnds`
- `gt_WaveShadowFX` — Wave Shadow FX
- `gt_ClearForgePing` — Clear Forge Ping
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene00CamerasMovementandPings` — Briefing Scene 00 Cameras Movement and Pings
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene01Yamato` — Briefing Scene 01 Yamato
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_IntroQ` — Intro Q
- `gt_IntroSetup` — Intro Setup
- `gt_IntroCinematic` — Intro Cinematic
- `gt_IntroCinematicEnd` — Intro Cinematic End
- `gt_IntroCleanup` — Intro Cleanup
- `gt_IntroScene` — Intro Scene
- `gt_BaseMidQ` — Base Mid Q
- `gt_BaseMidSetup` — Base Mid Setup
- `gt_BaseMidCinematic` — Base Mid Cinematic
- `gt_BaseMidCinematicEnd` — Base Mid Cinematic End
- `gt_BaseMidCleanup` — Base Mid Cleanup
- `gt_PrisonersMidQ` — Prisoners-Mid Q
- `gt_PrisonersMidSetup` — Prisoners-Mid Setup
- `gt_PrisonersMidCinematic` — Prisoners-Mid Cinematic
- `gt_PrisonersMidCinematicEnd` — Prisoners-Mid Cinematic End
- `gt_PrisonersMidCleanup` — Prisoners-Mid Cleanup
- `gt_MothershipMidQ` — Mothership-Mid Q
- `gt_MothershipMidQAltermate` — Mothership-Mid Q Altermate
- `gt_MothershipMidSetup` — Mothership-Mid Setup
- `gt_MothershipMidCinematic` — Mothership-Mid Cinematic
- `gt_MothershipMidCinematicEnd` — Mothership-Mid Cinematic End
- `gt_MothershipMidCleanup` — Mothership-Mid Cleanup
- `gt_MothershipMidVault` — Mothership Mid Vault
- `gt_MothershipMidArrival` — Mothership Mid Arrival
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

