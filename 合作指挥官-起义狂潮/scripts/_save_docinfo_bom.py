import os

content = '''<?xml version="1.0" encoding="utf-8"?>
<DocInfo>
    <Dependencies>
        <Value>bnet:虚空之遗 (Mod)/0.0/999,file:Mods/Void.SC2Mod</Value>
        <Value>file:Mods/crys_the_swarm_reborn.SC2Mod</Value>
        <Value>file:Mods/CovertOps.SC2Mod</Value>
        <Value>file:Mods/Umojan.SC2Mod</Value>
    </Dependencies>
</DocInfo>
'''

path = r'e:\Code\MyMod\SC2\合作指挥官-起义狂潮\Maps\abathur_test_map\DocumentInfo'
with open(path, 'wb') as f:
    f.write(b'\xef\xbb\xbf')  # UTF-8 BOM
    f.write(content.encode('utf-8'))

print('DocumentInfo saved with UTF-8 BOM')

# Verify
with open(path, 'rb') as f:
    data = f.read()
print('First bytes:', data[:10].hex())
print('Content decoded:')
print(data.decode('utf-8-sig'))
