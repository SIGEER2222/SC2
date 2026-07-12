import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dependencySearchRoots, readWorkflowConfig } from './dependencyGraph.mjs';

const MODULE_DIR = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_TOOLKIT_ROOT = path.resolve(
  MODULE_DIR,
  '..',
  '..',
  '..',
  '..',
  'tools',
  'sc2-galaxy-toolkit',
);

function walkGalaxyFiles(root, out = []) {
  if (!fs.existsSync(root)) return out;
  for (const name of fs.readdirSync(root)) {
    const file = path.join(root, name);
    const stat = fs.statSync(file);
    if (stat.isDirectory()) walkGalaxyFiles(file, out);
    else if (name.toLowerCase().endsWith('.galaxy')) out.push(file);
  }
  return out;
}

function severityFromLsp(value) {
  if (value === 1) return 'error';
  if (value === 2) return 'warning';
  if (value === 3) return 'info';
  return 'info';
}

function summarizeIssues(issues) {
  return {
    errors: issues.filter(issue => issue.severity === 'error').length,
    warnings: issues.filter(issue => issue.severity === 'warning').length,
    infos: issues.filter(issue => issue.severity === 'info').length,
  };
}

function toRuleCode(issue) {
  const source = typeof issue.source === 'string' ? issue.source : 'toolkit';
  return source === 'parser' ? 'TOOLKIT_PARSE'
    : source === 'typecheck' ? 'TOOLKIT_TYPECHECK'
    : 'TOOLKIT_DIAGNOSTIC';
}

export function findArchiveRootForGalaxyCheck(inputPath) {
  let current = path.resolve(inputPath);
  if (fs.existsSync(current) && fs.statSync(current).isFile()) current = path.dirname(current);
  while (true) {
    if (/\.(SC2Mod|SC2Map)$/i.test(path.basename(current))) return current;
    const parent = path.dirname(current);
    if (parent === current) return null;
    current = parent;
  }
}

function detectProjectRoot(baseDataRoot) {
  let current = path.resolve(baseDataRoot);
  while (true) {
    if (fs.existsSync(path.join(current, 'Shared', 'Workflow', 'sc2-workflow.json'))) return current;
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
  return path.resolve(MODULE_DIR, '..', '..');
}

function resolveModSources(projectRoot) {
  const config = readWorkflowConfig(projectRoot);
  return dependencySearchRoots(projectRoot, config).filter(root => fs.existsSync(root));
}

async function createStoreForCheck({
  Store,
  S2WorkspaceWatcher,
  createTextDocumentFromFs,
  archiveRoot,
  baseDataRoot,
}) {
  const store = new Store({});
  let loadMode = 'directory-fallback';

  if (archiveRoot) {
    const projectRoot = detectProjectRoot(baseDataRoot);
    const modSources = resolveModSources(projectRoot);
    const watcher = new S2WorkspaceWatcher(archiveRoot, modSources);
    const workspaces = [];
    watcher.onDidOpen(ev => store.updateDocument(ev.document));
    watcher.onDidOpenS2Archive(ev => workspaces.push(ev.workspace));
    await watcher.watch();
    for (const workspace of workspaces) {
      await store.updateS2Workspace(workspace);
    }
    loadMode = 'archive-workspace';
  } else {
    store.rootPath = baseDataRoot;
  }

  const galaxyFiles = walkGalaxyFiles(baseDataRoot).sort((left, right) => left.localeCompare(right));
  const fileToUri = new Map();
  for (const file of galaxyFiles) {
    const document = createTextDocumentFromFs(file);
    fileToUri.set(file, document.uri);
    store.updateDocument(document);
  }

  return { store, galaxyFiles, fileToUri, loadMode };
}

export function resolveToolkitRoot(toolkitRoot = DEFAULT_TOOLKIT_ROOT) {
  const resolved = path.resolve(toolkitRoot);
  if (!fs.existsSync(resolved)) {
    throw new Error(`sc2-galaxy-toolkit 不存在: ${resolved}`);
  }
  return resolved;
}

export async function checkGalaxyWithToolkit({
  baseDataRoot,
  toolkitRoot = DEFAULT_TOOLKIT_ROOT,
} = {}) {
  if (!baseDataRoot) throw new Error('缺少 baseDataRoot');
  const resolvedBaseData = path.resolve(baseDataRoot);
  if (!fs.existsSync(resolvedBaseData)) {
    throw new Error(`待检查路径不存在: ${resolvedBaseData}`);
  }

  const resolvedToolkitRoot = resolveToolkitRoot(toolkitRoot);
  const [
    { Store, S2WorkspaceWatcher, createTextDocumentFromFs },
    { DiagnosticsProvider },
    { createProvider },
  ] = await Promise.all([
    import(pathToFileURL(path.join(resolvedToolkitRoot, 'packages', 'sc2-lsp', 'lib', 'src', 'galaxy', 'store.js')).href),
    import(pathToFileURL(path.join(resolvedToolkitRoot, 'packages', 'sc2-lsp', 'lib', 'src', 'galaxy', 'diagnostics.js')).href),
    import(pathToFileURL(path.join(resolvedToolkitRoot, 'packages', 'sc2-lsp', 'lib', 'src', 'galaxy', 'provider.js')).href),
  ]);

  const archiveRoot = findArchiveRootForGalaxyCheck(resolvedBaseData);
  const { store, galaxyFiles, fileToUri, loadMode } = await createStoreForCheck({
    Store,
    S2WorkspaceWatcher,
    createTextDocumentFromFs,
    archiveRoot,
    baseDataRoot: resolvedBaseData,
  });

  const diagnosticsProvider = createProvider(DiagnosticsProvider, store);
  const issues = [];

  for (const file of galaxyFiles) {
    const uri = fileToUri.get(file);
    diagnosticsProvider.checkFile(uri);
    const diagnostics = diagnosticsProvider.provideDiagnostics(uri);
    for (const diagnostic of diagnostics) {
      issues.push({
        file,
        relativeFile: path.relative(resolvedBaseData, file).replaceAll('\\', '/'),
        line: diagnostic.range.start.line + 1,
        column: diagnostic.range.start.character + 1,
        endLine: diagnostic.range.end.line + 1,
        endColumn: diagnostic.range.end.character + 1,
        severity: severityFromLsp(diagnostic.severity),
        ruleCode: toRuleCode(diagnostic),
        source: diagnostic.source ?? 'toolkit',
        message: diagnostic.message,
      });
    }
  }

  return {
    version: '1.0',
    tool: 'sc2-galaxy-toolkit',
    toolkitRoot: resolvedToolkitRoot,
    baseDataRoot: resolvedBaseData,
    archiveRoot,
    loadMode,
    filesChecked: galaxyFiles.length,
    summary: summarizeIssues(issues),
    issues,
  };
}

export function renderToolkitGalaxyResult(result) {
  const lines = [];
  for (const issue of result.issues) {
    const tag = issue.severity === 'error' ? 'ERROR'
      : issue.severity === 'warning' ? 'WARN'
      : 'INFO';
    lines.push(`[${tag}] ${issue.relativeFile}:${issue.line}:${issue.column}  ${issue.ruleCode}`);
    lines.push(`        ${issue.message}`);
    lines.push('');
  }
  lines.push(
    `总计: ${result.summary.errors} 错误, ${result.summary.warnings} 警告, ${result.summary.infos} 提示`,
  );
  lines.push(`文件: ${result.filesChecked}`);
  return lines.join('\n');
}
