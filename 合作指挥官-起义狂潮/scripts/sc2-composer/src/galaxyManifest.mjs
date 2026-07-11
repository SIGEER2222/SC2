/**
 * GalaxyManifest 校验与生成模块
 *
 * GalaxyManifest 显式声明需要注入到地图 Base.SC2Data 的 galaxy 文件清单，
 * 替代 launcher-plan.ps1 的目录扫描行为。未声明文件禁止注入。
 *
 * 详见 docs/系统结构与工作流优化设计-2026-07-11.md §5.3。
 */

import { readFileSync, existsSync } from 'node:fs';
import { basename } from 'node:path';

/** GalaxyManifest 当前 schema 版本 */
export const GALAXY_MANIFEST_SCHEMA_VERSION = 1;

/** 必填顶层字段 */
const REQUIRED_FIELDS = ['schemaVersion', 'id', 'entries'];

/**
 * 校验 GalaxyManifest 结构。
 *
 * @param {any} manifest - 待校验的 GalaxyManifest 对象
 * @returns {{ valid: boolean, errors: string[] }}
 */
export function validateManifest(manifest) {
  const errors = [];

  if (typeof manifest !== 'object' || manifest === null || Array.isArray(manifest)) {
    return { valid: false, errors: ['GalaxyManifest 必须是对象'] };
  }

  for (const field of REQUIRED_FIELDS) {
    if (!(field in manifest)) errors.push(`缺少必填字段: ${field}`);
  }

  if (manifest.schemaVersion !== undefined && manifest.schemaVersion !== GALAXY_MANIFEST_SCHEMA_VERSION) {
    errors.push(`schemaVersion 必须为 ${GALAXY_MANIFEST_SCHEMA_VERSION}，实际为 ${manifest.schemaVersion}`);
  }

  if (manifest.id !== undefined && (typeof manifest.id !== 'string' || manifest.id.length === 0)) {
    errors.push('id 必须是非空字符串');
  }

  if (manifest.entries !== undefined) {
    if (!Array.isArray(manifest.entries)) {
      errors.push('entries 必须是数组');
    } else {
      if (manifest.entries.length === 0) {
        errors.push('entries 不能为空');
      }
      const seenFiles = new Set();
      for (let i = 0; i < manifest.entries.length; i++) {
        const e = manifest.entries[i];
        const prefix = `entries[${i}]`;
        if (typeof e !== 'object' || e === null) {
          errors.push(`${prefix} 必须是对象`);
          continue;
        }
        for (const f of ['file', 'owner', 'sourceMod', 'reason']) {
          if (!e[f] || typeof e[f] !== 'string') {
            errors.push(`${prefix}.${f} 缺失或非字符串`);
          }
        }
        if (e.file) {
          if (seenFiles.has(e.file)) {
            errors.push(`${prefix}.file 重复: ${e.file}`);
          }
          seenFiles.add(e.file);
        }
        if (e.compileProvides !== undefined && !Array.isArray(e.compileProvides)) {
          errors.push(`${prefix}.compileProvides 必须是数组`);
        }
        if (e.compileRequires !== undefined && !Array.isArray(e.compileRequires)) {
          errors.push(`${prefix}.compileRequires 必须是数组`);
        }
        if (e.compatibilityOnly !== undefined && typeof e.compatibilityOnly !== 'boolean') {
          errors.push(`${prefix}.compatibilityOnly 必须是布尔值`);
        }
        if (e.compatibilityOnly === true && !e.removalCondition) {
          errors.push(`${prefix}.removalCondition 在 compatibilityOnly=true 时必填`);
        }
      }
    }
  }

  return { valid: errors.length === 0, errors };
}

/**
 * 从 LauncherCompatibilityPlan 的 galaxyInjection 字段生成 GalaxyManifest。
 *
 * @param {object} plan - LauncherCompatibilityPlan 对象（需含 galaxyInjection 数组）
 * @param {object} [options]
 * @param {string} [options.manifestId='reborn.compat'] - manifest ID
 * @param {string} [options.description] - 可选描述
 * @param {string} [options.mapFamily='reborn'] - 地图族
 * @param {string[]} [options.coveredCompositions=[]] - 已覆盖组合 ID 列表
 * @returns {object} GalaxyManifest 对象
 */
export function generateFromPlan(plan, options = {}) {
  if (!plan || !Array.isArray(plan.galaxyInjection)) {
    throw new Error('plan.galaxyInjection 必须是数组');
  }

  const manifestId = options.manifestId || 'reborn.compat';
  const mapFamily = options.mapFamily || 'reborn';
  const coveredCompositions = options.coveredCompositions || (plan.compositionId ? [plan.compositionId] : []);

  const entries = plan.galaxyInjection.map((g) => {
    // Derive compileProvides from filename: Base.SC2Data/LibE0EAE146_RaynorRuntime.galaxy -> LibE0EAE146_RaynorRuntime
    const filename = g.file.replace(/^Base\.SC2Data\//, '');
    const provides = filename.replace(/\.galaxy$/, '');

    // Derive sourceMod from source path: Mods\7vs1\CommanderUnits_Raynor.SC2Mod\Base.SC2Data\... -> Mods/7vs1/CommanderUnits_Raynor.SC2Mod
    const normalizedSource = String(g.source || '').replace(/\\/g, '/');
    const modMatch = normalizedSource.match(/Mods\/[^/]+\/[^/]+\.SC2Mod/);
    const sourceMod = modMatch ? modMatch[0] : normalizedSource;

    const entry = {
      file: g.file,
      owner: g.owner,
      sourceMod,
      compileProvides: [provides],
      compileRequires: [],
      reason: g.reason,
      compatibilityOnly: !!g.compatibilityOnly,
    };

    if (entry.compatibilityOnly) {
      entry.removalCondition = 'generated bootstrap includes only selected commander Runtime and passes Raynor/Kerrigan/Karax regression';
    }

    return entry;
  });

  return {
    schemaVersion: GALAXY_MANIFEST_SCHEMA_VERSION,
    id: manifestId,
    description: options.description || `Galaxy injection manifest for ${mapFamily} map family. Generated from launcher plan.`,
    scope: {
      mapFamily,
      coveredCompositions,
    },
    entries,
  };
}

/**
 * 从文件加载 GalaxyManifest。
 *
 * @param {string} path - manifest JSON 文件路径
 * @returns {object}
 * @throws {Error} 文件不存在或解析失败
 */
export function loadManifest(path) {
  if (!existsSync(path)) {
    throw new Error(`GalaxyManifest 文件不存在: ${path}`);
  }
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (e) {
    throw new Error(`GalaxyManifest 解析失败: ${path} - ${e.message}`);
  }
}

/**
 * 比对 manifest 与 plan 的 galaxyInjection，检查覆盖一致性。
 *
 * @param {object} manifest - GalaxyManifest
 * @param {object} plan - LauncherCompatibilityPlan
 * @returns {{ matched: string[], missingFromManifest: string[], missingFromPlan: string[] }}
 *   matched: 两边都有的文件
 *   missingFromManifest: plan 有但 manifest 没有的文件（需补全 manifest）
 *   missingFromPlan: manifest 有但 plan 没有的文件（可能过期或 plan 变化）
 */
export function diffAgainstPlan(manifest, plan) {
  const manifestFiles = new Set((manifest.entries || []).map((e) => e.file));
  const planFiles = new Set((plan.galaxyInjection || []).map((g) => g.file));

  const matched = [];
  const missingFromManifest = [];
  const missingFromPlan = [];

  for (const f of manifestFiles) {
    if (planFiles.has(f)) matched.push(f);
    else missingFromPlan.push(f);
  }
  for (const f of planFiles) {
    if (!manifestFiles.has(f)) missingFromManifest.push(f);
  }

  return { matched, missingFromManifest, missingFromPlan };
}
