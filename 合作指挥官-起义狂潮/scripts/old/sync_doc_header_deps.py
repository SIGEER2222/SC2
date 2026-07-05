"""Sync DocumentInfo dependencies to DocumentHeader (binary).

DocumentHeader format (simplified):
- Header bytes (varies)
- ... some sections ...
- Dependency count (4 bytes little-endian uint32)
- For each dependency:
  - UTF-8 encoded string
  - Null terminator (0x00)
- ... rest of file ...

This script:
1. Reads dependencies from DocumentInfo (XML, UTF-8)
2. Finds the dependency table in DocumentHeader
3. Replaces the dependency table with new dependencies
"""

import os
import re
import struct
import sys
from xml.etree import ElementTree as ET


def read_dependencies_from_info(doc_info_path):
    """Read dependencies from DocumentInfo XML file."""
    with open(doc_info_path, 'rb') as f:
        data = f.read()
    # Skip BOM if present
    if data.startswith(b'\xef\xbb\xbf'):
        data = data[3:]
    text = data.decode('utf-8')
    # Truncate to </DocInfo> end
    end_idx = text.find('</DocInfo>')
    if end_idx >= 0:
        text = text[:end_idx + len('</DocInfo>')]
    root = ET.fromstring(text)
    deps = []
    for value_node in root.findall('./Dependencies/Value'):
        deps.append(value_node.text)
    return deps


def find_dependency_table_offset(data):
    """Find the dependency table start offset in DocumentHeader binary data.

    Look for the markers file: or bnet: preceded by a 4-byte uint32 count.
    """
    markers = [b'file:', b'bnet:', b'ExtensionMod']
    for offset in range(4, len(data)):
        for marker in markers:
            if data[offset:offset + len(marker)] == marker:
                count = struct.unpack_from('<I', data, offset - 4)[0]
                if 0 < count < 128:
                    return offset - 4
    return -1


def get_dependency_end(data, start_offset):
    """Get the end offset of the dependency table."""
    count = struct.unpack_from('<I', data, start_offset)[0]
    offset = start_offset + 4
    for _ in range(count):
        while offset < len(data) and data[offset] != 0:
            offset += 1
        if offset >= len(data):
            raise ValueError('Dependency string not null-terminated')
        offset += 1
    return offset


def set_dependencies(doc_header_path, dependencies):
    """Update the dependency table in DocumentHeader."""
    with open(doc_header_path, 'rb') as f:
        data = f.read()
    
    table_offset = find_dependency_table_offset(data)
    if table_offset < 0:
        raise ValueError('Dependency table not found in DocumentHeader')
    
    table_end = get_dependency_end(data, table_offset)
    
    # Build new dependency table
    new_bytes = struct.pack('<I', len(dependencies))
    for dep in dependencies:
        new_bytes += dep.encode('utf-8') + b'\x00'
    
    new_data = data[:table_offset] + new_bytes + data[table_end:]
    
    with open(doc_header_path, 'wb') as f:
        f.write(new_data)
    
    return len(dependencies)


if __name__ == '__main__':
    base_dir = r'e:\Code\MyMod\SC2\合作指挥官-起义狂潮\Maps\abathur_test_map'
    doc_info = os.path.join(base_dir, 'DocumentInfo')
    doc_header = os.path.join(base_dir, 'DocumentHeader')
    
    deps = read_dependencies_from_info(doc_info)
    print('Dependencies from DocumentInfo:')
    for d in deps:
        print(f'  - {d}')
    
    count = set_dependencies(doc_header, deps)
    print(f'\nDocumentHeader updated with {count} dependencies')
    
    # Verify
    with open(doc_header, 'rb') as f:
        data = f.read()
    text = data.decode('utf-8', errors='ignore')
    matches = re.findall(r'[a-z_]+:[^\x00]+', text)
    print('\nDependencies in DocumentHeader (after update):')
    for m in matches:
        print(f'  - {m}')
