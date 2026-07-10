import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { buildDependencyGraph } from '../src/dependencyGraph.mjs';
import { compareCatalogTraces, flattenNodeFields, traceCatalogId } from '../src/provenance.mjs';
import { parseXml } from '../src/lenientXml.mjs';

function write(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content, 'utf8');
}

test('flattenNodeFields：使用 SC2 关键属性生成稳定字段路径', () => {
  const node = parseXml(
    '<CUnit id="U"><CardLayouts><LayoutButtons Row="0" Column="1" Face="B"/></CardLayouts></CUnit>',
  ).roots[0];
  const fields = flattenNodeFields(node);
  assert.ok(fields.some(item => item.path.includes('LayoutButtons[Row=0,Column=1]/@Face')));
});

test('traceCatalogId：报告父子覆盖、字段来源和 Galaxy 运行时修改', () => {
  const project = fs.mkdtempSync(path.join(os.tmpdir(), 'sc2-trace-'));
  const parent = path.join(project, 'Mods', 'Parent.SC2Mod');
  const target = path.join(project, 'Maps', 'Target.SC2Map');
  write(path.join(parent, 'DocumentInfo'), '<DocInfo><Dependencies/></DocInfo>');
  write(path.join(target, 'DocumentInfo'), '<DocInfo><Dependencies><Value>file:Mods/Parent.SC2Mod</Value></Dependencies></DocInfo>');
  write(path.join(parent, 'Base.SC2Data', 'GameData', 'UnitData.xml'),
    '<Catalog><CUnit id="MarineX"><LifeMax value="45"/></CUnit></Catalog>');
  write(path.join(target, 'Base.SC2Data', 'GameData', 'UnitData.xml'),
    '<Catalog><CUnit id="MarineX"><LifeMax value="60"/></CUnit></Catalog>');
  write(path.join(target, 'Base.SC2Data', 'MapScript.galaxy'),
    'libNtve_gf_TechTreeUnitAllow(1, "MarineX", true);\n' +
    'CatalogFieldValueSet(c_gameCatalogUnit, "MarineX", "LifeMax", 1, "90");\n');
  write(path.join(project, 'config.json'), JSON.stringify({ dependencySearchRoots: ['.'] }));

  const graph = buildDependencyGraph({
    target,
    projectRoot: project,
    configPath: path.join(project, 'config.json'),
  });
  const trace = traceCatalogId({ graph, catalog: 'Unit', id: 'MarineX' });
  assert.equal(trace.found, true);
  assert.equal(trace.definitions.length, 2);
  assert.equal(trace.fieldProvenance['LifeMax#0/@value'].effective.value, '60');
  assert.equal(trace.runtimeMutations.length, 2);
  assert.equal(trace.runtimeMutations[0].function, 'libNtve_gf_TechTreeUnitAllow');
  assert.equal(trace.runtimeMutations[1].function, 'CatalogFieldValueSet');
  assert.equal(trace.runtimeScan.mode, 'literal-id-line-scan');
  assert.equal(trace.runtimeScan.complete, false);
});

test('traceCatalogId：加载同 catalog 的父条目并正确判断完整性', () => {
  const project = fs.mkdtempSync(path.join(os.tmpdir(), 'sc2-parent-trace-'));
  const target = path.join(project, 'Maps', 'Target.SC2Map');
  write(path.join(target, 'DocumentInfo'), '<DocInfo><Dependencies/></DocInfo>');
  write(path.join(target, 'Base.SC2Data', 'GameData', 'UnitData.xml'),
    '<Catalog><CUnit id="Marine"/><CUnit id="MarineX" parent="Marine"/></Catalog>');
  write(path.join(project, 'config.json'), JSON.stringify({ dependencySearchRoots: ['.'] }));

  const graph = buildDependencyGraph({
    target,
    projectRoot: project,
    configPath: path.join(project, 'config.json'),
  });
  const trace = traceCatalogId({ graph, catalog: 'Unit', id: 'MarineX' });
  assert.deepEqual(trace.parentChain, ['MarineX', 'Marine']);
  assert.equal(trace.unresolvedParent, null);
  assert.equal(trace.complete, true);
});

test('traceCatalogId：无 GameData 的依赖只产生警告，不抛异常', () => {
  const project = fs.mkdtempSync(path.join(os.tmpdir(), 'sc2-empty-mod-'));
  const parent = path.join(project, 'Mods', 'Empty.SC2Mod');
  const target = path.join(project, 'Maps', 'Target.SC2Map');
  write(path.join(parent, 'DocumentInfo'), '<DocInfo><Dependencies/></DocInfo>');
  write(path.join(target, 'DocumentInfo'),
    '<DocInfo><Dependencies><Value>file:Mods/Empty.SC2Mod</Value></Dependencies></DocInfo>');
  write(path.join(target, 'Base.SC2Data', 'GameData', 'UnitData.xml'),
    '<Catalog><CUnit id="MarineX"/></Catalog>');
  write(path.join(project, 'config.json'), JSON.stringify({ dependencySearchRoots: ['.'] }));

  const graph = buildDependencyGraph({
    target,
    projectRoot: project,
    configPath: path.join(project, 'config.json'),
  });
  const trace = traceCatalogId({ graph, catalog: 'Unit', id: 'MarineX' });
  assert.equal(trace.found, true);
});

test('compareCatalogTraces：只输出字段值、来源和运行时差异', () => {
  const baseTrace = {
    schemaVersion: 1,
    target: 'left',
    catalog: 'Upgrade',
    id: 'U',
    found: true,
    complete: true,
    fieldProvenance: {
      'EffectArray[index=0]/@value': {
        effective: {
          value: 'LeftEffect',
          action: 'set',
          source: { file: 'left.xml', line: 10 },
        },
      },
    },
    runtimeMutations: [
      { function: 'TechTreeAbilityAllow', text: 'left', file: 'left.galaxy', line: 1 },
    ],
    runtimeScan: { mode: 'literal-id-line-scan', complete: false },
  };
  const comparison = compareCatalogTraces(baseTrace, {
    ...baseTrace,
    target: 'right',
    fieldProvenance: {
      'EffectArray[index=0]/@value': {
        effective: {
          value: 'RightEffect',
          action: 'set',
          source: { file: 'right.xml', line: 20 },
        },
      },
    },
    runtimeMutations: [
      { function: 'TechTreeAbilityAllow', text: 'right', file: 'right.galaxy', line: 2 },
    ],
  });
  assert.equal(comparison.complete, true);
  assert.equal(comparison.status, 'complete');
  assert.equal(comparison.runtimeScanComplete, false);
  assert.equal(comparison.fieldDifferences.length, 1);
  assert.equal(comparison.fieldDifferences[0].valueChanged, true);
  assert.equal(comparison.runtimeDifferences.onlyLeft.length, 1);
  assert.equal(comparison.runtimeDifferences.onlyRight.length, 1);

  const incomplete = compareCatalogTraces({ ...baseTrace, complete: false }, baseTrace);
  assert.equal(incomplete.status, 'incomplete');
});
