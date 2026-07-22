import { describe, it, expect } from 'vitest';
import { analyze } from '../src/analyzer/SemanticAnalyzer.js';
import { SymbolTable } from '../src/analyzer/SymbolTable.js';

describe('SemanticAnalyzer - 重复声明', () => {
  it('同作用域变量重复声明报错', () => {
    const issues = analyze('void f() { int x; int x; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_DUPLICATE_DECLARATION')).toBeDefined();
  });

  it('全局变量重复声明报错', () => {
    const issues = analyze('int gv_x; int gv_x;', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_DUPLICATE_DECLARATION')).toBeDefined();
  });

  it('函数重复定义报错', () => {
    const issues = analyze('void foo() {} void foo() {}', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_DUPLICATE_DECLARATION')).toBeDefined();
  });

  it('不同作用域同名变量不报', () => {
    const issues = analyze('void f() { int x; { int x; } }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_DUPLICATE_DECLARATION')).toBeUndefined();
  });

  it('目录模式：同文件二次扫描不报（sourceFile 相同）', () => {
    const globalTable = new SymbolTable();
    // 模拟 ProjectLoader 扫描本文件时记录的 sourceFile
    globalTable.declareGlobalVariable('int', 'gv_x', false, undefined, '/proj/t.galaxy');
    globalTable.declareFunction({ name: 'foo', returnType: 'void', params: [], isNative: false }, undefined, '/proj/t.galaxy');

    const issues = analyze('int gv_x; void foo() {}', 't.galaxy', globalTable, undefined, undefined, undefined, undefined, '/proj/t.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_DUPLICATE_DECLARATION')).toBeUndefined();
  });

  it('目录模式：跨文件变量声明冲突报错（sourceFile 不同）', () => {
    const globalTable = new SymbolTable();
    // 模拟 _h.galaxy 中已声明该全局变量
    globalTable.declareGlobalVariable('bool', 'libCOMU_gv_cT_MAbomination_MutatorsEnhanced', true, undefined, '/proj/LibCOMU_h.galaxy');

    // 当前分析的是 cmui_customization.galaxy，其中重复声明了同一变量
    const issues = analyze(
      'bool libCOMU_gv_cT_MAbomination_MutatorsEnhanced;',
      'cmui_customization.galaxy',
      globalTable,
      undefined, undefined, undefined, undefined,
      '/proj/scripts/cmui_customization.galaxy'
    );
    const dup = issues.find(i => i.ruleCode === 'SEM_DUPLICATE_DECLARATION');
    expect(dup).toBeDefined();
    expect(dup!.message).toContain('LibCOMU_h.galaxy');
    expect(dup!.message).toContain('跨文件重复声明');
  });

  it('目录模式：跨文件函数声明冲突报错（sourceFile 不同）', () => {
    const globalTable = new SymbolTable();
    globalTable.declareFunction(
      { name: 'libCOMU_gf_CT_DisableMutatorVariant', returnType: 'void', params: [{ type: 'string', name: 'lp_mutator' }], isNative: false },
      undefined,
      '/proj/LibCOMU_h.galaxy'
    );

    const issues = analyze(
      'void libCOMU_gf_CT_DisableMutatorVariant(string lp_mutator) {}',
      'cmui_customization.galaxy',
      globalTable,
      undefined, undefined, undefined, undefined,
      '/proj/scripts/cmui_customization.galaxy'
    );
    const dup = issues.find(i => i.ruleCode === 'SEM_DUPLICATE_DECLARATION');
    expect(dup).toBeDefined();
    expect(dup!.message).toContain('跨文件重复声明');
  });

  it('目录模式：旧式 API（无 sourceFile）不报，保持向后兼容', () => {
    const globalTable = new SymbolTable();
    // 不传 sourceFile（旧式 API）
    globalTable.declareGlobalVariable('int', 'gv_x');
    globalTable.declareFunction({ name: 'foo', returnType: 'void', params: [], isNative: false });

    const issues = analyze('int gv_x; void foo() {}', 't.galaxy', globalTable);
    expect(issues.find(i => i.ruleCode === 'SEM_DUPLICATE_DECLARATION')).toBeUndefined();
  });
});
