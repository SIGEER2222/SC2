import fs from 'node:fs';
import path from 'node:path';
import { CatalogStore, catalogForTag, keyAttrs } from './catalog.mjs';
import { readModCatalog } from './modLoader.mjs';

function sourceOf(node, packageRoot) {
  return {
    package: packageRoot,
    file: node.file,
    line: node.line,
    tag: node.tag,
  };
}

function escapeKey(value) {
  return String(value).replaceAll('\\', '\\\\').replaceAll(']', '\\]');
}

function childSegment(node, siblingIndex) {
  const keys = keyAttrs(node);
  if (keys.length > 0) {
    const suffix = keys.map(key => `${key}=${escapeKey(node.attrs[key])}`).join(',');
    return `${node.tag}[${suffix}]`;
  }
  return `${node.tag}#${siblingIndex}`;
}

export function flattenNodeFields(node) {
  const fields = [];
  const walk = (current, currentPath) => {
    for (const [name, value] of Object.entries(current.attrs)) {
      if (currentPath === '' && name === 'id') continue;
      fields.push({
        path: currentPath ? `${currentPath}/@${name}` : `@${name}`,
        value,
        action: name === 'removed' && value === '1' ? 'remove' : 'set',
      });
    }
    const counts = new Map();
    for (const child of current.children) {
      const index = counts.get(child.tag) ?? 0;
      counts.set(child.tag, index + 1);
      const segment = childSegment(child, index);
      walk(child, currentPath ? `${currentPath}/${segment}` : segment);
    }
  };
  walk(node, '');
  return fields;
}

function collectGalaxyFiles(root, out = []) {
  if (!fs.existsSync(root)) return out;
  for (const name of fs.readdirSync(root)) {
    const file = path.join(root, name);
    const stat = fs.statSync(file);
    if (stat.isDirectory()) collectGalaxyFiles(file, out);
    else if (name.toLowerCase().endsWith('.galaxy')) out.push(file);
  }
  return out;
}

export function findRuntimeMutations(packagePaths, catalogId, functionNames = []) {
  const defaultNames = [
    'CatalogFieldValueSet',
    'CatalogFieldValueSetAsInt',
    'CatalogFieldValueSetAsFixed',
    'TechTreeUnitAllow',
    'TechTreeAbilityAllow',
    'UnitAbilityAdd',
    'UnitAbilityRemove',
  ];
  const names = [...new Set([...defaultNames, ...functionNames])];
  const functionPattern = /\b([A-Za-z_][A-Za-z0-9_]*)\s*\(/g;
  const quotedId = new RegExp(`["']${catalogId.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&')}["']`);
  const results = [];
  for (const packageRoot of packagePaths) {
    const baseData = path.join(packageRoot, 'Base.SC2Data');
    for (const file of collectGalaxyFiles(baseData)) {
      const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
      lines.forEach((line, index) => {
        functionPattern.lastIndex = 0;
        const fn = [...line.matchAll(functionPattern)].find(match =>
          names.some(name => match[1] === name || match[1].endsWith(name))
        );
        if (fn && quotedId.test(line)) {
          results.push({
            function: fn[1],
            file,
            line: index + 1,
            text: line.trim(),
          });
        }
      });
    }
  }
  return results;
}

export function traceCatalogId({ graph, catalog, id, field = null, runtimeMutationFunctions = [] }) {
  const store = new CatalogStore();
  const definitions = [];
  const fieldHistory = new Map();
  const loadIssues = [];

  for (const packageRoot of graph.loadOrder) {
    const loaded = readModCatalog(packageRoot);
    loadIssues.push(...loaded.fileIssues);
    for (const elem of loaded.entries) {
      store.addEntry(elem);
      if (catalogForTag(elem.tag) !== catalog || elem.attrs.id !== id) continue;
      const source = sourceOf(elem, packageRoot);
      const fields = flattenNodeFields(elem);
      definitions.push({
        ...source,
        parent: elem.attrs.parent ?? null,
        removed: elem.attrs.removed === '1',
        fields,
      });
      for (const event of fields) {
        if (field && !event.path.includes(field)) continue;
        const history = fieldHistory.get(event.path) ?? [];
        history.push({ ...event, source });
        fieldHistory.set(event.path, history);
      }
    }
  }

  const effective = store.getEntry(catalog, id);
  const parent = effective ? store.parentChain(catalog, id) : { chain: [], circular: false };
  const unresolvedParent = effective?.node.attrs.parent &&
    !store.getEntry(catalog, effective.node.attrs.parent)
    ? effective.node.attrs.parent
    : null;
  const incompleteDependencies = graph.edges.filter(edge =>
    ['external', 'missing', 'legacy', 'needs-selection'].includes(edge.status)
  );
  const provenance = {};
  for (const [fieldPath, events] of [...fieldHistory.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
    provenance[fieldPath] = {
      effective: events.at(-1),
      history: events,
    };
  }
  return {
    schemaVersion: 1,
    target: graph.target,
    catalog,
    id,
    found: Boolean(effective),
    definitions,
    effectiveSources: effective?.sources ?? [],
    parentChain: parent.chain.map(entry => entry.id),
    parentCircular: parent.circular,
    unresolvedParent,
    complete: incompleteDependencies.length === 0 && !unresolvedParent,
    incompleteDependencies,
    provenanceMode: 'definition-history',
    fieldProvenance: provenance,
    runtimeMutations: findRuntimeMutations(graph.loadOrder, id, runtimeMutationFunctions),
    runtimeScan: {
      mode: 'literal-id-line-scan',
      complete: false,
      limitations: ['dynamic-id', 'indirect-call', 'generated-string', 'multiline-call'],
    },
    issues: [...graph.issues, ...loadIssues],
  };
}

function comparableField(event) {
  if (!event) return null;
  return {
    value: event.value,
    action: event.action,
    source: event.source,
  };
}

function mutationKey(mutation) {
  return `${mutation.function}\u0000${mutation.text}`;
}

export function compareCatalogTraces(left, right) {
  const fieldPaths = new Set([
    ...Object.keys(left.fieldProvenance),
    ...Object.keys(right.fieldProvenance),
  ]);
  const fieldDifferences = [];
  for (const fieldPath of [...fieldPaths].sort((a, b) => a.localeCompare(b))) {
    const leftEvent = comparableField(left.fieldProvenance[fieldPath]?.effective);
    const rightEvent = comparableField(right.fieldProvenance[fieldPath]?.effective);
    if (
      leftEvent?.value === rightEvent?.value &&
      leftEvent?.action === rightEvent?.action &&
      leftEvent?.source?.file === rightEvent?.source?.file
    ) {
      continue;
    }
    fieldDifferences.push({
      path: fieldPath,
      left: leftEvent,
      right: rightEvent,
      valueChanged: leftEvent?.value !== rightEvent?.value || leftEvent?.action !== rightEvent?.action,
      sourceChanged: leftEvent?.source?.file !== rightEvent?.source?.file,
    });
  }

  const leftMutations = new Map(left.runtimeMutations.map(item => [mutationKey(item), item]));
  const rightMutations = new Map(right.runtimeMutations.map(item => [mutationKey(item), item]));
  return {
    schemaVersion: 1,
    comparisonMode: 'definition-history',
    catalog: left.catalog,
    id: left.id,
    complete: left.complete && right.complete,
    status: !left.found || !right.found
      ? 'missing'
      : left.complete && right.complete
        ? 'complete'
        : 'incomplete',
    runtimeScanComplete: Boolean(left.runtimeScan?.complete && right.runtimeScan?.complete),
    left,
    right,
    fieldDifferences,
    runtimeDifferences: {
      onlyLeft: [...leftMutations.entries()]
        .filter(([key]) => !rightMutations.has(key))
        .map(([, value]) => value),
      onlyRight: [...rightMutations.entries()]
        .filter(([key]) => !leftMutations.has(key))
        .map(([, value]) => value),
    },
  };
}
