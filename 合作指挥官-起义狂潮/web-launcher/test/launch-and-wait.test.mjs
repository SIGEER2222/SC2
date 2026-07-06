import { test } from 'node:test';
import assert from 'node:assert';
import { parseWaitExitCode, buildLaunchCommand } from '../lib/launch-and-wait.mjs';

test('parseWaitExitCode: 0=成功, 1=失败, 2=超时, 其他=未知', () => {
  assert.strictEqual(parseWaitExitCode(0).ok, true);
  assert.strictEqual(parseWaitExitCode(1).ok, false);
  assert.strictEqual(parseWaitExitCode(1).reason, 'script_error');
  assert.strictEqual(parseWaitExitCode(2).ok, false);
  assert.strictEqual(parseWaitExitCode(2).reason, 'timeout');
  assert.strictEqual(parseWaitExitCode(99).ok, false);
  assert.strictEqual(parseWaitExitCode(99).reason, 'unknown');
});

test('buildLaunchCommand: 构造 SC2Switcher 启动命令', () => {
  const cmd = buildLaunchCommand({
    mapPath: 'E:/test/map.SC2Map',
    switcherPath: 'E:/SC2/SC2Switcher_x64.exe',
  });
  assert.strictEqual(cmd.executable, 'E:/SC2/SC2Switcher_x64.exe');
  assert.deepStrictEqual(cmd.args, ['E:/test/map.SC2Map']);
});
