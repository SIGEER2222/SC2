import { describe, it, expect } from 'vitest';
import { checkRules } from '../src/analyzer/RuleEngine.js';

describe('语法规则', () => {
  it('官方 Galaxy 支持 continue 语句', () => {
    const issues = checkRules('void f() { while(true) { continue; } }', 'test.galaxy');
    expect(issues.filter(i => i.severity === 'error')).toHaveLength(0);
  });

  it('break 语句不报错', () => {
    const issues = checkRules('void f() { while(true) { break; } }', 'test.galaxy');
    expect(issues.filter(i => i.severity === 'error')).toHaveLength(0);
  });

  it('官方 Galaxy 支持局部变量声明时初始化', () => {
    const issues = checkRules('void f() { point p = null; int x = 1; }', 'test.galaxy');
    expect(issues.filter(i => i.severity === 'error')).toHaveLength(0);
  });

  it('局部变量先声明再赋值也不报错', () => {
    const issues = checkRules('void f() { int x; x = 1; }', 'test.galaxy');
    expect(issues.filter(i => i.severity === 'error')).toHaveLength(0);
  });

  it('全局变量初始化不报错', () => {
    const issues = checkRules('int gv_x = 1;', 'test.galaxy');
    expect(issues.filter(i => i.severity === 'error')).toHaveLength(0);
  });
});
