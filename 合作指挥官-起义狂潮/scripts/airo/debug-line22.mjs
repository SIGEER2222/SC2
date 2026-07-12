#!/usr/bin/env node
import { Parser, getKindName } from '../../../tools/sc2-galaxy-toolkit/packages/sc2-galaxy-lang/lib/src/index.js';

console.log('=== Debugging line 22 ===');

const testCode = `include "TriggerLibs/natives"
include "LibNtve"
include "LibE0EAE146"
include "LibAIROAdapter_h"

void libAIROAdapter_InitLib() {
    libAIROAdapter_initialized = false;
}

void libAIROAdapter_gf_CleanupStartLocationUnits() {
    point lv_start = PlayerStartLocation(1);
    region lv_startRegion = RegionCircle(lv_start, 25.0);
    unitgroup lv_units = UnitGroup(null, 1, lv_startRegion, UnitFilter(0, 0, (1 << 0), (1 << 1)), 0);
    unit lv_u;
    
    while (true) {
        lv_u = UnitGroupPickRandomUnit(lv_units, true);
        if (lv_u == null) {
            break;
        }
        
        string lv_type = UnitGetType(lv_u);
        string lv_replacement = libAIROAdapterInterface_GetReplacementUnit(lv_type);
        
        if (lv_replacement != "" && lv_replacement != lv_type) {
            UnitRemove(lv_u);
        }
    }
}`;

const parser = new Parser();
const sourceFile = parser.parseFile('test.galaxy', testCode);

console.log(`Total diagnostics: ${sourceFile.parseDiagnostics.length}`);
for (const diag of sourceFile.parseDiagnostics) {
    console.log(`- Line ${diag.line} (char ${diag.col}): ${diag.message}`);
}

console.log('\nTokenizing line 22...');
const lines = testCode.split('\n');
const line22 = lines[21];
console.log(`Line 22 text: "${line22}"`);

console.log('\n=== done ===');
