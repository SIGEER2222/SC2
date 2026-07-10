"""临时脚本：列出 Alenger3 所有单位的能力和卡牌按钮"""
import xml.etree.ElementTree as ET
import re
import sys

mod_path = r'Mods\7vs1\Alenger3.SC2Mod\Base.SC2Data\GameData'
unit_path = mod_path + r'\UnitData.xml'
abil_path = mod_path + r'\AbilData.xml'

# 解析单位数据
tree = ET.parse(unit_path)
root = tree.getroot()

# 排除辅助单位
exclude_patterns = [r'Weapon$', r'Placement$', r'Flying$', r'Missile$', r'Placeholder$']

def is_excluded(uid):
    return any(re.search(p, uid) for p in exclude_patterns)

# 基础能力（不显示）
basic_abils = {'stop', 'attack', 'move', 'que1', 'que5', 'Rally', 'BuildInProgress'}

# 收集所有单位
units = []
for unit in root.findall('CUnit'):
    uid = unit.get('id', '')
    if not uid or not uid.startswith('3'):
        continue
    if is_excluded(uid):
        continue
    
    abils = []
    for a in unit.findall('AbilArray'):
        link = a.get('Link', '')
        if link and link not in basic_abils:
            abils.append(link)
    
    cards = []
    for cl in unit.findall('CardLayouts'):
        for lb in cl.findall('LayoutButtons'):
            face = lb.get('Face', '')
            typ = lb.get('Type', '')
            cmd = lb.get('AbilCmd', '')
            req = lb.get('Requirements', '')
            cards.append((face, typ, cmd, req))
    
    units.append((uid, abils, cards))

# 输出到文件
out_path = 'scripts/unit_abil_list.txt'
with open(out_path, 'w', encoding='utf-8') as f:
    for uid, abils, cards in units:
        # 过滤掉基础卡牌（move/stop/attack/patrol/hold）
        basic_faces = {'Move', 'Stop', 'MoveHoldPosition', 'Attack', 'AcquireMove', 'MovePatrol',
                       'Rally', 'Halt', 'Cancel', 'CancelBuilding', 'SelectBuilder', 'Lift'}
        extra_cards = [c for c in cards if c[0] not in basic_faces]
        
        f.write(f'\n=== {uid} ===\n')
        f.write(f'  AbilArray: {abils if abils else "(无)"}\n')
        if extra_cards:
            for face, typ, cmd, req in extra_cards:
                req_str = f' [需:{req}]' if req else ''
                f.write(f'  [{typ}] {face} -> {cmd}{req_str}\n')
        elif not cards:
            f.write('  (无卡牌按钮)\n')
print(f'Written to {out_path}')
