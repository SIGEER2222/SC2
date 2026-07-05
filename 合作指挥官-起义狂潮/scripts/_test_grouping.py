"""测试 VioletsHoTSReworkMod 单位按指挥官分组规则"""
import re
from pathlib import Path
from collections import defaultdict

mod_dir = Path(r"C:\Users\22448\Downloads\阿巴瑟之心\Mods\VioletsHoTSReworkMod.SC2Mod")
unit_file = mod_dir / "Base.SC2Data" / "GameData" / "UnitData.xml"
text = unit_file.read_text(encoding="utf-8", errors="replace")

CUNIT_RE = re.compile(r'<CUnit\s+id="([^"]+)"(?:\s+parent="([^"]+)")?')
units = []
for line in text.splitlines():
    if line.strip().startswith("<!--"):
        continue
    m = CUNIT_RE.search(line)
    if m:
        units.append(m.group(1))

# ========================================
# VioletsHoTSReworkMod 指挥官分组规则
# ========================================
# 按 mod 内部约定，每个指挥官用特定前缀/关键字标识
# 规则按优先级从高到低匹配，第一个匹配的归属生效

def classify_violets_unit(unit_id):
    """返回 (commander_id, commander_label) 或 None 表示共享/未分类"""

    # 1. Mengsk 系列（人形帝国指挥官）
    if unit_id.startswith("Mengsk"):
        return ("Violets_Mengsk", "Mengsk（蒙斯克）")

    # 2. Dehaka / Primal 系列（原始虫族指挥官）
    if unit_id.startswith("Dehaka") or unit_id.startswith("Primal"):
        return ("Violets_Dehaka", "Dehaka（迪哈卡）")

    # 3. Stukov 系列（感染人类）
    if (unit_id.startswith("Infested")
        or unit_id in ("Infestor", "InfestorBurrowed")
        or unit_id in ("DevilDog", "ScienceVessel")):
        return ("Violets_Stukov", "Stukov（斯图科夫）")

    # 4. Kerrigan 系列（K5 虫群女王）
    if (unit_id.startswith("K5Kerrigan")
        or unit_id.startswith("Kerrigan")
        or unit_id in ("HunterKiller", "HunterKillerBurrowed")
        or unit_id in ("SwarmQueen", "SwarmQueenBurrowed")
        or unit_id in ("HugeSwarmQueen", "HugeSwarmQueenBurrowed")
        or unit_id in ("LargeSwarmQueen", "LargeSwarmQueenBurrowed")
        or unit_id == "Brutalisk"):
        return ("Violets_Kerrigan", "Kerrigan（凯瑞甘）")

    # 5. ZaGara 系列（扎加拉）
    if unit_id.startswith("ZaGara"):
        return ("Violets_ZaGara", "ZaGara（扎加拉）")

    # 6. Aiur 星灵（Artanis 系）
    if unit_id.endswith("Aiur"):
        return ("Violets_Artanis", "Artanis（阿塔尼斯）")

    # 7. Shakuras 星灵（Zeratul 系）
    if unit_id.endswith("Shakuras"):
        return ("Violets_Zeratul", "Zeratul（泽拉图）")

    # 8. Taldarim 星灵（Alarak 系）
    if unit_id.endswith("Taldarim"):
        return ("Violets_Alarak", "Alarak（阿拉纳克）")

    # 9. Purifier 星灵（Fenix 系）
    if unit_id.endswith("Purifier"):
        return ("Violets_Fenix", "Fenix（菲尼克斯）")

    # 未分类
    return None


# 测试分组
groups = defaultdict(list)
unclassified = []
for u in units:
    result = classify_violets_unit(u)
    if result:
        groups[result[1]].append(u)
    else:
        unclassified.append(u)

print("=== VioletsHoTSReworkMod 指挥官分组结果 ===")
print()
for label, members in sorted(groups.items()):
    print(f"## {label} ({len(members)} 个)")
    for u in sorted(members):
        print(f"  - {u}")
    print()

print(f"## 未分类/共享 ({len(unclassified)} 个)")
for u in sorted(unclassified):
    print(f"  - {u}")
