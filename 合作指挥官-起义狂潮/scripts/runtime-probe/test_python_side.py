"""Python 端快速验证：用模拟 Bank 文件测试解析和归一化"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from bank_io import parse_bank_file, write_bank_values
from normalize_probe import build_verification_report, report_to_markdown

# 创建模拟 Bank 文件
bank_path = Path(__file__).parent / "test_mock.SC2Bank"
mock_data = {
    "probe_state": {
        "run_id": "run-20260712-0001",
        "heartbeat": 15,
        "phase": "in_mission",
        "is_in_mission": True,
        "is_paused": False,
        "game_loop": 960,
        "player_id": 1,
        "minerals": 500,
        "gas": 200,
        "supply_used": 15,
        "supply_cap": 27,
        "script_error_count": 0,
        "unit_scan_id": 7,
    },
    "probe_units": {
        "u_1_SCVRaynor": "count:12,completed:12,in_progress:0,life_avg:45.0,energy_avg:0.0,owner:1,scan_id:7",
        "u_1_BarracksRaynor": "count:1,completed:1,in_progress:0,life_avg:1500.0,energy_avg:0.0,owner:1,scan_id:7",
        "u_1_MarineRaynor": "count:3,completed:3,in_progress:0,life_avg:45.0,energy_avg:0.0,owner:1,scan_id:7",
        "u_1_OldUnit": "count:2,completed:2,in_progress:0,life_avg:50.0,energy_avg:0.0,owner:1,scan_id:6",
    },
    "probe_upgrades": {
        "up_1_TerranInfantryWeaponsLevel1": "upgrade_id:TerranInfantryWeaponsLevel1,researched:1,in_progress:0,available:1,blocked_reason:None",
    },
}
write_bank_values(bank_path, mock_data)
print("[OK] Mock bank file created")

# 解析
parsed = parse_bank_file(bank_path)
print(f"[OK] Parsed sections: {list(parsed.keys())}")

# 归一化
report = build_verification_report(parsed, composition_id="raynor-7vs1", run_id="run-20260712-0001")
print("[OK] Report built")
status = report["status"]
print(f"  status: {status}")
units = report["probe_units"]
upgrades = report["probe_upgrades"]
print(f"  units: {len(units)} (should be 3, scan_id=7 filters out OldUnit)")
print(f"  upgrades: {len(upgrades)}")

# 验证 scan_id 过滤
unit_types = [u["unit_type_id"] for u in units]
assert "OldUnit" not in unit_types, "OldUnit should be filtered out by scan_id"
assert "SCVRaynor" in unit_types
assert "BarracksRaynor" in unit_types
assert "MarineRaynor" in unit_types
print(f"[OK] scan_id filter works: {unit_types}")

# Markdown 输出
md = report_to_markdown(report)
print(f"[OK] Markdown report: {len(md)} chars")
print()
print("=== Markdown Preview (first 800 chars) ===")
print(md[:800])

# 清理
bank_path.unlink()
print()
print("[OK] All Python-side tests passed")
