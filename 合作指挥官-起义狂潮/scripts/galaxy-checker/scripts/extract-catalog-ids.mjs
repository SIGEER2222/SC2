#!/usr/bin/env node
// extract-catalog-ids.mjs
// 从所有 mod 的 GameData XML 中提取 catalog ID，按 XML 元素名分类。
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

// XML 元素名前缀 → catalog 类型映射
// SC2 GameData 中元素名是 C 前缀 + 子类型，如 CAbilEffectTarget, CBehaviorBuff, CEffectDamage
const ELEMENT_PREFIX_TO_CATALOG = [
  { prefix: 'CUnit', catType: 'Unit' },
  { prefix: 'CAbil', catType: 'Abil' },
  { prefix: 'CUpgrade', catType: 'Upgrade' },
  { prefix: 'CBehavior', catType: 'Behavior' },
  { prefix: 'CEffect', catType: 'Effect' },
  { prefix: 'CButton', catType: 'Button' },
];

// 从 XML 中按元素名前缀提取 id 属性，正确分类 catalog 类型
// 同时将所有 C* 元素的 ID 纳入 any 集合（覆盖 CWeapon/CActor/CValidator 等未单独跟踪的类型）
function extractIdsByElement(xmlPath) {
  const content = readFileSync(xmlPath, 'utf-8');
  const result = { Unit: new Set(), Abil: new Set(), Upgrade: new Set(), Behavior: new Set(), Effect: new Set(), Button: new Set(), any: new Set() };

  // 按前缀分类提取
  for (const { prefix, catType } of ELEMENT_PREFIX_TO_CATALOG) {
    const re = new RegExp(`<${prefix}[A-Z][^>]*?\\bid\\s*=\\s*["']([^"']+)["']`, 'gi');
    let m;
    while ((m = re.exec(content)) !== null) {
      result[catType].add(m[1]);
      result.any.add(m[1]);
    }
    const re2 = new RegExp(`<${prefix}\\s+[^>]*?\\bid\\s*=\\s*["']([^"']+)["']`, 'gi');
    while ((m = re2.exec(content)) !== null) {
      result[catType].add(m[1]);
      result.any.add(m[1]);
    }
  }

  // 提取所有 C* 元素的 ID 到 any 集合（覆盖 CWeapon/CActor/CValidator/Camera 等未单独跟踪的类型）
  const anyRe = /<C[A-Z][A-Za-z]+\s+[^>]*?\bid\s*=\s*["']([^"']+)["']/gi;
  let m;
  while ((m = anyRe.exec(content)) !== null) {
    result.any.add(m[1]);
  }

  return result;
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
    any: new Set(),
  };

  let totalIds = 0;
  for (const xmlFile of xmlFiles) {
    const extracted = extractIdsByElement(xmlFile);
    for (const [catType, ids] of Object.entries(extracted)) {
      for (const id of ids) {
        catalog[catType].add(id);
        catalog.any.add(id);
        totalIds++;
      }
    }
  }

  // 转换为数组并排序
  const output = {};
  for (const [key, set] of Object.entries(catalog)) {
    output[key] = [...set].sort();
  }

  writeFileSync(outputPath, JSON.stringify(output, null, 2), 'utf-8');
  console.log(`提取完成（按 XML 元素名分类）:`);
  for (const [key, arr] of Object.entries(output)) {
    console.log(`  ${key}: ${arr.length} IDs`);
  }
  console.log(`总计 ${totalIds} 个 ID 引用（含跨 catalog 重复），输出到 ${outputPath}`);
}

main();
