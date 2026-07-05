"""检查 mod 的 RaceData 和 UnitData，找指挥官区分字段"""
import re
from pathlib import Path
from mpyq import MPQArchive

mods_to_check = [
    r"C:\Users\22448\Downloads\阿巴瑟之心\Mods\Alenger\1钢铁.SC2Mod",
    r"C:\Users\22448\Downloads\阿巴瑟之心\Mods\Alenger\4塔达林.SC2Mod",
    r"C:\Users\22448\Downloads\阿巴瑟之心\Mods\Alenger\6阿巴瑟.SC2Mod",
    r"C:\Users\22448\Downloads\阿巴瑟之心\Mods\Ihanrii.SC2Mod",
    r"C:\Users\22448\Downloads\阿巴瑟之心\Mods\Moebius.SC2Mod",
]

for m in mods_to_check:
    p = Path(m)
    print(f"=== {p.name} ===")
    a = MPQArchive(str(p))

    # RaceData
    try:
        data = a.read_file("Base.SC2Data\\GameData\\RaceData.xml")
        text = data.decode("utf-8", "replace") if isinstance(data, bytes) else data
        race_ids = re.findall(r'<CRace\s+id="([^"]+)"', text)
        print(f"  CRace ids: {race_ids}")
        cmd_arrays = re.findall(r'<CommanderArray\s+Commander="([^"]+)"', text)
        print(f"  CommanderArray: {cmd_arrays}")
        heroes = re.findall(r'HeroUnit(?:\s+value)?="([^"]+)"', text)
        print(f"  HeroUnit: {heroes}")
    except Exception as e:
        print(f"  No RaceData: {e}")

    # UnitData 中的 Race 字段
    try:
        data = a.read_file("Base.SC2Data\\GameData\\UnitData.xml")
        text = data.decode("utf-8", "replace") if isinstance(data, bytes) else data
        races = set(re.findall(r'\sRace="([^"]+)"', text))
        print(f"  UnitData Race values: {sorted(races)}")
        # 找带 HeroUnit 属性的单位
        hero_units = re.findall(r'<CUnit\s+id="([^"]+)"[^>]*\sHeroUnit="1"', text)
        print(f"  HeroUnit=1: {hero_units[:5]}")
    except Exception as e:
        print(f"  No UnitData: {e}")
    print()
