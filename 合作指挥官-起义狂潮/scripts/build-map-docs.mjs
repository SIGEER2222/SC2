// build-map-docs.mjs
// Parse Maps/<map>/MapScript.galaxy for every map directory and generate
// per-map logic breakdown docs under docs/maps/<map-name>.md, plus an
// index docs/maps/README.md.
//
// Usage: node scripts/build-map-docs.mjs
//
// Notes on trigger Chinese-name mapping (调查结论):
// - MapScript.galaxy 中每个 "bool gt_X_Func" 上方都有 "// Trigger: <编辑器显示名>"
//   注释,这是最可靠的显示名来源(与 TriggerStrings 中同 GUID 的值一致)。
// - TriggerStrings.txt 中地图级触发器键形如 "Trigger/Name/<8位GUID>=<名字>"。
//   通过"去掉名字中非标识符字符 == gt_ 后缀"可以把 gt_ 名映射到 GUID,再查
//   zhCN.SC2Data 的同 GUID 条目。该映射机制可行(抽样命中率 ~85%+),
//   但实测全部 42 张图的 zhCN 地图级触发器名均为英文(0 条含中文),
//   即作者从未给地图触发器起过中文名;含中文的只有 lib_ 前缀的库触发器,
//   不属于 MapScript 的 gt_ 范畴。因此文档中触发器只展示编辑器显示名
//   (英文),若某天 zhCN 中出现含中文的名字,脚本会自动附上。
//
// 输出文件均为 UTF-8 无 BOM;读取 galaxy/txt 时会剥离可能存在的 UTF-8 BOM。

import { readFileSync, writeFileSync, readdirSync, existsSync, statSync, mkdirSync } from 'fs';
import { dirname, join, resolve, basename } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, '..');
const mapsRoot = join(projectRoot, 'Maps');
const outDir = join(projectRoot, 'docs', 'maps');
const mapsJsonFile = join(projectRoot, 'Shared', 'Maps', 'maps.json');
const cnIndexFile = join(projectRoot, 'docs', 'others', '地图中文名索引-2026-06-19.md');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function readText(file) {
  // Strip UTF-8 BOM if present.
  return readFileSync(file, 'utf8').replace(/^\uFEFF/, '');
}

const hasCJK = (s) => /[\u4e00-\u9fff]/.test(s);
const sanitizeIdent = (s) => s.replace(/[^A-Za-z0-9_]/g, '');

// ---------------------------------------------------------------------------
// Load reusable metadata
// ---------------------------------------------------------------------------

// maps.json: map_id -> metadata
const mapsJson = JSON.parse(readText(mapsJsonFile));
const metaById = new Map(mapsJson.maps.map((m) => [m.map_id, m]));

// 中文名索引: map directory name -> Chinese name
const cnNameByDir = new Map();
if (existsSync(cnIndexFile)) {
  for (const line of readText(cnIndexFile).split(/\r?\n/)) {
    const m = line.match(/^\|\s*([^|]+?)\s*\|\s*`[^`]*`\s*\|\s*`([^`]+)`\s*\|/);
    if (m) cnNameByDir.set(m[2], m[1]);
  }
}

function chineseNameFor(dirName) {
  if (cnNameByDir.has(dirName)) return cnNameByDir.get(dirName);
  // xm 变体沿用对应 _7vs1 图的中文名
  const base = dirName.replace(/_xm\.SC2Map$/, '_7vs1.SC2Map');
  if (base !== dirName && cnNameByDir.has(base)) {
    return cnNameByDir.get(base) + '(xm 变体)';
  }
  return null;
}

// ---------------------------------------------------------------------------
// Parse one map
// ---------------------------------------------------------------------------

function parseTriggerStrings(file) {
  // Returns Map<GUID, name> for map-level triggers (8-hex-digit keys only).
  const out = new Map();
  if (!existsSync(file)) return out;
  for (const line of readText(file).split(/\r?\n/)) {
    const m = line.match(/^Trigger\/Name\/([0-9A-F]{8})=(.*)$/);
    if (m) out.set(m[1], m[2]);
  }
  return out;
}

function parseMap(dirName) {
  const dir = join(mapsRoot, dirName);
  const scriptFile = join(dir, 'MapScript.galaxy');
  const src = readText(scriptFile);
  const lines = src.split(/\r?\n/);

  // include libraries
  const includes = [...src.matchAll(/^include\s+"([^"]+)"/gm)].map((m) => m[1]);

  // global variables: top-level declarations of gv_ names, e.g.
  //   int gv_x;  /  const int gv_y = 1;  /  unitgroup[4] gv_z;
  const varRe = /^(?:const\s+)?([A-Za-z_]\w*)((?:\[[^\]]*\])*)\s+(gv_\w+)(?:\s*=\s*[^;]+)?;\s*$/;
  const variables = []; // { type, name, isArray }
  for (const line of lines) {
    const m = line.match(varRe);
    if (m) variables.push({ type: m[1], name: m[3], isArray: m[2] !== '' });
  }

  // triggers: "// Trigger: <display name>" comment precedes "bool gt_X_Func"
  const triggers = []; // { name (gt_X), display }
  const displayByName = new Map();
  const commentRe = /\/\/ Trigger: (.+?)\r?\n\/\/-+\r?\nbool (gt_\w+)_Func\b/g;
  for (const m of src.matchAll(commentRe)) {
    displayByName.set(m[2], m[1].trim());
  }
  for (const m of src.matchAll(/^bool (gt_\w+)_Func\s*\(/gm)) {
    triggers.push({ name: m[1], display: displayByName.get(m[1]) ?? null });
  }

  // TriggerStrings mapping: gt_ name -> GUID -> zhCN name (only useful if CJK)
  const enStrings = parseTriggerStrings(join(dir, 'enUS.SC2Data', 'LocalizedData', 'TriggerStrings.txt'));
  const zhStrings = parseTriggerStrings(join(dir, 'zhCN.SC2Data', 'LocalizedData', 'TriggerStrings.txt'));
  const guidByIdent = new Map(); // 'gt_<sanitized>' -> [guid, ...]
  const merged = new Map([...enStrings, ...zhStrings]); // zhCN 优先(条目更全)
  for (const [guid, name] of merged) {
    const key = 'gt_' + sanitizeIdent(name);
    if (!guidByIdent.has(key)) guidByIdent.set(key, []);
    guidByIdent.get(key).push(guid);
  }
  let mapped = 0;
  for (const t of triggers) {
    const guids = guidByIdent.get(t.name);
    if (guids && guids.length === 1) {
      mapped++;
      const zh = zhStrings.get(guids[0]);
      if (zh && hasCJK(zh)) t.zhName = zh;
    }
  }

  return {
    dirName,
    lineCount: lines.length,
    includes,
    variables,
    triggers,
    mappingStats: { total: triggers.length, mapped },
  };
}

// ---------------------------------------------------------------------------
// Trigger classification
// ---------------------------------------------------------------------------

const CATEGORIES = ['初始化', '进攻波次', '胜负', '对白提示', '其他'];

function classifyTrigger(t) {
  const n = t.name.replace(/^gt_/, '');
  const d = t.display ?? '';
  const both = n + ' ' + d;
  if (/^(Init|Initialization|Melee\s*Init)/i.test(n) || /^(Init|Initialization)/i.test(d) ||
      /StartGame|Start Game/i.test(both) || /Intro|Briefing|Preload/i.test(both)) {
    return '初始化';
  }
  if (/Attack|Wave|Patrol|DropPod|Drop Pod|Nydus|Tumor/i.test(both)) return '进攻波次';
  if (/Victory|Defeat/i.test(both)) return '胜负';
  if (/Q$/.test(n) || /Transmission/i.test(both)) return '对白提示';
  return '其他';
}

// ---------------------------------------------------------------------------
// Scan all maps
// ---------------------------------------------------------------------------

const allDirs = readdirSync(mapsRoot).filter((d) => {
  const full = join(mapsRoot, d);
  return statSync(full).isDirectory() && existsSync(join(full, 'MapScript.galaxy'));
});
const skipped = readdirSync(mapsRoot).filter((d) => !allDirs.includes(d));

function mapType(dirName) {
  if (/^t\w+_7vs1\.SC2Map$/i.test(dirName)) return '战役改造';
  if (/^t\w+_xm\.SC2Map$/i.test(dirName)) return 'xm变体';
  return '测试/第三方';
}

const parsed = allDirs.map(parseMap);
const byDir = new Map(parsed.map((p) => [p.dirName, p]));

// 公共框架集合:27 张 _7vs1 图共有的 gt_ 名与 gv_ 名
const coreMaps = parsed.filter((p) => mapType(p.dirName) === '战役改造');
function intersectionOf(listOfSets) {
  let acc = null;
  for (const s of listOfSets) {
    if (acc === null) acc = new Set(s);
    else acc = new Set([...acc].filter((x) => s.has(x)));
  }
  return acc ?? new Set();
}
const commonTriggers = intersectionOf(coreMaps.map((p) => new Set(p.triggers.map((t) => t.name))));
const commonVars = intersectionOf(coreMaps.map((p) => new Set(p.variables.map((v) => v.name))));

// ---------------------------------------------------------------------------
// Emit per-map docs
// ---------------------------------------------------------------------------

mkdirSync(outDir, { recursive: true });

function docFileName(dirName) {
  return dirName.replace(/\.SC2Map$/i, '') + '.md';
}

function triggerLine(t) {
  const bare = t.name.replace(/^gt_/, '');
  const display = t.display && t.display !== bare ? ` — ${t.display}` : '';
  const zh = t.zhName ? `(${t.zhName})` : '';
  return `- \`${t.name}\`${display}${zh}`;
}

let totalMapped = 0;
let totalTriggers = 0;

for (const p of parsed) {
  const cnName = chineseNameFor(p.dirName);
  const mapId = p.dirName.replace(/\.SC2Map$/i, '');
  const meta = metaById.get(mapId);
  const type = mapType(p.dirName);
  const isCore = type === '战役改造' || type === 'xm变体';
  totalMapped += p.mappingStats.mapped;
  totalTriggers += p.mappingStats.total;

  let md = '';
  md += `# ${mapId}${cnName ? `(${cnName})` : ''}\n\n`;
  md += `> 本文档由 \`scripts/build-map-docs.mjs\` 自动生成,请勿手工编辑自动段落;`;
  md += `"特有机制"小节欢迎人工补充后另存他处或改用独立文档。\n\n`;

  // 概览
  md += `## 概览\n\n`;
  md += `| 项目 | 值 |\n| --- | --- |\n`;
  md += `| 地图目录 | \`Maps/${p.dirName}\` |\n`;
  md += `| 类型 | ${type} |\n`;
  md += `| MapScript.galaxy 行数 | ${p.lineCount} |\n`;
  md += `| 触发器总数(gt_*_Func) | ${p.triggers.length} |\n`;
  md += `| 全局变量数(gv_) | ${p.variables.length} |\n`;
  if (p.includes.length) {
    md += `| include 库 | ${p.includes.map((i) => `\`${i}\``).join('、')} |\n`;
  }
  if (meta) {
    const fmt = (v) => (v === undefined || v === -1 ? '默认' : String(v));
    if (meta.minerals_difficulty) {
      md += `| 起始晶体矿 | 按难度 [${meta.minerals_difficulty.join(', ')}] |\n`;
    } else {
      md += `| 起始晶体矿 | ${fmt(meta.start_minerals)} |\n`;
    }
    md += `| 起始高能瓦斯 | ${fmt(meta.start_vespene)} |\n`;
    md += `| 起始人口(supplies made) | ${fmt(meta.start_supplies)} |\n`;
    const flags = [];
    if (meta.needs_pre_init_rpg) flags.push('needs_pre_init_rpg');
    if (meta.needs_unit_event_null) flags.push('needs_unit_event_null');
    if (meta.uses_shared_ally) flags.push('uses_shared_ally');
    if (meta.second_unit_offset) {
      flags.push(`second_unit_offset(${meta.second_unit_offset.method}=${meta.second_unit_offset.value ?? `${meta.second_unit_offset.offset}@${meta.second_unit_offset.angle}`})`);
    }
    md += `| 特殊标志位 | ${flags.length ? flags.map((f) => `\`${f}\``).join('、') : '无'} |\n`;
  }
  md += `\n`;

  // 全局变量摘要
  md += `## 全局变量摘要\n\n`;
  const byType = new Map();
  for (const v of p.variables) {
    const key = v.type + (v.isArray ? '[]' : '');
    if (!byType.has(key)) byType.set(key, []);
    byType.get(key).push(v);
  }
  if (p.variables.length === 0) {
    md += `(无 gv_ 全局变量)\n\n`;
  } else {
    md += `按类型统计:\n\n`;
    md += `| 类型 | 数量 |\n| --- | --- |\n`;
    for (const [type, vs] of [...byType.entries()].sort((a, b) => b[1].length - a[1].length)) {
      md += `| \`${type}\` | ${vs.length} |\n`;
    }
    md += `\n`;
    const specific = isCore ? p.variables.filter((v) => !commonVars.has(v.name)) : p.variables;
    const commonCount = p.variables.length - (isCore ? specific.length : p.variables.length);
    if (isCore && commonCount > 0) {
      md += `其中 ${commonCount} 个为公共框架变量(${coreMaps.length} 张 _7vs1 图共有,从略)。\n\n`;
    }
    if (specific.length > 0) {
      md += `本图特有变量(${specific.length} 个):\n\n`;
      for (const v of specific) {
        md += `- \`${v.type}${v.isArray ? '[]' : ''} ${v.name}\`\n`;
      }
      md += `\n`;
    } else if (isCore) {
      md += `本图没有公共框架之外的特有变量。\n\n`;
    }
  }

  // 触发器清单
  md += `## 触发器清单\n\n`;
  const grouped = new Map(CATEGORIES.map((c) => [c, []]));
  for (const t of p.triggers) grouped.get(classifyTrigger(t)).push(t);
  for (const c of CATEGORIES) {
    const ts = grouped.get(c);
    if (ts.length === 0) continue;
    md += `### ${c}(${ts.length})\n\n`;
    for (const t of ts) md += triggerLine(t) + '\n';
    md += `\n`;
  }

  // 特有机制
  md += `## 特有机制(待人工补充)\n\n`;
  md += `<!-- 请在此补充该图的特有玩法/机制说明 -->\n\n`;
  if (isCore) {
    const specificTriggers = p.triggers.filter((t) => !commonTriggers.has(t.name));
    md += `以下为非公共触发器(不在 ${coreMaps.length} 张 _7vs1 图共有的 ${commonTriggers.size} 个公共框架触发器集合中),`;
    md += `可作为梳理本图特有逻辑的线索(共 ${specificTriggers.length} 个):\n\n`;
    for (const t of specificTriggers) md += triggerLine(t) + '\n';
  } else {
    md += `本图不属于 _7vs1 战役改造框架,未做公共/特有触发器区分,请直接参考上方触发器清单。\n`;
  }
  md += `\n`;

  writeFileSync(join(outDir, docFileName(p.dirName)), md, 'utf8');
}

// ---------------------------------------------------------------------------
// Emit index README.md
// ---------------------------------------------------------------------------

let idx = '';
idx += `# 地图逻辑拆解文档索引\n\n`;
idx += `> 由 \`scripts/build-map-docs.mjs\` 自动生成(数据来源:各图 MapScript.galaxy、`;
idx += `Shared/Maps/maps.json、docs/others/地图中文名索引)。重新生成:\`node scripts/build-map-docs.mjs\`。\n\n`;
idx += `公共框架触发器集合(${coreMaps.length} 张 _7vs1 图共有的 gt_ 名)大小:**${commonTriggers.size}**;`;
idx += `公共框架全局变量集合大小:**${commonVars.size}**。\n\n`;
idx += `| 地图目录 | 中文名 | 类型 | 触发器数 | 文档 |\n`;
idx += `| --- | --- | --- | ---: | --- |\n`;
const order = { '战役改造': 0, 'xm变体': 1, '测试/第三方': 2 };
const sorted = [...parsed].sort((a, b) =>
  order[mapType(a.dirName)] - order[mapType(b.dirName)] || a.dirName.localeCompare(b.dirName));
for (const p of sorted) {
  const cn = chineseNameFor(p.dirName) ?? '—';
  const f = docFileName(p.dirName);
  idx += `| \`${p.dirName}\` | ${cn} | ${mapType(p.dirName)} | ${p.triggers.length} | [${f}](./${encodeURI(f)}) |\n`;
}
idx += `\n`;
if (skipped.length) {
  idx += `未生成文档的条目:${skipped.map((s) => `\`${s}\``).join('、')}`;
  idx += `(为打包的 .SC2Map 文件或缺少 MapScript.galaxy,无法直接解析)。\n`;
}
writeFileSync(join(outDir, 'README.md'), idx, 'utf8');

console.log(`Generated ${parsed.length} map docs + README.md in ${outDir}`);
console.log(`Common framework trigger set: ${commonTriggers.size} (across ${coreMaps.length} _7vs1 maps)`);
console.log(`Common framework variable set: ${commonVars.size}`);
console.log(`Trigger name -> TriggerStrings GUID mapping: ${totalMapped}/${totalTriggers} (${(totalMapped / totalTriggers * 100).toFixed(1)}%)`);
const zhHits = parsed.reduce((n, p) => n + p.triggers.filter((t) => t.zhName).length, 0);
console.log(`Triggers with Chinese zhCN names: ${zhHits}`);
