// src/index.ts
import { readFileSync, statSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname, basename } from 'node:path';
import { resolveDataFile } from './dataPath.js';
import { parse } from './parser/index.js';
import { RuleEngine, checkRules } from './analyzer/RuleEngine.js';
import { IssueReporter } from './reporter/IssueReporter.js';
import { NativeFunctionTable } from './analyzer/NativeFunctionTable.js';
import { ProjectLoader } from './analyzer/ProjectLoader.js';
import { analyze } from './analyzer/SemanticAnalyzer.js';
import { SymbolTable } from './analyzer/SymbolTable.js';
import { enrichIssues } from './analyzer/IssueEnricher.js';
import { resolveFromCompositionPlan } from './analyzer/CompositionPlanResolver.js';
import type { Issue, CheckResult, CheckOptions, CatalogDb } from './types.js';

export { parse, RuleEngine, checkRules, IssueReporter, NativeFunctionTable, ProjectLoader, analyze, enrichIssues, resolveFromCompositionPlan };
export { runFixer, fixDiscouragedUnitCreate } from './fixer/Fixer.js';
// 注意：baseline-compare 和 script-error-correlator 的函数不在此导出，避免其 main()
// 被 esbuild 打包进 cli.mjs / 其他 bundle 后因 import.meta.url 守卫失效而意外执行。
// 这两个模块各自作为独立 bundle（galaxy-checker-baseline / galaxy-checker-scripterror）提供 CLI 入口。
export type { Issue, CheckResult, CheckOptions, FixEdit, FixResult, BaselineEntry, CompareResult, ScriptErrorEntry, CorrelationResult } from './types.js';

const DEFAULT_RULES_PATH = resolveDataFile('project-rules.json');

// 随包附带的 native 函数签名表（由编辑器全函数索引生成）
const DEFAULT_NATIVES_PATH = resolveDataFile('natives.galaxy');
const DEFAULT_TRIGGERLIB_PATH = resolveDataFile('triggerlib-functions.galaxy');

// 默认 catalog ID 数据库（由 sc2_unit_explorer.py --export-catalog-ids 导出）
const DEFAULT_CATALOG_DB_PATH = resolveDataFile('catalog-ids.json');

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

  // CompositionPlan 集成：从 plan 解析 symbolRoots/catalogDb/compositionId
  let compositionId: string | undefined;
  let contextLoaded = false;
  let resolvedCatalogDbPath = options.catalogDbPath;
  let extraSymbolRoots = options.symbolRoots ?? [];

  if (options.compositionPlanPath) {
    // projRoot = workspace root（target 的上溯）
    const projRoot = guessProjRoot(target);
    const ctx = resolveFromCompositionPlan(options.compositionPlanPath, projRoot);
    if (ctx.contextLoaded) {
      compositionId = ctx.compositionId;
      contextLoaded = true;
      // CompositionPlan 提供的 symbolRoots 与手动传入的合并
      extraSymbolRoots = [...ctx.symbolRoots, ...extraSymbolRoots];
      // CompositionPlan 提供的 catalogDb 优先级低于手动传入
      if (!resolvedCatalogDbPath && ctx.catalogDbPath) {
        resolvedCatalogDbPath = ctx.catalogDbPath;
      }
    }
  }

  // 全局符号表：仅当 target 是目录且未禁用时构建（跨文件符号可见性）
  let globalTable: SymbolTable | undefined;
  const symbolRoots = [
    ...(statSync(target).isDirectory() ? [target] : []),
    ...extraSymbolRoots,
  ].filter((root, index, roots) =>
    roots.indexOf(root) === index && existsSync(root) && statSync(root).isDirectory()
  );
  if (!options.noGlobalSymbols && symbolRoots.length > 0) {
    const loader = new ProjectLoader(symbolRoots);
    globalTable = loader.buildGlobalSymbolTable();
  }

  // native 表：黑名单默认加载 data/native-blacklist.json；
  // native 签名优先用 options.nativeLibPath，否则回退到附带的 data/natives.galaxy
  const nativeTable = getNativeTable(options.nativeLibPath);

  // catalog ID 数据库：用于校验 galaxy 脚本中传给 catalog native 的字符串字面量
  // 优先用 options.catalogDbPath（或 CompositionPlan 解析的），否则回退到附带的 data/catalog-ids.json
  const catalogDb = loadCatalogDb(resolvedCatalogDbPath);

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

    // parse 一次，语法层与语义层共用（parse error 只由语法层收集一次）
    const parsed = parse(content, basename(file));
    const syntaxIssues = checkRules(content, basename(file), parsed);
    allIssues.push(...syntaxIssues);

    // 语义层 + 跨库/native 检查 + catalog 引用校验
    const semanticIssues = analyze(
      content, basename(file), globalTable, nativeTable, engine,
      { ast: parsed.ast, errors: [] }, catalogDb
    );
    allIssues.push(...semanticIssues);

    // include 存在性检查
    const includes = extractIncludes(content);
    for (const inc of includes) {
      if (inc.startsWith('TriggerLibs/') || inc.startsWith('triggerlibs/')) continue;
      const includeFound = findIncludeFile(fileDir, inc)
        || symbolRoots.some(root => findIncludeFile(root, inc));
      if (!includeFound && engine.isRuleEnabled('XLIB_MISSING_INCLUDE')) {
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

  // 注入工程化元数据（confidence/autoFixable/runtimeRisk/suggestedOwner）
  const enrichedIssues = enrichIssues(allIssues, { contextLoaded });

  const result = reporter.buildResult(enrichedIssues, files.length);
  result.compositionId = compositionId;
  result.contextLoaded = contextLoaded;
  return result;
}

// 从 target 路径猜测项目根目录（向上查找含 Mods/ 的目录）
function guessProjRoot(target: string): string {
  let dir = target;
  for (let i = 0; i < 6; i++) {
    if (existsSync(join(dir, 'Mods'))) return dir;
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return target;
}

// natives 签名表按路径缓存（同进程内重复 check() 免重复 parse）
let cachedNativeTable: NativeFunctionTable | null = null;
let cachedNativePath: string | null = null;

function getNativeTable(nativeLibPath?: string): NativeFunctionTable {
  const path = nativeLibPath && existsSync(nativeLibPath)
    ? nativeLibPath
    : existsSync(DEFAULT_NATIVES_PATH) ? DEFAULT_NATIVES_PATH : null;
  if (cachedNativeTable && cachedNativePath === path) return cachedNativeTable;
  const table = new NativeFunctionTable();
  if (path) table.loadFromFile(path);
  if (existsSync(DEFAULT_TRIGGERLIB_PATH)) table.loadFromFile(DEFAULT_TRIGGERLIB_PATH);
  cachedNativeTable = table;
  cachedNativePath = path;
  return table;
}

// catalog ID 数据库按路径缓存（同进程内重复 check() 免重复解析 JSON）
let cachedCatalogDb: CatalogDb | null = null;
let cachedCatalogPath: string | null = null;

function loadCatalogDb(catalogDbPath?: string): CatalogDb | undefined {
  const path = catalogDbPath && existsSync(catalogDbPath)
    ? catalogDbPath
    : existsSync(DEFAULT_CATALOG_DB_PATH) ? DEFAULT_CATALOG_DB_PATH : null;
  if (path === null) return undefined;
  if (cachedCatalogDb && cachedCatalogPath === path) return cachedCatalogDb;
  try {
    const raw = JSON.parse(readFileSync(path, 'utf-8')) as Record<string, string[]>;
    // 将 JSON 数组转换为 Set 实现 O(1) 查找
    const db: CatalogDb = {};
    for (const key of ['Unit', 'Abil', 'Upgrade', 'Behavior', 'Effect', 'Button', 'any'] as const) {
      if (Array.isArray(raw[key])) {
        db[key] = new Set(raw[key]);
      }
    }
    cachedCatalogDb = db;
    cachedCatalogPath = path;
    return db;
  } catch {
    return undefined;
  }
}

export function collectFiles(target: string): string[] {
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
