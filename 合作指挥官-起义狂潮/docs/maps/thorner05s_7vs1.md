# thorner05s_7vs1(揭露黑幕)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/thorner05s_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 4290 |
| 触发器总数(gt_*_Func) | 81 |
| 全局变量数(gv_) | 86 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`TriggerLibs/SwarmLib`、`LibA070801C`、`Lib67C0F0E7`、`LibC0F50AA6`、`LibE0EAE146` |
| 起始晶体矿 | 300 |
| 起始高能瓦斯 | 150 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 34 |
| `bool` | 12 |
| `unitgroup` | 12 |
| `unit` | 11 |
| `actor` | 5 |
| `fixed` | 4 |
| `soundlink` | 3 |
| `playergroup` | 2 |
| `timer` | 1 |
| `point` | 1 |
| `point[]` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(84 个):

- `int gv_p01_USER`
- `int gv_p02_DOMINION_RED`
- `int gv_p03_HAZRAD`
- `int gv_p04_HYBRID_THRALLS`
- `int gv_p05_MOEBIUSTHRALLS`
- `int gv_p06_MOEBISMASTERMINDS`
- `int gv_p07_BLIGHTSPREADER`
- `int gv_p08_DOOMINIONSURVIVORSBROWN`
- `int gv_p09_ENTRALLEDDOMINION`
- `int gv_p10_LEVIATHANBROOD`
- `int gv_p11_HORRORFROMBEYOND`
- `int gv_p12_DOMINION_WHITE`
- `int gv_p13_KHALAI`
- `int gv_p14_NERAZIM`
- `fixed gv_cameraDefault`
- `bool gv_inSecondHalf`
- `unit gv_warbot`
- `unit gv_escapeWarbot`
- `unit gv_hybrid`
- `unitgroup gv_vikings`
- `unitgroup gv_tanks`
- `unit gv_shamblingHorror`
- `int gv_horrorPing`
- `unit gv_brutaliskInForceField`
- `actor gv_hybridChamber`
- `actor gv_actorBrutaliskInPrison`
- `unitgroup gv_playerGroupforAI`
- `unitgroup gv_scientistsGroup`
- `unitgroup gv_eggsGroup`
- `unitgroup gv_hybridGroup`
- `soundlink gv_soundWarbotInitiateButton`
- `soundlink gv_soundTerminalButtonPush`
- `soundlink gv_soundBeacon`
- `fixed gv_shamblingMaximumHP`
- `playergroup gv_hybridPlayers`
- `playergroup gv_tg`
- `unitgroup gv_introMoebiusGuards`
- `bool gv_achievementUnitLosttoBrutalisk`
- `int gv_achievementPickUpsRemaining`
- `int gv_achievementWeaponKillls`
- `int gv_grenadeKills`
- `int gv_raynorKills`
- `int gv_statTotalRaynorAndGrenadeKills`
- `int gv_statWeaponsCollected`
- `int gv_statBrutaliskKilled`
- `unit gv_reactorCore`
- `unit gv_hazrad`
- `timer gv_attackTimer`
- `int gv_respawnTimerWindow`
- `fixed gv_hybridRespawnTime`
- `fixed gv_hybridMaxLife`
- `point gv_hybridRespawnPoint`
- `int gv_hazradPing`
- `int gv_hybridDrivenBackCount`
- `int gv_reviveCycle`
- `bool gv_dropPodsEnabled`
- `bool gv_annihilationBeamEnabled`
- `bool gv_parasiticFieldEnabled`
- `bool gv_consumingSwarmEnabled`
- `int gv_missileStrikeCount`
- `int gv_annihilationBeamCount`
- `int gv_parasiticBombCount`
- `int gv_dropPodCount`
- `bool gv_hybridBusy`
- `point[] gv_waypointArrayEliteGuard`
- `int gv_khalaiKills`
- `int gv_nerazimKills`
- `bool gv_introCinematicCompleted`
- `unitgroup gv_introHiddenUnitGroup`
- `unitgroup gv_introDropshipCargoGroup`
- `unit gv_introDropship`
- `unit gv_raynor`
- `int gv_marineMove`
- `int gv_medicMove`
- `unitgroup gv_midHiddenUnitGroupLab01`
- `bool gv_midCinematicCompletedLab01`
- `unitgroup gv_zerglingUnitGroupPen01`
- `actor gv_actorEnergyDoor01`
- `actor gv_actorEnergyDoor02`
- `actor gv_actorPenTarget`
- `bool gv_victoryCinematicCompleted`
- `unitgroup gv_victoryHiddenUnitGroup`
- `unit gv_escapeDropship`
- `unit gv_hercules`

## 触发器清单

### 初始化(20)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03Units` — Init 03 Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_StartGame` — Start Game
- `gt_IntroComplete` — Intro Complete
- `gt_StartGameMain` — Start Game Main
- `gt_ProtossAllyIntro` — Protoss Ally Intro
- `gt_DefeatIntroFailed` — Defeat Intro Failed
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_IntroQ` — Intro Q
- `gt_IntroSetup` — Intro Setup
- `gt_IntroCinematic` — Intro Cinematic
- `gt_IntroCinematicEnd` — Intro Cinematic End
- `gt_IntroCleanup` — Intro Cleanup

### 进攻波次(13)

- `gt_HybridAttackInitiate` — Hybrid Attack Initiate
- `gt_DropPods` — Drop Pods
- `gt_P13KhalaiAttackWaves` — P13 Khalai Attack Waves
- `gt_P14NerazimAttackWaves` — P14 Nerazim Attack Waves
- `gt_P5MoebiusThrallsAttacks` — P5 Moebius Thralls Attacks
- `gt_P9EnthralledSurvivorAttacks` — P9 Enthralled Survivor Attacks
- `gt_HybridThrallsAttackWaves` — Hybrid Thralls Attack Waves
- `gt_MoebiusMastermindsAttacks` — Moebius Masterminds Attacks
- `gt_BlightspreaderAttackWaves` — Blightspreader Attack Waves
- `gt_LeviathanAttackWaves` — Leviathan Attack Waves
- `gt_P2InfantrySurvivorAttacks` — P2 Infantry Survivor Attacks
- `gt_P8MechSurvivorAttacks` — P8 Mech Survivor Attacks
- `gt_P12AirSurvivorAttacks` — P12 Air Survivor Attacks

### 胜负(12)

- `gt_VictoryCoreDestroyed` — Victory - Core Destroyed
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
- `gt_VictorySceneTiming` — Victory Scene Timing

### 对白提示(1)

- `gt_MidLab01Q` — Mid Lab 01 Q

### 其他(35)

- `gt_ScaredDominion` — Scared Dominion
- `gt_MoebiusAmbush` — Moebius Ambush
- `gt_ExtremeAggro` — Extreme Aggro
- `gt_AchievementBrutaliskKillsPlayerUnit` — Achievement - Brutalisk Kills Player Unit
- `gt_AchievmentWeaponpickups` — Achievment - Weapon pick ups
- `gt_GrenadeKillsforStats` — Grenade Kills for Stats
- `gt_RaynorKillsforStats` — Raynor Kills for Stats
- `gt_RaynorPlasmaKillsforStats` — Raynor Plasma Kills for Stats
- `gt_AchievementRaynorWeaponKills` — Achievement - Raynor Weapon Kills
- `gt_main2`
- `gt_HybridUpgrades` — Hybrid Upgrades
- `gt_HybridRespawnTimer` — Hybrid Respawn Timer
- `gt_MissileStrikes` — Missile Strikes
- `gt_ParasiticField` — Parasitic Field
- `gt_KhalaiFreed` — Khalai Freed
- `gt_NerazimFreed` — Nerazim Freed
- `gt_AlliedBulliesTheOverlook` — Allied Bullies - The Overlook
- `gt_AlliedBulliesDropGuards` — Allied Bullies - Drop Guards
- `gt_AlliedBulliesBlightspreaderMain` — Allied Bullies - Blightspreader Main
- `gt_AlliedBulliesTheGrind` — Allied Bullies - The Grind
- `gt_BattlefrontTugofWar` — Battlefront Tug of War
- `gt_ShipyardTugofWar` — Shipyard Tug of War
- `gt_ThrallRampsTugofWar` — Thrall Ramps Tug of War
- `gt_TheGrindTugofWar` — The Grind Tug of War
- `gt_MechBaseTugofWar` — Mech Base Tug of War
- `gt_StartAI` — Start AI
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_MechBulliesEntralledMain` — Mech Bullies - Entralled Main
- `gt_MechBulliesBlightspreaderMain` — Mech Bullies - Blightspreader Main
- `gt_KhalaiKills` — Khalai Kills
- `gt_NerazimKills` — Nerazim Kills
- `gt_MidLab01Setup` — Mid Lab 01 Setup
- `gt_MidLab01Cinematic` — Mid Lab 01 Cinematic
- `gt_MidLab01CinematicEnd` — Mid Lab 01 Cinematic End
- `gt_MidLab01Cleanup` — Mid Lab 01 Cleanup

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 71 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_StartGame` — Start Game
- `gt_ScaredDominion` — Scared Dominion
- `gt_MoebiusAmbush` — Moebius Ambush
- `gt_IntroComplete` — Intro Complete
- `gt_ExtremeAggro` — Extreme Aggro
- `gt_AchievementBrutaliskKillsPlayerUnit` — Achievement - Brutalisk Kills Player Unit
- `gt_AchievmentWeaponpickups` — Achievment - Weapon pick ups
- `gt_GrenadeKillsforStats` — Grenade Kills for Stats
- `gt_RaynorKillsforStats` — Raynor Kills for Stats
- `gt_RaynorPlasmaKillsforStats` — Raynor Plasma Kills for Stats
- `gt_AchievementRaynorWeaponKills` — Achievement - Raynor Weapon Kills
- `gt_StartGameMain` — Start Game Main
- `gt_main2`
- `gt_HybridUpgrades` — Hybrid Upgrades
- `gt_HybridAttackInitiate` — Hybrid Attack Initiate
- `gt_HybridRespawnTimer` — Hybrid Respawn Timer
- `gt_MissileStrikes` — Missile Strikes
- `gt_DropPods` — Drop Pods
- `gt_ParasiticField` — Parasitic Field
- `gt_ProtossAllyIntro` — Protoss Ally Intro
- `gt_KhalaiFreed` — Khalai Freed
- `gt_NerazimFreed` — Nerazim Freed
- `gt_AlliedBulliesTheOverlook` — Allied Bullies - The Overlook
- `gt_AlliedBulliesDropGuards` — Allied Bullies - Drop Guards
- `gt_AlliedBulliesBlightspreaderMain` — Allied Bullies - Blightspreader Main
- `gt_AlliedBulliesTheGrind` — Allied Bullies - The Grind
- `gt_BattlefrontTugofWar` — Battlefront Tug of War
- `gt_ShipyardTugofWar` — Shipyard Tug of War
- `gt_ThrallRampsTugofWar` — Thrall Ramps Tug of War
- `gt_TheGrindTugofWar` — The Grind Tug of War
- `gt_MechBaseTugofWar` — Mech Base Tug of War
- `gt_StartAI` — Start AI
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_P13KhalaiAttackWaves` — P13 Khalai Attack Waves
- `gt_P14NerazimAttackWaves` — P14 Nerazim Attack Waves
- `gt_P5MoebiusThrallsAttacks` — P5 Moebius Thralls Attacks
- `gt_P9EnthralledSurvivorAttacks` — P9 Enthralled Survivor Attacks
- `gt_HybridThrallsAttackWaves` — Hybrid Thralls Attack Waves
- `gt_MoebiusMastermindsAttacks` — Moebius Masterminds Attacks
- `gt_MechBulliesEntralledMain` — Mech Bullies - Entralled Main
- `gt_MechBulliesBlightspreaderMain` — Mech Bullies - Blightspreader Main
- `gt_BlightspreaderAttackWaves` — Blightspreader Attack Waves
- `gt_LeviathanAttackWaves` — Leviathan Attack Waves
- `gt_P2InfantrySurvivorAttacks` — P2 Infantry Survivor Attacks
- `gt_P8MechSurvivorAttacks` — P8 Mech Survivor Attacks
- `gt_P12AirSurvivorAttacks` — P12 Air Survivor Attacks
- `gt_KhalaiKills` — Khalai Kills
- `gt_NerazimKills` — Nerazim Kills
- `gt_VictoryCoreDestroyed` — Victory - Core Destroyed
- `gt_DefeatIntroFailed` — Defeat Intro Failed
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_IntroQ` — Intro Q
- `gt_IntroSetup` — Intro Setup
- `gt_IntroCinematic` — Intro Cinematic
- `gt_IntroCinematicEnd` — Intro Cinematic End
- `gt_IntroCleanup` — Intro Cleanup
- `gt_MidLab01Q` — Mid Lab 01 Q
- `gt_MidLab01Setup` — Mid Lab 01 Setup
- `gt_MidLab01Cinematic` — Mid Lab 01 Cinematic
- `gt_MidLab01CinematicEnd` — Mid Lab 01 Cinematic End
- `gt_MidLab01Cleanup` — Mid Lab 01 Cleanup
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictorySceneTiming` — Victory Scene Timing

