# Neuro 运行时 WebUI 改造（Phase A）

- 日期：2026-07-12
- 作者：协作生成
- 状态：待批准
- 关联项目目标：SC2-Neuro-WoL-Integration（让 Neuro 在任务中当副官，任务间隙自由选择）

## 1. 背景与目标

### 1.1 现状

- `tools/SC2-Neuro-API-Integration/` 是第三方 Python 运行时（独立 git 仓库），通过 Bank 文件 IPC 与 SC2 galaxy 侧通信，通过 WebSocket 与 Neuro 通信
- 现有入口 `headless_runner.py` 无 UI，`SC2_integration.py` 是 tkinter UI（卡顿）
- 无日志收集，运行时事件和游戏日志分散
- `launch-7vs1-coop-test.ps1 -EnableNeuro` Step 6 调用 `headless_runner.py`

### 1.2 目标

- 替换 tkinter UI 为 FastAPI + WebSocket 的 webui（浏览器访问，流畅）
- webui 支持：实时监控（bank 状态、action/context 流、心跳）+ 手动控制（发 action、暂停/恢复）
- 日志接入：运行时日志 + SC2 GameLogs（当天保留）
- 保持原位置改，不 fork

### 1.3 非目标

- 不改 galaxy 侧代码（Phase B/C/D 处理）
- 不改 Bank IPC 协议
- 不改 Neuro WebSocket 协议
- 不替换 `SC2_integration.py`（保留作备用）

## 2. 架构设计

### 2.1 组件结构

```
tools/SC2-Neuro-API-Integration/
├── neuro_integration_runtime.py   # 保留，加 hook 回调
├── bank_file_io.py                # 保留
├── message_builder.py             # 保留
├── protocol.py                    # 保留
├── headless_runner.py             # 保留作参考
├── SC2_integration.py             # 保留(tkinter)，不作为默认入口
├── configure.json                 # 保留
├── webui/                         # 新增
│   ├── __init__.py
│   ├── server.py                  # FastAPI 应用 + WebSocket
│   ├── log_manager.py             # 日志收集(当天保留)
│   ├── routes.py                  # REST API 端点
│   └── static/
│       ├── index.html             # 单页应用
│       ├── app.js                 # 前端逻辑
│       └── style.css
├── run.py                         # 新入口: FastAPI + 核心运行时
└── requirements.txt               # 加 FastAPI + uvicorn
```

### 2.2 数据流

```
SC2 galaxy ──Bank文件──▶ neuro_integration_runtime ──WebSocket──▶ Neuro
                                    │
                                    ├─▶ webui/server.py ──WebSocket──▶ 浏览器
                                    │     (状态推送 + 日志流)
                                    │
                                    └─▶ webui/log_manager ──▶ 日志文件(当天)

浏览器 webui ──HTTP POST──▶ webui/routes ──▶ neuro_integration_runtime ──▶ Bank文件 ──▶ SC2 galaxy
```

### 2.3 进程模型

单进程，asyncio 事件循环：

- `run.py` 作为入口，启动 FastAPI (uvicorn) + 核心运行时
- 核心运行时通过 hook 回调将事件推送给 webui（状态变化、action 执行、日志）
- webui 通过内存队列与运行时通信（asyncio.Queue）
- 浏览器通过 WebSocket 实时接收事件，通过 HTTP POST 发送控制命令

## 3. 组件设计

### 3.1 `run.py`（新入口）

职责：启动 FastAPI 服务 + 核心运行时

```python
async def main():
    runner = HeadlessRunner()  # 复用现有运行时
    runner.load_config()
    
    # 注入 webui hook
    webui_manager = WebUIManager()
    runner.set_event_hook(webui_manager.push_event)
    
    # 启动 FastAPI
    app = create_app(runner, webui_manager)
    config = uvicorn.Config(app, host="127.0.0.1", port=8080, log_level="info")
    server = uvicorn.Server(config)
    
    # 并行启动
    await asyncio.gather(
        runner._start_integration(),
        server.serve()
    )
```

关键点：
- 复用 `HeadlessRunner`（继承 `NeuroIntegrationRuntimeMixin`）
- 通过 `set_event_hook` 注入回调，运行时事件推送到 webui
- FastAPI 端口 8080（可通过 configure.json 配置）

### 3.2 `webui/server.py`（FastAPI 应用）

职责：HTTP REST API + WebSocket 推送

**REST API 端点**：

| 方法 | 路径 | 功能 |
|------|------|------|
| GET | `/` | 返回 index.html |
| GET | `/api/status` | 运行时状态（连接状态、bank 路径、心跳、Neuro URL） |
| GET | `/api/bank` | 当前 bank 数据（解析后的 JSON） |
| GET | `/api/actions` | 已注册的 action 列表 |
| POST | `/api/action/trigger` | 手动触发 action（body: `{action_name, args}`，走运行时 `_action_queue`，与 Neuro 下发的 action 同路径） |
| POST | `/api/control/pause` | 暂停运行时 |
| POST | `/api/control/resume` | 恢复运行时 |
| GET | `/api/logs/runtime` | 运行时日志（当天，分页） |
| GET | `/api/logs/game` | 游戏日志（当天 GameLogs） |

**WebSocket 端点**：

| 路径 | 功能 |
|------|------|
| `/ws/events` | 实时事件流（bank 变化、action 执行、日志、心跳） |

事件格式：
```json
{
  "type": "bank_update" | "action_executed" | "log" | "heartbeat" | "connection",
  "timestamp": "2026-07-12T15:43:24",
  "data": { ... }
}
```

### 3.3 `webui/log_manager.py`（日志管理）

职责：收集运行时日志 + 游戏日志，只保留当天

**运行时日志**：
- 通过 hook 接收 `print_line` 输出
- 内存环形缓冲（最近 1000 条）+ 当天文件持久化
- 日志文件路径：`tools/SC2-Neuro-API-Integration/logs/runtime-{YYYYMMDD}.log`
- 启动时清理非当天的日志文件

**游戏日志**：
- 读取 `C:\Users\22448\Documents\StarCraft II\GameLogs\` 目录
- 只显示当天修改的文件（ScriptError*.txt、Alerts.txt 等）
- 每 2 秒轮询一次（watchdog 不适用于多个小文件）
- 提取关键错误（ScriptError、TriggerError）

**日志接口**：
```python
class LogManager:
    def push_runtime_log(self, level: int, text: str) -> None
    def get_runtime_logs(self, offset: int = 0, limit: int = 100) -> list[dict]
    def get_game_logs(self) -> list[dict]  # 当天文件列表+内容摘要
    def cleanup_old_logs(self) -> None  # 删除非当天日志文件
```

### 3.4 `webui/static/`（前端单页应用）

**index.html**：单页应用，三个 tab

1. **监控 tab**：
   - 运行时状态（连接状态、Neuro URL、bank 路径、心跳数）
   - Bank 数据树形展示（section → key → value）
   - Action 流（最近执行的 action + 结果）

2. **控制 tab**：
   - Action 列表（从 `/api/actions` 获取）
   - 手动触发 action 表单（选择 action + 填参数 + 提交）
   - 暂停/恢复按钮

3. **日志 tab**：
   - 运行时日志（实时滚动，支持级别过滤）
   - 游戏日志（当天 GameLogs 文件列表 + 内容查看）
   - 关键错误高亮（ScriptError 红色）

**app.js**：
- WebSocket 连接 `/ws/events`，实时更新 UI
- HTTP 调用 REST API 获取历史数据和发送控制命令
- 轻量，无框架依赖（原生 JS + fetch）

### 3.5 `neuro_integration_runtime.py` 修改

最小改动，加 hook 回调机制：

```python
class NeuroIntegrationRuntimeMixin:
    def _runtime_init(self) -> None:
        # ... 现有代码 ...
        self._event_hook: Callable[[str, dict], None] | None = None  # 新增
    
    def set_event_hook(self, hook: Callable[[str, dict], None]) -> None:  # 新增
        self._event_hook = hook
    
    def print_line(self, text: str, level: int = 2, override_verbosity: bool = False) -> None:
        # ... 现有打印逻辑 ...
        if self._event_hook:  # 新增
            self._event_hook("log", {"level": level, "text": text})
    
    async def _handle_bank_file_updated(self) -> None:
        # ... 现有解析逻辑 ...
        if self._event_hook:  # 新增
            self._event_hook("bank_update", {"data": self._last_parsed_bank_data})
```

关键 hook 点：
- `print_line`：所有日志输出
- `_handle_bank_file_updated`：bank 文件变化
- `_process_action_queue`：action 执行
- `_listen_neuro_messages`：Neuro 消息接收

## 4. launch 脚本对接

`launch-7vs1-coop-test.ps1` Step 6 修改：

**修改前**（当前代码）：
```powershell
# Step 6: 启动 Python 运行时
$pythonArgs = @($pythonPath, "headless_runner.py")
Start-Process $pythonPath -ArgumentList $pythonArgs -WorkingDirectory $NeuroApiRoot
```

**修改后**：
```powershell
# Step 6: 启动 Python 运行时（带 webui）
$pythonArgs = @($pythonPath, "run.py")
Start-Process $pythonPath -ArgumentList $pythonArgs -WorkingDirectory $NeuroApiRoot
Write-Host "WebUI: http://127.0.0.1:8080" -ForegroundColor Cyan
```

## 5. 依赖更新

`requirements.txt` 新增：
```
fastapi>=0.104.0
uvicorn[standard]>=0.24.0
```

其他依赖保持不变（aiohttp、watchdog、psutil 已存在）。

## 6. 配置扩展

`configure.json` 新增字段：
```json
{
  "game_path": "...",
  "banks_path": "...",
  "neuro_url": "...",
  "webui_host": "127.0.0.1",
  "webui_port": 8080
}
```

`webui_host` 和 `webui_port` 可选，默认 `127.0.0.1:8080`。

## 7. 验证标准

1. `python run.py` 启动后，浏览器访问 `http://127.0.0.1:8080` 能看到 webui
2. 启动 SC2 游戏后，监控 tab 能实时显示 bank 数据变化
3. 控制 tab 能手动触发 action（如 `get_mutators`）并看到结果
4. 日志 tab 能显示运行时日志和当天 GameLogs
5. `launch-7vs1-coop-test.ps1 -EnableNeuro` 启动游戏后，webui 自动可用
6. 性能：webui 流畅不卡顿（对比 tkinter 的明显改善）

## 8. 风险与缓解

| 风险 | 缓解 |
|------|------|
| FastAPI 与现有 asyncio 事件循环冲突 | 单进程，uvicorn 集成到现有 loop |
| WebSocket 连接断开 | 前端自动重连（指数退避） |
| 日志文件堆积 | 启动时清理非当天文件 |
| 游戏日志路径变化 | 从 configure.json 的 game_path 推导 |

## 9. 后续阶段（不在本 spec 范围）

- **Phase B**：galaxy 角色对话推送（监听 Transmission 事件，push context 给 Neuro）
- **Phase C**：永久能力系统（galaxy 数据层 + Bank 持久化）
- **Phase D**：任务间隙逻辑（跨地图状态 + 任务选择 UI）
