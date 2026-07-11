/**
 * CommanderPackage 校验与提取模块
 *
 * CommanderPackage 是一个可独立选择的指挥官实现清单，描述：
 *   - identity：ID、别名、种族、版本
 *   - dependencies：所需 base mod 与 capability
 *   - catalog：owned / extended IDs、本地化根
 *   - runtime：init/applyTech/createStartSquad 等 galaxy 函数
 *   - metadata / requirements / validation
 *
 * 详见 docs/指挥官地图组合框架设计.md 第 4.3 节。
 */

import { existsSync, readFileSync } from 'node:fs';
import { join, basename } from 'node:path';

/** CommanderPackage 当前 schema 版本 */
export const PACKAGE_SCHEMA_VERSION = 1;

/** identity 对象的必填字段 */
const IDENTITY_REQUIRED = ['id'];

/** runtime 字段必须是字符串 */
const RUNTIME_STRING_FIELDS = ['init', 'applyTech', 'createStartSquad', 'createCargoSquad', 'initUi'];

/**
 * 校验 CommanderPackage manifest 结构。
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

  // identity（必填）
  if (pkg.identity === undefined) {
    errors.push('缺少必填字段: identity');
  } else if (typeof pkg.identity !== 'object' || pkg.identity === null || Array.isArray(pkg.identity)) {
    errors.push('identity 必须是对象');
  } else {
    for (const f of IDENTITY_REQUIRED) {
      if (pkg.identity[f] === undefined) {
        errors.push(`identity.${f} 缺失`);
      } else if (typeof pkg.identity[f] !== 'string' || pkg.identity[f].length === 0) {
        errors.push(`identity.${f} 必须是非空字符串`);
      }
    }
    if (pkg.identity.aliases !== undefined && !Array.isArray(pkg.identity.aliases)) {
      errors.push('identity.aliases 必须是数组');
    }
    if (pkg.identity.race !== undefined && typeof pkg.identity.race !== 'string') {
      errors.push('identity.race 必须是字符串');
    }
    if (pkg.identity.version !== undefined && typeof pkg.identity.version !== 'number') {
      errors.push('identity.version 必须是数字');
    }
  }

  // dependencies（可选）
  if (pkg.dependencies !== undefined) {
    if (typeof pkg.dependencies !== 'object' || pkg.dependencies === null || Array.isArray(pkg.dependencies)) {
      errors.push('dependencies 必须是对象');
    } else {
      if (pkg.dependencies.requiredBaseMods !== undefined && !Array.isArray(pkg.dependencies.requiredBaseMods)) {
        errors.push('dependencies.requiredBaseMods 必须是数组');
      }
      if (pkg.dependencies.requiredCapabilities !== undefined && !Array.isArray(pkg.dependencies.requiredCapabilities)) {
        errors.push('dependencies.requiredCapabilities 必须是数组');
      }
    }
  }

  // catalog（可选）
  if (pkg.catalog !== undefined) {
    if (typeof pkg.catalog !== 'object' || pkg.catalog === null || Array.isArray(pkg.catalog)) {
      errors.push('catalog 必须是对象');
    } else {
      if (pkg.catalog.ownedIds !== undefined && !Array.isArray(pkg.catalog.ownedIds)) {
        errors.push('catalog.ownedIds 必须是数组');
      }
      if (pkg.catalog.extendedIds !== undefined && !Array.isArray(pkg.catalog.extendedIds)) {
        errors.push('catalog.extendedIds 必须是数组');
      }
      if (pkg.catalog.localizationRoots !== undefined && !Array.isArray(pkg.catalog.localizationRoots)) {
        errors.push('catalog.localizationRoots 必须是数组');
      }
    }
  }

  // runtime（可选）
  if (pkg.runtime !== undefined) {
    if (typeof pkg.runtime !== 'object' || pkg.runtime === null || Array.isArray(pkg.runtime)) {
      errors.push('runtime 必须是对象');
    } else {
      for (const f of RUNTIME_STRING_FIELDS) {
        if (pkg.runtime[f] !== undefined && typeof pkg.runtime[f] !== 'string') {
          errors.push(`runtime.${f} 必须是字符串`);
        }
      }
    }
  }

  // metadata（可选，对象即可）
  if (pkg.metadata !== undefined && (typeof pkg.metadata !== 'object' || pkg.metadata === null || Array.isArray(pkg.metadata))) {
    errors.push('metadata 必须是对象');
  }

  // requirements（可选）
  if (pkg.requirements !== undefined) {
    if (typeof pkg.requirements !== 'object' || pkg.requirements === null || Array.isArray(pkg.requirements)) {
      errors.push('requirements 必须是对象');
    } else if (pkg.requirements.mapCapabilities !== undefined && !Array.isArray(pkg.requirements.mapCapabilities)) {
      errors.push('requirements.mapCapabilities 必须是数组');
    }
  }

  // validation（可选）
  if (pkg.validation !== undefined) {
    if (typeof pkg.validation !== 'object' || pkg.validation === null || Array.isArray(pkg.validation)) {
      errors.push('validation 必须是对象');
    } else {
      const arrFields = ['expectedProducers', 'expectedUnits', 'expectedAbilities', 'runtimeProbes'];
      for (const f of arrFields) {
        if (pkg.validation[f] !== undefined && !Array.isArray(pkg.validation[f])) {
          errors.push(`validation.${f} 必须是数组`);
        }
      }
    }
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
 * 从 DataCenter.exports 收集所有 ownedIds。
 *
 * @param {object} dataCenter
 * @returns {string[]}
 */
function collectOwnedIds(dataCenter) {
  const ids = [];
  if (dataCenter.exports) {
    for (const arr of Object.values(dataCenter.exports)) {
      if (Array.isArray(arr)) ids.push(...arr);
    }
  }
  return ids;
}

/**
 * 从 DataCenter.galaxyRuntime 提取 runtime 字段。
 *
 * 字段映射：
 *   initFunction         -> init
 *   applyTechFunction    -> applyTech
 *   createStartSquadFunction -> createStartSquad
 *
 * @param {object} dataCenter
 * @returns {object}
 */
function extractRuntime(dataCenter) {
  const rt = dataCenter.galaxyRuntime;
  if (!rt) return {};
  const result = {};
  if (rt.initFunction) result.init = rt.initFunction;
  if (rt.applyTechFunction) result.applyTech = rt.applyTechFunction;
  if (rt.createStartSquadFunction) result.createStartSquad = rt.createStartSquadFunction;
  return result;
}

/**
 * 从现有 SC2Mod + DataCenter.json 提取 CommanderPackage 草案。
 *
 * 要求 modPath 下存在 DataCenter.json，且 type === 'CommanderDataCenter'。
 * 提取结果仅作草案，调用方需进一步补充 metadata、requirements 等。
 *
 * @param {string} modPath - SC2Mod 目录绝对路径
 * @returns {Promise<object>} CommanderPackage 草案对象
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

  // 构建 CommanderPackage 草案
  const pkg = {
    schemaVersion: PACKAGE_SCHEMA_VERSION,
    identity: {
      id: commanderId,
      aliases: [],
      race: inferRaceFromCommanderId(commanderId),
      version: 1,
    },
    dependencies: {
      requiredBaseMods: [],
      requiredCapabilities: dataCenter.imports?.capabilities || [],
    },
    catalog: {
      ownedIds: collectOwnedIds(dataCenter),
      extendedIds: [],
      localizationRoots: dataCenter.localization ? [dataCenter.localization] : [],
    },
    runtime: extractRuntime(dataCenter),
    metadata: {
      modName: basename(modPath),
      dataCenterId: dataCenter.id,
    },
    requirements: {
      mapCapabilities: [],
    },
    validation: {
      expectedProducers: [],
      expectedUnits: dataCenter.exports?.units || [],
      expectedAbilities: dataCenter.exports?.abilities || [],
      runtimeProbes: [],
    },
  };

  return pkg;
}
