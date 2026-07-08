import { describe, it, expect } from 'vitest';
import { analyze } from '../src/analyzer/SemanticAnalyzer.js';

describe('SemanticAnalyzer - 函数参数数量检查 (SEM_ARGUMENT_COUNT_MISMATCH)', () => {
  it('参数太少：期望 2 个，实际传 1 个', () => {
    const issues = analyze('void f(int a, int b) {} void g() { f(1); }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_ARGUMENT_COUNT_MISMATCH')).toBeDefined();
  });

  it('参数太多：期望 1 个，实际传 2 个', () => {
    const issues = analyze('void f(int a) {} void g() { f(1, 2); }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_ARGUMENT_COUNT_MISMATCH')).toBeDefined();
  });

  it('参数数量正确：期望 2 个，实际传 2 个，不报', () => {
    const issues = analyze('void f(int a, int b) {} void g() { f(1, 2); }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_ARGUMENT_COUNT_MISMATCH')).toBeUndefined();
  });

  it('无参函数被传参：期望 0 个，实际传 1 个', () => {
    const issues = analyze('void f() {} void g() { f(1); }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_ARGUMENT_COUNT_MISMATCH')).toBeDefined();
  });
});
