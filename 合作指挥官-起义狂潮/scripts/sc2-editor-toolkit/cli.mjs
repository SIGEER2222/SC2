#!/usr/bin/env node
/**
 * sc2-editor-toolkit CLI —— GameData XML 解析/校验工具链（离线银河编辑器数据层）
 *
 * 用法:
 *   node cli.mjs validate <mod路径...> [--deps <mod路径...>] [--format json|text] [--rules <file>]
 *   node cli.mjs dump <mod路径...> --catalog <名> --id <条目id> [--format xml|json]
 *   node cli.mjs list <mod路径...> [--catalog <名>] [--filter <正则>]
 *   node cli.mjs inspect <地图或mod路径> [--format json|text]
 *   node cli.mjs trace <地图或mod路径> --catalog <名> --id <条目id> [--field <字段>]
 *   node cli.mjs compare <左地图或mod> <右地图或mod> --catalog <名> --id <条目id>
 *   node cli.mjs doctor [--format json|text]
 *   node cli.mjs check [文件...] [--changed] [--run] [--format json|text]
 *
 * 退出码: 0 无 error / 1 存在 error / 2 工具异常或用法错误
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { validate } from './src/validator.mjs';
import { report } from './src/reporter.mjs';
import { CatalogStore } from './src/catalog.mjs';
import { loadModIntoStore } from './src/modLoader.mjs';
import { buildDependencyGraph, readWorkflowConfig } from './src/dependencyGraph.mjs';
import { compareCatalogTraces, traceCatalogId } from './src/provenance.mjs';
import {
  buildValidationPlan,
  changedFiles,
  doctorProject,
  runValidationPlan,
} from './src/workflow.mjs';

const USAGE = `用法: node cli.mjs <command> ...
命令:
  validate <mod路径...>   合并 mod 依赖链并做数据完整性校验
    --deps <mod路径...>   依赖 mod（只提供定义、不产生报告；在目标 mod 之前合并）
    --format <json|text>  输出格式，默认 json
    --rules <file>        规则配置 JSON（{"rules":{"XML_DANGLING_REF":{"severity":"warning"}}}）
    --out <file>          输出写入文件

  dump <mod路径...>       输出合并后的条目（编辑器"查看合并字段"）
    --catalog <名>        catalog 名（如 Unit/Abil/Effect）
    --id <条目id>         条目 id
    --format <xml|json>   输出格式，默认 xml

  list <mod路径...>       列出合并后的条目 id
    --catalog <名>        限定 catalog（缺省列出全部 catalog 及数量）
    --filter <正则>       id 过滤

  inspect <地图或mod路径> 解析声明依赖、可解析路径、旧依赖替代信息与父级加载顺序
    --project-root <路径> 项目根目录，默认自动定位
    --config <文件>       工作流配置文件
    --effective           应用启动器等价的有效依赖替换
    --commander <id,...>  有效依赖使用的指挥官 id
    --format <json|text>  输出格式，默认 json

  trace <地图或mod路径>   追踪 Catalog ID 的定义、字段覆盖来源与 Galaxy 运行时修改
    --catalog <名>        catalog 名（如 Unit/Abil/Upgrade）
    --id <条目id>         条目 id
    --field <文本>        只保留路径包含该文本的字段
    --effective           应用启动器等价的有效依赖替换
    --commander <id,...>  有效依赖使用的指挥官 id
    --format <json|text>  输出格式，默认 json

  compare <左路径> <右路径> 对比两个环境中同一 Catalog ID 的定义历史、字段和运行时差异
    --catalog <名>        catalog 名（如 Unit/Abil/Upgrade）
    --id <条目id>         条目 id
    --field <文本>        只对比路径包含该文本的字段
    --left-effective      左侧应用有效依赖替换
    --right-effective     右侧应用有效依赖替换
    --left-commander      左侧指挥官 id，可逗号分隔
    --right-commander     右侧指挥官 id，可逗号分隔
    --allow-incomplete    允许依赖不完整时仍返回 exit 0
    --format <json|text>  输出格式，默认 json

  doctor                  检查路径、工具、文档、旧依赖和双运行时源分叉
    --project-root <路径> 项目根目录，默认自动定位
    --format <json|text>  输出格式，默认 json

  check [文件...]         按改动类型生成最小静态验证计划
    --changed             从 git 工作区读取改动文件（未给文件时默认启用）
    --run                 执行静态检查；游戏内验证只报告要求，不自动启动
    --workspace-root      Git 工作区根目录
    --format <json|text>  输出格式，默认 json`;

const TOOL_DIR = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_PROJECT_ROOT = path.resolve(TOOL_DIR, '..', '..');
const DEFAULT_WORKSPACE_ROOT = path.resolve(DEFAULT_PROJECT_ROOT, '..');

function parseArgs(argv) {
  const positional = [];
  const flags = {};
  let i = 0;
  while (i < argv.length) {
    const a = argv[i];
    if (a === '--deps') {
      flags.deps = [];
      i++;
      while (i < argv.length && !argv[i].startsWith('--')) flags.deps.push(argv[i++]);
    } else if (a.startsWith('--')) {
      const name = a.slice(2);
      if (i + 1 < argv.length && !argv[i + 1].startsWith('--')) {
        flags[name] = argv[++i];
      } else {
        flags[name] = true;
      }
      i++;
    } else {
      positional.push(a);
      i++;
    }
  }
  return { positional, flags };
}

function nodeToXml(node, indent = '') {
  const attrs = Object.entries(node.attrs)
    .map(([k, v]) => ` ${k}="${v.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;')}"`)
    .join('');
  if (node.children.length === 0) return `${indent}<${node.tag}${attrs}/>`;
  const inner = node.children.map(c => nodeToXml(c, indent + '  ')).join('\n');
  return `${indent}<${node.tag}${attrs}>\n${inner}\n${indent}</${node.tag}>`;
}

function nodeToJson(node) {
  return {
    tag: node.tag,
    attrs: node.attrs,
    file: node.file,
    line: node.line,
    children: node.children.map(nodeToJson),
  };
}

function loadStore(modPaths) {
  const store = new CatalogStore();
  const allWarnings = [];
  for (const mod of modPaths) {
    const { warnings } = loadModIntoStore(mod, store);
    allWarnings.push(...warnings);
  }
  for (const w of allWarnings) console.error(`[WARN] ${w}`);
  return store;
}

function outputValue(value, format, textRenderer, outFile = null) {
  const output = format === 'text' ? textRenderer(value) : JSON.stringify(value, null, 2);
  if (typeof outFile === 'string') {
    fs.writeFileSync(outFile, output, 'utf8');
    console.error(`[INFO] 已写入 ${outFile}`);
  } else {
    console.log(output);
  }
}

function dependencyGraphText(graph) {
  const lines = [
    `目标: ${graph.target}`,
    `模式: ${graph.mode}${graph.profile ? ` (${graph.profile})` : ''}`,
    `指挥官: ${graph.commanders.join(', ') || '(未指定)'}`,
    `配置: ${graph.configPath}`,
    '',
    '父级优先加载顺序:',
  ];
  graph.loadOrder.forEach((item, index) => lines.push(`  ${index + 1}. ${item}`));
  lines.push('', '声明依赖:');
  for (const node of graph.nodes) {
    lines.push(`  [${node.name}]`);
    if (node.dependencies.length === 0) lines.push('    (无显式依赖)');
    for (const dep of node.dependencies) {
      const target = dep.path ??
        dep.replacements?.map(item => item.path ?? item.fileRef).join(', ') ??
        dep.legacy?.replacement?.join(', ') ??
        '(未解析)';
      lines.push(`    - ${dep.fileRef ?? dep.raw} [${dep.status}] -> ${target}`);
      if (dep.legacy?.note) lines.push(`      ${dep.legacy.note}`);
    }
  }
  if (graph.issues.length) {
    lines.push('', '问题:');
    for (const item of graph.issues) lines.push(`  [${item.severity}] ${item.code}: ${item.message}`);
  }
  return lines.join('\n');
}

function traceText(trace) {
  const lines = [
    `${trace.catalog} "${trace.id}"`,
    `状态: ${trace.found ? '已找到' : '未找到'}`,
    '',
    '定义/覆盖顺序:',
  ];
  if (trace.definitions.length === 0) lines.push('  (没有定义)');
  for (const def of trace.definitions) {
    lines.push(`  - ${def.file}:${def.line} (${def.tag})`);
    if (def.parent) lines.push(`    parent=${def.parent}`);
  }
  lines.push('', `parent 链: ${trace.parentChain.join(' -> ') || '(无)'}`);
  lines.push(`完整性: ${trace.complete ? '完整' : '不完整'}`);
  if (trace.unresolvedParent) lines.push(`  未加载 parent: ${trace.unresolvedParent}`);
  if (trace.incompleteDependencies.length) {
    lines.push(`  未加载/外部依赖: ${trace.incompleteDependencies.map(item => item.ref).join(', ')}`);
  }
  lines.push(`字段来源模式: ${trace.provenanceMode}`);
  lines.push(`运行时扫描: ${trace.runtimeScan.mode}（完整=${trace.runtimeScan.complete}）`);
  const fields = Object.entries(trace.fieldProvenance);
  lines.push('', `字段来源 (${fields.length}):`);
  for (const [fieldPath, data] of fields) {
    const event = data.effective;
    lines.push(`  - ${fieldPath} = ${event.value} <- ${event.source.file}:${event.source.line}`);
  }
  lines.push('', `运行时修改 (${trace.runtimeMutations.length}):`);
  for (const mutation of trace.runtimeMutations) {
    lines.push(`  - ${mutation.function} ${mutation.file}:${mutation.line}`);
    lines.push(`    ${mutation.text}`);
  }
  return lines.join('\n');
}

function compareText(comparison) {
  const lines = [
    `${comparison.catalog} "${comparison.id}" 环境对比`,
    `模式: ${comparison.comparisonMode}`,
    `状态: ${comparison.status}`,
    `完整性: ${comparison.complete ? '完整' : '不完整'}`,
    `运行时扫描完整: ${comparison.runtimeScanComplete}`,
    `左: ${comparison.left.target} (${comparison.left.complete ? '完整' : '不完整'})`,
    `右: ${comparison.right.target} (${comparison.right.complete ? '完整' : '不完整'})`,
  ];
  const appendIncomplete = (label, trace) => {
    if (trace.incompleteDependencies.length === 0 && !trace.unresolvedParent) return;
    lines.push(`${label}缺失边界:`);
    for (const dependency of trace.incompleteDependencies) {
      lines.push(`  - ${dependency.ref} [${dependency.status}]`);
    }
    if (trace.unresolvedParent) lines.push(`  - parent:${trace.unresolvedParent} [unresolved]`);
  };
  appendIncomplete('左侧', comparison.left);
  appendIncomplete('右侧', comparison.right);
  lines.push(
    '',
    `字段差异 (${comparison.fieldDifferences.length}):`,
  );
  if (comparison.fieldDifferences.length === 0) lines.push('  (无)');
  for (const difference of comparison.fieldDifferences) {
    const left = difference.left
      ? `${difference.left.value} <- ${difference.left.source.file}:${difference.left.source.line}`
      : '(未定义)';
    const right = difference.right
      ? `${difference.right.value} <- ${difference.right.source.file}:${difference.right.source.line}`
      : '(未定义)';
    lines.push(`  - ${difference.path}`);
    lines.push(`    左: ${left}`);
    lines.push(`    右: ${right}`);
  }
  lines.push('', `仅左侧运行时修改 (${comparison.runtimeDifferences.onlyLeft.length}):`);
  for (const mutation of comparison.runtimeDifferences.onlyLeft) {
    lines.push(`  - ${mutation.function} ${mutation.file}:${mutation.line}`);
  }
  lines.push('', `仅右侧运行时修改 (${comparison.runtimeDifferences.onlyRight.length}):`);
  for (const mutation of comparison.runtimeDifferences.onlyRight) {
    lines.push(`  - ${mutation.function} ${mutation.file}:${mutation.line}`);
  }
  return lines.join('\n');
}

function listFlag(value) {
  return typeof value === 'string'
    ? value.split(',').map(item => item.trim()).filter(Boolean)
    : [];
}

function doctorText(result) {
  const lines = [
    `项目: ${result.projectRoot}`,
    `错误: ${result.summary.errors}，警告: ${result.summary.warnings}`,
    `旧依赖声明: ${result.summary.legacyDependencyCount}`,
    `未解析依赖: ${result.summary.unresolvedDependencyCount}`,
  ];
  if (result.summary.runtimeCopies) {
    lines.push(
      `CoreRuntime/CoopZeroPop 同路径文件: 相同 ${result.summary.runtimeCopies.same}，分叉 ${result.summary.runtimeCopies.different}`,
    );
  }
  lines.push('', '检查结果:');
  for (const finding of result.findings) {
    lines.push(`  [${finding.severity}] ${finding.code}: ${finding.message}`);
    if (finding.relocated) lines.push(`    可能已移动到: ${finding.relocated}`);
  }
  return lines.join('\n');
}

function validationText(plan) {
  const lines = ['静态验证:'];
  if (plan.staticActions.length === 0) lines.push('  (无)');
  for (const action of plan.staticActions) {
    lines.push(`  - [${action.kind}] (${action.cwd}) ${action.command} ${action.args.join(' ')}`);
  }
  if (plan.results) {
    lines.push('', '执行结果:');
    for (const result of plan.results) {
      lines.push(`  - ${result.kind}: exit=${result.exitCode}, ${result.durationMs}ms`);
      if (result.parsed?.summary) lines.push(`    ${JSON.stringify(result.parsed.summary)}`);
      for (const line of result.stderr ?? []) lines.push(`    ${line}`);
    }
  }
  lines.push('', `游戏内验证: ${plan.runtimeValidation.required ? '必须' : '不需要'}`);
  if (plan.runtimeValidation.policy) lines.push(`  ${plan.runtimeValidation.policy}`);
  return lines.join('\n');
}

function main() {
  const [command, ...rest] = process.argv.slice(2);
  if (!command || command === '--help' || command === '-h') {
    console.error(USAGE);
    return 2;
  }
  const { positional, flags } = parseArgs(rest);
  const projectRoot = path.resolve(flags['project-root'] || DEFAULT_PROJECT_ROOT);
  const format = flags.format === 'text' ? 'text' : 'json';
  const commanders = listFlag(flags.commander);

  if (command === 'validate') {
    if (positional.length === 0) {
      console.error('validate 需要至少一个 mod 路径\n' + USAGE);
      return 2;
    }
    for (const p of [...positional, ...(flags.deps ?? [])]) {
      if (!fs.existsSync(p)) {
        console.error(`路径不存在: ${p}`);
        return 2;
      }
    }
    let ruleConfig = {};
    if (typeof flags.rules === 'string') {
      ruleConfig = JSON.parse(fs.readFileSync(flags.rules, 'utf8'));
    }
    const { filesChecked, issues, stats } = validate({
      targetMods: positional,
      depMods: flags.deps ?? [],
      ruleConfig,
    });
    const format = flags.format === 'text' ? 'text' : 'json';
    const output = report(issues, filesChecked, format, { stats });
    if (typeof flags.out === 'string') {
      fs.writeFileSync(flags.out, output, 'utf8');
      console.error(`[INFO] 已写入 ${flags.out}`);
    } else {
      console.log(output);
    }
    return issues.some(i => i.severity === 'error') ? 1 : 0;
  }

  if (command === 'dump') {
    if (positional.length === 0 || !flags.catalog || !flags.id) {
      console.error('dump 需要 mod 路径与 --catalog/--id\n' + USAGE);
      return 2;
    }
    const store = loadStore(positional);
    const entry = store.getEntry(flags.catalog, flags.id);
    if (!entry) {
      console.error(`未找到 ${flags.catalog} "${flags.id}"`);
      return 1;
    }
    if (flags.format === 'json') {
      console.log(JSON.stringify({
        catalog: flags.catalog,
        id: entry.id,
        classTag: entry.tag,
        sources: entry.sources,
        node: nodeToJson(entry.node),
      }, null, 2));
    } else {
      console.log(`<!-- ${flags.catalog} "${entry.id}"，定义/修改于: -->`);
      for (const s of entry.sources) console.log(`<!--   ${s.file}:${s.line} (${s.tag}) -->`);
      console.log(nodeToXml(entry.node));
    }
    return 0;
  }

  if (command === 'list') {
    if (positional.length === 0) {
      console.error('list 需要至少一个 mod 路径\n' + USAGE);
      return 2;
    }
    const store = loadStore(positional);
    if (!flags.catalog) {
      const rows = [...store.catalogs.entries()]
        .sort((a, b) => a[0].localeCompare(b[0]))
        .map(([cat, map]) => `  ${cat}: ${map.size}`);
      console.log('合并后 catalog 条目数:\n' + rows.join('\n'));
      return 0;
    }
    const map = store.ids(flags.catalog);
    const re = typeof flags.filter === 'string' ? new RegExp(flags.filter) : null;
    let count = 0;
    for (const [id, entry] of [...map.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
      if (re && !re.test(id)) continue;
      console.log(`  [${entry.tag}] ${id}`);
      count++;
    }
    console.log(`\n共 ${count} 个 ${flags.catalog} 条目` + (re ? `（匹配 /${flags.filter}/）` : ''));
    return 0;
  }

  if (command === 'inspect') {
    if (positional.length !== 1) {
      console.error('inspect 需要一个地图或 mod 路径\n' + USAGE);
      return 2;
    }
    const graph = buildDependencyGraph({
      target: positional[0],
      projectRoot,
      configPath: typeof flags.config === 'string' ? flags.config : null,
      effective: Boolean(flags.effective),
      commanders,
    });
    outputValue(graph, format, dependencyGraphText, flags.out);
    return graph.issues.some(item => item.severity === 'error') ? 1 : 0;
  }

  if (command === 'trace') {
    if (positional.length !== 1 || !flags.catalog || !flags.id) {
      console.error('trace 需要地图或 mod 路径与 --catalog/--id\n' + USAGE);
      return 2;
    }
    const config = readWorkflowConfig(
      projectRoot,
      typeof flags.config === 'string' ? flags.config : null,
    );
    const graph = buildDependencyGraph({
      target: positional[0],
      projectRoot,
      configPath: typeof flags.config === 'string' ? flags.config : null,
      effective: Boolean(flags.effective || commanders.length > 0),
      commanders,
    });
    const trace = traceCatalogId({
      graph,
      catalog: flags.catalog,
      id: flags.id,
      field: typeof flags.field === 'string' ? flags.field : null,
      runtimeMutationFunctions: config.runtimeMutationFunctions ?? [],
    });
    outputValue(trace, format, traceText, flags.out);
    return trace.found ? 0 : 1;
  }

  if (command === 'compare') {
    if (positional.length !== 2 || !flags.catalog || !flags.id) {
      console.error('compare 需要两个地图或 mod 路径与 --catalog/--id\n' + USAGE);
      return 2;
    }
    const config = readWorkflowConfig(
      projectRoot,
      typeof flags.config === 'string' ? flags.config : null,
    );
    const leftCommanders = listFlag(flags['left-commander'] ?? flags.commander);
    const rightCommanders = listFlag(flags['right-commander'] ?? flags.commander);
    const makeTrace = (target, effective, selectedCommanders) => {
      const graph = buildDependencyGraph({
        target,
        projectRoot,
        configPath: typeof flags.config === 'string' ? flags.config : null,
        effective: Boolean(effective || selectedCommanders.length > 0),
        commanders: selectedCommanders,
      });
      return traceCatalogId({
        graph,
        catalog: flags.catalog,
        id: flags.id,
        field: typeof flags.field === 'string' ? flags.field : null,
        runtimeMutationFunctions: config.runtimeMutationFunctions ?? [],
      });
    };
    const comparison = compareCatalogTraces(
      makeTrace(positional[0], flags['left-effective'] || flags.effective, leftCommanders),
      makeTrace(positional[1], flags['right-effective'] || flags.effective, rightCommanders),
    );
    outputValue(comparison, format, compareText, flags.out);
    if (comparison.status === 'missing') return 1;
    if (comparison.status === 'incomplete' && !flags['allow-incomplete']) return 1;
    return 0;
  }

  if (command === 'doctor') {
    const result = doctorProject({
      projectRoot,
      configPath: typeof flags.config === 'string' ? flags.config : null,
    });
    outputValue(result, format, doctorText, flags.out);
    return result.summary.errors > 0 ? 1 : 0;
  }

  if (command === 'check') {
    const workspaceRoot = path.resolve(flags['workspace-root'] || DEFAULT_WORKSPACE_ROOT);
    const files = positional.length > 0 && !flags.changed
      ? positional
      : changedFiles(workspaceRoot);
    const plan = buildValidationPlan({ workspaceRoot, projectRoot, files });
    const result = flags.run ? runValidationPlan(plan) : plan;
    outputValue(result, format, validationText, flags.out);
    return result.results && !result.ok ? 1 : 0;
  }

  console.error(`未知命令: ${command}\n` + USAGE);
  return 2;
}

try {
  process.exit(main());
} catch (e) {
  console.error(`工具异常: ${e.message}`);
  console.error(e.stack);
  process.exit(2);
}
