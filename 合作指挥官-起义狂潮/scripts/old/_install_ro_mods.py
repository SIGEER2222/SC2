"""安装 RO mod 及其依赖到 SC2 Mods 目录"""
import shutil
from pathlib import Path

src = Path(r"C:\Users\22448\Downloads\RevolutionOverdrive缝合版\RevolutionOverdrive缝合版")
dst = Path(r"E:\SC2\SC2new\StarCraft II\Mods")

# 扫描源目录所有 .SC2Mod 项（可能是目录或 MPQ 文件）
mod_items = []
for child in src.iterdir():
    if child.name.endswith(".SC2Mod"):
        mod_items.append(child)

print(f"Found {len(mod_items)} mods in source:")
for item in mod_items:
    kind = "dir" if item.is_dir() else f"file({item.stat().st_size} bytes)"
    print(f"  {item.name} [{kind}]")

# 安装到 SC2 Mods 目录
for item in mod_items:
    d = dst / item.name
    if d.exists():
        if d.is_dir():
            shutil.rmtree(d)
        else:
            d.unlink()
    if item.is_dir():
        shutil.copytree(item, d)
    else:
        shutil.copy2(item, d)
    print(f"Installed: {item.name}")

# 把 ttosh01 地图复制到 SC2 Maps 目录
map_src = src / "ttosh01.SC2Map"
map_dst = Path(r"E:\SC2\SC2new\StarCraft II\Maps\RO_ttosh01.SC2Map")
if map_src.is_dir():
    if map_dst.exists():
        shutil.rmtree(map_dst)
    shutil.copytree(map_src, map_dst)
    print(f"Map installed: {map_dst}")
else:
    print(f"Map source not found: {map_src}")
