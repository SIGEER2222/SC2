import { test } from 'node:test';
import assert from 'node:assert';
import { syncMods, syncMaps, syncAll } from '../lib/sync-mods-and-maps.mjs';
import { mkdtempSync, mkdirSync, writeFileSync, existsSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';

test('syncMods 复制 mod 目录到目标，跳过 DocumentHeader/DocumentInfo', () => {
  const workspace = mkdtempSync(join(tmpdir(), 'ws-'));
  const sc2root = mkdtempSync(join(tmpdir(), 'sc2-'));
  const modDir = join(workspace, 'Mods', 'TestMod.SC2Mod');
  mkdirSync(modDir, { recursive: true });
  writeFileSync(join(modDir, 'base.xml'), '<base/>');
  writeFileSync(join(modDir, 'DocumentHeader'), 'HEADER');
  writeFileSync(join(modDir, 'DocumentInfo'), 'INFO');

  const result = syncMods({
    modNames: ['TestMod'],
    workspaceRoot: workspace,
    sc2Root: sc2root,
  });

  assert.strictEqual(result.copied > 0, true);
  assert.strictEqual(existsSync(join(sc2root, 'Mods', 'TestMod.SC2Mod', 'base.xml')), true);
  assert.strictEqual(existsSync(join(sc2root, 'Mods', 'TestMod.SC2Mod', 'DocumentHeader')), false);
  assert.strictEqual(existsSync(join(sc2root, 'Mods', 'TestMod.SC2Mod', 'DocumentInfo')), false);
});

test('syncMaps 复制地图文件到目标', () => {
  const workspace = mkdtempSync(join(tmpdir(), 'ws-'));
  const sc2root = mkdtempSync(join(tmpdir(), 'sc2-'));
  const mapFile = join(workspace, 'Maps', 'TestMap.SC2Map');
  mkdirSync(join(workspace, 'Maps'), { recursive: true });
  writeFileSync(mapFile, 'MPQ\x1a');

  const result = syncMaps({
    mapPaths: ['Maps/TestMap.SC2Map'],
    workspaceRoot: workspace,
    sc2Root: sc2root,
  });

  assert.strictEqual(result.copied, 1);
  assert.strictEqual(existsSync(join(sc2root, 'Maps', 'TestMap.SC2Map')), true);
});

test('syncAll 同时同步 mods 和 maps', () => {
  const workspace = mkdtempSync(join(tmpdir(), 'ws-'));
  const sc2root = mkdtempSync(join(tmpdir(), 'sc2-'));
  mkdirSync(join(workspace, 'Mods', 'M.SC2Mod'), { recursive: true });
  writeFileSync(join(workspace, 'Mods', 'M.SC2Mod', 'a.xml'), '<a/>');
  mkdirSync(join(workspace, 'Maps'), { recursive: true });
  writeFileSync(join(workspace, 'Maps', 'T.SC2Map'), 'MPQ');

  const result = syncAll({
    modNames: ['M'],
    mapPaths: ['Maps/T.SC2Map'],
    workspaceRoot: workspace,
    sc2Root: sc2root,
  });

  assert.strictEqual(result.copied > 0, true);
  assert.strictEqual(existsSync(join(sc2root, 'Mods', 'M.SC2Mod', 'a.xml')), true);
  assert.strictEqual(existsSync(join(sc2root, 'Maps', 'T.SC2Map')), true);
});
