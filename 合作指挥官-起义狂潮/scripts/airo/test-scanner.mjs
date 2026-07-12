#!/usr/bin/env node
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import { GalaxyRuntimeScanner } from '../../../tools/sc2-galaxy-toolkit/packages/sc2-unit-explorer/lib/src/index.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.join(__dirname, '..', '..');
const AIRO_DIR = path.join(PROJECT_ROOT, 'Mods', 'AIRO');

console.log('=== AIRO 适配器语法检查 ===\n');

const scanner = new GalaxyRuntimeScanner();
const filesToCheck = [];

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

collectGalaxyFiles(AIRO_DIR);

console.log(`找到 ${filesToCheck.length} 个 .galaxy 文件\n`);

let totalErrors = 0;
const errorFiles = [];

for (const file of filesToCheck) {
    const relativePath = path.relative(PROJECT_ROOT, file);
    
    // 只检查我们创建的 AIRO 适配器文件
    if (!relativePath.includes('AIROAdapter') && !relativePath.includes('Adapters')) {
        continue;
    }
    
    console.log(`检查: ${relativePath}`);
    
    try {
        const content = fs.readFileSync(file, 'utf-8');
        scanner.data.parseErrors = 0;
        scanner.scanFile(relativePath, content);
        
        if (scanner.data.parseErrors > 0) {
            console.log(`  ? 解析错误: ${scanner.data.parseErrors} 个`);
            totalErrors += scanner.data.parseErrors;
            
            errorFiles.push({ 
                path: relativePath, 
                errors: scanner.data.parseErrors 
            });
        } else {
            console.log('  ? 无语法错误');
        }
    } catch (e) {
        console.log(`  ? 读取错误: ${e.message}`);
        totalErrors++;
        errorFiles.push({ path: relativePath, errors: 1 });
    }
}

console.log('\n--- 检查结果 ---');
if (totalErrors === 0) {
    console.log('? 所有文件语法检查通过！');
} else {
    console.log(`? 共发现 ${totalErrors} 个语法错误，在 ${errorFiles.length} 个文件中：`);
    for (const ef of errorFiles) {
        console.log(`  - ${ef.path}: ${ef.errors} 个错误`);
    }
    process.exit(1);
}
