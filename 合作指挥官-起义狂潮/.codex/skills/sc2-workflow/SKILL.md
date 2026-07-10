---
name: sc2-workflow
description: Diagnose StarCraft II campaign maps and mods when dependencies override Catalog IDs, production buildings train the wrong units, created units lack abilities or command-card buttons, campaign behavior differs from custom melee, static GameData differs from Galaxy runtime state, Galaxy checker output needs classification, or Catalog ownership must be traced. Also use to generate low-cost evidence-collection task files and validate their batch outputs.
---

# SC2 Workflow

Diagnose the effective data environment before editing XML or Galaxy. A map inherits its declared
dependency chain; later dependencies and map-local data can replace the same Catalog ID.

Run commands from `合作指挥官-起义狂潮`:

```powershell
$tool = "scripts/sc2-editor-toolkit/cli.mjs"
$checker = "scripts/galaxy-checker/dist/cli.mjs"
```

## Diagnose in Evidence Order

1. Classify the target: unpacked map, MPQ map, Mod, campaign map, custom-melee map, or 7vs1
   launcher environment.
2. Resolve declared and effective dependencies:

   ```powershell
   node $tool inspect "<map-or-mod>" --format text
   node $tool inspect "<7vs1-map>" --effective --commander "<commander-id>" --format text
   ```

3. Diagnose the unit before manually reading XML:

   ```powershell
   node $tool diagnose-unit "<map-or-mod>" --unit "<unit-id>" `
     --producer "<producer-id>" --expect-ability "<ability-id>" `
     --effective --commander "<commander-id>" --format json
   ```

4. Trace the IDs and fields involved in the mismatch:

   ```powershell
   node $tool trace "<map-or-mod>" --catalog Unit --id "<unit-id>" `
     --field "AbilArray" --effective --commander "<commander-id>" --format json
   node $tool trace "<map-or-mod>" --catalog Abil --id "<train-ability-id>" `
     --field "InfoArray" --effective --commander "<commander-id>" --format json
   ```

5. Compare environments when custom melee works but campaign does not:

   ```powershell
   node $tool compare "<campaign-map>" "<working-map-or-mod>" `
     --catalog Unit --id "<unit-id>" --field "CardLayouts" --format json
   ```

6. Scan the complete `Base.SC2Data` boundary after changing Galaxy:

   ```powershell
   node $checker "<mod>\Base.SC2Data" --format text
   node $checker "<child-mod>\Base.SC2Data" `
     --symbol-root "<parent-mod>\Base.SC2Data" --format text
   ```

7. Classify the root cause before choosing an owner:
   - Dependency selection or order.
   - Same-ID Catalog override or inherited parent data.
   - Producer `InfoArray`, Requirement, or Restricted state.
   - Unit `AbilArray` or `CardLayouts` wiring.
   - Galaxy ability/tech-tree injection or lock.
   - Runtime-only behavior outside static scan coverage.

Read [diagnostic-evidence.md](references/diagnostic-evidence.md) before interpreting incomplete
diagnostics, checker policies, or runtime/static differences.

## Choose the Fix Layer

Fix the earliest package that should own the behavior:

- Shared Mod for behavior inherited by every consumer.
- Commander package for commander-canonical data.
- Adapter for one commander and one runtime family.
- Launcher/configuration for dependency replacement or ordering.
- Map-local data only for mission-specific behavior.

Do not infer campaign compatibility from a successful custom-melee test. Do not edit every child
map to compensate for a broken shared dependency.

When map, trigger, GameData, Galaxy, or runtime behavior changes, read
[runtime-validation.md](references/runtime-validation.md) and complete the required in-game test.

## Delegate Mechanical Evidence Collection

Generate a filled low-cost task file from the existing project templates:

```powershell
$pack = ".codex/skills/sc2-workflow/scripts/task-pack.ps1"
& $pack -Action List
& $pack -Action New -TaskId 04 -BatchId "raynor-catalog-02" `
  -Set "CASES_FILE=E:\work\raynor-cases.tsv" `
  -OutFile "E:\work\raynor-catalog-02.md"
```

Validate returned batch output before senior review:

```powershell
& $pack -Action Validate -TaskId 04 `
  -BatchDir "docs/低成本模型产物/catalog-trace-compare/raynor-catalog-02" `
  -Format text
```

Read [low-cost-delegation.md](references/low-cost-delegation.md) for task selection, input
contracts, and senior-review boundaries.

## Completion Gate

Finish only when:

1. Declared and effective dependencies are explicit, including unresolved external dependencies.
2. The affected Catalog IDs, winning definitions, inherited fields, and runtime mutations are
   identified.
3. `complete: false` and empty runtime evidence are reported as incomplete, not as success.
4. The fix layer follows ownership rather than convenience.
5. Galaxy checker and relevant tool tests pass.
6. Required in-game validation is completed through `runtime-validation.md`.
7. Delegated batch outputs pass the low-cost batch validator before their conclusions are used.
