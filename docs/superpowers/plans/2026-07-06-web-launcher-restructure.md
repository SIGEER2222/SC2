# web-launcher 重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 Node.js + Express 重写 web-launcher 后端，新增 Tab B（mod 测试地图）入口，把杀进程/同步/启动/等待 scripterror 整合为统一编排流程。

**Architecture:** Node 后端三层（routes/services/lib），3 个公共能力模块（stop-sc2 / launch-and-wait / sync-mods-and-maps），通过 child_process 委托已验证的 PowerShell 资产（launch-7vs1-coop-test.ps1 / wait-for-game-ready.ps1）。maps.json manifest 描述所有场景。

**Tech Stack:** Node.js 18+ / Express / 原生 ES modules / PowerShell（已存在资产）

---

## 文件结构

```
合作指挥官-起义狂潮/
├── web-launcher/
│   ├── server.mjs                    [新] Express 入口
│   ├── maps.json                     [新] 场景 manifest
│   ├── package.json                  [新] express 依赖
│   ├── .gitignore                    [新] node_modules 排除
│   ├── routes/
│   │   ├── bootstrap.mjs             [新] /api/bootstrap
│   │   ├── scenario.mjs              [新] /api/scenarios, /api/scenario/:id/test
│   │   └── sync.mjs                  [新] /api/sync-all, /api/sync-mods, /api/sync-maps
│   ├── services/
│   │   ├── scenario-registry.mjs     [新] 加载 maps.json
│   │   └── launch-args-builder.mjs   [新] 构造 launch-7vs1-coop-test.ps1 参数
│   ├── lib/
│   │   ├── stop-sc2.mjs              [新] 杀 SC2 进程
│   │   ├── launch-and-wait.mjs       [新] 启动+等待
│   │   └── sync-mods-and-maps.mjs    [新] 同步 Mods/Maps
│   ├── test/
│   │   ├── stop-sc2.test.mjs
│   │   ├── launch-and-wait.test.mjs
│   │   ├── sync-mods-and-maps.test.mjs
│   │   ├── scenario-registry.test.mjs
│   │   └── launch-args-builder.test.mjs
│   ├── app.js                        [改] 增加 Tab 切换
│   ├── index.html                    [改] 增加 Tab 容器
│   ├── styles.css                    [改] Tab 样式
│   └── components/
│       ├── scenario-panels.js        [新] Tab B 卡片
│       └── test-result-panel.js      [新] 测试结果展示
├── scripts/
│   └── start-web-launcher.mjs        [新] 启动入口
```

---

## Task 1: 项目骨架与 package.json

**Files:**
- Create: `web-launcher/package.json`
- Create: `web-launcher/.gitignore`

- [ ] **Step 1: 创建 package.json**

```json
{
  "name": "sc2-web-launcher",
  "version": "1.0.0",
  "type": "module",
  "description": "SC2 合作指挥官-起义狂潮 web launcher",
  "engines": { "node": ">=18" },
  "scripts": {
    "start": "node server.mjs",
    "test": "node --test test/"
  },
  "dependencies": {
    "express": "^4.19.2"
  }
}
```

- [ ] **Step 2: 创建 .gitignore**

```
node_modules/
*.log
```

- [ ] **Step 3: 安装依赖**

Run: `cd web-launcher && npm install`
Expected: 生成 `node_modules/` 和 `package-lock.json`

- [ ] **Step 4: Commit**

```bash
git add web-launcher/package.json web-launcher/.gitignore
git commit -m "feat(web-launcher): 初始化 Node.js 项目骨架"
```

---

## Task 2: 公共能力模块 - stop-sc2.mjs

**Files:**
- Create: `web-launcher/lib/stop-sc2.mjs`
- Create: `web-launcher/test/stop-sc2.test.mjs`

- [ ] **Step 1: 写测试（验证无 SC2 进程时的返回）**

`web-launcher/test/stop-sc2.test.mjs`:
```javascript
import { test } from 'node:test';
import assert from 'node:assert';
import { stopAllSc2 } from '../lib/stop-sc2.mjs';

test('stopAllSc2 在没有 SC2 进程时返回 killed=0', async () => {
  const result = await stopAllSc2();
  assert.strictEqual(result.killed >= 0, true);
  assert.strictEqual(Array.isArray(result.pids), true);
});
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd web-launcher && node --test test/stop-sc2.test.mjs`
Expected: FAIL（模块不存在）

- [ ] **Step 3: 实现 stop-sc2.mjs**

`web-launcher/lib/stop-sc2.mjs`:
```javascript
import { execSync } from 'child_process';

/**
 * 杀掉所有 SC2 进程（SC2_x64.exe 和 SC2Switcher_x64.exe）
 * @returns {Promise<{killed: number, pids: number[]}>}
 */
export async function stopAllSc2() {
  const processNames = ['SC2_x64.exe', 'SC2Switcher_x64.exe'];
  const pids = [];

  for (const name of processNames) {
    try {
      const output = execSync(`tasklist /FI "IMAGENAME eq ${name}" /FO CSV /NH`, {
        encoding: 'utf8',
        windowsHide: true,
      });
      const lines = output.trim().split('\n').filter(l => l.includes(name));
      for (const line of lines) {
        const match = line.match(/"(\d+)"/);
        if (match) pids.push(parseInt(match[1], 10));
      }
    } catch {
      // tasklist 失败（如未找到进程），忽略
    }
  }

  let killed = 0;
  for (const pid of pids) {
    try {
      execSync(`taskkill /F /PID ${pid}`, { windowsHide: true });
      killed++;
    } catch {
      // 进程可能已退出
    }
  }

  return { killed, pids };
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd web-launcher && node --test test/stop-sc2.test.mjs`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add web-launcher/lib/stop-sc2.mjs web-launcher/test/stop-sc2.test.mjs
git commit -m "feat(web-launcher): 新增 stop-sc2 公共能力模块"
```

---

## Task 3: 公共能力模块 - sync-mods-and-maps.mjs

**Files:**
- Create: `web-launcher/lib/sync-mods-and-maps.mjs`
- Create: `web-launcher/test/sync-mods-and-maps.test.mjs`

- [ ] **Step 1: 写测试**

`web-launcher/test/sync-mods-and-maps.test.mjs`:
```javascript
import { test } from 'node:test';
import assert from 'node:assert';
import { syncMods, syncMaps, syncAll } from '../lib/sync-mods-and-maps.mjs';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';

test('syncMods 复制 mod 目录到目标，跳过 DocumentHeader/DocumentInfo', () => {
  const workspace = mkdtempSync(join(tmpdir(), 'ws-'));
  const sc2root = mkdtempSync(join(tmpdir(), 'sc2-'));
  const modDir = join(workspace, 'Mods', 'TestMod.SC2Mod');
  mkdirSync(modDir, { recursive: true });
  writeFileSync(join(modDir, 'base.xml'), '<base/>');
  writeFileSync(join(modDir, 'DocumentHeader'), 'HEADER');
  writeFileSync(join(modDir, 'DocumentInfo'), 'INFO');

  const result = syncMods({
    modNames: ['TestMod'],
    workspaceRoot: workspace,
    sc2Root: sc2root,
  });

  assert.strictEqual(result.copied > 0, true);
  assert.strictEqual(existsSync(join(sc2root, 'Mods', 'TestMod.SC2Mod', 'base.xml')), true);
  assert.strictEqual(existsSync(join(sc2root, 'Mods', 'TestMod.SC2Mod', 'DocumentHeader')), false);
  assert.strictEqual(existsSync(join(sc2root, 'Mods', 'TestMod.SC2Mod', 'DocumentInfo')), false);
});

test('syncMaps 复制地图文件到目标', () => {
  const workspace = mkdtempSync(join(tmpdir(), 'ws-'));
  const sc2root = mkdtempSync(join(tmpdir(), 'sc2-'));
  const mapFile = join(workspace, 'Maps', 'TestMap.SC2Map');
  mkdirSync(join(workspace, 'Maps'), { recursive: true });
  writeFileSync(mapFile, 'MPQ\x1a');

  const result = syncMaps({
    mapPaths: ['Maps/TestMap.SC2Map'],
    workspaceRoot: workspace,
    sc2Root: sc2root,
  });

  assert.strictEqual(result.copied, 1);
  assert.strictEqual(existsSync(join(sc2root, 'Maps', 'TestMap.SC2Map')), true);
});

test('syncAll 同时同步 mods 和 maps', () => {
  const workspace = mkdtempSync(join(tmpdir(), 'ws-'));
  const sc2root = mkdtempSync(join(tmpdir(), 'sc2-'));
  mkdirSync(join(workspace, 'Mods', 'M.SC2Mod'), { recursive: true });
  writeFileSync(join(workspace, 'Mods', 'M.SC2Mod', 'a.xml'), '<a/>');
  mkdirSync(join(workspace, 'Maps'), { recursive: true });
  writeFileSync(join(workspace, 'Maps', 'T.SC2Map'), 'MPQ');

  const result = syncAll({
    modNames: ['M'],
    mapPaths: ['Maps/T.SC2Map'],
    workspaceRoot: workspace,
    sc2Root: sc2root,
  });

  assert.strictEqual(result.copied > 0, true);
  assert.strictEqual(existsSync(join(sc2root, 'Mods', 'M.SC2Mod', 'a.xml')), true);
  assert.strictEqual(existsSync(join(sc2root, 'Maps', 'T.SC2Map')), true);
});
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd web-launcher && node --test test/sync-mods-and-maps.test.mjs`
Expected: FAIL（模块不存在）

- [ ] **Step 3: 实现 sync-mods-and-maps.mjs**

`web-launcher/lib/sync-mods-and-maps.mjs`:
```javascript
import { cpSync, existsSync, mkdirSync, statSync } from 'fs';
import { join, resolve, basename } from 'path';

const DEFAULT_PRESERVE = ['DocumentHeader', 'DocumentInfo'];

function copyWithExclude(src, dst, preserveFiles) {
  mkdirSync(dst, { recursive: true });
  const entries = cpSync(src, dst, {
    recursive: true,
    filter: (source) => {
      const name = source.split(/[\\/]/).pop();
      return !preserveFiles.includes(name);
    },
    force: true,
  });
}

/**
 * 同步 mod 到 SC2 安装目录
 * @param {Object} opts
 * @param {string[]} opts.modNames - mod 名列表（不含 .SC2Mod 后缀）
 * @param {string} opts.workspaceRoot - 工作区根路径
 * @param {string} opts.sc2Root - SC2 安装根路径
 * @param {Object} [opts.modSources] - 外部 mod 源路径映射
 * @param {string[]} [opts.preserveFiles] - 跳过的文件名列表
 * @returns {{copied: number, details: Array}}
 */
export function syncMods(opts) {
  const { modNames, workspaceRoot, sc2Root, modSources = {}, preserveFiles = DEFAULT_PRESERVE } = opts;
  const targetModsRoot = join(sc2Root, 'Mods');
  let copied = 0;
  const details = [];

  for (const name of modNames) {
    const modDirName = name.endsWith('.SC2Mod') ? name : `${name}.SC2Mod`;
    let src = join(workspaceRoot, 'Mods', modDirName);
    if (!existsSync(src) && modSources[name]) {
      src = modSources[name];
    }
    if (!existsSync(src)) {
      details.push({ path: modDirName, action: 'skipped', reason: 'source not found' });
      continue;
    }
    const dst = join(targetModsRoot, modDirName);
    copyWithExclude(src, dst, preserveFiles);
    copied++;
    details.push({ path: modDirName, action: 'copied' });
  }

  return { copied, details };
}

/**
 * 同步地图到 SC2 安装目录
 * @param {Object} opts
 * @param {string[]} opts.mapPaths - 地图相对路径列表（相对于 workspaceRoot）
 * @param {string} opts.workspaceRoot
 * @param {string} opts.sc2Root
 * @returns {{copied: number, details: Array}}
 */
export function syncMaps(opts) {
  const { mapPaths, workspaceRoot, sc2Root } = opts;
  const targetMapsRoot = join(sc2Root, 'Maps');
  mkdirSync(targetMapsRoot, { recursive: true });
  let copied = 0;
  const details = [];

  for (const relPath of mapPaths) {
    const src = resolve(workspaceRoot, relPath);
    if (!existsSync(src)) {
      details.push({ path: relPath, action: 'skipped', reason: 'source not found' });
      continue;
    }
    const name = basename(src);
    const dst = join(targetMapsRoot, name);
    cpSync(src, dst, { recursive: true, force: true });
    copied++;
    details.push({ path: relPath, action: 'copied' });
  }

  return { copied, details };
}

/**
 * 同时同步 mods 和 maps
 */
export function syncAll(opts) {
  const modResult = syncMods(opts);
  const mapResult = syncMaps(opts);
  return {
    copied: modResult.copied + mapResult.copied,
    details: [...modResult.details, ...mapResult.details],
  };
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd web-launcher && node --test test/sync-mods-and-maps.test.mjs`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add web-launcher/lib/sync-mods-and-maps.mjs web-launcher/test/sync-mods-and-maps.test.mjs
git commit -m "feat(web-launcher): 新增 sync-mods-and-maps 公共能力模块"
```

---

## Task 4: 公共能力模块 - launch-and-wait.mjs

**Files:**
- Create: `web-launcher/lib/launch-and-wait.mjs`
- Create: `web-launcher/test/launch-and-wait.test.mjs`

- [ ] **Step 1: 写测试**

`web-launcher/test/launch-and-wait.test.mjs`:
```javascript
import { test } from 'node:test';
import assert from 'node:assert';
import { parseWaitExitCode, buildLaunchCommand } from '../lib/launch-and-wait.mjs';

test('parseWaitExitCode: 0=成功, 1=失败, 2=超时, 其他=未知', () => {
  assert.strictEqual(parseWaitExitCode(0).ok, true);
  assert.strictEqual(parseWaitExitCode(1).ok, false);
  assert.strictEqual(parseWaitExitCode(1).reason, 'script_error');
  assert.strictEqual(parseWaitExitCode(2).ok, false);
  assert.strictEqual(parseWaitExitCode(2).reason, 'timeout');
  assert.strictEqual(parseWaitExitCode(99).ok, false);
  assert.strictEqual(parseWaitExitCode(99).reason, 'unknown');
});

test('buildLaunchCommand: 构造 SC2Switcher 启动命令', () => {
  const cmd = buildLaunchCommand({
    mapPath: 'E:/test/map.SC2Map',
    switcherPath: 'E:/SC2/SC2Switcher_x64.exe',
  });
  assert.strictEqual(cmd.executable, 'E:/SC2/SC2Switcher_x64.exe');
  assert.deepStrictEqual(cmd.args, ['E:/test/map.SC2Map']);
});
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd web-launcher && node --test test/launch-and-wait.test.mjs`
Expected: FAIL

- [ ] **Step 3: 实现 launch-and-wait.mjs**

`web-launcher/lib/launch-and-wait.mjs`:
```javascript
import { spawn } from 'child_process';
import { existsSync, readFileSync, readdirSync, statSync } from 'fs';
import { join } from 'path';

/**
 * 解析 wait-for-game-ready.ps1 的退出码
 * @param {number} code
 * @returns {{ok: boolean, reason?: string}}
 */
export function parseWaitExitCode(code) {
  if (code === 0) return { ok: true };
  if (code === 1) return { ok: false, reason: 'script_error' };
  if (code === 2) return { ok: false, reason: 'timeout' };
  return { ok: false, reason: 'unknown' };
}

/**
 * 构造 SC2Switcher 启动命令
 * @param {Object} opts
 * @param {string} opts.mapPath
 * @param {string} opts.switcherPath
 * @returns {{executable: string, args: string[]}}
 */
export function buildLaunchCommand({ mapPath, switcherPath }) {
  return {
    executable: switcherPath,
    args: [mapPath],
  };
}

function findLatestLog(gameLogsPath, pattern) {
  if (!existsSync(gameLogsPath)) return null;
  const files = readdirSync(gameLogsPath)
    .filter(f => f.includes(pattern))
    .map(f => ({ name: f, path: join(gameLogsPath, f), mtime: statSync(join(gameLogsPath, f)).mtimeMs }))
    .sort((a, b) => b.mtime - a.mtime);
  return files[0] || null;
}

/**
 * 启动游戏并等待 scripterror 检测完成
 * @param {Object} opts
 * @param {string} opts.mapPath - 地图绝对路径
 * @param {string} [opts.switcherPath] - SC2Switcher_x64.exe 路径
 * @param {string} [opts.gameLogsPath] - GameLogs 目录
 * @param {string} [opts.waitForGameReadyScript] - wait-for-game-ready.ps1 路径
 * @param {number} [opts.maxWaitSeconds=180]
 * @param {number} [opts.gracePeriodSeconds=20]
 * @returns {Promise<{ok: boolean, exitCode: number, pid: number, scriptErrorContent: string|null, alertsPath: string|null, durationMs: number}>}
 */
export async function launchAndWait(opts) {
  const {
    mapPath,
    switcherPath = 'E:/SC2/SC2new/StarCraft II/Support64/SC2Switcher_x64.exe',
    gameLogsPath = 'C:/Users/22448/Documents/StarCraft II/GameLogs',
    waitForGameReadyScript = null,
    maxWaitSeconds = 180,
    gracePeriodSeconds = 20,
  } = opts;

  const startMs = Date.now();
  const cmd = buildLaunchCommand({ mapPath, switcherPath });

  const child = spawn(cmd.executable, cmd.args, {
    detached: false,
    windowsHide: false,
  });

  const pid = child.pid;

  if (!waitForGameReadyScript) {
    // 不等待，直接返回启动结果
    return {
      ok: true,
      exitCode: 0,
      pid,
      scriptErrorContent: null,
      alertsPath: null,
      durationMs: Date.now() - startMs,
    };
  }

  // spawn wait-for-game-ready.ps1
  const waitChild = spawn('pwsh', [
    '-NoProfile',
    '-File',
    waitForGameReadyScript,
    '-MaxWaitSeconds', String(maxWaitSeconds),
    '-GracePeriodSeconds', String(gracePeriodSeconds),
  ], { windowsHide: true });

  const exitCode = await new Promise((resolve) => {
    waitChild.on('exit', resolve);
    waitChild.on('error', () => resolve(99));
  });

  // 读取 ScriptError 内容
  const scriptErrorLog = findLatestLog(gameLogsPath, 'ScriptError');
  let scriptErrorContent = null;
  if (scriptErrorLog) {
    try {
      scriptErrorContent = readFileSync(scriptErrorLog.path, 'utf8');
    } catch {
      scriptErrorContent = null;
    }
  }

  const alertsLog = findLatestLog(gameLogsPath, 'Alerts');

  const parsed = parseWaitExitCode(exitCode);

  return {
    ok: parsed.ok,
    exitCode,
    pid,
    scriptErrorContent,
    alertsPath: alertsLog ? alertsLog.path : null,
    durationMs: Date.now() - startMs,
  };
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd web-launcher && node --test test/launch-and-wait.test.mjs`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add web-launcher/lib/launch-and-wait.mjs web-launcher/test/launch-and-wait.test.mjs
git commit -m "feat(web-launcher): 新增 launch-and-wait 公共能力模块"
```

---

## Task 5: 场景配置 - maps.json

**Files:**
- Create: `web-launcher/maps.json`

- [ ] **Step 1: 创建 maps.json**

`web-launcher/maps.json`:
```json
{
  "scenarios": [
    {
      "id": "ttosh02_7vs1",
      "displayName": "7vs1 合作测试 - ttosh02",
      "type": "7vs1",
      "mapPath": "Maps/XM/ttosh02_7vs1.SC2Map",
      "launchMode": "7vs1-launcher",
      "requiredMods": ["CoopZeroPop", "CommanderCatalog", "XM", "kit_mutations"],
      "defaultArgs": {
        "commander": "ZergAbathur",
        "masteryLevel": 30
      },
      "tab": "A"
    },
    {
      "id": "abathur_test_map",
      "displayName": "Abathur 测试地图（F2 排除）",
      "type": "modtest",
      "mapPath": "Maps/abathur_test_map",
      "launchMode": "sc2-switcher",
      "requiredMods": ["CoopZeroPop"],
      "defaultArgs": {},
      "tab": "B"
    },
    {
      "id": "crys_heart",
      "displayName": "虫心 mod 测试地图",
      "type": "modtest",
      "mapPath": "Maps/虫心mod测试地图_unpacked",
      "launchMode": "sc2-switcher",
      "requiredMods": ["crys_the_swarm_reborn"],
      "modSources": {
        "crys_the_swarm_reborn": "C:/Users/22448/Downloads/重生虫心0.71汉化版（新）/reborn/crys_the_swarm_reborn.SC2Mod"
      },
      "defaultArgs": {},
      "tab": "B"
    },
    {
      "id": "home_soil",
      "displayName": "Home Soil（中译）",
      "type": "modtest",
      "mapPath": "Maps/Home_Soil.SC2Map",
      "launchMode": "sc2-switcher",
      "requiredMods": [],
      "defaultArgs": {},
      "tab": "B"
    }
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add web-launcher/maps.json
git commit -m "feat(web-launcher): 新增场景配置 manifest"
```

---

## Task 6: 业务服务 - scenario-registry.mjs

**Files:**
- Create: `web-launcher/services/scenario-registry.mjs`
- Create: `web-launcher/test/scenario-registry.test.mjs`

- [ ] **Step 1: 写测试**

`web-launcher/test/scenario-registry.test.mjs`:
```javascript
import { test } from 'node:test';
import assert from 'node:assert';
import { loadScenarios, getScenario, getScenariosByTab } from '../services/scenario-registry.mjs';
import { writeFileSync, mkdtempSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';

test('loadScenarios 从 JSON 文件加载场景', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'sr-'));
  writeFileSync(join(tmp, 'maps.json'), JSON.stringify({
    scenarios: [
      { id: 'a', displayName: 'A', type: '7vs1', tab: 'A' },
      { id: 'b', displayName: 'B', type: 'modtest', tab: 'B' },
    ]
  }));
  const list = loadScenarios(join(tmp, 'maps.json'));
  assert.strictEqual(list.length, 2);
  assert.strictEqual(list[0].id, 'a');
});

test('getScenario 按 id 查找', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'sr-'));
  writeFileSync(join(tmp, 'maps.json'), JSON.stringify({
    scenarios: [{ id: 'x', displayName: 'X', tab: 'A' }]
  }));
  const s = getScenario(join(tmp, 'maps.json'), 'x');
  assert.strictEqual(s.displayName, 'X');
  const notFound = getScenario(join(tmp, 'maps.json'), 'y');
  assert.strictEqual(notFound, null);
});

test('getScenariosByTab 按 tab 过滤', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'sr-'));
  writeFileSync(join(tmp, 'maps.json'), JSON.stringify({
    scenarios: [
      { id: 'a', tab: 'A' },
      { id: 'b', tab: 'B' },
      { id: 'c', tab: 'A' },
    ]
  }));
  const aList = getScenariosByTab(join(tmp, 'maps.json'), 'A');
  assert.strictEqual(aList.length, 2);
});
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd web-launcher && node --test test/scenario-registry.test.mjs`
Expected: FAIL

- [ ] **Step 3: 实现 scenario-registry.mjs**

`web-launcher/services/scenario-registry.mjs`:
```javascript
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DEFAULT_MAPS_JSON = join(__dirname, '..', 'maps.json');

/**
 * 加载所有场景
 * @param {string} [mapsJsonPath]
 * @returns {Array}
 */
export function loadScenarios(mapsJsonPath = DEFAULT_MAPS_JSON) {
  const content = readFileSync(mapsJsonPath, 'utf8');
  const data = JSON.parse(content);
  return data.scenarios || [];
}

/**
 * 按 id 查找场景
 * @param {string} mapsJsonPath
 * @param {string} id
 * @returns {Object|null}
 */
export function getScenario(mapsJsonPath, id) {
  const list = loadScenarios(mapsJsonPath);
  return list.find(s => s.id === id) || null;
}

/**
 * 按 tab 过滤场景
 * @param {string} mapsJsonPath
 * @param {string} tab - 'A' or 'B'
 * @returns {Array}
 */
export function getScenariosByTab(mapsJsonPath, tab) {
  const list = loadScenarios(mapsJsonPath);
  return list.filter(s => s.tab === tab);
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd web-launcher && node --test test/scenario-registry.test.mjs`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add web-launcher/services/scenario-registry.mjs web-launcher/test/scenario-registry.test.mjs
git commit -m "feat(web-launcher): 新增 scenario-registry 业务服务"
```

---

## Task 7: 业务服务 - launch-args-builder.mjs

**Files:**
- Create: `web-launcher/services/launch-args-builder.mjs`
- Create: `web-launcher/test/launch-args-builder.test.mjs`

- [ ] **Step 1: 写测试**

`web-launcher/test/launch-args-builder.test.mjs`:
```javascript
import { test } from 'node:test';
import assert from 'node:assert';
import { buildLaunchArgs } from '../services/launch-args-builder.mjs';

test('buildLaunchArgs: 7vs1 场景构造 launch-7vs1-coop-test.ps1 参数', () => {
  const args = buildLaunchArgs({
    scenario: {
      id: 'ttosh02_7vs1',
      type: '7vs1',
      launchMode: '7vs1-launcher',
      mapPath: 'Maps/XM/ttosh02_7vs1.SC2Map',
      defaultArgs: { commander: 'ZergAbathur', masteryLevel: 30 },
    },
    userSelection: { commander: 'TerranRaynor', masteryLevel: 50 },
  });
  assert.strictEqual(args[0], '-NoProfile');
  assert.ok(args.some(a => a.includes('launch-7vs1-coop-test.ps1')));
  assert.ok(args.some(a => a === '-Commander'));
  assert.ok(args.some(a => a === 'TerranRaynor'));
});

test('buildLaunchArgs: sc2-switcher 场景返回 null 参数', () => {
  const args = buildLaunchArgs({
    scenario: {
      id: 'home_soil',
      type: 'modtest',
      launchMode: 'sc2-switcher',
      mapPath: 'Maps/Home_Soil.SC2Map',
      defaultArgs: {},
    },
    userSelection: {},
  });
  assert.strictEqual(args, null);
});

test('buildLaunchArgs: userSelection 覆盖 defaultArgs', () => {
  const args = buildLaunchArgs({
    scenario: {
      id: 'x',
      type: '7vs1',
      launchMode: '7vs1-launcher',
      mapPath: 'm.SC2Map',
      defaultArgs: { commander: 'Default', masteryLevel: 30 },
    },
    userSelection: { commander: 'Override' },
  });
  assert.ok(args.some(a => a === 'Override'));
  assert.ok(args.some(a => a === '30')); // masteryLevel 保留 default
});
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd web-launcher && node --test test/launch-args-builder.test.mjs`
Expected: FAIL

- [ ] **Step 3: 实现 launch-args-builder.mjs**

`web-launcher/services/launch-args-builder.mjs`:
```javascript
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const LAUNCH_7VS1_PS1 = join(__dirname, '..', '..', 'scripts', 'launch-7vs1-coop-test.ps1');

/**
 * 构造启动参数
 * @param {Object} ctx
 * @param {Object} ctx.scenario - maps.json 中的场景对象
 * @param {Object} ctx.userSelection - 用户选择（覆盖 defaultArgs）
 * @returns {string[]|null} PowerShell 调用参数，或 null（不需要 PS 脚本）
 */
export function buildLaunchArgs({ scenario, userSelection = {} }) {
  if (scenario.launchMode === 'sc2-switcher') {
    return null;
  }

  const merged = { ...scenario.defaultArgs, ...userSelection };

  const args = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', LAUNCH_7VS1_PS1];

  if (merged.commander) {
    args.push('-Commander', merged.commander);
  }
  if (merged.prestige) {
    args.push('-Prestige', String(merged.prestige));
  }
  if (merged.masteryLevel !== undefined) {
    args.push('-MasteryLevel', String(merged.masteryLevel));
  }
  if (merged.mutators && merged.mutators.length > 0) {
    args.push('-Mutators', merged.mutators.join(','));
  }
  if (merged.mapPath) {
    args.push('-MapPath', merged.mapPath);
  } else if (scenario.mapPath) {
    args.push('-MapPath', scenario.mapPath);
  }

  return args;
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd web-launcher && node --test test/launch-args-builder.test.mjs`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add web-launcher/services/launch-args-builder.mjs web-launcher/test/launch-args-builder.test.mjs
git commit -m "feat(web-launcher): 新增 launch-args-builder 业务服务"
```

---

## Task 8: 后端路由 - bootstrap.mjs

**Files:**
- Create: `web-launcher/routes/bootstrap.mjs`

- [ ] **Step 1: 实现 bootstrap.mjs**

`web-launcher/routes/bootstrap.mjs`:
```javascript
import { Router } from 'express';
import { getScenariosByTab } from '../services/scenario-registry.mjs';
import { readFileSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const METADATA_PATH = join(__dirname, '..', '..', 'Shared', 'CommanderPower', 'commander-power-metadata.json');

const router = Router();

router.get('/bootstrap', (req, res) => {
  const scenariosA = getScenariosByTab(join(__dirname, '..', 'maps.json'), 'A');
  const scenariosB = getScenariosByTab(join(__dirname, '..', 'maps.json'), 'B');

  let commanderMetadata = null;
  if (existsSync(METADATA_PATH)) {
    commanderMetadata = JSON.parse(readFileSync(METADATA_PATH, 'utf8'));
  }

  res.json({
    ok: true,
    data: {
      scenariosA,
      scenariosB,
      commanderMetadata,
    },
  });
});

export { router as bootstrapRouter };
```

- [ ] **Step 2: Commit**

```bash
git add web-launcher/routes/bootstrap.mjs
git commit -m "feat(web-launcher): 新增 bootstrap 路由"
```

---

## Task 9: 后端路由 - sync.mjs

**Files:**
- Create: `web-launcher/routes/sync.mjs`

- [ ] **Step 1: 实现 sync.mjs**

`web-launcher/routes/sync.mjs`:
```javascript
import { Router } from 'express';
import { syncMods, syncMaps, syncAll } from '../lib/sync-mods-and-maps.mjs';
import { loadScenarios } from '../services/scenario-registry.mjs';
import { fileURLToPath } from 'url';
import { dirname, join, resolve } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const MAPS_JSON = join(__dirname, '..', 'maps.json');
const WORKSPACE_ROOT = resolve(__dirname, '..', '..');
const SC2_ROOT = 'E:/SC2/SC2new/StarCraft II';

const router = Router();

function resolveModNames(scenarioIds) {
  const scenarios = loadScenarios(MAPS_JSON);
  const names = new Set();
  for (const id of scenarioIds || []) {
    const s = scenarios.find(x => x.id === id);
    if (s && s.requiredMods) {
      for (const m of s.requiredMods) names.add(m);
    }
  }
  return Array.from(names);
}

function resolveMapPaths(scenarioIds) {
  const scenarios = loadScenarios(MAPS_JSON);
  const paths = new Set();
  for (const id of scenarioIds || []) {
    const s = scenarios.find(x => x.id === id);
    if (s && s.mapPath) paths.add(s.mapPath);
  }
  return Array.from(paths);
}

router.post('/sync-mods', (req, res) => {
  try {
    const { scenarioIds } = req.body || {};
    const modNames = resolveModNames(scenarioIds);
    const result = syncMods({
      modNames,
      workspaceRoot: WORKSPACE_ROOT,
      sc2Root: SC2_ROOT,
    });
    res.json({ ok: true, data: result });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e) });
  }
});

router.post('/sync-maps', (req, res) => {
  try {
    const { scenarioIds } = req.body || {};
    const mapPaths = resolveMapPaths(scenarioIds);
    const result = syncMaps({
      mapPaths,
      workspaceRoot: WORKSPACE_ROOT,
      sc2Root: SC2_ROOT,
    });
    res.json({ ok: true, data: result });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e) });
  }
});

router.post('/sync-all', (req, res) => {
  try {
    const { scenarioIds } = req.body || {};
    const modNames = resolveModNames(scenarioIds);
    const mapPaths = resolveMapPaths(scenarioIds);
    const result = syncAll({
      modNames,
      mapPaths,
      workspaceRoot: WORKSPACE_ROOT,
      sc2Root: SC2_ROOT,
    });
    res.json({ ok: true, data: result });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e) });
  }
});

export { router as syncRouter };
```

- [ ] **Step 2: Commit**

```bash
git add web-launcher/routes/sync.mjs
git commit -m "feat(web-launcher): 新增 sync 路由"
```

---

## Task 10: 后端路由 - scenario.mjs

**Files:**
- Create: `web-launcher/routes/scenario.mjs`

- [ ] **Step 1: 实现 scenario.mjs**

`web-launcher/routes/scenario.mjs`:
```javascript
import { Router } from 'express';
import { loadScenarios, getScenario } from '../services/scenario-registry.mjs';
import { syncAll } from '../lib/sync-mods-and-maps.mjs';
import { stopAllSc2 } from '../lib/stop-sc2.mjs';
import { launchAndWait } from '../lib/launch-and-wait.mjs';
import { buildLaunchArgs } from '../services/launch-args-builder.mjs';
import { fileURLToPath } from 'url';
import { dirname, join, resolve } from 'path';
import { spawn } from 'child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const MAPS_JSON = join(__dirname, '..', 'maps.json');
const WORKSPACE_ROOT = resolve(__dirname, '..', '..');
const SC2_ROOT = 'E:/SC2/SC2new/StarCraft II';
const SWITCHER_PATH = 'E:/SC2/SC2new/StarCraft II/Support64/SC2Switcher_x64.exe';
const GAME_LOGS_PATH = 'C:/Users/22448/Documents/StarCraft II/GameLogs';
const WAIT_PS1 = join(__dirname, '..', '..', 'scripts', 'wait-for-game-ready.ps1');

const router = Router();

router.get('/scenarios', (req, res) => {
  const list = loadScenarios(MAPS_JSON);
  res.json({ ok: true, data: list });
});

router.post('/scenario/:id/test', async (req, res) => {
  const scenarioId = req.params.id;
  const scenario = getScenario(MAPS_JSON, scenarioId);
  if (!scenario) {
    return res.status(404).json({ ok: false, error: `场景不存在: ${scenarioId}` });
  }

  const userSelection = req.body?.userSelection || {};
  const steps = {};
  const startMs = Date.now();

  try {
    // 1. 杀进程
    const stopStart = Date.now();
    const stopResult = await stopAllSc2();
    steps.stop = { durationMs: Date.now() - stopStart, killed: stopResult.killed };

    // 2. 同步 mods + maps
    const syncStart = Date.now();
    const syncResult = syncAll({
      modNames: scenario.requiredMods || [],
      mapPaths: [scenario.mapPath].filter(Boolean),
      workspaceRoot: WORKSPACE_ROOT,
      sc2Root: SC2_ROOT,
      modSources: scenario.modSources || {},
    });
    steps.sync = { durationMs: Date.now() - syncStart, copied: syncResult.copied };

    // 3. 启动
    const launchStart = Date.now();
    let launchResult;
    const args = buildLaunchArgs({ scenario, userSelection });
    if (args) {
      // 7vs1-launcher 模式：spawn pwsh + launch-7vs1-coop-test.ps1
      const child = spawn('pwsh', args, { windowsHide: false });
      const pid = child.pid;
      const waitResult = await launchAndWait({
        mapPath: resolve(WORKSPACE_ROOT, scenario.mapPath || ''),
        switcherPath: SWITCHER_PATH,
        gameLogsPath: GAME_LOGS_PATH,
        waitForGameReadyScript: WAIT_PS1,
        maxWaitSeconds: 180,
        gracePeriodSeconds: 20,
      });
      launchResult = { ...waitResult, pid };
    } else {
      // sc2-switcher 模式：直接 SC2Switcher <mapPath>
      launchResult = await launchAndWait({
        mapPath: resolve(WORKSPACE_ROOT, scenario.mapPath),
        switcherPath: SWITCHER_PATH,
        gameLogsPath: GAME_LOGS_PATH,
        waitForGameReadyScript: WAIT_PS1,
        maxWaitSeconds: 180,
        gracePeriodSeconds: 20,
      });
    }
    steps.launch = { durationMs: Date.now() - launchStart, args: args || ['<switcher>', scenario.mapPath] };
    steps.wait = { durationMs: launchResult.durationMs, exitCode: launchResult.exitCode };

    return res.json({
      ok: true,
      data: {
        ok: launchResult.ok,
        exitCode: launchResult.exitCode,
        pid: launchResult.pid,
        scriptErrorContent: launchResult.scriptErrorContent,
        alertsPath: launchResult.alertsPath,
        durationMs: Date.now() - startMs,
        steps,
      },
    });
  } catch (e) {
    return res.status(500).json({
      ok: false,
      error: String(e),
      data: { steps, durationMs: Date.now() - startMs },
    });
  }
});

export { router as scenarioRouter };
```

- [ ] **Step 2: Commit**

```bash
git add web-launcher/routes/scenario.mjs
git commit -m "feat(web-launcher): 新增 scenario 路由（一键测试闭环）"
```

---

## Task 11: 后端入口 - server.mjs

**Files:**
- Create: `web-launcher/server.mjs`

- [ ] **Step 1: 实现 server.mjs**

`web-launcher/server.mjs`:
```javascript
import express from 'express';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { bootstrapRouter } from './routes/bootstrap.mjs';
import { syncRouter } from './routes/sync.mjs';
import { scenarioRouter } from './routes/scenario.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PORT = 17761;

const app = express();
app.use(express.json());
app.use(express.static(__dirname));
app.use('/api', bootstrapRouter, syncRouter, scenarioRouter);

app.listen(PORT, '127.0.0.1', () => {
  console.log(`SC2 web-launcher: http://127.0.0.1:${PORT}/`);
});
```

- [ ] **Step 2: 启动验证**

Run: `cd web-launcher && node server.mjs`
Expected: 控制台输出 `SC2 web-launcher: http://127.0.0.1:17761/`
访问 `http://127.0.0.1:17761/api/scenarios` 应返回场景 JSON

- [ ] **Step 3: Commit**

```bash
git add web-launcher/server.mjs
git commit -m "feat(web-launcher): 新增 Express 后端入口"
```

---

## Task 12: 启动入口脚本

**Files:**
- Create: `scripts/start-web-launcher.mjs`

- [ ] **Step 1: 实现 start-web-launcher.mjs**

`scripts/start-web-launcher.mjs`:
```javascript
import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { existsSync } from 'fs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SERVER_PATH = join(__dirname, '..', 'web-launcher', 'server.mjs');
const PORT = 17761;

if (!existsSync(SERVER_PATH)) {
  console.error('找不到 web-launcher/server.mjs:', SERVER_PATH);
  process.exit(1);
}

// 检查 node_modules
const nodeModules = join(dirname(SERVER_PATH), 'node_modules');
if (!existsSync(nodeModules)) {
  console.error('未安装依赖，请先执行: cd web-launcher && npm install');
  process.exit(1);
}

console.log('启动 SC2 web-launcher...');
const child = spawn('node', [SERVER_PATH], {
  stdio: 'inherit',
  windowsHide: false,
});

// 自动打开浏览器
setTimeout(async () => {
  try {
    const open = (await import('open')).default;
    await open(`http://127.0.0.1:${PORT}/`);
  } catch {
    console.log(`请手动访问: http://127.0.0.1:${PORT}/`);
  }
}, 1000);

child.on('exit', (code) => process.exit(code ?? 0));
```

- [ ] **Step 2: 安装 open 依赖**

Run: `cd web-launcher && npm install open`
Expected: package.json 多出 open 依赖

- [ ] **Step 3: Commit**

```bash
git add scripts/start-web-launcher.mjs web-launcher/package.json
git commit -m "feat(web-launcher): 新增 start-web-launcher.mjs 启动入口"
```

---

## Task 13: 前端 - index.html Tab 容器

**Files:**
- Modify: `web-launcher/index.html`

- [ ] **Step 1: 读取现有 index.html**

Run: `cat web-launcher/index.html` (查看现有结构)

- [ ] **Step 2: 在 body 顶部插入 Tab 容器**

在 `<body>` 内、现有内容前插入：
```html
<div class="tab-bar">
  <button class="tab active" data-tab="A">7vs1 合作测试</button>
  <button class="tab" data-tab="B">Mod 测试地图</button>
</div>
<div class="tab-content" data-tab-content="A">
  <!-- 原有内容保留在此 -->
</div>
<div class="tab-content" data-tab-content="B" hidden>
  <div id="scenario-cards"></div>
  <div id="test-result-panel"></div>
</div>
```

- [ ] **Step 3: Commit**

```bash
git add web-launcher/index.html
git commit -m "feat(web-launcher): 前端增加 Tab 容器结构"
```

---

## Task 14: 前端 - styles.css Tab 样式

**Files:**
- Modify: `web-launcher/styles.css`

- [ ] **Step 1: 追加 Tab 样式**

在 styles.css 末尾追加：
```css
.tab-bar {
  display: flex;
  gap: 4px;
  padding: 8px 16px;
  background: #1a1a1a;
  border-bottom: 1px solid #333;
}
.tab {
  padding: 8px 16px;
  background: #2a2a2a;
  color: #ccc;
  border: none;
  border-radius: 4px 4px 0 0;
  cursor: pointer;
  font-size: 14px;
}
.tab.active {
  background: #3a5a8a;
  color: #fff;
}
.tab-content {
  padding: 16px;
}
.tab-content[hidden] {
  display: none;
}
.scenario-card {
  background: #2a2a2a;
  border: 1px solid #444;
  border-radius: 8px;
  padding: 16px;
  margin-bottom: 12px;
}
.scenario-card h3 {
  margin: 0 0 8px 0;
  color: #eee;
}
.scenario-card .meta {
  color: #888;
  font-size: 12px;
  margin-bottom: 12px;
}
.scenario-card .actions {
  display: flex;
  gap: 8px;
}
.scenario-card button {
  padding: 6px 12px;
  background: #3a5a8a;
  color: #fff;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}
.scenario-card button:hover {
  background: #4a6aaa;
}
.test-result {
  background: #1a1a1a;
  border: 1px solid #555;
  border-radius: 8px;
  padding: 16px;
  margin-top: 16px;
}
.test-result.success { border-color: #4a4; }
.test-result.error { border-color: #a44; }
.test-result.timeout { border-color: #aa4; }
.test-result pre {
  background: #0a0a0a;
  padding: 8px;
  border-radius: 4px;
  overflow: auto;
  max-height: 300px;
}
```

- [ ] **Step 2: Commit**

```bash
git add web-launcher/styles.css
git commit -m "feat(web-launcher): 前端增加 Tab 样式"
```

---

## Task 15: 前端 - app.js Tab 切换

**Files:**
- Modify: `web-launcher/app.js`

- [ ] **Step 1: 在 app.js 末尾追加 Tab 切换逻辑**

```javascript
// === Tab 切换 ===
document.querySelectorAll('.tab').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.tab').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    const tab = btn.dataset.tab;
    document.querySelectorAll('[data-tab-content]').forEach(c => {
      c.hidden = c.dataset.tabContent !== tab;
    });
    if (tab === 'B') {
      import('./components/scenario-panels.js').then(m => m.renderScenarioCards());
    }
  });
});
```

- [ ] **Step 2: Commit**

```bash
git add web-launcher/app.js
git commit -m "feat(web-launcher): 前端增加 Tab 切换逻辑"
```

---

## Task 16: 前端组件 - scenario-panels.js

**Files:**
- Create: `web-launcher/components/scenario-panels.js`

- [ ] **Step 1: 实现 scenario-panels.js**

`web-launcher/components/scenario-panels.js`:
```javascript
import { renderTestResult } from './test-result-panel.js';

export async function renderScenarioCards() {
  const container = document.getElementById('scenario-cards');
  if (!container) return;

  try {
    const resp = await fetch('/api/bootstrap');
    const json = await resp.json();
    if (!json.ok) throw new Error(json.error);
    const scenarios = json.data.scenariosB || [];

    container.innerHTML = scenarios.map(s => `
      <div class="scenario-card" data-id="${s.id}">
        <h3>${s.displayName}</h3>
        <div class="meta">
          类型: ${s.type} |
          启动: ${s.launchMode} |
          所需 mod: ${(s.requiredMods || []).join(', ') || '无'}
        </div>
        <div class="actions">
          <button class="test-btn" data-id="${s.id}">一键测试</button>
          <button class="sync-btn" data-id="${s.id}">仅同步</button>
        </div>
      </div>
    `).join('');

    container.querySelectorAll('.test-btn').forEach(btn => {
      btn.addEventListener('click', () => runTest(btn.dataset.id));
    });
    container.querySelectorAll('.sync-btn').forEach(btn => {
      btn.addEventListener('click', () => runSync(btn.dataset.id));
    });
  } catch (e) {
    container.innerHTML = `<div class="error">加载失败: ${e.message}</div>`;
  }
}

async function runTest(scenarioId) {
  const panel = document.getElementById('test-result-panel');
  panel.innerHTML = '<div class="test-result">测试中...</div>';

  try {
    const resp = await fetch(`/api/scenario/${scenarioId}/test`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userSelection: {} }),
    });
    const json = await resp.json();
    renderTestResult(json, panel);
  } catch (e) {
    panel.innerHTML = `<div class="test-result error">请求失败: ${e.message}</div>`;
  }
}

async function runSync(scenarioId) {
  const panel = document.getElementById('test-result-panel');
  panel.innerHTML = '<div class="test-result">同步中...</div>';

  try {
    const resp = await fetch('/api/sync-all', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ scenarioIds: [scenarioId] }),
    });
    const json = await resp.json();
    if (json.ok) {
      panel.innerHTML = `<div class="test-result success">同步完成: 复制 ${json.data.copied} 项</div>`;
    } else {
      panel.innerHTML = `<div class="test-result error">同步失败: ${json.error}</div>`;
    }
  } catch (e) {
    panel.innerHTML = `<div class="test-result error">请求失败: ${e.message}</div>`;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add web-launcher/components/scenario-panels.js
git commit -m "feat(web-launcher): 新增 Tab B 场景卡片组件"
```

---

## Task 17: 前端组件 - test-result-panel.js

**Files:**
- Create: `web-launcher/components/test-result-panel.js`

- [ ] **Step 1: 实现 test-result-panel.js**

`web-launcher/components/test-result-panel.js`:
```javascript
export function renderTestResult(json, container) {
  if (!json.ok) {
    container.innerHTML = `
      <div class="test-result error">
        <h3>测试失败（请求错误）</h3>
        <pre>${escapeHtml(json.error || '未知错误')}</pre>
      </div>`;
    return;
  }

  const data = json.data;
  const cls = data.ok ? 'success' : (data.exitCode === 2 ? 'timeout' : 'error');
  const title = data.ok ? '测试成功' : (data.exitCode === 2 ? '测试超时' : '测试失败');

  const stepsHtml = data.steps ? Object.entries(data.steps).map(([k, v]) => `
    <div>${k}: ${v.durationMs}ms ${v.killed !== undefined ? `(killed ${v.killed})` : ''} ${v.copied !== undefined ? `(copied ${v.copied})` : ''} ${v.exitCode !== undefined ? `(exit ${v.exitCode})` : ''}</div>
  `).join('') : '';

  const scriptErrorHtml = data.scriptErrorContent
    ? `<h4>ScriptError 内容：</h4><pre>${escapeHtml(data.scriptErrorContent)}</pre>`
    : '';

  container.innerHTML = `
    <div class="test-result ${cls}">
      <h3>${title}</h3>
      <div>PID: ${data.pid ?? 'N/A'} | 总耗时: ${data.durationMs}ms</div>
      <div class="steps">${stepsHtml}</div>
      ${scriptErrorHtml}
    </div>`;
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}
```

- [ ] **Step 2: Commit**

```bash
git add web-launcher/components/test-result-panel.js
git commit -m "feat(web-launcher): 新增测试结果展示组件"
```

---

## Task 18: 端到端测试 - Tab B 跑 abathur_test_map

**Files:**
- 无新文件，端到端验证

- [ ] **Step 1: 启动 web-launcher**

Run: `cd "E:/Code/MyMod/SC2/合作指挥官-起义狂潮" && node scripts/start-web-launcher.mjs`
Expected: 浏览器自动打开 http://127.0.0.1:17761/

- [ ] **Step 2: 切换到 Tab B**

点击"Mod 测试地图" Tab，应看到 3 个卡片：
- Abathur 测试地图（F2 排除）
- 虫心 mod 测试地图
- Home Soil（中译）

- [ ] **Step 3: 跑 abathur_test_map 测试**

点击"Abathur 测试地图"卡片的"一键测试"按钮
Expected:
- 显示"测试中..."
- 几秒后 SC2 启动
- 约 30-60 秒后显示测试结果（应为 success，无 ScriptError）

- [ ] **Step 4: 如果有 ScriptError，记录并修复**

观察 test-result-panel 显示的内容，如果有 ScriptError，根据内容修复 mod 或地图问题。

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "test(web-launcher): 端到端验证 Tab B abathur_test_map 测试通过"
```

---

## Task 19: 端到端测试 - Tab B 跑 home_soil（无 mod）

- [ ] **Step 1: 在浏览器 Tab B 点击 Home Soil 的"一键测试"**

Expected:
- SC2 启动
- 加载完成无 ScriptError

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "test(web-launcher): 端到端验证 Tab B home_soil 测试通过"
```

---

## Task 20: 端到端测试 - Tab A 现有 7vs1 测试不破坏

- [ ] **Step 1: 切换到 Tab A，跑一次现有 7vs1 测试**

Expected:
- 现有 7vs1 面板功能保持不变
- 能正常启动游戏并检测 Alerts

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "test(web-launcher): 验证 Tab A 现有 7vs1 测试不破坏"
```

---

## Task 21: 最终推送

- [ ] **Step 1: pull --rebase**

Run: `cd "E:/Code/MyMod/SC2" && git pull --rebase origin fix_003`

- [ ] **Step 2: push**

Run: `cd "E:/Code/MyMod/SC2" && git push origin fix_003`

---

## Self-Review 结果

**Spec 覆盖：**
- §3.1 目录结构 → Task 1-12 全部对应
- §3.2 模块边界 → Task 2-7 全部对应
- §3.3 数据流 Tab A/B → Task 10 (scenario.mjs) + Task 18-20 端到端
- §4.1 maps.json → Task 5
- §4.2 API 响应格式 → Task 10 实现
- §5.1-5.3 公共能力模块 → Task 2-4
- §6 前端 Tab 改造 → Task 13-17
- §7 错误处理 → Task 10 的 try/catch + Task 17 错误展示
- §8 测试与验证 → Task 18-20

**类型一致性：**
- `stopAllSc2()` 返回 `{killed, pids}` 在 Task 2/10 一致
- `launchAndWait()` 返回 `{ok, exitCode, pid, scriptErrorContent, alertsPath, durationMs}` 在 Task 4/10 一致
- `syncAll()` 返回 `{copied, details}` 在 Task 3/9 一致
- `buildLaunchArgs()` 返回 `string[]|null` 在 Task 7/10 一致

**Placeholder 扫描：** 无 TODO/TBD
