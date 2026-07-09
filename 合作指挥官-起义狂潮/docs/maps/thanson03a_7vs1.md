# thanson03a_7vs1(拯救海文)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/thanson03a_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 5856 |
| 触发器总数(gt_*_Func) | 111 |
| 全局变量数(gv_) | 92 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`LibA070801C`、`Lib67C0F0E7`、`LibE0EAE146` |
| 起始晶体矿 | 300 |
| 起始高能瓦斯 | 150 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | `uses_shared_ally` |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 34 |
| `unitgroup` | 12 |
| `actor` | 9 |
| `bool` | 8 |
| `unit` | 7 |
| `point[]` | 7 |
| `fixed` | 6 |
| `revealer` | 4 |
| `timer` | 2 |
| `playergroup` | 2 |
| `point` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(90 个):

- `int gv_pLAYER01_USER`
- `int gv_pLAYER02_PROTOSSVANGUARD`
- `int gv_pLAYER03_COLONISTMARINES`
- `int gv_pLAYER04_PHASESMITHS`
- `int gv_pLAYER05_COLONISTMECHS`
- `int gv_pLAYER06_FLEET`
- `int gv_pLAYER08_ELITEGUARD`
- `int gv_pLAYER09_NERAZIMBLADES`
- `int gv_pLAYER10_INFESTED`
- `int gv_pLAYER11_COLONISTFLEET`
- `int gv_pLAYER12_TEMPLARFORWARD`
- `int gv_pLAYER13_NERAZIMFORWARD`
- `int gv_pLAYER07_RESOURCES`
- `bool gv_gameOn`
- `unit gv_purifier`
- `unitgroup gv_purifierGroup`
- `unit gv_superWarpGateP02`
- `unit gv_superWarpGateP04`
- `int gv_purifierStatusBoard`
- `unitgroup gv_purifierEscortGroup`
- `unitgroup gv_prismGroupNorth`
- `unitgroup gv_prismGroupEast`
- `unitgroup gv_prismGroupSouth`
- `revealer gv_colonist_Outpost_Alpha`
- `revealer gv_colonist_Outpost_Beta`
- `revealer gv_colonist_Outpost_Gamma`
- `revealer gv_colonist_Outpost_Omega`
- `unitgroup gv_resourceGroupBeta`
- `unitgroup gv_resourceGroupGamma`
- `unitgroup gv_resourceGroupOmega`
- `actor gv_planetCrackerHoleAlpha`
- `actor gv_planetCrackerHoleBeta`
- `actor gv_planetCrackerHoleGamma`
- `actor gv_planetCrackerHoleOmega`
- `actor gv_planetCrackerHolePlayerBase`
- `timer gv_poweringUpTime`
- `fixed gv_pOWER_UP_TIME`
- `fixed gv_pURIFIER_MAX_LIFE`
- `fixed gv_cOLONIST_SHIP_MAX_LIFE`
- `int gv_colonyOutpostsSaved`
- `int gv_nexusDestroyed`
- `playergroup gv_protossPlayers`
- `playergroup gv_protossGroundPlayers`
- `point[] gv_waypointArrayForwardAiur`
- `point[] gv_waypointArrayNerazimForward`
- `point[] gv_waypointArrayEliteGuard`
- `bool gv_nexusBeingDestroyed`
- `int gv_purifierPing`
- `fixed gv_powerUpTimeProgress`
- `int gv_purifierProgressCounter`
- `point gv_purifierMainTarget`
- `fixed gv_purifierChargeTime`
- `int gv_purifierChargeTimerWindow`
- `timer gv_purifierChargeTimer`
- `int gv_wrathShotCount`
- `fixed gv_wrathRateofFire`
- `unitgroup gv_terrorFleetGroup`
- `int gv_terrorFleetPing`
- `int gv_terrorFleetsDestroyedCounter`
- `bool gv_firstFleetObjectiveFailed`
- `bool gv_secondFleetObjectiveFailed`
- `bool gv_thirdFleetObjectiveFailed`
- `point[] gv_pathtoAlpha`
- `point[] gv_pathtoBeta`
- `point[] gv_pathtoGamma`
- `point[] gv_pathtoOmega`
- `int gv_pathtoAlphaLength`
- `int gv_pathtoBetaLength`
- `int gv_pathtoGammaLength`
- `int gv_pathtoOmegaLength`
- `int gv_currentWavePath`
- `int gv_currentWaveAttacker`
- `unitgroup gv_currentWaveUnits`
- `unitgroup gv_currentWaveSources`
- `int gv_infestedBuildingKillCount`
- `int gv_vikingKills`
- `int gv_purifierKills`
- `int gv_gaspickedup`
- `int gv_mineralsPickedUp`
- `int gv_allyKills`
- `actor gv_briefingNexusPingActor`
- `actor gv_briefingVikingPingActor1`
- `actor gv_briefingVikingPingActor2`
- `actor gv_briefingVikingPingActor3`
- `unit gv_briefingViking1`
- `unit gv_briefingViking2`
- `unit gv_briefingViking3`
- `unit gv_briefingBiodome`
- `bool gv_victoryCinematicCompleted`
- `unitgroup gv_victoryHiddenUnitGroup`

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
- `gt_StartGame` — Start Game
- `gt_PURIFIERIntro` — PURIFIER Intro
- `gt_InitializePaths` — Initialize Paths
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_Briefing00Civvies` — Briefing 00 Civvies
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_Briefing02VikingIndicators` — Briefing 02 Viking Indicators
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingScene04` — Briefing Scene 04
- `gt_Briefing04Nexus` — Briefing 04 Nexus
- `gt_BriefingScene05` — Briefing Scene 05

### 进攻波次(14)

- `gt_P2Attack`
- `gt_P4Attack`
- `gt_P6Attack`
- `gt_P8EliteGuardAttackWaves` — P8 Elite Guard Attack Waves
- `gt_P12AiurForwardAttackWaves` — P12 Aiur Forward Attack Waves
- `gt_P13NerazimForwardAttackWaves` — P13 Nerazim Forward Attack Waves
- `gt_P9BladesAttackWaves` — P9 Blades Attack Waves
- `gt_P3MarineAttackWaves` — P3 Marine Attack Waves
- `gt_P5MechAttackWaves` — P5 Mech Attack Waves
- `gt_P11AirAttackWaves` — P11 Air Attack Waves
- `gt_ProtossP02AttackWaves` — Protoss P02 Attack Waves
- `gt_TransmissionBetaShipUnderAttackQ` — Transmission - Beta Ship Under Attack Q
- `gt_TransmissionGammaShipUnderAttackQ` — Transmission - Gamma Ship Under Attack Q
- `gt_TransmissionOmegaShipUnderAttackQ` — Transmission - Omega Ship Under Attack Q

### 胜负(14)

- `gt_VictoryPurifierDestroyed` — Victory Purifier Destroyed
- `gt_Victory`
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatInfestedWiped` — Defeat Infested Wiped
- `gt_DefeatColoniesDestroyed` — Defeat Colonies Destroyed
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictoryScene` — Victory Scene

### 对白提示(26)

- `gt_TransmissionProtossNexusQ` — Transmission - Protoss Nexus Q
- `gt_TransmissionHelpColonistsQ` — Transmission - Help Colonists Q
- `gt_TransmissionPurifierArrivedQ` — Transmission - Purifier Arrived Q
- `gt_TransmissionPurifierUsesVortexQ` — Transmission - Purifier Uses Vortex Q
- `gt_TransmissionNexusDestroyedQ` — Transmission - Nexus Destroyed Q
- `gt_TransmissionFirstTerrorFleetWarningQ` — Transmission - First Terror Fleet Warning Q
- `gt_TransmissionSecondTerrorFleetWarningQ` — Transmission - Second Terror Fleet Warning Q
- `gt_TransmissionThirdTerrorFleetWarningQ` — Transmission - Third Terror Fleet Warning Q
- `gt_TransmissionColonistsEvacuateBetaOutpostQ` — Transmission - Colonists Evacuate Beta Outpost Q
- `gt_TransmissionColonistsEvacuateGammaOutpostQ` — Transmission - Colonists Evacuate Gamma Outpost Q
- `gt_TransmissionColonistsEvacuateOmegaOutpostQ` — Transmission - Colonists Evacuate Omega Outpost Q
- `gt_TransmissionPurifierEntersColonistBaseAlphaQ` — Transmission - Purifier Enters Colonist Base Alpha Q
- `gt_TransmissionPurifierEntersColonistBaseBetaQ` — Transmission - Purifier Enters Colonist Base Beta Q
- `gt_TransmissionPurifierEntersColonistBaseGammaQ` — Transmission - Purifier Enters Colonist Base Gamma Q
- `gt_TransmissionPurifierEntersColonistBaseOmegaQ` — Transmission - Purifier Enters Colonist Base Omega Q
- `gt_TransmissionPurifierEntersPlayerBaseQ` — Transmission - Purifier Enters Player Base Q
- `gt_TransmissionPurifierAboutToFire` — Transmission - Purifier About To Fire
- `gt_PlayerkillscolonistsQ` — Player kills colonists Q
- `gt_PlayerkillscolonistsAgainQ` — Player kills colonists Again Q
- `gt_PlayerkillscolonisthomesQ` — Player kills colonist homes Q
- `gt_Colonistskeepdyingline1Q` — Colonists keep dying line 1 Q
- `gt_Colonistskeepdyingline2Q` — Colonists keep dying line 2 Q
- `gt_Colonistskeepdyingline4Q` — Colonists keep dying line 4 Q
- `gt_CampaignTipsQ` — Campaign Tips Q
- `gt_NewUnitVikingTipQ` — New Unit: Viking Tip Q
- `gt_NewEnemyPurifierTipQ` — New Enemy: Purifier Tip Q

### 其他(36)

- `gt_CreateNexusPings` — Create Nexus Pings
- `gt_P2Stop`
- `gt_Inf`
- `gt_Alli`
- `gt_Pickups`
- `gt_PurifierUsesVortex` — Purifier Uses Vortex
- `gt_Gameover`
- `gt_OrbitalBarrage` — Orbital Barrage
- `gt_VortexSpread` — Vortex Spread
- `gt_PurifierBeam` — Purifier Beam
- `gt_PurifierReinforcements` — Purifier Reinforcements
- `gt_WarpInUnitsStarted` — Warp-In Units Started
- `gt_WarpInUnitsBehavior` — Warp-In Units Behavior
- `gt_ColonistsWander` — Colonists Wander
- `gt_ColonistsGarrisonPlayerBase` — Colonists Garrison Player Base
- `gt_RemoveLoadingColonist` — Remove Loading Colonist
- `gt_ShowPathtoAlphaBase` — Show Path to Alpha Base
- `gt_ShowPathtoBetaBase` — Show Path to Beta Base
- `gt_ShowPathtoGammaBase` — Show Path to Gamma Base
- `gt_ShowPathtoOmegaBase` — Show Path to Omega Base
- `gt_ProtossP02WarpInUnitsBehavior` — Protoss P02 Warp-In Units Behavior
- `gt_StartAI` — Start AI
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_AlliedBulliesMarinesinVanguardBase` — Allied Bullies - Marines in Vanguard Base
- `gt_AlliedBulliesMarinesCenter` — Allied Bullies - Marines Center
- `gt_AlliedBulliesMechBuildup` — Allied Bullies - Mech Buildup
- `gt_AlliedBulliesFleetBuildup` — Allied Bullies - Fleet Buildup
- `gt_AlliedBulliesMines` — Allied Bullies - Mines
- `gt_BunkerRefill` — Bunker Refill
- `gt_ColonistKilled` — Colonist Killed
- `gt_ColonistKilledIncrement` — Colonist Killed Increment
- `gt_Playerkillscolonists` — Player kills colonists
- `gt_VikingKillsofEnemyUnits` — Viking Kills of Enemy Units
- `gt_StatsPurifierKills` — Stats - Purifier Kills
- `gt_MilitiaKills` — Militia Kills
- `gt_Brieifng00Air` — Brieifng 00 Air

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 101 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_CreateNexusPings` — Create Nexus Pings
- `gt_P2Stop`
- `gt_Inf`
- `gt_Alli`
- `gt_Pickups`
- `gt_PURIFIERIntro` — PURIFIER Intro
- `gt_PurifierUsesVortex` — Purifier Uses Vortex
- `gt_Gameover`
- `gt_OrbitalBarrage` — Orbital Barrage
- `gt_VortexSpread` — Vortex Spread
- `gt_PurifierBeam` — Purifier Beam
- `gt_PurifierReinforcements` — Purifier Reinforcements
- `gt_WarpInUnitsStarted` — Warp-In Units Started
- `gt_WarpInUnitsBehavior` — Warp-In Units Behavior
- `gt_ColonistsWander` — Colonists Wander
- `gt_ColonistsGarrisonPlayerBase` — Colonists Garrison Player Base
- `gt_RemoveLoadingColonist` — Remove Loading Colonist
- `gt_InitializePaths` — Initialize Paths
- `gt_ShowPathtoAlphaBase` — Show Path to Alpha Base
- `gt_ShowPathtoBetaBase` — Show Path to Beta Base
- `gt_ShowPathtoGammaBase` — Show Path to Gamma Base
- `gt_ShowPathtoOmegaBase` — Show Path to Omega Base
- `gt_ProtossP02WarpInUnitsBehavior` — Protoss P02 Warp-In Units Behavior
- `gt_StartAI` — Start AI
- `gt_P2Attack`
- `gt_P4Attack`
- `gt_P6Attack`
- `gt_P8EliteGuardAttackWaves` — P8 Elite Guard Attack Waves
- `gt_P12AiurForwardAttackWaves` — P12 Aiur Forward Attack Waves
- `gt_P13NerazimForwardAttackWaves` — P13 Nerazim Forward Attack Waves
- `gt_P9BladesAttackWaves` — P9 Blades Attack Waves
- `gt_P3MarineAttackWaves` — P3 Marine Attack Waves
- `gt_P5MechAttackWaves` — P5 Mech Attack Waves
- `gt_P11AirAttackWaves` — P11 Air Attack Waves
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_ProtossP02AttackWaves` — Protoss P02 Attack Waves
- `gt_AlliedBulliesMarinesinVanguardBase` — Allied Bullies - Marines in Vanguard Base
- `gt_AlliedBulliesMarinesCenter` — Allied Bullies - Marines Center
- `gt_AlliedBulliesMechBuildup` — Allied Bullies - Mech Buildup
- `gt_AlliedBulliesFleetBuildup` — Allied Bullies - Fleet Buildup
- `gt_AlliedBulliesMines` — Allied Bullies - Mines
- `gt_BunkerRefill` — Bunker Refill
- `gt_TransmissionProtossNexusQ` — Transmission - Protoss Nexus Q
- `gt_TransmissionHelpColonistsQ` — Transmission - Help Colonists Q
- `gt_TransmissionPurifierArrivedQ` — Transmission - Purifier Arrived Q
- `gt_TransmissionPurifierUsesVortexQ` — Transmission - Purifier Uses Vortex Q
- `gt_TransmissionBetaShipUnderAttackQ` — Transmission - Beta Ship Under Attack Q
- `gt_TransmissionGammaShipUnderAttackQ` — Transmission - Gamma Ship Under Attack Q
- `gt_TransmissionOmegaShipUnderAttackQ` — Transmission - Omega Ship Under Attack Q
- `gt_TransmissionNexusDestroyedQ` — Transmission - Nexus Destroyed Q
- `gt_TransmissionFirstTerrorFleetWarningQ` — Transmission - First Terror Fleet Warning Q
- `gt_TransmissionSecondTerrorFleetWarningQ` — Transmission - Second Terror Fleet Warning Q
- `gt_TransmissionThirdTerrorFleetWarningQ` — Transmission - Third Terror Fleet Warning Q
- `gt_TransmissionColonistsEvacuateBetaOutpostQ` — Transmission - Colonists Evacuate Beta Outpost Q
- `gt_TransmissionColonistsEvacuateGammaOutpostQ` — Transmission - Colonists Evacuate Gamma Outpost Q
- `gt_TransmissionColonistsEvacuateOmegaOutpostQ` — Transmission - Colonists Evacuate Omega Outpost Q
- `gt_TransmissionPurifierEntersColonistBaseAlphaQ` — Transmission - Purifier Enters Colonist Base Alpha Q
- `gt_TransmissionPurifierEntersColonistBaseBetaQ` — Transmission - Purifier Enters Colonist Base Beta Q
- `gt_TransmissionPurifierEntersColonistBaseGammaQ` — Transmission - Purifier Enters Colonist Base Gamma Q
- `gt_TransmissionPurifierEntersColonistBaseOmegaQ` — Transmission - Purifier Enters Colonist Base Omega Q
- `gt_TransmissionPurifierEntersPlayerBaseQ` — Transmission - Purifier Enters Player Base Q
- `gt_TransmissionPurifierAboutToFire` — Transmission - Purifier About To Fire
- `gt_ColonistKilled` — Colonist Killed
- `gt_ColonistKilledIncrement` — Colonist Killed Increment
- `gt_Playerkillscolonists` — Player kills colonists
- `gt_PlayerkillscolonistsQ` — Player kills colonists Q
- `gt_PlayerkillscolonistsAgainQ` — Player kills colonists Again Q
- `gt_PlayerkillscolonisthomesQ` — Player kills colonist homes Q
- `gt_Colonistskeepdyingline1Q` — Colonists keep dying line 1 Q
- `gt_Colonistskeepdyingline2Q` — Colonists keep dying line 2 Q
- `gt_Colonistskeepdyingline4Q` — Colonists keep dying line 4 Q
- `gt_CampaignTipsQ` — Campaign Tips Q
- `gt_NewUnitVikingTipQ` — New Unit: Viking Tip Q
- `gt_NewEnemyPurifierTipQ` — New Enemy: Purifier Tip Q
- `gt_VikingKillsofEnemyUnits` — Viking Kills of Enemy Units
- `gt_StatsPurifierKills` — Stats - Purifier Kills
- `gt_MilitiaKills` — Militia Kills
- `gt_VictoryPurifierDestroyed` — Victory Purifier Destroyed
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatInfestedWiped` — Defeat Infested Wiped
- `gt_DefeatColoniesDestroyed` — Defeat Colonies Destroyed
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_Briefing00Civvies` — Briefing 00 Civvies
- `gt_Brieifng00Air` — Brieifng 00 Air
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_Briefing02VikingIndicators` — Briefing 02 Viking Indicators
- `gt_BriefingScene03` — Briefing Scene 03
- `gt_BriefingScene04` — Briefing Scene 04
- `gt_Briefing04Nexus` — Briefing 04 Nexus
- `gt_BriefingScene05` — Briefing Scene 05
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictoryScene` — Victory Scene

