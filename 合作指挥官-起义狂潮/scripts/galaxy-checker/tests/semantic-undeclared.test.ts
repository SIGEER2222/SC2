import { describe, it, expect } from 'vitest';
import { analyze } from '../src/analyzer/SemanticAnalyzer.js';

describe('SemanticAnalyzer - 未声明检查', () => {
  it('SEM_UNDECLARED_VARIABLE：引用未声明变量', () => {
    const issues = analyze('void f() { x = 1; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_UNDECLARED_VARIABLE')).toBeDefined();
  });

  it('SEM_UNDECLARED_VARIABLE：已声明变量不报', () => {
    const issues = analyze('void f() { int x; x = 1; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_UNDECLARED_VARIABLE')).toBeUndefined();
  });

  it('SEM_UNDECLARED_FUNCTION：调用未声明函数', () => {
    const issues = analyze('void f() { undefinedFunc(); }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_UNDECLARED_FUNCTION')).toBeDefined();
  });

  it('SEM_UNDECLARED_FUNCTION：已声明函数不报', () => {
    const issues = analyze('void foo() {} void bar() { foo(); }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_UNDECLARED_FUNCTION')).toBeUndefined();
  });

  it('全局变量在函数内可见', () => {
    const issues = analyze('int gv_x; void f() { gv_x = 1; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_UNDECLARED_VARIABLE')).toBeUndefined();
  });

  it('函数参数在函数体可见', () => {
    const issues = analyze('void f(int p) { p = 1; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_UNDECLARED_VARIABLE')).toBeUndefined();
  });

  it('SEM_VOID_IN_CONDITION：void 函数用在 if 条件', () => {
    const issues = analyze('void doSomething() {} void f() { if (doSomething()) {} }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_VOID_IN_CONDITION')).toBeDefined();
  });

  it('SEM_VOID_IN_CONDITION：bool 函数用在 if 条件不报', () => {
    const issues = analyze('bool check() { return true; } void f() { if (check()) {} }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_VOID_IN_CONDITION')).toBeUndefined();
  });
});
