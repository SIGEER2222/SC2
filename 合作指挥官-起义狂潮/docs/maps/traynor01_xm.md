# traynor01_xm(自由日(xm 变体))

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/traynor01_xm.SC2Map` |
| 类型 | xm变体 |
| MapScript.galaxy 行数 | 6219 |
| 触发器总数(gt_*_Func) | 121 |
| 全局变量数(gv_) | 82 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`Lib67C0F0E7`、`LibC0F50AA6`、`LibDF8E6945`、`Lib975E2FE9`、`LibE0EAE146` |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `unit` | 27 |
| `int` | 20 |
| `unitgroup` | 13 |
| `bool` | 9 |
| `actor` | 6 |
| `revealer` | 3 |
| `actor[]` | 1 |
| `int[]` | 1 |
| `unit[]` | 1 |
| `sound` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(80 个):

- `int gv_p1_USER`
- `int gv_p2_DOMINION_RED`
- `int gv_p3_RIKSVILLE_YELLOW`
- `int gv_p4_ACTORS_BLUE`
- `int gv_p5_RIKSVILLE_PUSHY`
- `int gv_p6_UNMANNEDVEHICLES`
- `int gv_p7_MISSINGSOLDIERS`
- `unit gv_raynor`
- `bool gv_tutorialWindowclosed`
- `unitgroup gv_aggroGroup`
- `unit gv_dogmeat`
- `unit gv_crazyOldClarice`
- `int gv_roadblockTransmission`
- `actor gv_roadblockActor01`
- `actor gv_roadblockActor02`
- `actor gv_roadblockActor03`
- `unit gv_mutteringJohn`
- `unit gv_southieTarget`
- `unit gv_viking01`
- `unit gv_viking02`
- `unit gv_viking03`
- `unitgroup gv_dropGroup`
- `unitgroup gv_riksvilleTownSquareDominion`
- `revealer gv_riksvilleTownSquareReavler`
- `int gv_southieTransmission`
- `unit gv_southieSpeaker`
- `bool gv_onTheMove`
- `unitgroup gv_escapeJerks`
- `unitgroup gv_escapeCivilians`
- `bool gv_escapeCivillansFinalOrderIssued`
- `revealer gv_escapeRevealer`
- `actor gv_civMarchActor02`
- `actor gv_civMarchActor03`
- `unit gv_civMarchSpeaker01`
- `unit gv_civMarchSpeaker02`
- `unit gv_civMarchSpeaker03`
- `bool gv_compoundClear`
- `unitgroup gv_dominionCompoundCivilian`
- `unitgroup gv_dominionCompoundGuards`
- `revealer gv_dominionCompoundRevealer`
- `actor[] gv_holoReticules`
- `int[] gv_holoPing`
- `unit[] gv_holoboards`
- `int gv_holoboardTransmission01`
- `int gv_holoboardTransmission02`
- `int gv_holoboardTransmission03`
- `int gv_holoboardTransmission04`
- `int gv_holoboardTransmission05`
- `int gv_holoboardTransmission06`
- `int gv_riksvillePopulation`
- `int gv_holoboardsDestroyed`
- `int gv_dominionMarinesKilled`
- `int gv_dominionMarinesTotal`
- `actor gv_introActorBase01`
- `unit gv_introVik01`
- `unit gv_introVik02`
- `unit gv_introVik03`
- `unit gv_introMar01`
- `unit gv_introMar02`
- `unit gv_introMar03`
- `unit gv_introMar04`
- `unit gv_introDrop01`
- `unit gv_introDrop02`
- `unit gv_introCiv01`
- `unit gv_introCiv02`
- `unit gv_introCiv03`
- `unit gv_introCiv04`
- `unit gv_introCiv05`
- `unitgroup gv_raynorsMarines`
- `unit gv_introDropship`
- `unitgroup gv_introUnitCargoStart`
- `int gv_introUnitCargoStartDrop`
- `unitgroup gv_introActorGroup`
- `bool gv_introCinematicCompleted`
- `unitgroup gv_introCinHiddenUnitGroup`
- `bool gv_midCinematicCompleted`
- `unitgroup gv_midHiddenUnitGroup`
- `sound gv_crowdSoundEmitter`
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
- `gt_StartGame` — Start Game
- `gt_InitialGroup` — Initial Group
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene00Viking` — Briefing Scene 00 Viking
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_IntroQ` — Intro Q
- `gt_IntroSetup` — Intro Setup
- `gt_IntroCinematic` — Intro Cinematic
- `gt_IntroCinematicEnd` — Intro Cinematic End
- `gt_IntroCleanupNoEscape` — Intro Cleanup - No Escape
- `gt_IntroCleanupEscape` — Intro Cleanup -  Escape
- `gt_IntroCargoUnload` — Intro Cargo Unload

### 进攻波次(3)

- `gt_RoadblockAttacked` — Roadblock Attacked
- `gt_RiksvilleTownSquareDropPods` — Riksville Town Square Drop Pods
- `gt_SouthieMarineattackQ` — Southie Marine attack Q

### 胜负(12)

- `gt_VictoryTowerDestroyed` — Victory Tower Destroyed
- `gt_Victory`
- `gt_DefeatRaynorDead` — Defeat Raynor Dead
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictoryRandomCheer` — Victory Random Cheer

### 对白提示(24)

- `gt_TutorialReviewQ` — Tutorial Review Q
- `gt_OpeningLineQ` — Opening Line Q
- `gt_CrazyOldLadyLineQ` — Crazy Old Lady Line Q
- `gt_RoadblockAggroQ` — Roadblock Aggro Q
- `gt_RoadblockTransmissionKill` — Roadblock Transmission Kill
- `gt_RaynorsaysKillHoloboardsQ` — Raynor says Kill Holoboards Q
- `gt_WhereisEveryoneQ` — Where is Everyone?  Q
- `gt_MutteringJohnQ` — Muttering John Q
- `gt_ThisisuglyQ` — This is ugly Q
- `gt_RiksvilleTownSquareViewQ` — Riksville Town Square View Q
- `gt_RiksvilleTownSquareClearDialogueQ` — Riksville Town Square Clear Dialogue Q
- `gt_SouthieTransmissionKill` — Southie Transmission Kill
- `gt_ThisisbadQ` — This is bad Q
- `gt_EscapeClearQ` — Escape Clear Q
- `gt_CivilianMarchQ` — Civilian March Q
- `gt_DominionCompoundViewQ` — Dominion Compound View Q
- `gt_PlayHoloboard01Q` — Play Holoboard01 Q
- `gt_PlayHoloboard02Q` — Play Holoboard02 Q
- `gt_PlayHoloboard03Q` — Play Holoboard03 Q
- `gt_PlayHoloboard04Q` — Play Holoboard04 Q
- `gt_PlayHoloboard05Q` — Play Holoboard05 Q
- `gt_PlayHoloboard06Q` — Play Holoboard06 Q
- `gt_MidBillboardQ` — Mid Billboard Q
- `gt_MidEscapeQ` — Mid Escape Q

### 其他(61)

- `gt_Rescue1Dialogue` — Rescue 1 Dialogue
- `gt_Rescue2Dialogue` — Rescue 2 Dialogue
- `gt_Rescue3Dialogue` — Rescue 3 Dialogue
- `gt_DominionHoloboards`
- `gt_PickUpPickUp`
- `gt_AggressiveEnemies` — Aggressive Enemies
- `gt_ExtremeAggro` — Extreme Aggro
- `gt_RunDogmeatRUN` — Run Dogmeat RUN!
- `gt_Dogmeatgo` — Dogmeat go!
- `gt_GohomeDogmeat` — Go home Dogmeat!
- `gt_CrazyOldLadyMove` — Crazy Old Lady Move
- `gt_CrazyOldLadyDespawn` — Crazy Old Lady Despawn
- `gt_RoadblockView` — Roadblock View
- `gt_RoadblockCarcass` — Roadblock Carcass
- `gt_FirstHoloboardencounter` — First Holoboard encounter
- `gt_MutteringJohnDespawn` — Muttering John Despawn
- `gt_GhostTownEntranceCarcass` — Ghost Town Entrance Carcass
- `gt_GhostTownExitCarcass1` — Ghost Town Exit Carcass 1
- `gt_GhostTownExitCarcass2` — Ghost Town Exit Carcass 2
- `gt_GhostTownExitCarcass3` — Ghost Town Exit Carcass 3
- `gt_GhostTownExitCarcass4` — Ghost Town Exit Carcass 4
- `gt_RiksvilleAutoSave01` — Riksville Auto Save01
- `gt_RiksvilleTownSquareClear` — Riksville Town Square Clear
- `gt_RiksvilleTownSquareVikingRemove` — Riksville Town Square Viking Remove
- `gt_RiksvilleTownRevealCheck` — Riksville Town Reveal Check
- `gt_SouthieMarineaggroStatue` — Southie Marine aggro- Statue
- `gt_SouthieMarineaggroProximity` — Southie Marine aggro- Proximity
- `gt_Firebats`
- `gt_EscapeView` — Escape View
- `gt_EscapeDamage` — Escape Damage
- `gt_EscapeRevealCheck`
- `gt_EscapeRandomCheer` — Escape Random Cheer
- `gt_CivilianSpawnCrowd` — Civilian Spawn Crowd
- `gt_Flyawaybirdie` — Fly away birdie!
- `gt_FlyawaybirdieptIItheBirdening` — Fly away birdie! pt. II - the Birdening
- `gt_DominionCompoundVikingland` — Dominion Compound Viking land
- `gt_DominionCompoundClear` — Dominion Compound Clear
- `gt_DominionCompoundMove` — Dominion Compound Move
- `gt_DominionCompoundCheer` — Dominion Compound Cheer
- `gt_DominionCompoundWarningLights` — Dominion Compound Warning Lights
- `gt_DominionCivilianCompound` — Dominion Civilian Compound
- `gt_DominionCompoundReticleKiller` — Dominion Compound Reticle Killer
- `gt_CreateReticule2` — Create Reticule 2
- `gt_CreateReticule3` — Create Reticule 3
- `gt_CreateReticule4` — Create Reticule 4
- `gt_CreateReticule5` — Create Reticule 5
- `gt_CreateReticule6` — Create Reticule 6
- `gt_HoloReticuleKiller` — Holo-Reticule Killer
- `gt_HoloPingKiller` — Holo-Ping Killer
- `gt_HoloboardStopSounds` — Holoboard Stop Sounds
- `gt_StatHoloboardsDestroyed` — Stat - Holoboards Destroyed
- `gt_StatDominionMarinesKilled` — Stat - Dominion Marines Killed
- `gt_Achievement5RaynorKillsNormal` — Achievement - 5 Raynor Kills (Normal)
- `gt_MidBillboardSetup` — Mid Billboard Setup
- `gt_MidBillboardCinematic` — Mid Billboard Cinematic
- `gt_MidBillboardCinematicEnd` — Mid Billboard Cinematic End
- `gt_MidBillboardCleanup` — Mid Billboard Cleanup
- `gt_MidEscapeSetup` — Mid Escape Setup
- `gt_MidEscapeCinematic` — Mid Escape Cinematic
- `gt_MidEscapeCinematicEnd` — Mid Escape Cinematic End
- `gt_MidEscapeCleanup` — Mid Escape Cleanup

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 111 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_Rescue1Dialogue` — Rescue 1 Dialogue
- `gt_Rescue2Dialogue` — Rescue 2 Dialogue
- `gt_Rescue3Dialogue` — Rescue 3 Dialogue
- `gt_DominionHoloboards`
- `gt_PickUpPickUp`
- `gt_StartGame` — Start Game
- `gt_TutorialReviewQ` — Tutorial Review Q
- `gt_OpeningLineQ` — Opening Line Q
- `gt_AggressiveEnemies` — Aggressive Enemies
- `gt_ExtremeAggro` — Extreme Aggro
- `gt_RunDogmeatRUN` — Run Dogmeat RUN!
- `gt_Dogmeatgo` — Dogmeat go!
- `gt_GohomeDogmeat` — Go home Dogmeat!
- `gt_CrazyOldLadyLineQ` — Crazy Old Lady Line Q
- `gt_CrazyOldLadyMove` — Crazy Old Lady Move
- `gt_CrazyOldLadyDespawn` — Crazy Old Lady Despawn
- `gt_InitialGroup` — Initial Group
- `gt_RoadblockView` — Roadblock View
- `gt_RoadblockAggroQ` — Roadblock Aggro Q
- `gt_RoadblockTransmissionKill` — Roadblock Transmission Kill
- `gt_RoadblockAttacked` — Roadblock Attacked
- `gt_RoadblockCarcass` — Roadblock Carcass
- `gt_FirstHoloboardencounter` — First Holoboard encounter
- `gt_RaynorsaysKillHoloboardsQ` — Raynor says Kill Holoboards Q
- `gt_WhereisEveryoneQ` — Where is Everyone?  Q
- `gt_MutteringJohnQ` — Muttering John Q
- `gt_MutteringJohnDespawn` — Muttering John Despawn
- `gt_ThisisuglyQ` — This is ugly Q
- `gt_GhostTownEntranceCarcass` — Ghost Town Entrance Carcass
- `gt_GhostTownExitCarcass1` — Ghost Town Exit Carcass 1
- `gt_GhostTownExitCarcass2` — Ghost Town Exit Carcass 2
- `gt_GhostTownExitCarcass3` — Ghost Town Exit Carcass 3
- `gt_GhostTownExitCarcass4` — Ghost Town Exit Carcass 4
- `gt_RiksvilleAutoSave01` — Riksville Auto Save01
- `gt_RiksvilleTownSquareViewQ` — Riksville Town Square View Q
- `gt_RiksvilleTownSquareDropPods` — Riksville Town Square Drop Pods
- `gt_RiksvilleTownSquareClear` — Riksville Town Square Clear
- `gt_RiksvilleTownSquareClearDialogueQ` — Riksville Town Square Clear Dialogue Q
- `gt_RiksvilleTownSquareVikingRemove` — Riksville Town Square Viking Remove
- `gt_RiksvilleTownRevealCheck` — Riksville Town Reveal Check
- `gt_SouthieMarineaggroStatue` — Southie Marine aggro- Statue
- `gt_SouthieMarineaggroProximity` — Southie Marine aggro- Proximity
- `gt_SouthieMarineattackQ` — Southie Marine attack Q
- `gt_SouthieTransmissionKill` — Southie Transmission Kill
- `gt_ThisisbadQ` — This is bad Q
- `gt_Firebats`
- `gt_EscapeView` — Escape View
- `gt_EscapeDamage` — Escape Damage
- `gt_EscapeClearQ` — Escape Clear Q
- `gt_EscapeRevealCheck`
- `gt_EscapeRandomCheer` — Escape Random Cheer
- `gt_CivilianSpawnCrowd` — Civilian Spawn Crowd
- `gt_CivilianMarchQ` — Civilian March Q
- `gt_Flyawaybirdie` — Fly away birdie!
- `gt_FlyawaybirdieptIItheBirdening` — Fly away birdie! pt. II - the Birdening
- `gt_DominionCompoundViewQ` — Dominion Compound View Q
- `gt_DominionCompoundVikingland` — Dominion Compound Viking land
- `gt_DominionCompoundClear` — Dominion Compound Clear
- `gt_DominionCompoundMove` — Dominion Compound Move
- `gt_DominionCompoundCheer` — Dominion Compound Cheer
- `gt_DominionCompoundWarningLights` — Dominion Compound Warning Lights
- `gt_DominionCivilianCompound` — Dominion Civilian Compound
- `gt_DominionCompoundReticleKiller` — Dominion Compound Reticle Killer
- `gt_CreateReticule2` — Create Reticule 2
- `gt_CreateReticule3` — Create Reticule 3
- `gt_CreateReticule4` — Create Reticule 4
- `gt_CreateReticule5` — Create Reticule 5
- `gt_CreateReticule6` — Create Reticule 6
- `gt_HoloReticuleKiller` — Holo-Reticule Killer
- `gt_HoloPingKiller` — Holo-Ping Killer
- `gt_PlayHoloboard01Q` — Play Holoboard01 Q
- `gt_PlayHoloboard02Q` — Play Holoboard02 Q
- `gt_PlayHoloboard03Q` — Play Holoboard03 Q
- `gt_PlayHoloboard04Q` — Play Holoboard04 Q
- `gt_PlayHoloboard05Q` — Play Holoboard05 Q
- `gt_PlayHoloboard06Q` — Play Holoboard06 Q
- `gt_HoloboardStopSounds` — Holoboard Stop Sounds
- `gt_StatHoloboardsDestroyed` — Stat - Holoboards Destroyed
- `gt_StatDominionMarinesKilled` — Stat - Dominion Marines Killed
- `gt_Achievement5RaynorKillsNormal` — Achievement - 5 Raynor Kills (Normal)
- `gt_VictoryTowerDestroyed` — Victory Tower Destroyed
- `gt_DefeatRaynorDead` — Defeat Raynor Dead
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene00Viking` — Briefing Scene 00 Viking
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_IntroQ` — Intro Q
- `gt_IntroSetup` — Intro Setup
- `gt_IntroCinematic` — Intro Cinematic
- `gt_IntroCinematicEnd` — Intro Cinematic End
- `gt_IntroCleanupNoEscape` — Intro Cleanup - No Escape
- `gt_IntroCleanupEscape` — Intro Cleanup -  Escape
- `gt_IntroCargoUnload` — Intro Cargo Unload
- `gt_MidBillboardQ` — Mid Billboard Q
- `gt_MidBillboardSetup` — Mid Billboard Setup
- `gt_MidBillboardCinematic` — Mid Billboard Cinematic
- `gt_MidBillboardCinematicEnd` — Mid Billboard Cinematic End
- `gt_MidBillboardCleanup` — Mid Billboard Cleanup
- `gt_MidEscapeQ` — Mid Escape Q
- `gt_MidEscapeSetup` — Mid Escape Setup
- `gt_MidEscapeCinematic` — Mid Escape Cinematic
- `gt_MidEscapeCinematicEnd` — Mid Escape Cinematic End
- `gt_MidEscapeCleanup` — Mid Escape Cleanup
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictoryRandomCheer` — Victory Random Cheer

