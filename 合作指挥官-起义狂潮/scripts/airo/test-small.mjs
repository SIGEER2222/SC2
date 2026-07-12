#!/usr/bin/env node
import { Parser, getKindName } from '../../../tools/sc2-galaxy-toolkit/packages/sc2-galaxy-lang/lib/src/index.js';

console.log('=== Testing small parts ===\n');

// 测试包含语句
const testIncludes = `include "TriggerLibs/natives"
include "LibNtve"
include "LibE0EAE146"
include "LibAIROAdapter_h"
`;

// 测试变量声明
const testVar = `include "TriggerLibs/natives"
bool libAIROAdapter_initialized = false;
`;

// 测试一个空函数
const testEmptyFunc = `include "TriggerLibs/natives"
void libAIROAdapter_InitLib() {
}
`;

// 测试我们的第一个真实函数
const testFirstFunc = `include "TriggerLibs/natives"
void libAIROAdapter_InitLib() {
    libAIROAdapter_initialized = false;
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

test('Includes', testIncludes);
test('Var declaration', testVar);
test('Empty function', testEmptyFunc);
test('First func', testFirstFunc);

console.log('=== Done ===');
