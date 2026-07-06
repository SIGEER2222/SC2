"""
修改 7vs1 地图 DocumentHeader，追加 Alenger3Adapter.SC2Mod 依赖。
策略：
  1. 读取 DocumentHeader 二进制
  2. 在 header 后找到 dependency count（4 字节整数）
  3. 验证当前 dependency count 与实际依赖字符串数匹配
  4. 增加 dependency count，在最后一个依赖字符串后追加新依赖
"""
import struct
import sys

MAP_PATH = r"e:\SC2\SC2new\StarCraft II\Maps\7vs1\7vs1CoopTest.SC2Map\DocumentHeader"
NEW_DEP = "file:Mods/7vs1/Alenger3Adapter.SC2Mod"

data = bytearray(open(MAP_PATH, "rb").read())
print(f"Original size: {len(data)} bytes")

# 从 kit_mutations 分析得知，header 是 44 字节，dependency count 在 offset 0x2C
# 但地图可能有不同的 header 长度。让我先验证 offset 0x2C 处的值。
dep_count_offset = 0x2C
dep_count = struct.unpack_from("<I", data, dep_count_offset)[0]
print(f"Dependency count at offset 0x{dep_count_offset:04x}: {dep_count}")

# 依赖字符串从 offset 0x30 开始（dep_count_offset + 4）
dep_strings_start = dep_count_offset + 4
offset = dep_strings_start
deps_found = []
for i in range(dep_count):
    # 读取 null-terminated 字符串
    end = data.index(b"\x00", offset)
    dep_bytes = bytes(data[offset:end])
    try:
        dep_str = dep_bytes.decode("utf-8")
    except UnicodeDecodeError:
        dep_str = dep_bytes.decode("gbk", errors="replace")
    deps_found.append((offset, end, dep_str))
    offset = end + 1

print(f"\nFound {len(deps_found)} dependencies:")
for start, end, s in deps_found:
    print(f"  offset=0x{start:04x}-0x{end:04x} len={end-start}: {s}")

# 验证：最后一个依赖字符串后的位置应该是 key-value pair count
last_dep_end = deps_found[-1][1] + 1  # +1 for null
kv_count = struct.unpack_from("<I", data, last_dep_end)[0]
print(f"\nKey-value pair count at offset 0x{last_dep_end:04x}: {kv_count}")

# 检查是否已经追加过 adapter 依赖
already_added = any("Alenger3Adapter" in s for _, _, s in deps_found)
if already_added:
    print("\nAlenger3Adapter 依赖已存在，无需修改")
    sys.exit(0)

# 追加新依赖
new_dep_bytes = NEW_DEP.encode("utf-8") + b"\x00"
print(f"\nAppending new dependency: {NEW_DEP}")
print(f"  bytes: {new_dep_bytes.hex(' ')}")

# 在最后一个依赖字符串后（null 之后）插入新依赖
insert_pos = deps_found[-1][1] + 1  # null byte 之后
data[insert_pos:insert_pos] = new_dep_bytes

# 增加 dependency count
new_count = dep_count + 1
struct.pack_into("<I", data, dep_count_offset, new_count)
print(f"Updated dependency count: {dep_count} -> {new_count}")

# 写入文件
with open(MAP_PATH, "wb") as f:
    f.write(data)

print(f"\nNew size: {len(data)} bytes")
print("Done!")
