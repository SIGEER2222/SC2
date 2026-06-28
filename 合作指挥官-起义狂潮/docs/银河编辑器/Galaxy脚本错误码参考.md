# Galaxy 脚本错误码参考

> 本文档整理自星际争霸2银河编辑器 Galaxy 脚本语言的完整错误信息列表，附中文翻译，供 AI 开发和调试时快速定位问题。
> 来源：Core.SC2Mod/enUS.SC2Data/Error.txt（Galaxy 部分）
> 整理日期：2026-06-28

---

## 一、编译期错误（Compile-time Errors）

### 1.1 语法与结构错误

| 错误码 | 英文原文 | 中文翻译 | 说明 |
|--------|----------|----------|------|
| `e_syntaxError` | Syntax error | 语法错误 | 通用语法错误，需检查代码结构 |
| `e_expectedSemicolon` | Expected a semicolon: ';' | 缺少分号 | 语句末尾缺少分号 |
| `e_expectedOpenBrace` | Expected an opening brace: '{' | 缺少开始大括号 | 缺少左大括号 `{` |
| `e_expectedCloseBrace` | Expected a closing brace: '}' | 缺少结束大括号 | 缺少右大括号 `}` |
| `e_expectedLeftParen` | Expected '(' | 缺少左括号 | 缺少左括号 `(` |
| `e_expectedRightParen` | Expected ')' | 缺少右括号 | 缺少右括号 `)` |
| `e_expectedComma` | Expected a comma: ',' | 缺少逗号 | 缺少逗号 `,` |
| `e_expectedExpr` | Expected an expression | 缺少表达式 | 期望表达式的位置没有表达式 |
| `e_expectedBoolExpr` | Expected a boolean expression | 缺少布尔表达式 | 条件位置需要布尔表达式 |
| `e_expectedFuncBody` | Expected ';' or function body | 缺少函数体 | 函数声明后缺少函数体或分号 |
| `e_expectedType` | Expected type name | 缺少类型 | 期望类型名的位置 |
| `e_expectedGlobalName` | Expected unused global variable or function name | 缺少全局名 | 全局变量/函数名重复或缺失 |
| `e_expectedStructIdent` | Structure requires an identifier | 缺少结构标识符 | struct 定义缺少名称 |
| `e_expectedTypedefIdent` | Typedef requires an unused identifier | Typedef缺少标识符 | typedef 缺少新类型名称 |
| `e_expectedTypedefType` | Typedef requires a type | 缺少类型 | typedef 缺少类型定义 |
| `e_expectedFieldName` | Expected a field name inside a structure | 缺少字段名 | struct 中缺少字段名 |
| `e_expectedFieldType` | Expected a field type inside a structure | 缺少字段类型 | struct 中缺少字段类型 |
| `e_expectedArrayIndex` | Expected an array index: '[' | 缺少数组索引 | 数组访问缺少 `[` |
| `e_expectedIntType` | Shift operator requires integer value | 需要int型 | 位移操作需要整型值 |
| `e_expectedConstExpr` | Non-constant initialization of constant object | 缺少常量表达式 | 常量必须用常量表达式初始化 |
| `e_expectedInclude` | Expected an include file name | 缺少需要include的文件名 | include 语句缺少文件名 |
| `e_expectedNativeName` | Expected a registered native function name | 缺少Native函数名 | native 函数声明名称未注册 |
| `e_expectedParams` | Invalid parameter list | 缺少参数 | 参数列表无效 |
| `e_expectedReturn` | Expected a return value | 缺少返回 | 非 void 函数缺少返回值 |

### 1.2 类型与转换错误

| 错误码 | 英文原文 | 中文翻译 | 说明 |
|--------|----------|----------|------|
| `e_typeMismatch` | Types do not match | 类型不符 | 赋值或比较时类型不匹配 |
| `e_typecastError` | That typecast not allowed | 类型转换错误 | 不支持的类型转换方式 |
| `e_noImplicitCast` | Implicit cast not allowed | 无隐式类型转换 | Galaxy 不支持隐式类型转换 |
| `e_paramTypeMismatch` | Parameter type does not match the function definition | 参数类型不符 | 函数实参类型与形参不匹配 |
| `e_paramCountMismatch` | Wrong number of parameters | 参数个数不符 | 函数调用参数数量不对 |
| `e_prototypeMismatch` | Function does not match previous definition | 函数原型不符 | 函数声明与之前的定义不一致 |
| `e_callbackMismatch` | Mismatched callback definitions | 回调不符 | 回调函数定义不匹配 |
| `e_nativeMismatch` | Native function prototype does not match the internal function | Native函数不符 | native 函数原型与内部函数不匹配 |
| `e_badParameterType` | Can only pass basic types | 错误的参数类型 | 只能传递基础类型参数 |
| `e_notArray` | Cannot use '[': object is not an array | 非数组 | 对非数组使用 `[]` 访问 |
| `e_notFunction` | Cannot use '(': object is not a function | 非函数 | 对非函数使用 `()` 调用 |
| `e_notStruct` | Cannot use '.': object is not a structure | 非结构 | 对非 struct 使用 `.` 访问 |
| `e_notStructField` | This field is not a member of the struct type | 非结构字段 | 访问了 struct 不存在的字段 |
| `e_requireStruct` | Require struct on left side of -> or . | 需要结构 | `->` 或 `.` 左边必须是结构 |
| `e_derefNotPointer` | Cannot use '->' on a non-pointer object | 解引用非指针 | 对非指针对象使用 `->` |
| `e_illegalIndex` | Array index require an integer value | 非法索引 | 数组索引必须是整数值 |
| `e_illegalArraySize` | Illegal array dimension | 非法的数组尺寸 | 数组维度定义非法 |
| `e_oldStyleDimension` | Galaxy array definitions require the dimension after the type | 旧式尺寸声明 | 数组维度必须写在类型后面（如 `int[3] arr;`） |
| `e_noVoidVars` | Illegal variable type: void | 无void变量 | 不能声明 void 类型变量 |

### 1.3 不支持的特性错误

| 错误码 | 英文原文 | 中文翻译 | 说明 |
|--------|----------|----------|------|
| `e_unexpectedComment` | comment blocks with /\* \*/ are not supported | 不支持注释块 | Galaxy 只支持 `//` 单行注释，不支持 `/* */` 块注释 |
| `e_unexpectedDirective` | unexpected directive, Galaxy does not have a preprocessor | 不支持的指令 | Galaxy 没有预处理器，不支持 `#define` 等 |
| `e_unexpectedGoto` | 'goto' statements are unsupported | 不支持goto | 不支持 goto 语句 |
| `e_unexpectedSwitch` | 'switch' statements are unsupported | 不支持switch | 不支持 switch 语句，用 if 替代 |
| `e_unexpectedNew` | dynamic memory allocation unsupported | 不支持new | 不支持动态内存分配 |
| `e_unexpectedOperator` | Operators ++ and -- are unsupported | 不支持的操作符 | 不支持 `++` 和 `--` 操作符 |
| `e_unexpectedBreak` | Unexpected 'break' statement | 多余的break | break 语句位置错误 |
| `e_unexpectedContinue` | Unexpected 'continue' statement | 多余的continue | continue 语句位置错误 |
| `e_unexpectedReturn` | Unexpected value returned from a 'void' function | 多余的Return值 | void 函数中返回了值 |
| `e_unexpectedSign` | unexpected 'signed' or 'unsigned' as Galaxy types have implicit sign | 多余的signed/unsigned | Galaxy 类型默认有符号，无需显式声明 |
| `e_noForwardSupport` | struct forward declaration not supported | 无前置声明 | struct 不支持前置声明 |
| `e_noNestedStruct` | struct cannot be nested inside itself | 无嵌套结构 | struct 不能嵌套自身 |
| `e_noBulkCopy` | Bulk copy not supported | 无批量复制 | 不支持结构体批量复制 |
| `e_cantTakeAddress` | Cannot use '&' on an object which has no address | 无法获取地址 | 不能对无地址对象使用 `&` |

### 1.4 变量与常量错误

| 错误码 | 英文原文 | 中文翻译 | 说明 |
|--------|----------|----------|------|
| `e_badLValue` | Cannot assign to the left side of assignment expression | 错误的左值 | 赋值表达式左边不能被赋值 |
| `e_constAssigned` | Const variable already assigned | 常量已赋值 | 常量被重复赋值 |
| `e_constInitRequired` | Must initialize const variables | 需要初始化常量 | 常量声明时必须初始化 |
| `e_constNotAllowedHere` | Cannot use const here | 不允许常数 | const 不能用在此位置 |
| `e_redefinedFuncName` | function already defined | 重定义函数名 | 函数名重复定义 |
| `e_redefinedField` | struct field redefinition | 字段重定义 | struct 字段重复定义 |
| `e_redefinedParam` | redefined identifier | 重定义参数 | 标识符重复定义 |
| `e_undefFunction` | Function declared but not defined | 函数未定义 | 函数声明了但没有实现 |
| `e_noFunctionBody` | No function body was ever declared | 无函数体 | 函数没有函数体 |
| `e_globalsTooLarge` | Global data are too large | 全局变量太大 | 全局变量数据总量超限 |
| `e_localsTooLarge` | 32k - 1 size limit to local variables | 局部变量太大 | 局部变量超过 32k-1 大小限制 |
| `e_identiferTruncated` | Truncated identifier | 标识符断裂 | 标识符被截断 |
| `e_numericOverflow` | Numeric overflow | 数值溢出 | 数值超出表示范围 |
| `e_stringTruncated` | Truncated string | 字符串截断 | 字符串被截断 |

### 1.5 字符与字面量错误

| 错误码 | 英文原文 | 中文翻译 | 说明 |
|--------|----------|----------|------|
| `e_illegalCharacter` | Illegal char constant | 非法字符 | 非法的字符常量 |
| `e_illegalEscapeSeq` | Illegal escape sequence | 非法转义字符 | 非法的转义序列 |
| `e_illegalOctal` | illegal octal digit | 非法八进制值 | 非法的八进制数字 |
| `e_newlineConst` | Newline in constant | 常量换行 | 常量中出现换行 |

### 1.6 其他编译错误

| 错误码 | 英文原文 | 中文翻译 | 说明 |
|--------|----------|----------|------|
| `e_cantFindInclude` | Include file not found | 无法找到include文件 | include 的文件不存在 |
| `e_internalGalaxyError` | Internal compiler error | 银河内部错误 | 编译器内部错误 |
| `e_scriptTooLarge` | Script too large | 脚本太大 | 脚本文件过大 |
| `e_nestingTooDeep` | Nesting overflow | 嵌套过深 | 代码嵌套层次太深 |
| `e_mangleOverflow` | Mangled name overflow | 名称修饰溢出 | 内部名称修饰溢出 |
| `e_unreachableCode` | unreachable code | 不可达的代码 | 存在永远不会执行的代码 |
| `e_registerUsageOverflow` | Register overflow | 寄存器溢出 | 寄存器使用超限 |
| `e_stateStackOverflow` | Stack overflow | 状态栈溢出 | 解析器状态栈溢出 |

---

## 二、运行期错误（Runtime Errors）

### 2.1 线程执行错误

| 错误码 | 英文原文 | 中文翻译 | 说明 |
|--------|----------|----------|------|
| `e_execPaused` | Execution paused | 线程挂起 | 执行已暂停 |
| `e_threadIsActive` | Execution currently active | 线程活跃 | 线程当前正在执行 |
| `e_threadIsReady` | Thread is ready to execute | 线程就绪 | 线程已准备就绪 |
| `e_execTimeout` | Execution took too long | 执行超时 | 脚本执行时间过长 |
| `e_tooManyThreads` | Too many threads | 线程太多 | 创建的线程数量超限 |
| `e_nestedIteration` | Nested iteration detected | 嵌套迭代 | 检测到嵌套迭代 |

### 2.2 内存与指针错误

| 错误码 | 英文原文 | 中文翻译 | 说明 |
|--------|----------|----------|------|
| `e_divByZero` | Divide by zero | 除零异常 | 尝试除以零 |
| `e_nullPointer` | Dereferenced a null pointer | 空指针 | 解引用了空指针 |
| `e_invalidAddr` | Invalid address | 无效地址 | 访问了无效地址 |
| `e_invalidGlobalPtr` | Invalid global pointer | 无效的全局指针 | 全局指针无效 |
| `e_invalidStackPtr` | Invalid stack pointer | 无效的堆栈指针 | 栈指针无效 |
| `e_stackOverflow` | Stack overflow | 堆栈上溢 | 运行时栈溢出 |
| `e_stackUnderflow` | Stack underflow | 堆栈下溢 | 运行时栈下溢 |
| `e_jumpOutOfBounds` | Code pointer tried to jump out of bounds | 跳出界限 | 代码指针跳转越界 |
| `e_codePtrInData` | Code pointer tried to jump to data space | 代码指针在数据区 | 代码指针跳转到了数据区 |
| `e_dataPtrInCode` | Data pointer tried to access code space | 数据指针在代码区 | 数据指针访问了代码区 |
| `e_notInCode` | Code pointer moved out of code space | 不在代码区 | 代码指针移出了代码空间 |
| `e_functionNotFound` | Function not found | 函数未找到 | 调用的函数不存在 |
| `e_unknownInstr` | Unknown instruction | 未知指令 | 遇到未知的指令 |
| `e_nativeCodeError` | Native function has encountered an error | Native函数错误 | 原生函数执行出错 |

---

## 三、AI 调试速查表

### 3.1 常见错误快速定位

| 现象 | 可能原因 | 检查方向 |
|------|----------|----------|
| `e_syntaxError` 但看不出来哪错了 | 大括号不匹配、缺少分号 | 从报错行往上逐行检查 `{}` 配对 |
| `e_typeMismatch` | fixed 与 int 混用、字符串与 text 混用 | 用显式转换函数：`IntToFixed()`、`StringToText()` |
| `e_paramCountMismatch` | 函数参数数量不对 | 查原生函数签名，注意是否有返回值参数 |
| `e_cantFindInclude` | include 路径错误 | include 路径相对于 TriggerLibs/，不加 .galaxy 后缀 |
| `e_nativeMismatch` | native 函数声明写错 | 核对原生函数名和参数，注意大小写 |
| `e_scriptTooLarge` | 脚本文件太大 | 拆分文件，用多个库 |
| `e_execTimeout` | 死循环或计算量过大 | 检查 while 循环条件，避免无限循环 |
| `e_stackOverflow` | 递归过深或局部变量太多 | 减少递归深度，用全局变量替代大局部数组 |

### 3.2 AI 开发注意事项

1. **Galaxy 与 C 的关键区别**（AI 写代码时最容易踩的坑）：
   - 数组维度写在类型后：`int[5] arr;` 而非 `int arr[5];`
   - 不支持 `++` / `--`，用 `x = x + 1;`
   - 不支持 `for` 循环，用 `while`
   - 不支持 `switch`，用 `if/else if`
   - 不支持 `/* */` 块注释，只用 `//`
   - 没有预处理器，没有 `#define` / `#include`
   - 所有 `if` / `while` 体必须用 `{}`，即使单行
   - 变量必须声明在函数顶部
   - 用 `fixed` 代替 `float` / `double`
   - 不支持隐式类型转换

2. **常见类型转换函数**：
   - `IntToFixed(int)` → fixed
   - `FixedToInt(fixed)` → int
   - `StringToText(string)` → text
   - `TextToString(text)` → string
   - `UnitGetTypeId(unit)` → int (unit type id)

3. **调试技巧**：
   - 用 `UIDisplayMessage()` 打印调试信息
   - 用 `TriggerDebugWindow` 查看触发器执行
   - 在 GameLogs 目录查看运行时错误日志
   - 编译阶段错误一般是语法问题，运行时错误一般是逻辑问题

---

## 附录：错误码字母索引

- **b**: e_badLValue, e_badParameterType
- **c**: e_cantFindInclude, e_cantTakeAddress, e_callbackMismatch, e_codePtrInData, e_constAssigned, e_constInitRequired, e_constNotAllowedHere
- **d**: e_dataPtrInCode, e_derefNotPointer, e_divByZero
- **e**: e_expectedArrayIndex, e_expectedBoolExpr, e_expectedCloseBrace, e_expectedComma, e_expectedConstExpr, e_expectedExpr, e_expectedFieldName, e_expectedFieldType, e_expectedFuncBody, e_expectedGlobalName, e_expectedInclude, e_expectedIntType, e_expectedLeftParen, e_expectedNativeName, e_expectedOpenBrace, e_expectedParams, e_expectedReturn, e_expectedRightParen, e_expectedSemicolon, e_expectedStructIdent, e_expectedType, e_expectedTypedefIdent, e_expectedTypedefType, e_execPaused, e_execTimeout
- **f**: e_functionNotFound
- **g**: e_globalsTooLarge
- **i**: e_identiferTruncated, e_illegalArraySize, e_illegalCharacter, e_illegalEscapeSeq, e_illegalIndex, e_illegalOctal, e_internalGalaxyError, e_invalidAddr, e_invalidGlobalPtr, e_invalidStackPtr
- **j**: e_jumpOutOfBounds
- **l**: e_localsTooLarge
- **m**: e_mangleOverflow, e_nativeCodeError, e_nativeMismatch, e_nestingTooDeep, e_newlineConst, e_noBulkCopy, e_noForwardSupport, e_noFunctionBody, e_noImplicitCast, e_noNestedStruct, e_noVoidVars, e_notArray, e_notFunction, e_notInCode, e_notStruct, e_notStructField, e_numericOverflow, e_nullPointer
- **p**: e_paramCountMismatch, e_paramTypeMismatch, e_prototypeMismatch
- **r**: e_redefinedField, e_redefinedFuncName, e_redefinedParam, e_registerUsageOverflow, e_requireStruct
- **s**: e_scriptTooLarge, e_stateStackOverflow, e_stackOverflow, e_stackUnderflow, e_stringTruncated, e_syntaxError
- **t**: e_threadIsActive, e_threadIsReady, e_tooManyThreads, e_typecastError, e_typeMismatch
- **u**: e_undefFunction, e_unexpectedBreak, e_unexpectedComment, e_unexpectedContinue, e_unexpectedDirective, e_unexpectedGoto, e_unexpectedNew, e_unexpectedOperator, e_unexpectedReturn, e_unexpectedSign, e_unexpectedSwitch, e_unreachableCode, e_unknownInstr

---

> 注：以上错误码来自 Core.SC2Mod 中的 Error.txt 文件，涵盖了 Galaxy 脚本编译器和运行时的全部已知错误。开发时可按错误码快速定位问题类型。
