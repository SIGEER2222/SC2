import { test } from 'node:test';
import assert from 'node:assert';
import { buildLaunchArgs, buildCommandLine } from '../services/launch-args-builder.mjs';
import { loadCommanders } from '../lib/commanders-loader.mjs';
import { loadMaps } from '../lib/maps-loader.mjs';
import { loadMutators } from '../lib/mutators-loader.mjs';

const commanders = loadCommanders();
const maps = loadMaps();
const mutators = loadMutators();

const commander = commanders[0]?.runtime;
const map7vs1 = maps.find((m) => m.launchMode === '7vs1');
const mapXm = maps.find((m) => m.launchMode === 'xm-scenario');
const mutatorId = mutators[0]?.id;

test('数据前置条件：指挥官/地图/因子已加载', () => {
  assert.ok(commander, '至少存在一个指挥官');
  assert.ok(map7vs1, '至少存在一张 *_7vs1.SC2Map 地图');
  assert.ok(mutatorId, '至少存在一个因子');
});

test('buildLaunchArgs: 7vs1 地图使用 launch-7vs1-coop-test.ps1 + MapSource/LiveMapName', () => {
  const { args, score } = buildLaunchArgs({
    commander,
    map: map7vs1.id,
    mutators: [mutatorId, mutatorId],
  });
  assert.strictEqual(args[0], '-NoProfile');
  assert.ok(args.some((a) => String(a).includes('launch-7vs1-coop-test.ps1')));
  const mapSourceIndex = args.indexOf('-MapSource');
  assert.ok(mapSourceIndex >= 0);
  assert.strictEqual(args[args.indexOf('-LiveMapName') + 1], map7vs1.id);
  assert.strictEqual(args[args.indexOf('-Commanders') + 1], commander);
  // 因子去重后以逗号拼接
  assert.strictEqual(args[args.indexOf('-Mutators') + 1], mutatorId);
  assert.strictEqual(args[args.indexOf('-VoicePack') + 1], 'Default');
  assert.strictEqual(args[args.indexOf('-MutatorPreset') + 1], '0');
  assert.ok(!args.includes('-NoLaunch'));
  assert.strictEqual(typeof score.balanceAfterSelection, 'number');
});

test('buildLaunchArgs: xm 地图使用 launch-xm-scenario.ps1 + MapPath', (t) => {
  if (!mapXm) {
    t.skip('工作区没有 *_xm.SC2Map 地图');
    return;
  }
  const { args } = buildLaunchArgs({ commander, map: mapXm.id });
  assert.ok(args.some((a) => String(a).includes('launch-xm-scenario.ps1')));
  assert.strictEqual(args[args.indexOf('-MapPath') + 1], mapXm.path);
  assert.strictEqual(args.indexOf('-MapSource'), -1);
  assert.strictEqual(args.indexOf('-LiveMapName'), -1);
});

test('buildLaunchArgs: noLaunch=true 追加 -NoLaunch', () => {
  const { args } = buildLaunchArgs({ commander, map: map7vs1.id, noLaunch: true });
  assert.ok(args.includes('-NoLaunch'));
});

test('buildLaunchArgs: 启动天赋掩码 > 0 时追加 StartTalentMask 覆盖项', () => {
  const { args } = buildLaunchArgs({
    commander,
    map: map7vs1.id,
    enableStartTalents: true,
    startTalentMask: 5,
  });
  const overrideIndex = args.indexOf('-CommanderPowerOverride');
  assert.ok(overrideIndex >= 0);
  assert.strictEqual(args[overrideIndex + 1], `${commander}.StartTalentMask=5`);
});

test('buildLaunchArgs: enableStartTalents=false 时不追加 StartTalentMask', () => {
  const { args } = buildLaunchArgs({
    commander,
    map: map7vs1.id,
    enableStartTalents: false,
    startTalentMask: 5,
  });
  assert.strictEqual(args.indexOf('-CommanderPowerOverride'), -1);
});

test('buildLaunchArgs: 可分级通用加成序列化为 id=level', () => {
  const { args } = buildLaunchArgs({
    commander,
    map: map7vs1.id,
    genericBonuses: ['RichResources'],
    genericBonusLevels: { DoubleMinerals: 2 },
  });
  const serialized = args[args.indexOf('-GenericBonuses') + 1];
  const parts = serialized.split(',');
  assert.ok(parts.includes('RichResources'));
  assert.ok(parts.includes('DoubleMinerals=2'));
});

test('buildLaunchArgs: 未知指挥官/地图/因子/加成抛错', () => {
  assert.throws(() => buildLaunchArgs({ commander: 'NoSuchCommander', map: map7vs1.id }), /Unknown commander/);
  assert.throws(() => buildLaunchArgs({ commander, map: 'NoSuchMap' }), /Unknown map/);
  assert.throws(() => buildLaunchArgs({ commander, map: map7vs1.id, mutators: ['NoSuchMutator'] }), /Unknown mutator/);
  assert.throws(() => buildLaunchArgs({ commander, map: map7vs1.id, genericBonuses: ['NoSuchBonus'] }), /Unknown generic bonus/);
  assert.throws(() => buildLaunchArgs({ commander, map: map7vs1.id, voicePack: 'NoSuchPack' }), /Unknown voice pack/);
  assert.throws(() => buildLaunchArgs({ commander, map: map7vs1.id, commanderOverrides: ['not-an-override'] }), /Invalid commander override/);
});

test('buildCommandLine: 带空格参数加引号', () => {
  const line = buildCommandLine(['-File', 'C:\\path with space\\a.ps1', '-Flag']);
  assert.ok(line.startsWith('pwsh '));
  assert.ok(line.includes('"C:\\path with space\\a.ps1"'));
});
