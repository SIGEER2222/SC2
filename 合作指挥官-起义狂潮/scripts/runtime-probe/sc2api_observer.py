"""SC2API Observer - 通过 SC2API WebSocket 获取运行时观测数据

零游戏内触发器开销的观测方案。通过 RequestObservation 直接从 SC2 进程
获取完整观测数据（单位、升级、资源、订单等），不依赖 Bank 文件。

用法:
    python sc2api_observer.py --host 127.0.0.1 --port 5000 --composition-id "airo-runtime-probe" --once

    python sc2api_observer.py --host 127.0.0.1 --port 5000 --composition-id "airo-runtime-probe" --duration 60

依赖:
    - s2clientprotocol (引用 tools/SC2-Neuro-API-Integration/s2clientprotocol)
    - ids/ (引用 tools/SC2-Neuro-API-Integration/ids)
    - aiohttp
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any

# 引用本地 s2clientprotocol 和 ids 映射（避免重复维护）
_SC2NEURO_ROOT = Path(r"e:\Code\MyMod\SC2\tools\SC2-Neuro-API-Integration")
if str(_SC2NEURO_ROOT) not in sys.path:
    sys.path.insert(0, str(_SC2NEURO_ROOT))

import aiohttp
from s2clientprotocol import sc2api_pb2 as sc_pb

# ID → 名称反查表
from ids.unit_typeid import UnitTypeId
from ids.upgrade_id import UpgradeId
from ids.ability_id import AbilityId

_UNIT_TYPE_NAMES: dict[int, str] = {member.value: member.name for member in UnitTypeId}
_UPGRADE_NAMES: dict[int, str] = {member.value: member.name for member in UpgradeId}
_ABILITY_NAMES: dict[int, str] = {member.value: member.name for member in AbilityId}

from normalize_probe import build_verification_report, report_to_markdown

DEFAULT_OUTPUT_DIR = Path(__file__).parent / "reports"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 5000


class SC2ApiObserver:
    """SC2API 观测采集器。"""

    def __init__(
        self,
        host: str = DEFAULT_HOST,
        port: int = DEFAULT_PORT,
        composition_id: str = "sc2api-observer",
        output_dir: Path | None = None,
        run_id: str | None = None,
    ) -> None:
        self.host = host
        self.port = port
        self.ws_url = f"ws://{host}:{port}/sc2api"
        self.composition_id = composition_id
        self.output_dir = output_dir or DEFAULT_OUTPUT_DIR
        self.run_id = run_id or f"run-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        self.session: aiohttp.ClientSession | None = None
        self.ws: aiohttp.ClientWebSocketResponse | None = None

        self.output_dir.mkdir(parents=True, exist_ok=True)

    async def connect(self, timeout: float = 30.0) -> None:
        """连接到 SC2 API。包含 TCP 预检和 WebSocket 握手。"""
        print(f"[SC2ApiObserver] Connecting to {self.ws_url} ...")

        # 等待 SC2 启动监听端口
        deadline = time.time() + timeout
        while time.time() < deadline:
            if await self._tcp_port_check(self.host, self.port):
                break
            print(f"[SC2ApiObserver] Port {self.port} not reachable, retrying in 3s...")
            await asyncio.sleep(3)
        else:
            raise TimeoutError(f"SC2 API port {self.port} not reachable after {timeout}s")

        # WebSocket 连接（带重试）
        self.session = aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=10))
        for attempt in range(3):
            try:
                self.ws = await self.session.ws_connect(self.ws_url)
                print("[SC2ApiObserver] WebSocket connected")
                break
            except (asyncio.TimeoutError, aiohttp.ClientError) as exc:
                print(f"[SC2ApiObserver] Connect attempt {attempt+1} failed: {exc}")
                if attempt == 2:
                    raise
                await asyncio.sleep(3)

        # Ping 测试
        await self._ping()
        print("[SC2ApiObserver] Ping OK")

    async def _tcp_port_check(self, host: str, port: int) -> bool:
        try:
            _reader, writer = await asyncio.wait_for(
                asyncio.open_connection(host, port), timeout=2.0
            )
            writer.close()
            await writer.wait_closed()
            return True
        except (asyncio.TimeoutError, OSError, ConnectionRefusedError):
            return False

    async def _send_request(self, request: sc_pb.Request) -> sc_pb.Response:
        """发送 protobuf 请求并接收响应。

        战役图模式下 SC2 可能返回文本错误消息而非二进制 protobuf，
        需要处理非二进制消息类型。
        """
        if self.ws is None or getattr(self.ws, "closed", False):
            raise ConnectionError("WebSocket not connected")

        await self.ws.send_bytes(request.SerializeToString())

        # 用 receive() 代替 receive_bytes()，可处理文本错误消息
        msg = await self.ws.receive()
        if msg.type != aiohttp.WSMsgType.BINARY:
            # 文本消息通常是错误或状态信息
            text_data = msg.data if isinstance(msg.data, str) else str(msg.data)
            raise RuntimeError(
                f"SC2API returned non-binary message (type={msg.type}): {text_data!r}"
            )

        response = sc_pb.Response()
        response.ParseFromString(msg.data)

        if response.error:
            raise RuntimeError(f"SC2API error: {response.error}")

        return response

    async def _ping(self) -> None:
        req = sc_pb.Request(ping=sc_pb.RequestPing())
        resp = await self._send_request(req)
        if not resp.HasField("ping"):
            raise RuntimeError("Ping response missing ping field")

    async def observe_once(self) -> dict[str, Any] | None:
        """发送一次 RequestObservation，解析并生成报告。"""
        if self.ws is None:
            print("[SC2ApiObserver] Not connected")
            return None

        req = sc_pb.Request(observation=sc_pb.RequestObservation())
        try:
            resp = await self._send_request(req)
        except RuntimeError as exc:
            print(f"[SC2ApiObserver] RequestObservation failed: {exc}")
            return None

        if not resp.HasField("observation"):
            print("[SC2ApiObserver] Response missing observation field")
            return None

        obs = resp.observation
        bank_data = self._convert_observation_to_bank_data(obs)
        report = build_verification_report(
            bank_data,
            composition_id=self.composition_id,
            run_id=self.run_id,
        )
        self._save_report(report)
        self._print_summary(report)
        return report

    def _convert_observation_to_bank_data(self, obs: Any) -> dict[str, dict[str, Any]]:
        """将 SC2API Observation 转换为 bank_data dict 格式（兼容 normalize_probe.py）。

        bank_data 结构:
            probe_state: { heartbeat, game_time, game_loop, phase, minerals, gas, ... }
            probe_units: { "u_<player>_<type>": "count:N,completed:N,...", ... }
            probe_upgrades: { "up_<player>_<upgrade>": "upgrade_id:X,researched:1,...", ... }
        """
        # player_common 包含资源、人口、game_loop
        pc = obs.player_common
        game_loop = pc.game_loop
        game_time = game_loop / 16.0  # SC2 16帧/秒

        # 资源和人口（player_common 的 player_id 通常是本地玩家）
        player_id = pc.player_id
        minerals = pc.minerals
        gas = pc.vespene
        supply_used = int(pc.food_used)
        supply_cap = int(pc.food_cap)

        # raw_data 包含单位、升级等
        raw = obs.raw_data

        # 按 unit_type 聚合单位
        units_by_type: dict[int, list[Any]] = {}
        for u in raw.units:
            # 只统计自有单位（alliance == Self = 1）
            if u.alliance != 1:
                continue
            units_by_type.setdefault(u.unit_type, []).append(u)

        probe_units: dict[str, str] = {}
        scan_id = 1
        for unit_type, unit_list in units_by_type.items():
            count = len(unit_list)
            life_sum = sum(int(u.health) for u in unit_list)
            energy_sum = sum(int(u.energy) for u in unit_list)
            life_avg = life_sum / count if count > 0 else 0
            energy_avg = energy_sum / count if count > 0 else 0

            type_name = _UNIT_TYPE_NAMES.get(unit_type, f"ID_{unit_type}")
            key = f"u_{player_id}_{type_name}"
            val = (
                f"count:{count},completed:{count},in_progress:0,"
                f"life_avg:{life_avg}.0,energy_avg:{energy_avg}.0,"
                f"owner:{player_id},is_structure:0,is_worker:0,scan_id:{scan_id}"
            )
            probe_units[key] = val

        # 升级列表（已研究的）
        probe_upgrades: dict[str, str] = {}
        for up_id in raw.player.upgrade_ids:
            up_name = _UPGRADE_NAMES.get(up_id, f"ID_{up_id}")
            key = f"up_{player_id}_{up_name}"
            val = f"upgrade_id:{up_name},researched:1,in_progress:0,available:1,blocked_reason:None"
            probe_upgrades[key] = val

        # 构造 probe_state（与 Bank 方案兼容的字段名）
        probe_state = {
            "run_id": "sc2api",
            "phase": "in_mission",
            "game_time": int(game_time),
            "game_loop": game_loop,
            "is_in_mission": True,
            "is_paused": False,
            "player_id": player_id,
            "minerals": minerals,
            "gas": gas,
            "supply_used": supply_used,
            "supply_cap": supply_cap,
            "unit_scan_id": scan_id,
            "script_error_count": 0,
        }

        return {
            "probe_state": probe_state,
            "probe_units": probe_units,
            "probe_upgrades": probe_upgrades,
        }

    def _save_report(self, report: dict[str, Any]) -> None:
        """保存 JSON 和 Markdown 报告。"""
        json_path = self.output_dir / "latest-report.json"
        md_path = self.output_dir / "latest-report.md"

        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2, ensure_ascii=False)

        with open(md_path, "w", encoding="utf-8") as f:
            f.write(report_to_markdown(report))

        # 也保存带时间戳的副本
        ts = datetime.now().strftime("%Y%m%d-%H%M%S")
        ts_json = self.output_dir / f"report-{ts}.json"
        with open(ts_json, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2, ensure_ascii=False)

        print(f"[SC2ApiObserver] Report saved: {json_path}")

    def _print_summary(self, report: dict[str, Any]) -> None:
        """打印简要摘要。"""
        state = report["probe_state"]
        units = report["probe_units"]
        upgrades = report["probe_upgrades"]
        status = report["status"]

        ok = all(status.values())
        tag = "OK" if ok else "FAIL"

        ts = datetime.now().strftime("%H:%M:%S")
        print(
            f"[{ts}] "
            f"Phase={state.get('phase', '?')} "
            f"Units={len(units)} Upgrades={len(upgrades)} "
            f"Min={state.get('minerals', 0)} Gas={state.get('gas', 0)} "
            f"Supply={state.get('supply_used', 0)}/{state.get('supply_cap', 0)} "
            f"[{tag}]"
        )

    async def run_watch(self, duration: float | None = None, interval: float = 2.0) -> None:
        """持续观测模式。"""
        print(f"[SC2ApiObserver] Watching (duration={duration}s, interval={interval}s)")
        print(f"[SC2ApiObserver] Run ID: {self.run_id}")
        print(f"[SC2ApiObserver] Composition: {self.composition_id}")
        print(f"[SC2ApiObserver] Output: {self.output_dir}")

        deadline = time.time() + duration if duration else None
        while True:
            if deadline and time.time() >= deadline:
                break
            try:
                await self.observe_once()
            except Exception as exc:
                print(f"[SC2ApiObserver] Observe error: {exc}")
            await asyncio.sleep(interval)

        print(f"[SC2ApiObserver] Duration reached ({duration}s), exiting.")

    async def disconnect(self) -> None:
        """关闭连接。"""
        if self.ws is not None and not self.ws.closed:
            await self.ws.close()
            self.ws = None
        if self.session is not None and not self.session.closed:
            await self.session.close()
            self.session = None
        print("[SC2ApiObserver] Disconnected")


async def main() -> None:
    parser = argparse.ArgumentParser(description="SC2API Observer")
    parser.add_argument("--host", default=DEFAULT_HOST, help="SC2 API 监听地址")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="SC2 API 监听端口")
    parser.add_argument("--composition-id", default="sc2api-observer", help="组合 ID")
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_DIR), help="报告输出目录")
    parser.add_argument("--run-id", default=None, help="运行 ID")
    parser.add_argument("--once", action="store_true", help="只观测一次")
    parser.add_argument("--duration", type=float, default=None, help="持续观测时长（秒）")
    parser.add_argument("--interval", type=float, default=2.0, help="观测间隔（秒）")
    parser.add_argument("--connect-timeout", type=float, default=60.0, help="连接超时（秒）")
    args = parser.parse_args()

    observer = SC2ApiObserver(
        host=args.host,
        port=args.port,
        composition_id=args.composition_id,
        output_dir=Path(args.output_dir),
        run_id=args.run_id,
    )

    try:
        await observer.connect(timeout=args.connect_timeout)
        if args.once:
            await observer.observe_once()
        elif args.duration:
            await observer.run_watch(duration=args.duration, interval=args.interval)
        else:
            # 默认只观测一次
            await observer.observe_once()
    except (KeyboardInterrupt, asyncio.CancelledError):
        print("\n[SC2ApiObserver] Interrupted")
    except Exception as exc:
        print(f"[SC2ApiObserver] Error: {exc}")
        raise
    finally:
        await observer.disconnect()


if __name__ == "__main__":
    asyncio.run(main())
