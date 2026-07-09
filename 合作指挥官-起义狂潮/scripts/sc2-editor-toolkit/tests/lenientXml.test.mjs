import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseXml, parseCatalogXml, decodeBuffer, decodeEntities } from '../src/lenientXml.mjs';

test('基本解析：属性、嵌套、行号', () => {
  const { roots, issues } = parseXml(
    '<Catalog>\n  <CUnit id="A" parent="B">\n    <LifeMax value="10"/>\n  </CUnit>\n</Catalog>', 'f.xml');
  assert.equal(issues.length, 0);
  assert.equal(roots.length, 1);
  const unit = roots[0].children[0];
  assert.equal(unit.tag, 'CUnit');
  assert.equal(unit.attrs.id, 'A');
  assert.equal(unit.line, 2);
  assert.equal(unit.children[0].tag, 'LifeMax');
  assert.equal(unit.children[0].line, 3);
  assert.equal(unit.file, 'f.xml');
});

test('us-ascii 声明 + 中文内容 → XML_ENCODING_MISMATCH 且解析成功', () => {
  const { roots, issues } = parseXml(
    '<?xml version="1.0" encoding="us-ascii"?>\n<Catalog><!-- 中文注释 --><CUnit id="甲"/></Catalog>');
  assert.ok(issues.some(i => i.code === 'XML_ENCODING_MISMATCH'));
  assert.equal(roots[0].children[0].attrs.id, '甲');
});

test('缺 <Catalog> 包装 → 自动收录顶层条目并报 XML_MISSING_CATALOG_ROOT', () => {
  const { entries, issues } = parseCatalogXml('<CUnit id="A"/>\n<CUnit id="B"/>');
  assert.equal(entries.length, 2);
  assert.ok(issues.some(i => i.code === 'XML_MISSING_CATALOG_ROOT'));
});

test('正常 <Catalog> 包装不报缺包装', () => {
  const { entries, issues } = parseCatalogXml('<?xml version="1.0"?><Catalog><CUnit id="A"/></Catalog>');
  assert.equal(entries.length, 1);
  assert.ok(!issues.some(i => i.code === 'XML_MISSING_CATALOG_ROOT'));
});

test('标签未闭合 → 恢复并报 XML_PARSE_ERROR', () => {
  const { roots, issues } = parseXml('<Catalog><CUnit id="A"><AbilArray Link="X"/></Catalog>');
  assert.ok(issues.some(i => i.code === 'XML_PARSE_ERROR'));
  // CUnit 在 </Catalog> 处被自动闭合，仍保留其子元素
  const unit = roots[0].children[0];
  assert.equal(unit.tag, 'CUnit');
  assert.equal(unit.children[0].attrs.Link, 'X');
});

test('多余闭合标签 → 忽略并继续', () => {
  const { roots, issues } = parseXml('<Catalog></CUnit><CButton id="B"/></Catalog>');
  assert.ok(issues.some(i => i.message.includes('多余的闭合标签')));
  assert.equal(roots[0].children[0].attrs.id, 'B');
});

test('属性值内含 ">" 与实体', () => {
  const { roots } = parseXml('<Catalog><CValidator id="V" Filters="a>b" Text="&amp;&lt;&#65;"/></Catalog>');
  const v = roots[0].children[0];
  assert.equal(v.attrs.Filters, 'a>b');
  assert.equal(v.attrs.Text, '&<A');
});

test('const 顶层元素被单独收集', () => {
  const { entries, consts } = parseCatalogXml('<Catalog><const id="X" value="1"/><CUnit id="A"/></Catalog>');
  assert.equal(consts.length, 1);
  assert.equal(consts[0].attrs.id, 'X');
  assert.equal(entries.length, 1);
});

test('BOM 与 UTF-16 解码', () => {
  const utf8bom = Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), Buffer.from('<a/>')]);
  assert.equal(decodeBuffer(utf8bom).text, '<a/>');
  const utf16 = Buffer.concat([Buffer.from([0xff, 0xfe]), Buffer.from('<a/>', 'utf16le')]);
  const d = decodeBuffer(utf16);
  assert.equal(d.text, '<a/>');
  assert.equal(d.encoding, 'utf-16le');
});

test('实体解码工具', () => {
  assert.equal(decodeEntities('A&quot;B&apos;C&#x41;'), `A"B'CA`);
  assert.equal(decodeEntities('无实体'), '无实体');
});
