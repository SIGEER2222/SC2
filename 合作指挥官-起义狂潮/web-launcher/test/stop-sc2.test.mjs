import { test } from 'node:test';
import assert from 'node:assert';
import { stopAllSc2 } from '../lib/stop-sc2.mjs';

test('stopAllSc2 在没有 SC2 进程时返回 killed>=0', async () => {
  const result = await stopAllSc2();
  assert.strictEqual(result.killed >= 0, true);
  assert.strictEqual(Array.isArray(result.pids), true);
});
