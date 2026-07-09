import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { analyze } from '../src/analyzer/SemanticAnalyzer.js';
import { checkRules } from '../src/analyzer/RuleEngine.js';

const FIXTURES_DIR = join(dirname(fileURLToPath(import.meta.url)), 'fixtures', 'regression');

describe('回归测试夹具', () => {
  const files = readdirSync(FIXTURES_DIR).filter(f => f.endsWith('.galaxy'));

  for (const file of files) {
    it(`fixture: ${file}`, () => {
      const src = readFileSync(join(FIXTURES_DIR, file), 'utf-8');
      const expected = JSON.parse(
        readFileSync(join(FIXTURES_DIR, file.replace('.galaxy', '.expected.json')), 'utf-8')
      );

      // 语法层 + 语义层，与 check() 的检查路径一致
      const issues = [...checkRules(src, file), ...analyze(src, file)];
      const actualRules = issues.map(i => i.ruleCode);

      // 期望每个规则都触发
      for (const rule of expected.rules) {
        expect(actualRules, `${file} 应触发 ${rule}`).toContain(rule);
      }

      // clean fixture：无任何 error
      if (expected.rules.length === 0) {
        expect(issues.filter(i => i.severity === 'error'), `${file} 应无 error`).toHaveLength(0);
      }
    });
  }
});
