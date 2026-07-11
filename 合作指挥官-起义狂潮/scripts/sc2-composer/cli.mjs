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
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readFileSync, existsSync } from 'node:fs';

const args = process.argv.slice(2);

// 已支持的子命令清单
const COMMANDS = [
  'lint-dataspaces',
  'validate-composition-plan',
  'validate-commander-package',
  'resolve-dependencies',
];

function printUsage() {
  console.log(`sc2-composer - 数据中心驱动的 SC2Mod 组合工具链

用法：
  node cli.mjs lint-dataspaces [options] [project-root]
  node cli.mjs lint-dataspaces --mod <mod-path>
  node cli.mjs validate-composition-plan <plan.json>
  node cli.mjs validate-commander-package <package.json>
  node cli.mjs resolve-dependencies <plan.json> [--project-root <path>]

子命令：
  lint-dataspaces               扫描 SC2Mod 数据空间，校验 DataCenter manifest
  validate-composition-plan     校验 CompositionPlan 结构
  validate-commander-package    校验 CommanderPackage manifest
  resolve-dependencies          根据 CompositionPlan 解析有序依赖列表

选项：
  --mod <path>         [lint-dataspaces] 只 lint 指定的 SC2Mod 目录
  --json               [lint-dataspaces] 输出 JSON 格式（便于 CI 集成）
  --quiet              [lint-dataspaces] 只输出 error 级别问题
  --project-root <p>   [resolve-dependencies] 项目根目录（默认自动探测）
  --help, -h           显示帮助

示例：
  node cli.mjs lint-dataspaces
  node cli.mjs lint-dataspaces --json
  node cli.mjs lint-dataspaces --mod "Mods/7vs1/CommanderUnits_Raynor.SC2Mod"
  node cli.mjs validate-composition-plan plan.json
  node cli.mjs validate-commander-package Shared/Commanders/TerranRaynor.json
  node cli.mjs resolve-dependencies plan.json --project-root .
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
    projectRoot: null, // resolve-dependencies 显式 --project-root
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--help' || a === '-h') { printUsage(); process.exit(0); }
    else if (a === '--json') opts.json = true;
    else if (a === '--quiet') opts.quiet = true;
    else if (a === '--mod') opts.mod = argv[++i];
    else if (a === '--project-root') opts.projectRoot = argv[++i];
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
