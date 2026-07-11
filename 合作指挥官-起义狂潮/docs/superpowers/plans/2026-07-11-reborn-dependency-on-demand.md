# Reborn 依赖按需加载 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 从 CoreRuntime 移除 AdapterBootstrap 硬编码的 11 个 Alenger adapter include，将 Alenger 初始化迁移到 RebornMapAdapter，通过 generated `LibRebornAdapter_AlengerBootstrap.galaxy` 实现按选中指挥官动态加载，将 Reborn 地图依赖数从 37 降到 ~11-14。

**Architecture:** CoreRuntime 回归纯净（只依赖 VoidMulti+StarCoop）。Alenger 初始化逻辑移到 RebornMapAdapter.SC2Mod，由 generated galaxy 文件按需 include 选中的 Alenger adapter。launcher 根据 commanderToAlenger 映射只同步选中的 Alenger mod，campaign 依赖按地图选择。

**Tech Stack:** Galaxy script, PowerShell 5.1, Node.js 18+ (ESM), JSON config

---

## File Structure

### 创建文件
| 文件 | 职责 |
|------|------|
| `Mods/Reborn/RebornMapAdapter.SC2Mod/Base.SC2Data/LibRebornAdapter_AlengerBootstrap_h.galaxy` | 静态头文件，声明 `libRebornAdapter_AlengerBootstrap_InitLib()` |
| `scripts/sc2-composer/src/alengerBootstrapCli.mjs` | CLI wrapper，供 PowerShell launcher 调用生成 AlengerBootstrap galaxy |

### 修改文件
| 文件 | 改动 |
|------|------|
| `Shared/Launcher/alenger-mods.json` | 添加 `commanderToAlenger` 映射表 |
| `Shared/Launcher/reborn-dependencies.json` | 移除 Campaign 依赖到 `mapCampaigns`，移除 `Alenger*Adapter` 注入模式 |
| `scripts/sc2-composer/src/bootstrapGenerator.mjs` | 新增 `generateAlengerBootstrap()` 函数 |
| `scripts/sc2-composer/tests/bootstrapGenerator.test.mjs` | 新增 AlengerBootstrap 测试用例 |
| `scripts/sc2-launcher/launcher-plan.ps1` | L2 层改为按需 Alenger，documentRewrite 添加 Alenger+Campaign |
| `scripts/reborn/launch-reborn-commander.ps1` | 调用 Node.js 生成 AlengerBootstrap，同步选中 Alenger mod |
| `Mods/Reborn/RebornMapAdapter.SC2Mod/Base.SC2Data/RebornMapAdapter_h.galaxy` | 添加 AlengerBootstrap_InitLib 声明 |
| `Mods/Reborn/RebornMapAdapter.SC2Mod/Base.SC2Data/RebornMapAdapter.galaxy` | 添加 include + OnAfterUnitsInit 调用 |
| `Mods/7vs1/CoreRuntime.SC2Mod/Base.SC2Data/LibE0EAE146.galaxy` | 移除 AdapterBootstrap include + InitLib 调用 |

### 删除文件
| 文件 | 原因 |
|------|------|
| `Mods/7vs1/CoreRuntime.SC2Mod/Base.SC2Data/LibE0EAE146_AdapterBootstrap.galaxy` | 硬编码全量 include，迁移到 RebornMapAdapter |
| `Mods/7vs1/CoreRuntime.SC2Mod/Base.SC2Data/LibE0EAE146_AdapterBootstrap_h.galaxy` | 对应头文件，一并删除 |

---

## Task 1: 添加 commanderToAlenger 映射到 alenger-mods.json

**Files:**
- Modify: `Shared/Launcher/alenger-mods.json`

- [ ] **Step 1: 在 alenger-mods.json 中添加 commanderToAlenger 映射**

在 `dependencyPaths` 数组之后添加 `commanderToAlenger` 字段。映射的 key 使用 `Alenger*` 格式（与 `runtime_name` 一致），launcher 会做前缀归一化。

```json
{
  "$schema": "alenger-mods.schema.json",
  "description": "Alenger mod set. commanderToAlenger maps commander runtime_name to required Alenger mods. mods/dependencyPaths retained as full reference.",
  "mods": [
    "7vs1\\AlengerCommon.SC2Mod",
    "7vs1\\Alenger3.SC2Mod",
    "7vs1\\Alenger3Adapter.SC2Mod",
    "7vs1\\Alenger1.SC2Mod",
    "7vs1\\Alenger1Adapter.SC2Mod",
    "7vs1\\Alenger6.SC2Mod",
    "7vs1\\Alenger6Adapter.SC2Mod",
    "7vs1\\Alenger8.SC2Mod",
    "7vs1\\Alenger8Runtime.SC2Mod",
    "7vs1\\Alenger8Adapter.SC2Mod",
    "7vs1\\Alenger9.SC2Mod",
    "7vs1\\Alenger9Adapter.SC2Mod",
    "7vs1\\Alenger12.SC2Mod",
    "7vs1\\Alenger12Adapter.SC2Mod",
    "7vs1\\Alenger13.SC2Mod",
    "7vs1\\Alenger13Adapter.SC2Mod",
    "7vs1\\Alenger2.SC2Mod",
    "7vs1\\Alenger2Adapter.SC2Mod",
    "7vs1\\Alenger7.SC2Mod",
    "7vs1\\Alenger7Adapter.SC2Mod",
    "7vs1\\Alenger10.SC2Mod",
    "7vs1\\Alenger10Adapter.SC2Mod",
    "7vs1\\Alenger11.SC2Mod",
    "7vs1\\Alenger11Adapter.SC2Mod"
  ],
  "dependencyPaths": [
    "file:Mods/7vs1/AlengerCommon.SC2Mod",
    "file:Mods/7vs1/Alenger3.SC2Mod",
    "file:Mods/7vs1/Alenger3Adapter.SC2Mod",
    "file:Mods/7vs1/Alenger1.SC2Mod",
    "file:Mods/7vs1/Alenger1Adapter.SC2Mod",
    "file:Mods/7vs1/Alenger6.SC2Mod",
    "file:Mods/7vs1/Alenger6Adapter.SC2Mod",
    "file:Mods/7vs1/Alenger8.SC2Mod",
    "file:Mods/7vs1/Alenger8Runtime.SC2Mod",
    "file:Mods/7vs1/Alenger8Adapter.SC2Mod",
    "file:Mods/7vs1/Alenger9.SC2Mod",
    "file:Mods/7vs1/Alenger9Adapter.SC2Mod",
    "file:Mods/7vs1/Alenger12.SC2Mod",
    "file:Mods/7vs1/Alenger12Adapter.SC2Mod",
    "file:Mods/7vs1/Alenger13.SC2Mod",
    "file:Mods/7vs1/Alenger13Adapter.SC2Mod",
    "file:Mods/7vs1/Alenger2.SC2Mod",
    "file:Mods/7vs1/Alenger2Adapter.SC2Mod",
    "file:Mods/7vs1/Alenger7.SC2Mod",
    "file:Mods/7vs1/Alenger7Adapter.SC2Mod",
    "file:Mods/7vs1/Alenger10.SC2Mod",
    "file:Mods/7vs1/Alenger10Adapter.SC2Mod",
    "file:Mods/7vs1/Alenger11.SC2Mod",
    "file:Mods/7vs1/Alenger11Adapter.SC2Mod"
  ],
  "commanderToAlenger": {
    "Alenger1":  ["AlengerCommon", "Alenger1", "Alenger1Adapter"],
    "Alenger2":  ["AlengerCommon", "Alenger2", "Alenger2Adapter"],
    "Alenger3":  ["AlengerCommon", "Alenger3", "Alenger3Adapter"],
    "Alenger6":  ["AlengerCommon", "Alenger6", "Alenger6Adapter"],
    "Alenger7":  ["AlengerCommon", "Alenger7", "Alenger7Adapter"],
    "Alenger8":  ["AlengerCommon", "Alenger8", "Alenger8Runtime", "Alenger8Adapter"],
    "Alenger9":  ["AlengerCommon", "Alenger9", "Alenger9Adapter"],
    "Alenger10": ["AlengerCommon", "Alenger10", "Alenger10Adapter"],
    "Alenger11": ["AlengerCommon", "Alenger11", "Alenger11Adapter"],
    "Alenger12": ["AlengerCommon", "Alenger12", "Alenger12Adapter"],
    "Alenger13": ["AlengerCommon", "Alenger13", "Alenger13Adapter"]
  }
}
```

- [ ] **Step 2: 验证 JSON 合法**

Run: `node -e "JSON.parse(require('fs').readFileSync('e:/Code/MyMod/SC2/合作指挥官-起义狂潮/Shared/Launcher/alenger-mods.json','utf8')); console.log('OK')"`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add "合作指挥官-起义狂潮/Shared/Launcher/alenger-mods.json"
git commit -m "feat: 添加 commanderToAlenger 映射表支持按需加载"
```

---

## Task 2: 重构 reborn-dependencies.json — Campaign 按地图选择 + 移除 Alenger 全量注入

**Files:**
- Modify: `Shared/Launcher/reborn-dependencies.json`

- [ ] **Step 1: 修改 reborn-dependencies.json**

从 `baseDependencyPaths` 移除 3 条 Campaign 依赖，新增 `mapCampaigns` 映射。从 `galaxyInjection.sourcePatterns` 移除 `Alenger*Adapter.SC2Mod`（Alenger adapter 改为通过 mod 依赖链加载）。

```json
{
  "$schema": "map-family-dependencies.schema.json",
  "description": "Reborn map family dependency configuration. Campaign deps are per-map via mapCampaigns. Alenger deps are per-commander via commanderToAlenger.",
  "family": "reborn",
  "baseMods": [
    "crys_the_swarm_reborn.SC2Mod",
    "crys_swarm_assets.SC2Mod",
    "sibirens_starhooks_common.SC2Mod",
    "sibirens_starhooks_swarmstoryutils.SC2Mod",
    "sibirens_sundries_swarm_reborn.SC2Mod",
    "Reborn\\RebornBridge.SC2Mod",
    "Reborn\\RebornMapAdapter.SC2Mod",
    "kit_mutations.SC2Mod",
    "7vs1\\CoreRuntime.SC2Mod",
    "7vs1\\CommanderBridge.SC2Mod",
    "7vs1\\BaseCatalogPatch.SC2Mod",
    "7vs1\\SharedUnits.SC2Mod",
    "7vs1\\ExternalRefs.SC2Mod"
  ],
  "baseDependencyPaths": [
    "file:Mods/crys_the_swarm_reborn.SC2Mod",
    "file:Mods/RebornBridge.SC2Mod",
    "file:Mods/RebornMapAdapter.SC2Mod",
    "file:Mods/kit_mutations.SC2Mod",
    "file:Mods/7vs1/BaseCatalogPatch.SC2Mod",
    "file:Mods/7vs1/CommanderBridge.SC2Mod",
    "file:Mods/7vs1/CoreRuntime.SC2Mod",
    "file:Mods/7vs1/SharedUnits.SC2Mod",
    "file:Mods/7vs1/ExternalRefs.SC2Mod"
  ],
  "mapCampaigns": {
    "zexpedition03_reborn_port": [
      "bnet:自由之翼剧情 (战役)/0.0/999,file:Campaigns/LibertyStory.SC2Campaign",
      "bnet:自由之翼 (Mod)/0.0/999,file:Mods/Liberty.SC2Mod",
      "bnet:Void Story (Campaign)/0.0/999,file:Campaigns/VoidStory.SC2Campaign"
    ],
    "zevolutionbaneling2_reborn_port": [
      "bnet:Void Story (Campaign)/0.0/999,file:Campaigns/VoidStory.SC2Campaign"
    ]
  },
  "galaxyInjection": {
    "description": "Galaxy files injected from workspace to map Base.SC2Data. Alenger*Adapter galaxy files are NOT injected — they resolve via mod dependency chain when the selected Alenger mod is synced.",
    "sourcePatterns": [
      "CommanderUnits_*.SC2Mod"
    ],
    "sourceRoot": "Mods\\7vs1"
  },
  "validCommanders": [
    "TerranRaynor", "TerranNova", "TerranSwann", "TerranHorner", "TerranMengsk", "TerranTychus",
    "ZergKerrigan", "ZergAbathur", "ZergZagara", "ZergStukov", "ZergDehaka", "ZergStetmann",
    "ProtossArtanis", "ProtossVorazun", "ProtossKarax", "ProtossFenix", "ProtossAlarak", "ProtossZeratul",
    "TerranAlenger1", "TerranAlenger2", "TerranAlenger3", "TerranAlenger6", "TerranAlenger7",
    "TerranAlenger8", "TerranAlenger9", "TerranAlenger10", "TerranAlenger11", "TerranAlenger12", "TerranAlenger13"
  ]
}
```

- [ ] **Step 2: 验证 JSON 合法**

Run: `node -e "JSON.parse(require('fs').readFileSync('e:/Code/MyMod/SC2/合作指挥官-起义狂潮/Shared/Launcher/reborn-dependencies.json','utf8')); console.log('OK')"`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add "合作指挥官-起义狂潮/Shared/Launcher/reborn-dependencies.json"
git commit -m "feat: Campaign 按地图选择，移除 Alenger 全量注入模式"
```

---

## Task 3: 在 bootstrapGenerator.mjs 中实现 generateAlengerBootstrap（TDD）

**Files:**
- Test: `scripts/sc2-composer/tests/bootstrapGenerator.test.mjs`
- Modify: `scripts/sc2-composer/src/bootstrapGenerator.mjs`

- [ ] **Step 1: 写失败测试 — Raynor（非 Alenger）生成空壳 bootstrap**

在 `bootstrapGenerator.test.mjs` 末尾新增 describe 块：

```javascript
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
    assert.equal(includes.length, 2); // _h + implementation
    assert.equal(stats.adapterCount, 1);
    assert.deepEqual(stats.alengerMods, ['AlengerCommon', 'Alenger3', 'Alenger3Adapter']);
  });

  test('Alenger8 → 只 include LibA8ADAPTER（Alenger8Runtime 不影响 adapter include）', () => {
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
```

在文件顶部的 import 列表中添加 `generateAlengerBootstrap`：

```javascript
import {
  BOOTSTRAP_PURPOSE,
  classifyEntry,
  filterBootstrapEntries,
  deriveIncludeName,
  generateBootstrapGalaxy,
  generateBootstrapFile,
  generateAlengerBootstrap,
} from '../src/bootstrapGenerator.mjs';
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\sc2-composer" && node --test tests/bootstrapGenerator.test.mjs`
Expected: FAIL — `generateAlengerBootstrap is not defined` 或 import 错误

- [ ] **Step 3: 实现 generateAlengerBootstrap 函数**

在 `bootstrapGenerator.mjs` 末尾（`generateBootstrapFile` 之后）添加：

```javascript
/**
 * 从 commander 名称推导 Alenger 基名。
 * "TerranAlenger3" → "Alenger3", "Alenger3" → "Alenger3"
 *
 * @param {string} commander - commander ID
 * @returns {string} Alenger 基名（如 "Alenger3"），非 Alenger 返回 null
 */
function deriveAlengerBaseName(commander) {
  // 尝试直接匹配
  if (commander.startsWith('Alenger')) {
    return commander;
  }
  // 尝试去种族前缀 (Terran/Zerg/Protoss)
  const racePrefixes = ['Terran', 'Zerg', 'Protoss'];
  for (const prefix of racePrefixes) {
    if (commander.startsWith(prefix)) {
      const rest = commander.slice(prefix.length);
      if (rest.startsWith('Alenger')) {
        return rest;
      }
    }
  }
  return null;
}

/**
 * 从 Alenger mod 名称推导 adapter 的 galaxy include 名称。
 * "Alenger3Adapter" → { header: "LibA3ADAPTER_h", impl: "LibA3ADAPTER", initFn: "libA3ADAPTER_InitLib" }
 *
 * @param {string} modName - Alenger mod 名称（如 "Alenger3Adapter"）
 * @returns {{ header: string, impl: string, initFn: string } | null}
 */
function deriveAdapterIncludes(modName) {
  // 匹配 AlengerNAdapter 格式
  const match = modName.match(/^Alenger(\d+)Adapter$/);
  if (!match) {
    return null;
  }
  const n = match[1];
  const adapterName = `LibA${n}ADAPTER`;
  return {
    header: `${adapterName}_h`,
    impl: adapterName,
    initFn: `libA${n}ADAPTER_InitLib`,
  };
}

/**
 * 生成 RebornMapAdapter 的 AlengerBootstrap galaxy 文件内容。
 *
 * 选中的 commander 在 commanderToAlenger 映射中 → 生成只 include 对应 adapter 的实体
 * commander 不在映射中 → 生成空壳（无 Alenger include）
 *
 * @param {string} commander - 选中 commander ID（如 'TerranRaynor' 或 'TerranAlenger3'）
 * @param {Object<string, string[]>} commanderToAlenger - commander → Alenger mod 列表映射
 * @returns {{ content: string, includes: string[], stats: object }}
 */
export function generateAlengerBootstrap(commander, commanderToAlenger) {
  const alengerBase = deriveAlengerBaseName(commander);
  const alengerMods = (alengerBase && commanderToAlenger[alengerBase]) || [];

  // 从 mod 列表中找到 Adapter mod，推导 include 信息
  const adapters = [];
  for (const modName of alengerMods) {
    const adapterInfo = deriveAdapterIncludes(modName);
    if (adapterInfo) {
      adapters.push(adapterInfo);
    }
  }

  const includes = [];
  for (const adapter of adapters) {
    includes.push(adapter.header);
    includes.push(adapter.impl);
  }

  // 生成 galaxy 内容
  const lines = [];
  lines.push(`// Auto-generated by sc2-composer bootstrapGenerator`);
  lines.push(`// AlengerBootstrap for commander: ${commander}`);
  if (adapters.length > 0) {
    lines.push(`// Alenger mods: ${alengerMods.join(', ')}`);
  } else {
    lines.push(`// No Alenger adapters required (commander not in commanderToAlenger mapping)`);
  }
  lines.push(`// Generated: ${new Date().toISOString()}`);
  lines.push('');

  for (const adapter of adapters) {
    lines.push(`include "${adapter.header}"`);
    lines.push(`include "${adapter.impl}"`);
  }
  if (adapters.length > 0) {
    lines.push('');
  }

  lines.push('//--------------------------------------------------------------------------------------------------');
  lines.push(`// Library: LibRebornAdapter_AlengerBootstrap`);
  lines.push('//--------------------------------------------------------------------------------------------------');
  lines.push(`bool libRebornAdapter_AlengerBootstrap_InitLib_completed = false;`);
  lines.push('');
  lines.push(`void libRebornAdapter_AlengerBootstrap_InitLib () {`);
  lines.push(`    if (libRebornAdapter_AlengerBootstrap_InitLib_completed) {`);
  lines.push(`        return;`);
  lines.push(`    }`);
  lines.push(`    libRebornAdapter_AlengerBootstrap_InitLib_completed = true;`);
  lines.push('');

  if (adapters.length > 0) {
    for (const adapter of adapters) {
      lines.push(`    ${adapter.initFn}();`);
    }
  } else {
    lines.push(`    // No Alenger adapter to initialize`);
  }

  lines.push(`}`);
  lines.push('');

  return {
    content: lines.join('\n'),
    includes,
    stats: {
      adapterCount: adapters.length,
      alengerMods,
    },
  };
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `cd "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\sc2-composer" && node --test tests/bootstrapGenerator.test.mjs`
Expected: PASS — 全部测试通过（原有 + 新增 7 个）

- [ ] **Step 5: Commit**

```bash
git add "合作指挥官-起义狂潮/scripts/sc2-composer/src/bootstrapGenerator.mjs" "合作指挥官-起义狂潮/scripts/sc2-composer/tests/bootstrapGenerator.test.mjs"
git commit -m "feat: generateAlengerBootstrap 按需生成 Alenger adapter bootstrap galaxy"
```

---

## Task 4: 创建 AlengerBootstrap CLI wrapper 供 launcher 调用

**Files:**
- Create: `scripts/sc2-composer/src/alengerBootstrapCli.mjs`

- [ ] **Step 1: 创建 CLI wrapper 脚本**

```javascript
#!/usr/bin/env node
/**
 * AlengerBootstrap CLI wrapper
 *
 * 供 PowerShell launcher 调用，生成 LibRebornAdapter_AlengerBootstrap.galaxy 并写入指定路径。
 *
 * 用法:
 *   node alengerBootstrapCli.mjs --commander TerranAlenger3 --output <path> [--alenger-mods <path>]
 *
 * --commander   选中 commander ID（如 TerranRaynor, TerranAlenger3）
 * --output      输出 galaxy 文件路径
 * --alenger-mods  alenger-mods.json 路径（可选，默认从 Shared/Launcher/alenger-mods.json 读取）
 */

import { writeFileSync, readFileSync } from 'node:fs';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { generateAlengerBootstrap } from './bootstrapGenerator.mjs';

const args = process.argv.slice(2);
const opts = {};
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--commander' && args[i + 1]) {
    opts.commander = args[++i];
  } else if (args[i] === '--output' && args[i + 1]) {
    opts.output = args[++i];
  } else if (args[i] === '--alenger-mods' && args[i + 1]) {
    opts.alengerMods = args[++i];
  }
}

if (!opts.commander || !opts.output) {
  console.error('Usage: node alengerBootstrapCli.mjs --commander <id> --output <path> [--alenger-mods <path>]');
  process.exit(1);
}

// 确定 alenger-mods.json 路径
const __dirname = dirname(fileURLToPath(import.meta.url));
const defaultAlengerModsPath = join(__dirname, '..', '..', '..', 'Shared', 'Launcher', 'alenger-mods.json');
const alengerModsPath = opts.alengerMods ? resolve(opts.alengerMods) : defaultAlengerModsPath;

// 读取 commanderToAlenger 映射
const alengerConfig = JSON.parse(readFileSync(alengerModsPath, 'utf8'));
const commanderToAlenger = alengerConfig.commanderToAlenger || {};

// 生成 bootstrap galaxy
const result = generateAlengerBootstrap(opts.commander, commanderToAlenger);

// 写入文件
writeFileSync(resolve(opts.output), result.content, 'utf-8');

console.log(`AlengerBootstrap generated: ${opts.output}`);
console.log(`  commander: ${opts.commander}`);
console.log(`  adapterCount: ${result.stats.adapterCount}`);
console.log(`  alengerMods: ${result.stats.alengerMods.join(', ') || '(none)'}`);
```

- [ ] **Step 2: 验证 CLI 可运行 — Raynor 空壳**

Run: `cd "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\sc2-composer" && node src/alengerBootstrapCli.mjs --commander TerranRaynor --output "$TEMP/test-raynor-bootstrap.galaxy"`
Expected: 输出 `adapterCount: 0`

- [ ] **Step 3: 验证 CLI 可运行 — Alenger3**

Run: `cd "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\sc2-composer" && node src/alengerBootstrapCli.mjs --commander TerranAlenger3 --output "$TEMP/test-alenger3-bootstrap.galaxy"`
Expected: 输出 `adapterCount: 1`, `alengerMods: AlengerCommon, Alenger3, Alenger3Adapter`

- [ ] **Step 4: Commit**

```bash
git add "合作指挥官-起义狂潮/scripts/sc2-composer/src/alengerBootstrapCli.mjs"
git commit -m "feat: AlengerBootstrap CLI wrapper 供 launcher 调用"
```

---

## Task 5: 创建 RebornMapAdapter AlengerBootstrap 静态头文件 + 修改 RebornMapAdapter galaxy

**Files:**
- Create: `Mods/Reborn/RebornMapAdapter.SC2Mod/Base.SC2Data/LibRebornAdapter_AlengerBootstrap_h.galaxy`
- Modify: `Mods/Reborn/RebornMapAdapter.SC2Mod/Base.SC2Data/RebornMapAdapter_h.galaxy`
- Modify: `Mods/Reborn/RebornMapAdapter.SC2Mod/Base.SC2Data/RebornMapAdapter.galaxy`

- [ ] **Step 1: 创建静态头文件 LibRebornAdapter_AlengerBootstrap_h.galaxy**

```galaxy
//--------------------------------------------------------------------------------------------------
// Library: RebornAdapter AlengerBootstrap Header
// 声明 AlengerBootstrap InitLib，实现由 generated LibRebornAdapter_AlengerBootstrap.galaxy 提供。
// launcher 根据 selected commander 生成对应的 bootstrap galaxy 文件并注入地图 Base.SC2Data。
//--------------------------------------------------------------------------------------------------

void libRebornAdapter_AlengerBootstrap_InitLib ();
```

- [ ] **Step 2: 在 RebornMapAdapter_h.galaxy 中添加声明**

在 `void libRebornAdapter_RegisterPlayer1 ();` 之前添加：

```galaxy
void libRebornAdapter_AlengerBootstrap_InitLib ();
```

- [ ] **Step 3: 修改 RebornMapAdapter.galaxy — 添加 include 和 OnAfterUnitsInit 调用**

在 `include "LibE0EAE146_h"` 之后（第 5 行后）添加：

```galaxy
include "LibRebornAdapter_AlengerBootstrap_h"
```

将 `libRebornAdapter_OnAfterUnitsInit` 函数修改为在 `libE0EAE146_gf_Initialize` 之前调用 AlengerBootstrap 初始化：

```galaxy
void libRebornAdapter_OnAfterUnitsInit () {
    point lv_startPoint;
    string lv_commander;

    lv_startPoint = PlayerStartLocation(1);
    lv_commander = libRebornAdapter_GetCommanderForPlayer(1);

    libRebornAdapter_AlengerBootstrap_InitLib();
    libE0EAE146_gf_Initialize(true);
    libE0EAE146_gf_CommanderRuntimeInit(1, lv_commander, lv_startPoint, true);
}
```

注意：当前文件（工作区已有修改）的 `OnAfterUnitsInit` 可能已有不同内容，需要先读取确认当前状态再编辑。如果当前版本不含 `libE0EAE146_gf_CommanderRuntimeInit` 调用，则只添加 `libRebornAdapter_AlengerBootstrap_InitLib()` 在 `libE0EAE146_gf_Initialize` 之前。

- [ ] **Step 4: Commit**

```bash
git add "合作指挥官-起义狂潮/Mods/Reborn/RebornMapAdapter.SC2Mod/Base.SC2Data/LibRebornAdapter_AlengerBootstrap_h.galaxy" "合作指挥官-起义狂潮/Mods/Reborn/RebornMapAdapter.SC2Mod/Base.SC2Data/RebornMapAdapter_h.galaxy" "合作指挥官-起义狂潮/Mods/Reborn/RebornMapAdapter.SC2Mod/Base.SC2Data/RebornMapAdapter.galaxy"
git commit -m "feat: RebornMapAdapter 承接 Alenger 初始化逻辑"
```

---

## Task 6: 从 CoreRuntime 移除 AdapterBootstrap

**Files:**
- Delete: `Mods/7vs1/CoreRuntime.SC2Mod/Base.SC2Data/LibE0EAE146_AdapterBootstrap.galaxy`
- Delete: `Mods/7vs1/CoreRuntime.SC2Mod/Base.SC2Data/LibE0EAE146_AdapterBootstrap_h.galaxy`
- Modify: `Mods/7vs1/CoreRuntime.SC2Mod/Base.SC2Data/LibE0EAE146.galaxy`

- [ ] **Step 1: 删除 AdapterBootstrap galaxy 文件**

使用 file-ops 包装脚本删除：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "c:\Users\22448\.trae-cn\skills\file-ops\scripts\trae-rm.ps1" "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods\7vs1\CoreRuntime.SC2Mod\Base.SC2Data\LibE0EAE146_AdapterBootstrap.galaxy"
powershell -NoProfile -ExecutionPolicy Bypass -File "c:\Users\22448\.trae-cn\skills\file-ops\scripts\trae-rm.ps1" "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods\7vs1\CoreRuntime.SC2Mod\Base.SC2Data\LibE0EAE146_AdapterBootstrap_h.galaxy"
```

- [ ] **Step 2: 修改 LibE0EAE146.galaxy — 移除 include 和 InitLib 调用**

删除第 54 行：
```galaxy
include "LibE0EAE146_AdapterBootstrap"
```

删除 `libE0EAE146_InitLib` 函数中的 `libE0EAE146_AdapterBootstrap_InitLib();` 调用（当前第 1906 行）。修改后的 InitLib 函数：

```galaxy
void libE0EAE146_InitLib () {
    if (libE0EAE146_InitLib_completed) {
        return;
    }

    libE0EAE146_InitLib_completed = true;

    libE0EAE146_InitLibraries();
    libE0EAE146_InitVariables();
    libE0EAE146_InitTriggers();
}
```

- [ ] **Step 3: Commit**

```bash
git add -A "合作指挥官-起义狂潮/Mods/7vs1/CoreRuntime.SC2Mod/Base.SC2Data/"
git commit -m "refactor: 从 CoreRuntime 移除 AdapterBootstrap，回归纯净依赖"
```

---

## Task 7: 修改 launcher-plan.ps1 — L2 按需 Alenger + Campaign 按地图 + 注入 AlengerBootstrap

**Files:**
- Modify: `scripts/sc2-launcher/launcher-plan.ps1`

- [ ] **Step 1: 添加 commanderToAlenger 归一化辅助函数**

在 `New-LauncherPlan` 函数的 config 加载之后（约第 60 行 `$reborn = $Configs["reborn-dependencies"]` 之后），添加 Alenger 归一化逻辑：

```powershell
    # === Alenger commander 归一化 ===
    # commander ID 格式可能是 "TerranAlenger3" 或 "Alenger3"
    # commanderToAlenger 的 key 使用 "Alenger3" 格式
    $alengerBaseName = $null
    $racePrefixes = @('Terran', 'Zerg', 'Protoss')
    if ($Commander -like 'Alenger*') {
        $alengerBaseName = $Commander
    } else {
        foreach ($prefix in $racePrefixes) {
            if ($Commander -like "$prefix`Alenger*") {
                $alengerBaseName = $Commander.Substring($prefix.Length)
                break
            }
        }
    }

    # 查找选中的 Alenger mod 列表
    $selectedAlengerMods = @()
    if ($alengerBaseName -and $alenger.commanderToAlenger.PSObject.Properties.Name -contains $alengerBaseName) {
        $selectedAlengerMods = @($alenger.commanderToAlenger.$alengerBaseName)
    }
```

- [ ] **Step 2: 修改 L2 层 — 按需 Alenger 依赖**

将 L2 层（当前第 92-95 行 `$l2Entries = @()`）替换为：

```powershell
    # L2: Alenger mods (on-demand, based on selected commander)
    $l2Entries = @()
    foreach ($modName in $selectedAlengerMods) {
        $depPath = "file:Mods/7vs1/$modName.SC2Mod"
        $l2Entries += [PSCustomObject]@{
            path   = $depPath
            source = "Mods\7vs1\$modName.SC2Mod"
            reason = if ($selectedAlengerMods.Count -gt 0) { "Alenger on-demand ($alengerBaseName)" } else { "Alenger (not selected)" }
        }
    }
```

- [ ] **Step 3: 修改 documentRewrite — 添加 Alenger 依赖 + Campaign 按地图**

将 document rewrite 部分（当前第 150-163 行）替换为：

```powershell
    # === Document rewrite (DocumentHeader + DocumentInfo share same dep list) ===
    $runtimeDeps = @() + $reborn.baseDependencyPaths

    # Add on-demand Alenger dependencies
    foreach ($entry in $l2Entries) {
        if ($entry.path) {
            $runtimeDeps += $entry.path
        }
    }

    # Add selected commander package
    if ($selectedCommanderUnitsMod) {
        $runtimeDeps += "file:Mods/7vs1/$selectedCommanderUnitsMod.SC2Mod"
    }

    # Add campaign dependencies (per-map)
    $mapBaseName = [System.IO.Path]::GetFileNameWithoutExtension($MapName)
    if ($reborn.mapCampaigns.PSObject.Properties.Name -contains $mapBaseName) {
        $runtimeDeps += @($reborn.mapCampaigns.$mapBaseName)
    } else {
        Write-Warning "No mapCampaigns entry for map '$mapBaseName', campaign deps will be missing"
    }

    # De-duplicate while preserving order
    $seen = @{}
    $uniqueDeps = @()
    foreach ($d in $runtimeDeps) {
        if (-not $seen.ContainsKey($d)) {
            $seen[$d] = $true
            $uniqueDeps += $d
        }
    }
```

- [ ] **Step 4: 修改 galaxyInjection — 移除 Alenger*Adapter，添加 generated AlengerBootstrap**

在 galaxy injection 部分之后（`$galaxyInjection` 构建完成后），添加 generated AlengerBootstrap 条目：

```powershell
    # === Generated AlengerBootstrap galaxy injection ===
    # The generated LibRebornAdapter_AlengerBootstrap.galaxy is written by the launcher
    # (via alengerBootstrapCli.mjs) to the map Base.SC2Data. It's not in the galaxyInjection
    # list because it doesn't exist in any mod — it's generated per-launch.
    # The launcher writes it directly. We track it here for plan completeness.
    if ($selectedAlengerMods.Count -gt 0) {
        $galaxyInjection += [PSCustomObject]@{
            file                      = "Base.SC2Data/LibRebornAdapter_AlengerBootstrap.galaxy"
            owner                     = "Generated.AlengerBootstrap"
            source                    = "(generated by alengerBootstrapCli.mjs)"
            reason                    = "Generated Alenger bootstrap for $alengerBaseName"
            selectedCommanderRequired = $true
            compatibilityOnly         = $false
        }
    }
```

- [ ] **Step 5: 更新 knownDebt — 标记 alenger-adapter-bootstrap-hardcoded 为已解决**

将 `alenger-adapter-bootstrap-hardcoded` 条目的 removalCondition 更新为：

```powershell
                [PSCustomObject]@{
                    id               = "alenger-adapter-bootstrap-hardcoded"
                    reason           = "RESOLVED: AdapterBootstrap removed from CoreRuntime, Alenger mods now loaded on-demand via commanderToAlenger mapping"
                    removalCondition = "resolved"
                }
```

- [ ] **Step 6: 更新 L2 layer name 描述**

将 dependencyLayers 中的 L2 名称从 `"Alenger adapter bootstrap (CoreRuntime hardcoded)"` 改为：

```powershell
            [PSCustomObject]@{ layer = "L2"; name = "Alenger on-demand (commanderToAlenger)"; entries = $l2Entries },
```

- [ ] **Step 7: 验证 plan 生成 — Raynor（无 Alenger）**

Run:
```powershell
cd "e:\Code\MyMod\SC2\合作指挥官-起义狂潮"
$plan = New-LauncherPlan -Commander "TerranRaynor" -MapName "zexpedition03_reborn_port.SC2Map" -ProjRoot (Get-Location) -Sc2Root "E:\SC2\SC2new\StarCraft II"
$plan.dependencyLayers | Where-Object { $_.layer -eq "L2" } | Select-Object -ExpandProperty entries
$plan.documentRewrite.DocumentHeader.Count
```
Expected: L2 entries 为空，DocumentHeader 依赖数 ≈ 13 (9 base + 1 commander + 3 campaign)

- [ ] **Step 8: 验证 plan 生成 — Alenger3（3 个 Alenger mod）**

Run:
```powershell
$plan2 = New-LauncherPlan -Commander "TerranAlenger3" -MapName "zexpedition03_reborn_port.SC2Map" -ProjRoot (Get-Location) -Sc2Root "E:\SC2\SC2new\StarCraft II"
$plan2.dependencyLayers | Where-Object { $_.layer -eq "L2" } | Select-Object -ExpandProperty entries
$plan2.documentRewrite.DocumentHeader.Count
```
Expected: L2 有 3 个 entries (AlengerCommon + Alenger3 + Alenger3Adapter)，DocumentHeader 依赖数 ≈ 16 (9 base + 3 Alenger + 1 commander + 3 campaign)

- [ ] **Step 9: Commit**

```bash
git add "合作指挥官-起义狂潮/scripts/sc2-launcher/launcher-plan.ps1"
git commit -m "feat: launcher-plan L2 按需 Alenger + Campaign 按地图 + AlengerBootstrap 注入"
```

---

## Task 8: 修改 launch-reborn-commander.ps1 — 生成并注入 AlengerBootstrap + 同步选中 Alenger mod

**Files:**
- Modify: `scripts/reborn/launch-reborn-commander.ps1`

- [ ] **Step 1: 在 MOD SYNC SECTION 添加 Alenger 按需同步**

在 legacy mode 的 `Sync-ModSet` 之后（当前第 224 行后），替换 Alenger disabled 注释，添加按需同步逻辑：

```powershell
    # Sync only selected Alenger mods (on-demand loading)
    if ($selectedAlengerMods.Count -gt 0) {
        Write-Host "ALenger on-demand sync: $($selectedAlengerMods.Count) mods"
        foreach ($modName in $selectedAlengerMods) {
            Sync-ModToLive -ModRelPath "7vs1\$modName.SC2Mod" -ProjRoot $ProjRoot -Sc2Root $Sc2Root
        }
    }
```

需要在此逻辑之前计算 `$selectedAlengerMods`。在 `New-LauncherPlan` 调用之后添加：

```powershell
# === Alenger on-demand resolution ===
$alengerConfig = $alengerConfig  # already loaded
$alengerBaseName = $null
$racePrefixes = @('Terran', 'Zerg', 'Protoss')
if ($Commander -like 'Alenger*') {
    $alengerBaseName = $Commander
} else {
    foreach ($prefix in $racePrefixes) {
        if ($Commander -like "$prefix`Alenger*") {
            $alengerBaseName = $Commander.Substring($prefix.Length)
            break
        }
    }
}
$selectedAlengerMods = @()
if ($alengerBaseName -and $alengerConfig.commanderToAlenger.PSObject.Properties.Name -contains $alengerBaseName) {
    $selectedAlengerMods = @($alengerConfig.commanderToAlenger.$alengerBaseName)
}
```

- [ ] **Step 2: 在 MAP SYNC SECTION 添加 generated AlengerBootstrap 注入**

在 RebornMapAdapter galaxy 文件复制之后（当前第 294 行后），添加 AlengerBootstrap 生成和注入：

```powershell
# === Generate and inject AlengerBootstrap galaxy ===
$alengerBootstrapCli = Join-Path $ScriptsRoot "sc2-composer\src\alengerBootstrapCli.mjs"
$alengerBootstrapOutput = Join-Path $mapLiveBaseData "LibRebornAdapter_AlengerBootstrap.galaxy"
$alengerModsJsonPath = Join-Path $sharedRoot "alenger-mods.json"

Write-Host "Generating AlengerBootstrap for $Commander..."
& node $alengerBootstrapCli --commander $Commander --output $alengerBootstrapOutput --alenger-mods $alengerModsJsonPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: AlengerBootstrap generation failed"
    exit 1
}
Write-Host "AlengerBootstrap injected: $alengerBootstrapOutput"
```

注意：`$sharedRoot` 变量在 launcher-plan.ps1 中定义，但 launch-reborn-commander.ps1 中需要等效路径。使用 `$ScriptsRoot` 推导：

```powershell
$sharedRoot = Join-Path $ProjRoot "Shared\Launcher"
$alengerModsJsonPath = Join-Path $sharedRoot "alenger-mods.json"
```

- [ ] **Step 3: 添加 AlengerBootstrap_h.galaxy 到 RebornMapAdapter 复制列表**

将 `$rebornAdapterGalaxyNames` 数组扩展，包含 AlengerBootstrap 头文件：

```powershell
$rebornAdapterGalaxyNames = @('RebornMapAdapter.galaxy', 'RebornMapAdapter_h.galaxy', 'LibRebornAdapter_AlengerBootstrap_h.galaxy')
```

- [ ] **Step 4: 验证 DryRun 模式可正常运行 — Raynor**

Run:
```powershell
cd "e:\Code\MyMod\SC2\合作指挥官-起义狂潮"
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\reborn\launch-reborn-commander.ps1" -Commander "TerranRaynor" -MapName "zexpedition03_reborn_port.SC2Map" -DryRun
```
Expected: DryRun 完成，输出 PLAN emitted，无错误

- [ ] **Step 5: 验证 DryRun 模式可正常运行 — Alenger3**

Run:
```powershell
cd "e:\Code\MyMod\SC2\合作指挥官-起义狂潮"
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\reborn\launch-reborn-commander.ps1" -Commander "TerranAlenger3" -MapName "zexpedition03_reborn_port.SC2Map" -DryRun
```
Expected: DryRun 完成，输出 PLAN emitted，L2 有 3 个 Alenger mod

- [ ] **Step 6: Commit**

```bash
git add "合作指挥官-起义狂潮/scripts/reborn/launch-reborn-commander.ps1"
git commit -m "feat: launcher 生成 AlengerBootstrap + 按需同步 Alenger mod"
```

---

## Task 9: 单元测试 + launcher plan 稳定性测试

**Files:**
- Test: `scripts/sc2-composer/tests/bootstrapGenerator.test.mjs`
- Test: `scripts/sc2-launcher/launcher-plan.ps1`

- [ ] **Step 1: 运行全部 bootstrapGenerator 测试**

Run: `cd "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\sc2-composer" && npm test`
Expected: 全部通过（原有 + 新增 7 个 = 25 个）

- [ ] **Step 2: 运行 launcher plan 稳定性测试 — Raynor**

Run:
```powershell
cd "e:\Code\MyMod\SC2\合作指挥官-起义狂潮"
. .\scripts\sc2-launcher\launcher-plan.ps1
$result = Test-LauncherPlanStable -PlanInputs @{ Commander="TerranRaynor"; MapName="zexpedition03_reborn_port.SC2Map"; ProjRoot=(Get-Location); Sc2Root="E:\SC2\SC2new\StarCraft II" }
$result.Stable
```
Expected: `True`

- [ ] **Step 3: 运行 launcher plan 稳定性测试 — Alenger3**

Run:
```powershell
$result2 = Test-LauncherPlanStable -PlanInputs @{ Commander="TerranAlenger3"; MapName="zexpedition03_reborn_port.SC2Map"; ProjRoot=(Get-Location); Sc2Root="E:\SC2\SC2new\StarCraft II" }
$result2.Stable
```
Expected: `True`

- [ ] **Step 4: 验证 plan 依赖数符合预期**

Run:
```powershell
$plan = New-LauncherPlan -Commander "TerranRaynor" -MapName "zexpedition03_reborn_port.SC2Map" -ProjRoot (Get-Location) -Sc2Root "E:\SC2\SC2new\StarCraft II"
Write-Host "Raynor deps: $($plan.documentRewrite.DocumentHeader.Count)"
$plan2 = New-LauncherPlan -Commander "TerranAlenger3" -MapName "zexpedition03_reborn_port.SC2Map" -ProjRoot (Get-Location) -Sc2Root="E:\SC2\SC2new\StarCraft II"
Write-Host "Alenger3 deps: $($plan2.documentRewrite.DocumentHeader.Count)"
```
Expected: Raynor ≤ 14, Alenger3 ≤ 17

---

## Task 10: 进图回归测试 — Raynor + Alenger3

**Files:**
- Test: `scripts/reborn/launch-reborn-commander.ps1`

- [ ] **Step 1: Raynor × zexpedition03 进图测试**

Run:
```powershell
cd "e:\Code\MyMod\SC2\合作指挥官-起义狂潮"
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\reborn\launch-reborn-commander.ps1" -Commander "TerranRaynor" -MapName "zexpedition03_reborn_port.SC2Map"
```
等待 120 秒后检查 `C:\Users\22448\Documents\StarCraft II\GameLogs` 是否有 ScriptError。
Expected: 无 ScriptError，游戏正常加载

- [ ] **Step 2: Alenger3 × zexpedition03 进图测试**

Run:
```powershell
cd "e:\Code\MyMod\SC2\合作指挥官-起义狂潮"
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\reborn\launch-reborn-commander.ps1" -Commander "TerranAlenger3" -MapName "zexpedition03_reborn_port.SC2Map"
```
等待 120 秒后检查 GameLogs。
Expected: 无 ScriptError，Alenger3 单位可生产（手动验证建造面板）

- [ ] **Step 3: 验证 DocumentHeader 依赖数**

检查启动日志或 DryRun 输出，确认 Raynor ≤ 14 依赖，Alenger3 ≤ 17 依赖。

- [ ] **Step 4: 如有 ScriptError，修复后重新进图**

如果出现 ScriptError，根据错误信息修复，然后重新运行 Step 1 或 Step 2。

---

## Task 11: 最终 commit + push

- [ ] **Step 1: 检查 git status**

Run: `git status --short --branch`
Expected: 所有改动已暂存，无未提交文件

- [ ] **Step 2: git pull --ff-only**

Run: `git pull --ff-only`
Expected: Already up to date 或快进合并

- [ ] **Step 3: push**

Run: `git push`
Expected: 推送成功

- [ ] **Step 4: 更新经验总结**

如有新的可复用经验，写入 `合作指挥官-起义狂潮/docs/经验总结/` 目录。

---

## Self-Review

### Spec coverage
- ✅ CoreRuntime 移除 AdapterBootstrap — Task 6
- ✅ RebornMapAdapter 承接 Alenger 初始化 — Task 5
- ✅ generated LibRebornAdapter_AlengerBootstrap.galaxy — Task 3 (generator) + Task 4 (CLI) + Task 8 (launcher inject)
- ✅ commanderToAlenger 映射 — Task 1
- ✅ mapCampaigns 映射 — Task 2
- ✅ launcher-plan.ps1 L2 按需 — Task 7
- ✅ Alenger mod 按需同步 — Task 8
- ✅ Campaign 按地图选择 — Task 7 (plan) + Task 2 (config)
- ✅ 单元测试 — Task 3 (TDD) + Task 9
- ✅ 进图回归测试 — Task 10
- ✅ 依赖数对比验证 — Task 9 Step 4 + Task 10 Step 3

### Placeholder scan
- 无 TBD/TODO
- 所有代码步骤包含完整代码
- 所有命令包含预期输出

### Type consistency
- `generateAlengerBootstrap(commander, commanderToAlenger)` — Task 3 定义，Task 4 CLI 调用，一致
- `libRebornAdapter_AlengerBootstrap_InitLib()` — Task 5 头文件声明，Task 3 生成内容，一致
- `commanderToAlenger` — Task 1 定义，Task 3/4/7/8 消费，一致
- `mapCampaigns` — Task 2 定义，Task 7 消费，一致
- `selectedAlengerMods` — Task 7 定义（plan），Task 8 定义（launcher），逻辑一致
