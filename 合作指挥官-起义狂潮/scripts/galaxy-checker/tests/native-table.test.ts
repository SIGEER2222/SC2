import { describe, it, expect } from 'vitest';
import { NativeFunctionTable } from '../src/analyzer/NativeFunctionTable.js';

describe('NativeFunctionTable', () => {
  it('从内联字符串解析 native 声明', () => {
    const table = new NativeFunctionTable();
    table.loadFromString(`
      native void UnitCreate(int count, string type, int player, point p);
      native bool UnitIsAlive(unit u);
    `);
    expect(table.lookup('UnitCreate')?.params).toHaveLength(4);
    expect(table.lookup('UnitIsAlive')?.returnType).toBe('bool');
  });

  it('加载黑名单', () => {
    const table = new NativeFunctionTable();
    expect(table.isDisallowed('UnitIsHero')).toBe(true);
    expect(table.isDisallowed('UnitIsAlive')).toBe(false);
  });

  it('UnitCreate 在黑名单中（项目规则禁用直接调用）', () => {
    const table = new NativeFunctionTable();
    expect(table.isDisallowed('UnitCreate')).toBe(true);
  });

  it('获取黑名单备注', () => {
    const table = new NativeFunctionTable();
    expect(table.getNote('UnitCreate')).toContain('libNtve_gf_CreateUnitsAtPoint2');
  });
});
