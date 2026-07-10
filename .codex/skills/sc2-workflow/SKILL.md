---
name: sc2-workflow
description: Diagnose and validate StarCraft II maps and mods using dependency-first analysis. Use when investigating missing or overridden units, abilities, upgrades, command-card buttons, technology mismatches, Catalog ID conflicts, campaign/7vs1/custom-melee differences, Galaxy runtime mutations, editor save failures involving Chinese script IDs or paths, or when modifying SC2 GameData/Galaxy code that requires static and in-game verification.
---

# SC2 Dependency-First Workflow

Use the repository's existing analyzers as one workflow. Treat a map's dependency chain as its
parent data model: later packages and the map can override inherited Catalog IDs, but a child
cannot freely redefine what its effective parents supply without following SC2 merge semantics.

## Establish the Target

1. Run `git status --short --branch` before editing and preserve unrelated user changes.
2. Classify the target as one of:
   - 7vs1 unpacked map or its runtime Mods.
   - Ordinary MPQ map under `外部资源/TemplateMaps`.
   - Standalone Mod.
   - Campaign map or custom-melee map.
3. Do not infer campaign compatibility from a Mod working in custom melee.
4. Treat source-declared dependencies and launch-time effective dependencies as separate facts.

Set the toolkit location from the repository root:

```powershell
$tool = "合作指挥官-起义狂潮/scripts/sc2-editor-toolkit/cli.mjs"
```

## Inspect Dependencies First

Inspect declarations before diagnosing Catalog or Galaxy behavior:

```powershell
node $tool inspect "<map-or-mod>" --format text
```

For a 7vs1 map, model the launcher replacements and selected commander packages:

```powershell
node $tool inspect "<map.SC2Map>" --effective --commander TerranRaynor --format text
```

Read the parent-first `loadOrder`, unresolved/external dependencies, legacy replacements, and
effective profile. Do not claim a complete diagnosis when required external dependencies are
unavailable.

Keep launcher-equivalent dependency order and replacements in:

```text
合作指挥官-起义狂潮/Shared/Workflow/sc2-workflow.json
```

Update this configuration when the launcher, split commander packages, aliases, or dependency
locations change. Do not duplicate those facts in prompts or one-off scripts.

## Trace Catalog Ownership

Trace the exact ID before editing any XML:

```powershell
node $tool trace "<map-or-mod>" --catalog Unit --id MarineRaynor --format text
node $tool trace "<map-or-mod>" --catalog Unit --id MarineRaynor --field CardLayouts --format text
```

For 7vs1, include the effective profile and commander:

```powershell
node $tool trace "<map.SC2Map>" --effective --commander TerranRaynor `
  --catalog Upgrade --id "<upgrade-id>" --format json
```

Use the result to distinguish:

- The first definition from inherited parents.
- Same-ID definitions loaded later.
- `parent` inheritance and unresolved parents.
- Field definition history and the effective last definition.
- `removed="1"` and keyed array merge behavior.
- Literal Galaxy runtime mutations such as `TechTree*Allow`, `UnitAbilityAdd`, and
  `CatalogFieldValueSet`.
- Incomplete traces caused by external or missing dependencies.

Treat `provenanceMode: definition-history` literally. It records definition and override history;
it is not a full simulation of every SC2 runtime transformation.

Compare two environments directly when behavior differs between a campaign map, custom-melee map,
test map, or Mod stack:

```powershell
node $tool compare "<campaign-map>" "<custom-map>" `
  --catalog Upgrade --id "<upgrade-id>" --format text
```

Use `--left-effective` / `--right-effective` and the matching commander flags when only one side
uses a launcher profile. Prefer `--field` for large entries. A comparison with either side marked
incomplete returns a nonzero exit code by default and is evidence of visible differences, not proof
that no additional differences exist. Use `--allow-incomplete` only when deliberately accepting and
reporting the missing dependency boundary.

If a user gives only a localized technology or button name, search GameStrings, ObjectStrings,
TriggerStrings, Button, Abil, Requirement, and Upgrade data to recover the internal ASCII ID before
tracing. Follow the chain `Button -> AbilCmd -> InfoArray -> Upgrade -> Requirement`, then compare
the relevant ID in both environments.

## Expand Unit Relationships

Use `sc2_unit_explorer.py` after the dependency and ownership trace when the question concerns
production, abilities, command cards, weapons, research, or reverse producers:

```powershell
python "合作指挥官-起义狂潮/scripts/sc2_unit_explorer.py" MarineRaynor --depth 2
```

Use the toolkit for dependency/ownership provenance and the explorer for relationship expansion.
Do not treat the explorer's default dependency chain as equivalent to `inspect --effective`; add
the relevant Mod explicitly when needed and keep the toolkit trace authoritative for load order.
Do not reimplement either analyzer inside a task-specific script.

## Make the Smallest Root-Cause Fix

Edit the earliest package that should own the behavior while respecting effective load order.
Prefer configuration or adapter fixes over copying whole Catalog entries into a map.

Before changing data, answer:

1. Which effective parent supplies the current value?
2. Which later package or map definition overrides it?
3. Is the mismatch XML merge behavior, `parent` inheritance, runtime Galaxy mutation, or a missing
   dependency?
4. Does the fix belong in a shared Mod, commander package, adapter, launcher profile, or map-local
   data?

Apply this ownership priority:

1. Shared upstream Mod when every consumer should receive the behavior.
2. Commander package when the behavior is canonical for one commander.
3. Adapter when the change only reconciles a commander with a specific runtime or map family.
4. Launcher/configuration when the problem is dependency selection or ordering.
5. Map-local data only for mission-specific behavior that should not propagate.

Keep internal script IDs, variable IDs, and filesystem paths ASCII when possible. Chinese display
text may remain localized. If an editor save failure follows trigger edits, inspect name-derived
script IDs and disable name-to-ID rewriting for Chinese identifiers; using an English editor or
translation pack changes the text-injection tradeoff and is not a substitute for stable internal
IDs.

## Route Validation From Changed Files

Generate the minimum static plan:

```powershell
node $tool check --changed --format text
node $tool check --changed --run --format text
```

Pass explicit files when the worktree contains unrelated user changes:

```powershell
node $tool check "<relative-file-1>" "<relative-file-2>" --run --format text
```

Interpret routing as follows:

- GameData XML: validate the containing package against its resolved dependency chain.
- Galaxy: run `galaxy-checker` against the entire containing `Base.SC2Data`, not a filtered
  single-file result.
- Toolkit code: run its Node test suite.
- Map/runtime changes: require in-game validation in addition to static checks.

After modifying `.galaxy` or `_h.galaxy`, run:

```powershell
node "合作指挥官-起义狂潮/scripts/galaxy-checker/dist/cli.mjs" `
  "<mod-or-map>/Base.SC2Data" --format text
```

Read every `[ERROR]` line. Fix actionable parser, semantic, cross-library, native, argument-count,
encoding, and BOM errors before entering the map.

When `inspect` reports unresolved official dependencies, locate a local official data mirror and
either add it to `dependencySearchRoots`, add a precise alias, or set `SC2_ROOT`, then rerun
`inspect` and `trace`. Stop when the missing dependency is genuinely unavailable and report the
remaining incomplete boundary.

## Select the Correct Runtime Test

For 7vs1 maps, use the repository's dedicated launcher. Restart an already-running game, wait for
`wait-for-game-ready.ps1`, and treat any nonzero result as a failed verification.

For ordinary MPQ maps, never use the 7vs1 launcher because it injects incompatible runtime
libraries. Start the original MPQ with `SC2Switcher_x64.exe`, wait at least 45 seconds, confirm the
`SC2_x64` process remains alive, and inspect new `ScriptError.txt` files.

Do not run an in-game test when only the toolkit, Skill, configuration, tests, or documentation
changed and no map/runtime behavior changed.

## Turn Failures Into Reusable Knowledge

When a new failure appears:

1. Capture a minimal reproducible fixture or real file reference.
2. Classify it as dependency resolution, Catalog merge/provenance, Galaxy static analysis,
   validation routing, editor/path risk, or runtime-only behavior.
3. Add or update the machine-readable configuration, parser rule, extractor, or router.
4. Add a regression test that fails before the fix.
5. Run the narrow test, then the relevant full suite.
6. Add a concise experience note under `合作指挥官-起义狂潮/docs/经验总结` when the failure was
   encountered in practice.

Do not record a recurring failure only in prose. The workflow improves only when the next run can
detect or route it automatically.

## Report the Result

Use these headings when the task is diagnostic or modifies runtime behavior:

- Effective dependency chain.
- Catalog ID and field source history.
- Runtime mutations.
- Root cause.
- Minimal fix location.
- Static verification.
- In-game verification, when required.
- Remaining incomplete dependencies or known limitations.

Do not report a trace as authoritative when `complete` is false.
Do not interpret `runtimeMutations: []` as proof of no runtime modification; dynamic IDs, variables,
indirect calls, and generated strings remain outside the literal scanner.

Treat a diagnosis as complete only when:

1. Both compared environments have resolved dependency boundaries, or every accepted missing
   boundary is explicitly listed.
2. The target internal ID is identified on both sides.
3. The differing definition, field, parent, or runtime mutation is located.
4. The proposed owner follows the shared/commander/adapter/config/map priority.
5. Static validation passes and required in-game validation completes.
6. Runtime scan limitations are reported when the conclusion depends on an empty mutation list.
