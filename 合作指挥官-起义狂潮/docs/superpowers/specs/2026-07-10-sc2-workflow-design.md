# SC2 依赖优先诊断与自迭代工作流设计文档

- **日期**：2026-07-10
- **状态**：依赖追踪与单位故障诊断版本已实现
- **目标读者**：SC2 Mod/地图维护者、自动化工具维护者、AI Agent
- **实现位置**：`scripts/sc2-editor-toolkit`、`Shared/Workflow/sc2-workflow.json`
- **Skill 位置**：仓库根目录 `.codex/skills/sc2-workflow`

## 1. 背景

现有 SC2 地图与 Mod 诊断流程已经积累了 `galaxy-checker`、`sc2_unit_explorer.py`、
启动器、日志等待脚本和大量经验文档，但真实任务仍常出现以下重复成本：

- 先猜 XML 或 Galaxy，再回头确认依赖链。
- 把地图声明的依赖误当成启动时实际加载的依赖。
- 只看到某个 Catalog ID 的最终值，看不到它被谁定义、继承和覆盖。
- 自定义对战可用，就误判战役图也兼容。
- 每次手工决定要跑哪些检查，容易漏掉完整目录扫描或错误启动方式。
- 新报错只写进经验文档，没有转成配置、解析规则或回归测试。

本设计把这些步骤收敛为一个“依赖优先”的工作流，并通过项目级 Skill 固化执行顺序。
目标不是再造一个全新的 SC2 解析器，而是把现有工具连接成可复用、可验证、可持续迭代
的诊断系统。

## 2. 目标与非目标

### 2.1 目标

1. 在修改前给出声明依赖和有效依赖的父级优先加载顺序。
2. 追踪指定 Catalog ID 的定义、同 ID 覆盖、父级继承和字段历史。
3. 抽取与指定 ID 相关的 Galaxy 字面量运行时修改。
4. 根据改动文件自动生成最小静态验证计划。
5. 明确区分 7vs1 地图和普通 MPQ 地图的运行时验证路径。
6. 把新失败转化为配置、规则、fixture 和测试，使后续工作越来越快、越来越准。
7. 输出稳定 JSON 契约，供 CLI、Skill 和后续 UI/CI 复用。
8. 自动诊断常见生产链、继承技能、命令卡和静态/运行时差异问题。

### 2.2 非目标

- 不完整模拟 SC2 引擎的全部 Catalog 运行时求值。
- 不替代 `galaxy-checker` 的 Galaxy AST/语义检查。
- 不替代 `sc2_unit_explorer.py` 的广域单位关系图查询；新诊断命令只聚焦故障链路。
- 不自动修改地图依赖或 Catalog 数据。
- `check --run` 不自动启动游戏，只声明是否需要运行时验证。
- 不把外部官方依赖缺失伪装成完整结果。

## 3. 核心模型：依赖项是地图的父级

工作流采用以下统一模型：

1. 地图或 Mod 通过 `DocumentInfo` 声明父依赖。
2. 父依赖先加载，子依赖和地图后加载。
3. 子级继承父级已有 Catalog 数据。
4. 后加载包中相同 Catalog + ID 的条目按 SC2 合并语义覆盖或追加字段。
5. `parent` 属性形成 Catalog 类内部的继承链。
6. Galaxy 可在运行时继续修改科技树、能力和 Catalog 字段。

因此，诊断“科技升级不对”“按钮缺失”“单位数据被覆盖”时，必须先回答：

- 实际父依赖是谁？
- 目标 ID 最早由谁定义？
- 哪个后加载包或地图再次定义了相同 ID？
- 子字段按什么键合并？
- 是否还有 Galaxy 运行时修改？

“我想让子地图变成另一个数据集”并不会改变其父级。只有声明依赖、启动时注入或替换、
加载顺序发生变化，实际数据父级才会变化。

## 4. 声明依赖与有效依赖

### 4.1 声明依赖

`inspect` 支持两种项目内已出现的 `DocumentInfo` 格式：

```xml
<Dependencies>
  <Value>file:Mods/Example.SC2Mod</Value>
</Dependencies>
```

```xml
<Dependency value="file:Mods/Example.SC2Mod"/>
```

声明图只反映源包中记录的依赖，不推断启动器行为。

### 4.2 有效依赖

7vs1 启动脚本会替换旧聚合依赖、安装固定运行时层，并根据选中指挥官加入拆分后的
`CommanderUnits_*` 包。因此：

```powershell
node cli.mjs inspect "<map>" --effective --commander TerranRaynor
```

需要应用 `sc2-workflow.json` 中的 effective profile，生成与启动器等价的父级优先
`loadOrder`。

有效依赖图保留两类事实：

- 原始声明仍显示为 `replaced`、`legacy` 或 `needs-selection`。
- 实际加入的包显示为 `effective`，并进入最终加载顺序。

### 4.3 外部依赖

官方 Campaign/Mod 可能不在仓库镜像中。配置可将其标记为 `external`，避免误报为工具
错误，但任何依赖这些包的追踪必须返回 `complete: false`。

## 5. 总体架构

```text
项目级 Skill
    |
    v
sc2-editor-toolkit CLI
    |-- inspect  -> dependencyGraph.mjs
    |-- trace    -> dependencyGraph.mjs + provenance.mjs + CatalogStore
    |-- diagnose-unit -> dependencyGraph.mjs + CatalogStore + unitDiagnostics.mjs
    |-- compare  -> two dependency graphs + two traces + focused differences
    |-- doctor   -> workflow.mjs
    |-- check    -> workflow.mjs validation router
    |-- validate -> 现有 GameData validator
    |-- dump/list-> 现有 CatalogStore 查询
    |
    +-- galaxy-checker          Galaxy AST/语义/跨库检查
    +-- sc2_unit_explorer.py    单位生产、能力、武器和反向关系
    +-- launcher/wait scripts   运行时验证
```

### 5.1 复用原则

- Catalog 合并继续由 `CatalogStore` 负责。
- Unit `parent` 继承展开继续由 `CatalogStore.resolveEntry` 负责。
- Galaxy 静态错误继续由 `galaxy-checker` 负责。
- 单位关系继续由 `sc2_unit_explorer.py` 负责。
- `diagnose-unit` 只聚合生产链、技能、卡牌与局部运行时证据，不复制广域关系浏览器。

## 6. 配置契约

机器可读配置位于：

```text
Shared/Workflow/sc2-workflow.json
```

核心字段：

| 字段 | 作用 |
|---|---|
| `schemaVersion` | 配置版本 |
| `dependencySearchRoots` | 依赖解析搜索根 |
| `externalDependencies` | 可识别但本地不要求存在的官方依赖 |
| `dependencyAliases` | 历史路径或简写到真实包路径的映射 |
| `legacyDependencies` | 旧聚合依赖及其替换策略 |
| `runtimeMutationFunctions` | 项目自定义 Galaxy 包装函数 |
| `effectiveProfiles` | 目标匹配、固定依赖顺序和指挥官依赖映射 |
| `validation` | 相关检查器和启动脚本位置 |

7vs1 profile 的固定依赖顺序必须与启动器同步。新增、拆分、改名或移动运行时 Mod 时，
同时修改配置和依赖图测试，禁止只在 Skill 或文档里硬编码。

## 7. CLI 契约

### 7.1 `inspect`

```powershell
node cli.mjs inspect <map|mod> [--effective] [--commander <id,...>] [--format json|text]
```

JSON 关键字段：

```json
{
  "schemaVersion": 1,
  "target": "...",
  "mode": "declared|effective",
  "profile": "7vs1|null",
  "commanders": [],
  "nodes": [],
  "edges": [],
  "loadOrder": [],
  "issues": []
}
```

`loadOrder` 始终父级在前、目标包在后。节点保留声明依赖、解析路径、状态和替换说明。

### 7.2 `trace`

```powershell
node cli.mjs trace <map|mod> --catalog Unit --id MarineRaynor [--field CardLayouts]
```

JSON 关键字段：

```json
{
  "schemaVersion": 1,
  "catalog": "Unit",
  "id": "MarineRaynor",
  "found": true,
  "definitions": [],
  "effectiveSources": [],
  "parentChain": [],
  "parentCircular": false,
  "unresolvedParent": null,
  "complete": false,
  "incompleteDependencies": [],
  "provenanceMode": "definition-history",
  "fieldProvenance": {},
  "runtimeMutations": [],
  "runtimeScan": {
    "mode": "literal-id-line-scan",
    "complete": false,
    "limitations": []
  },
  "issues": []
}
```

`complete` 只有在依赖没有 `external/missing/legacy/needs-selection` 且 `parent` 可解析时为
`true`。调用方必须展示不完整原因，不能只展示找到的定义。

### 7.3 `doctor`

```powershell
node cli.mjs doctor --format text
```

当前检查：

- 非 ASCII 项目路径。
- 无效嵌套 `.git`。
- 关键工具缺失。
- README/DESIGN 中已失效的路径。
- 旧依赖声明和未解析依赖数量。
- `CoreRuntime` 与 `CoopZeroPop` 同路径 Galaxy 文件分叉。

Doctor 的 warning 是维护线索，不等同于当前任务失败。

### 7.4 `compare`

```powershell
node cli.mjs compare <left-map-or-mod> <right-map-or-mod> \
  --catalog Upgrade --id <id> [--field <path-fragment>]
```

左右两侧可独立使用 `--left-effective`、`--right-effective`、
`--left-commander` 和 `--right-commander`。依赖不完整时默认返回 exit 1；只有调用者显式
传入 `--allow-incomplete` 才允许 exit 0。输出包含：

- 两侧完整 trace。
- 总体 `status: complete|incomplete|missing` 和 `complete`。
- 两侧缺失依赖及 unresolved parent。
- 仅包含值或来源发生变化的 `fieldDifferences`。
- 只在左侧或右侧出现的运行时修改。
- `runtimeScanComplete`，避免把空修改列表误解为已证明无运行时修改。
- `comparisonMode: definition-history`，避免误解为完整引擎执行结果。

该命令用于直接回答“战役图和自定义对战为什么不一致”，减少手工拼接两份长 trace。

### 7.5 `diagnose-unit`

```powershell
node cli.mjs diagnose-unit <map|mod> `
  --unit MarineRaynor `
  --producer BarracksRaynor `
  --expect-ability SuperStimpackMarineRaynor `
  [--effective] [--commander TerranRaynor] [--allow-incomplete]
```

该命令针对最常见的“造不出来、造出来没技能、XML 与游戏内不一致”问题，一次完成：

- 展开 Unit `parent` 链，生成继承后的 `AbilArray` 与 `CardLayouts`。
- 反查 `CAbilTrain/CAbilBuild/CAbilMorph.InfoArray` 中指向目标单位的槽位。
- 验证指定生产者是否拥有生产能力及匹配的 `AbilCmd` 按钮。
- 标记静态 Requirement 和 `Restricted` 状态。
- 验证预期能力是否有 Catalog 定义、是否静态/继承存在、是否缺按钮。
- 扫描 `TechTreeUnitAllow`、`TechTreeAbilityAllow`、`UnitAbilityAdd/Remove` 和
  `CatalogFieldValueSet*`。
- 在静态能力上叠加检测到的运行时添加/移除，输出 `effectiveAbilities`。

JSON 关键字段：

```json
{
  "schemaVersion": 1,
  "status": "ok|incomplete|error",
  "complete": true,
  "hasErrors": false,
  "unit": {
    "parentChain": [],
    "staticAbilities": [],
    "runtimeAddedAbilities": [],
    "runtimeRemovedAbilities": [],
    "effectiveAbilities": [],
    "cards": []
  },
  "production": {
    "targetSlots": [],
    "candidates": [],
    "selected": null
  },
  "runtime": {
    "events": [],
    "unitTech": {},
    "abilityTech": {},
    "catalogMutations": [],
    "scan": {}
  },
  "issues": []
}
```

`complete` 只表示依赖边界是否完整，`hasErrors` 表示是否发现行为错误。默认任一
`hasErrors: true` 或 `complete: false` 都返回 exit 1；只有依赖不完整但没有诊断 error
时，`--allow-incomplete` 才允许 exit 0。

核心 issue code 包括：

- `PRODUCTION_SLOT_MISSING`
- `PRODUCTION_PRODUCER_MISSING`
- `PRODUCER_MISSING_PRODUCTION_ABILITY`
- `PRODUCTION_BUTTON_MISSING`
- `PRODUCTION_REQUIREMENT_GATED`
- `EXPECTED_ABILITY_MISSING`
- `EXPECTED_ABILITY_BUTTON_MISSING`
- `UNIT_TECH_LOCKED_RUNTIME`
- `PRODUCTION_ABILITY_LOCKED_RUNTIME`
- `EXPECTED_ABILITY_LOCKED_RUNTIME`
- `STATIC_RUNTIME_DIVERGENCE`

### 7.6 `check`

```powershell
node cli.mjs check [files...] [--changed] [--run] [--format json|text]
```

`check` 先生成计划，再可选执行静态动作。Windows 下 npm/npx 通过当前 `node.exe` 直接
运行 npm CLI，避免 `.cmd` 的 `spawnSync EINVAL`。

## 8. Catalog 来源追踪

### 8.1 定义历史

对 `loadOrder` 中每个包：

1. 递归读取 `Base.SC2Data/GameData/**/*.xml`。
2. 把所有 Catalog 条目按加载顺序加入 `CatalogStore`，保证目标条目的 `parent` 可解析。
3. 对目标 Catalog + ID 记录定义位置、类 tag、parent、removed 和字段展开结果。
4. 使用稳定字段路径记录覆盖历史。

字段路径优先使用 SC2 合并键：

```text
id
index
Row+Column
Array.value
Link
```

例如：

```text
CardLayouts[index=0]/LayoutButtons[Row=2,Column=0]/@AbilCmd
```

### 8.2 合并语义

当前 `CatalogStore` 覆盖：

- 顶层 `(catalog, id)` 合并。
- 后加载属性覆盖。
- `id/index/Row+Column/Array.value/Link` 键控子元素合并。
- 无键叶子标量按同 tag 覆盖。
- `removed="1"` 删除匹配子元素。
- 无键复合子元素追加。
- 无 index 的 `CardLayouts` 规范化为 `index="0"`。

### 8.3 来源模式边界

当前 `fieldProvenance` 是目标 ID 的定义历史，不是完整的继承后最终字段快照。父条目可
正确出现在 `parentChain` 中。`CatalogStore.resolveEntry` 已能为 `diagnose-unit` 展开
继承后的 Unit 节点，但 `trace.fieldProvenance` 仍不把继承字段重新标成目标 ID 的定义
历史；Requirement 求值和所有引擎默认值也仍需后续版本展开。因此 trace 结果明确标记：

```text
provenanceMode: definition-history
```

## 9. Galaxy 运行时修改抽取

`trace` 递归扫描有效依赖链的 `Base.SC2Data/**/*.galaxy`，查找：

- `CatalogFieldValueSet*`
- `TechTreeUnitAllow`
- `TechTreeAbilityAllow`
- `UnitAbilityAdd`
- `UnitAbilityRemove`
- 配置中的项目包装函数

`trace` 只追踪同一行中包含目标 ID 字符串字面量的调用。返回函数名、文件、行号和原始
文本。

`diagnose-unit` 增加面向单位故障的局部上下文扫描：当附近出现
`UnitGetType(...) == "<unit-id>"` 时，把随后的 `UnitAbilityAdd/Remove` 归属到该单位，
并单独输出 `confidence: context-inferred`。原生函数名和带项目前缀的包装函数均可识别。

该策略强调低误报和可解释性，不尝试跨函数数据流。变量传递、字符串拼接和运行时生成
的 ID 属于已知限制。

## 10. 改动文件验证路由

`buildValidationPlan` 按文件类型生成最小动作集合：

| 改动 | 静态动作 | 运行时要求 |
|---|---|---|
| `.galaxy` / `_h.galaxy` | 对整个 `Base.SC2Data` 运行 galaxy-checker | 地图/7vs1 运行时改动需要 |
| GameData `.xml` | 对包和已解析父依赖运行 validator | 地图/7vs1 运行时改动需要 |
| toolkit 源码/测试 | `npm test` | 不需要 |
| galaxy-checker 源码/测试 | checker 测试套件 | 不需要 |
| web-launcher | launcher 测试套件 | 不需要 |
| Skill/配置/设计文档 | 结构校验或相关工具测试 | 不需要，除非改变运行时数据 |

在脏工作区中优先传入当前任务的显式文件列表，避免把用户未提交改动的失败混入本任务。

## 11. 运行时验证决策

### 11.1 7vs1 地图

1. 使用专用启动脚本安装/注入有效依赖。
2. 若游戏已运行，先重启。
3. 运行并等待 `wait-for-game-ready.ps1`。
4. exit 1 或 exit 2 都不能视为完成。
5. ScriptError 必须先修复；若 checker 漏报，先补 checker 规则和回归测试。

### 11.2 普通 MPQ 地图

1. 禁止使用 7vs1 启动器。
2. 使用 `SC2Switcher_x64.exe "<map.SC2Map>"`。
3. 等待至少 45 秒。
4. 确认 `SC2_x64` 存活。
5. 检查新生成的 `ScriptError.txt`。

错误启动方式会注入原地图不存在的 70+ Galaxy 库，制造“函数已声明但尚未定义”等假故障。

## 12. Skill 编排

项目级 `$sc2-workflow` Skill 固化以下顺序：

```text
保护工作区
  -> 分类地图/Mod
  -> inspect 声明或有效依赖
  -> diagnose-unit 聚合生产/技能/卡牌/运行时故障
  -> trace 仍有歧义的 Catalog ID/字段
  -> 必要时运行 unit explorer 扩展广域关系
  -> 最小根因修复
  -> check 路由静态验证
  -> 按地图类型进图
  -> 将新失败固化为规则/配置/fixture/测试
```

Skill 不复制庞大的指挥官映射和工具实现，只引用机器可读配置和稳定 CLI，从而减少每次
会话的 token 消耗并避免提示词事实过期。

## 13. 自迭代闭环

工作流的成熟度由“下一次是否自动更快发现同类问题”衡量。

### 13.1 闭环步骤

1. **观察**：保留 ScriptError、CLI issue、错误地图和依赖上下文。
2. **复现**：提取最小 fixture 或锁定真实文件与命令。
3. **分类**：依赖、合并、来源、Galaxy、路由、编辑器路径或纯运行时。
4. **编码**：
   - 依赖变化写入 `sc2-workflow.json`。
   - Galaxy 漏报写入 checker 规则/解析器。
   - Catalog 误判写入 toolkit 合并或 provenance。
   - 错误测试路径写入 validation router。
5. **回归**：新增先失败后通过的自动化测试。
6. **验证**：窄测试、完整相关套件、必要时进图。
7. **总结**：实际踩坑写入 `docs/经验总结`，但文档不能替代机器规则。

### 13.2 完成标准

一个新问题只有同时满足以下条件才算“被工作流吸收”：

- 同类输入下工具能自动检测、追踪或选择正确验证路径。
- 存在回归测试或机器可读配置。
- 输出解释包含证据位置。
- 不依赖某次会话中的隐含记忆。

## 14. 测试策略

### 14.1 单元测试

- 两种依赖格式解析。
- 父级优先拓扑顺序与循环检测。
- 7vs1 legacy/effective 替换与指挥官选择。
- Catalog 标量、数组、`removed`、CardLayouts 合并。
- 字段路径稳定性。
- 同 ID 定义历史。
- parent 链解析和循环。
- Galaxy 字面量运行时修改。
- Unit `parent` 继承后的能力与卡牌。
- Train/Build/Morph 生产槽、生产者能力和命令卡组合。
- 预期技能缺失、按钮缺失和 Requirement/Restricted 状态。
- Galaxy 能力注入、移除、科技锁定和静态/运行时差异。
- `diagnose-unit` JSON、退出码与 `--allow-incomplete`。
- 两个环境的字段与运行时差异比较。
- 无 GameData 包的容错。
- changed-file 路由。
- Windows npm/npx 执行路径。

### 14.2 真实烟测

- 对 `ttosh02_7vs1.SC2Map` 运行 effective inspect。
- 追踪 `MarineRaynor` 的 `CardLayouts`。
- 运行 doctor。
- 用显式 toolkit 文件运行 `check --run`。

### 14.3 关联套件

工具修改完成后至少运行：

- `scripts/sc2-editor-toolkit` 测试。
- `scripts/galaxy-checker` 测试。
- `web-launcher` 测试。
- Skill `quick_validate.py`。

本任务未修改地图或 Galaxy 运行时，不要求进图测试。

## 15. 已知限制

1. 官方外部 Campaign/Mod 可能不可用，导致 `complete: false`。
2. 字段来源是 definition history，不是完整的 SC2 继承后运行时求值。
3. Galaxy 只追踪字符串字面量，不能静态解析变量传递和动态 ID。
4. 源地图依赖和启动器 live 注入链可能不同，必须显式选择 `--effective`。
5. Actor 数据不在当前来源追踪的核心范围。
6. `trace` 为解析 parent 会加载依赖链中的全部 GameData；超大依赖链后续可加缓存。
7. 普通 MPQ 内部结构仍需解包后才能参与完整静态追踪。
8. 当前不直接读取 CASC/游戏归档，官方 Campaign 缺失时需先建立目录镜像。
9. 中文名称反查和完整 Button/Abil/Upgrade/Requirement 科技链仍需人工串联；已知
   ASCII ID 后的生产/技能/卡牌故障可由 `diagnose-unit` 自动聚合。
10. 当前没有反向影响范围索引，定义所有权仍需结合消费地图和指挥官判断。
11. `diagnose-unit` 的 UnitAbility 局部上下文不跨函数、不建控制流图，复杂变量传播仍
   需人工检查。

## 16. 后续演进

优先级从高到低：

1. 将 `resolveEntry` 的继承结果扩展到通用 trace 字段来源，区分
   inherited/overridden/removed。
2. 给 Galaxy 修改增加有限的局部变量与常量传播。
3. 增加 `find-id`，从本地化名称反查 Button/Abil/Upgrade/Requirement。
4. 增加 `trace-tech`，自动串联 Button/AbilCmd/InfoArray/Upgrade/Requirement/TechTreeAllow。
5. 支持 MPQ 与 CASC 只读提取缓存，补齐官方 Campaign 依赖镜像。
6. 支持可命名的 campaign/custom-melee/7vs1 profile 和显式依赖清单。
7. 对配置与启动脚本做顺序一致性测试，防止 profile 漂移。
8. 扩展 `diagnose-unit` 到 Upgrade/Requirement 的布尔求值和科技前置解释。
9. 建立反向消费索引，输出一个 Catalog 定义影响的地图、指挥官和 Adapter。
10. 引入内容哈希缓存，避免重复解析未变化的官方镜像。

任何新能力都继续遵循同一原则：先用真实失败定义验收场景，再增加规则和回归测试，避免
只扩展命令数量而不提高诊断准确率。
