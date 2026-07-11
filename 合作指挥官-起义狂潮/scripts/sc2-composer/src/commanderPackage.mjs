/**
 * CommanderPackage 校验与提取模块
 *
 * CommanderPackage 是一个可独立选择的指挥官实现清单，描述：
 *   - commanderId / displayName：标识与显示名
 *   - dataCenter / modPath：引用的 DataCenter id 与 SC2Mod 路径
 *   - techTree：建筑/单位/升级/技能 Catalog ID 列表
 *   - runtimeHooks：Galaxy runtime 函数声明（init/applyTech/createStartSquad）
 *   - panelLayout：UI 面板布局
 *   - prestiges / masteries：威望与精通
 *   - compatibleMapFamilies / incompatibleMapFamilies：地图族兼容性
 *
 * 详见 docs/指挥官地图组合框架设计.md 第 4.3 节。
 */

import { existsSync, readFileSync } from 'node:fs';
import { join, basename } from 'node:path';

/** CommanderPackage 当前 schema 版本 */
export const PACKAGE_SCHEMA_VERSION = 1;

/**
 * 校验 CommanderPackage manifest 结构（遵循 CommanderPackage.schema.json）。
 *
 * @param {any} pkg - 待校验的 CommanderPackage 对象
 * @returns {{ valid: boolean, errors: string[] }}
 */
export function validatePackage(pkg) {
  const errors = [];

  if (typeof pkg !== 'object' || pkg === null || Array.isArray(pkg)) {
    return { valid: false, errors: ['CommanderPackage 必须是对象'] };
  }

  // schemaVersion
  if (pkg.schemaVersion === undefined) {
    errors.push('缺少必填字段: schemaVersion');
  } else if (pkg.schemaVersion !== PACKAGE_SCHEMA_VERSION) {
    errors.push(`schemaVersion 必须为 ${PACKAGE_SCHEMA_VERSION}，实际为 ${pkg.schemaVersion}`);
  }

  // commanderId（必填，非空字符串）
  if (typeof pkg.commanderId !== 'string' || pkg.commanderId.length === 0) {
    errors.push('commanderId 必须是非空字符串');
  } else if (!/^[A-Za-z][A-Za-z0-9_]*$/.test(pkg.commanderId)) {
    errors.push('commanderId 格式无效，必须以字母开头，只含字母数字下划线');
  }

  // displayName（必填，非空字符串）
  if (typeof pkg.displayName !== 'string' || pkg.displayName.length === 0) {
    errors.push('displayName 必须是非空字符串');
  }

  // dataCenter（必填，非空字符串）
  if (typeof pkg.dataCenter !== 'string' || pkg.dataCenter.length === 0) {
    errors.push('dataCenter 必须是非空字符串');
  }

  // modPath（必填，非空字符串）
  if (typeof pkg.modPath !== 'string' || pkg.modPath.length === 0) {
    errors.push('modPath 必须是非空字符串');
  }

  // techTree（必填对象）
  if (typeof pkg.techTree !== 'object' || pkg.techTree === null || Array.isArray(pkg.techTree)) {
    errors.push('techTree 必须是对象');
  } else {
    for (const f of ['buildings', 'units', 'upgrades', 'abilities']) {
      if (!Array.isArray(pkg.techTree[f])) {
        errors.push(`techTree.${f} 必须是数组`);
      } else if (!pkg.techTree[f].every((v) => typeof v === 'string' && v.length > 0)) {
        errors.push(`techTree.${f} 的每个元素必须是非空字符串`);
      }
    }
  }

  // runtimeHooks（必填对象）
  if (typeof pkg.runtimeHooks !== 'object' || pkg.runtimeHooks === null || Array.isArray(pkg.runtimeHooks)) {
    errors.push('runtimeHooks 必须是对象');
  } else {
    for (const f of ['initFunction', 'applyTechFunction', 'createStartSquadFunction']) {
      if (typeof pkg.runtimeHooks[f] !== 'string') {
        errors.push(`runtimeHooks.${f} 必须是字符串`);
      }
    }
  }

  // panelLayout（必填对象）
  if (typeof pkg.panelLayout !== 'object' || pkg.panelLayout === null || Array.isArray(pkg.panelLayout)) {
    errors.push('panelLayout 必须是对象');
  } else {
    if (!Array.isArray(pkg.panelLayout.topPanelAbilities)) {
      errors.push('panelLayout.topPanelAbilities 必须是数组');
    }
    if (!Array.isArray(pkg.panelLayout.commandCardLayouts)) {
      errors.push('panelLayout.commandCardLayouts 必须是数组');
    }
  }

  // prestiges / masteries（必填数组）
  if (!Array.isArray(pkg.prestiges)) {
    errors.push('prestiges 必须是数组');
  }
  if (!Array.isArray(pkg.masteries)) {
    errors.push('masteries 必须是数组');
  }

  // compatibleMapFamilies / incompatibleMapFamilies（必填数组）
  if (!Array.isArray(pkg.compatibleMapFamilies)) {
    errors.push('compatibleMapFamilies 必须是数组');
  }
  if (!Array.isArray(pkg.incompatibleMapFamilies)) {
    errors.push('incompatibleMapFamilies 必须是数组');
  }

  return { valid: errors.length === 0, errors };
}

/**
 * 从 commanderId 推断种族。
 *
 * 仅基于命名约定做启发式推断，未知时返回 'Unknown'。
 *
 * @param {string} commanderId
 * @returns {'Terran'|'Protoss'|'Zerg'|'Unknown'}
 */
function inferRaceFromCommanderId(commanderId) {
  if (/^Terran|^Raynor|^Mengsk|^Nova|^Warfield/i.test(commanderId)) return 'Terran';
  if (/^Protoss|^Zeratul|^Artanis|^Vorazun|^Karax|^Alarak|^Fenix|^Talandar|^Selendis|^Urun|^Mohandar|^Haven/i.test(commanderId)) return 'Protoss';
  if (/^Zerg|^Kerrigan|^Zagara|^Abathur|^Stukov|^Niadra|^Dehaka/i.test(commanderId)) return 'Zerg';
  return 'Unknown';
}

/**
 * 从 DataCenter.exports 收集所有 catalog ID（units + abilities）。
 *
 * @param {object} dataCenter
 * @returns {{ units: string[], abilities: string[] }}
 */
function collectCatalogIds(dataCenter) {
  const result = { units: [], abilities: [] };
  if (dataCenter.exports) {
    if (Array.isArray(dataCenter.exports.units)) result.units = dataCenter.exports.units;
    if (Array.isArray(dataCenter.exports.abilities)) result.abilities = dataCenter.exports.abilities;
  }
  return result;
}

/**
 * 从 DataCenter.galaxyRuntime 提取 runtimeHooks 字段。
 *
 * 字段映射：
 *   initFunction              -> initFunction
 *   applyTechFunction         -> applyTechFunction
 *   createStartSquadFunction  -> createStartSquadFunction
 *
 * @param {object} dataCenter
 * @returns {object}
 */
function extractRuntimeHooks(dataCenter) {
  const rt = dataCenter.galaxyRuntime;
  if (!rt) {
    return {
      initFunction: '',
      applyTechFunction: '',
      createStartSquadFunction: '',
    };
  }
  return {
    initFunction: rt.initFunction || '',
    applyTechFunction: rt.applyTechFunction || '',
    createStartSquadFunction: rt.createStartSquadFunction || '',
  };
}

/**
 * 从现有 SC2Mod + DataCenter.json 提取 CommanderPackage 草案。
 *
 * 要求 modPath 下存在 DataCenter.json，且 type === 'CommanderDataCenter'。
 * 提取结果仅作草案，调用方需进一步补充 panelLayout、prestiges 等。
 *
 * @param {string} modPath - SC2Mod 目录绝对路径
 * @returns {Promise<object>} CommanderPackage 草案对象（遵循 CommanderPackage.schema.json）
 * @throws {Error} DataCenter.json 缺失、解析失败或类型不符时抛错
 */
export async function extractPackageFromMod(modPath) {
  const dataCenterPath = join(modPath, 'DataCenter.json');
  if (!existsSync(dataCenterPath)) {
    throw new Error(`DataCenter.json 不存在: ${dataCenterPath}`);
  }

  let dataCenter;
  try {
    dataCenter = JSON.parse(readFileSync(dataCenterPath, 'utf8'));
  } catch (e) {
    throw new Error(`DataCenter.json 解析失败: ${e.message}`);
  }

  if (dataCenter.type !== 'CommanderDataCenter') {
    throw new Error(`DataCenter.type 必须是 CommanderDataCenter，实际为 ${dataCenter.type}`);
  }

  // 从 DataCenter.id 提取 commanderId（格式：Commander.<Name>）
  const idParts = String(dataCenter.id || '').split('.');
  if (idParts.length !== 2 || idParts[0] !== 'Commander') {
    throw new Error(`DataCenter.id 格式无效: ${dataCenter.id}，应为 Commander.<Name>`);
  }
  const commanderId = idParts[1];
  const catalogIds = collectCatalogIds(dataCenter);

  // 构建 CommanderPackage 草案（schema 格式）
  const pkg = {
    schemaVersion: PACKAGE_SCHEMA_VERSION,
    commanderId,
    displayName: commanderId,
    dataCenter: dataCenter.id,
    modPath: `Mods/7vs1/${basename(modPath)}`,
    techTree: {
      buildings: [],
      units: catalogIds.units,
      upgrades: [],
      abilities: catalogIds.abilities,
    },
    runtimeHooks: extractRuntimeHooks(dataCenter),
    panelLayout: {
      topPanelAbilities: [],
      commandCardLayouts: [],
    },
    prestiges: [],
    masteries: [],
    compatibleMapFamilies: [],
    incompatibleMapFamilies: [],
  };

  return pkg;
}
