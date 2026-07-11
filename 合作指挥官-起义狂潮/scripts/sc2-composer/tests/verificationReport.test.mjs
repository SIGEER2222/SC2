/**
 * VerificationReport 模块测试
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  VERIFICATION_REPORT_SCHEMA_VERSION,
  CHECK_POINTS,
  createReport,
  validateReport,
  aggregateFromLint,
  aggregateFromLauncherPlan,
  aggregateFromComparePlans,
  aggregateFromSchemaValidation,
  mergeIntoReport,
  deriveOverallStatus,
  summarize,
} from '../src/verificationReport.mjs';

test('createReport - 创建合法 report', () => {
  const report = createReport({
    compositionId: 'reborn.zexpedition03_reborn_port__p1-TerranRaynor',
    runId: '20260711-test-001',
  });

  assert.equal(report.schemaVersion, VERIFICATION_REPORT_SCHEMA_VERSION);
  assert.equal(report.compositionId, 'reborn.zexpedition03_reborn_port__p1-TerranRaynor');
  assert.equal(report.runId, '20260711-test-001');
  // 所有检查点默认 pending
  for (const cp of CHECK_POINTS) {
    assert.equal(report.checks[cp], 'pending', `${cp} 应默认 pending`);
  }
  // pending 检查点自动补充 incompleteReasons
  assert.equal(report.incompleteReasons.length, CHECK_POINTS.length);
  assert.equal(report.evidence.length, 0);
  assert.equal(report.failures.length, 0);
});

test('createReport - 缺少 compositionId 抛错', () => {
  assert.throws(
    () => createReport({ runId: 'r1' }),
    /compositionId is required/,
  );
});

test('createReport - 缺少 runId 抛错', () => {
  assert.throws(
    () => createReport({ compositionId: 'c1' }),
    /runId is required/,
  );
});

test('createReport - 未知检查点抛错', () => {
  assert.throws(
    () => createReport({
      compositionId: 'c1',
      runId: 'r1',
      checks: { unknownCheck: 'pass' },
    }),
    /未知检查点: unknownCheck/,
  );
});

test('createReport - 非法状态值抛错', () => {
  assert.throws(
    () => createReport({
      compositionId: 'c1',
      runId: 'r1',
      checks: { schema: 'invalid-status' },
    }),
    /状态非法/,
  );
});

test('validateReport - 结构非法返回 errors', () => {
  const { valid, errors } = validateReport({
    schemaVersion: 2,
    compositionId: '',
    runId: '',
    checks: { unknown: 'pass' },
    evidence: 'not-an-array',
    failures: [],
    incompleteReasons: [],
  });
  assert.equal(valid, false);
  assert.ok(errors.length >= 4);
});

test('aggregateFromLint - 无问题时返回 pass', () => {
  const result = aggregateFromLint({
    modCount: 55,
    issues: [],
    modReports: new Map(),
  });
  assert.equal(result.checks.datacenter, 'pass');
  assert.equal(result.evidence.length, 1);
  assert.equal(result.failures.length, 0);
});

test('aggregateFromLint - 有 error 时返回 fail', () => {
  const result = aggregateFromLint({
    modCount: 55,
    issues: [
      { code: 'DC-002', severity: 'error', message: 'schema 失败', file: '/path/a.json' },
      { code: 'DC-005', severity: 'warning', message: 'owns 不匹配', file: '/path/b.xml' },
    ],
  });
  assert.equal(result.checks.datacenter, 'fail');
  assert.equal(result.failures.length, 2);
  assert.equal(result.failures[0].severity, 'error');
  assert.equal(result.failures[1].severity, 'warning');
});

test('aggregateFromLint - 只有 warning 时返回 partial', () => {
  const result = aggregateFromLint({
    modCount: 55,
    issues: [
      { code: 'DC-004', severity: 'warning', message: '混用风险' },
    ],
  });
  assert.equal(result.checks.datacenter, 'partial');
});

test('aggregateFromLauncherPlan - 提取 evidence', () => {
  const plan = {
    compositionId: 'reborn.test__p1-TerranRaynor',
    documentRewrite: {
      DocumentHeader: ['file:Mods/a', 'file:Mods/b'],
      DocumentInfo: ['file:Mods/a', 'file:Mods/b'],
    },
    galaxyInjection: [{ file: 'Base.SC2Data/x.galaxy' }],
    dependencyLayers: [
      { layer: 'L1', entries: [{ path: 'file:Mods/a' }] },
      { layer: 'L2', entries: [{ path: 'file:Mods/b' }] },
      { layer: 'L4', entries: [{ path: 'file:Mods/c' }] },
    ],
  };
  const result = aggregateFromLauncherPlan(plan, { planPath: '/tmp/plan.json' });
  assert.equal(result.evidence.length, 2);
  assert.equal(result.evidence[0].check, 'documentRoundtrip');
  assert.equal(result.evidence[1].check, 'dependencyClosure');
  assert.equal(result.evidence[0].path, '/tmp/plan.json');
});

test('aggregateFromComparePlans - 一致时 pass', () => {
  const result = aggregateFromComparePlans({
    consistent: true,
    differences: [],
  });
  assert.equal(result.checks.dependencyClosure, 'pass');
  assert.equal(result.failures.length, 0);
});

test('aggregateFromComparePlans - 不一致时 fail', () => {
  const result = aggregateFromComparePlans({
    consistent: false,
    differences: ['planId mismatch', 'galaxyIncludes count mismatch'],
  });
  assert.equal(result.checks.dependencyClosure, 'fail');
  assert.equal(result.failures.length, 2);
  assert.equal(result.failures[0].message, 'planId mismatch');
});

test('aggregateFromSchemaValidation - 校验通过 pass', () => {
  const result = aggregateFromSchemaValidation({ valid: true, errors: [] });
  assert.equal(result.checks.schema, 'pass');
  assert.equal(result.failures.length, 0);
});

test('aggregateFromSchemaValidation - 校验失败 fail', () => {
  const result = aggregateFromSchemaValidation({
    valid: false,
    errors: ['planId 缺失', 'commanderSlots 为空'],
  });
  assert.equal(result.checks.schema, 'fail');
  assert.equal(result.failures.length, 2);
});

test('mergeIntoReport - 合并多个聚合结果', () => {
  let report = createReport({
    compositionId: 'c1',
    runId: 'r1',
  });
  assert.equal(report.checks.datacenter, 'pending');

  report = mergeIntoReport(
    report,
    aggregateFromLint({ modCount: 55, issues: [] }),
    aggregateFromSchemaValidation({ valid: true, errors: [] }),
    aggregateFromComparePlans({ consistent: true, differences: [] }),
  );

  assert.equal(report.checks.datacenter, 'pass');
  assert.equal(report.checks.schema, 'pass');
  assert.equal(report.checks.dependencyClosure, 'pass');
  // 已 pass 的检查点应从 incompleteReasons 移除
  const incompleteChecks = report.incompleteReasons.map((r) => r.check);
  assert.ok(!incompleteChecks.includes('datacenter'));
  assert.ok(!incompleteChecks.includes('schema'));
  assert.ok(!incompleteChecks.includes('dependencyClosure'));
  // 仍 pending 的检查点应保留
  assert.ok(incompleteChecks.includes('galaxyChecker'));
  assert.ok(incompleteChecks.includes('runtimeSmoke'));
  // evidence 应合并
  assert.ok(report.evidence.length >= 3);
});

test('deriveOverallStatus - 含 fail 时 overall=fail', () => {
  const report = createReport({ compositionId: 'c1', runId: 'r1' });
  const merged = mergeIntoReport(report, aggregateFromLint({
    modCount: 1,
    issues: [{ code: 'DC-002', severity: 'error', message: 'fail' }],
  }));
  const { overall } = deriveOverallStatus(merged);
  assert.equal(overall, 'fail');
});

test('deriveOverallStatus - 全 pass 时 overall=pass', () => {
  const report = createReport({
    compositionId: 'c1',
    runId: 'r1',
    checks: Object.fromEntries(CHECK_POINTS.map((cp) => [cp, 'pass'])),
  });
  const { overall } = deriveOverallStatus(report);
  assert.equal(overall, 'pass');
});

test('summarize - 生成 markdown', () => {
  const report = createReport({
    compositionId: 'c1',
    runId: 'r1',
    checks: { schema: 'pass' },
  });
  const md = summarize(report);
  assert.ok(md.includes('VerificationReport - c1'));
  assert.ok(md.includes('schema'));
  assert.ok(md.includes('[pass]'));
});
