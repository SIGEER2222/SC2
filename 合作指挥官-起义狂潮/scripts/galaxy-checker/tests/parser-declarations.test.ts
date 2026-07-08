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
});
