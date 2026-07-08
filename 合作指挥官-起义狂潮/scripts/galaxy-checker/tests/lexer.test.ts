import { describe, it, expect } from 'vitest';
import { tokenize } from '../src/lexer/tokens.js';

describe('Lexer', () => {
  it('识别关键字', () => {
    const tokens = tokenize('if else while for return break');
    expect(tokens.map(t => t.tokenType.name)).toEqual([
      'If', 'Else', 'While', 'For', 'Return', 'Break',
    ]);
  });

  it('识别类型关键字', () => {
    const tokens = tokenize('void int bool string');
    expect(tokens.map(t => t.tokenType.name)).toEqual([
      'Void', 'Int', 'Bool', 'String',
    ]);
  });

  it('识别标识符', () => {
    const tokens = tokenize('libNtve_gf_UnitIsHero foo_bar');
    expect(tokens.map(t => t.tokenType.name)).toEqual(['Identifier', 'Identifier']);
  });

  it('识别整数', () => {
    const tokens = tokenize('42 0');
    expect(tokens.map(t => t.tokenType.name)).toEqual(['Integer', 'Integer']);
  });

  it('识别固定点', () => {
    const tokens = tokenize('1.5f 3.14');
    expect(tokens.map(t => t.tokenType.name)).toEqual(['Fixed', 'Fixed']);
  });

  it('识别字符串', () => {
    const tokens = tokenize('"hello world"');
    expect(tokens[0].tokenType.name).toBe('String');
  });

  it('识别行注释', () => {
    const tokens = tokenize('int x; // 这是注释\nint y;');
    expect(tokens.find(t => t.tokenType.name === 'LineComment')).toBeDefined();
  });

  it('识别块注释', () => {
    const tokens = tokenize('/* 块注释 */ int x;');
    expect(tokens.find(t => t.tokenType.name === 'BlockComment')).toBeDefined();
  });

  it('识别运算符', () => {
    const tokens = tokenize('a == b && c != d');
    expect(tokens.map(t => t.tokenType.name)).toContain('EqualsEquals');
    expect(tokens.map(t => t.tokenType.name)).toContain('AmpersandAmpersand');
    expect(tokens.map(t => t.tokenType.name)).toContain('ExclamationEquals');
  });

  it('跳过空白', () => {
    const tokens = tokenize('  int\n\t x  ');
    expect(tokens[0].tokenType.name).toBe('Int');
  });
});
