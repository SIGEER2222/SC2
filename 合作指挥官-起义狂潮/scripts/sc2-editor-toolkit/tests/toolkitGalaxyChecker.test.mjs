import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import {
  checkGalaxyWithToolkit,
  findArchiveRootForGalaxyCheck,
} from '../src/toolkitGalaxyChecker.mjs';

test('findArchiveRootForGalaxyCheck：可从 Base.SC2Data 反推 SC2Mod 包根', () => {
  const archiveRoot = findArchiveRootForGalaxyCheck(path.resolve(
    '..',
    '..',
    'Mods',
    '7vs1',
    'CoreRuntime.SC2Mod',
    'Base.SC2Data',
  ));

  assert.ok(archiveRoot);
  assert.equal(path.basename(archiveRoot), 'CoreRuntime.SC2Mod');
});

test('checkGalaxyWithToolkit：可读取 toolkit fixture 并返回结构化结果', async () => {
  const baseDataRoot = path.resolve(
    '..',
    '..',
    '..',
    'tools',
    'sc2-galaxy-toolkit',
    'packages',
    'sc2-lsp',
    'tests',
    'fixtures',
    'type_checker',
    'diagnostics_recursive',
    'definition',
  );

  const result = await checkGalaxyWithToolkit({
    baseDataRoot,
    format: 'json',
  });

  assert.equal(result.tool, 'sc2-galaxy-toolkit');
  assert.ok(result.filesChecked >= 1);
  assert.ok(Array.isArray(result.issues));
  assert.ok(result.issues.length >= 1);
  assert.ok(result.summary.errors >= 1);
});
