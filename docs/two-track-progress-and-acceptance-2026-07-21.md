# Neuro 与疯批帝国接入亡者之夜进度复盘、发展计划和验收门禁 - 2026-07-21

## 范围和证据

本文件复盘两个当前任务：

1. `Neuro`：7vs1/CMRE 运行时接入 Gary/Neuro，重点是动作暴露、动作执行和验证矩阵。
2. `疯批帝国接入王者之夜`：仓库内可证实实体是 `MadEmpire（疯批帝国）` / `Alenger3` 接入 CMRE `亡者之夜.SC2Map`。未在仓库中找到 `王者之夜` 资源名，后续如确有另一个地图名，需要先补 MapProfile/路径映射。

主要证据来源：

- `合作指挥官-起义狂潮/docs/PROJECT_STATUS.md`
- `docs/neuro-integration-execution-plan-2026-07-20.md`
- `合作指挥官-起义狂潮/Mods/Neuro/NeuroBridge7vs1.SC2Mod/Base.SC2Data/LibNeuroBridge7vs1.galaxy`
- `合作指挥官-起义狂潮/scripts/runtime-probe/neuro_bridge.py`
- `tools/SC2-Neuro-API-Integration/neuro_integration_runtime.py`
- `合作指挥官-起义狂潮/Shared/Launcher/cmre-dependencies.json`
- `合作指挥官-起义狂潮/scripts/cmre/launch-cmre.ps1`
- `sc2-porting-workspace/scripts/launch-cmre-alenger.ps1`
- `sc2-porting-workspace/projects/cmre-porting/stages/**/result.json`
- `sc2-porting-workspace/projects/cmre-porting/stages/04-runtime-baseline/issues.json`
- `sc2-porting-workspace/projects/cmre-porting/stages/04-runtime-baseline/evidence/runtime/ScriptError.20260721-113956.txt`
- `sc2-porting-workspace/projects/cmre-porting/stages/04-runtime-baseline/evidence/runtime/NeuroIntegration.SC2Bank.20260721-114000`
- `C:\Users\22448\Documents\StarCraft II\GameLogs\2026-07-21 11.39.56 ScriptError.txt`（原始 ScriptError，已被复制到 evidence/runtime）

证据口径：

- `依赖接入` 只表示启动计划会加载对应 Mod 或地图依赖。
- `加载通过` 只表示某个组合进入运行时并且没有某类缺 include/缺符号错误。
- `单位/建筑接入通过` 必须看到运行时单位、建筑、生产者、命令卡、训练/建造结果中的至少一类直接证据。
- `Neuro action 通过` 必须有 action flag 清除、结果 key 写回、结果内容可解释；如果结果是确定性错误，只能证明链路可达，不能证明该动作在游戏逻辑上成功。

## 总体状态

| 任务 | 当前结论 | 可继续推进的前提 |
| --- | --- | --- |
| Neuro | 有一份 `7vs1-TerranRaynor` action verification JSON 证明 14/14 action bank round-trip 通过；本轮轻量测试也通过。 | 继续补非 Raynor、ScriptError/进程状态固化、CMRE 外部驱动路径。 |
| 疯批帝国接入亡者之夜 | 5-dep 组合（CMRE_Core_Base + CMRE_Core_Triggers + AlengerCommon + Alenger3 + Alenger3Adapter）已能在亡者之夜稳定运行 140+ 秒无崩溃，`cmui_customization.galaxy` 编译失败已解决，Bank IPC 工作（`alenger_unit_presence` 写入成功，`Marine=121` 证明 UnitGroup 查询工作）。但单位/建筑/生产链运行时证据仍缺失，CMRE core（LibCOTF/LibCOMI）有 6 类非致命 runtime 错误待修。阶段仍是 blocked。 | 先补单位/建筑/生产链运行时证据（玩家 1 commander、起始单位、生产者命令卡），再修 `LibCOTF`/`LibCOMI` runtime 错误。 |

## 任务 A：Neuro

### 已完成

- 7vs1 启动器已支持 `-EnableNeuro -UseGary -Commanders TerranRaynor`。
- `start-neuro-runtime-service.ps1` 已作为共享 Gary/Neuro runtime service 入口，服务判定由 `wait-for-game-ready.ps1` 消费。
- 项目状态页记录了 `7vs1 x TerranRaynor x Gary Neuro` 真实 E2E：context、actions/register、玩家指令 force、action 选择纠偏、`move_to_unit(SCVRaynor, CommandCenterRaynor)` 游戏侧执行均通过。
- 已修复 action 暴露缺口：`get_mutators`、`build_building` 进入 Galaxy force-action 列表，`build_building` 进入 Python bridge `ADVISOR_ACTIONS`，并在 Neuro API runtime 中补齐参数模式。
- 已有一份动作级证据文件：`out/verification/7vs1-TerranRaynor/20260721T110509-9c405a.verification.json`。
  - `summary.total=14`、`passed=14`、`failed=0`。
  - `get_commander_status` 返回 `17 total units, 3 structures, 0 army units`。
  - `train_unit Marine` 返回 `OK: Ordered MarineRaynor via CommandCenterTrainRaynor[0]`。
  - `build_building SupplyDepot` 返回 `OK: Ordered SCV to build SupplyDepot via TerranBuildRaynor[1] (unit=SupplyDepotRaynor)`。
  - `move_to_unit(SCVRaynor, CommandCenterRaynor)` 返回 `OK: Ordered 12 SCVRaynor to move near CommandCenterRaynor`。
  - `use_ability Stimpack`、`research_upgrade TerranInfantryWeaponsLevel1`、`attack_unit Zergling`、`focus_fire Zergling`、`set_rally Barracks CommandCenter` 返回的是确定性错误或信息提示，只能证明 action 链路可达，不能证明这些游戏行为成功。
- 本次复盘重新跑了轻量验证：
  - `python -m py_compile 合作指挥官-起义狂潮/scripts/runtime-probe/neuro_bridge.py`：exit 0。
  - `python -m pytest tests/test_force_action_arguments.py`：17 passed。

### 仍未完成

- Raynor action matrix 已有一份 bank round-trip 报告，但还缺统一 VerificationReport 中的 ScriptError 结论、SC2 进程状态和原始日志索引。
- Galaxy、Python bridge、Neuro API runtime 仍分散维护 action 名称和参数事实，容易再次出现“实现了但工具列表缺失”的问题。
- 非 Raynor commander、非 7vs1 地图、CMRE 地图上的 Neuro 行为还没有完整报告。
- CMRE runtime 中发现 Bank 外部写入缓存问题：Gary/Python 外部写入 `NeuroIntegration.SC2Bank` 不会被运行中的 SC2 自动观察到，不能直接推断 CMRE 可用。

### 发展计划

1. 冻结 action matrix：从 Galaxy registration、Galaxy force-action、Python bridge、Neuro API runtime 生成一张对照表，名称不一致即失败。
2. 固化静态验证：Galaxy checker、Python compile、force-action pytest 作为 Neuro 每次变更的最小门禁。
3. 把 Raynor action matrix 从临时 JSON 升级为统一 VerificationReport：补 ScriptError、进程状态、日志路径和命令行。
4. 强化 force-action：覆盖中英文玩家指令、一参/二参动作、无效参数解释、普通聊天 fallback。
5. 扩展组合：先 `7vs1 x TerranMengsk`，再 `7vs1 x TerranNova`，之后进入 Reborn/CMRE。
6. 去重 action 事实源：新增共享 manifest，例如 `合作指挥官-起义狂潮/Shared/Neuro/actions.json`，由它生成或校验 Galaxy/Python 两端。

### Neuro 验收门禁

必须同时满足：

- Galaxy checker 对 `NeuroBridge7vs1.SC2Mod/Base.SC2Data` 为 0 errors；已知 include warning 必须在报告中点名。
- `python -m py_compile 合作指挥官-起义狂潮/scripts/runtime-probe/neuro_bridge.py` 通过。
- `python -m pytest tests/test_force_action_arguments.py` 通过。
- Raynor action matrix 每个 action 都有一条 runtime 证据，写入 `out/verification/<compositionId>/<runId>.verification.json`；成功动作和确定性失败动作必须分开统计。
- 启动到 action 执行后的观察窗口无新增致命 `ScriptError.txt`，SC2 进程保持存活。
- 至少一个非 Raynor commander 有 runtime verification report。
- 新增 action 不能只改一个文件；必须通过 action matrix 静态一致性测试。

建议命令：

```powershell
node "合作指挥官-起义狂潮/scripts/galaxy-checker/dist/cli.mjs" `
  "合作指挥官-起义狂潮/Mods/Neuro/NeuroBridge7vs1.SC2Mod/Base.SC2Data" --format text

python -m py_compile "合作指挥官-起义狂潮/scripts/runtime-probe/neuro_bridge.py"

pushd tools/SC2-Neuro-API-Integration
python -m pytest tests/test_force_action_arguments.py
popd

pwsh -NoProfile -ExecutionPolicy Bypass -File `
  "合作指挥官-起义狂潮/scripts/launch-7vs1-coop-test.ps1" `
  -EnableNeuro -UseGary -Commanders TerranRaynor

pwsh -NoProfile -ExecutionPolicy Bypass -File `
  "合作指挥官-起义狂潮/scripts/wait-for-game-ready.ps1"
```

## 任务 B：疯批帝国接入亡者之夜

### 命名和目标确认

- `疯批帝国` 在仓库文档中对应 `MadEmpire（疯批帝国）`，来源 `Alenger\3疯批帝国.SC2Mod`。
- 工程内运行 ID 使用 `TerranAlenger3`，包映射在 `sc2-porting-workspace/config/alenger-mods.json`：
  - `AlengerCommon`
  - `Alenger3`
  - `Alenger3Adapter`
- CMRE 地图目录存在 `合作指挥官-起义狂潮/Maps/CMRE/亡者之夜.SC2Map`。
- 正式 CMRE launcher 默认地图也是 `亡者之夜.SC2Map`。
- `王者之夜` 未找到直接资源；本任务暂按 `亡者之夜` 执行，除非后续补充别名或真实地图路径。

### 已完成

- CMRE 源包已导入：
  - 15 张任务地图。
  - 1 张启动器地图。
  - 5 个 CMRE core/art Mod 包。
- `cmre-dependencies.json` 已声明正式 CMRE 基础依赖：
  - `CMRE_Core_Base.SC2Mod`
  - `CMRE_Core_Triggers.SC2Mod`
- `合作指挥官-起义狂潮/scripts/cmre/launch-cmre.ps1` 已支持：
  - 原版 CMRE 模式。
  - 标准 7vs1 commander overlay。
  - `亡者之夜.SC2Map` 默认启动。
  - 可选 `-EnableNeuro` 注入 NeuroIntegration/NeuroBridge。
- `sc2-porting-workspace` 已建立 CMRE porting 项目，目标是把 CMRE 拆为 commander、shared runtime、map-series、map、commander-map 包。
- 阶段进度：
  - `01-discovery` passed：确认 CMRE 源结构、依赖图、source/composition/runtime scenario manifest。
  - `02-static-boundaries` passed：CMRE trigger mod 和 Dead of Night Galaxy 解析无 AST syntax errors；识别 Mengsk/Catalog 边界。
  - `03-mengsk-extraction-recipe` blocked：已生成 Mengsk extraction tree，差异主要是计划内 field move，但阶段未完全验收。
  - `04-runtime-baseline` blocked：不是全线失败，已有多个 runtime 子项通过，但仍有阻塞 issue。
- `sc2-porting-workspace/scripts/launch-cmre-alenger.ps1` 已作为专项入口：
  - 限定 `MapName = 亡者之夜.SC2Map`。
  - 限定 commander 格式 `TerranAlenger3`。
  - 按需同步 `AlengerCommon + Alenger3 + Alenger3Adapter`。
  - 给地图安装 CMRE Galaxy host overlay。
  - 自动写 CMRE launch profile，绕过 commander selection UI。
  - 安装 Dead of Night dynamic observer。
  - 写 `CampaignXCore` Bank 并走 `Wait-GameReady`。
- 2026-07-21 11:39 runtime 验证运行（5-dep 组合）：
  - `launch-cmre-alenger.ps1 -DryRun` 输出完整 5-dep 依赖链。
  - `SC2_x64.exe` PID=19192 启动于 11:39:09，运行 140+ 秒（222 秒后手动关闭）无崩溃，gameplay world 可达。
  - `2026-07-21 11.39.56 ScriptError.txt`（8041 字节）**无任何 `cmui_customization.galaxy` 编译错误**，`CMRE-ALENGER3-001` 解决。
  - `NeuroIntegration.SC2Bank` mtime 11:40:00 写入 `alenger_unit_presence = "Marine=121; 3diguoqianshaojidi=0; 3diguolaogong=0; 3diguojianzhengzhe=0"`，证明 Bank IPC 和 UnitGroup 全图查询工作，Alenger3 单位类型 ID 可查询（mod 依赖链加载成功）。
  - `porting_observer_ready` 也成功发布，确认 `BootstrapPortingObserver` 是可靠的 Bank 写入时机。
  - 证据文件：`sc2-porting-workspace/projects/cmre-porting/stages/04-runtime-baseline/evidence/runtime/{ScriptError.20260721-113956.txt, NeuroIntegration.SC2Bank.20260721-114000}`。

### 已证实子项

来自 `04-runtime-baseline/result.json`：

- `CMRE-RUNTIME-DIRECT-LAUNCH`：isolated CMRE source profile 能直接进入 Dead of Night gameplay world，不停在 commander-selection UI。
- `CMRE-RUNTIME-REAL-SERVICE`：单 Gary backend 和真实 Neuro integration runtime 能暴露地图注册 action。
- `CMRE-RUNTIME-ACTION-E2E`：`blank_test_neuro` 上 NeuroIntegration 的 `do_action/chat_message` 在 SC2 内部链路已 runtime 证明。
- `CMRE-ALENGER3-HEART-LOAD`：alenger-heart `3疯批帝国.SC2Mod` 加入 Dead of Night 后，无 `LibDF8E6945_h` 缺 include 和 `libDF8E6945_*` unresolved symbol。
- `CMRE-ALENGER3-CMUI-COMPILE`（2026-07-21 新增，verified-runtime）：5-dep 组合下 `cmui_customization.galaxy` 编译通过，2026-07-21 11:39:56 ScriptError.txt 中无任何 `cmui_customization.galaxy` 错误。`libCOOC_gf_CC_CommanderIsDeveloping` 在 `LibCOOC_h.galaxy:349` 声明、`LibCOOC.galaxy:1826` 定义，签名 `bool(string)` 匹配，`cmui_customization.galaxy:1889` 调用 `if (libCOOC_gf_CC_CommanderIsDeveloping(lp_commander) == true)` 是合法布尔表达式。`CMRE-ALENGER3-001` 解决。
- `CMRE-ALENGER3-BANK-IPC`（2026-07-21 新增，verified-runtime）：`NeuroIntegration.SC2Bank` 成功写入 `alenger_unit_presence = "Marine=121; 3diguoqianshaojidi=0; 3diguolaogong=0; 3diguojianzhengzhe=0"`。`Marine=121` 证明 UnitGroup 全图查询工作；3 个 Alenger3 单位类型 ID（`3diguoqianshaojidi`/`3diguolaogong`/`3diguojianzhengzhe`）可查询证明 mod 依赖链加载成功，count=0 是因为本次干净运行未执行 UnitCreate（2026-07-20 的临时 UnitCreate 验证已证明 `3diguoqianshaojidi=1` 可达）。`porting_observer_ready` 也成功发布。
- `CMRE-ALENGER3-RUNTIME-STABILITY`（2026-07-21 新增，partially-verified）：SC2 PID=19192 运行 140+ 秒（222 秒手动确认）无崩溃，gameplay world 可达。但剩余 6 类 CMRE core（LibCOTF/LibCOMI）非致命 runtime 错误，跟踪为 `CMRE-ALENGER3-RUNTIME-002`。

这些子项不能推出"疯批帝国单位/建筑已接入成功"。它们只证明：

- 组合能走到某些运行时阶段。
- `3疯批帝国.SC2Mod` 没有触发指定的缺 include/缺符号错误。
- `cmui_customization.galaxy` 在当前 5-dep 组合下编译通过。
- Bank IPC 和 UnitGroup 全图查询工作，Alenger3 单位类型 ID 可查询。
- SC2 进程在 LibCOTF/LibCOMI runtime 错误下不崩溃，gameplay world 可达。
- **仍然没有证据显示 `Alenger3` 的起始单位、建筑、生产链、命令卡或科技树在 `亡者之夜` 中可用**。`3diguoqianshaojidi=0` 只证明该单位类型 ID 可被 UnitGroup 查询，不证明玩家 1 实际拥有该单位。

### 未证实但必须补齐

以下证据当前未找到，不能写成已完成：

- 玩家 1 实际 commander 最终为 `TerranAlenger3` 的 Bank/probe 记录。
- `Alenger3` 起始建筑或核心单位的运行时数量，例如 `probe_units` 或 observer 输出。
- 至少一个 `Alenger3` 建筑存在且 `is_structure=1`。
- 至少一个 `Alenger3` 生产者的可训练项列表。
- 至少一次 `Alenger3` 单位训练或建筑建造的 OK 结果。
- `Alenger3` 命令卡关键按钮存在且 requirement 未锁死。

### 阻塞项

- `CMRE-RUNTIME-001` / `CMRE-RUNTIME-003`：SC2 BankLoad 缓存导致外部 Python/Gary 写入 `NeuroIntegration.SC2Bank` 后，运行中的 SC2 不会自动看见新 flag。SC2 内部 do_action 链路是通的，但真实外部驱动路径还不能验收。
- `CMRE-ALENGER3-001`（**已解决，2026-07-21**）：`Dead of Night x TerranAlenger3` 5-dep 组合下 `cmui_customization.galaxy` 编译通过。`libCOOC_gf_CC_CommanderIsDeveloping` 声明/定义/调用签名匹配，2026-07-19 的旧错误是 staged map 旧版本的瞬时状态。详见 `04-runtime-baseline/issues.json` 和 `CMRE-ALENGER3-CMUI-COMPILE` claim。
- `CMRE-ALENGER3-HEART-COTF-RUNTIME`：2-dep 组合触发 `LibCOTF.galaxy` runtime errors，包括 `EventPlayerEffectUsedUnitOwner` 无匹配 event、`libCOTF_gt_UT_RandomSeedRefresh_Func` 无法从 `PlayerHandle` 值 2 取得 `gameUser`。证据表明这是 CMRE core 集成问题，不是 alenger-heart 包本身缺 Dehaka 类依赖。
- `CMRE-ALENGER3-RUNTIME-002`（**新增，2026-07-21，open**）：5-dep 组合下 SC2 运行 140+ 秒无崩溃，但 ScriptError 记录 6 类 CMRE core（LibCOTF/LibCOMI）非致命 runtime 错误：
  - `LibCOTF.galaxy:176` — `EventPlayerEffectUsedUnitOwner` no matching event
  - `LibCOTF.galaxy:7828/7829` — `libCOTF_gt_UT_RandomSeedRefresh_Func` 无法从 `PlayerHandle` 值 2 取得 `gameUser`
  - `LibCOTF.galaxy:7959` — `libCOTF_gt_UT_AfterStart_Func` `DialogSetVisible` `triggerDialog=0`
  - `LibCOUI.galaxy:3306` — `libCOMI_gt_CM_GlobalCasterInit_Func` `DialogControlSetPropertyAsUnitGroup` `triggerControl=0`
  - `LibCOMI.galaxy:23813/23851` — `ArtReloadUnitCreate_Func` / `ArtReloadUnitMorph_Func` 无法找到目录条目 `''`（空字符串）
  - `LibCOMI.galaxy:18204/18244/18259` — `auto_libCOMI_gf_CM_HeroHandleDeath_TriggerFunc` 目录条目 `''` + `StringToFixed` str=0 + 除零

  这些错误表明 CMRE core 期望已配置的 commander slot 上下文，5-dep 组合的 saved-profile startup patch 可能未完全初始化该上下文。`HeroHandleDeath` 中的除零可能在英雄死亡时引发级联状态损坏。
- 专项入口还未并入正式 `launch-cmre.ps1` / `CompositionPlan` / web launcher，仍是 porting workspace 内的实验路径。

### 发展计划

1. 先确认命名：若用户确实要 `王者之夜`，新增或修正 MapProfile；否则统一称为 `亡者之夜.SC2Map`。
2. **优先补 runtime unit/building probe**（当前最大缺口）：用 RuntimeProbe 或 Dead of Night observer 输出玩家 1 的单位、建筑、生产者、命令卡，证明疯批帝国内容真正进入游戏态。当前 `alenger_unit_presence` 只查 4 个写死的单位类型 ID，且 count=0，不能证明玩家 1 实际拥有 Alenger3 单位。需要：
   - 扩展探针查询玩家 1 的所有单位（按 owner 过滤，而不是按 unit type ID）。
   - 输出玩家 1 的建筑列表和生产者命令卡。
   - 验证玩家 1 commander 最终为 `TerranAlenger3`（从 Bank 或 UserData 读取）。
3. 收口静态边界：把 `Alenger3` 的 package mapping 从 workspace config 升级到主项目 manifest，避免只有专项脚本知道。
4. 修 CMRE core runtime（`CMRE-ALENGER3-RUNTIME-002`）：
   - ~~追踪 `libCOOC_gf_CC_CommanderIsDeveloping` 声明/实现在哪个依赖层丢失~~（已解决，`CMRE-ALENGER3-001` resolved）。
   - 修 `LibCOTF` 对 player/event 的假设，使 2 玩家或自动 profile 场景稳定（`EventPlayerEffectUsedUnitOwner` 无匹配 event、`PlayerHandle=2` 无法取得 `gameUser`）。
   - 修 `LibCOTF_gt_UT_AfterStart_Func` 和 `libCOMI_gt_CM_GlobalCasterInit_Func` 的无效 dialog/control 句柄（`triggerDialog=0`、`triggerControl=0`）。
   - 修 `ArtReloadUnitCreate_Func` / `ArtReloadUnitMorph_Func` / `auto_libCOMI_gf_CM_HeroHandleDeath_TriggerFunc` 中的空目录条目问题，可能是 commander tech states 未完全初始化导致 `CatalogFieldValueGet` 返回空字符串。
   - 修 `HeroHandleDeath` 中的除零（`StringToFixed` str=0 后做除法）。
5. 修外部驱动 IPC：
   - 不再把外部写 bank 当成实时动作通道，除非证明 SC2 端可刷新 BankLoad。
   - 优先评估 SC2 端刷新 hook、预启动写入 + 运行时回传、或替代 IPC。
6. 把专项 launcher 行为产品化：
   - 将 `launch-cmre-alenger.ps1` 的 overlay/profile/observer 逻辑拆进主 launcher 或 sc2-composer plan runner。
   - `cmre-dependencies.json` 或新 CompositionPlan 正式声明 `TerranAlenger3`。
   - web launcher 只消费 plan，不再另算依赖。
7. 形成 runtime verification report：
   - source CMRE 原版。
   - `亡者之夜 x TerranAlenger3`。
   - `亡者之夜 x TerranAlenger3 x Neuro observer`。

### 疯批帝国接入验收门禁

必须同时满足：

- `launch-cmre-alenger.ps1 -MapName 亡者之夜.SC2Map -Commander TerranAlenger3 -DryRun` 能输出完整依赖：
  - CMRE base deps。
  - `AlengerCommon.SC2Mod`
  - `Alenger3.SC2Mod`
  - `Alenger3Adapter.SC2Mod`
- staged live map 的 `DocumentHeader` / `DocumentInfo` roundtrip 通过。
- Galaxy checker 对 staged map 或等效 Base.SC2Data 为 0 errors；任何 warning 必须分类为已知、可接受或阻塞。
- SC2 runtime 进入 Dead of Night gameplay world，不停在 commander selection UI。
- 运行至少 120 秒无新增致命 ScriptError：
  - 无 `LibDF8E6945_h` missing include。
  - 无 `libDF8E6945_*` unresolved symbol。
  - 无 `cmui_customization.galaxy` 编译失败。
  - 无当前 `LibCOTF` player/event runtime error。
- observer 至少发布：
  - readiness/event started。
  - Alenger3 presence probe。
  - day/night 或 objective 状态。
- 玩家 1 commander 最终为 `TerranAlenger3`，不是 CMRE 默认、随机或 UI 未选择状态。
- 建筑/单位可见性和基础生产链必须通过 probe 或可复现手动验收：
  - 初始单位和建筑记录必须包含 Alenger3 专属 ID 或明确映射后的疯批帝国 ID。
  - 至少一个 Alenger3 建筑记录为 structure。
  - 至少一个 Alenger3 生产者有可训练项。
  - 至少一次 Alenger3 单位训练或建筑建造返回 OK。
  - command card 不出现关键空按钮或 requirement 锁死。
- 验收产物写入 `out/verification` 或 `sc2-porting-workspace/projects/cmre-porting/stages/04-runtime-baseline/evidence/runtime`，并在 result/issue JSON 中有结论。

建议命令：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File `
  "合作指挥官-起义狂潮/scripts/cmre/launch-cmre.ps1" `
  -Commander CMRE -MapName "亡者之夜.SC2Map" -DryRun

pwsh -NoProfile -ExecutionPolicy Bypass -File `
  "sc2-porting-workspace/scripts/launch-cmre-alenger.ps1" `
  -MapName "亡者之夜.SC2Map" -Commander TerranAlenger3 -DryRun

pwsh -NoProfile -ExecutionPolicy Bypass -File `
  "sc2-porting-workspace/scripts/launch-cmre-alenger.ps1" `
  -MapName "亡者之夜.SC2Map" -Commander TerranAlenger3
```

## 推荐执行顺序

1. 先完成 Neuro action matrix 静态一致性测试。这是低风险、高收益，能防止同类工具缺失问题再次出现。
2. 再补 Raynor action matrix runtime report。已有 E2E 基础，最容易形成可复用验收模板。
3. 对疯批帝国线，**优先补单位/建筑 probe**（当前最大缺口）。`cmui_customization.galaxy` 编译失败已解决（`CMRE-ALENGER3-001` resolved），Bank IPC 已工作（`alenger_unit_presence` 写入成功），但 `3diguoqianshaojidi=0` 只证明单位类型 ID 可查询，不证明玩家 1 实际拥有该单位。需要扩展探针按 owner 查询玩家 1 的所有单位，输出建筑列表和生产者命令卡。没有单位/建筑证据前，不再写"已接入成功"。
4. 修 `CMRE-ALENGER3-RUNTIME-002`（LibCOTF/LibCOMI runtime 错误）。SC2 已能稳定运行 140+ 秒，但这些错误可能在英雄死亡或特定事件时引发级联失败。
5. 暂缓把 CMRE + Neuro 作为最终验收目标，先让 `亡者之夜 x TerranAlenger3` 非 Neuro 模式产出单位/建筑报告。
6. 最后把专项 launcher 逻辑并入主 CompositionPlan/launcher，并补 web launcher 预览和启动路径。

## 完成定义

两个任务都不能只以“能启动”作为完成。最终完成标准是：

- 每个组合有可重复命令。
- 每个组合有静态和 runtime 两类证据。
- 每个 runtime 证据有原始日志路径、SC2 进程状态、ScriptError 结论、动作或 observer 结果。
- 已知失败写入 issue JSON 或项目状态页，不靠口头记忆。
- 新增工具/action/commander/map 事实源能被自动校验，避免多文件手工漂移。
