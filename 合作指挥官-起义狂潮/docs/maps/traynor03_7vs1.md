# traynor03_7vs1(零点行动)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/traynor03_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 5846 |
| 触发器总数(gt_*_Func) | 111 |
| 全局变量数(gv_) | 44 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`LibA070801C`、`Lib67C0F0E7`、`LibE0EAE146` |
| 起始晶体矿 | 400 |
| 起始高能瓦斯 | 100 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 18 |
| `timer` | 10 |
| `unit` | 8 |
| `playergroup` | 3 |
| `bool` | 3 |
| `unitgroup` | 2 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(42 个):

- `unit gv_artifactTruck`
- `int gv_pLAYER01_USER`
- `int gv_pLAYER02_ZERG`
- `int gv_pLAYER03_ZERG`
- `int gv_pLAYER04_ZERG`
- `int gv_pLAYER05_ZERG_NOAI`
- `int gv_pLAYER14_ZERG_RAVAGERS`
- `int gv_pLAYER06_REBELS`
- `int gv_pLAYER07_HYPERION`
- `int gv_pLAYER08_TAUREN`
- `int gv_pLAYER09_COLONISTS`
- `int gv_pLAYER10_DOMINIONRED`
- `int gv_pLAYER11_DOMINIONORANGE`
- `int gv_pLAYER12_DOMINIONLIGHTBLUE`
- `int gv_pLAYER13_DOMINIONBROWN`
- `playergroup gv_zergPlayers`
- `playergroup gv_dominionPlayers`
- `playergroup gv_enemyPlayers`
- `unit gv_nydusWormP02`
- `unit gv_nydusWormP03`
- `unit gv_nydusWormP04`
- `timer gv_dropPodExpansion1`
- `timer gv_dropPodExpansion2`
- `timer gv_dropPodExpansion3`
- `timer gv_dropPodExpansion4`
- `unitgroup gv_bullhornLightsGroup`
- `unit gv_rebelMarinesBeacon01`
- `unit gv_rebelMarinesBeacon02`
- `unit gv_rebelMarinesBeacon03`
- `timer gv_zergFirstAttackWaveTimer`
- `timer gv_tenMinuteWarning`
- `timer gv_fiveMinuteWarning`
- `timer gv_twoMinuteWarning`
- `timer gv_oneMinuteWarning`
- `timer gv_evacuationTimer`
- `int gv_evacuationTimerWindow`
- `int gv_hatcheriesDestroyed`
- `int gv_rebelFightersRescued`
- `int gv_structuresLostAndSalvaged`
- `unit gv_victoryHyperion`
- `bool gv_victoryCinematicCompleted`
- `unitgroup gv_victoryRemovedUnitGroup`

## 触发器清单

### 初始化(20)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03Units` — Init 03 Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_RebelMarines01Intro` — Rebel Marines 01 Intro
- `gt_RebelMarines02Intro` — Rebel Marines 02 Intro
- `gt_RebelMarines03Intro` — Rebel Marines 03 Intro
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingZergSpawn` — Briefing Zerg Spawn
- `gt_BriefingDropPodsDrones` — Briefing Drop Pods - Drones
- `gt_BriefingDropPodsZerglings` — Briefing Drop Pods - Zerglings
- `gt_BriefingCleanUpZerg` — Briefing Clean Up Zerg

### 进攻波次(40)

- `gt_AlertFirstZergWave` — Alert - First Zerg Wave
- `gt_AlertZergAttackingBullhornLights` — Alert - Zerg Attacking - Bullhorn Lights
- `gt_StartDropPodTimers` — Start Drop Pod Timers
- `gt_ZergDropPodExpansion1` — Zerg Drop Pod Expansion 1
- `gt_ZergDropPodExpansion2` — Zerg Drop Pod Expansion 2
- `gt_ZergDropPodExpansion3` — Zerg Drop Pod Expansion 3
- `gt_ZergDropPodExpansion4` — Zerg Drop Pod Expansion 4
- `gt_FinalZergAttack` — Final Zerg Attack
- `gt_StartFirstZergWaveSpecial` — Start First Zerg Wave - Special
- `gt_P2Attack`
- `gt_P4Attack`
- `gt_P5Attack`
- `gt_P3AttackWaves` — P3 Attack Waves
- `gt_P2AttackStop`
- `gt_P4AttackStop`
- `gt_P5AttackStop`
- `gt_AttackWavesPurpleZergP04` — Attack Waves - Purple - Zerg P04
- `gt_BlueDropPods` — Blue Drop Pods
- `gt_RedDropPods` — Red Drop Pods
- `gt_P10AttackWaves` — P10 Attack Waves
- `gt_P11AttackWaves` — P11 Attack Waves
- `gt_P12AttackWaves` — P12 Attack Waves
- `gt_P14AttackWaves` — P14 Attack Waves
- `gt_ZergP02EarlyNydusWave` — Zerg P02 - Early Nydus Wave
- `gt_ZergP04EarlyNydusWave` — Zerg P04 - Early Nydus Wave
- `gt_ZergP02LateNydusWave` — Zerg P02 - Late Nydus Wave
- `gt_ZergP04LateNydusWave` — Zerg P04 - Late Nydus Wave
- `gt_ZergP02EndGameNydusWorms` — Zerg P02 - End Game Nydus Worms
- `gt_ZergP03EndGameNydusWorms` — Zerg P03 - End Game Nydus Worms
- `gt_ZergP04EndGameNydusWorms` — Zerg P04 - End Game Nydus Worms
- `gt_ReviveP02NydusWorm` — Revive P02 Nydus Worm
- `gt_ReviveP04NydusWorm` — Revive P04 Nydus Worm
- `gt_TransmissionFirstZergWaveIncomingQ` — Transmission - First Zerg Wave Incoming! Q
- `gt_VictoryDropPods` — Victory Drop Pods
- `gt_VictoryNydusSpawn01` — Victory Nydus - Spawn 01
- `gt_VictoryNydusSpawn02` — Victory Nydus - Spawn 02
- `gt_VictoryNydusSpawn03` — Victory Nydus - Spawn 03
- `gt_VictoryNydusSpawn04` — Victory Nydus - Spawn 04
- `gt_VictoryNydusSpawn05` — Victory Nydus - Spawn 05
- `gt_VictoryNydusSpawn06` — Victory Nydus - Spawn 06

### 胜负(17)

- `gt_VictoryHoldOutCompleted` — Victory Hold Out Completed
- `gt_VictoryZergDestroyed` — Victory Zerg Destroyed
- `gt_Victory`
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictoryQ2` — Victory Q 2
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematic3` — Victory Cinematic 3
- `gt_VictoryCinematic2` — Victory Cinematic 2
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictoryBridgeZerg` — Victory Bridge Zerg
- `gt_VictoryMutas` — Victory Mutas

### 对白提示(12)

- `gt_SalvageBunkersDisableRetreatTransmission` — Salvage Bunkers - Disable Retreat Transmission
- `gt_TransmissionCallForRetreatQ` — Transmission - Call For Retreat Q
- `gt_TransmissionTychusIncomingAirUnitsQ` — Transmission - Tychus - Incoming Air Units Q
- `gt_TransmissionRebelMarines01MaydayQ` — Transmission - Rebel Marines 01 Mayday! Q
- `gt_TransmissionRebelMarines02MaydayQ` — Transmission - Rebel Marines 02  Mayday! Q
- `gt_TransmissionRebelMarines03MaydayQ` — Transmission - Rebel Marines 03 Mayday! Q
- `gt_TransmissionRebelMarines01RescuedQ` — Transmission - Rebel Marines 01 Rescued Q
- `gt_TransmissionRebelMarines02RescuedQ` — Transmission - Rebel Marines 02  Rescued Q
- `gt_TransmissionRebelMarines03RescuedQ` — Transmission - Rebel Marines 03 Rescued Q
- `gt_Transmission10MinuteWarningQ` — Transmission - 10 Minute Warning Q
- `gt_Transmission5MinuteWarningQ` — Transmission - 5 Minute Warning Q
- `gt_TransmissionLastMinuteQ` — Transmission - Last Minute Q

### 其他(22)

- `gt_Obj2`
- `gt_BurrowAmbushGlobalTrigger` — Burrow Ambush Global Trigger
- `gt_SpineCrawlerIncursion1` — Spine Crawler Incursion 1
- `gt_SpineCrawlerIncursion2` — Spine Crawler Incursion 2
- `gt_SpineCrawlerIncursion3` — Spine Crawler Incursion 3
- `gt_TransitiontoDawn` — Transition to Dawn
- `gt_TaurenMarineSighted` — Tauren Marine Sighted
- `gt_TaurenOuthouseLaunch` — Tauren Outhouse Launch
- `gt_StrandedRebelMarinesTiming` — Stranded Rebel Marines Timing
- `gt_RebelMarines01Rescued` — Rebel Marines 01 Rescued
- `gt_RebelMarines02Rescued` — Rebel Marines 02 Rescued
- `gt_RebelMarines03Rescued` — Rebel Marines 03 Rescued
- `gt_RebelMarines01Dead` — Rebel Marines 01 Dead
- `gt_RebelMarines02Dead` — Rebel Marines 02 Dead
- `gt_RebelMarines03Dead` — Rebel Marines 03 Dead
- `gt_StartTimers` — Start Timers
- `gt_StartAI` — Start AI
- `gt_CancelRedBullies` — Cancel Red Bullies
- `gt_AIUpgradesNormal` — AI Upgrades Normal
- `gt_AIUpgradesHard` — AI Upgrades Hard
- `gt_AIUpgradesBrutal` — AI Upgrades Brutal
- `gt_TIming`

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 101 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_Obj2`
- `gt_BurrowAmbushGlobalTrigger` — Burrow Ambush Global Trigger
- `gt_AlertFirstZergWave` — Alert - First Zerg Wave
- `gt_AlertZergAttackingBullhornLights` — Alert - Zerg Attacking - Bullhorn Lights
- `gt_StartDropPodTimers` — Start Drop Pod Timers
- `gt_ZergDropPodExpansion1` — Zerg Drop Pod Expansion 1
- `gt_ZergDropPodExpansion2` — Zerg Drop Pod Expansion 2
- `gt_ZergDropPodExpansion3` — Zerg Drop Pod Expansion 3
- `gt_ZergDropPodExpansion4` — Zerg Drop Pod Expansion 4
- `gt_SpineCrawlerIncursion1` — Spine Crawler Incursion 1
- `gt_SpineCrawlerIncursion2` — Spine Crawler Incursion 2
- `gt_SpineCrawlerIncursion3` — Spine Crawler Incursion 3
- `gt_SalvageBunkersDisableRetreatTransmission` — Salvage Bunkers - Disable Retreat Transmission
- `gt_TransitiontoDawn` — Transition to Dawn
- `gt_TaurenMarineSighted` — Tauren Marine Sighted
- `gt_TaurenOuthouseLaunch` — Tauren Outhouse Launch
- `gt_StrandedRebelMarinesTiming` — Stranded Rebel Marines Timing
- `gt_RebelMarines01Intro` — Rebel Marines 01 Intro
- `gt_RebelMarines02Intro` — Rebel Marines 02 Intro
- `gt_RebelMarines03Intro` — Rebel Marines 03 Intro
- `gt_RebelMarines01Rescued` — Rebel Marines 01 Rescued
- `gt_RebelMarines02Rescued` — Rebel Marines 02 Rescued
- `gt_RebelMarines03Rescued` — Rebel Marines 03 Rescued
- `gt_RebelMarines01Dead` — Rebel Marines 01 Dead
- `gt_RebelMarines02Dead` — Rebel Marines 02 Dead
- `gt_RebelMarines03Dead` — Rebel Marines 03 Dead
- `gt_StartTimers` — Start Timers
- `gt_FinalZergAttack` — Final Zerg Attack
- `gt_StartAI` — Start AI
- `gt_StartFirstZergWaveSpecial` — Start First Zerg Wave - Special
- `gt_P2Attack`
- `gt_P4Attack`
- `gt_P5Attack`
- `gt_P3AttackWaves` — P3 Attack Waves
- `gt_P2AttackStop`
- `gt_P4AttackStop`
- `gt_P5AttackStop`
- `gt_AttackWavesPurpleZergP04` — Attack Waves - Purple - Zerg P04
- `gt_BlueDropPods` — Blue Drop Pods
- `gt_RedDropPods` — Red Drop Pods
- `gt_CancelRedBullies` — Cancel Red Bullies
- `gt_AIUpgradesNormal` — AI Upgrades Normal
- `gt_AIUpgradesHard` — AI Upgrades Hard
- `gt_AIUpgradesBrutal` — AI Upgrades Brutal
- `gt_P10AttackWaves` — P10 Attack Waves
- `gt_P11AttackWaves` — P11 Attack Waves
- `gt_P12AttackWaves` — P12 Attack Waves
- `gt_P14AttackWaves` — P14 Attack Waves
- `gt_ZergP02EarlyNydusWave` — Zerg P02 - Early Nydus Wave
- `gt_ZergP04EarlyNydusWave` — Zerg P04 - Early Nydus Wave
- `gt_ZergP02LateNydusWave` — Zerg P02 - Late Nydus Wave
- `gt_ZergP04LateNydusWave` — Zerg P04 - Late Nydus Wave
- `gt_ZergP02EndGameNydusWorms` — Zerg P02 - End Game Nydus Worms
- `gt_ZergP03EndGameNydusWorms` — Zerg P03 - End Game Nydus Worms
- `gt_ZergP04EndGameNydusWorms` — Zerg P04 - End Game Nydus Worms
- `gt_ReviveP02NydusWorm` — Revive P02 Nydus Worm
- `gt_ReviveP04NydusWorm` — Revive P04 Nydus Worm
- `gt_TransmissionCallForRetreatQ` — Transmission - Call For Retreat Q
- `gt_TransmissionFirstZergWaveIncomingQ` — Transmission - First Zerg Wave Incoming! Q
- `gt_TransmissionTychusIncomingAirUnitsQ` — Transmission - Tychus - Incoming Air Units Q
- `gt_TransmissionRebelMarines01MaydayQ` — Transmission - Rebel Marines 01 Mayday! Q
- `gt_TransmissionRebelMarines02MaydayQ` — Transmission - Rebel Marines 02  Mayday! Q
- `gt_TransmissionRebelMarines03MaydayQ` — Transmission - Rebel Marines 03 Mayday! Q
- `gt_TransmissionRebelMarines01RescuedQ` — Transmission - Rebel Marines 01 Rescued Q
- `gt_TransmissionRebelMarines02RescuedQ` — Transmission - Rebel Marines 02  Rescued Q
- `gt_TransmissionRebelMarines03RescuedQ` — Transmission - Rebel Marines 03 Rescued Q
- `gt_Transmission10MinuteWarningQ` — Transmission - 10 Minute Warning Q
- `gt_Transmission5MinuteWarningQ` — Transmission - 5 Minute Warning Q
- `gt_TransmissionLastMinuteQ` — Transmission - Last Minute Q
- `gt_VictoryHoldOutCompleted` — Victory Hold Out Completed
- `gt_VictoryZergDestroyed` — Victory Zerg Destroyed
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingZergSpawn` — Briefing Zerg Spawn
- `gt_BriefingDropPodsDrones` — Briefing Drop Pods - Drones
- `gt_BriefingDropPodsZerglings` — Briefing Drop Pods - Zerglings
- `gt_BriefingCleanUpZerg` — Briefing Clean Up Zerg
- `gt_VictoryQ2` — Victory Q 2
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematic3` — Victory Cinematic 3
- `gt_VictoryCinematic2` — Victory Cinematic 2
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_TIming`
- `gt_VictoryDropPods` — Victory Drop Pods
- `gt_VictoryBridgeZerg` — Victory Bridge Zerg
- `gt_VictoryMutas` — Victory Mutas
- `gt_VictoryNydusSpawn01` — Victory Nydus - Spawn 01
- `gt_VictoryNydusSpawn02` — Victory Nydus - Spawn 02
- `gt_VictoryNydusSpawn03` — Victory Nydus - Spawn 03
- `gt_VictoryNydusSpawn04` — Victory Nydus - Spawn 04
- `gt_VictoryNydusSpawn05` — Victory Nydus - Spawn 05
- `gt_VictoryNydusSpawn06` — Victory Nydus - Spawn 06

