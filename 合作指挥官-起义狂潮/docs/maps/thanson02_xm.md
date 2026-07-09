# thanson02_xm(大爆发(xm 变体))

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/thanson02_xm.SC2Map` |
| 类型 | xm变体 |
| MapScript.galaxy 行数 | 5606 |
| 触发器总数(gt_*_Func) | 98 |
| 全局变量数(gv_) | 81 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`Lib67C0F0E7`、`LibE0EAE146` |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `bool` | 27 |
| `int` | 26 |
| `unitgroup` | 7 |
| `unit` | 5 |
| `fixed` | 5 |
| `timer` | 3 |
| `actor` | 2 |
| `region` | 2 |
| `int[]` | 1 |
| `unit[]` | 1 |
| `fixed[]` | 1 |
| `playergroup` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(79 个):

- `int gv_pLAYER_01_USER`
- `int gv_pLAYER_02_REFUGEES`
- `int gv_pLAYER_03_INFESTED_REFUGEES`
- `int gv_pLAYER_04_INFESTEDREFUGEES`
- `int gv_pLAYER_05_REFUGEES`
- `int gv_pLAYER_06_INFESTORS`
- `int gv_pLAYER_07_MILITIA`
- `int gv_pLAYER_08_SWANN`
- `int gv_pLAYER_09_BLIGHTSPREADERS`
- `int[] gv_infestableStructuresPings`
- `unitgroup gv_infestedStructureGroup`
- `unit[] gv_infestableStructure`
- `fixed[] gv_infestableStructureHealth`
- `int gv_infestableStructureSize`
- `unit gv_mainInfestor`
- `unit gv_infestor1`
- `unit gv_infestor2`
- `unitgroup gv_infestorGroup`
- `playergroup gv_zergPlayerGroup`
- `int gv_night`
- `int gv_day`
- `int gv_timeOfDay`
- `fixed gv_dAY_DURATION`
- `fixed gv_nIGHT_DURATION`
- `timer gv_mainTimer`
- `int gv_mainTimerWindow`
- `timer gv_transitionToDay`
- `timer gv_transitionToNight`
- `unitgroup gv_infestorAggressionInhibitor`
- `int gv_infestorPing01`
- `int gv_infestorPing02`
- `int gv_infestedMarineQty`
- `int gv_infestedTerranQty`
- `int gv_hunterlingQty`
- `int gv_bansheeQty`
- `int gv_spawnCooldown`
- `actor gv_structureSelectionActor`
- `bool gv_nightReactionThrottle`
- `int gv_reactionCounter`
- `fixed gv_nightDefenderCooldown`
- `unit gv_nightDefenderPingUnit`
- `bool gv_area01Cleared`
- `bool gv_area02Cleared`
- `bool gv_area03Cleared`
- `bool gv_area04Cleared`
- `bool gv_area05Cleared`
- `bool gv_area06Cleared`
- `bool gv_area07Cleared`
- `bool gv_area08Cleared`
- `bool gv_area09Cleared`
- `bool gv_area10Cleared`
- `bool gv_area11Cleared`
- `bool gv_area01Revealed`
- `bool gv_area02Revealed`
- `bool gv_area03Revealed`
- `bool gv_area04Revealed`
- `bool gv_area05Revealed`
- `bool gv_area06Revealed`
- `bool gv_area07Revealed`
- `bool gv_area08Revealed`
- `bool gv_area09Revealed`
- `bool gv_area10Revealed`
- `bool gv_area11Revealed`
- `int gv_areasCleared`
- `int gv_infestedBuildingsKilled`
- `unitgroup gv_rockDestroyers`
- `fixed gv_nydusSpitPeriod`
- `fixed gv_nydusWormHP`
- `region gv_spawnNydusWormRegion`
- `region gv_nydusRegions`
- `actor gv_aberrationSelectionActor`
- `unit gv_firstSightInfestedStructure`
- `unitgroup gv_firstSightInfestedGroup`
- `bool gv_finalFive`
- `int gv_statStructuresRazedAtNight`
- `int gv_allyKills`
- `unitgroup gv_briefingCinematicUnits`
- `bool gv_victoryCinematicCompleted`
- `unitgroup gv_victoryHiddenUnitGroup`

## 触发器清单

### 初始化(23)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03Units` — Init 03 Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_InitialAttack` — Initial Attack
- `gt_IntroHellions` — Intro Hellions
- `gt_TransmissionHellionIntroQ` — Transmission - Hellion Intro Q
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene05` — Briefing Scene 05
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingScene04` — Briefing Scene 04
- `gt_BriefingScene00Infestation` — Briefing Scene 00 Infestation
- `gt_BriefingScene01Infestation2` — Briefing Scene 01 Infestation 2
- `gt_BriefingScene02InfestedUnburrow` — Briefing Scene 02 Infested Unburrow
- `gt_BriefingScene03BaseDefense` — Briefing Scene 03 Base Defense

### 进攻波次(14)

- `gt_NydusSpawnCycle` — Nydus Spawn Cycle
- `gt_SpawnNydusWorm` — Spawn Nydus Worm
- `gt_NydusPingSound` — Nydus Ping Sound
- `gt_NydusQ` — Nydus Q
- `gt_NydusWarningQ` — Nydus Warning Q
- `gt_AlliedAttackWaves` — Allied Attack Waves
- `gt_NightlyAttackWavesP03HI` — Nightly Attack Waves - P03 HI
- `gt_P03AttackWavesCleared0` — P03 Attack Waves - Cleared 0
- `gt_P03AttackWavesCleared12` — P03 Attack Waves - Cleared 1-2
- `gt_P03AttackWavesCleared34` — P03 Attack Waves - Cleared 3-4
- `gt_P03AttackWavesCleared56` — P03 Attack Waves - Cleared 5-6
- `gt_P03AttackWavesCleared78` — P03 Attack Waves - Cleared 7-8
- `gt_P03AttackWavesCleared910` — P03 Attack Waves - Cleared 9-10
- `gt_P03AttackWavesCleared11` — P03 Attack Waves - Cleared 11+

### 胜负(12)

- `gt_VictoryInfestationPurged` — Victory - Infestation Purged
- `gt_Victory`
- `gt_DefeatBaseDestroyed` — Defeat - Base Destroyed
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictoryDropships` — Victory Dropships

### 对白提示(13)

- `gt_NightDefenderReactionQ` — Night Defender Reaction Q
- `gt_TransmissionBunkerUpQ` — Transmission - Bunker Up Q
- `gt_TransmissionSouthBarricadeQ` — Transmission - South Barricade Q
- `gt_TransmissionShowRemainingInfestedStructuresQ` — Transmission - Show Remaining Infested Structures Q
- `gt_TransmissionInfestationFirstSightQ` — Transmission - Infestation First Sight Q
- `gt_TransmissionInfestedRefugeeSightedQ` — Transmission - Infested Refugee Sighted Q
- `gt_TransmissionInfestedMarineSightedQ` — Transmission - Infested Marine Sighted Q
- `gt_TransmissionAberrationSightedQ` — Transmission - Aberration Sighted Q
- `gt_TransmissionInfestorsAtNightQ` — Transmission - Infestors At Night Q
- `gt_TransmissionInfestationAreaClearQ` — Transmission - Infestation Area Clear Q
- `gt_TransmissionDayNightin30SecondsQ` — Transmission - Day/Night in 30 Seconds Q
- `gt_TransmissionDaytimeQ` — Transmission - Daytime Q
- `gt_TransmissionNightQ` — Transmission - Night Q

### 其他(36)

- `gt_FirstNight` — First Night
- `gt_MapInitialInfestation` — Map Initial Infestation
- `gt_TimerCycling` — Timer Cycling
- `gt_InfestorCycling` — Infestor Cycling
- `gt_InfestorNorthFoundEarly` — Infestor North Found Early
- `gt_InfestorSouthFoundEarly` — Infestor South Found Early
- `gt_InfestorSouth` — Infestor South
- `gt_InfestorsBurrowUnburrow` — Infestors Burrow/Unburrow
- `gt_CreatePingsWhenInfestedUnburrows` — Create Pings When Infested Unburrows
- `gt_RemovePingsWhenInfestorBurrows` — Remove Pings When Infestor Burrows
- `gt_DestroyPingsWhenInfestorKilled` — Destroy Pings When Infestor Killed
- `gt_PlayDayMusic` — Play Day Music
- `gt_PlayNightMusic` — Play Night Music
- `gt_TransitionToDay` — Transition To Day
- `gt_TransitionToNight` — Transition To Night
- `gt_SolarCombustionCheck` — Solar Combustion Check
- `gt_UpdateSpawnSettings` — Update Spawn Settings
- `gt_InfestationSpawning` — Infestation Spawning
- `gt_ShowRemainingInfestedStructures` — Show Remaining Infested Structures
- `gt_RemoveInfestedStructurePing` — Remove Infested Structure Ping
- `gt_InfestationFirstSight` — Infestation First Sight
- `gt_ClearActoronInfestedBuilding` — Clear Actor on Infested Building
- `gt_NightDefenderReaction` — Night Defender Reaction
- `gt_NightDefenderPing` — Night Defender Ping
- `gt_InfestedBuildingDies` — Infested Building Dies
- `gt_AreaRevealers` — Area Revealers
- `gt_InfestedAreasClear` — Infested Areas Clear
- `gt_InfestedAreaBullies` — Infested Area Bullies
- `gt_RefugeeBehavior` — Refugee Behavior
- `gt_DestroyBarricade` — Destroy Barricade
- `gt_RocksDestroyed` — Rocks Destroyed
- `gt_StartAI` — Start AI
- `gt_BunkerRefill` — Bunker Refill
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_StatStructuresRazedatNight` — Stat - Structures Razed at Night
- `gt_MilitiaKills` — Militia Kills

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 88 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_FirstNight` — First Night
- `gt_InitialAttack` — Initial Attack
- `gt_MapInitialInfestation` — Map Initial Infestation
- `gt_TimerCycling` — Timer Cycling
- `gt_InfestorCycling` — Infestor Cycling
- `gt_InfestorNorthFoundEarly` — Infestor North Found Early
- `gt_InfestorSouthFoundEarly` — Infestor South Found Early
- `gt_InfestorSouth` — Infestor South
- `gt_InfestorsBurrowUnburrow` — Infestors Burrow/Unburrow
- `gt_CreatePingsWhenInfestedUnburrows` — Create Pings When Infested Unburrows
- `gt_RemovePingsWhenInfestorBurrows` — Remove Pings When Infestor Burrows
- `gt_DestroyPingsWhenInfestorKilled` — Destroy Pings When Infestor Killed
- `gt_PlayDayMusic` — Play Day Music
- `gt_PlayNightMusic` — Play Night Music
- `gt_TransitionToDay` — Transition To Day
- `gt_TransitionToNight` — Transition To Night
- `gt_SolarCombustionCheck` — Solar Combustion Check
- `gt_UpdateSpawnSettings` — Update Spawn Settings
- `gt_InfestationSpawning` — Infestation Spawning
- `gt_ShowRemainingInfestedStructures` — Show Remaining Infested Structures
- `gt_RemoveInfestedStructurePing` — Remove Infested Structure Ping
- `gt_InfestationFirstSight` — Infestation First Sight
- `gt_ClearActoronInfestedBuilding` — Clear Actor on Infested Building
- `gt_NightDefenderReaction` — Night Defender Reaction
- `gt_NightDefenderPing` — Night Defender Ping
- `gt_NightDefenderReactionQ` — Night Defender Reaction Q
- `gt_InfestedBuildingDies` — Infested Building Dies
- `gt_AreaRevealers` — Area Revealers
- `gt_InfestedAreasClear` — Infested Areas Clear
- `gt_InfestedAreaBullies` — Infested Area Bullies
- `gt_IntroHellions` — Intro Hellions
- `gt_RefugeeBehavior` — Refugee Behavior
- `gt_DestroyBarricade` — Destroy Barricade
- `gt_RocksDestroyed` — Rocks Destroyed
- `gt_NydusSpawnCycle` — Nydus Spawn Cycle
- `gt_SpawnNydusWorm` — Spawn Nydus Worm
- `gt_NydusPingSound` — Nydus Ping Sound
- `gt_NydusQ` — Nydus Q
- `gt_NydusWarningQ` — Nydus Warning Q
- `gt_AlliedAttackWaves` — Allied Attack Waves
- `gt_StartAI` — Start AI
- `gt_BunkerRefill` — Bunker Refill
- `gt_NightlyAttackWavesP03HI` — Nightly Attack Waves - P03 HI
- `gt_P03AttackWavesCleared0` — P03 Attack Waves - Cleared 0
- `gt_P03AttackWavesCleared12` — P03 Attack Waves - Cleared 1-2
- `gt_P03AttackWavesCleared34` — P03 Attack Waves - Cleared 3-4
- `gt_P03AttackWavesCleared56` — P03 Attack Waves - Cleared 5-6
- `gt_P03AttackWavesCleared78` — P03 Attack Waves - Cleared 7-8
- `gt_P03AttackWavesCleared910` — P03 Attack Waves - Cleared 9-10
- `gt_P03AttackWavesCleared11` — P03 Attack Waves - Cleared 11+
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_TransmissionBunkerUpQ` — Transmission - Bunker Up Q
- `gt_TransmissionSouthBarricadeQ` — Transmission - South Barricade Q
- `gt_TransmissionShowRemainingInfestedStructuresQ` — Transmission - Show Remaining Infested Structures Q
- `gt_TransmissionHellionIntroQ` — Transmission - Hellion Intro Q
- `gt_TransmissionInfestationFirstSightQ` — Transmission - Infestation First Sight Q
- `gt_TransmissionInfestedRefugeeSightedQ` — Transmission - Infested Refugee Sighted Q
- `gt_TransmissionInfestedMarineSightedQ` — Transmission - Infested Marine Sighted Q
- `gt_TransmissionAberrationSightedQ` — Transmission - Aberration Sighted Q
- `gt_TransmissionInfestorsAtNightQ` — Transmission - Infestors At Night Q
- `gt_TransmissionInfestationAreaClearQ` — Transmission - Infestation Area Clear Q
- `gt_TransmissionDayNightin30SecondsQ` — Transmission - Day/Night in 30 Seconds Q
- `gt_TransmissionDaytimeQ` — Transmission - Daytime Q
- `gt_TransmissionNightQ` — Transmission - Night Q
- `gt_StatStructuresRazedatNight` — Stat - Structures Razed at Night
- `gt_MilitiaKills` — Militia Kills
- `gt_VictoryInfestationPurged` — Victory - Infestation Purged
- `gt_DefeatBaseDestroyed` — Defeat - Base Destroyed
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene05` — Briefing Scene 05
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingScene04` — Briefing Scene 04
- `gt_BriefingScene00Infestation` — Briefing Scene 00 Infestation
- `gt_BriefingScene01Infestation2` — Briefing Scene 01 Infestation 2
- `gt_BriefingScene02InfestedUnburrow` — Briefing Scene 02 Infested Unburrow
- `gt_BriefingScene03BaseDefense` — Briefing Scene 03 Base Defense
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictoryDropships` — Victory Dropships

