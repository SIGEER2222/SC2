# RuntimeProbe 副官系统实现进度

**日期**: 2026-07-12
**分支**: fix_003
**任务类型**: 功能实现（Web 面板 + Neuro 桥接）+ Mod 依赖分析

## 一、已完成功能

### 1. Galaxy 扫描优化（持续扫描模式）

**文件**: `Mods/RuntimeProbe/RuntimeProbe.SC2Mod/Base.SC2Data/LibRuntimeProbe.galaxy`

**改动**:
- 恢复周期性 tick（3 秒一次，`c_timeGame`）
- 移除各扫描函数末尾的 `BankSave`，改为在 tick 结束时批量保存一次（4 次 → 1 次）
- `StartProbe()` 在 `gt_Initialization_Func` 中调用（`libAIROAdapter_gf_InitUnitReplacement()` 之后）
- `InitLib()` 中直接同步 `BankLoad` + 注册 tick

**测试结果**:
- Bank 文件: 8106 bytes
- heartbeat: 2（递增正常）
- phase: in_mission
- 单位: 5 种（Larva x3, CoopCasterKerrigan x1, Overlord x1, Hatchery x1, Drone x12）
- 升级: 30 个已研究
- 供应: 12/14
- ScriptError: 无
- galaxy-checker: 0 错误 0 警告

### 2. SC2API 观测器（备用方案）

**文件**: `scripts/runtime-probe/sc2api_observer.py`

**状态**: 代码完成，但战役图不可用

**说明**:
- 通过 SC2API WebSocket + RequestObservation 获取观测数据
- 零游戏内触发器开销
- 实测战役图启动后 SC2API 返回文本 `'None'` 而非 protobuf（确认文档中"战役图 SC2API 功能受限"的结论）
- 代码保留供非战役图（如 7vs1 自定义对战）使用

### 3. FastAPI Web 服务器

**文件**: `scripts/runtime-probe/web_server.py`

**功能**:
- 监听 `RuntimeProbe.SC2Bank` 文件 mtime 变化（0.5s 轮询）
- 解析 Bank 数据并生成 verification report
- 提供 REST API：
  - `GET /` - 前端面板 HTML
  - `GET /api/state` - 最新状态 JSON
  - `GET /api/state/md` - Markdown 报告
  - `GET /api/health` - 健康检查
- WebSocket 实时推送：`ws://127.0.0.1:8080/ws/live`

**测试结果**:
- `GET /api/health`: 200, `{"status":"ok","bank_loaded":true}`
- `GET /api/state`: 200, heartbeat=2, units=5, upgrades=30
- `GET /`: 200, 9746 字符 HTML
- WebSocket: 客户端连接后立即收到最新状态

### 4. 前端面板

**文件**: `scripts/runtime-probe/web/index.html`

**功能**:
- 实时显示 heartbeat、phase、资源、供应
- 单位列表表格（按数量排序）
- 生产建筑列表
- 已研究升级列表（按 ID 排序）
- 事件日志（heartbeat 变化记录）
- WebSocket 自动重连（5 秒）
- 暗色主题，SC2 风格

### 5. Neuro 桥接器

**文件**: `scripts/runtime-probe/neuro_bridge.py`

**功能**:
- 连接 Neuro WebSocket（`ws://127.0.0.1:41840`）
- 注册 6 个副官动作：
  1. `report_status` - 报告当前游戏状态
  2. `report_units` - 报告单位列表
  3. `report_upgrades` - 报告升级列表
  4. `report_producers` - 报告生产建筑
  5. `suggest_build_order` - 建议建造顺序
  6. `alert_supply_cap` - 供应预警
- 监听 RuntimeProbe Bank 变化，每 10 秒发送一次 context（中文状态报告）
- Neuro 执行动作后，把回复写入 `NeuroIntegration.SC2Bank` 的 `do_action/chat_message`，游戏显示为字幕
- 复用 `SC2-Neuro-API-Integration` 项目的 `message_builder` 和 `bank_file_io`

**状态**: 代码完成，未实际测试（需要 Neuro 服务运行）

### 6. 统一启动脚本

**文件**: `scripts/runtime-probe/start-advisor.ps1`

**功能**:
- 一个脚本启动所有组件
- Step 1: 调用 `launch-runtime-probe.ps1` 启动游戏（Bank 模式）
- Step 2: 后台启动 Web 服务器
- Step 3: 后台启动 Neuro 桥接器
- 支持 `-SkipGame`、`-SkipWeb`、`-SkipNeuro` 参数

## 二、Mod 依赖分析

### 地图直接依赖（12 条）

**项目内部 mod（9 个）**:
1. RevolutionOverdrive.SC2Mod → 依赖: Void.SC2Campaign
2. BaseCatalogPatch.SC2Mod → 依赖: VoidMulti + StarCoop
3. CommanderBridge.SC2Mod → 依赖: VoidMulti + StarCoop + CoreRuntime
4. CoreRuntime.SC2Mod → 依赖: VoidMulti + StarCoop
5. SharedUnits.SC2Mod → 依赖: VoidMulti + StarCoop
6. ExternalRefs.SC2Mod → 依赖: VoidMulti + StarCoop
7. kit_mutations.SC2Mod → 依赖: Void.SC2Campaign
8. AIROAdapter.SC2Mod → 依赖: 无（galaxy 物理注入）
9. CommanderUnits_Kerrigan.SC2Mod → 依赖: Void + StarCoop + BaseCatalogPatch

**官方依赖（3 个，无法移除）**:
10. Campaigns/LibertyStory.SC2Campaign
11. Mods/Liberty.SC2Mod
12. Campaigns/VoidStory.SC2Campaign

### 传递加载总计：16 个（9 项目 + 7 官方）

### 精简方案（用户选择"只分析不合并"）

**可合并到 CoreRuntime 的 mod**（都只依赖 VoidMulti + StarCoop）:
- BaseCatalogPatch
- SharedUnits
- ExternalRefs

**可合并到 CommanderBridge 的 mod**:
- kit_mutations（依赖 Void.SC2Campaign）

**合并后**：项目内部 mod 从 9 个 → 5 个，总数从 12 → 8

## 三、待办事项

1. **Neuro 桥接实测**: 需要 Neuro 服务运行时测试完整流程
2. **Mod 依赖精简**: 用户选择暂不合并，方案已记录
3. **SC2API 观测器**: 战役图不可用，7vs1 自定义对战图可用（未测试）
4. **性能优化**: 当前 3 秒 tick + 批量 BankSave，可进一步改为事件驱动

## 四、文件清单

| 文件 | 说明 | 状态 |
|------|------|------|
| `Mods/RuntimeProbe/RuntimeProbe.SC2Mod/Base.SC2Data/LibRuntimeProbe.galaxy` | Galaxy 触发器实现 | 已测试 |
| `Mods/RuntimeProbe/RuntimeProbe.SC2Mod/Base.SC2Data/LibRuntimeProbe_h.galaxy` | Galaxy 头文件 | 已测试 |
| `scripts/runtime-probe/sc2api_observer.py` | SC2API 观测器 | 战役图不可用 |
| `scripts/runtime-probe/web_server.py` | FastAPI Web 服务器 | 已测试 |
| `scripts/runtime-probe/web/index.html` | 前端面板 | 已测试 |
| `scripts/runtime-probe/neuro_bridge.py` | Neuro 桥接器 | 未实测 |
| `scripts/runtime-probe/start-advisor.ps1` | 统一启动脚本 | 已测试（部分） |
| `scripts/runtime-probe/launch-runtime-probe.ps1` | 游戏启动脚本 | 已测试 |

## 五、架构图

```
游戏内 Galaxy 触发器（3秒 tick）
  → BankValueSet 写入内存 Bank
  → BankSave 持久化到 RuntimeProbe.SC2Bank
  ↓
Python Web 服务器（监听 mtime）
  ├── /api/state      ← REST API
  ├── /ws/live        ← WebSocket 实时推送
  └── 前端面板 HTML
  ↓
浏览器（副官面板）
  ├── 资源卡片
  ├── 单位列表
  ├── 升级列表
  └── 事件日志

Python Neuro 桥接器
  ├── 监听 RuntimeProbe.SC2Bank → context 发送
  ├── 注册副官动作
  └── Neuro 回复 → NeuroIntegration.SC2Bank → 游戏字幕
```
