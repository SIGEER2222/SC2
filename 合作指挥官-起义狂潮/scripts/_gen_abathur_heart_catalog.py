"""扫描 C:\\Users\\22448\\Downloads\\阿巴瑟之心\\Mods 下的所有 mod，
按"指挥官"分组提取 UnitData.xml 中的自定义单位列表，
生成 LibAbathurHeartCatalog.galaxy。

分组规则（方案 A + B 混合）:
  - 单指挥官 mod（Alenger 系列、CM_Core_Zhelus、Ihanrii、Moebius）:
    1 个 mod = 1 个指挥官组
  - 共享库 mod（VioletsHoTSReworkMod）:
    用 ID 关键字拆分成多个子指挥官组 + 1 个共享组
  - 跳过的 mod（6阿巴瑟之心/AlengerBGM/通用效果）:
    纯依赖/音乐/效果 mod，不生成组

输出:
  - Base.SC2Data\\LibAbathurHeartCatalog.galaxy  (galaxy 库)
  - docs/阿巴瑟之心mod扫描报告.md  (扫描摘要)
"""
from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import List, Tuple

try:
    from mpyq import MPQArchive
except ImportError:
    MPQArchive = None  # 仅在解包 MPQ 时需要

# ---------------------------------------------------------------------------
# 路径配置
# ---------------------------------------------------------------------------
SOURCE_MODS_ROOT = Path(r"C:\Users\22448\Downloads\阿巴瑟之心\Mods")
WORKSPACE_ROOT = Path(r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮")
NEW_MAP_DIR = WORKSPACE_ROOT / "Maps" / "AbathurHeartTest_unpacked"
OUTPUT_LIB = NEW_MAP_DIR / "Base.SC2Data" / "LibAbathurHeartCatalog.galaxy"
REPORT_PATH = WORKSPACE_ROOT / "docs" / "阿巴瑟之心mod扫描报告.md"

# ---------------------------------------------------------------------------
# 过滤规则
# ---------------------------------------------------------------------------
BASE_RACE_UNITS = {
    "Drone", "Overlord", "OverlordTransport", "OverlordCocoon",
    "OverlordTransportCocoon", "Overseer", "OverseerCocoon",
    "OverseerTransport", "OverseerTransportCocoon", "Larva", "Egg", "Cocoon",
    "Changeling", "ChangelingMarine", "ChangelingMarineShield",
    "ChangelingZealot", "ChangelingZergling", "ChangelingZerglingWings",
    "Zergling", "Baneling", "BanelingBurrowed", "Roach", "RoachBurrowed",
    "RoachCorpserBurrowed", "RoachVileBurrowed", "RavagerBurrowed",
    "PrimalRoachBurrowed", "Hydralisk", "HydraliskBurrowed", "Lurker",
    "LurkerBurrowed", "LurkerCocoon", "SwarmHost", "SwarmHostBurrowed",
    "Locust", "LocustFlying", "BroodLord", "BroodLordCocoon", "Corruptor",
    "Broodling", "BroodlingEscort", "Infestor", "InfestorBurrowed",
    "Ultralisk", "Viper", "DefilerMound", "HydraliskDen", "LurkerDen",
    "SpawningPool", "SpineCrawler", "SpineCrawlerUprooted", "SporeCrawler",
    "SporeCrawlerUprooted", "EvolutionChamber", "Spire", "GreaterSpire",
    "NydusNetwork", "NydusCanal", "GreaterNydusWorm", "UltraliskCavern",
    "CreepTumor", "Hatchery", "Lair", "Hive", "Extractor", "SCV", "Marine",
    "Marauder", "Reaper", "Ghost", "GhostAcademy", "Barracks", "Factory",
    "Starport", "SupplyDepot", "Bunker", "EngineeringBay", "SensorTower",
    "MissileTurret", "PlanetaryFortress", "OrbitalCommand", "CommandCenter",
    "Refinery", "AutoTurret", "PointDefenseDrone", "Probe", "Zealot",
    "Stalker", "Sentry", "WarpPrism", "WarpPrismPhasing", "Observer",
    "Colossus", "Immortal", "HighTemplar", "DarkTemplar", "Phoenix",
    "VoidRay", "Carrier", "Tempest", "Interceptor", "Assimilator", "Pylon",
    "Gateway", "WarpGate", "CyberneticsCore", "RoboticsFacility",
    "Stargate", "TwilightCouncil", "RoboticsBay", "FleetBeacon",
    "TemplarArchive", "DarkShrine", "PhotonCannon", "ShieldBattery",
    "Nexus", "Mothership",
}

STATE_VARIANT_SUFFIXES = ("Burrowed", "Cocoon", "Uprooted", "Flying")
CUNIT_RE = re.compile(r'<CUnit\s+id="([^"]+)"(?:\s+parent="([^"]+)")?')


def is_state_variant(unit_id: str) -> bool:
    for suffix in STATE_VARIANT_SUFFIXES:
        if unit_id.endswith(suffix) and unit_id != suffix:
            return True
    return False


def is_suspicious_weapon(unit_id: str, parent: str) -> bool:
    if "MISSILE" in parent.upper():
        return True
    if not parent:
        upper_id = unit_id.upper()
        if any(kw in upper_id for kw in ("MISSILE", "WEAPON", "PROJECTILE")):
            return True
    return False


def extract_units_from_xml(xml_text: str) -> List[str]:
    """从 UnitData.xml 文本中提取单位 ID（已过滤）"""
    units: List[str] = []
    seen: set[str] = set()

    for line in xml_text.splitlines():
        stripped = line.lstrip()
        if stripped.startswith("<!--"):
            continue

        m = CUNIT_RE.search(line)
        if not m:
            continue

        unit_id = m.group(1)
        parent = m.group(2) or ""

        if is_suspicious_weapon(unit_id, parent):
            continue
        if unit_id in BASE_RACE_UNITS:
            continue
        if is_state_variant(unit_id):
            continue
        if unit_id in seen:
            continue
        seen.add(unit_id)
        units.append(unit_id)

    units.sort()
    return units


# ---------------------------------------------------------------------------
# MPQ / 目录读取
# ---------------------------------------------------------------------------
def read_unitdata_from_mpq(mpq_path: Path) -> str:
    if MPQArchive is None:
        raise RuntimeError("mpyq 未安装")
    archive = MPQArchive(str(mpq_path))
    target_files = ["Base.SC2Data\\GameData\\UnitData.xml", "Base\\GameData\\UnitData.xml"]

    file_names = []
    for name_bytes in archive.files:
        if name_bytes is None:
            continue
        if isinstance(name_bytes, bytes):
            try:
                name = name_bytes.decode("utf-8")
            except UnicodeDecodeError:
                name = name_bytes.decode("latin-1")
        else:
            name = name_bytes
        file_names.append(name)

    for target in target_files:
        if target in file_names:
            data = archive.read_file(target)
            if data is None:
                continue
            if isinstance(data, bytes):
                return data.decode("utf-8", errors="replace")
            return data

    print(f"  [WARN] {mpq_path.name} 未找到 UnitData.xml", file=sys.stderr)
    return ""


def read_unitdata_from_dir(mod_dir: Path) -> str:
    candidates = [
        mod_dir / "Base.SC2Data" / "GameData" / "UnitData.xml",
        mod_dir / "Base" / "GameData" / "UnitData.xml",
    ]
    for c in candidates:
        if c.exists():
            return c.read_text(encoding="utf-8", errors="replace")
    return ""


# ---------------------------------------------------------------------------
# 单指挥官 mod 配置（1 个 mod = 1 个指挥官组）
# ---------------------------------------------------------------------------
# (文件名, commander_id, commander_label)
SINGLE_COMMANDER_MODS = [
    # 顶层 mod
    ("CM_Core_Zhelus.SC2Mod",         "Cmdr_Dehaka",     "Dehaka（迪哈卡）"),
    ("Ihanrii.SC2Mod",                "Cmdr_Ihanrii",    "Ihanrii（伊汉里）"),
    ("Moebius.SC2Mod",                 "Cmdr_Moebius",    "Moebius（莫比斯）"),
    # Alenger 系列（每个 mod 一个指挥官）
    ("Alenger\\1钢铁.SC2Mod",          "Cmdr_Ironclad",   "Ironclad（钢铁）"),
    ("Alenger\\2贝希摩斯虫群.SC2Mod",   "Cmdr_Behemoth",   "Behemoth（贝希摩斯虫群）"),
    ("Alenger\\3疯批帝国.SC2Mod",       "Cmdr_MadEmpire",  "MadEmpire（疯批帝国）"),
    ("Alenger\\4塔达林.SC2Mod",         "Cmdr_Taldarim",   "Taldarim（塔达林）"),
    ("Alenger\\6阿巴瑟.SC2Mod",         "Cmdr_Abathur",    "Abathur（阿巴瑟）"),
    ("Alenger\\7卡莱.SC2Mod",           "Cmdr_Khalai",     "Khalai（卡莱）"),
    ("Alenger\\8扎加拉.SC2Mod",         "Cmdr_Zagara",     "Zagara（扎加拉）"),
    ("Alenger\\9海盗.SC2Mod",           "Cmdr_Pirate",     "Pirate（海盗）"),
    ("Alenger\\10埃蒙.SC2Mod",          "Cmdr_Amon",       "Amon（埃蒙）"),
    ("Alenger\\11群友.SC2Mod",          "Cmdr_Friends",    "Friends（群友）"),
    ("Alenger\\12游骑兵.SC2Mod",        "Cmdr_Ranger",     "Ranger（游骑兵）"),
    ("Alenger\\13净化者.SC2Mod",        "Cmdr_Purifier",   "Purifier（净化者）"),
]

# 跳过的 mod（纯依赖/音乐/效果，不生成组）
SKIP_MODS = {
    "6阿巴瑟之心.SC2Mod",       # 核心依赖库
    "AlengerBGM.SC2Mod",        # 顶层音乐 mod
    "Alenger\\AlengerBGM.SC2Mod",  # Alenger 子目录音乐 mod（同内容）
    "Alenger\\通用效果.SC2Mod",    # 通用效果
    "Alenger\\7卡莱 - 副本.SC2Mod",  # 7卡莱的副本，跳过避免重复
}


# ---------------------------------------------------------------------------
# VioletsHoTSReworkMod 子指挥官分组规则
# ---------------------------------------------------------------------------
def classify_violets_unit(unit_id: str) -> str:
    """返回子指挥官 ID，未匹配返回 "Violets_Shared" """
    # Mengsk 系列
    if unit_id.startswith("Mengsk"):
        return "Violets_Mengsk"
    # Dehaka / Primal 系列
    if unit_id.startswith("Dehaka") or unit_id.startswith("Primal"):
        return "Violets_Dehaka"
    # Stukov 系列
    if (unit_id.startswith("Infested")
        or unit_id in ("Infestor", "InfestorBurrowed")
        or unit_id in ("DevilDog", "ScienceVessel")):
        return "Violets_Stukov"
    # Kerrigan 系列
    if (unit_id.startswith("K5Kerrigan")
        or unit_id.startswith("Kerrigan")
        or unit_id in ("HunterKiller", "HunterKillerBurrowed")
        or unit_id in ("SwarmQueen", "SwarmQueenBurrowed")
        or unit_id in ("HugeSwarmQueen", "HugeSwarmQueenBurrowed")
        or unit_id in ("LargeSwarmQueen", "LargeSwarmQueenBurrowed")
        or unit_id == "Brutalisk"):
        return "Violets_Kerrigan"
    # ZaGara 系列
    if unit_id.startswith("ZaGara"):
        return "Violets_ZaGara"
    # Aiur 星灵（Artanis 系）
    if unit_id.endswith("Aiur"):
        return "Violets_Artanis"
    # Shakuras 星灵（Zeratul 系）
    if unit_id.endswith("Shakuras"):
        return "Violets_Zeratul"
    # Taldarim 星灵（Alarak 系）
    if unit_id.endswith("Taldarim"):
        return "Violets_Alarak"
    # Purifier 星灵（Fenix 系）
    if unit_id.endswith("Purifier"):
        return "Violets_Fenix"

    return "Violets_Shared"


VIOLETS_SUBCOMMANDER_LABELS = {
    "Violets_Mengsk":   "Violets/Mengsk（蒙斯克）",
    "Violets_Dehaka":   "Violets/Dehaka（迪哈卡）",
    "Violets_Stukov":   "Violets/Stukov（斯图科夫）",
    "Violets_Kerrigan": "Violets/Kerrigan（凯瑞甘）",
    "Violets_ZaGara":   "Violets/ZaGara（扎加拉）",
    "Violets_Artanis":  "Violets/Artanis（阿塔尼斯）",
    "Violets_Zeratul":  "Violets/Zeratul（泽拉图）",
    "Violets_Alarak":   "Violets/Alarak（阿拉纳克）",
    "Violets_Fenix":    "Violets/Fenix（菲尼克斯）",
    "Violets_Shared":   "Violets/Shared（共享基础单位）",
}

# Violets 子指挥官的输出顺序（共享放最后）
VIOLETS_SUBCOMMANDER_ORDER = [
    "Violets_Mengsk",
    "Violets_Dehaka",
    "Violets_Stukov",
    "Violets_Kerrigan",
    "Violets_ZaGara",
    "Violets_Artanis",
    "Violets_Zeratul",
    "Violets_Alarak",
    "Violets_Fenix",
    "Violets_Shared",
]


# ---------------------------------------------------------------------------
# 扫描入口
# ---------------------------------------------------------------------------
def scan_all_commanders() -> List[Tuple[str, str, List[str], Path]]:
    """扫描所有 mod，按指挥官分组返回 [(commander_id, label, units, source_path), ...]"""
    results: List[Tuple[str, str, List[str], Path]] = []

    # 1. 单指挥官 mod
    for rel_path, cmdr_id, cmdr_label in SINGLE_COMMANDER_MODS:
        mod_path = SOURCE_MODS_ROOT / rel_path
        if not mod_path.exists():
            print(f"  [SKIP] 单指挥官 mod 不存在: {rel_path}", file=sys.stderr)
            continue

        if mod_path.is_dir():
            xml_text = read_unitdata_from_dir(mod_path)
        else:
            try:
                xml_text = read_unitdata_from_mpq(mod_path)
            except Exception as e:
                print(f"  [ERROR] 解包 {rel_path} 失败: {e}", file=sys.stderr)
                continue

        if not xml_text:
            print(f"  [SKIP] {rel_path} 没有 UnitData.xml", file=sys.stderr)
            continue

        units = extract_units_from_xml(xml_text)
        results.append((cmdr_id, cmdr_label, units, mod_path))
        print(f"  [OK] {cmdr_label}  ←  {rel_path}  ({len(units)} 个单位)", file=sys.stderr)

    # 2. VioletsHoTSReworkMod 子指挥官分组
    violets_path = SOURCE_MODS_ROOT / "VioletsHoTSReworkMod.SC2Mod"
    if violets_path.exists():
        xml_text = read_unitdata_from_dir(violets_path)
        if xml_text:
            violets_units = extract_units_from_xml(xml_text)
            # 按子指挥官分组
            sub_groups: dict[str, List[str]] = {sid: [] for sid in VIOLETS_SUBCOMMANDER_ORDER}
            for u in violets_units:
                sub_id = classify_violets_unit(u)
                sub_groups[sub_id].append(u)

            for sub_id in VIOLETS_SUBCOMMANDER_ORDER:
                members = sorted(sub_groups[sub_id])
                if not members:
                    continue
                label = VIOLETS_SUBCOMMANDER_LABELS[sub_id]
                results.append((sub_id, label, members, violets_path))
                print(f"  [OK] {label}  ←  VioletsHoTSReworkMod  ({len(members)} 个单位)", file=sys.stderr)
        else:
            print(f"  [WARN] VioletsHoTSReworkMod 没有 UnitData.xml", file=sys.stderr)

    return results


# ---------------------------------------------------------------------------
# Galaxy 库生成
# ---------------------------------------------------------------------------
def generate_galaxy_library(
    results: List[Tuple[str, str, List[str], Path]]
) -> str:
    lines: List[str] = []
    lines.append("//================================================================================")
    lines.append("// LibAbathurHeartCatalog.galaxy - 阿巴瑟之心 mod 单位目录（按指挥官分组）")
    lines.append(f"// 来源: {SOURCE_MODS_ROOT}")
    lines.append(f"// 共 {len(results)} 个指挥官组")
    lines.append("//================================================================================")
    lines.append("")

    total_units = sum(len(u) for _, _, u, _ in results)
    cmdr_count = len(results)
    lines.append(f"const int gv_c_AH_ModCount = {cmdr_count};")
    lines.append(f"const int gv_c_AH_TotalUnits = {total_units};")
    lines.append("")
    lines.append(f"string[{cmdr_count}] gv_AH_ModLabels;")
    lines.append(f"string[{cmdr_count}] gv_AH_ModIdentifiers;")
    lines.append(f"int[{cmdr_count}] gv_AH_UnitOffsets;")
    lines.append(f"int[{cmdr_count}] gv_AH_UnitCounts;")
    lines.append(f"string[{total_units}] gv_AH_Units;")
    lines.append("")

    lines.append("void libAbathurHeartCatalog_InitLib () {")
    offset = 0
    for idx, (cmdr_id, label, units, _) in enumerate(results):
        lines.append(f'    gv_AH_ModLabels[{idx}] = "{label}";')
        lines.append(f'    gv_AH_ModIdentifiers[{idx}] = "{cmdr_id}";')
        lines.append(f"    gv_AH_UnitOffsets[{idx}] = {offset};")
        lines.append(f"    gv_AH_UnitCounts[{idx}] = {len(units)};")
        for j, uid in enumerate(units):
            lines.append(f'    gv_AH_Units[{offset + j}] = "{uid}";')
        offset += len(units)
        if idx < len(results) - 1:
            lines.append("")
    lines.append("}")
    lines.append("")

    # 辅助函数
    lines.append("// 按索引取单位 ID")
    lines.append("string libAbathurHeartCatalog_gf_UnitAt (int lp_modIndex, int lp_unitIndex) {")
    lines.append("    int lv_offset;")
    lines.append("    int lv_count;")
    lines.append("    if ((lp_modIndex < 0) || (lp_modIndex >= gv_c_AH_ModCount)) {")
    lines.append('        return "";')
    lines.append("    }")
    lines.append("    lv_offset = gv_AH_UnitOffsets[lp_modIndex];")
    lines.append("    lv_count = gv_AH_UnitCounts[lp_modIndex];")
    lines.append("    if ((lp_unitIndex < 0) || (lp_unitIndex >= lv_count)) {")
    lines.append('        return "";')
    lines.append("    }")
    lines.append("    return gv_AH_Units[lv_offset + lp_unitIndex];")
    lines.append("}")
    lines.append("")
    lines.append("// 按标签查找指挥官索引")
    lines.append("int libAbathurHeartCatalog_gf_ModIndexOf (string lp_label) {")
    lines.append("    int lv_i;")
    lines.append("    for (lv_i = 0; lv_i < gv_c_AH_ModCount; lv_i += 1) {")
    lines.append("        if (gv_AH_ModLabels[lv_i] == lp_label) {")
    lines.append("            return lv_i;")
    lines.append("        }")
    lines.append("    }")
    lines.append("    return -1;")
    lines.append("}")
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# 报告生成
# ---------------------------------------------------------------------------
def generate_report(
    results: List[Tuple[str, str, List[str], Path]]
) -> str:
    lines: List[str] = []
    lines.append("# 阿巴瑟之心 mod 单位扫描报告（按指挥官分组）")
    lines.append("")
    lines.append(f"扫描目录: `{SOURCE_MODS_ROOT}`")
    lines.append("")
    lines.append("## 概览")
    lines.append("")
    lines.append("| 指挥官 ID | 标签 | 单位数 | 来源 mod |")
    lines.append("|-----------|------|--------|----------|")
    for cmdr_id, label, units, mod_path in results:
        try:
            rel = mod_path.relative_to(SOURCE_MODS_ROOT)
        except ValueError:
            rel = mod_path
        lines.append(f"| `{cmdr_id}` | {label} | {len(units)} | `{rel}` |")
    lines.append("")

    for cmdr_id, label, units, mod_path in results:
        lines.append(f"## {label} ({len(units)} 个)")
        lines.append("")
        lines.append(f"- 指挥官 ID: `{cmdr_id}`")
        try:
            rel = mod_path.relative_to(SOURCE_MODS_ROOT)
        except ValueError:
            rel = mod_path
        lines.append(f"- 来源: `{rel}`")
        lines.append("")
        if units:
            for i in range(0, len(units), 5):
                chunk = units[i:i + 5]
                lines.append("  - " + ", ".join(f"`{u}`" for u in chunk))
        else:
            lines.append("  - (空)")
        lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# 入口
# ---------------------------------------------------------------------------
def main() -> int:
    if not SOURCE_MODS_ROOT.exists():
        print(f"[ERROR] 源 mod 目录不存在: {SOURCE_MODS_ROOT}", file=sys.stderr)
        return 1

    print(f"[INFO] 扫描目录: {SOURCE_MODS_ROOT}", file=sys.stderr)
    print(f"[INFO] 输出库: {OUTPUT_LIB}", file=sys.stderr)
    print("", file=sys.stderr)

    results = scan_all_commanders()
    if not results:
        print("[ERROR] 未扫描到任何单位", file=sys.stderr)
        return 2

    OUTPUT_LIB.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)

    galaxy_text = generate_galaxy_library(results)
    OUTPUT_LIB.write_text(galaxy_text, encoding="utf-8")

    report_text = generate_report(results)
    REPORT_PATH.write_text(report_text, encoding="utf-8")

    total = sum(len(u) for _, _, u, _ in results)
    print("", file=sys.stderr)
    print(f"[OK] 扫描完成: {len(results)} 个指挥官组, 共 {total} 个单位", file=sys.stderr)
    print(f"[OK] Galaxy 库: {OUTPUT_LIB}", file=sys.stderr)
    print(f"[OK] 扫描报告: {REPORT_PATH}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
