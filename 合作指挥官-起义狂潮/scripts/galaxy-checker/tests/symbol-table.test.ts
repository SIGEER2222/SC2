import { describe, it, expect } from 'vitest';
import { SymbolTable, Scope } from '../src/analyzer/SymbolTable.js';
import type { FunctionSignature } from '../src/types.js';

describe('SymbolTable', () => {
  it('根作用域声明与查询', () => {
    const root = new Scope(null);
    root.declareFunction({ name: 'foo', returnType: 'void', params: [], isNative: false });
    expect(root.lookupFunction('foo')?.name).toBe('foo');
  });

  it('嵌套作用域查找父作用域', () => {
    const root = new Scope(null);
    root.declareVariable('int', 'gv_x');
    const child = root.createChild();
    expect(child.lookupVariable('gv_x')?.name).toBe('gv_x');
  });

  it('同一作用域重复声明触发 onDuplicate 回调', () => {
    const root = new Scope(null);
    root.declareVariable('int', 'x');
    let called = false;
    root.declareVariable('int', 'x', false, () => { called = true; });
    expect(called).toBe(true);
  });

  it('子作用域可声明同名变量（遮蔽）', () => {
    const root = new Scope(null);
    root.declareVariable('int', 'x');
    const child = root.createChild();
    let called = false;
    child.declareVariable('int', 'x', false, () => { called = true; });
    expect(called).toBe(false);
  });

  it('SymbolTable 顶层提供函数表', () => {
    const st = new SymbolTable();
    st.declareFunction({ name: 'bar', returnType: 'int', params: [], isNative: false });
    expect(st.lookupFunction('bar')?.returnType).toBe('int');
  });
});
