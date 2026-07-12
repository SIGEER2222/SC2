#!/usr/bin/env node
import * as fs from 'node:fs';
import * as path from 'node:path';
import { Parser, getKindName } from '../../../tools/sc2-galaxy-toolkit/packages/sc2-galaxy-lang/lib/src/index.js';

console.log('=== Testing our code step by step ===\n');

const testFile = path.join('E:', 'Code', 'MyMod', 'SC2', '合作指挥官-起义狂潮', 'Mods', 'AIRO', 'AIROAdapter.SC2Mod', 'Base.SC2Data', 'LibAIROAdapter.galaxy');
const content = fs.readFileSync(testFile, 'utf8');

const lines = content.split('\n');

// 测试不同部分
for (let i = 1; i <= lines.length; i++) {
    const code = lines.slice(0, i).join('\n');
    const parser = new Parser();
    const sourceFile = parser.parseFile(`Test_${i}.galaxy`, code);
    
    if (sourceFile.parseDiagnostics.length > 0) {
        console.log(`First error at line ${i}:`);
        console.log(`Code up to line ${i}:`);
        console.log(code);
        console.log(`\nDiagnostics:`);
        for (const diag of sourceFile.parseDiagnostics) {
            console.log(`  - Line ${diag.line}: ${diag.message}`);
        }
        break;
    }
}

console.log('\n=== Done ===');
