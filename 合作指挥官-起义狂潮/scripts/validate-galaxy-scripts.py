#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Galaxy 脚本静态分析工具
用于在进图测试前快速检查常见的脚本错误

检查项：
1. UTF-8 BOM 检查（会导致库初始化失败）
2. 括号匹配检查（{} () []）
3. 禁用的原生函数调用检查（不存在的函数）
4. include 文件存在性检查（忽略游戏内置库）
5. 跨库引用一致性检查（仅检查 libE0EAE146_ 前缀）
"""

import os
import re
import sys
from pathlib import Path
from collections import defaultdict

ROOT = Path(r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data")

DISABLED_NATIVE_FUNCTIONS = {
    "UnitIsHero",
    "UnitIsStructure",
}

BUILT_IN_INCLUDE_PREFIXES = (
    "TriggerLibs/",
    "triggerlibs/",
)

CHECK_CROSS_REF_PREFIXES = ("libE0EAE146_",)

AUTO_GEN_TRIGGER_PATTERNS = (
    re.compile(r'_Trigger$'),
    re.compile(r'_TriggerFunc$'),
    re.compile(r'_lp_'),
)


def check_bom(filepath):
    with open(filepath, 'rb') as f:
        header = f.read(3)
    return header == b'\xef\xbb\xbf'


def read_file(filepath):
    with open(filepath, 'rb') as f:
        raw = f.read()
    if raw.startswith(b'\xef\xbb\xbf'):
        raw = raw[3:]
    return raw.decode('utf-8', errors='replace')


def check_brace_matching(content):
    issues = []
    lines = content.split('\n')
    stack = []
    brace_pairs = {')': '(', '}': '{', ']': '['}

    for line_num, line in enumerate(lines, 1):
        in_string = False
        in_line_comment = False
        in_block_comment = False
        string_char = None
        i = 0
        while i < len(line):
            ch = line[i]
            if in_line_comment:
                break
            if in_block_comment:
                if ch == '*' and i + 1 < len(line) and line[i+1] == '/':
                    in_block_comment = False
                    i += 2
                    continue
                i += 1
                continue
            if in_string:
                if ch == '\\' and i + 1 < len(line):
                    i += 2
                    continue
                if ch == string_char:
                    in_string = False
                i += 1
                continue
            if ch == '/' and i + 1 < len(line):
                if line[i+1] == '/':
                    in_line_comment = True
                    break
                if line[i+1] == '*':
                    in_block_comment = True
                    i += 2
                    continue
            if ch in ('"', "'"):
                in_string = True
                string_char = ch
                i += 1
                continue
            if ch in '({[':
                stack.append((ch, line_num, i))
            elif ch in ')}]':
                if not stack:
                    issues.append(f"  第 {line_num} 行第 {i+1} 列: 多余的 '{ch}'")
                else:
                    expected_open = brace_pairs[ch]
                    open_ch, open_line, open_col = stack.pop()
                    if open_ch != expected_open:
                        issues.append(
                            f"  第 {line_num} 行第 {i+1} 列: '{ch}' 与第 {open_line} 行的 '{open_ch}' 不匹配"
                        )
            i += 1

    for open_ch, line_num, col in stack:
        issues.append(f"  第 {line_num} 行第 {col+1} 列: 未闭合的 '{open_ch}'")

    return issues


def find_includes(content):
    includes = []
    for match in re.finditer(r'^\s*include\s+"([^"]+)"', content, re.MULTILINE):
        includes.append(match.group(1))
    return includes


def find_function_definitions(content):
    funcs = {}
    pattern = re.compile(
        r'^\s*(?:native\s+)?'
        r'(void|int|bool|unit|point|string|real|fixed|wave|group|'
        r'region|location|timer|trigger|bank|text|unitfilter|unitgroup|'
        r'playergroup|actor|sound|effect|behavior|abilcmd|order|pathing|'
        r'doodad|camera|quest|dialog|image|movie|model|footprint|object|'
        r'transmissionsource|transmission|planet|conversation|'
        r'accomplishment|score|airgroup|groundgroup|anygroup)\s+'
        r'([a-zA-Z_][a-zA-Z0-9_]*)\s*\(',
        re.MULTILINE
    )
    for match in pattern.finditer(content):
        func_name = match.group(2)
        line_num = content[:match.start()].count('\n') + 1
        if func_name not in funcs:
            funcs[func_name] = line_num
    return funcs


def find_variable_declarations(content):
    vars_dict = {}
    pattern = re.compile(
        r'^\s*(?:const\s+)?'
        r'(?:[a-zA-Z_][a-zA-Z0-9_]*(?:\[[^\]]*\])*\s+)+'
        r'([a-zA-Z_][a-zA-Z0-9_]*)\s*[;=]',
        re.MULTILINE
    )
    for match in pattern.finditer(content):
        var_name = match.group(1)
        line_num = content[:match.start()].count('\n') + 1
        if var_name not in vars_dict:
            vars_dict[var_name] = line_num
    return vars_dict


def find_trigger_declarations(content):
    triggers = {}
    pattern = re.compile(r'^\s*trigger\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*;', re.MULTILINE)
    for match in pattern.finditer(content):
        trig_name = match.group(1)
        line_num = content[:match.start()].count('\n') + 1
        triggers[trig_name] = line_num
    return triggers


def check_disabled_native_functions(content):
    issues = []
    lines = content.split('\n')
    for line_num, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith('//'):
            continue
        for func_name in DISABLED_NATIVE_FUNCTIONS:
            if re.search(r'(?<![a-zA-Z0-9_])' + re.escape(func_name) + r'\s*\(', line):
                issues.append(f"  第 {line_num} 行: 调用了不存在的原生函数 '{func_name}()'")
    return issues


def check_include_exists(includes, all_galaxy_files):
    issues = []
    for inc in includes:
        if inc.startswith(BUILT_IN_INCLUDE_PREFIXES):
            continue
        inc_filename = inc if inc.endswith('.galaxy') else inc + '.galaxy'
        found = False
        for gf in all_galaxy_files:
            gf_norm = gf.replace('\\', '/')
            if gf_norm.endswith('/' + inc_filename) or gf.endswith(inc_filename):
                found = True
                break
        if not found:
            base_name = os.path.basename(inc_filename)
            for gf in all_galaxy_files:
                if os.path.basename(gf) == base_name:
                    found = True
                    break
        if not found:
            issues.append(f"  include \"{inc}\" - 未找到对应文件")
    return issues


def collect_all_symbols(all_galaxy_files):
    all_funcs = {}
    all_vars = {}
    all_triggers = {}

    for gf in all_galaxy_files:
        content = read_file(gf)
        funcs = find_function_definitions(content)
        for fname, fline in funcs.items():
            all_funcs[fname] = (gf, fline)
        vars_dict = find_variable_declarations(content)
        for vname, vline in vars_dict.items():
            all_vars[vname] = (gf, vline)
        triggers = find_trigger_declarations(content)
        for tname, tline in triggers.items():
            all_triggers[tname] = (gf, tline)

    return all_funcs, all_vars, all_triggers


def is_auto_gen_trigger_var(symbol):
    for pat in AUTO_GEN_TRIGGER_PATTERNS:
        if pat.search(symbol):
            return True
    return False


def check_cross_library_refs(content, filepath, all_funcs, all_vars, all_triggers):
    issues = []
    lines = content.split('\n')
    lib_pattern = re.compile(r'(lib[a-zA-Z0-9_]+_[a-zA-Z0-9_]+)')
    checked_symbols = set()

    for line_num, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith('//'):
            continue

        for match in lib_pattern.finditer(line):
            symbol = match.group(1)
            if symbol in checked_symbols:
                continue
            checked_symbols.add(symbol)

            has_target_prefix = any(symbol.startswith(p) for p in CHECK_CROSS_REF_PREFIXES)
            if not has_target_prefix:
                continue

            if is_auto_gen_trigger_var(symbol):
                continue

            is_func = re.search(re.escape(symbol) + r'\s*\(', line) is not None

            if is_func:
                if symbol not in all_funcs:
                    issues.append(
                        f"  第 {line_num} 行: 函数 '{symbol}()' 未在任何库中找到定义"
                    )
            else:
                if symbol not in all_vars and symbol not in all_triggers:
                    issues.append(
                        f"  第 {line_num} 行: 变量/触发器 '{symbol}' 未在任何库中找到定义"
                    )

    return issues


def main():
    if len(sys.argv) > 1:
        target = sys.argv[1]
        if os.path.isfile(target):
            files_to_check = [target]
        elif os.path.isdir(target):
            files_to_check = sorted(str(p) for p in Path(target).rglob("Lib*.galaxy"))
        else:
            print(f"错误: 路径不存在: {target}")
            sys.exit(1)
    else:
        files_to_check = sorted(str(p) for p in ROOT.rglob("Lib*.galaxy"))

    print("=" * 70)
    print("Galaxy 脚本静态分析")
    print("=" * 70)
    print(f"检查文件数: {len(files_to_check)}")
    print()

    all_issues = defaultdict(list)
    all_funcs, all_vars, all_triggers = collect_all_symbols(files_to_check)
    total_issues = 0

    for filepath in files_to_check:
        basename = os.path.basename(filepath)
        content = read_file(filepath)
        file_issues = []

        if check_bom(filepath):
            file_issues.append("  [严重] 文件包含 UTF-8 BOM（会导致库初始化失败）")

        brace_issues = check_brace_matching(content)
        if brace_issues:
            file_issues.append("  [严重] 括号不匹配:")
            file_issues.extend(brace_issues[:10])

        disabled_issues = check_disabled_native_functions(content)
        if disabled_issues:
            file_issues.append("  [严重] 禁用原生函数调用:")
            file_issues.extend(disabled_issues)

        includes = find_includes(content)
        include_issues = check_include_exists(includes, files_to_check)
        if include_issues:
            file_issues.append("  [警告] include 文件未找到:")
            file_issues.extend(include_issues)

        cross_issues = check_cross_library_refs(
            content, filepath, all_funcs, all_vars, all_triggers
        )
        if cross_issues:
            file_issues.append("  [警告] 跨库引用未找到定义 (libE0EAE146_):")
            file_issues.extend(cross_issues[:20])

        if file_issues:
            all_issues[filepath] = file_issues
            total_issues += sum(
                1 for x in file_issues if not x.startswith("  [") and x.startswith("  ")
            )

    if not all_issues:
        print("所有文件通过静态检查，未发现明显问题！")
        print()
        print("提示：静态检查只能发现部分明显错误，")
        print("      建议使用快速编译验证做进一步检查。")
        return

    severe_count = 0
    warn_count = 0
    for filepath, issues in all_issues.items():
        for issue in issues:
            if '[严重]' in issue:
                severe_count += 1
            elif '[警告]' in issue:
                warn_count += 1

    print(f"发现问题，分布在 {len(all_issues)} 个文件中：")
    print(f"  严重问题: {severe_count} 项")
    print(f"  警告: {warn_count} 项")
    print()

    for filepath, issues in sorted(all_issues.items()):
        basename = os.path.basename(filepath)
        print(f"【{basename}】")
        for issue in issues:
            print(issue)
        print()

    print("=" * 70)
    print(f"总计: {len(all_issues)} 个文件有问题")
    print("=" * 70)
    print()
    print("提示：静态检查只能发现部分明显错误，")
    print("      建议使用快速编译验证做进一步检查。")

    sys.exit(1 if severe_count > 0 else 0)


if __name__ == "__main__":
    main()
