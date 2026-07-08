// src/index.ts
import { readFileSync, statSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from './parser/index.js';
import { RuleEngine, checkRules } from './analyzer/RuleEngine.js';
import { IssueReporter } from './reporter/IssueReporter.js';
import { NativeFunctionTable } from './analyzer/NativeFunctionTable.js';
import { ProjectLoader } from './analyzer/ProjectLoader.js';
import { analyze } from './analyzer/SemanticAnalyzer.js';
import { SymbolTable } from './analyzer/SymbolTable.js';
import type { Issue, CheckResult, CheckOptions } from './types.js';

export { parse, RuleEngine, checkRules, IssueReporter, NativeFunctionTable, ProjectLoader, analyze };
export type { Issue, CheckResult, CheckOptions };

const DEFAULT_RULES_PATH = join(
  dirname(fileURLToPath(import.meta.url)),
  '..',
  'data',
  'project-rules.json'
);

// 从源码提取 include 路径
function extractIncludes(source: string): string[] {
  const out: string[] = [];
  for (const m of source.matchAll(/^\s*include\s+"([^"]+)"/gm)) {
    out.push(m[1]);
  }
  return out;
}

// 在给定目录查找 include 文件（递归向下 2 层）
function findIncludeFile(baseDir: string, inc: string): boolean {
  const incName = inc.endsWith('.galaxy') ? inc : inc + '.galaxy';
  const base = basename(incName);
  const search = (dir: string, depth: number): boolean => {
    if (depth < 0) return false;
    try {
      const entries = readdirSync(dir, { withFileTypes: true });
      for (const e of entries) {
        if (e.isFile() && e.name === base) return true;
        if (e.isDirectory()) {
          if (search(join(dir, e.name), depth - 1)) return true;
        }
      }
    } catch { /* ignore */ }
    return false;
  };
  return search(baseDir, 2);
}

export function check(target: string, options: CheckOptions = {}): CheckResult {
  const rulesPath = options.rulesPath ?? DEFAULT_RULES_PATH;
  const engine = new RuleEngine(rulesPath);
  const reporter = new IssueReporter('json');

  // 全局符号表：仅当 target 是目录且未禁用时构建（跨文件符号可见性）
  let globalTable: SymbolTable | undefined;
  if (!options.noGlobalSymbols && statSync(target).isDirectory()) {
    const loader = new ProjectLoader(target);
    globalTable = loader.buildGlobalSymbolTable();
  }

  // native 表：默认自动加载 data/native-blacklist.json
  const nativeTable = new NativeFunctionTable();
  if (options.nativeLibPath && existsSync(options.nativeLibPath)) {
    nativeTable.loadFromFile(options.nativeLibPath);
  }

  const files = collectFiles(target);
  const allIssues: Issue[] = [];

  for (const file of files) {
    const raw = readFileSync(file);
    const content = stripBom(raw.toString('utf-8'));
    const fileDir = dirname(file);

    // BOM 检查
    if (engine.isRuleEnabled('PROJ_UTF8_BOM')) {
      if (raw[0] === 0xef && raw[1] === 0xbb && raw[2] === 0xbf) {
        allIssues.push(engine.makeIssue('PROJ_UTF8_BOM', basename(file), 1, 1)!);
      }
    }

    // 语法层规则（SYNTAX_NO_CONTINUE 等）
    const syntaxIssues = checkRules(content, basename(file));
    allIssues.push(...syntaxIssues);

    // 语义层 + 跨库/native 检查
    const semanticIssues = analyze(content, basename(file), globalTable, nativeTable, engine);
    allIssues.push(...semanticIssues);

    // include 存在性检查
    const includes = extractIncludes(content);
    for (const inc of includes) {
      if (inc.startsWith('TriggerLibs/') || inc.startsWith('triggerlibs/')) continue;
      if (!findIncludeFile(fileDir, inc) && engine.isRuleEnabled('XLIB_MISSING_INCLUDE')) {
        const lines = content.split('\n');
        let line = 1;
        for (let i = 0; i < lines.length; i++) {
          if (lines[i].includes(`include "${inc}"`)) { line = i + 1; break; }
        }
        allIssues.push(
          engine.makeIssue('XLIB_MISSING_INCLUDE', basename(file), line, 1, `include "${inc}" 未找到`)!
        );
      }
    }
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
