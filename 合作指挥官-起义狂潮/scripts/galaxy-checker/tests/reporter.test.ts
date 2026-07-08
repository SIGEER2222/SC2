import { describe, it, expect } from 'vitest';
import { IssueReporter } from '../src/reporter/IssueReporter.js';
import type { Issue } from '../src/types.js';

describe('IssueReporter', () => {
  const sampleIssues: Issue[] = [
    {
      file: 'a.galaxy',
      line: 10,
      column: 5,
      ruleCode: 'SYNTAX_NO_CONTINUE',
      severity: 'error',
      message: 'continue 不允许',
    },
    {
      file: 'b.galaxy',
      line: 1,
      column: 1,
      ruleCode: 'PROJ_UTF8_BOM',
      severity: 'error',
      message: 'BOM',
    },
  ];

  it('JSON 格式输出包含 summary', () => {
    const reporter = new IssueReporter('json');
    const out = JSON.parse(reporter.report(sampleIssues, 2));
    expect(out.summary.errors).toBe(2);
    expect(out.issues).toHaveLength(2);
    expect(out.tool).toBe('galaxy-checker');
  });

  it('文本格式包含 ERROR 标签', () => {
    const reporter = new IssueReporter('text');
    const out = reporter.report(sampleIssues, 2);
    expect(out).toContain('[ERROR]');
    expect(out).toContain('SYNTAX_NO_CONTINUE');
    expect(out).toContain('总计');
  });

  it('无 issue 时 JSON 输出 errors=0', () => {
    const reporter = new IssueReporter('json');
    const out = JSON.parse(reporter.report([], 0));
    expect(out.summary.errors).toBe(0);
    expect(out.issues).toHaveLength(0);
  });
});
