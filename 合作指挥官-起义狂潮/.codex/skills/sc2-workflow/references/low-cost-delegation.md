# Low-Cost Delegation

Use the templates under `docs/低成本模型任务包`. They are read-only evidence-collection tasks;
the senior workflow retains ownership decisions, source edits, checker false-positive acceptance,
runtime interpretation, regression design, commits, and pushes.

## Task Selection

| Code | Task ID | Use for |
|---|---|---|
| 01 | `dependency-inventory` | Batch declared/effective dependency inspection |
| 02 | `unit-diagnostic-matrix` | Repeated unit/producer/expected-ability diagnostics |
| 03 | `galaxy-error-inventory` | Complete checker logs and rule counts |
| 04 | `catalog-trace-compare` | Catalog field trace and environment comparison |
| 05 | `localized-name-candidates` | Localized display-name to internal-ID candidates |
| 06 | `mpq-inventory` | MPQ entries and map structure |
| 07 | `validation-doc-audit` | Full validation logs and stale documentation candidates |

## Prepare Inputs

- Use TSV case files for tasks 02 and 04. Keep one independent case per row.
- Use a plain UTF-8 name list for task 05. Derive names from actual localized data or reported UI
  text; do not invent translations.
- Include exact map/Mod paths, effective commander IDs, expected producer IDs, expected abilities,
  Catalog types, fields, and comparison environments.
- Split batches by commander, map family, or roughly 20-50 IDs.

Generate a task file with `scripts/task-pack.ps1 -Action New`. Supply every remaining
`{{PLACEHOLDER}}` through repeated `-Set "KEY=VALUE"` arguments. The command fails when unresolved
placeholders remain unless `-AllowUnresolved` is explicit.

## Validate Outputs

Run:

```powershell
scripts/task-pack.ps1 -Action Validate -TaskId <01..07> `
  -BatchDir "<batch-output-directory>" -Format text
```

The wrapper invokes:

```text
scripts/low-cost-batch-validator/cli.mjs <batch-dir> --task <manifest-task-id> --format <text|json>
```

Reject the batch or return it for correction when required files, CSV columns, raw logs,
`complete: false` review entries, summary counts, or command metadata do not match the task
contract. Do not use a failed batch as authoritative evidence.
