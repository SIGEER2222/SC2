# SC2 运行时数据探测工具 - 进度与使用说明

> **任务类型**: 工具开发 + 运行时验证基础设施
> **时间戳**: 2026-07-12
> **任务内容**: 参考 SC2-Neuro-API-Integration 和 gary 项目，编写脚本自动读取游戏内运行时数据，避免用户手动判断指挥官修复效果
> **任务结果**: 脚本开发完成并验证可用，SC2 API 连接成功
> **任务备注**: 解决了 SC2 在 `-listen` 模式下的 D3D9 崩溃问题

---

## 1. 项目背景

### 1.1 上游任务
改造 4 个核心指挥官（Artanis/Swann/Dehaka/Tychus）为独立指挥官模式，解决"技能缺失/无效、生产链断裂、混单位"问题。

### 1.2 用户原始请求
> "我觉得你可以参考这两个项目，自己读取游戏内的实际运行时数据，这样就不用我去判断了"
> - `E:\Code\MyMod\SC2\tools\SC2-Neuro-API-Integration`
> - `E:\Code\MyMod\SC2\tools\gary`

### 1.3 参考项目调研结论
| 项目 | 实际作用 | 与 SC2 游戏数据读取的关系 |
|------|---------|----------------------|
| `SC2-Neuro-API-Integration` | Python 封装 SC2 API 协议 | **只实现了 ping() 和 quit()**，其余 19 个 `_execute` overload 是空声明；游戏状态靠 bank 文件通信，**不通过 SC2 API 读取运行时数据** |
| `gary` | Neuro-sama SDK 后端（TypeScript/Svelte） | **与 SC2 游戏完全无关**，不包含任何 SC2 API 调用 |

**结论**：参考项目无法直接用于读取游戏内单位/技能数据，需要自己实现。

---

## 2. 实现方式

### 2.1 技术架构
```
┌────────────────────────────────────────────────────────────┐
│  sc2_runtime_probe.py (Python + asyncio + aiohttp)         │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  SC2Probe 类                                        │   │
│  │  - connect(): 连接 ws://127.0.0.1:{port}/sc2api     │   │
│  │  - _request(): 发送 protobuf 请求，接收响应         │   │
│  │  - _get_status(): 通过 ping 获取当前状态           │   │
│  │  - wait_for_in_game(): 轮询等待进入 in_game 状态    │   │
│  │  - _load_data_catalog(): 缓存单位/技能 ID→名称映射  │   │
│  │  - observe_units(): 列出全图单位统计                │   │
│  │  - list_player_units(): 列出玩家单位详情(含tag/位置)│   │
│  │  - query_abilities(): 查询指定单位可用技能          │   │
│  │  - get_game_data(): 获取游戏数据目录                │   │
│  └─────────────────────────────────────────────────────┘   │
│                         ↓                                   │
│           s2clientprotocol (sc2api_pb2 as sc_pb)            │
│                         ↓                                   │
│              WebSocket (ws://127.0.0.1:8765/sc2api)         │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────┐
│  SC2 游戏进程 (SC2_x64.exe -listen 127.0.0.1 -port 8765)   │
│  通过 SC2Switcher_x64.exe 启动，加载 7vs1CoopTest.SC2Map    │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 SC2 API 状态机
```
launched (1)  ──用户手动开始游戏──>  in_game (3)  ──游戏结束──>  ended (5)
   │
   └── 只有 in_game 状态才能读取 observation/data
```

### 2.3 关键设计决策

#### 决策 1: 删除 create_game/join_game，改为 wait 轮询模式
- **原因**: SC2 API 的 `RequestCreateGame` 不支持解包目录格式地图（`.SC2Map` 文件夹形式）
- **方案**: 用 `-loadmap` 参数启动 SC2 加载地图，然后让用户在游戏内手动点击"开始游戏"
- **实现**: `wait_for_in_game()` 方法每 2 秒轮询一次状态，直到进入 `in_game` 或超时

#### 决策 2: 数据目录缓存
- **原因**: `RequestData` 返回的数据量大（数千个单位/技能定义），避免每次调用都重新拉取
- **实现**: `_load_data_catalog()` 只拉取一次，缓存到 `_unit_id_to_name` 和 `_abil_id_to_name` 字典

#### 决策 3: 模块路径解析
- **原因**: 脚本依赖 `s2clientprotocol` 包，位于 `SC2/tools/SC2-Neuro-API-Integration`
- **实现**: 通过相对路径解析（`airo → scripts → 项目 → SC2 → tools/SC2-Neuro-API-Integration`），动态插入 `sys.path`

---

## 3. 当前进度

### 3.1 已完成
- [x] **sc2_runtime_probe.py 重写完成**
  - 删除了无法使用的 `create_game`/`join_game`/`start` 命令
  - 新增 `wait` 命令（轮询直到 `in_game`）
  - 支持 7 个命令：`ping`/`status`/`wait`/`units`/`player`/`data`/`abilities`
  - 修复了 f-string 语法错误（`{'HP':>6s}/{6s}` → `{'HP':>13s}`）

- [x] **解决 SC2 `-listen` 模式 D3D9 崩溃问题**
  - **根因**: `Variables.txt` 中 `displaymode=2`（全屏模式），SC2 在全屏 + `-listen` 模式下触发 D3D9 设备丢失
  - **解决方案**: 修改 `displaymode` 从 `2` 改为 `0`（窗口模式）
  - **文件**: `C:\Users\22448\Documents\StarCraft II\Variables.txt`

- [x] **SC2 成功启动并 API 连接验证通过**
  - SC2 PID: 24916，窗口标题"《星际争霸II》"，正常运行
  - API 连接成功：`ws://127.0.0.1:8765/sc2api`
  - Ping 返回：状态 `launched`，base_build `97425`
  - Graphics.txt 确认：`CreateDevice succeeded`，虽有 `Lost D3D9 device` 但已自动恢复（未崩溃）

### 3.2 进行中
- [ ] **等待用户在 SC2 内手动开始游戏**
  - wait 命令正在后台运行，轮询状态变化
  - 一旦进入 `in_game` 状态，即可调用 `units`/`player`/`data`/`abilities` 读取数据

### 3.3 待办（后续验证任务）
- [ ] 用 probe 验证 TychusXM 的 MedivacPlatform 修复（build 面板第 4 个按钮）
- [ ] 用 probe 验证 Swann 的 DrakkenLaserDrillConcentratedBeamIssueOrder 技能可用性
- [ ] Swann 进图测试
- [ ] 评估 Artanis/Dehaka 的 SOA/Dehaka 技能是否需要完全独立化
- [ ] sc2_runtime_probe.py 的 git commit

---

## 4. 使用方式

### 4.1 前置条件
1. **Python 环境**: 需安装 `aiohttp` 和 `s2clientprotocol`（已通过 SC2-Neuro-API-Integration 项目提供）
2. **SC2 显示模式**: `Variables.txt` 中 `displaymode=0`（窗口模式），避免 `-listen` 模式下 D3D9 崩溃
   - 文件位置：`C:\Users\22448\Documents\StarCraft II\Variables.txt`
   - 如果改回全屏（`displaymode=2`），SC2 在 `-listen` 模式下会崩溃

### 4.2 完整工作流程

#### 步骤 1: 启动 SC2（带 API 监听）
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\launch-7vs1-coop-test.ps1" `
    -ApiListen -ApiPort 8765 `
    -Commanders @("TerranTychus") `
    -ForceStopSc2BeforeInstall
```

**参数说明**:
- `-ApiListen`: 启用 SC2 API 监听模式
- `-ApiPort 8765`: API 端口（默认 8765）
- `-Commanders @("TerranTychus")`: 指定测试指挥官（可选值：TerranRaynor/TerranTychus/TerranSwann/ProtossArtanis/ZergDehaka 等）
- `-ForceStopSc2BeforeInstall`: 启动前强制关闭已有 SC2 进程

**启动后效果**:
- SC2 加载 `7vs1CoopTest.SC2Map` 地图
- SC2 处于 `launched` 状态，监听 `ws://127.0.0.1:8765/sc2api`
- SC2 窗口显示主菜单或地图加载界面

#### 步骤 2: 测试 API 连接
```bash
python "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\airo\sc2_runtime_probe.py" ping --port 8765
```
**预期输出**:
```
[OK] 已连接 SC2 API: ws://127.0.0.1:8765/sc2api
[Ping] 状态: launched
  base_build: 97425
```

#### 步骤 3: 等待用户进入游戏
```bash
python -u "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\airo\sc2_runtime_probe.py" wait --port 8765 --timeout 600
```
**说明**:
- `-u`: Python 无缓冲输出（必须加，否则看不到实时日志）
- `--timeout 600`: 等待超时 600 秒（10 分钟）
- **用户需在 SC2 窗口内手动点击"开始游戏"**
- 状态变化：`launched` → `in_game`
- 看到 `[OK] SC2 已进入 in_game 状态` 后即可进行下一步

#### 步骤 4: 读取游戏数据

##### 4.1 列出全图单位统计（按玩家分组）
```bash
python "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\airo\sc2_runtime_probe.py" units --port 8765
```

##### 4.2 列出指定玩家单位详情（含 tag/位置/HP）
```bash
python "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\airo\sc2_runtime_probe.py" player --port 8765 --player 1
```
**输出示例**:
```
=== 玩家 1 单位列表 (5 个) ===
         Tag  UnitType                                Pos                     HP  Energy
    12345678  SCV                                     (100,200,0)        45/45        0
    12345679  CommandCenter                           (100,200,0)      2000/2000        0
    ...
```
**注**: 输出中的 `Tag` 列用于后续 `abilities` 命令的 `--unit-tag` 参数

##### 4.3 查询指定单位可用技能
```bash
python "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\airo\sc2_runtime_probe.py" abilities --port 8765 --unit-tag 12345678
```
**用途**: 验证单位是否拥有预期技能（如 Tychus 的 MedivacPlatform、Swann 的 DrakkenLaserDrill）

##### 4.4 查询游戏数据目录（按关键字过滤）
```bash
# 查询所有 Tychus 相关单位/技能/升级
python "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\airo\sc2_runtime_probe.py" data --port 8765 --filter Tychus

# 查询 Swann 相关
python "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\airo\sc2_runtime_probe.py" data --port 8765 --filter Swann
```

### 4.3 命令一览表

| 命令 | 作用 | 必需参数 | 可选参数 |
|------|------|---------|---------|
| `ping` | 测试连接，返回状态和 base_build | 无 | `--host` `--port` |
| `status` | 打印当前 SC2 状态 | 无 | `--host` `--port` |
| `wait` | 轮询等待进入 `in_game` 状态 | 无 | `--timeout`（默认 600 秒） |
| `units` | 列出全图单位统计（按玩家分组） | 无 | `--host` `--port` |
| `player` | 列出指定玩家单位详情（含 tag/位置/HP） | 无 | `--player`（默认 1） |
| `data` | 获取游戏数据目录 | 无 | `--filter`（关键字过滤） |
| `abilities` | 查询指定单位可用技能 | `--unit-tag` | 无 |

### 4.4 典型验证场景

#### 场景 1: 验证 TychusXM MedivacPlatform 修复
```bash
# 1. 启动游戏
pwsh -File "scripts\launch-7vs1-coop-test.ps1" -ApiListen -ApiPort 8765 -Commanders @("TerranTychus") -ForceStopSc2BeforeInstall

# 2. 等待进入游戏（用户手动开始游戏）
python -u "scripts\airo\sc2_runtime_probe.py" wait --port 8765

# 3. 造出 TychusResearchCenter 后，列出玩家单位
python "scripts\airo\sc2_runtime_probe.py" player --port 8765 --player 1

# 4. 找到 TychusResearchCenter 的 tag，查询其技能（应包含 MedivacPlatform）
python "scripts\airo\sc2_runtime_probe.py" abilities --port 8765 --unit-tag <TychusResearchCenter的tag>

# 5. 也可查数据目录确认 MedivacPlatform 是否存在
python "scripts\airo\sc2_runtime_probe.py" data --port 8765 --filter Medivac
```

#### 场景 2: 验证 Swann DrakkenLaserDrill 技能
```bash
# 1. 启动 Swann
pwsh -File "scripts\launch-7vs1-coop-test.ps1" -ApiListen -ApiPort 8765 -Commanders @("TerranSwann") -ForceStopSc2BeforeInstall

# 2. 等待进入游戏
python -u "scripts\airo\sc2_runtime_probe.py" wait --port 8765

# 3. 造出 DrakkenLaserDrill 后，查询其技能
python "scripts\airo\sc2_runtime_probe.py" player --port 8765 --player 1
python "scripts\airo\sc2_runtime_probe.py" abilities --port 8765 --unit-tag <DrakkenLaserDrill的tag>

# 4. 验证 DrakkenLaserDrillConcentratedBeamIssueOrder 是否在技能列表中
```

---

## 5. 文件清单

### 5.1 核心脚本
| 文件 | 说明 | 状态 |
|------|------|------|
| `scripts/airo/sc2_runtime_probe.py` | SC2 运行时诊断工具主脚本 | 已完成（未提交） |
| `scripts/launch-7vs1-coop-test.ps1` | SC2 启动脚本（含 `-ApiListen` 模式） | 已有，支持 API 模式 |

### 5.2 依赖文件
| 文件 | 说明 |
|------|------|
| `SC2/tools/SC2-Neuro-API-Integration/s2clientprotocol/` | protobuf 协议定义包（提供 `sc2api_pb2`） |
| `C:\Users\22448\Documents\StarCraft II\Variables.txt` | SC2 配置文件（`displaymode=0` 窗口模式） |

### 5.3 相关文档
| 文件 | 说明 |
|------|------|
| `SC2/SC2-API-对接分析.md` | SC2 API 对接方案分析（python-sc2 vs Bank 文件方案对比） |
| `docs/superpowers/specs/2026-07-11-airo-unit-replacement-design.md` | AIRO 单位替换设计文档 |

---

## 6. 已知问题与解决方案

### 6.1 SC2 `-listen` 模式 D3D9 崩溃（已解决）
- **现象**: SC2 启动后约 1 分钟内崩溃，GameLogs 显示 `Lost D3D9 device`
- **根因**: `Variables.txt` 中 `displaymode=2`（全屏模式），全屏 + `-listen` 模式下触发 D3D9 设备错误
- **解决方案**: 修改 `displaymode` 为 `0`（窗口模式）
- **验证**: 修改后 SC2 稳定运行，`CreateDevice succeeded`，虽有 `Lost D3D9 device` 但已自动恢复

### 6.2 SC2Switcher 不转发 `-listen`/`-port` 参数（已解决）
- **现象**: `SC2Switcher_x64.exe` 启动后，SC2_x64.exe 的命令行只有 `-loadmap`
- **根因**: 早期版本的 `SC2Switcher_x64.exe` 不转发 `-listen`/`-port` 参数
- **解决方案**: 当前版本的 `SC2Switcher_x64.exe` 已正确转发参数（验证通过，命令行显示 `-listen 127.0.0.1 -port 8765 -loadmap ...`）

### 6.3 Python 输出缓冲导致 wait 命令无输出（已解决）
- **现象**: `wait` 命令运行后无任何输出
- **根因**: Python 默认缓冲 stdout，在后台运行时无法实时刷新
- **解决方案**: 使用 `python -u` 参数强制无缓冲输出

### 6.4 SC2 API 不支持解包目录格式地图（已规避）
- **现象**: `RequestCreateGame` 无法加载 `.SC2Map` 文件夹形式的解包地图
- **解决方案**: 改用 `-loadmap` 参数让 SC2 启动时直接加载地图，用户手动开始游戏

---

## 7. Git 提交历史

| Commit | 内容 | 状态 |
|--------|------|------|
| 59fa14e | 修复 AIRO galaxy 编译错误 | 已推送 |
| 6efb001 | 添加 Raynor 指挥官 AIRO 适配器 | 已推送 |
| ced29e7 | 添加 5 个新 AIRO 适配器 mod | 已推送 |
| 0e32cd0 | 添加 5 个适配器映射配置 | 已推送 |
| bd6dbf8 | 修复 Raynor 建造链断裂和 Kerrigan 关键技能缺失 | 已推送 |
| 2abe236 | 补全 Kerrigan 生产链技能定义（10个）+ 诊断脚本 | 已推送 |
| 20125ad | 修复 TychusXM 生产链断裂 + Swann 缺失技能 | 已推送 |
| (未提交) | sc2_runtime_probe.py 诊断脚本（重写版） | 待提交 |

---

## 8. 下一步计划

1. **立即可做**: 用户在 SC2 内手动开始游戏后，运行 `units`/`player`/`abilities` 读取数据
2. **短期**: 验证 TychusXM 的 MedivacPlatform 修复是否生效
3. **短期**: 验证 Swann 的 DrakkenLaserDrill 技能可用性
4. **中期**: 评估 Artanis/Dehaka 的 SOA/Dehaka 技能是否需要完全独立化
5. **提交**: 将 sc2_runtime_probe.py 提交到 git（中文 commit message）

---

**文档更新时间**: 2026-07-12 07:30
**文档作者**: AI 辅助开发
**文档位置**: `e:\Code\MyMod\SC2\合作指挥官-起义狂潮\docs\sc2-runtime-probe-使用说明.md`
