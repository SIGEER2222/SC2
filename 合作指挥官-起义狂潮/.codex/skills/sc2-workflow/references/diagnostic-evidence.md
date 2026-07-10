# Diagnostic Evidence

## Dependency Semantics

- Treat the dependency chain as parent data. Parents load first; later packages and the map merge
  or replace the same Catalog IDs.
- Inspect both declared and launcher-effective dependencies for 7vs1 maps.
- Treat unresolved official campaign/Mod dependencies as an incomplete boundary.
- A fixed dependency may still require map-local repair when the map overrides the same ID.

## Unit Production and Ability Checks

Trace all relevant layers:

| Question | Primary evidence |
|---|---|
| Can the producer train the unit? | Producer train ability and ability `InfoArray` |
| Is the train button visible? | Producer `CardLayouts`, command index, Requirement |
| Does the created unit own the skill? | Unit `AbilArray`, inherited parent, runtime `UnitAbilityAdd` |
| Is the skill button visible? | Unit `CardLayouts`, Requirement, Restricted state |
| Is the tech enabled? | Static requirements plus runtime `TechTree*Allow/Block` |
| Why do environments differ? | Dependency order, trace history, compare output, runtime events |

Use internal IDs for diagnosis. Localized names are discovery hints, not stable keys.

## Static and Runtime Boundaries

- `complete: false` means the dependency boundary is incomplete, even when `hasErrors` is false.
- An empty runtime event list is inconclusive. Literal/local scans cannot prove absence of dynamic
  IDs, generated strings, indirect calls, or cross-function data flow.
- `provenanceMode: definition-history` describes definitions and overrides, not full engine
  execution.
- Prefer a direct trace of `AbilArray`, `CardLayouts`, and train `InfoArray` before proposing XML.

## Galaxy Checker Classification

Separate findings into:

1. Compile or semantic errors that must be fixed.
2. Project policy findings such as disallowed native usage.
3. Cross-Mod boundary findings caused by scanning without required dependency roots.
4. Checker false positives contradicted by official, compiling Galaxy sources.

Always read the complete checker output. Do not filter to one rule and declare the scan clean.
If the game reports a ScriptError that the checker misses, add a checker fixture and rule before
continuing the runtime fix.

## Common Save Failures

- Keep script IDs, variable IDs, and paths ASCII where possible.
- Chinese display text may remain localized, but name-derived script IDs can become corrupted.
- If a trigger editor rewrites IDs from localized names, disable name-based ID replacement or use
  stable ASCII names.
- Translation packages can inject localized game text into a map; record that tradeoff when used.
