import { describe, it, expect } from 'vitest';
import { analyze } from '../src/analyzer/SemanticAnalyzer.js';

describe('SemanticAnalyzer - 类型检查', () => {
  it('返回 int 函数 return 字符串报 warning', () => {
    const issues = analyze('int f() { return "x"; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_RETURN_TYPE_MISMATCH')).toBeDefined();
  });

  it('返回 int 函数 return 整数不报', () => {
    const issues = analyze('int f() { return 1; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_RETURN_TYPE_MISMATCH')).toBeUndefined();
  });

  it('int 变量赋字符串报 warning', () => {
    const issues = analyze('void f() { int x; x = "y"; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_ASSIGNMENT_TYPE_MISMATCH')).toBeDefined();
  });
});
