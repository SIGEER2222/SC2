"""生成 Reborn 源容器 SHA-256 清单。"""
import hashlib
import json
import os
import sys
from pathlib import Path

def sha256_file(filepath):
    """计算单个文件的 SHA-256"""
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

def sha256_dir(dirpath):
    """计算目录下所有文件的 SHA-256（聚合）"""
    files = sorted(Path(dirpath).rglob("*"))
    h = hashlib.sha256()
    for fp in files:
        if fp.is_file():
            h.update(fp.name.encode("utf-8"))
            with open(fp, "rb") as f:
                for chunk in iter(lambda: f.read(65536), b""):
                    h.update(chunk)
    return h.hexdigest()

def count_files(dirpath):
    """统计目录下文件数"""
    return sum(1 for _ in Path(dirpath).rglob("*") if _.is_file())

def scan_container(root, name):
    """扫描单个容器（目录或文件）"""
    fullpath = os.path.join(root, name)
    if os.path.isdir(fullpath):
        return {
            "name": name,
            "type": "directory",
            "size": sum(
                os.path.getsize(os.path.join(dirpath, f))
                for dirpath, _, filenames in os.walk(fullpath)
                for f in filenames
            ),
            "file_count": count_files(fullpath),
            "sha256": sha256_dir(fullpath),
        }
    else:
        return {
            "name": name,
            "type": "file",
            "size": os.path.getsize(fullpath),
            "sha256": sha256_file(fullpath),
        }

def main():
    if len(sys.argv) < 2:
        print("用法: python generate_manifest.py <reborn_source_dir> [output_path]")
        sys.exit(1)

    source_dir = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else "reborn-source-manifest.json"

    if not os.path.isdir(source_dir):
        print(f"源目录不存在: {source_dir}")
        sys.exit(1)

    containers = []

    # Scan main reborn directory
    for entry in sorted(os.listdir(source_dir)):
        entry_path = os.path.join(source_dir, entry)
        if entry == "metadata.txt":
            continue
        if entry == "evolution":
            # Evolution maps are in a subdirectory
            for evo_entry in sorted(os.listdir(entry_path)):
                evo_full = os.path.join(entry_path, evo_entry)
                if os.path.isdir(evo_full):
                    containers.append(scan_container(entry_path, evo_entry))
                elif evo_entry.endswith(".SC2Map"):
                    containers.append(scan_container(entry_path, evo_entry))
            continue
        if entry.endswith(".SC2Map") or entry.endswith(".SC2Mod"):
            containers.append(scan_container(source_dir, entry))

    # Count by type
    dirs = [c for c in containers if c["type"] == "directory"]
    files = [c for c in containers if c["type"] == "file"]
    total_size = sum(c["size"] for c in containers)

    manifest = {
        "schemaVersion": 1,
        "source": "The Swarm Reborn v0.71 by Cryswar",
        "sourcePath": source_dir,
        "generatedAt": __import__("datetime").datetime.now().isoformat(),
        "summary": {
            "totalContainers": len(containers),
            "directoryContainers": len(dirs),
            "fileContainers": len(files),
            "totalSizeBytes": total_size,
            "totalSizeMB": round(total_size / (1024 * 1024), 2),
        },
        "containers": containers,
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    print(f"清单已生成: {output_path}")
    print(f"总计: {len(containers)} 个容器")
    print(f"  目录型: {len(dirs)} 个")
    print(f"  文件型: {len(files)} 个")
    print(f"  总大小: {manifest['summary']['totalSizeMB']} MB")

if __name__ == "__main__":
    main()