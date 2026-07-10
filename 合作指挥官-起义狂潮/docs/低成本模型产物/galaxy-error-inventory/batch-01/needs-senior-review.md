# NEEDS_SENIOR_REVIEW - Galaxy 错误批量清单 batch-01

## XLIB_DISALLOWED_NATIVE

禁止调用的原生函数。需在运行时替代方案中确认是否可接受。

| baseData | count |
|---|---|
| CoopZeroPop | 18 |
| CoreRuntime | 15 |
| CommanderBridge | 3 |

原始证据: raw/01-CoreRuntime.txt, raw/02-CoopZeroPop.txt, raw/03-CommanderBridge.txt

## SEM_UNDECLARED_FUNCTION

未声明的函数调用。可能来自外部 Mod 定义或缺失声明。

| baseData | count |
|---|---|
| CoopZeroPop | 11 |
| CoreRuntime | 11 |

原始证据: raw/01-CoreRuntime.txt, raw/02-CoopZeroPop.txt

## SEM_UNDECLARED_VARIABLE

未声明的变量引用。CommanderBridge 特有。

| baseData | count |
|---|---|
| CommanderBridge | 22 |

原始证据: raw/03-CommanderBridge.txt

## 其他高优先级

- **SYNTAX_NO_LOCAL_INIT_ASSIGN**: 817 个错误中占 577 个（70.6%），为 Galaxy 语法层面局部变量初始化写法问题，属于已知模式。
- **SEM_INVALID_TEXT_CONCAT**: CoreRuntime 33 + CoopZeroPop 33 = 66 个，text 拼接类型检查。
- 未发现 SEM_ARGUMENT_COUNT_MISMATCH 或 PROJ_BOM_DETECTED。

## 统计

| baseData | 错误 | 警告 |
|---|---|---|
| CoreRuntime | 402 | 64 |
| CoopZeroPop | 376 | 59 |
| CommanderBridge | 39 | 0 |
| **合计** | **817** | **123** |