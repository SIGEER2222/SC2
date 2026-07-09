# ttosh01_7vs1(恶魔游乐场)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/ttosh01_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 4860 |
| 触发器总数(gt_*_Func) | 93 |
| 全局变量数(gv_) | 57 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`LibA070801C`、`Lib67C0F0E7`、`LibE0EAE146` |
| 起始晶体矿 | 300 |
| 起始高能瓦斯 | 200 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 21 |
| `unit` | 9 |
| `bool` | 7 |
| `unitgroup` | 7 |
| `timer` | 4 |
| `actor` | 3 |
| `revealer` | 2 |
| `playergroup` | 1 |
| `unitgroup[]` | 1 |
| `region[]` | 1 |
| `fixed` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(55 个):

- `int gv_p01_USER`
- `int gv_p02_ZERG`
- `int gv_p03_LAVA`
- `int gv_p04_ZERG`
- `int gv_p05_TOSH`
- `int gv_p06_SWANN`
- `int gv_p07_GRENDEL`
- `int gv_p08_KMC`
- `int gv_p09_ASHWORM`
- `int gv_p10_BRIDGES`
- `int gv_cRITTER_GROUPS`
- `int gv_noOfLavaSurges`
- `playergroup gv_zergPlayers`
- `int gv_eventNumber`
- `actor gv_briefingTargetingCursor`
- `actor gv_briefingTargetingCursor2`
- `revealer gv_revealer1`
- `revealer gv_revealer2`
- `unit gv_ashWorm`
- `unitgroup gv_dirtyBanelingCrew`
- `unitgroup[] gv_critterGroups`
- `region[] gv_critterHavens`
- `unitgroup gv_startingMineralFields`
- `int gv_toshMinersPing`
- `bool gv_toshMinersRescued`
- `int gv_brutaliskPing`
- `actor gv_brutaliskPingActor`
- `timer gv_sCVLossTimer`
- `int gv_sCVsLost`
- `int gv_combatUnitsTrained`
- `int gv_unitsRescued`
- `int gv_totalUnitsToRescue`
- `int gv_mineralsFromPickups`
- `unitgroup gv_toshReapers`
- `timer gv_lavaTimer`
- `timer gv_warning01Timer`
- `timer gv_warning02Timer`
- `int gv_lavaTimerWindow`
- `fixed gv_lavaInterval`
- `bool gv_lowGroundIsSafe`
- `bool gv_timerCreated`
- `bool gv_firstWarning`
- `unit gv_briefing_SCV5`
- `unit gv_briefing_SCV4`
- `unit gv_briefing_SCV3`
- `unit gv_briefing_SCV2`
- `unit gv_briefing_SCV1`
- `unit gv_briefing_CoCe`
- `unit gv_victoryDropship`
- `unit gv_victoryCoCe`
- `unitgroup gv_victorySCV`
- `unitgroup gv_victoryZergling`
- `unitgroup gv_victoryMarines`
- `unitgroup gv_victoryHiddenUnitGroup`
- `bool gv_victoryCinematicCompleted`

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
- `gt_StartGame` — Start Game
- `gt_BrutaliskIntroTimed` — Brutalisk Intro - Timed
- `gt_AshWormIntro` — Ash Worm Intro
- `gt_TransmissionIntroLavaTimerQ` — Transmission - Intro Lava Timer Q
- `gt_TransmissionReaperIntroQ` — Transmission - Reaper Intro Q
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingRetreat` — Briefing Retreat
- `gt_BriefingZerglings` — Briefing Zerglings

### 进攻波次(3)

- `gt_P2AttackWaves` — P2 Attack Waves
- `gt_P4AttackWaves` — P4 Attack Waves
- `gt_P7AttackWaves` — P7 Attack Waves

### 胜负(13)

- `gt_VictoryCollectedQuota` — Victory Collected Quota
- `gt_VictoryZergDead` — Victory Zerg Dead
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
- `gt_VictoryScene` — Victory Scene

### 对白提示(14)

- `gt_LavaWarning01Q` — Lava Warning 01 Q
- `gt_LavaWarning02Q` — Lava Warning 02 Q
- `gt_ItsSafeQ` — "It's Safe" Q
- `gt_TransmissionSCVReinforcementsQ` — Transmission - SCV Reinforcements Q
- `gt_TransmissionCommandCenterReplacementQ` — Transmission - Command Center Replacement Q
- `gt_TransmissionWatchSpendingWarningQ` — Transmission - Watch Spending Warning Q
- `gt_TransmissionFindToshsMissingMinersQ` — Transmission - Find Tosh's Missing Miners Q
- `gt_TransmissionMissingMinersFoundQ` — Transmission - Missing Miners Found Q
- `gt_TransmissionBrutaliskWarningQ` — Transmission - Brutalisk Warning Q
- `gt_TransmissionMineralNodeReveal1Q` — Transmission - Mineral Node Reveal 1 Q
- `gt_TransmissionMineralNodeReveal2Q` — Transmission - Mineral Node Reveal 2 Q
- `gt_TransmissionMineralNodeReveal3Q` — Transmission - Mineral Node Reveal 3 Q
- `gt_TransmissionMilestone4000MineralsQ` — Transmission - Milestone - 4000 Minerals Q
- `gt_TransmissionMilestone6500MineralsQ` — Transmission - Milestone - 6500 Minerals Q

### 其他(44)

- `gt_bon1`
- `gt_bon2`
- `gt_bon3`
- `gt_ObjectiveTiming` — Objective Timing
- `gt_EventTiming` — Event Timing
- `gt_MaggotSuicide` — Maggot Suicide
- `gt_StartAI` — Start AI
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_DirtyBanelingCrewListen` — Dirty Baneling Crew Listen
- `gt_DirtyBanelingCrewViaDamage` — Dirty Baneling Crew Via Damage
- `gt_DirtyBanelingCrewViaMovement` — Dirty Baneling Crew Via Movement
- `gt_DirtyBanelingCrewActions` — Dirty Baneling Crew Actions
- `gt_CritterInit` — Critter Init
- `gt_MakeCrittersFlee` — Make Critters Flee
- `gt_MakeCrittersReturn` — Make Critters Return
- `gt_CritterBabies` — Critter Babies
- `gt_BurrowAmbushGlobalTrigger` — Burrow Ambush Global Trigger
- `gt_BurrowAmbushRegion04` — Burrow Ambush (Region 04)
- `gt_FindToshsMiners` — Find Tosh's Miners
- `gt_RescuedToshsMiners` — Rescued Tosh's Miners
- `gt_HatcheryDestroyedShowResources` — Hatchery Destroyed - Show Resources
- `gt_SpawnResourcesRightSide` — Spawn Resources Right Side
- `gt_MineralPickups` — Mineral Pickups
- `gt_ReapersReinforcements01` — Reapers Reinforcements 01
- `gt_ReapersReinforcements02` — Reapers Reinforcements 02
- `gt_ReapersReinforcements03` — Reapers Reinforcements 03
- `gt_ReapersReinforcements04` — Reapers Reinforcements 04
- `gt_ReapersReinforcements05` — Reapers Reinforcements 05
- `gt_FirstSurge` — First Surge
- `gt_LavaTimerCreate` — Lava Timer Create
- `gt_LavaSurgeMusic` — Lava Surge Music
- `gt_CameraShakeWeak` — Camera Shake - Weak
- `gt_CameraShakeStrong` — Camera Shake - Strong
- `gt_CameraShakeDuringLava` — Camera Shake - During Lava
- `gt_LavaTurnsON` — Lava Turns ON
- `gt_LavaTurnsOFF` — Lava Turns OFF
- `gt_Res`
- `gt_Worker`
- `gt_LavaDamage` — Lava Damage
- `gt_MineralNodeReveal1` — Mineral Node Reveal 1
- `gt_MineralNodeReveal2` — Mineral Node Reveal 2
- `gt_MineralNodeReveal3` — Mineral Node Reveal 3
- `gt_AchievementAllReapersFound` — Achievement - All Reapers Found
- `gt_FeatofStrengthDestroyAllZerg` — Feat of Strength - Destroy All Zerg

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 83 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_bon1`
- `gt_bon2`
- `gt_bon3`
- `gt_ObjectiveTiming` — Objective Timing
- `gt_EventTiming` — Event Timing
- `gt_MaggotSuicide` — Maggot Suicide
- `gt_StartAI` — Start AI
- `gt_P2AttackWaves` — P2 Attack Waves
- `gt_P4AttackWaves` — P4 Attack Waves
- `gt_P7AttackWaves` — P7 Attack Waves
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_DirtyBanelingCrewListen` — Dirty Baneling Crew Listen
- `gt_DirtyBanelingCrewViaDamage` — Dirty Baneling Crew Via Damage
- `gt_DirtyBanelingCrewViaMovement` — Dirty Baneling Crew Via Movement
- `gt_DirtyBanelingCrewActions` — Dirty Baneling Crew Actions
- `gt_CritterInit` — Critter Init
- `gt_MakeCrittersFlee` — Make Critters Flee
- `gt_MakeCrittersReturn` — Make Critters Return
- `gt_CritterBabies` — Critter Babies
- `gt_BurrowAmbushGlobalTrigger` — Burrow Ambush Global Trigger
- `gt_BurrowAmbushRegion04` — Burrow Ambush (Region 04)
- `gt_BrutaliskIntroTimed` — Brutalisk Intro - Timed
- `gt_AshWormIntro` — Ash Worm Intro
- `gt_FindToshsMiners` — Find Tosh's Miners
- `gt_RescuedToshsMiners` — Rescued Tosh's Miners
- `gt_HatcheryDestroyedShowResources` — Hatchery Destroyed - Show Resources
- `gt_SpawnResourcesRightSide` — Spawn Resources Right Side
- `gt_MineralPickups` — Mineral Pickups
- `gt_ReapersReinforcements01` — Reapers Reinforcements 01
- `gt_ReapersReinforcements02` — Reapers Reinforcements 02
- `gt_ReapersReinforcements03` — Reapers Reinforcements 03
- `gt_ReapersReinforcements04` — Reapers Reinforcements 04
- `gt_ReapersReinforcements05` — Reapers Reinforcements 05
- `gt_FirstSurge` — First Surge
- `gt_LavaTimerCreate` — Lava Timer Create
- `gt_LavaSurgeMusic` — Lava Surge Music
- `gt_CameraShakeWeak` — Camera Shake - Weak
- `gt_CameraShakeStrong` — Camera Shake - Strong
- `gt_CameraShakeDuringLava` — Camera Shake - During Lava
- `gt_LavaTurnsON` — Lava Turns ON
- `gt_LavaTurnsOFF` — Lava Turns OFF
- `gt_Res`
- `gt_Worker`
- `gt_LavaDamage` — Lava Damage
- `gt_LavaWarning01Q` — Lava Warning 01 Q
- `gt_LavaWarning02Q` — Lava Warning 02 Q
- `gt_ItsSafeQ` — "It's Safe" Q
- `gt_TransmissionSCVReinforcementsQ` — Transmission - SCV Reinforcements Q
- `gt_TransmissionCommandCenterReplacementQ` — Transmission - Command Center Replacement Q
- `gt_TransmissionIntroLavaTimerQ` — Transmission - Intro Lava Timer Q
- `gt_TransmissionReaperIntroQ` — Transmission - Reaper Intro Q
- `gt_TransmissionWatchSpendingWarningQ` — Transmission - Watch Spending Warning Q
- `gt_TransmissionFindToshsMissingMinersQ` — Transmission - Find Tosh's Missing Miners Q
- `gt_TransmissionMissingMinersFoundQ` — Transmission - Missing Miners Found Q
- `gt_TransmissionBrutaliskWarningQ` — Transmission - Brutalisk Warning Q
- `gt_TransmissionMineralNodeReveal1Q` — Transmission - Mineral Node Reveal 1 Q
- `gt_MineralNodeReveal1` — Mineral Node Reveal 1
- `gt_TransmissionMineralNodeReveal2Q` — Transmission - Mineral Node Reveal 2 Q
- `gt_MineralNodeReveal2` — Mineral Node Reveal 2
- `gt_TransmissionMineralNodeReveal3Q` — Transmission - Mineral Node Reveal 3 Q
- `gt_MineralNodeReveal3` — Mineral Node Reveal 3
- `gt_TransmissionMilestone4000MineralsQ` — Transmission - Milestone - 4000 Minerals Q
- `gt_TransmissionMilestone6500MineralsQ` — Transmission - Milestone - 6500 Minerals Q
- `gt_AchievementAllReapersFound` — Achievement - All Reapers Found
- `gt_FeatofStrengthDestroyAllZerg` — Feat of Strength - Destroy All Zerg
- `gt_VictoryCollectedQuota` — Victory Collected Quota
- `gt_VictoryZergDead` — Victory Zerg Dead
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingRetreat` — Briefing Retreat
- `gt_BriefingZerglings` — Briefing Zerglings
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictoryScene` — Victory Scene

