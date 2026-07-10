"""
扫描缺失的 zhCN 本地化文本 key。

策略：对比 zhCN 和其他语言（enUS/zhTW）的 GameStrings/ObjectStrings/TriggerStrings，
找出 zhCN 中缺失或为空的 key。

用法:
  python scan_missing_text_keys.py              # 扫描所有文件
  python scan_missing_text_keys.py --summary     # 只显示摘要
  python scan_missing_text_keys.py --missing-only # 只显示缺失的 key
  python scan_missing_text_keys.py --empty-only   # 只显示值为空的 key
"""
import re
import sys
import json
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parent.parent


def load_locale_keys(filepath):
    """加载本地化文件中的 key -> value 映射"""
    keys = {}
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('//') or '=' not in line:
                    continue
                key, _, value = line.partition('=')
                keys[key.strip()] = value.strip()
    except Exception:
        pass
    return keys


def find_locale_pairs(base_dir):
    """找到所有 mod/地图的 zhCN 和参考语言文件对"""
    pairs = []
    targets = [base_dir / 'Mods' / '7vs1', base_dir / 'XM', base_dir / 'Maps']
    for target in targets:
        if not target.exists():
            continue
        for f in target.rglob('GameStrings.txt'):
            if f.is_dir():
                continue
            parts = f.parts
            # 找到相对于 target 的路径
            try:
                idx = parts.index(target.name)
            except ValueError:
                continue
            rel_parts = parts[idx+1:]  # 如 ('Alenger13.SC2Mod', 'zhCN.SC2Data', 'LocalizedData', 'GameStrings.txt')
            if len(rel_parts) < 4:
                continue
            mod_name = rel_parts[0]
            locale_dir = rel_parts[1]  # e.g. 'zhCN.SC2Data'
            if 'zhCN' not in locale_dir:
                continue
            file_name = rel_parts[-1]
            zhcn_path = str(f)

            # 找参考语言（enUS 优先，没有则 zhTW）
            mod_dir = f.parents[len(rel_parts) - 2]  # e.g. Alenger13.SC2Mod
            ref_path = None
            ref_locale = None
            for ref_loc in ['enUS.SC2Data', 'zhTW.SC2Data']:
                candidate = mod_dir / ref_loc / 'LocalizedData' / file_name
                if candidate.exists():
                    ref_path = str(candidate)
                    ref_locale = ref_loc
                    break
            if ref_path:
                pairs.append({
                    'mod': mod_name,
                    'file': file_name,
                    'zhcn': str(zhcn_path),
                    'ref': ref_path,
                    'ref_locale': ref_locale,
                })
    return pairs


def main():
    args = set(sys.argv[1:])
    summary_only = '--summary' in args
    missing_only = '--missing-only' in args
    empty_only = '--empty-only' in args

    base_dir = ROOT
    pairs = find_locale_pairs(base_dir)

    all_missing = []  # zhCN 中完全缺失的 key
    all_empty = []    # zhCN 中存在但值为空的 key

    total_zhcn = 0
    total_ref = 0

    for pair in pairs:
        zhcn = load_locale_keys(pair['zhcn'])
        ref = load_locale_keys(pair['ref'])
        total_zhcn += len(zhcn)
        total_ref += len(ref)

        # 找 zhCN 中缺失的 key
        for key, value in sorted(ref.items()):
            if key not in zhcn:
                all_missing.append({
                    'mod': pair['mod'],
                    'file': pair['file'],
                    'key': key,
                    'ref_value': value,
                    'ref_locale': pair['ref_locale'],
                    'zhcn_path': pair['zhcn'],
                })

        # 找 zhCN 中值为空的 key
        for key, value in sorted(zhcn.items()):
            if not value:
                all_empty.append({
                    'mod': pair['mod'],
                    'file': pair['file'],
                    'key': key,
                    'zhcn_path': pair['zhcn'],
                })

    print(f'zhCN 总 key 数: {total_zhcn}')
    print(f'参考语言总 key 数: {total_ref}')
    print(f'zhCN 缺失 key: {len(all_missing)}')
    print(f'zhCN 空值 key: {len(all_empty)}')
    print()

    if summary_only:
        # 按 mod 统计
        by_mod = defaultdict(lambda: {'missing': 0, 'empty': 0})
        for m in all_missing:
            by_mod[m['mod']]['missing'] += 1
        for e in all_empty:
            by_mod[e['mod']]['empty'] += 1
        print('按 Mod 统计:')
        for mod, stats in sorted(by_mod.items(), key=lambda x: -(x[1]['missing'] + x[1]['empty'])):
            print(f'  {mod}: 缺失{stats["missing"]}, 空值{stats["empty"]}')
        return

    issues = []
    if empty_only:
        issues = all_empty
    elif missing_only:
        issues = all_missing
    else:
        issues = all_missing + all_empty

    for item in issues:
        if 'ref_value' in item:
            print(f'[缺失] {item["mod"]} ({item["file"]})')
            print(f'  {item["key"]} = {item["ref_value"][:80]}')
        else:
            print(f'[空值] {item["mod"]} ({item["file"]})')
            print(f'  {item["key"]} = (空)')
        print()

    # 保存结果
    out = ROOT / 'scripts' / 'scan_missing_keys_result.json'
    with open(out, 'w', encoding='utf-8') as f:
        json.dump({'missing': all_missing, 'empty': all_empty}, f, ensure_ascii=False, indent=2)
    print(f'详细结果: {out}')


if __name__ == '__main__':
    main()