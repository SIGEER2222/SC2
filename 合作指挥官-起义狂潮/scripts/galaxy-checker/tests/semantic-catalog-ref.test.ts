import { describe, it, expect } from 'vitest';
import { analyze } from '../src/analyzer/SemanticAnalyzer.js';
import type { CatalogDb } from '../src/types.js';

// 构造一个迷你 catalog DB 用于测试
const miniDb: CatalogDb = {
  Unit: new Set(['Marine', 'Zergling', 'Barracks']),
  Upgrade: new Set(['Stimpack']),
  Abil: new Set(['Attack']),
  Behavior: new Set(['StimpackMovers']),
  Effect: new Set(['MarineAttack']),
  Button: new Set(['MarineButton']),
};

describe('SemanticAnalyzer - catalog 引用校验 (CATALOG_INVALID_UNIT_REF)', () => {
  it('libNtve_gf_CreateUnitsWithDefaultFacing 传无效 Unit ID → 报', () => {
    const src = `void f() { libNtve_gf_CreateUnitsWithDefaultFacing(1, "TypoUnit", 0, 1, null); }`;
    const issues = analyze(src, 'test.galaxy', undefined, undefined, undefined, undefined, miniDb);
    const hit = issues.find(i => i.ruleCode === 'CATALOG_INVALID_UNIT_REF');
    expect(hit).toBeDefined();
    expect(hit!.message).toContain('TypoUnit');
  });

  it('libNtve_gf_CreateUnitsWithDefaultFacing 传有效 Unit ID → 不报', () => {
    const src = `void f() { libNtve_gf_CreateUnitsWithDefaultFacing(1, "Marine", 0, 1, null); }`;
    const issues = analyze(src, 'test.galaxy', undefined, undefined, undefined, undefined, miniDb);
    expect(issues.find(i => i.ruleCode === 'CATALOG_INVALID_UNIT_REF')).toBeUndefined();
  });

  it('UnitTypeGetProperty 传无效 Unit ID → 报', () => {
    const src = `void f() { UnitTypeGetProperty("BadID", 0); }`;
    const issues = analyze(src, 'test.galaxy', undefined, undefined, undefined, undefined, miniDb);
    expect(issues.find(i => i.ruleCode === 'CATALOG_INVALID_UNIT_REF')).toBeDefined();
  });

  it('UnitTypeIsAffectedByUpgrade 同时校验 Unit 和 Upgrade 两个位置', () => {
    // Unit 位置有效，Upgrade 位置无效
    const src1 = `void f() { UnitTypeIsAffectedByUpgrade("Marine", "BadUpgrade"); }`;
    const issues1 = analyze(src1, 'test.galaxy', undefined, undefined, undefined, undefined, miniDb);
    const hit1 = issues1.find(i => i.ruleCode === 'CATALOG_INVALID_UNIT_REF' && i.message.includes('BadUpgrade'));
    expect(hit1).toBeDefined();

    // Unit 位置无效，Upgrade 位置有效
    const src2 = `void f() { UnitTypeIsAffectedByUpgrade("BadUnit", "Stimpack"); }`;
    const issues2 = analyze(src2, 'test.galaxy', undefined, undefined, undefined, undefined, miniDb);
    const hit2 = issues2.find(i => i.ruleCode === 'CATALOG_INVALID_UNIT_REF' && i.message.includes('BadUnit'));
    expect(hit2).toBeDefined();

    // 两个位置都有效 → 不报
    const src3 = `void f() { UnitTypeIsAffectedByUpgrade("Marine", "Stimpack"); }`;
    const issues3 = analyze(src3, 'test.galaxy', undefined, undefined, undefined, undefined, miniDb);
    expect(issues3.find(i => i.ruleCode === 'CATALOG_INVALID_UNIT_REF')).toBeUndefined();
  });

  it('CatalogFieldValueGet 用 any catalog：ID 不在任何 catalog 中 → 报', () => {
    const src = `void f() { CatalogFieldValueGet(1, "NotFoundAnywhere", "Cost", 0); }`;
    const issues = analyze(src, 'test.galaxy', undefined, undefined, undefined, undefined, miniDb);
    expect(issues.find(i => i.ruleCode === 'CATALOG_INVALID_UNIT_REF')).toBeDefined();
  });

  it('CatalogFieldValueGet 用 any catalog：ID 存在于某个 catalog → 不报', () => {
    // "Attack" 在 Abil catalog 中
    const src = `void f() { CatalogFieldValueGet(1, "Attack", "Cost", 0); }`;
    const issues = analyze(src, 'test.galaxy', undefined, undefined, undefined, undefined, miniDb);
    expect(issues.find(i => i.ruleCode === 'CATALOG_INVALID_UNIT_REF')).toBeUndefined();
  });

  it('无 catalogDb 时不做校验（不报）', () => {
    const src = `void f() { libNtve_gf_CreateUnitsWithDefaultFacing(1, "TotallyBogus", 0, 1, null); }`;
    const issues = analyze(src, 'test.galaxy', undefined, undefined, undefined, undefined, undefined);
    expect(issues.find(i => i.ruleCode === 'CATALOG_INVALID_UNIT_REF')).toBeUndefined();
  });

  it('非字符串字面量参数（变量）不校验', () => {
    const src = `void f() { string s = "Marine"; libNtve_gf_CreateUnitsWithDefaultFacing(1, s, 0, 1, null); }`;
    const issues = analyze(src, 'test.galaxy', undefined, undefined, undefined, undefined, miniDb);
    expect(issues.find(i => i.ruleCode === 'CATALOG_INVALID_UNIT_REF')).toBeUndefined();
  });

  it('不在 CATALOG_REF_FUNCS 表中的函数不校验', () => {
    const src = `void f() { SomeOtherFunc("BogusID"); }`;
    const issues = analyze(src, 'test.galaxy', undefined, undefined, undefined, undefined, miniDb);
    expect(issues.find(i => i.ruleCode === 'CATALOG_INVALID_UNIT_REF')).toBeUndefined();
  });
});
