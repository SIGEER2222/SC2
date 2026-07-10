"""从 DocumentHeader 中移除依赖。"""
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

def remove_dependency(data, dep_to_remove):
    dep_count_offset, dep_count, deps_found, kv_count_offset = parse_dependencies(data)
    
    # Find the dependency to remove
    to_remove = None
    for offset, end, dep_str in deps_found:
        if dep_str == dep_to_remove:
            to_remove = (offset, end)
            break
    
    if to_remove is None:
        print(f"依赖未找到: {dep_to_remove}")
        return data, 0
    
    offset, end = to_remove
    # Remove the dependency bytes (including the null terminator)
    del data[offset:end + 1]
    
    # Decrement count
    new_count = dep_count - 1
    struct.pack_into("<I", data, dep_count_offset, new_count)
    print(f"DocumentHeader 依赖计数: {dep_count} -> {new_count}")
    print(f"移除: {dep_to_remove}")
    return data, 1

def remove_from_documentinfo(docinfo_path, dep_to_remove):
    if not os.path.exists(docinfo_path):
        return
    tree = ET.parse(docinfo_path)
    root = tree.getroot()
    deps_elem = root.find("Dependencies")
    if deps_elem is None:
        return
    
    to_remove_nodes = []
    for value_elem in deps_elem.findall("Value"):
        if value_elem.text and value_elem.text.strip() == dep_to_remove:
            to_remove_nodes.append(value_elem)
    
    for node in to_remove_nodes:
        deps_elem.remove(node)
        print(f"DocumentInfo 移除: {dep_to_remove}")
    
    if to_remove_nodes:
        ET.indent(tree, space="    ")
        tree.write(docinfo_path, encoding="utf-8", xml_declaration=True)

def main():
    if len(sys.argv) < 3:
        print("用法: python remove_docheader_dep.py <DocumentHeader路径> <要移除的依赖>")
        sys.exit(1)
    
    docheader_path = sys.argv[1]
    dep_to_remove = sys.argv[2]
    
    data = read_docheader(docheader_path)
    print(f"处理: {docheader_path}")
    print(f"大小: {len(data)} 字节")
    
    _, dep_count, deps_found, _ = parse_dependencies(data)
    print(f"当前依赖 ({dep_count} 个):")
    for _, _, s in deps_found:
        print(f"  {s}")
    
    new_data, removed = remove_dependency(data, dep_to_remove)
    
    if removed > 0:
        with open(docheader_path, "wb") as f:
            f.write(new_data)
        print(f"已更新, 新大小: {len(new_data)} 字节")
        
        docinfo_path = os.path.join(os.path.dirname(docheader_path), "DocumentInfo")
        remove_from_documentinfo(docinfo_path, dep_to_remove)
    
    print("完成")

if __name__ == "__main__":
    main()