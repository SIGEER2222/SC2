#!/usr/bin/env node
/**
 * sc2-composer CLI 入口
 *
 * 用法：
 *   node cli.mjs lint-dataspaces [project-root]
 *   node cli.mjs lint-dataspaces --mod <mod-path>
 *   node cli.mjs lint-dataspaces --json
 *   node cli.mjs validate-composition-plan <plan.json>
 *   node cli.mjs validate-commander-package <package.json>
 *   node cli.mjs resolve-dependencies <plan.json> [--project-root <path>]
 *
 * 默认 project-root 为当前工作目录的父目录（自动探测）。
 */

import { lintMod, lintProject } from './src/lintDataspaces.mjs';
import { validatePlan, resolveDependencies, detectConflicts } from './src/compositionPlan.mjs';
import { validatePackage, extractPackageFromMod } from './src/commanderPackage.mjs';
import { generateCompositionPlan, comparePlans } from './src/rebornCompatibility.mjs';
import { generateBootstrapGalaxy, generateBootstrapFile } from './src/bootstrapGenerator.mjs';
import {
  createReport,
  aggregateFromLint,
  aggregateFromSchemaValidation,
  aggregateFromComparePlans,
  aggregateFromLauncherPlan,
  aggregateFromGalaxyChecker,
  aggregateFromDocumentRoundtrip,
  mergeIntoReport,
  summarize,
  deriveOverallStatus,
} from './src/verificationReport.mjs';
import { writeFileSync, readFileSync, mkdirSync, existsSync as fsExistsSync } from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';

const args = process.argv.slice(2);

// 已支持的子命令清单
const COMMANDS = [
  'lint-dataspaces',
  'validate-composition-plan',
  'validate-commander-package',
  'resolve-dependencies',
  'verify',
  'generate-bootstrap',
];

function printUsage() {
  console.log(`sc2-composer - 数据中心驱动的 SC2Mod 组合工具链

用法：
  node cli.mjs lint-dataspaces [options] [project-root]
  node cli.mjs lint-dataspaces --mod <mod-path>
  node cli.mjs validate-composition-plan <plan.json>
  node cli.mjs validate-commander-package <package.json>
  node cli.mjs resolve-dependencies <plan.json> [--project-root <path>]
  node cli.mjs verify --map <map.sc2map> --commander <id> [--launcher-plan <plan.json>] [--project-root <path>] [--json] [--md]
  node cli.mjs generate-bootstrap --map <map.sc2map> --commander <id> [--project-root <path>] [--output <path>] [--json]

子命令：
  lint-dataspaces               扫描 SC2Mod 数据空间，校验 DataCenter manifest
  validate-composition-plan     校验 CompositionPlan 结构
  validate-commander-package    校验 CommanderPackage manifest
  resolve-dependencies          根据 CompositionPlan 解析有序依赖列表
  verify                        汇总 lint + schema + comparePlans 生成 VerificationReport
  generate-bootstrap            从 CompositionPlan 生成 per-commander bootstrap galaxy

选项：
  --mod <path>         [lint-dataspaces] 只 lint 指定的 SC2Mod 目录
  --json               [lint-dataspaces/verify] 输出 JSON 格式（便于 CI 集成）
  --quiet              [lint-dataspaces] 只输出 error 级别问题
  --project-root <p>   [resolve-dependencies/verify] 项目根目录（默认自动探测）
  --map <map.sc2map>   [verify] 目标地图文件名
  --commander <id>     [verify] 指挥官 ID
  --launcher-plan <p>  [verify] 可选的 launcher-plan.json 路径，用于 comparePlans
  --md                 [verify] 同时输出 Markdown 摘要
  --output <path>      [generate-bootstrap] 输出 galaxy 文件路径
  --help, -h           显示帮助

示例：
  node cli.mjs lint-dataspaces
  node cli.mjs lint-dataspaces --json
  node cli.mjs lint-dataspaces --mod "Mods/7vs1/CommanderUnits_Raynor.SC2Mod"
  node cli.mjs validate-composition-plan plan.json
  node cli.mjs validate-commander-package Shared/Commanders/TerranRaynor.json
  node cli.mjs resolve-dependencies plan.json --project-root .
  node cli.mjs verify --map zexpedition03_reborn_port.SC2Map --commander TerranRaynor --md
  node cli.mjs generate-bootstrap --map zexpedition03_reborn_port.SC2Map --commander TerranRaynor --json
`);
}

/**
 * 解析命令行参数。
 * 第一个非选项参数为子命令，第二个非选项参数语义随子命令变化：
 *   - lint-dataspaces: projectRoot
 *   - validate-composition-plan / validate-commander-package / resolve-dependencies: 目标 JSON 文件
 */
function parseArgs(argv) {
  const opts = {
    command: null,
    target: null,      // 第二个非选项参数（lint-dataspaces 时即 projectRoot）
    json: false,
    quiet: false,
    mod: null,
    projectRoot: null, // resolve-dependencies / verify 显式 --project-root
    map: null,         // verify --map
    commander: null,   // verify --commander
    launcherPlan: null,// verify --launcher-plan
    md: false,         // verify --md
    output: null,      // generate-bootstrap --output
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--help' || a === '-h') { printUsage(); process.exit(0); }
    else if (a === '--json') opts.json = true;
    else if (a === '--quiet') opts.quiet = true;
    else if (a === '--md') opts.md = true;
    else if (a === '--mod') opts.mod = argv[++i];
    else if (a === '--project-root') opts.projectRoot = argv[++i];
    else if (a === '--map') opts.map = argv[++i];
    else if (a === '--commander') opts.commander = argv[++i];
    else if (a === '--launcher-plan') opts.launcherPlan = argv[++i];
    else if (a === '--output') opts.output = argv[++i];
    else if (!a.startsWith('--')) {
      if (!opts.command) opts.command = a;
      else if (opts.target === null) opts.target = a;
    }
  }
  return opts;
}

/**
 * 探测项目根目录：从脚本位置向上找包含 Mods/ 的目录。
 * @returns {string}
 */
function detectProjectRoot() {
  const scriptDir = dirname(fileURLToPath(import.meta.url));
  let dir = scriptDir;
  for (let i = 0; i < 6; i++) {
    if (dir === dirname(dir)) break;
    const candidate = join(dir, 'Mods');
    if (existsSync(candidate)) return dir;
    dir = dirname(dir);
  }
  return process.cwd();
}

/**
 * 读取并解析 JSON 文件。
 * @param {string} path
 * @returns {object}
 * @throws {Error} 文件不存在或解析失败
 */
function readJsonFile(path) {
  if (!existsSync(path)) {
    throw new Error(`文件不存在: ${path}`);
  }
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (e) {
    throw new Error(`JSON 解析失败: ${path} - ${e.message}`);
  }
}

// ============================================================
// 子命令：lint-dataspaces（保留原有行为不变）
// ============================================================
async function runLintDataspaces(opts) {
  // 探测 project root
  let projectRoot = opts.target;
  if (!projectRoot) {
    projectRoot = detectProjectRoot();
  }
  projectRoot = resolve(projectRoot);

  let results;
  if (opts.mod) {
    const modPath = resolve(opts.mod);
    const issues = await lintMod(modPath);
    results = {
      modCount: 1,
      issues,
      modReports: issues.length > 0 ? new Map([[modPath, issues]]) : new Map(),
    };
  } else {
    results = await lintProject(projectRoot);
  }

  const { modCount, issues, modReports } = results;

  // 统计
  const errorCount = issues.filter(i => i.severity === 'error').length;
  const warningCount = issues.filter(i => i.severity === 'warning').length;
  const infoCount = issues.filter(i => i.severity === 'info').length;

  if (opts.json) {
    const output = {
      projectRoot,
      modCount,
      totalIssues: issues.length,
      errors: errorCount,
      warnings: warningCount,
      infos: infoCount,
      mods: Array.from(modReports.entries()).map(([mod, issues]) => ({
        mod: basename(mod),
        path: mod,
        issues,
      })),
    };
    console.log(JSON.stringify(output, null, 2));
  } else {
    console.log(`\n=== sc2-composer lint-dataspaces ===`);
    console.log(`项目根: ${projectRoot}`);
    console.log(`扫描 mod 数: ${modCount}`);
    console.log(`问题统计: ${errorCount} errors, ${warningCount} warnings, ${infoCount} infos\n`);

    if (modReports.size === 0) {
      console.log('无问题报告。\n');
    } else {
      for (const [modPath, modIssues] of modReports) {
        const modName = basename(modPath);
        const filtered = opts.quiet
          ? modIssues.filter(i => i.severity === 'error')
          : modIssues;
        if (filtered.length === 0) continue;

        console.log(`--- ${modName} ---`);
        const relMod = modPath.replace(projectRoot + '\\', '').replace(projectRoot + '/', '');
        console.log(`路径: ${relMod}`);
        for (const issue of filtered) {
          const sev = issue.severity.toUpperCase().padEnd(7);
          const code = issue.code.padEnd(7);
          const loc = issue.file
            ? ` [${issue.file.replace(projectRoot + '\\', '').replace(projectRoot + '/', '')}${issue.line ? `:${issue.line}` : ''}]`
            : '';
          console.log(`  ${sev} ${code} ${issue.message}${loc}`);
        }
        console.log();
      }
    }
  }

  // 有 error 时退出码非零
  if (errorCount > 0) {
    process.exit(1);
  }
}

// ============================================================
// 子命令：validate-composition-plan
// ============================================================
async function runValidateCompositionPlan(opts) {
  if (!opts.target) {
    console.error('错误：validate-composition-plan 需要 <plan.json> 参数');
    process.exit(2);
  }
  const planPath = resolve(opts.target);
  const plan = readJsonFile(planPath);
  const { valid, errors } = validatePlan(plan);

  if (opts.json) {
    console.log(JSON.stringify({ file: planPath, valid, errors }, null, 2));
  } else {
    console.log(`\n=== validate-composition-plan ===`);
    console.log(`文件: ${planPath}`);
    console.log(`结果: ${valid ? 'PASS' : 'FAIL'}`);
    if (errors.length > 0) {
      console.log(`\n错误 (${errors.length}):`);
      for (const e of errors) console.log(`  - ${e}`);
    }
    console.log();
  }

  if (!valid) process.exit(1);
}

// ============================================================
// 子命令：validate-commander-package
// ============================================================
async function runValidateCommanderPackage(opts) {
  if (!opts.target) {
    console.error('错误：validate-commander-package 需要 <package.json> 参数');
    process.exit(2);
  }
  const pkgPath = resolve(opts.target);
  const pkg = readJsonFile(pkgPath);
  const { valid, errors } = validatePackage(pkg);

  if (opts.json) {
    console.log(JSON.stringify({ file: pkgPath, valid, errors }, null, 2));
  } else {
    console.log(`\n=== validate-commander-package ===`);
    console.log(`文件: ${pkgPath}`);
    console.log(`结果: ${valid ? 'PASS' : 'FAIL'}`);
    if (errors.length > 0) {
      console.log(`\n错误 (${errors.length}):`);
      for (const e of errors) console.log(`  - ${e}`);
    }
    console.log();
  }

  if (!valid) process.exit(1);
}

// ============================================================
// 子命令：resolve-dependencies
// ============================================================
async function runResolveDependencies(opts) {
  if (!opts.target) {
    console.error('错误：resolve-dependencies 需要 <plan.json> 参数');
    process.exit(2);
  }
  const planPath = resolve(opts.target);
  const plan = readJsonFile(planPath);

  // projectRoot：优先 --project-root，其次自动探测
  const projectRoot = opts.projectRoot ? resolve(opts.projectRoot) : detectProjectRoot();

  const { layers, missing } = await resolveDependencies(plan, projectRoot);

  if (opts.json) {
    console.log(JSON.stringify({
      file: planPath,
      projectRoot,
      layers,
      missing,
    }, null, 2));
  } else {
    console.log(`\n=== resolve-dependencies ===`);
    console.log(`计划文件: ${planPath}`);
    console.log(`项目根: ${projectRoot}`);
    console.log(`依赖层数: ${layers.length}`);
    console.log();

    for (const layer of layers) {
      console.log(`[${layer.layer}] ${layer.name} (${layer.source})`);
      for (const entry of layer.entries) {
        const flag = entry.missing ? ' (MISSING)' : '';
        const path = entry.path ? entry.path : '(无路径)';
        const slot = entry.slot ? ` slot=${entry.slot}` : '';
        const cmd = entry.commander ? ` commander=${entry.commander}` : '';
        console.log(`  - ${path}${slot}${cmd}  // ${entry.reason}${flag}`);
      }
      console.log();
    }

    if (missing.length > 0) {
      console.log(`缺失项 (${missing.length}):`);
      for (const m of missing) console.log(`  - ${m}`);
      console.log();
    }
  }
}

// ============================================================
// 子命令：verify - 汇总 lint + schema + comparePlans 生成 VerificationReport
// ============================================================

/**
 * 运行 galaxy-checker 对地图 galaxy 文件做静态检查，返回 CheckResult JSON。
 *
 * 非阻塞：galaxy-checker 退出码 1（存在 error）时仍解析 stdout；
 * 退出码 2（工具异常）或 JSON 解析失败时返回 null。
 *
 * @param {string} mapDir - 地图目录绝对路径
 * @param {string} compositionPlanPath - 可选，CompositionPlan.json 路径，传给 --composition-plan
 * @param {string} projectRoot - 项目根
 * @returns {object|null} galaxy-checker 输出的 CheckResult JSON，失败返回 null
 */
function runGalaxyChecker(mapDir, compositionPlanPath, projectRoot) {
  const checkerCli = join(projectRoot, 'scripts', 'galaxy-checker', 'dist', 'cli.mjs');
  if (!fsExistsSync(checkerCli)) {
    return null;
  }
  const cmdArgs = [checkerCli, mapDir];
  if (compositionPlanPath) {
    cmdArgs.push('--composition-plan', compositionPlanPath);
  }
  let result;
  try {
    result = spawnSync(process.execPath, cmdArgs, {
      cwd: projectRoot,
      encoding: 'utf8',
      maxBuffer: 32 * 1024 * 1024,
    });
  } catch (e) {
    return null;
  }
  // 退出码 2 = 工具异常，不解析
  if (result.status === 2) {
    return null;
  }
  // 退出码 0/1 都应输出 JSON（非 --ci 模式输出完整 CheckResult）
  const stdout = (result.stdout || '').trim();
  if (!stdout) return null;
  try {
    return JSON.parse(stdout);
  } catch {
    return null;
  }
}

/**
 * 读取 DocumentHeader（二进制）中的依赖字符串。
 * 复刻 document-dependencies.ps1 的 Read-DocumentHeaderDependencies 逻辑（只读）。
 *
 * @param {string} headerPath
 * @returns {string[]}
 */
function readDocumentHeaderDeps(headerPath) {
  if (!fsExistsSync(headerPath)) return [];
  const bytes = readFileSync(headerPath);
  // 定位 "file:" / "bnet:" marker，其前 4 字节为 uint32 count（1..127）
  const markers = [
    Buffer.from('file:', 'utf8'),
    Buffer.from('bnet:', 'utf8'),
  ];
  let start = -1;
  for (let offset = 4; offset < bytes.length; offset++) {
    for (const marker of markers) {
      if (offset + marker.length > bytes.length) continue;
      if (bytes.subarray(offset, offset + marker.length).equals(marker)) {
        const count = bytes.readUInt32LE(offset - 4);
        if (count > 0 && count < 128) {
          start = offset;
          break;
        }
      }
    }
    if (start >= 0) break;
  }
  if (start < 0) return [];
  const count = bytes.readUInt32LE(start - 4);
  const deps = [];
  let offset = start;
  for (let i = 0; i < count; i++) {
    let end = offset;
    while (end < bytes.length && bytes[end] !== 0) end++;
    deps.push(bytes.subarray(offset, end).toString('utf8'));
    offset = end + 1;
  }
  return deps;
}

/**
 * 读取 DocumentInfo（XML）中的 <Dependencies><Value> 条目。
 *
 * @param {string} infoPath
 * @returns {string[]}
 */
function readDocumentInfoDeps(infoPath) {
  if (!fsExistsSync(infoPath)) return [];
  const content = readFileSync(infoPath, 'utf8');
  const deps = [];
  const blockMatch = content.match(/<Dependencies>([\s\S]*?)<\/Dependencies>/);
  if (blockMatch) {
    const valueRe = /<Value>(.*?)<\/Value>/g;
    let m;
    while ((m = valueRe.exec(blockMatch[1])) !== null) {
      deps.push(m[1]);
    }
  }
  return deps;
}

/**
 * 只读检查 DocumentHeader 与 DocumentInfo 依赖一致性（不做 write-back roundtrip）。
 *
 * @param {string} mapDir - 地图目录绝对路径
 * @returns {{ valid: boolean, originalDeps: string[], infoDeps: string[], errors: string[] }}
 */
function checkDocumentRoundtrip(mapDir) {
  const headerPath = join(mapDir, 'DocumentHeader');
  const infoPath = join(mapDir, 'DocumentInfo');
  const errors = [];
  const originalDeps = readDocumentHeaderDeps(headerPath);
  const infoDeps = readDocumentInfoDeps(infoPath);

  if (!fsExistsSync(headerPath)) {
    errors.push(`DocumentHeader not found: ${headerPath}`);
  }
  // 一致性：空项 + 重复
  for (const d of originalDeps) {
    if (!d || !d.trim()) errors.push('Empty dependency entry found in DocumentHeader');
  }
  const seen = new Set();
  for (const d of originalDeps) {
    if (seen.has(d)) errors.push(`Duplicate dependency in DocumentHeader: '${d}'`);
    seen.add(d);
  }
  // header vs info 集合比对
  const setHeader = new Set(originalDeps);
  const setInfo = new Set(infoDeps);
  const onlyInHeader = [...setHeader].filter((x) => !setInfo.has(x));
  const onlyInInfo = [...setInfo].filter((x) => !setHeader.has(x));
  if (onlyInHeader.length > 0) {
    errors.push(`Only in DocumentHeader: ${onlyInHeader.join(', ')}`);
  }
  if (onlyInInfo.length > 0) {
    errors.push(`Only in DocumentInfo: ${onlyInInfo.join(', ')}`);
  }

  return { valid: errors.length === 0, originalDeps, infoDeps, errors };
}

async function runVerify(opts) {
  if (!opts.map) {
    console.error('错误：verify 需要 --map <map.sc2map> 参数');
    process.exit(2);
  }
  if (!opts.commander) {
    console.error('错误：verify 需要 --commander <id> 参数');
    process.exit(2);
  }

  const projectRoot = opts.projectRoot ? resolve(opts.projectRoot) : detectProjectRoot();

  // === 1. 生成 CompositionPlan 并校验 schema ===
  let compositionPlan;
  try {
    compositionPlan = generateCompositionPlan({
      mapName: opts.map,
      commander: opts.commander,
      projectRoot,
    });
  } catch (e) {
    // 生成失败：直接输出 fail 报告
    const report = createReport({
      compositionId: `reborn.${opts.map.replace(/\.SC2Map$/, '')}__p1-${opts.commander}`,
      runId: new Date().toISOString().replace(/[:.]/g, '').slice(0, 14),
      checks: { schema: 'fail' },
      failures: [{
        check: 'schema',
        message: `generateCompositionPlan 失败: ${e.message}`,
        severity: 'error',
        source: 'generateCompositionPlan',
      }],
    });
    emitVerifyReport(report, opts, projectRoot);
    process.exit(1);
  }

  const schemaValidation = validatePlan(compositionPlan);

  // === 2. lint-dataspaces ===
  const lintResult = await lintProject(projectRoot);

  // === 3. 可选 comparePlans ===
  let compareAgg = null;
  let launcherPlanAgg = null;
  if (opts.launcherPlan && fsExistsSync(opts.launcherPlan)) {
    const launcherPlan = readJsonFile(opts.launcherPlan);
    const compareResult = comparePlans(compositionPlan, launcherPlan);
    compareAgg = aggregateFromComparePlans(compareResult, {
      compositionPlanPath: '(generated)',
      launcherPlanPath: opts.launcherPlan,
    });
    launcherPlanAgg = aggregateFromLauncherPlan(launcherPlan, { planPath: opts.launcherPlan });
  }

  // === 4. galaxy-checker 静态检查 ===
  // 把生成的 CompositionPlan 写到 out 目录，供 galaxy-checker --composition-plan 加载上下文
  const verifyOutDir = join(projectRoot, 'out', 'verification', compositionPlan.planId);
  if (!fsExistsSync(verifyOutDir)) mkdirSync(verifyOutDir, { recursive: true });
  const tempPlanPath = join(verifyOutDir, '.verify.compositionPlan.json');
  writeFileSync(tempPlanPath, JSON.stringify(compositionPlan, null, 2) + '\n', 'utf8');

  const mapDir = join(projectRoot, 'Maps', opts.map);
  let galaxyAgg = null;
  if (fsExistsSync(mapDir)) {
    const galaxyResult = runGalaxyChecker(mapDir, tempPlanPath, projectRoot);
    if (galaxyResult) {
      galaxyAgg = aggregateFromGalaxyChecker(galaxyResult, {
        checkerPath: 'galaxy-checker/dist/cli.mjs',
      });
    }
  }

  // === 5. DocumentHeader/Info roundtrip（只读）===
  let docAgg = null;
  if (fsExistsSync(mapDir)) {
    const docResult = checkDocumentRoundtrip(mapDir);
    docAgg = aggregateFromDocumentRoundtrip(docResult, { mapPath: mapDir });
  }

  // === 6. 合并所有聚合结果 ===
  let report = createReport({
    compositionId: compositionPlan.planId,
    runId: new Date().toISOString().replace(/[:.]/g, '').slice(0, 14),
  });

  report = mergeIntoReport(
    report,
    aggregateFromSchemaValidation(schemaValidation, { planPath: '(generated)' }),
    aggregateFromLint(lintResult, { projectRoot }),
  );
  if (launcherPlanAgg) report = mergeIntoReport(report, launcherPlanAgg);
  if (compareAgg) report = mergeIntoReport(report, compareAgg);
  if (galaxyAgg) report = mergeIntoReport(report, galaxyAgg);
  if (docAgg) report = mergeIntoReport(report, docAgg);

  emitVerifyReport(report, opts, projectRoot);

  const { overall } = deriveOverallStatus(report);
  if (overall === 'fail') process.exit(1);
}

function emitVerifyReport(report, opts, projectRoot) {
  const outDir = join(projectRoot, 'out', 'verification', report.compositionId);
  if (!fsExistsSync(outDir)) {
    mkdirSync(outDir, { recursive: true });
  }
  const jsonPath = join(outDir, `${report.runId}.verification.json`);
  writeFileSync(jsonPath, JSON.stringify(report, null, 2) + '\n', 'utf8');

  if (opts.json) {
    console.log(JSON.stringify(report, null, 2));
  } else {
    const { overall, summary: overallSummary } = deriveOverallStatus(report);
    console.log(`\n=== verify ===`);
    console.log(`CompositionId: ${report.compositionId}`);
    console.log(`RunId: ${report.runId}`);
    console.log(`Overall: ${overall} — ${overallSummary}`);
    console.log(`Report: ${jsonPath}`);
    console.log();
    for (const [cp, status] of Object.entries(report.checks)) {
      const icon = status === 'pass' ? '[PASS]' : status === 'fail' ? '[FAIL]' : `[${status.toUpperCase()}]`;
      console.log(`  ${icon.padEnd(10)} ${cp}`);
    }
    if (report.failures.length > 0) {
      console.log(`\nFailures (${report.failures.length}):`);
      for (const f of report.failures.slice(0, 10)) {
        console.log(`  [${f.severity || 'error'}] ${f.check}: ${f.message}`);
      }
      if (report.failures.length > 10) {
        console.log(`  ... and ${report.failures.length - 10} more`);
      }
    }
  }

  if (opts.md) {
    const mdPath = join(outDir, `${report.runId}.md`);
    writeFileSync(mdPath, summarize(report), 'utf8');
    if (!opts.json) console.log(`Markdown: ${mdPath}`);
  }
}

/**
 * generate-bootstrap: 从 CompositionPlan 生成 per-commander bootstrap galaxy。
 *
 * 用法：node cli.mjs generate-bootstrap --map <map.sc2map> --commander <id> [--project-root <path>] [--output <path>] [--json]
 */
async function runGenerateBootstrap(opts) {
  if (!opts.map) {
    console.error('generate-bootstrap 需要 --map <map.sc2map>');
    process.exit(2);
  }
  if (!opts.commander) {
    console.error('generate-bootstrap 需要 --commander <id>');
    process.exit(2);
  }

  const projectRoot = opts.projectRoot ? resolve(opts.projectRoot) : detectProjectRoot();
  const plan = generateCompositionPlan({
    mapName: opts.map,
    commander: opts.commander,
    projectRoot,
  });

  const compositionLabel = `reborn.${opts.map.replace(/\.SC2Map$/, '')} × ${opts.commander}`;
  const result = generateBootstrapGalaxy(plan, { compositionLabel });

  if (opts.json) {
    console.log(JSON.stringify({
      planId: plan.planId,
      outputPath: opts.output || null,
      stats: result.stats,
      includes: result.includes,
    }, null, 2));
  } else {
    if (opts.output) {
      mkdirSync(dirname(opts.output), { recursive: true });
      writeFileSync(opts.output, result.content, 'utf-8');
      console.log(`Bootstrap written to: ${opts.output}`);
    } else {
      console.log(result.content);
    }
    console.error(`Stats: ${result.stats.total} → ${result.stats.kept} entries (${result.stats.excluded} excluded)`);
  }
}

async function main() {
  const opts = parseArgs(args);

  if (!opts.command) {
    printUsage();
    process.exit(2);
  }

  switch (opts.command) {
    case 'lint-dataspaces':
      await runLintDataspaces(opts);
      break;
    case 'validate-composition-plan':
      await runValidateCompositionPlan(opts);
      break;
    case 'validate-commander-package':
      await runValidateCommanderPackage(opts);
      break;
    case 'resolve-dependencies':
      await runResolveDependencies(opts);
      break;
    case 'verify':
      await runVerify(opts);
      break;
    case 'generate-bootstrap':
      await runGenerateBootstrap(opts);
      break;
    default:
      console.error(`未知子命令: ${opts.command}`);
      console.error(`支持的子命令: ${COMMANDS.join(', ')}`);
      process.exit(2);
  }
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(2);
});
