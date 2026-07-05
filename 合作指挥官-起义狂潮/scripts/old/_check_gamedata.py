import os

game_data_dir = r'e:\Code\MyMod\SC2\合作指挥官-起义狂潮\Maps\abathur_test_map\Base.SC2Data\GameData'
for name in sorted(os.listdir(game_data_dir)):
    path = os.path.join(game_data_dir, name)
    if os.path.isfile(path):
        size = os.path.getsize(path)
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        # Count non-whitespace chars
        stripped = content.strip()
        print(f'{name}: {size} bytes, {len(stripped)} chars content')
