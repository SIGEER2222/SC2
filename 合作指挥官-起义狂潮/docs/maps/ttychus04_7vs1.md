# ttychus04_7vs1(超新星)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/ttychus04_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 3829 |
| 触发器总数(gt_*_Func) | 79 |
| 全局变量数(gv_) | 55 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`TriggerLibs/SwarmLib`、`LibA070801C`、`Lib67C0F0E7`、`LibC0F50AA6`、`LibE0EAE146` |
| 起始晶体矿 | 350 |
| 起始高能瓦斯 | 200 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 20 |
| `unit` | 9 |
| `bool` | 6 |
| `fixed` | 5 |
| `unitgroup` | 4 |
| `region` | 4 |
| `timer` | 3 |
| `actor` | 2 |
| `int[]` | 1 |
| `revealer` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(53 个):

- `int gv_pLAYER01_USER`
- `int gv_pLAYER02_FLEET`
- `int gv_pLAYER03_FORWARDGUARD`
- `int gv_pLAYER04_PHASESMITHS`
- `int gv_pLAYER05_RELICS`
- `int gv_pLAYER06_RESOURCES`
- `int gv_pLAYER07_SCIONS`
- `int gv_pLAYER08_DEATHSUN`
- `int gv_pLAYER09_BULLIES`
- `unitgroup gv_stage1Enemies`
- `unit gv_artifactVault`
- `int gv_artifactVault_Ping`
- `unit gv_superWarpGateP02`
- `unit gv_superWarpGateP03`
- `unit gv_superWarpGateP04`
- `unit gv_wALLOFFIRE`
- `int gv_clearLZ_Ping`
- `actor gv_pingActor1`
- `actor gv_pingActor2`
- `int gv_dEBUG_TIME`
- `timer gv_dEBUG_TIMER`
- `unitgroup gv_artifactGuardianGroup`
- `fixed gv_wall_of_Fire_Speed`
- `int[] gv_wall_of_Fire_Ping`
- `int gv_ping_Increment`
- `fixed gv_ping_VertSpace_Increment`
- `revealer gv_wall_of_Fire_Revealer`
- `region gv_wall_of_Fire_DamageRegion`
- `region gv_wall_of_Fire_VisionRegion`
- `int gv_wall_of_Fire_Sound_Counter`
- `fixed gv_residueTimer`
- `timer gv_vaultDestructionTimer`
- `timer gv_archiveDestructionTimer`
- `fixed gv_mainQuestTimeLimit`
- `fixed gv_bonusTimeLimit`
- `region gv_stormSpawnRegions`
- `int gv_stormSpawnCount`
- `region gv_residueSafeZones`
- `int gv_massEjectionWarningCycle`
- `int gv_achievementBansheeCloakedKills`
- `bool gv_achievementBansheeKillsUnlocked`
- `bool gv_achievementBarracksOrFactoryUnitBuilt`
- `int gv_achievementPlayerUnitsKilledByFire`
- `int gv_statProtoss_Killed_By_Fire`
- `int gv_statProtoss_Structures_Remaining`
- `unit gv_cinematic_WallOfFire`
- `bool gv_midCinematicCompleted`
- `unitgroup gv_midCineTempPlayerGroup`
- `unit gv_midCineDropship`
- `unit gv_geyser01`
- `unit gv_geyser02`
- `bool gv_victoryCinematicCompleted`
- `unitgroup gv_victoryHiddenUnitGroup`

## 触发器清单

### 初始化(19)

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
- `gt_TransmissionIntroBansheesQ` — Transmission - Intro Banshees Q
- `gt_TransmissionTaldarimIntroAgainQ` — Transmission - Tal'darim Intro... Again Q
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingScene04` — Briefing Scene 04
- `gt_BriefingBaseMove` — Briefing Base Move

### 进攻波次(5)

- `gt_P2DeathFleetAttackWaves` — P2 Death Fleet Attack Waves
- `gt_P3ForwardGuardAttackWaves` — P3 Forward Guard Attack Waves
- `gt_P4SmithAttackWaves` — P4 Smith Attack Waves
- `gt_P7ScionsAttackWaves` — P7 Scions Attack Waves
- `gt_ProtossKilledbyFireWave` — Protoss Killed by Fire Wave

### 胜负(12)

- `gt_VictoryDestroytheArtifactVaultCompleted` — Victory Destroy the Artifact Vault Completed
- `gt_Victory`
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatBansheeGroupDead` — Defeat Banshee Group Dead
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

### 对白提示(8)

- `gt_TransmissionCloakDetectorsQ` — Transmission - Cloak Detectors Q
- `gt_TransmissionTaldarimYouWinThisTimeQ` — Transmission - Tal'darim - You Win This Time Q
- `gt_TransmissionAdjutantFirearrivalQ` — Transmission - Adjutant - Fire arrival Q
- `gt_TransmissionAdjutantFireFirstWarningQ` — Transmission - Adjutant - Fire First Warning Q
- `gt_TransmissionHornerEmergencyFireWarningQ` — Transmission - Horner - Emergency Fire Warning Q
- `gt_TransmissionHornerP04ProtossBaseFoundQ` — Transmission - Horner - P04 Protoss Base Found Q
- `gt_TransmissionP04BaseDestroyedQ` — Transmission - P04 Base Destroyed Q
- `gt_MidQ` — Mid Q

### 其他(35)

- `gt_bon1`
- `gt_bon2`
- `gt_Stage1Leashes` — Stage 1 Leashes
- `gt_AreaClearStage2` — Area Clear -> Stage 2
- `gt_ArtifactVaultPing` — Artifact Vault Ping
- `gt_PingDetectorCannon` — Ping Detector Cannon
- `gt_RemoveCannonPing` — Remove Cannon Ping
- `gt_CreateWallofFire` — Create Wall of Fire
- `gt_WallofFirePing` — Wall of Fire Ping
- `gt_WallofFireDamage` — Wall of Fire Damage
- `gt_ShareWallofFireVision` — Share Wall of Fire Vision
- `gt_SetWallofFireLighting` — Set Wall of Fire Lighting
- `gt_WallofFireAtP03ProtossBase` — Wall of Fire At P03 Protoss Base
- `gt_ProtossP03FinalActions` — Protoss P03 Final Actions
- `gt_WallofFireFirstWarning` — Wall of Fire First Warning
- `gt_WallofFireSpeedUp` — Wall of Fire Speed Up
- `gt_WallofFireSlowDown` — Wall of Fire Slow Down
- `gt_RemoveResources` — Remove Resources
- `gt_WarpPrismSpawninBaseDefenders` — Warp Prism Spawn in Base Defenders
- `gt_MineralDepositGiveResources` — Mineral Deposit Give Resources
- `gt_MineralDepositRevealInit` — Mineral Deposit Reveal Init
- `gt_AllDepositsGathered` — All Deposits Gathered
- `gt_PingDestroyer` — Ping Destroyer
- `gt_MassEjectionWarningCycle` — Mass Ejection Warning Cycle
- `gt_ArtifactProtectionRemover` — Artifact Protection Remover
- `gt_StartAI` — Start AI
- `gt_ProtossP03GivesUp` — Protoss P03 Gives Up
- `gt_AchievementBanshee75CloakedKills` — Achievement - Banshee - 75 Cloaked Kills
- `gt_AchievementBarracksOrFactoryUnitNotBuilt` — Achievement - Barracks Or Factory Unit Not Built
- `gt_AchievementPlayerUnitsKilledbyFire` — Achievement - Player Units Killed by Fire
- `gt_ProtossStructuresRemaining` — Protoss Structures Remaining
- `gt_MidSetup` — Mid Setup
- `gt_MidCinematic` — Mid Cinematic
- `gt_MidCinematicEnd` — Mid Cinematic End
- `gt_MidCleanup` — Mid Cleanup

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 69 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGameStage1` — Start Game - Stage 1
- `gt_StartGameStage2` — Start Game - Stage 2
- `gt_bon1`
- `gt_bon2`
- `gt_Stage1Leashes` — Stage 1 Leashes
- `gt_AreaClearStage2` — Area Clear -> Stage 2
- `gt_ArtifactVaultPing` — Artifact Vault Ping
- `gt_PingDetectorCannon` — Ping Detector Cannon
- `gt_RemoveCannonPing` — Remove Cannon Ping
- `gt_CreateWallofFire` — Create Wall of Fire
- `gt_WallofFirePing` — Wall of Fire Ping
- `gt_WallofFireDamage` — Wall of Fire Damage
- `gt_ShareWallofFireVision` — Share Wall of Fire Vision
- `gt_SetWallofFireLighting` — Set Wall of Fire Lighting
- `gt_WallofFireAtP03ProtossBase` — Wall of Fire At P03 Protoss Base
- `gt_ProtossP03FinalActions` — Protoss P03 Final Actions
- `gt_WallofFireFirstWarning` — Wall of Fire First Warning
- `gt_WallofFireSpeedUp` — Wall of Fire Speed Up
- `gt_WallofFireSlowDown` — Wall of Fire Slow Down
- `gt_RemoveResources` — Remove Resources
- `gt_WarpPrismSpawninBaseDefenders` — Warp Prism Spawn in Base Defenders
- `gt_MineralDepositGiveResources` — Mineral Deposit Give Resources
- `gt_MineralDepositRevealInit` — Mineral Deposit Reveal Init
- `gt_AllDepositsGathered` — All Deposits Gathered
- `gt_PingDestroyer` — Ping Destroyer
- `gt_MassEjectionWarningCycle` — Mass Ejection Warning Cycle
- `gt_ArtifactProtectionRemover` — Artifact Protection Remover
- `gt_StartAI` — Start AI
- `gt_ProtossP03GivesUp` — Protoss P03 Gives Up
- `gt_P2DeathFleetAttackWaves` — P2 Death Fleet Attack Waves
- `gt_P3ForwardGuardAttackWaves` — P3 Forward Guard Attack Waves
- `gt_P4SmithAttackWaves` — P4 Smith Attack Waves
- `gt_P7ScionsAttackWaves` — P7 Scions Attack Waves
- `gt_TransmissionIntroBansheesQ` — Transmission - Intro Banshees Q
- `gt_TransmissionCloakDetectorsQ` — Transmission - Cloak Detectors Q
- `gt_TransmissionTaldarimIntroAgainQ` — Transmission - Tal'darim Intro... Again Q
- `gt_TransmissionTaldarimYouWinThisTimeQ` — Transmission - Tal'darim - You Win This Time Q
- `gt_TransmissionAdjutantFirearrivalQ` — Transmission - Adjutant - Fire arrival Q
- `gt_TransmissionAdjutantFireFirstWarningQ` — Transmission - Adjutant - Fire First Warning Q
- `gt_TransmissionHornerEmergencyFireWarningQ` — Transmission - Horner - Emergency Fire Warning Q
- `gt_TransmissionHornerP04ProtossBaseFoundQ` — Transmission - Horner - P04 Protoss Base Found Q
- `gt_TransmissionP04BaseDestroyedQ` — Transmission - P04 Base Destroyed Q
- `gt_AchievementBanshee75CloakedKills` — Achievement - Banshee - 75 Cloaked Kills
- `gt_AchievementBarracksOrFactoryUnitNotBuilt` — Achievement - Barracks Or Factory Unit Not Built
- `gt_AchievementPlayerUnitsKilledbyFire` — Achievement - Player Units Killed by Fire
- `gt_ProtossKilledbyFireWave` — Protoss Killed by Fire Wave
- `gt_ProtossStructuresRemaining` — Protoss Structures Remaining
- `gt_VictoryDestroytheArtifactVaultCompleted` — Victory Destroy the Artifact Vault Completed
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatBansheeGroupDead` — Defeat Banshee Group Dead
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingScene04` — Briefing Scene 04
- `gt_BriefingBaseMove` — Briefing Base Move
- `gt_MidQ` — Mid Q
- `gt_MidSetup` — Mid Setup
- `gt_MidCinematic` — Mid Cinematic
- `gt_MidCinematicEnd` — Mid Cinematic End
- `gt_MidCleanup` — Mid Cleanup
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

