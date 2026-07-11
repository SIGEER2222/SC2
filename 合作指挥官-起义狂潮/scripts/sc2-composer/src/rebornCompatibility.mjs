/**
 * Reborn 兼容性 CompositionPlan 生成器
 *
 * 从 Shared/Launcher/*.json 过渡配置 + Mods/Reborn/MapProfiles/*.json 生成
 * 正式 CompositionPlan（符合 CompositionPlan.schema.json）。
 *
 * 这是 Phase 3 的关键产物：让 sc2-composer plan 能从现有过渡配置产出
 * 与 launcher-plan.ps1 对齐的正式 plan，为后续 Reborn launcher 支持 -Plan
 * 参数铺路。
 *
 * 详见 docs/系统结构与工作流优化设计-2026-07-11.md §7 Task 4。
 */

import { existsSync, readFileSync } from 'node:fs';
import { join, basename } from 'node:path';
import { classifyEntry } from './bootstrapGenerator.mjs';

/** CompositionPlan 当前 schema 版本 */
export const PLAN_SCHEMA_VERSION = 1;

/**
 * 读取并解析 JSON 文件。
 * @param {string} path
 * @returns {object}
 * @throws {Error} 文件不存在或解析失败
 */
function readJson(path) {
  if (!existsSync(path)) {
    throw new Error(`文件不存在: ${path}`);
  }
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (e) {
    throw new Error(`JSON 解析失败: ${path} - ${e.message}`);
  }
}

/**
 * 定位并读取 Reborn MapProfile。
 *
 * 查找顺序：
 *   1. Mods/Reborn/MapProfiles/<profileName>.json
 *   2. Mods/Reborn/MapProfiles/<mapBaseName split by _>[0].json
 *
 * @param {string} mapName - 地图文件名，如 zexpedition03_reborn_port.SC2Map
 * @param {string} projRoot - 项目根目录
 * @returns {{ profile: object, path: string }}
 * @throws {Error} MapProfile 不存在
 */
function loadRebornMapProfile(mapName, projRoot) {
  const profileDir = join(projRoot, 'Mods', 'Reborn', 'MapProfiles');
  const mapBaseName = basename(mapName, '.SC2Map');
  const parts = mapBaseName.split('_');
  const profileName = parts[0];

  const profilePath = join(profileDir, `${profileName}.json`);
  if (!existsSync(profilePath)) {
    throw new Error(`Reborn MapProfile 不存在: ${profilePath} (mapName=${mapName})`);
  }
  return { profile: readJson(profilePath), path: profilePath };
}

/**
 * 从 commander-units-mapping 解析选中的 CommanderUnits mod 后缀。
 *
 * @param {string} commander - 指挥官 ID，如 TerranRaynor
 * @param {object} cmdMap - commander-units-mapping.json 内容
 * @returns {string|null} mod 后缀，如 Raynor；未找到返回 null
 */
function resolveCommanderUnitsSuffix(commander, cmdMap) {
  if (cmdMap.mappings && cmdMap.mappings[commander]) {
    return cmdMap.mappings[commander];
  }
  return null;
}

/**
 * 生成正式 CompositionPlan。
 *
 * 输入：mapName + commander + projectRoot
 * 输出：CompositionPlan 对象（符合 CompositionPlan.schema.json）
 *
 * 事实来源：
 *   - Shared/Launcher/reborn-dependencies.json → dependencies.always (L1)
 *   - Shared/Launcher/alenger-mods.json → dependencies.always (L2, AdapterBootstrap)
 *   - Shared/Launcher/commander-units-mapping.json → dependencies.commander (L4)
 *   - Mods/Reborn/MapProfiles/<map>.json → map, bankConfig, victory/defeatCondition
 *   - Shared/Launcher/reborn-dependencies.json#galaxyInjection → bootstrap.galaxyIncludes
 *
 * @param {object} options
 * @param {string} options.mapName - 地图文件名，如 zexpedition03_reborn_port.SC2Map
 * @param {string} options.commander - 指挥官 ID，如 TerranRaynor
 * @param {string} options.projectRoot - 项目根目录
 * @param {string} [options.sc2Root] - SC2 安装根目录（用于 sourceMap/generatedMap 路径）
 * @returns {object} CompositionPlan 对象
 * @throws {Error} 配置缺失或解析失败
 */
export function generateCompositionPlan(options) {
  const { mapName, commander, projectRoot } = options;
  if (!mapName) throw new Error('mapName is required');
  if (!commander) throw new Error('commander is required');
  if (!projectRoot) throw new Error('projectRoot is required');

  const sc2Root = options.sc2Root || 'E:\\SC2\\SC2new\\StarCraft II';

  // === Load configs ===
  const sharedLauncher = join(projectRoot, 'Shared', 'Launcher');
  const rebornConfig = readJson(join(sharedLauncher, 'reborn-dependencies.json'));
  const alengerConfig = readJson(join(sharedLauncher, 'alenger-mods.json'));
  const cmdMapConfig = readJson(join(sharedLauncher, 'commander-units-mapping.json'));

  // === Load MapProfile ===
  const { profile: mapProfile } = loadRebornMapProfile(mapName, projectRoot);

  // === Resolve selected commander mod ===
  const selectedSuffix = resolveCommanderUnitsSuffix(commander, cmdMapConfig);
  const selectedCommanderUnitsMod = selectedSuffix ? `CommanderUnits_${selectedSuffix}` : null;

  // === Map paths ===
  const sourceMapPath = join(projectRoot, 'Maps', mapName);
  const generatedMapPath = join(sc2Root, 'Maps', mapName);
  const mapBaseName = basename(mapName, '.SC2Map');

  // === planId ===
  const planId = `reborn.${mapBaseName}__p1-${commander}`;

  // === dependencies.always (L1 + L2) ===
  const always = [];

  // L1: Reborn base mods — only those with direct dependency paths
  for (let i = 0; i < rebornConfig.baseMods.length; i++) {
    const modRel = rebornConfig.baseMods[i];
    const modBaseName = basename(modRel);
    // Find matching baseDependencyPath
    const depPath = rebornConfig.baseDependencyPaths.find((p) => p.endsWith(modBaseName) || p.endsWith(modBaseName.replace('\\', '/')));
    if (depPath) {
      always.push({
        path: depPath,
        layer: 'L1-MapFamilyBase',
        source: 'MapProfile.requiredDependencies.always (reborn-dependencies.json)',
      });
    }
    // Transitive mods (no direct dep path) are synced but not in document deps; skip from plan.always
  }

  // L2: Alenger adapter bootstrap (all 24 mods, CoreRuntime hardcoded)
  for (let i = 0; i < alengerConfig.mods.length; i++) {
    always.push({
      path: alengerConfig.dependencyPaths[i],
      layer: 'L2-PlatformKernel',
      source: 'CoreRuntime AdapterBootstrap hardcoded (alenger-mods.json)',
    });
  }

  // === dependencies.commander (L4) ===
  const commanderDeps = [];
  if (selectedCommanderUnitsMod) {
    commanderDeps.push({
      path: `file:Mods/7vs1/${selectedCommanderUnitsMod}.SC2Mod`,
      layer: 'L4-CommanderPackage',
      source: 'commander-units-mapping.json',
    });
  }

  // === dependencies.pairPatches (L7) ===
  const pairPatches = [];
  if (Array.isArray(mapProfile.pairPatches)) {
    for (const p of mapProfile.pairPatches) {
      if (p.commanderId === commander) {
        pairPatches.push({
          commanderId: p.commanderId,
          patchPath: p.patchPath,
          reason: p.reason || 'MapProfile.pairPatches',
        });
      }
    }
  }

  // === bootstrap.galaxyIncludes ===
  // 从 reborn-dependencies.json#galaxyInjection.sourcePatterns + sourceRoot 推导
  // 正式版应从 Shared/Galaxy/reborn-compat-galaxy-manifest.json 读取
  // 这里先用 sourcePatterns 声明注入范围，具体文件列表由 manifest 提供
  const galaxyManifestPath = join(projectRoot, 'Shared', 'Galaxy', 'reborn-compat-galaxy-manifest.json');
  const galaxyIncludes = [];
  if (existsSync(galaxyManifestPath)) {
    const manifest = readJson(galaxyManifestPath);
    for (const entry of manifest.entries) {
      galaxyIncludes.push({
        path: entry.file,
        purpose: classifyEntry(entry, commander),
      });
    }
  } else {
    // Fallback: declare pattern-based include (will be resolved by launcher)
    galaxyIncludes.push({
      path: `${rebornConfig.galaxyInjection.sourceRoot}/${rebornConfig.galaxyInjection.sourcePatterns.join(',')}`,
      purpose: 'CommanderRuntime+AdapterBootstrap (directory scan fallback)',
    });
  }

  // === bootstrap.initSequence ===
  // 当前阶段使用空序列，generated bootstrap 尚未实现
  const initSequence = [];

  // === bootstrap.runtimeOverrides ===
  const runtimeOverrides = [];

  // === conflictResolution ===
  const conflictResolution = {
    overrideStrategy: 'preserve-map',
    allowedConflicts: [],
  };

  // === bankConfig ===
  const bankConfig = {
    protectedBanks: mapProfile.bankProtection?.protectedBanks || [],
    playerBanks: mapProfile.bankProtection?.playerBanks || {},
  };

  // === victory/defeatCondition ===
  const victoryCondition = mapProfile.victoryCondition || { type: 'native' };
  const defeatCondition = mapProfile.defeatCondition || { type: 'native' };

  // === Build CompositionPlan ===
  const plan = {
    schemaVersion: PLAN_SCHEMA_VERSION,
    planId,
    map: {
      mapId: mapProfile.mapId || mapBaseName,
      mapFamily: mapProfile.mapFamily || 'RebornHotS',
      mapName: mapProfile.mapName || mapBaseName,
      source: `Maps/${mapName}`,
      adapter: mapProfile.mapAdapter || 'reborn',
    },
    commanderSlots: [
      {
        slotIndex: 0,
        playerId: 1,
        commanderId: commander,
        prestige: null,
        mastery: null,
        talents: [],
        bonuses: [],
      },
    ],
    dependencies: {
      always,
      commander: [
        {
          slotIndex: 0,
          commanderId: commander,
          dependencies: commanderDeps,
        },
      ],
      pairPatches,
    },
    conflictResolution,
    bankConfig,
    victoryCondition,
    defeatCondition,
    bootstrap: {
      galaxyIncludes,
      initSequence,
      runtimeOverrides,
    },
    // 扩展字段（CompositionPlan.schema.json 允许 additionalProperties:false，但这些字段用于对齐 launcher-plan）
    // 注：正式 schema 不允许额外字段；以下放在 _compat 命名空间供过渡期使用
    _compat: {
      sourceMap: sourceMapPath,
      generatedMap: generatedMapPath,
      selectedCommanderUnitsMod,
      executionMode: 'legacy-launcher',
      sourceFacts: [
        { field: 'dependencies.always.L1', source: 'Shared/Launcher/reborn-dependencies.json', migrationTarget: 'MapProfile.requiredDependencies.always' },
        { field: 'dependencies.always.L2', source: 'Shared/Launcher/alenger-mods.json', migrationTarget: 'CompositionPlan.dependencies (generated bootstrap)' },
        { field: 'dependencies.commander.L4', source: 'Shared/Launcher/commander-units-mapping.json', migrationTarget: 'CommanderPackage.dependencies' },
        { field: 'bootstrap.galaxyIncludes', source: 'Shared/Galaxy/reborn-compat-galaxy-manifest.json', migrationTarget: 'CompositionPlan.bootstrap.galaxyIncludes (generated)' },
        { field: 'bankConfig', source: 'Mods/Reborn/MapProfiles/<map>.json', migrationTarget: 'MapProfile.bankProtection' },
      ],
      knownDebt: [
        {
          id: 'core-runtime-full-include',
          reason: 'CoreRuntime LibE0EAE146.galaxy hardcodes include of all commander Runtime files',
          removalCondition: 'generated bootstrap includes only selected commander Runtime and passes Raynor/Kerrigan/Karax regression',
        },
        {
          id: 'galaxy-directory-scan',
          reason: 'galaxyInjection was built via directory scan; manifest now exists but launcher still scans',
          removalCondition: 'launcher reads from manifest, undeclared files not injected',
        },
        {
          id: 'launcher-config-as-temporary-source',
          reason: 'Shared/Launcher/*.json are Reborn transition configs',
          removalCondition: 'sc2-composer plan generates equivalent plan from Shared/Commanders + MapProfile + DataCenter',
        },
      ],
    },
  };

  return plan;
}

/**
 * 比对 CompositionPlan 与 LauncherCompatibilityPlan 的依赖层一致性。
 *
 * 用于验证 rebornCompatibility.mjs 生成的 plan 与 launcher-plan.ps1 生成的
 * launcher-plan 在依赖层数量、条目数上一致。
 *
 * 注意：launcher-plan 的 L1 包含 transitive sync 条目（path=null），
 * 这些条目只同步到 live 但不进 DocumentHeader。CompositionPlan.dependencies.always
 * 只包含有 path 的 document 依赖。因此比较时用 documentRewrite 对齐。
 *
 * @param {object} compositionPlan - 由 generateCompositionPlan 生成
 * @param {object} launcherPlan - 由 launcher-plan.ps1 生成
 * @returns {{ consistent: boolean, differences: string[] }}
 */
export function comparePlans(compositionPlan, launcherPlan) {
  const differences = [];

  // Compare planId / compositionId
  if (compositionPlan.planId !== launcherPlan.compositionId) {
    differences.push(`planId mismatch: composition=${compositionPlan.planId} launcher=${launcherPlan.compositionId}`);
  }

  // Compare document dependency counts:
  // CompositionPlan.dependencies.always + commander deps should match
  // launcher-plan.documentRewrite.DocumentHeader (which is the actual document dep list)
  const compDocDeps = [
    ...compositionPlan.dependencies.always.map((d) => d.path),
    ...compositionPlan.dependencies.commander.flatMap((c) => c.dependencies.map((d) => d.path)),
  ];
  const launchDocDeps = launcherPlan.documentRewrite?.DocumentHeader || [];
  if (compDocDeps.length !== launchDocDeps.length) {
    differences.push(`document deps count mismatch: composition(always+commander)=${compDocDeps.length} launcher(documentRewrite)=${launchDocDeps.length}`);
  } else {
    // Check set equality (order may differ)
    const compSet = new Set(compDocDeps);
    const launchSet = new Set(launchDocDeps);
    for (const d of compSet) {
      if (!launchSet.has(d)) {
        differences.push(`document dep in composition but not launcher: ${d}`);
      }
    }
    for (const d of launchSet) {
      if (!compSet.has(d)) {
        differences.push(`document dep in launcher but not composition: ${d}`);
      }
    }
  }

  // Compare galaxy includes
  const compGalaxyCount = compositionPlan.bootstrap.galaxyIncludes.length;
  const launchGalaxyCount = (launcherPlan.galaxyInjection || []).length;
  if (compGalaxyCount !== launchGalaxyCount) {
    differences.push(`galaxyIncludes count mismatch: composition=${compGalaxyCount} launcher=${launchGalaxyCount}`);
  }

  return {
    consistent: differences.length === 0,
    differences,
  };
}
