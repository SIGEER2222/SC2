# 任务：Catalog 追踪与环境对比

## 参数

- `{{BATCH_ID}}`：本批次名称。
- `{{CASES_FILE}}`：UTF-8 TSV。

TSV 列：

```text
caseId	mode	left	right	catalog	id	field	leftEffective	rightEffective	leftCommander	rightCommander
```

- `mode` 为 `trace` 或 `compare`。
- `trace` 模式只使用 `left`、`catalog`、`id`、`field`、`leftEffective`、`leftCommander`。
- 布尔值为 `true/false`，可选字段留空。

## 目标

机械地收集定义历史、字段差异、运行时修改和不完整依赖。不要决定哪个定义“正确”。

## 执行约束

1. 源文件只读。
2. 输出目录：
   `合作指挥官-起义狂潮/docs/低成本模型产物/catalog-trace-compare/{{BATCH_ID}}/`
3. 默认不传 `--allow-incomplete`。
4. 每个 case 保存完整 JSON 和退出码。

## 命令

```powershell
$tool = "合作指挥官-起义狂潮/scripts/sc2-editor-toolkit/cli.mjs"
```

Trace：

```powershell
node $tool trace "<left>" --catalog "<catalog>" --id "<id>" --format json
```

按输入追加 `--field`、`--effective`、`--commander`。

Compare：

```powershell
node $tool compare "<left>" "<right>" --catalog "<catalog>" --id "<id>" --format json
```

按输入追加：

```text
--field
--left-effective
--right-effective
--left-commander
--right-commander
```

## 输出

### `raw/<caseId>.json`

工具原始 JSON 和 `<caseId>.meta.json`。

### `catalog-summary.csv`

列：

```text
caseId,mode,catalog,id,found,status,complete,leftDefinitionCount,rightDefinitionCount,parentChain,leftRuntimeMutationCount,rightRuntimeMutationCount,fieldDifferenceCount,exitCode
```

不适用的列留空。

### `incomplete-boundaries.csv`

```text
caseId,side,ref,status,unresolvedParent
```

### `needs-senior-review.md`

列出：

- 同 ID 有多个后加载定义。
- `parentCircular` 或 `unresolvedParent`。
- 两侧定义来源不同。
- `runtimeScanComplete: false` 且结论依赖空运行时修改列表。
- `fieldDifferences` 非空。
- 任何 incomplete/missing 状态。

只描述证据，不写修复建议。

### `run-summary.json`

记录 trace/compare 数、完整数、不完整数、missing 数、工具异常数和差异总数。
