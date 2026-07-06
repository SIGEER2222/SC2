from __future__ import annotations

import html
import json
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MUTATORS_GAMEDATA_PATH = ROOT / "Mods" / "kit_mutations.SC2Mod" / "Base.SC2Data" / "GameData.xml"
MUTATORS_GAMEDATA_ROOT = ROOT / "Mods" / "kit_mutations.SC2Mod" / "Base.SC2Data" / "GameData"
ZH_STRINGS_PATH = ROOT / "Mods" / "kit_mutations.SC2Mod" / "zhCN.SC2Data" / "LocalizedData" / "GameStrings.txt"
EN_STRINGS_PATH = ROOT / "Mods" / "kit_mutations.SC2Mod" / "enUS.SC2Data" / "LocalizedData" / "GameStrings.txt"

OUTPUT_DIR = ROOT / "web-launcher" / "exported-real-mutator-images"
MANIFEST_PATH = OUTPUT_DIR / "manifest.json"
INDEX_PATH = OUTPUT_DIR / "index.html"
README_PATH = OUTPUT_DIR / "README.txt"

# SC2 CASC storage path
SC2_STORAGE_PATH = Path(r"E:\SC2\SC2new\StarCraft II")
CASC_DUMP_EXE = Path(r"C:\tools\casc\CascDump\bin\Debug\net9.0\CascDump.exe")

SOURCE_ROOTS = [
    Path(r"C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\游戏数据\官方合作指挥官\icon-assets\short-path"),
    Path(r"C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\tools\launcher_mpq"),
    Path(r"C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\整理输出\合作指挥官-起义狂潮"),
    Path(r"C:\Users\22448\Downloads\合作指挥官版起义狂潮0.81"),
]

# Cache of files found in SC2 CASC storage
# Maps normalized path (forward slashes) -> original CASC path (backslashes)
_casc_file_cache: dict[str, str] = {}
_casc_cache_loaded = False


def _load_casc_file_list() -> None:
    """Load the list of DDS files from SC2 CASC storage."""
    global _casc_cache_loaded
    if _casc_cache_loaded:
        return

    if not CASC_DUMP_EXE.exists():
        print(f"CascDump.exe not found: {CASC_DUMP_EXE}")
        _casc_cache_loaded = True
        return

    if not SC2_STORAGE_PATH.exists():
        print(f"SC2 storage not found: {SC2_STORAGE_PATH}")
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
            # Format: path size Full True
            # Use rsplit to handle paths with spaces (e.g. "coop_mutators_ wemoveunseen.dds")
            if ".dds" not in line or "Full" not in line:
                continue
            parts = line.rsplit(None, 3)
            if len(parts) < 4:
                continue
            file_path = parts[0]  # Keep original backslashes for extraction
            file_path_normalized = file_path.replace(chr(92), "/")
            # Store with normalized key (forward slashes) -> original path (backslashes)
            _casc_file_cache[file_path_normalized.lower()] = file_path
            # Also store without mods\liberty... prefix for matching Assets\Textures\xxx.dds
            if "base.sc2assets/assets/textures/" in file_path_normalized:
                filename = file_path_normalized.split("/")[-1]
                assets_path = f"Assets/Textures/{filename}"
                _casc_file_cache[assets_path.lower()] = file_path
                # Also store a version without spaces (for matching typo paths like "coop_mutators_ wemoveunseen.dds")
                if " " in filename:
                    no_space = filename.replace(" ", "")
                    no_space_path = f"Assets/Textures/{no_space}"
                    _casc_file_cache[no_space_path.lower()] = file_path
        print(f"Found {len(_casc_file_cache)} DDS files in CASC storage")
    except Exception as e:
        print(f"Failed to load CASC file list: {e}")

    _casc_cache_loaded = True


def resolve_source(asset_path: str) -> tuple[Path | None, str | None]:
    """Returns (source_path, casc_internal_path) where casc_internal_path is the CASC storage path if found."""
    normalized = asset_path.replace("\\", "/")
    # Fix common typo: spaces in filenames (e.g. "coop_mutators_ wemoveunseen.dds")
    normalized = normalized.replace(" ", "")

    # Check local source roots first
    for root in SOURCE_ROOTS:
        candidate = root / normalized
        if candidate.exists():
            return (candidate, None)

    # Check SC2 CASC storage (case-insensitive)
    _load_casc_file_list()
    key = normalized.lower()
    if key in _casc_file_cache:
        # Return the CASC internal path for extraction
        casc_internal_path = _casc_file_cache[key]
        return (Path(casc_internal_path), casc_internal_path)

    return (None, None)


def load_strings(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        result[key] = value
    return result


def resolve_text(key: str | None, zh_strings: dict[str, str], en_strings: dict[str, str]) -> str:
    if not key:
        return ""
    return zh_strings.get(key) or en_strings.get(key) or ""


def convert_image(source: Path, target: Path) -> dict[str, object]:
    with Image.open(source) as image:
        target.parent.mkdir(parents=True, exist_ok=True)
        image.save(target)
        return {
            "width": image.width,
            "height": image.height,
            "mode": image.mode,
            "format": image.format,
        }


def clean_output_dir(output_dir: Path) -> None:
    if not output_dir.exists():
        output_dir.mkdir(parents=True, exist_ok=True)
        return
    for child in output_dir.iterdir():
        if child.is_dir():
            shutil.rmtree(child)
        else:
            child.unlink()


def parse_mutators() -> list[dict[str, str]]:
    results: list[dict[str, str]] = []
    game_data_tree = ET.parse(MUTATORS_GAMEDATA_PATH)
    includes = game_data_tree.getroot().findall("Catalog")
    if not includes:
        raise RuntimeError(f"No catalog includes found in {MUTATORS_GAMEDATA_PATH}")

    for include in includes:
        rel = include.attrib.get("path", "")
        if not rel:
            continue
        catalog_path = MUTATORS_GAMEDATA_ROOT / rel.replace("GameData/", "", 1)
        if not catalog_path.exists():
            continue

        tree = ET.parse(catalog_path)
        root = tree.getroot()
        for mutators_user in root.findall("CUser"):
            if mutators_user.attrib.get("id") != "Mutators":
                continue
            for instance in mutators_user.findall("Instances"):
                instance_id = instance.attrib.get("Id", "")
                if not instance_id or instance_id == "[Default]":
                    continue

                icon_ref = ""
                name_key = ""
                description_key = ""
                for child in instance:
                    if child.tag == "Image":
                        icon_ref = child.attrib.get("Image", "")
                    elif child.tag == "Text":
                        text_key = child.attrib.get("Text", "")
                        if text_key.endswith("_Name"):
                            name_key = text_key
                        elif text_key.endswith("_Description"):
                            description_key = text_key

                results.append({
                    "id": instance_id,
                    "icon_ref": icon_ref,
                    "name_key": name_key,
                    "description_key": description_key,
                    "base_name": Path(icon_ref.replace("\\", "/")).name if icon_ref else "",
                })

    return results


def build_index(entries: list[dict[str, object]]) -> str:
    cards: list[str] = []
    for entry in entries:
        output_file = entry.get("output_file") or ""
        image_html = (
            f'<img src="{html.escape(output_file)}" alt="{html.escape(str(entry["name"]))}">'
            if output_file
            else '<div class="missing">未命中真实贴图</div>'
        )
        cards.append(
            "\n".join(
                [
                    '<article class="card">',
                    f'  <div class="thumb">{image_html}</div>',
                    f'  <div class="name">{html.escape(str(entry["name"]))}</div>',
                    f'  <div class="id">{html.escape(str(entry["id"]))}</div>',
                    f'  <div class="icon-ref">{html.escape(str(entry["icon_ref"]))}</div>',
                    f'  <div class="status">{html.escape(str(entry["status"]))}</div>',
                    f'  <div class="desc">{html.escape(str(entry["description"]))}</div>',
                    "</article>",
                ]
            )
        )

    return "\n".join(
        [
            "<!doctype html>",
            '<html lang="zh-CN">',
            "<head>",
            '  <meta charset="utf-8">',
            "  <title>Mutator Icon Export</title>",
            "  <style>",
            "    body { margin: 0; font-family: Segoe UI, Arial, sans-serif; background: #11161c; color: #e7edf5; }",
            "    .wrap { padding: 20px; }",
            "    h1 { margin: 0 0 8px; font-size: 24px; }",
            "    p { margin: 0 0 18px; color: #aeb8c5; }",
            "    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 14px; }",
            "    .card { background: #18202a; border: 1px solid #253140; border-radius: 8px; overflow: hidden; }",
            "    .thumb { height: 160px; display: flex; align-items: center; justify-content: center; background: #0d1218; }",
            "    .thumb img { max-width: 100%; max-height: 100%; image-rendering: auto; }",
            "    .missing { color: #ffb4b4; font-size: 14px; }",
            "    .name { padding: 10px 12px 2px; font-size: 16px; font-weight: 600; }",
            "    .id, .icon-ref, .status, .desc { padding: 0 12px 10px; font-size: 12px; line-height: 1.45; color: #b9c3cf; word-break: break-all; }",
            "    .status { color: #8fd3ff; }",
            "  </style>",
            "</head>",
            "<body>",
            '  <div class="wrap">',
            "    <h1>因子真实图标导出</h1>",
            "    <p>只展示精确命中的真实贴图；未命中的条目明确标缺失，不使用回退图。</p>",
            '    <section class="grid">',
            *cards,
            "    </section>",
            "  </div>",
            "</body>",
            "</html>",
        ]
    )


def main() -> int:
    clean_output_dir(OUTPUT_DIR)

    zh_strings = load_strings(ZH_STRINGS_PATH)
    en_strings = load_strings(EN_STRINGS_PATH)
    mutators = parse_mutators()

    # Pre-load CASC file list
    _load_casc_file_list()

    entries: list[dict[str, object]] = []
    resolved_count = 0
    missing_count = 0
    temp_files: list[Path] = []

    for item in mutators:
        icon_ref = item["icon_ref"]
        result = resolve_source(icon_ref) if icon_ref else (None, None)
        if not isinstance(result, tuple) or len(result) != 2:
            source_path, casc_path = None, None
        else:
            source_path, casc_path = result
        output_file = f'{item["id"]}.png'
        entry: dict[str, object] = {
            "id": item["id"],
            "name": resolve_text(item["name_key"], zh_strings, en_strings) or item["id"],
            "description": resolve_text(item["description_key"], zh_strings, en_strings),
            "name_key": item["name_key"],
            "description_key": item["description_key"],
            "icon_ref": icon_ref,
            "base_name": item["base_name"],
            "status": "",
            "source_path": str(source_path) if source_path else "",
            "output_file": "",
            "output_path": "",
        }

        if source_path is None:
            entry["status"] = "missing-exact-icon-file"
            missing_count += 1
        else:
            # Check if source is a CASC path (needs extraction)
            if casc_path:
                # Need to extract from CASC
                # CascDump extract: <storage> <out-dir> <file-list.txt>
                # Output preserves directory structure: <out-dir>/<casc-path>
                temp_base = Path(tempfile.gettempdir()) / f"casc_extract_{item['id']}"
                temp_base.mkdir(exist_ok=True)
                temp_files.append(temp_base)

                # Create file list with the CASC path (original backslashes)
                file_list = temp_base / "extract_list.txt"
                file_list.write_text(casc_path + "\n")

                try:
                    result = subprocess.run(
                        [str(CASC_DUMP_EXE), "extract", str(SC2_STORAGE_PATH), str(temp_base), str(file_list)],
                        capture_output=True,
                        text=True,
                        timeout=60,
                    )
                    if result.returncode != 0:
                        entry["status"] = f"casc-extract-failed: {result.stderr[:100] if result.stderr else 'unknown'}"
                        missing_count += 1
                        entries.append(entry)
                        continue

                    # Find the extracted file (it's in a subdirectory structure)
                    extracted_file = temp_base / casc_path  # casc_path has backslashes
                    if not extracted_file.exists():
                        entry["status"] = f"extracted-file-not-found: {extracted_file}"
                        missing_count += 1
                        entries.append(entry)
                        continue

                    source_path = extracted_file
                except Exception as e:
                    entry["status"] = f"casc-extract-error: {e}"
                    missing_count += 1
                    entries.append(entry)
                    continue

            target = OUTPUT_DIR / output_file
            try:
                image_info = convert_image(source_path, target)
                entry["status"] = "resolved-exact-icon-file"
                entry["output_file"] = output_file
                entry["output_path"] = str(target)
                entry.update(image_info)
                resolved_count += 1
            except Exception as e:
                entry["status"] = f"image-convert-error: {e}"
                missing_count += 1

        entries.append(entry)

    # Clean up temp files
    for temp_file in temp_files:
        try:
            if temp_file.exists():
                temp_file.unlink()
        except Exception:
            pass

    manifest = {
        "generated_at": datetime.now(timezone.utc).astimezone().isoformat(),
        "mutators_xml": str(MUTATORS_GAMEDATA_PATH),
        "source_roots": [str(path) for path in SOURCE_ROOTS],
        "resolved_count": resolved_count,
        "missing_count": missing_count,
        "entries": entries,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    INDEX_PATH.write_text(build_index(entries), encoding="utf-8")
    README_PATH.write_text(
        "\n".join(
            [
                "因子真实图标导出结果",
                "",
                "说明：",
                "1. 这里只导出精确命中的真实贴图文件。",
                "2. 未命中的条目说明当前本地没有找到该图标的实体文件，不会回退到错误图片。",
                "3. 详情见 manifest.json；可直接打开 index.html 浏览。",
                "",
                f"Resolved: {resolved_count}",
                f"Missing: {missing_count}",
            ]
        ),
        encoding="utf-8",
    )

    print(
        json.dumps(
            {
                "output_dir": str(OUTPUT_DIR),
                "manifest": str(MANIFEST_PATH),
                "index": str(INDEX_PATH),
                "resolved": resolved_count,
                "missing": missing_count,
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
