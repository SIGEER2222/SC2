import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const CLI = fileURLToPath(new URL('../cli.mjs', import.meta.url));

function write(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content, 'utf8');
}

function fixture({ missingDependency = false } = {}) {
  const project = fs.mkdtempSync(path.join(os.tmpdir(), 'sc2-unit-cli-'));
  const target = path.join(project, 'Maps', 'Target.SC2Map');
  const dependency = missingDependency
    ? '<Dependencies><Value>file:Mods/Missing.SC2Mod</Value></Dependencies>'
    : '<Dependencies/>';
  write(path.join(target, 'DocumentInfo'), `<DocInfo>${dependency}</DocInfo>`);
  write(path.join(target, 'Base.SC2Data', 'GameData', 'UnitData.xml'), `
    <Catalog>
      <CUnit id="MarineX">
        <AbilArray Link="StimX"/>
        <CardLayouts>
          <LayoutButtons AbilCmd="StimX,Execute" Type="AbilCmd"/>
        </CardLayouts>
      </CUnit>
      <CUnit id="BarracksX">
        <AbilArray Link="TrainX"/>
        <CardLayouts>
          <LayoutButtons AbilCmd="TrainX,Train1" Type="AbilCmd"/>
        </CardLayouts>
      </CUnit>
    </Catalog>`);
  write(path.join(target, 'Base.SC2Data', 'GameData', 'AbilData.xml'), `
    <Catalog>
      <CAbilTrain id="TrainX">
        <InfoArray index="Train1" Unit="MarineX"/>
      </CAbilTrain>
      <CAbilEffectInstant id="StimX"/>
    </Catalog>`);
  const config = path.join(project, 'workflow.json');
  write(config, JSON.stringify({ dependencySearchRoots: ['.'] }));
  return { project, target, config };
}

function run(args) {
  return spawnSync(process.execPath, [CLI, ...args], {
    encoding: 'utf8',
    windowsHide: true,
  });
}

test('diagnose-unit CLI：输出稳定 JSON 并在正常链路返回 0', () => {
  const { project, target, config } = fixture();
  const result = run([
    'diagnose-unit',
    target,
    '--project-root',
    project,
    '--config',
    config,
    '--unit',
    'MarineX',
    '--producer',
    'BarracksX',
    '--expect-ability',
    'StimX',
  ]);
  assert.equal(result.status, 0, result.stderr);
  const output = JSON.parse(result.stdout);
  assert.equal(output.schemaVersion, 1);
  assert.equal(output.status, 'ok');
  assert.equal(output.complete, true);
  assert.equal(output.production.selected.buttonVisible, true);
});

test('diagnose-unit CLI：依赖不完整默认失败，显式允许后返回 0', () => {
  const { project, target, config } = fixture({ missingDependency: true });
  const args = [
    'diagnose-unit',
    target,
    '--project-root',
    project,
    '--config',
    config,
    '--unit',
    'MarineX',
    '--producer',
    'BarracksX',
    '--expect-ability',
    'StimX',
  ];
  const strict = run(args);
  assert.equal(strict.status, 1, strict.stderr);
  assert.equal(JSON.parse(strict.stdout).status, 'incomplete');

  const allowed = run([...args, '--allow-incomplete']);
  assert.equal(allowed.status, 0, allowed.stderr);
  assert.equal(JSON.parse(allowed.stdout).complete, false);
});
