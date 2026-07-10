"""
扫描未翻译的本地化文本。

用法:
  python scan_english_text.py              # 扫描所有文件
  python scan_english_text.py --player-only  # 只显示玩家可见文本
  python scan_english_text.py --summary      # 只显示摘要
  python scan_english_text.py --fix-report   # 输出需要修复的清单

只检查 zhCN 本地化文件中的英文未翻译 value。
"""
import os
import re
import json
import sys
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parent.parent

# 含英文字母且不含中文
EN_RE = re.compile(r'[a-zA-Z]{3,}')
ZH_RE = re.compile(r'[\u4e00-\u9fff]')

# XML 标签：按钮 tooltip 中的资源图标等
XML_RE = re.compile(r'<\s*(s\s+val|IMG\s+path|d\s+ref|c\s+val)', re.IGNORECASE)

# 纯代码标识符（camelCase/PascalCase/underscore，无空格，3+ 字母）
CODE_ID_RE = re.compile(r'^[a-zA-Z_][a-zA-Z0-9_]*$')

# 玩家可见的 key 类型前缀
PLAYER_VISIBLE_TYPES = {
    'Button/Name', 'Button/Tooltip', 'Button/Hotkey', 'Button/SimpleDisplayText',
    'Unit/Name', 'Unit/Description', 'Unit/Subtitle', 'Unit/InfoText',
    'Abil/Name', 'Abil/Description', 'Abil/Tooltip', 'Abil/SimpleDisplayText',
    'Upgrade/Name', 'Upgrade/Description', 'Upgrade/Tooltip',
    'Behavior/Name', 'Behavior/Description', 'Behavior/Tooltip',
    'Weapon/Name', 'Weapon/Tooltip', 'Weapon/Tip',
    'Map/Name', 'Map/Description', 'Map/LoadingTitle', 'Map/LoadingHelp',
    'Map/PrimaryObjectiveText', 'Map/SecondaryObjectiveText',
    'DocInfo/Name', 'DocInfo/DescShort', 'DocInfo/DescLong',
    'Commander/Name', 'Commander/Description',
    'Race/Name',
    'Location/Name',
    'UI/',  # UI 相关
}

# 编辑器内部 key 类型（不需要翻译）
EDITOR_INTERNAL_TYPES = {
    'Variable/Name', 'Variable/Type', 'Variable/',
    'Trigger/Name', 'Trigger/Description',
    'FunctionDef/Name', 'FunctionDef/',
    'ParamDef/Name', 'ParamDef/',
    'Library/Name', 'Library/',
    'Preset/Name', 'Preset/',
    'StructDef/Name',
    'Category/Name',
    'Element/Name',
}

def is_english_value(value):
    v = value.strip()
    if not v or ZH_RE.search(v) or not EN_RE.search(v):
        return False
    # 跳过 XML 标记
    if XML_RE.search(v):
        return False
    return True

def is_player_visible(key):
    for prefix in PLAYER_VISIBLE_TYPES:
        if key.startswith(prefix):
            return True
    return False

def is_editor_internal(key):
    for prefix in EDITOR_INTERNAL_TYPES:
        if key.startswith(prefix):
            return True
    return False

def classify_key(key):
    """分类 key 类型"""
    if is_player_visible(key):
        return 'player'
    if is_editor_internal(key):
        return 'editor'
    return 'other'

def scan_loc_file(filepath):
    issues = []
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception:
        return issues

    for lineno, line in enumerate(lines, 1):
        line = line.rstrip()
        if not line or line.startswith('//') or '=' not in line:
            continue
        key, _, value = line.partition('=')
        key = key.strip()
        value = value.strip()
        if is_english_value(value):
            cls = classify_key(key)
            issues.append({'line': lineno, 'key': key, 'value': value, 'class': cls})
    return issues

def main():
    args = set(sys.argv[1:])
    player_only = '--player-only' in args
    summary_only = '--summary' in args
    fix_report = '--fix-report' in args

    all_issues = []
    for target in [ROOT / 'Mods' / '7vs1', ROOT / 'XM', ROOT / 'Maps']:
        if not target.exists():
            continue
        for f in target.rglob('*'):
            if f.is_dir() or f.name not in ('GameStrings.txt', 'ObjectStrings.txt', 'TriggerStrings.txt'):
                continue
            has_zhcn = any('zhCN' in p or 'zhcn' in p.lower() for p in f.parts)
            if not has_zhcn:
                continue
            issues = scan_loc_file(f)
            if issues:
                rel = str(f.relative_to(ROOT))
                all_issues.append({'file': rel, 'issues': issues})

    # 统计
    total = sum(len(i['issues']) for i in all_issues)
    player_issues = sum(sum(1 for iss in i['issues'] if iss['class'] == 'player') for i in all_issues)
    editor_issues = total - player_issues

    if summary_only:
        print(f'总计: {total} 条 ({len(all_issues)} 文件)')
        print(f'  玩家可见: {player_issues} 条')
        print(f'  编辑器内部: {editor_issues} 条')
        print()

        # 按文件类型统计
        by_file_type = defaultdict(lambda: {'player': 0, 'editor': 0, 'other': 0, 'total': 0})
        for entry in all_issues:
            ft = entry['file'].split('\\')[-1]
            for iss in entry['issues']:
                by_file_type[ft][iss['class']] += 1
                by_file_type[ft]['total'] += 1

        print('按文件类型统计:')
        for ft in ['GameStrings.txt', 'ObjectStrings.txt', 'TriggerStrings.txt']:
            if ft in by_file_type:
                stats = by_file_type[ft]
                print(f'  {ft}: {stats["total"]}条 (玩家可见:{stats["player"]}, 编辑器:{stats["editor"]}, 其他:{stats["other"]})')
        return

    # 输出
    if player_only:
        all_issues = [entry for entry in all_issues
                      if any(iss['class'] == 'player' for iss in entry['issues'])]
        for entry in all_issues:
            entry['issues'] = [iss for iss in entry['issues'] if iss['class'] == 'player']

    print(f'=== 未翻译本地化文本：{sum(len(i["issues"]) for i in all_issues)} 条，{len(all_issues)} 个文件 ===\n')
    for entry in all_issues:
        print(f'\n--- {entry["file"]} ({len(entry["issues"])}条) ---')
        for iss in entry['issues']:
            tag = '[玩家]' if iss['class'] == 'player' else '[内部]'
            print(f'  {tag} L{iss["line"]:4d} | {iss["key"]} = {iss["value"]}')

    # 保存结果
    out = ROOT / 'scripts' / 'scan_english_text_result.json'
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(all_issues, f, ensure_ascii=False, indent=2)
    print(f'\n详细结果: {out}')

    # 修复报告
    if fix_report:
        fix_entries = [entry for entry in all_issues
                       if any(iss['class'] == 'player' for iss in entry['issues'])]
        print(f'\n=== 需要修复的文件 ({len(fix_entries)} 个) ===')
        for entry in fix_entries:
            player = [iss for iss in entry['issues'] if iss['class'] == 'player']
            print(f'\n{entry["file"]}:')
            for iss in player:
                print(f'  L{iss["line"]} | {iss["key"]}')
                print(f'       = {iss["value"]}')

    return total

if __name__ == '__main__':
    main()