import { describe, it, expect } from 'vitest';
import { parse } from '../src/parser/index.js';

describe('Parser - 控制流', () => {
  it('解析 break 语句', () => {
    const result = parse('void f() { while (true) { break; } }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析 continue 语句（不报错，由规则引擎检查）', () => {
    const result = parse('void f() { while (true) { continue; } }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析 if/else', () => {
    const result = parse('void f() { if (true) { return; } else { return; } }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析 for 循环', () => {
    const result = parse('void f() { for (int i = 0; i < 10; i = i + 1) { } }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析 return 带表达式', () => {
    const result = parse('int f() { return 42; }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析函数调用', () => {
    const result = parse('void f() { libNtve_gf_UnitIsHero(1); }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析成员访问', () => {
    const result = parse('void f() { a.b = 1; }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析数组下标', () => {
    const result = parse('void f() { a[0] = 1; }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析三元表达式', () => {
    const result = parse('int f() { return x > 0 ? 1 : 0; }');
    expect(result.errors).toHaveLength(0);
  });
});
