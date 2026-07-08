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

  it('解析 for 循环 - 表达式 init（Galaxy 编译器生成形式）', () => {
    // 循环变量先声明，for 的 init 用赋值表达式（Galaxy 禁止局部变量 = 初始化）
    const result = parse('void f() { int i; for (i = 1; i <= 8; i += 1) { } }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析 for 循环 - 空 init', () => {
    const result = parse('void f() { int i; i = 0; for (; i < 10; i = i + 1) { } }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析 for 循环 - 全空 for(;;)', () => {
    const result = parse('void f() { for (;;) { break; } }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析 for 循环 - 复合赋值更新', () => {
    const result = parse('void f() { int i; for (i = 0; i < 100; i += 1) { } }');
    expect(result.errors).toHaveLength(0);
  });

  it('函数体内的行注释不导致崩溃', () => {
    const result = parse('void f() { // comment\n return; }');
    expect(result.errors).toHaveLength(0);
  });

  it('函数体内的块注释不导致崩溃', () => {
    const result = parse('void f() { /* block comment */ return; }');
    expect(result.errors).toHaveLength(0);
  });

  it('行注释穿插在语句间不导致崩溃', () => {
    const result = parse('void f() {\n  int x; // declare x\n  x = 1; // assign\n}');
    expect(result.errors).toHaveLength(0);
  });

  it('顶层行注释不导致崩溃', () => {
    const result = parse('// top level comment\nint x = 0;');
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

  it('解析位运算或 |', () => {
    // 真实 Galaxy：c_placementTestPowerMask | c_placementTestFogMask | ...
    const result = parse('void f() { int x = c_placementTestPowerMask | c_placementTestFogMask | c_placementTestZoneMask; }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析位运算与 &', () => {
    const result = parse('void f() { int x = a & b & c; }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析位运算异或 ^', () => {
    const result = parse('void f() { int x = a ^ b; }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析函数参数中的位运算链（真实崩溃场景）', () => {
    const result = parse('void f() { UnitSetPosition(EventUnit(), UnitTypePlacementTestsFromPoint(UnitGetType(EventUnit()), EventPlayer(), PlayerStartLocation(EventPlayer()), 5.0, c_placementTestPowerMask | c_placementTestFogMask | c_placementTestZoneMask | c_placementTestCliffMask | c_placementTestDensityMask), false); }');
    expect(result.errors).toHaveLength(0);
  });

  it('位运算与逻辑运算混合优先级', () => {
    // a | b && c -> C 优先级: (a | b) && c（| 高于 &&）
    const result = parse('void f() { bool x = a | b && c; }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析三元表达式', () => {
    const result = parse('int f() { return x > 0 ? 1 : 0; }');
    expect(result.errors).toHaveLength(0);
  });
});
