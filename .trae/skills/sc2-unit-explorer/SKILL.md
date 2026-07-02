---
name: "sc2-unit-explorer"
description: "Scans SC2 mods to extract unit/building/ability relationships without launching the game. Invoke when user wants to analyze a mod's unit production chains, tech tree, or commander-specific units, or asks 'what units does mod X add / which units can Y build'."
---

# SC2 Unit Explorer

This skill analyzes StarCraft 2 mods (`.SC2Mod` / `.sc2mod`) offline and extracts complete unit relationships — abilities, production, construction, research, weapons, and reverse dependencies — without launching the game.

## Tool Location

- **Script**: `合作指挥官-起义狂潮/scripts/sc2_unit_explorer.py`
- **Language**: Python 3 (uses lenient XML parsing, supports multi-layer mod merging)

## When to Invoke

- User asks "mod X 新增了哪些单位 / 有什么建筑 / 能生产什么"
- User wants to scan a mod's commander-specific units
- User wants to compare unit production chains across mods
- User asks about unit relationships (who builds X, what Y can produce, reverse dependencies)
- User wants to extract unit lists from a mod's `UnitData.xml`
- User wants to identify mod-original units (excluding SC2 native units)

## Core Mod Loading Chain

The tool merges multiple mod layers in order (later overrides earlier):

1. **Base SC2 mods** (always load first):
   - `E:\Code\MyMod\SC2\sc2-data-trigger\mods\core.sc2mod`
   - `E:\Code\MyMod\SC2\sc2-data-trigger\mods\liberty.sc2mod`
   - `E:\Code\MyMod\SC2\sc2-data-trigger\mods\swarm.sc2mod`
   - `E:\Code\MyMod\SC2\sc2-data-trigger\mods\void.sc2mod`

2. **Target mod(s)** to analyze (pass via `--only-mod`)

## Commands

### 1. List all units in a mod
```powershell
python sc2_unit_explorer.py --list-units --only-mod <base1> --only-mod <base2> ... --only-mod <target_mod>
```

### 2. List all abilities in a mod
```powershell
python sc2_unit_explorer.py --list-abilities --only-mod <base1> ... --only-mod <target_mod>
```

### 3. Query a single unit's full relationship (depth-controlled)
```powershell
python sc2_unit_explorer.py <UnitID> --depth 3 --only-mod <base1> ... --only-mod <target_mod>
```

- `--depth N`: expansion depth (1 = direct relations only, 3 = 3 levels deep)

## Parameters

| Parameter | Description |
|-----------|-------------|
| `--list-units` | Print all unit IDs + names to stdout |
| `--list-abilities` | Print all ability IDs to stdout |
| `--only-mod PATH` | Specify a mod to load (repeat for each mod; order matters) |
| `--depth N` | Relationship expansion depth (default 1) |
| `<UnitID>` | Positional arg: query this specific unit |

## Relationship Output (per unit)

For each queried unit, the tool reports:
- **Abilities** (AbilArray + CardLayouts, with parent inheritance merged)
- **Produces** (units this can train/morph)
- **Built By** (reverse: which units/buildings produce this)
- **Researches** (upgrades available here)
- **Weapons** (weapons attached to this unit)
- **Tech Tree** (requirements, restrictions)

## Merge Semantics

- `id` / `index` / `Row+Column` fields: child overrides parent entry by key
- `Link` fields: appended unless `removed="1"` is set
- `InfoArray` sub-elements: selected by `index` attribute
- Derived units with `parent` attribute inherit parent's `AbilArray` / `CardLayouts`, with child-specific entries taking priority

## Common Use Cases

### Case A: Scan a single mod's original units

1. Build the SC2 native ID set (958 units from core/liberty/swarm/void)
2. Load the mod's `UnitData.xml`, extract all CUnit ids
3. Filter: `mod_ids - native_ids` = mod-original units
4. For each original unit, run `sc2_unit_explorer.py <id> --depth 1`

### Case B: Scan commander-specific units

1. Identify the commander's hero unit (from galaxy script `gt_CommanderStart_Func` or `CommanderUnits` ability in `AbilData.xml`)
2. Run `sc2_unit_explorer.py <hero_id> --depth 3` to expand the production chain
3. For finer grouping, filter mod-original units by ID keyword (e.g., `^SI` for Izsha, `Primal*` for Dehaka)

### Case C: Compare across mods/factions

1. Run `--list-units` for each faction mod (with common base + shared mods)
2. Diff the unit ID lists
3. Generate a comparison table

## PowerShell Wrapper Pattern

For batch scanning multiple factions/commanders, wrap the tool in a PowerShell script:

```powershell
$BaseMods = @(
    "E:\Code\MyMod\SC2\sc2-data-trigger\mods\core.sc2mod",
    "E:\Code\MyMod\SC2\sc2-data-trigger\mods\liberty.sc2mod",
    "E:\Code\MyMod\SC2\sc2-data-trigger\mods\swarm.sc2mod",
    "E:\Code\MyMod\SC2\sc2-data-trigger\mods\void.sc2mod"
)
$TargetMods = @("path\to\target.SC2Mod")

$modArgs = @()
foreach ($m in ($BaseMods + $TargetMods)) { $modArgs += @("--only-mod", $m) }

# List units
& python sc2_unit_explorer.py --list-units @modArgs 2>$null | Out-File -FilePath "units.txt" -Encoding utf8

# Single unit detail
& python sc2_unit_explorer.py <UnitID> --depth 1 @modArgs 2>$null | Out-File -FilePath "detail.txt" -Encoding utf8 -Append
```

## Output Redirection

The tool prints to stdout. To save results, redirect with PowerShell:
- `Out-File -FilePath <path> -Encoding utf8` (overwrite)
- `Out-File -FilePath <path> -Encoding utf8 -Append` (append)
- `2>$null` suppresses stderr (parse warnings, missing localization)

## Known Limitations

- Galaxy runtime-injected abilities (via `UnitAbilityAdd` in triggers) are NOT reflected in the static scan — only data-defined abilities appear
- Localization text requires the mod's `enUS`/`zhCN` GameStrings files to be loaded; missing strings show as raw IDs
- Very large mod merges (1000+ units × depth 3) can be slow; prefer depth 1 for batch scans, depth 3 only for hero units

## Reference Implementations

Existing wrapper scripts in this workspace:
- `合作指挥官-起义狂潮/scripts/scan_crys_with_abathur.ps1` — scan mod-original commanders (filters SC2 native units, groups by keyword, includes Abathur from `CommanderUnits` ability)
- `其他mod/RevolutionOverdrive缝合版/_scan_all_factions.ps1` — scan 5 faction mods in batch
- `其他mod/RevolutionOverdrive缝合版/_scan_coverts_umojan.ps1` — scan mods without ID prefix (reads `UnitData.xml` directly)
