"""
create-raynorx.py
把当前 mod 里的雷诺 (Raynor) 克隆成 RaynorX 指挥官。
叠加海克斯 mod 里的修改（RaynorCommando 强化、牛头人升级等）。

策略：
1. 读取所有 Raynor 相关 XML 文件，提取 id 含 Raynor/raynor 的条目
2. 做字符串替换: Raynor -> RaynorX (精确匹配 ID 级别)
3. 输出到新文件：UnitData_RaynorX.xml, AbilData_RaynorX.xml, UpgradeData_RaynorX.xml
   RequirementNodeData_RaynorX.xml, RequirementData_RaynorX.xml
4. 追加 RaynorXCommander 升级 & 需求条件
5. 追加到 CoopZeroPop 的 UserData.xml 注册新指挥官
"""

import re
import os
import shutil
from pathlib import Path

BASE = Path("E:/Code/MyMod/SC2/合作指挥官-起义狂潮/Mods/7vs1")
CATALOG = BASE / "CommanderCatalog.SC2Mod/Base.SC2Data/GameData"
ZEROPOPGD = BASE / "CoopZeroPop.SC2Mod/Base.SC2Data/GameData"
ZEROPOPBASE = BASE / "CoopZeroPop.SC2Mod/Base.SC2Data"
HEX = Path("E:/Code/MyMod/SC2/解包数据/海克斯合作PVP0.110.SC2Mod/Base.SC2Data/GameData")


def raynor_to_raynorx(text):
    """
    把所有 "Raynor" 替换成 "RaynorX"。
    规则：Raynor 后面不是小写字母时才替换（避免 RaynorX 重复）。
    - CasterRaynor -> CasterRaynorX (末尾)
    - RaynorCommander -> RaynorXCommander (后接大写)
    - MarineRaynor -> MarineRaynorX (末尾)
    - RaynorX 不受影响（lookahead !X）
    """
    pattern = re.compile(r'Raynor(?!X)(?=[A-Z0-9"\'\\s<>/,=.\-]|$)')
    return pattern.sub('RaynorX', text)


def extract_raynor_entries(xml_text):
    """
    从 XML Catalog 里提取所有含 Raynor 的顶层条目 (<CXxx id="...Raynor...">...</CXxx>)
    返回这些条目的列表（字符串），已替换为 RaynorX。
    """
    entries = []
    # 匹配顶层元素（2空格缩进）
    pattern = re.compile(
        r'^  <(C\w+)[^>]*id="[^"]*[Rr]aynor[^"]*".*?</\1>',
        re.MULTILINE | re.DOTALL
    )
    for m in pattern.finditer(xml_text):
        entry = m.group(0)
        entry_x = raynor_to_raynorx(entry)
        entries.append(entry_x)
    return entries


def wrap_catalog(entries, header='<?xml version="1.0" encoding="utf-8"?>\n<Catalog>'):
    lines = [header]
    for e in entries:
        lines.append(e)
    lines.append('</Catalog>\n')
    return '\n'.join(lines)


def append_to_catalog_file(filepath, new_entries_xml):
    """在 </Catalog> 前插入新条目"""
    text = filepath.read_text(encoding='utf-8')
    idx = text.rfind('</Catalog>')
    if idx == -1:
        print(f"WARNING: No </Catalog> in {filepath}")
        return
    new_text = text[:idx] + new_entries_xml + '\n' + text[idx:]
    filepath.write_text(new_text, encoding='utf-8')


# ============================================================
# 1. 生成 UnitData_RaynorX.xml (从 CommanderCatalog)
# ============================================================
print("=== Step 1: UnitData_RaynorX.xml ===")
unit_src = (CATALOG / "UnitData_Raynor.xml").read_text(encoding='utf-8')

# 从海克斯 mod 补充 RaynorCommando 的修改（血量/护甲）
hex_unit = (HEX / "UnitData.xml").read_text(encoding='utf-8')
# 提取海克斯里 RaynorCommando 的差异
hex_raynor_commando = re.search(
    r'<CUnit id="RaynorCommando">.*?</CUnit>',
    hex_unit, re.DOTALL
)

# 把整个 UnitData_Raynor.xml 的内容替换 Raynor -> RaynorX
# 但 parent 属性里引用的官方 unit（如 parent="Marine"）不替换
# 先做全量替换，再把 parent="XxxRaynorX" 改回正确父类
unit_x_text = unit_src

# 替换所有 Raynor -> RaynorX
unit_x_text = raynor_to_raynorx(unit_x_text)

# 修复：parent 里如果指向官方单位（Marine, Medic等）不应该被替换
# 但由于 parent 里不含 "Raynor"，实际上不受影响

# 修复：link 到通用能力的不需要加X（如 Link="Stimpack"）也不含Raynor，OK

# 修复：HaveRaynorXCommander -> HaveRaynorXCommander (正确)
# 修复：NotHaveRaynorXCommander -> NotHaveRaynorXCommander (正确)

# 写出文件
out_unit = CATALOG / "UnitData_RaynorX.xml"
out_unit.write_text(unit_x_text, encoding='utf-8')
print(f"  Written: {out_unit}")

# ============================================================
# 2. 生成 AbilData_RaynorX.xml (从 CommanderCatalog)
# ============================================================
print("=== Step 2: AbilData_RaynorX.xml ===")
abil_src = (CATALOG / "AbilData_Raynor.xml").read_text(encoding='utf-8')
abil_x_text = raynor_to_raynorx(abil_src)
out_abil = CATALOG / "AbilData_RaynorX.xml"
out_abil.write_text(abil_x_text, encoding='utf-8')
print(f"  Written: {out_abil}")

# ============================================================
# 3. 生成 UpgradeData_RaynorX.xml (从 CommanderCatalog)
#    提取所有含 Raynor 的 CUpgrade 条目
# ============================================================
print("=== Step 3: UpgradeData_RaynorX.xml ===")
upgrade_src = (CATALOG / "UpgradeData.xml").read_text(encoding='utf-8')
upgrade_entries = extract_raynor_entries(upgrade_src)

# 从海克斯追加牛头人升级 (RaynorXTalentedTerranInfantryArmorLevel1~3)
hex_upgrade = (HEX / "UpgradeData.xml").read_text(encoding='utf-8')
hex_upgrade_entries = []
for entry_name in [
    "RaynorTalentedTerranInfantryArmorLevel1",
    "RaynorTalentedTerranInfantryArmorLevel2",
    "RaynorTalentedTerranInfantryArmorLevel3"
]:
    m = re.search(
        r'<CUpgrade id="' + entry_name + r'".*?</CUpgrade>',
        hex_upgrade, re.DOTALL
    )
    if m:
        hex_upgrade_entries.append(raynor_to_raynorx(m.group(0)))
        print(f"  Found hex upgrade: {entry_name} -> {entry_name.replace('Raynor', 'RaynorX')}")
    else:
        print(f"  WARNING: Not found in hex: {entry_name}")

# 也追加 CommanderPrestigeRaynorXBio 里的牛头人条目
# 海克斯版本覆盖了 CommanderPrestigeRaynorBio 的效果
hex_bio = re.search(
    r'<CUpgrade id="CommanderPrestigeRaynorBio">.*?</CUpgrade>',
    hex_upgrade, re.DOTALL
)
if hex_bio:
    # 这个在 upgrade_entries 里已经有了（从 CommanderCatalog 提取）
    # 用海克斯版本覆盖（不同：海克斯加了牛头人血量）
    # 找到并替换
    hex_bio_x = raynor_to_raynorx(hex_bio.group(0))
    # 去掉 upgrade_entries 里的 CommanderPrestigeRaynorBio，换成海克斯版
    upgrade_entries = [
        e for e in upgrade_entries
        if 'id="CommanderPrestigeRaynorXBio"' not in e
    ]
    upgrade_entries.append(hex_bio_x)
    print("  Replaced CommanderPrestigeRaynorXBio with hex version")

upgrade_entries += hex_upgrade_entries

# 追加 RaynorXCommander 升级（用于需求检查）
upgrade_entries.append(
    '  <CUpgrade id="RaynorXCommander" parent="RaynorCommander" />'
)

upgrade_x_content = '<?xml version="1.0" encoding="utf-8"?>\n<Catalog>\n'
for e in upgrade_entries:
    upgrade_x_content += e + '\n'
upgrade_x_content += '</Catalog>\n'

out_upgrade = CATALOG / "UpgradeData_RaynorX.xml"
out_upgrade.write_text(upgrade_x_content, encoding='utf-8')
print(f"  Written: {out_upgrade} ({len(upgrade_entries)} entries)")

# ============================================================
# 4. 生成 RequirementNodeData_RaynorX.xml (从 CommanderCatalog)
# ============================================================
print("=== Step 4: RequirementNodeData_RaynorX.xml ===")
reqnode_src = (CATALOG / "RequirementNodeData.xml").read_text(encoding='utf-8')
reqnode_entries = extract_raynor_entries(reqnode_src)

# 追加 CountUpgradeRaynorXCommanderCompleteOnly
reqnode_entries.append(
    '  <CRequirementCountUpgrade id="CountUpgradeRaynorXCommanderCompleteOnly">\n'
    '    <Flags index="TechTreeCheat" value="0" />\n'
    '    <Count Link="RaynorXCommander" State="CompleteOnly" />\n'
    '  </CRequirementCountUpgrade>'
)
reqnode_entries.append(
    '  <CRequirementNot id="NotCountUpgradeRaynorXCommanderCompleteOnly">\n'
    '    <Operand value="CountUpgradeRaynorXCommanderCompleteOnly" />\n'
    '  </CRequirementNot>'
)

reqnode_x_content = '<?xml version="1.0" encoding="utf-8"?>\n<Catalog>\n'
for e in reqnode_entries:
    reqnode_x_content += e + '\n'
reqnode_x_content += '</Catalog>\n'

out_reqnode = CATALOG / "RequirementNodeData_RaynorX.xml"
out_reqnode.write_text(reqnode_x_content, encoding='utf-8')
print(f"  Written: {out_reqnode} ({len(reqnode_entries)} entries)")

# ============================================================
# 5. 生成 RequirementData_RaynorX.xml (从 CommanderCatalog)
# ============================================================
print("=== Step 5: RequirementData_RaynorX.xml ===")
req_src = (CATALOG / "RequirementData.xml").read_text(encoding='utf-8')
req_entries = extract_raynor_entries(req_src)

# 追加 HaveRaynorXCommander / NotHaveRaynorXCommander
req_entries.append(
    '  <CRequirement id="HaveRaynorXCommander">\n'
    '    <NodeArray index="Show" Link="CountUpgradeRaynorXCommanderCompleteOnly" />\n'
    '    <NodeArray index="Use" Link="CountUpgradeRaynorXCommanderCompleteOnly" />\n'
    '  </CRequirement>'
)
req_entries.append(
    '  <CRequirement id="NotHaveRaynorXCommander">\n'
    '    <NodeArray index="Show" Link="NotCountUpgradeRaynorXCommanderCompleteOnly" />\n'
    '    <NodeArray index="Use" Link="NotCountUpgradeRaynorXCommanderCompleteOnly" />\n'
    '  </CRequirement>'
)

req_x_content = '<?xml version="1.0" encoding="utf-8"?>\n<Catalog>\n'
for e in req_entries:
    req_x_content += e + '\n'
req_x_content += '</Catalog>\n'

out_req = CATALOG / "RequirementData_RaynorX.xml"
out_req.write_text(req_x_content, encoding='utf-8')
print(f"  Written: {out_req} ({len(req_entries)} entries)")

# ============================================================
# 6. 生成 LibE0EAE147_RaynorXRuntime.galaxy (从 CoopZeroPop)
#    克隆现有 RaynorRuntime，替换所有 ID
# ============================================================
print("=== Step 6: LibE0EAE147_RaynorXRuntime.galaxy ===")
runtime_src = (ZEROPOPBASE / "LibE0EAE146_RaynorRuntime.galaxy").read_text(encoding='utf-8')

# 替换库前缀和 Raynor 标识符
runtime_x = raynor_to_raynorx(runtime_src)
# 替换库 ID（E0EAE146 -> E0EAE147）
runtime_x = runtime_x.replace('libE0EAE146', 'libE0EAE147')

out_runtime = ZEROPOPBASE / "LibE0EAE147_RaynorXRuntime.galaxy"
out_runtime.write_text(runtime_x, encoding='utf-8')
print(f"  Written: {out_runtime}")

# 7. 在 UserData.xml 里注册新指挥官（追加到 CoopZeroPop）
print("=== Step 7: Register RaynorX in UserData.xml ===")
userdata_path = ZEROPOPGD / "UserData.xml"
userdata = userdata_path.read_text(encoding='utf-8')

# 检查是否已注册
if 'RaynorXCommander' in userdata:
    print("  Already registered, skipping.")
else:
    # 找 RaynorCommander 所在行，在其后追加 RaynorXCommander
    m = re.search(r'(<CUser[^>]+>[^<]*<Value[^>]*>TerranRaynor</Value>[^<]*</CUser>)', userdata)
    if m:
        insert_after = m.group(0)
        raynorx_user = insert_after.replace('TerranRaynor', 'TerranRaynorX').replace(
            'RaynorCommander', 'RaynorXCommander'
        )
        userdata = userdata.replace(insert_after, insert_after + '\n' + raynorx_user)
        userdata_path.write_text(userdata, encoding='utf-8')
        print("  Registered RaynorX via UserData.xml")
    else:
        # 直接在最后追加
        raynorx_block = '\n  <!-- RaynorX Commander (海克斯版本测试) -->\n  <CUser id="RaynorXCommander">\n    <Value>TerranRaynorX</Value>\n  </CUser>'
        userdata = userdata.replace('</Catalog>', raynorx_block + '\n</Catalog>')
        userdata_path.write_text(userdata, encoding='utf-8')
        print("  Registered RaynorX (fallback append)")

print("\n=== ALL DONE ===")
print("新文件:")
for f in [out_unit, out_abil, out_upgrade, out_reqnode, out_req, out_runtime]:
    print(f"  {f}")
