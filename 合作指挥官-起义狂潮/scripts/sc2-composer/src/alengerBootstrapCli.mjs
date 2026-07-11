#!/usr/bin/env node
/**
 * AlengerBootstrap CLI wrapper
 *
 * 供 PowerShell launcher 调用，生成 LibRebornAdapter_AlengerBootstrap.galaxy 并写入指定路径。
 *
 * 用法:
 *   node alengerBootstrapCli.mjs --commander TerranAlenger3 --output <path> [--alenger-mods <path>]
 */

import { writeFileSync, readFileSync } from 'node:fs';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { generateAlengerBootstrap } from './bootstrapGenerator.mjs';

const args = process.argv.slice(2);
const opts = {};
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--commander' && args[i + 1]) {
    opts.commander = args[++i];
  } else if (args[i] === '--output' && args[i + 1]) {
    opts.output = args[i + 1];
  } else if (args[i] === '--alenger-mods' && args[i + 1]) {
    opts.alengerMods = args[++i];
  }
}

if (!opts.commander || !opts.output) {
  console.error('Usage: node alengerBootstrapCli.mjs --commander <id> --output <path> [--alenger-mods <path>]');
  process.exit(1);
}

const __dirname = dirname(fileURLToPath(import.meta.url));
const defaultAlengerModsPath = join(__dirname, '..', '..', '..', 'Shared', 'Launcher', 'alenger-mods.json');
const alengerModsPath = opts.alengerMods ? resolve(opts.alengerMods) : defaultAlengerModsPath;

const alengerConfig = JSON.parse(readFileSync(alengerModsPath, 'utf8'));
const commanderToAlenger = alengerConfig.commanderToAlenger || {};

const result = generateAlengerBootstrap(opts.commander, commanderToAlenger);

writeFileSync(resolve(opts.output), result.content, 'utf-8');

console.log(`AlengerBootstrap generated: ${opts.output}`);
console.log(`  commander: ${opts.commander}`);
console.log(`  adapterCount: ${result.stats.adapterCount}`);
console.log(`  alengerMods: ${result.stats.alengerMods.join(', ') || '(none)'}`);
