#!/usr/bin/env node
/**
 * AIRO ??????????º×??
 * ??? sc2-galaxy-toolkit ????????????? AIRO Adapter ?????
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Parser } from '../../../tools/sc2-galaxy-toolkit/packages/sc2-galaxy-lang/lib/src/index.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.join(__dirname, '..', '..');
const AIRO_DIR = path.join(PROJECT_ROOT, 'Mods', 'AIRO');

console.log('=== AIRO ??????????? ===\n');

const parser = new Parser();
const filesToCheck = [];

// ??????? .galaxy ???
function collectGalaxyFiles(dir) {
    if (!fs.existsSync(dir)) return;
    
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            collectGalaxyFiles(fullPath);
        } else if (entry.name.endsWith('.galaxy')) {
            filesToCheck.push(fullPath);
        }
    }
}

// ??? AIRO Adapter
collectGalaxyFiles(AIRO_DIR);

console.log(`??? ${filesToCheck.length} ?? .galaxy ???\n`);

let totalErrors = 0;
const errorFiles = [];

for (const file of filesToCheck) {
    const relativePath = path.relative(PROJECT_ROOT, file);
    
    // ??????????????????????????
    if (!relativePath.includes('AIROAdapter') && !relativePath.includes('Adapters')) {
        continue;
    }
    
    console.log(`???: ${relativePath}`);
    
    try {
        const content = fs.readFileSync(file, 'utf-8');
        const sourceFile = parser.parseFile(relativePath, content);
        
        if (sourceFile.parseDiagnostics.length > 0) {
            console.log(`  ? ????????: ${sourceFile.parseDiagnostics.length} ??`);
            totalErrors += sourceFile.parseDiagnostics.length;
            
            for (const diag of sourceFile.parseDiagnostics) {
                console.log(`    - Line ${diag.start.line + 1}: ${diag.message}`);
            }
            
            errorFiles.push({ 
                path: relativePath, 
                errors: sourceFile.parseDiagnostics.length 
            });
        } else {
            console.log('  ? ????????');
        }
    } catch (e) {
        console.log(`  ? ???????: ${e.message}`);
        totalErrors++;
        errorFiles.push({ path: relativePath, errors: 1 });
    }
}

console.log('\n--- ????? ---');
if (totalErrors === 0) {
    console.log('? ?????????????????');
} else {
    console.log(`? ?????? ${totalErrors} ?????????? ${errorFiles.length} ??????§µ?`);
    for (const ef of errorFiles) {
        console.log(`  - ${ef.path}: ${ef.errors} ??????`);
    }
    process.exit(1);
}
