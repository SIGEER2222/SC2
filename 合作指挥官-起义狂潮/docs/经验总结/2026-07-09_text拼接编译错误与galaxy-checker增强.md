# Galaxy text + text 拼接编译错误 & galaxy-checker 增强

## 错误现象
SC2 编译报错：`不正确的类型（不允许进行隐式强制转换）`

## 根因
Galaxy 的 `text` 类型不支持 `+` 拼接运算符。错误写法：
```galaxy
StringToText("小队: ") + IntToText(1)   // text + text，非法
```
`StringToText()` 和 `IntToText()` 都返回 `text` 类型，二者不能用 `+` 连接。

## 正确写法
先用 `string` 拼接，再用 `StringToText()` 转换：
```galaxy
StringToText("小队: " + IntToString(1))  // string + string，再转 text
```
- `"字符串字面量"` 在 Galaxy 中是 `string` 类型
- `IntToString(int)` 返回 `string`
- `string + string` 合法，结果是 `string`
- 最后 `StringToText(string)` 转为 `text`

## galaxy-checker 增强
原 galaxy-checker 无法静态检测此类错误，现已新增 `SEM_INVALID_TEXT_CONCAT` 规则：

### 改动文件
- `data/project-rules.json`：新增规则配置（severity: error）
- `src/analyzer/RuleEngine.ts`：新增默认错误消息
- `src/analyzer/SemanticAnalyzer.ts`：
  - `inferType()` 增加 `nativeTable` 参数，可推断 native 函数返回类型（如 `StringToText` → `text`）
  - `BinaryExpression` 的 `+` 运算符检测：任一操作数为 `text` 类型则报错
- `src/parser/GalaxyParser.ts`：为所有 10 个 BinaryExpression 节点附加 `start` 位置信息（取运算符 token 位置），使错误行号精确
- `tests/semantic-types.test.ts`：新增 5 个测试用例

### 验证
```powershell
node scripts/galaxy-checker/dist/cli.mjs "<含 text+text 的文件>" --format text
# 输出: [ERROR] file.galaxy:6:30  SEM_INVALID_TEXT_CONCAT
#       text 类型不能用 + 拼接（text + text）
```
行号精确到运算符 `+` 所在列。

## 经验教训
1. **Galaxy 类型严格**：`text` 和 `string` 是不同类型，`text` 不支持 `+`，`string` 支持
2. **galaxy-checker 应覆盖类型规则**：SC2 编译器报错滞后且不指明函数，静态分析能更早更准地定位
3. **AST 节点位置信息很重要**：原 BinaryExpression 节点无 `start` 属性导致错误行号为 0，补齐后定位精确到列
4. **先静态检查再进图测试**：30+ 秒的进图测试成本高，静态分析能在秒级发现此类问题
