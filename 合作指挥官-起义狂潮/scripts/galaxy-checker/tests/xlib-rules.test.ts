import { describe, it, expect } from 'vitest';
import { check } from '../src/index.js';
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

describe('跨库/Native 规则', () => {
  it('XLIB_DISALLOWED_NATIVE：不存在的伪 native 仍报 error', () => {
    const tmp = join(tmpdir(), `native-${Date.now()}.galaxy`);
    writeFileSync(tmp, 'void f() { UnitIsHero(1); }');
    const result = check(tmp);
    const issue = result.issues.find(i => i.ruleCode === 'XLIB_DISALLOWED_NATIVE');
    expect(issue).toBeDefined();
    expect(issue?.severity).toBe('error');
  });

  it('XLIB_DISCOURAGED_NATIVE：调用 UnitCreate 默认报 warning', () => {
    const tmp = join(tmpdir(), `uc-${Date.now()}.galaxy`);
    writeFileSync(tmp, 'void f() { UnitCreate(1, "Marine", 1, null); }');
    const result = check(tmp);
    const issue = result.issues.find(i => i.ruleCode === 'XLIB_DISCOURAGED_NATIVE');
    expect(issue).toBeDefined();
    expect(issue?.severity).toBe('warning');
    expect(result.summary.errors).toBe(0);
  });

  it('XLIB_UNDEFINED_CROSS_REF：引用未定义的 libXXX_ 符号', () => {
    const tmp = join(tmpdir(), `xlib-${Date.now()}.galaxy`);
    writeFileSync(tmp, 'void f() { libNonExistent_gf_foo(); }');
    const result = check(tmp);
    // 应该报 SEM_UNDECLARED_FUNCTION 或 XLIB_UNDEFINED_CROSS_REF
    const hasUndeclared = result.issues.some(
      i => i.ruleCode === 'SEM_UNDECLARED_FUNCTION' || i.ruleCode === 'XLIB_UNDEFINED_CROSS_REF'
    );
    expect(hasUndeclared).toBe(true);
  });

  it('XLIB_MISSING_INCLUDE：include 不存在文件', () => {
    const tmp = join(tmpdir(), `inc-${Date.now()}.galaxy`);
    writeFileSync(tmp, 'include "NonExistent.galaxy";');
    const result = check(tmp);
    expect(result.issues.find(i => i.ruleCode === 'XLIB_MISSING_INCLUDE')).toBeDefined();
  });
});
