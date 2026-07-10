# Galaxy Validation

Apply this procedure after modifying `.galaxy` or `_h.galaxy`, before any in-game test.

## Run the Checker

Use the complete containing `Base.SC2Data`, not only the changed file:

```powershell
node "合作指挥官-起义狂潮/scripts/galaxy-checker/dist/cli.mjs" `
  "<mod-or-map>/Base.SC2Data" --format text
```

Directory scanning loads headers and cross-file symbols and produces fewer false undeclared-symbol
results than single-file scanning.

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
  runtime.
- Prefer directory-level validation when single-file output reports missing `_h.galaxy` or native
  symbols.

High-priority codes include:

- `SEM_ARGUMENT_COUNT_MISMATCH`
- `SEM_UNDECLARED_FUNCTION`
- `SEM_UNDECLARED_VARIABLE`
- `XLIB_UNDEFINED_CROSS_REF`
- `XLIB_DISALLOWED_NATIVE`
- `SYNTAX_NO_CONTINUE`
- `PROJ_BOM_DETECTED`

If an in-game `ScriptError` is not detected by `galaxy-checker`, first add the missing checker rule
or parser coverage and a regression test, then resume map debugging. A checker miss is a reusable
tool defect, not a one-off exception.

## Internal Identifier Safety

Use ASCII letters, digits, and underscores for Galaxy function names, variable IDs, and
name-derived script IDs. Chinese display text belongs in localization data.

When the editor cannot save after trigger edits:

1. Inspect whether script IDs are generated from Chinese names.
2. Disable name-to-ID rewriting for affected triggers or variables.
3. Prefer an English editor environment for stable internal IDs.
4. Treat translation packs as a tradeoff because they may inject localized text into the map.
