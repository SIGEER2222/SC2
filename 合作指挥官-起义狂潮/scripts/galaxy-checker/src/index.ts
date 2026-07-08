// src/index.ts
import { readFileSync, statSync, readdirSync } from 'node:fs';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from './parser/index.js';
import { RuleEngine, checkRules } from './analyzer/RuleEngine.js';
import { IssueReporter } from './reporter/IssueReporter.js';
import type { Issue, CheckResult, CheckOptions } from './types.js';

export { parse, RuleEngine, checkRules, IssueReporter };
export type { Issue, CheckResult, CheckOptions };

const DEFAULT_RULES_PATH = join(
  dirname(fileURLToPath(import.meta.url)),
  '..',
  'data',
  'project-rules.json'
);

export function check(target: string, options: CheckOptions = {}): CheckResult {
  const rulesPath = options.rulesPath ?? DEFAULT_RULES_PATH;
  const engine = new RuleEngine(rulesPath);
  const reporter = new IssueReporter('json');

  const files = collectFiles(target);
  const allIssues: Issue[] = [];

  for (const file of files) {
    const raw = readFileSync(file);
    const content = stripBom(raw.toString('utf-8'));

    // BOM 检查
    if (engine.isRuleEnabled('PROJ_UTF8_BOM')) {
      if (raw[0] === 0xef && raw[1] === 0xbb && raw[2] === 0xbf) {
        allIssues.push(engine.makeIssue('PROJ_UTF8_BOM', basename(file), 1, 1)!);
      }
    }

    // 语法 + 规则检查
    const issues = checkRules(content, basename(file));
    allIssues.push(...issues);
  }

  return reporter.buildResult(allIssues, files.length);
}

function collectFiles(target: string): string[] {
  const stat = statSync(target);
  if (stat.isFile()) return [target];
  // 目录：递归扫 Lib*.galaxy
  const out: string[] = [];
  walkDir(target, out);
  return out;
}

function walkDir(dir: string, out: string[]): void {
  const entries = readdirSync(dir, { withFileTypes: true });
  for (const e of entries) {
    const full = join(dir, e.name);
    if (e.isDirectory()) {
      walkDir(full, out);
    } else if (e.isFile() && e.name.endsWith('.galaxy') && e.name.startsWith('Lib')) {
      out.push(full);
    }
  }
}

function stripBom(s: string): string {
  return s.charCodeAt(0) === 0xfeff ? s.slice(1) : s;
}
