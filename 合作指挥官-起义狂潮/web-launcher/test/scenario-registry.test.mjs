import { test } from 'node:test';
import assert from 'node:assert';
import { loadScenarios, getScenario, getScenariosByTab } from '../services/scenario-registry.mjs';
import { writeFileSync, mkdtempSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';

test('loadScenarios 从 JSON 文件加载场景', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'sr-'));
  writeFileSync(join(tmp, 'maps.json'), JSON.stringify({
    scenarios: [
      { id: 'a', displayName: 'A', type: '7vs1', tab: 'A' },
      { id: 'b', displayName: 'B', type: 'modtest', tab: 'B' },
    ]
  }));
  const list = loadScenarios(join(tmp, 'maps.json'));
  assert.strictEqual(list.length, 2);
  assert.strictEqual(list[0].id, 'a');
});

test('getScenario 按 id 查找', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'sr-'));
  writeFileSync(join(tmp, 'maps.json'), JSON.stringify({
    scenarios: [{ id: 'x', displayName: 'X', tab: 'A' }]
  }));
  const s = getScenario(join(tmp, 'maps.json'), 'x');
  assert.strictEqual(s.displayName, 'X');
  const notFound = getScenario(join(tmp, 'maps.json'), 'y');
  assert.strictEqual(notFound, null);
});

test('getScenariosByTab 按 tab 过滤', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'sr-'));
  writeFileSync(join(tmp, 'maps.json'), JSON.stringify({
    scenarios: [
      { id: 'a', tab: 'A' },
      { id: 'b', tab: 'B' },
      { id: 'c', tab: 'A' },
    ]
  }));
  const aList = getScenariosByTab(join(tmp, 'maps.json'), 'A');
  assert.strictEqual(aList.length, 2);
});
