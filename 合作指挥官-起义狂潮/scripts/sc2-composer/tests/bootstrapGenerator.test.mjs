/**
 * bootstrapGenerator.mjs 单元测试
 *
 * 运行：node --test tests/bootstrapGenerator.test.mjs
 */

import { test, describe } from 'node:test';
import { strict as assert } from 'node:assert';
import {
  BOOTSTRAP_PURPOSE,
  classifyEntry,
  filterBootstrapEntries,
  deriveIncludeName,
  generateBootstrapGalaxy,
  generateBootstrapFile,
  generateAlengerBootstrap,
} from '../src/bootstrapGenerator.mjs';
import { mkdtempSync, readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

describe('classifyEntry', () => {
  test('Adapter owner → AdapterBootstrap', () => {
    const entry = { owner: 'CoreRuntime.AdapterBootstrap', compatibilityOnly: true };
    assert.equal(classifyEntry(entry, 'TerranRaynor'), BOOTSTRAP_PURPOSE.ADAPTER_BOOTSTRAP);
  });

  test('Selected commander owner → CommanderRuntime', () => {
    const entry = { owner: 'Commander.TerranRaynor', compatibilityOnly: false };
    assert.equal(classifyEntry(entry, 'TerranRaynor'), BOOTSTRAP_PURPOSE.COMMANDER_RUNTIME);
  });

  test('Unselected commander owner → CompatibilityInclude', () => {
    const entry = { owner: 'Commander.Unselected', compatibilityOnly: true };
    assert.equal(classifyEntry(entry, 'TerranRaynor'), BOOTSTRAP_PURPOSE.COMPATIBILITY_INCLUDE);
  });

  test('Other commander owner → CompatibilityInclude', () => {
    const entry = { owner: 'Commander.Abathur', compatibilityOnly: true };
    assert.equal(classifyEntry(entry, 'TerranRaynor'), BOOTSTRAP_PURPOSE.COMPATIBILITY_INCLUDE);
  });

  test('Platform owner → PlatformKernel', () => {
    const entry = { owner: 'CoreRuntime.Platform', compatibilityOnly: false };
    assert.equal(classifyEntry(entry, 'TerranRaynor'), BOOTSTRAP_PURPOSE.PLATFORM_KERNEL);
  });
});

describe('filterBootstrapEntries', () => {
  test('保留 CommanderRuntime + AdapterBootstrap + PlatformKernel，排除 CompatibilityInclude', () => {
    const galaxyIncludes = [
      { path: 'Base.SC2Data/LibE0EAE146_RaynorRuntime.galaxy', purpose: 'CommanderRuntime' },
      { path: 'Base.SC2Data/LibA1ADAPTER.galaxy', purpose: 'AdapterBootstrap' },
      { path: 'Base.SC2Data/LibKCOR.galaxy', purpose: 'PlatformKernel' },
      { path: 'Base.SC2Data/LibE0EAE146_AbathurRuntime.galaxy', purpose: 'CompatibilityInclude' },
      { path: 'Base.SC2Data/LibE0EAE146_KerriganRuntime.galaxy', purpose: 'CompatibilityInclude' },
    ];
    const { kept, excluded, stats } = filterBootstrapEntries(galaxyIncludes);
    assert.equal(kept.length, 3);
    assert.equal(excluded.length, 2);
    assert.equal(stats.total, 5);
    assert.equal(stats.kept, 3);
    assert.equal(stats.excluded, 2);
    assert.equal(stats.byPurpose.CommanderRuntime, 1);
    assert.equal(stats.byPurpose.AdapterBootstrap, 1);
    assert.equal(stats.byPurpose.PlatformKernel, 1);
    assert.equal(stats.byPurpose.CompatibilityInclude, 2);
  });

  test('空数组返回空结果', () => {
    const { kept, excluded, stats } = filterBootstrapEntries([]);
    assert.equal(kept.length, 0);
    assert.equal(excluded.length, 0);
    assert.equal(stats.total, 0);
  });

  test('未设置 purpose 的 entry 视为 CompatibilityInclude', () => {
    const galaxyIncludes = [
      { path: 'some/path.galaxy' },
      { path: 'other/path.galaxy', purpose: 'CommanderRuntime' },
    ];
    const { kept, excluded } = filterBootstrapEntries(galaxyIncludes);
    assert.equal(kept.length, 1);
    assert.equal(excluded.length, 1);
  });
});

describe('deriveIncludeName', () => {
  test('从路径推导 include 名称', () => {
    assert.equal(
      deriveIncludeName('Base.SC2Data/LibE0EAE146_RaynorRuntime.galaxy'),
      'LibE0EAE146_RaynorRuntime'
    );
  });

  test('从简单文件名推导', () => {
    assert.equal(deriveIncludeName('LibA1ADAPTER.galaxy'), 'LibA1ADAPTER');
  });
});

describe('generateBootstrapGalaxy — Raynor pilot', () => {
  // 模拟 reborn-compat-galaxy-manifest.json 的 58 条 entry
  // 其中 34 条 Commander.Unselected + 23 条 AdapterBootstrap + 1 条 CommanderRuntime
  function buildMockPlan() {
    const galaxyIncludes = [];

    // 1 条选中 commander
    galaxyIncludes.push({
      path: 'Base.SC2Data/LibE0EAE146_RaynorRuntime.galaxy',
      purpose: 'CommanderRuntime',
    });

    // 34 条未选中 commander（简化为 5 个样本）
    for (const cmd of ['Abathur', 'Kerrigan', 'Karax', 'Stukov', 'Dehaka']) {
      galaxyIncludes.push({
        path: `Base.SC2Data/LibE0EAE146_${cmd}Runtime.galaxy`,
        purpose: 'CompatibilityInclude',
      });
    }

    // 23 条 adapter（简化为 11 个 × 2 文件 = 22，加 1 个 catalog = 23）
    for (const n of [1, 2, 3, 6, 7, 8, 9, 10, 11, 12, 13]) {
      galaxyIncludes.push({
        path: `Base.SC2Data/LibA${n}ADAPTER.galaxy`,
        purpose: 'AdapterBootstrap',
      });
      galaxyIncludes.push({
        path: `Base.SC2Data/LibA${n}ADAPTER_h.galaxy`,
        purpose: 'AdapterBootstrap',
      });
    }
    galaxyIncludes.push({
      path: 'Base.SC2Data/LibA3ADAPTER_Catalog.galaxy',
      purpose: 'AdapterBootstrap',
    });

    return {
      planId: 'reborn.zexpedition03_reborn_port__p1-TerranRaynor',
      bootstrap: {
        galaxyIncludes,
        initSequence: [],
        runtimeOverrides: [],
      },
    };
  }

  test('Raynor plan: 29 条 → 24 条 kept（1 runtime + 23 adapter），5 条 excluded', () => {
    const plan = buildMockPlan();
    const { stats, includes } = generateBootstrapGalaxy(plan);
    // 1 CommanderRuntime + 23 AdapterBootstrap = 24 kept
    assert.equal(stats.kept, 24);
    assert.equal(stats.excluded, 5);
    assert.equal(stats.total, 29); // 1 + 5 + 23
  });

  test('生成的 galaxy 内容包含 RaynorRuntime include', () => {
    const plan = buildMockPlan();
    const { content, includes } = generateBootstrapGalaxy(plan);
    assert.ok(content.includes('include "LibE0EAE146_RaynorRuntime"'));
    assert.ok(includes.includes('LibE0EAE146_RaynorRuntime'));
  });

  test('生成的 galaxy 内容不包含 AbathurRuntime', () => {
    const plan = buildMockPlan();
    const { content, includes } = generateBootstrapGalaxy(plan);
    assert.ok(!content.includes('AbathurRuntime'));
    assert.ok(!includes.includes('LibE0EAE146_AbathurRuntime'));
  });

  test('生成的 galaxy 内容包含 adapter includes', () => {
    const plan = buildMockPlan();
    const { content, includes } = generateBootstrapGalaxy(plan);
    assert.ok(content.includes('include "LibA1ADAPTER"'));
    assert.ok(content.includes('include "LibA13ADAPTER"'));
  });

  test('生成的 galaxy 内容包含自动生成注释', () => {
    const plan = buildMockPlan();
    const { content } = generateBootstrapGalaxy(plan, {
      compositionLabel: 'reborn.zexpedition03_reborn_port × TerranRaynor',
    });
    assert.ok(content.includes('Auto-generated by sc2-composer bootstrapGenerator'));
    assert.ok(content.includes('Composition: reborn.zexpedition03_reborn_port × TerranRaynor'));
    assert.ok(content.includes('Injection:'));
  });

  test('生成的 galaxy 内容包含 InitLib 函数', () => {
    const plan = buildMockPlan();
    const { content } = generateBootstrapGalaxy(plan);
    assert.ok(content.includes('libE0EAE146_CompositionBootstrap_InitLib_completed = false;'));
    assert.ok(content.includes('void libE0EAE146_CompositionBootstrap_InitLib ()'));
    assert.ok(content.includes('libE0EAE146_CompositionBootstrap_InitLib_completed = true;'));
  });

  test('initSequence 非空时生成调用代码', () => {
    const plan = buildMockPlan();
    plan.bootstrap.initSequence = [
      { phase: 'CompositionRegistered', function: 'libE0EAE146_AdapterBootstrap_InitLib' },
    ];
    const { content } = generateBootstrapGalaxy(plan);
    assert.ok(content.includes('libE0EAE146_AdapterBootstrap_InitLib()'));
    assert.ok(content.includes('phase: CompositionRegistered'));
  });
});

describe('generateBootstrapFile', () => {
  test('写入文件并返回内容', () => {
    const tmpDir = mkdtempSync(join(tmpdir(), 'bootstrap-test-'));
    const outputPath = join(tmpDir, 'LibE0EAE146_CompositionBootstrap.galaxy');

    const plan = {
      planId: 'test-composition',
      bootstrap: {
        galaxyIncludes: [
          { path: 'Base.SC2Data/LibE0EAE146_RaynorRuntime.galaxy', purpose: 'CommanderRuntime' },
          { path: 'Base.SC2Data/LibA1ADAPTER.galaxy', purpose: 'AdapterBootstrap' },
          { path: 'Base.SC2Data/LibE0EAE146_AbathurRuntime.galaxy', purpose: 'CompatibilityInclude' },
        ],
        initSequence: [],
        runtimeOverrides: [],
      },
    };

    const result = generateBootstrapFile(plan, outputPath);
    assert.ok(existsSync(outputPath));
    const written = readFileSync(outputPath, 'utf-8');
    assert.ok(written.includes('include "LibE0EAE146_RaynorRuntime"'));
    assert.ok(written.includes('include "LibA1ADAPTER"'));
    assert.ok(!written.includes('AbathurRuntime'));
    assert.equal(result.outputPath, outputPath);
    assert.equal(result.stats.kept, 2);
    assert.equal(result.stats.excluded, 1);
  });
});

describe('generateAlengerBootstrap — on-demand Alenger adapter loading', () => {
  const alengerMapping = {
    Alenger1:  ['AlengerCommon', 'Alenger1', 'Alenger1Adapter'],
    Alenger3:  ['AlengerCommon', 'Alenger3', 'Alenger3Adapter'],
    Alenger8:  ['AlengerCommon', 'Alenger8', 'Alenger8Runtime', 'Alenger8Adapter'],
  };

  test('Raynor (非 Alenger) → 空壳 bootstrap，无 Alenger include', () => {
    const { content, includes, stats } = generateAlengerBootstrap('TerranRaynor', alengerMapping);
    assert.ok(!content.includes('include "LibA'));
    assert.ok(content.includes('void libRebornAdapter_AlengerBootstrap_InitLib ()'));
    assert.ok(content.includes('libRebornAdapter_AlengerBootstrap_InitLib_completed = true;'));
    assert.equal(includes.length, 0);
    assert.equal(stats.adapterCount, 0);
  });

  test('Alenger3 → 只 include LibA3ADAPTER', () => {
    const { content, includes, stats } = generateAlengerBootstrap('TerranAlenger3', alengerMapping);
    assert.ok(content.includes('include "LibA3ADAPTER_h"'));
    assert.ok(content.includes('include "LibA3ADAPTER"'));
    assert.ok(content.includes('libA3ADAPTER_InitLib();'));
    assert.ok(!content.includes('LibA1ADAPTER'));
    assert.ok(!content.includes('LibA8ADAPTER'));
    assert.equal(includes.length, 2);
    assert.equal(stats.adapterCount, 1);
    assert.deepEqual(stats.alengerMods, ['AlengerCommon', 'Alenger3', 'Alenger3Adapter']);
  });

  test('Alenger8 → 只 include LibA8ADAPTER', () => {
    const { content, includes, stats } = generateAlengerBootstrap('TerranAlenger8', alengerMapping);
    assert.ok(content.includes('include "LibA8ADAPTER_h"'));
    assert.ok(content.includes('include "LibA8ADAPTER"'));
    assert.ok(content.includes('libA8ADAPTER_InitLib();'));
    assert.equal(stats.adapterCount, 1);
    assert.deepEqual(stats.alengerMods, ['AlengerCommon', 'Alenger8', 'Alenger8Runtime', 'Alenger8Adapter']);
  });

  test('Alenger3 without race prefix → 正常匹配', () => {
    const { content, stats } = generateAlengerBootstrap('Alenger3', alengerMapping);
    assert.ok(content.includes('include "LibA3ADAPTER"'));
    assert.equal(stats.adapterCount, 1);
  });

  test('未知 commander → 空壳 bootstrap', () => {
    const { content, stats } = generateAlengerBootstrap('UnknownCommander', alengerMapping);
    assert.ok(!content.includes('include "LibA'));
    assert.equal(stats.adapterCount, 0);
  });

  test('空 mapping → 空壳 bootstrap', () => {
    const { content, stats } = generateAlengerBootstrap('TerranAlenger3', {});
    assert.ok(!content.includes('include "LibA'));
    assert.equal(stats.adapterCount, 0);
  });

  test('生成内容包含自动生成注释', () => {
    const { content } = generateAlengerBootstrap('TerranAlenger3', alengerMapping);
    assert.ok(content.includes('Auto-generated by sc2-composer bootstrapGenerator'));
    assert.ok(content.includes('AlengerBootstrap'));
  });
});
