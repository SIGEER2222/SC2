# 项目状态页

> 范围：`合作指挥官-起义狂潮`
> 更新时间：2026-07-13
> 状态来源：本文件只放状态，长设计见 `docs/系统结构与工作流优化设计-2026-07-11.md` 与 `docs/指挥官地图组合框架设计.md`

## 1. 当前主线目标

把项目从"多入口、多脚本、多事实源"的形态，收敛为围绕四个核心 manifest 的工程系统：

- `CompositionPlan` —— 组合计划单一真源
- `DataCenter.json` —— Catalog/Galaxy 数据中心 owner 唯一入口
- `MapProfile` —— 地图契约唯一入口
- `CommanderPackage` —— 指挥官身份和能力清单唯一入口

目标是把"任意指挥官 × 任意地图"从手工搬运，变成可迭代、可验证、可下放的工程流水线。

## 2. 当前可运行组合

| 组合 | 入口脚本 | 验证状态 | 说明 |
| --- | --- | --- | --- |
| `reborn.zexpedition03 × TerranRaynor` | `scripts/reborn/launch-reborn-commander.ps1` | smoke 通过 | 35 galaxy 注入、9 依赖、无致命 ScriptError、exit code 0；RebornBridge 空骨架验证通过（Phase 3） |
| `reborn.zexpedition03 × TerranAlenger3` | `scripts/reborn/launch-reborn-commander.ps1` | smoke 通过 | 24 Alenger mod 全依赖、无 ScriptError |
| 7vs1 系列地图（traynor01 等） | `scripts/launch-7vs1-coop-test.ps1` | Gary 真实 Neuro E2E 通过 | `-EnableNeuro -UseGary -Commanders TerranRaynor` 连接 `gary.exe` / `ws://127.0.0.1:8000`；RuntimeProbe 上下文、actions/register、玩家指令 force、action 选择纠偏、`move_to_unit(SCVRaynor, CommandCenterRaynor)` 游戏执行通过 |
| 光晕测试地图 | 已移除（工作区已删除） | n/a | 实验：残影效果数据空间集成 |

> 说明：smoke 通过 = SC2 启动、无 ScriptError、进程正常。不等于单位诊断/运行时 probe 通过。

## 3. 当前已验证组合（含行为验证）

| 组合 | 验证内容 | 证据 |
| --- | --- | --- |
| `reborn.zexpedition03 × TerranRaynor` | galaxy 编译、依赖闭包、DocumentHeader/Info roundtrip | commit 2739165、69dcdb6（fix_003） |
| `7vs1 × TerranRaynor × Gary Neuro` | 真实 Gary WebSocket、玩家指令 force、游戏侧单位操作 | 2026-07-13：Gary PID 38776 监听 8000，两个 Python 客户端真实连接；force 指令会在 Gary 选错 action 时按玩家明确命令纠偏；最终 `codex_move_final` 执行 `move_to_unit(SCVRaynor, CommandCenterRaynor)`，游戏侧返回 `OK: Ordered 12 SCVRaynor to move near CommandCenterRaynor.`；动作后 20 秒无新 ScriptError |

> 暂无组合完成完整 `unitDiagnostics + runtimeProbe` 的端到端验证报告，是当前最大债务之一。

## 4. 当前 Compatibility Shim

过渡期保留的兼容入口和临时事实源，将在 CompositionPlan 接管后冻结或移除。

| Shim | 位置 | 迁移目标 | 移除条件 |
| --- | --- | --- | --- |
| Reborn launcher 临时配置 | `Shared/Launcher/*.json` | `Shared/Commanders` + `Shared/Maps/profiles` + `DataCenter.json` | `sc2-composer plan` 完全覆盖 Reborn |
| LauncherCompatibilityPlan | `scripts/sc2-launcher/launcher-plan.ps1` | `CompositionPlan` | `sc2-composer plan` 覆盖 Reborn Raynor |
| 目录扫描 Galaxy 注入 | `launcher-plan.ps1` / `map-sync.ps1` | `Shared/Galaxy/reborn-compat-galaxy-manifest.json` | manifest 覆盖全部注入条目 |
| 旧 7vs1 启动器硬编码映射 | `launch-7vs1-coop-test.ps1` | `CompositionPlan` + plan runner | 新增 `-Plan` 参数并跑通回归 |
| Web launcher 自推导依赖 | `web-launcher/app.js` | `/api/plan/preview` + `/api/plan/launch` | Web 只消费 plan |

## 5. 当前高风险债务

按风险从高到低排序：

1. **Galaxy 注入仍靠目录扫描** —— 未声明文件可能被注入；需要 GalaxyManifest 初版（Task 3）。
2. **CoreRuntime 全指挥官硬编码 include** —— `LibE0EAE146.galaxy` 硬编码 include 所有指挥官 Runtime，导致 unselected commander 的 galaxy 也必须注入；需要在 generated bootstrap 中裁剪。
3. **`launch-7vs1-coop-test.ps1` 全量 fallback** —— 未指定 commander 时返回全量依赖；必须改为显式 `-LegacyAllCommanders`。
4. **Web launcher 独立事实** —— Web 自维护依赖计算逻辑，容易与 CLI/PowerShell 漂移。
5. **验证结果分散** —— ~~logs / console / docs / 低成本产物格式不统一；需要 VerificationReport schema（Task 5）。~~ **已落地**：`VerificationReport.schema.json` + `verificationReport.mjs` + `cli.mjs verify` 子命令；`zexpedition03 × TerranRaynor` 首份报告已生成。
6. **端到端行为验证覆盖仍需扩展** —— 7vs1 Raynor + Gary Neuro 已完成真实上下文、force 指令、玩家命令 action 纠偏和单位移动动作闭环；后续仍需扩展到攻击、集火、集结点、技能、科技研究、更多 commander 与 Bank 隔离矩阵。
7. **`Shared/Launcher` 与 `Shared/Commanders` 重复映射** —— 同一 commander 在两处定义，无冲突硬失败检查。

## 6. 下一步任务（按优先级）

按 `docs/系统结构与工作流优化设计-2026-07-11.md` §7 的 Task 列表推进：

1. **Task 1** ✅ —— `docs/PROJECT_STATUS.md` 状态页已建立。
2. **Task 2** ✅ —— `LauncherCompatibilityPlan` 增加 `knownDebt` / `sourceFacts` 字段，`-DryRun` 输出债务。
3. **Task 3** ✅ —— `Shared/Galaxy/galaxy-manifest.schema.json` + `reborn-compat-galaxy-manifest.json`（58 条目，与 launcher 注入数一致）。
4. **Task 4** ✅ —— `scripts/sc2-composer/src/rebornCompatibility.mjs` 从 `Shared/Launcher` 生成正式 `CompositionPlan`，`comparePlans` 与 launcher-plan 端到端一致。
5. **Task 5** ✅ —— `VerificationReport.schema.json` + `verificationReport.mjs` + `cli.mjs verify` 子命令；`zexpedition03 × TerranRaynor` 首份报告已生成。
6. **Phase 3 接管** —— Reborn launcher 支持 `-Plan` 参数；`-Commander/-MapName` 只作为 plan 生成快捷方式。

## 7. 最近一次验证报告路径

- **Phase 3 RebornBridge 骨架验证**：`docs/reborn-port/phase-3-report.md`（2026-07-12，空骨架 smoke 通过）
- **7vs1 Gary Neuro 真实端到端验证**：`docs/经验总结/Neuro接入与运行时验证-2026-07-13.md`（2026-07-13，真实 Gary 8000、context、force、玩家命令纠偏、move_to_unit 通过）
- smoke 报告：`docs/经验总结/2026-07-11_Reborn地图ScriptError修复.md`
- 工程化总结：`docs/经验总结/reborn启动器工程化总结-2026-07-11.md`
- 数据空间迁移：fix_003 分支 commit `69dcdb6`（55 mods 通过 lint）
- **统一 VerificationReport**：`out/verification/reborn.zexpedition03_reborn_port__p1-TerranRaynor/<runId>.verification.json` + `.md`（由 `node cli.mjs verify --map ... --commander ...` 生成）

> 统一 `VerificationReport` schema（Task 5）已落地，所有新验证产物应输出到 `out/verification/<compositionId>/<runId>.verification.json` + `.md`。

## 8. 当前系统总线

```text
Shared/Commanders + Shared/Maps/profiles + Mods/**/DataCenter.json + Shared/Launcher (过渡)
                              ↓
scripts/sc2-composer plan  →  CompositionPlan.json
                              ↓
scripts/sc2-launcher / web-launcher / launch-7vs1  (执行 plan)
                              ↓
scripts/sc2-editor-toolkit + galaxy-checker + runtime probes  (验证)
                              ↓
docs/经验总结 + out/verification/ + fixtures  (沉淀)
```
