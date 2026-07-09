# tvalerian01_7vs1(地狱之门)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/tvalerian01_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 7538 |
| 触发器总数(gt_*_Func) | 133 |
| 全局变量数(gv_) | 101 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`TriggerLibs/SwarmLib`、`LibA070801C`、`Lib67C0F0E7`、`LibC0F50AA6`、`Lib81FF3B49`、`LibDF8E6945`、`Lib0940FFB7`、`Lib975E2FE9`、`LibE0EAE146` |
| 起始晶体矿 | 2000 |
| 起始高能瓦斯 | 1000 |
| 起始人口(supplies made) | 200 |
| 特殊标志位 | `needs_pre_init_rpg` |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 32 |
| `unit` | 29 |
| `bool` | 14 |
| `unitgroup` | 8 |
| `actor` | 8 |
| `playergroup` | 3 |
| `fixed` | 3 |
| `region` | 1 |
| `point` | 1 |
| `string` | 1 |
| `gs_RECORD_BriefingSlaughterArea[]` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(99 个):

- `int gv_p00_NEUTRAL_PALLETS`
- `int gv_p01_USER`
- `int gv_p02_LEVIATHANBROOD`
- `int gv_p03_DOMINION_RED`
- `int gv_p04_WARFIELD`
- `int gv_p05_GARMBROOD`
- `int gv_p06_GRENDELBROOD`
- `int gv_p07_RAVAGING`
- `int gv_p08_RESCUABLE`
- `int gv_p09_ACTORDOMINION`
- `int gv_p10_JORMUNGAND`
- `int gv_p11_ZERG_YELLOWSPORECANNON`
- `int gv_p12_MOEBIUS`
- `int gv_p13_FIRETEAMRAVEN`
- `int gv_p14_FIRETEAMZULU`
- `int gv_p15_ZAGARA`
- `unit gv_nydusOBJ01`
- `unit gv_nydusOBJ02`
- `unit gv_nydusOBJ03`
- `unit gv_warfieldShipFlying`
- `unit gv_thor01`
- `unit gv_thor02`
- `unit gv_sandbag01`
- `unit gv_sandbag02`
- `unit gv_sandbag03`
- `unit gv_sandbag04`
- `unit gv_sandbag05`
- `unit gv_sandbag06`
- `unit gv_sandbag07`
- `unit gv_sandbag08`
- `unit gv_sandbag09`
- `unit gv_sandbag10`
- `bool gv_drop01Done`
- `playergroup gv_zergPlayers`
- `playergroup gv_zergTargets1`
- `playergroup gv_zergTargets2`
- `fixed gv_nydusWormMaximumHP`
- `int gv_trickleIntensity`
- `region gv_trickleDropRegions`
- `bool gv_zuluFound`
- `bool gv_zuluRescue`
- `bool gv_midRocksDead`
- `int gv_allOutDialog`
- `int gv_allOutDialogButton`
- `int gv_achievementDropPodForcesRescued`
- `bool gv_achievementNonMercCombatUnitTrained`
- `int gv_statStructuresRescued`
- `int gv_statSporeCannonsDestroyed`
- `int gv_statDropPodsRescued`
- `unitgroup gv_zergRushGroup01`
- `unitgroup gv_zergRushGroup02`
- `unitgroup gv_zergRushGroup03`
- `int gv_tempNydusPing`
- `point gv_tempNydusPoint`
- `int gv_tempNydusPlayer`
- `int gv_tempNydusPacks`
- `int gv_tempNydusPackSize`
- `fixed gv_tempNydusCooldown`
- `string gv_tempNydusType`
- `fixed gv_nydusSpawnDelay`
- `bool gv_stopFallingDebrisAndStuctures`
- `gs_RECORD_BriefingSlaughterArea[] gv_briefingSlaughterAreas`
- `bool gv_sandbagGet01`
- `bool gv_sandbagMovingToPlaceLeft`
- `int gv_sandbagsSwitchLeft`
- `bool gv_sandbagGet02`
- `bool gv_sandbagMovingToPlaceRight`
- `int gv_sandbagsSwitchRight`
- `int gv_pingNydus01`
- `int gv_pingNydus02`
- `int gv_pingNydus03`
- `actor gv_actorNydusTarget01`
- `actor gv_actorNydusTarget02`
- `actor gv_actorNydusTarget03`
- `unit gv_sCV01`
- `unit gv_sCV02`
- `unit gv_sCV03`
- `unit gv_sCV04`
- `unit gv_marine01`
- `unit gv_marine02`
- `unit gv_marine03`
- `unit gv_marine04`
- `actor gv_fire01`
- `actor gv_fire02`
- `actor gv_fire03`
- `actor gv_fire04`
- `actor gv_fire05`
- `unit gv_bunker01`
- `unit gv_bunker02`
- `unit gv_bunker03`
- `unit gv_bunker04`
- `unit gv_hydraSquish`
- `unitgroup gv_bunkerGroup01`
- `unitgroup gv_bunkerGroup02`
- `unitgroup gv_bunkerGroup03`
- `unitgroup gv_bunkerGroup04`
- `bool gv_midCinematicCompleted`
- `unitgroup gv_midHiddenUnitGroup`
- `bool gv_victoryCinematicCompleted`

## 触发器清单

### 初始化(17)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03Units` — Init 03 Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_Init08Variables` — Init 08 Variables
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_InitialBattle` — Initial Battle
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingZergCreation` — Briefing Zerg Creation
- `gt_BriefingZergRespawn` — Briefing Zerg Respawn
- `gt_BriefingTerranInvasion` — Briefing Terran Invasion

### 进攻波次(24)

- `gt_CreateAllOutAttackButton` — Create All Out Attack Button
- `gt_AllOutAttack` — All Out Attack
- `gt_AllOutAttackQ` — All Out Attack Q
- `gt_DialogueSirIveLocatedAnIncomingDropPodQ` — Dialogue Sir,I'veLocatedAnIncomingDropPod Q
- `gt_DialogueSirIveDetectedaDropPodInYourVicinityQ` — Dialogue Sir,I'veDetectedaDropPodInYourVicinity Q
- `gt_DialogueSendingCoordinatesToANearbyDroppodQ` — Dialogue SendingCoordinatesToANearbyDroppod Q
- `gt_DialogueSirAnotherDropPodIsComingDownQ` — Dialogue Sir,AnotherDropPodIsComingDown Q
- `gt_DialogueYouveGotAnotherDropPodLandingNearByQ` — Dialogue You'veGotAnotherDropPodLandingNearBy Q
- `gt_DialogueSirAnotherDropPodHasArrivedNearYourPerimeterQ` — Dialogue Sir,AnotherDropPodHasArrivedNearYourPerimeter Q
- `gt_DialogueSirIReadMultipleDropPodsEnteringTheAtmosphereQ` — Dialogue Sir,IReadMultipleDropPodsEnteringTheAtmosphere Q
- `gt_DialogueTheresAnotherWaveOfDropPodsComingInQ` — Dialogue There'sAnotherWaveOfDropPodsComingIn Q
- `gt_DialogueCommanderTheLastOfTheDominionDropPodsQ` — Dialogue Commander,TheLastOfTheDominionDropPods Q
- `gt_ZergStartAttack`
- `gt_ZergAmbientAttackBothSidesNew` — ZergAmbientAttackBothSides New
- `gt_AchievementRescuealldroppods` — Achievement - Rescue all drop pods
- `gt_P6GrendelAttackWaves` — P6 Grendel Attack Waves
- `gt_P5GarmAttackWaves` — P5 Garm Attack Waves
- `gt_P2LeviathanAttackWaves` — P2 Leviathan Attack Waves
- `gt_NydusSpawningTrigger` — Nydus Spawning Trigger
- `gt_NydusInfiniteSpawning01` — Nydus Infinite Spawning 01
- `gt_NydusInfiniteSpawning02` — Nydus Infinite Spawning 02
- `gt_NydusInfiniteSpawning03` — Nydus Infinite Spawning 03
- `gt_NydusAttack01` — Nydus Attack 01
- `gt_ZerglingsRearAttackLightWaves`

### 胜负(11)

- `gt_VictoryPrimaryObjectiveCompleted` — Victory - Primary Objective Completed
- `gt_Victory`
- `gt_DefeatAllTroopsDead` — Defeat All Troops Dead
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

### 对白提示(16)

- `gt_DialogueCommanderTacticalAnalysisTheZergGreatlyOutnumberQ` — Dialogue Commander,TacticalAnalysisTheZergGreatlyOutnumber Q
- `gt_DialogueKeepMeUpdatedIfWeCanReachQ` — Dialogue KeepMeUpdated/IfWeCanReach Q
- `gt_DialogueAlrightletsGetOutThereQ` — Dialogue Alright, let'sGetOutThere Q
- `gt_DialogueRaynorsRaidersFiveLinesQ` — Dialogue Raynor'sRaiders!/FiveLines Q
- `gt_DialogueLetsMoveQ` — Dialogue Let's Move Q
- `gt_DialogueSirWShouldMobilizeEverythingWeGotQ` — Dialogue Sir,WShouldMobilizeEverythingWeGot Q
- `gt_DialogueWeCanSalvageSomeOfTheWreckageFromtheDomBaseQ` — Dialogue WeCanSalvageSomeOfTheWreckageFromtheDomBase Q
- `gt_DialogueAtLeastABarracksMadeItDownQ` — Dialogue AtLeastABarracksMadeItDown Q
- `gt_DialogueGetThisFactoryBackToTheLandingZoneQ` — Dialogue GetThisFactoryBackToTheLandingZone Q
- `gt_DialogueSomeAirPowerIsJustWhatWeNeedQ` — Dialogue SomeAirPowerIsJustWhatWeNeed Q
- `gt_DialogueSomeInvasionplayedduringmidcinQ` — Dialogue SomeInvasion (played during midcin) Q
- `gt_DialogueYouWereFoolsToComeHereQ` — Dialogue YouWereFoolsToComeHere Q
- `gt_DialogueWeveReachedTheCrashSiteQ` — Dialogue We'veReachedTheCrashSite Q
- `gt_DialogueWarfieldWontBeAliveForVeryMuchLongerQ` — Dialogue WarfieldWon'tBeAliveForVeryMuchLonger Q
- `gt_DialogueYoureSureTalkingALotKerriganQ` — Dialogue You'reSureTalkingALot,Kerrigan Q
- `gt_MidQ` — Mid Q

### 其他(65)

- `gt_bon2`
- `gt_main`
- `gt_TricklePods` — Trickle Pods
- `gt_TriggerWarfieldCinematic` — Trigger Warfield Cinematic
- `gt_PredatorCave1Rescue` — Predator Cave 1 Rescue
- `gt_EggCaveRescue` — Egg Cave Rescue
- `gt_PredatorCave2Rescue` — Predator Cave 2 Rescue
- `gt_SabRescue` — Sab Rescue
- `gt_TankMinesRescue` — Tank + Mines Rescue
- `gt_Warden1Rescue` — Warden 1 Rescue
- `gt_LingRush` — Ling Rush!
- `gt_BRUTALISK`
- `gt_RadbatRescue` — Radbat Rescue
- `gt_SabShockRescue` — Sab + Shock Rescue
- `gt_LoneSpectreRescue` — Lone Spectre Rescue
- `gt_TitanRescue` — Titan Rescue
- `gt_UnstableRocksDie` — Unstable Rocks Die
- `gt_KilloffRocksblockingsideentrances` — Kill off Rocks blocking side entrances
- `gt_PhantomSporeDestroyed` — Phantom Spore Destroyed
- `gt_LiberatorSporeDestroyed` — Liberator Spore Destroyed
- `gt_RavenSporeDestroyed` — Raven Spore Destroyed
- `gt_VoidConduitSporeDestroyed` — Void Conduit Spore Destroyed
- `gt_ZuluReveal` — Zulu Reveal
- `gt_ZuluRescue` — Zulu Rescue
- `gt_FireteamRavenMovesForward` — Fireteam Raven Moves Forward
- `gt_InfestationPitDies` — Infestation Pit Dies
- `gt_MoveArea02` — Move Area 02
- `gt_AchievementKillallSporeCannons` — Achievement - Kill all Spore Cannons
- `gt_DestroyZagaraandSporeCannonPings` — Destroy Zagara and Spore Cannon Pings
- `gt_AggressiveEnemies` — Aggressive Enemies
- `gt_StartAI` — Start AI
- `gt_ZerglingRush` — Zergling Rush
- `gt_SporeCannonShotsAmbient` — Spore Cannon Shots Ambient
- `gt_Barracks01`
- `gt_Barracks02`
- `gt_Factory01`
- `gt_Factory02`
- `gt_Battlecruiser01`
- `gt_Battlecruiser02`
- `gt_CreateFloatingDebris`
- `gt_SandbagsGetSandbagLeft`
- `gt_SandbagsAtCrashSiteLeft`
- `gt_SandbagsHasSandbagLeft`
- `gt_SandbagsPlaceSandbag01`
- `gt_SandbagsPlaceSandbag02`
- `gt_SandbagsPlaceSandbag03`
- `gt_SandbagsPlaceSandbag04`
- `gt_SandbagsPlaceSandbag05`
- `gt_SandbagsGetSandbagRight`
- `gt_SandbagsAtCrashSiteRight`
- `gt_SandbagsHasSandbagRight`
- `gt_SandbagsPlaceSandbag06`
- `gt_SandbagsPlaceSandbag07`
- `gt_SandbagsPlaceSandbag08`
- `gt_SandbagsPlaceSandbag09`
- `gt_SandbagsPlaceSandbag010`
- `gt_MidSetup` — Mid Setup
- `gt_MidCinematic` — Mid Cinematic
- `gt_MidCinematicEnd` — Mid Cinematic End
- `gt_MidCleanup` — Mid Cleanup
- `gt_WarfieldCrashSurvivors`
- `gt_Fire01`
- `gt_Fire02`
- `gt_Fire03`
- `gt_HydraSquish` — Hydra Squish

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 123 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_Init08Variables` — Init 08 Variables
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_bon2`
- `gt_main`
- `gt_TricklePods` — Trickle Pods
- `gt_InitialBattle` — Initial Battle
- `gt_TriggerWarfieldCinematic` — Trigger Warfield Cinematic
- `gt_PredatorCave1Rescue` — Predator Cave 1 Rescue
- `gt_EggCaveRescue` — Egg Cave Rescue
- `gt_PredatorCave2Rescue` — Predator Cave 2 Rescue
- `gt_SabRescue` — Sab Rescue
- `gt_TankMinesRescue` — Tank + Mines Rescue
- `gt_Warden1Rescue` — Warden 1 Rescue
- `gt_LingRush` — Ling Rush!
- `gt_BRUTALISK`
- `gt_RadbatRescue` — Radbat Rescue
- `gt_SabShockRescue` — Sab + Shock Rescue
- `gt_LoneSpectreRescue` — Lone Spectre Rescue
- `gt_TitanRescue` — Titan Rescue
- `gt_UnstableRocksDie` — Unstable Rocks Die
- `gt_KilloffRocksblockingsideentrances` — Kill off Rocks blocking side entrances
- `gt_PhantomSporeDestroyed` — Phantom Spore Destroyed
- `gt_LiberatorSporeDestroyed` — Liberator Spore Destroyed
- `gt_RavenSporeDestroyed` — Raven Spore Destroyed
- `gt_VoidConduitSporeDestroyed` — Void Conduit Spore Destroyed
- `gt_ZuluReveal` — Zulu Reveal
- `gt_ZuluRescue` — Zulu Rescue
- `gt_FireteamRavenMovesForward` — Fireteam Raven Moves Forward
- `gt_CreateAllOutAttackButton` — Create All Out Attack Button
- `gt_AllOutAttack` — All Out Attack
- `gt_AllOutAttackQ` — All Out Attack Q
- `gt_DialogueCommanderTacticalAnalysisTheZergGreatlyOutnumberQ` — Dialogue Commander,TacticalAnalysisTheZergGreatlyOutnumber Q
- `gt_DialogueKeepMeUpdatedIfWeCanReachQ` — Dialogue KeepMeUpdated/IfWeCanReach Q
- `gt_DialogueSirIveLocatedAnIncomingDropPodQ` — Dialogue Sir,I'veLocatedAnIncomingDropPod Q
- `gt_DialogueAlrightletsGetOutThereQ` — Dialogue Alright, let'sGetOutThere Q
- `gt_DialogueRaynorsRaidersFiveLinesQ` — Dialogue Raynor'sRaiders!/FiveLines Q
- `gt_DialogueLetsMoveQ` — Dialogue Let's Move Q
- `gt_DialogueSirIveDetectedaDropPodInYourVicinityQ` — Dialogue Sir,I'veDetectedaDropPodInYourVicinity Q
- `gt_DialogueSendingCoordinatesToANearbyDroppodQ` — Dialogue SendingCoordinatesToANearbyDroppod Q
- `gt_DialogueSirAnotherDropPodIsComingDownQ` — Dialogue Sir,AnotherDropPodIsComingDown Q
- `gt_DialogueYouveGotAnotherDropPodLandingNearByQ` — Dialogue You'veGotAnotherDropPodLandingNearBy Q
- `gt_DialogueSirAnotherDropPodHasArrivedNearYourPerimeterQ` — Dialogue Sir,AnotherDropPodHasArrivedNearYourPerimeter Q
- `gt_DialogueSirIReadMultipleDropPodsEnteringTheAtmosphereQ` — Dialogue Sir,IReadMultipleDropPodsEnteringTheAtmosphere Q
- `gt_DialogueTheresAnotherWaveOfDropPodsComingInQ` — Dialogue There'sAnotherWaveOfDropPodsComingIn Q
- `gt_DialogueCommanderTheLastOfTheDominionDropPodsQ` — Dialogue Commander,TheLastOfTheDominionDropPods Q
- `gt_DialogueSirWShouldMobilizeEverythingWeGotQ` — Dialogue Sir,WShouldMobilizeEverythingWeGot Q
- `gt_DialogueWeCanSalvageSomeOfTheWreckageFromtheDomBaseQ` — Dialogue WeCanSalvageSomeOfTheWreckageFromtheDomBase Q
- `gt_DialogueAtLeastABarracksMadeItDownQ` — Dialogue AtLeastABarracksMadeItDown Q
- `gt_DialogueGetThisFactoryBackToTheLandingZoneQ` — Dialogue GetThisFactoryBackToTheLandingZone Q
- `gt_DialogueSomeAirPowerIsJustWhatWeNeedQ` — Dialogue SomeAirPowerIsJustWhatWeNeed Q
- `gt_DialogueSomeInvasionplayedduringmidcinQ` — Dialogue SomeInvasion (played during midcin) Q
- `gt_DialogueYouWereFoolsToComeHereQ` — Dialogue YouWereFoolsToComeHere Q
- `gt_DialogueWeveReachedTheCrashSiteQ` — Dialogue We'veReachedTheCrashSite Q
- `gt_DialogueWarfieldWontBeAliveForVeryMuchLongerQ` — Dialogue WarfieldWon'tBeAliveForVeryMuchLonger Q
- `gt_DialogueYoureSureTalkingALotKerriganQ` — Dialogue You'reSureTalkingALot,Kerrigan Q
- `gt_InfestationPitDies` — Infestation Pit Dies
- `gt_ZergStartAttack`
- `gt_ZergAmbientAttackBothSidesNew` — ZergAmbientAttackBothSides New
- `gt_MoveArea02` — Move Area 02
- `gt_AchievementKillallSporeCannons` — Achievement - Kill all Spore Cannons
- `gt_AchievementRescuealldroppods` — Achievement - Rescue all drop pods
- `gt_VictoryPrimaryObjectiveCompleted` — Victory - Primary Objective Completed
- `gt_DefeatAllTroopsDead` — Defeat All Troops Dead
- `gt_DestroyZagaraandSporeCannonPings` — Destroy Zagara and Spore Cannon Pings
- `gt_AggressiveEnemies` — Aggressive Enemies
- `gt_StartAI` — Start AI
- `gt_ZerglingRush` — Zergling Rush
- `gt_P6GrendelAttackWaves` — P6 Grendel Attack Waves
- `gt_P5GarmAttackWaves` — P5 Garm Attack Waves
- `gt_P2LeviathanAttackWaves` — P2 Leviathan Attack Waves
- `gt_NydusSpawningTrigger` — Nydus Spawning Trigger
- `gt_SporeCannonShotsAmbient` — Spore Cannon Shots Ambient
- `gt_NydusInfiniteSpawning01` — Nydus Infinite Spawning 01
- `gt_NydusInfiniteSpawning02` — Nydus Infinite Spawning 02
- `gt_NydusInfiniteSpawning03` — Nydus Infinite Spawning 03
- `gt_Barracks01`
- `gt_Barracks02`
- `gt_Factory01`
- `gt_Factory02`
- `gt_Battlecruiser01`
- `gt_Battlecruiser02`
- `gt_CreateFloatingDebris`
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingZergCreation` — Briefing Zerg Creation
- `gt_BriefingZergRespawn` — Briefing Zerg Respawn
- `gt_BriefingTerranInvasion` — Briefing Terran Invasion
- `gt_SandbagsGetSandbagLeft`
- `gt_SandbagsAtCrashSiteLeft`
- `gt_SandbagsHasSandbagLeft`
- `gt_SandbagsPlaceSandbag01`
- `gt_SandbagsPlaceSandbag02`
- `gt_SandbagsPlaceSandbag03`
- `gt_SandbagsPlaceSandbag04`
- `gt_SandbagsPlaceSandbag05`
- `gt_SandbagsGetSandbagRight`
- `gt_SandbagsAtCrashSiteRight`
- `gt_SandbagsHasSandbagRight`
- `gt_SandbagsPlaceSandbag06`
- `gt_SandbagsPlaceSandbag07`
- `gt_SandbagsPlaceSandbag08`
- `gt_SandbagsPlaceSandbag09`
- `gt_SandbagsPlaceSandbag010`
- `gt_MidQ` — Mid Q
- `gt_MidSetup` — Mid Setup
- `gt_MidCinematic` — Mid Cinematic
- `gt_MidCinematicEnd` — Mid Cinematic End
- `gt_MidCleanup` — Mid Cleanup
- `gt_NydusAttack01` — Nydus Attack 01
- `gt_WarfieldCrashSurvivors`
- `gt_Fire01`
- `gt_Fire02`
- `gt_Fire03`
- `gt_ZerglingsRearAttackLightWaves`
- `gt_HydraSquish` — Hydra Squish
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

