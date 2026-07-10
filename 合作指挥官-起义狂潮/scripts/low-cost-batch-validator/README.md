# Low-cost batch validator

Deterministic validation for artifacts produced from
`docs/低成本模型任务包`.

Validate one task batch:

```powershell
node cli.mjs "../../docs/低成本模型产物/unit-diagnostic-matrix/batch-01"
```

Validate the same batch ID across every task in `task-manifest.json`:

```powershell
node cli.mjs --batch batch-01
```

Use `--format json` for machine-readable output. The CLI exits with code `1`
when any contract violation is found and code `2` for invocation or validator
failures.

The executable contracts cover:

- manifest and prompt-file consistency
- required artifact patterns and `run-summary.json.outputs`
- CSV schemas declared by each task prompt
- raw output, stderr, and metadata pairing
- unit incomplete-case review coverage and raw/summary aggregation
- Galaxy error-line preservation and aggregate counts
- dependency, MPQ, and validation raw/summary row counts

Run tests with:

```powershell
npm test
```
