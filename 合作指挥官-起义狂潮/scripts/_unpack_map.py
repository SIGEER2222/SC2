import os
from mpyq import MPQArchive

map_file = r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Maps\虫心mod测试地图.SC2Map"
out_dir = r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Maps\虫心mod测试地图_unpacked"

os.makedirs(out_dir, exist_ok=True)

archive = MPQArchive(map_file)

# Extract files manually - files is a list of bytes
print("=== Extracting files ===")
for name_bytes in archive.files:
    if name_bytes is None:
        continue
    name = name_bytes.decode('utf-8') if isinstance(name_bytes, bytes) else name_bytes
    print(f"  Extracting: {name}")
    data = archive.read_file(name)
    if data is None:
        print(f"    -> Failed to read!")
        continue
    out_path = os.path.join(out_dir, name)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, 'wb') as fp:
        fp.write(data)
    print(f"    -> {len(data)} bytes")

print(f"\nDone! Extracted to: {out_dir}")
