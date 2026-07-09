import { describe, it, expect } from 'vitest';
import { parse } from '../src/parser/index.js';

// 真实项目文件（编辑器导出 + 手写）暴露出的语法形态，防回归
describe('Parser - 真实项目语法', () => {
  it('行注释与块注释不产生 parse error', () => {
    const result = parse('// 注释\nvoid f() { /* 块 */ return; }');
    expect(result.errors).toHaveLength(0);
  });

  it('非 native 函数前置声明（头文件 prototype）', () => {
    const result = parse('void foo ();\nvoid bar (int lp_player);');
    expect(result.errors).toHaveLength(0);
    expect(result.ast.body).toHaveLength(2);
    expect(result.ast.body[0]).toMatchObject({ type: 'FunctionDeclaration', body: null });
  });

  it('include 无分号（编辑器导出格式）', () => {
    const result = parse('include "TriggerLibs/NativeLib"\ninclude "Lib67C0F0E7"\nvoid f() {}');
    expect(result.errors).toHaveLength(0);
  });

  it('do-while 语句', () => {
    const result = parse('void f() { do { g(); } while (x > 0); } void g() {}');
    expect(result.errors).toHaveLength(0);
  });

  it('位运算与移位表达式', () => {
    const result = parse('void f() { x = (1 << a) | (1 << b); y = m & (~n); z = p ^ q; }');
    expect(result.errors).toHaveLength(0);
  });

  it('复合赋值 |= 与 &=', () => {
    const result = parse('void f() { x |= (1 << i); x &= (~(1 << i)); }');
    expect(result.errors).toHaveLength(0);
  });

  it('十六进制整数字面量', () => {
    const result = parse('int gv_mask = 0x1F;');
    expect(result.errors).toHaveLength(0);
  });

  it('数组维度为常量表达式', () => {
    const result = parse('unit[gv_MAXPLAYERS + 1] gv_casters;');
    expect(result.errors).toHaveLength(0);
    expect(result.ast.body[0]).toMatchObject({ type: 'VariableDeclaration', isArray: true });
  });

  it('多维数组声明', () => {
    const result = parse('fixed[gv_COUNT + 1][gv_MAX + 1] gv_timers;');
    expect(result.errors).toHaveLength(0);
  });

  it('for 空 init（`for ( ; cond ; update)`）', () => {
    const result = parse('void f() { int lv_i; for ( ; lv_i >= 2 ; lv_i -= 1 ) { g(); } } void g() {}');
    expect(result.errors).toHaveLength(0);
  });

  it('for init 为赋值表达式', () => {
    const result = parse('void f() { int i; for (i = 0; i < 10; i += 1) { } }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析失败时降级为空 Program 而非返回 undefined', () => {
    const result = parse('void 123 !!!');
    expect(result.ast).toBeDefined();
    expect(Array.isArray(result.ast.body)).toBe(true);
    expect(result.errors.length).toBeGreaterThan(0);
  });
});
