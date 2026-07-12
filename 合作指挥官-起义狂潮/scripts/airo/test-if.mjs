#!/usr/bin/env node
import { Parser, getKindName } from '../../../tools/sc2-galaxy-toolkit/packages/sc2-galaxy-lang/lib/src/index.js';

console.log('=== Testing if conditions ===\n');

const test1 = `include "TriggerLibs/natives"
void test() {
    int x = 0;
    if (x != 0) {
        x = 1;
    }
}`;

const test2 = `include "TriggerLibs/natives"
void test() {
    string s = "";
    if (s != "") {
        s = "test";
    }
}`;

const test3 = `include "TriggerLibs/natives"
void test() {
    string s1 = "";
    string s2 = "";
    if (s1 != "" && s2 != "") {
        s1 = "test";
    }
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

test('Simple if not equal', test1);
test('String not empty', test2);
test('And condition', test3);

console.log('=== Done ===');
