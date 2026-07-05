import os

paths = [
    r'E:\SC2\SC2new\StarCraft II\Mods\CovertOps.SC2Mod',
    r'E:\SC2\SC2new\StarCraft II\Mods\Umojan.SC2Mod',
]

for p in paths:
    print(f'=== {p} ===')
    if os.path.isdir(p):
        print('  Type: Directory')
        for root, dirs, files in os.walk(p):
            for f in files:
                full = os.path.join(root, f)
                size = os.path.getsize(full)
                print(f'    {full} ({size} bytes)')
    elif os.path.isfile(p):
        print(f'  Type: File, size={os.path.getsize(p)} bytes')
    else:
        print('  Type: Not exists')
    print()
