"""Neuro Bridge - 把 RuntimeProbe 状态作为 context 发送给 Neuro，注册副官动作

架构:
    RuntimeProbe.SC2Bank ← 游戏内 Galaxy 触发器写入
         ↓ (Python 监听 mtime)
    neuro_bridge.py
         ↓ (WebSocket)
    Neuro (LLM) ← 接收 context + action 注册
         ↓ (返回动作)
    neuro_bridge.py → NeuroIntegration.SC2Bank (写入动作) → 游戏执行

本模块独立运行，不修改 SC2-Neuro-API-Integration 的代码。
NeuroIntegration.SC2Bank 的动作执行由游戏端触发器读取 Bank 并执行。

用法:
    python neuro_bridge.py --banks-path "C:\\Users\\22448\\Documents\\StarCraft II\\Banks" --neuro-url "ws://127.0.0.1:41840"

    或作为模块导入:
        from neuro_bridge import NeuroBridge
        bridge = NeuroBridge(banks_path, neuro_url)
        await bridge.start()
"""

from __future__ import annotations

import argparse
import asyncio
import json
import time
from datetime import datetime
from pathlib import Path
from typing import Any

import aiohttp

# 引用 Neuro 集成的 message_builder
_NEURO_ROOT = Path(r"e:\Code\MyMod\SC2\tools\SC2-Neuro-API-Integration")
import sys
if str(_NEURO_ROOT) not in sys.path:
    sys.path.insert(0, str(_NEURO_ROOT))

from message_builder import NeuroAPIMessageBuilder
from bank_file_io import parse_bank_file, write_bank_values

DEFAULT_BANKS_PATH = r"C:\Users\22448\Documents\StarCraft II\Banks"
DEFAULT_NEURO_URL = "ws://127.0.0.1:41840"
PROBE_BANK_NAME = "RuntimeProbe.SC2Bank"
NEURO_BANK_NAME = "NeuroIntegration.SC2Bank"

# 与 Galaxy 侧 LibNeuroBridge7vs1.galaxy RegisterActions 完全一致的 12 个 action
# Neuro 通过 WebSocket 调用时，Python 转发到 NeuroIntegration Bank 的 do_action section
# Galaxy 在 ExecuteActionsMap tick 读取 flag + arg，执行后通过 libEFA54406_gf_create_context 推回结果
#
# 额外包含 LibEFA54406 默认 action（chat_message/your_units 等）以便 Neuro 能调用这些基础能力
ADVISOR_ACTIONS = [
    # === LibEFA54406 默认 action（Galaxy 端已注册，Neuro 也可调用）===
    {
        "name": "chat_message",
        "description": "Post a message into the game chat. Pass args.data.arg_1 = message text.",
    },
    # === 只读查询型 ===
    {
        "name": "get_mutators",
        "description": "Query current resources, supply and active mutators in this 7vs1 mission.",
    },
    {
        "name": "get_commander_status",
        "description": "Query commander status: total units, structures and army count.",
    },
    {
        "name": "get_production_queue",
        "description": "Query current production queue of all buildings.",
    },
    {
        "name": "get_active_mutators",
        "description": "Query active mutators with semantic descriptions explaining their gameplay impact.",
    },
    # === 写入型：原有生产/技能/升级 ===
    {
        "name": "train_unit",
        "description": "Order production of a unit. Pass args.data.arg_1 = unit type id, e.g. 'Marine', 'Marauder', 'SiegeTank', 'Medivac', 'Viking'.",
    },
    {
        "name": "use_ability",
        "description": "Order a unit to use an ability. Pass args.data.arg_1 = ability id (e.g. 'Stimpack', 'YamatoCannon', 'SiegeMode'), args.data.arg_2 = target unit type (optional).",
    },
    {
        "name": "research_upgrade",
        "description": "Order research of an upgrade. Pass args.data.arg_1 = upgrade id, e.g. 'TerranInfantryWeaponsLevel1'.",
    },
    # === 写入型：精确单位控制（基于目标单位类型定位）===
    {
        "name": "attack_unit",
        "description": "Order currently selected player units to attack the nearest enemy unit of the given type. Pass args.data.arg_1 = target unit type id, e.g. 'Marine', 'Zergling', 'Hydralisk'.",
    },
    {
        "name": "focus_fire",
        "description": "Order ALL player army units to attack the nearest enemy unit of the given type. Pass args.data.arg_1 = target unit type id, e.g. 'Baneling', 'Ultralisk'.",
    },
    {
        "name": "set_rally",
        "description": "Set rally point of all buildings matching arg_1 to the nearest unit of type arg_2 (any owner). Pass args.data.arg_1 = building type (e.g. 'Barracks'), args.data.arg_2 = target unit type (e.g. 'CommandCenter').",
    },
    {
        "name": "move_to_unit",
        "description": "Order all player units of type arg_1 to move to the nearest unit of type arg_2 (any owner). Pass args.data.arg_1 = source unit type (e.g. 'Marine'), args.data.arg_2 = target unit type (e.g. 'SCV').",
    },
    {
        "name": "move_selected_to_unit",
        "description": "Order the currently selected player units to move to the nearest unit of type arg_1. Pass args.data.arg_1 = target unit type (e.g. 'CommandCenter', 'SCV', 'Marine').",
    },
]


def _build_context_message(bank_data: dict[str, dict[str, Any]]) -> str:
    """把 RuntimeProbe Bank 数据转成中文 context 消息（给 Neuro 的副官 prompt）。"""
    state = bank_data.get("probe_state", {})
    units = bank_data.get("probe_units", {})
    upgrades = bank_data.get("probe_upgrades", {})
    producers = bank_data.get("probe_producers", {})

    hb = state.get("heartbeat", 0)
    minerals = state.get("minerals", 0)
    gas = state.get("gas", 0)
    supply_used = state.get("supply_used", 0)
    supply_cap = state.get("supply_cap", 0)
    game_time = state.get("game_time", 0)

    # 单位摘要
    unit_lines = []
    for key, val in units.items():
        # key 格式: u_1_<UnitType>, val 格式: count:N,life_avg:X,...
        unit_type = key.split("_", 2)[-1] if "_" in key else key
        count = 0
        if isinstance(val, str):
            for part in val.split(","):
                if part.startswith("count:"):
                    count = int(part.split(":", 1)[1])
                    break
        unit_lines.append(f"  {unit_type} x{count}")

    # 升级摘要
    upgrade_names = []
    for key, _ in upgrades.items():
        # key 格式: up_1_<UpgradeId>
        name = key.split("_", 2)[-1] if "_" in key else key
        upgrade_names.append(name)

    # 生产建筑摘要
    producer_lines = []
    for key, val in producers.items():
        prod_type = key.split("_", 2)[-1] if "_" in key else key
        count = 0
        if isinstance(val, str):
            for part in val.split(","):
                if part.startswith("producer_count:"):
                    count = int(part.split(":", 1)[1])
                    break
        producer_lines.append(f"  {prod_type} x{count}")

    msg = (
        f"[副官状态报告]\n"
        f"时间: {game_time}s | 心跳: {hb}\n"
        f"资源: 矿物 {minerals} / 高产瓦斯 {gas}\n"
        f"供应: {supply_used}/{supply_cap}\n"
        f"\n[单位列表] ({len(unit_lines)} 种)\n"
        + "\n".join(unit_lines[:20])
        + (f"\n... 共 {len(unit_lines)} 种" if len(unit_lines) > 20 else "")
        + f"\n\n[已研究升级] ({len(upgrade_names)} 个)\n"
        + ", ".join(upgrade_names[:30])
        + (f"\n... 共 {len(upgrade_names)} 个" if len(upgrade_names) > 30 else "")
        + f"\n\n[生产建筑] ({len(producer_lines)} 种)\n"
        + "\n".join(producer_lines[:10])
    )
    return msg


import re


class ChatCommandParser:
    """自然语言指令解析（轻量级关键词匹配 + 简单 NLU 调度）。

    支持的中文/英文指令模式：
      - "造 5 个 Marines" / "训练 Marine" / "train Marine" → train_unit(arg_1=Marine)
      - "攻击 Zergling" / "attack Zergling"                  → attack_unit(arg_1=Zergling)
      - "集火 Baneling" / "focus Baneling"                   → focus_fire(arg_1=Baneling)
      - "集结点设在 CommandCenter 附近" / "rally Barracks CommandCenter"
                                                            → set_rally(arg_1=Barracks, arg_2=CommandCenter)
      - "让 Marine 移动到 SCV 旁边" / "move Marine SCV"     → move_to_unit(arg_1=Marine, arg_2=SCV)
      - "研究 Stimpack" / "research TerranInfantryWeaponsLevel1"
                                                            → research_upgrade(arg_1=...)
      - "使用 Stimpack" / "use Stimpack"                    → use_ability(arg_1=Stimpack)

    解析失败时返回 None，调用方可选择把原始消息作为 context 发给 Neuro。
    """

    # 关键词 → (action_name, arg_count)
    _KEYWORD_MAP = [
        # (中文/英文关键词列表, action_name, arg_count)
        (("造", "训练", "生产", "train", "build"), "train_unit", 1),
        (("攻击", "attack", "打"), "attack_unit", 1),
        (("集火", "focus", "focus_fire"), "focus_fire", 1),
        (("集结", "rally", "集结点"), "set_rally", 2),
        (("移动", "move", "去"), "move_to_unit", 2),
        (("研究", "research"), "research_upgrade", 1),
        (("使用", "use", "施放"), "use_ability", 1),
        (("查", "查询", "状态", "status"), "get_commander_status", 0),
        (("变数", "突变", "mutator"), "get_mutators", 0),
        (("生产队列", "queue"), "get_production_queue", 0),
    ]

    # 单位类型白名单（实际验证用 CatalogEntryIsValid 在 Galaxy 端做，这里仅做粗过滤）
    _UNIT_ID_PATTERN = re.compile(r"\b([A-Z][a-zA-Z0-9_]{2,})\b")

    @classmethod
    def parse(cls, text: str) -> tuple[str, dict[str, str]] | None:
        """从文本中解析出 (action_name, args)。

        返回 None 表示无法识别。
        """
        if not text:
            return None
        lowered = text.strip()

        # 提取所有疑似单位 ID 的大写开头 token
        unit_tokens = cls._UNIT_ID_PATTERN.findall(lowered)

        for keywords, action_name, arg_count in cls._KEYWORD_MAP:
            for kw in keywords:
                if kw.lower() in lowered.lower():
                    # 命中关键词，尝试提取参数
                    if arg_count == 0:
                        return (action_name, {})
                    if action_name == "move_to_unit" and arg_count == 2 and len(unit_tokens) == 1:
                        return ("move_selected_to_unit", {"arg_1": unit_tokens[0]})
                    if len(unit_tokens) < arg_count:
                        # 单位 token 不够，跳过这个匹配尝试下一个
                        continue
                    args: dict[str, str] = {}
                    for i in range(arg_count):
                        args[f"arg_{i+1}"] = unit_tokens[i]
                    return (action_name, args)

        return None


class NeuroBridge:
    """Neuro 桥接器：监听 RuntimeProbe Bank，转发 context 给 Neuro。"""

    def __init__(
        self,
        banks_path: str = DEFAULT_BANKS_PATH,
        neuro_url: str = DEFAULT_NEURO_URL,
        context_interval: float = 10.0,
        enable_chat_parser: bool = False,
    ) -> None:
        self.banks_path = Path(banks_path)
        self.probe_bank_path = self.banks_path / PROBE_BANK_NAME
        self.neuro_bank_path = self.banks_path / NEURO_BANK_NAME
        self.neuro_url = neuro_url
        self.context_interval = context_interval
        self.enable_chat_parser = enable_chat_parser
        self.builder = NeuroAPIMessageBuilder(game_title="StarCraft 2")

        self.session: aiohttp.ClientSession | None = None
        self.ws: aiohttp.ClientWebSocketResponse | None = None
        self._running = False
        self._registered = False
        self._last_probe_mtime: float = 0
        self._last_context_time: float = 0

    async def start(self) -> None:
        print(f"[NeuroBridge] Starting...")
        print(f"[NeuroBridge] Probe bank: {self.probe_bank_path}")
        print(f"[NeuroBridge] Neuro URL: {self.neuro_url}")
        print(f"[NeuroBridge] Context interval: {self.context_interval}s")
        print(f"[NeuroBridge] Chat parser: {'enabled' if self.enable_chat_parser else 'disabled'}")

        self._running = True
        self.session = aiohttp.ClientSession()

        tasks = [
            self._neuro_ws_loop(),
            self._probe_watcher_loop(),
        ]
        if self.enable_chat_parser:
            tasks.append(self._chat_parser_loop())

        # 启动并发任务
        await asyncio.gather(*tasks)

    async def stop(self) -> None:
        self._running = False
        if self.ws and not self.ws.closed:
            await self.ws.close()
        if self.session and not self.session.closed:
            await self.session.close()
        print("[NeuroBridge] Stopped")

    async def _neuro_ws_loop(self) -> None:
        """Neuro WebSocket 连接循环（含自动重连）。"""
        while self._running:
            try:
                print(f"[NeuroBridge] Connecting to {self.neuro_url} ...")
                self.ws = await self.session.ws_connect(self.neuro_url)
                print("[NeuroBridge] WebSocket connected")

                # 发送 startup
                startup_msg = self.builder.startup()
                await self.ws.send_json(startup_msg)
                print(f"[NeuroBridge] Sent startup: {startup_msg}")

                # 注册副官动作
                if not self._registered:
                    register_msg = self.builder.actions_register(ADVISOR_ACTIONS)
                    await self.ws.send_json(register_msg)
                    self._registered = True
                    print(f"[NeuroBridge] Registered {len(ADVISOR_ACTIONS)} actions")

                # 接收 Neuro 消息循环
                async for msg in self.ws:
                    if msg.type == aiohttp.WSMsgType.TEXT:
                        await self._handle_neuro_message(msg.data)
                    elif msg.type == aiohttp.WSMsgType.ERROR:
                        print(f"[NeuroBridge] WS error: {self.ws.exception()}")
                        break

                print("[NeuroBridge] WebSocket closed, reconnecting in 5s...")
            except (asyncio.TimeoutError, aiohttp.ClientError, ConnectionError) as exc:
                print(f"[NeuroBridge] Connection failed: {exc}, retrying in 5s...")
            except asyncio.CancelledError:
                break

            if self._running:
                await asyncio.sleep(5)

    async def _handle_neuro_message(self, raw: str) -> None:
        """处理 Neuro 发来的消息（action 调用 / action result / force 请求）。"""
        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
            print(f"[NeuroBridge] Invalid JSON from Neuro: {raw[:100]}")
            return

        command = msg.get("command", "")
        data = msg.get("data", {})

        if command == "action":
            # Neuro 请求执行一个 action，转发到 NeuroIntegration Bank 让 Galaxy 在下一 tick 执行
            action_id = data.get("id", "")
            action_name = data.get("name", "")
            action_args = data.get("data", {}) or {}
            print(f"[NeuroBridge] Neuro requests action: {action_name} (id={action_id}) args={action_args}")

            ok = await self._forward_action_to_bank(action_name, action_args)
            # 立即回复 action/result（Galaxy 执行结果会通过 context 推回）
            result_msg = self.builder.action_result(
                action_id=action_id,
                success=ok,
                message=("Forwarded to galaxy bank" if ok else "Unknown action or bank write failed"),
            )
            if self.ws and not self.ws.closed:
                await self.ws.send_json(result_msg)
        elif command == "actions/force":
            query = data.get("query", "")
            state = data.get("state", "")
            print(f"[NeuroBridge] Neuro force query: {query}")
            # 在 force 期间持续提供 context（_probe_watcher_loop 会自动定期发送）
        elif command == "context":
            # Neuro 主动发的上下文/对话，可以记录或显示给玩家
            text = data.get("message", "")
            if text:
                print(f"[Neuro] Neuro says: {text[:200]}")
                await self._write_chat_to_neuro_bank(text)
        else:
            print(f"[NeuroBridge] Neuro message: {command}")

    async def _forward_action_to_bank(self, action_name: str, args: dict[str, Any]) -> bool:
        """把 Neuro 的 action 请求转发到 NeuroIntegration Bank 的 do_action section。

        Galaxy 会在下一个 ExecuteActionsMap tick 读取 flag + arg_N，执行后通过
        libEFA54406_gf_create_context 把结果作为 context 推回，被 _probe_watcher_loop
        在下一周期发送给 Neuro。
        """
        # 只接受注册过的 action
        registered_names = {a["name"] for a in ADVISOR_ACTIONS}
        if action_name not in registered_names:
            print(f"[NeuroBridge] Rejected unknown action: {action_name}")
            return False

        if not self.neuro_bank_path.parent.exists():
            print(f"[NeuroBridge] Bank directory missing: {self.neuro_bank_path.parent}")
            return False

        # 组装 Bank 写入：do_action/<action_name>=True + do_action/<action_name>_arg_N=value
        section_values: dict[str, Any] = {action_name: True}
        for k, v in args.items():
            section_values[f"{action_name}_{k}"] = str(v)

        try:
            write_bank_values(self.neuro_bank_path, {"do_action": section_values})
            print(f"[NeuroBridge] Forwarded action '{action_name}' to bank: {section_values}")
            return True
        except Exception as exc:
            print(f"[NeuroBridge] Forward action to bank failed: {exc}")
            return False

    async def _write_chat_to_neuro_bank(self, message: str) -> None:
        """把副官回复写入 NeuroIntegration.SC2Bank 的 do_action section。

        游戏端触发器会读取 do_action/chat_message 并显示为字幕。
        """
        if not self.neuro_bank_path.parent.exists():
            return

        try:
            values = {
                "do_action": {
                    "chat_message": True,
                    "chat_message_arg_1": message,
                }
            }
            write_bank_values(self.neuro_bank_path, values)
            print(f"[NeuroBridge] Chat written to NeuroIntegration bank: {message[:80]}...")
        except Exception as exc:
            print(f"[NeuroBridge] Write chat failed: {exc}")

    async def _probe_watcher_loop(self) -> None:
        """监听 RuntimeProbe Bank 文件变化，定期发送 context。"""
        print(f"[NeuroBridge] Watching probe bank: {self.probe_bank_path}")
        poll_interval = 1.0

        while self._running:
            try:
                if self.probe_bank_path.exists():
                    mtime = self.probe_bank_path.stat().st_mtime
                    now = time.time()

                    # 两种触发条件：Bank 文件变化，或到达 context_interval
                    bank_changed = mtime != self._last_probe_mtime
                    interval_elapsed = (now - self._last_context_time) >= self.context_interval

                    if bank_changed or (interval_elapsed and self._last_probe_mtime > 0):
                        if bank_changed:
                            self._last_probe_mtime = mtime

                        if interval_elapsed or bank_changed:
                            await self._send_context()
                            self._last_context_time = now
            except Exception as exc:
                print(f"[NeuroBridge] Watcher error: {exc}")

            await asyncio.sleep(poll_interval)

    async def _send_context(self) -> None:
        """读取 Bank 并发送 context 给 Neuro。"""
        if not self.probe_bank_path.exists():
            return
        if not self.ws or self.ws.closed:
            return

        try:
            bank_data = parse_bank_file(self.probe_bank_path)
        except Exception as exc:
            print(f"[NeuroBridge] parse_bank_file failed: {exc}")
            return

        if "probe_state" not in bank_data:
            return

        context_str = _build_context_message(bank_data)
        msg = self.builder.context(context_str, silent=True)
        await self.ws.send_json(msg)
        print(f"[NeuroBridge] Context sent (HB={bank_data['probe_state'].get('heartbeat', 0)})")

    async def _chat_parser_loop(self) -> None:
        """从 stdin 读取自然语言指令，解析为 action 并转发到 NeuroIntegration Bank。

        用途：在 Neuro 未接入（mock 模式或断线）时，仍然可以通过终端
        输入中文/英文指令驱动游戏执行 action，便于端到端测试。
        """
        loop = asyncio.get_running_loop()
        print("[ChatParser] 启动聊天指令解析器（从 stdin 读取）")
        print("[ChatParser] 示例指令：")
        print("  - 造 Marine")
        print("  - 攻击 Zergling")
        print("  - 集火 Baneling")
        print("  - 研究 TerranInfantryWeaponsLevel1")
        print("  - 使用 Stimpack")
        print("  - rally Barracks CommandCenter")
        print("  - move Marine SCV")
        print("  - move SCV")
        print("  - 查状态")

        while self._running:
            try:
                line = await loop.run_in_executor(None, input, "> ")
            except EOFError:
                print("[ChatParser] stdin EOF, exiting parser loop")
                break
            except Exception as exc:
                print(f"[ChatParser] stdin read error: {exc}")
                await asyncio.sleep(1.0)
                continue

            line = (line or "").strip()
            if not line:
                continue
            if line.lower() in {"quit", "exit", "q"}:
                print("[ChatParser] 收到退出指令")
                self._running = False
                break

            parsed = ChatCommandParser.parse(line)
            if parsed is None:
                print(f"[ChatParser] 无法识别指令: {line!r}")
                print("[ChatParser] 已识别关键词：造/训练/攻击/集火/集结/移动/研究/使用/查状态/突变/生产队列")
                continue

            action_name, args = parsed
            print(f"[ChatParser] 解析为 action: {action_name} args={args}")
            ok = await self._forward_action_to_bank(action_name, args)
            if ok:
                print(f"[ChatParser] 已转发到 Galaxy bank，等待下一 tick 执行")
            else:
                print(f"[ChatParser] 转发失败")

        print("[ChatParser] 退出")


async def main() -> None:
    parser = argparse.ArgumentParser(description="Neuro Bridge - 副官桥接器")
    parser.add_argument("--banks-path", default=DEFAULT_BANKS_PATH, help="Banks 目录路径")
    parser.add_argument("--neuro-url", default=DEFAULT_NEURO_URL, help="Neuro WebSocket URL")
    parser.add_argument("--context-interval", type=float, default=10.0, help="context 发送间隔（秒）")
    parser.add_argument(
        "--enable-chat-parser",
        action="store_true",
        help="启用聊天指令解析器（从 stdin 读取中文/英文指令并转发到 Galaxy bank）",
    )
    args = parser.parse_args()

    bridge = NeuroBridge(
        banks_path=args.banks_path,
        neuro_url=args.neuro_url,
        context_interval=args.context_interval,
        enable_chat_parser=args.enable_chat_parser,
    )

    try:
        await bridge.start()
    except KeyboardInterrupt:
        print("\n[NeuroBridge] Interrupted")
    finally:
        await bridge.stop()


if __name__ == "__main__":
    asyncio.run(main())
