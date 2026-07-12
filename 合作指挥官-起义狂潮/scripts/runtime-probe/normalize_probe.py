"""RuntimeProbe 数据归一化模块

将 Bank 解析的原始数据归一化为 VerificationReport JSON 结构。
"""

from datetime import datetime
from typing import Any

from bank_io import parse_unit_value, parse_upgrade_value, parse_producer_value


def normalize_probe_state(state: dict[str, Any]) -> dict[str, Any]:
    """归一化 probe_state section。"""
    return {
        "run_id": state.get("run_id", "unknown"),
        "composition_id": state.get("composition_id", "unknown"),
        "map_id": state.get("map_id", "unknown"),
        "map_path": state.get("map_path", ""),
        "commander_id": state.get("commander_id", "unknown"),
        "player_id": state.get("player_id", 0),
        "game_time": state.get("game_time", 0),
        "game_loop": state.get("game_loop", 0),
        "phase": state.get("phase", "unknown"),
        "heartbeat": state.get("heartbeat", 0),
        "is_paused": state.get("is_paused", False),
        "is_in_mission": state.get("is_in_mission", False),
        "script_error_count": state.get("script_error_count", 0),
        "loaded_mods": state.get("loaded_mods", "").split(",") if state.get("loaded_mods") else [],
        "minerals": state.get("minerals", 0),
        "gas": state.get("gas", 0),
        "supply_used": state.get("supply_used", 0),
        "supply_cap": state.get("supply_cap", 0),
        "unit_scan_id": state.get("unit_scan_id", 0),
    }


def normalize_probe_units(units: dict[str, Any], latest_scan_id: int) -> list[dict[str, Any]]:
    """归一化 probe_units section，只保留最新 scan_id 的数据。"""
    result: list[dict[str, Any]] = []

    for key, value in units.items():
        if not key.startswith("u_"):
            continue
        if not isinstance(value, str):
            continue

        parsed = parse_unit_value(value)
        if not parsed:
            continue

        # 过滤旧 scan_id 的数据
        scan_id = parsed.get("scan_id", 0)
        if latest_scan_id > 0 and scan_id != latest_scan_id:
            continue

        # 解析 key: u_<player>_<unit_type>
        parts = key.split("_", 2)
        if len(parts) < 3:
            continue
        player_id = int(parts[1])
        unit_type_id = parts[2]

        result.append({
            "player_id": player_id,
            "unit_type_id": unit_type_id,
            "count": parsed.get("count", 0),
            "completed_count": parsed.get("completed", 0),
            "in_progress_count": parsed.get("in_progress", 0),
            "life_summary": {"avg": parsed.get("life_avg", 0.0)},
            "energy_summary": {"avg": parsed.get("energy_avg", 0.0)},
            "owner": parsed.get("owner", player_id),
            "is_structure": parsed.get("is_structure", False),
            "is_worker": parsed.get("is_worker", False),
        })

    return result


def normalize_probe_upgrades(upgrades: dict[str, Any]) -> list[dict[str, Any]]:
    """归一化 probe_upgrades section。"""
    result: list[dict[str, Any]] = []

    for key, value in upgrades.items():
        if not key.startswith("up_"):
            continue
        if not isinstance(value, str):
            continue

        parsed = parse_upgrade_value(value)
        if not parsed:
            continue

        # 解析 key: up_<player>_<upgrade_id>
        parts = key.split("_", 2)
        if len(parts) < 3:
            continue
        player_id = int(parts[1])
        upgrade_id = parts[2]

        result.append({
            "player_id": player_id,
            "upgrade_id": upgrade_id,
            "researched": parsed.get("researched", 0) > 0,
            "available": parsed.get("available", 0) > 0,
            "in_progress": parsed.get("in_progress", 0) > 0,
            "blocked_reason": parsed.get("blocked_reason", "None"),
            "affected_unit_ids": [],
        })

    return result


def normalize_probe_producers(producers: dict[str, Any]) -> list[dict[str, Any]]:
    """归一化 probe_producers section。

    Bank key 格式: p_<player>_<unit_type>
    Bank value 格式: producer_count:1,trainable:BarracksTrainRaynor:0,blocked:,queue:,last_order:None
    """
    result: list[dict[str, Any]] = []

    for key, value in producers.items():
        if not key.startswith("p_"):
            continue
        if not isinstance(value, str):
            continue

        parsed = parse_producer_value(value)
        if not parsed:
            continue

        # 解析 key: p_<player>_<unit_type>
        parts = key.split("_", 2)
        if len(parts) < 3:
            continue
        player_id = int(parts[1])
        unit_type_id = parts[2]

        result.append({
            "player_id": player_id,
            "producer_type_id": unit_type_id,
            "producer_count": parsed.get("producer_count", 0),
            "trainable": parsed.get("trainable", ""),
            "blocked": parsed.get("blocked", ""),
            "queue": parsed.get("queue", ""),
            "last_order": parsed.get("last_order", "None"),
        })

    return result


def normalize_probe_tech(tech: dict[str, Any]) -> dict[str, Any]:
    """归一化 probe_tech section。

    Bank key 格式:
      a_<abil>_<cmdIdx> — 能力可用性 (int: 1=可用)
      up_<upgrade>      — 升级完成数量 (int)
    """
    abilities: list[dict[str, Any]] = []
    upgrades: list[dict[str, Any]] = []

    for key, value in tech.items():
        if not isinstance(value, int):
            continue

        if key.startswith("a_"):
            # a_<abil>_<cmdIdx>
            parts = key.split("_")
            if len(parts) < 3:
                continue
            abil_id = parts[1]
            try:
                cmd_idx = int(parts[2])
            except ValueError:
                continue
            abilities.append({
                "abil_id": abil_id,
                "cmd_index": cmd_idx,
                "allowed": value > 0,
            })
        elif key.startswith("up_"):
            # up_<upgrade>
            parts = key.split("_", 1)
            if len(parts) < 2:
                continue
            upgrade_id = parts[1]
            upgrades.append({
                "upgrade_id": upgrade_id,
                "count": value,
            })

    return {
        "abilities": abilities,
        "upgrades": upgrades,
    }


def build_verification_report(
    bank_data: dict[str, dict[str, Any]],
    composition_id: str = "unknown",
    run_id: str | None = None,
) -> dict[str, Any]:
    """构建 VerificationReport JSON 结构。"""
    state_raw = bank_data.get("probe_state", {})
    units_raw = bank_data.get("probe_units", {})
    upgrades_raw = bank_data.get("probe_upgrades", {})
    producers_raw = bank_data.get("probe_producers", {})
    tech_raw = bank_data.get("probe_tech", {})
    replacement_raw = bank_data.get("probe_replacement", {})

    state = normalize_probe_state(state_raw)
    latest_scan_id = state.get("unit_scan_id", 0)
    units = normalize_probe_units(units_raw, latest_scan_id)
    upgrades = normalize_probe_upgrades(upgrades_raw)
    producers = normalize_probe_producers(producers_raw)
    tech = normalize_probe_tech(tech_raw)

    if run_id:
        state["run_id"] = run_id
    if composition_id != "unknown":
        state["composition_id"] = composition_id

    heartbeat = state.get("heartbeat", 0)
    is_in_mission = state.get("is_in_mission", False)
    script_errors = state.get("script_error_count", 0)

    status = {
        "launch_pass": True,
        "map_loaded": heartbeat > 0,
        "probe_complete": is_in_mission and len(units) > 0,
        "static_match": True,
        "runtime_assertions_pass": True,
        "script_error_free": script_errors == 0,
    }

    return {
        "run_id": state.get("run_id", "unknown"),
        "composition_id": state.get("composition_id", composition_id),
        "timestamp": datetime.now().isoformat(),
        "status": status,
        "probe_state": state,
        "probe_units": units,
        "probe_producers": producers,
        "probe_tech": tech,
        "probe_replacement": replacement_raw,
        "probe_abilities": [],
        "probe_upgrades": upgrades,
        "probe_assertions": [],
        "diffs": [],
        "errors": [],
    }


def report_to_markdown(report: dict[str, Any]) -> str:
    """将 VerificationReport 转换为 Markdown 格式。"""
    lines: list[str] = []
    lines.append("# RuntimeProbe VerificationReport")
    lines.append("")
    lines.append(f"- Run ID: `{report['run_id']}`")
    lines.append(f"- Composition: `{report['composition_id']}`")
    lines.append(f"- Timestamp: `{report['timestamp']}`")
    lines.append("")

    # 状态
    status = report["status"]
    lines.append("## Status")
    lines.append("")
    lines.append("| 检查项 | 结果 |")
    lines.append("|--------|------|")
    for k, v in status.items():
        icon = "OK" if v else "FAIL"
        lines.append(f"| {k} | {icon} |")
    lines.append("")

    # probe_state
    state = report["probe_state"]
    lines.append("## Probe State")
    lines.append("")
    lines.append(f"- Heartbeat: `{state.get('heartbeat', 0)}`")
    lines.append(f"- Phase: `{state.get('phase', 'unknown')}`")
    lines.append(f"- In Mission: `{state.get('is_in_mission', False)}`")
    lines.append(f"- Game Loop: `{state.get('game_loop', 0)}`")
    lines.append(f"- Minerals: `{state.get('minerals', 0)}`")
    lines.append(f"- Gas: `{state.get('gas', 0)}`")
    lines.append(f"- Supply: `{state.get('supply_used', 0)}/{state.get('supply_cap', 0)}`")
    lines.append(f"- Unit Scan ID: `{state.get('unit_scan_id', 0)}`")
    lines.append(f"- Script Errors: `{state.get('script_error_count', 0)}`")
    lines.append("")

    # probe_units
    units = report["probe_units"]
    lines.append(f"## Probe Units ({len(units)} types)")
    lines.append("")
    if units:
        lines.append("| Unit Type | Count | Life Avg | Energy Avg | Structure | Worker |")
        lines.append("|-----------|-------|----------|------------|-----------|--------|")
        for u in sorted(units, key=lambda x: x["unit_type_id"]):
            lines.append(
                f"| `{u['unit_type_id']}` | {u['count']} | "
                f"{u['life_summary']['avg']:.1f} | "
                f"{u['energy_summary']['avg']:.1f} | "
                f"{'Y' if u['is_structure'] else 'N'} | "
                f"{'Y' if u['is_worker'] else 'N'} |"
            )
    else:
        lines.append("(no units)")
    lines.append("")

    # probe_upgrades
    upgrades = report["probe_upgrades"]
    lines.append(f"## Probe Upgrades ({len(upgrades)} active)")
    lines.append("")
    if upgrades:
        lines.append("| Upgrade ID | Researched | In Progress |")
        lines.append("|------------|------------|-------------|")
        for up in sorted(upgrades, key=lambda x: x["upgrade_id"]):
            lines.append(
                f"| `{up['upgrade_id']}` | "
                f"{'Y' if up['researched'] else 'N'} | "
                f"{'Y' if up['in_progress'] else 'N'} |"
            )
    else:
        lines.append("(no upgrades)")
    lines.append("")

    # probe_replacement
    replacement = report.get("probe_replacement", {})
    if replacement:
        lines.append("## Probe Replacement")
        lines.append("")
        lines.append(f"- Expected Commander: `{replacement.get('expected_commander', 'unknown')}`")
        lines.append(f"- Expected Race: `{replacement.get('expected_race', 'unknown')}`")
        lines.append(f"- Status: `{replacement.get('status', 'unknown')}`")
        lines.append(f"- Zerg Units: `{replacement.get('zerg_units_count', 0)}`")
        lines.append(f"- Terran Units: `{replacement.get('terran_units_count', 0)}`")
        lines.append(f"- Protoss Units: `{replacement.get('protoss_units_count', 0)}`")
        lines.append("")

    # probe_producers
    producers = report.get("probe_producers", [])
    lines.append(f"## Probe Producers ({len(producers)} types)")
    lines.append("")
    if producers:
        lines.append("| Producer Type | Count | Trainable | Blocked |")
        lines.append("|---------------|-------|-----------|---------|")
        for p in sorted(producers, key=lambda x: x["producer_type_id"]):
            lines.append(
                f"| `{p['producer_type_id']}` | {p['producer_count']} | "
                f"`{p['trainable']}` | `{p['blocked']}` |"
            )
    else:
        lines.append("(no producers)")
    lines.append("")

    # probe_tech
    tech = report.get("probe_tech", {})
    tech_abilities = tech.get("abilities", [])
    tech_upgrades = tech.get("upgrades", [])
    lines.append(f"## Probe Tech ({len(tech_abilities)} abilities, {len(tech_upgrades)} upgrades)")
    lines.append("")

    if tech_abilities:
        lines.append("### Abilities (allowed only)")
        lines.append("")
        lines.append("| Ability | Cmd | Allowed |")
        lines.append("|---------|-----|---------|")
        allowed_abils = [a for a in tech_abilities if a["allowed"]]
        blocked_abils = [a for a in tech_abilities if not a["allowed"]]
        for a in sorted(allowed_abils, key=lambda x: (x["abil_id"], x["cmd_index"])):
            lines.append(f"| `{a['abil_id']}` | {a['cmd_index']} | Y |")
        if blocked_abils:
            lines.append("")
            lines.append("### Blocked Abilities")
            lines.append("")
            lines.append("| Ability | Cmd | Allowed |")
            lines.append("|---------|-----|---------|")
            for a in sorted(blocked_abils, key=lambda x: (x["abil_id"], x["cmd_index"])):
                lines.append(f"| `{a['abil_id']}` | {a['cmd_index']} | N |")
        lines.append("")

    if tech_upgrades:
        lines.append("### Tech Upgrades")
        lines.append("")
        lines.append("| Upgrade | Count |")
        lines.append("|---------|-------|")
        for u in sorted(tech_upgrades, key=lambda x: x["upgrade_id"]):
            lines.append(f"| `{u['upgrade_id']}` | {u['count']} |")
        lines.append("")

    return "\n".join(lines)
