#!/usr/bin/env python3
"""
合并 CommanderCatalog 的需求节点和数据到 CoopZeroPop 里。
用法：python scripts/merge-requirements.py
"""

import re

def merge_requirement_node_data():
    """合并 RequirementNodeData.xml"""
    src_file = r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods\7vs1\CommanderCatalog.SC2Mod\Base.SC2Data\GameData\RequirementNodeData.xml"
    dst_file = r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\GameData\RequirementNodeData.xml"
    
    # 读取源文件
    with open(src_file, 'r', encoding='utf-8') as f:
        src_content = f.read()
    
    # 提取 <Catalog> 和 </Catalog> 之间的内容（跳过第一行 <?xml...?>）
    src_match = re.search(r'<Catalog>(.*?)</Catalog>', src_content, re.DOTALL)
    if not src_match:
        print(f"Error: <Catalog> not found in {src_file}")
        return False
    
    src_nodes = src_match.group(1).strip()
    
    # 读取目标文件
    with open(dst_file, 'r', encoding='utf-8') as f:
        dst_content = f.read()
    
    # 在 </Catalog> 前插入源节点的内容
    dst_content = dst_content.replace('</Catalog>', f'{src_nodes}\n</Catalog>')
    
    # 写回文件
    with open(dst_file, 'w', encoding='utf-8') as f:
        f.write(dst_content)
    
    print(f"Merged RequirementNodeData.xml: added {len(src_nodes.splitlines())} lines")
    return True

def merge_requirement_data():
    """合并 RequirementData.xml"""
    src_file = r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods\7vs1\CommanderCatalog.SC2Mod\Base.SC2Data\GameData\RequirementData.xml"
    dst_file = r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\GameData\RequirementData.xml"
    
    # 读取源文件
    with open(src_file, 'r', encoding='utf-8') as f:
        src_content = f.read()
    
    # 提取 <Catalog> 和 </Catalog> 之间的内容
    src_match = re.search(r'<Catalog>(.*?)</Catalog>', src_content, re.DOTALL)
    if not src_match:
        print(f"Error: <Catalog> not found in {src_file}")
        return False
    
    src_requirements = src_match.group(1).strip()
    
    # 读取目标文件
    with open(dst_file, 'r', encoding='utf-8') as f:
        dst_content = f.read()
    
    # 在 </Catalog> 前插入源需求的内容
    dst_content = dst_content.replace('</Catalog>', f'{src_requirements}\n</Catalog>')
    
    # 写回文件
    with open(dst_file, 'w', encoding='utf-8') as f:
        f.write(dst_content)
    
    print(f"Merged RequirementData.xml: added {len(src_requirements.splitlines())} lines")
    return True

if __name__ == '__main__':
    print("Merging RequirementNodeData.xml...")
    if not merge_requirement_node_data():
        exit(1)
    
    print("Merging RequirementData.xml...")
    if not merge_requirement_data():
        exit(1)
    
    print("Done!")