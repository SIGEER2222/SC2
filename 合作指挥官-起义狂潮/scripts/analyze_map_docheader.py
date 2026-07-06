"""分析 7vs1 地图 DocumentHeader 的依赖字符串位置。"""
import re

PATH = r"e:\SC2\SC2new\StarCraft II\Maps\7vs1\7vs1CoopTest.SC2Map\DocumentHeader"
data = open(PATH, "rb").read()

print(f"Size: {len(data)} bytes")
print("\nStrings found:")
for m in re.finditer(rb"[\x20-\x7E\x80-\xff]{8,}", data):
    s = m.group()
    try:
        decoded = s.decode("utf-8")
    except UnicodeDecodeError:
        decoded = s.decode("gbk", errors="replace")
    print(f"  offset=0x{m.start():04x} len={len(s)}: {decoded}")

# 找依赖字符串（包含 file: 或 bnet: 的）
print("\nDependency strings (file:/bnet:):")
for m in re.finditer(rb"(?:bnet:[^\x00]+|file:[^\x00]+)", data):
    s = m.group()
    try:
        decoded = s.decode("utf-8")
    except UnicodeDecodeError:
        decoded = s.decode("gbk", errors="replace")
    print(f"  offset=0x{m.start():04x} len={len(s)}: {decoded}")
