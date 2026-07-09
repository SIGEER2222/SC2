import { describe, it, expect } from 'vitest';
import { existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { check } from '../src/index.js';

// tests/ -> galaxy-checker/ -> scripts/ -> 合作指挥官-起义狂潮/
const MOD_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const COOP_MOD = join(MOD_ROOT, 'Mods', '7vs1', 'CoopZeroPop.SC2Mod', 'Base.SC2Data');

describe.skipIf(!existsSync(COOP_MOD))('与现有 .py 工具兼容性（真实项目目录）', () => {
  it('至少能扫描 CoopZeroPop 目录而不崩溃', () => {
    const result = check(COOP_MOD);
    expect(result.filesChecked).toBeGreaterThan(0);
    // 不强制要求零误报，但要求能跑完并产出结构化结果
    expect(Array.isArray(result.issues)).toBe(true);
    expect(result.summary.errors).toBeGreaterThanOrEqual(0);
  }, 60000);

  it('BOM issue（若有）格式正确', () => {
    // 项目历史曾因 BOM 出错，这里验证报告格式
    const result = check(COOP_MOD);
    for (const i of result.issues) {
      if (i.ruleCode === 'PROJ_UTF8_BOM') {
        expect(i.line).toBe(1);
        expect(i.column).toBe(1);
      }
    }
  }, 60000);
});
