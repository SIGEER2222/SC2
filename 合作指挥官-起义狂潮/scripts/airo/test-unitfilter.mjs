#!/usr/bin/env node
import { Parser, getKindName } from '../../../tools/sc2-galaxy-toolkit/packages/sc2-galaxy-lang/lib/src/index.js';

console.log('=== Testing UnitFilter ===\n');

const test1 = `include "TriggerLibs/natives"
void test() {
    unitgroup lv_units = UnitGroup(null, 1, null, UnitFilter(0, 0, 0, 0), 0);
}`;

const test2 = `include "TriggerLibs/natives"
void test() {
    unitgroup lv_units = UnitGroup(null, 1, null, UnitFilter(0, 0, (1 << 0), (1 << 1)), 0);
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

test('Simple filter', test1);
test('With bit shifts', test2);

console.log('=== Done ===');
