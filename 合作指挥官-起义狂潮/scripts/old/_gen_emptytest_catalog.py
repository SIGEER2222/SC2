r"""扫描 CommanderCatalog\UnitData_*.xml 生成 LibEmptyTestCatalog.galaxy

为 emptytest.SC2Map 测试图生成指挥官单位清单查询表。
- 扫描 UnitData_<Commander>.xml（跳过 Shared_* 文件）
- 维护文件名 -> 指挥官短名映射（如 TychusXM -> Tychus）
- 过滤掉 MISSILE / MISSILE_INVULNERABLE / EFFECT 等 parent 不可生成的实例
- 输出 galaxy 数据结构 + 查表函数
"""
import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# 文件名 → 指挥官短名（与 Bank 的 PrimaryCommander 一致）
COMMANDER_NAME_MAP = {
    "Kerrigan": "Kerrigan",
    "Raynor": "Raynor",
    "RaynorX": "Raynor",
    "TychusXM": "Tychus",
    "Nova": "Nova",
    "Swann": "Swann",
    "Horner": "Horner",
    "Mengsk": "Mengsk",
    "Stukov": "Stukov",
    "Stetmann": "Stetmann",
    "Artanis": "Artanis",
    "Vorazun": "Vorazun",
    "Zeratul": "Zeratul",
    "Karax": "Karax",
    "Alarak": "Alarak",
    "Fenix": "Fenix",
    "Abathur": "Abathur",
    "Reborn": "AbathurReborn",
    "Zagara": "Zagara",
    "Dehaka": "Dehaka",
}

# 不可生成的 parent 黑名单（单位/特效/导弹）
BLACKLIST_PARENTS = {
    "MISSILE",
    "MISSILE_INVULNERABLE",
    "EFFECT",
    "BEHAVIOR",
    "ACTOR",
    "TURRET",
    "BEAM",
    "EDITOR",
}

# 按种族分组的指挥官
PROTOSS_COMMANDERS = {"Artanis", "Vorazun", "Zeratul", "Karax", "Alarak", "Fenix"}
TERRAN_COMMANDERS = {"Raynor", "Nova", "Swann", "Tychus", "Horner", "Mengsk", "Stukov"}
ZERG_COMMANDERS = {"Kerrigan", "Abathur", "AbathurReborn", "Zagara", "Dehaka", "Stukov"}
ALL_COMMANDERS = PROTOSS_COMMANDERS | TERRAN_COMMANDERS | ZERG_COMMANDERS

# Shared_* 文件名 -> 接收该文件单位的指挥官集合
# 未在此表中的 Shared_* 文件会被忽略
SHARED_FILE_OWNERS = {
    "Shared_Protoss": PROTOSS_COMMANDERS,
    "Shared_Terran_A_G": TERRAN_COMMANDERS,
    "Shared_Terran_H": TERRAN_COMMANDERS,
    "Shared_Terran_I_V": TERRAN_COMMANDERS,
    "Shared_Zerg": ZERG_COMMANDERS,
    "Shared_InfestedTerran": {"Stukov"},
    # 中立单位：所有指挥官都可用
    "Shared_Neutral_H": ALL_COMMANDERS,
    "Shared_Neutral_I_M": ALL_COMMANDERS,
    "Shared_Neutral_N_Z": ALL_COMMANDERS,
}


def parse_catalog_xml(path: Path) -> list[tuple[str, str]]:
    """解析 UnitData_*.xml，返回 [(unit_id, parent), ...]"""
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    # 宽容编码修复
    text = text.replace('encoding="us-ascii"', 'encoding="utf-8"')
    # 缺少 <Catalog> 包装则补
    if "<Catalog" not in text:
        text = "<Catalog>" + text + "</Catalog>"
    try:
        root = ET.fromstring(text)
    except ET.ParseError as e:
        print(f"  XML 解析失败 {path.name}: {e}", file=sys.stderr)
        return []
    out = []
    for u in root.findall("CUnit"):
        uid = u.attrib.get("id", "").strip()
        parent = u.attrib.get("parent", "").strip()
        if uid:
            out.append((uid, parent))
    return out


def is_generatable(uid: str, parent: str) -> bool:
    """判断是否可生成实例（过滤掉导弹/特效等）"""
    if parent in BLACKLIST_PARENTS:
        return False
    # 单位 ID 后缀黑名单
    uid_upper = uid.upper()
    for suffix in ("MISSILE", "BEAM", "EFFECT", "ACTOR", "TURRET"):
        if uid_upper.endswith(suffix):
            return False
    # SC2 内置的纯抽象单位（如 EditorPlacerOutline 等）
    if uid.startswith("Editor"):
        return False
    return True


def collect_commander_units(commander_catalog_root: Path) -> dict[str, list[str]]:
    """按指挥官聚合可生成单位 ID 清单"""
    gamedata_dir = commander_catalog_root / "Base.SC2Data" / "GameData"
    if not gamedata_dir.exists():
        raise FileNotFoundError(f"GameData dir not found: {gamedata_dir}")

    # commander -> set(unit_id) 用于去重; 最终按插入顺序保留
    commander_units: dict[str, list[str]] = {}
    commander_seen: dict[str, set] = {}

    def add_unit(commander: str, uid: str) -> None:
        seen = commander_seen.setdefault(commander, set())
        if uid not in seen:
            commander_units.setdefault(commander, []).append(uid)
            seen.add(uid)

    def add_units(commanders: set, units: list[tuple[str, str]], source_file: str) -> None:
        generatable = [uid for (uid, parent) in units if is_generatable(uid, parent)]
        for commander in sorted(commanders):
            for uid in generatable:
                add_unit(commander, uid)
        if generatable:
            print(f"  {source_file} -> {sorted(commanders)[0] if len(commanders) == 1 else f'{len(commanders)} 个指挥官'}: +{len(generatable)} 单位")

    for xml_path in sorted(gamedata_dir.glob("UnitData_*.xml")):
        name = xml_path.stem[len("UnitData_"):]
        units = parse_catalog_xml(xml_path)

        # 处理 Shared_* 文件
        if name.startswith("Shared_"):
            if name in SHARED_FILE_OWNERS:
                add_units(SHARED_FILE_OWNERS[name], units, xml_path.name)
            else:
                print(f"  跳过未知 Shared_ 文件: {xml_path.name}", file=sys.stderr)
            continue

        # 处理指挥官专属文件
        if name not in COMMANDER_NAME_MAP:
            print(f"  跳过未知文件: {xml_path.name}（请维护映射表）", file=sys.stderr)
            continue
        commander = COMMANDER_NAME_MAP[name]
        generatable = [uid for (uid, parent) in units if is_generatable(uid, parent)]
        for uid in generatable:
            add_unit(commander, uid)
        print(f"  {xml_path.name} -> {commander}: +{len(generatable)} 单位")

    return commander_units


def emit_galaxy(commander_units: dict[str, list[str]]) -> str:
    """生成 LibEmptyTestCatalog.galaxy 内容"""
    # Galaxy 不支持 const 数组初始化列表, 改用普通数组 + InitLib 函数逐个赋值
    sorted_commanders = sorted(commander_units.keys())

    flat_units = []
    flat_offsets = []
    cursor = 0
    for commander in sorted_commanders:
        units = commander_units[commander]
        flat_offsets.append((commander, cursor, len(units)))
        flat_units.extend(units)
        cursor += len(units)

    n_cmd = max(len(sorted_commanders), 1)
    n_units = max(len(flat_units), 1)

    lines = []
    lines.append("//================================================================================")
    lines.append("//")
    lines.append("// LibEmptyTestCatalog.galaxy - 自动生成")
    lines.append("//   为每个指挥官列出所有可生成单位 ID，用于 emptytest 测试图动态生成实例。")
    lines.append("//   生成脚本: scripts/_gen_emptytest_catalog.py")
    lines.append("//")
    lines.append("// 注意: Galaxy 不支持 const 数组初始化列表, 所以全部用普通数组 + InitLib 赋值")
    lines.append("//================================================================================")
    lines.append("")
    lines.append(f"const int gv_c_EmptyTestCommanderCount = {len(sorted_commanders)};")
    lines.append(f"const int gv_c_EmptyTestTotalUnits = {len(flat_units)};")
    lines.append("")
    lines.append("//--------------------------------------------------------------------------------------------------")
    lines.append("// 指挥官名表（按字母顺序）")
    lines.append("//--------------------------------------------------------------------------------------------------")
    lines.append(f"string[{n_cmd}] gv_EmptyTestCommanders;")
    lines.append("")
    lines.append("//--------------------------------------------------------------------------------------------------")
    lines.append("// 每个指挥官在扁平表中的起始偏移 + 单位数")
    lines.append("//--------------------------------------------------------------------------------------------------")
    lines.append(f"int[{n_cmd}] gv_EmptyTestUnitOffsets;")
    lines.append(f"int[{n_cmd}] gv_EmptyTestUnitCounts;")
    lines.append("")
    lines.append("//--------------------------------------------------------------------------------------------------")
    lines.append("// 单位 ID 扁平表")
    lines.append("//--------------------------------------------------------------------------------------------------")
    lines.append(f"string[{n_units}] gv_EmptyTestUnits;")
    lines.append("")
    lines.append("//--------------------------------------------------------------------------------------------------")
    lines.append("// 初始化查表数据")
    lines.append("//--------------------------------------------------------------------------------------------------")
    lines.append("void libEmptyTestCatalog_InitLib () {")
    for i, (commander, _, _) in enumerate(flat_offsets):
        lines.append(f'    gv_EmptyTestCommanders[{i}] = "{commander}";')
    lines.append("")
    for i, (_, offset, count) in enumerate(flat_offsets):
        lines.append(f"    gv_EmptyTestUnitOffsets[{i}] = {offset};")
        lines.append(f"    gv_EmptyTestUnitCounts[{i}] = {count};")
    lines.append("")
    for i, uid in enumerate(flat_units):
        lines.append(f'    gv_EmptyTestUnits[{i}] = "{uid}";')
    lines.append("}")
    lines.append("")
    lines.append("//--------------------------------------------------------------------------------------------------")
    lines.append("// 查表 API: 指挥官名 -> 序号 (-1 表示未找到)")
    lines.append("//--------------------------------------------------------------------------------------------------")
    lines.append("int libEmptyTestCatalog_gf_CommanderIndex (string lp_commander) {")
    lines.append("    int li;")
    lines.append(f"    for (li = 0; li <= {n_cmd - 1}; li += 1) {{")
    lines.append("        if (gv_EmptyTestCommanders[li] == lp_commander) {")
    lines.append("            return li;")
    lines.append("        }")
    lines.append("    }")
    lines.append("    return -1;")
    lines.append("}")
    lines.append("")
    lines.append("//--------------------------------------------------------------------------------------------------")
    lines.append("// 查表 API: 指挥官名 -> 该指挥官的单位数")
    lines.append("//--------------------------------------------------------------------------------------------------")
    lines.append("int libEmptyTestCatalog_gf_UnitCountOf (string lp_commander) {")
    lines.append("    int li = libEmptyTestCatalog_gf_CommanderIndex(lp_commander);")
    lines.append("    if (li < 0) { return 0; }")
    lines.append("    return gv_EmptyTestUnitCounts[li];")
    lines.append("}")
    lines.append("")
    lines.append("//--------------------------------------------------------------------------------------------------")
    lines.append("// 查表 API: 指挥官名 + 序号 -> 单位 ID (越界返回空字符串)")
    lines.append("//--------------------------------------------------------------------------------------------------")
    lines.append("string libEmptyTestCatalog_gf_UnitAt (string lp_commander, int lp_index) {")
    lines.append("    int li = libEmptyTestCatalog_gf_CommanderIndex(lp_commander);")
    lines.append("    if (li < 0) { return \"\"; }")
    lines.append("    if (lp_index < 0 || lp_index >= gv_EmptyTestUnitCounts[li]) { return \"\"; }")
    lines.append("    return gv_EmptyTestUnits[gv_EmptyTestUnitOffsets[li] + lp_index];")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def main():
    workspace_root = Path(r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮")
    commander_catalog_root = workspace_root / "Mods/7vs1/CommanderCatalog.SC2Mod"
    output_path = workspace_root / "Mods/emptytest.SC2Map/Base.SC2Data/LibEmptyTestCatalog.galaxy"

    print(f"扫描目录: {commander_catalog_root}")
    commander_units = collect_commander_units(commander_catalog_root)

    print()
    print(f"共 {len(commander_units)} 个指挥官，单位数:")
    for commander, units in sorted(commander_units.items()):
        print(f"  {commander:18s} {len(units):3d} 单位")

    # 输出到 emptytest 的 Base.SC2Data
    output_path.parent.mkdir(parents=True, exist_ok=True)
    galaxy_text = emit_galaxy(commander_units)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(galaxy_text)
    print()
    print(f"已生成: {output_path}")
    print(f"  文件大小: {output_path.stat().st_size} bytes")


if __name__ == "__main__":
    main()
