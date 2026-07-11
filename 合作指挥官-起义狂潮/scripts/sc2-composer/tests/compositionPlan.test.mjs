/**
 * compositionPlan.mjs 单元测试
 *
 * 运行：node --test tests/compositionPlan.test.mjs
 */

import { test, describe } from 'node:test';
import { strict as assert } from 'node:assert';
import { validatePlan, resolveDependencies, detectConflicts, PLAN_SCHEMA_VERSION, DEPENDENCY_LAYERS } from '../src/compositionPlan.mjs';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

describe('validatePlan', () => {
  test('合法 plan 通过校验', () => {
    const plan = {
      schemaVersion: 1,
      compositionId: 'reborn.zexpedition03__p1-TerranRaynor',
      mapProfile: 'reborn.zexpedition03',
      slots: {
        '1': { commander: 'TerranRaynor', adapter: 'TerranRaynor@generic-campaign' },
      },
      dependencyLayers: [],
      capabilities: {},
      catalogDecisions: [],
      localPatches: [],
      generatedBootstrap: '',
      validation: {},
    };
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, true, `应当通过校验，错误: ${errors.join('; ')}`);
    assert.equal(errors.length, 0);
  });

  test('非对象返回 invalid', () => {
    assert.equal(validatePlan(null).valid, false);
    assert.equal(validatePlan('not an object').valid, false);
    assert.equal(validatePlan([]).valid, false);
  });

  test('缺少必填字段时收集所有错误', () => {
    const { valid, errors } = validatePlan({});
    assert.equal(valid, false);
    // schemaVersion / compositionId / mapProfile / slots
    assert.ok(errors.some(e => e.includes('schemaVersion')));
    assert.ok(errors.some(e => e.includes('compositionId')));
    assert.ok(errors.some(e => e.includes('mapProfile')));
    assert.ok(errors.some(e => e.includes('slots')));
  });

  test('schemaVersion 必须为 1', () => {
    const plan = makeValidPlan({ schemaVersion: 2 });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('schemaVersion 必须为 1')));
  });

  test('slots 必须是对象', () => {
    const plan = makeValidPlan({ slots: [] });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('slots 必须是对象')));
  });

  test('slots 键必须是数字字符串', () => {
    const plan = makeValidPlan({ slots: { abc: { commander: 'X' } } });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('必须是数字字符串')));
  });

  test('slot.commander 必填', () => {
    const plan = makeValidPlan({ slots: { '1': { adapter: 'X' } } });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('commander 缺失')));
  });

  test('slots 不能为空', () => {
    const plan = makeValidPlan({ slots: {} });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('slots 不能为空')));
  });

  test('可选字段类型检查 - dependencyLayers 必须是数组', () => {
    const plan = makeValidPlan({ dependencyLayers: 'not array' });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('dependencyLayers 必须是数组')));
  });

  test('可选字段类型检查 - capabilities 必须是对象', () => {
    const plan = makeValidPlan({ capabilities: [] });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('capabilities 必须是对象')));
  });

  test('PLAN_SCHEMA_VERSION 常量导出', () => {
    assert.equal(PLAN_SCHEMA_VERSION, 1);
  });

  test('DEPENDENCY_LAYERS 包含 L0-L8', () => {
    const layers = DEPENDENCY_LAYERS.map(l => l.layer);
    assert.deepEqual(layers, ['L0', 'L1', 'L2', 'L3', 'L4', 'L5', 'L6', 'L7', 'L8']);
  });
});

// ============================================================
// 新 schema 格式（planId/map/commanderSlots/...）校验测试
// ============================================================

describe('validatePlan 新 schema 格式', () => {
  test('合法新格式 plan 通过校验', () => {
    const plan = makeValidNewPlan();
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, true, `应当通过校验，错误: ${errors.join('; ')}`);
    assert.equal(errors.length, 0);
  });

  test('map 必填字段缺失时报错', () => {
    const plan = makeValidNewPlan({
      map: { mapId: '', mapFamily: 'X', mapName: 'X', source: 'X', adapter: 'X' },
    });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('map.mapId 必须是非空字符串')));
  });

  test('commanderSlots 元素缺少 commanderId 时报错', () => {
    const plan = makeValidNewPlan({
      commanderSlots: [{ slotIndex: 0, playerId: 1, commanderId: '' }],
    });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('commanderId 必须是非空字符串')));
  });

  test('commanderSlots slotIndex/playerId 类型检查', () => {
    const plan = makeValidNewPlan({
      commanderSlots: [{ slotIndex: -1, playerId: 0, commanderId: 'X' }],
    });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('slotIndex 必须是非负整数')));
    assert.ok(errors.some(e => e.includes('playerId 必须是 >= 1 的整数')));
  });

  test('slot.prestige 必须是字符串或 null', () => {
    const plan = makeValidNewPlan({
      commanderSlots: [{ slotIndex: 0, playerId: 1, commanderId: 'X', prestige: 123 }],
    });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('prestige 必须是字符串或 null')));
  });

  test('dependencies.always 元素缺少 path 时报错', () => {
    const plan = makeValidNewPlan({
      dependencies: {
        always: [{ path: '', layer: 'L0', source: 'X' }],
        commander: [],
        pairPatches: [],
      },
    });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('path 必须是非空字符串')));
  });

  test('dependencies.commander[].slotIndex 必须是非负整数', () => {
    const plan = makeValidNewPlan({
      dependencies: {
        always: [],
        commander: [{ slotIndex: -1, commanderId: 'X', dependencies: [] }],
        pairPatches: [],
      },
    });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('slotIndex 必须是非负整数')));
  });

  test('dependencies.pairPatches 缺少 patchPath 时报错', () => {
    const plan = makeValidNewPlan({
      dependencies: {
        always: [],
        commander: [],
        pairPatches: [{ commanderId: 'X', patchPath: '', reason: 'X' }],
      },
    });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('patchPath 必须是非空字符串')));
  });

  test('conflictResolution.overrideStrategy 非法时报错', () => {
    const plan = makeValidNewPlan({
      conflictResolution: { overrideStrategy: 'invalid', allowedConflicts: [] },
    });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('overrideStrategy 非法')));
  });

  test('bankConfig.protectedBanks 必须是数组', () => {
    const plan = makeValidNewPlan({
      bankConfig: { protectedBanks: 'not array', playerBanks: {} },
    });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('protectedBanks 必须是数组')));
  });

  test('victoryCondition.type 非法时报错', () => {
    const plan = makeValidNewPlan({
      victoryCondition: { type: 'invalid' },
    });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('victoryCondition.type 必须是')));
  });

  test('bootstrap.galaxyIncludes 元素缺少 path 时报错', () => {
    const plan = makeValidNewPlan({
      bootstrap: {
        galaxyIncludes: [{ path: '', purpose: 'X' }],
        initSequence: [],
        runtimeOverrides: [],
      },
    });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('path 必须是非空字符串')));
  });

  test('bootstrap.initSequence 元素缺少 function 时报错', () => {
    const plan = makeValidNewPlan({
      bootstrap: {
        galaxyIncludes: [],
        initSequence: [{ phase: 'CompositionRegistered', function: '' }],
        runtimeOverrides: [],
      },
    });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('function 必须是非空字符串')));
  });

  test('bootstrap.runtimeOverrides value 必须是基本类型', () => {
    const plan = makeValidNewPlan({
      bootstrap: {
        galaxyIncludes: [],
        initSequence: [],
        runtimeOverrides: [{ target: 'X', fieldPath: 'X', value: { obj: true } }],
      },
    });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('value 必须是 string/number/boolean')));
  });

  test('bootstrap.runtimeOverrides value 接受 boolean', () => {
    const plan = makeValidNewPlan({
      bootstrap: {
        galaxyIncludes: [],
        initSequence: [],
        runtimeOverrides: [{ target: 'X', fieldPath: 'X', value: true, reason: 'X' }],
      },
    });
    const { valid, errors } = validatePlan(plan);
    assert.equal(valid, true, `应当通过校验，错误: ${errors.join('; ')}`);
  });
});

/**
 * 构造一个合法的新 schema CompositionPlan，可选 override 字段。
 */
function makeValidNewPlan(overrides = {}) {
  return {
    schemaVersion: 1,
    planId: 'reborn.test__p1-TerranRaynor',
    map: {
      mapId: 'Test',
      mapFamily: 'RebornHotS',
      mapName: 'Test Map',
      source: 'Maps/test.SC2Map',
      adapter: 'reborn',
    },
    commanderSlots: [
      { slotIndex: 0, playerId: 1, commanderId: 'TerranRaynor', prestige: null, mastery: null, talents: [], bonuses: [] },
    ],
    dependencies: {
      always: [],
      commander: [],
      pairPatches: [],
    },
    conflictResolution: {
      overrideStrategy: 'preserve-map',
      allowedConflicts: [],
    },
    bankConfig: {
      protectedBanks: [],
      playerBanks: {},
    },
    victoryCondition: { type: 'native' },
    defeatCondition: { type: 'native' },
    bootstrap: {
      galaxyIncludes: [],
      initSequence: [],
      runtimeOverrides: [],
    },
    ...overrides,
  };
}

describe('resolveDependencies', () => {
  test('校验失败时抛错', async () => {
    await assert.rejects(
      () => resolveDependencies({}, '/tmp'),
      /CompositionPlan 校验失败/,
    );
  });

  test('MapProfile 不存在时记入 missing', async () => {
    const plan = makeValidPlan();
    const tmpRoot = mkdtempSync(join(tmpdir(), 'sc2-comp-'));
    try {
      const { layers, missing } = await resolveDependencies(plan, tmpRoot);
      assert.ok(missing.some(m => m.includes('MapProfile 未找到')));
      // CommanderPackage 也未找到
      assert.ok(missing.some(m => m.includes('CommanderPackage 未找到')));
      // L4 层应包含一个 missing entry
      const l4 = layers.find(l => l.layer === 'L4');
      assert.ok(l4, '应当有 L4 层');
      assert.ok(l4.entries.some(e => e.missing === true));
    } finally {
      rmSync(tmpRoot, { recursive: true, force: true });
    }
  });

  test('存在 MapProfile 时输出 L1 依赖', async () => {
    const plan = makeValidPlan();
    const tmpRoot = mkdtempSync(join(tmpdir(), 'sc2-comp-'));
    try {
      // 创建 MapProfile 文件
      const profilesDir = join(tmpRoot, 'Shared', 'Maps', 'profiles');
      mkdirSync(profilesDir, { recursive: true });
      const mapProfile = {
        schemaVersion: 1,
        mapFamily: 'reborn',
        mapId: 'zexpedition03',
        mapName: 'Test',
        mapAdapter: 'reborn',
        entryType: 'direct',
        commanderSlots: [{ slotIndex: 0, playerId: 1, commanderId: null }],
        pairPatches: [],
        requiredDependencies: {
          always: [
            'file:Mods/Platform/PlatformKernel.SC2Mod',
            'file:Mods/Reborn/RebornMapAdapter.SC2Mod',
          ],
        },
        bankProtection: { protectedBanks: [], playerBanks: {} },
        victoryCondition: { type: 'native' },
        defeatCondition: { type: 'native' },
      };
      writeFileSync(join(profilesDir, 'reborn.zexpedition03.json'), JSON.stringify(mapProfile));

      const { layers, missing } = await resolveDependencies(plan, tmpRoot);
      const l1 = layers.find(l => l.layer === 'L1');
      assert.ok(l1, '应当有 L1 层');
      assert.equal(l1.entries.length, 2);
      assert.ok(l1.entries.some(e => e.path.includes('PlatformKernel')));
      assert.ok(l1.entries.some(e => e.path.includes('RebornMapAdapter')));
      // MapProfile 找到了，missing 不应包含它
      assert.ok(!missing.some(m => m.includes('MapProfile 未找到')));
    } finally {
      rmSync(tmpRoot, { recursive: true, force: true });
    }
  });

  test('存在 CommanderPackage 时输出 L4 依赖', async () => {
    const plan = makeValidPlan();
    const tmpRoot = mkdtempSync(join(tmpdir(), 'sc2-comp-'));
    try {
      // 创建 CommanderPackage
      const cmdDir = join(tmpRoot, 'Shared', 'Commanders');
      mkdirSync(cmdDir, { recursive: true });
      const pkg = {
        schemaVersion: 1,
        identity: { id: 'TerranRaynor', race: 'Terran', version: 1, aliases: [] },
      };
      writeFileSync(join(cmdDir, 'TerranRaynor.json'), JSON.stringify(pkg));

      const { layers, missing } = await resolveDependencies(plan, tmpRoot);
      const l4 = layers.find(l => l.layer === 'L4');
      assert.ok(l4, '应当有 L4 层');
      assert.equal(l4.entries.length, 1);
      assert.equal(l4.entries[0].commander, 'TerranRaynor');
      assert.equal(l4.entries[0].slot, '1');
      assert.ok(!l4.entries[0].missing);
      // missing 不应包含 CommanderPackage
      assert.ok(!missing.some(m => m.includes('CommanderPackage 未找到')));
    } finally {
      rmSync(tmpRoot, { recursive: true, force: true });
    }
  });

  test('MapProfile.pairPatches 匹配选中 commander 时输出 L7', async () => {
    const plan = makeValidPlan();
    const tmpRoot = mkdtempSync(join(tmpdir(), 'sc2-comp-'));
    try {
      const profilesDir = join(tmpRoot, 'Shared', 'Maps', 'profiles');
      mkdirSync(profilesDir, { recursive: true });
      const mapProfile = {
        schemaVersion: 1,
        mapFamily: 'reborn',
        mapId: 'zexpedition03',
        mapName: 'Test',
        mapAdapter: 'reborn',
        entryType: 'direct',
        commanderSlots: [],
        pairPatches: [
          { commanderId: 'TerranRaynor', patchPath: 'Shared/Compatibility/reborn/TerranRaynor.json', reason: '测试补丁' },
        ],
        requiredDependencies: { always: [] },
        bankProtection: { protectedBanks: [], playerBanks: {} },
        victoryCondition: { type: 'native' },
        defeatCondition: { type: 'native' },
      };
      writeFileSync(join(profilesDir, 'reborn.zexpedition03.json'), JSON.stringify(mapProfile));

      const { layers } = await resolveDependencies(plan, tmpRoot);
      const l7 = layers.find(l => l.layer === 'L7');
      assert.ok(l7, '应当有 L7 层');
      assert.equal(l7.entries.length, 1);
      assert.equal(l7.entries[0].commander, 'TerranRaynor');
      assert.equal(l7.entries[0].path, 'Shared/Compatibility/reborn/TerranRaynor.json');
    } finally {
      rmSync(tmpRoot, { recursive: true, force: true });
    }
  });

  test('plan.localPatches 也作为 L7 候选', async () => {
    const plan = makeValidPlan({
      localPatches: [
        { path: 'Shared/Compatibility/local.json', commander: 'TerranRaynor', reason: '本地补丁' },
      ],
    });
    const tmpRoot = mkdtempSync(join(tmpdir(), 'sc2-comp-'));
    try {
      const { layers } = await resolveDependencies(plan, tmpRoot);
      const l7 = layers.find(l => l.layer === 'L7');
      assert.ok(l7, '应当有 L7 层');
      assert.ok(l7.entries.some(e => e.path === 'Shared/Compatibility/local.json'));
    } finally {
      rmSync(tmpRoot, { recursive: true, force: true });
    }
  });
});

describe('detectConflicts', () => {
  test('占位实现返回空数组', async () => {
    const plan = makeValidPlan();
    const result = await detectConflicts(plan, '/tmp');
    assert.deepEqual(result, []);
  });
});

/**
 * 构造一个合法的 CompositionPlan，可选 override 字段。
 */
function makeValidPlan(overrides = {}) {
  return {
    schemaVersion: 1,
    compositionId: 'reborn.zexpedition03__p1-TerranRaynor',
    mapProfile: 'reborn.zexpedition03',
    slots: {
      '1': { commander: 'TerranRaynor', adapter: 'TerranRaynor@generic-campaign' },
    },
    ...overrides,
  };
}
