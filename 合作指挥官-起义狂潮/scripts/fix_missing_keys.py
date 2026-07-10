"""
自动修复 zhCN 本地化文件中缺失或为空的 key，从 enUS 复制值。

安全策略：只修复以下类型的条目：
  - Param/Value: Galaxy 编辑器生成的格式化文本（跨语言通用）
  - Param/Expression: Galaxy 编辑器生成的表达式（跨语言通用）
  - DocInfo/DescLong: 地图描述（可留空，不修复）
  
用法:
  python fix_missing_keys.py --dry-run   # 预览将要修复的内容
  python fix_missing_keys.py             # 执行修复
"""
import sys
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parent.parent

# 要修复的 key 前缀
FIXABLE_PREFIXES = ['Param/Value/', 'Param/Expression/']


def load_locale_keys(filepath):
    keys = {}
    try:
        with open(filepath, 'r', encoding='utf-8-sig') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('//') or '=' not in line:
                    continue
                key, _, value = line.partition('=')
                keys[key.strip()] = value.strip()
    except Exception:
        pass
    return keys


def find_empty_zhcn_pairs(base_dir):
    """找到所有需要修复的 zhCN 文件"""
    pairs = []
    targets = [base_dir / 'Mods' / '7vs1', base_dir / 'XM', base_dir / 'Maps']
    for target in targets:
        if not target.exists():
            continue
        for f in target.rglob('GameStrings.txt'):
            if f.is_dir():
                continue
            parts = f.parts
            try:
                idx = parts.index(target.name)
            except ValueError:
                continue
            rel_parts = parts[idx + 1:]
            if len(rel_parts) < 4:
                continue
            locale_dir = rel_parts[1]
            if 'zhCN' not in locale_dir:
                continue
            file_name = rel_parts[-1]
            mod_dir = f.parents[len(rel_parts) - 2]
            zhcn_path = str(f)

            # 找 enUS 参考
            for ref_loc in ['enUS.SC2Data', 'zhTW.SC2Data']:
                candidate = mod_dir / ref_loc / 'LocalizedData' / file_name
                if candidate.exists():
                    pairs.append({
                        'zhcn_path': zhcn_path,
                        'ref_path': str(candidate),
                        'ref_locale': ref_loc,
                    })
                    break
    return pairs


def main():
    dry_run = '--dry-run' in sys.argv
    base_dir = ROOT
    pairs = find_empty_zhcn_pairs(base_dir)

    fixed_count = 0
    fixed_files = set()

    for pair in pairs:
        zhcn = load_locale_keys(pair['zhcn_path'])
        ref = load_locale_keys(pair['ref_path'])

        # 找到 zhCN 中为空但 enUS 中有的 Param/Value 和 Param/Expression
        to_fix = {}
        for key, zhcn_val in zhcn.items():
            if not zhcn_val:  # 空值
                is_fixable = any(key.startswith(p) for p in FIXABLE_PREFIXES)
                if is_fixable and key in ref and ref[key]:
                    to_fix[key] = ref[key]

        if not to_fix:
            continue

        print(f'{pair["zhcn_path"]}: {len(to_fix)} keys to fix')
        for key, val in sorted(to_fix.items()):
            print(f'  {key} = {val[:80]}')

        if not dry_run:
            # 修复文件
            with open(pair['zhcn_path'], 'r', encoding='utf-8-sig') as f:
                lines = f.readlines()

            with open(pair['zhcn_path'], 'w', encoding='utf-8-sig') as f:
                for line in lines:
                    stripped = line.strip()
                    if stripped and not stripped.startswith('//') and '=' in stripped:
                        key = stripped.split('=', 1)[0].strip()
                        if key in to_fix:
                            f.write(f'{key}={to_fix[key]}\n')
                            fixed_count += 1
                            continue
                    f.write(line)

            fixed_files.add(pair['zhcn_path'])

    print(f'\n总计: {fixed_count} 个 key 已修复 ({len(fixed_files)} 个文件)')

    if dry_run:
        print('(dry-run 模式，未实际修改文件。去掉 --dry-run 执行修复)')


if __name__ == '__main__':
    main()