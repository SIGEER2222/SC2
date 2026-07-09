# ttychus01_7vs1(来之不易)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/ttychus01_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 5045 |
| 触发器总数(gt_*_Func) | 92 |
| 全局变量数(gv_) | 44 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`TriggerLibs/SwarmLib`、`LibA070801C`、`Lib67C0F0E7`、`LibE0EAE146` |
| 起始晶体矿 | 150 |
| 起始高能瓦斯 | 50 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 16 |
| `unitgroup` | 10 |
| `bool` | 5 |
| `timer` | 5 |
| `fixed` | 2 |
| `playergroup` | 1 |
| `unit` | 1 |
| `revealer` | 1 |
| `unit[]` | 1 |
| `point[]` | 1 |
| `region[]` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(42 个):

- `int gv_p1_USER`
- `int gv_p2_ZERG`
- `int gv_p3_TEMPLE`
- `int gv_p4_LOWER_CAUSEWAY`
- `int gv_p5_UPPER_CAUSEWAY`
- `int gv_p6_FIRST_PROTOSS`
- `int gv_p7_PROTOSS_RELIC`
- `int gv_p8_ZERGRAVAGERS`
- `int gv_p9_TALDARIMFORWARDGUARD`
- `fixed gv_vIDEO_PADDING`
- `playergroup gv_protossPlayers`
- `unitgroup gv_savePoint1UnitGroup`
- `unitgroup gv_savePoint2UnitGroup`
- `unitgroup gv_outsideProtossBaseDefenders`
- `unitgroup gv_initialStalkers`
- `unit gv_artifact`
- `unitgroup gv_artifactGuardiansNorth`
- `unitgroup gv_artifactGuardiansSouth`
- `int gv_statuesKilled`
- `revealer gv_artifactRevealer`
- `unitgroup gv_zergArtifactAttackers`
- `bool gv_victoryPending`
- `timer gv_guardianTimer`
- `int gv_statuesDestoyed`
- `fixed gv_statueHealth`
- `int gv_spineCrawlerSize`
- `unit[] gv_spineCrawlers`
- `point[] gv_spineCrawlerPoints`
- `int gv_creepRegionsSize`
- `region[] gv_creepRegions`
- `timer gv_zergSpeedBumpTimer`
- `timer gv_zergSpeedBumpTimerShorter`
- `unitgroup gv_zergSpeedBumpUnits`
- `timer gv_kerriganTimer`
- `timer gv_achievementHardTimer`
- `int gv_statZergKilledByPlayer`
- `int gv_statProtossKilledByPlayer`
- `int gv_statStoneGuardianKillCount`
- `bool gv_zergStructuresKilled`
- `bool gv_victoryCinematicCompleted`
- `unitgroup gv_zerglingGroupNorth`
- `unitgroup gv_zerglingGroupSouth`

## 触发器清单

### 初始化(12)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03Units` — Init 03 Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_IntroBriefingQ` — Intro Briefing Q
- `gt_IntroBriefingCinematic` — Intro Briefing Cinematic
- `gt_BriefingZergAttacks` — Briefing Zerg Attacks

### 进攻波次(17)

- `gt_ArtifactGuardiansNorthAttacks` — Artifact Guardians North Attacks
- `gt_ArtifactGuardiansSouthAttacks` — Artifact Guardians South Attacks
- `gt_ZergArtifactAttacking` — Zerg Artifact Attacking
- `gt_ZergAttackInitiation` — Zerg Attack Initiation
- `gt_FirstAttackQ` — First Attack Q
- `gt_NexusDroppod` — Nexus Droppod
- `gt_PylonDroppod1` — Pylon Droppod 1
- `gt_PylonDroppod2` — Pylon Droppod 2
- `gt_PylonDroppod3` — Pylon Droppod 3
- `gt_GatewayDroppod` — Gateway Droppod
- `gt_KerriganAttacks` — Kerrigan Attacks
- `gt_PAttack4`
- `gt_RavagerAttackWaves` — Ravager Attack Waves
- `gt_P9AttackWaves` — P9 Attack Waves
- `gt_ZergAttackWavesProtoss` — Zerg Attack Waves - Protoss
- `gt_PAttack2`
- `gt_UpperProtossAttackWaves` — Upper Protoss Attack Waves

### 胜负(12)

- `gt_VictoryArtifactGained` — Victory - Artifact Gained
- `gt_Victory`
- `gt_DefeatBaseDead` — Defeat - Base Dead
- `gt_DefeatArtifactLost` — Defeat - Artifact Lost
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

### 对白提示(10)

- `gt_ArtifactRaceQ` — Artifact Race Q
- `gt_SavePoint1Q` — Save Point 1 Q
- `gt_SavePoint2Q` — Save Point 2 Q
- `gt_PylonTipQ` — Pylon Tip Q
- `gt_DefenseQ` — Defense Q
- `gt_MarauderQ` — Marauder Q
- `gt_ZergArtifactQ` — Zerg Artifact Q
- `gt_ShieldQ` — Shield Q
- `gt_CrazyQ` — Crazy Q
- `gt_ZergCloseRevealQ` — Zerg Close Reveal Q

### 其他(41)

- `gt_Bon1`
- `gt_Bon2a1`
- `gt_Bon2a2`
- `gt_Bon2a3`
- `gt_Bridge1Control` — Bridge 1 Control
- `gt_Bridge2Control` — Bridge 2 Control
- `gt_SecretBridgeControl` — Secret Bridge Control
- `gt_FirstGuard` — First Guard
- `gt_OuterForcefieldArea` — Outer Forcefield Area
- `gt_OutsideProtossBaseWarpIn` — Outside Protoss Base Warp In
- `gt_LowerForcefieldArea` — Lower Forcefield Area
- `gt_UpperHighTemplars` — Upper High Templars
- `gt_PylonTipProximityActivation` — Pylon Tip - Proximity Activation
- `gt_PylonTipDeathActivation` — Pylon Tip - Death Activation
- `gt_StalkerGather` — Stalker Gather
- `gt_MarauderQ2` — Marauder Q 2
- `gt_StatueInitialization` — Statue Initialization
- `gt_ArtifactVisibility` — Artifact Visibility
- `gt_ArtifactGuardianActivationNorth` — Artifact Guardian Activation North
- `gt_ArtifactGuardianActivationSouth` — Artifact Guardian Activation South
- `gt_ArtifactShieldActivation` — Artifact Shield Activation
- `gt_ArtifactGuardianDestroyed` — Artifact Guardian Destroyed
- `gt_CreepExpansion` — Creep Expansion
- `gt_SpineCrawlerSpawning` — Spine Crawler Spawning
- `gt_SpineCrawlerMovement` — Spine Crawler Movement
- `gt_AddZergSpeedBumpUnit` — Add Zerg Speed Bump Unit
- `gt_ZergSpeedBumpController` — Zerg Speed Bump Controller
- `gt_ZergSpeedBumpTimerExpires` — Zerg Speed Bump Timer Expires
- `gt_ZergSpeedBumpTimerNearsExpiration` — Zerg Speed Bump Timer Nears Expiration
- `gt_ProtossWarpDefense` — Protoss Warp Defense
- `gt_KerriganDies` — Kerrigan Dies
- `gt_StartAI` — Start AI
- `gt_p4stop`
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_OverseerBullies` — Overseer Bullies
- `gt_UpperLaneReveal` — Upper Lane Reveal
- `gt_UpperStatueReveal` — Upper Statue Reveal
- `gt_ProtossKilledbyPlayer` — Protoss Killed by Player
- `gt_ZergKilledbyPlayer` — Zerg Killed by Player
- `gt_ZergStructureKilledbyPlayer` — Zerg Structure Killed by Player
- `gt_StoneGuardianKills` — Stone Guardian Kills

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 82 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGame` — Start Game
- `gt_ArtifactRaceQ` — Artifact Race Q
- `gt_Bon1`
- `gt_Bon2a1`
- `gt_Bon2a2`
- `gt_Bon2a3`
- `gt_Bridge1Control` — Bridge 1 Control
- `gt_Bridge2Control` — Bridge 2 Control
- `gt_SecretBridgeControl` — Secret Bridge Control
- `gt_SavePoint1Q` — Save Point 1 Q
- `gt_SavePoint2Q` — Save Point 2 Q
- `gt_FirstGuard` — First Guard
- `gt_OuterForcefieldArea` — Outer Forcefield Area
- `gt_OutsideProtossBaseWarpIn` — Outside Protoss Base Warp In
- `gt_LowerForcefieldArea` — Lower Forcefield Area
- `gt_UpperHighTemplars` — Upper High Templars
- `gt_PylonTipQ` — Pylon Tip Q
- `gt_PylonTipProximityActivation` — Pylon Tip - Proximity Activation
- `gt_PylonTipDeathActivation` — Pylon Tip - Death Activation
- `gt_DefenseQ` — Defense Q
- `gt_StalkerGather` — Stalker Gather
- `gt_MarauderQ` — Marauder Q
- `gt_MarauderQ2` — Marauder Q 2
- `gt_StatueInitialization` — Statue Initialization
- `gt_ArtifactVisibility` — Artifact Visibility
- `gt_ArtifactGuardianActivationNorth` — Artifact Guardian Activation North
- `gt_ArtifactGuardianActivationSouth` — Artifact Guardian Activation South
- `gt_ArtifactShieldActivation` — Artifact Shield Activation
- `gt_ArtifactGuardiansNorthAttacks` — Artifact Guardians North Attacks
- `gt_ArtifactGuardiansSouthAttacks` — Artifact Guardians South Attacks
- `gt_ArtifactGuardianDestroyed` — Artifact Guardian Destroyed
- `gt_ZergArtifactAttacking` — Zerg Artifact Attacking
- `gt_ZergAttackInitiation` — Zerg Attack Initiation
- `gt_ZergArtifactQ` — Zerg Artifact Q
- `gt_ShieldQ` — Shield Q
- `gt_CreepExpansion` — Creep Expansion
- `gt_SpineCrawlerSpawning` — Spine Crawler Spawning
- `gt_SpineCrawlerMovement` — Spine Crawler Movement
- `gt_CrazyQ` — Crazy Q
- `gt_FirstAttackQ` — First Attack Q
- `gt_ZergCloseRevealQ` — Zerg Close Reveal Q
- `gt_AddZergSpeedBumpUnit` — Add Zerg Speed Bump Unit
- `gt_ZergSpeedBumpController` — Zerg Speed Bump Controller
- `gt_ZergSpeedBumpTimerExpires` — Zerg Speed Bump Timer Expires
- `gt_ZergSpeedBumpTimerNearsExpiration` — Zerg Speed Bump Timer Nears Expiration
- `gt_NexusDroppod` — Nexus Droppod
- `gt_PylonDroppod1` — Pylon Droppod 1
- `gt_PylonDroppod2` — Pylon Droppod 2
- `gt_PylonDroppod3` — Pylon Droppod 3
- `gt_GatewayDroppod` — Gateway Droppod
- `gt_ProtossWarpDefense` — Protoss Warp Defense
- `gt_KerriganAttacks` — Kerrigan Attacks
- `gt_KerriganDies` — Kerrigan Dies
- `gt_StartAI` — Start AI
- `gt_PAttack4`
- `gt_p4stop`
- `gt_RavagerAttackWaves` — Ravager Attack Waves
- `gt_P9AttackWaves` — P9 Attack Waves
- `gt_ZergAttackWavesProtoss` — Zerg Attack Waves - Protoss
- `gt_PAttack2`
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_UpperProtossAttackWaves` — Upper Protoss Attack Waves
- `gt_OverseerBullies` — Overseer Bullies
- `gt_UpperLaneReveal` — Upper Lane Reveal
- `gt_UpperStatueReveal` — Upper Statue Reveal
- `gt_ProtossKilledbyPlayer` — Protoss Killed by Player
- `gt_ZergKilledbyPlayer` — Zerg Killed by Player
- `gt_ZergStructureKilledbyPlayer` — Zerg Structure Killed by Player
- `gt_StoneGuardianKills` — Stone Guardian Kills
- `gt_VictoryArtifactGained` — Victory - Artifact Gained
- `gt_DefeatBaseDead` — Defeat - Base Dead
- `gt_DefeatArtifactLost` — Defeat - Artifact Lost
- `gt_IntroBriefingQ` — Intro Briefing Q
- `gt_IntroBriefingCinematic` — Intro Briefing Cinematic
- `gt_BriefingZergAttacks` — Briefing Zerg Attacks
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup

