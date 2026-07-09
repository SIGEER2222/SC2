# thanson01_7vs1(大撤离)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/thanson01_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 5525 |
| 触发器总数(gt_*_Func) | 96 |
| 全局变量数(gv_) | 46 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`LibA070801C`、`Lib67C0F0E7`、`LibDF8E6945`、`Lib0940FFB7`、`LibE0EAE146` |
| 起始晶体矿 | 200 |
| 起始高能瓦斯 | 50 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | `uses_shared_ally` |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 21 |
| `unitgroup` | 7 |
| `bool` | 5 |
| `unit` | 4 |
| `fixed` | 3 |
| `timer` | 2 |
| `point` | 2 |
| `playergroup` | 1 |
| `string` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(44 个):

- `int gv_p1_USER`
- `int gv_p2_ZERG_ORANGE_NW`
- `int gv_p3_ZERG_LIGHTBLUE_SE`
- `int gv_p4_COLONISTS`
- `int gv_p5_ZERG_TACTICALPHASE`
- `int gv_p6_ZERG_NOAIPREPLACED`
- `int gv_p7_LEFT_MILITIA`
- `int gv_p8_RIGHT_MILITIA`
- `int gv_p9_RAVAGERS`
- `int gv_p10_LEVIATHAN`
- `playergroup gv_zergPlayers`
- `unitgroup gv_civilianSpawners`
- `unit gv_crazyRidley`
- `bool gv_enoughColonistsSavedThisWave`
- `unitgroup gv_colonistsOnTheMove`
- `int gv_escortIndex`
- `int gv_structuresLost`
- `unitgroup gv_zergOnTheLoose`
- `unitgroup gv_zergOnTheLoose2`
- `int gv_colonistsKilled`
- `int gv_objCom`
- `timer gv_doomsdayTimer`
- `int gv_doomsdayWavesSent`
- `timer gv_dropPodTimer`
- `int gv_dropperlordCycle`
- `int gv_doomsdayZergSpawnCount`
- `point gv_tempTumorPoint`
- `point gv_tempNydusPoint`
- `int gv_tempNydusPacks`
- `int gv_tempNydusPackSize`
- `fixed gv_tempNydusCooldown`
- `string gv_tempNydusType`
- `unitgroup gv_activeNydusWorms`
- `fixed gv_nydusSpawnDelay`
- `fixed gv_nydusWormHP`
- `unitgroup gv_doomsdayZergUnitGroup`
- `unit gv_blastOffShip`
- `int gv_convoyTrucksKilled`
- `int gv_allyKills`
- `bool gv_briefingCinematicPlaying`
- `unit gv_briefingTransport1`
- `unit gv_briefingBunker`
- `unitgroup gv_victoryHiddenUnitGroup`
- `bool gv_victoryCinematicCompleted`

## 触发器清单

### 初始化(15)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03VariablesUnits` — Init 03 Variables/Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulty` — Init 06 Difficulty
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_StarportIntroQ` — Starport Intro Q
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingSetup` — Briefing Setup
- `gt_BriefingAction01Road` — Briefing Action 01 - Road
- `gt_BriefingAction02HansonsColony` — Briefing Action 02 - Hanson's Colony
- `gt_BriefingAction03Fighting` — Briefing Action 03 - Fighting

### 进攻波次(24)

- `gt_P2Attack`
- `gt_P3Attack`
- `gt_P5Attack`
- `gt_AttackWaveStop5`
- `gt_AttackWaveStop2`
- `gt_AttackWaveStop3`
- `gt_P9AttackWaves` — P9 Attack Waves
- `gt_P10AttackWaves` — P10 Attack Waves
- `gt_DoomsdayZergAttackWavesAnnounceQ` — Doomsday Zerg Attack Waves Announce Q
- `gt_DoomsdayZergAttackWaves` — Doomsday Zerg Attack Waves
- `gt_DropPodController` — Drop Pod Controller
- `gt_DropperlordWaves` — Dropperlord Waves
- `gt_P7Patrols` — P7 Patrols
- `gt_P8Patrols` — P8 Patrols
- `gt_ConvoyAttack1Freebie` — Convoy Attack 1 (Freebie)
- `gt_ConvoyAttack2StressBunkersnotallfull` — Convoy Attack 2 (Stress Bunkers - not all full)
- `gt_ConvoyAttack3Burnsinglebunkers` — Convoy Attack 3 (Burn single bunkers)
- `gt_ConvoyAttack4Droppods` — Convoy Attack 4 (Drop pods)
- `gt_ConvoyAttack5Nydusworms` — Convoy Attack 5 (Nydus worms)
- `gt_ConvoyAttack6AHH` — Convoy Attack 6 (AHH)
- `gt_ConvoyAttack7VariationAHH` — Convoy Attack 7 (Variation AHH)
- `gt_TumorSpawningTrigger` — Tumor Spawning Trigger
- `gt_NydusSpawningTrigger` — Nydus Spawning Trigger
- `gt_WaveOver03TipaboutzergdroppodsQ` — Wave Over 03 Tip about zerg drop pods Q

### 胜负(17)

- `gt_DefeatBaseDead` — Defeat - Base Dead
- `gt_DefeatTacticalPhase` — Defeat - Tactical Phase
- `gt_DefeatColonyShipDead` — Defeat - Colony Ship Dead
- `gt_DefeatColonistHutsDie` — Defeat - Colonist Huts Die
- `gt_DefeatTooManyColonistsDie` — Defeat - Too Many Colonists Die
- `gt_VictoryPlayerSavesEnoughColonists` — Victory Player Saves Enough Colonists
- `gt_VictoryPlayerSavesEnoughColonistsQ` — Victory Player Saves Enough Colonists Q
- `gt_Victory`
- `gt_VictoryCheat` — Victory Cheat
- `gt_Defeat`
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryAction` — Victory Action
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

### 对白提示(13)

- `gt_SwanntalksaboutFirebatQ` — Swann talks about Firebat Q
- `gt_SwitchtoEscortPhaseQ` — Switch to Escort Phase Q
- `gt_DropperlordQ` — Dropperlord Q
- `gt_ColonistsHeadsupMessageEarlyQ` — Colonists Headsup Message Early Q
- `gt_ColonistsHeadsupMessageMidQ` — Colonists Headsup Message Mid Q
- `gt_ColonistsHeadsupMessageLateQ` — Colonists Headsup Message Late Q
- `gt_ColonistsGOGOMessageEarlyQ` — Colonists GOGO Message Early Q
- `gt_ColonistsGOGOMessageLateQ` — Colonists GOGO Message Late Q
- `gt_BunkerLineQ` — Bunker Line Q
- `gt_Colonistskeepdyingline1Q` — Colonists keep dying line 1 Q
- `gt_Colonistskeepdyingline2Q` — Colonists keep dying line 2 Q
- `gt_Colonistskeepdyingline3Q` — Colonists keep dying line 3 Q
- `gt_Colonistskeepdyingline4Q` — Colonists keep dying line 4 Q

### 其他(27)

- `gt_FirebatDropshipAction` — Firebat Dropship Action
- `gt_ZergontheLoose` — Zerg on the Loose
- `gt_ZergontheLoose2` — Zerg on the Loose 2
- `gt_Zerg1` — Zerg 1
- `gt_Zerg3` — Zerg 3
- `gt_SwitchtoEscortPhase` — Switch to Escort Phase
- `gt_ResourcePickups` — Resource Pickups
- `gt_MainObj`
- `gt_finish`
- `gt_StartHansonEscortPhase` — Start Hanson Escort Phase
- `gt_Main`
- `gt_Right`
- `gt_Left`
- `gt_convoyDead`
- `gt_PingMidPath` — Ping Mid Path
- `gt_PingRightPath` — Ping Right Path
- `gt_PingLeftPath` — Ping Left Path
- `gt_StartAI` — Start AI
- `gt_ResearchObjectiveChrysalisUpdate2` — Research Objective - Chrysalis - Update 2
- `gt_ScourgeNestsDead`
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_DoomsdayZergAI` — Doomsday Zerg AI
- `gt_DropperlordQMulti` — Dropperlord Q Multi
- `gt_BunkerGet1` — Bunker Get 1
- `gt_BackdoorSpoogeAmbience` — Backdoor Spooge Ambience
- `gt_ColonyShipBlastoffActions` — Colony Ship Blastoff Actions
- `gt_MilitiaKills` — Militia Kills

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 86 个):

- `gt_Init03VariablesUnits` — Init 03 Variables/Units
- `gt_Init06Difficulty` — Init 06 Difficulty
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_SwanntalksaboutFirebatQ` — Swann talks about Firebat Q
- `gt_FirebatDropshipAction` — Firebat Dropship Action
- `gt_ZergontheLoose` — Zerg on the Loose
- `gt_ZergontheLoose2` — Zerg on the Loose 2
- `gt_Zerg1` — Zerg 1
- `gt_Zerg3` — Zerg 3
- `gt_SwitchtoEscortPhase` — Switch to Escort Phase
- `gt_SwitchtoEscortPhaseQ` — Switch to Escort Phase Q
- `gt_ResourcePickups` — Resource Pickups
- `gt_MainObj`
- `gt_finish`
- `gt_StartHansonEscortPhase` — Start Hanson Escort Phase
- `gt_Main`
- `gt_Right`
- `gt_Left`
- `gt_convoyDead`
- `gt_PingMidPath` — Ping Mid Path
- `gt_PingRightPath` — Ping Right Path
- `gt_PingLeftPath` — Ping Left Path
- `gt_StarportIntroQ` — Starport Intro Q
- `gt_StartAI` — Start AI
- `gt_ResearchObjectiveChrysalisUpdate2` — Research Objective - Chrysalis - Update 2
- `gt_ScourgeNestsDead`
- `gt_DefeatBaseDead` — Defeat - Base Dead
- `gt_DefeatTacticalPhase` — Defeat - Tactical Phase
- `gt_DefeatColonyShipDead` — Defeat - Colony Ship Dead
- `gt_DefeatColonistHutsDie` — Defeat - Colonist Huts Die
- `gt_DefeatTooManyColonistsDie` — Defeat - Too Many Colonists Die
- `gt_VictoryPlayerSavesEnoughColonists` — Victory Player Saves Enough Colonists
- `gt_VictoryPlayerSavesEnoughColonistsQ` — Victory Player Saves Enough Colonists Q
- `gt_P2Attack`
- `gt_P3Attack`
- `gt_P5Attack`
- `gt_AttackWaveStop5`
- `gt_AttackWaveStop2`
- `gt_AttackWaveStop3`
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_P9AttackWaves` — P9 Attack Waves
- `gt_P10AttackWaves` — P10 Attack Waves
- `gt_DoomsdayZergAttackWavesAnnounceQ` — Doomsday Zerg Attack Waves Announce Q
- `gt_DoomsdayZergAttackWaves` — Doomsday Zerg Attack Waves
- `gt_DoomsdayZergAI` — Doomsday Zerg AI
- `gt_DropPodController` — Drop Pod Controller
- `gt_DropperlordWaves` — Dropperlord Waves
- `gt_DropperlordQ` — Dropperlord Q
- `gt_DropperlordQMulti` — Dropperlord Q Multi
- `gt_P7Patrols` — P7 Patrols
- `gt_P8Patrols` — P8 Patrols
- `gt_ColonistsHeadsupMessageEarlyQ` — Colonists Headsup Message Early Q
- `gt_ColonistsHeadsupMessageMidQ` — Colonists Headsup Message Mid Q
- `gt_ColonistsHeadsupMessageLateQ` — Colonists Headsup Message Late Q
- `gt_ColonistsGOGOMessageEarlyQ` — Colonists GOGO Message Early Q
- `gt_ColonistsGOGOMessageLateQ` — Colonists GOGO Message Late Q
- `gt_BunkerGet1` — Bunker Get 1
- `gt_BunkerLineQ` — Bunker Line Q
- `gt_ConvoyAttack1Freebie` — Convoy Attack 1 (Freebie)
- `gt_ConvoyAttack2StressBunkersnotallfull` — Convoy Attack 2 (Stress Bunkers - not all full)
- `gt_ConvoyAttack3Burnsinglebunkers` — Convoy Attack 3 (Burn single bunkers)
- `gt_ConvoyAttack4Droppods` — Convoy Attack 4 (Drop pods)
- `gt_ConvoyAttack5Nydusworms` — Convoy Attack 5 (Nydus worms)
- `gt_ConvoyAttack6AHH` — Convoy Attack 6 (AHH)
- `gt_ConvoyAttack7VariationAHH` — Convoy Attack 7 (Variation AHH)
- `gt_BackdoorSpoogeAmbience` — Backdoor Spooge Ambience
- `gt_TumorSpawningTrigger` — Tumor Spawning Trigger
- `gt_NydusSpawningTrigger` — Nydus Spawning Trigger
- `gt_ColonyShipBlastoffActions` — Colony Ship Blastoff Actions
- `gt_WaveOver03TipaboutzergdroppodsQ` — Wave Over 03 Tip about zerg drop pods Q
- `gt_Colonistskeepdyingline1Q` — Colonists keep dying line 1 Q
- `gt_Colonistskeepdyingline2Q` — Colonists keep dying line 2 Q
- `gt_Colonistskeepdyingline3Q` — Colonists keep dying line 3 Q
- `gt_Colonistskeepdyingline4Q` — Colonists keep dying line 4 Q
- `gt_MilitiaKills` — Militia Kills
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingSetup` — Briefing Setup
- `gt_BriefingAction01Road` — Briefing Action 01 - Road
- `gt_BriefingAction02HansonsColony` — Briefing Action 02 - Hanson's Colony
- `gt_BriefingAction03Fighting` — Briefing Action 03 - Fighting
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryAction` — Victory Action
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

