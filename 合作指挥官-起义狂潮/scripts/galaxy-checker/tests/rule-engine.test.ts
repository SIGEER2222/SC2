import { describe, it, expect } from 'vitest';
import { RuleEngine } from '../src/analyzer/RuleEngine.js';

describe('RuleEngine', () => {
  it('加载默认规则文件', () => {
    const engine = new RuleEngine();
    expect(engine.getRule('SYNTAX_NO_CONTINUE')?.severity).toBe('error');
    expect(engine.getRule('PROJ_UTF8_BOM')?.severity).toBe('error');
  });

  it('禁用规则', () => {
    const engine = new RuleEngine({
      rules: { SYNTAX_NO_CONTINUE: { severity: 'off' } },
    });
    expect(engine.getRule('SYNTAX_NO_CONTINUE')?.severity).toBe('off');
  });

  it('获取所有启用的规则', () => {
    const engine = new RuleEngine();
    const enabled = engine.getEnabledRules();
    expect(enabled.find(r => r.code === 'SYNTAX_NO_CONTINUE')).toBeDefined();
  });

  it('未配置的规则默认 off', () => {
    const engine = new RuleEngine();
    expect(engine.getRule('UNKNOWN_RULE')?.severity).toBe('off');
  });
});
