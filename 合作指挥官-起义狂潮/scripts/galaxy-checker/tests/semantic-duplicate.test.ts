import { describe, it, expect } from 'vitest';
import { analyze } from '../src/analyzer/SemanticAnalyzer.js';

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
});
