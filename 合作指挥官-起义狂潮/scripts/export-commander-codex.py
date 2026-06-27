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

OUTPUT_DIR = ROOT / "web-launcher" / "exported-commander-codex"
PORTRAIT_DIR = OUTPUT_DIR / "portraits"
MANIFEST_PATH = OUTPUT_DIR / "manifest.json"

SC2_STORAGE_PATH = Path(r"E:\SC2\SC2new\StarCraft II")
CASC_DUMP_EXE = Path(r"C:\tools\casc\CascDump\bin\Debug\net9.0\CascDump.exe")

LOCAL_ICON_ROOTS = [
    Path(r"C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\tools\launcher_mpq\Assets\Textures"),
    Path(r"C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\整理输出\合作指挥官-起义狂潮\Mods\XM\XMCore.SC2Mod\Assets\Textures"),
    Path(r"C:\Users\22448\Downloads\合作指挥官版起义狂潮0.81\Mods\XM\XMCore.SC2Mod\Assets\Textures"),
]

COMMANDER_SPECS = [
    {"runtime": "ZergAbathur", "name": "阿巴瑟", "unitData": "UnitData_Abathur.xml", "abilData": "AbilData_Abathur.xml"},
    {"runtime": "ProtossAlarak", "name": "阿拉纳克", "unitData": "UnitData_Alarak.xml", "abilData": "AbilData_Alarak.xml"},
    {"runtime": "ProtossArtanis", "name": "阿塔尼斯", "unitData": "UnitData_Artanis.xml", "abilData": "AbilData_Artanis.xml"},
    {"runtime": "ZergDehaka", "name": "德哈卡", "unitData": "UnitData_Dehaka.xml", "abilData": "AbilData_Dehaka.xml"},
    {"runtime": "ProtossFenix", "name": "菲尼克斯", "unitData": "UnitData_Fenix.xml", "abilData": "AbilData_Fenix.xml"},
    {"runtime": "TerranHorner", "name": "汉与霍纳", "unitData": "UnitData_Horner.xml", "abilData": "AbilData_Horner.xml"},
    {"runtime": "ProtossKarax", "name": "凯拉克斯", "unitData": "UnitData_Karax.xml", "abilData": "AbilData_Karax.xml"},
    {"runtime": "ZergKerrigan", "name": "凯瑞甘", "unitData": "UnitData_Kerrigan.xml", "abilData": "AbilData_Kerrigan.xml"},
    {"runtime": "TerranMengsk", "name": "蒙斯克", "unitData": "UnitData_Mengsk.xml", "abilData": "AbilData_Mengsk.xml"},
    {"runtime": "TerranNova", "name": "诺娃", "unitData": "UnitData_Nova.xml", "abilData": "AbilData_Nova.xml"},
    {"runtime": "TerranRaynor", "name": "雷诺", "unitData": "UnitData_Raynor.xml", "abilData": "AbilData_Raynor.xml"},
    {"runtime": "ZergStetmann", "name": "斯台特曼", "unitData": "UnitData_Stetmann.xml", "abilData": "AbilData_Stetmann.xml"},
    {"runtime": "ZergStukov", "name": "斯托科夫", "unitData": "UnitData_Stukov.xml", "abilData": "AbilData_Stukov.xml"},
    {"runtime": "TerranSwann", "name": "斯旺", "unitData": "UnitData_Swann.xml", "abilData": "AbilData_Swann.xml"},
    {"runtime": "TerranTychus", "name": "泰凯斯", "unitData": "UnitData_Tychus.xml", "abilData": "AbilData_Tychus.xml"},
    {"runtime": "ProtossVorazun", "name": "沃拉尊", "unitData": "UnitData_Vorazun.xml", "abilData": "AbilData_Vorazun.xml"},
    {"runtime": "ZergZagara", "name": "扎加拉", "unitData": "UnitData_Zagara.xml", "abilData": "AbilData_Zagara.xml"},
    {"runtime": "ProtossZeratul", "name": "泽拉图", "unitData": "UnitData_Zeratul.xml", "abilData": "AbilData_Zeratul.xml"},
]

_casc_file_cache: dict[str, str] = {}
_casc_cache_loaded = False
_string_cache: dict[str, str] = {}
_string_cache_loaded = False


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
            [str(CASC_DUMP_EXE), "list", str(SC2_STORAGE_PATH), "1000000"],
            capture_output=True,
            text=True,
            timeout=300,
        )
        for line in result.stdout.splitlines():
            if "_coop.dds" in line and "Full" in line:
                parts = line.split()
                if len(parts) >= 4:
                    file_path = parts[0]
                    file_path_normalized = file_path.replace("\\", "/")
                    _casc_file_cache[file_path_normalized] = file_path
                    filename = file_path_normalized.split("/")[-1]
                    assets_path = f"Assets/Textures/{filename}"
                    _casc_file_cache[assets_path] = file_path
                    _casc_file_cache[filename.lower()] = file_path
        print(f"Found {len(_casc_file_cache)} coop DDS files in CASC storage")
    except Exception as e:
        print(f"Failed to load CASC file list: {e}")

    _casc_cache_loaded = True


def extract_from_casc(casc_path: str, target_path: Path) -> bool:
    if not CASC_DUMP_EXE.exists() or not SC2_STORAGE_PATH.exists():
        return False
    try:
        target_path.parent.mkdir(parents=True, exist_ok=True)
        result = subprocess.run(
            [str(CASC_DUMP_EXE), "extract", str(SC2_STORAGE_PATH), casc_path, str(target_path)],
            capture_output=True,
            text=True,
            timeout=60,
        )
        return result.returncode == 0 and target_path.exists()
    except Exception:
        return False


def resolve_icon(icon_path: str) -> Path | None:
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
    casc_key = normalized
    if casc_key in _casc_file_cache:
        import tempfile
        with tempfile.NamedTemporaryFile(suffix=".dds", delete=False) as tmp:
            tmp_path = Path(tmp.name)
        try:
            if extract_from_casc(_casc_file_cache[casc_key], tmp_path):
                return tmp_path
        finally:
            pass

    if filename in _casc_file_cache:
        import tempfile
        with tempfile.NamedTemporaryFile(suffix=".dds", delete=False) as tmp:
            tmp_path = Path(tmp.name)
        try:
            if extract_from_casc(_casc_file_cache[filename], tmp_path):
                return tmp_path
        finally:
            pass

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


def parse_unit_xml(xml_path: Path, race: str = "") -> tuple[list[dict], list[dict]]:
    units = []
    buildings = []

    if not xml_path.exists():
        print(f"  Warning: {xml_path.name} not found")
        return units, buildings

    seen_ids: set[str] = set()

    try:
        content = xml_path.read_text(encoding="utf-8")
        root = _parse_xml_flexible(content)

        parent_map: dict[str, ET.Element] = {}
        for elem in root:
            eid = elem.get("id", "")
            if eid:
                parent_map[eid] = elem

        def get_editor_categories(elem: ET.Element, visited: set[str] | None = None) -> str:
            if visited is None:
                visited = set()
            eid = elem.get("id", "")
            if eid in visited:
                return ""
            visited.add(eid)
            cat_elem = elem.find("EditorCategories")
            if cat_elem is not None:
                val = cat_elem.get("value", "")
                if val:
                    return val
            parent_id = elem.get("parent", "")
            if parent_id and parent_id in parent_map:
                return get_editor_categories(parent_map[parent_id], visited)
            return ""

        def get_first_face(elem: ET.Element, visited: set[str] | None = None) -> str:
            if visited is None:
                visited = set()
            eid = elem.get("id", "")
            if eid in visited:
                return ""
            visited.add(eid)
            for card_layout in elem.findall(".//CardLayouts"):
                first_btn = card_layout.find("LayoutButtons")
                if first_btn is not None:
                    face = first_btn.get("Face", "")
                    if face:
                        return face
            parent_id = elem.get("parent", "")
            if parent_id and parent_id in parent_map:
                return get_first_face(parent_map[parent_id], visited)
            return ""

        for unit_elem in root:
            tag = unit_elem.tag
            if not tag.startswith("CUnit"):
                continue
            if unit_elem.get("removed") == "1":
                continue

            unit_id = unit_elem.get("id", "")
            if not unit_id or unit_id in seen_ids:
                continue
            seen_ids.add(unit_id)

            name = get_string(f"Unit/Name/{unit_id}", "")
            tooltip = get_string(f"Unit/Tooltip/{unit_id}", "")
            description = get_string(f"Unit/Description/{unit_id}", "")

            editor_categories = get_editor_categories(unit_elem)

            is_building = "ObjectType:Structure" in editor_categories or "ObjectType:Building" in editor_categories
            is_unit = "ObjectType:Unit" in editor_categories or "ObjectType:Hero" in editor_categories

            if not is_unit and not is_building:
                continue

            icon = get_first_face(unit_elem)

            item = {
                "id": unit_id,
                "name": name or unit_id,
                "description": tooltip or description or "",
                "icon": icon,
                "image": "",
            }

            if is_building:
                buildings.append(item)
            else:
                units.append(item)

    except Exception as e:
        print(f"  Error parsing {xml_path.name}: {e}")
        import traceback
        traceback.print_exc()

    return units, buildings


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


def parse_abil_xml(xml_path: Path, runtime: str = "") -> list[dict]:
    abilities = []

    if not xml_path.exists():
        print(f"  Warning: {xml_path.name} not found")
        return abilities

    seen_ids: set[str] = set()

    try:
        content = xml_path.read_text(encoding="utf-8")
        root = _parse_xml_flexible(content)

        for abil_elem in root:
            tag = abil_elem.tag
            if not tag.startswith("CAbil"):
                continue
            if abil_elem.get("removed") == "1":
                continue

            abil_id = abil_elem.get("id", "")
            if not abil_id or abil_id in seen_ids:
                continue
            seen_ids.add(abil_id)

            name = get_string(f"Abil/Name/{abil_id}", "")
            tooltip = get_string(f"Abil/Tooltip/{abil_id}", "")
            description = get_string(f"Abil/Description/{abil_id}", "")

            icon = ""
            btn_face = abil_elem.find(".//DefaultButtonFace")
            if btn_face is not None:
                icon = btn_face.get("value", "")
            if not icon:
                btn = abil_elem.find(".//Button")
                if btn is not None:
                    icon = btn.get("DefaultButtonFace", "")

            editor_categories = ""
            cat_elem = abil_elem.find("EditorCategories")
            if cat_elem is not None:
                editor_categories = cat_elem.get("value", "")

            if not name and not icon:
                continue

            abilities.append({
                "id": abil_id,
                "name": name or abil_id,
                "description": tooltip or description or "",
                "icon": icon,
                "image": "",
                "category": editor_categories,
            })

    except Exception as e:
        print(f"  Error parsing {xml_path.name}: {e}")
        import traceback
        traceback.print_exc()

    return abilities


def extract_and_save_icons(items: list[dict], output_dir: Path) -> int:
    count = 0
    for item in items:
        icon_path = item.get("icon", "")
        if not icon_path:
            continue

        filename = Path(icon_path).stem + ".png"
        target = output_dir / filename

        if target.exists():
            item["image"] = filename
            count += 1
            continue

        source = resolve_icon(icon_path)
        if source is None:
            source = resolve_icon(Path(icon_path).name + ".dds")

        if source and convert_dds_to_png(source, target):
            item["image"] = filename
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

    manifest: dict = {
        "generated_at": datetime.now(timezone.utc).astimezone().isoformat(),
        "commanders": [],
    }

    for spec in COMMANDER_SPECS:
        runtime = spec["runtime"]
        name = spec["name"]
        race = get_commander_race(runtime)
        print(f"\nProcessing {name} ({runtime})...")

        unit_xml = GAME_DATA_ROOT / spec["unitData"]
        abil_xml = GAME_DATA_ROOT / spec["abilData"]

        units, buildings = parse_unit_xml(unit_xml, race)
        abilities = parse_abil_xml(abil_xml, runtime)

        print(f"  Units: {len(units)}, Buildings: {len(buildings)}, Abilities: {len(abilities)}")

        commander_out_dir = OUTPUT_DIR / runtime
        commander_out_dir.mkdir(parents=True, exist_ok=True)

        unit_icon_count = extract_and_save_icons(units, commander_out_dir)
        building_icon_count = extract_and_save_icons(buildings, commander_out_dir)
        abil_icon_count = extract_and_save_icons(abilities, commander_out_dir)

        print(f"  Icons saved: units={unit_icon_count}, buildings={building_icon_count}, abilities={abil_icon_count}")

        portrait_src = None
        portrait_filename = f"{runtime}.png"
        portrait_target = PORTRAIT_DIR / portrait_filename

        if not portrait_target.exists():
            portrait_src = resolve_icon(f"ui_btn_commanderportrait_{runtime.lower().replace('terran','').replace('protoss','').replace('zerg','')}.dds")
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
