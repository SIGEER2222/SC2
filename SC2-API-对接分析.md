# SC2 API 对接方式分析

本文档分析了以下三个项目如何对接 SC2 API 获取游戏内数据：

- `E:\Code\MyMod\SC2\Large-Language-Models-play-StarCraftII`
- `E:\Code\MyMod\SC2\tools\SC2-Neuro-API-Integration`
- `E:\Code\MyMod\SC2\tools\SC2-Neuro-WoL-Integration`

---

## 总览

这三个项目展示了**两种截然不同**的 SC2 数据对接思路：

| 方案 | 代表项目 | 核心机制 |
|------|---------|---------|
| 方案一 | Large-Language-Models-play-StarCraftII | 使用 python-sc2 (burnysc2) 库，高层封装 |
| 方案二 | SC2-Neuro-API-Integration / WoL-Integration | 直接对接 SC2API + Bank 文件系统双通道 |

---

## 方案一：使用 python-sc2 库（高层封装）

**代表项目**：`Large-Language-Models-play-StarCraftII`

这是最简单、最标准的方式。项目使用 [BurnySc2/python-sc2](https://github.com/BurnySc2/python-sc2) 库，该库对 SC2 的 protobuf API 进行了完整封装。

### 核心架构

```
Python 代码  →  burnysc2 库  →  WebSocket(protobuf)  →  SC2 进程
```

### 启动方式

通过 `run_game()` 自动启动 SC2 进程并建立连接，见 `Protoss_bot.py:2151`：

```python
result = run_game(maps.get(map),
    [Bot(Race.Protoss, Protoss_Bot(transaction, lock, isReadyForNextStep)),
     Computer(map_race(opposite_race), map_difficulty(difficulty), map_ai_build(args.ai_build))],
    realtime=args.real_time,
    save_replay_as=temp_replay_path)
```

### 获取游戏数据的方式

继承 `BotAI` 类，在 `on_step(iteration)` 回调中直接读取，见 `Protoss_bot.py:443-696`：

```python
class Protoss_Bot(BotAI):
    async def on_step(self, iteration: int):
        information = self.get_information()  # 读取游戏状态
        ...
    
    def _get_resource_information(self):
        return {
            'game_time': self.time_formatted,      # 游戏时间
            'worker_supply': self.workers.amount,   # 农民数量
            'mineral': self.minerals,               # 矿产
            'gas': self.vespene,                    # 气体
            'supply_left': self.supply_left,        # 剩余人口
            'supply_cap': self.supply_cap,          # 人口上限
            'army_supply': self.supply_army,        # 军队人口
        }
```

### 可直接访问的数据（BotAI 提供）

- `self.units` / `self.structures` - 我方所有单位/建筑
- `self.enemy_units` / `self.enemy_structures` - 敌方单位/建筑
- `self.minerals` / `self.vespene` - 资源
- `self.workers` / `self.townhalls` - 农民/基地
- `self.supply_left` / `self.supply_cap` / `self.supply_used` / `self.supply_army` - 人口信息
- `self.time_formatted` - 游戏时间字符串
- `self.already_pending(UnitTypeId.XXX)` - 正在建造的数量
- `self.already_pending_upgrade(UpgradeId.XXX)` - 升级进度
- `self.game_info.map_center` / `self.enemy_start_locations` - 地图信息
- `self.expansion_locations_list` - 分矿点列表

### 执行动作

直接调用单位/建筑方法：

```python
nexus.train(UnitTypeId.PROBE)        # 训练农民
await self.build(UnitTypeId.PYLON)   # 建造建筑
unit.attack(target_location)          # 攻击
unit.move(rally_point)                # 移动
by.research(UpgradeId.WARPGATERESEARCH)  # 研究升级
```

### 特点

- 完全控制游戏启动/结束
- 适合 **AI vs AI** 或 **AI vs 内置电脑**
- 不适合对接正在运行的玩家游戏
- 需要 Python 进程作为 Bot 参与者

### 关键文件

- `sc2_rl_agent/starcraftenv_test/env/bot/Protoss_bot.py` - Protoss Bot 实现，包含 `get_information()` 数据采集和 `handle_action_X()` 动作执行
- `sc2_rl_agent/starcraftenv_test/env/single_agent.py` - Gym 环境封装，通过 `multiprocessing` 与 Bot 进程通信
- `sc2_rl_agent/starcraftenv_test/env/starcraft_env.py` - 环境选择器

---

## 方案二：直接对接 SC2API + Bank 文件系统（Neuro 集成方案）

**代表项目**：`SC2-Neuro-API-Integration` 和 `SC2-Neuro-WoL-Integration`

这个方案更复杂但更灵活，它使用**双通道通信**：

1. **SC2API WebSocket**（protobuf）- 用于启动游戏、发送 Ping、获取原始观测数据
2. **Bank 文件系统**（XML）- 用于游戏内触发器和外部 Python 程序之间的双向数据交换

### 通道 1：SC2API WebSocket 连接

#### 启动游戏监听

见 `sc2api_connection_handler.py:32-50`，通过 `SC2Switcher_x64.exe` 启动带 API 监听的 SC2：

```python
exe_path = game_root / "Support64" / "SC2Switcher_x64.exe"
self.integration.sc2api_process = subprocess.Popen(
    [str(exe_path), *self.integration.sc2api_launch_arg_ip, *self.integration.sc2api_launch_arg_port],
    cwd=str(exe_path.parent),
)
# 参数: -listen 127.0.0.1 -port 5000
```

#### WebSocket 连接

见 `sc2api_connection_handler.py:52-102`：

```python
ws_url = f"ws://{ip}:{port}/sc2api"
# TCP 预检 → WebSocket 连接 → 重试机制
self.integration.sc2api_ws = await self.integration.sc2api_session.ws_connect(ws_url)
```

连接流程包含：
- 5 秒等待 SC2 启动
- TCP 端口预检（`_tcp_port_check`）
- 3 次重试的 WebSocket 连接
- 10 秒超时保护

#### 协议通信

见 `protocol.py:37-136`，使用 `s2clientprotocol`（Blizzard 官方 protobuf 定义）：

```python
# 发送请求
await self._integration.sc2api_ws.send_bytes(request.SerializeToString())
# 接收响应
response_bytes = await self._integration.sc2api_ws.receive_bytes()
response.ParseFromString(response_bytes)
```

#### 可用的请求类型

`_execute` 方法的重载（见 `protocol.py:76-119`）：

| 请求类型 | 用途 |
|---------|------|
| `RequestPing` | 连接测试 |
| `RequestCreateGame` / `RequestJoinGame` | 创建/加入游戏 |
| `RequestObservation` | **获取游戏观测数据**（单位、地图、事件） |
| `RequestAction` | **发送动作指令** |
| `RequestGameInfo` | 获取游戏信息 |
| `RequestStep` | 推进游戏帧 |
| `RequestData` | 获取静态数据（单位/技能/升级定义） |
| `RequestQuery` | 查询（路径、放置位置、能力可用性） |
| `RequestSaveReplay` / `RequestQuit` | 保存回放/退出 |
| `RequestQuickSave` / `RequestQuickLoad` | 快速存档/读档 |
| `RequestRestartGame` / `RequestLeaveGame` | 重启/离开游戏 |
| `RequestObserverAction` | 观察者动作 |
| `RequestMapCommand` / `RequestReplayInfo` / `RequestAvailableMaps` / `RequestSaveMap` | 地图相关 |
| `RequestDebug` | 调试命令 |

#### 原始观测数据结构

来自 `s2clientprotocol/raw_pb2.py`，`ObservationRaw` 包含：

- `player` - 玩家原始数据
  - `power_sources` - 电源范围（Protoss 水晶塔供电区域）
  - `camera` - 摄像机位置
  - `upgrade_ids` - 已研发的升级列表
- `units` - **所有单位列表**，每个 `Unit` 含：
  - `display_type` - 显示类型（Visible/Snapshot/Hidden/Placeholder）
  - `alliance` - 阵营（Self/Ally/Neutral/Enemy）
  - `tag` - 单位唯一标识
  - `unit_type` - 单位类型 ID
  - `owner` - 所有者
  - `pos` - 位置（3D）
  - `facing` - 朝向
  - `radius` - 半径
  - `build_progress` - 建造进度（0-1）
  - `cloak` - 隐身状态
  - `buff_ids` - Buff 列表
  - `detect_range` / `radar_range` - 探测/雷达范围
  - `is_selected` / `is_on_screen` / `is_blip` / `is_powered` / `is_active` - 状态标志
  - `attack_upgrade_level` / `armor_upgrade_level` / `shield_upgrade_level` - 升级等级
  - `health` / `health_max` - 生命值
  - `shield` / `shield_max` - 护盾
  - `energy` / `energy_max` - 能量
  - `mineral_contents` / `vespene_contents` - 矿/气含量（资源点）
  - `is_flying` / `is_burrowed` / `is_hallucination` - 状态标志
  - `orders` - 当前指令列表（含 ability_id、目标位置/单位、进度）
  - `add_on_tag` - 附件 tag
  - `passengers` - 乘客列表（运输单位）
  - `cargo_space_taken` / `cargo_space_max` - 货舱空间
  - `assigned_harvesters` / `ideal_harvesters` - 分配/理想农民数
  - `weapon_cooldown` - 武器冷却
  - `engaged_target_tag` - 交战目标
  - `buff_duration_remain` / `buff_duration_max` - Buff 持续时间
  - `rally_targets` - 集结点列表
- `map_state` - 地图状态
  - `visibility` - 可见性图像（ImageData）
  - `creep` - 菌毯图像（ImageData）
- `event` - 事件
  - `dead_units` - 死亡单位 tag 列表
- `effects` - 当前效果（技能效果区域）
- `radar` - 雷达环列表

#### 动作执行结构

`ActionRaw` 包含三种动作类型：

- `unit_command` - 单位指令
  - `ability_id` - 能力 ID
  - `target_world_space_pos` - 目标位置（Point2D）
  - `target_unit_tag` - 目标单位 tag
  - `unit_tags` - 执行指令的单位 tag 列表
  - `queue_command` - 是否排队执行
- `camera_move` - 摄像机移动
  - `center_world_space` - 中心位置（Point）
- `toggle_autocast` - 切换自动施法
  - `ability_id` - 能力 ID
  - `unit_tags` - 单位 tag 列表

#### 关键限制

README 中提到（`README.md:50-51`）：

> "You can then currently only send Ping messages to the game. This method of communicating with the game turned out to be a dead end for creating a custom campaign but maybe interesting for letting Neuro play the game herself"

即 SC2API 方式在**战役/自定义地图**场景下功能受限（无法完全控制），所以项目主要依赖 Bank 文件系统。

### 通道 2：Bank 文件系统（实际使用的主通道）

这是该项目的**核心创新**，通过 SC2 的 Bank 文件（XML 格式持久化存储）实现 Python 与游戏内触发器的双向通信。

#### Bank 文件位置

```
C:\Users\22448\Documents\StarCraft II\Banks\NeuroIntegration.SC2Bank
```

配置见 `configure.json`：

```json
{
  "verbosity": 1,
  "banks_path": "C:\\Users\\22448\\Documents\\StarCraft II\\Banks",
  "game_path": "E:\\SC2\\SC2new\\StarCraft II",
  "neuro_url": "ws://127.0.0.1:8000"
}
```

#### 数据结构（XML）

```xml
<Bank>
  <Section name="game_state">
    <Key name="in_mission"><Value int="1"/></Key>
    <Key name="active"><Value int="12345"/></Key>       <!-- 变化值，用于检测游戏是否运行 -->
    <Key name="is_blocking"><Value flag="1"/></Key>      <!-- 是否在过场动画 -->
    <Key name="clear_queue"><Value flag="0"/></Key>
  </Section>
  <Section name="game_context">
    <Key name="units_new"><Value flag="1"/></Key>         <!-- 有新上下文 -->
    <Key name="units"><Value string="..."/></Key>         <!-- 单位信息文本 -->
  </Section>
  <Section name="possible_actions">
    <Key name="attack_active"><Value flag="1"/></Key>
    <Key name="attack_uses"><Value int="99"/></Key>
    <Key name="attack_description"><Value string="Attack enemy"/></Key>
    <Key name="attack_arg_0"><Value string="integer(1,10)"/></Key>  <!-- 参数 schema -->
  </Section>
  <Section name="force_action">
    <Key name="group1_query"><Value string="Choose an action"/></Key>
    <Key name="group1_actions"><Value string="attack,retreat"/></Key>
    <Key name="group1_priority"><Value string="low"/></Key>
  </Section>
  <Section name="do_action">
    <Key name="attack"><Value flag="1"/></Key>            <!-- Python 写入，触发游戏执行 -->
    <Key name="attack_arg_0"><Value int="3"/></Key>
  </Section>
</Bank>
```

#### 支持的值类型

来自 `bank_file_io.py:67-91`：

| 类型 | XML 属性 | Python 类型 |
|------|---------|------------|
| 布尔 | `flag="1"` / `flag="0"` | bool |
| 整数 | `int="123"` | int |
| 定点数 | `fixed="1.5"` | float |
| 字符串 | `string="text"` | str |
| 文本 | `text="..."` | str |

#### 通信流程

```
游戏内触发器(Galaxy)                 Python 程序
        │                                │
        │  1. 写入 game_state/context     │
        │  ─────────────────────────────> │
        │  (bank 文件变更)                 │
        │                                │
        │                                │  2. watchdog 监测文件变更
        │                                │  3. parse_bank_file() 解析
        │                                │  4. 发送到 Neuro(LLM) WebSocket
        │                                │  5. LLM 决策返回动作
        │                                │
        │                                │  6. write_bank_values() 写入 do_action
        │  <───────────────────────────── │
        │  7. 游戏触发器读取 do_action      │
        │  8. 执行动作                     │
        │  9. 清除 do_action flags         │
        │                                │
```

#### Python 端核心逻辑

见 `neuro_integration_runtime.py`：

##### 1. 文件监听

使用 `watchdog` 库监听 Bank 文件变更（`neuro_integration_runtime.py:352-410`）：

```python
handler = BankFileEventHandler(self, self._bank_file_path.name)
observer = Observer()
observer.schedule(handler, str(Path(self.banks_path)), recursive=False)
observer.start()
```

`BankFileEventHandler`（`bank_file_io.py:16-41`）监听 `on_modified`、`on_created`、`on_moved` 事件，过滤目标文件名后通知集成层。

为避免遗漏事件，还有**合成事件机制**：如果 0.25 秒内没有自然文件变更事件，会主动将文件路径放入队列触发一次解析（`neuro_integration_runtime.py:364-392`）。

##### 2. 文件解析

XML 解析见 `bank_file_io.py:44-91`：

```python
def parse_bank_file(bank_file: Path) -> dict[str, dict[str, Any]]:
    tree = ET.parse(bank_file)
    root = tree.getroot()
    parsed: dict[str, dict[str, Any]] = {}
    for section in root.findall("Section"):
        section_name = section.get("name")
        section_dict: dict[str, Any] = {}
        for key in section.findall("Key"):
            key_name = key.get("name")
            value_node = key.find("Value")
            section_dict[key_name] = parse_bank_value(value_node)
        parsed[section_name] = section_dict
    return parsed
```

##### 3. 上下文同步

解析 `game_context` section，将带 `_new` 后缀的键视为新上下文，发送给 LLM（`neuro_integration_runtime.py:603-636`）：

```python
for key, value in game_context.items():
    if key.endswith("_new") and value:
        base = key[:-4]
        contexts.append(game_context.get(base, base))
        if not game_context.get(f"{base}_silent"):
            silent = False
```

##### 4. 动作注册

解析 `possible_actions` section，动态注册可用动作（含 schema 验证）（`neuro_integration_runtime.py:638-805`）：

- `<action_name>_active` - 是否激活
- `<action_name>_uses` - 剩余使用次数
- `<action_name>_description` - 描述
- `<action_name>_arg_<N>` - 第 N 个参数的类型 schema

支持的参数类型 schema：
- `string` / `str` / `text` - 字符串
- `int` / `integer` - 整数
- `float` / `fixed` / `number` / `decimal` / `real` - 浮点数
- `bool` / `boolean` / `flag` - 布尔
- `integer(1,10)` - 范围整数
- `float(0.0,1.0)` - 范围浮点
- `string(a,b,c)` - 枚举字符串
- `string/pattern=regex` - 正则匹配字符串

##### 5. 动作执行

LLM 返回动作后，写入 `do_action` section 触发游戏执行（`neuro_integration_runtime.py:1275-1336`）：

```python
updates: dict[str, dict[str, Any]] = {"do_action": {action_name: True}}
if isinstance(action_args, dict):
    for argument_name, argument_value in action_args.items():
        updates["do_action"][f"{action_name}_{argument_name}"] = argument_value
# 同时更新剩余使用次数
if current_uses > 0:
    next_uses = current_uses - 1
    possible_actions_updates[f"{action_name}_uses"] = next_uses
    if next_uses == 0:
        possible_actions_updates[f"{action_name}_active"] = False
await self._run_serialised_bank_write(lambda: write_bank_values(self._bank_file_path, updates))
```

##### 6. 游戏状态监测

- **暂停检测**：通过 `game_state.active` 值变化判断游戏是否暂停（`neuro_integration_runtime.py:1377-1428`）。如果 active 值 2.5 秒内未变化，判定为暂停。
- **进程监测**：通过 `psutil` 监测 SC2 进程是否存活（`neuro_integration_runtime.py:1338-1375`）。如果 SC2 退出，清理 Bank 文件。
- **备份 Bank 管理**：游戏保存时会创建备份 Bank 文件，Python 端监控并重命名以确保唯一 ID（`neuro_integration_runtime.py:266-350`）。

##### 7. 动作队列

支持动作排队执行（`neuro_integration_runtime.py:1213-1265`）：
- 队列最大长度 3，满时移除最旧的动作并通知 LLM
- 仅在游戏 active 值变化后的 0.3 秒窗口内执行动作（确保游戏正在处理）
- 动作执行后阻塞 1 秒防止过载

##### 8. 写入安全

- 使用 `asyncio.Lock` 序列化所有 Bank 写入（`neuro_integration_runtime.py:1430-1436`）
- 原子替换写入（`bank_file_io.py:95+`），先写临时文件再重命名
- 写入窗口限制：仅在 active 值变化后 0.3 秒内允许写入

#### 游戏端（Galaxy 触发器）

需要 Mod 和地图配合，通过触发器：
- 定期将游戏状态写入 Bank 文件
- 监听 `do_action` section 变化并执行对应动作

Mod 文件位于 `Mod/NeuroIntegration.SC2Mod/`，包含：
- `LibEFA54406.galaxy` / `LibEFA54406_h.galaxy` - 触发器库
- `integration.galaxy` - 集成辅助函数
- `GameData/GameData.xml` - 游戏数据定义

---

## 两种方案对比

| 特性 | python-sc2 (burnysc2) | SC2API + Bank 文件 |
|------|----------------------|-------------------|
| **复杂度** | 低，封装完善 | 高，需自定义协议 |
| **数据获取** | 直接访问 `self.units` 等 | 游戏触发器写入 Bank，Python 解析 |
| **动作执行** | 直接调用 API | 写入 Bank，触发器读取执行 |
| **适用场景** | AI vs AI 对战 | 对接已有游戏（战役/自定义地图） |
| **游戏控制** | 完全控制（启动/结束） | 有限控制，依赖触发器设计 |
| **实时性** | 高（每帧回调） | 中（文件 IO + watchdog） |
| **数据粒度** | 完整原始数据 | 由触发器决定，可自定义 |
| **依赖** | burnysc2 库 | s2clientprotocol + watchdog + 自定义 Mod |
| **协议** | protobuf over WebSocket | XML 文件 + WebSocket（Neuro 通信） |
| **延迟** | 毫秒级 | ~100ms（文件 IO） |
| **并发** | 单线程异步 | 多任务（监听器、队列、看门狗） |

---

## 对合作指挥官-起义狂潮项目的建议

根据不同的应用场景，可以选择不同的方案：

### 场景 1：调试/诊断

**推荐方案**：Bank 文件方案

理由：
- 你已经有大量 Galaxy 触发器经验
- 项目中已有 `EmptyTestDiag.SC2Bank` 诊断机制（见 project_memory）
- 可以在触发器中写入需要的数据，Python 端读取分析
- 无需改变游戏核心逻辑

### 场景 2：AI 对战测试

**推荐方案**：python-sc2 方案

理由：
- 封装完善，开发效率高
- 适合标准对战模式
- 需要将合作指挥官 Mod 适配为标准对战模式

### 场景 3：对接 LLM

**推荐方案**：Neuro Integration 的 Bank 方案

理由：
- 最灵活，不改变游戏核心逻辑
- 通过触发器向 LLM 报告状态并接收指令
- 支持动作注册和 schema 验证
- 已有完整的开源实现可参考

### 场景 4：实时数据监控

**推荐方案**：SC2API WebSocket + RequestObservation

理由：
- 可获取完整的单位/地图/事件数据
- 不需要修改游戏触发器
- 适合外部数据分析和可视化

---

## 关键文件索引

### Large-Language-Models-play-StarCraftII

| 文件 | 说明 |
|------|------|
| `sc2_rl_agent/starcraftenv_test/env/bot/Protoss_bot.py` | Protoss Bot 实现，包含数据采集和动作执行 |
| `sc2_rl_agent/starcraftenv_test/env/single_agent.py` | Gym 环境封装，多进程通信 |
| `sc2_rl_agent/starcraftenv_test/env/starcraft_env.py` | 环境选择器 |
| `sc2_rl_agent/starcraftenv_test/utils/action_info.py` | 动作描述定义 |
| `sc2_rl_agent/starcraftenv_test/summarize/L1_summarize.py` | L1 帧总结方法 |
| `sc2_rl_agent/starcraftenv_test/summarize/gpt_test/L2_summarize.py` | L2 多帧总结方法 |

### SC2-Neuro-API-Integration

| 文件 | 说明 |
|------|------|
| `SC2_integration.py` | 主入口，Tkinter 终端 UI |
| `sc2api_connection_handler.py` | SC2API WebSocket 连接管理 |
| `protocol.py` | protobuf 协议封装 |
| `neuro_integration_runtime.py` | 核心运行时，Bank 文件监听和动作执行 |
| `bank_file_io.py` | Bank 文件 XML 解析和写入 |
| `message_builder.py` | Neuro API 消息构建器 |
| `data.py` | 枚举定义（Status/Race/AbilityId 等） |
| `ids/ability_id.py` | 能力 ID 枚举 |
| `ids/unit_typeid.py` | 单位类型 ID 枚举 |
| `s2clientprotocol/` | Blizzard 官方 protobuf 定义 |
| `Mod/NeuroIntegration.SC2Mod/` | 游戏 Mod（Galaxy 触发器） |
| `Maps/traynor01.SC2Map/` | 示例地图 |
| `configure.json` | 配置文件 |
| `mock_neuro_server.py` / `mock_neuro_server_enhanced.py` | Mock Neuro 服务器（测试用） |
| `headless_runner.py` | 无头运行器 |

### SC2-Neuro-WoL-Integration

| 文件 | 说明 |
|------|------|
| `Mods/NeuroIntegration.SC2Mod/` | 游戏 Mod（与 API-Integration 相同） |
| `Maps/Campaign/` | Wings of Liberty 战役地图集合（29 张地图） |

---

## 附录：SC2API 启动参数

启动 SC2 监听 API 的命令：

```powershell
SC2Switcher_x64.exe -listen 127.0.0.1 -port 5000
```

或直接使用 SC2_x64.exe：

```powershell
SC2_x64.exe -listen 127.0.0.1 -port 5000
```

连接 URL：`ws://127.0.0.1:5000/sc2api`

---

## 附录：Neuro API 消息类型

Neuro Integration 使用 WebSocket 与 LLM 通信，消息类型包括：

- `startup` - 启动握手，包含 session/characterId/displayName
- `context` - 上下文消息，向 LLM 提供游戏状态信息
- `actions/register` - 注册可用动作
- `actions/unregister` - 注销动作
- `actions/force` - 强制 LLM 从指定动作中选择
- `action` - LLM 返回的动作指令
- `actions/reregister_all` - 重新注册所有动作
- `action_result` - 动作执行结果反馈

---

*文档生成时间：2026-07-12*
*基于项目源码分析*
