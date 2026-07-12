#!/usr/bin/env node
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Parser, getKindName } from '../../../tools/sc2-galaxy-toolkit/packages/sc2-galaxy-lang/lib/src/index.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

console.log('=== Testing Galaxy Parser with known good file ===');

const testFile = path.join(__dirname, '../../Mods/7vs1/CoreRuntime.SC2Mod/Base.SC2Data/LibE0EAE146.galaxy');
const content = fs.readFileSync(testFile, 'utf8');

console.log(`Testing file: ${testFile}`);

const parser = new Parser();
const sourceFile = parser.parseFile('LibE0EAE146.galaxy', content);

console.log(`\nParse Diagnostics: ${sourceFile.parseDiagnostics.length}`);
for (const diag of sourceFile.parseDiagnostics.slice(0, 10)) {
    console.log(`  - Line ${diag.line}: ${diag.message}`);
}

console.log(`\nNodes: ${sourceFile.statements.length}`);
for (let i = 0; i < Math.min(10, sourceFile.statements.length); i++) {
    const stmt = sourceFile.statements[i];
    console.log(`  - ${getKindName(stmt.kind)}`);
}

console.log('\n=== Done ===');
