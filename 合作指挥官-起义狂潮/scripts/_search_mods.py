import os
import re

mods_root = r'E:\SC2\SC2new\StarCraft II\Mods'
keywords = ['Covert', 'Umojan', 'crys_swarm']

print(f'=== Searching in {mods_root} ===')
found = []
for root, dirs, files in os.walk(mods_root):
    depth = root[len(mods_root):].count(os.sep)
    if depth > 3:
        continue
    for name in files + dirs:
        if name.endswith('.SC2Mod'):
            for kw in keywords:
                if kw.lower() in name.lower():
                    found.append(os.path.join(root, name))
                    break

for f in found:
    print(f)
print(f'Total: {len(found)}')
