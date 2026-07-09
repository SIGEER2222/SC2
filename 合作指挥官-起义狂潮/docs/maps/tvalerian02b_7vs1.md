# tvalerian02b_7vs1(天崩地坼)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/tvalerian02b_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 7236 |
| 触发器总数(gt_*_Func) | 127 |
| 全局变量数(gv_) | 92 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`LibA070801C`、`Lib67C0F0E7`、`LibE0EAE146` |
| 起始晶体矿 | 350 |
| 起始高能瓦斯 | 250 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 31 |
| `region` | 13 |
| `bool` | 11 |
| `unitgroup` | 9 |
| `fixed` | 6 |
| `timer` | 6 |
| `revealer` | 3 |
| `unit` | 3 |
| `point[]` | 2 |
| `playergroup` | 1 |
| `gs_RECORD_UnitArea01[]` | 1 |
| `gs_RECORD_UnitArea02[]` | 1 |
| `gs_RECORD_UnitArea03[]` | 1 |
| `gs_RECORD_UnitArea04[]` | 1 |
| `point` | 1 |
| `unitgroup[]` | 1 |
| `actor` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(90 个):

- `int gv_pLAYER_P01_USER`
- `int gv_pLAYER_P02_COOLANT_TOWERS`
- `int gv_pLAYER_P03_LEVIATHANBROOD`
- `int gv_pLAYER_P04_BLIGHTSPREADERS`
- `int gv_pLAYER_P05_ZERG_GRENDEL`
- `int gv_pLAYER_P06_JORMUNGAND`
- `int gv_pLAYER_P07_RAVAGINGSWARM`
- `int gv_pLAYER_P08_MUTALISK_TOWERS`
- `int gv_pLAYER_P09_HORNER`
- `int gv_pLAYER_P10_LEVIATHAN`
- `int gv_pLAYER_P11_PLATFORM_PIECES`
- `int gv_pLAYER_P12_GARM`
- `int gv_pLAYER_P13_SKYWINGS`
- `int gv_pLAYER_P14_DOMINIONFLEET`
- `int gv_pLAYER_P15_AERIALSWARMS`
- `revealer gv_startingMapRevealer`
- `unitgroup gv_hiddenUnits`
- `unitgroup gv_pATHINGBLOCKERAREA01`
- `unitgroup gv_pATHINGBLOCKERAREA02`
- `unitgroup gv_pATHINGBLOCKERAREA03`
- `unitgroup gv_pATHINGBLOCKERAREA04`
- `bool gv_midCinePlayed`
- `int gv_fleetLinesGiven`
- `fixed gv_leviathanMaxLife`
- `fixed gv_leviathanMaxEnergy`
- `playergroup gv_zergPlayers`
- `timer gv_platformDelayTimer`
- `gs_RECORD_UnitArea01[] gv_unitsArea01`
- `gs_RECORD_UnitArea02[] gv_unitsArea02`
- `gs_RECORD_UnitArea03[] gv_unitsArea03`
- `gs_RECORD_UnitArea04[] gv_unitsArea04`
- `int gv_numberOfUnitsArea01`
- `int gv_numberOfUnitsArea02`
- `int gv_numberOfUnitsArea03`
- `int gv_numberOfUnitsArea04`
- `region gv_ground0`
- `region gv_ground1`
- `region gv_ground2`
- `region gv_ground3`
- `region gv_ground4`
- `region gv_ground5`
- `region gv_ground6`
- `region gv_ground7`
- `region gv_ground8`
- `region gv_ground9`
- `region gv_ground10`
- `region gv_ground11`
- `point gv_leviathanGuardArea`
- `region gv_leviathanSpawnRegion`
- `int gv_cinematicNumber`
- `timer gv_leviathanDeathWindow`
- `timer gv_platformBlowsTimerArea01`
- `timer gv_platformBlowsTimerArea02`
- `timer gv_platformBlowsTimerArea03`
- `timer gv_platformBlowsTimerArea04`
- `unit gv_leviathan`
- `unitgroup gv_leviathanMutaGroup`
- `bool gv_timerReadytoBlowArea01`
- `bool gv_timerReadytoBlowArea02`
- `bool gv_timerReadytoBlowArea03`
- `bool gv_timerReadytoBlowArea04`
- `fixed gv_cMutaRadiusCheckFast`
- `int gv_cMutaSpewSizeSlow`
- `int gv_cMutaSpewSizeFast`
- `unitgroup[] gv_mutaDefenders`
- `fixed gv_cMutaRadiusCheckSlow`
- `fixed gv_cMutaSpawnPeriodFast`
- `fixed gv_cMutaSpawnPeriodSlow`
- `int gv_mutaSpawnMax`
- `int gv_ventPing01`
- `unit gv_firstMutaSpawner`
- `point[] gv_dropWaveWaypoints`
- `point[] gv_attackWaveWaypoints`
- `int gv_attackIntensity`
- `int gv_stat_PlayerUnitsLostToPlatform`
- `int gv_stat_ZergKilledByPlatform`
- `int gv_stat_UnitsLostToEnemies`
- `int gv_allyKills`
- `actor gv_briefingTargetingCursor`
- `bool gv_midCinematicIsBusy`
- `bool gv_midPlatformsCinematicCompleted`
- `unitgroup gv_midPlatformsHiddenUnitGroup`
- `revealer gv_midPlatformsRevealer`
- `int gv_midCinematicCount`
- `bool gv_midLeviathanCinematicCompleted`
- `unitgroup gv_midLeviathanHiddenUnitGroup`
- `unit gv_leviathanCINE`
- `bool gv_victoryCinematicCompleted`
- `unitgroup gv_victoryHiddenUnitGroup`
- `revealer gv_victoryRevealer`

## 触发器清单

### 初始化(15)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03Units` — Init 03 Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingScene04` — Briefing Scene 04

### 进攻波次(9)

- `gt_LeviathanPatrolAI` — Leviathan Patrol AI
- `gt_P5GrendelAttackWaves` — P5 Grendel Attack Waves
- `gt_P4BlightspreaderAttackWaves` — P4 Blightspreader Attack Waves
- `gt_P3LeviathanAttackWaves` — P3 Leviathan Attack Waves
- `gt_P7RavagerAttackWaves` — P7 Ravager Attack Waves
- `gt_P12GarmAttackWaves` — P12 Garm Attack Waves
- `gt_P6JormungandAttackWaves` — P6 Jormungand Attack Waves
- `gt_P14DominionAttacks` — P14 Dominion Attacks
- `gt_SkywingPatrols` — Skywing Patrols

### 胜负(11)

- `gt_VictoryDestroySpacePlatformsCompleted` — Victory Destroy Space Platforms Completed
- `gt_Victory`
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

### 对白提示(18)

- `gt_Area01CoolantTowerKilledRedSouthEastQ` — Area 01 - Coolant Tower Killed - Red (South East) Q
- `gt_Area02CoolantTowerKilledGreenSouthWestQ` — Area 02 - Coolant Tower Killed - Green (South West) Q
- `gt_Area03CoolantTowerKilledPurpleNorthWestQ` — Area 03 - Coolant Tower Killed - Purple (North West) Q
- `gt_Area04CoolantTowerKilledWhiteCentralQ` — Area 04 - Coolant Tower Killed - White (Central) Q
- `gt_AirQ` — Air Q
- `gt_PlatformLinesFirstTowerQ` — Platform Lines First Tower Q
- `gt_PlatformLinesBRAQ` — Platform Lines BR - A Q
- `gt_PlatformLinesBRBQ` — Platform Lines BR - B Q
- `gt_PlatformLinesBLAQ` — Platform Lines BL - A Q
- `gt_PlatformLinesBLBQ` — Platform Lines BL - B Q
- `gt_PlatformLinesTLAQ` — Platform Lines TL - A Q
- `gt_PlatformLinesTLBQ` — Platform Lines TL - B Q
- `gt_PlatformLinesTRAQ` — Platform Lines TR - A Q
- `gt_PlatformLinesTRBQ` — Platform Lines TR - B Q
- `gt_PlatformInfestedLineQ` — Platform Infested Line Q
- `gt_ComsatStationQ` — Comsat Station Q
- `gt_MidPlatformsQ` — Mid Platforms Q
- `gt_MidLeviathanQ` — Mid Leviathan Q

### 其他(74)

- `gt_bon2`
- `gt_PeriodicAerialSwarms` — Periodic Aerial Swarms
- `gt_FullEnergyViper` — Full Energy Viper
- `gt_SpawnLeviathan` — Spawn Leviathan
- `gt_LeviathanDies` — Leviathan Dies
- `gt_Area01Kaboom` — Area 01 - Kaboom!
- `gt_Area02Kaboom` — Area 02 - Kaboom!
- `gt_Area03Kaboom` — Area 03 - Kaboom!
- `gt_Area04Kaboom` — Area 04 - Kaboom!
- `gt_Area01MoneyPickUps` — Area 01 Money Pick Ups
- `gt_Area02MoneyPickUps` — Area 02 Money Pick Ups
- `gt_Area03MoneyPickUps` — Area 03 Money Pick Ups
- `gt_Area04MoneyPickUps` — Area 04 Money Pick Ups
- `gt_CreateBlockersArea01`
- `gt_CreateBlockersArea02`
- `gt_CreateBlockersArea03`
- `gt_CreateBlockersArea04`
- `gt_SuicideMutalisks` — Suicide Mutalisks
- `gt_StartMutaSpawners` — Start Muta Spawners
- `gt_CatchtheMutaPart1` — Catch the Muta, Part 1
- `gt_CatchtheMutaPart2` — Catch the Muta, Part 2
- `gt_MutaSpawnersN3` — Muta Spawners N3
- `gt_MutaSpawnersN7` — Muta Spawners N7
- `gt_MutaSpawnersN16` — Muta Spawners N16
- `gt_MutaSpawnersN18` — Muta Spawners N18
- `gt_MutaSpawnersN20` — Muta Spawners N20
- `gt_MutaSpawnersH1` — Muta Spawners H1
- `gt_MutaSpawnersH2` — Muta Spawners H2
- `gt_MutaSpawnersI5` — Muta Spawners I5
- `gt_MutaSpawnersI6` — Muta Spawners I6
- `gt_MutaSpawnersN6` — Muta Spawners N6
- `gt_MutaSpawnersN12` — Muta Spawners N12
- `gt_MutaSpawnersN15` — Muta Spawners N15
- `gt_MutaSpawnersN17` — Muta Spawners N17
- `gt_MutaSpawnersI1` — Muta Spawners I1
- `gt_MutaSpawnersI4` — Muta Spawners I4
- `gt_MutaSpawnersN5` — Muta Spawners N5
- `gt_MutaSpawnersN9` — Muta Spawners N9
- `gt_MutaSpawnersN10` — Muta Spawners N10
- `gt_MutaSpawnersN14` — Muta Spawners N14
- `gt_MutaSpawnersN23` — Muta Spawners N23
- `gt_MutaSpawnersI2` — Muta Spawners I2
- `gt_MutaSpawnersI3` — Muta Spawners I3
- `gt_ComsatStationQ2` — Comsat Station Q 2
- `gt_ComsatStationQ3` — Comsat Station Q 3
- `gt_PlatformInfoSafetyDelay` — Platform Info Safety Delay
- `gt_StartAI` — Start AI
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_DominionForward1` — Dominion Forward 1
- `gt_DominionForward2` — Dominion Forward 2
- `gt_DominionForward3` — Dominion Forward 3
- `gt_DominionReinforce1` — Dominion Reinforce 1
- `gt_DominionReinforce2` — Dominion Reinforce 2
- `gt_DominionReinforce3` — Dominion Reinforce 3
- `gt_BunkerRefill` — Bunker Refill
- `gt_StatUnitsLosttoEnemies` — Stat - Units Lost to Enemies
- `gt_AllyKills` — Ally Kills
- `gt_MidPlatformsSetup` — Mid Platforms Setup
- `gt_MidPlatformsCinematic` — Mid Platforms Cinematic
- `gt_MidPlatformsCinematicEnd` — Mid Platforms Cinematic End
- `gt_MidPlatformsCleanup` — Mid Platforms Cleanup
- `gt_CreepArea01BR` — Creep Area 01 - BR
- `gt_CreepArea02BL` — Creep Area 02 - BL
- `gt_CreepArea03TL` — Creep Area 03 - TL
- `gt_CreepArea04TR` — Creep Area 04 - TR
- `gt_FinalCinematicPlatformLinesBR` — Final Cinematic Platform Lines BR
- `gt_FinalCinematicPlatformLinesBL` — Final Cinematic Platform Lines BL
- `gt_FinalCinematicPlatformLinesTL` — Final Cinematic Platform Lines TL
- `gt_FinalCinematicPlatformLinesTR` — Final Cinematic Platform Lines TR
- `gt_MidLeviathanSetup` — Mid Leviathan Setup
- `gt_MidLeviathanCinematic` — Mid Leviathan Cinematic
- `gt_MidLeviathanCinematicEnd` — Mid Leviathan Cinematic End
- `gt_MidLeviathanCleanup` — Mid Leviathan Cleanup
- `gt_RemoveUnits` — Remove Units

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 117 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_bon2`
- `gt_Area01CoolantTowerKilledRedSouthEastQ` — Area 01 - Coolant Tower Killed - Red (South East) Q
- `gt_Area02CoolantTowerKilledGreenSouthWestQ` — Area 02 - Coolant Tower Killed - Green (South West) Q
- `gt_Area03CoolantTowerKilledPurpleNorthWestQ` — Area 03 - Coolant Tower Killed - Purple (North West) Q
- `gt_Area04CoolantTowerKilledWhiteCentralQ` — Area 04 - Coolant Tower Killed - White (Central) Q
- `gt_AirQ` — Air Q
- `gt_PeriodicAerialSwarms` — Periodic Aerial Swarms
- `gt_FullEnergyViper` — Full Energy Viper
- `gt_SpawnLeviathan` — Spawn Leviathan
- `gt_LeviathanPatrolAI` — Leviathan Patrol AI
- `gt_LeviathanDies` — Leviathan Dies
- `gt_Area01Kaboom` — Area 01 - Kaboom!
- `gt_Area02Kaboom` — Area 02 - Kaboom!
- `gt_Area03Kaboom` — Area 03 - Kaboom!
- `gt_Area04Kaboom` — Area 04 - Kaboom!
- `gt_Area01MoneyPickUps` — Area 01 Money Pick Ups
- `gt_Area02MoneyPickUps` — Area 02 Money Pick Ups
- `gt_Area03MoneyPickUps` — Area 03 Money Pick Ups
- `gt_Area04MoneyPickUps` — Area 04 Money Pick Ups
- `gt_CreateBlockersArea01`
- `gt_CreateBlockersArea02`
- `gt_CreateBlockersArea03`
- `gt_CreateBlockersArea04`
- `gt_SuicideMutalisks` — Suicide Mutalisks
- `gt_StartMutaSpawners` — Start Muta Spawners
- `gt_CatchtheMutaPart1` — Catch the Muta, Part 1
- `gt_CatchtheMutaPart2` — Catch the Muta, Part 2
- `gt_MutaSpawnersN3` — Muta Spawners N3
- `gt_MutaSpawnersN7` — Muta Spawners N7
- `gt_MutaSpawnersN16` — Muta Spawners N16
- `gt_MutaSpawnersN18` — Muta Spawners N18
- `gt_MutaSpawnersN20` — Muta Spawners N20
- `gt_MutaSpawnersH1` — Muta Spawners H1
- `gt_MutaSpawnersH2` — Muta Spawners H2
- `gt_MutaSpawnersI5` — Muta Spawners I5
- `gt_MutaSpawnersI6` — Muta Spawners I6
- `gt_MutaSpawnersN6` — Muta Spawners N6
- `gt_MutaSpawnersN12` — Muta Spawners N12
- `gt_MutaSpawnersN15` — Muta Spawners N15
- `gt_MutaSpawnersN17` — Muta Spawners N17
- `gt_MutaSpawnersI1` — Muta Spawners I1
- `gt_MutaSpawnersI4` — Muta Spawners I4
- `gt_MutaSpawnersN5` — Muta Spawners N5
- `gt_MutaSpawnersN9` — Muta Spawners N9
- `gt_MutaSpawnersN10` — Muta Spawners N10
- `gt_MutaSpawnersN14` — Muta Spawners N14
- `gt_MutaSpawnersN23` — Muta Spawners N23
- `gt_MutaSpawnersI2` — Muta Spawners I2
- `gt_MutaSpawnersI3` — Muta Spawners I3
- `gt_PlatformLinesFirstTowerQ` — Platform Lines First Tower Q
- `gt_PlatformLinesBRAQ` — Platform Lines BR - A Q
- `gt_PlatformLinesBRBQ` — Platform Lines BR - B Q
- `gt_PlatformLinesBLAQ` — Platform Lines BL - A Q
- `gt_PlatformLinesBLBQ` — Platform Lines BL - B Q
- `gt_PlatformLinesTLAQ` — Platform Lines TL - A Q
- `gt_PlatformLinesTLBQ` — Platform Lines TL - B Q
- `gt_PlatformLinesTRAQ` — Platform Lines TR - A Q
- `gt_PlatformLinesTRBQ` — Platform Lines TR - B Q
- `gt_PlatformInfestedLineQ` — Platform Infested Line Q
- `gt_ComsatStationQ` — Comsat Station Q
- `gt_ComsatStationQ2` — Comsat Station Q 2
- `gt_ComsatStationQ3` — Comsat Station Q 3
- `gt_PlatformInfoSafetyDelay` — Platform Info Safety Delay
- `gt_StartAI` — Start AI
- `gt_P5GrendelAttackWaves` — P5 Grendel Attack Waves
- `gt_P4BlightspreaderAttackWaves` — P4 Blightspreader Attack Waves
- `gt_P3LeviathanAttackWaves` — P3 Leviathan Attack Waves
- `gt_P7RavagerAttackWaves` — P7 Ravager Attack Waves
- `gt_P12GarmAttackWaves` — P12 Garm Attack Waves
- `gt_P6JormungandAttackWaves` — P6 Jormungand Attack Waves
- `gt_P14DominionAttacks` — P14 Dominion Attacks
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_DominionForward1` — Dominion Forward 1
- `gt_DominionForward2` — Dominion Forward 2
- `gt_DominionForward3` — Dominion Forward 3
- `gt_DominionReinforce1` — Dominion Reinforce 1
- `gt_DominionReinforce2` — Dominion Reinforce 2
- `gt_DominionReinforce3` — Dominion Reinforce 3
- `gt_SkywingPatrols` — Skywing Patrols
- `gt_BunkerRefill` — Bunker Refill
- `gt_StatUnitsLosttoEnemies` — Stat - Units Lost to Enemies
- `gt_AllyKills` — Ally Kills
- `gt_VictoryDestroySpacePlatformsCompleted` — Victory Destroy Space Platforms Completed
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingScene04` — Briefing Scene 04
- `gt_MidPlatformsQ` — Mid Platforms Q
- `gt_MidPlatformsSetup` — Mid Platforms Setup
- `gt_MidPlatformsCinematic` — Mid Platforms Cinematic
- `gt_MidPlatformsCinematicEnd` — Mid Platforms Cinematic End
- `gt_MidPlatformsCleanup` — Mid Platforms Cleanup
- `gt_CreepArea01BR` — Creep Area 01 - BR
- `gt_CreepArea02BL` — Creep Area 02 - BL
- `gt_CreepArea03TL` — Creep Area 03 - TL
- `gt_CreepArea04TR` — Creep Area 04 - TR
- `gt_FinalCinematicPlatformLinesBR` — Final Cinematic Platform Lines BR
- `gt_FinalCinematicPlatformLinesBL` — Final Cinematic Platform Lines BL
- `gt_FinalCinematicPlatformLinesTL` — Final Cinematic Platform Lines TL
- `gt_FinalCinematicPlatformLinesTR` — Final Cinematic Platform Lines TR
- `gt_MidLeviathanQ` — Mid Leviathan Q
- `gt_MidLeviathanSetup` — Mid Leviathan Setup
- `gt_MidLeviathanCinematic` — Mid Leviathan Cinematic
- `gt_MidLeviathanCinematicEnd` — Mid Leviathan Cinematic End
- `gt_MidLeviathanCleanup` — Mid Leviathan Cleanup
- `gt_RemoveUnits` — Remove Units
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

