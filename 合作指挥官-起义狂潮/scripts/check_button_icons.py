"""检查 ButtonData.xml 中所有图标路径是否存在"""
import xml.etree.ElementTree as ET
import os

mod_root = r'Mods\7vs1\Alenger3.SC2Mod'
button_path = mod_root + r'\Base.SC2Data\GameData\ButtonData.xml'
textures_dir = mod_root + r'\Assets\Textures'

# SC2 原版纹理路径（在游戏 MPQ 中）
# 我们只能检查 mod 自带的纹理，原版纹理假设存在
tree = ET.parse(button_path)
root = tree.getroot()

missing = []
present = []
for btn in root.findall('CButton'):
    bid = btn.get('id', '')
    icon_elem = btn.find('Icon')
    if icon_elem is not None:
        icon_path = icon_elem.get('value', '')
        if icon_path:
            # 提取文件名
            filename = os.path.basename(icon_path.replace('\\', '/'))
            # 检查是否在 mod 的 Textures 目录中
            local_path = os.path.join(textures_dir, filename)
            if os.path.exists(local_path):
                present.append((bid, filename))
            else:
                # 检查是否是原版 SC2 纹理（不在 mod 中）
                missing.append((bid, filename, icon_path))

print(f'=== mod 自带图标的按钮 ({len(present)} 个) ===')
for bid, fn in present[:10]:
    print(f'  {bid} -> {fn}')
print(f'  ... (共 {len(present)} 个)')

print(f'\n=== 引用原版/缺失图标的按钮 ({len(missing)} 个) ===')
for bid, fn, full_path in missing[:20]:
    print(f'  {bid} -> {fn}')
print(f'  ... (共 {len(missing)} 个)')
