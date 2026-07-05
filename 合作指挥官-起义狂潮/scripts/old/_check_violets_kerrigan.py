"""检查 VioletsHoTSReworkMod 的目录结构，查找 CommanderData / RaceData 等元数据"""
from pathlib import Path

violets = Path(r"C:\Users\22448\Downloads\阿巴瑟之心\Mods\VioletsHoTSReworkMod.SC2Mod")
print("=== 目录结构 ===")
for p in sorted(violets.rglob("*")):
    if p.is_file():
        rel = p.relative_to(violets)
        size = p.stat().st_size
        print(f"  [{size:>8} bytes] {rel}")

print()
print("=== GameData 目录文件 ===")
gd = violets / "Base.SC2Data" / "GameData"
if gd.exists():
    for f in sorted(gd.iterdir()):
        print(f"  {f.name} ({f.stat().st_size} bytes)")
