#!/usr/bin/env node
import { Parser, getKindName } from '../../../tools/sc2-galaxy-toolkit/packages/sc2-galaxy-lang/lib/src/index.js';

console.log('=== Testing minimal examples ===\n');

const test1 = `include "TriggerLibs/natives"
int testVar = 0;
`;

const test2 = `include "TriggerLibs/natives"

void testFunc() {
    int x = 0;
}
`;

const test3 = `include "TriggerLibs/natives"

string testFunc(string input) {
    return input;
}
`;

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

test('Test1', test1);
test('Test2', test2);
test('Test3', test3);

console.log('=== Done ===');
