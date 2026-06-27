import re

file_path = r'E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\LibE0EAE146_ZeratulRuntime.galaxy'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()
    lines = content.split('\n')

print(f'文件总行数: {len(lines)}')
print()

# 收集所有以 libE0EAE146_ 开头的函数定义及其行号
func_defs = {}
for i, line in enumerate(lines):
    stripped = line.strip()
    # 匹配函数定义
    match = re.match(r'^(void|int|bool|unit|point|string|real|fixed|wave|group|region|location|timer|trigger|bank|text)\s+(libE0EAE146_\w+)\s*\(', stripped)
    if match and '{' in stripped:
        func_name = match.group(2)
        if func_name not in func_defs:
            func_defs[func_name] = i + 1

print(f'共找到 {len(func_defs)} 个 libE0EAE146_ 函数定义')
print()

# 专门检查 ZeratulRuntimeInit 调用的所有 _Init 函数
print('=' * 60)
print('ZeratulRuntimeInit 函数调用检查:')
print('=' * 60)

runtime_init_line = None
runtime_init_calls = []
in_runtime_init = False
brace_count = 0

for i, line in enumerate(lines):
    line_num = i + 1
    stripped = line.strip()
    
    if 'void libE0EAE146_gf_ZeratulRuntimeInit' in stripped:
        runtime_init_line = line_num
        in_runtime_init = True
        brace_count = stripped.count('{') - stripped.count('}')
        continue
    
    if in_runtime_init:
        brace_count += stripped.count('{') - stripped.count('}')
        # 查找 _Init 函数调用
        calls = re.findall(r'(libE0EAE146_\w+_Init)\s*\(', stripped)
        for called in calls:
            runtime_init_calls.append((called, line_num))
        if brace_count <= 0:
            in_runtime_init = False
            break

print(f'ZeratulRuntimeInit 定义在第 {runtime_init_line} 行')
print(f'共调用了 {len(runtime_init_calls)} 个 _Init 函数')
print()

problems = []
for called_func, call_line in runtime_init_calls:
    if called_func in func_defs:
        def_line = func_defs[called_func]
        if def_line > runtime_init_line:
            problems.append((called_func, call_line, def_line))
            print(f'  ✗ {called_func}')
            print(f'      调用于第 {call_line} 行，定义于第 {def_line} 行')
        else:
            print(f'  ✓ {called_func} (定义于第 {def_line} 行)')
    else:
        print(f'  ? {called_func} (未找到定义)')

print()
if problems:
    print(f'发现 {len(problems)} 个先调用后定义的问题')
else:
    print('✓ 所有 _Init 函数都在 ZeratulRuntimeInit 之前定义，没有问题！')

print()
print('=' * 60)
print('其他函数的初步检查（仅检查本文件内的 libE0EAE146_ 函数调用）:')
print('=' * 60)

# 检查所有函数
all_issues = []
current_func = None
current_func_line = 0
brace_count = 0
in_func = False

for i, line in enumerate(lines):
    line_num = i + 1
    stripped = line.strip()
    
    # 检查是否进入新函数
    func_match = re.match(r'^(void|int|bool|unit|point|string|real|fixed|wave|group|region|location|timer|trigger|bank|text)\s+(libE0EAE146_\w+)\s*\(', stripped)
    if func_match and '{' in stripped:
        current_func = func_match.group(2)
        current_func_line = line_num
        brace_count = stripped.count('{') - stripped.count('}')
        in_func = True
        continue
    
    if in_func:
        brace_count += stripped.count('{') - stripped.count('}')
        if brace_count <= 0:
            in_func = False
            current_func = None
            continue
    
    # 在函数体内查找函数调用
    if in_func and current_func:
        calls = re.findall(r'(libE0EAE146_\w+)\s*\(', stripped)
        for called_func in calls:
            if called_func in func_defs:
                def_line = func_defs[called_func]
                if def_line > current_func_line:
                    issue_key = (current_func, called_func)
                    if not any(x[0] == current_func and x[1] == called_func for x in all_issues):
                        all_issues.append((current_func, current_func_line, called_func, def_line, line_num))

if all_issues:
    print(f'发现 {len(all_issues)} 个潜在的先调用后定义问题:')
    print()
    for func, func_line, called, called_line, call_line in sorted(all_issues, key=lambda x: x[1]):
        print(f'  函数 \"{func}\" (第 {func_line} 行)')
        print(f'    调用 \"{called}\" 在第 {call_line} 行')
        print(f'    但 \"{called}\" 定义在第 {called_line} 行')
        print()
else:
    print('✓ 未发现其他明显的先调用后定义问题')

print()
print('注意：这只是简单的静态分析，可能存在误报或漏报。')
print('对于 Galaxy 脚本，关键是确保 Init 函数的调用顺序正确。')
