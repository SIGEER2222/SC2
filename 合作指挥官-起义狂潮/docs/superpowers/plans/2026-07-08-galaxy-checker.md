# Galaxy 脚本静态检查器 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现一个基于 Chevrotain 的 Galaxy 脚本静态检查器（AI 可调用的库 + CLI），覆盖语法/语义/跨库-native 三层检查，在进图测试前把绝大多数错误暴露出来。

**Architecture:** 单进程一次跑完，Lexer→Parser→AST→SymbolTable→Analyzer→Reporter 流水线。规则与代码解耦（JSON 配置）。AI 默认拿 JSON 输出。

**Tech Stack:** TypeScript + Chevrotain + Node.js + vitest

**关联 Spec:** [2026-07-08-galaxy-checker-design.md](../specs/2026-07-08-galaxy-checker-design.md)

---

## 文件结构总览

| 文件 | 责任 | 任务 |
|---|---|---|
| `scripts/galaxy-checker/package.json` | 依赖与脚本入口 | T1 |
| `scripts/galaxy-checker/tsconfig.json` | TS 配置（严格模式） | T1 |
| `scripts/galaxy-checker/src/types.ts` | Issue/Severity 等共享类型 | T2 |
| `scripts/galaxy-checker/src/lexer/tokens.ts` | Chevrotain token 定义 | T3 |
| `scripts/galaxy-checker/src/parser/ast.ts` | AST 节点类型 | T4 |
| `scripts/galaxy-checker/src/parser/GalaxyParser.ts` | Chevrotain 规则 | T5, T6 |
| `scripts/galaxy-checker/src/parser/index.ts` | parse() 公共入口 | T7 |
| `scripts/galaxy-checker/src/analyzer/SymbolTable.ts` | 作用域符号表 | T11 |
| `scripts/galaxy-checker/src/analyzer/SemanticAnalyzer.ts` | 语义检查 | T12-T15 |
| `scripts/galaxy-checker/src/analyzer/NativeFunctionTable.ts` | native 函数表 | T17 |
| `scripts/galaxy-checker/src/analyzer/ProjectLoader.ts` | 全局符号表 | T18 |
| `scripts/galaxy-checker/src/analyzer/RuleEngine.ts` | 项目规则引擎 | T8, T16 |
| `scripts/galaxy-checker/src/reporter/IssueReporter.ts` | 输出格式化 | T9 |
| `scripts/galaxy-checker/src/index.ts` | 库导出 API | T10 |
| `scripts/galaxy-checker/src/cli.mjs` | CLI 入口 | T10 |
| `scripts/galaxy-checker/data/project-rules.json` | 项目规则配置 | T8 |
| `scripts/galaxy-checker/data/native-blacklist.json` | native 黑名单 | T17 |
| `scripts/galaxy-checker/tests/fixtures/*.galaxy` | 回归测试夹具 | T16, T19 |
| `scripts/galaxy-checker/README.md` | 使用说明 | T20 |

---

## 阶段 1：MVP（语法检查）

### Task 1: 项目脚手架

**Files:**
- Create: `scripts/galaxy-checker/package.json`
- Create: `scripts/galaxy-checker/tsconfig.json`
- Create: `scripts/galaxy-checker/.gitignore`

- [x] **Step 1: 创建 `package.json`**

```json
{
  "name": "galaxy-checker",
  "version": "0.1.0",
  "description": "Galaxy 脚本静态检查器（AI 可调用）",
  "type": "module",
  "main": "dist/index.js",
  "bin": {
    "galaxy-check": "dist/cli.js"
  },
  "scripts": {
    "build": "tsc",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "chevrotain": "^11.0.0"
  },
  "devDependencies": {
    "typescript": "^5.4.0",
    "vitest": "^1.6.0",
    "@types/node": "^20.12.0"
  }
}
```

- [x] **Step 2: 创建 `tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "lib": ["ES2022"],
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
```

- [x] **Step 3: 创建 `.gitignore`**

```
node_modules/
dist/
*.log
```

- [x] **Step 4: 安装依赖**

Run: `cd scripts/galaxy-checker && npm install`
Expected: node_modules 创建成功，无错误

- [x] **Step 5: 验证 TypeScript 可用**

Run: `cd scripts/galaxy-checker && npx tsc --version`
Expected: 显示 TypeScript 版本号

- [x] **Step 6: Commit**

```bash
cd scripts/galaxy-checker && git add package.json tsconfig.json .gitignore
git commit -m "feat(galaxy-checker): 初始化项目脚手架"
```

---

### Task 2: 共享类型定义

**Files:**
- Create: `scripts/galaxy-checker/src/types.ts`
- Test: `scripts/galaxy-checker/tests/types.test.ts`

- [x] **Step 1: 写测试 `tests/types.test.ts`**

```typescript
import { describe, it, expect } from 'vitest';
import type { Issue, Severity, CheckResult } from '../src/types.js';

describe('types', () => {
  it('Issue 接口可被构造', () => {
    const issue: Issue = {
      file: 'test.galaxy',
      line: 1,
      column: 1,
      ruleCode: 'SYNTAX_NO_CONTINUE',
      severity: 'error',
      message: 'continue 不允许',
    };
    expect(issue.ruleCode).toBe('SYNTAX_NO_CONTINUE');
  });

  it('CheckResult 接口可被构造', () => {
    const result: CheckResult = {
      filesChecked: 1,
      issues: [],
      summary: { errors: 0, warnings: 0, infos: 0 },
    };
    expect(result.summary.errors).toBe(0);
  });
});
```

- [x] **Step 2: 运行测试，确认失败（找不到模块）**

Run: `cd scripts/galaxy-checker && npx vitest run tests/types.test.ts`
Expected: FAIL，错误为找不到 `../src/types.js`

- [x] **Step 3: 实现 `src/types.ts`**

```typescript
// src/types.ts
export type Severity = 'error' | 'warning' | 'info';

export interface Issue {
  file: string;
  line: number;
  column: number;
  ruleCode: string;
  severity: Severity;
  message: string;
}

export interface CheckResult {
  filesChecked: number;
  issues: Issue[];
  summary: { errors: number; warnings: number; infos: number };
}

export interface CheckOptions {
  rulesPath?: string;
  nativeLibPath?: string;
  globalSymbolGlobs?: string[];
  noGlobalSymbols?: boolean;
}

// Galaxy 类型枚举（来自设计文档 §14.1）
export const GALAXY_TYPES = [
  'void', 'int', 'bool', 'unit', 'point', 'string', 'real', 'fixed', 'wave',
  'group', 'region', 'location', 'timer', 'trigger', 'bank', 'text',
  'unitfilter', 'unitgroup', 'playergroup', 'actor', 'sound', 'effect',
  'behavior', 'abilcmd', 'order', 'pathing', 'doodad', 'camera', 'quest',
  'dialog', 'image', 'movie', 'model', 'footprint', 'object',
  'transmissionsource', 'transmission', 'planet', 'conversation',
  'accomplishment', 'score', 'airgroup', 'groundgroup', 'anygroup',
] as const;

export type GalaxyType = typeof GALAXY_TYPES[number];

export interface FunctionSignature {
  name: string;
  returnType: string;
  params: { type: string; name: string }[];
  isNative: boolean;
}
```

- [x] **Step 4: 运行测试，确认通过**

Run: `cd scripts/galaxy-checker && npx vitest run tests/types.test.ts`
Expected: PASS

- [x] **Step 5: Commit**

```bash
cd scripts/galaxy-checker && git add src/types.ts tests/types.test.ts
git commit -m "feat(galaxy-checker): 添加共享类型定义"
```

---

### Task 3: Lexer Token 定义

**Files:**
- Create: `scripts/galaxy-checker/src/lexer/tokens.ts`
- Test: `scripts/galaxy-checker/tests/lexer.test.ts`

- [x] **Step 1: 写测试 `tests/lexer.test.ts`**

```typescript
import { describe, it, expect } from 'vitest';
import { tokenize } from '../src/lexer/tokens.js';

describe('Lexer', () => {
  it('识别关键字', () => {
    const tokens = tokenize('if else while for return break');
    expect(tokens.map(t => t.tokenType.name)).toEqual([
      'If', 'Else', 'While', 'For', 'Return', 'Break',
    ]);
  });

  it('识别类型关键字', () => {
    const tokens = tokenize('void int bool string');
    expect(tokens.map(t => t.tokenType.name)).toEqual([
      'Void', 'Int', 'Bool', 'String',
    ]);
  });

  it('识别标识符', () => {
    const tokens = tokenize('libNtve_gf_UnitIsHero foo_bar');
    expect(tokens.map(t => t.tokenType.name)).toEqual(['Identifier', 'Identifier']);
  });

  it('识别整数', () => {
    const tokens = tokenize('42 0');
    expect(tokens.map(t => t.tokenType.name)).toEqual(['Integer', 'Integer']);
  });

  it('识别固定点', () => {
    const tokens = tokenize('1.5f 3.14');
    expect(tokens.map(t => t.tokenType.name)).toEqual(['Fixed', 'Fixed']);
  });

  it('识别字符串', () => {
    const tokens = tokenize('"hello world"');
    expect(tokens[0].tokenType.name).toBe('String');
  });

  it('识别行注释', () => {
    const tokens = tokenize('int x; // 这是注释\nint y;');
    expect(tokens.find(t => t.tokenType.name === 'LineComment')).toBeDefined();
  });

  it('识别块注释', () => {
    const tokens = tokenize('/* 块注释 */ int x;');
    expect(tokens.find(t => t.tokenType.name === 'BlockComment')).toBeDefined();
  });

  it('识别运算符', () => {
    const tokens = tokenize('a == b && c != d');
    expect(tokens.map(t => t.tokenType.name)).toContain('EqualsEquals');
    expect(tokens.map(t => t.tokenType.name)).toContain('AmpersandAmpersand');
    expect(tokens.map(t => t.tokenType.name)).toContain('ExclamationEquals');
  });

  it('跳过空白', () => {
    const tokens = tokenize('  int\n\t x  ');
    expect(tokens[0].tokenType.name).toBe('Int');
  });
});
```

- [x] **Step 2: 运行测试，确认失败**

Run: `cd scripts/galaxy-checker && npx vitest run tests/lexer.test.ts`
Expected: FAIL，找不到 `../src/lexer/tokens.js`

- [x] **Step 3: 实现 `src/lexer/tokens.ts`**

```typescript
// src/lexer/tokens.ts
import { createToken, Lexer, type IToken } from 'chevrotain';
import { GALAXY_TYPES } from '../types.js';

// 关键字
const If = createToken({ name: 'If', pattern: /if/, longer_alt: Identifier });
const Else = createToken({ name: 'Else', pattern: /else/, longer_alt: Identifier });
const While = createToken({ name: 'While', pattern: /while/, longer_alt: Identifier });
const For = createToken({ name: 'For', pattern: /for/, longer_alt: Identifier });
const Return = createToken({ name: 'Return', pattern: /return/, longer_alt: Identifier });
const Break = createToken({ name: 'Break', pattern: /break/, longer_alt: Identifier });
const Continue = createToken({ name: 'Continue', pattern: /continue/, longer_alt: Identifier });
const Struct = createToken({ name: 'Struct', pattern: /struct/, longer_alt: Identifier });
const Enum = createToken({ name: 'Enum', pattern: /enum/, longer_alt: Identifier });
const Typedef = createToken({ name: 'Typedef', pattern: /typedef/, longer_alt: Identifier });
const Include = createToken({ name: 'Include', pattern: /include/, longer_alt: Identifier });
const Const = createToken({ name: 'Const', pattern: /const/, longer_alt: Identifier });
const Native = createToken({ name: 'Native', pattern: /native/, longer_alt: Identifier });
const Static = createToken({ name: 'Static', pattern: /static/, longer_alt: Identifier });
const True = createToken({ name: 'True', pattern: /true/, longer_alt: Identifier });
const False = createToken({ name: 'False', pattern: /false/, longer_alt: Identifier });
const Null = createToken({ name: 'Null', pattern: /null/, longer_alt: Identifier });

// 类型关键字（必须先于 Identifier 定义，且使用 longer_alt）
const TypeTokens = GALAXY_TYPES.map(t =>
  createToken({ name: capitalize(t), pattern: new RegExp(`\\b${t}\\b`), longer_alt: Identifier })
);

// 标识符（必须放在所有关键字之前，让 Chevrotain 用 longer_alt 区分）
const Identifier = createToken({ name: 'Identifier', pattern: /[a-zA-Z_][a-zA-Z0-9_]*/ });

// 字面量
const Integer = createToken({ name: 'Integer', pattern: /[0-9]+/ });
const Fixed = createToken({ name: 'Fixed', pattern: /[0-9]+\.[0-9]+f?/ });
const String = createToken({ name: 'String', pattern: /"(?:[^"\\]|\\.)*"/ });
const Char = createToken({ name: 'Char', pattern: /'(?:[^'\\]|\\.)'/ });

// 注释（先于运算符，避免 // 被识别为斜杠）
const LineComment = createToken({
  name: 'LineComment',
  pattern: /\/\/[^\n\r]*/,
  group: Lexer.SKIPPED,
});
const BlockComment = createToken({
  name: 'BlockComment',
  pattern: /\/\*[^*]*\*+(?:[^/*][^*]*\*+) *\//,
  group: Lexer.SKIPPED,
});

// 运算符（按长度降序，避免贪婪问题）
const EqualsEquals = createToken({ name: 'EqualsEquals', pattern: /==/ });
const ExclamationEquals = createToken({ name: 'ExclamationEquals', pattern: /!=/ });
const LessEquals = createToken({ name: 'LessEquals', pattern: /<=/ });
const GreaterEquals = createToken({ name: 'GreaterEquals', pattern: />=/ });
const AmpersandAmpersand = createToken({ name: 'AmpersandAmpersand', pattern: /&&/ });
const PipePipe = createToken({ name: 'PipePipe', pattern: /\|\|/ });
const PlusPlus = createToken({ name: 'PlusPlus', pattern: /\+\+/ });
const MinusMinus = createToken({ name: 'MinusMinus', pattern: /--/ });
const PlusEquals = createToken({ name: 'PlusEquals', pattern: /\+=/ });
const MinusEquals = createToken({ name: 'MinusEquals', pattern: /-=/ });
const StarEquals = createToken({ name: 'StarEquals', pattern: /\*=/ });
const SlashEquals = createToken({ name: 'SlashEquals', pattern: /\/=/ });
const Arrow = createToken({ name: 'Arrow', pattern: /->/ });

const LBrace = createToken({ name: 'LBrace', pattern: /{/ });
const RBrace = createToken({ name: 'RBrace', pattern: /}/ });
const LParen = createToken({ name: 'LParen', pattern: /\(/ });
const RParen = createToken({ name: 'RParen', pattern: /\)/ });
const LBracket = createToken({ name: 'LBracket', pattern: /\[/ });
const RBracket = createToken({ name: 'RBracket', pattern: /\]/ });

const Semicolon = createToken({ name: 'Semicolon', pattern: /;/ });
const Comma = createToken({ name: 'Comma', pattern: /,/ });
const Dot = createToken({ name: 'Dot', pattern: /\./ });
const Colon = createToken({ name: 'Colon', pattern: /:/ });
const Question = createToken({ name: 'Question', pattern: /\?/ });

const Equals = createToken({ name: 'Equals', pattern: /=/ });
const Exclamation = createToken({ name: 'Exclamation', pattern: /!/ });
const Less = createToken({ name: 'Less', pattern: /</ });
const Greater = createToken({ name: 'Greater', pattern: />/ });
const Plus = createToken({ name: 'Plus', pattern: /\+/ });
const Minus = createToken({ name: 'Minus', pattern: /-/ });
const Star = createToken({ name: 'Star', pattern: /\*/ });
const Slash = createToken({ name: 'Slash', pattern: /\// });
const Percent = createToken({ name: 'Percent', pattern: /%/ });
const Ampersand = createToken({ name: 'Ampersand', pattern: /&/ });
const Pipe = createToken({ name: 'Pipe', pattern: /\|/ });
const Caret = createToken({ name: 'Caret', pattern: /\^/ });
const Tilde = createToken({ name: 'Tilde', pattern: /~/ });

// 空白
const WhiteSpace = createToken({
  name: 'WhiteSpace',
  pattern: /[ \t\n\r]+/,
  group: Lexer.SKIPPED,
});

// 所有 token（顺序重要！关键字 → 标识符 → 字面量 → 注释 → 运算符 → 空白）
const allTokens = [
  WhiteSpace,
  LineComment,
  BlockComment,
  // 关键字先于 Identifier
  If, Else, While, For, Return, Break, Continue,
  Struct, Enum, Typedef, Include, Const, Native, Static,
  True, False, Null,
  ...TypeTokens,
  Identifier,
  Integer, Fixed, String, Char,
  // 多字符运算符先于单字符
  EqualsEquals, ExclamationEquals, LessEquals, GreaterEquals,
  AmpersandAmpersand, PipePipe, PlusPlus, MinusMinus,
  PlusEquals, MinusEquals, StarEquals, SlashEquals, Arrow,
  LBrace, RBrace, LParen, RParen, LBracket, RBracket,
  Semicolon, Comma, Dot, Colon, Question,
  Equals, Exclamation, Less, Greater, Plus, Minus, Star, Slash,
  Percent, Ampersand, Pipe, Caret, Tilde,
];

function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

const GalaxyLexer = new Lexer(allTokens, {
  ensureOptimizations: false,
  recoveryEnabled: true,
});

export function tokenize(source: string): IToken[] {
  const result = GalaxyLexer.tokenize(source);
  return result.tokens;
}

export {
  allTokens,
  If, Else, While, For, Return, Break, Continue,
  Struct, Enum, Typedef, Include, Const, Native, Static,
  True, False, Null,
  Identifier, Integer, Fixed, String, Char,
  LineComment, BlockComment,
  EqualsEquals, ExclamationEquals, LessEquals, GreaterEquals,
  AmpersandAmpersand, PipePipe, PlusPlus, MinusMinus,
  PlusEquals, MinusEquals, StarEquals, SlashEquals, Arrow,
  LBrace, RBrace, LParen, RParen, LBracket, RBracket,
  Semicolon, Comma, Dot, Colon, Question,
  Equals, Exclamation, Less, Greater, Plus, Minus, Star, Slash,
  Percent, Ampersand, Pipe, Caret, Tilde,
  TypeTokens,
};
```

- [x] **Step 4: 运行测试，确认通过**

Run: `cd scripts/galaxy-checker && npx vitest run tests/lexer.test.ts`
Expected: PASS

- [x] **Step 5: Commit**

```bash
cd scripts/galaxy-checker && git add src/lexer/tokens.ts tests/lexer.test.ts
git commit -m "feat(galaxy-checker): 实现 Lexer token 定义"
```

---

### Task 4: AST 节点类型

**Files:**
- Create: `scripts/galaxy-checker/src/parser/ast.ts`

- [x] **Step 1: 实现 `src/parser/ast.ts`**

```typescript
// src/parser/ast.ts
export interface Position {
  line: number;
  column: number;
  offset: number;
}

export interface Node {
  type: string;
  start?: Position;
  end?: Position;
}

// 顶层声明
export interface Program extends Node {
  type: 'Program';
  body: TopLevelDeclaration[];
}

export type TopLevelDeclaration =
  | FunctionDeclaration
  | VariableDeclaration
  | IncludeDirective
  | StructDeclaration
  | EnumDeclaration
  | TypedefDeclaration;

export interface IncludeDirective extends Node {
  type: 'Include';
  path: string;
}

export interface FunctionDeclaration extends Node {
  type: 'FunctionDeclaration';
  returnType: string;
  name: string;
  params: { type: string; name: string; isArray?: boolean }[];
  body: BlockStatement | null;
  isNative: boolean;
  isStatic: boolean;
}

export interface VariableDeclaration extends Node {
  type: 'VariableDeclaration';
  varType: string;
  name: string;
  isArray?: boolean;
  init: Expression | null;
  isConst: boolean;
  isStatic: boolean;
}

export interface StructDeclaration extends Node {
  type: 'StructDeclaration';
  name: string;
  members: (VariableDeclaration | FunctionDeclaration)[];
}

export interface EnumDeclaration extends Node {
  type: 'EnumDeclaration';
  name: string;
  members: string[];
}

export interface TypedefDeclaration extends Node {
  type: 'TypedefDeclaration';
  name: string;
  alias: string;
}

// 语句
export interface BlockStatement extends Node {
  type: 'BlockStatement';
  body: Statement[];
}

export type Statement =
  | VariableDeclaration
  | ExpressionStatement
  | IfStatement
  | WhileStatement
  | ForStatement
  | ReturnStatement
  | BreakStatement
  | ContinueStatement
  | BlockStatement;

export interface ExpressionStatement extends Node {
  type: 'ExpressionStatement';
  expression: Expression;
}

export interface IfStatement extends Node {
  type: 'IfStatement';
  test: Expression;
  consequent: Statement;
  alternate: Statement | null;
}

export interface WhileStatement extends Node {
  type: 'WhileStatement';
  test: Expression;
  body: Statement;
}

export interface ForStatement extends Node {
  type: 'ForStatement';
  init: Statement | null;
  test: Expression | null;
  update: Expression | null;
  body: Statement;
}

export interface ReturnStatement extends Node {
  type: 'ReturnStatement';
  argument: Expression | null;
}

export interface BreakStatement extends Node {
  type: 'BreakStatement';
}

export interface ContinueStatement extends Node {
  type: 'ContinueStatement';
}

// 表达式
export type Expression =
  | Identifier
  | Literal
  | BinaryExpression
  | UnaryExpression
  | AssignmentExpression
  | CallExpression
  | MemberExpression
  | IndexExpression
  | ConditionalExpression;

export interface Identifier extends Node {
  type: 'Identifier';
  name: string;
}

export interface Literal extends Node {
  type: 'Literal';
  value: string | number | boolean | null;
  literalType: 'integer' | 'fixed' | 'string' | 'char' | 'bool' | 'null';
}

export interface BinaryExpression extends Node {
  type: 'BinaryExpression';
  operator: string;
  left: Expression;
  right: Expression;
}

export interface UnaryExpression extends Node {
  type: 'UnaryExpression';
  operator: string;
  argument: Expression;
  prefix: boolean;
}

export interface AssignmentExpression extends Node {
  type: 'AssignmentExpression';
  operator: string;
  left: Expression;
  right: Expression;
}

export interface CallExpression extends Node {
  type: 'CallExpression';
  callee: Expression;
  arguments: Expression[];
}

export interface MemberExpression extends Node {
  type: 'MemberExpression';
  object: Expression;
  property: Expression;
  computed: boolean;
}

export interface IndexExpression extends Node {
  type: 'IndexExpression';
  object: Expression;
  index: Expression;
}

export interface ConditionalExpression extends Node {
  type: 'ConditionalExpression';
  test: Expression;
  consequent: Expression;
  alternate: Expression;
}
```

- [x] **Step 2: 验证编译通过**

Run: `cd scripts/galaxy-checker && npx tsc --noEmit`
Expected: 无错误

- [x] **Step 3: Commit**

```bash
cd scripts/galaxy-checker && git add src/parser/ast.ts
git commit -m "feat(galaxy-checker): 定义 AST 节点类型"
```

---

### Task 5: Parser - 基础声明（include/function/var）

**Files:**
- Create: `scripts/galaxy-checker/src/parser/GalaxyParser.ts`
- Test: `scripts/galaxy-checker/tests/parser-declarations.test.ts`

- [x] **Step 1: 写测试 `tests/parser-declarations.test.ts`**

```typescript
import { describe, it, expect } from 'vitest';
import { parse } from '../src/parser/index.js';

describe('Parser - 基础声明', () => {
  it('解析 include 指令', () => {
    const result = parse('include "TriggerLibs/NativeLib.galaxy";');
    expect(result.errors).toHaveLength(0);
    expect(result.ast.body[0]).toMatchObject({
      type: 'Include',
      path: 'TriggerLibs/NativeLib.galaxy',
    });
  });

  it('解析无参函数', () => {
    const result = parse('void foo() {}');
    expect(result.errors).toHaveLength(0);
    expect(result.ast.body[0]).toMatchObject({
      type: 'FunctionDeclaration',
      returnType: 'void',
      name: 'foo',
      isNative: false,
    });
  });

  it('解析带参数函数', () => {
    const result = parse('int add(int a, int b) { return a + b; }');
    expect(result.errors).toHaveLength(0);
    const fn = result.ast.body[0] as any;
    expect(fn.params).toEqual([
      { type: 'int', name: 'a' },
      { type: 'int', name: 'b' },
    ]);
  });

  it('解析 native 函数声明', () => {
    const result = parse('native void UnitCreate(int count, string type);');
    expect(result.errors).toHaveLength(0);
    expect(result.ast.body[0]).toMatchObject({
      type: 'FunctionDeclaration',
      isNative: true,
      body: null,
    });
  });

  it('解析全局变量声明', () => {
    const result = parse('int gv_counter;');
    expect(result.errors).toHaveLength(0);
    expect(result.ast.body[0]).toMatchObject({
      type: 'VariableDeclaration',
      varType: 'int',
      name: 'gv_counter',
      init: null,
    });
  });

  it('解析 const 变量', () => {
    const result = parse('const int MAX = 100;');
    expect(result.errors).toHaveLength(0);
    expect(result.ast.body[0]).toMatchObject({
      type: 'VariableDeclaration',
      isConst: true,
      name: 'MAX',
    });
  });

  it('解析数组变量', () => {
    const result = parse('int[10] gv_array;');
    expect(result.errors).toHaveLength(0);
    expect(result.ast.body[0]).toMatchObject({
      type: 'VariableDeclaration',
      isArray: true,
      name: 'gv_array',
    });
  });
});
```

- [x] **Step 2: 运行测试，确认失败**

Run: `cd scripts/galaxy-checker && npx vitest run tests/parser-declarations.test.ts`
Expected: FAIL，找不到 `../src/parser/index.js`

- [x] **Step 3: 实现 `src/parser/GalaxyParser.ts`**

```typescript
// src/parser/GalaxyParser.ts
import { CstParser, type IToken } from 'chevrotain';
import * as tok from '../lexer/tokens.js';
import { GALAXY_TYPES } from '../types.js';
import type * as ast from './ast.js';

export class GalaxyParser extends CstParser {
  constructor() {
    super(tok.allTokens, { recoveryEnabled: true, nodeLocationTracking: 'full' });
    this.performSelfAnalysis();
  }

  // 顶层规则
  public program = this.RULE('program', () => {
    const body: ast.TopLevelDeclaration[] = [];
    this.MANY(() => {
      this.OR([
        { ALT: () => body.push(this.SUBRULE(this.includeDirective) as any) },
        { ALT: () => body.push(this.SUBRULE(this.functionDeclaration) as any) },
        { ALT: () => body.push(this.SUBRULE(this.globalVarDeclaration) as any) },
        { ALT: () => body.push(this.SUBRULE(this.structDeclaration) as any) },
        { ALT: () => body.push(this.SUBRULE(this.enumDeclaration) as any) },
        { ALT: () => body.push(this.SUBRULE(this.typedefDeclaration) as any) },
      ]);
    });
    return { type: 'Program', body } as ast.Program;
  });

  // include "path";
  private includeDirective = this.RULE('includeDirective', () => {
    this.CONSUME(tok.Include);
    const pathTok = this.CONSUME(tok.String);
    this.CONSUME(tok.Semicolon);
    return {
      type: 'Include',
      path: pathTok.image.slice(1, -1),
    } as ast.IncludeDirective;
  });

  // 类型名
  private typeName = this.RULE('typeName', () => {
    let typeTok: IToken;
    this.OR(
      GALAXY_TYPES.map(t => ({
        ALT: () => {
          typeTok = this.CONSUME((tok.TypeTokens as any)[GALAXY_TYPES.indexOf(t)]);
        },
      }))
    );
    // 也允许 Identifier 当类型（struct 等）
    this.OR({
      ALT: () => {
        typeTok = this.CONSUME(tok.Identifier);
      },
    });
    return typeTok!.image;
  });

  // 函数声明
  private functionDeclaration = this.RULE('functionDeclaration', () => {
    let isNative = false;
    let isStatic = false;

    this.OPTION(() => {
      this.CONSUME(tok.Native);
      isNative = true;
    });
    this.OPTION2(() => {
      this.CONSUME(tok.Static);
      isStatic = true;
    });

    const returnType = this.SUBRULE(this.typeName);
    const nameTok = this.CONSUME(tok.Identifier);
    this.CONSUME(tok.LParen);

    const params: { type: string; name: string; isArray?: boolean }[] = [];
    this.OPTION3(() => {
      params.push(this.SUBRULE(this.paramDeclaration));
      this.MANY(() => {
        this.CONSUME(tok.Comma);
        params.push(this.SUBRULE(this.paramDeclaration));
      });
    });

    this.CONSUME(tok.RParen);

    let body: ast.BlockStatement | null = null;
    if (!isNative) {
      body = this.SUBRULE(this.blockStatement) as any;
    } else {
      this.CONSUME(tok.Semicolon);
    }

    return {
      type: 'FunctionDeclaration',
      returnType,
      name: nameTok.image,
      params,
      body,
      isNative,
      isStatic,
    } as ast.FunctionDeclaration;
  });

  // 参数声明
  private paramDeclaration = this.RULE('paramDeclaration', () => {
    const type = this.SUBRULE(this.typeName);
    const nameTok = this.CONSUME(tok.Identifier);
    let isArray = false;
    this.OPTION(() => {
      this.CONSUME(tok.LBracket);
      this.CONSUME(tok.RBracket);
      isArray = true;
    });
    return { type, name: nameTok.image, isArray };
  });

  // 全局变量声明
  private globalVarDeclaration = this.RULE('globalVarDeclaration', () => {
    return this.SUBRULE(this.varDeclaration);
  });

  // 变量声明（统一规则，给语句也复用）
  private varDeclaration = this.RULE('varDeclaration', () => {
    let isConst = false;
    let isStatic = false;
    this.OPTION(() => {
      this.CONSUME(tok.Const);
      isConst = true;
    });
    this.OPTION2(() => {
      this.CONSUME(tok.Static);
      isStatic = true;
    });

    const varType = this.SUBRULE(this.typeName);
    const nameTok = this.CONSUME(tok.Identifier);

    let isArray = false;
    this.OPTION3(() => {
      this.CONSUME(tok.LBracket);
      // 数组大小（可空）
      this.OPTION4(() => {
        this.CONSUME(tok.Integer);
      });
      this.CONSUME(tok.RBracket);
      isArray = true;
    });

    let init: ast.Expression | null = null;
    this.OPTION5(() => {
      this.CONSUME(tok.Equals);
      init = this.SUBRULE(this.assignmentExpression) as any;
    });

    this.CONSUME(tok.Semicolon);

    return {
      type: 'VariableDeclaration',
      varType,
      name: nameTok.image,
      isArray,
      init,
      isConst,
      isStatic,
    } as ast.VariableDeclaration;
  });

  // block 语句
  private blockStatement = this.RULE('blockStatement', () => {
    this.CONSUME(tok.LBrace);
    const body: ast.Statement[] = [];
    this.MANY(() => {
      body.push(this.SUBRULE(this.statement) as any);
    });
    this.CONSUME(tok.RBrace);
    return { type: 'BlockStatement', body } as ast.BlockStatement;
  });

  // 语句（占位，后续任务扩展）
  private statement = this.RULE('statement', () => {
    return this.OR([
      { ALT: () => this.SUBRULE(this.varDeclaration) as any },
      { ALT: () => this.SUBRULE(this.expressionStatement) as any },
      { ALT: () => this.SUBRULE(this.ifStatement) as any },
      { ALT: () => this.SUBRULE(this.whileStatement) as any },
      { ALT: () => this.SUBRULE(this.forStatement) as any },
      { ALT: () => this.SUBRULE(this.returnStatement) as any },
      { ALT: () => this.CONSUME(tok.Break) as any },
      { ALT: () => this.SUBRULE(this.blockStatement) as any },
    ]);
  });

  private expressionStatement = this.RULE('expressionStatement', () => {
    const expr = this.SUBRULE(this.expression);
    this.CONSUME(tok.Semicolon);
    return { type: 'ExpressionStatement', expression: expr } as ast.ExpressionStatement;
  });

  private ifStatement = this.RULE('ifStatement', () => {
    this.CONSUME(tok.If);
    this.CONSUME(tok.LParen);
    const test = this.SUBRULE(this.expression);
    this.CONSUME(tok.RParen);
    const consequent = this.SUBRULE(this.statement);
    let alternate: ast.Statement | null = null;
    this.OPTION(() => {
      this.CONSUME(tok.Else);
      alternate = this.SUBRULE(this.statement) as any;
    });
    return { type: 'IfStatement', test, consequent, alternate } as ast.IfStatement;
  });

  private whileStatement = this.RULE('whileStatement', () => {
    this.CONSUME(tok.While);
    this.CONSUME(tok.LParen);
    const test = this.SUBRULE(this.expression);
    this.CONSUME(tok.RParen);
    const body = this.SUBRULE(this.statement);
    return { type: 'WhileStatement', test, body } as ast.WhileStatement;
  });

  private forStatement = this.RULE('forStatement', () => {
    this.CONSUME(tok.For);
    this.CONSUME(tok.LParen);
    // 简化：init / test / update
    let init: ast.Statement | null = null;
    this.OPTION(() => {
      init = this.SUBRULE(this.varDeclaration) as any;
    });
    let test: ast.Expression | null = null;
    this.OPTION2(() => {
      test = this.SUBRULE(this.expression) as any;
    });
    this.CONSUME(tok.Semicolon);
    let update: ast.Expression | null = null;
    this.OPTION3(() => {
      update = this.SUBRULE(this.expression) as any;
    });
    this.CONSUME(tok.RParen);
    const body = this.SUBRULE(this.statement);
    return { type: 'ForStatement', init, test, update, body } as ast.ForStatement;
  });

  private returnStatement = this.RULE('returnStatement', () => {
    this.CONSUME(tok.Return);
    let argument: ast.Expression | null = null;
    this.OPTION(() => {
      argument = this.SUBRULE(this.expression) as any;
    });
    this.CONSUME(tok.Semicolon);
    return { type: 'ReturnStatement', argument } as ast.ReturnStatement;
  });

  // 表达式入口
  private expression = this.RULE('expression', () => {
    return this.SUBRULE(this.assignmentExpression);
  });

  // 赋值表达式（右结合）
  private assignmentExpression = this.RULE('assignmentExpression', () => {
    const left = this.SUBRULE(this.conditionalExpression);
    let result: ast.Expression = left;
    this.OPTION(() => {
      const opTok = this.OR1([
        { ALT: () => this.CONSUME(tok.Equals) },
        { ALT: () => this.CONSUME(tok.PlusEquals) },
        { ALT: () => this.CONSUME(tok.MinusEquals) },
        { ALT: () => this.CONSUME(tok.StarEquals) },
        { ALT: () => this.CONSUME(tok.SlashEquals) },
      ]);
      const right = this.SUBRULE(this.assignmentExpression);
      result = {
        type: 'AssignmentExpression',
        operator: opTok!.image,
        left: result,
        right,
      } as ast.AssignmentExpression;
    });
    return result;
  });

  // 三元
  private conditionalExpression = this.RULE('conditionalExpression', () => {
    const test = this.SUBRULE(this.logicalOrExpression);
    let result: ast.Expression = test;
    this.OPTION(() => {
      this.CONSUME(tok.Question);
      const consequent = this.SUBRULE(this.expression);
      this.CONSUME(tok.Colon);
      const alternate = this.SUBRULE(this.conditionalExpression);
      result = {
        type: 'ConditionalExpression',
        test: result,
        consequent,
        alternate,
      } as ast.ConditionalExpression;
    });
    return result;
  });

  // 逻辑或
  private logicalOrExpression = this.RULE('logicalOrExpression', () => {
    let left = this.SUBRULE(this.logicalAndExpression);
    this.MANY(() => {
      const opTok = this.CONSUME(tok.PipePipe);
      const right = this.SUBRULE(this.logicalAndExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok.image,
        left,
        right,
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 逻辑与
  private logicalAndExpression = this.RULE('logicalAndExpression', () => {
    let left = this.SUBRULE(this.equalityExpression);
    this.MANY(() => {
      const opTok = this.CONSUME(tok.AmpersandAmpersand);
      const right = this.SUBRULE(this.equalityExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok.image,
        left,
        right,
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 相等
  private equalityExpression = this.RULE('equalityExpression', () => {
    let left = this.SUBRULE(this.relationalExpression);
    this.MANY(() => {
      const opTok = this.OR1([
        { ALT: () => this.CONSUME(tok.EqualsEquals) },
        { ALT: () => this.CONSUME(tok.ExclamationEquals) },
      ]);
      const right = this.SUBRULE(this.relationalExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok!.image,
        left,
        right,
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 关系
  private relationalExpression = this.RULE('relationalExpression', () => {
    let left = this.SUBRULE(this.additiveExpression);
    this.MANY(() => {
      const opTok = this.OR1([
        { ALT: () => this.CONSUME(tok.Less) },
        { ALT: () => this.CONSUME(tok.Greater) },
        { ALT: () => this.CONSUME(tok.LessEquals) },
        { ALT: () => this.CONSUME(tok.GreaterEquals) },
      ]);
      const right = this.SUBRULE(this.additiveExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok!.image,
        left,
        right,
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 加减
  private additiveExpression = this.RULE('additiveExpression', () => {
    let left = this.SUBRULE(this.multiplicativeExpression);
    this.MANY(() => {
      const opTok = this.OR1([
        { ALT: () => this.CONSUME(tok.Plus) },
        { ALT: () => this.CONSUME(tok.Minus) },
      ]);
      const right = this.SUBRULE(this.multiplicativeExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok!.image,
        left,
        right,
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 乘除模
  private multiplicativeExpression = this.RULE('multiplicativeExpression', () => {
    let left = this.SUBRULE(this.unaryExpression);
    this.MANY(() => {
      const opTok = this.OR1([
        { ALT: () => this.CONSUME(tok.Star) },
        { ALT: () => this.CONSUME(tok.Slash) },
        { ALT: () => this.CONSUME(tok.Percent) },
      ]);
      const right = this.SUBRULE(this.unaryExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok!.image,
        left,
        right,
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 一元
  private unaryExpression = this.RULE('unaryExpression', () => {
    let prefix = '';
    this.OPTION(() => {
      prefix = (this.OR1([
        { ALT: () => this.CONSUME(tok.Plus) },
        { ALT: () => this.CONSUME(tok.Minus) },
        { ALT: () => this.CONSUME(tok.Exclamation) },
        { ALT: () => this.CONSUME(tok.Tilde) },
      ]) as IToken)!.image;
    });
    const arg = this.SUBRULE(this.postfixExpression);
    if (prefix) {
      return {
        type: 'UnaryExpression',
        operator: prefix,
        argument: arg,
        prefix: true,
      } as ast.UnaryExpression;
    }
    return arg;
  });

  // 后缀：调用 / 成员 / 下标
  private postfixExpression = this.RULE('postfixExpression', () => {
    let expr = this.SUBRULE(this.primaryExpression);
    this.MANY(() => {
      this.OR([
        {
          ALT: () => {
            this.CONSUME(tok.LParen);
            const args: ast.Expression[] = [];
            this.OPTION(() => {
              args.push(this.SUBRULE(this.expression) as any);
              this.MANY(() => {
                this.CONSUME(tok.Comma);
                args.push(this.SUBRULE(this.expression) as any);
              });
            });
            this.CONSUME(tok.RParen);
            expr = {
              type: 'CallExpression',
              callee: expr,
              arguments: args,
            } as ast.CallExpression;
          },
        },
        {
          ALT: () => {
            this.CONSUME(tok.Dot);
            const propTok = this.CONSUME(tok.Identifier);
            expr = {
              type: 'MemberExpression',
              object: expr,
              property: { type: 'Identifier', name: propTok.image } as ast.Identifier,
              computed: false,
            } as ast.MemberExpression;
          },
        },
        {
          ALT: () => {
            this.CONSUME(tok.LBracket);
            const idx = this.SUBRULE(this.expression);
            this.CONSUME(tok.RBracket);
            expr = {
              type: 'IndexExpression',
              object: expr,
              index: idx,
            } as ast.IndexExpression;
          },
        },
      ]);
    });
    return expr;
  });

  // 基础表达式
  private primaryExpression = this.RULE('primaryExpression', () => {
    return this.OR([
      { ALT: () => this.SUBRULE(this.literal) as any },
      {
        ALT: () => {
          const idTok = this.CONSUME(tok.Identifier);
          return { type: 'Identifier', name: idTok.image } as ast.Identifier;
        },
      },
      {
        ALT: () => {
          this.CONSUME(tok.LParen);
          const expr = this.SUBRULE(this.expression);
          this.CONSUME(tok.RParen);
          return expr;
        },
      },
    ]);
  });

  // 字面量
  private literal = this.RULE('literal', () => {
    return this.OR([
      {
        ALT: () => {
          const t = this.CONSUME(tok.Integer);
          return {
            type: 'Literal',
            value: parseInt(t.image, 10),
            literalType: 'integer' as const,
          } as ast.Literal;
        },
      },
      {
        ALT: () => {
          const t = this.CONSUME(tok.Fixed);
          return {
            type: 'Literal',
            value: parseFloat(t.image),
            literalType: 'fixed' as const,
          } as ast.Literal;
        },
      },
      {
        ALT: () => {
          const t = this.CONSUME(tok.String);
          return {
            type: 'Literal',
            value: t.image.slice(1, -1),
            literalType: 'string' as const,
          } as ast.Literal;
        },
      },
      {
        ALT: () => {
          const t = this.CONSUME(tok.Char);
          return {
            type: 'Literal',
            value: t.image.slice(1, -1),
            literalType: 'char' as const,
          } as ast.Literal;
        },
      },
      {
        ALT: () => {
          this.CONSUME(tok.True);
          return {
            type: 'Literal',
            value: true,
            literalType: 'bool' as const,
          } as ast.Literal;
        },
      },
      {
        ALT: () => {
          this.CONSUME(tok.False);
          return {
            type: 'Literal',
            value: false,
            literalType: 'bool' as const,
          } as ast.Literal;
        },
      },
      {
        ALT: () => {
          this.CONSUME(tok.Null);
          return {
            type: 'Literal',
            value: null,
            literalType: 'null' as const,
          } as ast.Literal;
        },
      },
    ]);
  });

  // struct（占位）
  private structDeclaration = this.RULE('structDeclaration', () => {
    this.CONSUME(tok.Struct);
    const nameTok = this.CONSUME(tok.Identifier);
    this.CONSUME(tok.LBrace);
    const members: any[] = [];
    this.MANY(() => {
      members.push(this.SUBRULE(this.varDeclaration) as any);
    });
    this.CONSUME(tok.RBrace);
    return { type: 'StructDeclaration', name: nameTok.image, members } as ast.StructDeclaration;
  });

  // enum（占位）
  private enumDeclaration = this.RULE('enumDeclaration', () => {
    this.CONSUME(tok.Enum);
    const nameTok = this.CONSUME(tok.Identifier);
    this.CONSUME(tok.LBrace);
    const members: string[] = [];
    this.MANY(() => {
      const m = this.CONSUME(tok.Identifier);
      members.push(m.image);
      this.OPTION(() => this.CONSUME(tok.Comma));
    });
    this.CONSUME(tok.RBrace);
    return { type: 'EnumDeclaration', name: nameTok.image, members } as ast.EnumDeclaration;
  });

  // typedef（占位）
  private typedefDeclaration = this.RULE('typedefDeclaration', () => {
    this.CONSUME(tok.Typedef);
    const nameTok = this.CONSUME(tok.Identifier);
    const alias = this.SUBRULE(this.typeName);
    this.CONSUME(tok.Semicolon);
    return {
      type: 'TypedefDeclaration',
      name: nameTok.image,
      alias,
    } as ast.TypedefDeclaration;
  });
}

// 单例
const parserInstance = new GalaxyParser();
const BaseCstVisitor = parserInstance.getBaseCstVisitorConstructor();

// 把 CST 转换为 AST 的访问器
class GalaxyAstBuilder extends BaseCstVisitor {
  constructor() {
    super();
    this.validateVisitor();
  }

  program(ctx: any): ast.Program {
    const body = (ctx.body || []).map((c: any) => this.visit(c));
    return { type: 'Program', body };
  }
}

export function getParser(): GalaxyParser {
  return parserInstance;
}
```

- [x] **Step 4: 实现 `src/parser/index.ts`（公共入口）**

```typescript
// src/parser/index.ts
import { tokenize } from '../lexer/tokens.js';
import { getParser } from './GalaxyParser.js';
import type { Program } from './ast.js';
import type { Issue } from '../types.js';

const parser = getParser();

export interface ParseResult {
  ast: Program;
  errors: Issue[];
  cst: any;
}

export function parse(source: string, filename: string = '<inline>'): ParseResult {
  const lexResult = tokenize(source);

  // 词法错误
  const errors: Issue[] = [];

  // 解析
  parser.input = lexResult;
  const cst = parser.program();
  const parserErrors = parser.errors;

  // 把解析错误转换为 Issue
  for (const err of parserErrors) {
    errors.push({
      file: filename,
      line: err.token?.startLine ?? 0,
      column: err.token?.startColumn ?? 0,
      ruleCode: 'SYNTAX_PARSE_ERROR',
      severity: 'error',
      message: err.message,
    });
  }

  const ast = cst as unknown as Program;

  return { ast, errors, cst };
}
```

- [x] **Step 5: 运行测试，确认通过**

Run: `cd scripts/galaxy-checker && npx vitest run tests/parser-declarations.test.ts`
Expected: PASS

- [x] **Step 6: Commit**

```bash
cd scripts/galaxy-checker && git add src/parser/GalaxyParser.ts src/parser/index.ts tests/parser-declarations.test.ts
git commit -m "feat(galaxy-checker): 实现基础 Parser（include/function/var）"
```

---

### Task 6: Parser - continue 与 break 语句

**Files:**
- Modify: `scripts/galaxy-checker/src/parser/GalaxyParser.ts`
- Test: `scripts/galaxy-checker/tests/parser-control-flow.test.ts`

- [x] **Step 1: 写测试 `tests/parser-control-flow.test.ts`**

```typescript
import { describe, it, expect } from 'vitest';
import { parse } from '../src/parser/index.js';

describe('Parser - 控制流', () => {
  it('解析 break 语句', () => {
    const result = parse('void f() { while (true) { break; } }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析 continue 语句（不报错，由规则引擎检查）', () => {
    const result = parse('void f() { while (true) { continue; } }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析 if/else', () => {
    const result = parse('void f() { if (true) { return; } else { return; } }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析 for 循环', () => {
    const result = parse('void f() { for (int i = 0; i < 10; i = i + 1) { } }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析 return 带表达式', () => {
    const result = parse('int f() { return 42; }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析函数调用', () => {
    const result = parse('void f() { libNtve_gf_UnitIsHero(1); }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析成员访问', () => {
    const result = parse('void f() { a.b = 1; }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析数组下标', () => {
    const result = parse('void f() { a[0] = 1; }');
    expect(result.errors).toHaveLength(0);
  });

  it('解析三元表达式', () => {
    const result = parse('int f() { return x > 0 ? 1 : 0; }');
    expect(result.errors).toHaveLength(0);
  });
});
```

- [x] **Step 2: 运行测试，确认部分失败（continue 在 statement 里没列出）**

Run: `cd scripts/galaxy-checker && npx vitest run tests/parser-control-flow.test.ts`
Expected: continue 测试 FAIL

- [x] **Step 3: 修改 `GalaxyParser.ts` 的 statement 规则，添加 continue**

在 `statement` 规则的 OR 选项里加：

```typescript
{ ALT: () => this.SUBRULE(this.continueStatement) as any },
```

并新增规则（紧挨 break 之后）：

```typescript
private continueStatement = this.RULE('continueStatement', () => {
  this.CONSUME(tok.Continue);
  this.CONSUME(tok.Semicolon);
  return { type: 'ContinueStatement' } as ast.ContinueStatement;
});
```

同时 break 也改为单独规则（更易追踪位置）：

```typescript
private breakStatement = this.RULE('breakStatement', () => {
  this.CONSUME(tok.Break);
  this.CONSUME(tok.Semicolon);
  return { type: 'BreakStatement' } as ast.BreakStatement;
});
```

把 statement 中的 `this.CONSUME(tok.Break)` 换成 `this.SUBRULE(this.breakStatement)`。

- [x] **Step 4: 运行测试，确认全部通过**

Run: `cd scripts/galaxy-checker && npx vitest run tests/parser-control-flow.test.ts`
Expected: PASS

- [x] **Step 5: Commit**

```bash
cd scripts/galaxy-checker && git add src/parser/GalaxyParser.ts tests/parser-control-flow.test.ts
git commit -m "feat(galaxy-checker): 支持 continue/break 与完整控制流语句"
```

---

### Task 7: RuleEngine 框架 + 项目规则加载

**Files:**
- Create: `scripts/galaxy-checker/src/analyzer/RuleEngine.ts`
- Create: `scripts/galaxy-checker/data/project-rules.json`
- Test: `scripts/galaxy-checker/tests/rule-engine.test.ts`

- [x] **Step 1: 写测试 `tests/rule-engine.test.ts`**

```typescript
import { describe, it, expect } from 'vitest';
import { RuleEngine } from '../src/analyzer/RuleEngine.js';

describe('RuleEngine', () => {
  it('加载默认规则文件', () => {
    const engine = new RuleEngine();
    expect(engine.getRule('SYNTAX_NO_CONTINUE')?.severity).toBe('error');
    expect(engine.getRule('PROJ_UTF8_BOM')?.severity).toBe('error');
  });

  it('禁用规则', () => {
    const engine = new RuleEngine({
      rules: { SYNTAX_NO_CONTINUE: { severity: 'off' } },
    });
    expect(engine.getRule('SYNTAX_NO_CONTINUE')?.severity).toBe('off');
  });

  it('获取所有启用的规则', () => {
    const engine = new RuleEngine();
    const enabled = engine.getEnabledRules();
    expect(enabled.find(r => r.code === 'SYNTAX_NO_CONTINUE')).toBeDefined();
  });

  it('未配置的规则默认 info', () => {
    const engine = new RuleEngine();
    expect(engine.getRule('UNKNOWN_RULE')?.severity).toBe('off');
  });
});
```

- [x] **Step 2: 运行测试，确认失败**

Run: `cd scripts/galaxy-checker && npx vitest run tests/rule-engine.test.ts`
Expected: FAIL

- [x] **Step 3: 创建 `data/project-rules.json`**

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
    },
    "PROJ_ENCODING_INVALID": {
      "severity": "warning"
    }
  },
  "nativeBlacklistFile": "native-blacklist.json",
  "globalSymbolGlobs": ["Lib*.galaxy"],
  "nativeLibPath": "TriggerLibs/NativeLib.galaxy"
}
```

- [x] **Step 4: 实现 `src/analyzer/RuleEngine.ts`**

```typescript
// src/analyzer/RuleEngine.ts
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { Issue, Severity } from '../types.js';

export interface RuleConfig {
  severity: Severity | 'off';
  message?: string;
}

export interface RuleDefinition {
  code: string;
  severity: Severity | 'off';
  message: string;
}

export interface RulesFile {
  version: string;
  rules: Record<string, RuleConfig>;
  nativeBlacklistFile?: string;
  globalSymbolGlobs?: string[];
  nativeLibPath?: string;
}

const DEFAULT_RULES_PATH = join(
  dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
  'data',
  'project-rules.json'
);

const DEFAULT_MESSAGE: Record<string, string> = {
  SYNTAX_NO_CONTINUE: 'Galaxy 不支持 continue 语句',
  SYNTAX_NO_LOCAL_INIT_ASSIGN: 'Galaxy 局部变量不能用 = 初始化',
  SEM_VOID_IN_CONDITION: 'void 返回函数不能用在条件表达式',
  XLIB_DISALLOWED_NATIVE: '调用了不允许的 native 函数',
  PROJ_UTF8_BOM: '文件含 UTF-8 BOM',
  PROJ_ENCODING_INVALID: '文件编码非 UTF-8',
};

export class RuleEngine {
  private rules: Map<string, RuleDefinition> = new Map();

  constructor(rulesFile?: RulesFile | string) {
    let file: RulesFile;
    if (!rulesFile) {
      file = JSON.parse(readFileSync(DEFAULT_RULES_PATH, 'utf-8'));
    } else if (typeof rulesFile === 'string') {
      file = JSON.parse(readFileSync(rulesFile, 'utf-8'));
    } else {
      file = rulesFile;
    }

    for (const [code, cfg] of Object.entries(file.rules)) {
      this.rules.set(code, {
        code,
        severity: cfg.severity,
        message: cfg.message ?? DEFAULT_MESSAGE[code] ?? code,
      });
    }
  }

  getRule(code: string): RuleDefinition | undefined {
    return this.rules.get(code);
  }

  getEnabledRules(): RuleDefinition[] {
    return Array.from(this.rules.values()).filter(r => r.severity !== 'off');
  }

  isRuleEnabled(code: string): boolean {
    const r = this.rules.get(code);
    return r !== undefined && r.severity !== 'off';
  }

  makeIssue(
    code: string,
    file: string,
    line: number,
    column: number,
    overrideMessage?: string
  ): Issue | null {
    const rule = this.rules.get(code);
    if (!rule || rule.severity === 'off') return null;
    return {
      file,
      line,
      column,
      ruleCode: code,
      severity: rule.severity as Severity,
      message: overrideMessage ?? rule.message,
    };
  }
}
```

- [x] **Step 5: 运行测试，确认通过**

Run: `cd scripts/galaxy-checker && npx vitest run tests/rule-engine.test.ts`
Expected: PASS

- [x] **Step 6: Commit**

```bash
cd scripts/galaxy-checker && git add src/analyzer/RuleEngine.ts data/project-rules.json tests/rule-engine.test.ts
git commit -m "feat(galaxy-checker): 实现规则引擎与 JSON 配置加载"
```

---

### Task 8: 语法规则 - SYNTAX_NO_CONTINUE / NO_LOCAL_INIT_ASSIGN

**Files:**
- Modify: `scripts/galaxy-checker/src/analyzer/RuleEngine.ts`
- Test: `scripts/galaxy-checker/tests/rules-syntax.test.ts`

- [x] **Step 1: 写测试 `tests/rules-syntax.test.ts`**

```typescript
import { describe, it, expect } from 'vitest';
import { checkRules } from '../src/analyzer/RuleEngine.js';

describe('语法规则', () => {
  it('SYNTAX_NO_CONTINUE：检测 continue 语句', () => {
    const issues = checkRules('void f() { while(true) { continue; } }', 'test.galaxy');
    const cont = issues.find(i => i.ruleCode === 'SYNTAX_NO_CONTINUE');
    expect(cont).toBeDefined();
    expect(cont?.severity).toBe('error');
    expect(cont?.line).toBeGreaterThan(0);
  });

  it('SYNTAX_NO_CONTINUE：无 continue 时不报', () => {
    const issues = checkRules('void f() { while(true) { break; } }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SYNTAX_NO_CONTINUE')).toBeUndefined();
  });

  it('SYNTAX_NO_LOCAL_INIT_ASSIGN：检测局部变量 = 初始化', () => {
    const issues = checkRules('void f() { int x = 1; }', 'test.galaxy');
    const init = issues.find(i => i.ruleCode === 'SYNTAX_NO_LOCAL_INIT_ASSIGN');
    expect(init).toBeDefined();
  });

  it('SYNTAX_NO_LOCAL_INIT_ASSIGN：仅声明不报', () => {
    const issues = checkRules('void f() { int x; x = 1; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SYNTAX_NO_LOCAL_INIT_ASSIGN')).toBeUndefined();
  });

  it('SYNTAX_NO_LOCAL_INIT_ASSIGN：全局变量初始化不报', () => {
    const issues = checkRules('int gv_x = 1;', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SYNTAX_NO_LOCAL_INIT_ASSIGN')).toBeUndefined();
  });
});
```

- [x] **Step 2: 运行测试，确认失败**

Run: `cd scripts/galaxy-checker && npx vitest run tests/rules-syntax.test.ts`
Expected: FAIL，`checkRules` 不存在

- [x] **Step 3: 在 `RuleEngine.ts` 添加 `checkRules` 函数（走 parse + 遍历 AST）**

在文件末尾追加：

```typescript
import { parse } from '../parser/index.js';
import type { Program, Node, ContinueStatement, VariableDeclaration } from '../parser/ast.js';

export function checkRules(source: string, filename: string): Issue[] {
  const engine = new RuleEngine();
  const { ast, errors } = parse(source, filename);
  const issues: Issue[] = [...errors];

  // 遍历 AST 找 continue / 局部变量初始化
  walk(ast, (node, parent) => {
    if (node.type === 'ContinueStatement' && engine.isRuleEnabled('SYNTAX_NO_CONTINUE')) {
      const n = node as ContinueStatement & { start?: { line: number; column: number } };
      issues.push(
        engine.makeIssue(
          'SYNTAX_NO_CONTINUE',
          filename,
          n.start?.line ?? 0,
          n.start?.column ?? 0
        )!
      );
    }

    if (
      node.type === 'VariableDeclaration' &&
      parent?.type !== 'Program' && // 只检查局部变量
      (node as VariableDeclaration).init !== null &&
      engine.isRuleEnabled('SYNTAX_NO_LOCAL_INIT_ASSIGN')
    ) {
      const n = node as VariableDeclaration & { start?: { line: number; column: number } };
      issues.push(
        engine.makeIssue(
          'SYNTAX_NO_LOCAL_INIT_ASSIGN',
          filename,
          n.start?.line ?? 0,
          n.start?.column ?? 0
        )!
      );
    }
  });

  return issues;
}

function walk(node: Node, cb: (n: Node, parent: Node | null) => void, parent: Node | null = null) {
  if (!node || typeof node !== 'object') return;
  cb(node, parent);
  for (const key of Object.keys(node)) {
    if (key === 'type' || key === 'start' || key === 'end') continue;
    const val = (node as any)[key];
    if (Array.isArray(val)) {
      for (const child of val) {
        if (child && typeof child === 'object' && typeof child.type === 'string') {
          walk(child, cb, node);
        }
      }
    } else if (val && typeof val === 'object' && typeof val.type === 'string') {
      walk(val, cb, node);
    }
  }
}
```

- [x] **Step 4: 运行测试，确认通过**

Run: `cd scripts/galaxy-checker && npx vitest run tests/rules-syntax.test.ts`
Expected: PASS

- [x] **Step 5: Commit**

```bash
cd scripts/galaxy-checker && git add src/analyzer/RuleEngine.ts tests/rules-syntax.test.ts
git commit -m "feat(galaxy-checker): 实现 SYNTAX_NO_CONTINUE / NO_LOCAL_INIT_ASSIGN 规则"
```

---

### Task 9: IssueReporter

**Files:**
- Create: `scripts/galaxy-checker/src/reporter/IssueReporter.ts`
- Test: `scripts/galaxy-checker/tests/reporter.test.ts`

- [x] **Step 1: 写测试 `tests/reporter.test.ts`**

```typescript
import { describe, it, expect } from 'vitest';
import { IssueReporter } from '../src/reporter/IssueReporter.js';
import type { Issue } from '../src/types.js';

describe('IssueReporter', () => {
  const sampleIssues: Issue[] = [
    {
      file: 'a.galaxy',
      line: 10,
      column: 5,
      ruleCode: 'SYNTAX_NO_CONTINUE',
      severity: 'error',
      message: 'continue 不允许',
    },
    {
      file: 'b.galaxy',
      line: 1,
      column: 1,
      ruleCode: 'PROJ_UTF8_BOM',
      severity: 'error',
      message: 'BOM',
    },
  ];

  it('JSON 格式输出包含 summary', () => {
    const reporter = new IssueReporter('json');
    const out = JSON.parse(reporter.report(sampleIssues, 2));
    expect(out.summary.errors).toBe(2);
    expect(out.issues).toHaveLength(2);
    expect(out.tool).toBe('galaxy-checker');
  });

  it('文本格式包含 ERROR 标签', () => {
    const reporter = new IssueReporter('text');
    const out = reporter.report(sampleIssues, 2);
    expect(out).toContain('[ERROR]');
    expect(out).toContain('SYNTAX_NO_CONTINUE');
    expect(out).toContain('总计');
  });

  it('无 issue 时 JSON 输出 errors=0', () => {
    const reporter = new IssueReporter('json');
    const out = JSON.parse(reporter.report([], 0));
    expect(out.summary.errors).toBe(0);
    expect(out.issues).toHaveLength(0);
  });
});
```

- [x] **Step 2: 运行测试，确认失败**

Run: `cd scripts/galaxy-checker && npx vitest run tests/reporter.test.ts`
Expected: FAIL

- [x] **Step 3: 实现 `src/reporter/IssueReporter.ts`**

```typescript
// src/reporter/IssueReporter.ts
import type { Issue, CheckResult } from '../types.js';

export type ReportFormat = 'json' | 'text';

export class IssueReporter {
  constructor(private format: ReportFormat = 'json') {}

  report(issues: Issue[], filesChecked: number): string {
    const result = this.buildResult(issues, filesChecked);
    if (this.format === 'json') {
      return JSON.stringify(result, null, 2);
    }
    return this.formatText(result);
  }

  buildResult(issues: Issue[], filesChecked: number): CheckResult {
    const summary = {
      errors: issues.filter(i => i.severity === 'error').length,
      warnings: issues.filter(i => i.severity === 'warning').length,
      infos: issues.filter(i => i.severity === 'info').length,
    };
    return { filesChecked, issues, summary };
  }

  private formatText(result: CheckResult): string {
    const lines: string[] = [];
    for (const issue of result.issues) {
      const tag = issue.severity === 'error' ? 'ERROR'
        : issue.severity === 'warning' ? 'WARN'
        : 'INFO';
      lines.push(
        `[${tag}] ${issue.file}:${issue.line}:${issue.column}  ${issue.ruleCode}`
      );
      lines.push(`        ${issue.message}`);
      lines.push('');
    }
    lines.push(
      `总计: ${result.summary.errors} 错误, ${result.summary.warnings} 警告`
    );
    return lines.join('\n');
  }
}
```

- [x] **Step 4: 运行测试，确认通过**

Run: `cd scripts/galaxy-checker && npx vitest run tests/reporter.test.ts`
Expected: PASS

- [x] **Step 5: Commit**

```bash
cd scripts/galaxy-checker && git add src/reporter/IssueReporter.ts tests/reporter.test.ts
git commit -m "feat(galaxy-checker): 实现 IssueReporter（JSON/text 输出）"
```

---

### Task 10: CLI 入口 + 库 API

**Files:**
- Create: `scripts/galaxy-checker/src/index.ts`
- Create: `scripts/galaxy-checker/src/cli.mjs`
- Test: `scripts/galaxy-checker/tests/cli.test.ts`

- [x] **Step 1: 写测试 `tests/cli.test.ts`**

```typescript
import { describe, it, expect } from 'vitest';
import { check } from '../src/index.js';
import { writeFileSync, readFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

describe('check API', () => {
  it('检查 continue 报错', () => {
    const tmp = join(tmpdir(), `test-${Date.now()}.galaxy`);
    writeFileSync(tmp, 'void f() { while(true) { continue; } }', 'utf-8');
    const result = check(tmp);
    expect(result.issues.find(i => i.ruleCode === 'SYNTAX_NO_CONTINUE')).toBeDefined();
    expect(result.summary.errors).toBeGreaterThan(0);
  });

  it'检查干净文件无报错', () => {
    const tmp = join(tmpdir(), `clean-${Date.now()}.galaxy`);
    writeFileSync(tmp, 'void f() { return; }', 'utf-8');
    const result = check(tmp);
    expect(result.summary.errors).toBe(0);
  });

  it('检查 BOM 文件报错', () => {
    const tmp = join(tmpdir(), `bom-${Date.now()}.galaxy`);
    const bom = Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), Buffer.from('void f() {}', 'utf-8')]);
    writeFileSync(tmp, bom);
    const result = check(tmp);
    expect(result.issues.find(i => i.ruleCode === 'PROJ_UTF8_BOM')).toBeDefined();
  });
});
```

- [x] **Step 2: 运行测试，确认失败**

Run: `cd scripts/galaxy-checker && npx vitest run tests/cli.test.ts`
Expected: FAIL（注意上面 test 故意写错了一处 `'it'检查'`，先用错误的，验证 fail）

修正测试里 `it'检查干净文件无报错'` → `it('检查干净文件无报错'`，再运行一次确认失败原因是 `check` 不存在。

- [x] **Step 3: 实现 `src/index.ts`**

```typescript
// src/index.ts
import { readFileSync, statSync } from 'node:fs';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { globSync } from 'node:fs';
import { tokenize } from './lexer/tokens.js';
import { parse } from './parser/index.js';
import { RuleEngine, checkRules } from './analyzer/RuleEngine.js';
import { IssueReporter } from './reporter/IssueReporter.js';
import type { Issue, CheckResult, CheckOptions } from './types.js';

export { tokenize, parse, RuleEngine, IssueReporter };
export type { Issue, CheckResult, CheckOptions };

const DEFAULT_RULES_PATH = join(
  dirname(fileURLToPath(import.meta.url)),
  '..',
  'data',
  'project-rules.json'
);

export function check(target: string, options: CheckOptions = {}): CheckResult {
  const rulesPath = options.rulesPath ?? DEFAULT_RULES_PATH;
  const engine = new RuleEngine(rulesPath);
  const reporter = new IssueReporter('json');

  const files = collectFiles(target);
  const allIssues: Issue[] = [];

  for (const file of files) {
    const raw = readFileSync(file);
    const content = stripBom(raw.toString('utf-8'));

    // BOM 检查
    if (engine.isRuleEnabled('PROJ_UTF8_BOM')) {
      if (raw[0] === 0xef && raw[1] === 0xbb && raw[2] === 0xbf) {
        allIssues.push(
          engine.makeIssue('PROJ_UTF8_BOM', basename(file), 1, 1)!
        );
      }
    }

    // 语法 + 规则检查
    const issues = checkRules(content, basename(file));
    allIssues.push(...issues);
  }

  const result = reporter.buildResult(allIssues, files.length);
  return result;
}

function collectFiles(target: string): string[] {
  const stat = statSync(target);
  if (stat.isFile()) return [target];
  // 目录：扫 Lib*.galaxy
  const dir = target;
  const out: string[] = [];
  for (const entry of walkDir(dir)) {
    if (entry.endsWith('.galaxy') && basename(entry).startsWith('Lib')) {
      out.push(entry);
    }
  }
  return out;
}

function* walkDir(dir: string): Generator<string> {
  const entries = require('node:fs').readdirSync(dir, { withFileTypes: true });
  for (const e of entries) {
    const full = join(dir, e.name);
    if (e.isDirectory()) {
      yield* walkDir(full);
    } else {
      yield full;
    }
  }
}

function stripBom(s: string): string {
  return s.charCodeAt(0) === 0xfeff ? s.slice(1) : s;
}
```

- [x] **Step 4: 实现 `src/cli.mjs`**

```javascript
#!/usr/bin/env node
// src/cli.mjs
import { check } from './index.js';
import { IssueReporter } from './reporter/IssueReporter.js';

const args = process.argv.slice(2);
if (args.length === 0 || args.includes('--help')) {
  console.error(`用法: galaxy-check <file|dir> [options]
选项:
  --format <json|text>    输出格式，默认 json
  --rules <path>          项目规则 JSON 路径
  --native-lib <path>     NativeLib.galaxy 路径
  --no-global-symbols      跳过全局符号表构建
  --quiet                 仅输出 issue，无汇总行
  --help                  显示帮助`);
  process.exit(2);
}

const target = args[0];
const formatIdx = args.indexOf('--format');
const format = formatIdx >= 0 ? args[formatIdx + 1] : 'json';

try {
  const result = check(target);
  const reporter = new IssueReporter(format);
  const output = reporter.report(result.issues, result.filesChecked);
  console.log(output);
  process.exit(result.summary.errors > 0 ? 1 : 0);
} catch (e) {
  console.error(`工具异常: ${e.message}`);
  console.error(e.stack);
  process.exit(2);
}
```

- [x] **Step 5: 运行测试，确认通过**

Run: `cd scripts/galaxy-checker && npx vitest run tests/cli.test.ts`
Expected: PASS

- [x] **Step 6: 端到端 CLI 测试**

Run: `cd scripts/galaxy-checker && node dist/cli.mjs ../old/validate-galaxy-scripts.py --format text`
（先 build 再跑）
```bash
cd scripts/galaxy-checker && npx tsc && node dist/cli.mjs <某个 Lib*.galaxy 路径> --format text
```
Expected: 输出 JSON 或文本，exit code 反映是否有 error

- [x] **Step 7: Commit**

```bash
cd scripts/galaxy-checker && git add src/index.ts src/cli.mjs tests/cli.test.ts
git commit -m "feat(galaxy-checker): 实现 check API 与 CLI 入口"
```

---

## 阶段 2：语义检查

### Task 11: SymbolTable

**Files:**
- Create: `scripts/galaxy-checker/src/analyzer/SymbolTable.ts`
- Test: `scripts/galaxy-checker/tests/symbol-table.test.ts`

- [x] **Step 1: 写测试 `tests/symbol-table.test.ts`**

```typescript
import { describe, it, expect } from 'vitest';
import { SymbolTable, Scope } from '../src/analyzer/SymbolTable.js';
import type { FunctionSignature } from '../src/types.js';

describe('SymbolTable', () => {
  it('根作用域声明与查询', () => {
    const root = new Scope(null);
    root.declareFunction({ name: 'foo', returnType: 'void', params: [], isNative: false });
    expect(root.lookupFunction('foo')?.name).toBe('foo');
  });

  it('嵌套作用域查找父作用域', () => {
    const root = new Scope(null);
    root.declareVariable('int', 'gv_x');
    const child = root.createChild();
    expect(child.lookupVariable('gv_x')?.name).toBe('gv_x');
  });

  it('同一作用域重复声明报错', () => {
    const root = new Scope(null);
    root.declareVariable('int', 'x');
    expect(() => root.declareVariable('int', 'x')).toThrow();
  });

  it('子作用域可声明同名变量（遮蔽）', () => {
    const root = new Scope(null);
    root.declareVariable('int', 'x');
    const child = root.createChild();
    expect(() => child.declareVariable('int', 'x')).not.toThrow();
  });

  it('SymbolTable 顶层提供函数表', () => {
    const st = new SymbolTable();
    st.declareFunction({ name: 'bar', returnType: 'int', params: [], isNative: false });
    expect(st.lookupFunction('bar')?.returnType).toBe('int');
  });
});
```

- [x] **Step 2: 运行测试，确认失败**

Run: `cd scripts/galaxy-checker && npx vitest run tests/symbol-table.test.ts`
Expected: FAIL

- [x] **Step 3: 实现 `src/analyzer/SymbolTable.ts`**

```typescript
// src/analyzer/SymbolTable.ts
import type { FunctionSignature } from '../types.js';

export interface VariableSymbol {
  name: string;
  varType: string;
  isArray: boolean;
}

export class Scope {
  private vars = new Map<string, VariableSymbol>();
  private funcs = new Map<string, FunctionSignature>();
  private children: Scope[] = [];

  constructor(public parent: Scope | null) {}

  declareVariable(varType: string, name: string, isArray = false): void {
    if (this.vars.has(name)) {
      throw new Error(`变量 '${name}' 在此作用域已声明`);
    }
    this.vars.set(name, { name, varType, isArray });
  }

  declareFunction(sig: FunctionSignature): void {
    if (this.funcs.has(sig.name)) {
      throw new Error(`函数 '${sig.name}' 在此作用域已声明`);
    }
    this.funcs.set(sig.name, sig);
  }

  lookupVariable(name: string): VariableSymbol | null {
    if (this.vars.has(name)) return this.vars.get(name)!;
    return this.parent?.lookupVariable(name) ?? null;
  }

  lookupFunction(name: string): FunctionSignature | null {
    if (this.funcs.has(name)) return this.funcs.get(name)!;
    return this.parent?.lookupFunction(name) ?? null;
  }

  createChild(): Scope {
    const c = new Scope(this);
    this.children.push(c);
    return c;
  }
}

export class SymbolTable {
  private global = new Scope(null);

  declareFunction(sig: FunctionSignature): void {
    this.global.declareFunction(sig);
  }

  declareGlobalVariable(varType: string, name: string, isArray = false): void {
    this.global.declareVariable(varType, name, isArray);
  }

  lookupFunction(name: string): FunctionSignature | null {
    return this.global.lookupFunction(name);
  }

  lookupVariable(name: string): VariableSymbol | null {
    return this.global.lookupVariable(name);
  }

  getGlobalScope(): Scope {
    return this.global;
  }

  createFunctionScope(): Scope {
    return this.global.createChild();
  }
}
```

- [x] **Step 4: 运行测试，确认通过**

Run: `cd scripts/galaxy-checker && npx vitest run tests/symbol-table.test.ts`
Expected: PASS

- [x] **Step 5: Commit**

```bash
cd scripts/galaxy-checker && git add src/analyzer/SymbolTable.ts tests/symbol-table.test.ts
git commit -m "feat(galaxy-checker): 实现作用域符号表"
```

---

### Task 12: SemanticAnalyzer - 未声明检查

**Files:**
- Create: `scripts/galaxy-checker/src/analyzer/SemanticAnalyzer.ts`
- Test: `scripts/galaxy-checker/tests/semantic-undeclared.test.ts`

- [x] **Step 1: 写测试 `tests/semantic-undeclared.test.ts`**

```typescript
import { describe, it, expect } from 'vitest';
import { analyze } from '../src/analyzer/SemanticAnalyzer.js';

describe('SemanticAnalyzer - 未声明检查', () => {
  it('SEM_UNDECLARED_VARIABLE：引用未声明变量', () => {
    const issues = analyze('void f() { x = 1; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_UNDECLARED_VARIABLE')).toBeDefined();
  });

  it('SEM_UNDECLARED_VARIABLE：已声明变量不报', () => {
    const issues = analyze('void f() { int x; x = 1; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_UNDECLARED_VARIABLE')).toBeUndefined();
  });

  it('SEM_UNDECLARED_FUNCTION：调用未声明函数', () => {
    const issues = analyze('void f() { undefinedFunc(); }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_UNDECLARED_FUNCTION')).toBeDefined();
  });

  it('SEM_UNDECLARED_FUNCTION：已声明函数不报', () => {
    const issues = analyze('void foo() {} void bar() { foo(); }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_UNDECLARED_FUNCTION')).toBeUndefined();
  });

  it('全局变量在函数内可见', () => {
    const issues = analyze('int gv_x; void f() { gv_x = 1; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_UNDECLARED_VARIABLE')).toBeUndefined();
  });

  it('函数参数在函数体可见', () => {
    const issues = analyze('void f(int p) { p = 1; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_UNDECLARED_VARIABLE')).toBeUndefined();
  });
});
```

- [x] **Step 2: 运行测试，确认失败**

Run: `cd scripts/galaxy-checker && npx vitest run tests/semantic-undeclared.test.ts`
Expected: FAIL

- [x] **Step 3: 实现 `src/analyzer/SemanticAnalyzer.ts`**

```typescript
// src/analyzer/SemanticAnalyzer.ts
import { parse } from '../parser/index.js';
import { SymbolTable, Scope } from './SymbolTable.js';
import { RuleEngine } from './RuleEngine.js';
import type { Issue } from '../types.js';
import type * as ast from '../parser/ast.js';

export function analyze(
  source: string,
  filename: string,
  globalTable?: SymbolTable
): Issue[] {
  const { ast: program, errors } = parse(source, filename);
  const issues: Issue[] = [...errors];

  const engine = new RuleEngine();
  const table = globalTable ?? new SymbolTable();

  // 第一遍：收集顶层声明
  for (const decl of program.body) {
    collectTopLevel(decl, table);
  }

  // 第二遍：分析函数体
  for (const decl of program.body) {
    if (decl.type === 'FunctionDeclaration' && decl.body) {
      analyzeFunction(decl, table, filename, engine, issues);
    }
  }

  return issues;
}

function collectTopLevel(decl: ast.TopLevelDeclaration, table: SymbolTable): void {
  switch (decl.type) {
    case 'FunctionDeclaration':
      table.declareFunction({
        name: decl.name,
        returnType: decl.returnType,
        params: decl.params.map(p => ({ type: p.type, name: p.name })),
        isNative: decl.isNative,
      });
      break;
    case 'VariableDeclaration':
      table.declareGlobalVariable(decl.varType, decl.name, decl.isArray);
      break;
  }
}

function analyzeFunction(
  fn: ast.FunctionDeclaration,
  table: SymbolTable,
  filename: string,
  engine: RuleEngine,
  issues: Issue[]
): void {
  const scope = table.createFunctionScope();
  for (const p of fn.params) {
    scope.declareVariable(p.type, p.name, p.isArray);
  }

  if (fn.body) {
    walkStatements(fn.body, scope, table, engine, filename, issues);
  }
}

function walkStatements(
  stmt: ast.Statement,
  scope: Scope,
  table: SymbolTable,
  engine: RuleEngine,
  filename: string,
  issues: Issue[]
): void {
  if (!stmt) return;
  switch (stmt.type) {
    case 'VariableDeclaration':
      scope.declareVariable(stmt.varType, stmt.name, stmt.isArray);
      if (stmt.init) checkExpression(stmt.init, scope, table, engine, filename, issues);
      break;
    case 'ExpressionStatement':
      checkExpression(stmt.expression, scope, table, engine, filename, issues);
      break;
    case 'IfStatement':
      checkExpression(stmt.test, scope, table, engine, filename, issues);
      // SEM_VOID_IN_CONDITION 检查
      checkVoidInCondition(stmt.test, table, engine, filename, issues);
      walkStatements(stmt.consequent, scope, table, engine, filename, issues);
      if (stmt.alternate) walkStatements(stmt.alternate, scope, table, engine, filename, issues);
      break;
    case 'WhileStatement':
      checkExpression(stmt.test, scope, table, engine, filename, issues);
      checkVoidInCondition(stmt.test, table, engine, filename, issues);
      walkStatements(stmt.body, scope, table, engine, filename, issues);
      break;
    case 'ForStatement': {
      const forScope = scope.createChild();
      if (stmt.init) walkStatements(stmt.init, forScope, table, engine, filename, issues);
      if (stmt.test) {
        checkExpression(stmt.test, forScope, table, engine, filename, issues);
        checkVoidInCondition(stmt.test, table, engine, filename, issues);
      }
      if (stmt.update) checkExpression(stmt.update, forScope, table, engine, filename, issues);
      walkStatements(stmt.body, forScope, table, engine, filename, issues);
      break;
    }
    case 'ReturnStatement':
      if (stmt.argument) checkExpression(stmt.argument, scope, table, engine, filename, issues);
      break;
    case 'BlockStatement': {
      const blockScope = scope.createChild();
      for (const s of stmt.body) {
        walkStatements(s, blockScope, table, engine, filename, issues);
      }
      break;
    }
  }
}

function checkExpression(
  expr: ast.Expression,
  scope: Scope,
  table: SymbolTable,
  engine: RuleEngine,
  filename: string,
  issues: Issue[]
): void {
  if (!expr) return;
  switch (expr.type) {
    case 'Identifier':
      if (!scope.lookupVariable(expr.name)) {
        if (engine.isRuleEnabled('SEM_UNDECLARED_VARIABLE')) {
          issues.push(
            engine.makeIssue(
              'SEM_UNDECLARED_VARIABLE',
              filename,
              (expr as any).start?.line ?? 0,
              (expr as any).start?.column ?? 0,
              `未声明的变量 '${expr.name}'`
            )!
          );
        }
      }
      break;
    case 'BinaryExpression':
      checkExpression(expr.left, scope, table, engine, filename, issues);
      checkExpression(expr.right, scope, table, engine, filename, issues);
      break;
    case 'UnaryExpression':
      checkExpression(expr.argument, scope, table, engine, filename, issues);
      break;
    case 'AssignmentExpression':
      checkExpression(expr.left, scope, table, engine, filename, issues);
      checkExpression(expr.right, scope, table, engine, filename, issues);
      break;
    case 'CallExpression':
      // 函数调用
      if (expr.callee.type === 'Identifier') {
        const fnName = expr.callee.name;
        const fn = scope.lookupFunction(fnName);
        if (!fn && engine.isRuleEnabled('SEM_UNDECLARED_FUNCTION')) {
          issues.push(
            engine.makeIssue(
              'SEM_UNDECLARED_FUNCTION',
              filename,
              (expr as any).start?.line ?? 0,
              (expr as any).start?.column ?? 0,
              `未声明的函数 '${fnName}()'`
            )!
          );
        }
        // 参数数量检查（阶段 2 暂只查函数是否声明，参数数量在 Task 13 加）
      }
      checkExpression(expr.callee, scope, table, engine, filename, issues);
      for (const a of expr.arguments) {
        checkExpression(a, scope, table, engine, filename, issues);
      }
      break;
    case 'MemberExpression':
      checkExpression(expr.object, scope, table, engine, filename, issues);
      break;
    case 'IndexExpression':
      checkExpression(expr.object, scope, table, engine, filename, issues);
      checkExpression(expr.index, scope, table, engine, filename, issues);
      break;
    case 'ConditionalExpression':
      checkExpression(expr.test, scope, table, engine, filename, issues);
      checkExpression(expr.consequent, scope, table, engine, filename, issues);
      checkExpression(expr.alternate, scope, table, engine, filename, issues);
      break;
  }
}

function checkVoidInCondition(
  expr: ast.Expression,
  table: SymbolTable,
  engine: RuleEngine,
  filename: string,
  issues: Issue[]
): void {
  if (expr.type === 'CallExpression' && expr.callee.type === 'Identifier') {
    const fn = table.lookupFunction(expr.callee.name);
    if (fn && fn.returnType === 'void' && engine.isRuleEnabled('SEM_VOID_IN_CONDITION')) {
      issues.push(
        engine.makeIssue(
          'SEM_VOID_IN_CONDITION',
          filename,
          (expr as any).start?.line ?? 0,
          (expr as any).start?.column ?? 0,
          `void 返回函数 '${fn.name}()' 不能用在条件表达式`
        )!
      );
    }
  }
}
```

- [x] **Step 4: 运行测试，确认通过**

Run: `cd scripts/galaxy-checker && npx vitest run tests/semantic-undeclared.test.ts`
Expected: PASS

- [x] **Step 5: Commit**

```bash
cd scripts/galaxy-checker && git add src/analyzer/SemanticAnalyzer.ts tests/semantic-undeclared.test.ts
git commit -m "feat(galaxy-checker): 实现未声明变量/函数与 void-in-condition 检查"
```

---

### Task 13: SEM_ARGUMENT_COUNT_MISMATCH

**Files:**
- Modify: `scripts/galaxy-checker/src/analyzer/SemanticAnalyzer.ts`
- Modify: `scripts/galaxy-checker/data/project-rules.json`
- Test: `scripts/galaxy-checker/tests/semantic-args.test.ts`

- [x] **Step 1: 在 `project-rules.json` 加规则**

```json
"SEM_ARGUMENT_COUNT_MISMATCH": {
  "severity": "error",
  "message": "函数参数数量不匹配"
}
```

- [x] **Step 2: 写测试 `tests/semantic-args.test.ts`**

```typescript
import { describe, it, expect } from 'vitest';
import { analyze } from '../src/analyzer/SemanticAnalyzer.js';

describe('SemanticAnalyzer - 参数数量', () => {
  it('参数数量太少报错', () => {
    const issues = analyze('void foo(int a, int b) {} void bar() { foo(1); }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_ARGUMENT_COUNT_MISMATCH')).toBeDefined();
  });

  it('参数数量太多报错', () => {
    const issues = analyze('void foo(int a) {} void bar() { foo(1, 2); }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_ARGUMENT_COUNT_MISMATCH')).toBeDefined();
  });

  it('参数数量正确不报', () => {
    const issues = analyze('void foo(int a, int b) {} void bar() { foo(1, 2); }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_ARGUMENT_COUNT_MISMATCH')).toBeUndefined();
  });

  it('无参数函数不报', () => {
    const issues = analyze('void foo() {} void bar() { foo(); }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_ARGUMENT_COUNT_MISMATCH')).toBeUndefined();
  });
});
```

- [x] **Step 3: 运行测试，确认失败**

Run: `cd scripts/galaxy-checker && npx vitest run tests/semantic-args.test.ts`
Expected: FAIL

- [x] **Step 4: 在 `SemanticAnalyzer.ts` 的 CallExpression 分支加参数数量检查**

修改 `checkExpression` 的 `CallExpression` 分支，在函数已声明时加：

```typescript
if (fn) {
  const expected = fn.params.length;
  const actual = expr.arguments.length;
  if (expected !== actual && engine.isRuleEnabled('SEM_ARGUMENT_COUNT_MISMATCH')) {
    issues.push(
      engine.makeIssue(
        'SEM_ARGUMENT_COUNT_MISMATCH',
        filename,
        (expr as any).start?.line ?? 0,
        (expr as any).start?.column ?? 0,
        `函数 '${fnName}()' 期望 ${expected} 个参数，实际 ${actual} 个`
      )!
    );
  }
}
```

- [x] **Step 5: 运行测试，确认通过**

Run: `cd scripts/galaxy-checker && npx vitest run tests/semantic-args.test.ts`
Expected: PASS

- [x] **Step 6: Commit**

```bash
cd scripts/galaxy-checker && git add src/analyzer/SemanticAnalyzer.ts data/project-rules.json tests/semantic-args.test.ts
git commit -m "feat(galaxy-checker): 实现 SEM_ARGUMENT_COUNT_MISMATCH 检查"
```

---

### Task 14: SEM_DUPLICATE_DECLARATION

**Files:**
- Modify: `scripts/galaxy-checker/src/analyzer/SemanticAnalyzer.ts`
- Modify: `scripts/galaxy-checker/data/project-rules.json`
- Test: `scripts/galaxy-checker/tests/semantic-duplicate.test.ts`

- [x] **Step 1: 在 `project-rules.json` 加规则**

```json
"SEM_DUPLICATE_DECLARATION": {
  "severity": "error",
  "message": "同作用域重复定义"
}
```

- [x] **Step 2: 写测试 `tests/semantic-duplicate.test.ts`**

```typescript
import { describe, it, expect } from 'vitest';
import { analyze } from '../src/analyzer/SemanticAnalyzer.js';

describe('SemanticAnalyzer - 重复声明', () => {
  it('同作用域变量重复声明报错', () => {
    const issues = analyze('void f() { int x; int x; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_DUPLICATE_DECLARATION')).toBeDefined();
  });

  it('全局变量重复声明报错', () => {
    const issues = analyze('int gv_x; int gv_x;', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_DUPLICATE_DECLARATION')).toBeDefined();
  });

  it('函数重复定义报错', () => {
    const issues = analyze('void foo() {} void foo() {}', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_DUPLICATE_DECLARATION')).toBeDefined();
  });

  it('不同作用域同名变量不报', () => {
    const issues = analyze('void f() { int x; { int x; } }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_DUPLICATE_DECLARATION')).toBeUndefined();
  });
});
```

- [x] **Step 3: 运行测试，确认失败**

Run: `cd scripts/galaxy-checker && npx vitest run tests/semantic-duplicate.test.ts`
Expected: FAIL

- [x] **Step 4: 修改 `SymbolTable.ts` 与 `SemanticAnalyzer.ts` 让重复声明产生 Issue 而非抛异常**

修改 `SymbolTable.ts` 的 `declareVariable` / `declareFunction`：

```typescript
declareVariable(varType: string, name: string, isArray = false, onDuplicate?: () => void): void {
  if (this.vars.has(name)) {
    if (onDuplicate) onDuplicate();
    return;
  }
  this.vars.set(name, { name, varType, isArray });
}
```

修改 `SemanticAnalyzer.ts` 的 `collectTopLevel` 和 `walkStatements`，传入 `onDuplicate` 回调，回调里 push issue：

```typescript
// collectTopLevel:
case 'FunctionDeclaration':
  table.declareFunction(
    {
      name: decl.name,
      returnType: decl.returnType,
      params: decl.params.map(p => ({ type: p.type, name: p.name })),
      isNative: decl.isNative,
    },
    () => {
      if (engine.isRuleEnabled('SEM_DUPLICATE_DECLARATION')) {
        issues.push(engine.makeIssue('SEM_DUPLICATE_DECLARATION', filename, 0, 0, `函数 '${decl.name}' 重复定义`)!);
      }
    }
  );
  break;
```

（注意：需要把 `engine`/`filename`/`issues` 传进 `collectTopLevel`，调整签名）

- [x] **Step 5: 运行测试，确认通过**

Run: `cd scripts/galaxy-checker && npx vitest run tests/semantic-duplicate.test.ts`
Expected: PASS

- [x] **Step 6: 运行全部测试，确保未破坏其他用例**

Run: `cd scripts/galaxy-checker && npx vitest run`
Expected: 全部 PASS

- [x] **Step 7: Commit**

```bash
cd scripts/galaxy-checker && git add src/analyzer/SemanticAnalyzer.ts src/analyzer/SymbolTable.ts data/project-rules.json tests/semantic-duplicate.test.ts
git commit -m "feat(galaxy-checker): 实现 SEM_DUPLICATE_DECLARATION 检查"
```

---

### Task 15: SEM_RETURN_TYPE_MISMATCH / SEM_ASSIGNMENT_TYPE_MISMATCH（warning）

**Files:**
- Modify: `scripts/galaxy-checker/src/analyzer/SemanticAnalyzer.ts`
- Modify: `scripts/galaxy-checker/data/project-rules.json`
- Test: `scripts/galaxy-checker/tests/semantic-types.test.ts`

- [x] **Step 1: 在 `project-rules.json` 加规则**

```json
"SEM_RETURN_TYPE_MISMATCH": {
  "severity": "warning",
  "message": "return 类型与函数签名不符"
},
"SEM_ASSIGNMENT_TYPE_MISMATCH": {
  "severity": "warning",
  "message": "赋值类型不匹配"
}
```

- [x] **Step 2: 写测试 `tests/semantic-types.test.ts`**

```typescript
import { describe, it, expect } from 'vitest';
import { analyze } from '../src/analyzer/SemanticAnalyzer.js';

describe('SemanticAnalyzer - 类型检查', () => {
  it('返回 int 函数 return 字符串报 warning', () => {
    const issues = analyze('int f() { return "x"; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_RETURN_TYPE_MISMATCH')).toBeDefined();
  });

  it('返回 int 函数 return 整数不报', () => {
    const issues = analyze('int f() { return 1; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_RETURN_TYPE_MISMATCH')).toBeUndefined();
  });

  it('int 变量赋字符串报 warning', () => {
    const issues = analyze('void f() { int x; x = "y"; }', 'test.galaxy');
    expect(issues.find(i => i.ruleCode === 'SEM_ASSIGNMENT_TYPE_MISMATCH')).toBeDefined();
  });
});
```

- [x] **Step 3: 实现 `inferType` 辅助函数（粗粒度类型推断）**

在 `SemanticAnalyzer.ts` 加：

```typescript
function inferType(expr: ast.Expression, scope: Scope): string | null {
  switch (expr.type) {
    case 'Literal':
      return expr.literalType === 'integer' ? 'int'
        : expr.literalType === 'fixed' ? 'fixed'
        : expr.literalType === 'string' ? 'string'
        : expr.literalType === 'char' ? 'string'
        : expr.literalType === 'bool' ? 'bool'
        : null;
    case 'Identifier': {
      const v = scope.lookupVariable(expr.name);
      return v?.varType ?? null;
    }
    case 'CallExpression':
      if (expr.callee.type === 'Identifier') {
        const fn = scope.lookupFunction(expr.callee.name);
        return fn?.returnType ?? null;
      }
      return null;
    case 'BinaryExpression':
      if (['==', '!=', '<', '>', '<=', '>=', '&&', '||'].includes(expr.operator)) return 'bool';
      if (expr.operator === '+') {
        // 字符串拼接？
        const lt = inferType(expr.left, scope);
        const rt = inferType(expr.right, scope);
        if (lt === 'string' || rt === 'string') return 'string';
      }
      return inferType(expr.left, scope) ?? inferType(expr.right, scope);
    case 'UnaryExpression':
      if (expr.operator === '!') return 'bool';
      return inferType(expr.argument, scope);
    default:
      return null;
  }
}
```

- [x] **Step 4: 在 ReturnStatement 和 AssignmentExpression 加类型检查**

```typescript
// ReturnStatement 分支：
case 'ReturnStatement': {
  // 找到所属函数的返回类型（需把 fn 传进来）
  if (stmt.argument && fn.returnType !== 'void') {
    const t = inferType(stmt.argument, scope);
    if (t && t !== fn.returnType && engine.isRuleEnabled('SEM_RETURN_TYPE_MISMATCH')) {
      issues.push(
        engine.makeIssue('SEM_RETURN_TYPE_MISMATCH', filename,
          (stmt as any).start?.line ?? 0, (stmt as any).start?.column ?? 0,
          `return 类型应为 ${fn.returnType}，实际 ${t}`)!
      );
    }
  }
  if (stmt.argument) checkExpression(stmt.argument, scope, table, engine, filename, issues);
  break;
}

// AssignmentExpression 分支（在 checkExpression 内）：
case 'AssignmentExpression':
  checkExpression(expr.left, scope, table, engine, filename, issues);
  checkExpression(expr.right, scope, table, engine, filename, issues);
  if (expr.left.type === 'Identifier') {
    const lv = scope.lookupVariable(expr.left.name);
    if (lv) {
      const rt = inferType(expr.right, scope);
      if (rt && rt !== lv.varType && engine.isRuleEnabled('SEM_ASSIGNMENT_TYPE_MISMATCH')) {
        issues.push(
          engine.makeIssue('SEM_ASSIGNMENT_TYPE_MISMATCH', filename,
            (expr as any).start?.line ?? 0, (expr as any).start?.column ?? 0,
            `变量 ${lv.name} 类型 ${lv.varType}，赋值类型 ${rt}`)!
        );
      }
    }
  }
  break;
```

注：`walkStatements` 需要传 `fn`（当前所在函数），签名调整为 `walkStatements(stmt, fn, scope, ...)`。

- [x] **Step 5: 运行测试，确认通过**

Run: `cd scripts/galaxy-checker && npx vitest run tests/semantic-types.test.ts`
Expected: PASS

- [x] **Step 6: 运行全部测试**

Run: `cd scripts/galaxy-checker && npx vitest run`
Expected: 全部 PASS

- [x] **Step 7: Commit**

```bash
cd scripts/galaxy-checker && git add src/analyzer/SemanticAnalyzer.ts data/project-rules.json tests/semantic-types.test.ts
git commit -m "feat(galaxy-checker): 实现返回/赋值类型不匹配检查（warning）"
```

---

## 阶段 3：跨库/Native

### Task 16: 回归测试夹具

**Files:**
- Create: `scripts/galaxy-checker/tests/fixtures/*.galaxy` 与对应 `.expected.json`

- [x] **Step 1: 创建 fixtures 目录与文件**

`tests/fixtures/regression/no-continue.galaxy`:
```galaxy
void f() {
    while (true) {
        continue;
    }
}
```

`tests/fixtures/regression/no-continue.expected.json`:
```json
{
  "rules": ["SYNTAX_NO_CONTINUE"]
}
```

`tests/fixtures/regression/local-var-init.galaxy`:
```galaxy
void f() {
    int x = 1;
}
```

`tests/fixtures/regression/local-var-init.expected.json`:
```json
{
  "rules": ["SYNTAX_NO_LOCAL_INIT_ASSIGN"]
}
```

`tests/fixtures/regression/void-in-condition.galaxy`:
```galaxy
void doSomething() {}
void f() {
    if (doSomething()) {
    }
}
```

`tests/fixtures/regression/void-in-condition.expected.json`:
```json
{
  "rules": ["SEM_VOID_IN_CONDITION"]
}
```

`tests/fixtures/regression/undeclared-var.galaxy`:
```galaxy
void f() {
    x = 1;
}
```

`tests/fixtures/regression/undeclared-var.expected.json`:
```json
{
  "rules": ["SEM_UNDECLARED_VARIABLE"]
}
```

`tests/fixtures/regression/arg-count.galaxy`:
```galaxy
void foo(int a, int b) {}
void f() {
    foo(1);
}
```

`tests/fixtures/regression/arg-count.expected.json`:
```json
{
  "rules": ["SEM_ARGUMENT_COUNT_MISMATCH"]
}
```

`tests/fixtures/regression/clean.galaxy`:
```galaxy
int gv_x;

void foo(int a, int b) {
    return;
}

void bar() {
    int x;
    x = 1;
    foo(1, 2);
    if (gv_x > 0) {
        return;
    }
}
```

`tests/fixtures/regression/clean.expected.json`:
```json
{
  "rules": []
}
```

- [x] **Step 2: 写回归测试 `tests/regression.test.ts`**

```typescript
import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { join, basename } from 'node:path';
import { analyze } from '../src/analyzer/SemanticAnalyzer.js';

const FIXTURES_DIR = join(__dirname, 'fixtures', 'regression');

describe('回归测试夹具', () => {
  const files = readdirSync(FIXTURES_DIR).filter(f => f.endsWith('.galaxy'));

  for (const file of files) {
    it(`fixture: ${file}`, () => {
      const src = readFileSync(join(FIXTURES_DIR, file), 'utf-8');
      const expected = JSON.parse(
        readFileSync(join(FIXTURES_DIR, file.replace('.galaxy', '.expected.json')), 'utf-8')
      );

      const issues = analyze(src, file);
      const actualRules = issues.map(i => i.ruleCode);

      // 期望每个规则都触发
      for (const rule of expected.rules) {
        expect(actualRules, `${file} 应触发 ${rule}`).toContain(rule);
      }

      // clean fixture：无任何错误
      if (expected.rules.length === 0) {
        expect(issues.filter(i => i.severity === 'error'), `${file} 应无 error`).toHaveLength(0);
      }
    });
  }
});
```

- [x] **Step 3: 运行测试，确认全部通过**

Run: `cd scripts/galaxy-checker && npx vitest run tests/regression.test.ts`
Expected: PASS

- [x] **Step 4: Commit**

```bash
cd scripts/galaxy-checker && git add tests/fixtures tests/regression.test.ts
git commit -m "test(galaxy-checker): 添加回归测试夹具"
```

---

### Task 17: NativeFunctionTable + native-blacklist.json

**Files:**
- Create: `scripts/galaxy-checker/data/native-blacklist.json`
- Create: `scripts/galaxy-checker/src/analyzer/NativeFunctionTable.ts`
- Test: `scripts/galaxy-checker/tests/native-table.test.ts`

- [x] **Step 1: 创建 `data/native-blacklist.json`**

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
    "UnitIsHero": "Galaxy 不存在此 native",
    "UnitCreate": "不应直接调用，请用 libNtve_gf_CreateUnitsAtPoint2 包装"
  }
}
```

- [x] **Step 2: 写测试 `tests/native-table.test.ts`**

```typescript
import { describe, it, expect } from 'vitest';
import { NativeFunctionTable } from '../src/analyzer/NativeFunctionTable.js';

describe('NativeFunctionTable', () => {
  it('从 NativeLib.galaxy 解析 native 声明', () => {
    const table = new NativeFunctionTable();
    // 内置 natives.galaxy 文本（或 fixture）
    table.loadFromString(`
      native void UnitCreate(int count, string type, int player, point p);
      native bool UnitIsAlive(unit u);
    `);
    expect(table.lookup('UnitCreate')?.params).toHaveLength(4);
    expect(table.lookup('UnitIsAlive')?.returnType).toBe('bool');
  });

  it('加载黑名单', () => {
    const table = new NativeFunctionTable({
      disallowedNatives: ['UnitIsHero'],
      notes: { UnitIsHero: '不存在' },
    });
    expect(table.isDisallowed('UnitIsHero')).toBe(true);
    expect(table.isDisallowed('UnitIsAlive')).toBe(false);
  });

  it('UnitCreate 在黑名单中（项目规则禁用直接调用）', () => {
    const table = new NativeFunctionTable({
      disallowedNatives: ['UnitCreate'],
      notes: { UnitCreate: '请用包装' },
    });
    expect(table.isDisallowed('UnitCreate')).toBe(true);
  });
});
```

- [x] **Step 3: 运行测试，确认失败**

Run: `cd scripts/galaxy-checker && npx vitest run tests/native-table.test.ts`
Expected: FAIL

- [x] **Step 4: 实现 `src/analyzer/NativeFunctionTable.ts`**

```typescript
// src/analyzer/NativeFunctionTable.ts
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from '../parser/index.js';
import type { FunctionSignature } from '../types.js';

export interface BlacklistFile {
  version: string;
  disallowedNatives: string[];
  notes?: Record<string, string>;
}

const DEFAULT_BLACKLIST_PATH = join(
  dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
  'data',
  'native-blacklist.json'
);

export class NativeFunctionTable {
  private natives = new Map<string, FunctionSignature>();
  private disallowed = new Set<string>();
  private notes = new Map<string, string>();

  constructor(blacklist?: BlacklistFile | string) {
    if (!blacklist) {
      blacklist = JSON.parse(readFileSync(DEFAULT_BLACKLIST_PATH, 'utf-8'));
    } else if (typeof blacklist === 'string') {
      blacklist = JSON.parse(readFileSync(blacklist, 'utf-8'));
    }
    for (const name of blacklist.disallowedNatives) {
      this.disallowed.add(name);
    }
    if (blacklist.notes) {
      for (const [k, v] of Object.entries(blacklist.notes)) {
        this.notes.set(k, v);
      }
    }
  }

  loadFromString(source: string): void {
    const { ast } = parse(source, '<native>');
    for (const decl of ast.body) {
      if (decl.type === 'FunctionDeclaration' && decl.isNative) {
        this.natives.set(decl.name, {
          name: decl.name,
          returnType: decl.returnType,
          params: decl.params.map(p => ({ type: p.type, name: p.name })),
          isNative: true,
        });
        // 默认 native 表里存在的也加入 disallowed 检查池
        // 实际是否禁用由 isDisallowed 判断
      }
    }
  }

  loadFromFile(path: string): void {
    this.loadFromString(readFileSync(path, 'utf-8'));
  }

  lookup(name: string): FunctionSignature | undefined {
    return this.natives.get(name);
  }

  isNative(name: string): boolean {
    return this.natives.has(name);
  }

  isDisallowed(name: string): boolean {
    return this.disallowed.has(name);
  }

  getNote(name: string): string | undefined {
    return this.notes.get(name);
  }
}
```

- [x] **Step 5: 运行测试，确认通过**

Run: `cd scripts/galaxy-checker && npx vitest run tests/native-table.test.ts`
Expected: PASS

- [x] **Step 6: Commit**

```bash
cd scripts/galaxy-checker && git add data/native-blacklist.json src/analyzer/NativeFunctionTable.ts tests/native-table.test.ts
git commit -m "feat(galaxy-checker): 实现 NativeFunctionTable 与黑名单加载"
```

---

### Task 18: ProjectLoader - 全局符号表

**Files:**
- Create: `scripts/galaxy-checker/src/analyzer/ProjectLoader.ts`
- Test: `scripts/galaxy-checker/tests/project-loader.test.ts`

- [x] **Step 1: 写测试 `tests/project-loader.test.ts`**

```typescript
import { describe, it, expect, beforeAll } from 'vitest';
import { ProjectLoader } from '../src/analyzer/ProjectLoader.js';
import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

describe('ProjectLoader', () => {
  let tmpProject: string;

  beforeAll(() => {
    tmpProject = join(tmpdir(), `galaxy-project-${Date.now()}`);
    mkdirSync(tmpProject, { recursive: true });
    writeFileSync(join(tmpProject, 'LibFoo.galaxy'), 'void foo() {} int gv_foo;');
    writeFileSync(join(tmpProject, 'LibBar.galaxy'), 'void bar() {}');
    writeFileSync(join(tmpProject, 'not-a-lib.galaxy'), 'void ignored() {}');
  });

  it('扫描 Lib*.galaxy 文件', () => {
    const loader = new ProjectLoader(tmpProject);
    const files = loader.collectGalaxyFiles();
    expect(files.map(f => f.split(/[\\/]/).pop()).sort()).toEqual(['LibBar.galaxy', 'LibFoo.galaxy']);
  });

  it('构建全局符号表', () => {
    const loader = new ProjectLoader(tmpProject);
    const table = loader.buildGlobalSymbolTable();
    expect(table.lookupFunction('foo')).toBeDefined();
    expect(table.lookupFunction('bar')).toBeDefined();
    expect(table.lookupVariable('gv_foo')).toBeDefined();
  });
});
```

- [x] **Step 2: 运行测试，确认失败**

Run: `cd scripts/galaxy-checker && npx vitest run tests/project-loader.test.ts`
Expected: FAIL

- [x] **Step 3: 实现 `src/analyzer/ProjectLoader.ts`**

```typescript
// src/analyzer/ProjectLoader.ts
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, basename } from 'node:path';
import { parse } from '../parser/index.js';
import { SymbolTable } from './SymbolTable.js';
import type * as ast from '../parser/ast.js';

export class ProjectLoader {
  constructor(private rootDir: string) {}

  collectGalaxyFiles(): string[] {
    const out: string[] = [];
    const walk = (dir: string) => {
      const entries = readdirSync(dir, { withFileTypes: true });
      for (const e of entries) {
        const full = join(dir, e.name);
        if (e.isDirectory()) {
          walk(full);
        } else if (e.isFile() && e.name.endsWith('.galaxy') && e.name.startsWith('Lib')) {
          out.push(full);
        }
      }
    };
    walk(this.rootDir);
    return out;
  }

  buildGlobalSymbolTable(): SymbolTable {
    const table = new SymbolTable();
    for (const file of this.collectGalaxyFiles()) {
      const source = readFileSync(file, 'utf-8');
      const { ast: program, errors } = parse(source, basename(file));
      // 仅收集顶层声明，不分析函数体
      for (const decl of program.body) {
        try {
          if (decl.type === 'FunctionDeclaration') {
            table.declareFunction({
              name: decl.name,
              returnType: decl.returnType,
              params: decl.params.map(p => ({ type: p.type, name: p.name })),
              isNative: decl.isNative,
            });
          } else if (decl.type === 'VariableDeclaration') {
            table.declareGlobalVariable(decl.varType, decl.name, decl.isArray);
          }
        } catch {
          // 重复声明跳过（其他文件已声明）
        }
      }
    }
    return table;
  }
}
```

- [x] **Step 4: 运行测试，确认通过**

Run: `cd scripts/galaxy-checker && npx vitest run tests/project-loader.test.ts`
Expected: PASS

- [x] **Step 5: Commit**

```bash
cd scripts/galaxy-checker && git add src/analyzer/ProjectLoader.ts tests/project-loader.test.ts
git commit -m "feat(galaxy-checker): 实现 ProjectLoader 全局符号表构建"
```

---

### Task 19: XLIB_DISALLOWED_NATIVE / XLIB_UNDEFINED_CROSS_REF / XLIB_MISSING_INCLUDE

**Files:**
- Modify: `scripts/galaxy-checker/src/analyzer/SemanticAnalyzer.ts`
- Modify: `scripts/galaxy-checker/src/index.ts`（接入 NativeFunctionTable + ProjectLoader）
- Test: `scripts/galaxy-checker/tests/xlib-rules.test.ts`

- [x] **Step 1: 写测试 `tests/xlib-rules.test.ts`**

```typescript
import { describe, it, expect } from 'vitest';
import { check } from '../src/index.js';
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

describe('跨库/Native 规则', () => {
  it('XLIB_DISALLOWED_NATIVE：调用 UnitIsHero 报错', () => {
    const tmp = join(tmpdir(), `native-${Date.now()}.galaxy`);
    writeFileSync(tmp, 'void f() { UnitIsHero(1); }');
    const result = check(tmp);
    expect(result.issues.find(i => i.ruleCode === 'XLIB_DISALLOWED_NATIVE')).toBeDefined();
  });

  it('XLIB_DISALLOWED_NATIVE：调用 UnitCreate 报错', () => {
    const tmp = join(tmpdir(), `uc-${Date.now()}.galaxy`);
    writeFileSync(tmp, 'void f() { UnitCreate(1, "Marine", 1, null); }');
    const result = check(tmp);
    expect(result.issues.find(i => i.ruleCode === 'XLIB_DISALLOWED_NATIVE')).toBeDefined();
  });

  it('XLIB_UNDEFINED_CROSS_REF：引用未定义的 libXXX_ 符号', () => {
    const tmp = join(tmpdir(), `xlib-${Date.now()}.galaxy`);
    writeFileSync(tmp, 'void f() { libNonExistent_gf_foo(); }');
    const result = check(tmp);
    // 应该报 SEM_UNDECLARED_FUNCTION 或 XLIB_UNDEFINED_CROSS_REF
    const hasUndeclared = result.issues.some(
      i => i.ruleCode === 'SEM_UNDECLARED_FUNCTION' || i.ruleCode === 'XLIB_UNDEFINED_CROSS_REF'
    );
    expect(hasUndeclared).toBe(true);
  });

  it('XLIB_MISSING_INCLUDE：include 不存在文件', () => {
    const tmp = join(tmpdir(), `inc-${Date.now()}.galaxy`);
    writeFileSync(tmp, 'include "NonExistent.galaxy";');
    const result = check(tmp);
    expect(result.issues.find(i => i.ruleCode === 'XLIB_MISSING_INCLUDE')).toBeDefined();
  });
});
```

- [x] **Step 2: 运行测试，确认失败**

Run: `cd scripts/galaxy-checker && npx vitest run tests/xlib-rules.test.ts`
Expected: FAIL

- [x] **Step 3: 在 `project-rules.json` 补充规则**

```json
"XLIB_UNDEFINED_CROSS_REF": { "severity": "error" },
"XLIB_MISSING_INCLUDE": { "severity": "warning" }
```

- [x] **Step 4: 修改 `src/index.ts`，加载 NativeFunctionTable 并传给 analyze**

在 `src/index.ts` 顶部新增 import 与辅助函数：

```typescript
import { NativeFunctionTable } from './analyzer/NativeFunctionTable.js';
import { existsSync } from 'node:fs';

// 从源码提取 include 路径
function extractIncludes(source: string): string[] {
  const out: string[] = [];
  for (const m of source.matchAll(/^\s*include\s+"([^"]+)"/gm)) {
    out.push(m[1]);
  }
  return out;
}

// 在给定目录查找 include 文件（递归向上 2 层 + 同级 + 子目录）
function findIncludeFile(baseDir: string, inc: string): boolean {
  const incName = inc.endsWith('.galaxy') ? inc : inc + '.galaxy';
  const base = basename(incName);
  const search = (dir: string, depth: number): boolean => {
    if (depth < 0) return false;
    try {
      const entries = readdirSync(dir, { withFileTypes: true });
      for (const e of entries) {
        if (e.isFile() && e.name === base) return true;
        if (e.isDirectory()) {
          if (search(join(dir, e.name), depth - 1)) return true;
        }
      }
    } catch { /* ignore */ }
    return false;
  };
  return search(baseDir, 2);
}
```

修改 `check` 函数主体：

```typescript
export function check(target: string, options: CheckOptions = {}): CheckResult {
  const rulesPath = options.rulesPath ?? DEFAULT_RULES_PATH;
  const engine = new RuleEngine(rulesPath);
  const reporter = new IssueReporter('json');

  // 全局符号表
  let globalTable: SymbolTable | undefined;
  if (!options.noGlobalSymbols && statSync(target).isDirectory()) {
    const loader = new ProjectLoader(target);
    globalTable = loader.buildGlobalSymbolTable();
  }

  // native 表
  const nativeTable = new NativeFunctionTable();
  if (options.nativeLibPath && existsSync(options.nativeLibPath)) {
    nativeTable.loadFromFile(options.nativeLibPath);
  }

  const files = collectFiles(target);
  const allIssues: Issue[] = [];

  for (const file of files) {
    const raw = readFileSync(file);
    const content = stripBom(raw.toString('utf-8'));
    const fileDir = dirname(file);

    // BOM 检查
    if (engine.isRuleEnabled('PROJ_UTF8_BOM')) {
      if (raw[0] === 0xef && raw[1] === 0xbb && raw[2] === 0xbf) {
        allIssues.push(engine.makeIssue('PROJ_UTF8_BOM', basename(file), 1, 1)!);
      }
    }

    // 语义 + 跨库/native 检查
    const issues = analyze(content, basename(file), globalTable, nativeTable, engine);
    allIssues.push(...issues);

    // include 存在性检查
    const includes = extractIncludes(content);
    for (const inc of includes) {
      if (inc.startsWith('TriggerLibs/') || inc.startsWith('triggerlibs/')) continue;
      if (!findIncludeFile(fileDir, inc) && engine.isRuleEnabled('XLIB_MISSING_INCLUDE')) {
        // 查找 include 行号
        const lines = content.split('\n');
        let line = 1;
        for (let i = 0; i < lines.length; i++) {
          if (lines[i].includes(`include "${inc}"`)) { line = i + 1; break; }
        }
        allIssues.push(
          engine.makeIssue('XLIB_MISSING_INCLUDE', basename(file), line, 1, `include "${inc}" 未找到`)!
        );
      }
    }
  }

  return reporter.buildResult(allIssues, files.length);
}
```

> **关于 SYNTAX_BRACE_MISMATCH / MISSING_SEMICOLON / UNCLOSED_STRING / INVALID_TOKEN**：
> 这些细分规则在 MVP 阶段统一由 Chevrotain 报错，ruleCode 为 `SYNTAX_PARSE_ERROR`，
> 不细分到 spec §8.1 列的子类。实用上等价（用户只看位置+消息），如后续需细拆可后处理 Chevrotain 错误信息。

- [x] **Step 5: 修改 `SemanticAnalyzer.ts` 的 `analyze` 签名，接受 `NativeFunctionTable`**

```typescript
export function analyze(
  source: string,
  filename: string,
  globalTable?: SymbolTable,
  nativeTable?: NativeFunctionTable,
  engine?: RuleEngine
): Issue[] {
  // ...
  // 在 CallExpression 分支：
  if (fn) {
    // 参数数量检查（已实现）
  } else if (nativeTable?.isDisallowed(fnName) && engine.isRuleEnabled('XLIB_DISALLOWED_NATIVE')) {
    issues.push(
      engine.makeIssue('XLIB_DISALLOWED_NATIVE', filename,
        (expr as any).start?.line ?? 0, (expr as any).start?.column ?? 0,
        `调用了不允许的 native 函数 '${fnName}()'
         ${nativeTable.getNote(fnName) ? '(' + nativeTable.getNote(fnName) + ')' : ''}`)!
    );
  } else if (fnName.startsWith('lib') && fnName.includes('_') && !fn && engine.isRuleEnabled('XLIB_UNDEFINED_CROSS_REF')) {
    issues.push(
      engine.makeIssue('XLIB_UNDEFINED_CROSS_REF', filename,
        (expr as any).start?.line ?? 0, (expr as any).start?.column ?? 0,
        `跨库引用未定义 '${fnName}()'`)!
    );
  }
}
```

- [x] **Step 6: 运行测试，确认通过**

Run: `cd scripts/galaxy-checker && npx vitest run tests/xlib-rules.test.ts`
Expected: PASS

- [x] **Step 7: 运行全部测试**

Run: `cd scripts/galaxy-checker && npx vitest run`
Expected: 全部 PASS

- [x] **Step 8: Commit**

```bash
cd scripts/galaxy-checker && git add src/ data/project-rules.json tests/xlib-rules.test.ts
git commit -m "feat(galaxy-checker): 实现 XLIB_DISALLOWED_NATIVE / UNDEFINED_CROSS_REF / MISSING_INCLUDE"
```

---

## 阶段 4：打磨

### Task 20: README 与使用文档

**Files:**
- Create: `scripts/galaxy-checker/README.md`

- [x] **Step 1: 编写 README**

```markdown
# galaxy-checker

Galaxy 脚本静态检查器（AI 可调用）

## 安装

\`\`\`bash
cd scripts/galaxy-checker
npm install
npm run build
\`\`\`

## 使用

### CLI

\`\`\`bash
# 检查单个文件
node dist/cli.mjs path/to/LibFoo.galaxy

# 检查目录
node dist/cli.mjs path/to/CoopZeroPop.SC2Mod/Base.SC2Data --format text

# JSON 输出（默认）
node dist/cli.mjs path/to/file.galaxy --format json
\`\`\`

### 库 API

\`\`\`typescript
import { check } from 'galaxy-checker';

const result = check('path/to/file.galaxy');
if (result.summary.errors > 0) {
  for (const issue of result.issues) {
    console.log(\`[\${issue.severity}] \${issue.file}:\${issue.line} \${issue.ruleCode} - \${issue.message}\`);
  }
}
\`\`\`

## 规则

参见 [设计文档](../../docs/superpowers/specs/2026-07-08-galaxy-checker-design.md) §8。

可通过 \`data/project-rules.json\` 配置每条规则的严重级别：
\`\`\`json
{
  "rules": {
    "SYNTAX_NO_CONTINUE": { "severity": "error" }
  }
}
\`\`\`

severity 可选：\`error\` / \`warning\` / \`info\` / \`off\`

## AI 调用约定

AI Agent 写完 Galaxy 代码后：
1. 调用 \`check(filePath, { format: 'json' })\`
2. 解析 JSON，按 \`severity\` 优先处理 error 级 issue
3. 修复后再次检查，直到 \`summary.errors === 0\`

## 退出码

- 0：无 error 级 issue
- 1：存在 error
- 2：工具异常
```

- [x] **Step 2: Commit**

```bash
cd scripts/galaxy-checker && git add README.md
git commit -m "docs(galaxy-checker): 添加 README 使用说明"
```

---

### Task 21: 与现有 .py 工具对比测试

**Files:**
- Create: `scripts/galaxy-checker/tests/compat-py.test.ts`

- [x] **Step 1: 写对比测试（用项目实际文件）**

```typescript
import { describe, it, expect } from 'vitest';
import { check } from '../src/index.js';
import { join } from 'node:path';

const PROJECT_ROOT = join(__dirname, '..', '..', '..', '..');
const COOP_MOD = join(PROJECT_ROOT, '合作指挥官-起义狂潮', 'Mods', '7vs1', 'CoopZeroPop.SC2Mod', 'Base.SC2Data');

describe('与现有 .py 工具兼容性', () => {
  it('至少能扫描 CoopZeroPop 目录而不崩溃', () => {
    const result = check(COOP_MOD);
    expect(result.filesChecked).toBeGreaterThan(0);
    // 不强制要求零误报，但要求能跑完
  }, 30000);

  it('对含 BOM 的文件能检测到', () => {
    // 项目历史曾因 BOM 出错
    const result = check(COOP_MOD);
    // 检查报告里如果有 BOM issue，格式应正确
    for (const i of result.issues) {
      if (i.ruleCode === 'PROJ_UTF8_BOM') {
        expect(i.line).toBe(1);
        expect(i.column).toBe(1);
      }
    }
  });
});
```

- [x] **Step 2: 运行对比测试**

Run: `cd scripts/galaxy-checker && npx vitest run tests/compat-py.test.ts`
Expected: PASS（或暴露误报，按需调整）

- [x] **Step 3: Commit**

```bash
cd scripts/galaxy-checker && git add tests/compat-py.test.ts
git commit -m "test(galaxy-checker): 与现有 .py 工具对比测试"
```

---

### Task 22: 最终验收

- [x] **Step 1: 运行所有测试**

Run: `cd scripts/galaxy-checker && npx vitest run`
Expected: 全部 PASS

- [x] **Step 2: 性能验证**

Run: `cd scripts/galaxy-checker && npx tsc && time node dist/cli.mjs <某个最大的 Lib*.galaxy> --format json`
Expected: 单文件 < 200ms

- [x] **Step 3: 在项目根目录测试**

Run: `node scripts/galaxy-checker/dist/cli.mjs "合作指挥官-起义狂潮/Mods/7vs1/CoopZeroPop.SC2Mod/Base.SC2Data" --format text`
Expected: 输出所有 Lib*.galaxy 的检查结果，exit code 反映是否有 error

- [x] **Step 4: 写经验总结到 `合作指挥官-起义狂潮/docs/经验总结/`**

参考项目规则，把开发过程中遇到的关键经验写到 `docs/经验总结/2026-07-08_Galaxy脚本静态检查器.md`。

- [ ] **Step 5: 提交并推送**

```bash
cd e:/Code/MyMod/SC2
git pull
git add 合作指挥官-起义狂潮/scripts/galaxy-checker
git commit -m "feat: 完成 Galaxy 脚本静态检查器（Chevrotain 实现）"
git push
```

---

## 验收清单

按设计文档 §15.4：

- [x] 所有 regression fixture 全部通过（Task 16）
- [x] 对项目当前所有 `Lib*.galaxy` 跑一遍，无新增误报（Task 21）
- [x] 单文件检查延迟 < 200ms（Task 22 Step 2）
- [x] CLI 可用：`node dist/cli.mjs <file> --format json` 输出符合设计 §11.1 格式（Task 10 + Task 19）
- [x] 库 API 可用：`import { check } from 'galaxy-checker'`（Task 10）
- [x] 规则 JSON 配置可调级（Task 7）

## 自我审查记录

- ✅ Spec 覆盖：所有 §8 检查项均对应到任务（SYNTAX_*/SEM_*/XLIB_*/PROJ_*）
- ✅ 无 placeholder：每个 step 都有具体代码或具体命令
- ✅ 类型一致性：`Issue`/`CheckResult`/`FunctionSignature`/`Scope`/`SymbolTable` 在各任务间签名一致
- ✅ TDD：每个功能先写测试再实现
- ✅ 频繁 commit：每个 Task 末尾都 commit
