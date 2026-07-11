/**
 * commanderPackage.mjs 单元测试
 *
 * 运行：node --test tests/commanderPackage.test.mjs
 */

import { test, describe } from 'node:test';
import { strict as assert } from 'node:assert';
import { validatePackage, extractPackageFromMod, PACKAGE_SCHEMA_VERSION } from '../src/commanderPackage.mjs';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

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

  test('缺少 identity 时报错', () => {
    const pkg = makeValidPackage();
    delete pkg.identity;
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('identity')));
  });

  test('identity.id 必须是非空字符串', () => {
    const pkg = makeValidPackage({ identity: { id: '', race: 'Terran' } });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('identity.id 必须是非空字符串')));
  });

  test('identity.aliases 必须是数组', () => {
    const pkg = makeValidPackage({ identity: { id: 'X', aliases: 'not array' } });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('aliases 必须是数组')));
  });

  test('dependencies 必须是对象', () => {
    const pkg = makeValidPackage({ dependencies: 'not object' });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('dependencies 必须是对象')));
  });

  test('dependencies.requiredBaseMods 必须是数组', () => {
    const pkg = makeValidPackage({ dependencies: { requiredBaseMods: 'not array' } });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('requiredBaseMods 必须是数组')));
  });

  test('catalog 必须是对象', () => {
    const pkg = makeValidPackage({ catalog: 'not object' });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('catalog 必须是对象')));
  });

  test('catalog.ownedIds 必须是数组', () => {
    const pkg = makeValidPackage({ catalog: { ownedIds: 'not array' } });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('ownedIds 必须是数组')));
  });

  test('runtime 必须是对象', () => {
    const pkg = makeValidPackage({ runtime: 'not object' });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('runtime 必须是对象')));
  });

  test('runtime.init 必须是字符串', () => {
    const pkg = makeValidPackage({ runtime: { init: 123 } });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('runtime.init 必须是字符串')));
  });

  test('validation.expectedUnits 必须是数组', () => {
    const pkg = makeValidPackage({ validation: { expectedUnits: 'not array' } });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('expectedUnits 必须是数组')));
  });

  test('metadata 必须是对象', () => {
    const pkg = makeValidPackage({ metadata: 'not object' });
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, false);
    assert.ok(errors.some(e => e.includes('metadata 必须是对象')));
  });

  test('最小合法 package（仅 schemaVersion + identity）', () => {
    const pkg = { schemaVersion: 1, identity: { id: 'TestCmd' } };
    const { valid, errors } = validatePackage(pkg);
    assert.equal(valid, true, `应当通过校验，错误: ${errors.join('; ')}`);
  });

  test('PACKAGE_SCHEMA_VERSION 常量导出', () => {
    assert.equal(PACKAGE_SCHEMA_VERSION, 1);
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
        imports: {
          capabilities: ['hero-revive', 'top-panel'],
        },
        galaxyRuntime: {
          initFunction: 'RaynorRuntime_Init',
          applyTechFunction: 'RaynorRuntime_ApplyTech',
          createStartSquadFunction: 'RaynorRuntime_CreateStartSquad',
        },
        localization: { enUS: 'enUS.SC2Data/LocalizedData/GameStrings.txt' },
      };
      writeFileSync(join(tmp, 'DataCenter.json'), JSON.stringify(dc));

      const pkg = await extractPackageFromMod(tmp);

      // 顶层字段
      assert.equal(pkg.schemaVersion, 1);

      // identity
      assert.equal(pkg.identity.id, 'TerranRaynor');
      assert.equal(pkg.identity.race, 'Terran');
      assert.equal(pkg.identity.version, 1);
      assert.deepEqual(pkg.identity.aliases, []);

      // dependencies
      assert.deepEqual(pkg.dependencies.requiredCapabilities, ['hero-revive', 'top-panel']);
      assert.deepEqual(pkg.dependencies.requiredBaseMods, []);

      // catalog.ownedIds 应包含所有 exports 中的 ID
      assert.ok(pkg.catalog.ownedIds.includes('Marine'));
      assert.ok(pkg.catalog.ownedIds.includes('Marauder'));
      assert.ok(pkg.catalog.ownedIds.includes('Stimpack'));

      // runtime 字段映射
      assert.equal(pkg.runtime.init, 'RaynorRuntime_Init');
      assert.equal(pkg.runtime.applyTech, 'RaynorRuntime_ApplyTech');
      assert.equal(pkg.runtime.createStartSquad, 'RaynorRuntime_CreateStartSquad');

      // validation
      assert.deepEqual(pkg.validation.expectedUnits, ['Marine', 'Marauder']);
      assert.deepEqual(pkg.validation.expectedAbilities, ['Stimpack']);

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

  test('Zerg commander 推断 race 为 Zerg', async () => {
    const tmp = mkdtempSync(join(tmpdir(), 'sc2-cmd-'));
    try {
      const dc = {
        schemaVersion: 1,
        id: 'Commander.Kerrigan',
        type: 'CommanderDataCenter',
        gameDataEntry: 'Base.SC2Data/GameData.xml',
        spaces: [],
      };
      writeFileSync(join(tmp, 'DataCenter.json'), JSON.stringify(dc));
      const pkg = await extractPackageFromMod(tmp);
      assert.equal(pkg.identity.race, 'Zerg');
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  test('Protoss commander 推断 race 为 Protoss', async () => {
    const tmp = mkdtempSync(join(tmpdir(), 'sc2-cmd-'));
    try {
      const dc = {
        schemaVersion: 1,
        id: 'Commander.Zeratul',
        type: 'CommanderDataCenter',
        gameDataEntry: 'Base.SC2Data/GameData.xml',
        spaces: [],
      };
      writeFileSync(join(tmp, 'DataCenter.json'), JSON.stringify(dc));
      const pkg = await extractPackageFromMod(tmp);
      assert.equal(pkg.identity.race, 'Protoss');
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});

/**
 * 构造一个合法的 CommanderPackage，可选 override 字段。
 */
function makeValidPackage(overrides = {}) {
  return {
    schemaVersion: 1,
    identity: {
      id: 'TerranRaynor',
      aliases: ['Raynor'],
      race: 'Terran',
      version: 1,
    },
    dependencies: {
      requiredBaseMods: [],
      requiredCapabilities: ['top-panel'],
    },
    catalog: {
      ownedIds: ['Marine'],
      extendedIds: [],
      localizationRoots: [],
    },
    runtime: {
      init: 'RaynorRuntime_Init',
      applyTech: 'RaynorRuntime_ApplyTech',
      createStartSquad: 'RaynorRuntime_CreateStartSquad',
    },
    metadata: {},
    requirements: { mapCapabilities: [] },
    validation: {
      expectedProducers: [],
      expectedUnits: [],
      expectedAbilities: [],
      runtimeProbes: [],
    },
    ...overrides,
  };
}
