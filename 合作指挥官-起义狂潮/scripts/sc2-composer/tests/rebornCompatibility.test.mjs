/**
 * rebornCompatibility.mjs 单元测试
 *
 * 运行：node --test tests/rebornCompatibility.test.mjs
 */

import { test, describe } from 'node:test';
import { strict as assert } from 'node:assert';
import { generateCompositionPlan, comparePlans, PLAN_SCHEMA_VERSION } from '../src/rebornCompatibility.mjs';
import { validatePlan } from '../src/compositionPlan.mjs';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

/**
 * 创建一个临时项目结构，模拟 Shared/Launcher + Mods/Reborn/MapProfiles。
 */
function createTempProject() {
  const root = mkdtempSync(join(tmpdir(), 'sc2-reborn-'));
  const launcherDir = join(root, 'Shared', 'Launcher');
  const profileDir = join(root, 'Mods', 'Reborn', 'MapProfiles');
  const galaxyDir = join(root, 'Shared', 'Galaxy');
  mkdirSync(launcherDir, { recursive: true });
  mkdirSync(profileDir, { recursive: true });
  mkdirSync(galaxyDir, { recursive: true });

  // reborn-dependencies.json
  const rebornDeps = {
    family: 'reborn',
    baseMods: [
      'crys_the_swarm_reborn.SC2Mod',
      'Reborn\\RebornBridge.SC2Mod',
      '7vs1\\CoreRuntime.SC2Mod',
    ],
    baseDependencyPaths: [
      'file:Mods/crys_the_swarm_reborn.SC2Mod',
      'file:Mods/RebornBridge.SC2Mod',
      'file:Mods/7vs1/CoreRuntime.SC2Mod',
    ],
    galaxyInjection: {
      sourcePatterns: ['CommanderUnits_*.SC2Mod', 'Alenger*Adapter.SC2Mod'],
      sourceRoot: 'Mods\\7vs1',
    },
    validCommanders: ['TerranRaynor'],
  };
  writeFileSync(join(launcherDir, 'reborn-dependencies.json'), JSON.stringify(rebornDeps));

  // alenger-mods.json
  const alengerMods = {
    mods: ['7vs1\\Alenger3.SC2Mod', '7vs1\\Alenger3Adapter.SC2Mod'],
    dependencyPaths: ['file:Mods/7vs1/Alenger3.SC2Mod', 'file:Mods/7vs1/Alenger3Adapter.SC2Mod'],
  };
  writeFileSync(join(launcherDir, 'alenger-mods.json'), JSON.stringify(alengerMods));

  // commander-units-mapping.json
  const cmdMap = {
    mappings: { TerranRaynor: 'Raynor' },
  };
  writeFileSync(join(launcherDir, 'commander-units-mapping.json'), JSON.stringify(cmdMap));

  // MapProfile
  const mapProfile = {
    schemaVersion: 1,
    mapFamily: 'RebornHotS',
    mapId: 'ZExpedition3',
    mapName: 'Harvest of Screams',
    mapAdapter: 'reborn',
    entryType: 'direct',
    commanderSlots: [{ slotIndex: 0, playerId: 1, commanderId: null }],
    pairPatches: [],
    requiredDependencies: { always: [] },
    bankProtection: {
      protectedBanks: ['cryswarmcoop'],
      playerBanks: { '1': 'cryswarmcoop' },
    },
    victoryCondition: { type: 'native', trigger: 'libRebornAdapter_TriggerVictory' },
    defeatCondition: { type: 'native', trigger: 'libRebornAdapter_TriggerDefeat' },
  };
  writeFileSync(join(profileDir, 'zexpedition03.json'), JSON.stringify(mapProfile));

  // GalaxyManifest (minimal)
  const galaxyManifest = {
    schemaVersion: 1,
    id: 'reborn.compat',
    entries: [
      {
        file: 'Base.SC2Data/LibE0EAE146_RaynorRuntime.galaxy',
        owner: 'Commander.TerranRaynor',
        sourceMod: 'Mods/7vs1/CommanderUnits_Raynor.SC2Mod',
        compileProvides: ['LibE0EAE146_RaynorRuntime'],
        compileRequires: [],
        reason: 'Selected commander runtime',
        compatibilityOnly: false,
      },
      {
        file: 'Base.SC2Data/LibA3ADAPTER.galaxy',
        owner: 'CoreRuntime.AdapterBootstrap',
        sourceMod: 'Mods/7vs1/Alenger3Adapter.SC2Mod',
        compileProvides: ['LibA3ADAPTER'],
        compileRequires: [],
        reason: 'CoreRuntime AdapterBootstrap compatibility include',
        compatibilityOnly: true,
        removalCondition: 'generated bootstrap trims unselected adapters',
      },
    ],
  };
  writeFileSync(join(galaxyDir, 'reborn-compat-galaxy-manifest.json'), JSON.stringify(galaxyManifest));

  return root;
}

describe('generateCompositionPlan', () => {
  test('生成合法 CompositionPlan', () => {
    const root = createTempProject();
    try {
      const plan = generateCompositionPlan({
        mapName: 'zexpedition03_reborn_port.SC2Map',
        commander: 'TerranRaynor',
        projectRoot: root,
      });

      // 基本字段
      assert.equal(plan.schemaVersion, PLAN_SCHEMA_VERSION);
      assert.ok(plan.planId.includes('TerranRaynor'));
      assert.equal(plan.map.mapId, 'ZExpedition3');
      assert.equal(plan.map.mapFamily, 'RebornHotS');
      assert.equal(plan.map.adapter, 'reborn');

      // commanderSlots
      assert.equal(plan.commanderSlots.length, 1);
      assert.equal(plan.commanderSlots[0].commanderId, 'TerranRaynor');
      assert.equal(plan.commanderSlots[0].playerId, 1);

      // dependencies.always: 3 base + 2 alenger = 5
      assert.ok(plan.dependencies.always.length >= 3, `always should have at least 3 entries, got ${plan.dependencies.always.length}`);

      // dependencies.commander: 1 (CommanderUnits_Raynor)
      assert.equal(plan.dependencies.commander.length, 1);
      assert.equal(plan.dependencies.commander[0].commanderId, 'TerranRaynor');
      assert.equal(plan.dependencies.commander[0].dependencies.length, 1);
      assert.ok(plan.dependencies.commander[0].dependencies[0].path.includes('CommanderUnits_Raynor'));

      // bootstrap.galaxyIncludes: from manifest (2 entries)
      assert.equal(plan.bootstrap.galaxyIncludes.length, 2);

      // bankConfig from MapProfile
      assert.deepEqual(plan.bankConfig.protectedBanks, ['cryswarmcoop']);
      assert.deepEqual(plan.bankConfig.playerBanks, { '1': 'cryswarmcoop' });

      // victory/defeatCondition
      assert.equal(plan.victoryCondition.type, 'native');
      assert.equal(plan.defeatCondition.type, 'native');

      // _compat
      assert.ok(plan._compat);
      assert.equal(plan._compat.executionMode, 'legacy-launcher');
      assert.ok(plan._compat.sourceFacts.length >= 3);
      assert.ok(plan._compat.knownDebt.length >= 1);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  test('缺少 mapName 时抛错', () => {
    assert.throws(
      () => generateCompositionPlan({ commander: 'TerranRaynor', projectRoot: '/tmp' }),
      /mapName is required/,
    );
  });

  test('缺少 commander 时抛错', () => {
    assert.throws(
      () => generateCompositionPlan({ mapName: 'test.SC2Map', projectRoot: '/tmp' }),
      /commander is required/,
    );
  });

  test('MapProfile 不存在时抛错', () => {
    const root = createTempProject();
    try {
      assert.throws(
        () => generateCompositionPlan({
          mapName: 'nonexistent_map.SC2Map',
          commander: 'TerranRaynor',
          projectRoot: root,
        }),
        /Reborn MapProfile 不存在/,
      );
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  test('未注册的 commander 时 commander deps 为空但不报错', () => {
    const root = createTempProject();
    try {
      const plan = generateCompositionPlan({
        mapName: 'zexpedition03_reborn_port.SC2Map',
        commander: 'UnknownCommander',
        projectRoot: root,
      });
      assert.equal(plan.dependencies.commander[0].dependencies.length, 0);
      assert.equal(plan._compat.selectedCommanderUnitsMod, null);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  test('生成的 plan 通过 compositionPlan.validatePlan', () => {
    const root = createTempProject();
    try {
      const plan = generateCompositionPlan({
        mapName: 'zexpedition03_reborn_port.SC2Map',
        commander: 'TerranRaynor',
        projectRoot: root,
      });
      // _compat 是过渡期扩展字段，schema 为 additionalProperties:false，剥离后校验
      const { _compat, ...planWithoutCompat } = plan;
      const { valid, errors } = validatePlan(planWithoutCompat);
      assert.equal(valid, true, `plan 应通过校验，错误: ${errors.join('; ')}`);
      assert.equal(errors.length, 0);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });
});

describe('comparePlans', () => {
  test('一致的两个 plan 返回 consistent=true', () => {
    const root = createTempProject();
    try {
      const compositionPlan = generateCompositionPlan({
        mapName: 'zexpedition03_reborn_port.SC2Map',
        commander: 'TerranRaynor',
        projectRoot: root,
      });

      // 构造一个对齐的 launcher-plan，使用 documentRewrite 对齐
      const docDeps = [
        ...compositionPlan.dependencies.always.map((d) => d.path),
        ...compositionPlan.dependencies.commander.flatMap((c) => c.dependencies.map((d) => d.path)),
      ];
      const launcherPlan = {
        compositionId: compositionPlan.planId,
        documentRewrite: { DocumentHeader: docDeps, DocumentInfo: docDeps },
        galaxyInjection: compositionPlan.bootstrap.galaxyIncludes.map(() => ({})),
      };

      const result = comparePlans(compositionPlan, launcherPlan);
      assert.ok(result.consistent, `Expected consistent, differences: ${result.differences.join('; ')}`);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  test('galaxyIncludes 数量不一致时报告差异', () => {
    const root = createTempProject();
    try {
      const compositionPlan = generateCompositionPlan({
        mapName: 'zexpedition03_reborn_port.SC2Map',
        commander: 'TerranRaynor',
        projectRoot: root,
      });

      const docDeps = [
        ...compositionPlan.dependencies.always.map((d) => d.path),
        ...compositionPlan.dependencies.commander.flatMap((c) => c.dependencies.map((d) => d.path)),
      ];
      const launcherPlan = {
        compositionId: compositionPlan.planId,
        documentRewrite: { DocumentHeader: docDeps, DocumentInfo: docDeps },
        galaxyInjection: [], // 空数组，与 compositionPlan.bootstrap.galaxyIncludes 不一致
      };

      const result = comparePlans(compositionPlan, launcherPlan);
      assert.ok(!result.consistent);
      assert.ok(result.differences.some((d) => d.includes('galaxyIncludes count mismatch')));
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  test('planId 不一致时报告差异', () => {
    const root = createTempProject();
    try {
      const compositionPlan = generateCompositionPlan({
        mapName: 'zexpedition03_reborn_port.SC2Map',
        commander: 'TerranRaynor',
        projectRoot: root,
      });

      const docDeps = [
        ...compositionPlan.dependencies.always.map((d) => d.path),
        ...compositionPlan.dependencies.commander.flatMap((c) => c.dependencies.map((d) => d.path)),
      ];
      const launcherPlan = {
        compositionId: 'different.id',
        documentRewrite: { DocumentHeader: docDeps, DocumentInfo: docDeps },
        galaxyInjection: compositionPlan.bootstrap.galaxyIncludes.map(() => ({})),
      };

      const result = comparePlans(compositionPlan, launcherPlan);
      assert.ok(!result.consistent);
      assert.ok(result.differences.some((d) => d.includes('planId mismatch')));
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  test('document deps 数量不一致时报告差异', () => {
    const root = createTempProject();
    try {
      const compositionPlan = generateCompositionPlan({
        mapName: 'zexpedition03_reborn_port.SC2Map',
        commander: 'TerranRaynor',
        projectRoot: root,
      });

      const launcherPlan = {
        compositionId: compositionPlan.planId,
        documentRewrite: { DocumentHeader: ['only-one-dep'], DocumentInfo: ['only-one-dep'] },
        galaxyInjection: compositionPlan.bootstrap.galaxyIncludes.map(() => ({})),
      };

      const result = comparePlans(compositionPlan, launcherPlan);
      assert.ok(!result.consistent);
      assert.ok(result.differences.some((d) => d.includes('document deps count mismatch')));
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });
});
