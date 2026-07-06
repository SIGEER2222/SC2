"""读取 3疯批帝国.SC2Mod 的关键 XML 和 galaxy 文件内容"""
from pathlib import Path
from mpyq import MPQArchive

mpq_path = Path(r"C:\Users\22448\Downloads\阿巴瑟之心\Mods\Alenger\3疯批帝国.SC2Mod")
archive = MPQArchive(str(mpq_path))

# 关键文件列表
key_files = [
    "Base.SC2Data\\GameData\\GameData.xml",
    "Base.SC2Data\\GameData\\CommanderData.xml",
    "Base.SC2Data\\GameData\\RaceData.xml",
    "Base.SC2Data\\GameData\\UnitData.xml",  # 只读前 200 行
    "Base.SC2Data\\GameData\\AbilData.xml",  # 只读前 100 行
    "Base.SC2Data\\LibDE538C36_h.galaxy",     # 头文件全读
    "Base.SC2Data\\LibDE538C36.galaxy",       # 主文件只读前 200 行
    "zhCN.SC2Data\\LocalizedData\\GameStrings.txt",  # 前 100 行
]

for f in key_files:
    print(f"\n{'='*80}")
    print(f"=== {f} ===")
    print(f"{'='*80}")
    data = archive.read_file(f)
    if data is None:
        print("[未找到]")
        continue
    if isinstance(data, bytes):
        text = data.decode("utf-8", errors="replace")
    else:
        text = data

    lines = text.splitlines()
    if f.endswith("UnitData.xml"):
        print(f"[总 {len(lines)} 行，只显示前 150 行]")
        print("\n".join(lines[:150]))
    elif f.endswith("AbilData.xml"):
        print(f"[总 {len(lines)} 行，只显示前 100 行]")
        print("\n".join(lines[:100]))
    elif f.endswith("LibDE538C36.galaxy"):
        print(f"[总 {len(lines)} 行，只显示前 200 行]")
        print("\n".join(lines[:200]))
    elif f.endswith("GameStrings.txt"):
        print(f"[总 {len(lines)} 行，只显示前 80 行]")
        print("\n".join(lines[:80]))
    else:
        print(text)
