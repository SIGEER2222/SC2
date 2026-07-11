// src/reporter/IssueReporter.ts
import type { Issue, CheckResult } from '../types.js';

export type ReportFormat = 'json' | 'text';

export class IssueReporter {
  constructor(private format: ReportFormat = 'json') {}

  report(issues: Issue[], filesChecked: number): string {
    const result = this.buildResult(issues, filesChecked);
    return this.formatResult(result);
  }

  /**
   * 格式化完整 CheckResult（含 compositionId/contextLoaded 等扩展字段）。
   */
  reportResult(result: CheckResult): string {
    return this.formatResult(result);
  }

  private formatResult(result: CheckResult): string {
    if (this.format === 'json') {
      const output: Record<string, unknown> = {
        version: '1.1',
        tool: 'galaxy-checker',
        filesChecked: result.filesChecked,
        summary: result.summary,
        issues: result.issues,
      };
      // 工程化扩展字段（仅当存在时输出）
      if (result.compositionId) output.compositionId = result.compositionId;
      if (result.contextLoaded !== undefined) output.contextLoaded = result.contextLoaded;
      return JSON.stringify(output, null, 2);
    }
    return this.formatText(result);
  }

  buildResult(issues: Issue[], filesChecked: number): CheckResult {
    const summary = {
      errors: issues.filter(i => i.severity === 'error').length,
      warnings: issues.filter(i => i.severity === 'warning').length,
      infos: issues.filter(i => i.severity === 'info').length,
    };
    return { filesChecked, issues, summary };
  }

  private formatText(result: CheckResult): string {
    const lines: string[] = [];
    for (const issue of result.issues) {
      const tag = issue.severity === 'error' ? 'ERROR'
        : issue.severity === 'warning' ? 'WARN'
        : 'INFO';
      lines.push(
        `[${tag}] ${issue.file}:${issue.line}:${issue.column}  ${issue.ruleCode}`
      );
      lines.push(`        ${issue.message}`);
      lines.push('');
    }
    lines.push(
      `总计: ${result.summary.errors} 错误, ${result.summary.warnings} 警告`
    );
    return lines.join('\n');
  }
}
