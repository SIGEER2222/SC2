#!/usr/bin/env node
/**
 * sc2-editor-toolkit CLI —— GameData XML 解析/校验工具链（离线银河编辑器数据层）
 *
 * 用法:
 *   node cli.mjs validate <mod路径...> [--deps <mod路径...>] [--format json|text] [--rules <file>]
 *   node cli.mjs dump <mod路径...> --catalog <名> --id <条目id> [--format xml|json]
 *   node cli.mjs list <mod路径...> [--catalog <名>] [--filter <正则>]
 *
 * 退出码: 0 无 error / 1 存在 error / 2 工具异常或用法错误
 */
import fs from 'node:fs';
import { validate } from './src/validator.mjs';
import { report } from './src/reporter.mjs';
import { CatalogStore } from './src/catalog.mjs';
import { loadModIntoStore } from './src/modLoader.mjs';

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
    --filter <正则>       id 过滤`;

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

function main() {
  const [command, ...rest] = process.argv.slice(2);
  if (!command || command === '--help' || command === '-h') {
    console.error(USAGE);
    return 2;
  }
  const { positional, flags } = parseArgs(rest);

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
