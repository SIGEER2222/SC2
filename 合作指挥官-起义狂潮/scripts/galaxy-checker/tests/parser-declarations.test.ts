import { describe, it, expect } from 'vitest';
import { parse } from '../src/parser/index.js';

describe('Parser - 基础声明', () => {
  it('解析 include 指令', () => {
    const result = parse('include "TriggerLibs/NativeLib.galaxy";');
    expect(result.errors).toHaveLength(0);
    expect(result.ast.body[0]).toMatchObject({
      type: 'Include',
      path: 'TriggerLibs/NativeLib.galaxy',
    });
  });

  it('解析 include 指令（不带分号，Galaxy 真实代码形式）', () => {
    // Galaxy 真实代码 include 不带分号：`include "TriggerLibs/NativeLib"`
    const result = parse('include "TriggerLibs/NativeLib"');
    expect(result.errors).toHaveLength(0);
    expect(result.ast.body[0]).toMatchObject({
      type: 'Include',
      path: 'TriggerLibs/NativeLib',
    });
  });

  it('解析无参函数', () => {
    const result = parse('void foo() {}');
    expect(result.errors).toHaveLength(0);
    expect(result.ast.body[0]).toMatchObject({
      type: 'FunctionDeclaration',
      returnType: 'void',
      name: 'foo',
      isNative: false,
    });
  });

  it('解析带参数函数', () => {
    const result = parse('int add(int a, int b) { return a + b; }');
    expect(result.errors).toHaveLength(0);
    const fn = result.ast.body[0] as any;
    expect(fn.params).toEqual([
      { type: 'int', name: 'a' },
      { type: 'int', name: 'b' },
    ]);
  });

  it('解析 native 函数声明', () => {
    const result = parse('native void UnitCreate(int count, string type);');
    expect(result.errors).toHaveLength(0);
    expect(result.ast.body[0]).toMatchObject({
      type: 'FunctionDeclaration',
      isNative: true,
      body: null,
    });
  });

  it('解析函数原型/forward declaration（无 body，分号结尾）', () => {
    // Galaxy 头文件（*_h.galaxy）大量使用函数原型声明函数签名
    const result = parse('void lib0940FFB7_gf_NovaCaster();');
    expect(result.errors).toHaveLength(0);
    expect(result.ast.body[0]).toMatchObject({
      type: 'FunctionDeclaration',
      isNative: false,
      body: null,
      name: 'lib0940FFB7_gf_NovaCaster',
    });
  });

  it('解析带参数的函数原型', () => {
    const result = parse('int libFoo_gf_Bar(int a, string b);');
    expect(result.errors).toHaveLength(0);
    const fn = result.ast.body[0] as any;
    expect(fn.body).toBeNull();
    expect(fn.isNative).toBe(false);
    expect(fn.params).toEqual([
      { type: 'int', name: 'a' },
      { type: 'string', name: 'b' },
    ]);
  });

  it('解析全局变量声明', () => {
    const result = parse('int gv_counter;');
    expect(result.errors).toHaveLength(0);
    expect(result.ast.body[0]).toMatchObject({
      type: 'VariableDeclaration',
      varType: 'int',
      name: 'gv_counter',
      init: null,
    });
  });

  it('解析 const 变量', () => {
    const result = parse('const int MAX = 100;');
    expect(result.errors).toHaveLength(0);
    expect(result.ast.body[0]).toMatchObject({
      type: 'VariableDeclaration',
      isConst: true,
      name: 'MAX',
    });
  });

  it('解析数组变量', () => {
    const result = parse('int[10] gv_array;');
    expect(result.errors).toHaveLength(0);
    expect(result.ast.body[0]).toMatchObject({
      type: 'VariableDeclaration',
      isArray: true,
      name: 'gv_array',
    });
  });

  it('解析数组变量（维度用 Identifier 常量引用）', () => {
    // Galaxy 真实代码用常量引用作数组维度：`int[MAXPLAYERS] gv_players;`
    const result = parse('int[libKCOR_gv_cCC_MAXPLAYERS] gv_players;');
    expect(result.errors).toHaveLength(0);
    expect(result.ast.body[0]).toMatchObject({
      type: 'VariableDeclaration',
      isArray: true,
      name: 'gv_players',
    });
    const declaration = result.ast.body[0] as any;
    expect(declaration.arrayDimensions).toHaveLength(1);
    expect(declaration.arrayDimensions[0]).toMatchObject({
      type: 'Identifier',
      name: 'libKCOR_gv_cCC_MAXPLAYERS',
    });
  });

  it('保留多维数组的全部维度表达式', () => {
    const result = parse('unit[4][gv_MAX + 1] gv_units;');
    expect(result.errors).toHaveLength(0);
    const declaration = result.ast.body[0] as any;
    expect(declaration.arrayDimensions).toHaveLength(2);
    expect(declaration.arrayDimensions[0]).toMatchObject({ type: 'Literal', value: 4 });
    expect(declaration.arrayDimensions[1]).toMatchObject({ type: 'BinaryExpression', operator: '+' });
  });
});
