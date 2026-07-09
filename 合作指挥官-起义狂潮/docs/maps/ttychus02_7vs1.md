# ttychus02_7vs1(挖宝行动)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/ttychus02_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 6131 |
| 触发器总数(gt_*_Func) | 118 |
| 全局变量数(gv_) | 79 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`TriggerLibs/SwarmLib`、`LibA070801C`、`Lib67C0F0E7`、`LibC0F50AA6`、`LibDF8E6945`、`Lib0940FFB7`、`LibE0EAE146` |
| 起始晶体矿 | 300 |
| 起始高能瓦斯 | 100 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 34 |
| `unit` | 10 |
| `bool` | 9 |
| `unitgroup` | 6 |
| `point[]` | 4 |
| `int[]` | 3 |
| `actor` | 2 |
| `fixed` | 2 |
| `timer` | 2 |
| `playergroup` | 1 |
| `trigger[]` | 1 |
| `region` | 1 |
| `unitgroup[]` | 1 |
| `string[]` | 1 |
| `point` | 1 |
| `actor[]` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(77 个):

- `int gv_p1_USER`
- `int gv_p2_NE_PROTOSSMiddle`
- `int gv_p3_WARPEDINPROTOSS`
- `int gv_p4_SE_PROTOSSRight`
- `int gv_p5_NW_PROTOSSLeft`
- `int gv_p6_PROTOSSAir`
- `int gv_p7_ABANDONED_BASE`
- `int gv_p8_ANCIENT_TEMPLE`
- `int gv_p9_MOEBIUSEXPEDITION`
- `int gv_p10_SCIONS`
- `int gv_p11_DEATHFLEET`
- `int gv_p12_FORWARDGUARD`
- `int gv_p13_PHASESMITHS`
- `int gv_p14_DRILL`
- `unit gv_tHEONEDRILL`
- `unit gv_tHEONEDOOR`
- `unit gv_superWarpGateP6`
- `unitgroup gv_sCVs`
- `playergroup gv_protossPlayerGroup`
- `actor gv_siegeTankPingActor`
- `int gv_unstableTransmission`
- `bool gv_interruptTransmission`
- `int gv_laserDrillPing`
- `unit gv_dismantler`
- `fixed gv_selftDestructTime`
- `timer gv_selfDestructTimer`
- `int gv_selfDestructTimerWindow`
- `bool gv_playerControlsLaserDrill`
- `int gv_inCombatIndicator`
- `int gv_templeDoorBossBar`
- `trigger[] gv_lDAttackedByEnemyTriggers`
- `bool gv_lDAdviceToRepairTheDrill`
- `int gv_lDAttackedIndex`
- `int gv_statLaserDrillKills`
- `int gv_anniversaryStatLaserKillsTracking`
- `region gv_soundRegion`
- `actor gv_soundRegionActor`
- `bool gv_soundRegionCreated`
- `timer gv_laserSoundDelayTimer`
- `unit gv_laserDrillTargetUnit`
- `unit gv_lastWarpedInPhasePrism`
- `fixed gv_phasePrismSpawnRate`
- `int gv_phasePrismAggroLevel`
- `int[] gv_phasePrismCurrentlyTrained`
- `int[] gv_phasePrismWaveSize`
- `unitgroup[] gv_phasePrismUnitGroups`
- `point[] gv_phasePrismAttackPoints`
- `point[] gv_phasePrismSpawnPoints`
- `bool gv_airWarningIssued`
- `int gv_allyKills`
- `int gv_dAWAttacker`
- `int gv_dAWArrivalTime`
- `int gv_dAWLingerTime`
- `int[] gv_dAWUnitQuantities`
- `string[] gv_dAWUnitTypes`
- `int gv_dAWUnitCount`
- `point gv_dAWWaypoint`
- `unitgroup gv_suicidalBullies`
- `int gv_shrinePing1`
- `int gv_shrinePing2`
- `int gv_shrinePing3`
- `unitgroup gv_carrionBirds`
- `unit gv_carrionBirdParameter`
- `int gv_statProtossRemaining`
- `int gv_statSiegeTankKills`
- `int gv_statProtossStructureKills`
- `actor[] gv_midCinematicPings`
- `unitgroup gv_midCinematicProtoss`
- `unitgroup gv_midHiddenUnitGroup`
- `bool gv_midCinematicCompleted`
- `point[] gv_victoryMarineFormationLeft`
- `point[] gv_victoryMarineFormationRight`
- `unit gv_victoryTruck`
- `unitgroup gv_victoryHiddenUnitGroup`
- `bool gv_victoryCinematicCompleted`
- `unit gv_victoryMarine1`
- `unit gv_victoryMarine2`

## 触发器清单

### 初始化(16)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03Units` — Init 03 Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulty` — Init 06 Difficulty
- `gt_SiegeTankIntroQ` — Siege Tank Intro Q
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGameTacticalPhase` — Start Game - Tactical Phase
- `gt_InitDarkArchonDies` — Init Dark Archon Dies
- `gt_StartGameDefensePhase` — Start Game - Defense Phase
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02

### 进攻波次(25)

- `gt_Laserdrillunderattack01Q` — Laser drill under attack 01 Q
- `gt_Laserdrillunderattack02Q` — Laser drill under attack 02 Q
- `gt_Laserdrillunderattack03Q` — Laser drill under attack 03 Q
- `gt_Laserdrillunderattack04Q` — Laser drill under attack 04 Q
- `gt_Laserisattackedbyenemy` — Laser is attacked by enemy
- `gt_LaserisattackedbyplayerQ` — Laser is attacked by player Q
- `gt_PrismAttackPhase1Training` — Prism Attack Phase 1 - Training
- `gt_PrismAttackPhase1aWarpedIn` — Prism Attack Phase 1a - Warped In
- `gt_PrismAttackPhase2NW` — Prism Attack Phase 2 - NW
- `gt_PrismAttackPhase2NE` — Prism Attack Phase 2 - NE
- `gt_PrismAttackPhase2SE` — Prism Attack Phase 2 - SE
- `gt_PrismAttackPhase2aWarnPlayer` — Prism Attack Phase 2a - Warn Player
- `gt_PrismAttackPhase3Arrival` — Prism Attack Phase 3 - Arrival
- `gt_IncomingPrismAttack01Q` — Incoming Prism Attack 01 Q
- `gt_IncomingPrismAttack02Q` — Incoming Prism Attack 02 Q
- `gt_IncomingPrismAttack03Q` — Incoming Prism Attack 03 Q
- `gt_P9MoebiusAttackWaves` — P9 Moebius Attack Waves
- `gt_P9MoebiusAlliedAttackWaves` — P9 Moebius Allied Attack Waves
- `gt_P10ScionsAttackWaves` — P10 Scions Attack Waves
- `gt_P11DeathFleetAttackWaves` — P11 Death Fleet Attack Waves
- `gt_P12ForwardGuardAttackWaves` — P12 Forward Guard Attack Waves
- `gt_P13SmithAttackWaves` — P13 Smith Attack Waves
- `gt_SendDelayedAttackWaveThread` — Send Delayed Attack Wave Thread
- `gt_AIAttackWaves` — AI Attack Waves
- `gt_AIColossusWave` — AI Colossus Wave

### 胜负(18)

- `gt_TacticalVictory` — Tactical Victory
- `gt_VictoryDestroyDoor` — Victory Destroy Door
- `gt_VictoryDestroyProtoss` — Victory Destroy Protoss
- `gt_VictoryDestroyProtossDialogueQ` — Victory Destroy Protoss Dialogue Q
- `gt_Victory`
- `gt_DefeatTacticalTroopsDestroyed` — Defeat Tactical Troops Destroyed
- `gt_DefeatLaserDrillDestroyed` — Defeat Laser Drill Destroyed
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_Defeat`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictoryInitialMarineMove` — Victory Initial Marine Move
- `gt_VictoryDropship` — Victory Dropship

### 对白提示(11)

- `gt_SiegeTankTipQ` — Siege Tank Tip Q
- `gt_ZealotAggroQ` — Zealot Aggro Q
- `gt_RaynorQ` — Raynor Q
- `gt_RevealRelicShrinesQ` — Reveal Relic Shrines Q
- `gt_CampaignTipsQ` — Campaign Tips Q
- `gt_DrillisrepairabletipQ` — Drill is repairable tip Q
- `gt_LaserkillsaplayerunitQ` — Laser kills a player unit Q
- `gt_TempleHPLow1Q` — Temple HP Low 1 Q
- `gt_TempleHPLow2Q` — Temple HP Low 2 Q
- `gt_TempleHPLow4Q` — Temple HP Low 4 Q
- `gt_MidQ` — Mid Q

### 其他(48)

- `gt_SiegeTanksComeIn` — Siege Tanks Come In
- `gt_bon1`
- `gt_Bon2`
- `gt_Phase1Start` — Phase 1 Start
- `gt_DrillTimerStart` — Drill Timer Start
- `gt_DrillTimerExpires` — Drill Timer Expires
- `gt_ArchonsDeadFreeMoebius` — Archons Dead, Free Moebius
- `gt_DarkArchonChampionPingRemove` — Dark Archon Champion Ping Remove
- `gt_WeneedTanksandBunkersQ15s` — We need Tanks and Bunkers Q - 15s
- `gt_ProtossincomingQ65s` — Protoss incoming Q - 65s
- `gt_UseLaserDrillQ360s` — Use Laser Drill Q - 360s
- `gt_DelayedRelicReveal630s` — Delayed Relic Reveal - 630s
- `gt_PlayerIsInCombat` — Player Is In Combat
- `gt_PlayerIsInCombatIndicatorDiminish` — Player Is In Combat Indicator Diminish
- `gt_CreateTempleDoorBossBar` — Create Temple Door Boss Bar
- `gt_Laserkillsaprotossunit` — Laser kills a protoss unit
- `gt__10AnniversaryAchievementLaserKillsTracking` — 10 Anniversary Achievement - Laser Kills Tracking
- `gt_LaserSoundFiringDelay` — Laser Sound Firing Delay
- `gt_LaserSoundRegionClear` — Laser Sound Region Clear
- `gt_LaserSoundFiring` — Laser Sound Firing
- `gt_LaserDrillDies` — Laser Drill Dies
- `gt_TempleHPEvents` — Temple HP Events
- `gt_TempleHPLow3Q19m` — Temple HP Low 3 Q - 19m
- `gt_MoebiusKills` — Moebius Kills
- `gt_MoebiusExpo` — Moebius Expo
- `gt_StartAI` — Start AI
- `gt_AIEndSuicide` — AI End Suicide
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_AIP6WarpInSuicide` — AI P6 Warp In Suicide
- `gt_AIP6CargoDropSuicide` — AI P6 Cargo Drop Suicide
- `gt_PingDangerousUnits` — Ping Dangerous Units
- `gt_PingDangerousUnitsDeathTransfer` — Ping Dangerous Units Death Transfer
- `gt_PingDangerousUnitsBullyRemoval` — Ping Dangerous Units Bully Removal
- `gt_Shrine1Killed` — Shrine 1 Killed
- `gt_Shrine2Killed` — Shrine 2 Killed
- `gt_Shrine3Killed` — Shrine 3 Killed
- `gt_CarrionBirds` — Carrion Birds
- `gt_CarrionBirdFlysAway` — Carrion Bird Flys Away
- `gt_SiegeTankKills` — Siege Tank Kills
- `gt_DetermineRemainingProtoss` — Determine Remaining Protoss
- `gt_AchievementLaserDrill20Kills` — Achievement - Laser Drill 20 Kills
- `gt_Achievement50ProtossStructuresDestroyed` — Achievement - 50 Protoss Structures Destroyed
- `gt_MidSetup` — Mid Setup
- `gt_MidCinematic` — Mid Cinematic
- `gt_MidCinematicEnd` — Mid Cinematic End
- `gt_MidCleanup` — Mid Cleanup
- `gt_MidCinematicWarpIn` — Mid Cinematic Warp In
- `gt_MidCinematicWarpInOrders` — Mid Cinematic Warp In Orders

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 108 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulty` — Init 06 Difficulty
- `gt_SiegeTankIntroQ` — Siege Tank Intro Q
- `gt_SiegeTanksComeIn` — Siege Tanks Come In
- `gt_SiegeTankTipQ` — Siege Tank Tip Q
- `gt_TacticalVictory` — Tactical Victory
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGameTacticalPhase` — Start Game - Tactical Phase
- `gt_bon1`
- `gt_Bon2`
- `gt_ZealotAggroQ` — Zealot Aggro Q
- `gt_RaynorQ` — Raynor Q
- `gt_InitDarkArchonDies` — Init Dark Archon Dies
- `gt_Phase1Start` — Phase 1 Start
- `gt_DrillTimerStart` — Drill Timer Start
- `gt_DrillTimerExpires` — Drill Timer Expires
- `gt_ArchonsDeadFreeMoebius` — Archons Dead, Free Moebius
- `gt_DarkArchonChampionPingRemove` — Dark Archon Champion Ping Remove
- `gt_StartGameDefensePhase` — Start Game - Defense Phase
- `gt_WeneedTanksandBunkersQ15s` — We need Tanks and Bunkers Q - 15s
- `gt_ProtossincomingQ65s` — Protoss incoming Q - 65s
- `gt_UseLaserDrillQ360s` — Use Laser Drill Q - 360s
- `gt_RevealRelicShrinesQ` — Reveal Relic Shrines Q
- `gt_DelayedRelicReveal630s` — Delayed Relic Reveal - 630s
- `gt_CampaignTipsQ` — Campaign Tips Q
- `gt_PlayerIsInCombat` — Player Is In Combat
- `gt_PlayerIsInCombatIndicatorDiminish` — Player Is In Combat Indicator Diminish
- `gt_CreateTempleDoorBossBar` — Create Temple Door Boss Bar
- `gt_Laserdrillunderattack01Q` — Laser drill under attack 01 Q
- `gt_Laserdrillunderattack02Q` — Laser drill under attack 02 Q
- `gt_Laserdrillunderattack03Q` — Laser drill under attack 03 Q
- `gt_Laserdrillunderattack04Q` — Laser drill under attack 04 Q
- `gt_DrillisrepairabletipQ` — Drill is repairable tip Q
- `gt_Laserisattackedbyenemy` — Laser is attacked by enemy
- `gt_LaserisattackedbyplayerQ` — Laser is attacked by player Q
- `gt_LaserkillsaplayerunitQ` — Laser kills a player unit Q
- `gt_Laserkillsaprotossunit` — Laser kills a protoss unit
- `gt__10AnniversaryAchievementLaserKillsTracking` — 10 Anniversary Achievement - Laser Kills Tracking
- `gt_LaserSoundFiringDelay` — Laser Sound Firing Delay
- `gt_LaserSoundRegionClear` — Laser Sound Region Clear
- `gt_LaserSoundFiring` — Laser Sound Firing
- `gt_LaserDrillDies` — Laser Drill Dies
- `gt_TempleHPEvents` — Temple HP Events
- `gt_TempleHPLow1Q` — Temple HP Low 1 Q
- `gt_TempleHPLow2Q` — Temple HP Low 2 Q
- `gt_TempleHPLow3Q19m` — Temple HP Low 3 Q - 19m
- `gt_TempleHPLow4Q` — Temple HP Low 4 Q
- `gt_PrismAttackPhase1Training` — Prism Attack Phase 1 - Training
- `gt_PrismAttackPhase1aWarpedIn` — Prism Attack Phase 1a - Warped In
- `gt_PrismAttackPhase2NW` — Prism Attack Phase 2 - NW
- `gt_PrismAttackPhase2NE` — Prism Attack Phase 2 - NE
- `gt_PrismAttackPhase2SE` — Prism Attack Phase 2 - SE
- `gt_PrismAttackPhase2aWarnPlayer` — Prism Attack Phase 2a - Warn Player
- `gt_PrismAttackPhase3Arrival` — Prism Attack Phase 3 - Arrival
- `gt_IncomingPrismAttack01Q` — Incoming Prism Attack 01 Q
- `gt_IncomingPrismAttack02Q` — Incoming Prism Attack 02 Q
- `gt_IncomingPrismAttack03Q` — Incoming Prism Attack 03 Q
- `gt_MoebiusKills` — Moebius Kills
- `gt_MoebiusExpo` — Moebius Expo
- `gt_P9MoebiusAttackWaves` — P9 Moebius Attack Waves
- `gt_P9MoebiusAlliedAttackWaves` — P9 Moebius Allied Attack Waves
- `gt_P10ScionsAttackWaves` — P10 Scions Attack Waves
- `gt_P11DeathFleetAttackWaves` — P11 Death Fleet Attack Waves
- `gt_P12ForwardGuardAttackWaves` — P12 Forward Guard Attack Waves
- `gt_P13SmithAttackWaves` — P13 Smith Attack Waves
- `gt_SendDelayedAttackWaveThread` — Send Delayed Attack Wave Thread
- `gt_StartAI` — Start AI
- `gt_AIAttackWaves` — AI Attack Waves
- `gt_AIColossusWave` — AI Colossus Wave
- `gt_AIEndSuicide` — AI End Suicide
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_AIP6WarpInSuicide` — AI P6 Warp In Suicide
- `gt_AIP6CargoDropSuicide` — AI P6 Cargo Drop Suicide
- `gt_PingDangerousUnits` — Ping Dangerous Units
- `gt_PingDangerousUnitsDeathTransfer` — Ping Dangerous Units Death Transfer
- `gt_PingDangerousUnitsBullyRemoval` — Ping Dangerous Units Bully Removal
- `gt_Shrine1Killed` — Shrine 1 Killed
- `gt_Shrine2Killed` — Shrine 2 Killed
- `gt_Shrine3Killed` — Shrine 3 Killed
- `gt_CarrionBirds` — Carrion Birds
- `gt_CarrionBirdFlysAway` — Carrion Bird Flys Away
- `gt_SiegeTankKills` — Siege Tank Kills
- `gt_DetermineRemainingProtoss` — Determine Remaining Protoss
- `gt_AchievementLaserDrill20Kills` — Achievement - Laser Drill 20 Kills
- `gt_Achievement50ProtossStructuresDestroyed` — Achievement - 50 Protoss Structures Destroyed
- `gt_VictoryDestroyDoor` — Victory Destroy Door
- `gt_VictoryDestroyProtoss` — Victory Destroy Protoss
- `gt_VictoryDestroyProtossDialogueQ` — Victory Destroy Protoss Dialogue Q
- `gt_DefeatTacticalTroopsDestroyed` — Defeat Tactical Troops Destroyed
- `gt_DefeatLaserDrillDestroyed` — Defeat Laser Drill Destroyed
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_MidQ` — Mid Q
- `gt_MidSetup` — Mid Setup
- `gt_MidCinematic` — Mid Cinematic
- `gt_MidCinematicEnd` — Mid Cinematic End
- `gt_MidCleanup` — Mid Cleanup
- `gt_MidCinematicWarpIn` — Mid Cinematic Warp In
- `gt_MidCinematicWarpInOrders` — Mid Cinematic Warp In Orders
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictoryInitialMarineMove` — Victory Initial Marine Move
- `gt_VictoryDropship` — Victory Dropship

