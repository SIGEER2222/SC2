/**
 * commanderPackage.mjs 单元测试
 *
 * 运行：node --test tests/commanderPackage.test.mjs
 */

import { test, describe } from 'node:test';
import { strict as assert } from 'node:assert';
import { validatePackage, extractPackageFromMod, PACKAGE_SCHEMA_VERSION } from '../src/commanderPackage.mjs';
import { mkdtempSync, writeFileSync, rmSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

describe('validatePackage', () => {
  test('合法 package 通过校验', () => {
    const pkg = makeValidPackage();
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, true, `应当通过校验，错误: ${errors.join('; ')}`);
    assert.equal(errors.length, 0);
  });

  test('非对象返回 invalid', () => {
    assert.equal(validatePackage(null).valid, false);
    assert.equal(validatePackage('string').valid, false);
    assert.equal(validatePackage([]).valid, false);
  });

  test('缺少 schemaVersion 时报错', () => {
    const pkg = makeValidPackage();
    delete pkg.schemaVersion;
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('schemaVersion')));
  });

  test('schemaVersion 必须为 1', () => {
    const pkg = makeValidPackage({ schemaVersion: 2 });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('schemaVersion 必须为 1')));
  });

  test('缺少 commanderId 时报错', () => {
    const pkg = makeValidPackage();
    delete pkg.commanderId;
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('commanderId')));
  });

  test('commanderId 必须以字母开头', () => {
    const pkg = makeValidPackage({ commanderId: '1Raynor' });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('commanderId 格式无效')));
  });

  test('commanderId 为空字符串时报错', () => {
    const pkg = makeValidPackage({ commanderId: '' });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('commanderId 必须是非空字符串')));
  });

  test('缺少 displayName 时报错', () => {
    const pkg = makeValidPackage();
    delete pkg.displayName;
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('displayName')));
  });

  test('缺少 dataCenter 时报错', () => {
    const pkg = makeValidPackage();
    delete pkg.dataCenter;
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('dataCenter')));
  });

  test('缺少 modPath 时报错', () => {
    const pkg = makeValidPackage();
    delete pkg.modPath;
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('modPath')));
  });

  test('techTree 必须是对象', () => {
    const pkg = makeValidPackage({ techTree: 'not object' });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('techTree 必须是对象')));
  });

  test('techTree.buildings 必须是数组', () => {
    const pkg = makeValidPackage({ techTree: { buildings: 'not array', units: [], upgrades: [], abilities: [] } });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('techTree.buildings 必须是数组')));
  });

  test('techTree.units 元素必须是非空字符串', () => {
    const pkg = makeValidPackage({ techTree: { buildings: [], units: ['Marine', ''], upgrades: [], abilities: [] } });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('techTree.units 的每个元素必须是非空字符串')));
  });

  test('runtimeHooks 必须是对象', () => {
    const pkg = makeValidPackage({ runtimeHooks: 'not object' });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('runtimeHooks 必须是对象')));
  });

  test('runtimeHooks.initFunction 必须是字符串', () => {
    const pkg = makeValidPackage({ runtimeHooks: { initFunction: 123, applyTechFunction: 'a', createStartSquadFunction: 'b' } });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('runtimeHooks.initFunction 必须是字符串')));
  });

  test('panelLayout 必须是对象', () => {
    const pkg = makeValidPackage({ panelLayout: 'not object' });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('panelLayout 必须是对象')));
  });

  test('panelLayout.topPanelAbilities 必须是数组', () => {
    const pkg = makeValidPackage({ panelLayout: { topPanelAbilities: 'not array', commandCardLayouts: [] } });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('topPanelAbilities 必须是数组')));
  });

  test('prestiges 必须是数组', () => {
    const pkg = makeValidPackage({ prestiges: 'not array' });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('prestiges 必须是数组')));
  });

  test('compatibleMapFamilies 必须是数组', () => {
    const pkg = makeValidPackage({ compatibleMapFamilies: 'not array' });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('compatibleMapFamilies 必须是数组')));
  });

  test('PACKAGE_SCHEMA_VERSION 常量导出', () => {
    assert.equal(PACKAGE_SCHEMA_VERSION, 1);
  });
});

describe('TerranRaynor.json 集成校验', () => {
  test('真实 TerranRaynor.json 通过 validatePackage', () => {
    const pkgPath = join(__dirname, '..', '..', '..', 'Mods', '7vs1', 'CommanderPackages', 'TerranRaynor.json');
    const pkg = JSON.parse(readFileSync(pkgPath, 'utf8'));
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, true, `TerranRaynor.json 应通过校验，错误: ${errors.join('; ')}`);
  });

  test('TerranRaynor.json 包含 3 个威望', () => {
    const pkgPath = join(__dirname, '..', '..', '..', 'Mods', '7vs1', 'CommanderPackages', 'TerranRaynor.json');
    const pkg = JSON.parse(readFileSync(pkgPath, 'utf8'));
    assert.equal(pkg.prestiges.length, 3);
    assert.ok(pkg.prestiges.every(p => p.id && p.name && p.modifier));
  });

  test('TerranRaynor.json 包含 6 个精通', () => {
    const pkgPath = join(__dirname, '..', '..', '..', 'Mods', '7vs1', 'CommanderPackages', 'TerranRaynor.json');
    const pkg = JSON.parse(readFileSync(pkgPath, 'utf8'));
    assert.equal(pkg.masteries.length, 6);
    assert.ok(pkg.masteries.every(m => m.id && m.name && m.stat));
  });
});

describe('extractPackageFromMod', () => {
  test('DataCenter.json 不存在时抛错', async () => {
    const tmp = mkdtempSync(join(tmpdir(), 'sc2-cmd-'));
    try {
      await assert.rejects(
        () => extractPackageFromMod(tmp),
        /DataCenter\.json 不存在/,
      );
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  test('type 非 CommanderDataCenter 时抛错', async () => {
    const tmp = mkdtempSync(join(tmpdir(), 'sc2-cmd-'));
    try {
      const dc = {
        schemaVersion: 1,
        id: 'Platform.CoreRuntime',
        type: 'PlatformDataCenter',
        gameDataEntry: 'Base.SC2Data/GameData.xml',
        spaces: [],
      };
      writeFileSync(join(tmp, 'DataCenter.json'), JSON.stringify(dc));
      await assert.rejects(
        () => extractPackageFromMod(tmp),
        /必须是 CommanderDataCenter/,
      );
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  test('id 格式无效时抛错', async () => {
    const tmp = mkdtempSync(join(tmpdir(), 'sc2-cmd-'));
    try {
      const dc = {
        schemaVersion: 1,
        id: 'InvalidId',
        type: 'CommanderDataCenter',
        gameDataEntry: 'Base.SC2Data/GameData.xml',
        spaces: [],
      };
      writeFileSync(join(tmp, 'DataCenter.json'), JSON.stringify(dc));
      await assert.rejects(
        () => extractPackageFromMod(tmp),
        /id 格式无效/,
      );
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  test('从合法 DataCenter 提取 CommanderPackage 草案', async () => {
    const tmp = mkdtempSync(join(tmpdir(), 'sc2-cmd-'));
    try {
      const dc = {
        schemaVersion: 1,
        id: 'Commander.TerranRaynor',
        type: 'CommanderDataCenter',
        gameDataEntry: 'Base.SC2Data/GameData.xml',
        spaces: [
          { path: 'GameData/RaynorUnits.xml', owns: ['CUnit'], catalogIds: ['Marine'] },
        ],
        exports: {
          units: ['Marine', 'Marauder'],
          abilities: ['Stimpack'],
        },
        galaxyRuntime: {
          initFunction: 'RaynorRuntime_Init',
          applyTechFunction: 'RaynorRuntime_ApplyTech',
          createStartSquadFunction: 'RaynorRuntime_CreateStartSquad',
        },
      };
      writeFileSync(join(tmp, 'DataCenter.json'), JSON.stringify(dc));

      const pkg = await extractPackageFromMod(tmp);

      // 顶层字段
      assert.equal(pkg.schemaVersion, 1);

      // schema 字段
      assert.equal(pkg.commanderId, 'TerranRaynor');
      assert.equal(pkg.displayName, 'TerranRaynor');
      assert.equal(pkg.dataCenter, 'Commander.TerranRaynor');
      assert.ok(pkg.modPath.includes('sc2-cmd-'));

      // techTree 从 exports 填充
      assert.deepEqual(pkg.techTree.units, ['Marine', 'Marauder']);
      assert.deepEqual(pkg.techTree.abilities, ['Stimpack']);
      assert.deepEqual(pkg.techTree.buildings, []);
      assert.deepEqual(pkg.techTree.upgrades, []);

      // runtimeHooks 从 galaxyRuntime 填充
      assert.equal(pkg.runtimeHooks.initFunction, 'RaynorRuntime_Init');
      assert.equal(pkg.runtimeHooks.applyTechFunction, 'RaynorRuntime_ApplyTech');
      assert.equal(pkg.runtimeHooks.createStartSquadFunction, 'RaynorRuntime_CreateStartSquad');

      // 提取结果应该通过 validatePackage
      const { valid, errors } = validatePackage(pkg);
      assert.equal(valid, true, `提取的 package 应通过校验，错误: ${errors.join('; ')}`);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  test('DataCenter.json 解析失败时抛错', async () => {
    const tmp = mkdtempSync(join(tmpdir(), 'sc2-cmd-'));
    try {
      writeFileSync(join(tmp, 'DataCenter.json'), '{invalid json');
      await assert.rejects(
        () => extractPackageFromMod(tmp),
        /解析失败/,
      );
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  test('无 galaxyRuntime 时 runtimeHooks 为空字符串', async () => {
    const tmp = mkdtempSync(join(tmpdir(), 'sc2-cmd-'));
    try {
      const dc = {
        schemaVersion: 1,
        id: 'Commander.TerranRaynor',
        type: 'CommanderDataCenter',
        gameDataEntry: 'Base.SC2Data/GameData.xml',
        spaces: [],
      };
      writeFileSync(join(tmp, 'DataCenter.json'), JSON.stringify(dc));
      const pkg = await extractPackageFromMod(tmp);
      assert.equal(pkg.runtimeHooks.initFunction, '');
      assert.equal(pkg.runtimeHooks.applyTechFunction, '');
      assert.equal(pkg.runtimeHooks.createStartSquadFunction, '');
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});

/**
 * 构造一个合法的 CommanderPackage（遵循 CommanderPackage.schema.json），可选 override 字段。
 */
function makeValidPackage(overrides = {}) {
  return {
    schemaVersion: 1,
    commanderId: 'TerranRaynor',
    displayName: '雷诺',
    dataCenter: 'Commander.Raynor',
    modPath: 'Mods/7vs1/CommanderUnits_Raynor.SC2Mod',
    techTree: {
      buildings: ['BarracksRaynor'],
      units: ['MarineRaynor'],
      upgrades: [],
      abilities: ['Stimpack'],
    },
    runtimeHooks: {
      initFunction: 'libE0EAE146_gf_RaynorRuntimeInit',
      applyTechFunction: 'libE0EAE146_gf_RaynorApplyTechFilter',
      createStartSquadFunction: 'libE0EAE146_gf_RaynorCreateMapStartSquad',
    },
    panelLayout: {
      topPanelAbilities: ['VoidCoopSummonHyperion'],
      commandCardLayouts: [],
    },
    prestiges: [],
    masteries: [],
    compatibleMapFamilies: [],
    incompatibleMapFamilies: [],
    ...overrides,
  };
}
