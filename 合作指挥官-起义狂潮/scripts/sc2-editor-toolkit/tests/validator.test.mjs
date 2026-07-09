import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { validate } from '../src/validator.mjs';
import { extractRefs } from '../src/refRules.mjs';
import { parseXml } from '../src/lenientXml.mjs';

const FIXTURES = path.join(path.dirname(fileURLToPath(import.meta.url)), 'fixtures');
const DEP = path.join(FIXTURES, 'DepMod.SC2Mod');
const TARGET = path.join(FIXTURES, 'TargetMod.SC2Mod');

function run() {
  return validate({ targetMods: [TARGET], depMods: [DEP] });
}

function codesOf(issues) {
  return new Set(issues.map(i => i.ruleCode));
}

test('引用校验：依赖 mod 提供的定义可解析，缺失的报 XML_DANGLING_REF', () => {
  const { issues } = run();
  const dangling = issues.filter(i => i.ruleCode === 'XML_DANGLING_REF');
  const msgs = dangling.map(i => i.message).join('\n');
  // 应报：MissingAbil / MissingWeapon / MissingButton / MissingAbil2 /
  //       NoSuchParent / NoSuchUnit / MissingButton2 / MissingReq / MissingEffect / GoneEffect
  for (const id of ['MissingAbil', 'MissingWeapon', 'MissingButton', 'MissingAbil2',
    'NoSuchParent', 'NoSuchUnit', 'MissingButton2', 'MissingReq', 'MissingEffect', 'GoneEffect']) {
    assert.ok(msgs.includes(`"${id}"`), `应报告 dangling: ${id}\n实际:\n${msgs}`);
  }
  // 不应报：DepAbil/DepButton/DepUnit/DmgX（已定义）
  for (const id of ['"DepAbil"', '"DepButton"', '"DepUnit"', '"DmgX"']) {
    assert.ok(!msgs.includes(id), `不应报告已定义引用: ${id}`);
  }
});

test('依赖 mod 自身的问题不进入报告（编辑器行为）', () => {
  const { issues } = run();
  // DepMod 的 MissingFromDep 引用悬空，但 DepMod 是 --deps → 不报告
  assert.ok(!issues.some(i => i.message.includes('MissingFromDep')));
  assert.ok(!issues.some(i => i.file.includes('DepMod')));
});

test('解析级规则：编码不符 / 缺 Catalog 包装 / 重复 id', () => {
  const { issues } = run();
  const codes = codesOf(issues);
  assert.ok(codes.has('XML_ENCODING_MISMATCH'), 'AbilData.xml us-ascii+中文');
  assert.ok(codes.has('XML_MISSING_CATALOG_ROOT'), 'EffectData.xml 无 Catalog 包装');
  assert.ok(codes.has('XML_DUPLICATE_ID'), 'EffectData.xml DmgX 定义两次');
  const dup = issues.find(i => i.ruleCode === 'XML_DUPLICATE_ID');
  assert.ok(dup.message.includes('DmgX'));
});

test('const 校验：已定义的 $DepConst$ 不报，$MissingConst$ 报警告', () => {
  const { issues } = run();
  const constIssues = issues.filter(i => i.ruleCode === 'XML_DANGLING_CONST');
  assert.equal(constIssues.length, 1);
  assert.ok(constIssues[0].message.includes('$MissingConst$'));
});

test('issue 结构与 galaxy-checker 对齐', () => {
  const { issues, filesChecked } = run();
  assert.ok(filesChecked >= 3);
  for (const i of issues) {
    assert.equal(typeof i.file, 'string');
    assert.equal(typeof i.line, 'number');
    assert.equal(typeof i.column, 'number');
    assert.ok(['error', 'warning', 'info'].includes(i.severity));
    assert.ok(/^XML_[A-Z_]+$/.test(i.ruleCode));
    assert.equal(typeof i.message, 'string');
  }
  // dangling ref 有准确行号（UnitData.xml 的 MissingAbil 在第 5 行）
  const ma = issues.find(i => i.message.includes('"MissingAbil"') && i.ruleCode === 'XML_DANGLING_REF');
  assert.equal(ma.line, 5);
});

test('规则配置可降级/关闭', () => {
  const { issues } = validate({
    targetMods: [TARGET], depMods: [DEP],
    ruleConfig: { rules: {
      XML_DANGLING_REF: { severity: 'warning' },
      XML_DUPLICATE_ID: { severity: 'off' },
    } },
  });
  assert.ok(issues.filter(i => i.ruleCode === 'XML_DANGLING_REF').every(i => i.severity === 'warning'));
  assert.ok(!issues.some(i => i.ruleCode === 'XML_DUPLICATE_ID'));
});

test('不带 --deps 时依赖内容也被校验（全链目标）', () => {
  const { issues } = validate({ targetMods: [DEP, TARGET] });
  assert.ok(issues.some(i => i.message.includes('MissingFromDep')), '依赖也作为目标时其悬空引用应报告');
});

test('extractRefs：规则表抽取（CEffectSwitch/CUpgrade Reference/CRequirementCount）', () => {
  const sw = parseXml('<CEffectSwitch id="S"><CaseArray Validator="V1" Effect="E1"/><CaseDefault value="E2"/></CEffectSwitch>').roots[0];
  const refs = extractRefs(sw).map(r => `${r.target}:${r.id}`);
  assert.deepEqual(refs.sort(), ['Effect:E1', 'Effect:E2', 'Validator:V1']);

  const up = parseXml('<CUpgrade id="U"><EffectArray Reference="Behavior,Buff1,Modification.X" Value="1"/><AffectedUnitArray value="Marine"/></CUpgrade>').roots[0];
  const upRefs = extractRefs(up).map(r => `${r.target}:${r.id}`);
  assert.ok(upRefs.includes('Behavior:Buff1'));
  assert.ok(upRefs.includes('Unit:Marine'));

  const rn = parseXml('<CRequirementCountUpgrade id="R"><Count Link="Upg1" State="CompleteOnly"/></CRequirementCountUpgrade>').roots[0];
  assert.ok(extractRefs(rn).some(r => r.target === 'Upgrade' && r.id === 'Upg1'));

  const and = parseXml('<CRequirementAnd id="A"><OperandArray index="0" value="Node1"/><OperandArray index="1" value="0"/></CRequirementAnd>').roots[0];
  const andRefs = extractRefs(and);
  assert.ok(andRefs.some(r => r.target === 'RequirementNode' && r.id === 'Node1'));
  assert.ok(!andRefs.some(r => r.id === '0'), '纯数字常量节点不报');

  const actor = parseXml('<CActorUnit id="AC" unitName="U1;U2"/>').roots[0];
  const actorRefs = extractRefs(actor).map(r => `${r.target}:${r.id}`);
  assert.ok(actorRefs.includes('Unit:U1') && actorRefs.includes('Unit:U2'));

  // removed="1" 的子元素不抽取
  const rem = parseXml('<CUnit id="U"><AbilArray Link="A" removed="1"/></CUnit>').roots[0];
  assert.equal(extractRefs(rem).length, 0);
});
