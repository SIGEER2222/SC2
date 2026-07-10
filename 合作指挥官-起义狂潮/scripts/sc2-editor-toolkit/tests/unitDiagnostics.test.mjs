import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { buildDependencyGraph } from '../src/dependencyGraph.mjs';
import { diagnoseUnit } from '../src/unitDiagnostics.mjs';

function write(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content, 'utf8');
}

function fixture({ unitXml, producerXml, abilityXml, galaxy = '' }) {
  const project = fs.mkdtempSync(path.join(os.tmpdir(), 'sc2-unit-diagnostics-'));
  const target = path.join(project, 'Maps', 'Target.SC2Map');
  write(path.join(target, 'DocumentInfo'), '<DocInfo><Dependencies/></DocInfo>');
  write(path.join(target, 'Base.SC2Data', 'GameData', 'UnitData.xml'),
    `<Catalog>${unitXml}${producerXml}</Catalog>`);
  write(path.join(target, 'Base.SC2Data', 'GameData', 'AbilData.xml'),
    `<Catalog>${abilityXml}</Catalog>`);
  if (galaxy) write(path.join(target, 'Base.SC2Data', 'MapScript.galaxy'), galaxy);
  const configPath = path.join(project, 'config.json');
  write(configPath, JSON.stringify({ dependencySearchRoots: ['.'] }));
  const graph = buildDependencyGraph({ target, projectRoot: project, configPath });
  return { graph };
}

test('diagnoseUnit：正常生产链与继承技能不报错误', () => {
  const { graph } = fixture({
    unitXml: `
      <CUnit id="MarineBase">
        <AbilArray Link="StimX"/>
        <CardLayouts>
          <LayoutButtons Face="StimXButton" Type="AbilCmd"
            AbilCmd="StimX,Execute" Row="2" Column="0"/>
        </CardLayouts>
      </CUnit>
      <CUnit id="MarineX" parent="MarineBase"/>`,
    producerXml: `
      <CUnit id="BarracksX">
        <AbilArray Link="BarracksTrainX"/>
        <CardLayouts>
          <LayoutButtons Face="MarineXButton" Type="AbilCmd"
            AbilCmd="BarracksTrainX, Train1" Row="0" Column="0"/>
        </CardLayouts>
      </CUnit>`,
    abilityXml: `
      <CAbilTrain id="BarracksTrainX">
        <InfoArray index="Train1" Unit="MarineX">
          <Button DefaultButtonFace="MarineXButton"/>
        </InfoArray>
      </CAbilTrain>
      <CAbilEffectInstant id="StimX"/>`,
  });
  const result = diagnoseUnit({
    graph,
    unitId: 'MarineX',
    producerId: 'BarracksX',
    expectedAbilities: ['StimX'],
  });
  assert.equal(result.unit.found, true);
  assert.deepEqual(result.unit.parentChain, ['MarineX', 'MarineBase']);
  assert.deepEqual(result.unit.staticAbilities, ['StimX']);
  assert.equal(result.production.selected.buttonVisible, true);
  assert.equal(result.issues.some(item => item.severity === 'error'), false);
});

test('diagnoseUnit：识别兵营缺训练能力和单位缺预期技能', () => {
  const { graph } = fixture({
    unitXml: '<CUnit id="MarineX"/>',
    producerXml: '<CUnit id="BarracksX"/>',
    abilityXml: `
      <CAbilTrain id="BarracksTrainX">
        <InfoArray index="Train1" Unit="MarineX"/>
      </CAbilTrain>`,
  });
  const result = diagnoseUnit({
    graph,
    unitId: 'MarineX',
    producerId: 'BarracksX',
    expectedAbilities: ['StimX'],
  });
  const codes = new Set(result.issues.map(item => item.code));
  assert.ok(codes.has('PRODUCER_MISSING_PRODUCTION_ABILITY'));
  assert.ok(codes.has('EXPECTED_ABILITY_MISSING'));
  assert.equal(result.production.selected, null);
});

test('diagnoseUnit：自动发现不到生产者时返回明确错误', () => {
  const { graph } = fixture({
    unitXml: '<CUnit id="MarineX"/>',
    producerXml: '<CUnit id="BarracksX"/>',
    abilityXml: `
      <CAbilTrain id="BarracksTrainX">
        <InfoArray index="Train1" Unit="MarineX"/>
      </CAbilTrain>`,
  });
  const result = diagnoseUnit({ graph, unitId: 'MarineX' });
  assert.ok(result.issues.some(item => item.code === 'PRODUCTION_PRODUCER_MISSING'));
  assert.equal(result.hasErrors, true);
});

test('diagnoseUnit：识别 Unit parent 循环', () => {
  const { graph } = fixture({
    unitXml: `
      <CUnit id="MarineX" parent="MarineParent"/>
      <CUnit id="MarineParent" parent="MarineX"/>`,
    producerXml: '',
    abilityXml: '',
  });
  const result = diagnoseUnit({ graph, unitId: 'MarineX' });
  assert.ok(result.issues.some(item => item.code === 'UNIT_PARENT_CIRCULAR'));
});

test('diagnoseUnit：报告生产者 parent 缺失而不是只报缺能力', () => {
  const { graph } = fixture({
    unitXml: '<CUnit id="MarineX"/>',
    producerXml: '<CUnit id="BarracksX" parent="MissingBarracksParent"/>',
    abilityXml: `
      <CAbilTrain id="BarracksTrainX">
        <InfoArray index="Train1" Unit="MarineX"/>
      </CAbilTrain>`,
  });
  const result = diagnoseUnit({
    graph,
    unitId: 'MarineX',
    producerId: 'BarracksX',
  });
  assert.ok(result.issues.some(item => item.code === 'PRODUCER_PARENT_UNRESOLVED'));
});

test('diagnoseUnit：叠加运行时能力并标记科技锁定和静态差异', () => {
  const { graph } = fixture({
    unitXml: '<CUnit id="MarineX"/>',
    producerXml: `
      <CUnit id="BarracksX">
        <AbilArray Link="BarracksTrainX"/>
        <CardLayouts>
          <LayoutButtons Face="MarineXButton" Type="AbilCmd"
            AbilCmd="BarracksTrainX,Train1" Row="0" Column="0"/>
        </CardLayouts>
      </CUnit>`,
    abilityXml: `
      <CAbilTrain id="BarracksTrainX">
        <InfoArray index="Train1" Unit="MarineX"/>
      </CAbilTrain>
      <CAbilEffectInstant id="RuntimeStim"/>`,
    galaxy: `
      if (UnitGetType(lv_unit) == "MarineX") {
        UnitAbilityAdd(lv_unit, "RuntimeStim");
      }
      TechTreeUnitAllow(1, "MarineX", false);
      TechTreeAbilityAllow(1, AbilityCommand("BarracksTrainX", 0), false);
      CatalogFieldValueSet(c_gameCatalogUnit, "MarineX", "LifeMax", 1, "200");
    `,
  });
  const result = diagnoseUnit({
    graph,
    unitId: 'MarineX',
    producerId: 'BarracksX',
    expectedAbilities: ['RuntimeStim'],
  });
  const codes = new Set(result.issues.map(item => item.code));
  assert.deepEqual(result.unit.runtimeAddedAbilities, ['RuntimeStim']);
  assert.ok(result.unit.effectiveAbilities.includes('RuntimeStim'));
  assert.equal(result.runtime.unitTech.allowed, false);
  assert.equal(result.runtime.abilityTech.BarracksTrainX.allowed, false);
  assert.ok(codes.has('UNIT_TECH_LOCKED_RUNTIME'));
  assert.ok(codes.has('PRODUCTION_ABILITY_LOCKED_RUNTIME'));
  assert.ok(codes.has('STATIC_RUNTIME_DIVERGENCE'));
  assert.equal(result.runtime.scan.complete, false);
});
