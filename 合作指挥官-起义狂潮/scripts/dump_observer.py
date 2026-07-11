"""
Observer 外挂连接脚本：连接已启动的 SC2 游戏，读取开局单位/建筑，写入 JSON。

使用前提：
  1. SC2 已以 -listen 127.0.0.1 -port 8765 启动并加载了地图。
     可通过修改后的 launch-7vs1-coop-test.ps1 -ApiListen 启动。
  2. 游戏已进入地图（玩家已选择指挥官并开始游戏）。
  3. 安装依赖：pip install burnysc2
     （burnysc2 会自动安装 s2clientprotocol、aiohttp 等依赖）

用法：
  python dump_observer.py
  python dump_observer.py --host 127.0.0.1 --port 8765 --observed-player-id 1
  python dump_observer.py --wait 600

输出：
  scripts/dump/<时间戳>_observer_dump.json
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
import time
from datetime import datetime
from pathlib import Path

import aiohttp
from s2clientprotocol import sc2api_pb2 as sc_pb

# 默认配置
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8765
DEFAULT_OBSERVED_PLAYER_ID = 1
DEFAULT_WAIT_SECONDS = 300  # 最多等待 5 分钟
CONNECT_RETRY_INTERVAL = 2  # 连接重试间隔（秒）
GAME_READY_POLL_INTERVAL = 2  # 游戏就绪轮询间隔（秒）


async def send_request(ws: aiohttp.client_ws.ClientWebSocketResponse, request: sc_pb.Request) -> sc_pb.Response:
    """发送 protobuf 请求并等待响应。"""
    await ws.send_bytes(request.SerializeToString())
    msg = await ws.receive_bytes()
    response = sc_pb.Response()
    response.ParseFromString(msg)
    return response


def status_name(status_int: int) -> str:
    """将 SC2 状态整数转换为可读名称。"""
    names = {
        0: "unknown",
        1: "launched",
        2: "init_game",
        3: "in_game",
        4: "ended",
    }
    return names.get(status_int, f"status_{status_int}")


async def wait_for_game_ready(ws: aiohttp.client_ws.ClientWebSocketResponse, timeout: int = 300) -> bool:
    """轮询 SC2 状态，等待游戏进入 in_game 状态。"""
    print("[Observer] 等待游戏就绪（请在 SC2 中进入地图）...")
    start = time.time()

    while time.time() - start < timeout:
        try:
            resp = await send_request(ws, sc_pb.Request(ping=sc_pb.RequestPing()))
            status = resp.status
            elapsed = int(time.time() - start)
            print(f"\r[Observer] 状态: {status_name(status)} ({elapsed}s)", end="", flush=True)

            if status == sc_pb.Status.in_game:
                print()
                return True
        except Exception as e:
            print(f"\r[Observer] 轮询异常: {e}", end="", flush=True)

        await asyncio.sleep(GAME_READY_POLL_INTERVAL)

    print()
    return False


async def join_as_observer(
    ws: aiohttp.client_ws.ClientWebSocketResponse, observed_player_id: int
) -> int | None:
    """以 observer 模式加入游戏，返回 observer 的 player_id。"""
    ifopts = sc_pb.InterfaceOptions(
        raw=True,
        score=True,
        show_cloaked=True,
        show_burrowed_shadows=True,
        raw_affects_selection=False,
        raw_crop_to_playable_area=False,
        show_placeholders=True,
    )

    join_req = sc_pb.Request(
        join_game=sc_pb.RequestJoinGame(
            observed_player_id=observed_player_id,
            options=ifopts,
        )
    )

    resp = await send_request(ws, join_req)

    if resp.HasField("error"):
        error_details = ""
        if resp.HasField("error_details"):
            error_details = f" - {resp.error_details}"
        print(f"[Observer] 加入游戏失败: error={resp.error}{error_details}")
        return None

    player_id = resp.join_game.player_id
    print(f"[Observer] 已加入游戏，observer player_id={player_id}")
    return player_id


async def fetch_unit_type_map(ws: aiohttp.client_ws.ClientWebSocketResponse) -> dict[int, str]:
    """获取单位类型 ID -> 名称的映射。"""
    data_req = sc_pb.Request(
        data=sc_pb.RequestData(
            ability_id=True,
            unit_type_id=True,
            upgrade_id=True,
            buff_id=True,
            effect_id=True,
        )
    )
    resp = await send_request(ws, data_req)

    type_map: dict[int, str] = {}
    for unit_data in resp.data.units:
        type_map[unit_data.unit_id] = unit_data.name

    print(f"[Observer] 已获取 {len(type_map)} 个单位类型定义")
    return type_map


async def fetch_game_info(ws: aiohttp.client_ws.ClientWebSocketResponse) -> dict:
    """获取游戏信息（玩家名称、种族等）。"""
    resp = await send_request(ws, sc_pb.Request(game_info=sc_pb.RequestGameInfo()))

    players: dict[int, dict] = {}
    for pi in resp.game_info.player_info:
        players[pi.player_id] = {
            "player_id": pi.player_id,
            "player_name": pi.player_name,
            "race_requested": int(pi.race_requested) if pi.HasField("race_requested") else None,
            "race_actual": int(pi.race_actual) if pi.HasField("race_actual") else None,
        }

    return players


async def fetch_observation(
    ws: aiohttp.client_ws.ClientWebSocketResponse, unit_type_map: dict[int, str]
) -> dict:
    """获取观察数据并解析为单位列表。"""
    resp = await send_request(ws, sc_pb.Request(observation=sc_pb.RequestObservation()))
    observation = resp.observation.observation

    # 提取玩家资源
    player_resources: dict[int, dict] = {}
    for pc in observation.player_common:
        player_resources[pc.player_id] = {
            "minerals": pc.minerals,
            "vespene": pc.vespene,
            "supply_used": pc.food_used,
            "supply_cap": pc.food_cap,
        }

    # 提取单位列表
    units_list: list[dict] = []
    for unit in observation.raw_data.units:
        # 跳过非实际单位（如影子/虚假单位）
        if unit.is_blip:
            continue

        unit_info = {
            "unit_type_id": unit.unit_type,
            "unit_name": unit_type_map.get(unit.unit_type, f"Unknown_{unit.unit_type}"),
            "owner": unit.owner,
            "pos": {
                "x": round(unit.pos.x, 2),
                "y": round(unit.pos.y, 2),
                "z": round(unit.pos.z, 2),
            },
            "is_building": unit.is_building,
            "is_on_screen": unit.is_on_screen,
        }
        units_list.append(unit_info)

    # 按 owner 分组
    by_owner: dict[int, list[dict]] = {}
    for u in units_list:
        owner = u["owner"]
        by_owner.setdefault(owner, []).append(u)

    # 按类型聚合统计
    summary: dict[int, dict[str, dict]] = {}
    for owner, units in by_owner.items():
        summary[owner] = {}
        for u in units:
            name = u["unit_name"]
            if name not in summary[owner]:
                summary[owner][name] = {"count": 0, "is_building": u["is_building"]}
            summary[owner][name]["count"] += 1

    return {
        "game_loop": observation.game_loop,
        "player_resources": player_resources,
        "units_by_owner": by_owner,
        "summary_by_owner": summary,
        "total_units": len(units_list),
    }


def build_output(
    observed_player_id: int,
    game_info_players: dict[int, dict],
    observation_data: dict,
) -> dict:
    """构建最终输出结构。"""
    all_player_ids = sorted(
        set(
            list(game_info_players.keys())
            + list(observation_data["player_resources"].keys())
            + list(observation_data["units_by_owner"].keys())
        )
    )

    players_out: dict[str, dict] = {}
    for pid in all_player_ids:
        info = game_info_players.get(pid, {})
        resources = observation_data["player_resources"].get(pid, {})
        players_out[str(pid)] = {
            "player_id": pid,
            "name": info.get("player_name", ""),
            "race_requested": info.get("race_requested"),
            "race_actual": info.get("race_actual"),
            "resources": resources,
        }

    return {
        "timestamp": datetime.now().isoformat(),
        "game_loop": observation_data["game_loop"],
        "observed_player_id": observed_player_id,
        "players": players_out,
        "units_by_owner": {
            str(owner): units for owner, units in sorted(observation_data["units_by_owner"].items())
        },
        "summary_by_owner": {
            str(owner): summary_dict
            for owner, summary_dict in sorted(observation_data["summary_by_owner"].items())
        },
        "total_units": observation_data["total_units"],
    }


def print_summary(output: dict) -> None:
    """打印简要摘要到控制台。"""
    print()
    print("=" * 60)
    print(f"Game loop: {output['game_loop']}")
    print(f"Total units: {output['total_units']}")
    print()

    for pid_str, player_info in output["players"].items():
        name = player_info.get("name", f"Player{pid_str}")
        resources = player_info.get("resources", {})
        units = output["units_by_owner"].get(pid_str, [])
        buildings = [u for u in units if u.get("is_building")]
        army = [u for u in units if not u.get("is_building")]

        minerals = resources.get("minerals", "?")
        vespene = resources.get("vespene", "?")
        supply = f"{resources.get('supply_used', '?')}/{resources.get('supply_cap', '?')}"

        print(f"  Player {pid_str} ({name})")
        print(f"    Resources: {minerals} minerals, {vespene} gas, supply {supply}")
        print(f"    Buildings: {len(buildings)}, Army: {len(army)}")

        # 打印建筑摘要
        summary = output["summary_by_owner"].get(pid_str, {})
        building_summary = {k: v for k, v in summary.items() if v.get("is_building")}
        army_summary = {k: v for k, v in summary.items() if not v.get("is_building")}

        if building_summary:
            print(f"    Buildings breakdown:")
            for name, info in sorted(building_summary.items()):
                print(f"      {name:40s} x{info['count']}")

        if army_summary:
            print(f"    Army breakdown:")
            for name, info in sorted(army_summary.items()):
                print(f"      {name:40s} x{info['count']}")

    print("=" * 60)


async def connect_and_dump(
    host: str,
    port: int,
    observed_player_id: int,
    wait_timeout: int,
    output_dir: Path,
) -> bool:
    """主流程：连接 SC2 -> 等待游戏 -> observer 加入 -> 读取数据 -> 写入 JSON。"""
    url = f"ws://{host}:{port}/sc2api"
    print(f"[Observer] 正在连接 {url} ...")

    async with aiohttp.ClientSession() as session:
        # 1. 等待 SC2 websocket 就绪
        ws: aiohttp.client_ws.ClientWebSocketResponse | None = None
        connect_start = time.time()
        while time.time() - connect_start < wait_timeout:
            try:
                ws = await session.ws_connect(url, timeout=10)
                break
            except (aiohttp.client_exceptions.ClientConnectorError, asyncio.TimeoutError, OSError):
                elapsed = int(time.time() - connect_start)
                print(f"\r[Observer] 等待 SC2 启动... ({elapsed}s)", end="", flush=True)
                await asyncio.sleep(CONNECT_RETRY_INTERVAL)

        if ws is None:
            print("\n[Observer] 无法连接到 SC2，请确认 SC2 已以 -listen -port 启动")
            return False

        print("\n[Observer] Websocket 已连接")

        # 2. 等待游戏进入 in_game 状态
        ready = await wait_for_game_ready(ws, wait_timeout)
        if not ready:
            print("[Observer] 等待游戏就绪超时")
            await ws.close()
            return False

        # 3. 以 observer 模式加入游戏
        observer_pid = await join_as_observer(ws, observed_player_id)
        if observer_pid is None:
            await ws.close()
            return False

        # 4. 获取单位类型映射
        unit_type_map = await fetch_unit_type_map(ws)

        # 5. 获取游戏信息
        game_info_players = await fetch_game_info(ws)

        # 6. 获取观察数据
        observation_data = await fetch_observation(ws, unit_type_map)

        # 7. 构建输出
        output = build_output(observed_player_id, game_info_players, observation_data)

        # 8. 写入 JSON
        output_dir.mkdir(parents=True, exist_ok=True)
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        out_file = output_dir / f"{ts}_observer_dump.json"
        out_file.write_text(json.dumps(output, indent=2, ensure_ascii=False), encoding="utf-8")

        print(f"\n[Observer] 已写入: {out_file}")
        print_summary(output)

        # 9. 离开游戏
        try:
            await send_request(ws, sc_pb.Request(leave_game=sc_pb.RequestLeaveGame()))
            print("[Observer] 已离开游戏")
        except Exception as e:
            print(f"[Observer] 离开游戏时异常（可忽略）: {e}")

        await ws.close()
        print("[Observer] 连接已关闭")
        return True


def main() -> int:
    parser = argparse.ArgumentParser(
        description="以 Observer 模式连接 SC2 游戏，读取开局单位/建筑并写入 JSON"
    )
    parser.add_argument("--host", default=DEFAULT_HOST, help=f"SC2 监听地址 (默认: {DEFAULT_HOST})")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help=f"SC2 监听端口 (默认: {DEFAULT_PORT})")
    parser.add_argument(
        "--observed-player-id",
        type=int,
        default=DEFAULT_OBSERVED_PLAYER_ID,
        help=f"被观察的玩家 ID (默认: {DEFAULT_OBSERVED_PLAYER_ID})",
    )
    parser.add_argument(
        "--wait",
        type=int,
        default=DEFAULT_WAIT_SECONDS,
        help=f"等待 SC2 启动和游戏就绪的超时秒数 (默认: {DEFAULT_WAIT_SECONDS})",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default="",
        help="JSON 输出目录 (默认: scripts/dump)",
    )

    args = parser.parse_args()

    if args.output_dir:
        output_dir = Path(args.output_dir)
    else:
        output_dir = Path(__file__).parent / "dump"

    print(f"[Observer] 输出目录: {output_dir}")
    print(f"[Observer] 被观察玩家: Player {args.observed_player_id}")
    print()

    try:
        success = asyncio.run(
            connect_and_dump(
                host=args.host,
                port=args.port,
                observed_player_id=args.observed_player_id,
                wait_timeout=args.wait,
                output_dir=output_dir,
            )
        )
        return 0 if success else 1
    except KeyboardInterrupt:
        print("\n[Observer] 用户中断")
        return 130
    except Exception as e:
        print(f"[Observer] 异常: {e}", file=sys.stderr)
        import traceback

        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
