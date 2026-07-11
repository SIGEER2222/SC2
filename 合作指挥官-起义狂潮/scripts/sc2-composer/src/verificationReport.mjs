/**
 * 统一验证报告（VerificationReport）模块
 *
 * 把 lint-dataspaces、CompositionPlan 校验、Document roundtrip、launcher dry-run、
 * comparePlans、runtimeSmoke 等各检查点的结果汇总成单一 machine-readable 报告。
 *
 * 报告 schema：scripts/sc2-composer/schema/VerificationReport.schema.json
 * 详见 docs/系统结构与工作流优化设计-2026-07-11.md §5.6 与 §7 Task 5。
 */

/** VerificationReport 当前 schema 版本 */
export const VERIFICATION_REPORT_SCHEMA_VERSION = 1;

/** 支持的检查点名称（与 VerificationReport.schema.json checks.propertyNames 对齐） */
export const CHECK_POINTS = [
  'schema',              // CompositionPlan / MapProfile / CommanderPackage schema 校验
  'datacenter',          // lint-dataspaces 结果
  'dependencyClosure',   // 依赖闭包完整性（comparePlans / resolve-dependencies）
  'galaxyChecker',       // galaxy-checker 静态校验
  'documentRoundtrip',   // DocumentHeader/Info 依赖写入后回读一致
  'runtimeSmoke',        // 启动器 dry-run / 实际进图无 ScriptError
  'unitDiagnostics',     // 单位生产/科技/技能诊断
  'bankIsolation',       // Bank 写入隔离校验
];

/** 检查点合法状态值 */
export const CHECK_STATUS = ['pass', 'fail', 'partial', 'pending', 'skipped'];

/**
 * 校验 VerificationReport 结构。
 *
 * @param {any} report
 * @returns {{ valid: boolean, errors: string[] }}
 */
export function validateReport(report) {
  const errors = [];

  if (typeof report !== 'object' || report === null || Array.isArray(report)) {
    return { valid: false, errors: ['VerificationReport 必须是对象'] };
  }

  for (const f of ['schemaVersion', 'compositionId', 'runId', 'checks', 'evidence', 'failures', 'incompleteReasons']) {
    if (!(f in report)) errors.push(`缺少必填字段: ${f}`);
  }

  if (report.schemaVersion !== undefined && report.schemaVersion !== VERIFICATION_REPORT_SCHEMA_VERSION) {
    errors.push(`schemaVersion 必须为 ${VERIFICATION_REPORT_SCHEMA_VERSION}，实际为 ${report.schemaVersion}`);
  }

  if (report.compositionId !== undefined && (typeof report.compositionId !== 'string' || report.compositionId.length === 0)) {
    errors.push('compositionId 必须是非空字符串');
  }

  if (report.runId !== undefined && (typeof report.runId !== 'string' || report.runId.length === 0)) {
    errors.push('runId 必须是非空字符串');
  }

  if (report.checks !== undefined) {
    if (typeof report.checks !== 'object' || report.checks === null || Array.isArray(report.checks)) {
      errors.push('checks 必须是对象');
    } else {
      for (const [k, v] of Object.entries(report.checks)) {
        if (!CHECK_POINTS.includes(k)) {
          errors.push(`checks 含未知检查点: ${k}`);
        }
        if (!CHECK_STATUS.includes(v)) {
          errors.push(`checks.${k} 状态非法: ${v}（合法值: ${CHECK_STATUS.join('|')}）`);
        }
      }
    }
  }

  if (report.evidence !== undefined) {
    if (!Array.isArray(report.evidence)) {
      errors.push('evidence 必须是数组');
    } else {
      report.evidence.forEach((e, i) => {
        const prefix = `evidence[${i}]`;
        if (typeof e !== 'object' || e === null) {
          errors.push(`${prefix} 必须是对象`);
          return;
        }
        for (const f of ['check', 'kind', 'summary']) {
          if (!e[f] || typeof e[f] !== 'string') {
            errors.push(`${prefix}.${f} 缺失或非字符串`);
          }
        }
        if (e.check && !CHECK_POINTS.includes(e.check)) {
          errors.push(`${prefix}.check 含未知检查点: ${e.check}`);
        }
      });
    }
  }

  if (report.failures !== undefined) {
    if (!Array.isArray(report.failures)) {
      errors.push('failures 必须是数组');
    } else {
      report.failures.forEach((f, i) => {
        const prefix = `failures[${i}]`;
        if (typeof f !== 'object' || f === null) {
          errors.push(`${prefix} 必须是对象`);
          return;
        }
        if (!f.check || typeof f.check !== 'string') errors.push(`${prefix}.check 缺失或非字符串`);
        if (!f.message || typeof f.message !== 'string') errors.push(`${prefix}.message 缺失或非字符串`);
        if (f.severity && !['error', 'warning'].includes(f.severity)) {
          errors.push(`${prefix}.severity 非法: ${f.severity}`);
        }
        if (f.check && !CHECK_POINTS.includes(f.check)) {
          errors.push(`${prefix}.check 含未知检查点: ${f.check}`);
        }
      });
    }
  }

  if (report.incompleteReasons !== undefined) {
    if (!Array.isArray(report.incompleteReasons)) {
      errors.push('incompleteReasons 必须是数组');
    } else {
      report.incompleteReasons.forEach((r, i) => {
        const prefix = `incompleteReasons[${i}]`;
        if (typeof r !== 'object' || r === null) {
          errors.push(`${prefix} 必须是对象`);
          return;
        }
        if (!r.check || typeof r.check !== 'string') errors.push(`${prefix}.check 缺失或非字符串`);
        if (!r.reason || typeof r.reason !== 'string') errors.push(`${prefix}.reason 缺失或非字符串`);
        if (r.check && !CHECK_POINTS.includes(r.check)) {
          errors.push(`${prefix}.check 含未知检查点: ${r.check}`);
        }
      });
    }
  }

  return { valid: errors.length === 0, errors };
}

/**
 * 创建 VerificationReport。
 *
 * @param {object} options
 * @param {string} options.compositionId - 组合计划 ID
 * @param {string} options.runId - 运行 ID
 * @param {object} [options.checks={}] - 初始 checks 状态（未提供的检查点默认 pending）
 * @param {Array} [options.evidence=[]]
 * @param {Array} [options.failures=[]]
 * @param {Array} [options.incompleteReasons=[]]
 * @param {string} [options.generatedAt] - ISO 时间戳，默认当前时间
 * @returns {object} VerificationReport 对象
 * @throws {Error} 校验失败
 */
export function createReport(options) {
  const { compositionId, runId } = options;
  if (!compositionId) throw new Error('compositionId is required');
  if (!runId) throw new Error('runId is required');

  // 初始化所有检查点为 pending
  const checks = {};
  for (const cp of CHECK_POINTS) {
    checks[cp] = 'pending';
  }
  // 覆盖用户提供的初始状态
  if (options.checks) {
    for (const [k, v] of Object.entries(options.checks)) {
      if (!CHECK_POINTS.includes(k)) {
        throw new Error(`未知检查点: ${k}`);
      }
      if (!CHECK_STATUS.includes(v)) {
        throw new Error(`checks.${k} 状态非法: ${v}`);
      }
      checks[k] = v;
    }
  }

  // 对 pending/skipped 检查点自动补充 incompleteReasons
  const incompleteReasons = [...(options.incompleteReasons || [])];
  const existingReasonChecks = new Set(incompleteReasons.map((r) => r.check));
  for (const cp of CHECK_POINTS) {
    if ((checks[cp] === 'pending' || checks[cp] === 'skipped') && !existingReasonChecks.has(cp)) {
      incompleteReasons.push({
        check: cp,
        reason: checks[cp] === 'skipped' ? 'Skipped by caller' : 'Not executed yet',
      });
    }
  }

  const report = {
    schemaVersion: VERIFICATION_REPORT_SCHEMA_VERSION,
    compositionId,
    runId,
    generatedAt: options.generatedAt || new Date().toISOString(),
    checks,
    evidence: options.evidence || [],
    failures: options.failures || [],
    incompleteReasons,
  };

  const { valid, errors } = validateReport(report);
  if (!valid) {
    throw new Error(`VerificationReport 校验失败: ${errors.join('; ')}`);
  }
  return report;
}

/**
 * 从 lint-dataspaces 结果聚合 evidence 和 failures，并更新 datacenter 检查点状态。
 *
 * @param {object} lintResult - lintProject / runLintDataspaces 的结果对象
 *   期望字段: { modCount, issues: [{ code, severity, message, file? }], modReports? }
 * @param {object} [options]
 * @param {string} [options.projectRoot] - 用于计算相对路径
 * @returns {{ checks: { datacenter: string }, evidence: object[], failures: object[] }}
 */
export function aggregateFromLint(lintResult, options = {}) {
  const issues = lintResult?.issues || [];
  const errorCount = issues.filter((i) => i.severity === 'error').length;
  const warningCount = issues.filter((i) => i.severity === 'warning').length;

  let status = 'pass';
  if (errorCount > 0) status = 'fail';
  else if (warningCount > 0) status = 'partial';

  const evidence = [{
    check: 'datacenter',
    kind: 'lint-output',
    summary: `lint-dataspaces: ${lintResult?.modCount ?? 0} mods, ${errorCount} errors, ${warningCount} warnings, ${issues.length} total issues`,
    details: {
      modCount: lintResult?.modCount ?? 0,
      errorCount,
      warningCount,
      infoCount: issues.filter((i) => i.severity === 'info').length,
    },
  }];

  const failures = issues
    .filter((i) => i.severity === 'error' || i.severity === 'warning')
    .slice(0, 50) // 限制条数避免报告膨胀
    .map((i) => ({
      check: 'datacenter',
      message: `[${i.code}] ${i.message}`,
      severity: i.severity,
      source: i.file || undefined,
    }))
    .filter((f) => f.source !== undefined || true); // 保留无 source 的失败项

  return { checks: { datacenter: status }, evidence, failures };
}

/**
 * 从 launcher dry-run plan 聚合 evidence，用于 documentRoundtrip 与 dependencyClosure。
 *
 * @param {object} launcherPlan - LauncherCompatibilityPlan 对象
 * @param {object} [options]
 * @param {string} [options.planPath] - plan 文件路径
 * @returns {{ evidence: object[] }}
 */
export function aggregateFromLauncherPlan(launcherPlan, options = {}) {
  const evidence = [];

  if (!launcherPlan) return { evidence };

  const docDeps = launcherPlan.documentRewrite?.DocumentHeader || [];
  const galaxyCount = (launcherPlan.galaxyInjection || []).length;
  const layerCount = (launcherPlan.dependencyLayers || []).length;

  evidence.push({
    check: 'documentRoundtrip',
    kind: 'plan-json',
    summary: `launcher plan: ${docDeps.length} document deps, DocumentHeader === DocumentInfo: ${launcherPlan.documentRewrite?.DocumentHeader?.length === launcherPlan.documentRewrite?.DocumentInfo?.length}`,
    path: options.planPath,
    details: {
      documentDeps: docDeps.length,
      galaxyInjection: galaxyCount,
      dependencyLayers: layerCount,
    },
  });

  evidence.push({
    check: 'dependencyClosure',
    kind: 'plan-json',
    summary: `launcher plan layers: ${layerCount} (L1=${launcherPlan.dependencyLayers?.find((l) => l.layer === 'L1')?.entries?.length ?? 0}, L2=${launcherPlan.dependencyLayers?.find((l) => l.layer === 'L2')?.entries?.length ?? 0}, L4=${launcherPlan.dependencyLayers?.find((l) => l.layer === 'L4')?.entries?.length ?? 0})`,
    path: options.planPath,
    details: {
      layers: layerCount,
      galaxyInjection: galaxyCount,
    },
  });

  return { evidence };
}

/**
 * 从 comparePlans 结果聚合 evidence + failures，更新 dependencyClosure 检查点状态。
 *
 * @param {object} compareResult - comparePlans 返回的 { consistent, differences }
 * @param {object} [options]
 * @param {string} [options.compositionPlanPath]
 * @param {string} [options.launcherPlanPath]
 * @returns {{ checks: { dependencyClosure: string }, evidence: object[], failures: object[] }}
 */
export function aggregateFromComparePlans(compareResult, options = {}) {
  const status = compareResult.consistent ? 'pass' : 'fail';

  const evidence = [{
    check: 'dependencyClosure',
    kind: 'compare-plans',
    summary: compareResult.consistent
      ? 'CompositionPlan 与 LauncherCompatibilityPlan 一致'
      : `CompositionPlan 与 LauncherCompatibilityPlan 存在 ${compareResult.differences.length} 处差异`,
    details: {
      differences: compareResult.differences,
    },
  }];

  const failures = compareResult.consistent
    ? []
    : compareResult.differences.map((d) => ({
        check: 'dependencyClosure',
        message: d,
        severity: 'error',
        source: 'comparePlans',
      }));

  return { checks: { dependencyClosure: status }, evidence, failures };
}

/**
 * 从 CompositionPlan validatePlan 结果聚合 evidence + failures，更新 schema 检查点。
 *
 * @param {{ valid: boolean, errors: string[] }} validationResult
 * @param {object} [options]
 * @param {string} [options.planPath]
 * @returns {{ checks: { schema: string }, evidence: object[], failures: object[] }}
 */
export function aggregateFromSchemaValidation(validationResult, options = {}) {
  const status = validationResult.valid ? 'pass' : 'fail';

  const evidence = [{
    check: 'schema',
    kind: 'schema-validation',
    summary: validationResult.valid
      ? 'CompositionPlan schema 校验通过'
      : `CompositionPlan schema 校验失败：${validationResult.errors.length} 个错误`,
    path: options.planPath,
    details: {
      errorCount: validationResult.errors.length,
    },
  }];

  const failures = validationResult.valid
    ? []
    : validationResult.errors.map((e) => ({
        check: 'schema',
        message: e,
        severity: 'error',
        source: 'validatePlan',
      }));

  return { checks: { schema: status }, evidence, failures };
}

/**
 * 从 galaxy-checker 结果聚合证据。
 *
 * @param {object} galaxyResult - galaxy-checker 输出（CheckResult JSON）
 * @param {object} options - { compositionId }
 * @returns {{ checks: object, evidence: object[], failures: object[] }}
 */
export function aggregateFromGalaxyChecker(galaxyResult, options = {}) {
  const errorCount = galaxyResult.summary?.errors ?? 0;
  const warningCount = galaxyResult.summary?.warnings ?? 0;
  const filesChecked = galaxyResult.filesChecked ?? 0;

  // blocking issues 决定 pass/fail；无 blocking 字段时按 error 数判断
  const blockingIssues = (galaxyResult.issues || []).filter(i => i.blocking === true);
  const status = blockingIssues.length > 0
    ? 'fail'
    : (errorCount > 0 ? 'partial' : 'pass');

  const evidence = [{
    check: 'galaxyChecker',
    kind: 'galaxy-static-check',
    summary: `${filesChecked} files checked, ${errorCount} errors, ${warningCount} warnings, ${blockingIssues.length} blocking`,
    path: options.checkerPath,
    details: {
      filesChecked,
      errorCount,
      warningCount,
      blockingCount: blockingIssues.length,
      compositionId: galaxyResult.compositionId,
      contextLoaded: galaxyResult.contextLoaded,
    },
  }];

  const failures = blockingIssues.slice(0, 20).map(i => ({
    check: 'galaxyChecker',
    message: `${i.file}:${i.line} [${i.ruleCode}] ${i.message}`,
    severity: 'error',
    source: 'galaxy-checker',
  }));

  return { checks: { galaxyChecker: status }, evidence, failures };
}

/**
 * 从 DocumentHeader/DocumentInfo roundtrip 结果聚合证据。
 *
 * @param {object} roundtripResult - { valid: boolean, originalDeps: string[], infoDeps: string[], errors: string[] }
 * @param {object} options - { mapPath }
 * @returns {{ checks: object, evidence: object[], failures: object[] }}
 */
export function aggregateFromDocumentRoundtrip(roundtripResult, options = {}) {
  const status = roundtripResult.valid ? 'pass' : 'fail';

  const evidence = [{
    check: 'documentRoundtrip',
    kind: 'document-dependency-roundtrip',
    summary: roundtripResult.valid
      ? `DocumentHeader/Info roundtrip 通过 (header: ${roundtripResult.originalDeps?.length ?? 0} deps, info: ${roundtripResult.infoDeps?.length ?? 0} deps)`
      : `DocumentHeader/Info roundtrip 失败：${roundtripResult.errors?.length ?? 0} 个错误`,
    path: options.mapPath,
    details: {
      headerDepCount: roundtripResult.originalDeps?.length ?? 0,
      infoDepCount: roundtripResult.infoDeps?.length ?? 0,
      errorCount: roundtripResult.errors?.length ?? 0,
    },
  }];

  const failures = roundtripResult.valid
    ? []
    : (roundtripResult.errors || []).map(e => ({
        check: 'documentRoundtrip',
        message: e,
        severity: 'error',
        source: 'document-dependencies',
      }));

  return { checks: { documentRoundtrip: status }, evidence, failures };
}

/**
 * 合并多个聚合结果到一个 report。
 *
 * @param {object} report - 待合并入的 VerificationReport（会被修改）
 * @param  {...object} aggregates - aggregateFrom* 返回的对象
 * @returns {object} 更新后的 report
 */
export function mergeIntoReport(report, ...aggregates) {
  for (const agg of aggregates) {
    if (agg.checks) {
      for (const [k, v] of Object.entries(agg.checks)) {
        report.checks[k] = v;
      }
    }
    if (agg.evidence) {
      report.evidence.push(...agg.evidence);
    }
    if (agg.failures) {
      report.failures.push(...agg.failures);
    }
  }

  // 重新计算 incompleteReasons：移除已 pass/fail/partial 的检查点
  report.incompleteReasons = report.incompleteReasons.filter((r) => {
    const status = report.checks[r.check];
    return status === 'pending' || status === 'skipped';
  });
  // 补充新出现的 pending 检查点
  const existingChecks = new Set(report.incompleteReasons.map((r) => r.check));
  for (const cp of CHECK_POINTS) {
    if ((report.checks[cp] === 'pending' || report.checks[cp] === 'skipped') && !existingChecks.has(cp)) {
      report.incompleteReasons.push({
        check: cp,
        reason: report.checks[cp] === 'skipped' ? 'Skipped by caller' : 'Not executed yet',
      });
    }
  }

  const { valid, errors } = validateReport(report);
  if (!valid) {
    throw new Error(`合并后 VerificationReport 校验失败: ${errors.join('; ')}`);
  }
  return report;
}

/**
 * 推导报告整体状态。
 *
 * 优先级：fail > partial > pending > skipped > pass
 *
 * @param {object} report
 * @returns {{ overall: 'pass'|'fail'|'partial'|'pending', summary: string }}
 */
export function deriveOverallStatus(report) {
  const statuses = Object.values(report.checks || {});
  if (statuses.includes('fail')) {
    return { overall: 'fail', summary: '存在失败检查点' };
  }
  if (statuses.includes('partial')) {
    return { overall: 'partial', summary: '部分检查点未完全通过' };
  }
  if (statuses.includes('pending')) {
    return { overall: 'pending', summary: '存在未执行检查点' };
  }
  if (statuses.every((s) => s === 'pass' || s === 'skipped')) {
    return { overall: 'pass', summary: '所有执行的检查点均通过' };
  }
  return { overall: 'pending', summary: '状态未确定' };
}

/**
 * 生成 Markdown 摘要。
 *
 * @param {object} report
 * @returns {string} Markdown 文本
 */
export function summarize(report) {
  const { overall, summary: overallSummary } = deriveOverallStatus(report);
  const lines = [];
  lines.push(`# VerificationReport - ${report.compositionId}`);
  lines.push('');
  lines.push(`- Run ID: \`${report.runId}\``);
  lines.push(`- Generated: ${report.generatedAt || '-'}`);
  lines.push(`- Overall: **${overall}** — ${overallSummary}`);
  lines.push('');

  lines.push('## Checks');
  for (const cp of CHECK_POINTS) {
    const status = report.checks?.[cp] || 'pending';
    const icon = status === 'pass' ? '[pass]' : status === 'fail' ? '[FAIL]' : status === 'partial' ? '[part]' : `[${status}]`;
    lines.push(`- ${icon} \`${cp}\``);
  }
  lines.push('');

  if (report.evidence?.length > 0) {
    lines.push(`## Evidence (${report.evidence.length})`);
    for (const e of report.evidence) {
      lines.push(`- **${e.check}** (${e.kind}): ${e.summary}${e.path ? `  \n  - path: \`${e.path}\`` : ''}`);
    }
    lines.push('');
  }

  if (report.failures?.length > 0) {
    lines.push(`## Failures (${report.failures.length})`);
    for (const f of report.failures) {
      const sev = f.severity || 'error';
      lines.push(`- [${sev}] **${f.check}**: ${f.message}${f.source ? `  \n  - source: \`${f.source}\`` : ''}`);
    }
    lines.push('');
  }

  if (report.incompleteReasons?.length > 0) {
    lines.push(`## Incomplete (${report.incompleteReasons.length})`);
    for (const r of report.incompleteReasons) {
      lines.push(`- \`${r.check}\`: ${r.reason}`);
    }
    lines.push('');
  }

  return lines.join('\n');
}
