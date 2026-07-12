import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { buildDependencyGraph, readPackageDependencies, readWorkflowConfig } from './dependencyGraph.mjs';

function issue(severity, code, message, extra = {}) {
  return { severity, code, message, ...extra };
}

function hasNonAscii(value) {
  return /[^\x00-\x7f]/.test(value);
}

function walkFiles(root, predicate, out = []) {
  if (!fs.existsSync(root)) return out;
  for (const name of fs.readdirSync(root)) {
    const file = path.join(root, name);
    const stat = fs.statSync(file);
    if (stat.isDirectory()) walkFiles(file, predicate, out);
    else if (predicate(file)) out.push(file);
  }
  return out;
}

function hashFile(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

function compareRuntimeCopies(projectRoot) {
  const oldRoot = path.join(projectRoot, 'Mods', '7vs1', 'CoopZeroPop.SC2Mod', 'Base.SC2Data');
  const newRoot = path.join(projectRoot, 'Mods', '7vs1', 'CoreRuntime.SC2Mod', 'Base.SC2Data');
  if (!fs.existsSync(oldRoot) || !fs.existsSync(newRoot)) return null;
  let same = 0;
  let different = 0;
  const divergent = [];
  for (const file of walkFiles(newRoot, p => p.toLowerCase().endsWith('.galaxy'))) {
    const relative = path.relative(newRoot, file);
    const oldFile = path.join(oldRoot, relative);
    if (!fs.existsSync(oldFile)) continue;
    if (hashFile(file) === hashFile(oldFile)) same++;
    else {
      different++;
      divergent.push(relative.replaceAll('\\', '/'));
    }
  }
  return { same, different, divergent };
}

function findRelocatedFile(projectRoot, basename) {
  const docs = path.join(projectRoot, 'docs');
  return walkFiles(docs, file => path.basename(file).toLowerCase() === basename.toLowerCase())[0] ?? null;
}

function checkDocumentationReferences(projectRoot) {
  const findings = [];
  for (const sourceName of ['README.md', 'DESIGN.md']) {
    const source = path.join(projectRoot, sourceName);
    if (!fs.existsSync(source)) continue;
    const text = fs.readFileSync(source, 'utf8');
    const regex = /`([^`\r\n]+[\\/][^`\r\n]+\.(?:md|json|ps1|mjs|py|xml))`/g;
    let match;
    while ((match = regex.exec(text)) !== null) {
      const ref = match[1];
      if (/^[a-z]+:/i.test(ref)) continue;
      const resolved = path.resolve(projectRoot, ref);
      if (fs.existsSync(resolved)) continue;
      const relocated = findRelocatedFile(projectRoot, path.basename(ref));
      findings.push(issue('warning', 'DOC_STALE_PATH', `文档路径不存在: ${ref}`, {
        file: source,
        relocated,
      }));
    }
  }
  return findings;
}

export function doctorProject({ projectRoot, configPath = null }) {
  const config = readWorkflowConfig(projectRoot, configPath);
  const findings = [];
  if (hasNonAscii(projectRoot)) {
    findings.push(issue(
      'warning',
      'PATH_NON_ASCII',
      '项目路径包含非 ASCII 字符；银河编辑器、组件保存和部分旧工具可能失败',
      { path: projectRoot },
    ));
  }
  const nestedGit = path.join(projectRoot, '.git');
  if (fs.existsSync(nestedGit) && !fs.existsSync(path.join(nestedGit, 'HEAD'))) {
    findings.push(issue(
      'warning',
      'INVALID_NESTED_GIT',
      '项目目录内存在非 Git 仓库的 .git 目录，可能误导工具',
      { path: nestedGit },
    ));
  }
  const requiredTools = {
    toolkitGalaxyChecker: path.join(projectRoot, 'scripts', 'sc2-editor-toolkit', 'toolkit-galaxy-check.mjs'),
    unitExplorer: path.join(projectRoot, 'scripts', 'sc2_unit_explorer.py'),
    waitForGame: path.join(projectRoot, 'scripts', 'wait-for-game-ready.ps1'),
    launch7vs1: path.join(projectRoot, 'scripts', 'launch-7vs1-coop-test.ps1'),
  };
  for (const [name, file] of Object.entries(requiredTools)) {
    if (!fs.existsSync(file)) {
      findings.push(issue('error', 'TOOL_MISSING', `缺少工具 ${name}`, { path: file }));
    }
  }
  findings.push(...checkDocumentationReferences(projectRoot));

  const mapsRoot = path.join(projectRoot, 'Maps');
  let legacyDependencyCount = 0;
  let unresolvedDependencyCount = 0;
  for (const mapRoot of fs.existsSync(mapsRoot)
    ? fs.readdirSync(mapsRoot).filter(name => name.endsWith('.SC2Map')).map(name => path.join(mapsRoot, name))
    : []) {
    if (!fs.statSync(mapRoot).isDirectory()) continue;
    const info = readPackageDependencies(mapRoot);
    for (const dep of info.dependencies) {
      if (dep.fileRef && config.legacyDependencies?.[dep.fileRef]) legacyDependencyCount++;
    }
    const graph = buildDependencyGraph({ target: mapRoot, projectRoot, configPath });
    unresolvedDependencyCount += graph.issues.filter(i => i.code === 'DEPENDENCY_UNRESOLVED').length;
  }
  const runtimeCopies = compareRuntimeCopies(projectRoot);
  if (runtimeCopies?.different) {
    findings.push(issue(
      'warning',
      'RUNTIME_DUAL_SOURCE_DIVERGED',
      `CoreRuntime 与 CoopZeroPop 有 ${runtimeCopies.different} 个同路径 Galaxy 文件已分叉`,
      runtimeCopies,
    ));
  }
  return {
    schemaVersion: 1,
    projectRoot,
    configPath: config.configPath,
    summary: {
      errors: findings.filter(f => f.severity === 'error').length,
      warnings: findings.filter(f => f.severity === 'warning').length,
      legacyDependencyCount,
      unresolvedDependencyCount,
      runtimeCopies,
    },
    findings,
  };
}

function parseGitStatusZ(buffer) {
  const fields = buffer.toString('utf8').split('\0').filter(Boolean);
  const files = [];
  for (let index = 0; index < fields.length; index++) {
    const record = fields[index];
    const status = record.slice(0, 2);
    const file = record.slice(3);
    files.push(file);
    if (status.includes('R') || status.includes('C')) index++;
  }
  return files;
}

export function changedFiles(workspaceRoot) {
  const result = spawnSync('git', ['-C', workspaceRoot, 'status', '--porcelain=v1', '-z'], {
    encoding: null,
  });
  if (result.status !== 0) throw new Error(result.stderr.toString('utf8'));
  return parseGitStatusZ(result.stdout);
}

function packageRootFor(file) {
  let current = path.resolve(file);
  if (fs.existsSync(current) && fs.statSync(current).isFile()) current = path.dirname(current);
  while (true) {
    if (/\.(SC2Mod|SC2Map)$/i.test(path.basename(current))) return current;
    const parent = path.dirname(current);
    if (parent === current) return null;
    current = parent;
  }
}

function baseDataRootFor(file) {
  let current = path.resolve(file);
  if (fs.existsSync(current) && fs.statSync(current).isFile()) current = path.dirname(current);
  while (true) {
    if (path.basename(current).toLowerCase() === 'base.sc2data') return current;
    const parent = path.dirname(current);
    if (parent === current) return null;
    current = parent;
  }
}

function addAction(actions, action) {
  const key = JSON.stringify([action.kind, action.cwd, action.command, action.args]);
  if (!actions.some(existing => existing.key === key)) actions.push({ key, ...action });
}



export function buildValidationPlan({ workspaceRoot, projectRoot, files }) {
  const actions = [];
  const runtimeReasons = [];
  const toolkitRoot = path.join(projectRoot, 'scripts', 'sc2-editor-toolkit');
  for (const relative of files) {
    const absolute = path.resolve(workspaceRoot, relative);
    const normalized = absolute.replaceAll('\\', '/').toLowerCase();
    let baseData = null;
    if (normalized.endsWith('.galaxy')) {
      baseData = baseDataRootFor(absolute);
    } else if (
      normalized.endsWith('.sc2map') ||
      normalized.endsWith('.sc2mod') ||
      normalized.endsWith('.SC2Map') ||
      normalized.endsWith('.SC2Mod') ||
      fs.existsSync(path.join(absolute, 'GameData')) ||
      normalized.endsWith('/base.sc2data') ||
      fs.existsSync(path.join(absolute, 'DocumentInfo'))
    ) {
      if (normalized.endsWith('/base.sc2data')) {
        baseData = absolute;
      } else {
        const baseDataUnder = path.join(absolute, 'Base.SC2Data');
        baseData = fs.existsSync(baseDataUnder) ? baseDataUnder : absolute;
      }
    }
    if (baseData) {
      addAction(actions, {
        kind: 'toolkit-galaxy-check',
        cwd: path.join(projectRoot, 'scripts', 'sc2-editor-toolkit'),
        command: 'node',
        args: ['toolkit-galaxy-check.mjs', baseData, '--format', 'json'],
      });
    }
    if (absolute.toLowerCase().endsWith('.xml')) {
      const packageRoot = packageRootFor(absolute);
      if (packageRoot) {
        const graph = buildDependencyGraph({ target: packageRoot, projectRoot });
        const deps = graph.loadOrder.filter(item => path.resolve(item) !== path.resolve(packageRoot));
        addAction(actions, {
          kind: 'gamedata-validator',
          cwd: toolkitRoot,
          command: 'node',
          args: ['cli.mjs', 'validate', packageRoot, ...(deps.length ? ['--deps', ...deps] : []), '--format', 'json'],
        });
      }
    }
    if (normalized.includes('/scripts/sc2-editor-toolkit/')) {
      addAction(actions, { kind: 'toolkit-tests', cwd: toolkitRoot, command: 'npm', args: ['test'] });
    }
    if (normalized.includes('/scripts/galaxy-checker/')) {
      addAction(actions, {
        kind: 'galaxy-checker-tests',
        cwd: path.join(projectRoot, 'scripts', 'galaxy-checker'),
        command: 'npm',
        args: ['test'],
      });
    }
    if (normalized.includes('/web-launcher/')) {
      addAction(actions, {
        kind: 'web-launcher-tests',
        cwd: path.join(projectRoot, 'web-launcher'),
        command: 'npm',
        args: ['test'],
      });
    }
    if (
      normalized.includes('/maps/') ||
      (normalized.includes('/mods/7vs1/') && /\.(galaxy|xml)$/i.test(absolute))
    ) {
      runtimeReasons.push(relative);
    }
  }
  return {
    schemaVersion: 1,
    files,
    staticActions: actions.map(({ key, ...action }) => action),
    runtimeValidation: {
      required: runtimeReasons.length > 0,
      reasons: runtimeReasons,
      policy: runtimeReasons.length > 0
        ? '按地图类型启动，并等待 wait-for-game-ready.ps1 或普通 MPQ 完整检查流程结束'
        : null,
    },
  };
}

export function platformCommand(
  command,
  platform = process.platform,
  execPath = process.execPath,
  npmExecPath = process.env.npm_execpath,
) {
  if (platform !== 'win32' || !['npm', 'npx'].includes(command)) {
    return { command, argsPrefix: [] };
  }
  const npmBin = npmExecPath
    ? path.dirname(npmExecPath)
    : path.join(path.dirname(execPath), 'node_modules', 'npm', 'bin');
  return {
    command: execPath,
    argsPrefix: [path.join(npmBin, `${command}-cli.js`)],
  };
}

export function runValidationPlan(plan) {
  const results = [];
  for (const action of plan.staticActions) {
    const started = Date.now();
    const executable = platformCommand(action.command);
    const executedArgs = [...executable.argsPrefix, ...action.args];
    const result = spawnSync(executable.command, executedArgs, {
      cwd: action.cwd,
      encoding: 'utf8',
      windowsHide: true,
    });
    let parsed = null;
    const stdout = result.stdout ?? '';
    if (stdout.trim().startsWith('{')) {
      try { parsed = JSON.parse(stdout); } catch { /* preserve raw output */ }
    }
    results.push({
      ...action,
      executedCommand: executable.command,
      executedArgs,
      exitCode: result.status ?? 2,
      spawnError: result.error?.message ?? null,
      durationMs: Date.now() - started,
      parsed,
      stdout: parsed ? undefined : stdout.trim().split(/\r?\n/).slice(-80),
      stderr: (result.stderr ?? '').trim().split(/\r?\n/).filter(Boolean).slice(-80),
    });
  }
  const ok = results.every(result => {
    if (result.kind === 'toolkit-galaxy-check') {
      return (result.parsed?.summary?.errors ?? 0) === 0;
    }
    return result.exitCode === 0;
  });
  return {
    ...plan,
    results,
    ok,
  };
}
