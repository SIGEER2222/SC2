import fs from 'node:fs';
import path from 'node:path';
import { decodeBuffer, decodeEntities, parseXml } from './lenientXml.mjs';

function normalizePathKey(value) {
  return path.resolve(value).replaceAll('\\', '/').toLowerCase();
}

export function extractFileDependency(value) {
  if (typeof value !== 'string') return null;
  const index = value.lastIndexOf('file:');
  if (index < 0) return null;
  return value.slice(index).trim();
}

function findChildCaseInsensitive(parent, name) {
  if (!fs.existsSync(parent) || !fs.statSync(parent).isDirectory()) return null;
  const direct = path.join(parent, name);
  if (fs.existsSync(direct)) return direct;
  const match = fs.readdirSync(parent).find(entry => entry.toLowerCase() === name.toLowerCase());
  return match ? path.join(parent, match) : null;
}

export function resolveCaseInsensitive(root, relativePath) {
  let current = root;
  for (const segment of relativePath.split(/[\\/]+/).filter(Boolean)) {
    current = findChildCaseInsensitive(current, segment);
    if (!current) return null;
  }
  return current;
}

export function readWorkflowConfig(projectRoot, explicitPath = null) {
  const configPath = explicitPath
    ? path.resolve(explicitPath)
    : path.join(projectRoot, 'Shared', 'Workflow', 'sc2-workflow.json');
  if (!fs.existsSync(configPath)) {
    return {
      configPath,
      schemaVersion: 1,
      dependencySearchRoots: ['.'],
      legacyDependencies: {},
      runtimeMutationFunctions: [],
    };
  }
  return { configPath, ...JSON.parse(fs.readFileSync(configPath, 'utf8')) };
}

export function readPackageDependencies(packageRoot) {
  const documentInfo = path.join(packageRoot, 'DocumentInfo');
  if (!fs.existsSync(documentInfo)) {
    return { documentInfo, dependencies: [], issues: [] };
  }
  const { text } = decodeBuffer(fs.readFileSync(documentInfo));
  const parsed = parseXml(text, documentInfo);
  const dependencies = [];
  const dependenciesBlock = /<Dependencies\b[^>]*>([\s\S]*?)<\/Dependencies>/i.exec(text)?.[1] ?? '';
  const valuePattern = /<Value\b[^>]*>([\s\S]*?)<\/Value>/gi;
  let match;
  while ((match = valuePattern.exec(dependenciesBlock)) !== null) {
    const raw = decodeEntities(match[1].trim());
    const absoluteOffset = text.indexOf(dependenciesBlock) + match.index;
    const line = text.slice(0, absoluteOffset).split(/\r?\n/).length;
    dependencies.push({
      raw,
      fileRef: extractFileDependency(raw),
      line,
    });
  }
  const attributePattern = /<Dependency\b[^>]*\bvalue\s*=\s*(?:"([^"]*)"|'([^']*)')[^>]*\/?>/gi;
  while ((match = attributePattern.exec(text)) !== null) {
    const raw = decodeEntities((match[1] ?? match[2] ?? '').trim());
    const line = text.slice(0, match.index).split(/\r?\n/).length;
    dependencies.push({
      raw,
      fileRef: extractFileDependency(raw),
      line,
    });
  }
  return { documentInfo, dependencies, issues: parsed.issues };
}

function dependencyRelativePath(fileRef) {
  return fileRef?.startsWith('file:') ? fileRef.slice(5).replaceAll('/', path.sep) : null;
}

export function dependencySearchRoots(projectRoot, config) {
  const roots = [];
  for (const configured of config.dependencySearchRoots ?? ['.']) {
    roots.push(path.resolve(projectRoot, configured));
  }
  if (process.env.SC2_ROOT) roots.push(path.resolve(process.env.SC2_ROOT));
  return [...new Set(roots.map(root => path.resolve(root)))];
}

export function resolveDependency(fileRef, projectRoot, config) {
  const candidates = [];
  const refs = [fileRef, config.dependencyAliases?.[fileRef]].filter(Boolean);
  for (const ref of refs) {
    const relative = dependencyRelativePath(ref);
    if (!relative) continue;
    for (const root of dependencySearchRoots(projectRoot, config)) {
      const variants = [relative];
      const parts = relative.split(path.sep);
      if (parts[0]?.toLowerCase() === 'mods') {
        variants.push(path.join('mods', ...parts.slice(1)));
      } else if (parts[0]?.toLowerCase() === 'campaigns') {
        variants.push(path.join('campaigns', ...parts.slice(1)));
      }
      for (const variant of variants) {
        const candidate = resolveCaseInsensitive(root, variant);
        candidates.push(path.join(root, variant));
        if (candidate) return { path: path.resolve(candidate), candidates, resolvedRef: ref };
      }
    }
  }
  return { path: null, candidates };
}

function effectiveProfile(target, config) {
  return (config.effectiveProfiles ?? []).find(profile => {
    try {
      return new RegExp(profile.targetPattern, 'i').test(path.basename(target));
    } catch {
      return false;
    }
  }) ?? null;
}

function externalDependency(fileRef, config) {
  return (config.externalDependencies ?? []).some(value =>
    value.endsWith('*') ? fileRef.startsWith(value.slice(0, -1)) : fileRef === value
  );
}

function commanderDependencyRefs(profile, commanders) {
  const mapping = profile?.commanderDependencies ?? {};
  const selected = commanders.length > 0 ? commanders : Object.keys(mapping);
  return [...new Set(selected.flatMap(commander => mapping[commander] ?? []))];
}

function replacementRefs(legacy, profile, commanders) {
  if (legacy?.strategy === 'selected-commander-units') {
    return commanderDependencyRefs(profile, commanders);
  }
  return (legacy?.replacement ?? []).filter(ref => !ref.includes('<Commander>'));
}

export function buildDependencyGraph({
  target,
  projectRoot,
  configPath = null,
  effective = false,
  commanders = [],
}) {
  const resolvedTarget = path.resolve(target);
  const config = readWorkflowConfig(projectRoot, configPath);
  const profile = effective ? effectiveProfile(resolvedTarget, config) : null;
  const nodes = [];
  const edges = [];
  const issues = [];
  const loadOrder = [];
  const seen = new Set();
  const visiting = new Set();

  function addResolvedDependency(node, dep, fileRef, status, legacy = null) {
    const existing = node.dependencies.find(item => item.fileRef === fileRef && item.status === status);
    if (existing) return existing;
    const resolved = resolveDependency(fileRef, projectRoot, config);
    const isExternal = !resolved.path && externalDependency(fileRef, config);
    const depRecord = {
      ...dep,
      fileRef,
      path: resolved.path,
      status: resolved.path ? status : isExternal ? 'external' : status,
      legacy,
    };
    node.dependencies.push(depRecord);
    edges.push({
      from: node.id,
      to: resolved.path ? normalizePathKey(resolved.path) : fileRef,
      ref: fileRef,
      status: depRecord.status,
    });
    if (resolved.path) {
      visit(resolved.path, { declaredBy: node.path, declaredRef: fileRef });
    } else if (!legacy && !isExternal) {
      issues.push({
        severity: 'warning',
        code: 'DEPENDENCY_UNRESOLVED',
        file: node.documentInfo,
        line: dep.line,
        message: `无法解析 ${fileRef}`,
      });
    }
    return depRecord;
  }

  function visit(packagePath, meta = {}) {
    const key = normalizePathKey(packagePath);
    if (visiting.has(key)) {
      issues.push({
        severity: 'error',
        code: 'DEPENDENCY_CYCLE',
        message: `依赖循环: ${packagePath}`,
      });
      return;
    }
    if (seen.has(key)) return;
    visiting.add(key);
    const info = readPackageDependencies(packagePath);
    const node = {
      id: key,
      path: packagePath,
      name: path.basename(packagePath),
      declaredBy: meta.declaredBy ?? null,
      declaredRef: meta.declaredRef ?? null,
      status: 'resolved',
      documentInfo: info.documentInfo,
      dependencies: [],
    };
    nodes.push(node);
    for (const dep of info.dependencies) {
      if (!dep.fileRef) {
        node.dependencies.push({ ...dep, status: 'external' });
        continue;
      }
      const legacy = config.legacyDependencies?.[dep.fileRef] ?? null;
      if (effective && legacy) {
        const refs = replacementRefs(legacy, profile, commanders);
        const record = {
          ...dep,
          status: refs.length > 0 ? 'replaced' : 'needs-selection',
          legacy,
          replacements: [],
        };
        node.dependencies.push(record);
        for (const replacement of refs) {
          const resolvedReplacement = resolveDependency(replacement, projectRoot, config);
          record.replacements.push({
            fileRef: replacement,
            path: resolvedReplacement.path,
            status: resolvedReplacement.path ? 'effective' : 'missing',
          });
          if (!profile) {
            addResolvedDependency(
              node,
              { ...dep, raw: `effective:${dep.fileRef}` },
              replacement,
              'effective',
            );
          }
        }
        continue;
      }
      const resolved = resolveDependency(dep.fileRef, projectRoot, config);
      const status = legacy
        ? resolved.path ? 'legacy-resolved' : 'legacy'
        : resolved.path ? 'resolved' : externalDependency(dep.fileRef, config) ? 'external' : 'missing';
      addResolvedDependency(node, dep, dep.fileRef, status, legacy);
    }
    if (effective && meta.isTarget && profile) {
      for (const generatedRef of profile.alwaysDependencies ?? []) {
        addResolvedDependency(
          node,
          { raw: `effective-profile:${profile.name}`, line: 0 },
          generatedRef,
          'effective',
        );
      }
      for (const generatedRef of commanderDependencyRefs(profile, commanders)) {
        addResolvedDependency(
          node,
          { raw: `effective-commanders:${commanders.join(',') || 'all'}`, line: 0 },
          generatedRef,
          'effective',
        );
      }
    }
    visiting.delete(key);
    seen.add(key);
    loadOrder.push(packagePath);
  }

  visit(resolvedTarget, { isTarget: true });
  return {
    schemaVersion: 1,
    target: resolvedTarget,
    projectRoot: path.resolve(projectRoot),
    configPath: config.configPath,
    mode: effective ? 'effective' : 'declared',
    profile: profile?.name ?? null,
    commanders,
    nodes,
    edges,
    loadOrder,
    issues,
  };
}
