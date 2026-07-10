"""向 DocumentHeader 添加依赖。"""
import struct
import sys
import os
import xml.etree.ElementTree as ET

def read_docheader(path):
    with open(path, "rb") as f:
        return bytearray(f.read())

def parse_dependencies(data):
    dep_count_offset = 0x2C
    dep_count = struct.unpack_from("<I", data, dep_count_offset)[0]
    dep_strings_start = dep_count_offset + 4
    offset = dep_strings_start
    deps_found = []
    for i in range(dep_count):
        end = data.index(b"\x00", offset)
        dep_bytes = bytes(data[offset:end])
        try:
            dep_str = dep_bytes.decode("utf-8")
        except UnicodeDecodeError:
            dep_str = dep_bytes.decode("gbk", errors="replace")
        deps_found.append((offset, end, dep_str))
        offset = end + 1
    kv_count_offset = offset
    return dep_count_offset, dep_count, deps_found, kv_count_offset

def add_dependency(data, dep_to_add):
    dep_count_offset, dep_count, deps_found, kv_count_offset = parse_dependencies(data)
    
    # Check if already exists
    for _, _, dep_str in deps_found:
        if dep_str == dep_to_add:
            print(f"依赖已存在: {dep_to_add}")
            return data, 0
    
    # Insert at the beginning (position 0x30)
    insert_pos = dep_count_offset + 4  # right after the count
    dep_bytes = dep_to_add.encode("utf-8") + b"\x00"
    
    data[insert_pos:insert_pos] = dep_bytes
    
    # Increment count
    new_count = dep_count + 1
    struct.pack_into("<I", data, dep_count_offset, new_count)
    print(f"DocumentHeader 依赖计数: {dep_count} -> {new_count}")
    print(f"添加: {dep_to_add}")
    return data, 1

def add_to_documentinfo(docinfo_path, dep_to_add):
    if not os.path.exists(docinfo_path):
        return
    tree = ET.parse(docinfo_path)
    root = tree.getroot()
    deps_elem = root.find("Dependencies")
    if deps_elem is None:
        deps_elem = ET.SubElement(root, "Dependencies")
    
    # Check if already exists
    for value_elem in deps_elem.findall("Value"):
        if value_elem.text and value_elem.text.strip() == dep_to_add:
            print(f"DocumentInfo 依赖已存在: {dep_to_add}")
            return
    
    # Insert at the beginning
    new_value = ET.Element("Value")
    new_value.text = dep_to_add
    deps_elem.insert(0, new_value)
    print(f"DocumentInfo 添加: {dep_to_add}")
    
    ET.indent(tree, space="    ")
    tree.write(docinfo_path, encoding="utf-8", xml_declaration=True)

def main():
    if len(sys.argv) < 3:
        print("用法: python add_docheader_dep.py <DocumentHeader路径> <要添加的依赖>")
        sys.exit(1)
    
    docheader_path = sys.argv[1]
    dep_to_add = sys.argv[2]
    
    data = read_docheader(docheader_path)
    print(f"处理: {docheader_path}")
    print(f"大小: {len(data)} 字节")
    
    _, dep_count, deps_found, _ = parse_dependencies(data)
    print(f"当前依赖 ({dep_count} 个):")
    for _, _, s in deps_found:
        print(f"  {s}")
    
    new_data, added = add_dependency(data, dep_to_add)
    
    if added > 0:
        with open(docheader_path, "wb") as f:
            f.write(new_data)
        print(f"已更新, 新大小: {len(new_data)} 字节")
        
        docinfo_path = os.path.join(os.path.dirname(docheader_path), "DocumentInfo")
        add_to_documentinfo(docinfo_path, dep_to_add)
    
    print("完成")

if __name__ == "__main__":
    main()