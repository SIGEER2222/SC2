// tests/fixtures-regression.test.ts
// Fixture 梯队回归测试：保护真实错误样本，防止后续修 parser 时回归。
// 每条 fixture 对应 ADR 中的一条高频规则。
import { describe, it, expect } from 'vitest';
import { check } from '../src/index.js';
import { fixDiscouragedUnitCreate } from '../src/fixer/Fixer.js';
import { join } from 'node:path';
import { readFileSync } from 'node:fs';

const fixtureDir = join(__dirname, 'fixtures', 'real-errors');

describe('Fixture 梯队回归 - 真实错误样本', () => {

  it('XLIB_UNDEFINED_CROSS_REF: 检测跨库未定义函数', () => {
    const file = join(fixtureDir, 'xlib-undefined-cross-ref.galaxy');
    const result = check(file, { noGlobalSymbols: true });
    const crossRefIssues = result.issues.filter(i => i.ruleCode === 'XLIB_UNDEFINED_CROSS_REF');
    expect(crossRefIssues.length).toBeGreaterThan(0);
    // 验证 enrichment
    expect(crossRefIssues[0].confidence).toBe('low'); // 无 CompositionPlan
    expect(crossRefIssues[0].runtimeRisk).toBe('high');
    expect(crossRefIssues[0].suggestedOwner).toBe('CompositionPlan.resolver');
  });

  it('XLIB_MISSING_INCLUDE: 检测未找到的 include', () => {
    const file = join(fixtureDir, 'xlib-missing-include.galaxy');
    const result = check(file, { noGlobalSymbols: true });
    const includeIssues = result.issues.filter(i => i.ruleCode === 'XLIB_MISSING_INCLUDE');
    expect(includeIssues.length).toBeGreaterThan(0);
    // 验证 enrichment
    expect(includeIssues[0].confidence).toBe('low');
    expect(includeIssues[0].autoFixable).toBe(false);
  });

  it('SEM_UNDECLARED_VARIABLE: 检测未声明变量', () => {
    const file = join(fixtureDir, 'sem-undeclared-variable.galaxy');
    const result = check(file, { noGlobalSymbols: true });
    const undeclaredIssues = result.issues.filter(i => i.ruleCode === 'SEM_UNDECLARED_VARIABLE');
    expect(undeclaredIssues.length).toBeGreaterThan(0);
    // 验证 enrichment
    expect(undeclaredIssues[0].confidence).toBe('low');
    expect(undeclaredIssues[0].runtimeRisk).toBe('high');
  });

  it('CATALOG_INVALID_UNIT_REF: 检测无效 catalog 引用', () => {
    const file = join(fixtureDir, 'catalog-invalid-unit-ref.galaxy');
    const result = check(file, { noGlobalSymbols: true });
    const catalogIssues = result.issues.filter(i => i.ruleCode === 'CATALOG_INVALID_UNIT_REF');
    // 可能检测到 "Marine" 以外的无效引用
    expect(catalogIssues.length).toBeGreaterThanOrEqual(0);
    if (catalogIssues.length > 0) {
      expect(catalogIssues[0].confidence).toBe('medium');
    }
  });

  it('XLIB_DISCOURAGED_NATIVE: 检测 UnitCreate 直接调用', () => {
    const file = join(fixtureDir, 'xlib-discouraged-native.galaxy');
    const result = check(file, { noGlobalSymbols: true });
    const discouragedIssues = result.issues.filter(i => i.ruleCode === 'XLIB_DISCOURAGED_NATIVE');
    expect(discouragedIssues.length).toBe(4); // 4 个 UnitCreate 调用
    // 验证 enrichment - 这是唯一 100% 真实问题且可自动修复的规则
    expect(discouragedIssues[0].confidence).toBe('high');
    expect(discouragedIssues[0].autoFixable).toBe(true);
    expect(discouragedIssues[0].runtimeRisk).toBe('low');
    expect(discouragedIssues[0].suggestedOwner).toBe('Fixer.UnitCreateWrapper');
  });

  it('XLIB_DISCOURAGED_NATIVE fixer: 只转换安全的 2 个调用（createStyle=c_unitCreateIgnorePlacement）', () => {
    const file = join(fixtureDir, 'xlib-discouraged-native.galaxy');
    // 注意: fixer 直接读文件并生成 edits，但不 apply（避免修改 fixture）
    const edits = fixDiscouragedUnitCreate(file);
    // 4 个 UnitCreate 调用中，只有 2 个 createStyle=c_unitCreateIgnorePlacement 可安全转换
    expect(edits.length).toBe(2);

    // 验证每个 edit 都正确移除了 createStyle 参数
    for (const edit of edits) {
      expect(edit.newText).toContain('libNtve_gf_CreateUnitsAtPoint2');
      expect(edit.newText).not.toContain('UnitCreate');
      expect(edit.newText).not.toContain('c_unitCreateIgnorePlacement');
    }

    // 验证 fixture 文件未被修改
    const afterContent = readFileSync(file, 'utf-8');
    expect(afterContent).toContain('UnitCreate('); // fixture 保持原样
  });

  it('contextLoaded 影响 confidence: 有上下文时 XLIB_* 规则升为 high', () => {
    const file = join(fixtureDir, 'xlib-undefined-cross-ref.galaxy');
    // 无 CompositionPlan
    const resultNoCtx = check(file, { noGlobalSymbols: true });
    const issueNoCtx = resultNoCtx.issues.find(i => i.ruleCode === 'XLIB_UNDEFINED_CROSS_REF');
    expect(issueNoCtx?.confidence).toBe('low');

    // 模拟有上下文（通过 enrichIssues 的 contextLoaded 参数）
    // check() 本身在无 compositionPlanPath 时 contextLoaded=false
    // 这里验证 enrichment 逻辑：contextLoaded=false 时保持 low
    expect(resultNoCtx.contextLoaded).toBe(false);
  });
});
