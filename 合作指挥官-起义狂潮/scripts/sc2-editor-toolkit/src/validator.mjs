/**
 * 跨文件引用校验器（模拟银河编辑器"数据完整性"检查）
 *
 * 流程：
 *   1. 按依赖顺序合并所有 mod（--deps 的 mod 只提供定义，不产生报告，
 *      对应编辑器"依赖不检查，只检查当前文档"的行为）
 *   2. 对目标 mod 的每个条目提取跨 catalog 引用并解析
 *   3. dangling reference / parent 缺失 / parent 环 / const 缺失 → issue
 */
import path from 'node:path';
import { CatalogStore } from './catalog.mjs';
import { loadModIntoStore } from './modLoader.mjs';
import { extractRefs } from './refRules.mjs';

export const DEFAULT_SEVERITY = {
  XML_PARSE_ERROR: 'error',
  XML_ENCODING_MISMATCH: 'info',
  XML_MISSING_CATALOG_ROOT: 'warning',
  XML_DUPLICATE_ID: 'info',
  XML_ID_CLASS_CONFLICT: 'error',
  XML_DANGLING_REF: 'error',
  XML_CIRCULAR_PARENT: 'error',
  XML_DANGLING_CONST: 'warning',
  XML_MISSING_GAMEDATA: 'warning',
};

const CONST_TOKEN_RE = /\$([\w@/.\-]+)\$/g;

function normalizeRoot(p) {
  return path.resolve(p).toLowerCase().replace(/[\\/]+$/, '') + path.sep;
}

/**
 * @param {object} opts
 * @param {string[]} opts.targetMods 被校验的 mod 路径（依赖顺序，后覆盖前）
 * @param {string[]} [opts.depMods]  仅提供定义的依赖 mod（在 targetMods 之前合并）
 * @param {object}   [opts.ruleConfig] { rules: { CODE: { severity: 'error'|'warning'|'info'|'off' } } }
 * @returns {{ filesChecked:number, issues:object[], stats:object, store:CatalogStore }}
 */
export function validate({ targetMods, depMods = [], ruleConfig = {} }) {
  const severityOf = (code) =>
    ruleConfig?.rules?.[code]?.severity ?? DEFAULT_SEVERITY[code] ?? 'warning';

  const issues = [];
  const cwd = process.cwd();
  const push = (code, file, line, col, message) => {
    const severity = severityOf(code);
    if (severity === 'off') return;
    const rel = path.relative(cwd, file);
    issues.push({
      file: rel && !rel.startsWith('..') ? rel : file,
      line: line ?? 0,
      column: col ?? 0,
      ruleCode: code,
      severity,
      message,
    });
  };

  const store = new CatalogStore();
  const consts = new Map(); // id → value（全链可见）
  let filesChecked = 0;
  const targetRoots = targetMods.map(normalizeRoot);
  const isTargetFile = (file) => {
    const f = path.resolve(file).toLowerCase();
    return targetRoots.some(r => f.startsWith(r));
  };

  // ---- 阶段 1：按依赖顺序合并 ----
  for (const { mods, isDep } of [
    { mods: depMods, isDep: true },
    { mods: targetMods, isDep: false },
  ]) {
    for (const mod of mods) {
      const { files, fileIssues, consts: modConsts, warnings } = loadModIntoStore(mod, store);
      if (!isDep) {
        filesChecked += files.length;
        for (const w of warnings) push('XML_MISSING_GAMEDATA', mod, 1, 1, w);
        for (const fi of fileIssues) push(fi.code, fi.file, fi.line, fi.col, fi.message);
      }
      // 依赖 mod 的解析问题不进入报告（编辑器行为），但 const 定义全链可见
      for (const c of modConsts) {
        if (c.attrs.id) consts.set(c.attrs.id, c.attrs.value ?? '');
      }
    }
  }

  // ---- 阶段 2：引用校验（只报告目标 mod 文件中的引用出处）----
  const stats = {
    entries: 0,
    entriesChecked: 0,
    refsChecked: 0,
    dangling: 0,
    byTargetCatalog: {},
    catalogSizes: {},
  };
  for (const [catalog, map] of store.catalogs) {
    stats.catalogSizes[catalog] = map.size;
    stats.entries += map.size;
  }

  const seenIssueKeys = new Set();
  for (const [catalog, map] of store.catalogs) {
    for (const entry of map.values()) {
      // parent 环检测（条目归属于目标 mod 时才报告）
      const ownedByTarget = entry.sources.some(s => isTargetFile(s.file));
      if (!ownedByTarget) continue;
      stats.entriesChecked++;

      const { circular } = store.parentChain(catalog, entry.id);
      if (circular) {
        const src = entry.sources[0];
        push('XML_CIRCULAR_PARENT', src.file, src.line, 1,
          `${catalog} "${entry.id}" 的 parent 链存在循环`);
      }

      for (const ref of extractRefs(entry.node)) {
        if (!isTargetFile(ref.file)) continue; // 引用出处在依赖 mod 中：不报告
        const targetCatalog = ref.target === '#same' ? catalog : ref.target;
        stats.refsChecked++;
        if (store.has(targetCatalog, ref.id)) continue;
        stats.dangling++;
        stats.byTargetCatalog[targetCatalog] = (stats.byTargetCatalog[targetCatalog] ?? 0) + 1;
        const key = `${ref.file}\u0000${ref.line}\u0000${targetCatalog}\u0000${ref.id}\u0000${ref.via}`;
        if (seenIssueKeys.has(key)) continue;
        seenIssueKeys.add(key);
        push('XML_DANGLING_REF', ref.file, ref.line, 1,
          `${entry.tag} "${entry.id}" 的 ${ref.via} 引用了不存在的 ${targetCatalog} "${ref.id}"`);
      }

      // const 引用校验（$xxx$）
      const walkConst = (node) => {
        if (!isTargetFile(node.file)) {
          for (const child of node.children) walkConst(child);
          return;
        }
        for (const [attr, value] of Object.entries(node.attrs)) {
          if (!value.includes('$')) continue;
          CONST_TOKEN_RE.lastIndex = 0;
          let m;
          while ((m = CONST_TOKEN_RE.exec(value)) !== null) {
            if (consts.has(m[1])) continue;
            const key = `${node.file}\u0000${node.line}\u0000const\u0000${m[1]}`;
            if (seenIssueKeys.has(key)) continue;
            seenIssueKeys.add(key);
            push('XML_DANGLING_CONST', node.file, node.line, 1,
              `${entry.tag} "${entry.id}" 的 ${node.tag}/@${attr} 引用了未定义的常量 $${m[1]}$`);
          }
        }
        for (const child of node.children) walkConst(child);
      };
      walkConst(entry.node);
    }
  }

  return { filesChecked, issues, stats, store };
}
