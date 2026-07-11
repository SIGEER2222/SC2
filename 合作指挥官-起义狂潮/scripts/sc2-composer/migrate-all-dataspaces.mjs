#!/usr/bin/env node
/**
 * 一次性批量迁移工具：为所有 SC2Mod 创建数据空间主入口和 DataCenter.json
 *
 * 迁移规则：
 *   1. 如果 mod 没有 Base.SC2Data/GameData.xml 主入口，但有 Base.SC2Data/GameData/*.xml
 *      文件，则创建主入口（<Includes><Catalog path="GameData/X.xml"/></Includes>）
 *   2. 如果 Base.SC2Data/GameData/GameData.xml 存在且为空 <Catalog/>，且有其他 *.xml
 *      文件，则创建主入口并删除旧 GameData/GameData.xml
 *   3. 扫描每个数据空间 XML 的 Catalog 元素，生成 DataCenter.json
 *
 * 用法：node migrate-all-dataspaces.mjs [--dry-run] [--project-root <path>]
 */

import { readFileSync, existsSync, readdirSync, writeFileSync, unlinkSync, mkdirSync } from 'node:fs';
import { join, basename, dirname, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseXml, decodeBuffer, extractIncludes, isEmptyCatalog } from './src/xmlLite.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const force = args.includes('--force');
const projectRootIdx = args.indexOf('--project-root');
const projectRootArg = projectRootIdx >= 0 ? args[projectRootIdx + 1] : null;
const projectRoot = projectRootArg || findProjectRoot();

function findProjectRoot() {
  let dir = __dirname;
  for (let i = 0; i < 6; i++) {
    if (existsSync(join(dir, 'Mods'))) return dir;
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return process.cwd();
}

const modsDir = join(projectRoot, 'Mods');

function listSc2ModsRecursive(rootDir) {
  const result = [];
  if (!existsSync(rootDir)) return result;
  const scan = (dir, depth) => {
    if (depth > 3) return;
    const entries = readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      const full = join(dir, entry.name);
      if (entry.name.endsWith('.SC2Mod')) {
        result.push(full);
      } else {
        scan(full, depth + 1);
      }
    }
  };
  scan(rootDir, 0);
  return result;
}

function readXml(path) {
  if (!existsSync(path)) return null;
  const buf = readFileSync(path);
  const { text } = decodeBuffer(buf);
  return parseXml(text, path);
}

const CATALOG_PREFIXES = [
  'CUnit', 'CAbil', 'CButton', 'CActor', 'CEffect', 'CBehavior',
  'CUpgrade', 'CRequirement', 'CWeapon', 'CMover', 'CModel', 'CRace',
  'CTurret', 'CSound', 'CCamera', 'CLight', 'CDoodad', 'CUnitSplat',
  'CFootprint', 'CGame',
];

function isCatalogTag(tag) {
  if (!tag || tag[0] !== 'C') return false;
  return CATALOG_PREFIXES.some((prefix) =>
    tag === prefix || (tag.startsWith(prefix) && tag.length > prefix.length),
  );
}

function analyzeCatalog(roots) {
  const tagToIds = new Map();
  const visit = (nodes) => {
    for (const node of nodes) {
      if (isCatalogTag(node.tag) && node.attrs?.id) {
        if (!tagToIds.has(node.tag)) tagToIds.set(node.tag, []);
        tagToIds.get(node.tag).push(node.attrs.id);
      }
      if (node.children?.length) visit(node.children);
    }
  };
  visit(roots);
  return tagToIds;
}

// 将具体 Catalog 类型归并到父类型（CAbilArmMagazine -> CAbil）
function toParentType(tag) {
  for (const prefix of CATALOG_PREFIXES) {
    if (tag === prefix) return prefix;
    if (tag.startsWith(prefix) && tag.length > prefix.length) return prefix;
  }
  return tag;
}

// 根据 mod 名推断数据中心类型
function inferDataCenterType(modName) {
  if (modName === 'CoreRuntime.SC2Mod' || modName === 'CoopZeroPop.SC2Mod') return 'PlatformDataCenter';
  if (modName === 'BaseCatalogPatch.SC2Mod' || modName === 'SharedUnits.SC2Mod' || modName === 'ExternalRefs.SC2Mod' || modName === 'CommanderBridge.SC2Mod') return 'CapabilityDataCenter';
  if (modName === 'RebornBridge.SC2Mod' || modName === 'RebornMapAdapter.SC2Mod') return 'MapFamilyDataCenter';
  if (modName.startsWith('CommanderUnits_')) return 'CommanderDataCenter';
  if (modName.startsWith('Alenger') && !modName.includes('Adapter') && !modName.includes('Runtime')) return 'CommanderDataCenter';
  if (modName.startsWith('Alenger') && modName.includes('Adapter')) return 'CapabilityDataCenter';
  if (modName === 'AlengerCommon.SC2Mod') return 'CapabilityDataCenter';
  if (modName === 'Alenger8Runtime.SC2Mod') return 'CapabilityDataCenter';
  if (modName === 'kit_mutations.SC2Mod' || modName === 'kit_rogue_talents.SC2Mod' || modName === 'HexTalents.SC2Mod') return 'CapabilityDataCenter';
  if (modName === 'crys_the_swarm_reborn.SC2Mod') return 'MapFamilyDataCenter';
  return 'CapabilityDataCenter';
}

// 根据 mod 名推断数据中心 ID
function inferDataCenterId(modName, type) {
  const base = modName.replace(/\.SC2Mod$/, '');
  if (type === 'CommanderDataCenter') {
    // CommanderUnits_Raynor -> Commander.TerranRaynor（简化为 Commander.Raynor）
    if (base.startsWith('CommanderUnits_')) {
      const name = base.slice('CommanderUnits_'.length);
      return `Commander.${name}`;
    }
    // Alenger1 -> Commander.Alenger1
    return `Commander.${base}`;
  }
  if (type === 'MapFamilyDataCenter') {
    if (base === 'RebornBridge') return 'MapFamily.RebornHotS';
    if (base === 'RebornMapAdapter') return 'MapFamily.RebornHotSAdapter';
    if (base === 'crys_the_swarm_reborn') return 'MapFamily.CrysReborn';
    return `MapFamily.${base}`;
  }
  if (type === 'PlatformDataCenter') {
    if (base === 'CoreRuntime') return 'Platform.CoreRuntime';
    if (base === 'CoopZeroPop') return 'Platform.CoopZeroPop';
    return `Platform.${base}`;
  }
  // CapabilityDataCenter
  return `Capability.${base}`;
}

function generateGameDataXml(spaces) {
  if (spaces.length === 0) {
    return '<?xml version="1.0" encoding="utf-8"?>\n<Catalog/>\n';
  }
  const lines = ['<?xml version="1.0" encoding="utf-8"?>', '<Includes>'];
  for (const space of spaces) {
    lines.push(`  <Catalog path="${space.path}"/>`);
  }
  lines.push('</Includes>', '');
  return lines.join('\n');
}

function generateDataCenterJson(modDir, modName, spaces, tagToIdMap) {
  const type = inferDataCenterType(modName);
  const id = inferDataCenterId(modName, type);

  // 构建 exports
  const exports = {};
  const exportMap = {
    units: 'CUnit',
    abilities: 'CAbil',
    upgrades: 'CUpgrade',
    behaviors: 'CBehavior',
    effects: 'CEffect',
    buttons: 'CButton',
    requirements: 'CRequirement',
  };
  for (const [exportKey, catalogType] of Object.entries(exportMap)) {
    const ids = tagToIdMap.get(catalogType) || [];
    if (ids.length > 0) exports[exportKey] = ids;
  }

  const dc = {
    schemaVersion: 1,
    id,
    type,
    gameDataEntry: 'Base.SC2Data/GameData.xml',
    migrationStatus: 'complete',
    spaces,
  };
  if (Object.keys(exports).length > 0) dc.exports = exports;

  return JSON.stringify(dc, null, 2) + '\n';
}

function processMod(modDir) {
  const modName = basename(modDir);
  const gameDataRootPath = join(modDir, 'Base.SC2Data', 'GameData.xml');
  const gameDataDir = join(modDir, 'Base.SC2Data', 'GameData');

  // 收集 GameData/*.xml 文件
  let gameDataFiles = [];
  if (existsSync(gameDataDir)) {
    gameDataFiles = readdirSync(gameDataDir)
      .filter((f) => f.endsWith('.xml'))
      .sort();
  }

  if (gameDataFiles.length === 0) {
    return { modName, action: 'skip', reason: 'no GameData/*.xml files' };
  }

  // 检查现有主入口
  const existingRoot = readXml(gameDataRootPath);
  const rootExists = existsSync(gameDataRootPath);

  // 过滤掉空 GameData.xml（在 GameData/ 目录下）
  // 注意：GameData/GameData.xml 如果非空（包含 CGame 等元素），需要作为数据空间包含
  const realDataFiles = gameDataFiles.filter((f) => f !== 'GameData.xml');

  // 检查 GameData/GameData.xml 是否为空
  const oldGameDataPath = join(gameDataDir, 'GameData.xml');
  const oldGameDataExists = gameDataFiles.includes('GameData.xml');
  let oldGameDataIsEmpty = false;
  let oldGameDataHasContent = false;
  if (oldGameDataExists) {
    const oldXml = readXml(oldGameDataPath);
    if (oldXml && isEmptyCatalog(oldXml.roots)) {
      oldGameDataIsEmpty = true;
    } else if (oldXml && oldXml.roots.length > 0) {
      oldGameDataHasContent = true;
    }
  }

  // 构建 spaces 列表
  const spaces = [];
  const tagToIdMap = new Map();

  // 如果 GameData/GameData.xml 非空，将其作为数据空间包含
  if (oldGameDataHasContent) {
    const path = 'GameData/GameData.xml';
    const xml = readXml(oldGameDataPath);
    const tagIds = analyzeCatalog(xml.roots);
    const owns = [...new Set([...tagIds.keys()].map(toParentType))];
    const catalogIds = {};
    for (const [tag, ids] of tagIds) {
      const parentTag = toParentType(tag);
      if (!catalogIds[parentTag]) catalogIds[parentTag] = [];
      catalogIds[parentTag].push(...ids);
    }
    spaces.push({
      path,
      owns: owns.length > 0 ? owns : ['CGame'],
      catalogIds: Object.keys(catalogIds).length > 0
        ? Object.entries(catalogIds).flatMap(([_, ids]) => ids)
        : [],
    });
    for (const [tag, ids] of tagIds) {
      if (!tagToIdMap.has(tag)) tagToIdMap.set(tag, []);
      tagToIdMap.get(tag).push(...ids);
    }
  }

  for (const file of realDataFiles) {
    const path = `GameData/${file}`;
    const xml = readXml(join(gameDataDir, file));
    if (!xml) continue;
    const tagIds = analyzeCatalog(xml.roots);
    const owns = [...new Set([...tagIds.keys()].map(toParentType))];
    const catalogIds = {};
    for (const [tag, ids] of tagIds) {
      const parentTag = toParentType(tag);
      if (!catalogIds[parentTag]) catalogIds[parentTag] = [];
      catalogIds[parentTag].push(...ids);
    }
    spaces.push({
      path,
      owns: owns.length > 0 ? owns : ['CUnit'],
      catalogIds: Object.keys(catalogIds).length > 0
        ? Object.entries(catalogIds).flatMap(([_, ids]) => ids)
        : [],
    });
    // 合并到总 map
    for (const [tag, ids] of tagIds) {
      if (!tagToIdMap.has(tag)) tagToIdMap.set(tag, []);
      tagToIdMap.get(tag).push(...ids);
    }
  }

  const actions = [];

  // 1. 创建/更新主入口 GameData.xml
  const existingIncludes = existingRoot ? extractIncludes(existingRoot.roots) : [];
  const shouldRegenerate = !rootExists || existingIncludes.length === 0 || force;
  if (shouldRegenerate) {
    const content = generateGameDataXml(spaces);
    if (!dryRun) {
      mkdirSync(join(modDir, 'Base.SC2Data'), { recursive: true });
      writeFileSync(gameDataRootPath, content, 'utf8');
    }
    actions.push(`created GameData.xml with ${spaces.length} includes`);
  } else {
    actions.push(`GameData.xml already exists with ${existingIncludes.length} includes`);
  }

  // 2. 删除旧的空 GameData/GameData.xml（只要为空就删除，不论是否有其他数据文件）
  if (oldGameDataExists && oldGameDataIsEmpty) {
    if (!dryRun) {
      unlinkSync(oldGameDataPath);
    }
    actions.push(`removed empty GameData/GameData.xml`);
  }

  // 3. 创建/更新 DataCenter.json
  const dataCenterPath = join(modDir, 'DataCenter.json');
  if (!existsSync(dataCenterPath) || force) {
    const content = generateDataCenterJson(modDir, modName, spaces, tagToIdMap);
    if (!dryRun) {
      writeFileSync(dataCenterPath, content, 'utf8');
    }
    actions.push(`created DataCenter.json (${spaces.length} spaces)`);
  } else {
    actions.push(`DataCenter.json already exists`);
  }

  return { modName, action: 'processed', details: actions, spaces: spaces.length };
}

function main() {
  console.log(`=== migrate-all-dataspaces ===`);
  console.log(`Project root: ${projectRoot}`);
  console.log(`Mode: ${dryRun ? 'DRY RUN' : 'APPLY'}`);
  console.log();

  const mods = listSc2ModsRecursive(modsDir);
  console.log(`Found ${mods.length} SC2Mods\n`);

  const results = [];
  for (const modDir of mods) {
    const result = processMod(modDir);
    results.push(result);
    const status = result.action === 'skip' ? 'SKIP' : 'DONE';
    console.log(`[${status}] ${result.modName}`);
    if (result.details) {
      for (const d of result.details) console.log(`  - ${d}`);
    }
    if (result.reason) console.log(`  reason: ${result.reason}`);
  }

  console.log(`\n=== Summary ===`);
  const processed = results.filter((r) => r.action === 'processed');
  const skipped = results.filter((r) => r.action === 'skip');
  console.log(`Processed: ${processed.length}`);
  console.log(`Skipped: ${skipped.length}`);
  if (dryRun) console.log('(DRY RUN - no files were modified)');
}

main();
