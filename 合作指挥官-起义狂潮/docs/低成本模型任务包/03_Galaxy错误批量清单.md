# 任务：Galaxy 静态错误批量清单

## 参数

- `{{BATCH_ID}}`：本批次名称。
- `{{BASE_DATA_DIRS_FILE}}`：UTF-8 文本，每行一个 `Base.SC2Data` 目录。

## 目标

对每个完整 `Base.SC2Data` 运行 `galaxy-checker`，保存全部输出并形成不丢行的错误清单。
这是证据收集任务，不判断误报，不修改 Galaxy。

## 执行约束

1. 源文件只读。
2. 输出目录：
   `合作指挥官-起义狂潮/docs/低成本模型产物/galaxy-error-inventory/{{BATCH_ID}}/`
3. 必须保存完整 stdout/stderr，禁止用 `Select-String`、`grep` 或规则白名单过滤后再保存。
4. 摘要必须逐条对应原始 `[ERROR]` 行。

## 命令

```powershell
$checker = "合作指挥官-起义狂潮/scripts/galaxy-checker/dist/cli.mjs"
node $checker "<Base.SC2Data>" --format text
```

如果 `dist/cli.mjs` 不存在，停止并报告 `CHECKER_BUILD_REQUIRED`。不要自行安装依赖或修改
checker。

## 输出

### `raw/<序号>.txt`

完整 stdout。另存：

- `<序号>.stderr.txt`
- `<序号>.meta.json`：目录、命令、退出码、开始/结束时间。

### `errors.csv`

每个 `[ERROR]` 一行：

```text
baseData,ruleCode,file,line,column,message,rawOutputFile
```

无法解析字段时保留空列，但 `message` 必须保存完整原文。

### `error-counts.csv`

```text
baseData,ruleCode,count
```

### `needs-senior-review.md`

列出：

- 所有 `XLIB_DISALLOWED_NATIVE`
- 所有 `SEM_UNDECLARED_FUNCTION`
- 所有 `SEM_ARGUMENT_COUNT_MISMATCH`
- 所有 `PROJ_BOM_DETECTED`
- 连续重复但文件/行不同的错误
- 解析器崩溃或输出不符合格式

不要标记“已知误报”。只写证据路径。

### `run-summary.json`

记录目录数、exit 0/1/2 数、错误总数、各 ruleCode 数量和工具异常数。

## 停止条件

- 某个 Mod 有错误：记录后继续。
- checker 本身连续 3 次崩溃：停止批次。
- 不执行进图测试。
