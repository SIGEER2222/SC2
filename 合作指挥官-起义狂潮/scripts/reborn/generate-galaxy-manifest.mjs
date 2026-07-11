#!/usr/bin/env node
/**
 * GalaxyManifest 生成器
 *
 * 从 LauncherCompatibilityPlan 的 galaxyInjection 字段生成 GalaxyManifest JSON 文件。
 * 用于初次建立 Shared/Galaxy/reborn-compat-galaxy-manifest.json。
 *
 * 用法：
 *   node generate-galaxy-manifest.mjs --plan <plan.json> --output <manifest.json>
 *   node generate-galaxy-manifest.mjs --plan <plan.json>  (输出到 stdout)
 *
 * 属于 checked-in 生成器，运行产出文件符合 file-ops skill 规则。
 */

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { generateFromPlan, validateManifest } from '../sc2-composer/src/galaxyManifest.mjs';

function parseArgs(argv) {
  const opts = { plan: null, output: null, manifestId: 'reborn.compat', mapFamily: 'reborn' };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--plan') opts.plan = argv[++i];
    else if (a === '--output') opts.output = argv[++i];
    else if (a === '--manifest-id') opts.manifestId = argv[++i];
    else if (a === '--map-family') opts.mapFamily = argv[++i];
    else if (a === '--help' || a === '-h') {
      console.log(`Usage: node generate-galaxy-manifest.mjs --plan <plan.json> [--output <manifest.json>] [--manifest-id <id>] [--map-family <family>]
`);
      process.exit(0);
    }
  }
  return opts;
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (!opts.plan) {
    console.error('Error: --plan is required');
    process.exit(2);
  }

  const planPath = resolve(opts.plan);
  if (!existsSync(planPath)) {
    console.error(`Plan file not found: ${planPath}`);
    process.exit(1);
  }

  const plan = JSON.parse(readFileSync(planPath, 'utf8'));
  const manifest = generateFromPlan(plan, {
    manifestId: opts.manifestId,
    mapFamily: opts.mapFamily,
    description: `Reborn map family galaxy injection manifest. Covers ${plan.compositionId || 'unknown'} composition. Replaces directory scan in launcher-plan.ps1.`,
    coveredCompositions: plan.compositionId ? [plan.compositionId] : [],
  });

  // Validate before writing
  const { valid, errors } = validateManifest(manifest);
  if (!valid) {
    console.error('Generated manifest failed validation:');
    for (const e of errors) console.error(`  - ${e}`);
    process.exit(1);
  }

  const json = JSON.stringify(manifest, null, 2) + '\n';

  if (opts.output) {
    const outPath = resolve(opts.output);
    writeFileSync(outPath, json, 'utf8');
    console.log(`Manifest written: ${outPath}`);
    console.log(`  id: ${manifest.id}`);
    console.log(`  entries: ${manifest.entries.length}`);
    const byOwner = {};
    for (const e of manifest.entries) byOwner[e.owner] = (byOwner[e.owner] || 0) + 1;
    console.log(`  by owner: ${JSON.stringify(byOwner)}`);
  } else {
    console.log(json);
  }
}

main();
