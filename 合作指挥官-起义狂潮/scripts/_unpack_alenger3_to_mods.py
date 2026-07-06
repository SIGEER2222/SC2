"""解包 3疯批帝国.SC2Mod 到 Mods/7vs1/Alenger3.SC2Mod/（目录形式）"""
from pathlib import Path
from mpyq import MPQArchive
import os

src = Path(r"C:\Users\22448\Downloads\阿巴瑟之心\Mods\Alenger\3疯批帝国.SC2Mod")
dst = Path(r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods\7vs1\Alenger3.SC2Mod")

print(f"解包: {src.name} -> {dst}")
if dst.exists():
    print(f"[WARN] 目标已存在，将覆盖")
dst.mkdir(parents=True, exist_ok=True)

archive = MPQArchive(str(src))

count = 0
skip = 0
for name_bytes in archive.files:
    if name_bytes is None:
        continue
    if isinstance(name_bytes, bytes):
        try:
            name = name_bytes.decode("utf-8")
        except UnicodeDecodeError:
            name = name_bytes.decode("latin-1")
    else:
        name = name_bytes

    # 跳过列表里的内建文件
    if name in ("(listfile)", "(attributes)", "(signature)"):
        skip += 1
        continue

    data = archive.read_file(name)
    if data is None:
        print(f"  [SKIP] 读取失败: {name}")
        skip += 1
        continue

    if isinstance(data, bytes):
        # 检测是否是文本文件（XML/galaxy/txt）
        ext = Path(name).suffix.lower()
        is_text = ext in (".xml", ".galaxy", ".txt", ".components", ".version", ".info", ".header")
        if is_text:
            try:
                data = data.decode("utf-8")
            except UnicodeDecodeError:
                data = data.decode("latin-1")
        # 否则保持 bytes

    # 写入文件
    out_path = dst / name
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, bytes):
        out_path.write_bytes(data)
    else:
        out_path.write_text(data, encoding="utf-8", newline="\n")
    count += 1

print(f"\n完成: 解包 {count} 个文件，跳过 {skip} 个")
print(f"目标目录: {dst}")
print(f"总大小: {sum(f.stat().st_size for f in dst.rglob('*') if f.is_file()) / 1024 / 1024:.1f} MB")
