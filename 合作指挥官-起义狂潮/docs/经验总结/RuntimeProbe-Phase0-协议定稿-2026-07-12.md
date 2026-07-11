# RuntimeProbe Phase 0 协议定稿

- 任务类型：架构设计 / 协议定稿
- 时间戳：2026-07-12
- 任务内容：根据 `SC2-API自动进图自检方案选型-2026-07-12.md`，完成 RuntimeProbe Bridge 的 Phase 0（协议定稿），产出 Bank 协议规范文档和 JSON schema。
- 任务结果：完成 Phase 0 协议定稿，schema 通过 jsonschema 校验，覆盖 Raynor Marine/Marauder/Vulture 最小诊断案例。
- 任务耗时：约 25 分钟。
- 任务备注：本次为纯文档和 schema 定稿，不涉及地图/Mod/Galaxy/GameData/启动器运行逻辑改动，不触发进图测试门禁。

## 产物

| 文件 | 说明 |
|------|------|
| `docs/技术设计/RuntimeProbe-Bank协议.md` | Bank 协议规范 v0.1.0，定义 7 个 section |
| `scripts/runtime-probe/schemas/runtime-probe.schema.json` | VerificationReport JSON schema，8 个 $defs |
| `scripts/runtime-probe/validate_schema.py` | schema 合法性 + 最小诊断案例验证脚本 |

## 协议定稿内容

### 7 个 Bank Section

1. **probe_state** - 心跳与运行信息（run_id, heartbeat, phase, script_error_count, loaded_mods 等）
2. **probe_units** - 单位与建筑摘要（按 player_id + unit_type_id 分组，含 count/completed/in_progress/life/energy）
3. **probe_producers** - 生产建筑与可训练项（trainable/blocked/queue/last_order）
4. **probe_abilities** - 单位能力与命令卡（abilities/buttons/autocast/missing_expected）
5. **probe_upgrades** - 科技与升级状态（researched/available/in_progress/blocked_reason/affected）
6. **probe_assertions** - 游戏内断言结果（assertion_id/severity/status/expected/actual/message）
7. **probe_actions** - 外部请求触发器执行的动作（spawn_unit/try_train_unit/dump_command_card 等 8 种）

### JSON Schema 8 个 $defs

- ProbeState / ProbeUnit / ProbeProducer / ProbeAbility / ProbeUpgrade / ProbeAssertion / ThreeWayDiff / ProbeAction

### 关键设计决策

1. **独立 Bank**：RuntimeProbe.SC2Bank 与 NeuroIntegration.SC2Bank 解耦，诊断协议与玩游戏动作协议分离。
2. **ASCII 优先**：Bank 内部 key/section/action_id/assertion_id 保持 ASCII，避免 Galaxy 编码问题。
3. **心跳单调**：probe_state.heartbeat 单调递增，Python 端据此判断游戏是否运行。
4. **unknown 显式**：无法稳定获取的字段标为 unknown，不静默当成通过。
5. **动作幂等**：每个 probe action 带 action_id，触发器端去重。
6. **三段式差异**：报告输出 Expected from DataCenter / Static effective Catalog / Runtime observed fact 三段对比。

## 验证结果

```
[OK] schema JSON 解析成功
  title: RuntimeProbe VerificationReport
  defs: ['ProbeState', 'ProbeUnit', 'ProbeProducer', 'ProbeAbility', 'ProbeUpgrade', 'ProbeAssertion', 'ThreeWayDiff', 'ProbeAction']
[OK] jsonschema 库可用
[OK] 样例报告通过 schema 校验
  probe_units: 3 项
  probe_producers: 2 项
  probe_assertions: 2 项
  diffs: 2 项
[OK] 协议能覆盖 Raynor Marine/Marauder/Vulture 最小诊断案例
```

## Git 记录

- 分支：fix_003
- 提交：356bb53 "RuntimeProbe Phase 0：协议定稿"
- 推送：65a2b2c..356bb53 -> origin/fix_003
- 暂存文件：仅本任务的 3 个新文件，未触碰工作区其他未提交修改

## 与现有资产的关系

| 现有资产 | 关系 |
|---------|------|
| `scripts/airo/sc2_runtime_probe.py` | SC2API RequestObservation 通道（辅助方案，Phase 4 复用） |
| `scripts/airo/test-7vs1-only.ps1` | 测试启动脚本（Phase 1 可参考） |
| `docs/经验总结/SC2-API自动进图自检方案选型-2026-07-12.md` | 方案选型文档（本次实施的依据） |
| Neuro 集成的 Bank 监听/原子写入/心跳机制 | Phase 1 将复用（Shared Bank Runtime） |

## 后续 Phase

| Phase | 产物 | 验收 |
|-------|------|------|
| Phase 1 | RuntimeProbe.SC2Mod + Python Bank watcher + NoActionProbe 报告 | 启动 7vs1 测试地图后能拿到心跳、玩家、初始单位、建筑、已研究升级 |
| Phase 2 | try_train_unit probe action + producer dump | 能对兵营/工厂/星港输出可生产项，能发现"期望可造但运行时不可造"的单位 |
| Phase 3 | dump_unit_abilities + dump_command_card + try_research_upgrade | 能发现单位缺技能、按钮不显示、自动施法状态错误、科技升级对不上 |
| Phase 4 | 可选 RequestObservation 采集器 + 交叉校验 | 能确认 Bank 中的单位数量和 SC2API 观测数量是否一致 |
| Phase 5 | 组合矩阵 + VerificationReport 汇总 | 能批量找出哪些地图缺 RuntimeProbe 支持，按失败类型输出待修复清单 |
