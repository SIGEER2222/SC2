"""去掉 AbilData.xml 中所有 State="Restricted" 属性

用法:
  python strip_restricted.py <xml文件路径>
  python strip_restricted.py <xml文件路径1> <xml文件路径2> ...
"""
import re
import sys

if len(sys.argv) < 2:
    print('用法: python strip_restricted.py <xml文件路径> [...]')
    sys.exit(1)

for path in sys.argv[1:]:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    count = content.count('State="Restricted"')
    if count == 0:
        print(f'{path}: 无 State="Restricted"，跳过')
        continue

    new_content = re.sub(r'\s+State="Restricted"', '', content)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print(f'{path}: 去掉 {count} 个 State="Restricted"')
