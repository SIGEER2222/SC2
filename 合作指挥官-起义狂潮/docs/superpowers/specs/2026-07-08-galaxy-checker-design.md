# Galaxy 脚本静态检查器 设计文档

- **日期**：2026-07-08
- **状态**：已批准，待复核
- **作者**：brainstorming skill
- **目标读者**：实现者（含 AI Agent）

## 1. 背景与动机

项目在迁移/编写 SC2 Galaxy 脚本过程中，反复踩到一类语法/语义错误，这些错误只有在
地图编译时才暴露，每次进图测试要等几十秒甚至几分钟，反馈周期长、调试成本高。
典型高频错误（来自项目 memory 经验总结）：

- `函数已声明但尚未定义`：调用了不存在的函数（如直接 `UnitCreate` 或未声明的 `libXXX_yyy`）
- `continue` 语句被 Galaxy 编译器拒绝，需用 `if` 块包裹
- `局部变量不能用 = 初始化`：必须先声明再赋值
- `void 返回函数用在条件表达式里`：`CommanderPowerSetUpgradeAtLeast` 等
- `函数参数数量不匹配`：`UnitCreate` 误用导致"参数数量不对"
- `调用不存在的 native 函数`：`UnitIsHero()`、`UnitIsStructure()` 等
- `跨库引用前缀错`：用 `libKMIS_` 引用了 `libE0EAE146_` 库的符号
- `文件含 UTF-8 BOM`：导致库初始化失败
- `include 文件不存在`

现有的 `scripts/old/validate-galaxy-scripts.py` 基于正则做浅层检查，能 catch 上述部分
问题但精度有限（函数签名、作用域、参数数量等无法可靠解析）。

本设计目标：构建一个**真正的 AST 解析器**，让 AI Agent 在写完 Galaxy 代码后调用
该工具做完整静态检查，**在进图测试前**把绝大多数语法/语义错误暴露出来。

## 2. 范围

### 2.1 主目标

AI Agent 可调用的**库 + CLI**：写完代码后调用解析器做静态校验，返回结构化错误
（行号、列号、错误类型、消息）。不依赖 IDE，可直接在当前会话或 CI 里跑。

### 2.2 非目标（YAGNI）

明确不做以下事项，避免范围蔓延：

- 代码格式化 / 美化
- 代码重构 / 自动修复
- 自动补全 / hover 提示 / 跳转定义
- 类型推断（只做基本类型校验，不做跨函数流分析）
- 静态执行模拟（不模拟运行时行为）
- 解析 XML 数据（已有 `sc2_unit_explorer.py` 处理）
- VSCode/LSP 集成（除非后续明确要求；本设计不阻塞该路径，但当前阶段不做）
- 缓存机制（项目规模小，单进程一次跑完）
- 自动修复建议（用户明确选择"只报错（位置+消息）"粒度）

### 2.3 检查深度

按用户选择，做到**语法 + 语义 + 跨库/native** 完整层：

- 语法层：约覆盖 60% 高频错误
- 语义层（含作用域、参数数量）：累计约 80-85%
- 跨库/native 检查：累计 95%+，含项目踩过的所有坑

## 3. 技术栈

| 组件 | 选型 | 理由 |
|---|---|---|
| 实现语言 | TypeScript（严格模式） | 与项目现有 `build-*.mjs` 一致，AI 可直接 import |
| 解析器 | **Chevrotain** | 纯 JS、零 native 依赖、Windows 友好、自带错误恢复 |
| 运行时 | Node.js | 与项目生态一致 |
| 测试 | vitest（可选） | 轻量、与 TS 集成好 |
| 依赖管理 | npm | 最小依赖：chevrotain + typescript + vitest |

### 3.1 为何选 Chevrotain（不选 tree-sitter）

经过实际调研：

- **社区资源**：GitHub 搜 `tree-sitter galaxy starcraft` = 0 仓库，社区无现成 Galaxy grammar
- **tree-sitter 在 Node.js**：是 native binding（C 扩展），需 node-gyp 编译；自写流程为
  `grammar.js` → `tree-sitter generate` → `tree-sitter build` → 打包 npm
- **Chevrotain**：纯 JS、零编译、Windows 稳定、文档明确支持错误恢复
- 项目环境对 native binding 较敏感（memory 多次记录 CASC 索引、依赖路径、文件编码等问题）
- 用户已选"AI 调用库/CLI"路径，不需要 LSP 过渡，tree-sitter 的 LSP 优势不触发
- 一次性投入与 tree-sitter 相当（1-2 天），但运行依赖更轻

### 3.2 未来上 LSP 的路径

本设计不阻塞后续 LSP 化：

- 解析器、分析器、规则引擎与 CLI 解耦
- 后续若做 LSP，可包装一层 `vscode-languageserver` 调用现有 `analyze()` API
- 不需要重写解析器

## 4. 总体架构

```
┌─────────────────────────────────────────────────────┐
│  CLI: galaxy-check <file|dir> [--format json|text]  │
│  AI 通过 subprocess 调用                              │
└─────────────┬───────────────────────────────────────┘
              ▼
┌─────────────────────────────────────────────────────┐
│  Checker Core (TS lib，也可被 import)               │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │ 1. Project Loader                            │   │
│  │   - 扫描同目录所有 Lib*.galaxy 建全局符号表  │   │
│  │   - 加载 native 表（解析 NativeLib.galaxy）   │   │
│  │   - 加载项目规则 JSON                         │   │
│  └──────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────┐   │
│  │ 2. Parser (Chevrotain)                        │   │
│  │   - 生成 AST + 语法错误（错误恢复强）          │   │
│  └──────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────┐   │
│  │ 3. Semantic Analyzer                         │   │
│  │   - 作用域符号表构建                          │   │
│  │   - 未声明变量/重复定义检查                    │   │
│  │   - 函数参数数量检查（对照 native 表签名）     │   │
│  │   - native 函数存在性对照                     │   │
│  │   - 跨库符号引用解析                           │   │
│  │   - 项目规则（continue禁用、void在条件、BOM等）│   │
│  └──────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────┐   │
│  │ 4. Issue Reporter                             │   │
│  │   - JSON / 人类可读文本                        │   │
│  │   - exit code: 0=clean, 1=issues, 2=工具异常  │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### 4.1 核心设计原则

- **单进程一次跑完**：不缓存，项目规模小，几秒内可扫完所有 Lib*.galaxy
- **JSON 优先**：AI 默认拿 JSON；开发调试可加 `--format text`
- **规则与代码解耦**：项目规则放 JSON，新增"踩坑规则"不改代码
- **错误恢复优先**：解析器遇到一处错不中断，尽量一次报多个问题
- **最小依赖**：仅 `chevrotain` + dev 依赖

## 5. 目录布局

放在 `合作指挥官-起义狂潮/scripts/galaxy-checker/` 下作为独立子项目：

```
scripts/galaxy-checker/
├── package.json              # chevrotain 依赖 + 脚本入口
├── tsconfig.json
├── README.md                 # 使用说明
├── src/
│   ├── cli.mjs               # CLI 入口
│   ├── index.ts              # 库导出 API
│   ├── lexer/
│   │   └── tokens.ts         # Chevrotain token 定义（C-like）
│   ├── parser/
│   │   ├── GalaxyParser.ts   # Chevrotain 规则定义
│   │   └── ast.ts            # AST 节点类型定义
│   ├── analyzer/
│   │   ├── SymbolTableBuilder.ts   # 作用域符号表构建
│   │   ├── SemanticAnalyzer.ts     # 语义检查
│   │   ├── NativeFunctionTable.ts  # native 函数表加载与查询
│   │   ├── ProjectLoader.ts        # 扫描同目录所有 Lib*.galaxy 建全局符号表
│   │   └── RuleEngine.ts           # 项目规则引擎
│   ├── reporter/
│   │   └── IssueReporter.ts        # JSON / 人类可读输出
│   └── types.ts                    # Issue/Severity/RuleCode 等共享类型
├── data/
│   ├── native-blacklist.json       # 项目踩坑黑名单（UnitIsHero 等）
│   └── project-rules.json          # 项目规则配置
└── tests/
    ├── fixtures/                   # 含已知错误的 galaxy 测试文件
    └── *.test.ts                   # 单元测试
```

## 6. 组件清单

| 组件 | 职责 | 输入 | 输出 |
|---|---|---|---|
| Lexer | 词法分析，识别 C-like token | 源码字符串 | Token 流 |
| Parser | 语法分析，构造 AST | Token 流 | AST + 语法错误 |
| AST | 节点类型定义 | - | TS 类型 |
| SymbolTableBuilder | 构建作用域符号表 | AST | SymbolTable |
| SemanticAnalyzer | 语义检查 | AST + SymbolTable | Issue 列表 |
| NativeFunctionTable | native 函数签名加载 | NativeLib.galaxy + blacklist JSON | 签名表 |
| ProjectLoader | 扫描所有 Lib*.galaxy | 目录路径 | 全局符号表 |
| RuleEngine | 应用项目规则 | AST + 规则 JSON | Issue 列表 |
| IssueReporter | 输出格式化 | Issue 列表 | JSON/text |
| CLI | 命令行入口 | argv | exit code |

## 7. 数据流

```
CLI argv
   ↓
ProjectLoader 扫描同目录所有 Lib*.galaxy
   ↓
NativeFunctionTable 解析 NativeLib.galaxy + 加载 blacklist JSON
   ↓
全局符号表初始化（收集所有函数/变量/触发器定义）
   ↓
对每个目标文件：
   ├─ Lexer → Token 流
   ├─ Parser → AST + 语法错误
   ├─ SymbolTableBuilder → 局部符号表（含全局表回链）
   ├─ SemanticAnalyzer → 语义 Issue
   └─ RuleEngine → 规则 Issue
   ↓
IssueReporter 汇总并格式化输出
   ↓
exit code (0/1/2)
```

## 8. 检查项清单

按规则代码分组，每条规则对应一个 RuleCode。所有规则可在 `project-rules.json` 中
开关 / 调整严重级别。

### 8.1 语法层（SYNTAX_*）

| RuleCode | 描述 | 严重级 | 来源 |
|---|---|---|---|
| `SYNTAX_BRACE_MISMATCH` | 括号 `{}()[]` 不匹配 | error | 现有 .py 已覆盖 |
| `SYNTAX_MISSING_SEMICOLON` | 语句缺分号 | error | 新增 |
| `SYNTAX_UNCLOSED_STRING` | 字符串未闭合 | error | 新增 |
| `SYNTAX_INVALID_TOKEN` | 无法识别的字符 | error | 新增 |
| `SYNTAX_NO_CONTINUE` | `continue` 语句被 Galaxy 拒绝 | error | memory 踩坑 |
| `SYNTAX_NO_LOCAL_INIT_ASSIGN` | 局部变量不能用 `=` 初始化 | error | memory 踩坑 |

### 8.2 语义层（SEM_*）

| RuleCode | 描述 | 严重级 | 来源 |
|---|---|---|---|
| `SEM_UNDECLARED_VARIABLE` | 引用未声明的变量 | error | 新增 |
| `SEM_UNDECLARED_FUNCTION` | 调用未声明的函数 | error | 新增 |
| `SEM_DUPLICATE_DECLARATION` | 同作用域重复定义 | error | 新增 |
| `SEM_ARGUMENT_COUNT_MISMATCH` | 函数参数数量不匹配 | error | memory 踩坑 |
| `SEM_VOID_IN_CONDITION` | void 返回函数用在条件表达式 | error | memory 踩坑 |
| `SEM_RETURN_TYPE_MISMATCH` | return 类型与函数签名不符 | warning | 新增 |
| `SEM_ASSIGNMENT_TYPE_MISMATCH` | 赋值类型不匹配（基础类型） | warning | 新增 |

### 8.3 跨库/Native 层（XLIB_*）

| RuleCode | 描述 | 严重级 | 来源 |
|---|---|---|---|
| `XLIB_UNDEFINED_CROSS_REF` | 跨库引用未定义的 `libXXX_` 符号 | error | memory 踩坑 |
| `XLIB_DISALLOWED_NATIVE` | 调用不存在的 native 函数 | error | memory 踩坑 |
| `XLIB_MISSING_INCLUDE` | include 文件不存在 | warning | 现有 .py 已覆盖 |

### 8.4 项目规则层（PROJ_*）

| RuleCode | 描述 | 严重级 | 来源 |
|---|---|---|---|
| `PROJ_UTF8_BOM` | 文件含 UTF-8 BOM | error | memory 踩坑 |
| `PROJ_ENCODING_INVALID` | 文件非 UTF-8 编码 | warning | memory 踩坑 |

> 项目规则与 RuleEngine 解耦：上述规则可在 `project-rules.json` 中关闭或调级。
> 新增"踩坑规则"时只需在 JSON 加一条 + 在 RuleEngine 加对应检测函数，不动核心。

## 9. 规则配置格式（`project-rules.json`）

```json
{
  "version": "1.0",
  "rules": {
    "SYNTAX_NO_CONTINUE": {
      "severity": "error",
      "message": "Galaxy 不支持 continue 语句，请用 if 块包裹"
    },
    "SYNTAX_NO_LOCAL_INIT_ASSIGN": {
      "severity": "error",
      "message": "Galaxy 局部变量不能用 = 初始化，必须先声明再赋值"
    },
    "SEM_VOID_IN_CONDITION": {
      "severity": "error",
      "message": "void 返回函数不能用在条件表达式"
    },
    "XLIB_DISALLOWED_NATIVE": { "severity": "error" },
    "PROJ_UTF8_BOM": {
      "severity": "error",
      "message": "文件含 UTF-8 BOM（会导致库初始化失败）"
    }
  },
  "nativeBlacklistFile": "native-blacklist.json",
  "globalSymbolGlobs": ["Lib*.galaxy"],
  "nativeLibPath": "TriggerLibs/NativeLib.galaxy"
}
```

**设计要点**：

- `severity` 可选：`error` / `warning` / `info` / `off`
- `message` 可覆盖默认消息
- `nativeBlacklistFile` 指向黑名单 JSON 文件
- `globalSymbolGlobs` 控制全局符号扫描范围
- `nativeLibPath` 指向 native 函数声明文件路径（相对/绝对均可）

## 10. native 函数黑名单（`native-blacklist.json`）

```json
{
  "version": "1.0",
  "disallowedNatives": [
    "UnitIsHero",
    "UnitIsStructure",
    "PlayerIsEnemy",
    "PlayerNumberAny",
    "PlayerIsActive",
    "TriggerAddEventUnitBorn"
  ],
  "notes": {
    "UnitIsHero": "Galaxy 不存在此 native，请用 libNtve_gf_UnitIsHero() 等包装",
    "UnitCreate": "不应直接调用，请用 libNtve_gf_CreateUnitsAtPoint2 包装"
  }
}
```

**说明**：`UnitCreate` 在 native 表中存在但项目规则禁止直接用，所以也列入黑名单
（区别于"不存在"的 native）。`XLIB_DISALLOWED_NATIVE` 规则统一报错。

## 11. 输出格式

### 11.1 JSON 输出（默认，AI 友好）

```json
{
  "version": "1.0",
  "tool": "galaxy-checker",
  "filesChecked": 42,
  "summary": {
    "errors": 3,
    "warnings": 1,
    "infos": 0
  },
  "issues": [
    {
      "file": "LibE0EAE146_TychusRuntime.galaxy",
      "line": 245,
      "column": 12,
      "ruleCode": "XLIB_DISALLOWED_NATIVE",
      "severity": "error",
      "message": "调用了不允许的 native 函数 'UnitIsHero()'"
    },
    {
      "file": "LibKMIS.galaxy",
      "line": 1,
      "column": 1,
      "ruleCode": "PROJ_UTF8_BOM",
      "severity": "error",
      "message": "文件含 UTF-8 BOM（会导致库初始化失败）"
    }
  ]
}
```

### 11.2 文本输出（`--format text`）

```
[ERROR] LibE0EAE146_TychusRuntime.galaxy:245:12  XLIB_DISALLOWED_NATIVE
        调用了不允许的 native 函数 'UnitIsHero()'

[ERROR] LibKMIS.galaxy:1:1  PROJ_UTF8_BOM
        文件含 UTF-8 BOM（会导致库初始化失败）

总计: 3 错误, 1 警告
```

### 11.3 Exit Code

- `0`：无 error 级 issue（warning/info 不影响 exit code，AI 拿到 JSON 自行决策）
- `1`：存在 error 级 issue
- `2`：工具自身异常（文件读不到、解析器崩溃等）

> 设计决策：exit code 仅反映 error 级。理由是 AI 主要看 JSON 内容做决策，
> exit code 仅作为"是否有阻断性错误"的快速信号；warning 让 AI 看消息再决定是否处理。

## 12. CLI 接口

```
用法:
  galaxy-check <file|dir> [options]

参数:
  <file|dir>              目标文件或目录（目录递归扫 Lib*.galaxy）

选项:
  --format <json|text>    输出格式，默认 json
  --rules <path>          项目规则 JSON 路径，默认 data/project-rules.json
  --native-lib <path>     NativeLib.galaxy 路径
  --no-global-symbols     跳过全局符号表构建（仅做单文件语法检查）
  --quiet                 仅输出 issue，无汇总行
  --help                  显示帮助

示例:
  # 检查单个文件
  galaxy-check LibE0EAE146_TychusRuntime.galaxy

  # 检查整个 mod 目录
  galaxy-check Mods/7vs1/CoopZeroPop.SC2Mod/Base.SC2Data --format text

  # AI 调用（JSON 输出，便于解析）
  galaxy-check <file> --format json
```

## 13. 库 API

```typescript
// src/index.ts
export interface Issue {
  file: string;
  line: number;
  column: number;
  ruleCode: string;
  severity: 'error' | 'warning' | 'info';
  message: string;
}

export interface CheckResult {
  filesChecked: number;
  issues: Issue[];
  summary: { errors: number; warnings: number; infos: number };
}

export interface CheckOptions {
  rulesPath?: string;        // 默认 data/project-rules.json
  nativeLibPath?: string;    // 默认 TriggerLibs/NativeLib.galaxy
  globalSymbolGlobs?: string[]; // 默认 ['Lib*.galaxy']
  noGlobalSymbols?: boolean;
}

// 主入口
export function check(target: string, options?: CheckOptions): CheckResult;

// 也可单独使用解析器
export function parse(source: string, filename?: string): {
  ast: AST;
  errors: Issue[];
};
```

## 14. Galaxy 语法覆盖范围

参考 `docs/银河编辑器/Galaxy脚本错误码参考.md` 与项目实际使用的语法子集：

### 14.1 必须支持

- 类型：`void/int/bool/unit/point/string/real/fixed/wave/group/region/location/timer/
  trigger/bank/text/unitfilter/unitgroup/playergroup/actor/sound/effect/behavior/
  abilcmd/order/pathing/doodad/camera/quest/dialog/image/movie/model/footprint/object/
  transmissionsource/transmission/planet/conversation/accomplishment/score/airgroup/
  groundgroup/anygroup`
- 修饰符：`const`、`native`、`static`
- 声明：函数 `void f() {}`、变量 `int x;`、`trigger t;`、`struct`
- 控制流：`if/else/while/for/break/return`（不允许 `continue`）
- 表达式：算术、比较、逻辑、位运算、函数调用、成员访问、数组下标
- 字面量：整数、固定点（`1.5f`）、字符串、字符、`true/false/null`
- 注释：`//` 行注释、`/* */` 块注释
- 预处理：`include "xxx.galaxy"`
- struct、enum（基础支持）

### 14.2 可选支持（视实际使用情况）

- `libNtve_gf_*` 等带前缀的库函数（按普通函数调用处理即可）
- 数组初始化语法
- 复杂的 typedef / using

### 14.3 不支持

- C 风格宏（`#define`）
- 预处理器条件（`#ifdef`）

## 15. 测试策略

### 15.1 单元测试

- Lexer：每个 token 类型独立测试
- Parser：每条语法规则独立测试
- 各 Analyzer：每个 RuleCode 独立测试

### 15.2 集成测试

- 用项目实际 `Lib*.galaxy` 文件做端到端检查
- 与现有 `validate-galaxy-scripts.py` 输出做兼容性对比（保证不退化）

### 15.3 回归测试（关键）

把项目 memory 里记录的每个踩坑场景都做成 fixture：

```
tests/fixtures/regression/
├── no-continue.galaxy              # continue 语句 → SYNTAX_NO_CONTINUE
├── local-var-init.galaxy           # int x = 1; → SYNTAX_NO_LOCAL_INIT_ASSIGN
├── unit-ishero-native.galaxy       # UnitIsHero() → XLIB_DISALLOWED_NATIVE
├── unitcreate-direct.galaxy        # UnitCreate() → XLIB_DISALLOWED_NATIVE
├── void-in-condition.galaxy        # if (CommanderPowerSet...) → SEM_VOID_IN_CONDITION
├── utf8-bom.galaxy                 # BOM 头 → PROJ_UTF8_BOM
├── cross-lib-undefined.galaxy      # libKMIS_xxx 引用未定义 → XLIB_UNDEFINED_CROSS_REF
├── arg-count-mismatch.galaxy       # 参数数量错 → SEM_ARGUMENT_COUNT_MISMATCH
└── undeclared-symbol.galaxy        # 未声明变量 → SEM_UNDECLARED_VARIABLE
```

每个 fixture 配一个 `.expected.json` 描述期望的 issue 输出。

### 15.4 验收标准

- 所有 regression fixture 全部通过
- 对项目当前所有 `Lib*.galaxy` 跑一遍，无新增误报（与 .py 工具一致的报错必须保留）
- 单文件检查延迟 < 200ms（项目规模内）

## 16. 实施分阶段

建议分 4 个阶段交付，每阶段都可独立验证：

### 阶段 1：MVP（语法检查）

- Lexer + Parser（Chevrotain）
- AST 类型定义
- 语法层规则（SYNTAX_*）
- CLI + JSON 输出
- 通过：能 catch 括号、分号、continue、BOM 等语法错误

### 阶段 2：语义检查

- SymbolTableBuilder
- SemanticAnalyzer（SEM_*）
- 通过：能 catch 未声明、重复定义、参数数量错、void 在条件

### 阶段 3：跨库/Native

- NativeFunctionTable 加载
- ProjectLoader 全局符号表
- XLIB_* 规则
- 通过：能 catch libXXX_ 未定义、disallowed native

### 阶段 4：打磨

- 文本输出格式
- README 与使用文档
- 与现有 .py 工具对比测试
- 性能优化（如有必要）

## 17. 风险与缓解

| 风险 | 缓解 |
|---|---|
| Galaxy 语法覆盖不全 | 优先覆盖项目实际使用的子集；遇到不支持时降级为"未知节点"不报错 |
| Chevrotain 错误恢复不够强 | 实测项目文件验证；必要时配置 `recoveryEnabled: true` |
| native 表维护成本 | 解析 NativeLib.galaxy 自动生成 + 黑名单 JSON 补充，避免硬编码 |
| 与现有 .py 工具重复 | 设计上 Chevrotain 版本为上位替代；保留 .py 作为兼容对照，不删除 |
| 项目规模扩大后单进程慢 | 设计不阻塞缓存；必要时加文件 mtime 缓存（当前不做） |

## 18. 开放问题

- exit code 是否仅 error 触发非零，还是 warning 也算？当前设计：仅 error。
  理由：AI 拿到 JSON 自行决策，exit code 仅作为 CI 信号。

- 是否需要在 issue 中附带上下文代码片段？当前不做（YAGNI），AI 可自己读文件。
  若后续发现 AI 频繁读文件确认上下文，再加。

- `UnitCreate` 这种"native 表里有但项目禁用"的情况，是否单独 RuleCode？
  当前统一用 `XLIB_DISALLOWED_NATIVE`，message 区分。若后续需要精细控制再拆。
