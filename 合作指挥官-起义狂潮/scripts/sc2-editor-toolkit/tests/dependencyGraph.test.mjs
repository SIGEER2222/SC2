import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
  buildDependencyGraph,
  extractFileDependency,
  readPackageDependencies,
} from '../src/dependencyGraph.mjs';

function write(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content, 'utf8');
}

test('extractFileDependency：从 bnet 描述中提取 file 依赖', () => {
  assert.equal(
    extractFileDependency('bnet:自由之翼 (Mod)/0.0/999,file:Mods/Liberty.SC2Mod'),
    'file:Mods/Liberty.SC2Mod',
  );
  assert.equal(extractFileDependency('file:Mods/Test.SC2Mod'), 'file:Mods/Test.SC2Mod');
});

test('readPackageDependencies：只读取 Dependencies，不混入 Preload', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'sc2-deps-'));
  write(path.join(root, 'DocumentInfo'), `<?xml version="1.0"?>
<DocInfo>
  <Dependencies><Value>file:Mods/A.SC2Mod</Value></Dependencies>
  <Dependency value="file:Mods/B.SC2Mod"/>
  <Preload><Value>Bank;Example</Value></Preload>
</DocInfo>`);
  const result = readPackageDependencies(root);
  assert.deepEqual(
    result.dependencies.map(item => item.fileRef).sort(),
    ['file:Mods/A.SC2Mod', 'file:Mods/B.SC2Mod'],
  );
});

test('buildDependencyGraph：父依赖优先排序并标记旧依赖', () => {
  const project = fs.mkdtempSync(path.join(os.tmpdir(), 'sc2-graph-'));
  const parent = path.join(project, 'Mods', 'Parent.SC2Mod');
  const target = path.join(project, 'Maps', 'Target.SC2Map');
  write(path.join(parent, 'DocumentInfo'), '<DocInfo><Dependencies/></DocInfo>');
  write(path.join(target, 'DocumentInfo'), `<DocInfo><Dependencies>
    <Value>file:Mods/Parent.SC2Mod</Value>
    <Value>file:Mods/Legacy.SC2Mod</Value>
  </Dependencies></DocInfo>`);
  write(path.join(project, 'config.json'), JSON.stringify({
    dependencySearchRoots: ['.'],
    legacyDependencies: {
      'file:Mods/Legacy.SC2Mod': {
        replacement: ['file:Mods/New.SC2Mod'],
      },
    },
  }));
  const graph = buildDependencyGraph({
    target,
    projectRoot: project,
    configPath: path.join(project, 'config.json'),
  });
  assert.deepEqual(graph.loadOrder, [parent, target]);
  const targetNode = graph.nodes.find(node => node.path === target);
  assert.equal(targetNode.dependencies[0].status, 'resolved');
  assert.equal(targetNode.dependencies[1].status, 'legacy');
  assert.equal(graph.issues.length, 0);
});

test('buildDependencyGraph effective：旧聚合依赖展开为固定层和选中指挥官包', () => {
  const project = fs.mkdtempSync(path.join(os.tmpdir(), 'sc2-effective-'));
  const target = path.join(project, 'Maps', 'Mission_7vs1.SC2Map');
  const core = path.join(project, 'Mods', 'Core.SC2Mod');
  const units = path.join(project, 'Mods', 'UnitsRaynor.SC2Mod');
  write(path.join(target, 'DocumentInfo'),
    '<DocInfo><Dependencies><Value>file:Mods/Legacy.SC2Mod</Value></Dependencies></DocInfo>');
  write(path.join(core, 'DocumentInfo'), '<DocInfo/>');
  write(path.join(units, 'DocumentInfo'), '<DocInfo/>');
  write(path.join(project, 'config.json'), JSON.stringify({
    dependencySearchRoots: ['.'],
    legacyDependencies: {
      'file:Mods/Legacy.SC2Mod': {
        strategy: 'selected-commander-units',
      },
    },
    effectiveProfiles: [{
      name: 'test',
      targetPattern: '_7vs1\\.SC2Map$',
      alwaysDependencies: ['file:Mods/Core.SC2Mod'],
      commanderDependencies: {
        TerranRaynor: ['file:Mods/UnitsRaynor.SC2Mod'],
      },
    }],
  }));
  const graph = buildDependencyGraph({
    target,
    projectRoot: project,
    configPath: path.join(project, 'config.json'),
    effective: true,
    commanders: ['TerranRaynor'],
  });
  assert.equal(graph.mode, 'effective');
  assert.ok(graph.loadOrder.includes(core));
  assert.ok(graph.loadOrder.includes(units));
  assert.ok(!graph.loadOrder.some(item => item.endsWith('Legacy.SC2Mod')));
});
