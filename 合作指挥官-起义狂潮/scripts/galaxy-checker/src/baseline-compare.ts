// src/baseline-compare.ts
// 基线对比工具：检测当前扫描结果与基线相比的新增问题。
// 用法:
//   galaxy-checker-baseline <target> --baseline <baseline.json> [check 选项]
//   node dist/baseline-compare.mjs <target> --baseline <baseline.json>
import { readFileSync } from 'node:fs';
import { basename } from 'node:path';
import { check } from './index.js';
import type { Issue, CheckResult } from './types.js';

export interface BaselineEntry {
  file: string;
  line: number;
  ruleCode: string;
  message: string;
}

export interface CompareResult {
  newIssues: Issue[];
  resolvedIssues: BaselineEntry[];
  unchangedCount: number;
  baselineTotal: number;
  currentTotal: number;
  currentResult: CheckResult;
}

/**
 * 从 CheckResult 中提取可比较的 issue 标识。
 * 用 file+line+ruleCode 作为唯一标识（忽略 message 差异）。
 */
function toBaselineEntries(issues: Issue[]): BaselineEntry[] {
  return issues.map(i => ({
    file: i.file,
    line: i.line,
    ruleCode: i.ruleCode,
    message: i.message,
  }));
}

/**
 * 生成 issue 的唯一键（file:line:ruleCode）。
 */
function issueKey(entry: { file: string; line: number; ruleCode: string }): string {
  return `${entry.file}:${entry.line}:${entry.ruleCode}`;
}

/**
 * 对比当前扫描结果与基线，找出新增和已解决的问题。
 */
export function compareWithBaseline(
  currentResult: CheckResult,
  baselinePath: string
): CompareResult {
  // 读取基线
  const baselineRaw = JSON.parse(readFileSync(baselinePath, 'utf-8'));
  const baselineIssues: Issue[] = baselineRaw.issues ?? [];
  const baselineEntries = toBaselineEntries(baselineIssues);
  const baselineKeys = new Set(baselineIssues.map(issueKey));

  // 当前 issue
  const currentEntries = toBaselineEntries(currentResult.issues);
  const currentKeys = new Set(currentEntries.map(issueKey));

  // 新增 issue：在当前但不在基线中
  const newIssues = currentResult.issues.filter(
    i => !baselineKeys.has(issueKey(i))
  );

  // 已解决 issue：在基线但不在当前中
  const resolvedIssues = baselineEntries.filter(
    e => !currentKeys.has(issueKey(e))
  );

  // 未变化 issue
  const unchangedCount = currentResult.issues.length - newIssues.length;

  return {
    newIssues,
    resolvedIssues,
    unchangedCount,
    baselineTotal: baselineIssues.length,
    currentTotal: currentResult.issues.length,
    currentResult,
  };
}

/**
 * 格式化对比结果为文本报告。
 */
export function formatCompareReport(result: CompareResult): string {
  const lines: string[] = [];
  lines.push('=== 基线对比报告 ===');
  lines.push(`基线总数: ${result.baselineTotal}`);
  lines.push(`当前总数: ${result.currentTotal}`);
  lines.push(`新增问题: ${result.newIssues.length}`);
  lines.push(`已解决: ${result.resolvedIssues.length}`);
  lines.push(`未变化: ${result.unchangedCount}`);
  lines.push('');

  if (result.newIssues.length > 0) {
    lines.push('=== 新增问题（需关注）===');
    // 按规则分组
    const byRule = new Map<string, Issue[]>();
    for (const issue of result.newIssues) {
      const arr = byRule.get(issue.ruleCode) ?? [];
      arr.push(issue);
      byRule.set(issue.ruleCode, arr);
    }
    for (const [rule, issues] of byRule) {
      lines.push(`  [${rule}] × ${issues.length}`);
      for (const i of issues.slice(0, 10)) {
        lines.push(`    ${i.file}:${i.line} — ${i.message}`);
      }
      if (issues.length > 10) {
        lines.push(`    ... 还有 ${issues.length - 10} 个`);
      }
    }
    lines.push('');
  }

  if (result.resolvedIssues.length > 0) {
    lines.push('=== 已解决问题 ===');
    const byRule = new Map<string, BaselineEntry[]>();
    for (const entry of result.resolvedIssues) {
      const arr = byRule.get(entry.ruleCode) ?? [];
      arr.push(entry);
      byRule.set(entry.ruleCode, arr);
    }
    for (const [rule, entries] of byRule) {
      lines.push(`  [${rule}] × ${entries.length}`);
    }
    lines.push('');
  }

  // 退出码建议
  if (result.newIssues.length > 0) {
    lines.push('结论: 发现新增问题，建议修复后再提交。');
  } else {
    lines.push('结论: 无新增问题，通过基线检查。');
  }

  return lines.join('\n');
}

// CLI 入口
async function main() {
  const args = process.argv.slice(2);
  if (args.length === 0 || args.includes('--help')) {
    console.error(`用法: galaxy-checker-baseline <target> --baseline <baseline.json> [options]
选项:
  --baseline <path>       基线 JSON 文件路径（必须）
  --symbol-root <dir>     追加符号目录，可重复
  --composition-plan <p>  CompositionPlan.json 路径
  --json                  输出 JSON 格式（默认文本）
  --help                  显示帮助`);
    process.exit(2);
  }

  const target = args[0];
  const baselineIdx = args.indexOf('--baseline');
  if (baselineIdx < 0 || !args[baselineIdx + 1]) {
    console.error('错误: 必须指定 --baseline <path>');
    process.exit(2);
  }
  const baselinePath = args[baselineIdx + 1];

  const symbolRoots: string[] = [];
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--symbol-root' && args[i + 1]) {
      symbolRoots.push(args[i + 1]);
      i++;
    }
  }

  const compositionPlanIdx = args.indexOf('--composition-plan');
  const useJson = args.includes('--json');

  const result = check(target, {
    symbolRoots,
    compositionPlanPath: compositionPlanIdx >= 0 ? args[compositionPlanIdx + 1] : undefined,
  });

  const compareResult = compareWithBaseline(result, baselinePath);

  if (useJson) {
    console.log(JSON.stringify({
      baselineTotal: compareResult.baselineTotal,
      currentTotal: compareResult.currentTotal,
      newIssues: compareResult.newIssues.length,
      resolvedIssues: compareResult.resolvedIssues.length,
      unchangedCount: compareResult.unchangedCount,
      newIssueDetails: compareResult.newIssues,
    }, null, 2));
  } else {
    console.log(formatCompareReport(compareResult));
  }

  // 新增 error 级别 issue → exit 1
  const hasNewErrors = compareResult.newIssues.some(i => i.severity === 'error');
  process.exit(hasNewErrors ? 1 : 0);
}

// CLI 入口（仅当作为主模块直接运行时执行）
import { fileURLToPath } from 'node:url';
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch(e => {
    console.error(`基线对比异常: ${e.message}`);
    process.exit(2);
  });
}
