import { describe, it, expect } from 'vitest';
import { GALAXY_TYPES } from '../src/types.js';
import type { Issue, Severity, CheckResult } from '../src/types.js';

describe('types', () => {
  it('Issue 接口可被构造', () => {
    const issue: Issue = {
      file: 'test.galaxy',
      line: 1,
      column: 1,
      ruleCode: 'SYNTAX_NO_CONTINUE',
      severity: 'error',
      message: 'continue 不允许',
    };
    expect(issue.ruleCode).toBe('SYNTAX_NO_CONTINUE');
  });

  it('CheckResult 接口可被构造', () => {
    const result: CheckResult = {
      filesChecked: 1,
      issues: [],
      summary: { errors: 0, warnings: 0, infos: 0 },
    };
    expect(result.summary.errors).toBe(0);
    // 确保 types 模块确实在运行时加载（避免 import type 被擦除导致测试空跑）
    expect(GALAXY_TYPES).toContain('int');
  });
});
