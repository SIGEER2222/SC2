import { describe, it, expect } from 'vitest';
import { checkRules } from '../src/analyzer/RuleEngine.js';

describe('语法规则', () => {
  it('SYNTAX_NO_CONTINUE：检测 continue 语句', () => {
    const issues = checkRules('void f() { while(true) { continue; } }', 'test.galaxy');
    const cont = issues.find(i => i.ruleCode === 'SYNTAX_NO_CONTINUE');
    expect(cont).toBeDefined();
    expect(cont?.severity).toBe('error');
    expect(cont?.line).toBeGreaterThanOrEqual(0);
  });

  it('SYNTAX_NO_CONTINUE：无 continue 时不报', () => {
    const issues = checkRules('void f() { while(true) { break; } }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SYNTAX_NO_CONTINUE')).toBeUndefined();
  });

  it('SYNTAX_NO_LOCAL_INIT_ASSIGN：检测局部变量 = 初始化', () => {
    const issues = checkRules('void f() { int x = 1; }', 'test.galaxy');
    const init = issues.find(i => i.ruleCode === 'SYNTAX_NO_LOCAL_INIT_ASSIGN');
    expect(init).toBeDefined();
  });

  it('SYNTAX_NO_LOCAL_INIT_ASSIGN：仅声明不报', () => {
    const issues = checkRules('void f() { int x; x = 1; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SYNTAX_NO_LOCAL_INIT_ASSIGN')).toBeUndefined();
  });

  it('SYNTAX_NO_LOCAL_INIT_ASSIGN：全局变量初始化不报', () => {
    const issues = checkRules('int gv_x = 1;', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SYNTAX_NO_LOCAL_INIT_ASSIGN')).toBeUndefined();
  });
});
