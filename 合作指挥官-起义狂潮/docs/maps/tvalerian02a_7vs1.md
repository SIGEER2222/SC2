# tvalerian02a_7vs1(野兽之腹)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/tvalerian02a_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 3645 |
| 触发器总数(gt_*_Func) | 79 |
| 全局变量数(gv_) | 85 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`TriggerLibs/SwarmLib`、`LibA070801C`、`Lib67C0F0E7`、`LibE0EAE146` |
| 起始晶体矿 | 500 |
| 起始高能瓦斯 | 300 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 23 |
| `unit` | 11 |
| `unitgroup` | 9 |
| `bool` | 8 |
| `point[]` | 7 |
| `fixed` | 7 |
| `actor` | 6 |
| `timer` | 5 |
| `bool[]` | 3 |
| `region` | 3 |
| `playergroup` | 1 |
| `region[]` | 1 |
| `doodad` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(83 个):

- `int gv_p1_USER`
- `int gv_p2_JORMUNGAND`
- `int gv_p3_GARM`
- `int gv_p4_DOMINIONALLIES`
- `int gv_p5_GRENDEL`
- `int gv_p6_BLIGHSPREADERS`
- `int gv_p7_RAVAGING`
- `int gv_p8_ABATHUR`
- `int gv_p9_BROODMOTHER`
- `int gv_p10_ZERG`
- `unit gv_tHEONERAYNOR`
- `unit gv_tHEONETYCHUS`
- `unit gv_tHEONESWANN`
- `unit gv_tHEONESTETMAN`
- `unit gv_tHEONEOMEGALISK`
- `unitgroup gv_nonHeroicDudes`
- `unitgroup gv__1BroodchamberAllUnits`
- `unitgroup gv__2BroodchamberAllUnits`
- `unitgroup gv__3BroodchamberAllUnits`
- `unitgroup gv__4BroodchamberAllUnits`
- `point[] gv__4LavaDoodadPositions`
- `bool[] gv__4LavaDoodadHavePlayedAnim`
- `point[] gv__4LavaNydusPositions`
- `bool[] gv__4LavaNydusHaveSpawned`
- `point[] gv__4LavaFireNydusPositions`
- `bool[] gv__4LavaFireNydusHaveSpawned`
- `timer gv_holdoutTimer`
- `int gv_holdoutTimerWindow`
- `bool gv_limitNydusWormSpawnsInHoldout`
- `playergroup gv_zergPlayers`
- `fixed gv_nydusWormHP`
- `fixed gv_queenHP`
- `fixed gv_omegaliskHP`
- `fixed gv_incapRescueRadius`
- `region[] gv_feederlingRegions`
- `int gv_interruptableTransmission`
- `fixed gv_caveAngerOriginal`
- `region gv_lowGroundEruptionRegions`
- `region gv_midGroundEruptionRegions`
- `int gv_caveIntensity`
- `fixed gv_caveAngerLevel`
- `int gv_waveSpawnCount`
- `point[] gv_northCaveSpawnPoints`
- `point[] gv_sECaveSpawnPoints`
- `point[] gv_sWCaveSpawnPoints`
- `point[] gv_broodmotherCaveSpawnPoints`
- `timer gv_caveTimer`
- `int gv_nydusSpawnCount`
- `bool gv_northNukeDetonated`
- `bool gv_sWNukeDetonated`
- `bool gv_sENukeDetonated`
- `region gv_nydusSpawnRegions`
- `fixed gv_nydusWormLife`
- `timer gv_sWDetTimer`
- `int gv_sWDetTimerWindow`
- `timer gv_sEDetTimer`
- `int gv_sEDetTimerWindow`
- `timer gv_nDetTimer`
- `int gv_nDetTimerWindow`
- `int gv_caveRampageCycle`
- `int gv_raynorSnipeKillsBest`
- `int gv_raynorSnipeKillsCurrent`
- `int gv_flamingBettyKills`
- `int gv_allyKills`
- `bool gv_cinematicCompleted`
- `actor gv_cinematicStartHoldout1Ping1`
- `actor gv_cinematicStartHoldout1Ping1a`
- `actor gv_cinematicStartHoldout1Ping2`
- `actor gv_cinematicStartHoldout1Ping2a`
- `actor gv_cinematicStartHoldout1Ping3`
- `actor gv_cinematicStartHoldout1Ping3a`
- `unit gv_cINEMATICSWANN`
- `unit gv_cINEMATICTYCHUS`
- `unit gv_cINEMATICSTETTMANN`
- `unit gv_cINEMATICRAYNOR`
- `unit gv_cINEMATIC_NukeUnit`
- `unit gv_cinematicNydusWorm`
- `unitgroup gv_cinematicActors`
- `unitgroup gv_cinematicHiddenUnitGroup`
- `unitgroup gv_cinematicReinforcements`
- `unitgroup gv_cinematicZergStrays`
- `doodad gv_cinematicFissureDoodad`
- `bool gv_briefingActionMercDismissed`

## 触发器清单

### 初始化(18)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03Units` — Init 03 Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt__1IntroSequence` — 1 Intro Sequence
- `gt__1StartGame` — 1 Start Game
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingAction02` — Briefing Action 02
- `gt_BriefingAction03` — Briefing Action 03
- `gt_BriefingAction04` — Briefing Action 04
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingCameraWork01` — Briefing Camera Work 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingScene04` — Briefing Scene 04

### 进攻波次(9)

- `gt_DestroyNydusandPrismPings` — Destroy Nydus and Prism Pings
- `gt_BroodmotherStartPatrol` — Broodmother Start Patrol
- `gt_P5GrendelAttackWaves` — P5 Grendel Attack Waves
- `gt_P6BlightspreaderAttackWaves` — P6 Blightspreader Attack Waves
- `gt_P7RavagerAttackWaves` — P7 Ravager Attack Waves
- `gt_P3GarmAttackWaves` — P3 Garm Attack Waves
- `gt_P2JormungandAttackWaves` — P2 Jormungand Attack Waves
- `gt_P8AbathurAttackWaves` — P8 Abathur Attack Waves
- `gt_P4DominionAttacks` — P4 Dominion Attacks

### 胜负(11)

- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_Victory`
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_CinematicVictorySetup` — Cinematic Victory Setup
- `gt_CinematicVictoryCinematic` — Cinematic Victory Cinematic
- `gt_CinematicVictoryAction` — Cinematic Victory Action
- `gt_CinematicVictoryCinematicEnd` — Cinematic Victory Cinematic End
- `gt_CinematicVictoryCleanup` — Cinematic Victory Cleanup

### 对白提示(8)

- `gt__1OpeningDialogueQ` — 1 Opening Dialogue Q
- `gt__2StoryTellingQ` — 2 Story Telling Q
- `gt_LavaRisingWarningQ` — Lava Rising Warning Q
- `gt_SeismicWarningQ` — Seismic Warning Q
- `gt_DominionRevealedQ` — Dominion Revealed Q
- `gt_InfestedRevealQ` — Infested Reveal  Q
- `gt_ChargePlantedQ` — Charge Planted Q
- `gt_CaveSwarmQ` — Cave Swarm Q

### 其他(33)

- `gt_bon1`
- `gt_bon2`
- `gt_DestroyPings` — Destroy Pings
- `gt_LavaRising` — Lava Rising
- `gt_CameraShakeDuringLava` — Camera Shake - During Lava
- `gt_LavaDamage` — Lava Damage
- `gt_PlantSWCharge` — Plant SW Charge
- `gt_DetonateSW` — Detonate SW
- `gt_PlantSECharge` — Plant SE Charge
- `gt_DetonateSE` — Detonate SE
- `gt_PlantNCharge` — Plant N Charge
- `gt_DetonateN` — Detonate N
- `gt_GrendelDroneReinforcements` — Grendel Drone Reinforcements
- `gt_BlightspreaderDroneReinforcements` — Blightspreader Drone Reinforcements
- `gt_JormungandDroneReinforcements` — Jormungand Drone Reinforcements
- `gt_BroodmotherReinforcements` — Broodmother Reinforcements
- `gt_DroneReinforcements` — Drone Reinforcements
- `gt_StartAI` — Start AI
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_DominionForward1` — Dominion Forward 1
- `gt_DominionForward2` — Dominion Forward 2
- `gt_DominionForward3` — Dominion Forward 3
- `gt_ZergReinforce1` — Zerg Reinforce 1
- `gt_ZergReinforce2` — Zerg Reinforce 2
- `gt_BunkerRefill` — Bunker Refill
- `gt_RaynorSnipeInitialize` — Raynor Snipe - Initialize
- `gt_RaynorSnipeUnitsKilled` — Raynor Snipe - Units Killed
- `gt_AchievementOneShotFiftyKills` — Achievement - One Shot, Fifty Kills
- `gt_AchievementBettyKill` — Achievement - Betty Kill
- `gt_AllyKills` — Ally Kills
- `gt_CinematicDeployNuke` — Cinematic Deploy Nuke
- `gt_CinematicCameraShakeNuke2` — Cinematic Fissure Death
- `gt_CinematicCameraShakeNuke` — Cinematic Nuke Camera Shake

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 69 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt__1IntroSequence` — 1 Intro Sequence
- `gt__1StartGame` — 1 Start Game
- `gt_bon1`
- `gt_bon2`
- `gt__1OpeningDialogueQ` — 1 Opening Dialogue Q
- `gt_DestroyPings` — Destroy Pings
- `gt_LavaRising` — Lava Rising
- `gt_CameraShakeDuringLava` — Camera Shake - During Lava
- `gt_LavaDamage` — Lava Damage
- `gt__2StoryTellingQ` — 2 Story Telling Q
- `gt_LavaRisingWarningQ` — Lava Rising Warning Q
- `gt_SeismicWarningQ` — Seismic Warning Q
- `gt_DestroyNydusandPrismPings` — Destroy Nydus and Prism Pings
- `gt_PlantSWCharge` — Plant SW Charge
- `gt_DetonateSW` — Detonate SW
- `gt_PlantSECharge` — Plant SE Charge
- `gt_DetonateSE` — Detonate SE
- `gt_PlantNCharge` — Plant N Charge
- `gt_DetonateN` — Detonate N
- `gt_GrendelDroneReinforcements` — Grendel Drone Reinforcements
- `gt_BlightspreaderDroneReinforcements` — Blightspreader Drone Reinforcements
- `gt_JormungandDroneReinforcements` — Jormungand Drone Reinforcements
- `gt_BroodmotherReinforcements` — Broodmother Reinforcements
- `gt_DroneReinforcements` — Drone Reinforcements
- `gt_BroodmotherStartPatrol` — Broodmother Start Patrol
- `gt_DominionRevealedQ` — Dominion Revealed Q
- `gt_InfestedRevealQ` — Infested Reveal  Q
- `gt_ChargePlantedQ` — Charge Planted Q
- `gt_CaveSwarmQ` — Cave Swarm Q
- `gt_StartAI` — Start AI
- `gt_P5GrendelAttackWaves` — P5 Grendel Attack Waves
- `gt_P6BlightspreaderAttackWaves` — P6 Blightspreader Attack Waves
- `gt_P7RavagerAttackWaves` — P7 Ravager Attack Waves
- `gt_P3GarmAttackWaves` — P3 Garm Attack Waves
- `gt_P2JormungandAttackWaves` — P2 Jormungand Attack Waves
- `gt_P8AbathurAttackWaves` — P8 Abathur Attack Waves
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_P4DominionAttacks` — P4 Dominion Attacks
- `gt_DominionForward1` — Dominion Forward 1
- `gt_DominionForward2` — Dominion Forward 2
- `gt_DominionForward3` — Dominion Forward 3
- `gt_ZergReinforce1` — Zerg Reinforce 1
- `gt_ZergReinforce2` — Zerg Reinforce 2
- `gt_BunkerRefill` — Bunker Refill
- `gt_RaynorSnipeInitialize` — Raynor Snipe - Initialize
- `gt_RaynorSnipeUnitsKilled` — Raynor Snipe - Units Killed
- `gt_AchievementOneShotFiftyKills` — Achievement - One Shot, Fifty Kills
- `gt_AchievementBettyKill` — Achievement - Betty Kill
- `gt_AllyKills` — Ally Kills
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_CinematicVictorySetup` — Cinematic Victory Setup
- `gt_CinematicVictoryCinematic` — Cinematic Victory Cinematic
- `gt_CinematicVictoryAction` — Cinematic Victory Action
- `gt_CinematicVictoryCinematicEnd` — Cinematic Victory Cinematic End
- `gt_CinematicVictoryCleanup` — Cinematic Victory Cleanup
- `gt_CinematicDeployNuke` — Cinematic Deploy Nuke
- `gt_CinematicCameraShakeNuke2` — Cinematic Fissure Death
- `gt_CinematicCameraShakeNuke` — Cinematic Nuke Camera Shake
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingAction02` — Briefing Action 02
- `gt_BriefingAction03` — Briefing Action 03
- `gt_BriefingAction04` — Briefing Action 04
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingCameraWork01` — Briefing Camera Work 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingScene04` — Briefing Scene 04

