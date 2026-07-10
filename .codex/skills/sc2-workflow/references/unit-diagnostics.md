# Unit Diagnostics

Use `diagnose-unit` for the recurring questions:

- Why can this barracks or building not produce the expected unit?
- Why does the produced unit lack an expected ability or command-card button?
- Which abilities are inherited from `parent` entries?
- Did Galaxy add, remove, unlock, lock, or mutate data after XML loading?

## Command

```powershell
node "合作指挥官-起义狂潮/scripts/sc2-editor-toolkit/cli.mjs" diagnose-unit `
  "<map-or-mod>" `
  --unit MarineRaynor `
  --producer BarracksRaynor `
  --expect-ability SuperStimpackMarineRaynor `
  --effective `
  --commander TerranRaynor `
  --format text
```

`--producer` is optional. Without it, the tool searches resolved units for production abilities
whose `InfoArray` points to the target. `--expect-ability` accepts comma-separated IDs.

Use JSON for automation:

```powershell
node $tool diagnose-unit "<target>" --unit "<id>" --format json
```

The command returns exit 1 when it finds a diagnostic error. It also returns exit 1 for incomplete
dependencies unless `--allow-incomplete` is explicitly supplied.

## What It Resolves

The analyzer loads the dependency graph in parent-first order, merges Catalog entries, expands the
target unit's complete `parent` chain, then checks:

- `CAbilTrain`, `CAbilBuild`, and `CAbilMorph` `InfoArray` targets.
- Whether the producer owns the required production ability.
- Whether `CardLayouts/LayoutButtons/AbilCmd` exposes the production command.
- Requirement and `Restricted` gating visible in static data.
- Expected ability Catalog definitions.
- Static and inherited `AbilArray` membership.
- Expected ability command-card buttons.
- Literal/local-context Galaxy events:
  - `TechTreeUnitAllow`
  - `TechTreeAbilityAllow`
  - `UnitAbilityAdd`
  - `UnitAbilityRemove`
  - `CatalogFieldValueSet*`

The effective ability list applies detected `UnitAbilityAdd` and `UnitAbilityRemove` events on top
of the inherited static unit.

## Important Issue Codes

| Code | Meaning | First place to inspect |
|---|---|---|
| `UNIT_NOT_FOUND` | Target unit is absent from the loaded Catalog | Dependency graph and same-ID trace |
| `UNIT_PARENT_UNRESOLVED` | A unit `parent` entry is unavailable | Missing dependency or bad parent ID |
| `UNIT_PARENT_CIRCULAR` | Unit `parent` inheritance contains a cycle | The IDs in `parentChain` |
| `PRODUCER_PARENT_UNRESOLVED` | The producer's inherited abilities may be unavailable | Producer dependency or parent ID |
| `PRODUCER_PARENT_CIRCULAR` | Producer `parent` inheritance contains a cycle | The IDs in producer `parentChain` |
| `PRODUCTION_SLOT_MISSING` | No Train/Build/Morph slot targets the unit | Production ability `InfoArray` |
| `PRODUCTION_PRODUCER_MISSING` | No loaded unit owns any ability that produces the target | Producer dependency and `AbilArray` |
| `PRODUCER_MISSING_PRODUCTION_ABILITY` | Producer does not own the ability containing the slot | Producer `AbilArray` and inheritance |
| `PRODUCTION_BUTTON_MISSING` | Producer owns the ability but exposes no matching `AbilCmd` | Producer `CardLayouts` |
| `PRODUCTION_REQUIREMENT_GATED` | Requirement or `Restricted` state may hide/block production | Button and slot gating |
| `ABILITY_DEFINITION_MISSING` | Expected ability has no loaded Catalog definition | Dependency and Abil ID |
| `EXPECTED_ABILITY_MISSING` | Static plus detected runtime abilities still lack the expected ability | Unit inheritance and Galaxy injection |
| `EXPECTED_ABILITY_BUTTON_MISSING` | Unit has the ability but no static command-card command | Unit `CardLayouts` |
| `UNIT_TECH_LOCKED_RUNTIME` | Galaxy disables the unit | Relevant TechTree call |
| `PRODUCTION_ABILITY_LOCKED_RUNTIME` | Galaxy disables the production ability | Relevant TechTree call |
| `EXPECTED_ABILITY_LOCKED_RUNTIME` | Galaxy disables an expected ability | Relevant TechTree call |
| `STATIC_RUNTIME_DIVERGENCE` | XML-only inspection differs from detected runtime state | Runtime event list |
| `DIAGNOSIS_INCOMPLETE_DEPENDENCIES` | Missing parents may change the conclusion | `inspect` output |

## Interpretation Order

1. Require `complete: true`, or list every accepted missing dependency.
2. Confirm the target unit and producer resolve through their parent chains.
3. Check that a production slot points to the exact target unit ID.
4. Check that the producer inherits or defines the production ability.
5. Check that its command card exposes the exact ability and command index.
6. Check Requirement/Restricted state.
7. Check expected abilities and their buttons.
8. Check runtime events for locks, injections, removals, or Catalog mutation.
9. Trace the implicated Unit/Abil/Button/Requirement ID when ownership is still ambiguous.

Do not treat the runtime scan as complete data-flow analysis. Variable-propagated IDs, generated
strings, indirect wrappers, and ambiguous context still require Galaxy inspection or an in-game
test.
