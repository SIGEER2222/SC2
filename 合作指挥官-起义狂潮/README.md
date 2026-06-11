# 7vs1 混合地图测试说明

本目录是当前 7vs1 测试图的工作目录。当前只在这里整合回放提取出来的合作指挥官运行库和 `因子之翼` 的因子运行库，避免误改外层工程。

## 当前入口

- 当前进度与文件说明：`docs/当前进度与文件说明-2026-06-07.md`
- 启动测试说明：`docs/启动测试说明-2026-06-07.md`
- `Shared/CommanderPower/commander-power-metadata.json`：18 个官方指挥官的威望/精通结构化元数据，给后续独立 UI 选项和脚本测试复用。
- 当前自动烟测门槛：只有真正进图并完成地图初始化，才算玩法验证通过；`login_required` 只代表当前没有新增启动级阻塞。
- 当前结构基线：`ttosh02_7vs1.SC2Map` 是纯 `7vs1` 依赖基线图。
- 当前 28 张 `_7vs1` 地图都已去掉旧公共运行时 mod 的地图级依赖，并在地图本地带 `Lib67C0F0E7.galaxy` / `LibE0EAE146.galaxy`。
- 目标工程当前不再携带旧公共运行时 mod；`Mods/7vs1/CoopZeroPop.SC2Mod/Base.SC2Data/` 作为公共 Galaxy 库唯一来源。
- 当前 28 张 `_7vs1` 地图都已经去掉对 `Mods/XM/*.SC2Mod` 的地图级私有依赖。
- 目标目录当前只保留 `Mods/7vs1/` 与 `Mods/kit_mutations.SC2Mod`；旧 `Mods/XM/` 已从目标 runtime 目录移除。
- 当前 owner 线已不再携带旧公共运行时 mod；`launch-7vs1-coop-test.ps1` 现在按依赖白名单清理 live 目录里的未批准 workspace 私有 mod 残留。
- 原始地图不在本目录重复存放；统一回源到 `C:\Users\22448\Downloads\合作指挥官版起义狂潮0.81\Maps\XM` 做对照。

## 目录来源

- `Maps/ttosh02_7vs1.SC2Map`：当前 7vs1 欢迎来到丛林混合测试图。
- `Mods/7vs1/CoopZeroPop.SC2Mod`：来自 `7vs1母巢之战合作指挥官bate版_SC2Replay_94137/s2ma_packages/pkg03/extract`，用于提供指挥官选择、威望、精通、指挥官面板和核心机制。
- `Mods/kit_mutations.SC2Mod`：来自 `因子之翼/kit_mutations.SC2Mod`，用于提供合作突变因子运行库 `LibA070801C` 和 Mutators 数据。
- `Mods/7vs1/CoopZeroPop.SC2Mod/Base.SC2Data`：当前 7vs1 变体图批量本地化与运行时共用的公共 Galaxy 库来源。
- `Shared/CommanderPower/commander-power-metadata.json`：由 `scripts/export-commander-power-metadata.ps1` 从官方合作指挥官 JSON + `liberty.sc2mod` 威望本地化数据导出，当前验证脚本会直接消费这份元数据。

## 当前接入方式

- `Maps/ttosh02_7vs1.SC2Map/DocumentInfo` 已增加本地依赖 `file:Mods/kit_mutations.SC2Mod`。
- `Maps/ttosh02_7vs1.SC2Map/MapScript.galaxy` 已 include 并初始化 `LibA070801C`。
- 地图保留原本 `gt_StartAI`、进攻波次和任务初始化逻辑；因子只在 `gt_StartAI` 执行后附加启动。
- `CoopZeroPop.SC2Mod/Attributes` 新增 `Attribute011`，作为房主全局单选项。
- `Attribute011/Value001` 是关闭，默认关闭；`Value002..Value059` 对应 58 个 `kit_mutations` 中标记 `CustomAllowed` 的单体 Mutator。

## 已暴露的可选因子

当前暴露的是 `kit_mutations.SC2Mod/Base.SC2Data/GameData/Mutators.xml` 中 `CUser id="Mutators"` 下带 `CustomAllowed` 的 58 个单体因子：

- `Random`
- `WalkingInfested`
- `InfestedTerranSpawner`
- `BlackFog`
- `TimeWarp`
- `UnitSpeed`
- `Magnificent`
- `Entomb`
- `Barrier`
- `Avenger`
- `SideStep`
- `FireFight`
- `LavaBurst`
- `DeathAOE`
- `DropPods`
- `SpawnBroodlings`
- `LaserDrill`
- `LongRange`
- `ReducedVision`
- `HybridNuke`
- `AllEnemiesCloaked`
- `NoResources`
- `ConcussiveAttacks`
- `JustDie`
- `TemporalField`
- `VoidRifts`
- `Tornadoes`
- `OrbitalStrike`
- `PurifierBeam`
- `Blizzard`
- `Fear`
- `PhotonOverload`
- `SpiderMines`
- `Reanimators`
- `Nukes`
- `LifeLeech`
- `OopsAllCasters`
- `OrderCosts`
- `MissileBarrage`
- `Vertigo`
- `Evolve`
- `UberDarkness`
- `TrickOrTreat`
- `DamageBounce`
- `Plague`
- `StructureSteal`
- `GiftFight`
- `HeroesFromTheStorm`
- `Inspiration`
- `HardenedWill`
- `Fireworks`
- `RedEnvelopes`
- `DamageReflect`
- `DeathPull`
- `Propagate`
- `MomentOfSilence`
- `KillBots`
- `BoomBots`

## 与官方镜像的对比

- `游戏数据/官方SC2原始文本镜像/mods/mutators/` 当前可见 239 个官方 mutator 目录。
- 其中大量 `mutatorcombo*.sc2mod` 是周突变/挑战组合包，不是单体因子。
- 排除 `mutatorcombo*` 和 `mutatorcustom.sc2mod` 后，官方镜像里可见 62 个非组合 mutator 目录。
- `kit_mutations.SC2Mod` 的 `CUser id="Mutators"` 下有 70 个实例，其中 58 个带 `CustomAllowed`，本次已全部暴露为 `Attribute011` 单选项。
- `kit_mutations.SC2Mod` 内存在但未暴露的 12 个实例是未标记 `CustomAllowed` 的条目：`[Default]`、`LazyWorkers`、`StoneZealots`、`CycleRandom`、`UndyingEvil`、`Polarity`、`FoodHunt`、`SharedSupply`、`KillKarma`、`AfraidOfTheDark`、`Insubordination`、`Sluggish`。
- 因此当前不是“官方全部 mutator 包完整接入”，而是“当前 `kit_mutations` 运行库中可自定义的单体因子全部接入”。后续如果要补齐官方 62 个非组合包或周突变组合包，需要继续搬对应官方 mutator mod 依赖并逐项测进图。

## 未接入内容

- 没有接入 `因子之翼/kit_liberty_mutation_challenge.SC2Mod`。
- 该 mod 带有自己的战役桥接库和 UI 桥接逻辑，和当前 7v1 测试图已有 `TriggerLibs/CampaignLib`、任务初始化、敌方进攻逻辑存在冲突风险。
- 当前先只接 `kit_mutations.SC2Mod` 的因子运行库，保证默认关闭、可单因子测试、尽量不改变原地图流程。

## 验证重点

- 默认 `7vs1因子=关闭` 时，应保持原 7v1 测试图流程。
- 选择具体因子时，应在进图后显示因子 UI，并由 P2 敌方阵营承载因子 AI。
- 若某个单因子进图失败，优先排查对应 Mutator 是否依赖挑战桥接库，而不是直接改地图主初始化。


要求：临时产生的文件都往 logs 目录下放
