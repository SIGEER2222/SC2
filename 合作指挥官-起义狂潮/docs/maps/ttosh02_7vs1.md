# ttosh02_7vs1(欢迎来到丛林)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/ttosh02_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 5442 |
| 触发器总数(gt_*_Func) | 90 |
| 全局变量数(gv_) | 48 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`LibA070801C`、`Lib67C0F0E7`、`LibC0F50AA6`、`Lib81FF3B49`、`LibDF8E6945`、`Lib0940FFB7`、`Lib975E2FE9`、`LibE0EAE146` |
| 起始晶体矿 | 300 |
| 起始高能瓦斯 | 100 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 25 |
| `unit` | 5 |
| `unitgroup` | 4 |
| `bool` | 3 |
| `unit[]` | 2 |
| `point[]` | 2 |
| `int[]` | 2 |
| `wave[]` | 1 |
| `region[]` | 1 |
| `playergroup` | 1 |
| `timer` | 1 |
| `point` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(46 个):

- `int gv_p1_USER`
- `int gv_p2_PROTOSS_EAST_ATTACKERS`
- `int gv_p3_PROTOSS_SCRIPTED`
- `int gv_p4_PROTOSS_WEST_ESCORTS`
- `int gv_p5_TERRAZINE`
- `int gv_p6_FORWARDGUARD`
- `int gv_p7_DEATHFLEET`
- `int gv_p8_TOSH`
- `int gv_p10_VOIDSHADESRIGHT`
- `int gv_p11_VOIDSHADESLEFT`
- `int gv_p12_VOIDSHADESTOP`
- `int gv_p13_VOIDSHADESDEVOURER`
- `unit gv_superWarpGateP3NoAI`
- `unit[] gv_terrazineNodes`
- `wave[] gv_terrazineAttackWaves`
- `region[] gv_terrazineRegions`
- `playergroup gv_protossPlayerGroup`
- `unitgroup gv_harvestingSpeedBumpNWBullies`
- `unitgroup gv_harvestingSpeedBumpCentralBullies`
- `timer gv_protossAggroTimer`
- `unit[] gv_nEDefenders`
- `point[] gv_nEDefenderPositions`
- `unitgroup gv_nEDefendersGroup`
- `int gv_numberOfNEDefenders`
- `int gv_allyKills`
- `unit gv_terrazineHarvesting`
- `int gv_gasControlCount`
- `int gv_gasHarvestingCount`
- `int gv_sCVsKilledWhileHarvesting`
- `point gv_sCVKilledAlertPosition`
- `unit gv_sCVGoingHome`
- `unit gv_droppedCargoFlashUnit`
- `int gv_playerScore`
- `int[] gv_playerHarvesterPings`
- `unitgroup gv_probeHarvesters`
- `int gv_probesThwarted`
- `int gv_multipleTerrazineSealingState`
- `int gv_multipleTerrazineSealingFirstTarget`
- `int gv_protossScore`
- `int[] gv_protossHarvesterPings`
- `point[] gv_waypointArrayAttackers`
- `int gv_protossThreatLevel`
- `int gv_statSCVsLost`
- `unit gv_victoryTerrazine`
- `bool gv_victoryCinematicCompleted`
- `int gv_ttoshEnemyAttackStage`

## 触发器清单

### 初始化(17)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03VariablesUnits` — Init 03 Variables/Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulty` — Init 06 Difficulty
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_InitNERelicDefenders` — Init NE Relic Defenders
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene01Action` — Briefing Scene 01 Action
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene02Action` — Briefing Scene 02 Action
- `gt_BriefingScene03` — Briefing Scene 03

### 进攻波次(6)

- `gt_ToshAttackWaves` — Tosh Attack Waves
- `gt_AIP2AttackWaves` — AI P2 Attack Waves
- `gt_P2AttackWaves` — P2 Attack Waves
- `gt_P6AttackWaves` — P6 Attack Waves
- `gt_P7AttackWaves` — P7 Attack Waves
- `gt_P3PatrolWaves` — P3 Patrol Waves

### 胜负(13)

- `gt_VictoryProtossDestroyed` — Victory Protoss Destroyed
- `gt_VictoryTerrazineCollected` — Victory Terrazine Collected
- `gt_Victory`
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatProtossSealedTooManyTerrazine` — Defeat Protoss Sealed Too Many Terrazine
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

### 对白提示(18)

- `gt_GoliathandGatherTerrazineTipsQ` — Goliath and Gather Terrazine Tips Q
- `gt_ProtossAggroLineQ` — Protoss Aggro Line Q
- `gt_ProtossmediumretaliationannounceQ` — Protoss medium retaliation announce Q
- `gt_ProtossheavyretaliationannounceQ` — Protoss heavy retaliation announce Q
- `gt_TiptoprotectSCVsQ` — Tip to protect SCV's Q
- `gt_PlayertriestoharvestmultiplecanistersatonceQ` — Player tries to harvest multiple canisters at once Q
- `gt_FirstTerrazineReturnQ` — First Terrazine Return Q
- `gt_DroppedterrazinecargoQ` — Dropped terrazine cargo Q
- `gt_Playerharvested1NodeQ` — Player harvested 1 Node Q
- `gt_Playerharvested3NodeQ` — Player harvested 3 Node Q
- `gt_Playerharvested4NodeQ` — Player harvested 4 Node Q
- `gt_Playerharvested6NodeQ` — Player harvested 6 Node Q
- `gt_ProtosssealingterrazineQ` — Protoss sealing terrazine Q
- `gt_ProtossstartssealingfirstterrazinenodeQ` — Protoss starts sealing first terrazine node Q
- `gt_Protossseal3shrinesQ` — Protoss seal 3 shrines Q
- `gt_Protossseal5shrinesQ` — Protoss seal 5 shrines Q
- `gt_Protossseal6shrinesQ` — Protoss seal 6 shrines Q
- `gt_ProtossDestroyedQ` — Protoss Destroyed Q

### 其他(36)

- `gt_Bon1`
- `gt_Bon2`
- `gt_Bon`
- `gt_PingTerrazineonMinimapandReveal` — Ping Terrazine on Minimap and Reveal
- `gt_ProtossAggroViaLeavingPlayerBase` — Protoss Aggro Via Leaving Player Base
- `gt_ProtossAggroViaTimer` — Protoss Aggro Via Timer
- `gt_ProtossAggroBullies` — Protoss Aggro Bullies
- `gt_StartRain` — Start Rain
- `gt_HarvestingSpeedBumpsNWesternTerritory` — Harvesting Speed Bumps - NWestern Territory
- `gt_HarvestingSpeedBumpsCentralTerritory` — Harvesting Speed Bumps - Central Territory
- `gt_NEDefenderScriptedAI`
- `gt_NEDefenderDeath`
- `gt_NEDefenderSpawned`
- `gt_NEVoidRays` — NE Void Rays
- `gt_ToshKills` — Tosh Kills
- `gt_ToshSetup` — Tosh Setup
- `gt_ToshExpo` — Tosh Expo
- `gt_ToshExpo2` — Tosh Expo 2
- `gt_PlayerExpo` — Player Expo
- `gt_BunkerRefill` — Bunker Refill
- `gt_TeleportProtossRelic` — Teleport Protoss Relic
- `gt_Playerstartsharvestingterrazine` — Player starts harvesting terrazine
- `gt_SCViskilledwhileharvesting` — SCV is killed while harvesting
- `gt_SCVharvestingmanuallystopped` — SCV harvesting manually stopped
- `gt_SCVisheadinghomewithterrazine` — SCV is heading home with terrazine
- `gt_SCVwithterrazinediesonreturntrip` — SCV with terrazine dies on return trip
- `gt_Playerhasclaimedterrazine` — Player has claimed terrazine
- `gt_Protossprobegoesidleterrazineharvestedbyplayer` — Protoss probe goes idle - terrazine harvested by player
- `gt_Probeiskilledwhileharvesting` — Probe is killed while harvesting
- `gt_Probehassealedtheterrazine` — Probe has sealed the terrazine
- `gt_MultipleTerrazineSealingAttempt` — Multiple Terrazine Sealing Attempt
- `gt_StartAI` — Start AI
- `gt_NorthernVoidRiftHarass` — Northern Void Rift Harass
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_AITerrazineSealingI` — AI Terrazine Sealing I
- `gt_StatSCVsLost` — Stat - SCVs Lost

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 80 个):

- `gt_Init03VariablesUnits` — Init 03 Variables/Units
- `gt_Init06Difficulty` — Init 06 Difficulty
- `gt_IntroSequence` — Intro Sequence
- `gt_Bon1`
- `gt_Bon2`
- `gt_Bon`
- `gt_StartGame` — Start Game
- `gt_GoliathandGatherTerrazineTipsQ` — Goliath and Gather Terrazine Tips Q
- `gt_PingTerrazineonMinimapandReveal` — Ping Terrazine on Minimap and Reveal
- `gt_ProtossAggroViaLeavingPlayerBase` — Protoss Aggro Via Leaving Player Base
- `gt_ProtossAggroViaTimer` — Protoss Aggro Via Timer
- `gt_ProtossAggroLineQ` — Protoss Aggro Line Q
- `gt_ProtossAggroBullies` — Protoss Aggro Bullies
- `gt_StartRain` — Start Rain
- `gt_HarvestingSpeedBumpsNWesternTerritory` — Harvesting Speed Bumps - NWestern Territory
- `gt_HarvestingSpeedBumpsCentralTerritory` — Harvesting Speed Bumps - Central Territory
- `gt_InitNERelicDefenders` — Init NE Relic Defenders
- `gt_NEDefenderScriptedAI`
- `gt_NEDefenderDeath`
- `gt_NEDefenderSpawned`
- `gt_NEVoidRays` — NE Void Rays
- `gt_ToshKills` — Tosh Kills
- `gt_ToshSetup` — Tosh Setup
- `gt_ToshExpo` — Tosh Expo
- `gt_ToshExpo2` — Tosh Expo 2
- `gt_PlayerExpo` — Player Expo
- `gt_BunkerRefill` — Bunker Refill
- `gt_ToshAttackWaves` — Tosh Attack Waves
- `gt_TeleportProtossRelic` — Teleport Protoss Relic
- `gt_Playerstartsharvestingterrazine` — Player starts harvesting terrazine
- `gt_ProtossmediumretaliationannounceQ` — Protoss medium retaliation announce Q
- `gt_ProtossheavyretaliationannounceQ` — Protoss heavy retaliation announce Q
- `gt_SCViskilledwhileharvesting` — SCV is killed while harvesting
- `gt_TiptoprotectSCVsQ` — Tip to protect SCV's Q
- `gt_SCVharvestingmanuallystopped` — SCV harvesting manually stopped
- `gt_PlayertriestoharvestmultiplecanistersatonceQ` — Player tries to harvest multiple canisters at once Q
- `gt_SCVisheadinghomewithterrazine` — SCV is heading home with terrazine
- `gt_FirstTerrazineReturnQ` — First Terrazine Return Q
- `gt_SCVwithterrazinediesonreturntrip` — SCV with terrazine dies on return trip
- `gt_DroppedterrazinecargoQ` — Dropped terrazine cargo Q
- `gt_Playerhasclaimedterrazine` — Player has claimed terrazine
- `gt_Playerharvested1NodeQ` — Player harvested 1 Node Q
- `gt_Playerharvested3NodeQ` — Player harvested 3 Node Q
- `gt_Playerharvested4NodeQ` — Player harvested 4 Node Q
- `gt_Playerharvested6NodeQ` — Player harvested 6 Node Q
- `gt_ProtosssealingterrazineQ` — Protoss sealing terrazine Q
- `gt_ProtossstartssealingfirstterrazinenodeQ` — Protoss starts sealing first terrazine node Q
- `gt_Protossprobegoesidleterrazineharvestedbyplayer` — Protoss probe goes idle - terrazine harvested by player
- `gt_Probeiskilledwhileharvesting` — Probe is killed while harvesting
- `gt_Probehassealedtheterrazine` — Probe has sealed the terrazine
- `gt_MultipleTerrazineSealingAttempt` — Multiple Terrazine Sealing Attempt
- `gt_Protossseal3shrinesQ` — Protoss seal 3 shrines Q
- `gt_Protossseal5shrinesQ` — Protoss seal 5 shrines Q
- `gt_Protossseal6shrinesQ` — Protoss seal 6 shrines Q
- `gt_StartAI` — Start AI
- `gt_AIP2AttackWaves` — AI P2 Attack Waves
- `gt_P2AttackWaves` — P2 Attack Waves
- `gt_NorthernVoidRiftHarass` — Northern Void Rift Harass
- `gt_P6AttackWaves` — P6 Attack Waves
- `gt_P7AttackWaves` — P7 Attack Waves
- `gt_P3PatrolWaves` — P3 Patrol Waves
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_AITerrazineSealingI` — AI Terrazine Sealing I
- `gt_StatSCVsLost` — Stat - SCVs Lost
- `gt_VictoryProtossDestroyed` — Victory Protoss Destroyed
- `gt_ProtossDestroyedQ` — Protoss Destroyed Q
- `gt_VictoryTerrazineCollected` — Victory Terrazine Collected
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatProtossSealedTooManyTerrazine` — Defeat Protoss Sealed Too Many Terrazine
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene01Action` — Briefing Scene 01 Action
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene02Action` — Briefing Scene 02 Action
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

