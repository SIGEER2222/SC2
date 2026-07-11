import { describe, it, expect } from 'vitest';
import { parseScriptError, correlateScriptErrors, formatCorrelationReport } from '../src/script-error-correlator.js';
import { writeFileSync, mkdirSync, rmSync, join } from 'node:fs';
import { tmpdir } from 'node:os';
import { join as pathJoin } from 'node:path';

describe('ScriptError Correlator', () => {
  it('解析标准 File/Line/Error 格式', () => {
    const content = `File: LibTest.galaxy
Line: 42
Error: Undeclared variable 'missing_var'

File: LibOther.galaxy
Line: 100
Error: Function 'foo' not defined`;
    const entries = parseScriptError(content);
    expect(entries.length).toBe(2);
    expect(entries[0].galaxyFile).toBe('LibTest.galaxy');
    expect(entries[0].galaxyLine).toBe(42);
    expect(entries[0].errorMessage).toBe("Undeclared variable 'missing_var'");
    expect(entries[1].galaxyFile).toBe('LibOther.galaxy');
    expect(entries[1].galaxyLine).toBe(100);
  });

  it('解析紧凑格式 LibX.galaxy:123: message', () => {
    const content = `LibTest.galaxy:42: Undeclared variable 'missing_var'
LibOther.galaxy:100: Function 'foo' not defined`;
    const entries = parseScriptError(content);
    expect(entries.length).toBe(2);
    expect(entries[0].galaxyFile).toBe('LibTest.galaxy');
    expect(entries[0].galaxyLine).toBe(42);
    expect(entries[0].errorMessage).toBe("Undeclared variable 'missing_var'");
  });

  it('解析 Trigger 格式', () => {
    const content = `Trigger: libTest_gf_Init
Some error message`;
    const entries = parseScriptError(content);
    expect(entries.length).toBeGreaterThanOrEqual(1);
    expect(entries[0].triggerName).toBe('libTest_gf_Init');
  });

  it('对不存在的文件返回空结果', () => {
    const result = correlateScriptErrors('nonexistent.txt', ['/tmp']);
    expect(result.totalErrors).toBe(0);
    expect(result.parsed.length).toBe(0);
  });

  it('关联 ScriptError 到静态检查结果', () => {
    const tmpDir = pathJoin(tmpdir(), `galaxy-scripterror-${Date.now()}`);
    mkdirSync(tmpDir, { recursive: true });
    // 创建一个有未声明变量的 galaxy 文件
    const galaxyFile = pathJoin(tmpDir, 'LibTest.galaxy');
    writeFileSync(galaxyFile, `void TestFunc() {
    int x = missing_var + 1;
}
`);

    // 创建 ScriptError.txt
    const scriptErrorPath = pathJoin(tmpDir, 'ScriptError.txt');
    writeFileSync(scriptErrorPath, `File: LibTest.galaxy
Line: 2
Error: Undeclared variable 'missing_var'
`);

    const result = correlateScriptErrors(scriptErrorPath, [tmpDir]);
    expect(result.totalErrors).toBe(1);
    expect(result.galaxyFilesChecked.size).toBe(1);

    rmSync(tmpDir, { recursive: true, force: true });
  });

  it('格式化关联报告', () => {
    const result = {
      totalErrors: 0,
      parsed: [],
      correlated: 0,
      unresolved: 0,
      galaxyFilesChecked: new Set<string>(),
    };
    const report = formatCorrelationReport(result);
    expect(report).toContain('ScriptError 关联报告');
    expect(report).toContain('总错误数: 0');
  });
});
