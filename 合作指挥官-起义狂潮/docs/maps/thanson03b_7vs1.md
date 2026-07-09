# thanson03b_7vs1(海文的陷落)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/thanson03b_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 4683 |
| 触发器总数(gt_*_Func) | 77 |
| 全局变量数(gv_) | 65 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`TriggerLibs/SwarmLib`、`TriggerLibs/VoidLib`、`LibA070801C`、`Lib67C0F0E7`、`LibE0EAE146` |
| 起始晶体矿 | 300 |
| 起始高能瓦斯 | 150 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 22 |
| `bool` | 5 |
| `unit` | 5 |
| `unitgroup` | 5 |
| `int[]` | 4 |
| `point[]` | 4 |
| `unit[]` | 4 |
| `fixed` | 3 |
| `actor` | 3 |
| `unitgroup[]` | 2 |
| `bool[]` | 2 |
| `playergroup` | 1 |
| `timer` | 1 |
| `region[]` | 1 |
| `string[]` | 1 |
| `revealer[]` | 1 |
| `region` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(63 个):

- `int gv_p01_USER`
- `int gv_p02_ZERG_EAST`
- `int gv_p03_VIROPHAGE`
- `int gv_p04_ZERG_NORTH`
- `int gv_p05_COLONIST`
- `int gv_p06_COLONIST`
- `int gv_p07_ZERG_INFESTED`
- `int gv_p08_ZERG_SOUTH`
- `int gv_p09_AGRIAFLEET`
- `int gv_p10_SELENDIS`
- `int gv_p11_OBSERVERS`
- `int gv_cOLONY_BASES`
- `int gv_iNFESTATION_OVERLORD_MAX`
- `int gv_iNFESTATION_DEFENDER_MAX`
- `int gv_scourgeNestsKilled`
- `int gv_hansonGoneWildTransmissionCounter`
- `playergroup gv_playerAndProtoss`
- `int gv_tEMP_ColonyIndex`
- `timer gv_purifierTimer`
- `int gv_purifierTimeWindow`
- `region[] gv_infestationRegion`
- `int[] gv_infestationPings`
- `point[] gv_infestationVirophageSpot`
- `unit[] gv_infestationVirophageUnit`
- `int[] gv_infestationOverlordCount`
- `int[] gv_infestationOverseerCount`
- `point[] gv_infestationOverlordLocation`
- `point[] gv_infestationOverseerLocation`
- `unit[] gv_infestationOverlordUnit`
- `unit[] gv_infestationOverseerUnit`
- `unitgroup[] gv_infestationOverlords`
- `unitgroup[] gv_infestationOverseers`
- `int[] gv_infestationDefenderCount`
- `point[] gv_infestationDefenderLocation`
- `string[] gv_infestationDefenderType`
- `unit[] gv_infestationDefenderUnit`
- `bool[] gv_infestationColonyLost`
- `bool[] gv_infestationColonyCleanedMsg`
- `revealer[] gv_infestationRevealer`
- `bool gv_twoBaseWarningPlayed`
- `fixed gv_bileLauncherInitAttackTimer`
- `fixed gv_bileLauncherEnragedTimer`
- `region gv_nydusSpawnRegions`
- `fixed gv_nydusWormHP`
- `unit gv_p11SuperWarpGate`
- `unitgroup gv_carrionBirds`
- `unit gv_carrionBirdParameter`
- `int gv_vikingStructureKills`
- `int gv_stat_ColoniesSaved`
- `int gv_stat_VirophagesKilled`
- `int gv_allyKills`
- `unit gv_briefingZergling`
- `unitgroup gv_briefingGroup`
- `bool gv_introCinematicCompleted`
- `unitgroup gv_introHiddenUnitGroup`
- `unitgroup gv_introSpawnedUnits`
- `actor gv_virophagePingActor`
- `actor gv_broodLordPingActor1`
- `actor gv_broodLordPingActor2`
- `bool gv_victoryCinematicCompleted`
- `unitgroup gv_victoryHiddenUnitGroup`
- `unit gv_endDropship`
- `unit gv_endMothership`

## 触发器清单

### 初始化(23)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03Units` — Init 03 Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_StartGame` — Start Game
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_Briefing00ProjectileVomiting` — Briefing 00 - Projectile Vomiting
- `gt_Briefing00RunLolaRun` — Briefing 00 - Run Lola Run
- `gt_Briefing00LikeCattletotheSlaughter` — Briefing 00 - Like Cattle to the Slaughter
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_Briefing02Eggs` — Briefing 02 - Eggs
- `gt_IntroQ` — Intro Q
- `gt_IntroSetup` — Intro Setup
- `gt_IntroCinematic` — Intro Cinematic
- `gt_IntroCinematicEnd` — Intro Cinematic End
- `gt_IntroCleanup` — Intro Cleanup
- `gt_IntroFeederlingMover` — Intro Feederling Mover

### 进攻波次(10)

- `gt_PlayAttackWarningQ` — Play Attack Warning Q
- `gt_DestroyNydusandPrismPings` — Destroy Nydus and Prism Pings
- `gt_P2Attack`
- `gt_P4Attack`
- `gt_P8Attack`
- `gt_P8GrendelAttackWaves` — P8 Grendel Attack Waves
- `gt_P10Attack`
- `gt_P11AirPatrols` — P11 Air Patrols
- `gt_P4BlightspreaderAttackWaves` — P4 Blightspreader Attack Waves
- `gt_P2LeviathanAttackWaves` — P2 Leviathan Attack Waves

### 胜负(12)

- `gt_VictoryInfestationCleansedCompleted` — Victory Infestation Cleansed Completed
- `gt_VictoryQ` — Victory Q
- `gt_Victory`
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatPurifierDead` — Defeat Purifier Dead
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

### 对白提示(6)

- `gt_ColonyCleansedQ` — Colony Cleansed Q
- `gt_PlayInfestedWarningQ` — Play Infested Warning Q
- `gt_TransmissionMissionStartQ` — Transmission - Mission Start Q
- `gt_TransmissionHansonGoneWildQ` — Transmission - Hanson Gone Wild Q
- `gt_TransmissionPurifierClosetoBeingCharged` — Transmission - Purifier Close to Being Charged
- `gt_TransmissionAllOutpostsInfestedQ` — Transmission - All Outposts Infested Q

### 其他(26)

- `gt_Main2`
- `gt_GasPickups` — Gas Pickups
- `gt_bon1`
- `gt_bon2`
- `gt_ColonistsBetrayed` — Colonists Betrayed!
- `gt_StartPurifierTimer` — Start Purifier Timer
- `gt_NexusDies` — Nexus Dies
- `gt_InfestedBuildingDies` — Infested Building Dies
- `gt_InfestaColony` — Infest a Colony
- `gt_VirophageConstructionBegins` — Virophage Construction Begins
- `gt_VirophageConstructionEnds` — Virophage Construction Ends
- `gt_VirophageDies` — Virophage Dies
- `gt_BileLauncherMissiles` — Bile Launcher Missiles
- `gt_BileLauncherSpawns` — Bile Launcher Spawns
- `gt_StartAI` — Start AI
- `gt_P2Stop`
- `gt_P4Stop`
- `gt_P8Stop`
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_TossBuildup` — Toss Buildup
- `gt_AlliedBulliesTossForward` — Allied Bullies - Toss Forward
- `gt_AlliedBulliesTossSouth` — Allied Bullies - TossSouth
- `gt_CarrionBirds` — Carrion Birds
- `gt_CarrionBirdFlysAway` — Carrion Bird Flys Away
- `gt_StatVirophagesKilled` — Stat - Virophages Killed
- `gt_MilitiaKills` — Militia Kills

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 67 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_StartGame` — Start Game
- `gt_Main2`
- `gt_GasPickups` — Gas Pickups
- `gt_bon1`
- `gt_bon2`
- `gt_ColonistsBetrayed` — Colonists Betrayed!
- `gt_StartPurifierTimer` — Start Purifier Timer
- `gt_NexusDies` — Nexus Dies
- `gt_InfestedBuildingDies` — Infested Building Dies
- `gt_InfestaColony` — Infest a Colony
- `gt_VirophageConstructionBegins` — Virophage Construction Begins
- `gt_VirophageConstructionEnds` — Virophage Construction Ends
- `gt_VirophageDies` — Virophage Dies
- `gt_ColonyCleansedQ` — Colony Cleansed Q
- `gt_PlayAttackWarningQ` — Play Attack Warning Q
- `gt_PlayInfestedWarningQ` — Play Infested Warning Q
- `gt_TransmissionMissionStartQ` — Transmission - Mission Start Q
- `gt_TransmissionHansonGoneWildQ` — Transmission - Hanson Gone Wild Q
- `gt_TransmissionPurifierClosetoBeingCharged` — Transmission - Purifier Close to Being Charged
- `gt_TransmissionAllOutpostsInfestedQ` — Transmission - All Outposts Infested Q
- `gt_BileLauncherMissiles` — Bile Launcher Missiles
- `gt_BileLauncherSpawns` — Bile Launcher Spawns
- `gt_DestroyNydusandPrismPings` — Destroy Nydus and Prism Pings
- `gt_StartAI` — Start AI
- `gt_P2Attack`
- `gt_P4Attack`
- `gt_P8Attack`
- `gt_P2Stop`
- `gt_P4Stop`
- `gt_P8Stop`
- `gt_P8GrendelAttackWaves` — P8 Grendel Attack Waves
- `gt_P10Attack`
- `gt_P11AirPatrols` — P11 Air Patrols
- `gt_P4BlightspreaderAttackWaves` — P4 Blightspreader Attack Waves
- `gt_P2LeviathanAttackWaves` — P2 Leviathan Attack Waves
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_TossBuildup` — Toss Buildup
- `gt_AlliedBulliesTossForward` — Allied Bullies - Toss Forward
- `gt_AlliedBulliesTossSouth` — Allied Bullies - TossSouth
- `gt_CarrionBirds` — Carrion Birds
- `gt_CarrionBirdFlysAway` — Carrion Bird Flys Away
- `gt_StatVirophagesKilled` — Stat - Virophages Killed
- `gt_MilitiaKills` — Militia Kills
- `gt_VictoryInfestationCleansedCompleted` — Victory Infestation Cleansed Completed
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatPurifierDead` — Defeat Purifier Dead
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_Briefing00ProjectileVomiting` — Briefing 00 - Projectile Vomiting
- `gt_Briefing00RunLolaRun` — Briefing 00 - Run Lola Run
- `gt_Briefing00LikeCattletotheSlaughter` — Briefing 00 - Like Cattle to the Slaughter
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_Briefing02Eggs` — Briefing 02 - Eggs
- `gt_IntroQ` — Intro Q
- `gt_IntroSetup` — Intro Setup
- `gt_IntroCinematic` — Intro Cinematic
- `gt_IntroCinematicEnd` — Intro Cinematic End
- `gt_IntroCleanup` — Intro Cleanup
- `gt_IntroFeederlingMover` — Intro Feederling Mover
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

