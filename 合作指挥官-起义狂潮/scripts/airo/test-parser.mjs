#!/usr/bin/env node
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Parser } from '../../../tools/sc2-galaxy-toolkit/packages/sc2-galaxy-lang/lib/src/index.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

console.log('=== Testing Galaxy Parser ===');

const testFile = path.join(__dirname, '../../Mods/AIRO/AIROAdapter.SC2Mod/Base.SC2Data/LibAIROAdapter.galaxy');
const content = fs.readFileSync(testFile, 'utf8');

console.log(`Testing file: ${testFile}`);
console.log(`File length: ${content.length}`);

const parser = new Parser();
const sourceFile = parser.parseFile('LibAIROAdapter.galaxy', content);

console.log(`\nParse Diagnostics: ${sourceFile.parseDiagnostics.length}`);
for (const diag of sourceFile.parseDiagnostics) {
    console.log(`  - Line ${diag.line}: ${diag.message}`);
}

console.log(`\nNodes: ${sourceFile.statements.length}`);
for (let i = 0; i < Math.min(5, sourceFile.statements.length); i++) {
    const stmt = sourceFile.statements[i];
    console.log(`  - ${stmt.kind}`);
}

console.log('=== Done ===');
