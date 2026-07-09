# thorner01_7vs1(火车大劫案)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/thorner01_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 5618 |
| 触发器总数(gt_*_Func) | 90 |
| 全局变量数(gv_) | 58 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`LibA070801C`、`Lib67C0F0E7`、`LibE0EAE146` |
| 起始晶体矿 | 200 |
| 起始高能瓦斯 | 200 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 32 |
| `bool` | 8 |
| `fixed` | 4 |
| `unitgroup` | 4 |
| `int[]` | 2 |
| `unit` | 2 |
| `playergroup` | 1 |
| `gs_RECORD_Train[]` | 1 |
| `point[]` | 1 |
| `timer` | 1 |
| `gs_RECORD_TrainStation[]` | 1 |
| `gs_RECORD_Charger[]` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(56 个):

- `int gv_pLAYER_01_USER`
- `int gv_pLAYER_02_DOMINION`
- `int gv_pLAYER_03_DOMINION`
- `int gv_pLAYER_04_DOMINION`
- `int gv_pLAYER_05_ABANDONEDVEHICLES`
- `int gv_pLAYER_06_TRAIN`
- `int gv_pLAYER_07_DEFILERBONESAMPLE`
- `int gv_pLAYER_08_GRENDEL`
- `int gv_pLAYER_09_GARM`
- `int gv_pLAYER_10_LEVIATHAN`
- `int gv_pLAYER_11_DOMINIONHEAVIES`
- `fixed gv_tRAIN_CAR_SEPERATION`
- `fixed gv_tRAIN_RADIUS`
- `playergroup gv_dominionPlayerGroup`
- `int gv_trainsNeeded`
- `gs_RECORD_Train[] gv_trainList`
- `int gv_numberOfTrains`
- `point[] gv_trainPath`
- `int[] gv_trainMinerals`
- `int gv_trainGas`
- `int gv_currentWave`
- `int gv_trainsDestroyed`
- `timer gv_nextTrainTimer`
- `int gv_nextTrainWindow`
- `fixed gv_trainWaveWait`
- `int[] gv_tunnelOrder`
- `int gv_currentTunnel`
- `int gv_alternateTrain`
- `unit gv_trainCarToAnimate`
- `fixed gv_trainCarToAnimateBreakPoint`
- `unit gv_trainCarToPing`
- `int gv_trainsSpawned`
- `int gv_midStart`
- `int gv_bottomStart`
- `int gv_numberOfTrainPathPoints`
- `bool gv_firstTrainSpawned`
- `int gv_trainToBeEscorted`
- `int gv_trainBossBarIndex`
- `gs_RECORD_TrainStation[] gv_trainStations`
- `int gv_numberOfTrainStations`
- `int gv_currentTrainStationGlobal`
- `gs_RECORD_Charger[] gv_chargers`
- `int gv_numberOfChargers`
- `unitgroup gv_patrolTop`
- `unitgroup gv_patrolBottom`
- `unitgroup gv_patrolSingle`
- `int gv_stackKillerSize`
- `int gv_stackKillerNumRespawn`
- `bool gv_patrolWaveSpawnedTop`
- `bool gv_patrolWaveSpawnedBottom`
- `bool gv_patrolWaveSpawnedSingle`
- `int gv_achievementMaraudersKilled`
- `bool gv_sCVTrained`
- `int gv_mineKills`
- `bool gv_victoryCinematicCompleted`
- `unitgroup gv_victoryHiddenUnitGroup`

## 触发器清单

### 初始化(16)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03Units` — Init 03 Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulty` — Init 06 Difficulty
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_InitializeTrainStations` — Initialize Train Stations
- `gt_InitializeChargers` — Initialize Chargers
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene00TrainSpawn` — Briefing Scene 00 Train Spawn
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02

### 进攻波次(11)

- `gt_TrainWaveController` — Train Wave Controller
- `gt_DominionAttackQ` — Dominion Attack Q
- `gt_P2Attack`
- `gt_P3Attack`
- `gt_P4Attack`
- `gt_PatrolWavesTop` — Patrol Waves Top
- `gt_PatrolWavesBottom` — Patrol Waves Bottom
- `gt_P8GrendelAttackWaves` — P8 Grendel Attack Waves
- `gt_P9GarmAttackWaves` — P9 Garm Attack Waves
- `gt_P10LeviathanAttackWaves` — P10 Leviathan Attack Waves
- `gt_PatrolPings` — Patrol Pings

### 胜负(13)

- `gt_VictoryAllTrainsDead` — Victory - All Trains Dead
- `gt_Victory`
- `gt_DefeatBaseDead` — Defeat - Base Dead
- `gt_DefeatTooManyTrainsMissed` — Defeat - Too Many Trains Missed
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCapsuleAnimation` — Victory Capsule Animation
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

### 对白提示(13)

- `gt_TrainDeathQ` — Train Death Q
- `gt_TrainSpawnQ` — Train Spawn Q
- `gt_NewTrainMechanicTransmissions` — New Train Mechanic Transmissions
- `gt_StackKillerQ` — Stack Killer Q
- `gt_LightEscortsQ` — Light Escorts Q
- `gt_TurbochargedQ` — Turbocharged Q
- `gt_HeavyEscortsQ` — Heavy Escorts Q
- `gt_DominionBunkerQ` — Dominion Bunker Q
- `gt_UncleanOnesQ` — Unclean Ones Q
- `gt_KillFirstTrainQ` — Kill First Train Q
- `gt_Train1MissedQ` — Train 1 Missed Q
- `gt_Train2MissedQ` — Train 2 Missed Q
- `gt_DiamondbacksRescuedQ` — Diamondbacks Rescued Q

### 其他(37)

- `gt_bon1Set`
- `gt_Bon1`
- `gt_Bon2`
- `gt_TrainPathInitialization` — Train Path Initialization
- `gt_TrainInitialization` — Train Initialization
- `gt_TrainEscorts2veryweakescorts` — Train Escorts 2 - very weak escorts
- `gt_TrainEscorts3lightescorts` — Train Escorts 3 - light escorts
- `gt_TrainEscorts4Duo1Escorts` — Train Escorts 4 - Duo 1 Escorts
- `gt_TrainEscorts5strongerescorts` — Train Escorts 5 - stronger escorts
- `gt_TrainEscorts67superfastescortsInsaneOnly` — Train Escorts 6 & 7 - super fast escorts (Insane Only)
- `gt_TrainEscortsDuo2` — Train Escorts - Duo 2
- `gt_TrainEscorts8heavyescorts` — Train Escorts 8 - heavy escorts
- `gt_SpawnTrains` — Spawn Trains
- `gt_SpawnEscorts` — Spawn Escorts
- `gt_TrainMovement` — Train Movement
- `gt_TrainTimerWindow` — Train Timer Window
- `gt_TrainBossBar` — Train Boss Bar
- `gt_TrainDespawn` — Train Despawn
- `gt_EscortDespawn` — Escort Despawn
- `gt_TrainCarDamageAnimationController` — Train Car Damage Animation Controller
- `gt_TrainCarPingController` — Train Car Ping Controller
- `gt_TrainStationController` — Train Station Controller
- `gt_ChargePulseController` — Charge Pulse Controller
- `gt_ActivateStation` — Activate Station
- `gt_DeactivateStation` — Deactivate Station
- `gt_TrainSpawnAnimations` — Train Spawn Animations
- `gt_TrainDespawnAnimationsTop` — Train Despawn Animations Top
- `gt_TrainDespawnAnimationsMid` — Train Despawn Animations Mid
- `gt_TrainDespawnAnimationsBottom` — Train Despawn Animations Bottom
- `gt_ResourcePalletPickups` — Resource Pallet Pickups
- `gt_RevealBottomLane` — Reveal Bottom Lane
- `gt_RevealMiddleLane` — Reveal Middle Lane
- `gt_RevealTopLane` — Reveal Top Lane
- `gt_StartAI` — Start AI
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_AchievementSCVTrained` — Achievement - SCV Trained
- `gt_KillswithMines` — Kills with Mines

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 80 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulty` — Init 06 Difficulty
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_bon1Set`
- `gt_Bon1`
- `gt_Bon2`
- `gt_TrainPathInitialization` — Train Path Initialization
- `gt_TrainInitialization` — Train Initialization
- `gt_TrainEscorts2veryweakescorts` — Train Escorts 2 - very weak escorts
- `gt_TrainEscorts3lightescorts` — Train Escorts 3 - light escorts
- `gt_TrainEscorts4Duo1Escorts` — Train Escorts 4 - Duo 1 Escorts
- `gt_TrainEscorts5strongerescorts` — Train Escorts 5 - stronger escorts
- `gt_TrainEscorts67superfastescortsInsaneOnly` — Train Escorts 6 & 7 - super fast escorts (Insane Only)
- `gt_TrainEscortsDuo2` — Train Escorts - Duo 2
- `gt_TrainEscorts8heavyescorts` — Train Escorts 8 - heavy escorts
- `gt_TrainWaveController` — Train Wave Controller
- `gt_SpawnTrains` — Spawn Trains
- `gt_SpawnEscorts` — Spawn Escorts
- `gt_TrainMovement` — Train Movement
- `gt_TrainTimerWindow` — Train Timer Window
- `gt_TrainBossBar` — Train Boss Bar
- `gt_TrainDeathQ` — Train Death Q
- `gt_TrainDespawn` — Train Despawn
- `gt_EscortDespawn` — Escort Despawn
- `gt_TrainCarDamageAnimationController` — Train Car Damage Animation Controller
- `gt_TrainCarPingController` — Train Car Ping Controller
- `gt_InitializeTrainStations` — Initialize Train Stations
- `gt_InitializeChargers` — Initialize Chargers
- `gt_TrainStationController` — Train Station Controller
- `gt_ChargePulseController` — Charge Pulse Controller
- `gt_ActivateStation` — Activate Station
- `gt_DeactivateStation` — Deactivate Station
- `gt_TrainSpawnAnimations` — Train Spawn Animations
- `gt_TrainDespawnAnimationsTop` — Train Despawn Animations Top
- `gt_TrainDespawnAnimationsMid` — Train Despawn Animations Mid
- `gt_TrainDespawnAnimationsBottom` — Train Despawn Animations Bottom
- `gt_ResourcePalletPickups` — Resource Pallet Pickups
- `gt_RevealBottomLane` — Reveal Bottom Lane
- `gt_RevealMiddleLane` — Reveal Middle Lane
- `gt_RevealTopLane` — Reveal Top Lane
- `gt_TrainSpawnQ` — Train Spawn Q
- `gt_NewTrainMechanicTransmissions` — New Train Mechanic Transmissions
- `gt_DominionAttackQ` — Dominion Attack Q
- `gt_StackKillerQ` — Stack Killer Q
- `gt_LightEscortsQ` — Light Escorts Q
- `gt_TurbochargedQ` — Turbocharged Q
- `gt_HeavyEscortsQ` — Heavy Escorts Q
- `gt_DominionBunkerQ` — Dominion Bunker Q
- `gt_UncleanOnesQ` — Unclean Ones Q
- `gt_KillFirstTrainQ` — Kill First Train Q
- `gt_Train1MissedQ` — Train 1 Missed Q
- `gt_Train2MissedQ` — Train 2 Missed Q
- `gt_DiamondbacksRescuedQ` — Diamondbacks Rescued Q
- `gt_StartAI` — Start AI
- `gt_P2Attack`
- `gt_P3Attack`
- `gt_P4Attack`
- `gt_PatrolWavesTop` — Patrol Waves Top
- `gt_PatrolWavesBottom` — Patrol Waves Bottom
- `gt_P8GrendelAttackWaves` — P8 Grendel Attack Waves
- `gt_P9GarmAttackWaves` — P9 Garm Attack Waves
- `gt_P10LeviathanAttackWaves` — P10 Leviathan Attack Waves
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_PatrolPings` — Patrol Pings
- `gt_AchievementSCVTrained` — Achievement - SCV Trained
- `gt_VictoryAllTrainsDead` — Victory - All Trains Dead
- `gt_KillswithMines` — Kills with Mines
- `gt_DefeatBaseDead` — Defeat - Base Dead
- `gt_DefeatTooManyTrainsMissed` — Defeat - Too Many Trains Missed
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene00TrainSpawn` — Briefing Scene 00 Train Spawn
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCapsuleAnimation` — Victory Capsule Animation
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

