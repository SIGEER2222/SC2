# tzeratul04_7vs1(究极黑暗)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/tzeratul04_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 4982 |
| 触发器总数(gt_*_Func) | 88 |
| 全局变量数(gv_) | 64 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`TriggerLibs/VoidLib`、`LibA070801C`、`Lib67C0F0E7`、`LibE0EAE146`、`ai5689EB5F`、`ai2C9F37EC`、`ai22AF3135` |
| 起始晶体矿 | 500 |
| 起始高能瓦斯 | 250 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 30 |
| `unit` | 19 |
| `bool` | 7 |
| `playergroup` | 3 |
| `unitgroup` | 2 |
| `timer` | 1 |
| `int[]` | 1 |
| `fixed` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(62 个):

- `int gv_p01_PLAYER`
- `int gv_p02_ALLIED_PROTOSS`
- `int gv_p3_ARTANIS`
- `int gv_p04_ZERG_NW`
- `int gv_p05_ZERG_NE`
- `int gv_p06_ZERG_SE`
- `int gv_p07_FRENZIED_ZERG`
- `int gv_p08_ARCHIVE`
- `int gv_p9_VORAZUN`
- `int gv_p10_REINFORCEMENTPROTOSS`
- `int gv_p11_KARAX`
- `int gv_p12_AMON`
- `int gv_sTAGE_01_KILL_QUOTA`
- `playergroup gv_zergPlayers`
- `unit gv_superWarpGate_P08`
- `unit gv_superWarpGate_P10`
- `unit gv_zeratul`
- `unit gv_heroPhoenix`
- `unit gv_heroVoidRay`
- `unit gv_heroCarrier`
- `unit gv_heroMothership`
- `bool gv_reinforcementAutoMove`
- `int gv_hybridSlain`
- `int gv_zeratulKills`
- `int gv_urunKills`
- `int gv_mohandarKills`
- `int gv_selendisKills`
- `int gv_artanisKills`
- `timer gv_protectArchiveTimer`
- `int[] gv_mineralFieldAmounts`
- `playergroup gv_pg`
- `playergroup gv_eg`
- `int gv_killCount`
- `int gv_allOutDialog`
- `int gv_allOutDialogButton`
- `int gv_wrathShotCount`
- `fixed gv_wrathRateofFire`
- `unit gv_amon`
- `bool gv_stargateUnitBuilt`
- `int gv_statWavessent`
- `int gv_statAchievementTierLevel`
- `int gv_statHeroKills`
- `int gv_vorazunKills`
- `int gv_karaxKills`
- `int gv_artanisHeroKills`
- `bool gv_introCinematicCompleted`
- `unitgroup gv_introCinematicProtossUnits`
- `unit gv_introCinematicColossusWest`
- `unit gv_introCinematicColossusEast`
- `unit gv_colossus_West`
- `unit gv_colossus_East`
- `unitgroup gv_midHiddenUnitGroup`
- `bool gv_midCinematicCompleted`
- `unit gv_omegalisk1`
- `unit gv_omegalisk2`
- `unit gv_omegalisk3`
- `bool gv_victoryCinematicCompleted`
- `int gv_victoryPortrait`
- `unit gv_hybrid1`
- `unit gv_hybrid2`
- `unit gv_hybrid3`
- `unit gv_hybrid4`

## 触发器清单

### 初始化(21)

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
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingZealotAnimations` — Briefing Zealot Animations
- `gt_DebriefingScene00` — Debriefing Scene 00
- `gt_DebriefingScene01` — Debriefing Scene 01
- `gt_IntroQ` — Intro Q
- `gt_IntroSetup` — Intro Setup
- `gt_IntroCinematic` — Intro Cinematic
- `gt_IntroCleanup` — Intro Cleanup
- `gt_IntroHeroGate` — Intro Hero Gate

### 进攻波次(6)

- `gt_CreateAllOutAttackButton` — Create All Out Attack Button
- `gt_AllOutAttack` — All Out Attack
- `gt_IncrementWavesSent` — Increment Waves Sent
- `gt_AirAttack`
- `gt_nydusanddropfinal`
- `gt_TransmissionAmonAttackedQ` — Transmission - Amon Attacked Q

### 胜负(12)

- `gt_VictoryDefeatforPlayer` — Victory & Defeat for Player
- `gt_VictoryAmonDies` — Victory Amon Dies
- `gt_Victory`
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictoryHybridExplosion` — Victory Hybrid Explosion

### 对白提示(24)

- `gt_NewTech01PhoenixQ` — New Tech 01 Phoenix Q
- `gt_NewTech02VoidRayQ` — New Tech 02 Void Ray Q
- `gt_NewTech03CarriersQ` — New Tech 03 Carriers Q
- `gt_NewTech04MothershipQ` — New Tech 04 Mothership Q
- `gt_ZeratulDiesQ` — Zeratul Dies Q
- `gt_HeroPhoenixDiesQ` — Hero Phoenix Dies Q
- `gt_HeroVoidRayDiesQ` — Hero Void Ray Dies Q
- `gt_HeroCarrierDiesQ` — Hero Carrier Dies Q
- `gt_HeroMothershipDiesQ` — Hero Mothership Dies Q
- `gt_VorazunDiesQ` — Vorazun Dies Q
- `gt_KaraxDiesQ` — Karax Dies Q
- `gt_TransmissionTemplarsStoreKnowledgeQ` — Transmission - Templars Store Knowledge Q
- `gt_TransmissionDarkVoicePronouncementQ` — Transmission - Dark Voice Pronouncement Q
- `gt_TransmissionZergswarmingflanksQ` — Transmission - Zerg swarming flanks Q
- `gt_TransmissionAllOutAssaultQ` — Transmission - All Out Assault Q
- `gt_TransmissionAmonSlainQ` — Transmission - Amon Slain Q
- `gt_TransmissionZerghordeincomingQ` — Transmission - Zerg horde incoming Q
- `gt_TransmissionDarkVoiceTauntsQ` — Transmission - Dark Voice Taunts Q
- `gt_TransmissionArtanisFinalSpeechQ` — Transmission - Artanis' Final Speech Q
- `gt_TransmissionHybridIncoming1Q` — Transmission - Hybrid Incoming 1 Q
- `gt_TransmissionHybridIncoming2Q` — Transmission - Hybrid Incoming 2 Q
- `gt_TransmissionWormsIncoming1Q` — Transmission - Worms Incoming 1 Q
- `gt_TransmissionWormsIncoming2Q` — Transmission - Worms Incoming 2 Q
- `gt_MidQ` — Mid Q

### 其他(25)

- `gt_bon`
- `gt_bon1timer`
- `gt_CreateLeaderboard` — Create Leaderboard
- `gt_UpdateLeaderboardZergorHybridKilled` — Update Leaderboard - Zerg or Hybrid Killed
- `gt_PrimaryKillCountComplete` — Primary Kill Count Complete
- `gt_ActivateHeroWayGate` — Activate Hero Way Gate
- `gt_ReinforcementBehavior` — Reinforcement Behavior
- `gt_MothershipSpawn` — Mothership Spawn
- `gt_ArchivistWarpedin` — Archivist Warped in
- `gt_AmonIntermission` — Amon Intermission
- `gt_BridgeControlDestroyed` — Bridge Control Destroyed
- `gt_StartAI` — Start AI
- `gt_upgrade`
- `gt_MissionEventTiming` — Mission Event Timing
- `gt_ZergBuildingreplenish` — Zerg Building replenish
- `gt_WarpedinTemplarBehavior` — Warped in Templar Behavior
- `gt_StatStargateUnitBuilt` — Stat -Stargate Unit Built
- `gt_Allykills` — Ally kills
- `gt_MidSetup` — Mid Setup
- `gt_MidCinematic` — Mid Cinematic
- `gt_MidCinematicEnd` — Mid Cinematic End
- `gt_MidCleanup` — Mid Cleanup
- `gt_MidOmegalisk1Unburrow` — Mid Omegalisk 1 Unburrow
- `gt_MidOmegalisk2Unburrow` — Mid Omegalisk 2 Unburrow
- `gt_MidOmegalisk3Unburrow` — Mid Omegalisk 3 Unburrow

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 78 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGameStage1` — Start Game - Stage 1
- `gt_bon`
- `gt_bon1timer`
- `gt_StartGameStage2` — Start Game - Stage 2
- `gt_CreateLeaderboard` — Create Leaderboard
- `gt_UpdateLeaderboardZergorHybridKilled` — Update Leaderboard - Zerg or Hybrid Killed
- `gt_PrimaryKillCountComplete` — Primary Kill Count Complete
- `gt_ActivateHeroWayGate` — Activate Hero Way Gate
- `gt_NewTech01PhoenixQ` — New Tech 01 Phoenix Q
- `gt_NewTech02VoidRayQ` — New Tech 02 Void Ray Q
- `gt_NewTech03CarriersQ` — New Tech 03 Carriers Q
- `gt_NewTech04MothershipQ` — New Tech 04 Mothership Q
- `gt_ReinforcementBehavior` — Reinforcement Behavior
- `gt_MothershipSpawn` — Mothership Spawn
- `gt_ZeratulDiesQ` — Zeratul Dies Q
- `gt_HeroPhoenixDiesQ` — Hero Phoenix Dies Q
- `gt_HeroVoidRayDiesQ` — Hero Void Ray Dies Q
- `gt_HeroCarrierDiesQ` — Hero Carrier Dies Q
- `gt_HeroMothershipDiesQ` — Hero Mothership Dies Q
- `gt_VorazunDiesQ` — Vorazun Dies Q
- `gt_KaraxDiesQ` — Karax Dies Q
- `gt_ArchivistWarpedin` — Archivist Warped in
- `gt_CreateAllOutAttackButton` — Create All Out Attack Button
- `gt_AllOutAttack` — All Out Attack
- `gt_AmonIntermission` — Amon Intermission
- `gt_BridgeControlDestroyed` — Bridge Control Destroyed
- `gt_IncrementWavesSent` — Increment Waves Sent
- `gt_StartAI` — Start AI
- `gt_upgrade`
- `gt_AirAttack`
- `gt_MissionEventTiming` — Mission Event Timing
- `gt_nydusanddropfinal`
- `gt_ZergBuildingreplenish` — Zerg Building replenish
- `gt_TransmissionTemplarsStoreKnowledgeQ` — Transmission - Templars Store Knowledge Q
- `gt_TransmissionDarkVoicePronouncementQ` — Transmission - Dark Voice Pronouncement Q
- `gt_TransmissionZergswarmingflanksQ` — Transmission - Zerg swarming flanks Q
- `gt_TransmissionAllOutAssaultQ` — Transmission - All Out Assault Q
- `gt_TransmissionAmonAttackedQ` — Transmission - Amon Attacked Q
- `gt_TransmissionAmonSlainQ` — Transmission - Amon Slain Q
- `gt_TransmissionZerghordeincomingQ` — Transmission - Zerg horde incoming Q
- `gt_TransmissionDarkVoiceTauntsQ` — Transmission - Dark Voice Taunts Q
- `gt_TransmissionArtanisFinalSpeechQ` — Transmission - Artanis' Final Speech Q
- `gt_TransmissionHybridIncoming1Q` — Transmission - Hybrid Incoming 1 Q
- `gt_TransmissionHybridIncoming2Q` — Transmission - Hybrid Incoming 2 Q
- `gt_TransmissionWormsIncoming1Q` — Transmission - Worms Incoming 1 Q
- `gt_TransmissionWormsIncoming2Q` — Transmission - Worms Incoming 2 Q
- `gt_WarpedinTemplarBehavior` — Warped in Templar Behavior
- `gt_StatStargateUnitBuilt` — Stat -Stargate Unit Built
- `gt_Allykills` — Ally kills
- `gt_VictoryDefeatforPlayer` — Victory & Defeat for Player
- `gt_VictoryAmonDies` — Victory Amon Dies
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingZealotAnimations` — Briefing Zealot Animations
- `gt_DebriefingScene00` — Debriefing Scene 00
- `gt_DebriefingScene01` — Debriefing Scene 01
- `gt_IntroQ` — Intro Q
- `gt_IntroSetup` — Intro Setup
- `gt_IntroCinematic` — Intro Cinematic
- `gt_IntroCleanup` — Intro Cleanup
- `gt_IntroHeroGate` — Intro Hero Gate
- `gt_MidQ` — Mid Q
- `gt_MidSetup` — Mid Setup
- `gt_MidCinematic` — Mid Cinematic
- `gt_MidCinematicEnd` — Mid Cinematic End
- `gt_MidCleanup` — Mid Cleanup
- `gt_MidOmegalisk1Unburrow` — Mid Omegalisk 1 Unburrow
- `gt_MidOmegalisk2Unburrow` — Mid Omegalisk 2 Unburrow
- `gt_MidOmegalisk3Unburrow` — Mid Omegalisk 3 Unburrow
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictoryHybridExplosion` — Victory Hybrid Explosion

