# traynor02_7vs1(不法之徒)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/traynor02_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 3071 |
| 触发器总数(gt_*_Func) | 64 |
| 全局变量数(gv_) | 26 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`LibA070801C`、`Lib67C0F0E7`、`LibE0EAE146` |
| 起始晶体矿 | 按难度 [200, 100, 100, 100] |
| 起始高能瓦斯 | 默认 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 12 |
| `bool` | 6 |
| `unitgroup` | 3 |
| `unit` | 3 |
| `playergroup` | 1 |
| `revealer` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(24 个):

- `int gv_pLAYER_01_USER`
- `int gv_pLAYER_02_DOMINION`
- `int gv_pLAYER_03_COLONISTS`
- `int gv_pLAYER_04_REBELS`
- `int gv_pLAYER_05_PATROL`
- `playergroup gv_enemyPlayers`
- `bool gv_initialOrderGiven`
- `unitgroup gv_initialAttackSquad`
- `int gv_dominionAttackSquadSize`
- `unitgroup gv_marinesRescued`
- `unit gv_medicBarracks`
- `unit gv_rebelBeacon`
- `int gv_mineGuardPairs`
- `int gv_guardsKilled`
- `unitgroup gv_mineGuardGroup`
- `bool gv_mineGuardsDefeated`
- `int gv_mineGuardsState`
- `unit gv_marineTaunter`
- `bool gv_lowerAnimation`
- `revealer gv_artifactRevealer`
- `int gv_medicsTrained`
- `int gv_palletsCollected`
- `int gv_numberOfPallets`
- `bool gv_victoryCinematicCompleted`

## 触发器清单

### 初始化(13)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03Units` — Init 03 Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02

### 进攻波次(5)

- `gt_HellionAttack` — Hellion Attack
- `gt_P2Attack`
- `gt_P5Attack`
- `gt_AIAttakcWaveUpgrade`
- `gt_VictoryMarinePatrol` — Victory Marine Patrol

### 胜负(12)

- `gt_MineGuardsDefeated` — Mine Guards Defeated
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_VictoryDominionOutpostCompleted` — Victory Dominion Outpost Completed
- `gt_Victory`
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

### 对白提示(16)

- `gt_BuildMarinesandSCVsQ` — Build Marines and SCVs Q
- `gt_ProdQ` — Prod Q
- `gt_RebelsTriggeredQ` — Rebels Triggered Q
- `gt_RebelsCompleteQ` — Rebels Complete Q
- `gt_RebelsRescuedQ` — Rebels Rescued Q
- `gt_Colonist1Q` — Colonist 1 Q
- `gt_Colonist2Q` — Colonist 2 Q
- `gt_Colonist3Q` — Colonist 3 Q
- `gt_Colonist4Q` — Colonist 4 Q
- `gt_Colonist5Q` — Colonist 5 Q
- `gt_Colonist6Q` — Colonist 6 Q
- `gt_Colonist7Q` — Colonist 7 Q
- `gt_HellionQ` — Hellion Q
- `gt_MarineTauntQ` — Marine Taunt Q
- `gt_BunkerDeathQ` — Bunker Death Q
- `gt_BarracksFactoryQ` — Barracks Factory Q

### 其他(18)

- `gt_NullNeut`
- `gt_RebelsTriggeredProximity` — Rebels Triggered - Proximity
- `gt_RebelsDestroyed` — Rebels Destroyed
- `gt_MineGuardsActivate` — Mine Guards Activate
- `gt_MineGuardsLoop` — Mine Guards Loop
- `gt_Despawning`
- `gt_ArtifactReveal` — Artifact Reveal
- `gt_RockMiners` — Rock Miners
- `gt_MinerLeft` — Miner - Left
- `gt_MinerTop` — Miner - Top
- `gt_MinerRight` — Miner - Right
- `gt_MinerDespawn` — Miner Despawn
- `gt_StartAI` — Start AI
- `gt_P5Stop`
- `gt_ResourcePalletPickups` — Resource Pallet Pickups
- `gt_ObjectiveCCComplete` — Objective CC Complete
- `gt_LowerCrane` — Lower Crane
- `gt_RaiseCrane` — Raise Crane

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 54 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_NullNeut`
- `gt_BuildMarinesandSCVsQ` — Build Marines and SCVs Q
- `gt_ProdQ` — Prod Q
- `gt_RebelsTriggeredProximity` — Rebels Triggered - Proximity
- `gt_RebelsTriggeredQ` — Rebels Triggered Q
- `gt_RebelsCompleteQ` — Rebels Complete Q
- `gt_RebelsDestroyed` — Rebels Destroyed
- `gt_RebelsRescuedQ` — Rebels Rescued Q
- `gt_Colonist1Q` — Colonist 1 Q
- `gt_Colonist2Q` — Colonist 2 Q
- `gt_Colonist3Q` — Colonist 3 Q
- `gt_Colonist4Q` — Colonist 4 Q
- `gt_Colonist5Q` — Colonist 5 Q
- `gt_Colonist6Q` — Colonist 6 Q
- `gt_Colonist7Q` — Colonist 7 Q
- `gt_HellionAttack` — Hellion Attack
- `gt_HellionQ` — Hellion Q
- `gt_MineGuardsActivate` — Mine Guards Activate
- `gt_MineGuardsLoop` — Mine Guards Loop
- `gt_MineGuardsDefeated` — Mine Guards Defeated
- `gt_Despawning`
- `gt_MarineTauntQ` — Marine Taunt Q
- `gt_BunkerDeathQ` — Bunker Death Q
- `gt_BarracksFactoryQ` — Barracks Factory Q
- `gt_ArtifactReveal` — Artifact Reveal
- `gt_RockMiners` — Rock Miners
- `gt_MinerLeft` — Miner - Left
- `gt_MinerTop` — Miner - Top
- `gt_MinerRight` — Miner - Right
- `gt_MinerDespawn` — Miner Despawn
- `gt_StartAI` — Start AI
- `gt_P2Attack`
- `gt_P5Attack`
- `gt_P5Stop`
- `gt_AIAttakcWaveUpgrade`
- `gt_ResourcePalletPickups` — Resource Pallet Pickups
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_VictoryDominionOutpostCompleted` — Victory Dominion Outpost Completed
- `gt_ObjectiveCCComplete` — Objective CC Complete
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_LowerCrane` — Lower Crane
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_RaiseCrane` — Raise Crane
- `gt_VictoryMarinePatrol` — Victory Marine Patrol

