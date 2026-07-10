import { describe, it, expect } from 'vitest';
import { check } from '../src/index.js';
import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

describe('check API', () => {
  it('检查 continue 不报错', () => {
    const tmp = join(tmpdir(), `test-${Date.now()}.galaxy`);
    writeFileSync(tmp, 'void f() { while(true) { continue; } }', 'utf-8');
    const result = check(tmp);
    expect(result.summary.errors).toBe(0);
  });

  it('识别官方 TriggerLib 声音包装函数并校验参数数量', () => {
    const ok = join(tmpdir(), `sound-ok-${Date.now()}.galaxy`);
    writeFileSync(ok, [
      'void f(soundlink s, playergroup g, point p) {',
      '  SoundPlay(s, g, 100.0, 0.0);',
      '  SoundPlayAtPoint(s, g, p, 0.0, 100.0, 0.0);',
      '}',
    ].join('\n'), 'utf-8');
    const okResult = check(ok);
    expect(okResult.issues.find(i => i.ruleCode === 'SEM_UNDECLARED_FUNCTION')).toBeUndefined();
    expect(okResult.issues.find(i => i.ruleCode === 'SEM_ARGUMENT_COUNT_MISMATCH')).toBeUndefined();

    const bad = join(tmpdir(), `sound-bad-${Date.now()}.galaxy`);
    writeFileSync(bad, 'void f(soundlink s, playergroup g) { SoundPlay(s, g, 100.0); }', 'utf-8');
    const badResult = check(bad);
    expect(badResult.issues.find(i => i.ruleCode === 'SEM_ARGUMENT_COUNT_MISMATCH')).toBeDefined();
  });

  it('检查干净文件无报错', () => {
    const tmp = join(tmpdir(), `clean-${Date.now()}.galaxy`);
    writeFileSync(tmp, 'void f() { return; }', 'utf-8');
    const result = check(tmp);
    expect(result.summary.errors).toBe(0);
  });

  it('symbolRoots 让子 Mod 继承父 Mod 的函数和变量符号', () => {
    const root = join(tmpdir(), `symbol-roots-${Date.now()}`);
    const parent = join(root, 'parent');
    const child = join(root, 'child');
    mkdirSync(parent, { recursive: true });
    mkdirSync(child, { recursive: true });
    writeFileSync(
      join(parent, 'LibParent.galaxy'),
      'const int libSame_gv_MAX = 15; void libSame_gf_Parent() {}',
      'utf-8'
    );
    writeFileSync(
      join(child, 'LibChild.galaxy'),
      [
        'int[libSame_gv_MAX + 1] libSame_gv_values;',
        'void libSame_gf_Child() { libSame_gf_Parent(); }',
      ].join('\n'),
      'utf-8'
    );

    const isolated = check(child);
    expect(isolated.issues.find(i => i.ruleCode === 'SEM_UNDECLARED_VARIABLE')).toBeDefined();
    expect(isolated.issues.find(i => i.ruleCode === 'XLIB_UNDEFINED_CROSS_REF')).toBeDefined();

    const inherited = check(child, { symbolRoots: [parent] });
    expect(inherited.issues.find(i => i.ruleCode === 'SEM_UNDECLARED_VARIABLE')).toBeUndefined();
    expect(inherited.issues.find(i => i.ruleCode === 'XLIB_UNDEFINED_CROSS_REF')).toBeUndefined();
  });

  it('检查 BOM 文件报错', () => {
    const tmp = join(tmpdir(), `bom-${Date.now()}.galaxy`);
    const bom = Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), Buffer.from('void f() {}', 'utf-8')]);
    writeFileSync(tmp, bom);
    const result = check(tmp);
    expect(result.issues.find(i => i.ruleCode === 'PROJ_UTF8_BOM')).toBeDefined();
  });
});
