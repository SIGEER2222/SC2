"""验证 RuntimeProbe schema 合法性 + 最小诊断案例覆盖能力"""
import json
import sys
from pathlib import Path

schema_path = Path(__file__).parent / "schemas" / "runtime-probe.schema.json"
schema = json.loads(schema_path.read_text(encoding="utf-8"))
print("[OK] schema JSON 解析成功")
title = schema.get("title", "")
defs = list(schema.get("$defs", {}).keys())
print(f"  title: {title}")
print(f"  defs: {defs}")

try:
    import jsonschema
    print("[OK] jsonschema 库可用")
except ImportError:
    print("[INFO] jsonschema 库未安装，跳过深度校验")
    sys.exit(0)

# 构造最小诊断案例的样例报告
sample = {
    "run_id": "run-20260712-0001",
    "composition_id": "raynor-traynor01-7vs1",
    "timestamp": "2026-07-12T15:30:00",
    "status": {
        "launch_pass": True,
        "map_loaded": True,
        "probe_complete": True,
        "static_match": True,
        "runtime_assertions_pass": True,
        "script_error_free": True,
    },
    "probe_state": {
        "run_id": "run-20260712-0001",
        "composition_id": "raynor-traynor01-7vs1",
        "map_id": "traynor01_7vs1",
        "commander_id": "Raynor",
        "player_id": 1,
        "game_time": 15,
        "game_loop": 960,
        "phase": "in_mission",
        "heartbeat": 15,
        "is_paused": False,
        "is_in_mission": True,
        "script_error_count": 0,
        "loaded_mods": ["CoreRuntime", "Raynor", "7vs1"],
    },
    "probe_units": [
        {"player_id": 1, "unit_type_id": "SCVRaynor", "count": 12, "completed_count": 12, "in_progress_count": 0, "is_structure": False, "is_worker": True},
        {"player_id": 1, "unit_type_id": "BarracksRaynor", "count": 1, "completed_count": 1, "in_progress_count": 0, "is_structure": True, "is_worker": False},
        {"player_id": 1, "unit_type_id": "MarineRaynor", "count": 3, "completed_count": 3, "in_progress_count": 0, "is_structure": False, "is_worker": False},
    ],
    "probe_producers": [
        {"player_id": 1, "producer_catalog_id": "BarracksRaynor", "producer_count": 1, "trainable_unit_ids": ["MarineRaynor", "MarauderRaynor"], "blocked_unit_ids": [], "active_queue": [], "last_order_ability": ""},
        {"player_id": 1, "producer_catalog_id": "FactoryRaynor", "producer_count": 1, "trainable_unit_ids": ["VultureRaynor", "SiegeTankRaynor"], "blocked_unit_ids": [], "active_queue": [], "last_order_ability": ""},
    ],
    "probe_assertions": [
        {"assertion_id": "raynor_marine_trainable", "severity": "critical", "status": "pass", "expected": "MarineRaynor", "actual": "MarineRaynor", "message": "BarracksRaynor can train MarineRaynor", "source": "probe_producers"},
        {"assertion_id": "raynor_vulture_trainable", "severity": "critical", "status": "pass", "expected": "VultureRaynor", "actual": "VultureRaynor", "message": "FactoryRaynor can train VultureRaynor", "source": "probe_producers"},
    ],
    "diffs": [
        {"producer": "BarracksRaynor", "expected_from_datacenter": ["MarineRaynor", "MarauderRaynor"], "static_effective_catalog": ["MarineRaynor", "MarauderRaynor"], "runtime_observed": ["MarineRaynor", "MarauderRaynor"], "match": True, "mismatch_type": "none"},
        {"producer": "FactoryRaynor", "expected_from_datacenter": ["VultureRaynor", "SiegeTankRaynor"], "static_effective_catalog": ["VultureRaynor", "SiegeTankRaynor"], "runtime_observed": ["VultureRaynor", "SiegeTankRaynor"], "match": True, "mismatch_type": "none"},
    ],
}

try:
    jsonschema.validate(instance=sample, schema=schema)
    print("[OK] 样例报告通过 schema 校验")
    print(f"  probe_units: {len(sample['probe_units'])} 项")
    print(f"  probe_producers: {len(sample['probe_producers'])} 项")
    print(f"  probe_assertions: {len(sample['probe_assertions'])} 项")
    print(f"  diffs: {len(sample['diffs'])} 项")
    print("[OK] 协议能覆盖 Raynor Marine/Marauder/Vulture 最小诊断案例")
except jsonschema.ValidationError as e:
    print(f"[FAIL] schema 校验失败: {e.message}")
    print(f"  path: {list(e.absolute_path)}")
    sys.exit(1)
