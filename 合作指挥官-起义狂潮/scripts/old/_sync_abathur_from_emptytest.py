"""
从 emptytest 复制所有非地形文件到 abathur_test_map，
保留虫心mod测试地图的地形文件。
然后用阿巴瑟单位列表替换 LibEmptyTestCatalog.galaxy。
"""
import os
import shutil

emptytest = r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods\emptytest.SC2Map"
abathur = r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Maps\abathur_test_map"

# 地形相关文件 - 保留虫心mod测试地图的
terrain_files = {
    "t3Terrain.xml", "t3Terrain.version",
    "t3HeightMap", "t3CellFlags", "t3Water", "t3TextureMasks",
    "t3VertCol", "t3SyncTextureInfo", "t3SyncCliffLevel", "t3SyncHeightMap",
    "t3HardTile", "t3FluffDoodad",
    "Objects", "Objects.version",
    "Minimap.tga",
    "MapInfo", "MapInfo.version",
}

# 从 emptytest 复制所有非地形文件
copied = []
for root, dirs, files in os.walk(emptytest):
    for f in files:
        src = os.path.join(root, f)
        rel = os.path.relpath(src, emptytest)

        # 跳过地形文件
        if f in terrain_files:
            print(f"  SKIP (terrain): {rel}")
            continue

        # 跳过 LibEmptyTestCatalog.galaxy (后面单独处理)
        if "LibEmptyTestCatalog.galaxy" in f:
            print(f"  SKIP (will replace): {rel}")
            continue

        # 跳过 .bak 文件
        if f.endswith(".bak"):
            print(f"  SKIP (backup): {rel}")
            continue

        dst = os.path.join(abathur, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
        copied.append(rel)

print(f"\nCopied {len(copied)} files from emptytest to abathur_test_map")
for f in copied:
    print(f"  {f}")

# 删除 LibAbathurCatalog.galaxy (不再需要，用 LibEmptyTestCatalog.galaxy 代替)
lib_abathur = os.path.join(abathur, "Base.SC2Data", "LibAbathurCatalog.galaxy")
if os.path.exists(lib_abathur):
    os.remove(lib_abathur)
    print(f"\nDeleted: {lib_abathur}")

print("\nDone! Now need to update LibEmptyTestCatalog.galaxy with Abathur units.")
