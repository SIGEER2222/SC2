"""
通用工具：向 SC2 地图/mod 的 DocumentHeader 二进制文件追加依赖。
同时同步更新 DocumentInfo（XML）中的 <Dependencies>。

用法:
    python append_docheader_dep.py <DocumentHeader路径> <依赖1> [依赖2] ...

示例:
    python append_docheader_dep.py "Maps\\abathur_test_map\\DocumentHeader" "file:Mods/7vs1/Alenger3Adapter.SC2Mod"

DocumentHeader 二进制格式:
    44 字节 header (magic "H2CS" + 版本 + 标志 + 时间戳等)
    4 字节 dependency count (little-endian uint32)
    N 个 null-terminated UTF-8 依赖字符串
    4 字节 key-value pair count
    key-value pairs: key_len(2) + key + type_id(4) + val_len(2) + value

注意:
    - DocumentHeader 路径和 DocumentInfo 路径在同一目录下
    - DocumentInfo 是 XML 格式，同步追加 <Value> 依赖
    - 如果依赖已存在，跳过追加
"""
import struct
import sys
import os
import xml.etree.ElementTree as ET


def read_docheader(path):
    with open(path, "rb") as f:
        return bytearray(f.read())


def parse_dependencies(data):
    """解析 DocumentHeader 中的依赖列表。
    返回 (dep_count_offset, dep_count, [(start, end, str), ...], kv_count_offset)
    """
    # dependency count 在 offset 0x2C (44 字节 header 之后)
    dep_count_offset = 0x2C
    dep_count = struct.unpack_from("<I", data, dep_count_offset)[0]

    # 依赖字符串从 offset 0x30 开始
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

    kv_count_offset = offset  # 最后一个依赖 null 之后就是 kv_count
    return dep_count_offset, dep_count, deps_found, kv_count_offset


def append_dependencies(data, new_deps):
    """向 DocumentHeader 追加依赖。返回 (new_data, appended_count)。"""
    dep_count_offset, dep_count, deps_found, kv_count_offset = parse_dependencies(data)

    # 过滤掉已存在的依赖
    existing_strs = [s for _, _, s in deps_found]
    to_append = [d for d in new_deps if d not in existing_strs]
    if not to_append:
        print("所有依赖已存在，无需修改 DocumentHeader")
        return data, 0

    # 在最后一个依赖字符串的 null 之后插入新依赖
    insert_pos = deps_found[-1][1] + 1  # null byte 之后
    new_bytes = b""
    for dep in to_append:
        new_bytes += dep.encode("utf-8") + b"\x00"

    data[insert_pos:insert_pos] = new_bytes

    # 增加 dependency count
    new_count = dep_count + len(to_append)
    struct.pack_into("<I", data, dep_count_offset, new_count)
    print(f"DocumentHeader 依赖计数: {dep_count} -> {new_count}")
    print(f"追加的依赖: {to_append}")
    return data, len(to_append)


def update_documentinfo(docinfo_path, new_deps):
    """同步更新 DocumentInfo XML 中的 <Dependencies>。"""
    if not os.path.exists(docinfo_path):
        print(f"DocumentInfo 不存在: {docinfo_path}，跳过 XML 同步")
        return

    # 读取并解析 XML
    with open(docinfo_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 解析 XML
    tree = ET.parse(docinfo_path)
    root = tree.getroot()

    # 找到 Dependencies 元素
    deps_elem = root.find("Dependencies")
    if deps_elem is None:
        # 创建 Dependencies 元素
        deps_elem = ET.SubElement(root, "Dependencies")

    # 获取现有依赖
    existing = set()
    for value_elem in deps_elem.findall("Value"):
        if value_elem.text:
            existing.add(value_elem.text.strip())

    # 追加新依赖
    appended = 0
    for dep in new_deps:
        if dep not in existing:
            value_elem = ET.SubElement(deps_elem, "Value")
            value_elem.text = dep
            existing.add(dep)
            appended += 1
            print(f"DocumentInfo 追加依赖: {dep}")

    if appended == 0:
        print("DocumentInfo 所有依赖已存在，无需修改")
        return

    # 写回文件（保持格式）
    # ET 写出的 XML 格式可能与原文件不同，这里手动写以保持兼容
    # 先用 ET 写出，再用 indent 美化
    ET.indent(tree, space="    ")
    tree.write(docinfo_path, encoding="utf-8", xml_declaration=True)
    print(f"DocumentInfo 已更新，追加 {appended} 个依赖")


def main():
    if len(sys.argv) < 3:
        print("用法: python append_docheader_dep.py <DocumentHeader路径> <依赖1> [依赖2] ...")
        print("示例: python append_docheader_dep.py \"Maps\\abathur_test_map\\DocumentHeader\" \"file:Mods/7vs1/Alenger3Adapter.SC2Mod\"")
        sys.exit(1)

    docheader_path = sys.argv[1]
    new_deps = sys.argv[2:]

    if not os.path.exists(docheader_path):
        print(f"错误: DocumentHeader 不存在: {docheader_path}")
        sys.exit(1)

    # 读取 DocumentHeader
    data = read_docheader(docheader_path)
    print(f"=== 处理: {docheader_path} ===")
    print(f"原始大小: {len(data)} 字节")

    # 解析并显示当前依赖
    _, dep_count, deps_found, _ = parse_dependencies(data)
    print(f"\n当前依赖 ({dep_count} 个):")
    for _, _, s in deps_found:
        print(f"  {s}")

    # 追加依赖
    print(f"\n要追加的依赖: {new_deps}")
    new_data, appended_count = append_dependencies(data, new_deps)

    if appended_count > 0:
        # 写回 DocumentHeader
        with open(docheader_path, "wb") as f:
            f.write(new_data)
        print(f"\nDocumentHeader 已更新，新大小: {len(new_data)} 字节")

        # 同步更新 DocumentInfo
        docinfo_path = os.path.join(os.path.dirname(docheader_path), "DocumentInfo")
        update_documentinfo(docinfo_path, new_deps)
    else:
        print("\n无需修改")

    print("=== 完成 ===")


if __name__ == "__main__":
    main()
