/**
 * Issue 报告器 —— 输出结构与 galaxy-checker 对齐：
 *   JSON: { version, tool, filesChecked, summary, issues }
 *   text: [ERROR] file:line:col  RULE_CODE\n        message
 */
export function buildResult(issues, filesChecked) {
  return {
    filesChecked,
    issues,
    summary: {
      errors: issues.filter(i => i.severity === 'error').length,
      warnings: issues.filter(i => i.severity === 'warning').length,
      infos: issues.filter(i => i.severity === 'info').length,
    },
  };
}

export function report(issues, filesChecked, format = 'json', extra = {}) {
  const result = buildResult(issues, filesChecked);
  if (format === 'json') {
    return JSON.stringify({
      version: '1.0',
      tool: 'sc2-editor-toolkit',
      filesChecked: result.filesChecked,
      summary: result.summary,
      ...extra,
      issues: result.issues,
    }, null, 2);
  }
  const lines = [];
  for (const issue of result.issues) {
    const tag = issue.severity === 'error' ? 'ERROR'
      : issue.severity === 'warning' ? 'WARN'
      : 'INFO';
    lines.push(`[${tag}] ${issue.file}:${issue.line}:${issue.column}  ${issue.ruleCode}`);
    lines.push(`        ${issue.message}`);
    lines.push('');
  }
  lines.push(`总计: ${result.summary.errors} 错误, ${result.summary.warnings} 警告, ${result.summary.infos} 提示`);
  if (extra.stats) {
    const s = extra.stats;
    lines.push(`条目: 合并后 ${s.entries} 个（校验 ${s.entriesChecked} 个），检查引用 ${s.refsChecked} 处，dangling ${s.dangling} 处`);
  }
  return lines.join('\n');
}
