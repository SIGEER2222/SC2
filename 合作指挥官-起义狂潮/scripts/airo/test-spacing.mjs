#!/usr/bin/env node
import { Parser, getKindName } from '../../../tools/sc2-galaxy-toolkit/packages/sc2-galaxy-lang/lib/src/index.js';

console.log('=== Testing function spacing ===\n');

const test1 = `include "TriggerLibs/natives"
void func() {
    int x = 0;
}`;

const test2 = `include "TriggerLibs/natives"
void func () {
    int x = 0;
}`;

function test(name, code) {
    console.log(`=== Test: ${name} ===`);
    const parser = new Parser();
    const sourceFile = parser.parseFile(name, code);
    console.log(`Diagnostics: ${sourceFile.parseDiagnostics.length}`);
    for (const diag of sourceFile.parseDiagnostics) {
        console.log(`  - Line ${diag.line}: ${diag.message}`);
    }
    console.log();
}

test('No space', test1);
test('With space', test2);

console.log('=== Done ===');
