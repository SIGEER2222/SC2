"""分析 VioletsHoTSReworkMod 的所有单位 ID，找规律"""
import re
from pathlib import Path

mod_dir = Path(r"C:\Users\22448\Downloads\阿巴瑟之心\Mods\VioletsHoTSReworkMod.SC2Mod")
unit_file = mod_dir / "Base.SC2Data" / "GameData" / "UnitData.xml"
text = unit_file.read_text(encoding="utf-8", errors="replace")

CUNIT_RE = re.compile(r'<CUnit\s+id="([^"]+)"(?:\s+parent="([^"]+)")?')
units = []
for line in text.splitlines():
    m = CUNIT_RE.search(line)
    if not m:
        continue
    if line.strip().startswith("<!--"):
        continue
    units.append(m.group(1))

print(f"VioletsHoTSReworkMod 总单位数: {len(units)}")
print()

# 后缀统计
from collections import Counter
suffix_counter = Counter()
prefix_counter = Counter()
for u in units:
    # 找末尾大写字母或数字
    m = re.search(r'([A-Z][a-z]*)?(\d+)?$', u)
    if m:
        suffix = u[-1] if u[-1].isupper() or u[-1].isdigit() else ""
        suffix_counter[suffix] += 1
    # 找前缀（开头几个字母）
    m = re.match(r'^([A-Z][a-z]+)', u)
    if m:
        prefix_counter[m.group(1)] += 1

print("=== 末尾字符统计 (top 30) ===")
for s, c in suffix_counter.most_common(30):
    print(f"  '{s}': {c}")

print()
print("=== 开头单词统计 (top 30) ===")
for p, c in prefix_counter.most_common(30):
    print(f"  {p}: {c}")

print()
print("=== 所有单位 ID (排序) ===")
for u in sorted(units):
    print(f"  {u}")
