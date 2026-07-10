---
name: sc2-workflow
description: Diagnose, modify, and validate StarCraft II maps and mods with dependency-first Catalog analysis and failure-oriented unit diagnostics. Use for missing production options, units missing abilities or command-card buttons, static XML versus Galaxy runtime differences, dependency or same-ID overrides, campaign/custom-melee/7vs1 mismatches, Galaxy edits, trigger save failures, and SC2 runtime verification.
---

# SC2 Dependency-First Workflow

Treat the effective dependency chain as the parent data model. Parents load first; later packages
and the map merge or override the same Catalog IDs. Diagnose ownership and runtime mutation before
editing data.

Set the toolkit path from the repository root:

```powershell
$tool = "合作指挥官-起义狂潮/scripts/sc2-editor-toolkit/cli.mjs"
```

## Execute the Core Flow

1. Classify the target as a 7vs1 unpacked map, ordinary MPQ map, standalone Mod, campaign map, or
   custom-melee map.
2. Inspect declared or launcher-effective dependencies:

   ```powershell
   node $tool inspect "<map-or-mod>" --format text
   node $tool inspect "<7vs1-map>" --effective --commander TerranRaynor --format text
   ```

3. For missing production, abilities, buttons, or static/runtime mismatches, run `diagnose-unit`
   before manually tracing XML. Read [unit-diagnostics.md](references/unit-diagnostics.md).
4. Trace the exact Catalog ID or field when ownership remains unclear:

   ```powershell
   node $tool trace "<map-or-mod>" --catalog Unit --id MarineRaynor --field CardLayouts --format text
   ```

5. Compare campaign, custom-melee, test-map, or effective-launcher environments directly:

   ```powershell
   node $tool compare "<left>" "<right>" --catalog Upgrade --id "<id>" --format text
   ```

6. Fix the earliest package that should own the behavior:
   - Shared Mod for behavior every consumer should inherit.
   - Commander package for commander-canonical behavior.
   - Adapter for one commander and map/runtime family.
   - Launcher/configuration for dependency selection or order.
   - Map-local data only for mission-specific behavior.
7. Route validation from the explicit files changed:

   ```powershell
   node $tool check "<relative-file-1>" "<relative-file-2>" --run --format text
   ```

8. Run the required runtime test only when map, trigger, Galaxy, GameData, or runtime behavior
   changed. Read [runtime-testing.md](references/runtime-testing.md).
9. Convert new failure modes into configuration, parser rules, fixtures, and regression tests.

## Respect Evidence Boundaries

- Do not infer campaign compatibility from success in custom melee.
- Do not report a trace or diagnosis as authoritative when `complete` is false.
- Use `--allow-incomplete` only when intentionally accepting and reporting missing dependencies.
- Treat `provenanceMode: definition-history` as definition/override history, not full engine
  execution.
- Treat an empty runtime event list as inconclusive. Dynamic IDs, cross-function data flow,
  generated strings, and indirect calls remain outside literal/local-context scans.
- Keep internal script IDs, variable IDs, and filesystem paths ASCII where possible. Localized
  display text may remain Chinese.

## Load Detailed Procedures When Needed

- Read [unit-diagnostics.md](references/unit-diagnostics.md) for production chains, inherited
  abilities, command cards, runtime injection/locking, issue codes, and exit behavior.
- Read [galaxy-validation.md](references/galaxy-validation.md) whenever `.galaxy` or `_h.galaxy`
  files change or a runtime ScriptError exposes checker coverage gaps.
- Read [runtime-testing.md](references/runtime-testing.md) before launching any map.
- Read [tooling.md](references/tooling.md) for analyzer paths, data sources, MPQ extraction, and
  maintenance boundaries.

## Definition of Done

Finish only when:

1. The effective dependency boundary is resolved or every accepted missing dependency is listed.
2. The target internal IDs and their owning definitions are identified.
3. The mismatch is classified as dependency selection, Catalog merge/inheritance, command-card
   wiring, Requirement/Restricted state, Galaxy mutation, or runtime-only behavior.
4. The fix is made at the correct ownership layer with regression coverage where practical.
5. Static validation passes and required in-game validation completes.
6. A newly encountered failure is captured in machine-readable logic or a regression fixture, not
   only prose.
