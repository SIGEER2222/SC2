import { describe, it, expect } from 'vitest';
import { analyze } from '../src/analyzer/SemanticAnalyzer.js';
import { NativeFunctionTable } from '../src/analyzer/NativeFunctionTable.js';
import { SymbolTable } from '../src/analyzer/SymbolTable.js';

// 针对真实项目扫描暴露的误报场景，防回归
describe('SemanticAnalyzer - 真实项目误报修复', () => {
  it('已知 native 不报未声明，参数数量错误时报 mismatch', () => {
    const natives = new NativeFunctionTable({ version: '1.0', disallowedNatives: [] });
    natives.loadFromString('native void Wait(fixed lp_1, int lp_2);');

    const ok = analyze('void f() { Wait(1.0, 1); }', 't.galaxy', undefined, natives);
    expect(ok.find(i => i.ruleCode === 'SEM_UNDECLARED_FUNCTION')).toBeUndefined();
    expect(ok.find(i => i.ruleCode === 'SEM_ARGUMENT_COUNT_MISMATCH')).toBeUndefined();

    const bad = analyze('void f() { Wait(1.0); }', 't.galaxy', undefined, natives);
    expect(bad.find(i => i.ruleCode === 'SEM_ARGUMENT_COUNT_MISMATCH')).toBeDefined();
  });

  it('目录模式下外部库引用（前缀不在本地符号表）不报错', () => {
    const globalTable = new SymbolTable();
    globalTable.declareFunction({ name: 'libKMIS_gf_Foo', returnType: 'void', params: [], isNative: false });

    const issues = analyze('void f() { libNtve_gf_CreateUnitsWithDefaultFacing(1, "X", 0, 1, null); }',
      't.galaxy', globalTable);
    expect(issues.find(i => i.ruleCode === 'XLIB_UNDEFINED_CROSS_REF')).toBeUndefined();
    expect(issues.find(i => i.ruleCode === 'SEM_UNDECLARED_FUNCTION')).toBeUndefined();
  });

  it('目录模式下本地库前缀缺失符号仍报 XLIB_UNDEFINED_CROSS_REF', () => {
    const globalTable = new SymbolTable();
    globalTable.declareFunction({ name: 'libKMIS_gf_Foo', returnType: 'void', params: [], isNative: false });

    const issues = analyze('void f() { libKMIS_gf_NotExist(); }', 't.galaxy', globalTable);
    expect(issues.find(i => i.ruleCode === 'XLIB_UNDEFINED_CROSS_REF')).toBeDefined();
  });

  it('单文件模式下未知 lib 前缀仍报（保持旧行为）', () => {
    const issues = analyze('void f() { libNonExistent_gf_foo(); }', 't.galaxy');
    expect(issues.find(i => i.ruleCode === 'XLIB_UNDEFINED_CROSS_REF')).toBeDefined();
  });

  it('游戏常量 c_* 不报未声明变量', () => {
    const issues = analyze('void f() { int x; x = c_timeGame; }', 't.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_UNDECLARED_VARIABLE')).toBeUndefined();
  });

  it('目录模式下本文件顶层符号不误报重复定义', () => {
    const globalTable = new SymbolTable();
    // 模拟 ProjectLoader 已收集过本文件符号
    globalTable.declareFunction({ name: 'foo', returnType: 'void', params: [], isNative: false });
    globalTable.declareGlobalVariable('int', 'gv_x');

    const issues = analyze('int gv_x; void foo() {}', 't.galaxy', globalTable);
    expect(issues.find(i => i.ruleCode === 'SEM_DUPLICATE_DECLARATION')).toBeUndefined();
  });

  it('int 赋给 fixed 不报类型不匹配（Galaxy 隐式提升）', () => {
    const issues = analyze('void f() { fixed lv_a; lv_a = 1; }', 't.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_ASSIGNMENT_TYPE_MISMATCH')).toBeUndefined();
  });

  it('fixed 赋给 int 仍报类型不匹配', () => {
    const issues = analyze('void f() { int lv_a; lv_a = 1.5; }', 't.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_ASSIGNMENT_TYPE_MISMATCH')).toBeDefined();
  });

  it('语义 issue 携带行号（非 0）', () => {
    const issues = analyze('void f() {\n    undeclared_x = 1;\n}', 't.galaxy');
    const issue = issues.find(i => i.ruleCode === 'SEM_UNDECLARED_VARIABLE');
    expect(issue).toBeDefined();
    expect(issue!.line).toBe(2);
  });
});
