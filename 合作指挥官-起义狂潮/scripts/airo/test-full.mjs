#!/usr/bin/env node
import { Parser, getKindName } from '../../../tools/sc2-galaxy-toolkit/packages/sc2-galaxy-lang/lib/src/index.js';

console.log('=== Testing full file ===\n');

const fullCode = `include "TriggerLibs/NativeLib"
include "LibNtve"
include "LibAIROAdapter_h"

void libAIROAdapter_InitLib() {
    libAIROAdapter_initialized = false;
}

void libAIROAdapter_gf_CleanupStartLocationUnits() {
    point lv_start;
    region lv_startRegion;
    unitgroup lv_units;
    unit lv_u;
    string lv_type;
    string lv_replacement;
    
    lv_start = PlayerStartLocation(1);
    lv_startRegion = RegionCircle(lv_start, 25.0);
    lv_units = UnitGroup(null, 1, lv_startRegion, UnitFilter(0, 0, (1 << 0), (1 << 1)), 0);
    
    lv_u = UnitGroupUnit(lv_units, 1);
    while (lv_u != null) {
        lv_type = UnitGetType(lv_u);
        lv_replacement = libAIROAdapterInterface_GetReplacementUnit(lv_type);
        
        if (lv_replacement != "" && lv_replacement != lv_type) {
            UnitRemove(lv_u);
        }
        
        UnitGroupRemove(lv_units, lv_u);
        lv_u = UnitGroupUnit(lv_units, 1);
    }
}

bool libAIROAdapter_gt_UnitCreated_Func(bool testConds, bool runActions) {
    unit lv_createdUnit;
    int lv_player;
    string lv_type;
    string lv_replacement;
    point lv_pos;
    fixed lv_facing;
    unit lv_newUnit;
    
    if (testConds) {
        return true;
    }
    
    if (runActions) {
        lv_createdUnit = EventUnitCreatedUnit();
        lv_player = UnitGetOwner(lv_createdUnit);
        
        if (lv_player != 1) {
            return true;
        }
        
        lv_type = UnitGetType(lv_createdUnit);
        lv_replacement = libAIROAdapterInterface_GetReplacementUnit(lv_type);
        
        if (lv_replacement == "" || lv_replacement == lv_type) {
            libAIROAdapterInterface_OnUnitCreated(lv_createdUnit);
            return true;
        }
        
        if (CatalogEntryIsValid(c_gameCatalogUnit, lv_replacement) == false) {
            libAIROAdapterInterface_OnUnitCreated(lv_createdUnit);
            return true;
        }
        
        lv_pos = UnitGetPosition(lv_createdUnit);
        lv_facing = UnitGetFacing(lv_createdUnit);
        
        libNtve_gf_CreateUnitsWithDefaultFacing(1, lv_replacement, c_unitIgnore, lv_player, lv_pos);
        lv_newUnit = UnitLastCreated();
        UnitSetFacing(lv_newUnit, lv_facing, 0.0);
        
        UnitRemove(lv_createdUnit);
        
        libAIROAdapterInterface_OnUnitCreated(lv_newUnit);
    }
    
    return true;
}

void libAIROAdapter_gf_InitUnitReplacement() {
    if (libAIROAdapter_initialized) {
        return;
    }
    
    libAIROAdapter_gf_CleanupStartLocationUnits();
    libAIROAdapterInterface_OnGameStart();
    
    libAIROAdapter_gt_UnitCreated = TriggerCreate("libAIROAdapter_gt_UnitCreated_Func");
    TriggerAddEventUnitCreated(libAIROAdapter_gt_UnitCreated, 1, null, null);
    
    libAIROAdapter_initialized = true;
}`;

const parser = new Parser();
const sourceFile = parser.parseFile('LibAIROAdapter.galaxy', fullCode);

console.log(`=== Diagnostics (${sourceFile.parseDiagnostics.length}) ===`);
for (const diag of sourceFile.parseDiagnostics) {
    console.log(`- Line ${diag.line}: ${diag.message}`);
}

console.log('\n=== Statements ===');
for (let i = 0; i < Math.min(10, sourceFile.statements.length); i++) {
    console.log(`${i+1}: ${getKindName(sourceFile.statements[i].kind)}`);
}

console.log('\n=== Done ===');
