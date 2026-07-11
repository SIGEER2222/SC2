// tests/engineering-upgrade.test.ts
import { describe, it, expect } from 'vitest';
import { enrichIssues } from '../src/analyzer/IssueEnricher.js';
import { resolveFromCompositionPlan } from '../src/analyzer/CompositionPlanResolver.js';
import { fixDiscouragedUnitCreate, runFixer } from '../src/fixer/Fixer.js';
import { check } from '../src/index.js';
import type { Issue } from '../src/types.js';
import { writeFileSync, readFileSync, mkdirSync, rmSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

describe('IssueEnricher', () => {
  it('注入 confidence/autoFixable/runtimeRisk/suggestedOwner', () => {
    const issues: Issue[] = [
      {
        file: 'test.galaxy', line: 1, column: 1,
        ruleCode: 'XLIB_DISCOURAGED_NATIVE',
        severity: 'warning',
        message: 'test',
      },
    ];
    const enriched = enrichIssues(issues);
    expect(enriched[0].confidence).toBe('high');
    expect(enriched[0].autoFixable).toBe(true);
    expect(enriched[0].runtimeRisk).toBe('low');
    expect(enriched[0].suggestedOwner).toBe('Fixer.UnitCreateWrapper');
  });

  it('上下文相关规则在无 CompositionPlan 时 confidence=low', () => {
    const issues: Issue[] = [
      {
        file: 'test.galaxy', line: 1, column: 1,
        ruleCode: 'XLIB_UNDEFINED_CROSS_REF',
        severity: 'error',
        message: 'test',
      },
    ];
    const enriched = enrichIssues(issues, { contextLoaded: false });
    expect(enriched[0].confidence).toBe('low');
  });

  it('上下文相关规则在有 CompositionPlan 时 confidence 升级为 high', () => {
    const issues: Issue[] = [
      {
        file: 'test.galaxy', line: 1, column: 1,
        ruleCode: 'XLIB_UNDEFINED_CROSS_REF',
        severity: 'error',
        message: 'test',
      },
    ];
    const enriched = enrichIssues(issues, { contextLoaded: true });
    expect(enriched[0].confidence).toBe('high');
  });

  it('未知规则保持原样不注入元数据', () => {
    const issues: Issue[] = [
      {
        file: 'test.galaxy', line: 1, column: 1,
        ruleCode: 'UNKNOWN_RULE',
        severity: 'warning',
        message: 'test',
      },
    ];
    const enriched = enrichIssues(issues);
    expect(enriched[0].confidence).toBeUndefined();
    expect(enriched[0].autoFixable).toBeUndefined();
  });
});

describe('CompositionPlanResolver', () => {
  it('文件不存在时返回空上下文', () => {
    const ctx = resolveFromCompositionPlan('/nonexistent/plan.json', '/proj');
    expect(ctx.contextLoaded).toBe(false);
    expect(ctx.symbolRoots).toEqual([]);
  });

  it('解析 CompositionPlan 的依赖路径为 symbolRoots', () => {
    // 创建临时 mod 结构
    const tmpBase = join(tmpdir(), `galaxy-cp-test-${Date.now()}`);
    const modDir = join(tmpBase, 'Mods', 'TestMod.SC2Mod');
    const baseSc2Data = join(modDir, 'Base.SC2Data');
    mkdirSync(baseSc2Data, { recursive: true });
    writeFileSync(join(baseSc2Data, 'dummy.galaxy'), '// test');

    // 创建临时 plan
    const planPath = join(tmpBase, 'plan.json');
    const plan = {
      planId: 'test.plan1',
      dependencies: {
        always: [
          { path: 'file:Mods/TestMod.SC2Mod', layer: 'L0', source: 'test' },
        ],
      },
    };
    writeFileSync(planPath, JSON.stringify(plan));

    const ctx = resolveFromCompositionPlan(planPath, tmpBase);
    expect(ctx.contextLoaded).toBe(true);
    expect(ctx.compositionId).toBe('test.plan1');
    expect(ctx.symbolRoots.length).toBe(1);
    expect(ctx.symbolRoots[0]).toBe(baseSc2Data.replace(/\//g, '\\'));

    // cleanup
    rmSync(tmpBase, { recursive: true, force: true });
  });

  it('跳过不含 .SC2Mod 的依赖路径', () => {
    const tmpBase = join(tmpdir(), `galaxy-cp-test2-${Date.now()}`);
    mkdirSync(tmpBase, { recursive: true });
    const planPath = join(tmpBase, 'plan.json');
    const plan = {
      planId: 'test.plan2',
      dependencies: {
        always: [
          { path: 'file:Mods/NotAMod.txt', layer: 'L0', source: 'test' },
        ],
      },
    };
    writeFileSync(planPath, JSON.stringify(plan));

    const ctx = resolveFromCompositionPlan(planPath, tmpBase);
    expect(ctx.contextLoaded).toBe(true);
    expect(ctx.symbolRoots).toEqual([]);

    rmSync(tmpBase, { recursive: true, force: true });
  });
});

describe('Fixer', () => {
  it('识别并转换 6 参数 UnitCreate 调用（createStyle=c_unitCreateIgnorePlacement）', () => {
    const tmpDir = join(tmpdir(), `galaxy-fixer-${Date.now()}`);
    mkdirSync(tmpDir, { recursive: true });
    const filePath = join(tmpDir, 'TestLib.galaxy');
    writeFileSync(filePath, `
void TestFunc() {
    UnitCreate(1, "Marine", c_unitCreateIgnorePlacement, 1, lv_pos, 270.0);
}
`);
    const edits = fixDiscouragedUnitCreate(filePath);
    expect(edits.length).toBe(1);
    expect(edits[0].newText).toContain('libNtve_gf_CreateUnitsAtPoint2');
    expect(edits[0].newText).not.toContain('UnitCreate');
    // 验证移除了第 3 个参数 (c_unitCreateIgnorePlacement)
    expect(edits[0].newText).toBe('libNtve_gf_CreateUnitsAtPoint2(1, "Marine", 1, lv_pos, 270.0)');

    rmSync(tmpDir, { recursive: true, force: true });
  });

  it('跳过非 6 参数的 UnitCreate 调用', () => {
    const tmpDir = join(tmpdir(), `galaxy-fixer2-${Date.now()}`);
    mkdirSync(tmpDir, { recursive: true });
    const filePath = join(tmpDir, 'TestLib.galaxy');
    writeFileSync(filePath, `
void TestFunc() {
    UnitCreate(1, "Marine", c_unitCreateIgnorePlacement, 1, lv_pos);
}
`);
    const edits = fixDiscouragedUnitCreate(filePath);
    expect(edits.length).toBe(0);

    rmSync(tmpDir, { recursive: true, force: true });
  });

  it('跳过 createStyle 非 c_unitCreateIgnorePlacement 的调用（安全约束）', () => {
    const tmpDir = join(tmpdir(), `galaxy-fixer-unsafe-${Date.now()}`);
    mkdirSync(tmpDir, { recursive: true });
    const filePath = join(tmpDir, 'TestLib.galaxy');
    writeFileSync(filePath, `
void TestFunc() {
    UnitCreate(1, "Marine", 0, 1, lv_pos, 270.0);
    UnitCreate(1, "Marine", c_unitCreateConstruct, 1, lv_pos, 270.0);
}
`);
    const edits = fixDiscouragedUnitCreate(filePath);
    // createStyle=0 和 c_unitCreateConstruct 都不是 c_unitCreateIgnorePlacement，跳过
    expect(edits.length).toBe(0);

    rmSync(tmpDir, { recursive: true, force: true });
  });

  it('正确处理嵌套括号的参数', () => {
    const tmpDir = join(tmpdir(), `galaxy-fixer3-${Date.now()}`);
    mkdirSync(tmpDir, { recursive: true });
    const filePath = join(tmpDir, 'TestLib.galaxy');
    writeFileSync(filePath, `
void TestFunc() {
    UnitCreate(1, "Marine", c_unitCreateIgnorePlacement, lp_p, UnitGetPosition(lp_unit), libNtve_gf_RandomAngle());
}
`);
    const edits = fixDiscouragedUnitCreate(filePath);
    expect(edits.length).toBe(1);
    expect(edits[0].newText).toContain('libNtve_gf_CreateUnitsAtPoint2');
    expect(edits[0].newText).toContain('UnitGetPosition(lp_unit)');

    rmSync(tmpDir, { recursive: true, force: true });
  });

  it('applyEdits 实际修改文件内容', () => {
    const tmpDir = join(tmpdir(), `galaxy-fixer4-${Date.now()}`);
    mkdirSync(tmpDir, { recursive: true });
    const filePath = join(tmpDir, 'TestLib.galaxy');
    const original = `void TestFunc() {\n    UnitCreate(1, "Marine", c_unitCreateIgnorePlacement, 1, lv_pos, 270.0);\n}\n`;
    writeFileSync(filePath, original);

    const result = runFixer([filePath], 'XLIB_DISCOURAGED_NATIVE');
    expect(result.applied.length).toBe(1);
    expect(result.filesChanged.length).toBe(1);

    const after = readFileSync(filePath, 'utf-8');
    expect(after).toContain('libNtve_gf_CreateUnitsAtPoint2');
    expect(after).not.toContain('UnitCreate');

    rmSync(tmpDir, { recursive: true, force: true });
  });

  it('dryRun 模式不修改文件', () => {
    const tmpDir = join(tmpdir(), `galaxy-fixer-dryrun-${Date.now()}`);
    mkdirSync(tmpDir, { recursive: true });
    const filePath = join(tmpDir, 'TestLib.galaxy');
    const original = `void TestFunc() {\n    UnitCreate(1, "Marine", c_unitCreateIgnorePlacement, 1, lv_pos, 270.0);\n}\n`;
    writeFileSync(filePath, original);

    const result = runFixer([filePath], 'XLIB_DISCOURAGED_NATIVE', true);
    expect(result.applied.length).toBe(1);
    expect(result.filesChanged.length).toBe(0); // dry-run 不写文件

    const after = readFileSync(filePath, 'utf-8');
    expect(after).toBe(original); // 文件未被修改

    rmSync(tmpDir, { recursive: true, force: true });
  });
});

describe('check() with enriched report', () => {
  it('输出包含 confidence/autoFixable 字段', () => {
    const tmpDir = join(tmpdir(), `galaxy-check-enriched-${Date.now()}`);
    mkdirSync(tmpDir, { recursive: true });
    const filePath = join(tmpDir, 'LibTest.galaxy');
    writeFileSync(filePath, `
int TestVar;
void TestFunc() {
    libE0EAE146_gv_undefinedVar = 1;
}
`);
    const result = check(tmpDir, { noGlobalSymbols: true });
    // 应该有 SEM_UNDECLARED_VARIABLE 或类似 issue
    const hasEnrichedIssue = result.issues.some(
      i => i.confidence !== undefined || i.autoFixable !== undefined
    );
    expect(hasEnrichedIssue).toBe(true);

    rmSync(tmpDir, { recursive: true, force: true });
  });

  it('CheckResult 包含 contextLoaded 字段', () => {
    const tmpDir = join(tmpdir(), `galaxy-check-ctx-${Date.now()}`);
    mkdirSync(tmpDir, { recursive: true });
    const filePath = join(tmpDir, 'LibTest.galaxy');
    writeFileSync(filePath, `void TestFunc() {}\n`);

    const result = check(tmpDir);
    expect(result.contextLoaded).toBe(false); // 无 CompositionPlan

    rmSync(tmpDir, { recursive: true, force: true });
  });
});
