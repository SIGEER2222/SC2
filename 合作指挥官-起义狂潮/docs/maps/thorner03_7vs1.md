# thorner03_7vs1(毁灭引擎)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/thorner03_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 4698 |
| 触发器总数(gt_*_Func) | 96 |
| 全局变量数(gv_) | 52 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`LibA070801C`、`Lib67C0F0E7`、`LibB7B23F0D`、`LibDF8E6945`、`Lib0940FFB7`、`LibE0EAE146` |
| 起始晶体矿 | 300 |
| 起始高能瓦斯 | 250 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 19 |
| `bool` | 7 |
| `unit` | 6 |
| `unitgroup` | 5 |
| `int[]` | 5 |
| `timer` | 4 |
| `fixed` | 4 |
| `playergroup` | 1 |
| `actor` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(50 个):

- `int gv_p01_USER`
- `int gv_p02_TYCHUS`
- `int gv_p03_DOMINION_WAREHOUSE`
- `int gv_p04_ELITEGUARD`
- `int gv_p05_ALPHASQUADRON`
- `int gv_p06_HELLRIDERS`
- `int gv_p07_SHADOWOPS`
- `int gv_p08_INFANTRY`
- `int gv_p10_DOMINION_LOKI`
- `int gv_p11_Zerg`
- `unitgroup gv_raynorsRaidingForce`
- `playergroup gv_dominionEnemyGroup`
- `unit gv_odin`
- `unitgroup gv_warehouse1Bullies`
- `bool gv_initialOrderGiven`
- `unitgroup gv_warehouseDominion`
- `int gv_odinPing`
- `int gv_scrapCollected`
- `int gv_odinUpgradeLevel`
- `timer gv_odinTimer`
- `int gv_odinTimerWindow`
- `timer gv_warningTimer1`
- `timer gv_warningTimer2`
- `timer gv_warningTimer3`
- `int gv_odinAIPlayerTarget`
- `bool gv_odinRepairedOnAdvanced`
- `fixed gv_odinCurrentHealth`
- `unit gv_battlecruiser1`
- `unit gv_battlecruiser2`
- `int gv_battlecruiserPing1`
- `int gv_battlecruiserPing2`
- `actor gv_tippedDetectorPing`
- `unit gv_tippedDetectorUnit`
- `unit gv_loki`
- `int[] gv_waypointArrayEliteGuard`
- `int[] gv_waypointArrayInfantry`
- `int[] gv_waypointArrayHellriders`
- `int[] gv_waypointArrayAlphaSquadron`
- `int[] gv_waypointArraySpecOps`
- `int gv_barrageIncrement`
- `int gv_yamatoTransmission`
- `fixed gv_odinDamageDealt`
- `bool gv_achievementOdinHealthBelow30Percent`
- `fixed gv_odinLowestHealth`
- `fixed gv_sCVHealingPerformedOnOdin`
- `unit gv_briefingTychus`
- `bool gv_midCinematicCompleted`
- `unitgroup gv_midGameActors`
- `bool gv_victoryCinematicCompleted`
- `unitgroup gv_victoryHiddenUnitGroup`

## 触发器清单

### 初始化(22)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03Units` — Init 03 Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulty` — Init 06 Difficulty
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGameWarehouse` — Start Game Warehouse
- `gt_StartGameEscort` — Start Game Escort
- `gt_WraithIntro` — Wraith Intro
- `gt_AfterWraithIntroQ` — After Wraith Intro Q
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene00Tychus` — Briefing Scene 00 - Tychus
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene01Base` — Briefing Scene 01 - Base
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingScene03OdinBuild` — Briefing Scene 03 - Odin Build
- `gt_BriefingScene04` — Briefing Scene 04
- `gt_BriefingScene04Entry` — Briefing Scene 04 - Entry

### 进攻波次(9)

- `gt_BattlecruiserSpawnAttackOdin` — Battlecruiser Spawn / Attack Odin
- `gt_LokiReinforcementsForceAttack` — Loki Reinforcements Force Attack
- `gt_P6HellriderAttacks` — P6 Hellrider Attacks
- `gt_P8InfantryAttacks` — P8 Infantry Attacks
- `gt_P4EliteAttacks` — P4 Elite Attacks
- `gt_P5AlphaSquadronAttacks` — P5 Alpha Squadron Attacks
- `gt_P7SpecOpsAttacks` — P7 Spec Ops Attacks
- `gt_TransmissionBattlecruiserSpawnAttackOdinQ` — Transmission - Battlecruiser Spawn / Attack Odin Q
- `gt_TransmissionEliteGuardAttacksStart` — Transmission - Elite Guard Attacks Start

### 胜负(14)

- `gt_DefeatTychusDead` — Defeat Tychus Dead
- `gt_VictoryWarehouseDudesKilled` — Victory Warehouse Dudes Killed
- `gt_VictoryKillLoki` — Victory Kill Loki
- `gt_Victory`
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatOdinDead` — Defeat Odin Dead
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

### 对白提示(18)

- `gt_TychusMove1Q` — Tychus Move 1 Q
- `gt_TransmissionTychusTakesBreakAfterP04BaseQ` — Transmission - Tychus Takes Break After P04 Base Q
- `gt_TransmissionTychusTakesBreakAfterP08BaseQ` — Transmission - Tychus Takes Break After P08 Base Q
- `gt_TransmissionTychusTakesBreakAfterP06BaseQ` — Transmission - Tychus Takes Break After P06 Base Q
- `gt_WraithGetsClosetoDetectorQ` — Wraith Gets Close to Detector Q
- `gt_TransmissionWarehouseAutoTurretsQ` — Transmission - Warehouse Auto-Turrets Q
- `gt_TransmissionWarehouseBullies1AllDeadQ` — Transmission - Warehouse Bullies 1 All Dead Q
- `gt_TransmissionFindCerebrateSamplesQ` — Transmission - Find Cerebrate Samples Q
- `gt_TransmissionFirstBarrageQ` — Transmission - First Barrage Q
- `gt_TransmissionFirstBarrageCompleteQ` — Transmission - First Barrage Complete Q
- `gt_TransmissionBarrageQ` — Transmission - Barrage Q
- `gt_TransmissionTychusNoticesRaynorsUnitsQ` — Transmission - Tychus Notices Raynors Units Q
- `gt_TransmissionOdinApproachesP04BaseQ` — Transmission - Odin Approaches P04 Base Q
- `gt_TransmissionP04BaseDestroyedQ` — Transmission - P04 Base Destroyed Q
- `gt_TransmissionP05BaseDestroyedQ` — Transmission - P05 Base Destroyed Q
- `gt_TransmissionP06BaseDestroyedQ` — Transmission - P06 Base Destroyed Q
- `gt_TransmissionYamatoTheOdinQQ` — Transmission - Yamato The Odin QQ
- `gt_MidQ` — Mid Q

### 其他(33)

- `gt_WarehouseBullies1` — Warehouse Bullies 1
- `gt_WarehouseBullies2` — Warehouse Bullies 2
- `gt_WarehouseBullies3` — Warehouse Bullies 3
- `gt_bon1`
- `gt_bon2`
- `gt_CreateOdinBossBar` — Create Odin Boss Bar
- `gt_OdinLowHealthWarning` — Odin Low Health Warning
- `gt_OdinHealthLowWarnPlayer` — Odin Health Low - Warn Player
- `gt_OdinHealthLowSoundFX` — Odin Health Low Sound FX
- `gt_ExtendBridge` — Extend Bridge
- `gt_StartOdinTimer` — Start Odin Timer
- `gt_IncrementScrapCount` — Increment Scrap Count
- `gt_OdinRampageBegins` — Odin Rampage Begins
- `gt_BattlecruisersYamatoOdin` — Battlecruisers Yamato Odin
- `gt_OdinApproachesP06Base` — Odin Approaches P06 Base
- `gt_OdinGoGoGo` — Odin GoGoGo
- `gt_RemoveBattlecruiser1Ping` — Remove Battlecruiser 1 Ping
- `gt_RemoveBattlecruiser2Ping` — Remove Battlecruiser 2 Ping
- `gt_KillDetectorSpottedPing` — Kill Detector Spotted Ping
- `gt_LokiDropReinforcements` — Loki Drop Reinforcements
- `gt_LeftExpoCleared` — Left Expo Cleared
- `gt_RightExpoCleared` — Right Expo Cleared
- `gt_HellriderSideCleared` — Hellrider Side Cleared
- `gt_StartAI` — Start AI
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_AchievementOdinHealthBelow30Hard` — Achievement - Odin Health Below 30% (Hard)
- `gt_OdinHealthRepaired` — Odin Health Repaired
- `gt_OdinDamageDealt` — Odin Damage Dealt
- `gt_MidSetup` — Mid Setup
- `gt_MidCinematic` — Mid Cinematic
- `gt_MidCinematicEnd` — Mid Cinematic End
- `gt_MidCleanup` — Mid Cleanup
- `gt_MidValhallaDoorDamage` — Mid Valhalla Door Damage

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 86 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulty` — Init 06 Difficulty
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGameWarehouse` — Start Game Warehouse
- `gt_WarehouseBullies1` — Warehouse Bullies 1
- `gt_WarehouseBullies2` — Warehouse Bullies 2
- `gt_WarehouseBullies3` — Warehouse Bullies 3
- `gt_TychusMove1Q` — Tychus Move 1 Q
- `gt_DefeatTychusDead` — Defeat Tychus Dead
- `gt_VictoryWarehouseDudesKilled` — Victory Warehouse Dudes Killed
- `gt_StartGameEscort` — Start Game Escort
- `gt_bon1`
- `gt_bon2`
- `gt_CreateOdinBossBar` — Create Odin Boss Bar
- `gt_OdinLowHealthWarning` — Odin Low Health Warning
- `gt_OdinHealthLowWarnPlayer` — Odin Health Low - Warn Player
- `gt_OdinHealthLowSoundFX` — Odin Health Low Sound FX
- `gt_ExtendBridge` — Extend Bridge
- `gt_StartOdinTimer` — Start Odin Timer
- `gt_IncrementScrapCount` — Increment Scrap Count
- `gt_OdinRampageBegins` — Odin Rampage Begins
- `gt_TransmissionTychusTakesBreakAfterP04BaseQ` — Transmission - Tychus Takes Break After P04 Base Q
- `gt_TransmissionTychusTakesBreakAfterP08BaseQ` — Transmission - Tychus Takes Break After P08 Base Q
- `gt_TransmissionTychusTakesBreakAfterP06BaseQ` — Transmission - Tychus Takes Break After P06 Base Q
- `gt_BattlecruisersYamatoOdin` — Battlecruisers Yamato Odin
- `gt_OdinApproachesP06Base` — Odin Approaches P06 Base
- `gt_OdinGoGoGo` — Odin GoGoGo
- `gt_BattlecruiserSpawnAttackOdin` — Battlecruiser Spawn / Attack Odin
- `gt_RemoveBattlecruiser1Ping` — Remove Battlecruiser 1 Ping
- `gt_RemoveBattlecruiser2Ping` — Remove Battlecruiser 2 Ping
- `gt_WraithIntro` — Wraith Intro
- `gt_AfterWraithIntroQ` — After Wraith Intro Q
- `gt_WraithGetsClosetoDetectorQ` — Wraith Gets Close to Detector Q
- `gt_KillDetectorSpottedPing` — Kill Detector Spotted Ping
- `gt_LokiDropReinforcements` — Loki Drop Reinforcements
- `gt_LokiReinforcementsForceAttack` — Loki Reinforcements Force Attack
- `gt_LeftExpoCleared` — Left Expo Cleared
- `gt_RightExpoCleared` — Right Expo Cleared
- `gt_HellriderSideCleared` — Hellrider Side Cleared
- `gt_StartAI` — Start AI
- `gt_P6HellriderAttacks` — P6 Hellrider Attacks
- `gt_P8InfantryAttacks` — P8 Infantry Attacks
- `gt_P4EliteAttacks` — P4 Elite Attacks
- `gt_P5AlphaSquadronAttacks` — P5 Alpha Squadron Attacks
- `gt_P7SpecOpsAttacks` — P7 Spec Ops Attacks
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_TransmissionWarehouseAutoTurretsQ` — Transmission - Warehouse Auto-Turrets Q
- `gt_TransmissionWarehouseBullies1AllDeadQ` — Transmission - Warehouse Bullies 1 All Dead Q
- `gt_TransmissionFindCerebrateSamplesQ` — Transmission - Find Cerebrate Samples Q
- `gt_TransmissionBattlecruiserSpawnAttackOdinQ` — Transmission - Battlecruiser Spawn / Attack Odin Q
- `gt_TransmissionFirstBarrageQ` — Transmission - First Barrage Q
- `gt_TransmissionFirstBarrageCompleteQ` — Transmission - First Barrage Complete Q
- `gt_TransmissionEliteGuardAttacksStart` — Transmission - Elite Guard Attacks Start
- `gt_TransmissionBarrageQ` — Transmission - Barrage Q
- `gt_TransmissionTychusNoticesRaynorsUnitsQ` — Transmission - Tychus Notices Raynors Units Q
- `gt_TransmissionOdinApproachesP04BaseQ` — Transmission - Odin Approaches P04 Base Q
- `gt_TransmissionP04BaseDestroyedQ` — Transmission - P04 Base Destroyed Q
- `gt_TransmissionP05BaseDestroyedQ` — Transmission - P05 Base Destroyed Q
- `gt_TransmissionP06BaseDestroyedQ` — Transmission - P06 Base Destroyed Q
- `gt_TransmissionYamatoTheOdinQQ` — Transmission - Yamato The Odin QQ
- `gt_AchievementOdinHealthBelow30Hard` — Achievement - Odin Health Below 30% (Hard)
- `gt_OdinHealthRepaired` — Odin Health Repaired
- `gt_OdinDamageDealt` — Odin Damage Dealt
- `gt_VictoryKillLoki` — Victory Kill Loki
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatOdinDead` — Defeat Odin Dead
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene00Tychus` — Briefing Scene 00 - Tychus
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene01Base` — Briefing Scene 01 - Base
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingScene03OdinBuild` — Briefing Scene 03 - Odin Build
- `gt_BriefingScene04` — Briefing Scene 04
- `gt_BriefingScene04Entry` — Briefing Scene 04 - Entry
- `gt_MidQ` — Mid Q
- `gt_MidSetup` — Mid Setup
- `gt_MidCinematic` — Mid Cinematic
- `gt_MidCinematicEnd` — Mid Cinematic End
- `gt_MidCleanup` — Mid Cleanup
- `gt_MidValhallaDoorDamage` — Mid Valhalla Door Damage
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

