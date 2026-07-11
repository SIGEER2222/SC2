/**
 * CompositionPlan 校验与依赖解析模块
 *
 * CompositionPlan 是组合工具链的单一真源，描述一次组合所需的：
 *   - MapProfile 引用
 *   - 每个 commander slot 的 CommanderPackage 选择
 *   - 依赖层、capability 匹配、Catalog 决策等
 *
 * 详见 docs/指挥官地图组合框架设计.md 第 4.8 节。
 */

import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

/** CompositionPlan 当前 schema 版本 */
export const PLAN_SCHEMA_VERSION = 1;

/**
 * 依赖层定义（按 docs/指挥官地图组合框架设计.md 第 5.1 节）。
 * resolveDependencies 按此顺序产出有序依赖。
 */
export const DEPENDENCY_LAYERS = [
  { layer: 'L0', name: '官方 Base / Campaign', source: 'builtin' },
  { layer: 'L1', name: '地图原始依赖和地图族资源包', source: 'map' },
  { layer: 'L2', name: 'PlatformKernel', source: 'platform' },
  { layer: 'L3', name: '通用 CapabilityPackage', source: 'capability' },
  { layer: 'L4', name: 'CommanderPackage', source: 'commander' },
  { layer: 'L5', name: 'MapAdapter', source: 'map-adapter' },
  { layer: 'L6', name: 'CommanderAdapter', source: 'commander-adapter' },
  { layer: 'L7', name: 'PairPatch', source: 'pair-patch' },
  { layer: 'L8', name: '地图本地 GameData、Triggers 和生成 bootstrap', source: 'map-local' },
];

/** 必填顶层字段（旧 schema: compositionId/mapProfile/slots） */
const REQUIRED_FIELDS_LEGACY = ['schemaVersion', 'compositionId', 'mapProfile', 'slots'];

/** 必填顶层字段（新 schema: planId/map/commanderSlots/dependencies/bootstrap，对齐 CompositionPlan.schema.json） */
const REQUIRED_FIELDS_NEW = ['schemaVersion', 'planId', 'map', 'commanderSlots', 'dependencies', 'conflictResolution', 'bankConfig', 'victoryCondition', 'defeatCondition', 'bootstrap'];

/**
 * 校验 CompositionPlan 结构。
 *
 * 支持两种格式：
 *   - 新 schema（CompositionPlan.schema.json）：planId/map/commanderSlots/dependencies/bootstrap
 *   - 旧 schema（过渡期）：compositionId/mapProfile/slots
 *
 * 格式由 planId 字段存在性自动检测。generateCompositionPlan() 产出新格式，
 * 旧格式仍被 resolveDependencies 及其测试使用，过渡期两种格式共存。
 *
 * @param {any} plan - 待校验的 CompositionPlan 对象
 * @returns {{ valid: boolean, errors: string[] }}
 *   valid 为 true 时 errors 为空数组；为 false 时 errors 包含所有问题。
 */
export function validatePlan(plan) {
  const errors = [];

  if (typeof plan !== 'object' || plan === null || Array.isArray(plan)) {
    return { valid: false, errors: ['CompositionPlan 必须是对象'] };
  }

  // 检测格式：新 schema 有 planId，旧 schema 有 compositionId
  const isNewFormat = 'planId' in plan;
  const requiredFields = isNewFormat ? REQUIRED_FIELDS_NEW : REQUIRED_FIELDS_LEGACY;

  // 必填字段
  for (const field of requiredFields) {
    if (!(field in plan)) errors.push(`缺少必填字段: ${field}`);
  }

  // schemaVersion
  if (plan.schemaVersion !== undefined && plan.schemaVersion !== PLAN_SCHEMA_VERSION) {
    errors.push(`schemaVersion 必须为 ${PLAN_SCHEMA_VERSION}，实际为 ${plan.schemaVersion}`);
  }

  if (isNewFormat) {
    // === 新 schema 校验（对齐 CompositionPlan.schema.json）===
    if (plan.planId !== undefined) {
      if (typeof plan.planId !== 'string' || plan.planId.length === 0) {
        errors.push('planId 必须是非空字符串');
      }
    }

    if (plan.map !== undefined) {
      if (typeof plan.map !== 'object' || plan.map === null || Array.isArray(plan.map)) {
        errors.push('map 必须是对象');
      }
    }

    if (plan.commanderSlots !== undefined) {
      if (!Array.isArray(plan.commanderSlots) || plan.commanderSlots.length === 0) {
        errors.push('commanderSlots 必须是非空数组');
      }
    }

    if (plan.dependencies !== undefined) {
      if (typeof plan.dependencies !== 'object' || plan.dependencies === null || Array.isArray(plan.dependencies)) {
        errors.push('dependencies 必须是对象');
      }
    }

    if (plan.bootstrap !== undefined) {
      if (typeof plan.bootstrap !== 'object' || plan.bootstrap === null || Array.isArray(plan.bootstrap)) {
        errors.push('bootstrap 必须是对象');
      }
      if (plan.bootstrap && !Array.isArray(plan.bootstrap.galaxyIncludes)) {
        errors.push('bootstrap.galaxyIncludes 必须是数组');
      }
    }
  } else {
    // === 旧 schema 校验（过渡期兼容）===
    if (plan.compositionId !== undefined) {
      if (typeof plan.compositionId !== 'string' || plan.compositionId.length === 0) {
        errors.push('compositionId 必须是非空字符串');
      }
    }

    if (plan.mapProfile !== undefined) {
      if (typeof plan.mapProfile !== 'string' || plan.mapProfile.length === 0) {
        errors.push('mapProfile 必须是非空字符串');
      }
    }

    if (plan.slots !== undefined) {
      if (typeof plan.slots !== 'object' || plan.slots === null || Array.isArray(plan.slots)) {
        errors.push('slots 必须是对象（slotIndex -> slot 描述）');
      } else {
        const slotKeys = Object.keys(plan.slots);
        if (slotKeys.length === 0) {
          errors.push('slots 不能为空');
        }
        for (const slotKey of slotKeys) {
          if (!/^\d+$/.test(slotKey)) {
            errors.push(`slots 键 "${slotKey}" 必须是数字字符串`);
          }
          const slot = plan.slots[slotKey];
          if (typeof slot !== 'object' || slot === null || Array.isArray(slot)) {
            errors.push(`slots.${slotKey} 必须是对象`);
            continue;
          }
          if (!slot.commander || typeof slot.commander !== 'string') {
            errors.push(`slots.${slotKey}.commander 缺失或非字符串`);
          }
          if (slot.adapter !== undefined && typeof slot.adapter !== 'string') {
            errors.push(`slots.${slotKey}.adapter 必须是字符串`);
          }
        }
      }
    }

    // 可选字段类型检查（旧 schema）
    if (plan.dependencyLayers !== undefined && !Array.isArray(plan.dependencyLayers)) {
      errors.push('dependencyLayers 必须是数组');
    }
    if (plan.capabilities !== undefined && (typeof plan.capabilities !== 'object' || plan.capabilities === null || Array.isArray(plan.capabilities))) {
      errors.push('capabilities 必须是对象');
    }
    if (plan.catalogDecisions !== undefined && !Array.isArray(plan.catalogDecisions)) {
      errors.push('catalogDecisions 必须是数组');
    }
    if (plan.localPatches !== undefined && !Array.isArray(plan.localPatches)) {
      errors.push('localPatches 必须是数组');
    }
    if (plan.generatedBootstrap !== undefined && typeof plan.generatedBootstrap !== 'string') {
      errors.push('generatedBootstrap 必须是字符串');
    }
    if (plan.validation !== undefined && (typeof plan.validation !== 'object' || plan.validation === null || Array.isArray(plan.validation))) {
      errors.push('validation 必须是对象');
    }
  }

  return { valid: errors.length === 0, errors };
}

/**
 * 定位 MapProfile 文件。
 *
 * 查找顺序：
 *   1. projectRoot/Shared/Maps/profiles/<mapProfile>.json
 *   2. projectRoot/Shared/Maps/profiles/<family>/<mapId>.json（mapProfile 含 "." 时按 family.mapId 拆分）
 *   3. projectRoot/<mapProfile>.json（直接路径）
 *
 * @param {string} mapProfileId
 * @param {string} projectRoot
 * @returns {string|null} 找到的绝对路径，未找到返回 null
 */
function locateMapProfile(mapProfileId, projectRoot) {
  // 直接路径
  const direct = join(projectRoot, `${mapProfileId}.json`);
  if (existsSync(direct)) return direct;

  // Shared/Maps/profiles/<mapProfile>.json
  const profilesBase = join(projectRoot, 'Shared', 'Maps', 'profiles');
  const flat = join(profilesBase, `${mapProfileId}.json`);
  if (existsSync(flat)) return flat;

  // 按 family.mapId 拆分
  if (mapProfileId.includes('.')) {
    const [family, mapId] = mapProfileId.split('.', 2);
    const nested = join(profilesBase, family, `${mapId}.json`);
    if (existsSync(nested)) return nested;
  }

  return null;
}

/**
 * 定位 CommanderPackage manifest 文件。
 *
 * 查找顺序：
 *   1. projectRoot/Shared/Commanders/<commanderId>.json
 *   2. projectRoot/Mods/Commanders/<commanderId>/<commanderId>.json
 *
 * @param {string} commanderId
 * @param {string} projectRoot
 * @returns {string|null}
 */
function locateCommanderPackage(commanderId, projectRoot) {
  const shared = join(projectRoot, 'Shared', 'Commanders', `${commanderId}.json`);
  if (existsSync(shared)) return shared;

  const modsCmd = join(projectRoot, 'Mods', 'Commanders', commanderId, `${commanderId}.json`);
  if (existsSync(modsCmd)) return modsCmd;

  return null;
}

/**
 * 解析有序依赖列表。
 *
 * 按 DEPENDENCY_LAYERS 定义的层次顺序，从 MapProfile + CommanderSlots 计算
 * 完整有序依赖。文件缺失时记入 missing 数组而非抛错，便于增量迁移。
 *
 * @param {object} plan - CompositionPlan
 * @param {string} projectRoot - 项目根目录
 * @returns {Promise<{ layers: Array<{layer:string,name:string,source:string,entries:Array<object>}>, missing: string[] }>}
 */
export async function resolveDependencies(plan, projectRoot) {
  const { valid, errors } = validatePlan(plan);
  if (!valid) {
    throw new Error(`CompositionPlan 校验失败: ${errors.join('; ')}`);
  }

  const layers = [];
  const missing = [];

  // ===== L1: 地图原始依赖（MapProfile.requiredDependencies.always） =====
  const mapProfilePath = locateMapProfile(plan.mapProfile, projectRoot);
  let mapProfile = null;
  if (mapProfilePath) {
    try {
      mapProfile = JSON.parse(readFileSync(mapProfilePath, 'utf8'));
    } catch (e) {
      missing.push(`MapProfile 解析失败: ${mapProfilePath} - ${e.message}`);
    }
  } else {
    missing.push(`MapProfile 未找到: ${plan.mapProfile}`);
  }

  if (mapProfile?.requiredDependencies?.always) {
    layers.push({
      layer: 'L1',
      name: '地图原始依赖和地图族资源包',
      source: 'map',
      entries: mapProfile.requiredDependencies.always.map((dep) => ({
        path: dep,
        reason: 'MapProfile.requiredDependencies.always',
      })),
    });
  }

  // ===== L2: PlatformKernel（MapProfile.requiredDependencies.always 中前缀匹配 platform 的条目，占位） =====
  // 当前骨架不区分 platform 与 map 依赖，统一在 L1 输出；L2/L3/L5/L6/L8 暂留空层。

  // ===== L4: CommanderPackage（从 slots 展开） =====
  const commanderEntries = [];
  for (const [slotKey, slot] of Object.entries(plan.slots)) {
    const pkgPath = locateCommanderPackage(slot.commander, projectRoot);
    if (pkgPath) {
      commanderEntries.push({
        path: pkgPath.replace(projectRoot + '\\', '').replace(projectRoot + '/', ''),
        commander: slot.commander,
        slot: slotKey,
        reason: `slot ${slotKey}`,
      });
    } else {
      commanderEntries.push({
        commander: slot.commander,
        slot: slotKey,
        reason: `slot ${slotKey} (manifest 未找到)`,
        missing: true,
      });
      missing.push(`CommanderPackage 未找到: ${slot.commander}`);
    }
  }
  if (commanderEntries.length > 0) {
    layers.push({
      layer: 'L4',
      name: 'CommanderPackage',
      source: 'commander',
      entries: commanderEntries,
    });
  }

  // ===== L7: PairPatch（从 MapProfile.pairPatches 匹配选中 commander） =====
  const pairPatchEntries = [];
  if (mapProfile?.pairPatches && Array.isArray(mapProfile.pairPatches)) {
    for (const slot of Object.values(plan.slots)) {
      const patch = mapProfile.pairPatches.find((p) => p.commanderId === slot.commander);
      if (patch) {
        pairPatchEntries.push({
          path: patch.patchPath,
          commander: slot.commander,
          reason: patch.reason || 'MapProfile.pairPatches',
        });
      }
    }
  }
  // plan.localPatches 也作为 L7 候选
  if (Array.isArray(plan.localPatches)) {
    for (const lp of plan.localPatches) {
      if (lp && typeof lp === 'object' && lp.path) {
        pairPatchEntries.push({
          path: lp.path,
          commander: lp.commander || '',
          reason: lp.reason || 'plan.localPatches',
        });
      }
    }
  }
  if (pairPatchEntries.length > 0) {
    layers.push({
      layer: 'L7',
      name: 'PairPatch',
      source: 'pair-patch',
      entries: pairPatchEntries,
    });
  }

  return { layers, missing };
}

/**
 * 检测 Catalog ID 冲突。
 *
 * 占位实现：当前返回空数组。后续需根据实际 Catalog 扫描结果，
 * 检查同一 canonical Catalog ID 是否在多个 CommanderPackage 中同时定义。
 *
 * @param {object} plan - CompositionPlan
 * @param {string} projectRoot - 项目根目录
 * @returns {Promise<Array<{catalogId:string,type:string,owners:string[],conflictType:string}>>}
 */
export async function detectConflicts(plan, projectRoot) {
  // 占位：后续实现需遍历所有 CommanderPackage 的 catalog.ownedIds，
  // 与 MapProfile 的本地 catalog 比对，检测重复定义。
  return [];
}
