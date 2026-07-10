import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { buildValidationPlan, platformCommand } from '../src/workflow.mjs';

test('buildValidationPlan：Galaxy/XML/工具改动路由到最小静态检查集合', () => {
  const workspaceRoot = path.resolve('X:/Workspace');
  const projectRoot = path.join(workspaceRoot, 'Project');
  const files = [
    'Project/Mods/7vs1/Test.SC2Mod/Base.SC2Data/LibTest.galaxy',
    'Project/Mods/7vs1/Test.SC2Mod/Base.SC2Data/GameData/UnitData.xml',
    'Project/scripts/sc2-editor-toolkit/src/workflow.mjs',
  ];
  const plan = buildValidationPlan({ workspaceRoot, projectRoot, files });
  const kinds = new Set(plan.staticActions.map(action => action.kind));
  assert.ok(kinds.has('galaxy-checker'));
  assert.ok(kinds.has('gamedata-validator'));
  assert.ok(kinds.has('toolkit-tests'));
  assert.equal(plan.runtimeValidation.required, true);
});

test('platformCommand：Windows 通过 node 执行 npm/npx CLI', () => {
  const npm = platformCommand('npm', 'win32', 'X:/Node/node.exe', null);
  const npx = platformCommand('npx', 'win32', 'X:/Node/node.exe', null);
  assert.equal(npm.command, 'X:/Node/node.exe');
  assert.equal(npm.argsPrefix[0], path.join('X:/Node', 'node_modules', 'npm', 'bin', 'npm-cli.js'));
  assert.equal(npx.argsPrefix[0], path.join('X:/Node', 'node_modules', 'npm', 'bin', 'npx-cli.js'));
  assert.deepEqual(platformCommand('node', 'win32'), { command: 'node', argsPrefix: [] });
  assert.deepEqual(platformCommand('npm', 'linux'), { command: 'npm', argsPrefix: [] });
});
