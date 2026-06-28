from __future__ import annotations

import json
import re
import subprocess
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
GAME_DATA_ROOT = ROOT / "Mods" / "7vs1" / "CommanderCatalog.SC2Mod" / "Base.SC2Data" / "GameData"
STRINGS_ROOT = ROOT / "Mods" / "7vs1" / "CoopZeroPop.SC2Mod" / "zhCN.SC2Data" / "LocalizedData"
STARCOOP_STRINGS_ROOT = ROOT / "游戏数据" / "官方SC2原始文本镜像" / "mods" / "starcoop" / "starcoop.sc2mod" / "zhcn.sc2data" / "localizeddata"
VOID_STRINGS_ROOT = ROOT / "游戏数据" / "官方SC2原始文本镜像" / "mods" / "voidmulti.sc2mod" / "zhcn.sc2data" / "localizeddata"

STARCOOP_DATA_ROOT = ROOT / "游戏数据" / "官方SC2原始文本镜像" / "mods" / "starcoop" / "starcoop.sc2mod" / "base.sc2data" / "gamedata"

RUNTIME_ROOT = ROOT / "Mods" / "7vs1" / "CoopZeroPop.SC2Mod" / "Base.SC2Data"

OUTPUT_DIR = ROOT / "web-launcher" / "exported-commander-codex"
PORTRAIT_DIR = OUTPUT_DIR / "portraits"
MANIFEST_PATH = OUTPUT_DIR / "manifest.json"

ICON_LIBRARY_DIR = ROOT / "web-launcher" / "icon-library"

SC2_STORAGE_PATH = Path(r"E:\SC2\SC2new\StarCraft II")
CASC_DUMP_EXE = Path(r"C:\tools\casc\CascDump\bin\Debug\net9.0\CascDump.exe")

LOCAL_ICON_ROOTS = [
    p for p in [
        Path(r"C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\tools\launcher_mpq\Assets\Textures"),
        Path(r"C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\整理输出\合作指挥官-起义狂潮\Mods\XM\XMCore.SC2Mod\Assets\Textures"),
        Path(r"C:\Users\22448\Downloads\合作指挥官版起义狂潮0.81\Mods\XM\XMCore.SC2Mod\Assets\Textures"),
    ] if p.exists() and p.is_dir()
]

COMMANDER_SPECS = [
    {"runtime": "ZergAbathur", "name": "阿巴瑟", "faction": "FactionEvolved", "prefixes": ["Abathur"], "unitData": "UnitData_Abathur.xml", "casterId": "CoopCasterAbathur"},
    {"runtime": "ProtossAlarak", "name": "阿拉纳克", "faction": "FactionTaldarim", "prefixes": ["Alarak"], "unitData": "UnitData_Alarak.xml", "casterId": "CoopCasterAlarak"},
    {"runtime": "ProtossArtanis", "name": "阿塔尼斯", "faction": "FactionKhalai", "prefixes": ["Artanis"], "unitData": "UnitData_Artanis.xml", "casterId": "SoACasterArtanis"},
    {"runtime": "ZergDehaka", "name": "德哈卡", "faction": "", "prefixes": ["Dehaka"], "unitData": "UnitData_Dehaka.xml", "casterId": "CoopCasterDehaka"},
    {"runtime": "ProtossFenix", "name": "菲尼克斯", "faction": "FactionPurifier", "prefixes": ["Fenix"], "unitData": "UnitData_Fenix.xml", "casterId": "SoACasterFenix"},
    {"runtime": "TerranHorner", "name": "汉与霍纳", "faction": "", "prefixes": ["HH", "Horner", "Han"], "unitData": "UnitData_Horner.xml", "casterId": "CoopCasterHorner"},
    {"runtime": "ProtossKarax", "name": "凯拉克斯", "faction": "FactionKhalai", "prefixes": ["Karax", "SOA"], "unitData": "UnitData_Karax.xml", "casterId": "SoACasterKarax"},
    {"runtime": "ZergKerrigan", "name": "凯瑞甘", "faction": "", "prefixes": ["Kerrigan", "K5Kerrigan", "HotS"], "unitData": "UnitData_Kerrigan.xml", "casterId": "CoopCasterKerrigan"},
    {"runtime": "TerranMengsk", "name": "蒙斯克", "faction": "", "prefixes": ["Mengsk"], "unitData": "UnitData_Mengsk.xml", "casterId": ""},
    {"runtime": "TerranNova", "name": "诺娃", "faction": "FactionCovertOps", "prefixes": ["Nova"], "unitData": "UnitData_Nova.xml", "casterId": "CoopCasterNova"},
    {"runtime": "TerranRaynor", "name": "雷诺", "faction": "FactionRaider", "prefixes": ["Raynor"], "unitData": "UnitData_Raynor.xml", "casterId": "CoopCasterRaynor"},
    {"runtime": "ZergStetmann", "name": "斯台特曼", "faction": "", "prefixes": ["Stetmann", "Gary", "SuperGary"], "unitData": "UnitData_Stetmann.xml", "casterId": "CoopCasterStetmann"},
    {"runtime": "ZergStukov", "name": "斯托科夫", "faction": "", "prefixes": ["Stukov", "InfestedStukov", "SIStukov"], "unitData": "UnitData_Stukov.xml", "casterId": "CoopCasterStukov"},
    {"runtime": "TerranSwann", "name": "斯旺", "faction": "", "prefixes": ["Swann"], "unitData": "UnitData_Swann.xml", "casterId": "CoopCasterSwann"},
    {"runtime": "TerranTychus", "name": "泰凯斯", "faction": "FactionOutlaw", "prefixes": ["Tychus"], "unitData": "", "casterId": "CoopCasterTychus"},
    {"runtime": "ProtossVorazun", "name": "沃拉尊", "faction": "FactionNerazim", "prefixes": ["Vorazun"], "unitData": "UnitData_Vorazun.xml", "casterId": "SoACasterVorazun"},
    {"runtime": "ZergZagara", "name": "扎加拉", "faction": "", "prefixes": ["Zagara"], "unitData": "UnitData_Zagara.xml", "casterId": "CoopCasterZagara"},
    {"runtime": "ProtossZeratul", "name": "泽拉图", "faction": "FactionNerazim", "prefixes": ["Zeratul"], "unitData": "UnitData_Zeratul.xml", "casterId": "CoopCasterZeratul"},
]

_casc_file_cache: dict[str, str] = {}
_casc_filename_index: dict[str, list[str]] = {}
_casc_cache_loaded = False
_string_cache: dict[str, str] = {}
_string_cache_loaded = False
_global_unit_map: dict[str, ET.Element] = {}
_global_unit_map_loaded = False

_icon_library_units: list[tuple[str, Path]] = []
_icon_library_buildings: list[tuple[str, Path]] = []
_icon_library_abilities: list[tuple[str, Path]] = []
_icon_library_loaded = False


def load_strings() -> None:
    global _string_cache_loaded
    if _string_cache_loaded:
        return

    string_files = [
        STRINGS_ROOT / "GameStrings.txt",
        STRINGS_ROOT / "ObjectStrings.txt",
        STARCOOP_STRINGS_ROOT / "gamestrings.txt",
        STARCOOP_STRINGS_ROOT / "objectstrings.txt",
        VOID_STRINGS_ROOT / "gamestrings.txt",
        VOID_STRINGS_ROOT / "objectstrings.txt",
    ]

    for f in string_files:
        if not f.exists():
            continue
        try:
            content = f.read_text(encoding="utf-8", errors="replace")
            for line in content.splitlines():
                if "=" not in line:
                    continue
                key, _, value = line.partition("=")
                key = key.strip()
                value = value.strip()
                if key and value and "///Auto" not in value:
                    _string_cache[key] = value
        except Exception:
            pass

    _string_cache_loaded = True


def get_string(key: str, default: str = "") -> str:
    load_strings()
    return _string_cache.get(key, default)


def load_casc_file_list() -> None:
    global _casc_cache_loaded
    if _casc_cache_loaded:
        return

    if not CASC_DUMP_EXE.exists() or not SC2_STORAGE_PATH.exists():
        _casc_cache_loaded = True
        return

    print(f"Loading file list from SC2 CASC storage: {SC2_STORAGE_PATH}")
    try:
        result = subprocess.run(
            [str(CASC_DUMP_EXE), "list", str(SC2_STORAGE_PATH), "200000"],
            capture_output=True,
            text=True,
            timeout=300,
        )
        btn_count = 0
        portrait_count = 0
        for line in result.stdout.splitlines():
            if ".dds" not in line or "Full" not in line:
                continue
            parts = line.split()
            if len(parts) < 4:
                continue
            file_path = parts[0]
            file_path_normalized = file_path.replace("\\", "/")
            filename = file_path_normalized.split("/")[-1]
            filename_lower = filename.lower()

            is_btn = filename_lower.startswith("btn-")
            is_portrait = "commanderportrait" in filename_lower
            is_coop = "_coop" in filename_lower or "coop" in file_path_normalized.lower()

            if not (is_btn or is_portrait or is_coop):
                continue

            _casc_file_cache[file_path_normalized] = file_path
            _casc_file_cache[filename_lower] = file_path

            stem = Path(filename).stem.lower()
            if stem not in _casc_filename_index:
                _casc_filename_index[stem] = []
            _casc_filename_index[stem].append(file_path)

            if is_btn:
                btn_count += 1
            if is_portrait:
                portrait_count += 1

        print(f"Found {btn_count} btn icons, {portrait_count} commander portraits in CASC storage")
    except Exception as e:
        print(f"Failed to load CASC file list: {e}")

    _casc_cache_loaded = True


def load_icon_library() -> None:
    global _icon_library_loaded, _icon_library_units, _icon_library_buildings, _icon_library_abilities
    if _icon_library_loaded:
        return

    def _scan_dir(cat_dir: Path) -> list[tuple[str, Path]]:
        result = []
        if not cat_dir.exists():
            return result
        for f in cat_dir.iterdir():
            if f.is_file() and f.suffix.lower() == ".png":
                stem = f.stem.lower()
                result.append((stem, f))
        return result

    _icon_library_units = _scan_dir(ICON_LIBRARY_DIR / "units")
    _icon_library_buildings = _scan_dir(ICON_LIBRARY_DIR / "buildings")
    _icon_library_abilities = _scan_dir(ICON_LIBRARY_DIR / "abilities")
    _icon_library_loaded = True

    print(f"Loaded icon library: {len(_icon_library_units)} units, {len(_icon_library_buildings)} buildings, {len(_icon_library_abilities)} abilities")


def extract_from_casc(casc_path: str, target_path: Path) -> bool:
    if not CASC_DUMP_EXE.exists() or not SC2_STORAGE_PATH.exists():
        return False
    try:
        target_path.parent.mkdir(parents=True, exist_ok=True)
        import tempfile
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            file_list = tmpdir_path / "filelist.txt"
            file_list.write_text(casc_path + "\n", encoding="utf-8")

            result = subprocess.run(
                [str(CASC_DUMP_EXE), "extract", str(SC2_STORAGE_PATH), str(tmpdir_path), str(file_list)],
                capture_output=True,
                text=True,
                timeout=120,
            )

            if result.returncode != 0:
                return False

            extracted = tmpdir_path / casc_path
            if extracted.exists():
                import shutil
                shutil.copy2(extracted, target_path)
                return True

        return False
    except Exception:
        return False


def _extract_from_casc_temp(casc_path: str) -> Path | None:
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".dds", delete=False) as tmp:
        tmp_path = Path(tmp.name)
    try:
        if extract_from_casc(casc_path, tmp_path):
            return tmp_path
    except Exception:
        pass
    return None


def _fuzzy_match_icon(icon_name: str, context: dict | None = None) -> Path | None:
    casc_path = _fuzzy_match_casc_path(icon_name, context)
    if casc_path:
        return _extract_from_casc_temp(casc_path)
    return None


def resolve_icon(icon_path: str, context: dict | None = None) -> Path | None:
    normalized = icon_path.replace("\\", "/").lower()
    filename = normalized.split("/")[-1]

    for root in LOCAL_ICON_ROOTS:
        candidate = root / filename
        if candidate.exists():
            return candidate
        candidate = root / Path(icon_path).name
        if candidate.exists():
            return candidate

    load_casc_file_list()

    if normalized in _casc_file_cache:
        return _extract_from_casc_temp(_casc_file_cache[normalized])

    if filename in _casc_file_cache:
        return _extract_from_casc_temp(_casc_file_cache[filename])

    if context:
        fuzzy_result = _fuzzy_match_icon(Path(icon_path).stem, context)
        if fuzzy_result:
            return fuzzy_result

    return None


def resolve_commander_portrait(runtime: str) -> Path | None:
    short_name = runtime.lower()
    for prefix in ["terran", "protoss", "zerg"]:
        if short_name.startswith(prefix):
            short_name = short_name[len(prefix):]
            break

    name_map = {
        "horner": "hanandhorner",
        "hanandhorner": "hanandhorner",
    }
    portrait_name = name_map.get(short_name, short_name)

    filename = f"ui_commanderportrait_{portrait_name}.dds"
    filename_lower = filename.lower()

    for root in LOCAL_ICON_ROOTS:
        candidate = root / filename
        if candidate.exists():
            return candidate

    load_casc_file_list()
    if filename_lower in _casc_file_cache:
        return _extract_from_casc_temp(_casc_file_cache[filename_lower])

    for stem, paths in _casc_filename_index.items():
        if "commanderportrait" in stem and short_name in stem:
            return _extract_from_casc_temp(paths[0])

    return None


def convert_dds_to_png(source: Path, target: Path) -> bool:
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(source) as img:
            img.save(target)
        return True
    except Exception as e:
        print(f"  Failed to convert {source.name}: {e}")
        return False


def _parse_xml_flexible(content: str) -> ET.Element:
    try:
        return ET.fromstring(content)
    except ET.ParseError:
        pass

    lines = content.splitlines()
    filtered_lines: list[str] = []
    in_decl = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("<?xml"):
            if not filtered_lines:
                filtered_lines.append(line)
            continue
        if stripped.startswith("<!DOCTYPE"):
            continue
        filtered_lines.append(line)

    content = "\n".join(filtered_lines).strip()

    has_catalog_start = "<Catalog" in content
    has_catalog_end = "</Catalog>" in content

    if not has_catalog_start:
        first_tag_idx = -1
        for i, line in enumerate(filtered_lines):
            if line.strip().startswith("<") and not line.strip().startswith("</") and not line.strip().startswith("<?"):
                first_tag_idx = i
                break
        if first_tag_idx >= 0:
            content = "\n".join(filtered_lines[:first_tag_idx]) + "\n<Catalog>\n" + "\n".join(filtered_lines[first_tag_idx:])
        else:
            content = "<Catalog>\n" + content

    if not has_catalog_end:
        content = content + "\n</Catalog>"

    return ET.fromstring(content)


def load_all_units() -> None:
    global _global_unit_map_loaded
    if _global_unit_map_loaded:
        return

    print("Loading all unit definitions from XML files...")

    xml_files = sorted(GAME_DATA_ROOT.glob("UnitData*.xml"))

    if STARCOOP_DATA_ROOT.exists():
        starcoop_unit_xml = STARCOOP_DATA_ROOT / "unitdata.xml"
        if starcoop_unit_xml.exists():
            xml_files.append(starcoop_unit_xml)
        commanders_dir = STARCOOP_DATA_ROOT / "commanders"
        if commanders_dir.exists():
            for cmd_xml in sorted(commanders_dir.glob("*.xml")):
                xml_files.append(cmd_xml)

    for xml_path in xml_files:
        try:
            content = xml_path.read_text(encoding="utf-8")
            root = _parse_xml_flexible(content)
            count = 0
            for elem in root:
                tag = elem.tag
                if not tag.startswith("CUnit"):
                    continue
                if elem.get("removed") == "1":
                    continue
                uid = elem.get("id", "")
                if uid:
                    if uid not in _global_unit_map:
                        _global_unit_map[uid] = elem
                    count += 1
        except Exception as e:
            print(f"  Error loading {xml_path.name}: {e}")

    print(f"Loaded {len(_global_unit_map)} units from {len(xml_files)} files")
    _global_unit_map_loaded = True


def get_unit_elem(unit_id: str) -> ET.Element | None:
    load_all_units()
    return _global_unit_map.get(unit_id)


def get_inherited_value(unit_id: str, getter, visited: set[str] | None = None) -> str:
    if visited is None:
        visited = set()
    if unit_id in visited:
        return ""
    visited.add(unit_id)

    elem = get_unit_elem(unit_id)
    if elem is None:
        return ""

    val = getter(elem)
    if val:
        return val

    parent_id = elem.get("parent", "")
    if parent_id:
        return get_inherited_value(parent_id, getter, visited)

    return ""


def _find_name_by_suffix(core_name: str) -> str:
    if not _string_cache:
        load_strings()
    core_lower = core_name.lower()
    candidates: list[tuple[int, str]] = []
    bad_prefixes = ['原始', '被感染', '帝国', '塔达林', '净化者', '奈拉齐姆', '萨古拉斯', '艾尔']
    for key, val in _string_cache.items():
        if not val or not any('\u4e00' <= c <= '\u9fff' for c in val):
            continue
        if not (key.startswith("Unit/Name/") or key.startswith("ArmyCategory/Name/")):
            continue
        key_parts = key.split("/")
        if len(key_parts) < 3:
            continue
        unit_key = key_parts[-1].lower()
        if unit_key.endswith(core_lower) and len(unit_key) > len(core_lower):
            score = len(key)
            for bp in bad_prefixes:
                if val.startswith(bp):
                    score += 100
            candidates.append((score, val))
    if candidates:
        candidates.sort()
        return candidates[0][1]
    return ""


def get_unit_name(unit_id: str) -> str:
    name = _get_inherited_string(unit_id, lambda uid: get_string(f"Unit/Name/{uid}", ""))
    if name:
        return name

    name = _get_inherited_string(unit_id, lambda uid: get_string(f"ArmyCategory/Name/{uid}", ""))
    if name:
        return name

    name = get_string(f"UserData/TechUnit/{unit_id}_Name", "")
    if name:
        return name

    name = get_string(f"Button/Name/{unit_id}Passive", "")
    if name:
        return name

    def _split_camel_case(name: str) -> list[str]:
        parts = re.findall(r'[A-Z][a-z0-9]*|[a-z0-9]+', name)
        return [p for p in parts if len(p) >= 3]

    camel_parts = _split_camel_case(unit_id)
    if len(camel_parts) >= 2:
        suffixes_to_skip = {
            'burrowed', 'weapon', 'missile', 'egg', 'cocoon', 'dummy',
            'split', 'hunterkiller', 'torrasque', 'raptor', 'swarmling',
            'splitterling', 'hunter', 'leviathan', 'noxious',
            'mp', 'coop', 'hero', 'taldarim', 'purifier', 'shakuras',
            'aiur', 'nerazim', 'khalai', 'kerrigan', 'raynor',
            'stetmann', 'stukov', 'swann', 'nova', 'mengsk',
            'horner', 'han', 'tychus', 'vorazun', 'zeratul',
            'dehaka', 'fenix', 'karax', 'alarak', 'artanis',
            'zagara', 'abathur',
        }
        core_parts = [p for p in camel_parts if p.lower() not in suffixes_to_skip]
        if core_parts:
            for i in range(len(core_parts), 0, -1):
                candidate = ''.join(core_parts[:i])
                name = _get_inherited_string(candidate, lambda uid: get_string(f"Unit/Name/{uid}", ""))
                if name:
                    return name
                name = _get_inherited_string(candidate, lambda uid: get_string(f"ArmyCategory/Name/{uid}", ""))
                if name:
                    return name
                name = get_string(f"UserData/TechUnit/{candidate}_Name", "")
                if name:
                    return name
                name = _find_name_by_suffix(candidate)
                if name:
                    return name

    name = _find_name_by_suffix(unit_id)
    if name:
        return name

    return ""


def get_unit_tooltip(unit_id: str) -> str:
    def getter(uid):
        return get_string(f"Unit/Tooltip/{uid}", "")
    return _get_inherited_string(unit_id, getter)


def get_unit_description(unit_id: str) -> str:
    def getter(uid):
        return get_string(f"Unit/Description/{uid}", "")
    return _get_inherited_string(unit_id, getter)


def _get_inherited_string(unit_id: str, getter, visited: set[str] | None = None) -> str:
    if visited is None:
        visited = set()
    if unit_id in visited:
        return ""
    visited.add(unit_id)

    val = getter(unit_id)
    if val:
        return val

    elem = get_unit_elem(unit_id)
    if elem is not None:
        parent_id = elem.get("parent", "")
        if parent_id:
            return _get_inherited_string(parent_id, getter, visited)

    return ""


def get_editor_categories(unit_id: str) -> str:
    def getter(elem):
        cat = elem.find("EditorCategories")
        return cat.get("value", "") if cat is not None else ""
    return get_inherited_value(unit_id, getter)


def get_unit_icon(unit_id: str) -> str:
    def getter(elem):
        for card_layout in elem.findall(".//CardLayouts"):
            first_btn = card_layout.find("LayoutButtons")
            if first_btn is not None:
                face = first_btn.get("Face", "")
                if face:
                    return face
        return ""
    return get_inherited_value(unit_id, getter)


BUILDING_KEYWORDS = [
    "Hatchery", "Lair", "Hive", "Spire", "GreaterSpire",
    "Den", "Pool", "Chamber", "Cavern", "Nest", "Pit",
    "Forge", "Cybernetics", "Robotics", "Stargate", "Twilight", "Citadel", "Fleet",
    "Armory", "Barracks", "Factory", "Starport", "Engineering",
    "Turret", "Bunker", "Depot", "Refinery", "Extractor", "Assimilator",
    "Nydus", "Crawler", "Beacon", "Cocoon", "Spine", "Spore",
    "CommandCenter", "Orbital", "Planetary", "Nexus", "Hatchery",
    "Building", "Structure", "Tower", "Shrine", "Templar",
    "DarkShrine", "RoboticsFacility", "Bay", "Lab", "Academy",
    "SupplyDepot", "MissileTurret", "SensorTower", "PhysicsLab",
    "CovertOps", "GhostAcademy", "Reactor", "TechLab",
    "EvolutionChamber", "HydraliskDen", "LurkerDen", "RoachWarren",
    "UltraliskCavern", "BanelingNest", "InfestationPit",
    "SpawningPool", "EvoChamber",
    "Gateway", "WarpGate", "Pylon", "Cannon", "ShieldBattery",
    "StasisTrap", "Mothership",
    "PowerTower", "GarysDen", "Infested",
    "ReviveBeacon", "ReviveCocoon",
]

UNIT_KEYWORDS = [
    "Larva", "Egg", "Broodling", "Locust", "LavaWorm",
    "Drone", "Overlord", "Overseer", "Zergling", "Baneling",
    "Roach", "Ravager", "Hydralisk", "Lurker", "Mutalisk",
    "Corruptor", "BroodLord", "Viper", "Ultralisk", "SwarmHost",
    "Infestor", "Queen",
    "Zealot", "Stalker", "Sentry", "Adept", "HighTemplar",
    "DarkTemplar", "Immortal", "Colossus", "Disruptor",
    "Phoenix", "VoidRay", "Carrier", "Mothership", "Oracle", "Tempest", "WarpPrism", "Observer",
    "Marine", "Marauder", "Firebat", "Reaper", "Ghost", "Medic",
    "Vulture", "SiegeTank", "Hellion", "Hellbat", "Cyclone", "Thor", "Goliath", "Diamondback",
    "Wraith", "Viking", "Medivac", "Raven", "Banshee", "Battlecruiser", "Liberator",
    "SCV", "MULE", "WidowMine", "AutoTurret",
    "Hero", "Elite", "Elites",
]


def _has_building_keyword(unit_id: str) -> bool:
    uid_lower = unit_id.lower()
    for kw in BUILDING_KEYWORDS:
        if kw.lower() in uid_lower:
            return True
    return False


def _has_unit_keyword(unit_id: str) -> bool:
    uid_lower = unit_id.lower()
    for kw in UNIT_KEYWORDS:
        if kw.lower() in uid_lower:
            return True
    return False


def get_unit_type(unit_id: str) -> str:
    cats = get_editor_categories(unit_id)
    if "ObjectType:Structure" in cats or "ObjectType:Building" in cats:
        return "building"
    if "ObjectType:Unit" in cats or "ObjectType:Hero" in cats:
        return "unit"

    if _has_building_keyword(unit_id) and not _has_unit_keyword(unit_id):
        return "building"
    if _has_unit_keyword(unit_id) and not _has_building_keyword(unit_id):
        return "unit"

    elem = get_unit_elem(unit_id)
    if elem is not None:
        footprint = elem.find("Footprint")
        if footprint is not None:
            return "building"
        speed = elem.find("Speed")
        if speed is not None:
            return "unit"
        weapon = elem.find("WeaponArray")
        if weapon is not None:
            pass

    return ""


def unit_belongs_to_commander(unit_id: str, spec: dict, dedicated_units: set[str]) -> bool:
    if unit_id in dedicated_units:
        return True

    if unit_id == spec.get("casterId", ""):
        return True

    faction = spec.get("faction", "")
    if faction:
        cats = get_editor_categories(unit_id)
        if faction in cats:
            return True

    prefixes = spec.get("prefixes", [])
    for prefix in prefixes:
        if unit_id.startswith(prefix):
            return True

    return False


def load_dedicated_unit_ids(xml_filename: str) -> set[str]:
    if not xml_filename:
        return set()
    xml_path = GAME_DATA_ROOT / xml_filename
    if not xml_path.exists():
        return set()

    ids = set()
    try:
        content = xml_path.read_text(encoding="utf-8")
        root = _parse_xml_flexible(content)
        for elem in root:
            if elem.tag.startswith("CUnit") and elem.get("removed") != "1":
                uid = elem.get("id", "")
                if uid:
                    ids.add(uid)
    except Exception:
        pass
    return ids


def load_runtime_unit_ids(runtime: str) -> set[str]:
    short_name = runtime
    for prefix in ["Zerg", "Protoss", "Terran"]:
        if short_name.startswith(prefix):
            short_name = short_name[len(prefix):]
            break

    runtime_file = RUNTIME_ROOT / f"LibE0EAE146_{short_name}Runtime.galaxy"
    if not runtime_file.exists():
        return set()

    ids = set()
    try:
        content = runtime_file.read_text(encoding="utf-8")
        allow_pattern = re.compile(r'AllowUnitIfPresent\(\w+,\s*"([A-Za-z0-9_]+)"\)')
        for match in allow_pattern.finditer(content):
            uid = match.group(1)
            if uid:
                ids.add(uid)
    except Exception:
        pass
    return ids


def _is_non_combat_unit(unit_id: str) -> bool:
    uid_lower = unit_id.lower()
    exclude_suffixes = [
        'weapon', 'missile', 'burrowed', 'egg', 'cocoon', 'dummy',
        'corpse', 'shade', 'hallucination', 'phasing', 'rooted',
        'attackmissile', 'bomber', 'attack',
    ]
    for suf in exclude_suffixes:
        if uid_lower.endswith(suf):
            return True
    exclude_contains = [
        'weapon', 'missile', 'dummy', 'corpse',
    ]
    for kw in exclude_contains:
        if kw in uid_lower and uid_lower != kw:
            if len(uid_lower) > len(kw) + 3:
                return True
    return False


def collect_commander_units_and_buildings(spec: dict) -> tuple[list[dict], list[dict]]:
    load_all_units()
    load_strings()

    dedicated_ids = load_dedicated_unit_ids(spec.get("unitData", ""))
    runtime_ids = load_runtime_unit_ids(spec.get("runtime", ""))
    all_dedicated = dedicated_ids | runtime_ids

    units = []
    buildings = []
    seen_ids: set[str] = set()

    for unit_id in _global_unit_map:
        if unit_id in seen_ids:
            continue

        if not unit_belongs_to_commander(unit_id, spec, all_dedicated):
            continue

        if _is_non_combat_unit(unit_id):
            continue

        utype = get_unit_type(unit_id)
        if not utype:
            continue

        seen_ids.add(unit_id)

        name = get_unit_name(unit_id)
        tooltip = get_unit_tooltip(unit_id)
        description = get_unit_description(unit_id)
        icon = get_unit_icon(unit_id)

        item = {
            "id": unit_id,
            "name": name or unit_id,
            "description": tooltip or description or "",
            "icon": icon,
            "image": "",
        }

        if utype == "building":
            buildings.append(item)
        else:
            units.append(item)

    return units, buildings


def get_inherited_card_layouts(unit_id: str, visited: set[str] | None = None) -> list[ET.Element]:
    if visited is None:
        visited = set()
    if unit_id in visited:
        return []
    visited.add(unit_id)

    elem = get_unit_elem(unit_id)
    if elem is None:
        return []

    layouts = elem.findall("CardLayouts")
    if layouts:
        return layouts

    parent_id = elem.get("parent", "")
    if parent_id:
        return get_inherited_card_layouts(parent_id, visited)

    return []


def extract_topbar_abilities(spec: dict) -> list[dict]:
    caster_id = spec.get("casterId", "")
    if not caster_id:
        return []

    caster_elem = get_unit_elem(caster_id)
    if caster_elem is None:
        return []

    abilities = []
    seen_icons: set[str] = set()

    card_layouts = get_inherited_card_layouts(caster_id)
    for card in card_layouts:
        card_id = card.get("CardId", "")
        if card_id:
            continue
        for btn in card.findall("LayoutButtons"):
            btype = btn.get("Type", "")
            face = btn.get("Face", "")
            abil_cmd = btn.get("AbilCmd", "")
            row = btn.get("Row", "")
            col = btn.get("Column", "")

            if not face or face == "CancelBuilding":
                continue

            if btype == "Passive" and not abil_cmd:
                continue

            if face in seen_icons:
                continue
            seen_icons.add(face)

            abil_id = ""
            if abil_cmd and "," in abil_cmd:
                abil_id = abil_cmd.split(",")[0]

            name = ""
            tooltip = ""
            if abil_id:
                name = get_string(f"Abil/Name/{abil_id}", "")
                tooltip = get_string(f"Abil/Tooltip/{abil_id}", "")
            if not name:
                name = get_string(f"Button/Name/{face}", "")
            if not tooltip:
                tooltip = get_string(f"Button/Tooltip/{face}", "")

            abilities.append({
                "id": abil_id or face,
                "name": name or face,
                "description": tooltip or "",
                "icon": face,
                "image": "",
                "category": f"Row:{row},Col:{col}",
            })

    return abilities


def resolve_icon_casc_path(icon_path: str, context: dict | None = None, item_id: str = "") -> str | None:
    normalized = icon_path.replace("\\", "/").lower()
    filename = normalized.split("/")[-1]

    for root in LOCAL_ICON_ROOTS:
        candidate = root / filename
        if candidate.exists():
            return str(candidate)
        candidate = root / Path(icon_path).name
        if candidate.exists():
            return str(candidate)

    load_casc_file_list()

    if normalized in _casc_file_cache:
        return _casc_file_cache[normalized]

    if filename in _casc_file_cache:
        return _casc_file_cache[filename]

    if context:
        fuzzy_casc = _fuzzy_match_casc_path(item_id or Path(icon_path).stem, context)
        if fuzzy_casc:
            return fuzzy_casc

    return None


def _match_icon_library(icon_name: str, context: dict | None = None) -> Path | None:
    load_icon_library()
    icon_lower = icon_name.lower()
    context = context or {}
    commander = (context.get("commander", "") or "").lower()
    item_type = (context.get("type", "") or "").lower()
    race = (context.get("race", "") or "").lower()

    if item_type == "unit":
        icon_list = _icon_library_units
    elif item_type == "building":
        icon_list = _icon_library_buildings
    elif item_type == "ability":
        icon_list = _icon_library_abilities
    else:
        icon_list = _icon_library_units + _icon_library_buildings + _icon_library_abilities

    if not icon_list:
        return None

    search_names = [icon_lower]
    if commander and icon_lower.endswith(commander):
        base_name = icon_lower[:-len(commander)]
        if len(base_name) >= 3:
            search_names.insert(0, base_name)
    if commander and icon_lower.startswith(commander):
        base_name = icon_lower[len(commander):]
        if len(base_name) >= 3:
            search_names.insert(0, base_name)
    if icon_lower.endswith("mp"):
        base_name = icon_lower[:-2]
        if len(base_name) >= 3:
            search_names.insert(0, base_name)
    if "mp" in icon_lower:
        base_name = icon_lower.replace("mp", "")
        if len(base_name) >= 3:
            search_names.append(base_name)

    def _split_camel_case(name: str) -> list[str]:
        parts = re.findall(r'[A-Z][a-z0-9]*|[a-z0-9]+', name)
        return [p.lower() for p in parts if len(p) >= 3]

    camel_parts = _split_camel_case(icon_name)
    if len(camel_parts) >= 2:
        for part in camel_parts:
            if part not in search_names:
                search_names.append(part)

    tokens = re.findall(r'[a-z0-9]+', icon_lower)
    if len(tokens) >= 2:
        for i in range(len(tokens)):
            part = tokens[i]
            if len(part) >= 3 and part not in search_names:
                search_names.append(part)

    bad_keywords = [
        'collection', 'mecha', 'primal', 'taldarim', 'purifier', 'covertops',
        'umojan', 'junker', 'remastered', 'blizzcon', 'golden', 'collectoredition',
        'eidolon', 'aquatic', 'bone', 'tauren', 'merc', 'mercenary', 'silver',
        'iharii', 'dark', 'aiur', 'nerazim', 'nocord', 'hev',
        'upgraded', 'upgrade', 'webby', 'mutant', 'commando',
    ]

    def _calc_score(stem: str, search_name: str) -> int:
        score = 0
        stem_lower = stem.lower()
        name_tokens = re.findall(r'[a-z0-9]+', stem_lower)
        search_tokens = re.findall(r'[a-z0-9]+', search_name)
        meaningful_name = [t for t in name_tokens if t not in {'btn', 'unit', 'building', 'ability', 'zerg', 'terran', 'protoss'} and len(t) > 2]
        meaningful_search = [t for t in search_tokens if len(t) > 2]

        if not meaningful_search:
            return -999

        exact_match = False
        for mt in meaningful_name:
            for st in meaningful_search:
                if mt == st:
                    score += 50
                    exact_match = True
                elif st in mt and len(st) >= 4:
                    score += 20
                elif mt in st and len(mt) >= 4:
                    score += 15

        if not exact_match:
            matched = sum(1 for t in meaningful_search if any(t in nt for nt in meaningful_name))
            ratio = matched / max(len(meaningful_search), 1)
            if ratio < 0.3:
                return -999
            score += int(ratio * 30)

        if race and race in stem_lower:
            score += 15

        for kw in bad_keywords:
            if kw in stem_lower:
                score -= 30

        score -= len(name_tokens) * 2

        return score

    best_score = -999
    best_path = None

    for search_name in search_names:
        for stem, path in icon_list:
            s = _calc_score(stem, search_name)
            if s > best_score:
                best_score = s
                best_path = path

    if best_score > 10:
        return best_path
    return None


def _fuzzy_match_casc_path(icon_name: str, context: dict | None = None) -> str | None:
    load_casc_file_list()
    if not _casc_filename_index:
        return None

    icon_lower = icon_name.lower()
    context = context or {}
    commander = (context.get("commander", "") or "").lower()
    item_type = (context.get("type", "") or "").lower()
    race = (context.get("race", "") or "").lower()

    search_names = [icon_lower]
    if commander and icon_lower.endswith(commander):
        base_name = icon_lower[:-len(commander)]
        if len(base_name) >= 3:
            search_names.insert(0, base_name)
    if commander and icon_lower.startswith(commander):
        base_name = icon_lower[len(commander):]
        if len(base_name) >= 3:
            search_names.insert(0, base_name)
    if icon_lower.endswith("mp"):
        base_name = icon_lower[:-2]
        if len(base_name) >= 3:
            search_names.insert(0, base_name)
    if "mp" in icon_lower:
        base_name = icon_lower.replace("mp", "")
        if len(base_name) >= 3:
            search_names.append(base_name)

    def _split_camel_case(name: str) -> list[str]:
        parts = re.findall(r'[A-Z][a-z0-9]*|[a-z0-9]+', name)
        return [p.lower() for p in parts if len(p) >= 3]

    camel_parts = _split_camel_case(icon_name)
    if len(camel_parts) >= 2:
        for part in camel_parts:
            if part not in search_names:
                search_names.append(part)

    tokens = re.findall(r'[a-z0-9]+', icon_lower)
    if len(tokens) >= 2:
        for i in range(len(tokens)):
            part = tokens[i]
            if len(part) >= 3 and part not in search_names:
                search_names.append(part)

    best_overall_score = -999
    best_overall_path = None

    for search_name in search_names:
        tokens = re.findall(r'[a-z0-9]+', search_name)
        if not tokens:
            continue

        meaningful_tokens = [t for t in tokens if len(t) >= 3]
        if not meaningful_tokens:
            continue

        best_score = -999
        best_path = None

        basic_suffix_keywords = ['rcz', 'ex3', 'classic']
        bad_suffix_keywords = [
            'collection', 'mecha', 'primal', 'taldarim', 'purifier', 'covertops',
            'umojan', 'junker', 'remastered', 'blizzcon', 'golden', 'collectoredition',
            'eidolon', 'aquatic', 'bone', 'tauren', 'merc', 'mercenary', 'silver',
            'iharii', 'dark', 'aiur', 'nerazim', 'nocord', 'hev',
            'upgraded', 'upgrade',
        ]

        generic_ability_keywords = [
            'move', 'attack', 'stop', 'hold', 'patrol', 'cancel', 'repair',
            'gather', 'return', 'load', 'unload', 'burrow', 'unburrow',
            'siege', 'unsiege', 'morph', 'evolve', 'build', 'train',
        ]

        def _race_matches(stem: str) -> bool:
            if not race:
                return True
            if race in stem:
                return True
            race_map = {
                "zerg": ["zerg", "infested", "infestor"],
                "protoss": ["protoss", "taldarim", "purifier", "nerazim", "khalai", "aiur"],
                "terran": ["terran", "raynor", "swann", "nova", "mengsk", "horner", "han", "tychus"],
            }
            if race in race_map:
                for r in race_map[race]:
                    if r in stem:
                        return True
            return False

        def _is_generic_ability(stem: str) -> bool:
            for kw in generic_ability_keywords:
                if kw == stem or f"-{kw}" in stem or stem.endswith(kw):
                    return True
            return False

        def _version_score(stem: str) -> int:
            score = 0
            stem_lower = stem.lower()
            parts = re.findall(r'[a-z0-9]+', stem_lower)
            score -= len(parts) * 2

            if item_type == "unit" and stem_lower.startswith("btn-unit-") and race:
                prefix = f"btn-unit-{race}-"
                if stem_lower.startswith(prefix):
                    rest = stem_lower[len(prefix):]
                    if rest == search_name:
                        score += 40
                    elif search_name in rest:
                        extra = rest[len(search_name):]
                        if extra and extra[0] == '-':
                            score += 10

            if item_type == "building" and stem_lower.startswith("btn-building-") and race:
                prefix = f"btn-building-{race}-"
                if stem_lower.startswith(prefix):
                    rest = stem_lower[len(prefix):]
                    if rest == search_name:
                        score += 40
                    elif search_name in rest:
                        extra = rest[len(search_name):]
                        if extra and extra[0] == '-':
                            score += 10

            for kw in bad_suffix_keywords:
                if kw in stem_lower:
                    score -= 12
            for kw in basic_suffix_keywords:
                if kw in stem_lower:
                    score -= 3
            return score

        for stem, paths in _casc_filename_index.items():
            stem_lower = stem.lower()
            score = 0

            matched_tokens = 0
            for token in meaningful_tokens:
                if token in stem_lower:
                    matched_tokens += 1
                    score += len(token) * 2

            if matched_tokens == 0:
                continue

            token_match_ratio = matched_tokens / len(meaningful_tokens)
            if token_match_ratio < 0.4:
                continue

            if commander and commander in stem_lower:
                score += 10

            type_match = False
            if item_type == "unit":
                if "btn-unit" in stem_lower:
                    score += 25
                    type_match = True
                elif "btn-building" in stem_lower:
                        continue
                elif "btn-upgrade" in stem_lower or "btn-progression" in stem_lower:
                    continue
                elif _is_generic_ability(stem_lower):
                    continue
            elif item_type == "building":
                if "btn-building" in stem_lower:
                    score += 25
                    type_match = True
                elif "btn-unit" in stem_lower:
                    continue
                elif "btn-upgrade" in stem_lower or "btn-progression" in stem_lower:
                    continue
                elif _is_generic_ability(stem_lower):
                    continue
            elif item_type == "ability":
                if "btn-ability" in stem_lower:
                    score += 10
                    type_match = True

            if race and _race_matches(stem_lower):
                score += 12
            elif race and not _race_matches(stem_lower) and type_match:
                score -= 5

            score += _version_score(stem_lower)

            min_score = max(sum(len(t) for t in meaningful_tokens) * 0.5, 8)
            if type_match:
                min_score = max(sum(len(t) for t in meaningful_tokens) * 0.3, 6)

            if score > best_score and score >= min_score:
                best_score = score
                best_path = paths[0]

        if best_score > best_overall_score:
            best_overall_score = best_score
            best_overall_path = best_path

    return best_overall_path


def batch_extract_and_save_icons(items: list[dict], output_dir: Path, context: dict | None = None) -> int:
    pending: list[tuple[str, Path, dict]] = []
    local_pending: list[tuple[Path, Path, dict]] = []
    icon_library_pending: list[tuple[Path, Path, dict]] = []
    context = context or {}
    item_type = (context.get("type", "") or "").lower()
    is_unit_or_building = item_type in ("unit", "building")

    load_icon_library()

    for item in items:
        icon_path = item.get("icon", "")
        item_id = item.get("id", "")
        if not icon_path and not item_id:
            continue

        safe_name = re.sub(r'[^\w\-\.]', '_', item_id or Path(icon_path).stem)
        filename = safe_name + ".png"
        target = output_dir / filename

        if target.exists():
            item["image"] = filename
            continue

        found_source = None
        found_is_local = False
        found_from_library = False

        if is_unit_or_building and item_id and context:
            unit_ctx = context.copy()
            unit_ctx["type"] = item_type
            lib_path = _match_icon_library(item_id, unit_ctx)
            if lib_path:
                found_source = lib_path
                found_from_library = True

        if not found_source and not is_unit_or_building and context and item_id:
            lib_path = _match_icon_library(item_id, context)
            if lib_path:
                found_source = lib_path
                found_from_library = True

        if not found_source and icon_path:
            normalized = icon_path.replace("\\", "/").lower()
            filename_only = normalized.split("/")[-1]

            for root in LOCAL_ICON_ROOTS:
                candidate = root / filename_only
                if candidate.exists() and candidate.is_file():
                    found_source = candidate
                    found_is_local = True
                    break
                candidate = root / Path(icon_path).name
                if candidate.exists() and candidate.is_file():
                    found_source = candidate
                    found_is_local = True
                    break

            if not found_source:
                load_casc_file_list()
                if normalized in _casc_file_cache:
                    found_source = _casc_file_cache[normalized]
                elif filename_only in _casc_file_cache:
                    found_source = _casc_file_cache[filename_only]

        if not found_source and icon_path:
            dds_name = Path(icon_path).name + ".dds"
            dds_lower = dds_name.lower()
            load_casc_file_list()
            if dds_lower in _casc_file_cache:
                found_source = _casc_file_cache[dds_lower]

        if not found_source and icon_path and context:
            ability_ctx = context.copy()
            if is_unit_or_building:
                ability_ctx["type"] = "ability"
            lib_path = _match_icon_library(Path(icon_path).stem, ability_ctx)
            if lib_path:
                found_source = lib_path
                found_from_library = True

        if not found_source and icon_path and context:
            ability_ctx = context.copy()
            if is_unit_or_building:
                ability_ctx["type"] = "ability"
            casc_path = _fuzzy_match_casc_path(Path(icon_path).stem, ability_ctx)
            if casc_path:
                found_source = casc_path

        if not found_source and not is_unit_or_building and context and item_id:
            casc_path = _fuzzy_match_casc_path(item_id, context)
            if casc_path:
                found_source = casc_path

        if found_source:
            if found_from_library:
                icon_library_pending.append((found_source, target, item))
            elif found_is_local:
                local_pending.append((found_source, target, item))
            else:
                pending.append((found_source, target, item))

    count = sum(1 for item in items if item.get("image"))

    for source_path, target, item in icon_library_pending:
        try:
            import shutil
            shutil.copy2(source_path, target)
            safe_name = re.sub(r'[^\w\-\.]', '_', item.get("id", ""))
            item["image"] = safe_name + ".png"
            count += 1
        except Exception:
            pass

    for source_path, target, item in local_pending:
        if convert_dds_to_png(source_path, target):
            safe_name = re.sub(r'[^\w\-\.]', '_', item.get("id", ""))
            item["image"] = safe_name + ".png"
            count += 1

    if pending:
        import tempfile
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            file_list_path = tmpdir_path / "filelist.txt"
            with open(file_list_path, "w", encoding="utf-8") as f:
                for casc_path, _, _ in pending:
                    f.write(casc_path + "\n")

            if CASC_DUMP_EXE.exists() and SC2_STORAGE_PATH.exists():
                try:
                    subprocess.run(
                        [str(CASC_DUMP_EXE), "extract", str(SC2_STORAGE_PATH), str(tmpdir_path), str(file_list_path)],
                        capture_output=True,
                        text=True,
                        timeout=300,
                    )
                except Exception:
                    pass

            for casc_path, target, item in pending:
                extracted = tmpdir_path / casc_path
                if extracted.exists() and extracted.is_file():
                    if convert_dds_to_png(extracted, target):
                        safe_name = re.sub(r'[^\w\-\.]', '_', item.get("id", ""))
                        item["image"] = safe_name + ".png"
                        count += 1

    return count


def get_commander_race(runtime: str) -> str:
    if runtime.startswith("Terran"):
        return "Terran"
    if runtime.startswith("Protoss"):
        return "Protoss"
    if runtime.startswith("Zerg"):
        return "Zerg"
    return ""


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    PORTRAIT_DIR.mkdir(parents=True, exist_ok=True)

    load_strings()
    load_all_units()

    manifest: dict = {
        "generated_at": datetime.now(timezone.utc).astimezone().isoformat(),
        "commanders": [],
    }

    for spec in COMMANDER_SPECS:
        runtime = spec["runtime"]
        name = spec["name"]
        race = get_commander_race(runtime)
        print(f"\nProcessing {name} ({runtime})...")

        units, buildings = collect_commander_units_and_buildings(spec)
        abilities = extract_topbar_abilities(spec)

        print(f"  Units: {len(units)}, Buildings: {len(buildings)}, Abilities: {len(abilities)}")

        commander_out_dir = OUTPUT_DIR / runtime
        commander_out_dir.mkdir(parents=True, exist_ok=True)

        short_name = runtime
        for prefix in ["Terran", "Protoss", "Zerg"]:
            if short_name.startswith(prefix):
                short_name = short_name[len(prefix):]
                break

        unit_ctx = {"commander": short_name, "type": "unit", "runtime": runtime, "race": race.lower()}
        building_ctx = {"commander": short_name, "type": "building", "runtime": runtime, "race": race.lower()}
        ability_ctx = {"commander": short_name, "type": "ability", "runtime": runtime, "race": race.lower()}

        unit_icon_count = batch_extract_and_save_icons(units, commander_out_dir, unit_ctx)
        building_icon_count = batch_extract_and_save_icons(buildings, commander_out_dir, building_ctx)
        abil_icon_count = batch_extract_and_save_icons(abilities, commander_out_dir, ability_ctx)

        print(f"  Icons saved: units={unit_icon_count}, buildings={building_icon_count}, abilities={abil_icon_count}")

        portrait_filename = f"{runtime}.png"
        portrait_target = PORTRAIT_DIR / portrait_filename

        if not portrait_target.exists():
            portrait_src = resolve_commander_portrait(runtime)
            if portrait_src:
                convert_dds_to_png(portrait_src, portrait_target)

        commander_entry = {
            "runtime": runtime,
            "displayName": name,
            "name": name,
            "race": race,
            "image": portrait_filename if portrait_target.exists() else "",
            "units": units,
            "buildings": buildings,
            "abilities": abilities,
            "stats": {
                "units": len(units),
                "buildings": len(buildings),
                "abilities": len(abilities),
            },
        }

        manifest["commanders"].append(commander_entry)

    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    total_units = sum(len(c["units"]) for c in manifest["commanders"])
    total_buildings = sum(len(c["buildings"]) for c in manifest["commanders"])
    total_abilities = sum(len(c["abilities"]) for c in manifest["commanders"])

    print(f"\nDone! Manifest saved to {MANIFEST_PATH}")
    print(f"Total: {len(manifest['commanders'])} commanders, "
          f"{total_units} units, {total_buildings} buildings, {total_abilities} abilities")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
