"""启动 Home_Soil 中文翻译测试地图

用法:
    python scripts/launch-home-soil-zhcn.py

流程:
1. 将翻译后的解包地图复制到 SC2 Maps 目录
2. 清理 GameLogs
3. 用 SC2Switcher_x64.exe 直接加载解包文件夹（与 launch-7vs1-coop-test.ps1 启动方式一致）
"""
import shutil
import subprocess
import sys
from pathlib import Path

# 翻译后的解包地图源路径
SRC_MAP = Path(r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Maps\Home_Soil.SC2Map")
SC2_ROOT = Path(r"E:\SC2\SC2new\StarCraft II")
MAPS_DIR = SC2_ROOT / "Maps" / "7vs1"
SWITCHER = SC2_ROOT / "Support64" / "SC2Switcher_x64.exe"
GAME_LOGS = Path(r"C:\Users\22448\Documents\StarCraft II\GameLogs")

DST_MAP = MAPS_DIR / "Home_Soil.SC2Map"


def main():
    if not SRC_MAP.is_dir():
        print(f"源地图不存在: {SRC_MAP}")
        sys.exit(1)
    if not SWITCHER.is_file():
        print(f"SC2Switcher 不存在: {SWITCHER}")
        sys.exit(1)

    # 复制地图
    if DST_MAP.exists():
        shutil.rmtree(DST_MAP)
    shutil.copytree(SRC_MAP, DST_MAP)
    print(f"地图已复制: {DST_MAP}")

    # 清理 GameLogs
    if GAME_LOGS.exists():
        for child in GAME_LOGS.iterdir():
            if child.is_dir():
                shutil.rmtree(child)
            else:
                child.unlink()
    print("GameLogs 已清理")

    # 启动游戏
    print(f"启动: {DST_MAP}")
    proc = subprocess.Popen([str(SWITCHER), str(DST_MAP)])
    print(f"SC2Switcher 已启动, PID={proc.pid}")


if __name__ == "__main__":
    main()
