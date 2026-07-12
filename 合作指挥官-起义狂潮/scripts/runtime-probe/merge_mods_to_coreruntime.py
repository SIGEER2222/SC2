"""合并 BaseCatalogPatch + SharedUnits + ExternalRefs 到 CoreRuntime

策略:
1. 把源 mod 的 GameData/*.xml 文件复制到 CoreRuntime/GameData/
   - 同名文件加后缀避免覆盖（BaseCatalogPatch 的 AbilData.xml → AbilData_BasePatch.xml）
   - 不同名文件直接复制（SharedUnits 的 UnitData_Shared_*.xml 直接复制）
   - ExternalRefs 的 *_Reborn.xml / *_HexTalents.xml 直接复制
2. 合并 GameData.xml 的 <Includes> 列表
3. 合并本地化文件（enUS/zhCN 的 GameStrings.txt, ObjectStrings.txt）
4. 合并 DataCenter.json
5. 不修改 DocumentInfo（CoreRuntime 的依赖已经是 VoidMulti + StarCoop，正确）

用法:
    python merge_mods_to_coreruntime.py
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path

PROJ_ROOT = Path(r"e:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods")

CORE_RUNTIME = PROJ_ROOT / "7vs1" / "CoreRuntime.SC2Mod"
BASE_CATALOG_PATCH = PROJ_ROOT / "7vs1" / "BaseCatalogPatch.SC2Mod"
SHARED_UNITS = PROJ_ROOT / "7vs1" / "SharedUnits.SC2Mod"
EXTERNAL_REFS = PROJ_ROOT / "7vs1" / "ExternalRefs.SC2Mod"

# CoreRuntime 现有的 GameData 文件名（用于冲突检测）
CORE_RUNTIME_EXISTING_FILES: set[str] = set()

# 文件名重命名映射（源文件名 → 目标文件名）
# 同名文件加后缀避免覆盖
RENAME_MAP: dict[str, dict[str, str]] = {
    "BaseCatalogPatch": {
        "AbilData.xml": "AbilData_BasePatch.xml",
        "ActorData.xml": "ActorData_BasePatch.xml",
        "BehaviorData.xml": "BehaviorData_BasePatch.xml",
        "ButtonData.xml": "ButtonData_BasePatch.xml",
        "EffectData.xml": "EffectData_BasePatch.xml",
        "MoverData.xml": "MoverData_BasePatch.xml",
        "RequirementData.xml": "RequirementData_BasePatch.xml",
        "RequirementNodeData.xml": "RequirementNodeData_BasePatch.xml",
        "UnitData.xml": "UnitData_BasePatch.xml",
        "UpgradeData.xml": "UpgradeData_BasePatch.xml",
    },
    "SharedUnits": {},  # 全部带 _Shared_ 后缀，不冲突
    "ExternalRefs": {},  # 全部带 _Reborn 或 _HexTalents 后缀，不冲突
}


def collect_existing_files() -> None:
    """收集 CoreRuntime 现有的 GameData 文件名。"""
    gamedata_dir = CORE_RUNTIME / "Base.SC2Data" / "GameData"
    if gamedata_dir.exists():
        for f in gamedata_dir.iterdir():
            if f.is_file() and f.suffix == ".xml":
                CORE_RUNTIME_EXISTING_FILES.add(f.name)
    print(f"[Merge] CoreRuntime existing GameData files: {len(CORE_RUNTIME_EXISTING_FILES)}")
    for name in sorted(CORE_RUNTIME_EXISTING_FILES):
        print(f"  - {name}")


def merge_gamedata_files(src_mod: Path, mod_name: str) -> list[str]:
    """复制源 mod 的 GameData/*.xml 到 CoreRuntime/GameData/。

    返回新增的 includes 列表（相对路径）。
    """
    src_gamedata = src_mod / "Base.SC2Data" / "GameData"
    if not src_gamedata.exists():
        print(f"[Merge] {mod_name}: no GameData directory, skip")
        return []

    dst_gamedata = CORE_RUNTIME / "Base.SC2Data" / "GameData"
    rename_map = RENAME_MAP.get(mod_name, {})

    new_includes: list[str] = []
    copied = 0

    for src_file in sorted(src_gamedata.iterdir()):
        if not src_file.is_file() or src_file.suffix != ".xml":
            continue

        src_name = src_file.name
        dst_name = rename_map.get(src_name, src_name)

        if dst_name in CORE_RUNTIME_EXISTING_FILES and dst_name == src_name:
            # 同名且没有重命名映射——这不应该发生（rename_map 应该处理了）
            print(f"[Merge] {mod_name}: WARNING - {dst_name} already exists in CoreRuntime, renaming")
            dst_name = f"{src_file.stem}_{mod_name}.xml"

        dst_file = dst_gamedata / dst_name
        shutil.copy2(src_file, dst_file)
        CORE_RUNTIME_EXISTING_FILES.add(dst_name)
        new_includes.append(f"GameData/{dst_name}")
        copied += 1

    print(f"[Merge] {mod_name}: copied {copied} XML files to CoreRuntime/GameData/")
    return new_includes


def merge_gamedata_xml_includes(new_includes: list[str]) -> None:
    """在 CoreRuntime 的 GameData.xml 中追加 includes。"""
    gamedata_xml_path = CORE_RUNTIME / "Base.SC2Data" / "GameData.xml"
    content = gamedata_xml_path.read_text(encoding="utf-8")

    # 在 </Includes> 之前追加
    new_lines = []
    for inc in new_includes:
        new_lines.append(f'  <Catalog path="{inc}"/>')

    new_includes_str = "\n".join(new_lines)
    content = content.replace("</Includes>", f"{new_includes_str}\n</Includes>")

    gamedata_xml_path.write_text(content, encoding="utf-8")
    print(f"[Merge] Appended {len(new_includes)} includes to CoreRuntime GameData.xml")


def merge_localization(src_mod: Path, mod_name: str) -> None:
    """合并本地化文件到 CoreRuntime。"""
    for locale in ["enUS", "zhCN"]:
        src_locale_dir = src_mod / f"{locale}.SC2Data" / "LocalizedData"
        if not src_locale_dir.exists():
            continue

        dst_locale_dir = CORE_RUNTIME / f"{locale}.SC2Data" / "LocalizedData"
        dst_locale_dir.mkdir(parents=True, exist_ok=True)

        for src_file in src_locale_dir.iterdir():
            if not src_file.is_file():
                continue

            dst_file = dst_locale_dir / src_file.name
            if dst_file.exists():
                # 追加内容
                src_content = src_file.read_text(encoding="utf-8-sig", errors="ignore")
                dst_content = dst_file.read_text(encoding="utf-8-sig", errors="ignore")
                # 避免重复行
                src_lines = src_content.strip().splitlines()
                dst_lines = dst_content.strip().splitlines()
                dst_lines_set = set(dst_lines)
                new_lines = [line for line in src_lines if line not in dst_lines_set]
                if new_lines:
                    merged = dst_content.rstrip() + "\n" + "\n".join(new_lines) + "\n"
                    dst_file.write_text(merged, encoding="utf-8-sig")
                    print(f"[Merge] {mod_name}: appended {len(new_lines)} lines to {locale}/{src_file.name}")
            else:
                shutil.copy2(src_file, dst_file)
                print(f"[Merge] {mod_name}: copied {locale}/{src_file.name}")


def merge_datacenter_json(src_mod: Path, mod_name: str) -> None:
    """合并 DataCenter.json 的 spaces 到 CoreRuntime。"""
    src_dc_path = src_mod / "DataCenter.json"
    dst_dc_path = CORE_RUNTIME / "DataCenter.json"
    if not src_dc_path.exists():
        print(f"[Merge] {mod_name}: no DataCenter.json, skip")
        return

    src_dc = json.loads(src_dc_path.read_text(encoding="utf-8"))
    dst_dc = json.loads(dst_dc_path.read_text(encoding="utf-8"))

    # 合并 spaces 数组
    src_spaces = src_dc.get("spaces", [])
    dst_spaces = dst_dc.get("spaces", [])

    # 把源 mod 的 spaces 加到 CoreRuntime
    for space in src_spaces:
        if space not in dst_spaces:
            dst_spaces.append(space)

    dst_dc["spaces"] = dst_spaces

    # 合并 exports
    src_exports = src_dc.get("exports", {})
    dst_exports = dst_dc.get("exports", {})
    for key, val in src_exports.items():
        if key not in dst_exports:
            dst_exports[key] = val
    dst_dc["exports"] = dst_exports

    dst_dc_path.write_text(json.dumps(dst_dc, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"[Merge] {mod_name}: merged DataCenter.json ({len(src_spaces)} spaces)")


def main() -> None:
    print("=" * 60)
    print("Merge BaseCatalogPatch + SharedUnits + ExternalRefs → CoreRuntime")
    print("=" * 60)

    # 验证源 mod 存在
    for mod in [CORE_RUNTIME, BASE_CATALOG_PATCH, SHARED_UNITS, EXTERNAL_REFS]:
        if not mod.exists():
            raise FileNotFoundError(f"Mod not found: {mod}")

    # 1. 收集 CoreRuntime 现有文件
    collect_existing_files()
    print()

    # 2. 复制 GameData 文件
    all_new_includes: list[str] = []
    for src_mod, mod_name in [
        (BASE_CATALOG_PATCH, "BaseCatalogPatch"),
        (SHARED_UNITS, "SharedUnits"),
        (EXTERNAL_REFS, "ExternalRefs"),
    ]:
        new_includes = merge_gamedata_files(src_mod, mod_name)
        all_new_includes.extend(new_includes)
    print()

    # 3. 合并 GameData.xml includes
    merge_gamedata_xml_includes(all_new_includes)
    print()

    # 4. 合并本地化
    for src_mod, mod_name in [
        (BASE_CATALOG_PATCH, "BaseCatalogPatch"),
        (SHARED_UNITS, "SharedUnits"),
        (EXTERNAL_REFS, "ExternalRefs"),
    ]:
        merge_localization(src_mod, mod_name)
    print()

    # 5. 合并 DataCenter.json
    for src_mod, mod_name in [
        (BASE_CATALOG_PATCH, "BaseCatalogPatch"),
        (SHARED_UNITS, "SharedUnits"),
        (EXTERNAL_REFS, "ExternalRefs"),
    ]:
        merge_datacenter_json(src_mod, mod_name)
    print()

    print("=" * 60)
    print(f"Merge complete! Added {len(all_new_includes)} new XML files to CoreRuntime.")
    print("CoreRuntime now contains data from BaseCatalogPatch + SharedUnits + ExternalRefs.")
    print("=" * 60)


if __name__ == "__main__":
    main()
