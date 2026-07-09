import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseXml } from '../src/lenientXml.mjs';
import { CatalogStore, catalogForTag, mergeElement, deepClone } from '../src/catalog.mjs';

function el(xml) {
  return parseXml(xml).roots[0];
}

test('catalogForTag：精确、前缀与 Requirement/RequirementNode 区分', () => {
  assert.equal(catalogForTag('CUnit'), 'Unit');
  assert.equal(catalogForTag('CAbilTrain'), 'Abil');
  assert.equal(catalogForTag('CEffectDamage'), 'Effect');
  assert.equal(catalogForTag('CBehaviorBuff'), 'Behavior');
  assert.equal(catalogForTag('CRequirement'), 'Requirement');
  assert.equal(catalogForTag('CRequirementCountUnit'), 'RequirementNode');
  assert.equal(catalogForTag('CRequirementAnd'), 'RequirementNode');
  assert.equal(catalogForTag('CValidatorUnitFilters'), 'Validator');
  assert.equal(catalogForTag('CActorUnit'), 'Actor');
  assert.equal(catalogForTag('CFooBar'), 'FooBar'); // 未知类回退
  assert.equal(catalogForTag('const'), null);
});

test('mergeElement：index 覆盖', () => {
  const dst = deepClone(el('<CAbilTrain id="T"><InfoArray index="Train1" Unit="A"/></CAbilTrain>'));
  const src = el('<CAbilTrain id="T"><InfoArray index="Train1" Unit="B" Time="5"/></CAbilTrain>');
  mergeElement(dst, src);
  assert.equal(dst.children.length, 1);
  assert.equal(dst.children[0].attrs.Unit, 'B');
  assert.equal(dst.children[0].attrs.Time, '5');
});

test('mergeElement：removed="1" 移除匹配子元素且自身不追加', () => {
  const dst = deepClone(el('<CUnit id="U"><AbilArray Link="A"/><AbilArray Link="B"/></CUnit>'));
  const src = el('<CUnit id="U"><AbilArray Link="A" removed="1"/></CUnit>');
  mergeElement(dst, src);
  assert.equal(dst.children.length, 1);
  assert.equal(dst.children[0].attrs.Link, 'B');
});

test('mergeElement：Link 键匹配合并、无键追加', () => {
  const dst = deepClone(el('<CUnit id="U"><WeaponArray Link="W1"/></CUnit>'));
  const src = el('<CUnit id="U"><WeaponArray Link="W1" Turret="T"/><WeaponArray Link="W2"/></CUnit>'); 
  mergeElement(dst, src);
  assert.equal(dst.children.length, 2);
  assert.equal(dst.children[0].attrs.Turret, 'T');
});

test('mergeElement：Row+Column 键（CardLayouts.LayoutButtons）', () => {
  const dst = deepClone(el('<CardLayouts><LayoutButtons Row="0" Column="0" Face="Old"/></CardLayouts>'));
  const src = el('<CardLayouts><LayoutButtons Row="0" Column="0" Face="New"/><LayoutButtons Row="0" Column="1" Face="Add"/></CardLayouts>');
  mergeElement(dst, src);
  assert.equal(dst.children.length, 2);
  assert.equal(dst.children[0].attrs.Face, 'New');
});

test('CatalogStore：跨 mod 同 id 合并、后者属性覆盖、CardLayouts 默认 index', () => {
  const store = new CatalogStore();
  store.addEntry(el('<CUnit id="U" parent="P1"><LifeMax value="100"/><CardLayouts CardId="X"><LayoutButtons Row="0" Column="0" Face="A"/></CardLayouts></CUnit>'));
  store.addEntry(el('<CUnit id="U" parent="P2"><LifeMax value="200"/><CardLayouts><LayoutButtons Row="0" Column="0" Face="B"/></CardLayouts></CUnit>'));
  const entry = store.getEntry('Unit', 'U');
  assert.equal(entry.node.attrs.parent, 'P2');
  assert.equal(entry.sources.length, 2);
  const life = entry.node.children.find(c => c.tag === 'LifeMax');
  assert.equal(life.attrs.value, '200');
  // CardLayouts 两个都缺省/补全 index="0" → 合并成一个，按 Row/Column 覆盖 Face
  const cls = entry.node.children.filter(c => c.tag === 'CardLayouts');
  assert.equal(cls.length, 1);
  assert.equal(cls[0].children[0].attrs.Face, 'B');
});

test('CatalogStore：parentChain 检测循环', () => {
  const store = new CatalogStore();
  store.addEntry(el('<CUnit id="A" parent="B"/>'));
  store.addEntry(el('<CUnit id="B" parent="A"/>'));
  assert.equal(store.parentChain('Unit', 'A').circular, true);
  store.addEntry(el('<CUnit id="C" parent="D"/>'));
  assert.equal(store.parentChain('Unit', 'C').circular, false);
});
