import { describe, it, expect } from 'vitest';
import { check } from '../src/index.js';
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

describe('check API', () => {
  it('检查 continue 报错', () => {
    const tmp = join(tmpdir(), `test-${Date.now()}.galaxy`);
    writeFileSync(tmp, 'void f() { while(true) { continue; } }', 'utf-8');
    const result = check(tmp);
    expect(result.issues.find(i => i.ruleCode === 'SYNTAX_NO_CONTINUE')).toBeDefined();
    expect(result.summary.errors).toBeGreaterThan(0);
  });

  it('检查干净文件无报错', () => {
    const tmp = join(tmpdir(), `clean-${Date.now()}.galaxy`);
    writeFileSync(tmp, 'void f() { return; }', 'utf-8');
    const result = check(tmp);
    expect(result.summary.errors).toBe(0);
  });

  it('检查 BOM 文件报错', () => {
    const tmp = join(tmpdir(), `bom-${Date.now()}.galaxy`);
    const bom = Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), Buffer.from('void f() {}', 'utf-8')]);
    writeFileSync(tmp, bom);
    const result = check(tmp);
    expect(result.issues.find(i => i.ruleCode === 'PROJ_UTF8_BOM')).toBeDefined();
  });
});
