#!/usr/bin/env node
import { Parser, getKindName } from '../../../tools/sc2-galaxy-toolkit/packages/sc2-galaxy-lang/lib/src/index.js';

console.log('=== Minimal error example ===');

const test1 = `include "TriggerLibs/natives"
void test() {
    unit lv_u;
    while (true) {
        lv_u = UnitGroupPickRandomUnit(null, true);
        if (lv_u == null) {
            break;
        }
        string lv_type = UnitGetType(lv_u);
    }
}`;

console.log("\n--- Test 1 ---");
const parser1 = new Parser();
const sf1 = parser1.parseFile('t1.galaxy', test1);
console.log("Diagnostics:");
for (const d of sf1.parseDiagnostics) {
    console.log(`- Line ${d.line}, col ${d.col}: ${d.message}`);
}

const test2 = `include "TriggerLibs/natives"
void test() {
    string lv_type;
    lv_type = UnitGetType(null);
}`;

console.log("\n--- Test 2 ---");
const parser2 = new Parser();
const sf2 = parser2.parseFile('t2.galaxy', test2);
console.log("Diagnostics:");
for (const d of sf2.parseDiagnostics) {
    console.log(`- Line ${d.line}, col ${d.col}: ${d.message}`);
