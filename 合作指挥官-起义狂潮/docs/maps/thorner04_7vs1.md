# thorner04_7vs1(媒体轰炸)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/thorner04_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 8028 |
| 触发器总数(gt_*_Func) | 131 |
| 全局变量数(gv_) | 103 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`TriggerLibs/SwarmLib`、`LibA070801C`、`Lib67C0F0E7`、`LibB7B23F0D`、`LibE0EAE146` |
| 起始晶体矿 | 500 |
| 起始高能瓦斯 | 300 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 48 |
| `bool` | 12 |
| `unitgroup` | 11 |
| `timer` | 9 |
| `unit` | 4 |
| `revealer` | 4 |
| `actor` | 4 |
| `region` | 3 |
| `fixed` | 2 |
| `point[]` | 2 |
| `region[]` | 1 |
| `unit[]` | 1 |
| `int[]` | 1 |
| `sound` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(101 个):

- `int gv_p01_USER`
- `int gv_p02_DOMINION_INFANTRY`
- `int gv_p03_DOMINION_SIEGE`
- `int gv_p04_DOMINION_AIR`
- `int gv_p05_DOMINION_RAIDER`
- `int gv_p06_CIVILIANS`
- `int gv_p07_HORNERBASE`
- `int gv_p08_DOMINION`
- `int gv_p9_MINELAYERGARRISON`
- `int gv_p10_AERIALPATROLS`
- `int gv_p11_DOGSOFWAR`
- `int gv_p12_NUKINGGHOSTS`
- `int gv_p13_FLEET`
- `int gv_p14_KILLTEAMS`
- `unitgroup gv_hiddenPlayerBase`
- `bool gv_missionStage1`
- `int gv_civilianVehicleCounter`
- `fixed gv_distractionTime`
- `timer gv_distractionTimer`
- `int gv_distractionTimerWindow`
- `timer gv__90SecondWarning`
- `timer gv__30SecondWarning`
- `unit gv_odin`
- `bool gv_odinDead`
- `bool gv_sneakAttackBegun`
- `unitgroup gv_destructibleObjectsNeutral`
- `unitgroup gv_destructibleObjectsCiv`
- `unit gv_secretDocuments`
- `revealer gv_sector1BeaconRevealer`
- `revealer gv_sector2BeaconRevealer`
- `revealer gv_sector3BeaconRevealer`
- `int gv_pingSector1Tower`
- `int gv_pingSector2Tower`
- `int gv_pingSector3Tower`
- `int gv_pingSector1Base`
- `int gv_pingSector2Base`
- `int gv_pingSector3Base`
- `actor gv_pingActor_Tower1`
- `actor gv_pingActor_Tower2`
- `actor gv_pingActor_Tower3`
- `bool gv_playerHasMercTech`
- `revealer gv_korhalRevealer`
- `unit gv_supplyDepotSCV`
- `timer gv_dominionAttackOdin`
- `bool gv_zergDisabled`
- `bool gv_nukesDisabled`
- `bool gv_fleetDisabled`
- `timer gv_zergTimer`
- `int gv_zergTimerWindow`
- `timer gv_nukeTimer`
- `int gv_nukeTimerWindow`
- `timer gv_fleetTimer`
- `int gv_fleetTimerWindow`
- `region[] gv_fleetWarpRegions`
- `region gv_cerberusSpawnRegions`
- `int gv_nukeIntensity`
- `int gv_zergIntensity`
- `int gv_fleetIntensity`
- `region gv_ghostSpawnRegions`
- `unitgroup gv_availableTargets`
- `timer gv_killTeamTimer`
- `int gv_killTeamTimerWindow`
- `region gv_killTeamSpawnRegions`
- `int gv_killTeamIntensity`
- `int gv_bonusCreditsEarned`
- `int gv_statueCount`
- `unitgroup gv_statues`
- `int gv_statuesDestroyed`
- `actor gv_statueExclamation`
- `unit[] gv_statueBullhorns`
- `int gv_statueTransmission01`
- `int gv_statueTransmission02`
- `int gv_statueTransmission03`
- `int gv_statueTransmission04`
- `int gv_statueTransmission05`
- `int gv_statueTransmission06`
- `unitgroup gv_killTeamMedivacs`
- `unitgroup gv_killTeamAttackers`
- `fixed gv_uploadTime`
- `int gv_killTeamsSent`
- `int[] gv_transmissionProgress`
- `point[] gv_mechWaypointArray`
- `int gv_achievementUnitsKilledDuringSneakAttack`
- `int gv_achievementBarracksDestroyed`
- `int gv_achievementFactoryDestroyed`
- `int gv_achievementStarportDestroyed`
- `timer gv_achievementHardTimer`
- `int gv_secretsFound`
- `int gv_odinKillCount`
- `int gv_hornerTimeWarning`
- `unit gv_pickedUnit`
- `unitgroup gv_briefingParadeGroup`
- `point[] gv_briefingParadePoints`
- `int gv_briefingNumberOfParadePoints`
- `bool gv_introCinematicCompleted`
- `unitgroup gv_introHiddenUnitGroup`
- `sound gv_soundEmitterCheers`
- `bool gv_midCinematicCompleted`
- `unitgroup gv_midHiddenUnitGroup`
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
- `gt_StartGameStage1` — Start Game - Stage 1
- `gt_StartGameStage1Timer` — Start Game - Stage 1 Timer
- `gt_StartGameStage2` — Start Game - Stage 2
- `gt_InitialAttackOver` — Initial Attack Over
- `gt_TransmissionStage2IntroQ` — Transmission - Stage 2 Intro Q
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingParade` — Briefing Parade
- `gt_IntroQ` — Intro Q
- `gt_IntroSetup` — Intro Setup
- `gt_IntroCinematic` — Intro Cinematic
- `gt_IntroCinematicEnd` — Intro Cinematic End
- `gt_IntroCleanup` — Intro Cleanup

### 进攻波次(6)

- `gt_P5ShadowOpsAttacks` — P5 Shadow Ops Attacks
- `gt_P3AlphaSquadronAttacks` — P3 Alpha Squadron Attacks
- `gt_P4FleetAttacks` — P4 Fleet Attacks
- `gt_AerialPatrols` — Aerial Patrols
- `gt_AchievementKillUnitsDuringSneakAttack` — Achievement - Kill Units During Sneak Attack
- `gt_CiviliansAttackedandCower` — Civilians Attacked and Cower

### 胜负(12)

- `gt_VictoryBroadcastTowersCompleted` — Victory Broadcast Towers Completed
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
- `gt_VictoryTowerScene` — Victory Tower Scene

### 对白提示(24)

- `gt_OdinDiesQ` — Odin Dies Q
- `gt_NukeRepeatTransmission` — Nuke Repeat Transmission
- `gt_CerberusRepeatTransmission` — Cerberus Repeat Transmission
- `gt_ObjectiveMisterUniverseUpdateAAirBaseTowerQ` — Objective Mister Universe Update A - Air Base Tower Q
- `gt_ObjectiveMisterUniverseUpdateBSiegeBaseTowerQ` — Objective Mister Universe Update B - Siege Base Tower Q
- `gt_ObjectiveMisterUniverseUpdateCRaiderBaseTowerQ` — Objective Mister Universe Update C - Raider Base Tower Q
- `gt_TransmissionPlazaMarineReactionQ` — Transmission - Plaza Marine Reaction Q
- `gt_TransmissionTychusEjectsOutoftheOdin` — Transmission - Tychus Ejects Out of the Odin
- `gt_TransmissionSwannDropsInAThorQ` — Transmission - Swann Drops In A Thor Q
- `gt_TransmissionCivilianSquishArea1Q` — Transmission - Civilian Squish Area 1 Q
- `gt_TransmissionCivilianSquishArea2Q` — Transmission - Civilian Squish Area 2 Q
- `gt_TransmissionCivilianSquishArea3Q` — Transmission - Civilian Squish Area 3 Q
- `gt_TransmissionCivilianSquishArea4Q` — Transmission - Civilian Squish Area 4 Q
- `gt_TransmissionCivilianSquishArea5Q` — Transmission - Civilian Squish Area 5 Q
- `gt_TransmissionOdinNearReaperQ` — Transmission - Odin Near Reaper Q
- `gt_TransmissionOdinNearSiegeTankQ` — Transmission - Odin Near Siege Tank Q
- `gt_TransmissionOdinNearVikingQ` — Transmission - Odin Near Viking Q
- `gt_TransmissionAirBaseGankSquadQ` — Transmission - Air Base Gank Squad Q
- `gt_TransmissionSiegeBaseGankSquadQ` — Transmission - Siege Base Gank Squad Q
- `gt_TransmissionRaiderBaseGankSquadQ` — Transmission - Raider Base Gank Squad Q
- `gt_TransmissionDataSuccessfullyUploadedQ` — Transmission - Data Successfully Uploaded Q
- `gt_Transmission90sLeftonDistractionQ` — Transmission - 90s Left on Distraction Q
- `gt_Transmission30sLeftonDistractionQ` — Transmission - 30s Left on Distraction Q
- `gt_MidQ` — Mid Q

### 其他(66)

- `gt_ShowAggroIcononUnit` — Show Aggro Icon on Unit
- `gt_HornerBuildsPlayerBase` — Horner Builds Player Base
- `gt_ParadePlazaReaction` — Parade Plaza Reaction
- `gt_AggroPassiveUnits` — Aggro Passive Units
- `gt_OdinDies` — Odin Dies
- `gt_OdinDiesMovetoStage2` — Odin Dies, Move to Stage 2
- `gt_CreateBeaconsandMapPings` — Create Beacons and Map Pings
- `gt_SwannFliesInaThor` — Swann Flies In a Thor
- `gt_TychusEjection` — Tychus Ejection
- `gt_HardModeEnabled` — Hard Mode Enabled
- `gt_SuperweaponInit` — Superweapon Init
- `gt_DisableZergCalldowns` — Disable Zerg Calldowns
- `gt_DisableNukes` — Disable Nukes
- `gt_DisableFleet` — Disable Fleet
- `gt_CerberusDrop` — Cerberus Drop
- `gt_NuclearArsenal` — Nuclear Arsenal
- `gt_FleetHarass` — Fleet Harass
- `gt_KillTeamTimerExpire` — Kill Team Timer Expire
- `gt_Statue1` — Statue 1
- `gt_Statue2` — Statue 2
- `gt_Statue3` — Statue 3
- `gt_Statue4` — Statue 4
- `gt_Statue5` — Statue 5
- `gt_Statue6` — Statue 6
- `gt_Statue1KillBullhorn` — Statue 1 - Kill Bullhorn
- `gt_Statue2KillBullhorn` — Statue 2 - Kill Bullhorn
- `gt_Statue3KillBullhorn` — Statue 3 - Kill Bullhorn
- `gt_Statue4KillBullhorn` — Statue 4 - Kill Bullhorn
- `gt_Statue5KillBullhorn` — Statue 5 - Kill Bullhorn
- `gt_Statue6KillBullhorn` — Statue 6 - Kill Bullhorn
- `gt_BullhornStopSounds` — Bullhorn Stop Sounds
- `gt_SendAirBaseKillTeam1` — Send Air Base Kill Team 1
- `gt_SendAirBaseKillTeam2` — Send Air Base Kill Team 2
- `gt_SendAirBaseKillTeam3` — Send Air Base Kill Team 3
- `gt_SendSiegeBaseKillTeam1` — Send Siege Base Kill Team 1
- `gt_SendSiegeBaseKillTeam2` — Send Siege Base Kill Team 2
- `gt_SendSiegeBaseKillTeam3` — Send Siege Base Kill Team 3
- `gt_SendRaiderBaseKillTeam1` — Send Raider Base Kill Team 1
- `gt_SendRaiderBaseKillTeam2` — Send Raider Base Kill Team 2
- `gt_SendRaiderBaseKillTeam3` — Send Raider Base Kill Team 3
- `gt_DisableRightRedBullies` — Disable Right Red Bullies
- `gt_DisableLeftRedBullies` — Disable Left Red Bullies
- `gt_StartAI` — Start AI
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_AchievementDestroyaBarracksStarportandFactory` — Achievement - Destroy a Barracks, Starport and Factory
- `gt_PlayUnitTalkonPickedUnit` — Play Unit Talk on Picked Unit
- `gt_RemoveGarrisonedCivilians` — Remove Garrisoned Civilians
- `gt_CityAmbienceNorthSideVehicles` — City Ambience - North Side Vehicles
- `gt_CityAmbienceSESideVehicles` — City Ambience - SE Side Vehicles
- `gt_CityAmbienceSWSideVehicles` — City Ambience - SW Side Vehicles
- `gt_CityAmbienceWestSideBlimp` — City Ambience - West Side Blimp
- `gt_CityAmbienceEastSideBlimp` — City Ambience - East Side Blimp
- `gt_CityAmbienceNorthSpawnVehicleRemoval` — City Ambience - North Spawn Vehicle Removal
- `gt_CityAmbienceSESpawnVehicleRemoval` — City Ambience - SE Spawn Vehicle Removal
- `gt_CityAmbienceSWSpawnVehicleRemoval` — City Ambience - SW Spawn Vehicle Removal
- `gt_CityAmbienceWestBlimpRemoval` — City Ambience - West Blimp Removal
- `gt_CityAmbienceEastBlimpRemoval` — City Ambience - East Blimp Removal
- `gt_OdinStompsStuff` — Odin Stomps Stuff!
- `gt_RemoveDominionOutpostPings` — Remove Dominion Outpost Pings
- `gt_ScienceFacilityBarragedSpawnSecretDocuments` — Science Facility Barraged - Spawn Secret Documents
- `gt_SecretDocumentsRetrievedUnlockHorner05S` — Secret Documents Retrieved - Unlock Horner05S
- `gt_MidSetup` — Mid Setup
- `gt_MidCinematic` — Mid Cinematic
- `gt_MidCinematicEnd` — Mid Cinematic End
- `gt_MidCleanup` — Mid Cleanup
- `gt_RecreateBase` — Recreate Base

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 121 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_StartGameStage1` — Start Game - Stage 1
- `gt_StartGameStage1Timer` — Start Game - Stage 1 Timer
- `gt_StartGameStage2` — Start Game - Stage 2
- `gt_ShowAggroIcononUnit` — Show Aggro Icon on Unit
- `gt_HornerBuildsPlayerBase` — Horner Builds Player Base
- `gt_ParadePlazaReaction` — Parade Plaza Reaction
- `gt_AggroPassiveUnits` — Aggro Passive Units
- `gt_InitialAttackOver` — Initial Attack Over
- `gt_OdinDies` — Odin Dies
- `gt_OdinDiesMovetoStage2` — Odin Dies, Move to Stage 2
- `gt_CreateBeaconsandMapPings` — Create Beacons and Map Pings
- `gt_OdinDiesQ` — Odin Dies Q
- `gt_SwannFliesInaThor` — Swann Flies In a Thor
- `gt_TychusEjection` — Tychus Ejection
- `gt_HardModeEnabled` — Hard Mode Enabled
- `gt_SuperweaponInit` — Superweapon Init
- `gt_DisableZergCalldowns` — Disable Zerg Calldowns
- `gt_DisableNukes` — Disable Nukes
- `gt_DisableFleet` — Disable Fleet
- `gt_CerberusDrop` — Cerberus Drop
- `gt_NuclearArsenal` — Nuclear Arsenal
- `gt_FleetHarass` — Fleet Harass
- `gt_NukeRepeatTransmission` — Nuke Repeat Transmission
- `gt_CerberusRepeatTransmission` — Cerberus Repeat Transmission
- `gt_KillTeamTimerExpire` — Kill Team Timer Expire
- `gt_Statue1` — Statue 1
- `gt_Statue2` — Statue 2
- `gt_Statue3` — Statue 3
- `gt_Statue4` — Statue 4
- `gt_Statue5` — Statue 5
- `gt_Statue6` — Statue 6
- `gt_Statue1KillBullhorn` — Statue 1 - Kill Bullhorn
- `gt_Statue2KillBullhorn` — Statue 2 - Kill Bullhorn
- `gt_Statue3KillBullhorn` — Statue 3 - Kill Bullhorn
- `gt_Statue4KillBullhorn` — Statue 4 - Kill Bullhorn
- `gt_Statue5KillBullhorn` — Statue 5 - Kill Bullhorn
- `gt_Statue6KillBullhorn` — Statue 6 - Kill Bullhorn
- `gt_BullhornStopSounds` — Bullhorn Stop Sounds
- `gt_ObjectiveMisterUniverseUpdateAAirBaseTowerQ` — Objective Mister Universe Update A - Air Base Tower Q
- `gt_ObjectiveMisterUniverseUpdateBSiegeBaseTowerQ` — Objective Mister Universe Update B - Siege Base Tower Q
- `gt_ObjectiveMisterUniverseUpdateCRaiderBaseTowerQ` — Objective Mister Universe Update C - Raider Base Tower Q
- `gt_SendAirBaseKillTeam1` — Send Air Base Kill Team 1
- `gt_SendAirBaseKillTeam2` — Send Air Base Kill Team 2
- `gt_SendAirBaseKillTeam3` — Send Air Base Kill Team 3
- `gt_SendSiegeBaseKillTeam1` — Send Siege Base Kill Team 1
- `gt_SendSiegeBaseKillTeam2` — Send Siege Base Kill Team 2
- `gt_SendSiegeBaseKillTeam3` — Send Siege Base Kill Team 3
- `gt_SendRaiderBaseKillTeam1` — Send Raider Base Kill Team 1
- `gt_SendRaiderBaseKillTeam2` — Send Raider Base Kill Team 2
- `gt_SendRaiderBaseKillTeam3` — Send Raider Base Kill Team 3
- `gt_DisableRightRedBullies` — Disable Right Red Bullies
- `gt_DisableLeftRedBullies` — Disable Left Red Bullies
- `gt_StartAI` — Start AI
- `gt_P5ShadowOpsAttacks` — P5 Shadow Ops Attacks
- `gt_P3AlphaSquadronAttacks` — P3 Alpha Squadron Attacks
- `gt_P4FleetAttacks` — P4 Fleet Attacks
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_AerialPatrols` — Aerial Patrols
- `gt_AchievementDestroyaBarracksStarportandFactory` — Achievement - Destroy a Barracks, Starport and Factory
- `gt_AchievementKillUnitsDuringSneakAttack` — Achievement - Kill Units During Sneak Attack
- `gt_VictoryBroadcastTowersCompleted` — Victory Broadcast Towers Completed
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_PlayUnitTalkonPickedUnit` — Play Unit Talk on Picked Unit
- `gt_TransmissionPlazaMarineReactionQ` — Transmission - Plaza Marine Reaction Q
- `gt_TransmissionTychusEjectsOutoftheOdin` — Transmission - Tychus Ejects Out of the Odin
- `gt_TransmissionSwannDropsInAThorQ` — Transmission - Swann Drops In A Thor Q
- `gt_TransmissionCivilianSquishArea1Q` — Transmission - Civilian Squish Area 1 Q
- `gt_TransmissionCivilianSquishArea2Q` — Transmission - Civilian Squish Area 2 Q
- `gt_TransmissionCivilianSquishArea3Q` — Transmission - Civilian Squish Area 3 Q
- `gt_TransmissionCivilianSquishArea4Q` — Transmission - Civilian Squish Area 4 Q
- `gt_TransmissionCivilianSquishArea5Q` — Transmission - Civilian Squish Area 5 Q
- `gt_TransmissionOdinNearReaperQ` — Transmission - Odin Near Reaper Q
- `gt_TransmissionOdinNearSiegeTankQ` — Transmission - Odin Near Siege Tank Q
- `gt_TransmissionOdinNearVikingQ` — Transmission - Odin Near Viking Q
- `gt_TransmissionStage2IntroQ` — Transmission - Stage 2 Intro Q
- `gt_TransmissionAirBaseGankSquadQ` — Transmission - Air Base Gank Squad Q
- `gt_TransmissionSiegeBaseGankSquadQ` — Transmission - Siege Base Gank Squad Q
- `gt_TransmissionRaiderBaseGankSquadQ` — Transmission - Raider Base Gank Squad Q
- `gt_TransmissionDataSuccessfullyUploadedQ` — Transmission - Data Successfully Uploaded Q
- `gt_Transmission90sLeftonDistractionQ` — Transmission - 90s Left on Distraction Q
- `gt_Transmission30sLeftonDistractionQ` — Transmission - 30s Left on Distraction Q
- `gt_CiviliansAttackedandCower` — Civilians Attacked and Cower
- `gt_RemoveGarrisonedCivilians` — Remove Garrisoned Civilians
- `gt_CityAmbienceNorthSideVehicles` — City Ambience - North Side Vehicles
- `gt_CityAmbienceSESideVehicles` — City Ambience - SE Side Vehicles
- `gt_CityAmbienceSWSideVehicles` — City Ambience - SW Side Vehicles
- `gt_CityAmbienceWestSideBlimp` — City Ambience - West Side Blimp
- `gt_CityAmbienceEastSideBlimp` — City Ambience - East Side Blimp
- `gt_CityAmbienceNorthSpawnVehicleRemoval` — City Ambience - North Spawn Vehicle Removal
- `gt_CityAmbienceSESpawnVehicleRemoval` — City Ambience - SE Spawn Vehicle Removal
- `gt_CityAmbienceSWSpawnVehicleRemoval` — City Ambience - SW Spawn Vehicle Removal
- `gt_CityAmbienceWestBlimpRemoval` — City Ambience - West Blimp Removal
- `gt_CityAmbienceEastBlimpRemoval` — City Ambience - East Blimp Removal
- `gt_OdinStompsStuff` — Odin Stomps Stuff!
- `gt_RemoveDominionOutpostPings` — Remove Dominion Outpost Pings
- `gt_ScienceFacilityBarragedSpawnSecretDocuments` — Science Facility Barraged - Spawn Secret Documents
- `gt_SecretDocumentsRetrievedUnlockHorner05S` — Secret Documents Retrieved - Unlock Horner05S
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingParade` — Briefing Parade
- `gt_IntroQ` — Intro Q
- `gt_IntroSetup` — Intro Setup
- `gt_IntroCinematic` — Intro Cinematic
- `gt_IntroCinematicEnd` — Intro Cinematic End
- `gt_IntroCleanup` — Intro Cleanup
- `gt_MidQ` — Mid Q
- `gt_MidSetup` — Mid Setup
- `gt_MidCinematic` — Mid Cinematic
- `gt_MidCinematicEnd` — Mid Cinematic End
- `gt_MidCleanup` — Mid Cleanup
- `gt_RecreateBase` — Recreate Base
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictoryTowerScene` — Victory Tower Scene

