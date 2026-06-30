# Galaxy Editor Reference KB Plan

## Purpose

Build the reference knowledge base before relying on project-specific repository analysis. The SC2Mod AI platform needs a stable understanding of the StarCraft II Editor, Data Editor, Trigger Editor, GalaxyScript, Catalog data, dependencies, and publishing/runtime behavior.

Without this layer, later RAG and skills will overfit to the current repository and repeat historical SC2 Editor misunderstandings.

## Priority

This is Wave 0 for the platform. It should start before source inventory, script cataloging, or validator expansion.

## Source Tiers

| Tier | Source Type | Usage |
|---|---|---|
| T0 | Local extracted game data and editor-produced files | Ground truth for current project facts. |
| T1 | Blizzard-origin editor tutorials and official forum/update posts | High-trust reference for editor concepts and platform behavior. |
| T2 | Maintained community references such as SC2Mapster wiki.gg and Galaxy API references | Practical reference for editor workflows and API details. |
| T3 | Historical tutorials, blogs, forum answers, videos | Useful examples, but must be dated and treated as version-sensitive. |
| T4 | AI-generated summaries | Draft only; never primary evidence. |

## Initial Source Seeds

| Topic | Candidate Source | Notes |
|---|---|---|
| Editor overview | `https://s2editor-guides.readthedocs.io/` | SC2Mapster-maintained copy of Blizzard-origin editor tutorials. |
| Data Editor basics | `https://s2editor-guides.readthedocs.io/New_Tutorials/04_Data_Editor/058_Data_Editor_Introduction/` | Explains Data Editor as the home of project data assets. |
| Trigger Editor / GalaxyScript | `https://s2editor-guides.readthedocs.io/New_Tutorials/03_Trigger_Editor/058_GalaxyScript/` | Useful for deciding when runtime Galaxy is needed. |
| SC2Mapster tutorials | `https://sc2mapster.wiki.gg/wiki/Tutorials` | Broad community-maintained tutorial index. |
| Data types | `https://sc2mapster.wiki.gg/wiki/Data_Types` | Candidate source for Catalog concept taxonomy. |
| Galaxy API | `https://mapster.talv.space/galaxy/reference` | API/native reference and Catalog-related functions. |
| Publishing/runtime status | `https://us.forums.blizzard.com/en/sc2/t/starcraft-ii-editor-map-publishing-update-feb-24-2026/30688` | Current-ish official forum source for publishing behavior and service changes. |

## Knowledge Domains

Reference KB entries should be tagged by domain:

- `editor-overview`
- `data-editor`
- `catalog`
- `trigger-editor`
- `galaxy-script`
- `dependency`
- `document-header`
- `document-info`
- `localization`
- `actor-model`
- `requirement-validator`
- `publishing`
- `round-trip`
- `version-sensitive`

## Required Metadata

Each reference record must include:

```json
{
  "source_url": "",
  "source_title": "",
  "source_tier": "T0|T1|T2|T3|T4",
  "retrieved_date": "",
  "topic": [],
  "summary": "",
  "key_terms": [],
  "version_notes": "",
  "confidence": "low|medium|high",
  "outdated_risk": "low|medium|high",
  "usable_for": [],
  "not_usable_for": []
}
```

## Cheap Worker Tasks

### RKB-001: Source List And Trust Map

Owner: cheap worker.

Output:

```text
artifacts/sc2-modops/sprint-001/worker-rkb/source-trust-map.md
artifacts/sc2-modops/sprint-001/worker-rkb/reference-sources.jsonl
```

Task:

- Collect candidate Galaxy Editor / SC2 Editor reference sources.
- Classify each by source tier.
- Mark topic coverage.
- Mark outdated risk.
- Do not summarize technical rules yet.

### RKB-002: Editor Concept Glossary Draft

Owner: cheap worker.

Output:

```text
artifacts/sc2-modops/sprint-001/worker-rkb/editor-glossary-draft.md
```

Task:

- Extract editor terms and short definitions.
- Include source URL for every term.
- Mark ambiguous or version-sensitive terms.

### RKB-003: Reference Chunking Plan

Owner: cheap worker.

Output:

```text
artifacts/sc2-modops/sprint-001/worker-rkb/reference-chunking-plan.md
```

Task:

- Propose chunking rules for tutorials, API references, forum posts, and local extracted files.
- Include fields needed for RAG ingestion.
- Do not actually decide final schema.

## Strong Reviewer Tasks

The strong reviewer must decide:

- Which sources become trusted Reference KB input.
- Which sources are examples only.
- Which topics require local extracted-game-data verification.
- Which facts are stable enough to become skill rules.
- Which facts must remain version-sensitive RAG notes.

## Acceptance

Wave 0 is complete when:

- A source trust map exists.
- An editor glossary draft exists.
- A reference chunking plan exists.
- Strong reviewer approves the first source tiers.
- Later SC2 task skills can cite Reference KB categories instead of relying only on local project memory.
