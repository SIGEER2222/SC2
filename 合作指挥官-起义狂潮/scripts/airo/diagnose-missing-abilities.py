#!/usr/bin/env python3
"""
诊断脚本：扫描所有指挥官单位的技能引用，找出缺失的技能定义。

用法：
    python scripts/airo/diagnose-missing-abilities.py

输出：
    - 每个指挥官的缺失技能列表
    - 生产链断裂点（Build/Train 引用不存在的单位）
    - 汇总统计
"""

import os
import re
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

# 项目根目录
PROJECT_ROOT = Path(r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮")
MODS_DIR = PROJECT_ROOT / "Mods" / "7vs1"
AIRO_DIR = PROJECT_ROOT / "Mods" / "AIRO"

# 技能定义标签（所有 CAbil* 类型）
ABIL_TAGS = {
    "CAbilBuild", "CAbilTrain", "CAbilMorph", "CAbilMorphPlacement",
    "CAbilEffectTarget", "CAbilEffectInstant", "CAbilAttack",
    "CAbilMove", "CAbilStop", "CAbilHoldPosition", "CAbilAcquire",
    "CAbilRally", "CAbilQueue", "CAbilCargo", "CAbilLoad",
    "CAbilTransport", "CAbilRallyPort", "CAbilScanMove",
    "CAbilBeacon", "CAbilToggle", "CAbilInteract",
    "CAbilWarpable", "CAbilMerge", "CAbilSplit",
    "CAbilRam", "CAbilCloakField", "CAbilWeapon",
    "CAbilCombine", "CAbilExtractor",
}

def extract_abil_ids(xml_path):
    """从 XML 文件中提取所有技能定义 ID"""
    ids = set()
    try:
        # 使用正则提取，避免 XML 解析错误
        with open(xml_path, "r", encoding="utf-8") as f:
            content = f.read()
        # 匹配 <CAbil* id="XXX" ...> 模式
        pattern = r'<(CAbil\w+)\s+id="([^"]+)"'
        for match in re.finditer(pattern, content):
            ids.add(match.group(2))
    except Exception as e:
        print(f"  [WARN] 读取 {xml_path} 失败: {e}")
    return ids

def extract_unit_abil_refs(xml_path):
    """从 UnitData XML 中提取每个单位引用的技能列表"""
    refs = defaultdict(list)
    try:
        with open(xml_path, "r", encoding="utf-8") as f:
            content = f.read()
        # 匹配 <CUnit id="XXX" ...> ... <AbilArray Link="YYY" .../> ... </CUnit>
        pattern = r'<CUnit\s+id="([^"]+)"[^>]*>(.*?)</CUnit>'
        for match in re.finditer(pattern, content, re.DOTALL):
            unit_id = match.group(1)
            unit_body = match.group(2)
            # 提取 AbilArray Link
            for abil_match in re.finditer(r'<AbilArray\s+Link="([^"]+)"', unit_body):
                refs[unit_id].append(abil_match.group(1))
    except Exception as e:
        print(f"  [WARN] 读取 {xml_path} 失败: {e}")
    return refs

def extract_build_unit_refs(xml_path):
    """从 AbilData 中提取 Build/Train 技能引用的单位 ID"""
    refs = defaultdict(list)
    try:
        with open(xml_path, "r", encoding="utf-8") as f:
            content = f.read()
        # 匹配 CAbilBuild/CAbilTrain 中的 InfoArray Unit 引用
        pattern = r'<(CAbil(?:Build|Train))\s+id="([^"]+)"[^>]*>(.*?)</\1>'
        for match in re.finditer(pattern, content, re.DOTALL):
            abil_type = match.group(1)
            abil_id = match.group(2)
            abil_body = match.group(3)
            # 提取 Unit="XXX" 引用
            for unit_match in re.finditer(r'<InfoArray[^>]*Unit="([^"]+)"', abil_body):
                refs[abil_id].append(unit_match.group(1))
    except Exception as e:
        print(f"  [WARN] 读取 {xml_path} 失败: {e}")
    return refs

def scan_all_abil_defs():
    """扫描项目中所有技能定义"""
    all_abils = set()
    scan_dirs = [
        MODS_DIR,
        PROJECT_ROOT / "Mods" / "AIRO",
    ]
    for scan_dir in scan_dirs:
        if not scan_dir.exists():
            continue
        for xml_file in scan_dir.rglob("*.xml"):
            if "GameData" in str(xml_file):
                abils = extract_abil_ids(xml_file)
                all_abils.update(abils)
    return all_abils

def scan_commander_mods():
    """扫描所有指挥官 mod"""
    commanders = {}
    for mod_dir in sorted(MODS_DIR.iterdir()):
        if not mod_dir.is_dir():
            continue
        if not mod_dir.name.startswith("CommanderUnits_"):
            continue
        cmd_name = mod_dir.name.replace("CommanderUnits_", "").replace(".SC2Mod", "")
        gd_dir = mod_dir / "Base.SC2Data" / "GameData"
        if not gd_dir.exists():
            continue

        commanders[cmd_name] = {
            "mod_dir": mod_dir,
            "unit_files": list(gd_dir.glob("UnitData*.xml")),
            "abil_files": list(gd_dir.glob("AbilData*.xml")),
            "unit_refs": {},
            "build_refs": {},
            "local_abils": set(),
        }

        # 提取本地技能定义
        for abil_file in commanders[cmd_name]["abil_files"]:
            commanders[cmd_name]["local_abils"].update(extract_abil_ids(abil_file))

        # 提取单位技能引用
        for unit_file in commanders[cmd_name]["unit_files"]:
            refs = extract_unit_abil_refs(unit_file)
            commanders[cmd_name]["unit_refs"].update(refs)

        # 提取 Build/Train 引用的单位
        for abil_file in commanders[cmd_name]["abil_files"]:
            refs = extract_build_unit_refs(abil_file)
            commanders[cmd_name]["build_refs"].update(refs)

    return commanders

def scan_base_units():
    """扫描基础单位定义"""
    base_units = set()
    # 检查 BaseCatalogPatch 和 SharedUnits
    for mod_name in ["BaseCatalogPatch.SC2Mod", "SharedUnits.SC2Mod", "CoreRuntime.SC2Mod"]:
        mod_dir = MODS_DIR / mod_name
        if not mod_dir.exists():
            continue
        gd_dir = mod_dir / "Base.SC2Data" / "GameData"
        if not gd_dir.exists():
            continue
        for xml_file in gd_dir.glob("UnitData*.xml"):
            try:
                with open(xml_file, "r", encoding="utf-8") as f:
                    content = f.read()
                for match in re.finditer(r'<CUnit\s+id="([^"]+)"', content):
                    base_units.add(match.group(1))
            except Exception:
                pass
    return base_units

def main():
    print("=" * 70)
    print("指挥官技能缺失诊断工具")
    print("=" * 70)

    # 1. 扫描所有技能定义
    print("\n[1] 扫描项目中所有技能定义...")
    all_abils = scan_all_abil_defs()
    print(f"    总技能定义数: {len(all_abils)}")

    # 2. 扫描所有指挥官 mod
    print("\n[2] 扫描所有指挥官 mod...")
    commanders = scan_commander_mods()
    print(f"    发现 {len(commanders)} 个指挥官 mod:")
    for name, data in commanders.items():
        print(f"      {name}: {len(data['unit_refs'])} 单位, "
              f"{len(data['local_abils'])} 本地技能")

    # 3. 扫描基础单位
    print("\n[3] 扫描基础单位定义...")
    base_units = scan_base_units()
    print(f"    基础单位数: {len(base_units)}")

    # 4. 诊断每个指挥官
    print("\n" + "=" * 70)
    print("[4] 诊断结果")
    print("=" * 70)

    total_missing = 0
    total_broken_chains = 0
    report_lines = []

    for cmd_name, data in sorted(commanders.items()):
        missing_abils = set()
        broken_chains = []

        # 检查每个单位的技能引用
        for unit_id, abil_refs in data["unit_refs"].items():
            for abil_id in abil_refs:
                if abil_id not in all_abils:
                    missing_abils.add(abil_id)
                    report_lines.append(f"  [{cmd_name}] 单位 {unit_id} 引用缺失技能: {abil_id}")

        # 检查 Build/Train 引用的单位是否存在
        all_known_units = base_units.copy()
        for cd in commanders.values():
            for unit_file in cd["unit_files"]:
                try:
                    with open(unit_file, "r", encoding="utf-8") as f:
                        content = f.read()
                    for match in re.finditer(r'<CUnit\s+id="([^"]+)"', content):
                        all_known_units.add(match.group(1))
                except Exception:
                    pass

        for abil_id, unit_refs in data["build_refs"].items():
            for unit_ref in unit_refs:
                if unit_ref not in all_known_units:
                    broken_chains.append((abil_id, unit_ref))
                    report_lines.append(f"  [{cmd_name}] 技能 {abil_id} 引用不存在的单位: {unit_ref}")

        if missing_abils or broken_chains:
            print(f"\n--- {cmd_name} ---")
            print(f"  缺失技能: {len(missing_abils)} 个")
            if missing_abils:
                for abil in sorted(missing_abils):
                    print(f"    - {abil}")
            print(f"  断裂生产链: {len(broken_chains)} 处")
            if broken_chains:
                for abil, unit in broken_chains:
                    print(f"    - {abil} -> {unit}")
            total_missing += len(missing_abils)
            total_broken_chains += len(broken_chains)
        else:
            print(f"\n--- {cmd_name} --- OK (无缺失)")

    # 5. 汇总
    print("\n" + "=" * 70)
    print("[5] 汇总")
    print("=" * 70)
    print(f"  总缺失技能数: {total_missing}")
    print(f"  总断裂生产链数: {total_broken_chains}")

    # 6. 输出详细报告到文件
    report_path = PROJECT_ROOT / "scripts" / "airo" / "diagnosis-report.txt"
    with open(report_path, "w", encoding="utf-8") as f:
        f.write("指挥官技能缺失诊断报告\n")
        f.write(f"{'=' * 70}\n\n")
        f.write(f"总缺失技能数: {total_missing}\n")
        f.write(f"总断裂生产链数: {total_broken_chains}\n\n")
        f.write("详细列表:\n")
        for line in report_lines:
            f.write(line + "\n")
    print(f"\n详细报告已保存到: {report_path}")

if __name__ == "__main__":
    main()
