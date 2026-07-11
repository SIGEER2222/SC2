// src/script-error-correlator.ts
// ScriptError 关联工具：解析 GameLogs/ScriptError.txt，将运行时错误映射回 galaxy 文件位置。
// 用法:
//   node dist/script-error-correlator.mjs <ScriptError.txt> [--galaxy-root <dir>]
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { join, basename, dirname } from 'node:path';
import { check } from './index.js';
import type { Issue } from './types.js';

export interface ScriptErrorEntry {
  rawLine: string;
  lineNumber: number;
  // 解析出的信息
  galaxyFile?: string;
  galaxyLine?: number;
  triggerName?: string;
  errorMessage?: string;
  // 关联结果
  correlatedIssue?: Issue;
  suggestions?: string[];
}

export interface CorrelationResult {
  totalErrors: number;
  parsed: ScriptErrorEntry[];
  correlated: number;
  unresolved: number;
  galaxyFilesChecked: Set<string>;
}

/**
 * 解析 ScriptError.txt。
 * SC2 ScriptError.txt 格式（典型）:
 *
 * File: LibXXX.galaxy
 * Line: 1234
 * Error: <message>
 *
 * 或:
 * Trigger: libXXX_gf_FunctionName
 * <message>
 *
 * 或紧凑格式:
 * LibXXX.galaxy:1234: <message>
 */
export function parseScriptError(content: string): ScriptErrorEntry[] {
  const lines = content.split(/\r?\n/);
  const entries: ScriptErrorEntry[] = [];
  let current: Partial<ScriptErrorEntry> & { rawLines: string[] } = { rawLines: [] };

  const flush = () => {
    if (current.rawLines.length === 0 && !current.galaxyFile && !current.triggerName) return;
    entries.push({
      rawLine: current.rawLines.join('\n'),
      lineNumber: entries.length + 1,
      galaxyFile: current.galaxyFile,
      galaxyLine: current.galaxyLine,
      triggerName: current.triggerName,
      errorMessage: current.errorMessage,
    });
    current = { rawLines: [] };
  };

  for (const line of lines) {
    current.rawLines.push(line);

    // File: LibXXX.galaxy
    const fileMatch = line.match(/^\s*File:\s*(.+\.galaxy)\s*$/i);
    if (fileMatch) {
      current.galaxyFile = basename(fileMatch[1]);
      continue;
    }

    // Line: 1234
    const lineMatch = line.match(/^\s*Line:\s*(\d+)\s*$/i);
    if (lineMatch) {
      current.galaxyLine = parseInt(lineMatch[1], 10);
      continue;
    }

    // Trigger: libXXX_gf_FunctionName
    const triggerMatch = line.match(/^\s*Trigger:\s*(\S+)\s*$/i);
    if (triggerMatch) {
      current.triggerName = triggerMatch[1];
      continue;
    }

    // Error: <message>
    const errorMatch = line.match(/^\s*Error:\s*(.+)$/i);
    if (errorMatch) {
      current.errorMessage = errorMatch[1];
      continue;
    }

    // 紧凑格式: LibXXX.galaxy:1234: <message>
    const compactMatch = line.match(/^\s*(Lib\w+\.galaxy):(\d+):\s*(.+)$/);
    if (compactMatch) {
      current.galaxyFile = compactMatch[1];
      current.galaxyLine = parseInt(compactMatch[2], 10);
      current.errorMessage = compactMatch[3];
      flush();
      continue;
    }

    // 空行分隔条目
    if (line.trim() === '' && (current.galaxyFile || current.triggerName || current.errorMessage)) {
      flush();
    }
  }
  flush();

  return entries;
}

/**
 * 在 galaxy 文件目录中查找指定文件。
 */
function findGalaxyFile(fileName: string, galaxyRoots: string[]): string | null {
  for (const root of galaxyRoots) {
    if (!existsSync(root)) continue;
    const found = findFileRecursive(root, fileName);
    if (found) return found;
  }
  return null;
}

function findFileRecursive(dir: string, fileName: string): string | null {
  try {
    const entries = readdirSync(dir, { withFileTypes: true });
    for (const e of entries) {
      const full = join(dir, e.name);
      if (e.isFile() && e.name === fileName) return full;
      if (e.isDirectory()) {
        const found = findFileRecursive(full, fileName);
        if (found) return found;
      }
    }
  } catch { /* ignore */ }
  return null;
}

/**
 * 将 ScriptError 条目与 galaxy 源码关联，生成修复建议。
 */
export function correlateScriptErrors(
  scriptErrorPath: string,
  galaxyRoots: string[]
): CorrelationResult {
  if (!existsSync(scriptErrorPath)) {
    return { totalErrors: 0, parsed: [], correlated: 0, unresolved: 0, galaxyFilesChecked: new Set() };
  }

  const content = readFileSync(scriptErrorPath, 'utf-8');
  const entries = parseScriptError(content);
  const checkedFiles = new Set<string>();

  let correlated = 0;
  for (const entry of entries) {
    if (!entry.galaxyFile) {
      entry.suggestions = ['无法从 ScriptError 中解析出 galaxy 文件名'];
      continue;
    }

    const filePath = findGalaxyFile(entry.galaxyFile, galaxyRoots);
    if (!filePath) {
      entry.suggestions = [`文件 ${entry.galaxyFile} 在提供的目录中未找到`];
      continue;
    }

    checkedFiles.add(filePath);

    // 对该文件运行 checker，查找可能的静态问题
    try {
      const result = check(filePath, { symbolRoots: galaxyRoots });
      // 查找同行的 issue
      const matchingIssue = result.issues.find(
        i => i.line === entry.galaxyLine || (entry.galaxyLine && Math.abs(i.line - entry.galaxyLine) <= 2)
      );
      if (matchingIssue) {
        entry.correlatedIssue = matchingIssue;
        correlated++;
      } else {
        // 未找到精确匹配，生成基于 ScriptError 信息的建议
        entry.suggestions = [
          `ScriptError 在 ${entry.galaxyFile}:${entry.galaxyLine} 报告错误`,
          entry.errorMessage ? `错误信息: ${entry.errorMessage}` : '',
          entry.triggerName ? `触发器: ${entry.triggerName}` : '',
          '静态检查未检测到对应问题，可能是运行时特有的错误（如 catalog 缺失、native 调用失败）',
        ].filter(Boolean);
      }
    } catch {
      entry.suggestions = [`对 ${entry.galaxyFile} 运行静态检查失败`];
    }
  }

  return {
    totalErrors: entries.length,
    parsed: entries,
    correlated,
    unresolved: entries.length - correlated,
    galaxyFilesChecked: checkedFiles,
  };
}

/**
 * 格式化关联结果为文本报告。
 */
export function formatCorrelationReport(result: CorrelationResult): string {
  const lines: string[] = [];
  lines.push('=== ScriptError 关联报告 ===');
  lines.push(`总错误数: ${result.totalErrors}`);
  lines.push(`已关联: ${result.correlated}`);
  lines.push(`未关联: ${result.unresolved}`);
  lines.push(`检查的 galaxy 文件: ${result.galaxyFilesChecked.size}`);
  lines.push('');

  if (result.correlated > 0) {
    lines.push('=== 已关联的静态问题 ===');
    for (const entry of result.parsed) {
      if (!entry.correlatedIssue) continue;
      const issue = entry.correlatedIssue;
      lines.push(`  ${entry.galaxyFile}:${entry.galaxyLine}`);
      if (entry.errorMessage) lines.push(`    ScriptError: ${entry.errorMessage}`);
      lines.push(`    静态规则: ${issue.ruleCode} (line ${issue.line})`);
      lines.push(`    静态消息: ${issue.message}`);
      if (issue.suggestedOwner) lines.push(`    建议修复方: ${issue.suggestedOwner}`);
      lines.push('');
    }
  }

  if (result.unresolved > 0) {
    lines.push('=== 未关联的运行时错误（需人工排查）===');
    for (const entry of result.parsed) {
      if (entry.correlatedIssue) continue;
      lines.push(`  ${entry.galaxyFile || '未知文件'}:${entry.galaxyLine || '?'}`);
      if (entry.suggestions) {
        for (const s of entry.suggestions) {
          lines.push(`    ${s}`);
        }
      }
      lines.push('');
    }
  }

  return lines.join('\n');
}

// CLI 入口
import { fileURLToPath } from 'node:url';
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  if (args.length === 0 || args.includes('--help')) {
    console.error(`用法: script-error-correlator <ScriptError.txt> [--galaxy-root <dir>] [--json]
选项:
  --galaxy-root <dir>  galaxy 文件根目录，可重复（默认当前目录）
  --json               输出 JSON 格式（默认文本）`);
    process.exit(2);
  }

  const scriptErrorPath = args[0];
  const galaxyRoots: string[] = [];
  for (let i = 1; i < args.length; i++) {
    if (args[i] === '--galaxy-root' && args[i + 1]) {
      galaxyRoots.push(args[i + 1]);
      i++;
    }
  }
  if (galaxyRoots.length === 0) galaxyRoots.push(process.cwd());

  const useJson = args.includes('--json');
  const result = correlateScriptErrors(scriptErrorPath, galaxyRoots);

  if (useJson) {
    console.log(JSON.stringify({
      totalErrors: result.totalErrors,
      correlated: result.correlated,
      unresolved: result.unresolved,
      filesChecked: [...result.galaxyFilesChecked],
      entries: result.parsed,
    }, null, 2));
  } else {
    console.log(formatCorrelationReport(result));
  }

  process.exit(result.unresolved > 0 ? 1 : 0);
}
