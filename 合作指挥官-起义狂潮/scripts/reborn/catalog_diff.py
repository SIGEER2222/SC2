"""Reborn ↔ 7vs1 Catalog 冲突对比工具

比较两个 Mod 集合的有效 Catalog，识别冲突单位/技能/行为等，
生成分类冲突报告。

用法:
    python catalog_diff.py --output reborn-port/diff-report.json
"""

from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

# ---------------------------------------------------------------------------
# 路径配置
# ---------------------------------------------------------------------------
PROJECT_ROOT = Path(__file__).resolve().parents[2]
NATIVE_MODS_ROOT = Path(r"E:\Code\MyMod\SC2\sc2-data-trigger\mods")
STARCOOP_ROOT = PROJECT_ROOT / "游戏数据" / "官方SC2原始文本镜像" / "mods" / "starcoop"
MODS_7VS1 = PROJECT_ROOT / "Mods" / "7vs1"
MODS_REBORN = PROJECT_ROOT / "Mods"

# 基础 SC2 Mod（两组共用）
BASE_MODS = [
    NATIVE_MODS_ROOT / "core.sc2mod",
    NATIVE_MODS_ROOT / "liberty.sc2mod",
    NATIVE_MODS_ROOT / "swarm.sc2mod",
    NATIVE_MODS_ROOT / "void.sc2mod",
    STARCOOP_ROOT / "starcoop.sc2mod",
]

# Reborn 主 Mod（辅助 Mod 是 MPQ 文件，无 XML 可读取）
REBORN_MODS = [
    MODS_REBORN / "crys_the_swarm_reborn.SC2Mod",
]

# 7vs1 Runtime Mod（不含指挥官）
SEVENVS1_RUNTIME_MODS = [
    MODS_7VS1 / "CoopZeroPop.SC2Mod",
    MODS_7VS1 / "ExternalRefs.SC2Mod",
    MODS_7VS1 / "BaseCatalogPatch.SC2Mod",
    MODS_7VS1 / "SharedUnits.SC2Mod",
    MODS_7VS1 / "CommanderBridge.SC2Mod",
    MODS_7VS1 / "CoreRuntime.SC2Mod",
]

# ---------------------------------------------------------------------------
# Catalog 解析
# ---------------------------------------------------------------------------

CATALOG_FILES = {
    "Unit": "UnitData.xml",
    "Ability": "AbilData.xml",
    "Behavior": "BehaviorData.xml",
    "Effect": "EffectData.xml",
    "Weapon": "WeaponData.xml",
    "Upgrade": "UpgradeData.xml",
    "Requirement": "RequirementData.xml",
    "Actor": "ActorData.xml",
    "Button": "ButtonData.xml",
    "Validator": "ValidatorData.xml",
    "Model": "ModelData.xml",
    "Sound": "SoundData.xml",
    "Mover": "MoverData.xml",
    "Tactical": "TacticalData.xml",
}

CATALOG_TAG_PREFIX = {
    "Unit": "CUnit",
    "Ability": "CAbil",
    "Behavior": "CBehavior",
    "Effect": "CEffect",
    "Weapon": "CWeapon",
    "Upgrade": "CUpgrade",
    "Requirement": "CRequirement",
    "Actor": "CActor",
    "Button": "CButton",
    "Validator": "CValidator",
    "Model": "CModel",
    "Sound": "CSound",
    "Mover": "CMover",
    "Tactical": "CTactical",
}


def find_catalog_files(mod_path: Path) -> Dict[str, Optional[Path]]:
    """在 mod 目录中查找所有 catalog XML 文件"""
    result = {}
    data_dir = mod_path / "Base.SC2Data" / "GameData"
    if not data_dir.is_dir():
        return result
    for cat_name, file_name in CATALOG_FILES.items():
        xml_path = data_dir / file_name
        if xml_path.is_file():
            result[cat_name] = xml_path
    return result


def parse_catalog_entries(xml_path: Path, cat_name: str) -> Dict[str, ET.Element]:
    """解析 catalog XML，返回 {id: element} 字典"""
    entries = {}
    try:
        tree = ET.parse(str(xml_path))
        root = tree.getroot()
        prefix = CATALOG_TAG_PREFIX.get(cat_name, "")
        for child in root:
            tag = child.tag
            # 提取 id
            entry_id = child.get("id", "")
            if not entry_id:
                continue
            entries[entry_id] = child
    except ET.ParseError as e:
        print(f"  [WARN] Parse error in {xml_path}: {e}", file=sys.stderr)
    return entries


def load_effective_catalog(mod_paths: List[Path]) -> Dict[str, Dict[str, ET.Element]]:
    """按顺序加载多层 mod，后加载的覆盖先加载的"""
    effective: Dict[str, Dict[str, ET.Element]] = defaultdict(dict)
    for mod_path in mod_paths:
        if not mod_path.exists():
            print(f"  [SKIP] Mod not found: {mod_path}", file=sys.stderr)
            continue
        cat_files = find_catalog_files(mod_path)
        for cat_name, xml_path in cat_files.items():
            entries = parse_catalog_entries(xml_path, cat_name)
            if entries:
                effective[cat_name].update(entries)
                print(f"  [LOAD] {mod_path.name} → {cat_name}: {len(entries)} entries", file=sys.stderr)
    return dict(effective)


def entry_to_hashable(entry: ET.Element) -> str:
    """将 XML element 转为可比较的字符串（忽略 id 属性）"""
    parts = []
    # 排序属性
    for key, val in sorted(entry.attrib.items()):
        if key == "id":
            continue
        parts.append(f"{key}={val}")
    # 排序子元素（按 tag + id）
    children = sorted(entry, key=lambda c: (c.tag, c.get("id", ""), c.get("index", "")))
    for child in children:
        child_attrs = ";".join(
            f"{k}={v}" for k, v in sorted(child.attrib.items())
        )
        parts.append(f"<{child.tag}>{child_attrs}")
    return "|".join(parts)


@dataclass
class CatalogConflict:
    entry_id: str
    cat_name: str
    conflict_type: str  # "redefined", "reborn_only", "7vs1_only"
    reborn_hash: Optional[str] = None
    sevenvs1_hash: Optional[str] = None


@dataclass
class DiffReport:
    reborn_mods: List[str] = field(default_factory=list)
    sevenvs1_mods: List[str] = field(default_factory=list)
    summary: Dict[str, Dict[str, int]] = field(default_factory=dict)
    conflicts: List[CatalogConflict] = field(default_factory=list)
    # 按分类聚合
    by_category: Dict[str, List[CatalogConflict]] = field(default_factory=dict)


def compare_catalogs(
    reborn_cat: Dict[str, Dict[str, ET.Element]],
    sevenvs1_cat: Dict[str, Dict[str, ET.Element]],
) -> DiffReport:
    """比较两个有效 Catalog"""
    report = DiffReport()
    all_cat_names = sorted(set(reborn_cat.keys()) | set(sevenvs1_cat.keys()))

    for cat_name in all_cat_names:
        reborn_entries = reborn_cat.get(cat_name, {})
        sevenvs1_entries = sevenvs1_cat.get(cat_name, {})
        cat_conflicts = []

        all_ids = sorted(set(reborn_entries.keys()) | set(sevenvs1_entries.keys()))
        for entry_id in all_ids:
            in_reborn = entry_id in reborn_entries
            in_sevenvs1 = entry_id in sevenvs1_entries

            if in_reborn and in_sevenvs1:
                # 两者都有，比较内容
                rh = entry_to_hashable(reborn_entries[entry_id])
                sh = entry_to_hashable(sevenvs1_entries[entry_id])
                if rh != sh:
                    conflict = CatalogConflict(
                        entry_id=entry_id,
                        cat_name=cat_name,
                        conflict_type="redefined",
                        reborn_hash=rh[:80],
                        sevenvs1_hash=sh[:80],
                    )
                    cat_conflicts.append(conflict)
            elif in_reborn:
                conflict = CatalogConflict(
                    entry_id=entry_id,
                    cat_name=cat_name,
                    conflict_type="reborn_only",
                )
                cat_conflicts.append(conflict)
            else:
                conflict = CatalogConflict(
                    entry_id=entry_id,
                    cat_name=cat_name,
                    conflict_type="7vs1_only",
                )
                cat_conflicts.append(conflict)

        if cat_conflicts:
            report.by_category[cat_name] = cat_conflicts
            report.conflicts.extend(cat_conflicts)

        # 统计
        report.summary[cat_name] = {
            "total": len(all_ids),
            "redefined": sum(1 for c in cat_conflicts if c.conflict_type == "redefined"),
            "reborn_only": sum(1 for c in cat_conflicts if c.conflict_type == "reborn_only"),
            "7vs1_only": sum(1 for c in cat_conflicts if c.conflict_type == "7vs1_only"),
            "identical": len(all_ids)
            - sum(1 for c in cat_conflicts if c.conflict_type in ("redefined", "reborn_only", "7vs1_only")),
        }

    return report


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Reborn ↔ 7vs1 Catalog 冲突对比")
    parser.add_argument("--output", default=None, help="输出 JSON 路径")
    parser.add_argument("--summary-only", action="store_true", help="仅输出摘要")
    parser.add_argument("--redefined-only", action="store_true", help="仅输出冲突条目")
    args = parser.parse_args()

    reborn_paths = BASE_MODS + REBORN_MODS
    sevenvs1_paths = BASE_MODS + SEVENVS1_RUNTIME_MODS

    print("=" * 60, file=sys.stderr)
    print("Loading Reborn catalog...", file=sys.stderr)
    reborn_cat = load_effective_catalog(reborn_paths)

    print("", file=sys.stderr)
    print("Loading 7vs1 catalog...", file=sys.stderr)
    sevenvs1_cat = load_effective_catalog(sevenvs1_paths)

    print("", file=sys.stderr)
    print("Comparing catalogs...", file=sys.stderr)
    report = compare_catalogs(reborn_cat, sevenvs1_cat)
    report.reborn_mods = [m.name for m in REBORN_MODS]
    report.sevenvs1_mods = [m.name for m in SEVENVS1_RUNTIME_MODS]

    # 输出摘要
    print("", file=sys.stderr)
    print("=" * 60, file=sys.stderr)
    print("CONFLICT SUMMARY", file=sys.stderr)
    print("=" * 60, file=sys.stderr)

    total_redefined = 0
    total_reborn_only = 0
    total_7vs1_only = 0

    for cat_name in sorted(report.summary.keys()):
        s = report.summary[cat_name]
        total_redefined += s["redefined"]
        total_reborn_only += s["reborn_only"]
        total_7vs1_only += s["7vs1_only"]
        print(
            f"  {cat_name:15s}: total={s['total']:5d}  "
            f"redefined={s['redefined']:5d}  "
            f"reborn_only={s['reborn_only']:5d}  "
            f"7vs1_only={s['7vs1_only']:5d}  "
            f"identical={s['identical']:5d}",
            file=sys.stderr,
        )

    print("", file=sys.stderr)
    print(
        f"  TOTAL: redefined={total_redefined}  "
        f"reborn_only={total_reborn_only}  "
        f"7vs1_only={total_7vs1_only}",
        file=sys.stderr,
    )

    # 输出 JSON
    output = {
        "reborn_mods": report.reborn_mods,
        "sevenvs1_mods": report.sevenvs1_mods,
        "summary": report.summary,
    }

    if not args.summary_only:
        if args.redefined_only:
            output["conflicts"] = [
                asdict(c)
                for c in report.conflicts
                if c.conflict_type == "redefined"
            ]
        else:
            output["conflicts"] = [asdict(c) for c in report.conflicts]
            output["by_category"] = {
                k: [asdict(c) for c in v]
                for k, v in report.by_category.items()
            }

    if args.output:
        output_path = Path(args.output)
        if not output_path.parent.exists():
            output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(output, f, ensure_ascii=False, indent=2)
        print(f"\nReport written to: {output_path}", file=sys.stderr)
    else:
        json.dump(output, sys.stdout, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()