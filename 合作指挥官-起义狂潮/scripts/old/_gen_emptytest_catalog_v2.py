"""生成 LibEmptyTestCatalog.galaxy - v2

基于 sc2_unit_explorer 的多层 mod 加载逻辑，生成指挥官单位清单。
包含官方 starcoop + CommanderCatalog + 海克斯合作PVP mod。
过滤掉基础种族共享单位，只保留指挥官特有单位。
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sc2_unit_explorer import CatalogDB, DEFAULT_MOD_PATHS

HEX_MOD_PATH = Path(r"E:\Code\MyMod\SC2\解包数据\海克斯合作PVP0.110.SC2Mod")
OUTPUT_PATH = Path(r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods\emptytest.SC2Map\Base.SC2Data\LibEmptyTestCatalog.galaxy")

COMMANDER_UNIT_PREFIXES = [
    ("Kerrigan", [
        "Kerrigan", "K5Kerrigan", "BroodLordKerrigan", "DroneKerrigan",
        "EvolutionChamberKerrigan", "ExtractorKerrigan", "GreaterNydusWormKerrigan",
        "GreaterSpireKerrigan", "HatcheryKerrigan", "HiveKerrigan",
        "HydraliskDenKerrigan", "HydraliskKerrigan", "HydraliskLurkerKerrigan",
        "LairKerrigan", "LarvaKerrigan", "LurkerDenKerrigan",
        "NydusCanalKerrigan", "NydusNetworkKerrigan", "OverlordKerrigan",
        "OverseerKerrigan", "SpawningPoolKerrigan", "SpineCrawlerKerrigan",
        "SpireKerrigan", "SporeCrawlerKerrigan", "UltraliskCavernKerrigan",
        "UltraliskKerrigan", "ViperKerrigan", "MutaliskKerrigan",
        "RoachKerrigan", "RoachWarrenKerrigan", "RavagerKerrigan",
        "SwarmHostKerrigan", "InfestationPitKerrigan", "InfestorKerrigan",
        "BanelingKerrigan", "BanelingNestKerrigan", "ZerglingKerrigan",
        "QueenKerrigan", "KerriganEgg", "KerriganReviveCocoon",
        "CoopCasterKerrigan", "MutatorAmonKerrigan", "BroodLordCocoonKerrigan",
        "KerriganChar", "KerriganVoid", "KerriganGhostLab",
        "KerriganInfestBroodling", "KerrigansInitialCocoonBlocker",
        "KerriganVoidCoopEconDrop", "KerriganXelNagaReviveCocoon",
        "KerriganEpilogue", "KerriganVoidUlnar", "HydraliskLurkerBurrowedKerrigan",
        "SpineCrawlerUprootedKerrigan", "SporeCrawlerUprootedKerrigan",
    ]),
]

BASE_ZERG_UNITS = {
    "Larva", "Egg", "Drone", "Zergling", "Baneling", "Roach", "Ravager",
    "Hydralisk", "Lurker", "Mutalisk", "Corruptor", "BroodLord", "SwarmHost",
    "Infestor", "Ultralisk", "Viper", "Overlord", "Overseer", "Queen",
    "Hatchery", "Lair", "Hive", "SpawningPool", "BanelingNest", "RoachWarren",
    "HydraliskDen", "LurkerDen", "Spire", "GreaterSpire", "InfestationPit",
    "UltraliskCavern", "NydusNetwork", "NydusCanal", "SpineCrawler",
    "SporeCrawler", "Extractor", "EvolutionChamber", "CreepTumor",
    "Broodling", "Locust", "Changeling",
}

# 缺少 CActorUnit 定义的单位（英雄/战役/Mutator 特殊单位）
# 这些单位在 ActorData_Kerrigan.xml 和 starcoop actordata.xml 中都没有 CActorUnit 定义
# 游戏会创建 fallback sphere（丢失模型的球体）
EXCLUDED_UNITS = {
    "CoopCasterKerrigan",
    "K5Kerrigan", "K5KerriganBurrowed", "K5KerriganPsiStrike",
    "Kerrigan", "KerriganChar", "KerriganCharBurrowed",
    "KerriganEgg", "KerriganReviveCocoon", "KerrigansInitialCocoonBlocker",
    "KerriganEpilogue03", "KerriganEpilogue03Burrowed",
    "KerriganGhostLab", "KerriganGhostLabUnarmed",
    "KerriganInfestBroodling",
    "KerriganVoid", "KerriganVoidBurrowed",
    "KerriganVoidCoopEconDrop1", "KerriganVoidCoopEconDrop2",
    "KerriganVoidCoopEconDrop3", "KerriganVoidCoopEconDrop4",
    "KerriganVoidCoopEconDrop5", "KerriganVoidCoopEconDropLT1",
    "KerriganVoidUlnar02", "KerriganXelNagaReviveCocoon",
    "MutatorAmonKerrigan", "MutatorAmonKerriganBurrowed",
}


def is_commander_unit(unit_id: str, commander: str, prefixes: list[str]) -> bool:
    uid = unit_id
    if uid in BASE_ZERG_UNITS:
        return False
    if uid in EXCLUDED_UNITS:
        return False
    for prefix in prefixes:
        if uid.startswith(prefix):
            return True
    return False


def main():
    mod_paths = list(DEFAULT_MOD_PATHS) + [HEX_MOD_PATH]

    db = CatalogDB(mod_paths=mod_paths, lang="zhCN")
    db.load()

    unit_catalog = db.catalogs.get("Unit", {})

    commanders_data = {}
    for commander, prefixes in COMMANDER_UNIT_PREFIXES:
        units = []
        for uid in sorted(unit_catalog.keys()):
            if is_commander_unit(uid, commander, prefixes):
                units.append(uid)
        commanders_data[commander] = units

    total_units = sum(len(v) for v in commanders_data.values())
    print(f"指挥官数: {len(commanders_data)}")
    print(f"总单位数: {total_units}")
    for cmd, units in commanders_data.items():
        print(f"  {cmd}: {len(units)} 个")
        for u in units[:15]:
            print(f"    - {u}")
        if len(units) > 15:
            print(f"    ... 还有 {len(units)-15} 个")

    commander_list = list(commanders_data.keys())
    offsets = []
    counts = []
    all_units = []
    offset = 0
    for cmd in commander_list:
        units = commanders_data[cmd]
        offsets.append(offset)
        counts.append(len(units))
        all_units.extend(units)
        offset += len(units)

    total = len(all_units)
    cmd_count = len(commander_list)

    lines = []
    lines.append("//================================================================================")
    lines.append("//")
    lines.append("// LibEmptyTestCatalog.galaxy - 自动生成 (v2)")
    lines.append("//   基于多层 mod 合并数据，过滤基础种族共享单位")
    lines.append("//   生成脚本: scripts/_gen_emptytest_catalog_v2.py")
    lines.append("//")
    lines.append("// 注意: Galaxy 不支持 const 数组初始化列表, 所以全部用普通数组 + InitLib 赋值")
    lines.append("//================================================================================")
    lines.append("")
    lines.append(f"const int gv_c_EmptyTestCommanderCount = {cmd_count};")
    lines.append(f"const int gv_c_EmptyTestTotalUnits = {total};")
    lines.append("")
    lines.append("//------------------------------------------------------------------------------")
    lines.append("// 指挥官名表")
    lines.append("//------------------------------------------------------------------------------")
    lines.append(f"string[{cmd_count}] gv_EmptyTestCommanders;")
    lines.append("")
    lines.append("//------------------------------------------------------------------------------")
    lines.append("// 每个指挥官在扁平表中的起始偏移 + 单位数")
    lines.append("//------------------------------------------------------------------------------")
    lines.append(f"int[{cmd_count}] gv_EmptyTestUnitOffsets;")
    lines.append(f"int[{cmd_count}] gv_EmptyTestUnitCounts;")
    lines.append("")
    lines.append("//------------------------------------------------------------------------------")
    lines.append("// 单位 ID 扁平表")
    lines.append("//------------------------------------------------------------------------------")
    lines.append(f"string[{total}] gv_EmptyTestUnits;")
    lines.append("")
    lines.append("//------------------------------------------------------------------------------")
    lines.append("// 初始化查表数据")
    lines.append("//------------------------------------------------------------------------------")
    lines.append("void libEmptyTestCatalog_InitLib () {")
    for i, cmd in enumerate(commander_list):
        lines.append(f'    gv_EmptyTestCommanders[{i}] = "{cmd}";')
    lines.append("")
    for i, off in enumerate(offsets):
        lines.append(f"    gv_EmptyTestUnitOffsets[{i}] = {off};")
    lines.append("")
    for i, cnt in enumerate(counts):
        lines.append(f"    gv_EmptyTestUnitCounts[{i}] = {cnt};")
    lines.append("")
    for i, uid in enumerate(all_units):
        lines.append(f'    gv_EmptyTestUnits[{i}] = "{uid}";')
    lines.append("}")
    lines.append("")
    lines.append("//------------------------------------------------------------------------------")
    lines.append("// 查询 API")
    lines.append("//------------------------------------------------------------------------------")
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

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(f"\n已写入: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
