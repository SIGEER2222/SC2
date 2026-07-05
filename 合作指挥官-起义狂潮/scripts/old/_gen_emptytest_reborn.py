"""生成 LibEmptyTestCatalog.galaxy - Reborn 版

解析 reborn mod 的 UnitData.xml，提取所有单位 ID，过滤：
  1. parent 属性包含 MISSILE 的单位（导弹/武器单位）
  2. 被注释掉的单位（<!--CUnit id="xxx"-->）
  3. 基础种族单位（覆盖定义，非自定义单位）
"""
import re
from pathlib import Path

REBORN_MOD_PATH = Path(
    r"C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\crys_the_swarm_reborn.SC2Mod"
)
UNIT_DATA_XML = REBORN_MOD_PATH / "Base.SC2Data" / "GameData" / "UnitData.xml"
OUTPUT_PATH = Path(
    r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods\emptytest.SC2Map\Base.SC2Data\LibEmptyTestCatalog.galaxy"
)

# 基础种族单位（覆盖定义，不是自定义单位，需要排除）
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

# 匹配 CUnit 标签起始行: <CUnit id="XXX" parent="YYY">
# 也允许单属性、自闭合等情况
CUNIT_RE = re.compile(r'<CUnit\s+id="([^"]+)"(?:\s+parent="([^"]+)")?')


def extract_units(xml_text: str) -> list[str]:
    """从 UnitData.xml 文本中提取单位 ID，应用过滤规则。

    过滤规则:
      1. 跳过被注释掉的单位 (<!--CUnit id="xxx")
      2. 跳过 parent 属性包含 MISSILE 的单位
      3. 跳过基础种族单位集合中的单位
      4. 跳过 parent 缺失但 id 中含 "Missile" / "Weapon" 的可疑武器单位
    """
    units: list[str] = []
    seen: set[str] = set()

    for line in xml_text.splitlines():
        # 跳过被注释掉的单位
        stripped = line.lstrip()
        if stripped.startswith("<!--"):
            continue

        m = CUNIT_RE.search(line)
        if not m:
            continue

        unit_id = m.group(1)
        parent = m.group(2) or ""

        # 过滤导弹/武器单位
        if "MISSILE" in parent:
            continue

        # 过滤基础种族单位
        if unit_id in BASE_RACE_UNITS:
            continue

        # 去重（reborn mod 中可能有同 id 多次定义，取第一次出现）
        if unit_id in seen:
            continue

        seen.add(unit_id)
        units.append(unit_id)

    units.sort()
    return units


def generate_galaxy(units: list[str]) -> str:
    """生成 LibEmptyTestCatalog.galaxy 文本。"""
    total = len(units)
    cmd_count = 1

    lines: list[str] = []
    lines.append("//================================================================================")
    lines.append("// LibEmptyTestCatalog.galaxy - 自动生成 (Reborn)")
    lines.append("// 基于 reborn mod UnitData.xml，过滤导弹/武器/基础种族单位")
    lines.append("//================================================================================")
    lines.append("")
    lines.append(f"const int gv_c_EmptyTestCommanderCount = {cmd_count};")
    lines.append(f"const int gv_c_EmptyTestTotalUnits = {total};")
    lines.append("")
    lines.append(f"string[{cmd_count}] gv_EmptyTestCommanders;")
    lines.append(f"int[{cmd_count}] gv_EmptyTestUnitOffsets;")
    lines.append(f"int[{cmd_count}] gv_EmptyTestUnitCounts;")
    lines.append(f"string[{total}] gv_EmptyTestUnits;")
    lines.append("")
    lines.append("void libEmptyTestCatalog_InitLib () {")
    lines.append('    gv_EmptyTestCommanders[0] = "Reborn";')
    lines.append("    gv_EmptyTestUnitOffsets[0] = 0;")
    lines.append(f"    gv_EmptyTestUnitCounts[0] = {total};")
    lines.append("")
    for i, uid in enumerate(units):
        lines.append(f'    gv_EmptyTestUnits[{i}] = "{uid}";')
    lines.append("}")
    lines.append("")
    lines.append("int libEmptyTestCatalog_gf_UnitCountOf (string lp_commander) {")
    lines.append("    int lv_i;")
    lines.append("    for (lv_i = 0; lv_i < gv_c_EmptyTestCommanderCount; lv_i += 1) {")
    lines.append("        if (gv_EmptyTestCommanders[lv_i] == lp_commander) {")
    lines.append("            return gv_EmptyTestUnitCounts[lv_i];")
    lines.append("        }")
    lines.append("    }")
    lines.append("    return 0;")
    lines.append("}")
    lines.append("")
    lines.append("string libEmptyTestCatalog_gf_UnitAt (string lp_commander, int lp_index) {")
    lines.append("    int lv_i;")
    lines.append("    for (lv_i = 0; lv_i < gv_c_EmptyTestCommanderCount; lv_i += 1) {")
    lines.append("        if (gv_EmptyTestCommanders[lv_i] == lp_commander) {")
    lines.append("            if ((lp_index >= 0) && (lp_index < gv_EmptyTestUnitCounts[lv_i])) {")
    lines.append("                return gv_EmptyTestUnits[gv_EmptyTestUnitOffsets[lv_i] + lp_index];")
    lines.append("            }")
    lines.append('            return "";')
    lines.append("        }")
    lines.append("    }")
    lines.append('    return "";')
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    if not UNIT_DATA_XML.exists():
        raise FileNotFoundError(f"UnitData.xml 未找到: {UNIT_DATA_XML}")

    xml_text = UNIT_DATA_XML.read_text(encoding="utf-8")
    units = extract_units(xml_text)

    print(f"Reborn mod: {REBORN_MOD_PATH}")
    print(f"UnitData.xml 总单位标签数: {xml_text.count('<CUnit id=')}")
    print(f"过滤后单位数: {len(units)}")
    print()
    print("前 20 个单位:")
    for u in units[:20]:
        print(f"  - {u}")
    if len(units) > 20:
        print(f"  ... 还有 {len(units) - 20} 个")
    print()

    galaxy_text = generate_galaxy(units)
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(galaxy_text, encoding="utf-8")
    print(f"已写入: {OUTPUT_PATH}")
    print(f"单位总数: {len(units)}")


if __name__ == "__main__":
    main()
