#!/usr/bin/env node
import { Parser, getKindName } from '../../../tools/sc2-galaxy-toolkit/packages/sc2-galaxy-lang/lib/src/index.js';

console.log('=== Testing our code step by step ===\n');

const ourCode = `include "TriggerLibs/natives"
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
}

bool libAIROAdapter_gt_UnitCreated_Func(bool testConds, bool runActions) {
    if (testConds) {
        return true;
    }
    
    if (runActions) {
        unit lv_createdUnit = EventUnitCreatedUnit();
        int lv_player = UnitGetOwner(lv_createdUnit);
        
        if (lv_player != 1) {
            return true;
        }
        
        string lv_type = UnitGetType(lv_createdUnit);
        string lv_replacement = libAIROAdapterInterface_GetReplacementUnit(lv_type);
        
        if (lv_replacement == "" || lv_replacement == lv_type) {
            libAIROAdapterInterface_OnUnitCreated(lv_createdUnit);
            return true;
        }
        
        if (CatalogEntryIsValid(c_gameCatalogUnit, lv_replacement) == false) {
            libAIROAdapterInterface_OnUnitCreated(lv_createdUnit);
            return true;
        }
        
        point lv_pos = UnitGetPosition(lv_createdUnit);
        fixed lv_facing = UnitGetFacing(lv_createdUnit);
        
        libNtve_gf_CreateUnitsWithDefaultFacing(1, lv_replacement, c_unitIgnore, lv_player, lv_pos);
        unit lv_newUnit = UnitLastCreated();
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
}
`;

const lines = ourCode.split('\n');

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
