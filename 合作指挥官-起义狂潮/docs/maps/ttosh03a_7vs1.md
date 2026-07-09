# ttosh03a_7vs1(营救)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/ttosh03a_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 3070 |
| 触发器总数(gt_*_Func) | 61 |
| 全局变量数(gv_) | 33 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`LibA070801C`、`Lib67C0F0E7`、`LibE0EAE146` |
| 起始晶体矿 | 500 |
| 起始高能瓦斯 | 300 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 25 |
| `bool` | 4 |
| `unit` | 2 |
| `timer` | 1 |
| `unitgroup` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(31 个):

- `int gv_p1_USER`
- `int gv_p2_RAYNOR_LIGHTBLUE`
- `int gv_p3_DOMINION_RED`
- `int gv_p4_DOMINION_PURPLE`
- `int gv_p5_DOMINION_GREY`
- `int gv_p6_DOMINION_ORANGE`
- `int gv_p7_PRISONER_YELLOW`
- `int gv_p8_RAYNOR_MID`
- `int gv_p9_RAYNOR_BOTTOM`
- `int gv_p11_RAYNOR_TOP`
- `int gv_p12_ALLIED_CELLBLOCK_B`
- `int gv_p10_DOMINIONWrecker`
- `int gv_p13_DOMINIONCONSCRIPTS`
- `int gv_p14_NOVA`
- `int gv_p0_NEUTRAL`
- `unit gv_ghostEMP`
- `unit gv_tosh`
- `int gv_raynorAttack`
- `int gv_p3Attack`
- `int gv_attack1`
- `int gv_attack2`
- `int gv_attack3`
- `timer gv_achievementHardTimer`
- `bool gv_achievementToshHealthBelow100`
- `int gv_bonusCreditsEarned`
- `int gv_cellBlocksFreed`
- `int gv_enemiesKilledByNukes`
- `int gv_enemiesKilled`
- `int gv_toshLowestHealth`
- `unitgroup gv_victoryHiddenUnitGroup`
- `bool gv_victoryCinematicCompleted`

## 触发器清单

### 初始化(15)

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
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingScene04` — Briefing Scene 04

### 进攻波次(10)

- `gt_RaynorsBaseUnderAttackQ` — Raynor'sBaseUnderAttack Q
- `gt_CellBlockBRavenPatrol` — Cell Block B Raven Patrol
- `gt_P14NovaAttackWaves` — P14 Nova Attack Waves
- `gt_P2RaynorNormalAttackWaves` — P2 Raynor Normal Attack Waves
- `gt_P3Attack`
- `gt_PAttack1`
- `gt_PAttack2`
- `gt_PAttack3`
- `gt_P13AttackWaves` — P13 Attack Waves
- `gt_P10AttackWaves` — P10 Attack Waves

### 胜负(14)

- `gt_VictoryMainPrisonCleared` — Victory - Main Prison Cleared
- `gt_Victory`
- `gt_DefeatRaynorBaseDead` — Defeat - Raynor Base Dead
- `gt_DefeatPlayerBaseDead` — Defeat - Player Base Dead
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryDoorAnimation` — Victory Door Animation
- `gt_VictoryCinematicDoorSounds` — Victory Cinematic Door Sounds
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

### 对白提示(5)

- `gt_OpeningDialogueQ` — Opening Dialogue Q
- `gt_CellBlockACompletedQ` — Cell Block A Completed Q
- `gt_CellBlockBCompletedQ` — Cell Block B Completed Q
- `gt_CellBlockCCompletedQ` — Cell Block C Completed Q
- `gt_DialogueRaynorsForcesQ` — Dialogue Raynor's Forces Q

### 其他(17)

- `gt_bon2`
- `gt_GuardTowersInitiate` — Guard Towers Initiate
- `gt_CellBlockACompleted` — Cell Block A Completed
- `gt_CellBlockBCompleted` — Cell Block B Completed
- `gt_CellBlockCCompleted` — Cell Block C Completed
- `gt_MidLaneBase1` — Mid Lane Base 1
- `gt_MidLaneBase2` — Mid Lane Base 2
- `gt_BotLaneBase1` — Bot Lane Base 1
- `gt_BotLaneBase2` — Bot Lane Base 2
- `gt_TopLaneBase1` — Top Lane Base 1
- `gt_TopLaneBase2` — Top Lane Base 2
- `gt_TopLaneBaseCheckpoint` — Top Lane Base Checkpoint
- `gt_StartAI` — Start AI
- `gt_ENEMYRavensActivateArea03Approached` — ENEMY Ravens Activate - Area 03 Approached
- `gt_StatEnemiesKilledByNukes` — Stat - Enemies Killed By Nukes
- `gt_StatEnemiesKilledbyAnyone` — Stat - Enemies Killed by Anyone
- `gt_StatToshLowestHealth` — Stat - Tosh Lowest Health

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 51 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_bon2`
- `gt_OpeningDialogueQ` — Opening Dialogue Q
- `gt_GuardTowersInitiate` — Guard Towers Initiate
- `gt_RaynorsBaseUnderAttackQ` — Raynor'sBaseUnderAttack Q
- `gt_CellBlockACompleted` — Cell Block A Completed
- `gt_CellBlockACompletedQ` — Cell Block A Completed Q
- `gt_CellBlockBCompleted` — Cell Block B Completed
- `gt_CellBlockBCompletedQ` — Cell Block B Completed Q
- `gt_CellBlockBRavenPatrol` — Cell Block B Raven Patrol
- `gt_CellBlockCCompleted` — Cell Block C Completed
- `gt_CellBlockCCompletedQ` — Cell Block C Completed Q
- `gt_DialogueRaynorsForcesQ` — Dialogue Raynor's Forces Q
- `gt_MidLaneBase1` — Mid Lane Base 1
- `gt_MidLaneBase2` — Mid Lane Base 2
- `gt_BotLaneBase1` — Bot Lane Base 1
- `gt_BotLaneBase2` — Bot Lane Base 2
- `gt_TopLaneBase1` — Top Lane Base 1
- `gt_TopLaneBase2` — Top Lane Base 2
- `gt_TopLaneBaseCheckpoint` — Top Lane Base Checkpoint
- `gt_StartAI` — Start AI
- `gt_P14NovaAttackWaves` — P14 Nova Attack Waves
- `gt_P2RaynorNormalAttackWaves` — P2 Raynor Normal Attack Waves
- `gt_P3Attack`
- `gt_PAttack1`
- `gt_PAttack2`
- `gt_PAttack3`
- `gt_P13AttackWaves` — P13 Attack Waves
- `gt_P10AttackWaves` — P10 Attack Waves
- `gt_ENEMYRavensActivateArea03Approached` — ENEMY Ravens Activate - Area 03 Approached
- `gt_StatEnemiesKilledByNukes` — Stat - Enemies Killed By Nukes
- `gt_StatEnemiesKilledbyAnyone` — Stat - Enemies Killed by Anyone
- `gt_StatToshLowestHealth` — Stat - Tosh Lowest Health
- `gt_VictoryMainPrisonCleared` — Victory - Main Prison Cleared
- `gt_DefeatRaynorBaseDead` — Defeat - Raynor Base Dead
- `gt_DefeatPlayerBaseDead` — Defeat - Player Base Dead
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingScene04` — Briefing Scene 04
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryDoorAnimation` — Victory Door Animation
- `gt_VictoryCinematicDoorSounds` — Victory Cinematic Door Sounds
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

