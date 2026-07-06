import { test } from 'node:test';
import assert from 'node:assert';
import { buildLaunchArgs } from '../services/launch-args-builder.mjs';

test('buildLaunchArgs: 7vs1 场景构造 launch-7vs1-coop-test.ps1 参数', () => {
  const args = buildLaunchArgs({
    scenario: {
      id: 'ttosh02_7vs1',
      type: '7vs1',
      launchMode: '7vs1-launcher',
      mapPath: 'Maps/XM/ttosh02_7vs1.SC2Map',
      defaultArgs: { commander: 'ZergAbathur', masteryLevel: 30 },
    },
    userSelection: { commander: 'TerranRaynor', masteryLevel: 50 },
  });
  assert.strictEqual(args[0], '-NoProfile');
  assert.ok(args.some(a => a.includes('launch-7vs1-coop-test.ps1')));
  assert.ok(args.some(a => a === '-Commander'));
  assert.ok(args.some(a => a === 'TerranRaynor'));
});

test('buildLaunchArgs: sc2-switcher 场景返回 null 参数', () => {
  const args = buildLaunchArgs({
    scenario: {
      id: 'home_soil',
      type: 'modtest',
      launchMode: 'sc2-switcher',
      mapPath: 'Maps/Home_Soil.SC2Map',
      defaultArgs: {},
    },
    userSelection: {},
  });
  assert.strictEqual(args, null);
});

test('buildLaunchArgs: userSelection 覆盖 defaultArgs', () => {
  const args = buildLaunchArgs({
    scenario: {
      id: 'x',
      type: '7vs1',
      launchMode: '7vs1-launcher',
      mapPath: 'm.SC2Map',
      defaultArgs: { commander: 'Default', masteryLevel: 30 },
    },
    userSelection: { commander: 'Override' },
  });
  assert.ok(args.some(a => a === 'Override'));
  assert.ok(args.some(a => a === '30')); // masteryLevel 保留 default
});
