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

# 副官可执行的动作注册列表
ADVISOR_ACTIONS = [
    {
        "name": "report_status",
        "description": "Report current game status (resources, supply, units, upgrades) in Chinese.",
    },
    {
        "name": "report_units",
        "description": "Report all unit types and their counts in Chinese.",
    },
    {
        "name": "report_upgrades",
        "description": "Report all researched upgrades in Chinese.",
    },
    {
        "name": "report_producers",
        "description": "Report all production buildings and their counts in Chinese.",
    },
    {
        "name": "suggest_build_order",
        "description": "Suggest next build order based on current state in Chinese.",
    },
    {
        "name": "alert_supply_cap",
        "description": "Alert when supply is near cap (within 3 of max) in Chinese.",
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


class NeuroBridge:
    """Neuro 桥接器：监听 RuntimeProbe Bank，转发 context 给 Neuro。"""

    def __init__(
        self,
        banks_path: str = DEFAULT_BANKS_PATH,
        neuro_url: str = DEFAULT_NEURO_URL,
        context_interval: float = 10.0,
    ) -> None:
        self.banks_path = Path(banks_path)
        self.probe_bank_path = self.banks_path / PROBE_BANK_NAME
        self.neuro_bank_path = self.banks_path / NEURO_BANK_NAME
        self.neuro_url = neuro_url
        self.context_interval = context_interval
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

        self._running = True
        self.session = aiohttp.ClientSession()

        # 启动两个并发任务
        await asyncio.gather(
            self._neuro_ws_loop(),
            self._probe_watcher_loop(),
        )

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
        """处理 Neuro 发来的消息（action 执行结果或 force 请求）。"""
        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
            print(f"[NeuroBridge] Invalid JSON from Neuro: {raw[:100]}")
            return

        command = msg.get("command", "")
        data = msg.get("data", {})

        if command == "action":
            action_name = data.get("name", "")
            action_result = data.get("data", {}).get("result", "")
            print(f"[NeuroBridge] Neuro executed action: {action_name}")
            print(f"[NeuroBridge] Action result: {action_result[:200]}")

            # 把副官回复写入 NeuroIntegration Bank，让游戏显示为聊天消息
            if action_result:
                await self._write_chat_to_neuro_bank(action_result)
        elif command == "actions/force":
            query = data.get("query", "")
            state = data.get("state", "")
            print(f"[NeuroBridge] Neuro force query: {query}")
            # 在 force 期间持续提供 context
        else:
            print(f"[NeuroBridge] Neuro message: {command}")

    async def _write_chat_to_neuro_bank(self, message: str) -> None:
        """把副官回复写入 NeuroIntegration.SC2Bank 的 do_action section。

        游戏端触发器会读取 do_action/chat_message 并显示为字幕。
        """
        if not self.neuro_bank_path.parent.exists():
            return

        try:
            # 使用 Neuro 集成项目的 write_bank_values 函数
            values = {
                "do_action": {
                    "chat_message": True,
                    "chat_message_arg_1": message,
                }
            }
            write_bank_values(self.neuro_bank_path, values, player=1)
            print(f"[NeuroBridge] Chat written to NeuroIntegration bank: {message[:80]}...")
        except Exception as exc:
            print(f"[NeuroBridge] Write chat failed: {exc}")

    async def _handle_advisor_action(self, action_name: str) -> None:
        """处理副官动作——立即发送一次最新状态 context。"""
        if not self.probe_bank_path.exists():
            return
        bank_data = parse_bank_file(self.probe_bank_path)
        context_msg = _build_context_message(bank_data)
        full_msg = self.builder.context(
            f"[副官响应: {action_name}]\n{context_msg}",
            silent=False,
        )
        if self.ws and not self.ws.closed:
            await self.ws.send_json(full_msg)
            print(f"[NeuroBridge] Sent context for action: {action_name}")

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


async def main() -> None:
    parser = argparse.ArgumentParser(description="Neuro Bridge - 副官桥接器")
    parser.add_argument("--banks-path", default=DEFAULT_BANKS_PATH, help="Banks 目录路径")
    parser.add_argument("--neuro-url", default=DEFAULT_NEURO_URL, help="Neuro WebSocket URL")
    parser.add_argument("--context-interval", type=float, default=10.0, help="context 发送间隔（秒）")
    args = parser.parse_args()

    bridge = NeuroBridge(
        banks_path=args.banks_path,
        neuro_url=args.neuro_url,
        context_interval=args.context_interval,
    )

    try:
        await bridge.start()
    except KeyboardInterrupt:
        print("\n[NeuroBridge] Interrupted")
    finally:
        await bridge.stop()


if __name__ == "__main__":
    asyncio.run(main())
