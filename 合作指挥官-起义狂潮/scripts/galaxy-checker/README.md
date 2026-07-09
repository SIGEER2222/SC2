# galaxy-checker

Galaxy 脚本静态检查器（AI 可调用）

## 安装

```bash
cd scripts/galaxy-checker
npm install
npm run build
```

## 使用

### CLI

`npm run build` 产出两份入口：`dist/cli.mjs`（esbuild 单文件 bundle，启动快，推荐）与 `dist/cli.js`（tsc 原始产物）。

```bash
# 检查单个文件（JSON 输出，默认）
node dist/cli.mjs path/to/LibFoo.galaxy

# 检查目录（递归 lint 所有 Lib*.galaxy，并用目录内全部 .galaxy 构建全局符号表），text 输出
node dist/cli.mjs "path/to/CoopZeroPop.SC2Mod/Base.SC2Data" --format text

# 指定自定义规则文件 / native 签名库
node dist/cli.mjs path/to/file.galaxy --rules path/to/project-rules.json
node dist/cli.mjs path/to/file.galaxy --native-lib path/to/NativeLib.galaxy

# 跳过全局符号表构建
node dist/cli.mjs path/to/dir --no-global-symbols
```

注意：检查真实工程的库文件请用**目录模式**（传目录）。单文件模式下跨文件符号
（如 `LibX_h.galaxy` 中的全局变量）不可见，会产生大量未声明误报。

### 库 API

```typescript
import { check } from 'galaxy-checker';

// check(target, options?): CheckResult
// target 可以是单个 .galaxy 文件或目录（目录递归扫 Lib*.galaxy）
const result = check('path/to/file.galaxy');
if (result.summary.errors > 0) {
  for (const issue of result.issues) {
    console.log(`[${issue.severity}] ${issue.file}:${issue.line} ${issue.ruleCode} - ${issue.message}`);
  }
}
```

`CheckOptions`：

| 字段 | 说明 |
| --- | --- |
| `rulesPath` | 项目规则 JSON 路径，默认 `data/project-rules.json` |
| `nativeLibPath` | native 签名库路径，默认回退到附带的 `data/natives.galaxy`（2874 个 native，由编辑器全函数索引 5.0.7 生成） |
| `noGlobalSymbols` | 跳过目录级全局符号表构建 |

## 规则

参见 [设计文档](../../docs/superpowers/specs/2026-07-08-galaxy-checker-design.md) §8。

可通过 `data/project-rules.json` 配置每条规则的严重级别：

```json
{
  "rules": {
    "SYNTAX_NO_CONTINUE": { "severity": "error" }
  }
}
```

severity 可选：`error` / `warning` / `info` / `off`

主要规则一览：

- `SYNTAX_NO_CONTINUE`：Galaxy 不支持 `continue`
- `SYNTAX_NO_LOCAL_INIT_ASSIGN`：局部变量不能声明时初始化
- `SEM_UNDECLARED_VARIABLE` / `SEM_UNDECLARED_FUNCTION`：未声明引用
- `SEM_ARGUMENT_COUNT_MISMATCH`：参数数量不匹配
- `SEM_DUPLICATE_DECLARATION`：同作用域重复定义
- `SEM_VOID_IN_CONDITION`：void 函数用在条件表达式
- `SEM_RETURN_TYPE_MISMATCH` / `SEM_ASSIGNMENT_TYPE_MISMATCH`：类型不匹配（warning）
- `XLIB_DISALLOWED_NATIVE`：调用黑名单 native（`data/native-blacklist.json`）
- `XLIB_UNDEFINED_CROSS_REF`：`libXXX_` 形式跨库引用未定义
- `XLIB_MISSING_INCLUDE`：include 的文件不存在
- `PROJ_UTF8_BOM`：文件含 UTF-8 BOM（会导致库初始化失败）

## AI 调用约定

AI Agent 写完 Galaxy 代码后：

1. 调用 `check(filePath)` 或 CLI（默认 JSON 输出）
2. 解析 JSON，按 `severity` 优先处理 error 级 issue
3. 修复后再次检查，直到 `summary.errors === 0`

## 退出码

- 0：无 error 级 issue
- 1：存在 error
- 2：工具异常（含 `--help` / 无参数）
