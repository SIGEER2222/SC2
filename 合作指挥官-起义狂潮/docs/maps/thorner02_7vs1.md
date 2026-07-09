# thorner02_7vs1(博弈)

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/thorner02_7vs1.SC2Map` |
| 类型 | 战役改造 |
| MapScript.galaxy 行数 | 7784 |
| 触发器总数(gt_*_Func) | 143 |
| 全局变量数(gv_) | 90 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib`、`TriggerLibs/SwarmLib`、`LibA070801C`、`Lib67C0F0E7`、`LibE0EAE146` |
| 起始晶体矿 | 400 |
| 起始高能瓦斯 | 200 |
| 起始人口(supplies made) | 默认 |
| 特殊标志位 | 无 |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 43 |
| `unitgroup` | 15 |
| `unit` | 7 |
| `bool` | 6 |
| `actor` | 4 |
| `playergroup` | 3 |
| `revealer` | 2 |
| `region` | 2 |
| `unit[]` | 1 |
| `string` | 1 |
| `int[]` | 1 |
| `text` | 1 |
| `gs_HotKey[]` | 1 |
| `gs_Numpad` | 1 |
| `gs_EventArgsButtonPressed` | 1 |
| `fixed` | 1 |

其中 2 个为公共框架变量(28 张 _7vs1 图共有,从略)。

本图特有变量(88 个):

- `int gv_p01_USER`
- `int gv_p02_ORLAN_ENEMY`
- `int gv_p03_MIRA_HAN`
- `int gv_p04_DOMINION`
- `int gv_p05_SCRAP`
- `int gv_p06_JUNKERS`
- `int gv_p07_DERELICT_STRUCTURES`
- `int gv_p08_RAYNOR_COMP`
- `int gv_p09_PROTOSS_RELICS`
- `int gv_p11_SCRAPPERS`
- `int gv_p12_RAIDERS`
- `int gv_p13_DEMOLISHERS`
- `int gv_p14_ARSONISTS`
- `int gv_numpadHotKyesMax`
- `playergroup gv_junkerPlayers`
- `playergroup gv_miraHanPlayers`
- `playergroup gv_miraTargets`
- `unitgroup gv_playerSCVs`
- `int gv_orlansFortressPing`
- `int gv_mERC_CONTRACT_PRICE`
- `bool gv_miraHanContractBought`
- `int gv_oRLANS_MINERAL_COUNT`
- `unit gv_ghostNukeSilo`
- `unitgroup gv_minerals_In_Expansion_1`
- `unitgroup gv_minerals_In_Expansion_2`
- `unitgroup gv_minerals_In_Expansion_3`
- `revealer gv_centerAreaRevealer`
- `int gv_pingCommandCenterSW`
- `int gv_pingCommandCenterSE`
- `int gv_pingCommandCenterNE`
- `unit[] gv_initialElevatorBlockers`
- `int gv_contractWindowRoot`
- `int gv_contractWindowTitle`
- `int gv_contractWindowRaynorBar`
- `int gv_contractWindowRaynorLabel`
- `int gv_contractWindowOrlanBar`
- `int gv_contractWindowOrlanLabel`
- `unit gv_orlansFortress`
- `int gv_keyPadOpenButtonDialog`
- `int gv_keyPadOpenButton`
- `unit gv_rightCodeBeacon`
- `int gv_leftDigits`
- `int gv_centerDigits`
- `int gv_rightDigits`
- `string gv_passcodeString`
- `unit gv_junkerCacheTriggeringUnit`
- `bool gv_vaultNumpadActive`
- `int gv_numpadDialog`
- `int[] gv_inputButtons`
- `int gv_cancelButton`
- `int gv_inputButton`
- `text gv_currentNumber`
- `gs_HotKey[] gv_numpadHotKeys`
- `gs_Numpad gv_numpad`
- `gs_EventArgsButtonPressed gv_eventArgsButtonPressed`
- `int gv_contractWindow`
- `unit gv_junker_NE`
- `unit gv_junker_S`
- `unit gv_junker_W`
- `int gv_salvageNumber`
- `int gv_salvageTotal`
- `unitgroup gv_huge_Scrap_1`
- `unitgroup gv_huge_Scrap_2`
- `unitgroup gv_huge_Scrap_3`
- `int gv_aggressionCount`
- `actor gv_nukeActor`
- `region gv_ghostSpawnRegions`
- `int gv_nukePhase`
- `int gv_nukeIntensity`
- `unitgroup gv_nukers`
- `unitgroup gv_availableTargets`
- `fixed gv_nukeDelay`
- `revealer gv_salvageRevealer`
- `unitgroup gv_respawnSalvagePingUnits`
- `actor gv_respawnSalvagePingActor2`
- `actor gv_respawnSalvagePingActor1`
- `actor gv_salvagePingActor`
- `region gv_respawnableSalvage`
- `int gv_achievementSCVsTrained`
- `int gv_spiderMineKillCount`
- `int gv_mineralsHarvested`
- `unitgroup gv_briefingHiddenUnits`
- `bool gv_midCinematicCompleted`
- `unitgroup gv_midHiddenUnitGroup`
- `bool gv_victoryCinematicCompleted`
- `unitgroup gv_victoryHiddenUnitGroup`
- `unitgroup gv_victoryRaynorsUnits`
- `unitgroup gv_victoryOrlansUnits`

## 触发器清单

### 初始化(18)

- `gt_Initialization`
- `gt_Init01Technology` — Init 01 Technology
- `gt_Init02Players` — Init 02 Players
- `gt_Init03Units` — Init 03 Units
- `gt_Init04Music` — Init 04 Music
- `gt_Init05Environment` — Init 05 Environment
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGameStage1` — Start Game - Stage 1
- `gt_StartGameStage2` — Start Game - Stage 2
- `gt_InitialScrapSpawn3x3` — Initial Scrap Spawn (3x3)
- `gt_TransmissionRaynorIntroQ` — Transmission - Raynor Intro Q
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene00Stuff` — Briefing Scene 00 Stuff
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingSalvage` — Briefing Salvage

### 进攻波次(12)

- `gt_OrlanExpansion1Attacked` — Orlan Expansion 1 Attacked
- `gt_OrlanExpansion2Attacked` — Orlan Expansion 2 Attacked
- `gt_OrlanExpansion3Attacked` — Orlan Expansion 3 Attacked
- `gt_PlayerAttacksMira` — Player Attacks Mira
- `gt_OrlanP02InitialAttackWaves` — Orlan P02 Initial Attack Waves
- `gt_OrlanPostContractAttackWaves` — Orlan Post Contract Attack Waves
- `gt_MiraAttackWaves` — Mira Attack Waves
- `gt_P4AttackWaves` — P4 Attack Waves
- `gt_P11AttackWaves` — P11 Attack Waves
- `gt_P12AttackWaves` — P12 Attack Waves
- `gt_P13AttackWaves` — P13 Attack Waves
- `gt_P14AttackWaves` — P14 Attack Waves

### 胜负(14)

- `gt_VictoryDestroyOrlanCompleted` — Victory Destroy Orlan Completed
- `gt_Victory`
- `gt_VictoryCheat` — Victory Cheat
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatMiraHanDead` — Defeat Mira Han Dead
- `gt_DefeatOrlanBuysContract` — Defeat Orlan Buys Contract
- `gt_Defeat`
- `gt_DefeatCheat` — Defeat Cheat
- `gt_VictoryQ` — Victory Q
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictoryScene` — Victory Scene

### 对白提示(9)

- `gt_TransmissionHornerTalksAboutPlanetQ` — Transmission - Horner Talks About Planet Q
- `gt_TransmissionRespawnableSalvageQ` — Transmission - Respawnable Salvage Q
- `gt_TransmissionMiraHanGivesVulturesQ` — Transmission - Mira Han Gives Vultures Q
- `gt_TransmissionOrlanNukeQ` — Transmission - Orlan Nuke Q
- `gt_TransmissionOrlanHalfwayDoneQ` — Transmission - Orlan Halfway Done Q
- `gt_TransmissionOrlanAlmostDoneQ` — Transmission - Orlan Almost Done Q
- `gt_TransmissionContractHalfFilledQ` — Transmission - Contract Half Filled Q
- `gt_TransmissionContractAlmostFilledQ` — Transmission - Contract Almost Filled Q
- `gt_MidQ` — Mid Q

### 其他(90)

- `gt_SpawnMagMines` — Spawn Mag Mines
- `gt_NukeDrops` — Nuke Drops
- `gt_SpawnReinforcements` — Spawn Reinforcements
- `gt_MiddleGate` — Middle Gate
- `gt_TopleftGate` — Top left Gate
- `gt_TopRightGate` — Top Right Gate
- `gt_CenterBeaconRevealed` — Center Beacon Revealed
- `gt_LeftBeaconRevealed` — Left Beacon Revealed
- `gt_SpawnRightCodeBeacon` — Spawn Right Code Beacon
- `gt_MakeOpenKeypadButton` — Make Open Keypad Button
- `gt_OpenKeypad` — Open Keypad
- `gt_VaultBeaconActivated` — Vault Beacon Activated
- `gt_VaultBeaconDeactivated` — Vault Beacon Deactivated
- `gt_ServicesDialogNumpadKeyButtonPackEvent` — Services.Dialog.Numpad.KeyButton.PackEvent
- `gt_NumpadHotKeysKeyDown` — Numpad.HotKeys.KeyDown
- `gt_PasscodeCheck` — Passcode Check
- `gt_NumpadShown` — Numpad.Shown
- `gt_NumpadKeyButtonClick` — Numpad.KeyButton.Click
- `gt_NumpadOKButtonClick` — Numpad.OKButton.Click
- `gt_NumpadCancelButtonClick` — Numpad.CancelButton.Click
- `gt_CreateOrlanCommandCenterPings` — Create Orlan Command Center Pings
- `gt_SuperCraneActivation` — Super Crane Activation
- `gt_CreateContract` — Create Contract
- `gt_CreateContractWindow` — Create Contract Window
- `gt_UpdateContractWindow` — Update Contract Window
- `gt_PlayerBuysContract` — Player Buys Contract
- `gt_MiraHanDestroyed` — Mira Han Destroyed
- `gt_MiraHanGivesVulturestoPlayer` — Mira Han Gives Vultures to Player
- `gt_OrlanMineralCount` — Orlan Mineral Count
- `gt_JunkersStart` — Junkers Start
- `gt_JunkerNESpawn` — Junker NE Spawn
- `gt_JunkerNEPitstop1` — Junker NE Pitstop 1
- `gt_JunkerNEPitstop2` — Junker NE Pitstop 2
- `gt_JunkerNEPitstop3` — Junker NE Pitstop 3
- `gt_JunkerNEDespawn` — Junker NE Despawn
- `gt_JunkerSSpawn` — Junker S Spawn
- `gt_JunkerSPitstop1` — Junker S Pitstop 1
- `gt_JunkerSPitstop2` — Junker S Pitstop 2
- `gt_JunkerSDespawn` — Junker S Despawn
- `gt_JunkerWInitiate` — Junker W Initiate
- `gt_JunkerWPitstop1` — Junker W Pitstop 1
- `gt_JunkerWPitstop2` — Junker W Pitstop 2
- `gt_JunkerKilledSpawnScrap` — Junker Killed - Spawn Scrap
- `gt_ResourcePickups` — Resource Pickups
- `gt_RespawnableScrapSalvaged3x3Site11` — Respawnable Scrap Salvaged (3x3) - Site 1-1
- `gt_RespawnableScrapSalvaged3x3Site12` — Respawnable Scrap Salvaged (3x3) - Site 1-2
- `gt_RespawnableScrapSalvaged3x3Site21` — Respawnable Scrap Salvaged (3x3) - Site 2-1
- `gt_RespawnableScrapSalvaged3x3Site22` — Respawnable Scrap Salvaged (3x3) - Site 2-2
- `gt_RespawnableScrapSalvaged3x3Site31` — Respawnable Scrap Salvaged (3x3) - Site 3-1
- `gt_RespawnableScrapSalvaged3x3Site32` — Respawnable Scrap Salvaged (3x3) - Site 3-2
- `gt_RespawnableScrapSalvaged3x3Site41` — Respawnable Scrap Salvaged (3x3) - Site 4-1
- `gt_RespawnableScrapSalvaged3x3Site42` — Respawnable Scrap Salvaged (3x3) - Site 4-2
- `gt_RespawnableScrapSalvaged3x3Site51` — Respawnable Scrap Salvaged (3x3) - Site 5-1
- `gt_RespawnableScrapSalvaged3x3Site52` — Respawnable Scrap Salvaged (3x3) - Site 5-2
- `gt_RespawnableScrapSalvaged3x3Site61` — Respawnable Scrap Salvaged (3x3) - Site 6-1
- `gt_RespawnableScrapSalvaged3x3Site62` — Respawnable Scrap Salvaged (3x3) - Site 6-2
- `gt_RespawnableScrapSalvaged3x3Site71` — Respawnable Scrap Salvaged (3x3) - Site 7-1
- `gt_RespawnableScrapSalvaged3x3Site72` — Respawnable Scrap Salvaged (3x3) - Site 7-2
- `gt_OrlanExpansion01DestroyedSE` — Orlan Expansion 01 Destroyed (SE)
- `gt_OrlanExpansion02DestroyedSW` — Orlan Expansion 02 Destroyed (SW)
- `gt_OrlanExpansion03DestroyedNE` — Orlan Expansion 03 Destroyed (NE)
- `gt_HugeScrapDestroyed` — Huge Scrap Destroyed
- `gt_OrlanGuardsSalvageSite1` — Orlan Guards Salvage Site 1
- `gt_OrlanGuardsSalvageSite2` — Orlan Guards Salvage Site 2
- `gt_OrlanGuardsSalvageSite3` — Orlan Guards Salvage Site 3
- `gt_OrlanGuardsSalvageSite4` — Orlan Guards Salvage Site 4
- `gt_RemoveRavenBully` — Remove Raven Bully
- `gt_MiraGoesHostile` — Mira Goes Hostile
- `gt_MiraStrikeFighters` — Mira Strike Fighters
- `gt_OrlanBonusSCVs` — Orlan Bonus SCVs
- `gt_BunkerRefill` — Bunker Refill
- `gt_StartAI` — Start AI
- `gt_OrlanRetributiveNuke` — Orlan Retributive Nuke
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_MiraExpo1` — Mira Expo 1
- `gt_MiraExpo2` — Mira Expo 2
- `gt_MiraExpo3` — Mira Expo 3
- `gt_NukeCycling` — Nuke Cycling
- `gt_GhostDiesRemoveNukeActor` — Ghost Dies, Remove Nuke Actor
- `gt_NukeCycle` — Nuke Cycle
- `gt_RemoveSalvagePing` — Remove Salvage Ping
- `gt_RemoveRespawnSalvagePings` — Remove Respawn Salvage Pings
- `gt_AchievementNoSCVTraining` — Achievement - No SCV Training
- `gt_Achievement25SpiderMineKills` — Achievement - 25 Spider Mine Kills
- `gt_KillswithSpiderMines` — Kills with Spider Mines
- `gt_MineralsHarvestedBySCVs` — Minerals Harvested By SCVs
- `gt_MidSetup` — Mid Setup
- `gt_MidCinematic` — Mid Cinematic
- `gt_MidCinematicEnd` — Mid Cinematic End
- `gt_MidCleanup` — Mid Cleanup

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

以下为非公共触发器(不在 28 张 _7vs1 图共有的 10 个公共框架触发器集合中),可作为梳理本图特有逻辑的线索(共 133 个):

- `gt_Init03Units` — Init 03 Units
- `gt_Init06Difficulties` — Init 06 Difficulties
- `gt_IntroSequence` — Intro Sequence
- `gt_StartGameStage1` — Start Game - Stage 1
- `gt_StartGameStage2` — Start Game - Stage 2
- `gt_SpawnMagMines` — Spawn Mag Mines
- `gt_NukeDrops` — Nuke Drops
- `gt_SpawnReinforcements` — Spawn Reinforcements
- `gt_MiddleGate` — Middle Gate
- `gt_TopleftGate` — Top left Gate
- `gt_TopRightGate` — Top Right Gate
- `gt_CenterBeaconRevealed` — Center Beacon Revealed
- `gt_LeftBeaconRevealed` — Left Beacon Revealed
- `gt_SpawnRightCodeBeacon` — Spawn Right Code Beacon
- `gt_MakeOpenKeypadButton` — Make Open Keypad Button
- `gt_OpenKeypad` — Open Keypad
- `gt_VaultBeaconActivated` — Vault Beacon Activated
- `gt_VaultBeaconDeactivated` — Vault Beacon Deactivated
- `gt_ServicesDialogNumpadKeyButtonPackEvent` — Services.Dialog.Numpad.KeyButton.PackEvent
- `gt_NumpadHotKeysKeyDown` — Numpad.HotKeys.KeyDown
- `gt_PasscodeCheck` — Passcode Check
- `gt_NumpadShown` — Numpad.Shown
- `gt_NumpadKeyButtonClick` — Numpad.KeyButton.Click
- `gt_NumpadOKButtonClick` — Numpad.OKButton.Click
- `gt_NumpadCancelButtonClick` — Numpad.CancelButton.Click
- `gt_CreateOrlanCommandCenterPings` — Create Orlan Command Center Pings
- `gt_SuperCraneActivation` — Super Crane Activation
- `gt_CreateContract` — Create Contract
- `gt_CreateContractWindow` — Create Contract Window
- `gt_UpdateContractWindow` — Update Contract Window
- `gt_PlayerBuysContract` — Player Buys Contract
- `gt_MiraHanDestroyed` — Mira Han Destroyed
- `gt_MiraHanGivesVulturestoPlayer` — Mira Han Gives Vultures to Player
- `gt_OrlanMineralCount` — Orlan Mineral Count
- `gt_OrlanExpansion1Attacked` — Orlan Expansion 1 Attacked
- `gt_OrlanExpansion2Attacked` — Orlan Expansion 2 Attacked
- `gt_OrlanExpansion3Attacked` — Orlan Expansion 3 Attacked
- `gt_JunkersStart` — Junkers Start
- `gt_JunkerNESpawn` — Junker NE Spawn
- `gt_JunkerNEPitstop1` — Junker NE Pitstop 1
- `gt_JunkerNEPitstop2` — Junker NE Pitstop 2
- `gt_JunkerNEPitstop3` — Junker NE Pitstop 3
- `gt_JunkerNEDespawn` — Junker NE Despawn
- `gt_JunkerSSpawn` — Junker S Spawn
- `gt_JunkerSPitstop1` — Junker S Pitstop 1
- `gt_JunkerSPitstop2` — Junker S Pitstop 2
- `gt_JunkerSDespawn` — Junker S Despawn
- `gt_JunkerWInitiate` — Junker W Initiate
- `gt_JunkerWPitstop1` — Junker W Pitstop 1
- `gt_JunkerWPitstop2` — Junker W Pitstop 2
- `gt_JunkerKilledSpawnScrap` — Junker Killed - Spawn Scrap
- `gt_InitialScrapSpawn3x3` — Initial Scrap Spawn (3x3)
- `gt_ResourcePickups` — Resource Pickups
- `gt_RespawnableScrapSalvaged3x3Site11` — Respawnable Scrap Salvaged (3x3) - Site 1-1
- `gt_RespawnableScrapSalvaged3x3Site12` — Respawnable Scrap Salvaged (3x3) - Site 1-2
- `gt_RespawnableScrapSalvaged3x3Site21` — Respawnable Scrap Salvaged (3x3) - Site 2-1
- `gt_RespawnableScrapSalvaged3x3Site22` — Respawnable Scrap Salvaged (3x3) - Site 2-2
- `gt_RespawnableScrapSalvaged3x3Site31` — Respawnable Scrap Salvaged (3x3) - Site 3-1
- `gt_RespawnableScrapSalvaged3x3Site32` — Respawnable Scrap Salvaged (3x3) - Site 3-2
- `gt_RespawnableScrapSalvaged3x3Site41` — Respawnable Scrap Salvaged (3x3) - Site 4-1
- `gt_RespawnableScrapSalvaged3x3Site42` — Respawnable Scrap Salvaged (3x3) - Site 4-2
- `gt_RespawnableScrapSalvaged3x3Site51` — Respawnable Scrap Salvaged (3x3) - Site 5-1
- `gt_RespawnableScrapSalvaged3x3Site52` — Respawnable Scrap Salvaged (3x3) - Site 5-2
- `gt_RespawnableScrapSalvaged3x3Site61` — Respawnable Scrap Salvaged (3x3) - Site 6-1
- `gt_RespawnableScrapSalvaged3x3Site62` — Respawnable Scrap Salvaged (3x3) - Site 6-2
- `gt_RespawnableScrapSalvaged3x3Site71` — Respawnable Scrap Salvaged (3x3) - Site 7-1
- `gt_RespawnableScrapSalvaged3x3Site72` — Respawnable Scrap Salvaged (3x3) - Site 7-2
- `gt_OrlanExpansion01DestroyedSE` — Orlan Expansion 01 Destroyed (SE)
- `gt_OrlanExpansion02DestroyedSW` — Orlan Expansion 02 Destroyed (SW)
- `gt_OrlanExpansion03DestroyedNE` — Orlan Expansion 03 Destroyed (NE)
- `gt_HugeScrapDestroyed` — Huge Scrap Destroyed
- `gt_OrlanGuardsSalvageSite1` — Orlan Guards Salvage Site 1
- `gt_OrlanGuardsSalvageSite2` — Orlan Guards Salvage Site 2
- `gt_OrlanGuardsSalvageSite3` — Orlan Guards Salvage Site 3
- `gt_OrlanGuardsSalvageSite4` — Orlan Guards Salvage Site 4
- `gt_RemoveRavenBully` — Remove Raven Bully
- `gt_PlayerAttacksMira` — Player Attacks Mira
- `gt_MiraGoesHostile` — Mira Goes Hostile
- `gt_MiraStrikeFighters` — Mira Strike Fighters
- `gt_OrlanBonusSCVs` — Orlan Bonus SCVs
- `gt_BunkerRefill` — Bunker Refill
- `gt_StartAI` — Start AI
- `gt_OrlanP02InitialAttackWaves` — Orlan P02 Initial Attack Waves
- `gt_OrlanRetributiveNuke` — Orlan Retributive Nuke
- `gt_OrlanPostContractAttackWaves` — Orlan Post Contract Attack Waves
- `gt_MiraAttackWaves` — Mira Attack Waves
- `gt_P4AttackWaves` — P4 Attack Waves
- `gt_P11AttackWaves` — P11 Attack Waves
- `gt_P12AttackWaves` — P12 Attack Waves
- `gt_P13AttackWaves` — P13 Attack Waves
- `gt_P14AttackWaves` — P14 Attack Waves
- `gt_ReinforceRegionsWithBullies` — Reinforce Regions With Bullies
- `gt_MiraExpo1` — Mira Expo 1
- `gt_MiraExpo2` — Mira Expo 2
- `gt_MiraExpo3` — Mira Expo 3
- `gt_NukeCycling` — Nuke Cycling
- `gt_GhostDiesRemoveNukeActor` — Ghost Dies, Remove Nuke Actor
- `gt_NukeCycle` — Nuke Cycle
- `gt_RemoveSalvagePing` — Remove Salvage Ping
- `gt_TransmissionRaynorIntroQ` — Transmission - Raynor Intro Q
- `gt_TransmissionHornerTalksAboutPlanetQ` — Transmission - Horner Talks About Planet Q
- `gt_TransmissionRespawnableSalvageQ` — Transmission - Respawnable Salvage Q
- `gt_RemoveRespawnSalvagePings` — Remove Respawn Salvage Pings
- `gt_TransmissionMiraHanGivesVulturesQ` — Transmission - Mira Han Gives Vultures Q
- `gt_TransmissionOrlanNukeQ` — Transmission - Orlan Nuke Q
- `gt_TransmissionOrlanHalfwayDoneQ` — Transmission - Orlan Halfway Done Q
- `gt_TransmissionOrlanAlmostDoneQ` — Transmission - Orlan Almost Done Q
- `gt_TransmissionContractHalfFilledQ` — Transmission - Contract Half Filled Q
- `gt_TransmissionContractAlmostFilledQ` — Transmission - Contract Almost Filled Q
- `gt_AchievementNoSCVTraining` — Achievement - No SCV Training
- `gt_Achievement25SpiderMineKills` — Achievement - 25 Spider Mine Kills
- `gt_KillswithSpiderMines` — Kills with Spider Mines
- `gt_MineralsHarvestedBySCVs` — Minerals Harvested By SCVs
- `gt_VictoryDestroyOrlanCompleted` — Victory Destroy Orlan Completed
- `gt_DefeatBaseDead` — Defeat Base Dead
- `gt_DefeatMiraHanDead` — Defeat Mira Han Dead
- `gt_DefeatOrlanBuysContract` — Defeat Orlan Buys Contract
- `gt_BriefingQ` — Briefing Q
- `gt_BriefingScene00` — Briefing Scene 00
- `gt_BriefingScene00Stuff` — Briefing Scene 00 Stuff
- `gt_BriefingScene01` — Briefing Scene 01
- `gt_BriefingScene02` — Briefing Scene 02
- `gt_BriefingSalvage` — Briefing Salvage
- `gt_MidQ` — Mid Q
- `gt_MidSetup` — Mid Setup
- `gt_MidCinematic` — Mid Cinematic
- `gt_MidCinematicEnd` — Mid Cinematic End
- `gt_MidCleanup` — Mid Cleanup
- `gt_VictorySetup` — Victory Setup
- `gt_VictoryCinematic` — Victory Cinematic
- `gt_VictoryCinematicEnd` — Victory Cinematic End
- `gt_VictoryCleanup` — Victory Cleanup
- `gt_VictoryScene` — Victory Scene

