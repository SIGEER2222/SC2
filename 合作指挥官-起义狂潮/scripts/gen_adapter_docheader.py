"""
生成 Alenger3Adapter.SC2Mod 的 DocumentHeader 二进制文件。
基于 kit_mutations.SC2Mod 的 DocumentHeader 格式分析：
  - Header (48 bytes): magic/version/flags/timestamps
  - dependency count (4 bytes)
  - dependency strings (each null-terminated)
  - key-value pair count (4 bytes)
  - key-value pairs: key_len(2) + key + type(4) + val_len(2) + value
"""
import struct

OUT_PATH = r"E:\SC2\SC2new\StarCraft II\Mods\7vs1\Alenger3Adapter.SC2Mod\DocumentHeader"

# Header (copy from kit_mutations, 48 bytes)
header = bytes([
    0x48, 0x32, 0x43, 0x53,  # H2CS magic
    0x08, 0x00, 0x00, 0x00,  # version = 8
    0x32, 0x53, 0x00, 0x00,  # ??
    0x01,                     # flag = ExtensionMod
    0x05,                     # ??
    0x00, 0x0e,               # ??
    0x95, 0x6c, 0x01, 0x00,   # timestamp1
    0x95, 0x6c, 0x01, 0x00,   # timestamp2
    0x02, 0x00, 0x00, 0x00,   # ??
    0x2b, 0x30, 0xaf, 0x74,   # ??
    0x2b, 0x30, 0xaf, 0x74,   # ??
    0x00, 0x00, 0x00, 0x00,   # ??
    0x00, 0x00, 0x00, 0x00,   # ??
])

# Dependencies
deps = [
    "file:Mods/7vs1/Alenger3.SC2Mod",
    "file:Mods/kit_mutations.SC2Mod",
]
dep_count = struct.pack("<I", len(deps))
dep_data = b""
for d in deps:
    dep_data += d.encode("utf-8") + b"\x00"

# Key-Value pairs
def kv(key, value, type_id=b"SUne"):
    kb = key.encode("utf-8")
    vb = value.encode("utf-8")
    return struct.pack("<H", len(kb)) + kb + type_id + struct.pack("<H", len(vb)) + vb

pairs = [
    kv("DocInfo/Name", "Alenger3 Adapter"),
    kv("DocInfo/DescShort", "Adapter for Alenger3 commander"),
]
pair_count = struct.pack("<I", len(pairs))
pair_data = b"".join(pairs)

# Assemble
data = header + dep_count + dep_data + pair_count + pair_data

with open(OUT_PATH, "wb") as f:
    f.write(data)

print(f"Generated: {OUT_PATH}")
print(f"Size: {len(data)} bytes")
print(f"Dependencies: {deps}")
print(f"Pairs: Name/DescShort")
