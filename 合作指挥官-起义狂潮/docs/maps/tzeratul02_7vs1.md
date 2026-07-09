# tzeratul02_7vs1(恶兆)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/tzeratul02_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 5870 |
| 触发器总数(gt_*_Func) | 115 |
| 全局变量数(gv_) | 97 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`LibA070801C`、`Lib67C0F0E7`、`LibE0EAE146` |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 28 |
| `unit` | 23 |
| `bool` | 18 |
| `actor` | 11 |
| `unitgroup` | 4 |
| `timer` | 4 |
| `fixed` | 3 |
| `soundlink` | 3 |
| `revealer` | 2 |
| `doodad` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(95 个):

- `int gv_p1_USER`
- `int gv_p2_PROTOSS_STALKER`
- `int gv_p3_PROTOSS_ENEMY`
- `int gv_p4_PROTOSS_ENEMY`
- `int gv_p5_ABANDONED_STRUCTURES`
- `int gv_p6_PROTOSS_ENEMY`
- `int gv_p7_NEUTRAL`
- `int gv_p8_PRISON_STRUCTURE`
- `int gv_p9_LIBRARIANS`
- `int gv_p10_HYBRID_MANIFESTATIONS`
- `int gv_p11_Phasesmiths`
- `int gv_p12_AbandonedTemplar`
- `int gv_p13_AbandonedRobotics`
- `int gv_p14_AbandonedStargates`
- `unit gv_superWarpGate_Neutral`
- `unit gv_preserverPrison01`
- `unit gv_preserverPrison02`
- `unit gv_preserverPrison03`
- `doodad gv_libraryHybrid`
- `unit gv_libraryAtBridge01`
- `unit gv_libraryAtBridge02`
- `unit gv_libraryAtBridge03`
- `unit gv_libraryAtBridge04`
- `unit gv_libraryAtBridge05`
- `unit gv_stalkerAtBridge`
- `unitgroup gv_prisonGroup`
- `unit gv_darkTemplar01`
- `unit gv_darkTemplar02`
- `unit gv_pylonPlayerCreatedDT`
- `unit gv_pylonPlayerCreatedRobotics`
- `unit gv_pylonPlayerCreatedHighTemplar`
- `unit gv_pylonInvisibleHighTemplar`
- `timer gv_achievementHardTimer`
- `timer gv_timerStalkerMoveOnHardBrutal`
- `int gv_energyBoard`
- `timer gv_attackTimer`
- `int gv_timerWindow`
- `fixed gv_hybridMaxLife`
- `fixed gv_hybridRespawnTime`
- `unit gv_hybridPhysical`
- `int gv_hybridWaves`
- `int gv_hybridDeathsForDialogue`
- `bool gv_hybridSoulAlive`
- `actor gv_actorHybridDeathEffect`
- `actor gv_actorHybridWarpBackEffect`
- `int gv_prisonsDead`
- `bool gv_hybridRecharging`
- `bool gv_hybridReturnsToPrisons`
- `bool gv_hybridPrisonsAllAlive`
- `fixed gv_hybridMovementSpeed`
- `bool gv_hybridBossPing`
- `int gv_pingHybridBoss`
- `bool gv_hybridBusy`
- `bool gv_secondaryObjStarted`
- `int gv_mineralsCollectedToActivateMidCin`
- `bool gv_stalkerWarningStarted`
- `int gv_mineralsCollectedToActivateStalker`
- `soundlink gv_soundLibrary`
- `bool gv_libraryDown01`
- `bool gv_libraryDown02`
- `bool gv_libraryDown03`
- `actor gv_actorAssimilator`
- `actor gv_actorGateway`
- `bool gv_stalkerDialogue`
- `actor gv_actorStalkerDialogue`
- `int gv_allyKills`
- `int gv_hybridKillsTracking`
- `int gv_hybridDeathsTracking`
- `int gv_hybridWavesTracking`
- `int gv_darkTemplarKills`
- `bool gv_introCinematicCompleted`
- `unitgroup gv_introHiddenUnitGroup`
- `unit gv_introVoidSeeker`
- `unit gv_archTemplar01`
- `unit gv_archTemplar02`
- `unit gv_archTemplar03`
- `unit gv_hybridNeutral`
- `actor gv_actorArchonEffect`
- `actor gv_actorHybridSpawn`
- `actor gv_actorVault01Spawn`
- `actor gv_actorVault02Spawn`
- `actor gv_actorVault03Spawn`
- `actor gv_actorVortexEffect`
- `timer gv_forceStartHybridCinTimer`
- `revealer gv_visbilityBridgeArea`
- `revealer gv_visbilityPrisonWholeArea`
- `soundlink gv_soundBridge`
- `soundlink gv_soundHybridWarpIn`
- `bool gv_midPrisonCinematicCompleted`
- `unitgroup gv_midPrisonInvisiblePylon`
- `bool gv_victoryCinematicCompleted`
- `bool gv_victoryCinematicShuttleUnload`
- `int gv_victoryCinematicPortrait`
- `unitgroup gv_victoryHiddenUnitGroup`
- `unit gv_zeratul`

## 触发器清单

### 初始化(16)

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
- `gt_BriefingAnimations` — Briefing Animations
- `gt_IntroQ` — Intro Q
- `gt_IntroSetup` — Intro Setup
- `gt_IntroCinematic` — Intro Cinematic
- `gt_IntroCinematicEnd` — Intro Cinematic End
- `gt_IntroCleanup` — Intro Cleanup

### 进攻波次(16)

- `gt_StartAttackWaves` — Start Attack Waves
- `gt_P3FleetAttackWaves` — P3 Fleet Attack Waves
- `gt_P9LibrariansAttackWaves` — P9 Librarians Attack Waves
- `gt_P11PhaseSmithsAttackWaves` — P11 Phase Smiths Attack Waves
- `gt_P2TopGuardiansAttackWaves` — P2 Top Guardians Attack Waves
- `gt_P4RightGuardiansAttackWaves` — P4 Right Guardians Attack Waves
- `gt_P6LeftGuardianAttackWaves` — P6 Left Guardian Attack Waves
- `gt_HybridAttacks` — Hybrid Attacks
- `gt_HybridAllWaves` — Hybrid All Waves
- `gt_HybridPrepforWave` — Hybrid Prep for Wave
- `gt_PlasmaBlastAttack` — Plasma Blast Attack
- `gt_PsionicShockwaveSecond` — Psionic Shockwave - Second
- `gt_Manifestation01ResumeWave` — Manifestation01 Resume Wave
- `gt_DarkTemplarAttackers` — Dark Templar Attackers
- `gt_ProtossGetAttackedFirstSetAlliance` — Protoss Get Attacked First Set Alliance
- `gt_HybridWaves` — Hybrid Waves

### 胜负(11)

- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_VictoryPrisonObjectiveComplete` — Victory Prison Objective Complete
- `gt_Victory`
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictoryCinematicSetup` — Victory Cinematic Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

### 对白提示(24)

- `gt_DialogueSomethingAmissQ` — Dialogue Something Amiss Q
- `gt_DialogueatArchivistQ` — Dialogue at Archivist Q
- `gt_DialogueSecondaryObjectiveQ` — Dialogue Secondary Objective Q
- `gt_DialoguePreserverBewareQ` — Dialogue Preserver Beware
- `gt_DialogueHaltatPlayerBase01Q` — Dialogue Halt at Player Base 01 Q
- `gt_DialogueHaltatPlayerBase02Q` — Dialogue Halt at Player Base 02 Q
- `gt_DialogueDarkShrineQ` — Dialogue Dark Shrine Q
- `gt_DialogueRoboticsFacilityQ` — Dialogue Robotics Facility Q
- `gt_DialogueTemplarArchivesQ` — Dialogue Templar Archives Q
- `gt_DialogueHybridReturnsLineQ` — Dialogue Hybrid Returns Line Q
- `gt_DialogueHybridPissed01Q` — Dialogue Hybrid Pissed 01 Q
- `gt_DialogueHybridPissed02Q` — Dialogue Hybrid Pissed 02 Q
- `gt_DialogueHybridPissed03Q` — Dialogue Hybrid Pissed 03 Q
- `gt_DialogueHybridPissed04Q` — Dialogue Hybrid Pissed 04 Q
- `gt_DialogueHybridPissed05Q` — Dialogue Hybrid Pissed 05 Q
- `gt_DialogueHybridPissed06Q` — Dialogue Hybrid Pissed 06 Q
- `gt_DialogueHybridPissed07Q` — Dialogue Hybrid Pissed 07 Q
- `gt_DialogueHybridPissedManifestationDead01Q` — Dialogue Hybrid Pissed Manifestation Dead 01 Q
- `gt_DialogueHybridPissedManifestationDead02Q` — Dialogue Hybrid Pissed Manifestation Dead 02 Q
- `gt_DialogueHybridPissedManifestationDead03Q` — Dialogue Hybrid Pissed Manifestation Dead 03 Q
- `gt_DialogueHybridPissedManifestationDead04Q` — Dialogue Hybrid Pissed Manifestation Dead 04 Q
- `gt_DialogueHybridPissedManifestationDead05Q` — Dialogue Hybrid Pissed Manifestation Dead 05 Q
- `gt_DialogueHybridPissedManifestationDead06Q` — Dialogue Hybrid Pissed Manifestation Dead 06 Q
- `gt_MidPrisonQ` — Mid Prison Q

### 其他(48)

- `gt_bon2`
- `gt_EnergyLeaderboard` — Energy Leaderboard
- `gt_EnergyTimer` — Energy Timer
- `gt_StartAI` — Start AI
- `gt_AbandonedTemplarTrickle` — Abandoned Templar Trickle
- `gt_AbandonedRoboticsTrickle` — Abandoned Robotics Trickle
- `gt_AbandonedStargateTrickle` — Abandoned Stargate Trickle
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_HybridPingandSound` — Hybrid Ping and Sound
- `gt_HybridBossPing` — Hybrid Boss Ping
- `gt_HybridDies` — Hybrid Dies
- `gt_PrisonDiesHybridReturn` — Prison Dies Hybrid Return
- `gt_PrisonDies` — Prison Dies
- `gt_Checkifallthreeprisonsdestroyed` — Check if all three prisons destroyed
- `gt_GravitonPrism` — Graviton Prism
- `gt_ShadowsoftheVoidEnable` — Shadows of the Void Enable
- `gt_ApocalypseEnable` — Apocalypse Enable
- `gt_SlaynGrabEnable` — Slayn Grab Enable
- `gt_Apocalypse`
- `gt_HybridLeaveshisarea` — Hybrid Leaves his area
- `gt_HybridEntershisarea` — Hybrid Enters his area
- `gt_SecondaryObjectiveRun` — Secondary Objective Run
- `gt_PlayerBuildingArmyActivatesMidCin` — Player Building Army Activates Mid Cin
- `gt_PlayerBuildingPhotonCannonsActivatesMidCin` — Player Building Photon Cannons Activates Mid Cin
- `gt_PlayerGatheringCashActivatesMidCin` — Player Gathering Cash Activates Mid Cin
- `gt_PlayerGatheringCashActivatesStalker` — Player Gathering Cash Activates Stalker
- `gt_PlayerBuildingUnitActivatesActivatesStalkerHardBrutal` — Player Building Unit Activates Activates Stalker Hard/Brutal
- `gt_StargatesPowered` — Stargates Powered
- `gt_RoboticsFacilityPowered` — Robotics Facility Powered
- `gt_GatewaysPowered` — Gateways Powered
- `gt_Library01`
- `gt_Library02`
- `gt_Library03`
- `gt_Library06`
- `gt_Library07`
- `gt_Library08`
- `gt_Library09`
- `gt_StalkerBecomesEnemyNearBase` — Stalker Becomes Enemy Near Base
- `gt_RunDialogueDeathLines` — Run Dialogue Death Lines
- `gt_AllyKills` — Ally Kills
- `gt_HybridKillsofplayerunits` — Hybrid Kills of player units
- `gt_DarkTemplarKillsofenemyunits` — Dark Templar Kills of enemy units
- `gt_HybridDiesfromplayer` — Hybrid Dies from player
- `gt_AchievementAllProtossDeadNormal` — Achievement - All Protoss Dead (Normal)
- `gt_MidPrisonSetup` — Mid Prison Setup
- `gt_MidPrisonCinematic` — Mid Prison Cinematic
- `gt_MidPrisonCinematicEnd` — Mid Prison Cinematic End
- `gt_MidPrisonCleanup` — Mid Prison Cleanup

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 105 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_StartGame` — Start Game
- `gt_bon2`
- `gt_EnergyLeaderboard` — Energy Leaderboard
- `gt_EnergyTimer` — Energy Timer
- `gt_StartAI` — Start AI
- `gt_StartAttackWaves` — Start Attack Waves
- `gt_P3FleetAttackWaves` — P3 Fleet Attack Waves
- `gt_P9LibrariansAttackWaves` — P9 Librarians Attack Waves
- `gt_P11PhaseSmithsAttackWaves` — P11 Phase Smiths Attack Waves
- `gt_P2TopGuardiansAttackWaves` — P2 Top Guardians Attack Waves
- `gt_P4RightGuardiansAttackWaves` — P4 Right Guardians Attack Waves
- `gt_P6LeftGuardianAttackWaves` — P6 Left Guardian Attack Waves
- `gt_AbandonedTemplarTrickle` — Abandoned Templar Trickle
- `gt_AbandonedRoboticsTrickle` — Abandoned Robotics Trickle
- `gt_AbandonedStargateTrickle` — Abandoned Stargate Trickle
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_HybridAttacks` — Hybrid Attacks
- `gt_HybridAllWaves` — Hybrid All Waves
- `gt_HybridPrepforWave` — Hybrid Prep for Wave
- `gt_HybridPingandSound` — Hybrid Ping and Sound
- `gt_HybridBossPing` — Hybrid Boss Ping
- `gt_HybridDies` — Hybrid Dies
- `gt_PrisonDiesHybridReturn` — Prison Dies Hybrid Return
- `gt_PrisonDies` — Prison Dies
- `gt_Checkifallthreeprisonsdestroyed` — Check if all three prisons destroyed
- `gt_GravitonPrism` — Graviton Prism
- `gt_ShadowsoftheVoidEnable` — Shadows of the Void Enable
- `gt_ApocalypseEnable` — Apocalypse Enable
- `gt_SlaynGrabEnable` — Slayn Grab Enable
- `gt_PlasmaBlastAttack` — Plasma Blast Attack
- `gt_Apocalypse`
- `gt_PsionicShockwaveSecond` — Psionic Shockwave - Second
- `gt_Manifestation01ResumeWave` — Manifestation01 Resume Wave
- `gt_HybridLeaveshisarea` — Hybrid Leaves his area
- `gt_HybridEntershisarea` — Hybrid Enters his area
- `gt_SecondaryObjectiveRun` — Secondary Objective Run
- `gt_PlayerBuildingArmyActivatesMidCin` — Player Building Army Activates Mid Cin
- `gt_PlayerBuildingPhotonCannonsActivatesMidCin` — Player Building Photon Cannons Activates Mid Cin
- `gt_PlayerGatheringCashActivatesMidCin` — Player Gathering Cash Activates Mid Cin
- `gt_PlayerGatheringCashActivatesStalker` — Player Gathering Cash Activates Stalker
- `gt_PlayerBuildingUnitActivatesActivatesStalkerHardBrutal` — Player Building Unit Activates Activates Stalker Hard/Brutal
- `gt_StargatesPowered` — Stargates Powered
- `gt_RoboticsFacilityPowered` — Robotics Facility Powered
- `gt_GatewaysPowered` — Gateways Powered
- `gt_Library01`
- `gt_Library02`
- `gt_Library03`
- `gt_Library06`
- `gt_Library07`
- `gt_Library08`
- `gt_Library09`
- `gt_DarkTemplarAttackers` — Dark Templar Attackers
- `gt_DialogueSomethingAmissQ` — Dialogue Something Amiss Q
- `gt_DialogueatArchivistQ` — Dialogue at Archivist Q
- `gt_DialogueSecondaryObjectiveQ` — Dialogue Secondary Objective Q
- `gt_DialoguePreserverBewareQ` — Dialogue Preserver Beware
- `gt_DialogueHaltatPlayerBase01Q` — Dialogue Halt at Player Base 01 Q
- `gt_DialogueHaltatPlayerBase02Q` — Dialogue Halt at Player Base 02 Q
- `gt_ProtossGetAttackedFirstSetAlliance` — Protoss Get Attacked First Set Alliance
- `gt_StalkerBecomesEnemyNearBase` — Stalker Becomes Enemy Near Base
- `gt_DialogueDarkShrineQ` — Dialogue Dark Shrine Q
- `gt_DialogueRoboticsFacilityQ` — Dialogue Robotics Facility Q
- `gt_DialogueTemplarArchivesQ` — Dialogue Templar Archives Q
- `gt_DialogueHybridReturnsLineQ` — Dialogue Hybrid Returns Line Q
- `gt_DialogueHybridPissed01Q` — Dialogue Hybrid Pissed 01 Q
- `gt_DialogueHybridPissed02Q` — Dialogue Hybrid Pissed 02 Q
- `gt_DialogueHybridPissed03Q` — Dialogue Hybrid Pissed 03 Q
- `gt_DialogueHybridPissed04Q` — Dialogue Hybrid Pissed 04 Q
- `gt_DialogueHybridPissed05Q` — Dialogue Hybrid Pissed 05 Q
- `gt_DialogueHybridPissed06Q` — Dialogue Hybrid Pissed 06 Q
- `gt_DialogueHybridPissed07Q` — Dialogue Hybrid Pissed 07 Q
- `gt_RunDialogueDeathLines` — Run Dialogue Death Lines
- `gt_DialogueHybridPissedManifestationDead01Q` — Dialogue Hybrid Pissed Manifestation Dead 01 Q
- `gt_DialogueHybridPissedManifestationDead02Q` — Dialogue Hybrid Pissed Manifestation Dead 02 Q
- `gt_DialogueHybridPissedManifestationDead03Q` — Dialogue Hybrid Pissed Manifestation Dead 03 Q
- `gt_DialogueHybridPissedManifestationDead04Q` — Dialogue Hybrid Pissed Manifestation Dead 04 Q
- `gt_DialogueHybridPissedManifestationDead05Q` — Dialogue Hybrid Pissed Manifestation Dead 05 Q
- `gt_DialogueHybridPissedManifestationDead06Q` — Dialogue Hybrid Pissed Manifestation Dead 06 Q
- `gt_AllyKills` — Ally Kills
- `gt_HybridKillsofplayerunits` — Hybrid Kills of player units
- `gt_DarkTemplarKillsofenemyunits` — Dark Templar Kills of enemy units
- `gt_HybridDiesfromplayer` — Hybrid Dies from player
- `gt_HybridWaves` — Hybrid Waves
- `gt_AchievementAllProtossDeadNormal` — Achievement - All Protoss Dead (Normal)
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_VictoryPrisonObjectiveComplete` — Victory Prison Objective Complete
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingAnimations` — Briefing Animations
- `gt_IntroQ` — Intro Q
- `gt_IntroSetup` — Intro Setup
- `gt_IntroCinematic` — Intro Cinematic
- `gt_IntroCinematicEnd` — Intro Cinematic End
- `gt_IntroCleanup` — Intro Cleanup
- `gt_MidPrisonQ` — Mid Prison Q
- `gt_MidPrisonSetup` — Mid Prison Setup
- `gt_MidPrisonCinematic` — Mid Prison Cinematic
- `gt_MidPrisonCinematicEnd` — Mid Prison Cinematic End
- `gt_MidPrisonCleanup` — Mid Prison Cleanup
- `gt_VictoryCinematicSetup` — Victory Cinematic Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

