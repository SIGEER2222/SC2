import re

path = r'e:\Code\MyMod\SC2\合作指挥官-起义狂潮\Maps\abathur_test_map\DocumentHeader'
with open(path, 'rb') as f:
    data = f.read()

text = data.decode('utf-8', errors='ignore')
# Find all non-null terminated strings starting with file: or bnet:
matches = re.findall(r'[a-z_]+:[^\x00]+', text)
for m in matches:
    print(repr(m))
print()
print('=== Raw bytes around dependencies (last 600 bytes) ===')
# Look for the dependency table
dep_section = data[-2000:]
# Print all printable strings
strings = re.findall(rb'[\x20-\x7e\xe0-\xef][\x20-\x7e\x80-\xbf]{5,}', dep_section)
for s in strings:
    try:
        decoded = s.decode('utf-8')
        print(repr(decoded))
    except:
        pass
