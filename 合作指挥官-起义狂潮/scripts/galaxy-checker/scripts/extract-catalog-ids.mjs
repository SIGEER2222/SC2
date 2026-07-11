#!/usr/bin/env node
// extract-catalog-ids.mjs
// 从所有 mod 的 GameData XML 中提取 catalog ID，合并到 catalog-ids.json。
// 用法: node extract-catalog-ids.mjs <mods-dir> <output-json>
import { readdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, basename } from 'node:path';

function walkDir(dir, out) {
  const entries = readdirSync(dir, { withFileTypes: true });
  for (const e of entries) {
    const full = join(dir, e.name);
    if (e.isDirectory()) {
      walkDir(full, out);
    } else if (e.isFile() && e.name.endsWith('.xml')) {
      out.push(full);
    }
  }
}

// 从 XML 中提取所有 id="..." 属性值，按文件名分类
function extractIdsFromXml(xmlPath) {
  const content = readFileSync(xmlPath, 'utf-8');
  const ids = new Set();
  // 匹配 id="..." 属性（不区分大小写）
  const re = /\bid\s*=\s*"([^"]+)"/gi;
  let m;
  while ((m = re.exec(content)) !== null) {
    ids.add(m[1]);
  }
  return ids;
}

// 根据文件名推断 catalog 类型
function inferCatalogType(fileName) {
  const lower = fileName.toLowerCase();
  if (lower.includes('unit')) return 'Unit';
  if (lower.includes('abil')) return 'Abil';
  if (lower.includes('upgrade')) return 'Upgrade';
  if (lower.includes('behavior') || lower.includes('buff')) return 'Behavior';
  if (lower.includes('effect')) return 'Effect';
  if (lower.includes('button')) return 'Button';
  return null; // 未知类型，归入 'any'
}

function main() {
  const modsDir = process.argv[2];
  const outputPath = process.argv[3];
  if (!modsDir || !outputPath) {
    console.error('用法: node extract-catalog-ids.mjs <mods-dir> <output-json>');
    process.exit(2);
  }
  if (!existsSync(modsDir)) {
    console.error(`目录不存在: ${modsDir}`);
    process.exit(1);
  }

  // 收集所有 XML 文件
  const xmlFiles = [];
  walkDir(modsDir, xmlFiles);
  console.log(`扫描 ${xmlFiles.length} 个 XML 文件...`);

  // 按类型分组的 ID 集合
  const catalog = {
    Unit: new Set(),
    Abil: new Set(),
    Upgrade: new Set(),
    Behavior: new Set(),
    Effect: new Set(),
    Button: new Set(),
    any: new Set(), // 所有 ID 的并集
  };

  let totalIds = 0;
  for (const xmlFile of xmlFiles) {
    const fileName = basename(xmlFile);
    const cat = inferCatalogType(fileName);
    const ids = extractIdsFromXml(xmlFile);
    for (const id of ids) {
      catalog.any.add(id);
      totalIds++;
      if (cat) {
        catalog[cat].add(id);
      }
    }
  }

  // 转换为数组并排序
  const output = {};
  for (const [key, set] of Object.entries(catalog)) {
    output[key] = [...set].sort();
  }

  writeFileSync(outputPath, JSON.stringify(output, null, 2), 'utf-8');
  console.log(`提取完成:`);
  for (const [key, arr] of Object.entries(output)) {
    console.log(`  ${key}: ${arr.length} IDs`);
  }
  console.log(`总计 ${totalIds} 个 ID 引用（含重复），输出到 ${outputPath}`);
}

main();
