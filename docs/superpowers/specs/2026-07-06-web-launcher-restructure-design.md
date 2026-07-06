# web-launcher 重构设计文档

- **日期**：2026-07-06
- **范围**：SC2 合作指挥官-起义狂潮 项目下的 web-launcher 与 scripts 测试链
- **作者**：TRAE + 用户协作
- **状态**：已确认设计，待 review

## 1. 背景与目标

### 1.1 现状

- `scripts/` 下分散着 20 个保留脚本 + 64 个 old/ 脚本，最近刚做过一次清理（见 commit `1cf6275b`）
- `web-launcher/` 由 PowerShell `start-7vs1-web-launcher.ps1`（2078 行）作为后端 + 原生 JS 前端构成
- 当前只覆盖 7vs1 合作测试一类地图（`*_7vs1.SC2Map`），其他测试地图（abathur_test_map、虫心mod测试地图、Home_Soil 等）没有入口
- 测试流程碎片化：杀进程、启动、等待 scripterror、同步 mod+map 分散在多个 PowerShell 脚本里
- 上层入口只有命令行 `pwsh -File start-7vs1-web-launcher.ps1`，每次跑一次测试要手动拼步骤

### 1.2 目标

1. **统一入口**：所有地图测试都从 `web-launcher/` 的 Web UI 进入
2. **流程编排**：杀进程 → 同步 mod+map → 启动 → 等待 Alerts → 检测 ScriptError 这一整套作为一个 API 闭环
3. **场景化**：前端区分 7vs1 合作测试地图（带完整逻辑）与 mod 测试地图（空白地图），分别进 Tab A 和 Tab B
4. **技术栈统一**：Node.js + Express 作为后端，与前端语言一致
5. **复用已验证逻辑**：bank 写入、地图安装等逻辑仍由 `launch-7vs1-coop-test.ps1` 完成，Node 通过 `child_process` 调用
6. **最外层精简**：顶层调用只保留 `scripts/start-web-launcher.mjs`（或 `web-launcher/server.mjs` 直接启动）

### 1.3 非目标

- 不重写 `launch-7vs1-coop-test.ps1` 的 bank 写入逻辑
- 不动 `scripts/old/` 中的 64 个历史脚本
- 不改 `sc2_unit_explorer.py` / `collect_commander_units.py` / `unpack_maps_batch.py`（独立工具）
- 不引入前端构建工具（保持原生 JS + ES modules）
- 不动现有 Tab A 的 7vs1 业务逻辑

## 2. 决策记录

| 决策点 | 选择 | 备选 | 理由 |
|---|---|---|---|
| 重构深度 | 深度重构 | 最小/中度/深度 | 用户明确要求"大加改动" |
| 场景定义 | 区分对待 7vs1 / modtest | 按地图/按地图+目标 | 用户希望"thanson01_7vs1 这类已带逻辑的保持现状，空白测试地图单独 Tab B" |
| 地图配置来源 | JSON manifest | 后端动态识别/每地图一个 manifest | 加地图只改 JSON，最灵活 |
| 同步范围 | Mods + Maps | Bank/资源缓存 | 用户只勾选了 Mods 和 Maps |
| 测试流程 UX | 一键 + 高级展开 | 一键闭环/分步 | 用户明确选择"默认一键 + 高级展开" |
| Node 框架 | Express | 原生 http/Fastify | 用户明确选择 Express |
| Bank 写入 | Node 调用 PowerShell | 全部 Node 重写/混合 | 用户明确选择委托 PowerShell，最大化复用已验证逻辑 |
| 历史脚本 | 保留 old/ | 删除/部分恢复 | 用户明确选择保留作为存档 |

## 3. 架构设计

### 3.1 目录结构

```
合作指挥官-起义狂潮/
├── web-launcher/                    # 前端 + Node 后端
│   ├── server.mjs                    # Express 入口（取代 start-7vs1-web-launcher.ps1）
│   ├── maps.json                    # 地图场景配置 manifest
│   ├── package.json                 # express 依赖
│   ├── routes/                      # 后端路由（拆分 2078 行）
│   │   ├── bootstrap.mjs            # /api/bootstrap
│   │   ├── launch.mjs               # /api/launch, /api/launch-status, /api/preview
│   │   ├── sync.mjs                 # /api/sync-mods, /api/sync-maps, /api/sync-all
│   │   └── scenario.mjs             # /api/scenarios, /api/scenario/:id/test
│   ├── services/                    # 业务逻辑层
│   │   ├── commander-metadata.mjs   # 读取 commander-power-metadata.json
│   │   ├── mutator-catalog.mjs      # 解析 mutator catalog
│   │   ├── bank-snapshot.mjs        # 读取 CampaignXCore.SC2Bank
│   │   ├── asset-resolver.mjs       # 头像/图标缓存
│   │   ├── launch-args-builder.mjs   # 构造 launch-7vs1-coop-test.ps1 参数
│   │   └── scenario-registry.mjs     # 加载 maps.json
│   ├── lib/                         # 公共能力（核心）
│   │   ├── stop-sc2.mjs             # 杀 SC2 进程
│   │   ├── launch-and-wait.mjs      # 启动游戏 + 等待 Alerts.txt + 检测 ScriptError
│   │   └── sync-mods-and-maps.mjs   # 同步 Mods/ 和 Maps/ 到 SC2 安装目录
│   ├── components/                  # 前端组件（保留现有 + 新增）
│   │   ├── *.js                     # 现有 Tab A 组件保持不动
│   │   ├── scenario-panels.js       # 新增 Tab B 卡片
│   │   └── test-result-panel.js     # 新增测试结果展示
│   ├── app.js                       # 前端入口（增加 Tab 切换）
│   ├── index.html                   # 增加 Tab 容器
│   └── styles.css                   # Tab 样式
├── scripts/
│   ├── start-web-launcher.mjs       # 启动入口（取代 start-7vs1-web-launcher.ps1）
│   ├── launch-7vs1-coop-test.ps1   # 7vs1 启动器（被 Node 调用，不改逻辑）
│   ├── commander-power-metadata.ps1 # 被 launch-7vs1-coop-test dot-source（保留）
│   ├── sc2/campaignxcore-bank.ps1  # 被 launch-7vs1-coop-test dot-source（保留）
│   ├── wait-for-game-ready.ps1     # 被 Node 调用（保留）
│   ├── check-game-logs.ps1         # 备用
│   ├── sc2_unit_explorer.py        # 独立工具
│   ├── collect_commander_units.py  # 独立工具
│   ├── unpack_maps_batch.py        # 独立工具
│   └── old/                         # 64 个历史脚本（保留不动）
└── docs/superpowers/specs/         # 本文档所在
```

### 3.2 模块边界

每个模块只回答一个问题，能独立理解和和测试：

| 模块 | 回答的问题 | 输入 | 输出 |
|---|---|---|---|
| `stop-sc2.mjs` | 怎么把正在跑的 SC2 杀掉？ | 无 | `{ killed, pids[] }` |
| `launch-and-wait.mjs` | 怎么启动一个地图并等它加载完？ | `{ mapPath, switcherPath, gameLogsPath, maxWaitSeconds }` | `{ ok, exitCode, pid, scriptErrorContent, durationMs }` |
| `sync-mods-and-maps.mjs` | 怎么把工作区的 mod 和 map 推到游戏目录？ | `{ modNames[], mapPaths[], sc2Root, preserveFiles[] }` | `{ copied, skipped, durationMs }` |
| `scenario-registry.mjs` | 我有哪些场景？场景长什么样？ | 无（读 maps.json） | `Scenario[]` |
| `launch-args-builder.mjs` | 给场景+用户选择，怎么拼 launch-7vs1-coop-test.ps1 的参数？ | `{ scenario, userSelection }` | `string[] args` |
| `commander-metadata.mjs` | 有哪些指挥官/威望/精通？ | 无（读 metadata.json） | `Commander[]` |
| `bank-snapshot.mjs` | 玩家当前 bank 状态如何？ | 无（读 CampaignXCore.SC2Bank） | `CompletionSnapshot` |
| `asset-resolver.mjs` | 指挥官/突变因子的图标怎么处理？ | `{ id, type }` | `{ image, source }` |

### 3.3 数据流

#### Tab A 一键测试流程

```
用户在 Tab A 选 指挥官/突变/威望/精通 → 点"一键测试"
       ↓
POST /api/scenario/ttosh02_7vs1/test
       ↓
scenario.mjs:
  1. stop-sc2.stopAllSc2()
  2. sync-mods-and-maps.syncAll({ mods: scenario.requiredMods, maps: [scenario.mapPath] })
  3. launch-args-builder.buildArgs(scenario, userSelection)
  4. spawn('pwsh', ['-File', 'launch-7vs1-coop-test.ps1', ...args])
  5. launch-and-wait.launchAndWait({ mapPath, ... })
       └─ spawn('pwsh', ['-File', 'wait-for-game-ready.ps1'])
       └─ 等待 exitCode
  6. 返回 { ok, pid, scriptError, alerts, durationMs }
       ↓
前端 test-result-panel 显示
```

#### Tab B 一键测试流程

```
用户在 Tab B 点某地图卡片的"一键测试"
       ↓
POST /api/scenario/:id/test
       ↓
scenario.mjs:
  1. stop-sc2.stopAllSc2()
  2. sync-mods-and-maps.syncAll({ mods: scenario.requiredMods, maps: [scenario.mapPath] })
  3. 按 scenario.launchMode:
     - '7vs1-launcher': 调 launch-7vs1-coop-test.ps1
     - 'sc2-switcher': 直接 SC2Switcher_x64.exe <mapPath>
  4. launch-and-wait.launchAndWait(...)
  5. 返回结果
```

#### Mods/Maps 同步流程（独立入口）

```
用户点"同步到游戏目录"
       ↓
POST /api/sync-all  (或 /api/sync-mods, /api/sync-maps)
       ↓
sync.mjs → sync-mods-and-maps.syncAll({ mods, maps, sc2Root, preserveFiles })
       ↓
返回 { copied, skipped, durationMs }
```

## 4. 关键数据结构

### 4.1 maps.json

```json
{
  "scenarios": [
    {
      "id": "ttosh02_7vs1",
      "displayName": "7vs1 合作测试 - ttosh02",
      "type": "7vs1",
      "mapPath": "Maps/ttosh02_7vs1.SC2Map",
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

字段说明：
- `id`：唯一标识，用于 URL
- `type`：`7vs1` 或 `modtest`，决定 Tab
- `launchMode`：`7vs1-launcher`（走 launch-7vs1-coop-test.ps1）或 `sc2-switcher`（直接 SC2Switcher）
- `requiredMods`：mod 名列表（不含 .SC2Mod 后缀），同步时从工作区 `Mods/` 拷贝
- `modSources`：可选，当 mod 不在工作区 Mods/ 时，指定外部源路径
- `defaultArgs`：场景默认参数（commander、masteryLevel 等）
- `tab`：`A` 或 `B`，决定渲染到哪个 Tab

### 4.2 API 响应格式

所有 API 统一返回：

```typescript
interface ApiResponse<T> {
  ok: boolean;
  error?: string;
  data?: T;
}

interface TestResult {
  ok: boolean;
  exitCode: number;       // 0=成功, 1=失败, 2=超时
  pid: number;
  scriptErrorContent: string | null;
  alertsPath: string | null;
  durationMs: number;
  steps: {
    stop: { durationMs: number; killed: number };
    sync: { durationMs: number; copied: number };
    launch: { durationMs: number; args: string[] };
    wait: { durationMs: number; exitCode: number };
  };
}

interface SyncResult {
  copied: number;
  skipped: number;
  durationMs: number;
  details: Array<{ path: string; action: 'copied' | 'skipped' }>;
}
```

## 5. 公共能力模块详细设计

### 5.1 stop-sc2.mjs

```javascript
import { execSync } from 'child_process';

export function stopAllSc2() {
  // tasklist + taskkill /F /IM SC2_x64.exe /IM SC2Switcher_x64.exe
  // 返回 { killed, pids: [] }
}
```

- 用 `tasklist` 列出 SC2_x64.exe 和 SC2Switcher_x64.exe 进程
- 用 `taskkill /F /PID` 逐个杀
- 不抛异常（即使没找到进程也返回 0）

### 5.2 launch-and-wait.mjs

```javascript
import { spawn } from 'child_process';
import { existsSync, readFileSync } from 'fs';

export async function launchAndWait({
  mapPath,
  switcherPath = 'E:/SC2/SC2new/StarCraft II/Support64/SC2Switcher_x64.exe',
  gameLogsPath = 'C:/Users/22448/Documents/StarCraft II/GameLogs',
  maxWaitSeconds = 180,
  gracePeriodSeconds = 20,
}) {
  // 1. spawn SC2Switcher_x64.exe <mapPath>
  // 2. spawn pwsh -File wait-for-game-ready.ps1 -MaxWaitSeconds ...
  // 3. 等待 wait-for-game-ready 退出
  // 4. 读取 ScriptError.txt（如果有）
  // 5. 返回 { ok, exitCode, pid, scriptErrorContent, durationMs }
}
```

- 不重新实现 wait-for-game-ready 的逻辑，直接调用 PowerShell 脚本
- 退出码语义：0=成功, 1=失败（有 ScriptError）, 2=超时

### 5.3 sync-mods-and-maps.mjs

```javascript
import { cpSync, existsSync, readdirSync, statSync } from 'fs';
import { join, resolve } from 'path';

export async function syncAll({
  modNames = [],
  mapPaths = [],
  sc2Root = 'E:/SC2/SC2new/StarCraft II',
  workspaceRoot,
  preserveFiles = ['DocumentHeader', 'DocumentInfo'],
}) {
  // 1. 复制 modNames 中每个 mod: 工作区 Mods/<name>.SC2Mod → sc2Root/Mods/<name>.SC2Mod
  //    - 跳过 preserveFiles 中的文件
  // 2. 复制 mapPaths 中每个 map: 工作区 <mapPath> → sc2Root/Maps/<basename>
  // 3. 返回 { copied, skipped, durationMs, details }
}
```

- 用 `fs.cpSync` 递归复制（Node 16+ 支持）
- 跳过 DocumentHeader / DocumentInfo（与现有 sync-all-to-live.ps1 一致）
- mod 名格式：`<name>.SC2Mod`（如 `CoopZeroPop.SC2Mod`）
- map 可以是目录（解包的 .SC2Map）或文件（MPQ 压缩的 .SC2Map）

## 6. 前端改造

### 6.1 Tab 容器

`index.html` 顶部加 Tab 切换：

```html
<div class="tab-bar">
  <button class="tab active" data-tab="A">7vs1 合作测试</button>
  <button class="tab" data-tab="B">Mod 测试地图</button>
</div>
<div class="tab-content" data-tab-content="A">
  <!-- 现有 7vs1 面板 -->
</div>
<div class="tab-content" data-tab-content="B" hidden>
  <!-- 新增 mod 测试地图列表 -->
</div>
```

### 6.2 Tab B 组件

`components/scenario-panels.js`：

```javascript
export async function renderScenarioCards(scenarios) {
  // 从 /api/scenarios?type=modtest 获取
  // 每个场景一个卡片：
  //   - 显示 displayName、type、requiredMods
  //   - "一键测试" 按钮 → POST /api/scenario/:id/test
  //   - "高级" 展开：单独同步、单独启动、查看所需 mod
}

export function renderTestResult(result) {
  // 显示在 test-result-panel.js
  //   - 成功：绿色，显示 PID、耗时
  //   - 失败：红色，显示 ScriptError 内容
  //   - 超时：黄色，提示人工确认
}
```

### 6.3 现有 Tab A 改造

Tab A 现有的 7vs1 面板保持不动，只把"启动"按钮的 click handler 从直接调 `/api/launch` 改为调 `/api/scenario/:id/test`（一键闭环）。原有 `/api/launch` 等接口保留作为高级展开用。

## 7. 错误处理

- 所有 API 返回 `{ ok, error?, ...data }`
- stop/sync/launch 任一步失败立即返回错误，不继续后续步骤
- launch-and-wait 失败时返回 ScriptError 文件路径 + 内容
- 前端统一在 test-result-panel 显示错误，包含：
  - 失败步骤（stop/sync/launch/wait）
  - 错误消息
  - ScriptError 内容（如果有）
  - 建议的下一步操作

## 8. 测试与验证

| 场景 | 验证点 |
|---|---|
| 启动 web-launcher | http://127.0.0.1:17761/ 能访问，两个 Tab 都能切换 |
| Tab A 跑 7vs1 测试 | 现有行为保持，能成功启动游戏并检测到 Alerts |
| Tab B 跑 abathur_test_map | sc2-switcher 模式启动成功，无 ScriptError |
| Tab B 跑 home_soil | 无 mod 启动成功 |
| 同步按钮 | 点击后 mods 和 maps 同步到游戏目录，文件数正确 |
| 故意触发 ScriptError | 前端能显示错误内容 |
| 杀进程 | 能正确杀掉 SC2_x64.exe |

## 9. 实施顺序

按依赖关系，建议实施顺序：

1. **基础设施**：`package.json`、`server.mjs` 骨架、Express 路由占位
2. **公共能力**：`stop-sc2.mjs`、`sync-mods-and-maps.mjs`、`launch-and-wait.mjs`
3. **场景配置**：`maps.json`、`scenario-registry.mjs`
4. **业务服务**：`commander-metadata.mjs`、`launch-args-builder.mjs`、`bank-snapshot.mjs`、`asset-resolver.mjs`、`mutator-catalog.mjs`
5. **路由**：`bootstrap.mjs`、`scenario.mjs`、`sync.mjs`、`launch.mjs`
6. **前端 Tab**：`index.html` Tab 容器、`scenario-panels.js`、`test-result-panel.js`
7. **启动入口**：`scripts/start-web-launcher.mjs`
8. **测试验证**：按 §8 跑一遍
9. **文档更新**：在 `docs/` 下加 README，说明如何启动

## 10. 风险与缓解

| 风险 | 缓解 |
|---|---|
| `fs.cpSync` 在 Node 16 以下不可用 | package.json 声明 `"engines": { "node": ">=18" }` |
| 路径中包含中文（虫心mod测试地图） | 所有路径操作用 `path.join`，不假设 ASCII |
| `wait-for-game-ready.ps1` 调用失败 | 透传 exitCode，前端按 1/2 分别显示 |
| 现有 Tab A 行为被破坏 | Tab A 的现有组件和 `/api/launch` 路由保留，只增加新的 `/api/scenario/:id/test` |
| PowerShell 脚本路径假设 `$PSScriptRoot` | Node 调用时显式传 `-File` 绝对路径 |
| mods.json 字段缺失 | scenario-registry 加载时做 schema 校验，缺失字段给默认值 |

## 11. 不在范围内

- 不重写 `launch-7vs1-coop-test.ps1` 的 bank 写入逻辑
- 不动 `scripts/old/` 中的 64 个脚本
- 不改 `sc2_unit_explorer.py` / `collect_commander_units.py` / `unpack_maps_batch.py`
- 不引入前端构建工具
- 不删除 `start-7vs1-web-launcher.ps1`（保留作为对照，新代码独立）
