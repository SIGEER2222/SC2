/**
 * Mod 加载：扫描 <mod>/Base.SC2Data/GameData/ 下所有 XML（递归，含
 * Commanders/ 等子目录），宽容解析后合并进 CatalogStore。
 */
import fs from 'node:fs';
import path from 'node:path';
import { decodeBuffer, parseCatalogXml } from './lenientXml.mjs';
import { catalogForTag } from './catalog.mjs';

/** 大小写不敏感地定位 mod 的 GameData 目录 */
export function findGameDataDir(modRoot) {
  const tryDirs = [
    path.join(modRoot, 'Base.SC2Data', 'GameData'),
    path.join(modRoot, 'base.sc2data', 'gamedata'),
  ];
  for (const d of tryDirs) {
    if (fs.existsSync(d) && fs.statSync(d).isDirectory()) return d;
  }
  // 兜底：枚举一层目录做大小写无关匹配
  try {
    for (const base of fs.readdirSync(modRoot)) {
      if (base.toLowerCase() !== 'base.sc2data') continue;
      const baseDir = path.join(modRoot, base);
      for (const gd of fs.readdirSync(baseDir)) {
        if (gd.toLowerCase() === 'gamedata') {
          const p = path.join(baseDir, gd);
          if (fs.statSync(p).isDirectory()) return p;
        }
      }
    }
  } catch { /* ignore */ }
  return null;
}

export function collectXmlFiles(dir, out = []) {
  for (const name of fs.readdirSync(dir)) {
    const p = path.join(dir, name);
    const st = fs.statSync(p);
    if (st.isDirectory()) collectXmlFiles(p, out);
    else if (name.toLowerCase().endsWith('.xml')) out.push(p);
  }
  return out.sort((a, b) => a.localeCompare(b));
}

/**
 * 读取单个 mod 的所有 GameData 条目，不执行合并。
 */
export function readModCatalog(modRoot) {
  const fileIssues = [];
  const consts = [];
  const allEntries = [];
  const warnings = [];
  const gd = findGameDataDir(modRoot);
  if (!gd) {
    warnings.push(`未找到 GameData 目录: ${modRoot}`);
    return { files: [], fileIssues, consts, entries: [], warnings };
  }
  const files = collectXmlFiles(gd);
  for (const file of files) {
    let text;
    try {
      ({ text } = decodeBuffer(fs.readFileSync(file)));
    } catch (e) {
      fileIssues.push({ file, line: 1, col: 1, code: 'XML_PARSE_ERROR', message: `读取失败: ${e.message}` });
      continue;
    }
    const { entries: parsedEntries, consts: fileConsts, issues } = parseCatalogXml(text, file);
    for (const issue of issues) fileIssues.push({ file, ...issue });
    for (const c of fileConsts) consts.push(c);
    allEntries.push(...parsedEntries);
  }
  return { files, fileIssues, consts, entries: allEntries, warnings };
}

/**
 * 加载单个 mod 的所有 GameData XML 并合并进 store。
 * @param {string} modRoot mod 根目录（*.SC2Mod / *.SC2Map）
 * @param {import('./catalog.mjs').CatalogStore} store
 * @returns {{ files: string[], fileIssues: {file,line,col,code,message}[], consts: object[], warnings: string[] }}
 */
export function loadModIntoStore(modRoot, store) {
  const loaded = readModCatalog(modRoot);
  const { files, fileIssues, consts, entries, warnings } = loaded;
  // 本 mod 内已见过的 (catalog, id) → 首次定义位置（用于 XML_DUPLICATE_ID）
  const seenInMod = new Map();
  for (const elem of entries) {
      const catalog = catalogForTag(elem.tag);
      if (!catalog) continue; // 非 C* 顶层元素（如注释残留），跳过
      if (!elem.attrs.id) continue; // 无 id 的顶层元素对引擎无意义
      const key = `${catalog}\u0000${elem.attrs.id}`;

      // 类冲突：同 catalog 同 id，但类 tag 不同（引擎/编辑器都会出问题）
      const existing = store.getEntry(catalog, elem.attrs.id);
      if (existing && existing.tag !== elem.tag) {
        fileIssues.push({
          file: elem.file, line: elem.line, col: elem.col, code: 'XML_ID_CLASS_CONFLICT',
          message: `${catalog} "${elem.attrs.id}" 已定义为 ${existing.tag}` +
            `（${path.basename(existing.sources[0].file)}:${existing.sources[0].line}），此处又定义为 ${elem.tag}`,
        });
      } else if (seenInMod.has(key)) {
        const first = seenInMod.get(key);
        fileIssues.push({
          file: elem.file, line: elem.line, col: elem.col, code: 'XML_DUPLICATE_ID',
          message: `${catalog} "${elem.attrs.id}" 在本 mod 内重复定义` +
            `（首见 ${path.basename(first.file)}:${first.line}，已按引擎语义合并）`,
        });
      }
      if (!seenInMod.has(key)) seenInMod.set(key, { file: elem.file, line: elem.line });
      store.addEntry(elem);
  }
  return { files, fileIssues, consts, warnings };
}
