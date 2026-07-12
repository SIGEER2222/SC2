"""合并 kit_mutations 到 CommanderBridge

策略:
1. 复制 kit_mutations 的 GameData/*.xml (15 个 Mutators_*.xml) 到 CommanderBridge/GameData/
2. 复制 LibA070801C.galaxy 和 LibA070801C_h.galaxy 到 CommanderBridge
3. 合并 GameData/GameData.xml - 追加 <TriggerLibs Id="A070801C"/>
4. 合并 GameData.xml 主入口 - 追加 15 条 Catalog includes
5. 复制 UI/Layout/ 文件 (4 个 SC2Layout + version)
6. 复制本地化文件 (enUS + zhCN 各 4 个)
7. 复制 Preload.xml 和 PreloadAssetDB.txt
8. 复制 ComponentList.SC2Components
9. 合并 DataCenter.json spaces

用法:
    python merge_kit_mutations_to_commanderbridge.py
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path

PROJ_ROOT = Path(r"e:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods")

COMMANDER_BRIDGE = PROJ_ROOT / "7vs1" / "CommanderBridge.SC2Mod"
KIT_MUTATIONS = PROJ_ROOT / "kit_mutations.SC2Mod"


def copy_gamedata_files() -> list[str]:
    """复制 kit_mutations 的 GameData/*.xml 到 CommanderBridge/GameData/。

    返回新增的 includes 列表。
    """
    src_gamedata = KIT_MUTATIONS / "Base.SC2Data" / "GameData"
    dst_gamedata = COMMANDER_BRIDGE / "Base.SC2Data" / "GameData"
    dst_gamedata.mkdir(parents=True, exist_ok=True)

    new_includes: list[str] = []
    copied = 0

    for src_file in sorted(src_gamedata.iterdir()):
        if not src_file.is_file() or src_file.suffix != ".xml":
            continue

        # 跳过 GameData.xml 本身（需要合并而非复制）
        if src_file.name == "GameData.xml":
            continue

        dst_file = dst_gamedata / src_file.name
        if dst_file.exists():
            print(f"  [Skip] {src_file.name} already exists in CommanderBridge")
            continue

        shutil.copy2(src_file, dst_file)
        new_includes.append(f"GameData/{src_file.name}")
        copied += 1

    print(f"[Merge] kit_mutations: copied {copied} XML files to CommanderBridge/GameData/")
    return new_includes


def copy_galaxy_files() -> None:
    """复制 LibA070801C.galaxy 和 LibA070801C_h.galaxy。"""
    src_base = KIT_MUTATIONS / "Base.SC2Data"
    dst_base = COMMANDER_BRIDGE / "Base.SC2Data"

    copied = 0
    for src_file in src_base.iterdir():
        if not src_file.is_file():
            continue
        if src_file.name.startswith("LibA070801C") and src_file.suffix == ".galaxy":
            dst_file = dst_base / src_file.name
            if dst_file.exists():
                print(f"  [Skip] {src_file.name} already exists")
                continue
            shutil.copy2(src_file, dst_file)
            print(f"  [Copy] {src_file.name}")
            copied += 1

    print(f"[Merge] kit_mutations: copied {copied} galaxy files")


def merge_gamedata_gamedata_xml() -> None:
    """合并 GameData/GameData.xml - 追加 TriggerLibs 声明。"""
    src_path = KIT_MUTATIONS / "Base.SC2Data" / "GameData" / "GameData.xml"
    dst_path = COMMANDER_BRIDGE / "Base.SC2Data" / "GameData" / "GameData.xml"

    dst_content = dst_path.read_text(encoding="utf-8")

    # 检查是否已有 TriggerLibs
    if 'TriggerLibs Id="A070801C"' in dst_content:
        print("[Merge] GameData/GameData.xml: TriggerLibs A070801C already exists, skip")
        return

    # 在 </CGame> 之前追加 TriggerLibs
    dst_content = dst_content.replace(
        "</CGame>",
        '        <TriggerLibs Id="A070801C"/>\n    </CGame>',
    )

    dst_path.write_text(dst_content, encoding="utf-8")
    print("[Merge] GameData/GameData.xml: appended <TriggerLibs Id=\"A070801C\"/>")


def merge_main_gamedata_xml(new_includes: list[str]) -> None:
    """合并 GameData.xml 主入口 - 追加 Catalog includes。"""
    gamedata_xml_path = COMMANDER_BRIDGE / "Base.SC2Data" / "GameData.xml"
    content = gamedata_xml_path.read_text(encoding="utf-8")

    # 在 </Includes> 之前追加
    new_lines = []
    for inc in new_includes:
        # 检查是否已存在
        if f'path="{inc}"' in content:
            continue
        new_lines.append(f'  <Catalog path="{inc}"/>')

    if not new_lines:
        print("[Merge] GameData.xml: all includes already exist, skip")
        return

    new_includes_str = "\n".join(new_lines)
    content = content.replace("</Includes>", f"{new_includes_str}\n</Includes>")

    gamedata_xml_path.write_text(content, encoding="utf-8")
    print(f"[Merge] Appended {len(new_lines)} includes to CommanderBridge GameData.xml")


def copy_ui_layout() -> None:
    """复制 UI/Layout/ 文件。"""
    src_ui = KIT_MUTATIONS / "Base.SC2Data" / "UI" / "Layout"
    dst_ui = COMMANDER_BRIDGE / "Base.SC2Data" / "UI" / "Layout"

    if not src_ui.exists():
        print("[Merge] kit_mutations: no UI/Layout directory, skip")
        return

    dst_ui.mkdir(parents=True, exist_ok=True)

    copied = 0
    for src_file in src_ui.iterdir():
        if not src_file.is_file():
            continue
        dst_file = dst_ui / src_file.name
        if dst_file.exists():
            print(f"  [Skip] UI/Layout/{src_file.name} already exists")
            continue
        shutil.copy2(src_file, dst_file)
        copied += 1

    print(f"[Merge] kit_mutations: copied {copied} UI/Layout files")


def copy_localization() -> None:
    """复制本地化文件。"""
    for locale in ["enUS", "zhCN"]:
        src_locale_dir = KIT_MUTATIONS / f"{locale}.SC2Data" / "LocalizedData"
        if not src_locale_dir.exists():
            continue

        dst_locale_dir = COMMANDER_BRIDGE / f"{locale}.SC2Data" / "LocalizedData"
        dst_locale_dir.mkdir(parents=True, exist_ok=True)

        copied = 0
        for src_file in src_locale_dir.iterdir():
            if not src_file.is_file():
                continue
            dst_file = dst_locale_dir / src_file.name
            if dst_file.exists():
                # 追加内容（避免重复行）
                src_content = src_file.read_text(encoding="utf-8-sig", errors="ignore")
                dst_content = dst_file.read_text(encoding="utf-8-sig", errors="ignore")
                src_lines = src_content.strip().splitlines()
                dst_lines_set = set(dst_content.strip().splitlines())
                new_lines = [line for line in src_lines if line not in dst_lines_set]
                if new_lines:
                    merged = dst_content.rstrip() + "\n" + "\n".join(new_lines) + "\n"
                    dst_file.write_text(merged, encoding="utf-8-sig")
                    print(f"  [Append] {locale}/{src_file.name}: +{len(new_lines)} lines")
            else:
                shutil.copy2(src_file, dst_file)
                copied += 1

        print(f"[Merge] kit_mutations: copied {copied} {locale} localization files")


def copy_preload() -> None:
    """复制 Preload.xml 和 PreloadAssetDB.txt。"""
    for filename in ["Preload.xml", "PreloadAssetDB.txt"]:
        src_file = KIT_MUTATIONS / filename
        dst_file = COMMANDER_BRIDGE / filename
        if not src_file.exists():
            continue
        if dst_file.exists():
            print(f"  [Skip] {filename} already exists")
            continue
        shutil.copy2(src_file, dst_file)
        print(f"  [Copy] {filename}")


def copy_component_list() -> None:
    """复制 ComponentList.SC2Components。"""
    src_file = KIT_MUTATIONS / "ComponentList.SC2Components"
    dst_file = COMMANDER_BRIDGE / "ComponentList.SC2Components"
    if not src_file.exists():
        print("[Merge] kit_mutations: no ComponentList.SC2Components, skip")
        return
    if dst_file.exists():
        print("[Merge] ComponentList.SC2Components already exists, skip")
        return
    shutil.copy2(src_file, dst_file)
    print("[Merge] Copied ComponentList.SC2Components")


def merge_datacenter_json() -> None:
    """合并 DataCenter.json 的 spaces 到 CommanderBridge。"""
    src_dc_path = KIT_MUTATIONS / "DataCenter.json"
    dst_dc_path = COMMANDER_BRIDGE / "DataCenter.json"
    if not src_dc_path.exists():
        print("[Merge] kit_mutations: no DataCenter.json, skip")
        return

    src_dc = json.loads(src_dc_path.read_text(encoding="utf-8"))
    dst_dc = json.loads(dst_dc_path.read_text(encoding="utf-8"))

    # 合并 spaces 数组
    src_spaces = src_dc.get("spaces", [])
    dst_spaces = dst_dc.get("spaces", [])

    added = 0
    for space in src_spaces:
        if space not in dst_spaces:
            dst_spaces.append(space)
            added += 1

    dst_dc["spaces"] = dst_spaces

    # 合并 exports
    src_exports = src_dc.get("exports", {})
    dst_exports = dst_dc.get("exports", {})
    for key, val in src_exports.items():
        if key not in dst_exports:
            dst_exports[key] = val
    dst_dc["exports"] = dst_exports

    dst_dc_path.write_text(json.dumps(dst_dc, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"[Merge] kit_mutations: merged DataCenter.json ({added} spaces added)")


def main() -> None:
    print("=" * 60)
    print("Merge kit_mutations -> CommanderBridge")
    print("=" * 60)

    # 验证源 mod 存在
    for mod in [COMMANDER_BRIDGE, KIT_MUTATIONS]:
        if not mod.exists():
            raise FileNotFoundError(f"Mod not found: {mod}")

    print()
    # 1. 复制 GameData 文件
    new_includes = copy_gamedata_files()
    print()

    # 2. 复制 galaxy 文件
    copy_galaxy_files()
    print()

    # 3. 合并 GameData/GameData.xml (CGame TriggerLibs)
    merge_gamedata_gamedata_xml()
    print()

    # 4. 合并 GameData.xml 主入口
    merge_main_gamedata_xml(new_includes)
    print()

    # 5. 复制 UI/Layout
    copy_ui_layout()
    print()

    # 6. 复制本地化
    copy_localization()
    print()

    # 7. 复制 Preload
    copy_preload()
    print()

    # 8. 复制 ComponentList
    copy_component_list()
    print()

    # 9. 合并 DataCenter.json
    merge_datacenter_json()
    print()

    print("=" * 60)
    print(f"Merge complete! Added {len(new_includes)} XML files to CommanderBridge.")
    print("CommanderBridge now contains data from kit_mutations.")
    print("=" * 60)


if __name__ == "__main__":
    main()
