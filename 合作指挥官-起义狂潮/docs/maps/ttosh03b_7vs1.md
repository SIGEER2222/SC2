# ttosh03b_7vs1(幽灵一击)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/ttosh03b_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 3754 |
| 触发器总数(gt_*_Func) | 80 |
| 全局变量数(gv_) | 106 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`LibA070801C`、`Lib67C0F0E7`、`LibC0F50AA6`、`Lib81FF3B49`、`LibDF8E6945`、`Lib0940FFB7`、`Lib975E2FE9`、`LibE0EAE146` |
| 起始晶体矿 | 2000 |
| 起始高能瓦斯 | 1000 |
| 起始人口(supplies made) | 200 |
| 特殊标志位 | `needs_pre_init_rpg` |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `unit` | 32 |
| `int` | 23 |
| `unitgroup` | 21 |
| `bool` | 12 |
| `actor` | 6 |
| `point[]` | 6 |
| `revealer` | 5 |
| `timer` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(104 个):

- `int gv_pLAYER01_USER`
- `int gv_pLAYER02_TOSH`
- `int gv_pLAYER03_DROPSHIPS`
- `int gv_pLAYER04_NOVA`
- `int gv_pLAYER05_ULTRA`
- `int gv_pLAYER06_THOR`
- `int gv_pLAYER8_REINFORCEMENTS`
- `int gv_platform`
- `unit gv_nova`
- `unitgroup gv_novaGroup`
- `actor gv_outhouse`
- `unitgroup gv_aggroGroup`
- `unitgroup gv_p1StartingTroopsA`
- `unitgroup gv_p1StartingTroopsB`
- `unit gv_p1DropshipA`
- `unit gv_p1DropshipB`
- `unit gv_p1SnipeTarget`
- `unitgroup gv_p1MiTuGuards`
- `revealer gv_p1MiTuRevealer`
- `bool gv_p1MiTuGuardsEngaged`
- `int gv_p1MiTuNovaHitCount`
- `unit gv_p1Nighthawk`
- `timer gv_p1NighthawkTimer`
- `unit gv_p1Tank`
- `revealer gv_p1TankRevealer`
- `revealer gv_p1Spec2Revealer`
- `unit gv_p1MineralDepot`
- `int gv_p1SnipeTransmissionSafety`
- `actor gv_p1GateDesignator`
- `actor gv_p1ObjectiveDesignator`
- `unit gv_p1Gate`
- `unit gv_p1GateControl`
- `unitgroup gv_p1Units`
- `unitgroup gv_hercGuards`
- `unitgroup gv_foundryGuards`
- `unitgroup gv_siloGuards1`
- `unitgroup gv_siloGuards2`
- `unitgroup gv_siloGuards3`
- `int gv_objectivesDestroyed`
- `bool gv_scanPerformed`
- `int gv_novaNukeCount`
- `int gv_platform1Spectres`
- `int gv_platform2Spectres`
- `int gv_platform3Spectres`
- `point[] gv_gauntlet1Points`
- `point[] gv_gauntlet2Points`
- `point[] gv_gauntlet3Points`
- `point[] gv_gauntlet4Points`
- `point[] gv_gauntletBrutalPoints`
- `point[] gv_gauntletFoundryPoints`
- `unit gv_dominatedUnit`
- `unitgroup gv_p2SearchCrew`
- `int gv_p2SearchCrewLine`
- `bool gv_p2SearchCrewSilenced`
- `unit gv_p2Raven`
- `unit gv_p2Nuker`
- `unit gv_p2NukerSilo`
- `bool gv_p2NukeDone`
- `unitgroup gv_p2LZGuards`
- `unit gv_p2DropPodder`
- `unit gv_p2TerrazineDepot`
- `unit gv_p2WestSpectre`
- `actor gv_p2GateDesignator`
- `actor gv_p2ObjectiveDesignator`
- `unit gv_p2Gate`
- `unit gv_p2GateControl`
- `unit gv_p2Silo`
- `unitgroup gv_p2Units`
- `bool gv_p2DropDone`
- `bool gv_p2NighthawkReplaced`
- `bool gv_p2ReapersReplaced`
- `revealer gv_p2EndRevealer`
- `bool gv_sENDMORE`
- `unit gv_p3Raven`
- `unit gv_p3BCruiser`
- `unit gv_p3NukerA`
- `unit gv_p3NukerASilo`
- `unit gv_p3NukerB`
- `unit gv_p3NukerBSilo`
- `unit gv_p3SouthViking`
- `unit gv_p3NorthViking`
- `unitgroup gv_p3SouthGuards`
- `unitgroup gv_p3NorthGuards`
- `unit gv_p3PsiIndoctrinator`
- `unit gv_p3SouthThor`
- `unit gv_p3SouthMarauder1`
- `unit gv_p3SouthMarauder2`
- `unitgroup gv_p3SouthPatrolGroup`
- `unitgroup gv_p3ObjectiveGuards`
- `int gv_p3ObjectiveGuardCount`
- `actor gv_p3ObjectiveDesignator`
- `unit gv_p3Silo`
- `unitgroup gv_p3Units`
- `revealer gv_p3EndRevealer`
- `int gv_spectreKillsByReapers`
- `int gv_bonusCreditsEarned`
- `int gv_nukeLaunchCount`
- `int gv_dominationCastCount`
- `int gv_dominationKills`
- `int gv_snipeKills`
- `bool gv_p1DoneCompleted`
- `unitgroup gv_p1DoneOldUnits`
- `bool gv_p2DoneCompleted`
- `unitgroup gv_p2DoneOldUnits`

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
- `gt_StartGameQ` — Start Game Q
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00AvernusStation` — Briefing Scene 00 - Avernus Station
- `gt_BriefingScene01JoriumStockpile` — Briefing Scene 01 - Jorium Stockpile
- `gt_BriefingScene02TerrazineTanks` — Briefing Scene 02 - Terrazine Tanks
- `gt_BriefingScene03PsiIndoctrinator` — Briefing Scene 03 - Psi Indoctrinator
- `gt_BriefingScene04Defenses` — Briefing Scene 04 - Defenses
- `gt_BriefingScene05NukePrep` — Briefing Scene 05 - Nuke Prep
- `gt_BriefingScene06NukeLaunch` — Briefing Scene 06 - Nuke Launch
- `gt_BriefingNukeActivity1` — Briefing Nuke Activity 1
- `gt_BriefingNukeActivity2` — Briefing Nuke Activity 2

### 胜负(6)

- `gt_VictoryPsiIndoctrinatorDestroyed` — Victory Psi-Indoctrinator Destroyed
- `gt_Victory`
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q

### 对白提示(2)

- `gt_TrapTransmission` — Trap Transmission'
- `gt_P1DoneQ` — P1Done Q

### 其他(53)

- `gt_ResetNova` — Reset Nova
- `gt_AggressiveEnemies` — Aggressive Enemies
- `gt_ExtremeAggro` — Extreme Aggro
- `gt_bon2`
- `gt_StartTimer` — Start Timer
- `gt_MindControlRemovefromUnitGroup` — Mind Control Remove from Unit Group
- `gt_ShockTechRescue` — Shock + Tech Rescue
- `gt_SabTechRescue` — Sab + Tech Rescue
- `gt_PredatorRescue` — Predator Rescue
- `gt_WardenRescue` — Warden Rescue
- `gt_DesecratorRescue` — Desecrator Rescue
- `gt_RadbatRescue` — Radbat Rescue
- `gt_TrooperRescue` — Trooper Rescue
- `gt_TankGhostRescue` — Tank + Ghost Rescue
- `gt_HercRescue` — Herc Rescue
- `gt_TankWardenRescue` — Tank + Warden Rescue
- `gt_NukeSilo1Rescue` — Nuke Silo 1 Rescue
- `gt_NukeSilo2Rescue` — Nuke Silo 2 Rescue
- `gt_NukeSilo3Rescue` — Nuke Silo 3 Rescue
- `gt_P1MineralDepotDestroyed` — P1 Mineral Depot Destroyed
- `gt_P2TerrazineRefineryDestroyed` — P2 Terrazine Refinery Destroyed
- `gt_KillWidowMines` — Kill Widow Mines
- `gt_KillOrbitalCommands` — Kill Orbital Commands
- `gt_OrbitalScans` — Orbital Scans
- `gt_OpenTopGate` — Open Top Gate
- `gt_OpenBottomGate` — Open Bottom  Gate
- `gt_StopLightning1` — Stop Lightning 1
- `gt_StopLightning2` — Stop Lightning 2
- `gt_StopLightning3` — Stop Lightning 3
- `gt_StopLightning4` — Stop Lightning 4
- `gt_LightningGauntlet1` — Lightning Gauntlet 1
- `gt_LightningGauntlet2` — Lightning Gauntlet 2
- `gt_LightningGauntletFoundry` — Lightning Gauntlet Foundry
- `gt_LightningGauntlet3` — Lightning Gauntlet 3
- `gt_LightningGauntlet4` — Lightning Gauntlet 4
- `gt_LightningGauntletBrutal` — Lightning Gauntlet Brutal
- `gt_StartAcidCycling` — Start Acid Cycling
- `gt_AcidCycling` — Acid Cycling
- `gt_AcidRoomDamage` — Acid Room Damage
- `gt_OpenZergLabDoors` — Open Zerg Lab Doors
- `gt_ZergLabTrapTriggered` — Zerg Lab Trap Triggered
- `gt_EndTrapPhase` — End Trap Phase
- `gt_NukeLaunched` — Nuke Launched
- `gt_NovaSnipeKills` — Nova Snipe Kills
- `gt_DominationCast` — Domination Cast
- `gt_DominatedKills` — Dominated Kills
- `gt_P1DoneSetup` — P1Done Setup
- `gt_P1DoneCinematic` — P1Done Cinematic
- `gt_P1DoneCinematicEnd` — P1Done Cinematic End
- `gt_P1DoneCleanup` — P1Done Cleanup
- `gt_P2DoneCinematic` — P2Done Cinematic
- `gt_P2DoneCinematicEnd` — P2Done Cinematic End
- `gt_P2DoneCleanup` — P2Done Cleanup

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 70 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_ResetNova` — Reset Nova
- `gt_IntroSequence` — Intro Sequence
- `gt_AggressiveEnemies` — Aggressive Enemies
- `gt_ExtremeAggro` — Extreme Aggro
- `gt_StartGameQ` — Start Game Q
- `gt_bon2`
- `gt_StartTimer` — Start Timer
- `gt_MindControlRemovefromUnitGroup` — Mind Control Remove from Unit Group
- `gt_ShockTechRescue` — Shock + Tech Rescue
- `gt_SabTechRescue` — Sab + Tech Rescue
- `gt_PredatorRescue` — Predator Rescue
- `gt_WardenRescue` — Warden Rescue
- `gt_DesecratorRescue` — Desecrator Rescue
- `gt_RadbatRescue` — Radbat Rescue
- `gt_TrooperRescue` — Trooper Rescue
- `gt_TankGhostRescue` — Tank + Ghost Rescue
- `gt_HercRescue` — Herc Rescue
- `gt_TankWardenRescue` — Tank + Warden Rescue
- `gt_NukeSilo1Rescue` — Nuke Silo 1 Rescue
- `gt_NukeSilo2Rescue` — Nuke Silo 2 Rescue
- `gt_NukeSilo3Rescue` — Nuke Silo 3 Rescue
- `gt_P1MineralDepotDestroyed` — P1 Mineral Depot Destroyed
- `gt_P2TerrazineRefineryDestroyed` — P2 Terrazine Refinery Destroyed
- `gt_VictoryPsiIndoctrinatorDestroyed` — Victory Psi-Indoctrinator Destroyed
- `gt_KillWidowMines` — Kill Widow Mines
- `gt_KillOrbitalCommands` — Kill Orbital Commands
- `gt_OrbitalScans` — Orbital Scans
- `gt_OpenTopGate` — Open Top Gate
- `gt_OpenBottomGate` — Open Bottom  Gate
- `gt_StopLightning1` — Stop Lightning 1
- `gt_StopLightning2` — Stop Lightning 2
- `gt_StopLightning3` — Stop Lightning 3
- `gt_StopLightning4` — Stop Lightning 4
- `gt_LightningGauntlet1` — Lightning Gauntlet 1
- `gt_LightningGauntlet2` — Lightning Gauntlet 2
- `gt_LightningGauntletFoundry` — Lightning Gauntlet Foundry
- `gt_LightningGauntlet3` — Lightning Gauntlet 3
- `gt_LightningGauntlet4` — Lightning Gauntlet 4
- `gt_LightningGauntletBrutal` — Lightning Gauntlet Brutal
- `gt_StartAcidCycling` — Start Acid Cycling
- `gt_AcidCycling` — Acid Cycling
- `gt_AcidRoomDamage` — Acid Room Damage
- `gt_OpenZergLabDoors` — Open Zerg Lab Doors
- `gt_ZergLabTrapTriggered` — Zerg Lab Trap Triggered
- `gt_TrapTransmission` — Trap Transmission'
- `gt_EndTrapPhase` — End Trap Phase
- `gt_NukeLaunched` — Nuke Launched
- `gt_NovaSnipeKills` — Nova Snipe Kills
- `gt_DominationCast` — Domination Cast
- `gt_DominatedKills` — Dominated Kills
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00AvernusStation` — Briefing Scene 00 - Avernus Station
- `gt_BriefingScene01JoriumStockpile` — Briefing Scene 01 - Jorium Stockpile
- `gt_BriefingScene02TerrazineTanks` — Briefing Scene 02 - Terrazine Tanks
- `gt_BriefingScene03PsiIndoctrinator` — Briefing Scene 03 - Psi Indoctrinator
- `gt_BriefingScene04Defenses` — Briefing Scene 04 - Defenses
- `gt_BriefingScene05NukePrep` — Briefing Scene 05 - Nuke Prep
- `gt_BriefingScene06NukeLaunch` — Briefing Scene 06 - Nuke Launch
- `gt_BriefingNukeActivity1` — Briefing Nuke Activity 1
- `gt_BriefingNukeActivity2` — Briefing Nuke Activity 2
- `gt_P1DoneQ` — P1Done Q
- `gt_P1DoneSetup` — P1Done Setup
- `gt_P1DoneCinematic` — P1Done Cinematic
- `gt_P1DoneCinematicEnd` — P1Done Cinematic End
- `gt_P1DoneCleanup` — P1Done Cleanup
- `gt_P2DoneCinematic` — P2Done Cinematic
- `gt_P2DoneCinematicEnd` — P2Done Cinematic End
- `gt_P2DoneCleanup` — P2Done Cleanup

