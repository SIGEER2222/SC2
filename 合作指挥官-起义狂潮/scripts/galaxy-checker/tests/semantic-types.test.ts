import { describe, it, expect } from 'vitest';
import { analyze } from '../src/analyzer/SemanticAnalyzer.js';
import { NativeFunctionTable } from '../src/analyzer/NativeFunctionTable.js';

describe('SemanticAnalyzer - 类型检查', () => {
  it('返回 int 函数 return 字符串报 warning', () => {
    const issues = analyze('int f() { return "x"; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_RETURN_TYPE_MISMATCH')).toBeDefined();
  });

  it('返回 int 函数 return 整数不报', () => {
    const issues = analyze('int f() { return 1; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_RETURN_TYPE_MISMATCH')).toBeUndefined();
  });

  it('int 变量赋字符串报 warning', () => {
    const issues = analyze('void f() { int x; x = "y"; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_ASSIGNMENT_TYPE_MISMATCH')).toBeDefined();
  });
});

describe('SemanticAnalyzer - text 类型拼接检测', () => {
  // 加载含 StringToText/IntToText 的 native 表
  const natives = new NativeFunctionTable({ version: '1.0', disallowedNatives: [] });
  natives.loadFromString(`
    native text StringToText(string s);
    native text IntToText(int x);
    native string IntToString(int x);
    native void TriggerDebugOutput(int type, text inText, bool includeGameUI);
    native void UnitSetInfoText(unit inUnit, text info, text tip, text subTip);
  `);

  it('StringToText() + IntToText() 报 SEM_INVALID_TEXT_CONCAT', () => {
    const issues = analyze(
      'void f() { text t; t = StringToText("a") + IntToText(1); }',
      'test.galaxy', undefined, natives
    );
    const hit = issues.find(i => i.ruleCode === 'SEM_INVALID_TEXT_CONCAT');
    expect(hit).toBeDefined();
    expect(hit?.severity).toBe('error');
    // BinaryExpression 现已附加 start（取运算符 token 位置），行号应非 0
    expect(hit?.line).toBeGreaterThan(0);
  });

  it('"str" + StringToText("x") 报 SEM_INVALID_TEXT_CONCAT', () => {
    const issues = analyze(
      'void f() { text t; t = "abc" + StringToText("x"); }',
      'test.galaxy', undefined, natives
    );
    expect(issues.find(i => i.ruleCode === 'SEM_INVALID_TEXT_CONCAT')).toBeDefined();
  });

  it('StringToText(str + IntToString(i)) 不报 text 拼接错误（正确写法）', () => {
    const issues = analyze(
      'void f() { text t; t = StringToText("abc" + IntToString(1)); }',
      'test.galaxy', undefined, natives
    );
    expect(issues.find(i => i.ruleCode === 'SEM_INVALID_TEXT_CONCAT')).toBeUndefined();
  });

  it('string + string 不报 text 拼接错误', () => {
    const issues = analyze(
      'void f() { string s; s = "a" + "b"; }',
      'test.galaxy', undefined, natives
    );
    expect(issues.find(i => i.ruleCode === 'SEM_INVALID_TEXT_CONCAT')).toBeUndefined();
  });

  it('int + int 不报 text 拼接错误', () => {
    const issues = analyze(
      'void f() { int x; x = 1 + 2; }',
      'test.galaxy', undefined, natives
    );
    expect(issues.find(i => i.ruleCode === 'SEM_INVALID_TEXT_CONCAT')).toBeUndefined();
  });
});
