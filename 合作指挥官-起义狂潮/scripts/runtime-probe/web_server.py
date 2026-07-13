"""RuntimeProbe Web Server

基于 FastAPI 的实时观测 Web 服务器。
监听 RuntimeProbe.SC2Bank 文件变化，通过 WebSocket 推送给前端面板，并提供稳定的
verdict/events API 给启动器和验证脚本使用。

用法:
    python web_server.py --banks-path "C:\\Users\\22448\\Documents\\StarCraft II\\Banks" --port 18080

    然后浏览器访问 http://127.0.0.1:18080
"""

from __future__ import annotations

import argparse
import asyncio
import json
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import Any

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from bank_io import parse_bank_file
from normalize_probe import build_verification_report, report_to_markdown

DEFAULT_BANKS_PATH = r"C:\Users\22448\Documents\StarCraft II\Banks"
DEFAULT_PORT = 18080
BANK_FILE_NAME = "RuntimeProbe.SC2Bank"
NEURO_BANK_FILE_NAME = "NeuroIntegration.SC2Bank"

app = FastAPI(title="RuntimeProbe Web Panel", version="0.1.0")

# 全局状态（由 Bank watcher 线程更新，由 API/WebSocket 读取）
_state_lock = threading.Lock()
_latest_report: dict[str, Any] | None = None
_latest_bank_raw: dict[str, dict[str, Any]] | None = None
_latest_neuro_bank_raw: dict[str, dict[str, Any]] | None = None
_latest_events: list[dict[str, Any]] = []
_last_update_time: datetime | None = None
_last_bank_mtime: float = 0
_last_neuro_bank_mtime: float = 0

# WebSocket 连接管理
_ws_clients: set[WebSocket] = set()
_ws_lock = threading.Lock()


def _bank_file_path(banks_path: str) -> Path:
    return Path(banks_path) / BANK_FILE_NAME


def _neuro_bank_file_path(banks_path: str) -> Path:
    return Path(banks_path) / NEURO_BANK_FILE_NAME


def _bool_event(name: str, ok: bool, details: dict[str, Any] | None = None) -> dict[str, Any]:
    return {
        "type": name,
        "ok": ok,
        "timestamp": datetime.now().isoformat(),
        "details": details or {},
    }


def _build_verdict(report: dict[str, Any] | None, last_update: datetime | None) -> dict[str, Any]:
    if report is None:
        return {
            "source": "runtime-probe-service",
            "verdict": "pending",
            "pass": False,
            "ready": False,
            "reason": "RuntimeProbe bank has not been loaded yet.",
            "status": {},
            "failed_checks": [],
            "pending_checks": ["bank_loaded"],
            "last_update": None,
        }

    status = report.get("status", {})
    failed_checks = [key for key, value in status.items() if value is False]
    pending_checks: list[str] = []
    if not status.get("map_loaded", False):
        pending_checks.append("map_loaded")
    if status.get("map_loaded", False) and not status.get("probe_complete", False):
        pending_checks.append("probe_complete")

    fatal_failures = [
        key for key in failed_checks
        if key not in {"map_loaded", "probe_complete"}
    ]
    if fatal_failures:
        verdict = "fail"
    elif pending_checks:
        verdict = "pending"
    else:
        verdict = "pass"

    return {
        "source": "runtime-probe-service",
        "verdict": verdict,
        "pass": verdict == "pass",
        "ready": verdict in {"pass", "fail"},
        "reason": (
            "All runtime checks passed."
            if verdict == "pass"
            else "Runtime checks failed."
            if verdict == "fail"
            else "RuntimeProbe is still waiting for enough in-game data."
        ),
        "status": status,
        "failed_checks": failed_checks,
        "pending_checks": pending_checks,
        "run_id": report.get("run_id", "unknown"),
        "composition_id": report.get("composition_id", "unknown"),
        "last_update": last_update.isoformat() if last_update else None,
    }


def _build_events(
    report: dict[str, Any],
    runtime_bank: dict[str, dict[str, Any]],
    neuro_bank: dict[str, dict[str, Any]],
) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    state = report.get("probe_state", {})
    status = report.get("status", {})

    events.append(_bool_event("map_loaded", bool(status.get("map_loaded")), {
        "heartbeat": state.get("heartbeat", 0),
        "phase": state.get("phase", "unknown"),
        "game_time": state.get("game_time", 0),
    }))
    events.append(_bool_event("probe_complete", bool(status.get("probe_complete")), {
        "unit_types": len(report.get("probe_units", [])),
        "producer_types": len(report.get("probe_producers", [])),
    }))
    events.append(_bool_event("script_error_free", bool(status.get("script_error_free")), {
        "script_error_count": state.get("script_error_count", 0),
    }))

    if report.get("probe_units"):
        events.append({
            "type": "unit_snapshot",
            "timestamp": datetime.now().isoformat(),
            "details": {
                "units": [
                    {
                        "unit_type_id": unit.get("unit_type_id"),
                        "count": unit.get("count", 0),
                        "completed_count": unit.get("completed_count", 0),
                    }
                    for unit in report.get("probe_units", [])
                ]
            },
        })

    game_context = neuro_bank.get("game_context", {})
    if game_context:
        for key, value in game_context.items():
            events.append({
                "type": "neuro_game_context",
                "timestamp": datetime.now().isoformat(),
                "details": {"key": key, "value": value},
            })

    do_action = neuro_bank.get("do_action", {})
    pending_actions = [
        key for key, value in do_action.items()
        if isinstance(value, bool) and value is True and not key.endswith("_arg_1") and not key.endswith("_arg_2")
    ]
    if pending_actions:
        events.append({
            "type": "neuro_pending_actions",
            "timestamp": datetime.now().isoformat(),
            "details": {"actions": pending_actions},
        })

    force_action = neuro_bank.get("force_action", {})
    for key, value in force_action.items():
        if isinstance(key, str) and key.endswith("_query"):
            group = key[:-6]
            events.append({
                "type": "neuro_force_query",
                "timestamp": datetime.now().isoformat(),
                "details": {
                    "group": group,
                    "query": value,
                    "actions": force_action.get(f"{group}_actions", ""),
                    "state": force_action.get(f"{group}_state", ""),
                },
            })

    if runtime_bank.get("probe_replacement"):
        events.append({
            "type": "replacement_status",
            "timestamp": datetime.now().isoformat(),
            "details": runtime_bank.get("probe_replacement", {}),
        })

    return events[-200:]


def _parse_and_update(bank_path: Path, neuro_bank_path: Path) -> bool:
    """解析 Bank 文件并更新全局状态。返回是否有更新。"""
    global _latest_report, _latest_bank_raw, _latest_neuro_bank_raw, _latest_events
    global _last_update_time, _last_bank_mtime, _last_neuro_bank_mtime

    try:
        mtime = bank_path.stat().st_mtime
    except OSError:
        return False

    neuro_mtime = 0.0
    if neuro_bank_path.exists():
        try:
            neuro_mtime = neuro_bank_path.stat().st_mtime
        except OSError:
            neuro_mtime = 0.0

    if mtime == _last_bank_mtime and neuro_mtime == _last_neuro_bank_mtime:
        return False

    try:
        bank_data = parse_bank_file(bank_path)
    except Exception as exc:
        print(f"[WebServer] parse_bank_file failed: {exc}")
        return False

    neuro_bank_data: dict[str, dict[str, Any]] = {}
    if neuro_bank_path.exists():
        try:
            neuro_bank_data = parse_bank_file(neuro_bank_path)
        except Exception as exc:
            print(f"[WebServer] parse_neuro_bank_file failed: {exc}")

    report = build_verification_report(bank_data, composition_id="web-panel")
    events = _build_events(report, bank_data, neuro_bank_data)

    with _state_lock:
        _latest_report = report
        _latest_bank_raw = bank_data
        _latest_neuro_bank_raw = neuro_bank_data
        _latest_events = events
        _last_update_time = datetime.now()
        _last_bank_mtime = mtime
        _last_neuro_bank_mtime = neuro_mtime

    return True


def _bank_watcher_loop(banks_path: str, stop_event: threading.Event) -> None:
    """Bank 文件监听线程（轮询 mtime，简单可靠）。"""
    bank_path = _bank_file_path(banks_path)
    neuro_bank_path = _neuro_bank_file_path(banks_path)
    print(f"[WebServer] Watching: {bank_path}")
    print(f"[WebServer] Watching Neuro bank: {neuro_bank_path}")
    poll_interval = 0.5

    while not stop_event.is_set():
        try:
            if bank_path.exists():
                updated = _parse_and_update(bank_path, neuro_bank_path)
                if updated:
                    print(f"[WebServer] Bank updated: {_last_update_time}")
                    # 异步通知 WebSocket 客户端
                    asyncio.run_coroutine_threadsafe(
                        _broadcast_to_clients(), _asyncio_loop
                    )
        except Exception as exc:
            print(f"[WebServer] Watcher error: {exc}")

        time.sleep(poll_interval)


async def _broadcast_to_clients() -> None:
    """向所有 WebSocket 客户端推送最新状态。"""
    with _state_lock:
        if _latest_report is None:
            return
        report_copy = json.loads(json.dumps(_latest_report))

    with _ws_lock:
        clients = list(_ws_clients)

    for ws in clients:
        try:
            await ws.send_json(report_copy)
        except Exception:
            # 客户端可能已断开，移除
            with _ws_lock:
                _ws_clients.discard(ws)


# === asyncio loop 引用（由 watcher 线程用于提交协程）===
_asyncio_loop: asyncio.AbstractEventLoop | None = None


@app.on_event("startup")
async def _startup() -> None:
    global _asyncio_loop, _stop_event, _watcher_thread
    _asyncio_loop = asyncio.get_running_loop()
    _stop_event = threading.Event()
    _watcher_thread = threading.Thread(
        target=_bank_watcher_loop, args=(_banks_path_arg, _stop_event), daemon=True
    )
    _watcher_thread.start()
    print(f"[WebServer] Started, listening on http://127.0.0.1:{_port_arg}")


@app.on_event("shutdown")
async def _shutdown() -> None:
    if _stop_event:
        _stop_event.set()


@app.get("/", response_class=HTMLResponse)
async def index() -> HTMLResponse:
    """返回前端面板 HTML。"""
    html_path = Path(__file__).parent / "web" / "index.html"
    if html_path.exists():
        return HTMLResponse(html_path.read_text(encoding="utf-8"))
    return HTMLResponse("<h1>web/index.html not found</h1>", status_code=404)


@app.get("/api/state")
async def get_state() -> JSONResponse:
    """获取最新状态 JSON。"""
    with _state_lock:
        if _latest_report is None:
            return JSONResponse({"status": "no_data", "message": "Bank not yet loaded"})
        return JSONResponse(_latest_report)


@app.get("/api/verdict")
async def get_verdict() -> JSONResponse:
    """获取面向脚本的完成度判定。"""
    with _state_lock:
        return JSONResponse(_build_verdict(_latest_report, _last_update_time))


@app.get("/api/events")
async def get_events() -> JSONResponse:
    """获取最近归一化运行时事件。"""
    with _state_lock:
        return JSONResponse({
            "source": "runtime-probe-service",
            "count": len(_latest_events),
            "last_update": _last_update_time.isoformat() if _last_update_time else None,
            "events": list(_latest_events),
        })


@app.get("/api/status")
async def get_status() -> JSONResponse:
    """获取服务、判定和事件状态。"""
    with _state_lock:
        return JSONResponse({
            "source": "runtime-probe-service",
            "health": {
                "status": "ok",
                "bank_loaded": _latest_report is not None,
                "last_update": _last_update_time.isoformat() if _last_update_time else None,
                "last_mtime": _last_bank_mtime,
                "neuro_last_mtime": _last_neuro_bank_mtime,
                "ws_clients": len(_ws_clients),
            },
            "verdict": _build_verdict(_latest_report, _last_update_time),
            "events_count": len(_latest_events),
        })


@app.get("/api/state/md")
async def get_state_md() -> str:
    """获取最新状态 Markdown。"""
    with _state_lock:
        if _latest_report is None:
            return "# No data"
        return report_to_markdown(_latest_report)


@app.get("/api/health")
async def health() -> dict:
    """健康检查。"""
    with _state_lock:
        return {
            "status": "ok",
            "bank_loaded": _latest_report is not None,
            "last_update": _last_update_time.isoformat() if _last_update_time else None,
            "last_mtime": _last_bank_mtime,
            "neuro_last_mtime": _last_neuro_bank_mtime,
            "ws_clients": len(_ws_clients),
        }


@app.websocket("/ws/live")
async def ws_live(ws: WebSocket) -> None:
    """WebSocket 实时推送。客户端连接后立即收到最新状态，之后每次 Bank 更新都推送。"""
    await ws.accept()
    with _ws_lock:
        _ws_clients.add(ws)

    # 立即推送当前状态
    with _state_lock:
        if _latest_report is not None:
            await ws.send_json(_latest_report)

    try:
        while True:
            # 保持连接，等待 Bank 更新广播
            await ws.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        with _ws_lock:
            _ws_clients.discard(ws)


# === 启动参数（全局，供 startup 事件使用）===
_banks_path_arg: str = DEFAULT_BANKS_PATH
_port_arg: int = DEFAULT_PORT
_stop_event: threading.Event | None = None
_watcher_thread: threading.Thread | None = None


def main() -> None:
    global _banks_path_arg, _port_arg

    parser = argparse.ArgumentParser(description="RuntimeProbe Web Server")
    parser.add_argument("--banks-path", default=DEFAULT_BANKS_PATH, help="Banks 目录路径")
    parser.add_argument("--host", default="127.0.0.1", help="监听地址")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="监听端口")
    args = parser.parse_args()

    _banks_path_arg = args.banks_path
    _port_arg = args.port

    import uvicorn

    uvicorn.run(app, host=args.host, port=args.port, log_level="info")


if __name__ == "__main__":
    main()
