"""完整读取 LibDE538C36.galaxy 和 _h.galaxy"""
from pathlib import Path
from mpyq import MPQArchive

mpq_path = Path(r"C:\Users\22448\Downloads\阿巴瑟之心\Mods\Alenger\3疯批帝国.SC2Mod")
archive = MPQArchive(str(mpq_path))

for f in [
    "Base.SC2Data\\LibDE538C36_h.galaxy",
    "Base.SC2Data\\LibDE538C36.galaxy",
]:
    print(f"\n{'='*80}")
    print(f"=== {f} (完整) ===")
    print(f"{'='*80}")
    data = archive.read_file(f)
    if data is None:
        print("[未找到]")
        continue
    if isinstance(data, bytes):
        text = data.decode("utf-8", errors="replace")
    else:
        text = data
    print(text)
