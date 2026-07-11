#!/usr/bin/env node
/**
 * sc2-composer CLI 入口
 *
 * 用法：
 *   node cli.mjs lint-dataspaces [project-root]
 *   node cli.mjs lint-dataspaces --mod <mod-path>
 *   node cli.mjs lint-dataspaces --json
 *
 * 默认 project-root 为当前工作目录的父目录（自动探测）。
 */

import { lintMod, lintProject } from './src/lintDataspaces.mjs';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);

function printUsage() {
  console.log(`sc2-composer - 数据中心驱动的 SC2Mod 组合工具链

用法：
  node cli.mjs lint-dataspaces [options] [project-root]
  node cli.mjs lint-dataspaces --mod <mod-path>

选项：
  --mod <path>     只 lint 指定的 SC2Mod 目录
  --json           输出 JSON 格式（便于 CI 集成）
  --quiet          只输出 error 级别问题
  --help, -h       显示帮助

示例：
  node cli.mjs lint-dataspaces
  node cli.mjs lint-dataspaces --json
  node cli.mjs lint-dataspaces --mod "Mods/7vs1/CommanderUnits_Raynor.SC2Mod"
`);
}

function parseArgs(args) {
  const opts = { command: null, json: false, quiet: false, mod: null, projectRoot: null };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--help' || a === '-h') { printUsage(); process.exit(0); }
    else if (a === '--json') opts.json = true;
    else if (a === '--quiet') opts.quiet = true;
    else if (a === '--mod') opts.mod = args[++i];
    else if (!a.startsWith('--')) {
      // 第一个非选项参数是子命令（lint-dataspaces），后续是 projectRoot
      if (!opts.command) opts.command = a;
      else opts.projectRoot = a;
    }
  }
  return opts;
}

async function main() {
  const opts = parseArgs(args);

  // 探测 project root：从脚本位置向上找包含 Mods/ 的目录
  let projectRoot = opts.projectRoot;
  if (!projectRoot) {
    const scriptDir = dirname(fileURLToPath(import.meta.url));
    let dir = scriptDir;
    for (let i = 0; i < 6; i++) {
      if (dir === dirname(dir)) break;
      const candidate = join(dir, 'Mods');
      try {
        const stat = await import('node:fs').then(fs => fs.statSync(candidate));
        if (stat.isDirectory()) { projectRoot = dir; break; }
      } catch {}
      dir = dirname(dir);
    }
    if (!projectRoot) projectRoot = process.cwd();
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

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(2);
});
