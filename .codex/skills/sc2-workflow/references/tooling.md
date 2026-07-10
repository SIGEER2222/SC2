# Tooling And Data Sources

## Primary Tools

| Tool | Path | Responsibility |
|---|---|---|
| SC2 editor toolkit | `合作指挥官-起义狂潮/scripts/sc2-editor-toolkit/cli.mjs` | Dependency graph, Catalog provenance, unit diagnosis, validation routing |
| Galaxy checker | `合作指挥官-起义狂潮/scripts/galaxy-checker/dist/cli.mjs` | Galaxy syntax, semantics, cross-library references, encoding, Catalog literal references |
| Unit explorer | `合作指挥官-起义狂潮/scripts/sc2_unit_explorer.py` | Broad unit production, research, weapon, ability, and reverse-producer exploration |
| Runtime wait | `合作指挥官-起义狂潮/scripts/wait-for-game-ready.ps1` | 7vs1 readiness and ScriptError gate |

Reference GameData mirror:

```text
E:\Code\MyMod\SC2\其他mod\SC2GameData
```

Launcher-equivalent dependency order, aliases, and commander mappings:

```text
合作指挥官-起义狂潮/Shared/Workflow/sc2-workflow.json
```

Update the machine-readable configuration when dependencies, aliases, split commander packages, or
launcher order change. Do not duplicate those facts in one-off scripts or prompts.

## Unit Explorer

Use the explorer after dependency inspection when broad relationships beyond the focused
`diagnose-unit` result are required:

```powershell
python "合作指挥官-起义狂潮/scripts/sc2_unit_explorer.py" MarineRaynor --depth 2
python "合作指挥官-起义狂潮/scripts/sc2_unit_explorer.py" BarracksRaynor
python "合作指挥官-起义狂潮/scripts/sc2_unit_explorer.py" Marine --mod "<other-mod>"
```

Keep the toolkit authoritative for effective load order and provenance. The explorer's default Mod
chain is not automatically equivalent to launcher-effective dependencies.

## MPQ Inspection

Use `mpyq` when a compressed map must be inspected as files:

```python
from mpyq import MPQArchive

archive = MPQArchive(r"<MPQ文件路径>")
for name_bytes in archive.files:
    ...
```

Extract to a separate analysis directory. Do not overwrite the original MPQ.

## Maintenance Boundaries

- Add dependency and alias facts to `sc2-workflow.json`.
- Add Galaxy misses to `galaxy-checker` with regression tests.
- Add Catalog merge, inheritance, provenance, or unit-diagnostic misses to
  `sc2-editor-toolkit` with fixtures.
- Keep `[运行时注入]` and `科技树:已解锁/锁定` output markers stable in
  `sc2_unit_explorer.py`; existing reports depend on them.
- Add concise real-world failure notes under `合作指挥官-起义狂潮/docs/经验总结`, but never use
  prose as a substitute for executable validation.
