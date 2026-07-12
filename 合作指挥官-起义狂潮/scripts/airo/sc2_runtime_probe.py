# -*- coding: gbk -*-
"""SC2 运行时诊断工具

连接通过 -ApiListen 启动的 SC2 实例，读取游戏中的运行时数据，
用于验证指挥官生产链修复是否生效，避免用户手动进游戏判断。

工作流程:
1. 用 launch-7vs1-coop-test.ps1 -ApiListen 启动 SC2（会带上 -loadmap 加载地图）
2. SC2 启动后处于 launched 状态，监听 API 端口
3. 用户在 SC2 内手动点击"开始游戏"进入游戏会话（状态变为 in_game）
4. 运行 wait 命令轮询状态直到 in_game，然后运行 units/data/abilities 读取数据

用法示例:
    # 1. 启动游戏（PowerShell 终端）
    pwsh -File scripts\\launch-7vs1-coop-test.ps1 -ApiListen -ApiPort 8765 -Commanders TerranTychus

    # 2. 用户在 SC2 内手动开始游戏（点击"开始游戏"按钮）

    # 3. 用本脚本读取数据
    python scripts\\airo\\sc2_runtime_probe.py wait
    python scripts\\airo\\sc2_runtime_probe.py units
    python scripts\\airo\\sc2_runtime_probe.py data --filter Tychus
    python scripts\\airo\\sc2_runtime_probe.py abilities --unit-tag 123456
    python scripts\\airo\\sc2_runtime_probe.py verify-unit --player 1 --unit-name TychusResearchCenter
    python scripts\\airo\\sc2_runtime_probe.py verify-ability --player 1 --unit-name TychusResearchCenter --ability-name MedivacPlatform
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from collections import Counter
from pathlib import Path

import aiohttp

# 复用 SC2-Neuro-API-Integration 的 s2clientprotocol
# 脚本位于 合作指挥官-起义狂潮/scripts/airo/sc2_runtime_probe.py
# SC2-Neuro-API-Integration 位于 SC2/tools/SC2-Neuro-API-Integration
_SCRIPT_DIR = Path(__file__).resolve().parent  # airo
_SCRIPTS_DIR = _SCRIPT_DIR.parent              # scripts
_PROJECT_DIR = _SCRIPTS_DIR.parent              # 合作指挥官-起义狂潮
_SC2_DIR = _PROJECT_DIR.parent                 # SC2
_SC2_NEURO_DIR = _SC2_DIR / "tools" / "SC2-Neuro-API-Integration"
if _SC2_NEURO_DIR.exists():
    sys.path.insert(0, str(_SC2_NEURO_DIR))
else:
    _ALT = _SCRIPT_DIR / ".." / ".." / ".." / "tools" / "SC2-Neuro-API-Integration"
    if _ALT.exists():
        sys.path.insert(0, str(_ALT.resolve()))

from s2clientprotocol import sc2api_pb2 as sc_pb
from s2clientprotocol.query_pb2 import RequestQuery


# SC2 API 状态码（来自 s2clientprotocol/sc2api_pb2.py Status 枚举）
# launched=1, init_game=2, in_game=3, in_replay=4, ended=5, quit=6
STATUS_LAUNCHED = 1
STATUS_INIT_GAME = 2
STATUS_IN_GAME = 3
STATUS_ENDED = 5


class SC2Probe:
    def __init__(self, host: str, port: int):
        self.host = host
        self.port = port
        self.ws_url = f"ws://{host}:{port}/sc2api"
        self.session: aiohttp.ClientSession | None = None
        self.ws: aiohttp.ClientWebSocketResponse | None = None
        # 缓存 unit_id -> name 的映射，避免每次 observe_units 都重新拉取数据目录
        self._unit_id_to_name: dict[int, str] | None = None
        self._abil_id_to_name: dict[int, str] | None = None

    async def connect(self) -> None:
        timeout = aiohttp.ClientTimeout(total=15)
        self.session = aiohttp.ClientSession(timeout=timeout)
        # 重试连接（游戏刚启动时端口可能还没就绪）
        for attempt in range(10):
            try:
                self.ws = await self.session.ws_connect(self.ws_url)
                print(f"[OK] 已连接 SC2 API: {self.ws_url}")
                return
            except (aiohttp.ClientError, OSError, asyncio.TimeoutError) as exc:
                print(f"[等待] 第 {attempt + 1}/10 次连接失败: {exc}")
                await asyncio.sleep(3)
        raise RuntimeError(f"无法连接 SC2 API: {self.ws_url}")

    async def _request(self, **kwargs) -> sc_pb.Response:
        if self.ws is None:
            raise RuntimeError("未连接 SC2 API")
        request = sc_pb.Request(**kwargs)
        await self.ws.send_bytes(request.SerializeToString())
        resp_bytes = await self.ws.receive_bytes()
        response = sc_pb.Response()
        response.ParseFromString(resp_bytes)
        if response.error:
            raise RuntimeError(f"SC2 API 返回错误: {response.error}")
        return response

    async def _get_status(self) -> int:
        """通过 ping 获取当前 SC2 状态"""
        resp = await self._request(ping=sc_pb.RequestPing())
        return resp.status

    async def status(self) -> None:
        """打印当前状态"""
        resp = await self._request(ping=sc_pb.RequestPing())
        print(f"[Status] {sc_pb.Status.Name(resp.status)}")
        print(f"  base_build: {resp.ping.base_build}")

    async def wait_for_in_game(self, timeout_sec: int = 600, poll_interval: float = 2.0) -> bool:
        """轮询状态，等待用户手动进入游戏会话

        SC2 启动后处于 launched 状态，需要用户在游戏内手动点击"开始游戏"
        才会进入 in_game 状态。本方法会一直轮询直到状态变为 in_game 或超时。
        """
        print(f"[Wait] 等待 SC2 进入 in_game 状态（超时 {timeout_sec} 秒）")
        print("[Wait] 请在 SC2 内手动开始游戏...")
        elapsed = 0
        last_status = -1
        while elapsed < timeout_sec:
            try:
                status = await self._get_status()
                if status != last_status:
                    print(f"[Wait] 状态变更: {sc_pb.Status.Name(status)} (elapsed={elapsed}s)")
                    last_status = status
                if status == STATUS_IN_GAME:
                    print(f"[OK] SC2 已进入 in_game 状态（耗时 {elapsed}s）")
                    return True
                if status == STATUS_ENDED:
                    print("[Warn] 游戏已结束，请重新开始")
                    return False
            except RuntimeError as exc:
                print(f"[Wait] 查询状态失败: {exc}")
            await asyncio.sleep(poll_interval)
            elapsed += int(poll_interval)
        print(f"[Timeout] 等待 {timeout_sec}s 后超时")
        return False

    async def _load_data_catalog(self) -> None:
        """加载 RequestData 缓存单位/技能 ID->名称映射"""
        if self._unit_id_to_name is not None:
            return
        resp = await self._request(data=sc_pb.RequestData())
        data = resp.data
        self._unit_id_to_name = {u.unit_id: u.name for u in data.units}
        self._abil_id_to_name = {a.ability_id: a.name for a in data.abilities}
        print(f"[Data] 缓存已加载: {len(self._unit_id_to_name)} 个单位, {len(self._abil_id_to_name)} 个技能")

    def _unit_name(self, unit_id: int) -> str:
        if self._unit_id_to_name is None:
            return f"#{unit_id}"
        return self._unit_id_to_name.get(unit_id, f"#{unit_id}")

    def _abil_name(self, abil_id: int) -> str:
        if self._abil_id_to_name is None:
            return f"#{abil_id}"
        return self._abil_id_to_name.get(abil_id, f"#{abil_id}")

    @staticmethod
    def _normalize_name(value: str) -> str:
        return "".join(ch.lower() for ch in value if ch.isalnum())

    def _matches_keyword(self, actual_name: str, keyword: str) -> bool:
        if not keyword:
            return True
        return self._normalize_name(keyword) in self._normalize_name(actual_name)

    async def _require_in_game(self) -> None:
        status = await self._get_status()
        if status != STATUS_IN_GAME:
            raise RuntimeError(
                f"当前 SC2 状态为 {sc_pb.Status.Name(status)}，需先用 wait 进入 in_game 后才能读取运行时数据"
            )

    async def _get_player_units(self, player_id: int) -> list:
        await self._load_data_catalog()
        await self._require_in_game()
        resp = await self._request(observation=sc_pb.RequestObservation())
        return [u for u in resp.observation.raw_data.units if u.owner == player_id]

    def _filter_units_by_name(self, units: list, unit_keyword: str) -> list:
        return [u for u in units if self._matches_keyword(self._unit_name(u.unit_type), unit_keyword)]

    async def _query_abilities_for_unit(self, unit_tag: int) -> list[tuple[int, str]]:
        await self._load_data_catalog()
        await self._require_in_game()
        query = RequestQuery()
        query.abilities.unit_tag = unit_tag
        resp = await self._request(query=query)
        return [(abil.ability_id, self._abil_name(abil.ability_id)) for abil in resp.query.abilities.abilities]

    async def observe_units(self, owner_filter: int = -1) -> None:
        """读取游戏中的所有单位，按玩家和类型分组统计

        owner_filter: -1 = 全部玩家；0-N = 仅指定玩家
        """
        await self._load_data_catalog()
        await self._require_in_game()
        resp = await self._request(observation=sc_pb.RequestObservation())
        obs = resp.observation

        print(f"\n=== 游戏观察数据 ===")
        print(f"游戏循环数: {obs.game_loop}")

        units = obs.raw_data.units
        print(f"地图上单位总数: {len(units)}")

        by_owner: dict[int, Counter] = {}
        for unit in units:
            owner = unit.owner
            unit_type = unit.unit_type
            if owner not in by_owner:
                by_owner[owner] = Counter()
            by_owner[owner][unit_type] += 1

        for owner in sorted(by_owner.keys()):
            if owner_filter >= 0 and owner != owner_filter:
                continue
            total = sum(by_owner[owner].values())
            print(f"\n--- 玩家 {owner} 单位 (共 {total} 个) ---")
            for unit_type, count in sorted(by_owner[owner].items(), key=lambda x: -x[1]):
                print(f"  {self._unit_name(unit_type):40s} x {count}")

    async def list_player_units(self, player_id: int = 1) -> None:
        """列出指定玩家的所有单位（含 tag、位置、HP），便于后续查询技能"""
        player_units = await self._get_player_units(player_id)
        print(f"\n=== 玩家 {player_id} 单位列表 ({len(player_units)} 个) ===")
        print(f"{'Tag':>12s}  {'UnitType':40s}  {'Pos':20s}  {'HP':>13s}  {'Energy':>6s}")
        for u in player_units:
            pos = f"({u.pos.x:.0f},{u.pos.y:.0f},{u.pos.z:.0f})"
            hp = f"{int(u.health):>6d}/{int(u.health_max):<6d}" if u.health_max > 0 else f"{int(u.health):>6d}/-     "
            energy = f"{int(u.energy):>6d}" if u.energy > 0 else "     0"
            print(f"{u.tag:>12d}  {self._unit_name(u.unit_type):40s}  {pos:20s}  {hp}  {energy}")

    async def query_abilities(self, unit_tag: int) -> None:
        """查询指定单位可用技能"""
        abilities = await self._query_abilities_for_unit(unit_tag)
        if abilities:
            print(f"\n单位 tag={unit_tag} 可用技能:")
            for ability_id, ability_name in abilities:
                print(f"  {ability_id:>6d} (0x{ability_id:x})  {ability_name}")
        else:
            print(f"单位 tag={unit_tag} 无可用技能或单位不存在")

    async def verify_unit(self, player_id: int, unit_keyword: str, min_count: int = 1) -> bool:
        """验证指定玩家是否拥有目标单位。"""
        player_units = await self._get_player_units(player_id)
        matches = self._filter_units_by_name(player_units, unit_keyword)

        print(f"\n[VerifyUnit] 玩家={player_id} 目标单位关键字='{unit_keyword}' 最小数量={min_count}")
        print(f"[VerifyUnit] 玩家单位总数: {len(player_units)}")
        print(f"[VerifyUnit] 命中数量: {len(matches)}")

        for unit in matches[:20]:
            pos = f"({unit.pos.x:.0f},{unit.pos.y:.0f},{unit.pos.z:.0f})"
            print(f"  tag={unit.tag:<12d} unit={self._unit_name(unit.unit_type):40s} pos={pos}")
        if len(matches) > 20:
            print(f"  ... 其余 {len(matches) - 20} 个匹配单位未展开")

        passed = len(matches) >= min_count
        print(f"[{'PASS' if passed else 'FAIL'}] 单位验证{'通过' if passed else '失败'}")
        return passed

    async def verify_ability(self, player_id: int, unit_keyword: str, ability_keyword: str) -> bool:
        """验证指定玩家的目标单位是否拥有目标技能。"""
        player_units = await self._get_player_units(player_id)
        matched_units = self._filter_units_by_name(player_units, unit_keyword)

        print(
            f"\n[VerifyAbility] 玩家={player_id} 单位关键字='{unit_keyword}' 技能关键字='{ability_keyword}'"
        )
        if not matched_units:
            print("[FAIL] 未找到匹配单位，无法继续验证技能")
            return False

        matched_abilities: list[tuple[int, str, int, str]] = []
        for unit in matched_units:
            abilities = await self._query_abilities_for_unit(unit.tag)
            ability_hits = [(ability_id, ability_name) for ability_id, ability_name in abilities if self._matches_keyword(ability_name, ability_keyword)]
            print(
                f"  单位 tag={unit.tag:<12d} unit={self._unit_name(unit.unit_type):40s} 技能数={len(abilities)} 命中={len(ability_hits)}"
            )
            for ability_id, ability_name in ability_hits:
                matched_abilities.append((unit.tag, self._unit_name(unit.unit_type), ability_id, ability_name))

        if matched_abilities:
            print("[PASS] 技能验证通过，命中技能如下:")
            for unit_tag, unit_name, ability_id, ability_name in matched_abilities:
                print(f"  unit_tag={unit_tag:<12d} unit={unit_name:40s} ability={ability_id:>6d} {ability_name}")
            return True

        print("[FAIL] 已找到目标单位，但未发现匹配技能")
        return False

    async def get_game_data(self, filter_keyword: str = "") -> None:
        """获取游戏数据目录（单位/技能/升级定义列表）"""
        resp = await self._request(data=sc_pb.RequestData())
        data = resp.data
        print(f"\n=== 游戏数据目录 ===")
        print(f"单位定义数: {len(data.units)}")
        print(f"技能定义数: {len(data.abilities)}")
        print(f"升级定义数: {len(data.upgrades)}")
        print(f"行为定义数: {len(data.buffs)}")

        if not filter_keyword:
            return

        kw = filter_keyword.lower()
        print(f"\n--- 单位匹配 '{filter_keyword}' ---")
        for unit in data.units:
            if kw in unit.name.lower():
                print(f"  {unit.unit_id:>6d}  {unit.name}  (race={unit.race})")

        print(f"\n--- 技能匹配 '{filter_keyword}' ---")
        for abil in data.abilities:
            if kw in abil.name.lower():
                print(f"  {abil.ability_id:>6d} (0x{abil.ability_id:x})  {abil.name}")

        print(f"\n--- 升级匹配 '{filter_keyword}' ---")
        for upg in data.upgrades:
            if kw in upg.name.lower():
                print(f"  {upg.upgrade_id:>6d}  {upg.name}")

    async def close(self) -> None:
        if self.ws is not None:
            await self.ws.close()
            self.ws = None
        if self.session is not None:
            await self.session.close()
            self.session = None


async def main():
    parser = argparse.ArgumentParser(
        description="SC2 运行时诊断工具",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument(
        "action",
        choices=["ping", "status", "wait", "units", "player", "data", "abilities", "verify-unit", "verify-ability"],
        help=(
            "ping=测试连接; status=打印当前状态; wait=轮询直到 in_game; "
            "units=列出全图单位统计; player=列出玩家单位详情(含tag/位置); "
            "data=数据目录; abilities=查询单位技能; "
            "verify-unit=按单位名验证单位存在; verify-ability=按单位名+技能名验证技能存在"
        ),
    )
    parser.add_argument("--unit-tag", type=int, default=0, help="abilities: 指定单位 tag")
    parser.add_argument("--unit-name", default="", help="verify-unit/verify-ability: 单位名称关键字")
    parser.add_argument("--ability-name", default="", help="verify-ability: 技能名称关键字")
    parser.add_argument("--filter", default="", help="data: 按关键字过滤(如 Tychus)")
    parser.add_argument("--player", type=int, default=1, help="player: 指定玩家ID(默认1)")
    parser.add_argument("--min-count", type=int, default=1, help="verify-unit: 最少命中数量(默认1)")
    parser.add_argument("--timeout", type=int, default=600, help="wait: 超时秒数(默认600)")
    args = parser.parse_args()

    probe = SC2Probe(args.host, args.port)
    try:
        await probe.connect()
        exit_code = 0
        if args.action == "ping":
            resp = await probe._request(ping=sc_pb.RequestPing())
            print(f"[Ping] 状态: {sc_pb.Status.Name(resp.status)}")
            print(f"  base_build: {resp.ping.base_build}")
        elif args.action == "status":
            await probe.status()
        elif args.action == "wait":
            ok = await probe.wait_for_in_game(timeout_sec=args.timeout)
            if not ok:
                exit_code = 1
        elif args.action == "units":
            await probe.observe_units()
        elif args.action == "player":
            await probe.list_player_units(player_id=args.player)
        elif args.action == "data":
            await probe.get_game_data(filter_keyword=args.filter)
        elif args.action == "abilities":
            if args.unit_tag == 0:
                print("请用 --unit-tag 指定单位 tag（可先用 player 命令查看）")
                exit_code = 1
            else:
                await probe.query_abilities(args.unit_tag)
        elif args.action == "verify-unit":
            if not args.unit_name:
                print("请用 --unit-name 指定单位名称关键字")
                exit_code = 1
            else:
                ok = await probe.verify_unit(player_id=args.player, unit_keyword=args.unit_name, min_count=args.min_count)
                if not ok:
                    exit_code = 1
        elif args.action == "verify-ability":
            if not args.unit_name:
                print("请用 --unit-name 指定单位名称关键字")
                exit_code = 1
            elif not args.ability_name:
                print("请用 --ability-name 指定技能名称关键字")
                exit_code = 1
            else:
                ok = await probe.verify_ability(
                    player_id=args.player,
                    unit_keyword=args.unit_name,
                    ability_keyword=args.ability_name,
                )
                if not ok:
                    exit_code = 1
        if exit_code != 0:
            sys.exit(exit_code)
    except RuntimeError as exc:
        print(f"[Error] {exc}")
        sys.exit(1)
    finally:
        await probe.close()


if __name__ == "__main__":
    asyncio.run(main())
