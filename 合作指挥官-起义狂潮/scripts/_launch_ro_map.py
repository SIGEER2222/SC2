"""启动 RO mod 的指定地图"""
import shutil
import subprocess
import sys
from pathlib import Path

RO_SRC = Path(r"C:\Users\22448\Downloads\RevolutionOverdrive缝合版\RevolutionOverdrive缝合版")
SC2_ROOT = Path(r"E:\SC2\SC2new\StarCraft II")
MAPS_DIR = SC2_ROOT / "Maps"
SWITCHER = SC2_ROOT / "Support64" / "SC2Switcher_x64.exe"

map_name = sys.argv[1] if len(sys.argv) > 1 else "traynor01"
map_src = RO_SRC / f"{map_name}.SC2Map"
map_dst = MAPS_DIR / f"RO_{map_name}.SC2Map"

if not map_src.is_dir():
    print(f"Map source not found: {map_src}")
    sys.exit(1)

# 复制地图
if map_dst.exists():
    shutil.rmtree(map_dst)
shutil.copytree(map_src, map_dst)
print(f"Map copied: {map_dst}")

# 清理 GameLogs
logs_dir = Path(r"C:\Users\22448\Documents\StarCraft II\GameLogs")
if logs_dir.exists():
    for child in logs_dir.iterdir():
        if child.is_dir():
            shutil.rmtree(child)
        else:
            child.unlink()
print("GameLogs cleared")

# 启动游戏
print(f"Launching: {map_dst}")
subprocess.Popen([str(SWITCHER), str(map_dst)])
print("SC2Switcher started")
