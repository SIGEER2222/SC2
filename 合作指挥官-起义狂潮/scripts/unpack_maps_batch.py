"""批量解包 SC2 地图到 Maps 目录。

用法：
  python scripts/unpack_maps_batch.py <map_file_path> [<map_file_path> ...]

输出路径：<workspace>/Maps/<basename>.SC2Map/
"""
import os
import sys
from pathlib import Path

from mpyq import MPQArchive


WORKSPACE = Path(__file__).resolve().parent.parent
MAPS_DIR = WORKSPACE / "Maps"


def unpack_one(map_file: Path, out_dir: Path) -> int:
    """解包单个地图，返回提取的文件数。"""
    if out_dir.exists():
        # 清理旧的解包目录
        import shutil
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    archive = MPQArchive(str(map_file))
    count = 0
    for name_bytes in archive.files:
        if name_bytes is None:
            continue
        name = name_bytes.decode("utf-8") if isinstance(name_bytes, bytes) else name_bytes
        data = archive.read_file(name)
        if data is None:
            print(f"    !! Failed to read: {name}")
            continue
        out_path = out_dir / name
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "wb") as fp:
            fp.write(data)
        count += 1
    return count


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: python unpack_maps_batch.py <map.sc2map> [<map.sc2map> ...]")
        return 2

    MAPS_DIR.mkdir(parents=True, exist_ok=True)

    failed = []
    for raw in sys.argv[1:]:
        map_file = Path(raw)
        if not map_file.is_file():
            print(f"!! Source not found: {raw}")
            failed.append(raw)
            continue

        # 目标目录名 = 源文件名（含 .SC2Map 后缀）
        out_dir = MAPS_DIR / map_file.name
        print(f"=== Unpacking: {map_file.name} ===")
        print(f"  src: {map_file}")
        print(f"  dst: {out_dir}")
        try:
            n = unpack_one(map_file, out_dir)
            print(f"  -> {n} files extracted")
        except Exception as e:
            print(f"  !! ERROR: {e}")
            failed.append(raw)

    print()
    if failed:
        print(f"Failed: {len(failed)} / {len(sys.argv)-1}")
        for f in failed:
            print(f"  - {f}")
        return 1
    print(f"All done: {len(sys.argv)-1} maps")
    return 0


if __name__ == "__main__":
    sys.exit(main())
