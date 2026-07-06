import sys

path = sys.argv[1]
data = open(path, 'rb').read()
print(f'length: {len(data)}')
print('hex:')
for i in range(0, len(data), 16):
    chunk = data[i:i+16]
    hex_str = chunk.hex(' ')
    ascii_str = ''.join(chr(c) if 32 <= c < 127 else '.' for c in chunk)
    print(f'{i:04x}: {hex_str:<48}  {ascii_str}')
