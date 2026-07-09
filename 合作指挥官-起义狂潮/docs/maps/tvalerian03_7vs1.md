# tvalerian03_7vs1(背水一战)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/tvalerian03_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 4637 |
| 触发器总数(gt_*_Func) | 87 |
| 全局变量数(gv_) | 34 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`LibA070801C`、`Lib67C0F0E7`、`LibE0EAE146` |
| 起始晶体矿 | 1000 |
| 起始高能瓦斯 | 800 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | `needs_unit_event_null`、`second_unit_offset(point_id=789749215)` |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 22 |
| `bool` | 4 |
| `unit` | 3 |
| `fixed` | 2 |
| `unitgroup` | 2 |
| `unit[]` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(32 个):

- `int gv_pLAYER_USER`
- `int gv_p02_SWARMGUARD`
- `int gv_p03_KILYSA`
- `int gv_p04_GRENDEL`
- `int gv_p05_GARM`
- `int gv_p06_LEVIATHAN`
- `int gv_p07_JORMUNGAND`
- `int gv_p08_BLIGHTSPREADERS`
- `int gv_p09_SURTUR`
- `int gv_p10_BAELROG`
- `int gv_p11_RAVAGING`
- `int gv_p12_DOMINIONFORWARD`
- `int gv_p13_MOEBIUS`
- `int gv_p14_DOMINIONFLEET`
- `int gv_p15_BULLYZERG`
- `unit gv_artifact`
- `int gv_artifactProgerss`
- `fixed gv_artifactChargeCurrent`
- `fixed gv_artifactChargeSpeed`
- `int gv_energyQPendingCount`
- `int gv_energyNovaKills`
- `int gv_energyNovasUsed`
- `unit gv_kerrigan`
- `int gv_kerriganAttackCount`
- `unit[] gv_u`
- `int gv_dominionKills`
- `int gv_moebiusKills`
- `bool gv_introCinematicCompleted`
- `unitgroup gv_introHiddenUnitGroup`
- `unitgroup gv_initialArtifactAttackers`
- `unit gv_cINEKerrigan`
- `bool gv_victoryCinematicCompleted`

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
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingZergAttacksMajor` — Briefing Zerg Attacks Major
- `gt_BriefingZergAttacksMinor` — Briefing Zerg Attacks Minor
- `gt_IntroQ` — Intro Q
- `gt_IntroSetup` — Intro Setup
- `gt_IntroCinematic` — Intro Cinematic
- `gt_IntroCinematicEnd` — Intro Cinematic End
- `gt_IntroCleanup` — Intro Cleanup
- `gt_IntroArtifactAttack` — Intro Artifact Attack
- `gt_InitialArtifactAttackPausing` — Initial Artifact Attack Pausing
- `gt_IntroKerriganAnimations` — Intro Kerrigan Animations

### 进攻波次(21)

- `gt_P4GrendelAttackWaves` — P4 Grendel Attack Waves
- `gt_P8BlightspreaderAttackWaves` — P8 Blightspreader Attack Waves
- `gt_P6LeviathanAttackWaves` — P6 Leviathan Attack Waves
- `gt_P11RavagerAttackWaves` — P11 Ravager Attack Waves
- `gt_P5GarmAttackWaves` — P5 Garm Attack Waves
- `gt_P7JormungandAttackWaves` — P7 Jormungand Attack Waves
- `gt_P9SurturAttackWaves` — P9 Surtur Attack Waves
- `gt_P10BaelrogAttackWaves` — P10 Baelrog Attack Waves
- `gt_KerriganAttacks` — Kerrigan Attacks
- `gt_AirWave`
- `gt_NydusWave`
- `gt_P12DominionAttacks` — P12 Dominion Attacks
- `gt_P13MoebiusAttacks` — P13 Moebius Attacks
- `gt_DominionFleetPatrols` — Dominion Fleet Patrols
- `gt_NydusQ` — Nydus Q
- `gt_NydusWarningQ` — Nydus Warning Q
- `gt_NydusBehindQ` — Nydus Behind Q
- `gt_SpawnKerriganWave` — Spawn Kerrigan Wave
- `gt_KerriganAttackTransmissionQ` — Kerrigan Attack Transmission Q
- `gt_KerriganAttackTauntQ` — Kerrigan Attack Taunt Q
- `gt_OverlordAttackQ` — Overlord Attack Q

### 胜负(11)

- `gt_VictoryArtifactCharged` — Victory - Artifact Charged
- `gt_Victory`
- `gt_DefeatArtifactDestroyed` — Defeat - Artifact Destroyed
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

### 对白提示(7)

- `gt_BunkerQ` — Bunker Q
- `gt_ArtifactCloseQ` — Artifact Close Q
- `gt_EnergyNovaWarningQ` — Energy Nova Warning Q
- `gt_AirBehindQ` — Air Behind Q
- `gt_LeviathanQ` — Leviathan Q
- `gt_AirQ` — Air Q
- `gt_KerriganDeepTunnelQ` — Kerrigan Deep Tunnel Q

### 其他(25)

- `gt_ArtifactProgerss`
- `gt_ArtifactCharging` — Artifact Charging
- `gt_StartAI` — Start AI
- `gt_P2SwarmguardDrops` — P2 Swarmguard Drops
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_Upgrade`
- `gt_TopNaturalBullies` — Top Natural Bullies
- `gt_BottomNaturalBullies` — Bottom Natural Bullies
- `gt_SpireBullies` — Spire Bullies
- `gt_MarshesBullies` — Marshes Bullies
- `gt_ForkBullies` — Fork Bullies
- `gt_GrendelBullies` — Grendel Bullies
- `gt_BlightspreaderBullies` — Blightspreader Bullies
- `gt_LeviathanBullies` — Leviathan Bullies
- `gt_JormungandBullies` — Jormungand Bullies
- `gt_bunker`
- `gt_KerriganGetsaKill` — Kerrigan Gets a Kill
- `gt_CU`
- `gt_artC1`
- `gt_artC2`
- `gt_artC3`
- `gt_artC4`
- `gt_artCUD`
- `gt_DominionKills` — Dominion Kills
- `gt_MoebiusKills` — Moebius Kills

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 77 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_StartGame` — Start Game
- `gt_ArtifactProgerss`
- `gt_ArtifactCharging` — Artifact Charging
- `gt_BunkerQ` — Bunker Q
- `gt_ArtifactCloseQ` — Artifact Close Q
- `gt_EnergyNovaWarningQ` — Energy Nova Warning Q
- `gt_StartAI` — Start AI
- `gt_P4GrendelAttackWaves` — P4 Grendel Attack Waves
- `gt_P2SwarmguardDrops` — P2 Swarmguard Drops
- `gt_P8BlightspreaderAttackWaves` — P8 Blightspreader Attack Waves
- `gt_P6LeviathanAttackWaves` — P6 Leviathan Attack Waves
- `gt_P11RavagerAttackWaves` — P11 Ravager Attack Waves
- `gt_P5GarmAttackWaves` — P5 Garm Attack Waves
- `gt_P7JormungandAttackWaves` — P7 Jormungand Attack Waves
- `gt_P9SurturAttackWaves` — P9 Surtur Attack Waves
- `gt_P10BaelrogAttackWaves` — P10 Baelrog Attack Waves
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_KerriganAttacks` — Kerrigan Attacks
- `gt_Upgrade`
- `gt_AirWave`
- `gt_NydusWave`
- `gt_TopNaturalBullies` — Top Natural Bullies
- `gt_BottomNaturalBullies` — Bottom Natural Bullies
- `gt_SpireBullies` — Spire Bullies
- `gt_MarshesBullies` — Marshes Bullies
- `gt_ForkBullies` — Fork Bullies
- `gt_GrendelBullies` — Grendel Bullies
- `gt_BlightspreaderBullies` — Blightspreader Bullies
- `gt_LeviathanBullies` — Leviathan Bullies
- `gt_JormungandBullies` — Jormungand Bullies
- `gt_P12DominionAttacks` — P12 Dominion Attacks
- `gt_P13MoebiusAttacks` — P13 Moebius Attacks
- `gt_DominionFleetPatrols` — Dominion Fleet Patrols
- `gt_bunker`
- `gt_AirBehindQ` — Air Behind Q
- `gt_LeviathanQ` — Leviathan Q
- `gt_AirQ` — Air Q
- `gt_NydusQ` — Nydus Q
- `gt_NydusWarningQ` — Nydus Warning Q
- `gt_NydusBehindQ` — Nydus Behind Q
- `gt_SpawnKerriganWave` — Spawn Kerrigan Wave
- `gt_KerriganAttackTransmissionQ` — Kerrigan Attack Transmission Q
- `gt_KerriganAttackTauntQ` — Kerrigan Attack Taunt Q
- `gt_KerriganDeepTunnelQ` — Kerrigan Deep Tunnel Q
- `gt_KerriganGetsaKill` — Kerrigan Gets a Kill
- `gt_CU`
- `gt_artC1`
- `gt_artC2`
- `gt_artC3`
- `gt_artC4`
- `gt_artCUD`
- `gt_OverlordAttackQ` — Overlord Attack Q
- `gt_DominionKills` — Dominion Kills
- `gt_MoebiusKills` — Moebius Kills
- `gt_VictoryArtifactCharged` — Victory - Artifact Charged
- `gt_DefeatArtifactDestroyed` — Defeat - Artifact Destroyed
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingZergAttacksMajor` — Briefing Zerg Attacks Major
- `gt_BriefingZergAttacksMinor` — Briefing Zerg Attacks Minor
- `gt_IntroQ` — Intro Q
- `gt_IntroSetup` — Intro Setup
- `gt_IntroCinematic` — Intro Cinematic
- `gt_IntroCinematicEnd` — Intro Cinematic End
- `gt_IntroCleanup` — Intro Cleanup
- `gt_IntroArtifactAttack` — Intro Artifact Attack
- `gt_InitialArtifactAttackPausing` — Initial Artifact Attack Pausing
- `gt_IntroKerriganAnimations` — Intro Kerrigan Animations
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

