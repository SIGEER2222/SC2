# Galaxy Validation

Apply this procedure after modifying `.galaxy` or `_h.galaxy`, **and after any launcher patches
live mod files**, before any in-game test. The pre-launch gate is mandatory: runtime `ScriptError`
exposing syntax/semantic/cross-lib/native-API issues is a process failure, not an expected debug
step.

## Run the Checker

Use the complete containing `Base.SC2Data`, not only the changed file:

```powershell
node "合作指挥官-起义狂潮/scripts/galaxy-checker/dist/cli.mjs" `
  "<mod-or-map>/Base.SC2Data" --format text
```

Directory scanning loads headers and cross-file symbols and produces fewer false undeclared-symbol
results than single-file scanning.

### Multi-Mod scenarios (mandatory `--symbol-root`)

When the target Mod depends on other Mods at runtime (CMRE + 7vs1 overlay, Alenger3Adapter +
RuntimeProbe + CMRE Core, etc.), every dependency Mod must be supplied via `--symbol-root`, or
`SEM_UNDECLARED_FUNCTION` / `XLIB_UNDEFINED_CROSS_REF` will false-positive on every cross-lib call.

```powershell
# CMRE + 7vs1 overlay 多 mod 场景示例
node "合作指挥官-起义狂潮/scripts/galaxy-checker/dist/cli.mjs" `
  "E:\SC2\SC2new\StarCraft II\Mods\CMRE\CMRE_Core_Triggers.SC2Mod\Base.SC2Data" `
  --symbol-root "E:\SC2\SC2new\StarCraft II\Mods\CMRE\CMRE_Core_Data.SC2Mod\Base.SC2Data" `
  --symbol-root "E:\SC2\SC2new\StarCraft II\Mods\7vs1\7vs1Base.SC2Mod\Base.SC2Data" `
  --format text
```

`--symbol-root` only contributes symbols; those Mods are not added to the target report. Repeat the
flag once per dependency Mod. Verify each path exists before running — a typo'd root silently
reproduces the false-positive storm.

### Known SC2 compiler limitation (multi-mod forward declaration visibility)

Under deep dependency stacks (13+ Mods), the SC2 compiler fails to resolve forward declarations in
`_h.galaxy` for `.galaxy` files under `scripts/` subdirectories. Symptom: a function declared in
`LibX_h.galaxy` and defined in `LibX.galaxy` is reported as undeclared (or its return type defaults
to `int`, breaking `if (boolFn() == true)` with "需要布尔表达式") even though the header is
indirectly included. galaxy-checker with the correct `--symbol-root` set catches this pre-launch.

Mitigation when the issue is confirmed in-game but checker must keep passing:

- Add a local forward declaration at the top of the affected `.galaxy` file (prototype only, no
  body). If the compiler then reports "already declared", the header was actually visible and the
  real cause is elsewhere.
- Do **not** patch by removing `== true` etc. — that hides the symptom without fixing symbol
  visibility, and the next cross-lib call will fail the same way.

If `dist/` is absent:

```powershell
Set-Location "合作指挥官-起义狂潮/scripts/galaxy-checker"
npm install
npm run build
```

## Evaluate Results

- Read the complete output and every `[ERROR]` line. Do not filter to selected rule names.
- Fix actionable syntax, semantic, argument-count, native, encoding, BOM, include, and
  cross-library errors before entering the map.
- Treat known cross-Mod references as accepted only after verifying the owning Mod is supplied at
  runtime (i.e., `--symbol-root` is configured and the issue still resolves to a real miss).
- Prefer directory-level validation when single-file output reports missing `_h.galaxy` or native
  symbols.

High-priority codes include:

- `SEM_ARGUMENT_COUNT_MISMATCH`
- `SEM_UNDECLARED_FUNCTION`
- `SEM_UNDECLARED_VARIABLE`
- `SEM_VOID_IN_CONDITION` — void return used in a condition; the multi-mod forward-declaration bug
  surfaces here when the compiler treats the return type as `int`.
- `SEM_DUPLICATE_DECLARATION`
- `SEM_LOCAL_DECLARATION_AFTER_STATEMENT`
- `XLIB_UNDEFINED_CROSS_REF`
- `XLIB_DISALLOWED_NATIVE` — blacklisted SC2 native (error). Backed by `data/natives.galaxy`
  (2874 native signatures) and `data/native-blacklist.json`.
- `XLIB_DISCOURAGED_NATIVE` — discouraged native (warning by default; upgrade to error in
  `data/project-rules.json` if the project forbids it).
- `CATALOG_INVALID_UNIT_REF` — string literal referencing a unit/ability ID not in catalog; usually
  means a Mod dependency is missing or an ID is misspelled. Backed by `data/catalog-ids*.json`.
- `PROJ_UTF8_BOM` / `PROJ_ENCODING_INVALID`
- `SYNTAX_NO_CONTINUE`

### Validation dimensions (one run covers all — do not skip any)

1. **Galaxy syntax/semantics**: parser + `SemanticAnalyzer` — `SEM_*` rules above.
2. **Cross-library symbol visibility**: `SymbolTable` + `ProjectLoader` —
   `SEM_UNDECLARED_FUNCTION` / `XLIB_UNDEFINED_CROSS_REF`. Always supply `--symbol-root` for
   dependent Mods.
3. **SC2 native API**: `NativeFunctionTable` + `data/natives.galaxy` + `native-blacklist.json` —
   `XLIB_DISALLOWED_NATIVE` / `XLIB_DISCOURAGED_NATIVE`. Validates that called natives exist and are
   not blacklisted.
4. **Catalog references**: `data/catalog-ids*.json` — `CATALOG_INVALID_UNIT_REF`. Validates
   string-literal unit/ability IDs against catalog entries.
5. **Project hygiene**: `PROJ_UTF8_BOM`, `PROJ_ENCODING_INVALID`, `XLIB_MISSING_INCLUDE`,
   `XLIB_MISSING_INIT`.

If an in-game `ScriptError` is not detected by `galaxy-checker`, first add the missing checker rule
or parser coverage and a regression test, then resume map debugging. A checker miss is a reusable
tool defect, not a one-off exception.

## Launcher Integration

Launchers that patch live mod files (`launch-cmre.ps1` `Patch-CmreCoreRuntimeErrors`,
`Enable-CmreSavedProfileStartup`, etc.) must invoke galaxy-checker on the patched `Base.SC2Data`
**after** patching and **before** `SC2Switcher` starts the game. Behavior:

- Build `--symbol-root` list from the launcher's runtime dependency set (the same Mods being synced
  to live SC2).
- On `summary.errors > 0` (CLI exit code 1): abort launch, print all error-level issues, and surface
  the patched file/line for each. Do not fall through to `SC2Switcher`.
- On exit code 0: proceed to launch.
- On exit code 2 (tool exception): abort and report the tool failure separately — do not silently
  proceed.

## Internal Identifier Safety

Use ASCII letters, digits, and underscores for Galaxy function names, variable IDs, and
name-derived script IDs. Chinese display text belongs in localization data.

When the editor cannot save after trigger edits:

1. Inspect whether script IDs are generated from Chinese names.
2. Disable name-to-ID rewriting for affected triggers or variables.
3. Prefer an English editor environment for stable internal IDs.
4. Treat translation packs as a tradeoff because they may inject localized text into the map.
