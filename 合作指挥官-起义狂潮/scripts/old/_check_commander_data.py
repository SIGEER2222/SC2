"""检查所有 mod 的 CommanderData.xml，找出 CCommander 和 UnitArray"""
import re
from pathlib import Path
from mpyq import MPQArchive

mods_root = Path(r"C:\Users\22448\Downloads\阿巴瑟之心\Mods")
all_mods = list(mods_root.glob("*.SC2Mod")) + list((mods_root / "Alenger").glob("*.SC2Mod"))

ID_RE = re.compile(r'<CCommander\s+id="([^"]+)"')
UNIT_RE = re.compile(r'<UnitArray\s+Unit="([^"]+)"')
TALENT_UNIT_RE = re.compile(r'<TalentTreeArray[^>]*>\s*<Unit\s+value="([^"]+)"', re.DOTALL)

for m in sorted(all_mods):
    rel = m.relative_to(mods_root)
    print(f"=== {rel} ===")

    if m.is_dir():
        cmd_file = m / "Base.SC2Data" / "GameData" / "CommanderData.xml"
        if not cmd_file.exists():
            print("  No CommanderData.xml")
            print()
            continue
        text = cmd_file.read_text(encoding="utf-8", errors="replace")
    else:
        try:
            a = MPQArchive(str(m))
            names = [n.decode("utf-8", "replace") if isinstance(n, bytes) else n for n in a.files if n]
            cmd_name = None
            for n in names:
                if "CommanderData.xml" in n:
                    cmd_name = n
                    break
            if not cmd_name:
                print("  No CommanderData.xml in MPQ")
                print()
                continue
            data = a.read_file(cmd_name)
            text = data.decode("utf-8", "replace") if isinstance(data, bytes) else data
        except Exception as e:
            print(f"  ERROR: {e}")
            print()
            continue

    # 解析 CCommander id
    ids = ID_RE.findall(text)
    print(f"  CCommander ids: {ids}")

    # 解析 UnitArray
    units = UNIT_RE.findall(text)
    print(f"  UnitArray count: {len(units)}")
    if units:
        if len(units) > 10:
            print(f"  Units (前10): {units[:10]}")
        else:
            print(f"  Units: {units}")

    # 解析 TalentTreeArray 中的 Unit
    talent_units = TALENT_UNIT_RE.findall(text)
    if talent_units:
        # 去掉 GluescreenDummy
        real_talent_units = [u for u in talent_units if "GluescreenDummy" not in u]
        if real_talent_units:
            print(f"  TalentTree 单位 (非Dummy): {len(real_talent_units)}")
            if len(real_talent_units) > 10:
                print(f"    前10: {real_talent_units[:10]}")
            else:
                print(f"    {real_talent_units}")

    print()
