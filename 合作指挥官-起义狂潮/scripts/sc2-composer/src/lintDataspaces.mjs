/**
 * 数据空间 linter：扫描 SC2Mod 目录，检查 DataCenter manifest 和数据空间使用情况。
 *
 * 检查项：
 *   DC-001  DataCenter.json 不存在（warning：未迁移）
 *   DC-002  DataCenter.json schema 验证失败（error）
 *   DC-003  数据空间 XML 文件不存在（error）
 *   DC-004  GameData.xml 使用 <Includes> 但有未引用的 GameData/*.xml（warning：混用风险）
 *   DC-005  数据空间 owns 声明的 Catalog 类型与实际 XML 不匹配（warning）
 *   DC-006  exports 声明的 catalog ID 在数据空间中未定义（error）
 *   DC-007  GameData.xml 为空 <Catalog/> 但有 GameData/*.xml 文件（info：未迁移，使用自动加载）
 *   DC-008  DataCenter.json 声明的 space.path 不在 gameDataEntry 的 <Includes> 中（error）
 */

import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { join, relative, basename, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseXml, decodeBuffer, findAll, isEmptyCatalog, extractIncludes } from './xmlLite.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/** @typedef {{ code: string, severity: 'error'|'warning'|'info', message: string, file?: string, line?: number }} Issue */

/**
 * 列出目录下所有 SC2Mod 子目录（递归 1 层）。
 * @param {string} baseDir
 * @returns {string[]}
 */
export function listSc2Mods(baseDir) {
  if (!existsSync(baseDir)) return [];
  return readdirSync(baseDir)
    .filter((name) => name.endsWith('.SC2Mod'))
    .map((name) => join(baseDir, name))
    .filter((p) => statSync(p).isDirectory());
}

/**
 * 递归列出目录下所有 .SC2Mod 目录（扫描子目录）。
 * @param {string} rootDir
 * @returns {string[]}
 */
export function listSc2ModsRecursive(rootDir) {
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

/**
 * 读取并解析 XML 文件。
 * @param {string} path
 * @returns {{ roots: object[], issues: object[] } | null}
 */
function readXmlFile(path) {
  if (!existsSync(path)) return null;
  const buf = readFileSync(path);
  const { text } = decodeBuffer(buf);
  return parseXml(text, path);
}

/**
 * 提取 XML 文件中所有 Catalog 元素的 id 属性。
 * @param {object[]} roots
 * @returns {{ types: Set<string>, ids: Map<string, string[]> }}
 */
function analyzeCatalogElements(roots) {
  const types = new Set();
  const ids = new Map(); // type -> [id, ...]

  // Catalog 父类型前缀列表：以这些前缀开头的标签都视为 Catalog 元素
  // 例如 CAbil 匹配 CAbilArmMagazine、CAbilBuild、CAbilEffect 等
  const CATALOG_PREFIXES = [
    'CUnit', 'CAbil', 'CButton', 'CActor', 'CEffect', 'CBehavior',
    'CUpgrade', 'CRequirement', 'CWeapon', 'CMover', 'CModel', 'CRace',
    'CTurret', 'CSound', 'CCamera', 'CLight', 'CDoodad', 'CUnitSplat',
    'CFootprint', 'CGame',
  ];

  const isCatalogTag = (tag) => {
    if (!tag || tag[0] !== 'C') return false;
    return CATALOG_PREFIXES.some((prefix) =>
      tag === prefix || (tag.startsWith(prefix) && tag.length > prefix.length),
    );
  };

  const visit = (nodes) => {
    for (const node of nodes) {
      if (isCatalogTag(node.tag)) {
        types.add(node.tag);
        if (node.attrs.id) {
          if (!ids.has(node.tag)) ids.set(node.tag, []);
          ids.get(node.tag).push(node.attrs.id);
        }
      }
      if (node.children?.length) visit(node.children);
    }
  };
  visit(roots);
  return { types, ids };
}

/**
 * 验证 DataCenter.json 是否符合基本 schema 要求。
 * @param {any} data
 * @returns {string[]} 错误消息列表
 */
function validateDataCenterSchema(data) {
  const errors = [];
  if (typeof data !== 'object' || data === null) {
    errors.push('DataCenter.json 不是有效 JSON 对象');
    return errors;
  }
  const required = ['schemaVersion', 'id', 'type', 'gameDataEntry', 'spaces'];
  for (const field of required) {
    if (!(field in data)) errors.push(`缺少必填字段: ${field}`);
  }
  if (data.schemaVersion !== undefined && data.schemaVersion !== 1) {
    errors.push(`schemaVersion 必须为 1，实际为 ${data.schemaVersion}`);
  }
  const validTypes = ['PlatformDataCenter', 'CapabilityDataCenter', 'CommanderDataCenter', 'MapFamilyDataCenter', 'PairPatchDataCenter'];
  if (data.type !== undefined && !validTypes.includes(data.type)) {
    errors.push(`type 无效: ${data.type}，有效值: ${validTypes.join(', ')}`);
  }
  if (data.id !== undefined && typeof data.id === 'string') {
    const idParts = data.id.split('.');
    if (idParts.length !== 2 || !/^(Platform|Capability|Commander|MapFamily|PairPatch)$/.test(idParts[0])) {
      errors.push(`id 格式无效: ${data.id}，应为 <type>.<Name>`);
    }
  }
  if (data.spaces !== undefined && Array.isArray(data.spaces)) {
    data.spaces.forEach((space, i) => {
      if (!space.path) errors.push(`spaces[${i}].path 缺失`);
      if (!Array.isArray(space.owns) || space.owns.length === 0) {
        errors.push(`spaces[${i}].owns 必须是非空数组`);
      }
    });
  }
  return errors;
}

/**
 * Lint 单个 SC2Mod。
 * @param {string} modDir
 * @returns {Promise<Issue[]>}
 */
export async function lintMod(modDir) {
  /** @type {Issue[]} */
  const issues = [];
  const modName = basename(modDir);

  // 1. 读取 GameData.xml（默认位置 Base.SC2Data/GameData.xml）
  let gameDataPath = join(modDir, 'Base.SC2Data', 'GameData.xml');
  const gameDataDir = join(modDir, 'Base.SC2Data', 'GameData');

  // 收集 GameData/*.xml 文件（自动加载的文件）
  let autoLoadedFiles = [];
  if (existsSync(gameDataDir)) {
    autoLoadedFiles = readdirSync(gameDataDir)
      .filter((f) => f.endsWith('.xml'))
      .map((f) => `GameData/${f}`);
  }

  let gameDataXml = readXmlFile(gameDataPath);
  let gameDataExists = existsSync(gameDataPath);

  // 2. 读取 DataCenter.json
  const dataCenterPath = join(modDir, 'DataCenter.json');
  let dataCenter = null;
  if (existsSync(dataCenterPath)) {
    try {
      dataCenter = JSON.parse(readFileSync(dataCenterPath, 'utf8'));
    } catch (e) {
      issues.push({
        code: 'DC-002',
        severity: 'error',
        message: `DataCenter.json 解析失败: ${e.message}`,
        file: dataCenterPath,
      });
    }
  } else {
    // 没有 DataCenter.json：检查是否需要迁移
    if (gameDataExists && autoLoadedFiles.length > 0) {
      const isEmpty = gameDataXml ? isEmptyCatalog(gameDataXml.roots) : true;
      if (isEmpty) {
        issues.push({
          code: 'DC-007',
          severity: 'info',
          message: `GameData.xml 为空 <Catalog/>，${autoLoadedFiles.length} 个 XML 文件使用自动加载（未迁移到数据空间）`,
          file: gameDataPath,
        });
      }
    }
    return issues;
  }

  // 3. 验证 DataCenter.json schema
  const schemaErrors = validateDataCenterSchema(dataCenter);
  for (const err of schemaErrors) {
    issues.push({
      code: 'DC-002',
      severity: 'error',
      message: err,
      file: dataCenterPath,
    });
  }
  if (schemaErrors.length > 0) return issues;

  // 3.5. 如果 DataCenter.json 声明了 gameDataEntry，使用它指定的路径
  const gameDataEntryRel = dataCenter.gameDataEntry || 'Base.SC2Data/GameData.xml';
  const gameDataEntryPath = join(modDir, gameDataEntryRel);
  if (gameDataEntryPath !== gameDataPath) {
    gameDataPath = gameDataEntryPath;
    gameDataXml = readXmlFile(gameDataPath);
    gameDataExists = existsSync(gameDataPath);
  }

  // 4. 验证数据空间文件存在性和 owns 匹配
  const includes = gameDataXml ? extractIncludes(gameDataXml.roots) : [];

  for (let i = 0; i < dataCenter.spaces.length; i++) {
    const space = dataCenter.spaces[i];
    const spacePath = join(modDir, 'Base.SC2Data', space.path);
    if (!existsSync(spacePath)) {
      issues.push({
        code: 'DC-003',
        severity: 'error',
        message: `数据空间文件不存在: ${space.path}`,
        file: dataCenterPath,
      });
      continue;
    }

    // DC-008: 检查 space.path 是否在 GameData.xml 的 <Includes> 中
    const normalizedSpacePath = space.path.replace(/\\/g, '/');
    if (includes.length > 0 && !includes.includes(normalizedSpacePath)) {
      issues.push({
        code: 'DC-008',
        severity: 'error',
        message: `数据空间 ${space.path} 未在 ${relative(modDir, gameDataPath)} 的 <Includes> 中引用`,
        file: gameDataPath,
      });
    }

    // DC-005: 检查 owns 与实际 XML 中的 Catalog 类型匹配
    // 支持类型继承：owns 声明父类型（如 CAbil）匹配子类型（如 CAbilArmMagazine）
    const spaceXml = readXmlFile(spacePath);
    if (spaceXml) {
      const { types, ids } = analyzeCatalogElements(spaceXml.roots);
      const declaredOwns = space.owns;

      // 判断 actual tag 是否被 declared owns 覆盖（精确匹配或前缀匹配）
      const isOwned = (actualTag) => {
        if (declaredOwns.includes(actualTag)) return true;
        // 前缀匹配：CAbil 匹配 CAbilArmMagazine
        return declaredOwns.some(decl => actualTag.startsWith(decl) && actualTag.length > decl.length);
      };

      for (const actual of types) {
        if (!isOwned(actual)) {
          issues.push({
            code: 'DC-005',
            severity: 'warning',
            message: `数据空间 ${space.path} 声明 owns=[${declaredOwns.join(',')}]，但实际包含 ${actual} 元素`,
            file: spacePath,
          });
        }
      }
      // 反向检查：声明的 owns 是否有对应的实际元素（有 catalogIds 时才报）
      for (const declared of declaredOwns) {
        const hasMatch = Array.from(types).some(t => t === declared || t.startsWith(declared));
        if (!hasMatch && space.catalogIds?.length) {
          issues.push({
            code: 'DC-005',
            severity: 'warning',
            message: `数据空间 ${space.path} 声明 owns=${declared}，但文件中无 ${declared}* 元素`,
            file: spacePath,
          });
        }
      }

      // DC-006: 检查 exports 中的 catalog IDs 是否在数据空间中定义
      // (在所有 space 扫描完后统一检查，这里先收集)
      space._actualIds = ids;
    }
  }

  // DC-006: 验证 exports 中的 IDs
  if (dataCenter.exports) {
    const allDefinedIds = new Set();
    for (const space of dataCenter.spaces) {
      if (space._actualIds) {
        for (const ids of space._actualIds.values()) {
          for (const id of ids) allDefinedIds.add(id);
        }
      }
    }

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
      const exportedIds = dataCenter.exports[exportKey];
      if (!Array.isArray(exportedIds)) continue;
      for (const exportedId of exportedIds) {
        if (!allDefinedIds.has(exportedId)) {
          issues.push({
            code: 'DC-006',
            severity: 'error',
            message: `exports.${exportKey} 声明了 "${exportedId}"，但在数据空间中未找到 ${catalogType} id="${exportedId}" 的定义`,
            file: dataCenterPath,
          });
        }
      }
    }
  }

  // DC-004: 检查混用问题
  if (includes.length > 0 && autoLoadedFiles.length > 0) {
    const includedSet = new Set(includes.map((p) => p.replace(/\\/g, '/')));
    const unreferenced = autoLoadedFiles.filter((f) => {
      const normalized = f.replace(/\\/g, '/');
      return !includedSet.has(normalized);
    });
    if (unreferenced.length > 0) {
      issues.push({
        code: 'DC-004',
        severity: 'warning',
        message: `GameData.xml 使用 <Includes> 但有 ${unreferenced.length} 个未引用的 GameData/*.xml（可能混用数据空间和自动加载）: ${unreferenced.slice(0, 5).join(', ')}${unreferenced.length > 5 ? '...' : ''}`,
        file: gameDataPath,
      });
    }
  }

  return issues;
}

/**
 * Lint 整个项目的 Mods 目录。
 * @param {string} projectRoot
 * @returns {Promise<{ modCount: number, issues: Issue[], modReports: Map<string, Issue[]> }>}
 */
export async function lintProject(projectRoot) {
  const modsDir = join(projectRoot, 'Mods');
  const modDirs = listSc2ModsRecursive(modsDir);

  const modReports = new Map();
  const allIssues = [];

  for (const modDir of modDirs) {
    const issues = await lintMod(modDir);
    if (issues.length > 0) {
      modReports.set(modDir, issues);
      allIssues.push(...issues);
    }
  }

  return {
    modCount: modDirs.length,
    issues: allIssues,
    modReports,
  };
}
