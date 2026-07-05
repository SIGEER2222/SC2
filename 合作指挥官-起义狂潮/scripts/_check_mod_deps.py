"""检查 MPQ 格式 mod 的依赖关系"""
import sys
from pathlib import Path
from mpyq import MPQArchive

def check_mod(mod_path):
    print(f"=== {Path(mod_path).name} ===")
    try:
        a = MPQArchive(str(mod_path))
        names = []
        for n in a.files:
            if n is None:
                continue
            if isinstance(n, bytes):
                names.append(n.decode('utf-8', 'replace'))
            else:
                names.append(n)

        # 找 DocumentInfo
        doc_info_name = None
        for n in names:
            if n.endswith('DocumentInfo') or n == 'DocumentInfo':
                doc_info_name = n
                break

        if doc_info_name:
            data = a.read_file(doc_info_name)
            if isinstance(data, bytes):
                text = data.decode('utf-8', 'replace')
            else:
                text = data
            print("DocumentInfo:")
            print(text)
        else:
            print("No DocumentInfo found")
            print(f"Files ({len(names)}):")
            for n in names[:20]:
                print(f"  {n}")
    except Exception as e:
        print(f"ERROR: {e}")
    print()

# 检查所有阿巴瑟之心 mod
mods_root = Path(r"C:\Users\22448\Downloads\阿巴瑟之心\Mods")
for mod in sorted(mods_root.glob("*.SC2Mod")):
    if mod.is_file():
        check_mod(mod)

alenger_dir = mods_root / "Alenger"
if alenger_dir.exists():
    for mod in sorted(alenger_dir.glob("*.SC2Mod")):
        if mod.is_file():
            check_mod(mod)
