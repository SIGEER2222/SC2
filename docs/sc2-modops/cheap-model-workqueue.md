# Cheap Model Work Queue

## Purpose

This queue contains work that can be delegated to cheap or free models now. These tasks are high-volume, low-risk, and produce reviewable drafts or structured candidates. They must not directly modify SC2 assets or mainline project rules.

## Global Rules For Cheap Workers

- Produce drafts, not final decisions.
- Do not edit SC2 assets.
- Do not modify `DocumentHeader` or `DocumentInfo`.
- Do not delete, disable, or rename Catalog nodes.
- Do not claim a bug is fixed.
- Always include source paths for claims.
- Mark uncertainty explicitly.
- Prefer JSONL or tables for large extracted data.

## Queue 001: Source Inventory Draft

Model tier: cheap.

Input:

- Repository root.
- Existing SC2Mod and SC2Map folders.

Task:

- List candidate SC2 source assets.
- Classify paths by type: mod, map, XML, Galaxy, localization, document, script, artifact.
- Identify large files and generated-looking files.

Output:

```text
kb/raw-manifest/source-inventory-draft.jsonl
reports/source-inventory-summary.md
```

Acceptance:

- Every record has `path`, `type`, `reason`, and `confidence`.
- No file content is rewritten.

## Queue 002: Existing Script Catalog

Model tier: cheap.

Input:

- `scripts/`
- project documentation mentioning validators or launchers

Task:

- Summarize each script's purpose.
- Identify likely inputs and outputs.
- Classify as launcher, validator, sync, repair, export, or unknown.

Output:

```text
kb/raw-manifest/script-catalog-draft.jsonl
reports/script-catalog-summary.md
```

Acceptance:

- Each script has a source path and a short summary.
- Unknown scripts are marked `unknown`, not guessed as final.

## Queue 003: Historical Fix Knowledge Cards

Model tier: cheap.

Input:

- Existing progress documents.
- Historical repair notes.
- AI output documents.

Task:

- Convert each confirmed historical fix into a knowledge card draft.
- Extract symptom, evidence, root cause, fix, validation, and future guardrail.

Output:

```text
kb/cards/draft/*.md
```

Acceptance:

- Cards must cite source documents.
- Cards must distinguish confirmed facts from inference.

## Queue 004: SC2 Topic Classification

Model tier: cheap.

Input:

- Historical fix cards.
- Script summaries.
- Design documents.

Task:

- Assign topics:
  - Catalog
  - Galaxy
  - DocumentHeader
  - DocumentInfo
  - Commander
  - Map
  - UI
  - Runtime
  - Localization
  - Validator
  - Editor round-trip

Output:

```text
kb/classification/topic-labels-draft.jsonl
```

Acceptance:

- Multiple labels allowed.
- Include confidence and source path.

## Queue 005: XML Field Candidate Extraction

Model tier: cheap.

Input:

- Sample `GameData/*.xml` files.

Task:

- Identify candidate fields that appear to reference other Catalog entries.
- Group by source node type and target candidate type.

Output:

```text
kb/catalog/candidate-reference-fields.jsonl
```

Acceptance:

- This is only a candidate list.
- Do not define final graph semantics.
- Include examples for each candidate field.

## Queue 006: Validator Coverage Matrix Draft

Model tier: cheap.

Input:

- Existing validator scripts.
- Historical bug reports.

Task:

- Map validators to risk categories.
- Identify risks with no validator coverage.
- Suggest candidate validators as drafts.

Output:

```text
docs/sc2-modops/validation-coverage-draft.md
```

Acceptance:

- Suggestions must be marked draft.
- Do not claim coverage unless a script path is cited.

## Queue 007: Skill Checklist Drafts

Model tier: cheap.

Input:

- Project charter.
- Task protocol.
- Historical fix cards.

Task:

- Draft checklists for:
  - `sc2-catalog-closure`
  - `sc2-commander-audit`
  - `sc2-map-dependency`
  - `sc2-galaxy-runtime`
  - `sc2-validator-author`

Output:

```text
skills-draft/<skill-name>/checklist.md
```

Acceptance:

- Checklist items must be action-oriented.
- Any semantic rule must cite a source or be marked as proposed.

## Queue 008: Task And Handoff Template Examples

Model tier: cheap.

Input:

- `task-protocol.md`

Task:

- Generate sample task records for common SC2 workflows.
- Generate sample handoff messages for each agent role.

Output:

```text
docs/sc2-modops/task-examples-draft.md
```

Acceptance:

- Examples must not reference nonexistent completed work.
- Examples must keep high-risk actions assigned to strong review.

## Queue 009: SC2 Term Glossary Draft

Model tier: cheap.

Input:

- Existing project docs.
- SC2 XML/Galaxy identifiers.

Task:

- Build a Chinese-English glossary for common terms.
- Include terms such as Catalog, Ability, Effect, Behavior, Requirement, Upgrade, Actor, DocumentHeader, Galaxy, Trigger, Validator.

Output:

```text
kb/glossary/sc2-terms-draft.md
```

Acceptance:

- Include source examples where possible.
- Mark uncertain translations.

## Queue 010: Eval Seed Cases Draft

Model tier: cheap.

Input:

- Historical fix cards.
- Validator failure examples.

Task:

- Generate eval seed cases with:
  - question
  - relevant evidence
  - correct conclusion
  - common wrong conclusion
  - expected validator or review gate

Output:

```text
evals/draft/sc2-task-routing.jsonl
evals/draft/catalog-closure-cases.jsonl
```

Acceptance:

- Each case must cite its source.
- Cases are drafts until strong-model review.

## Current Priority Order

1. Queue 001: Source Inventory Draft.
2. Queue 002: Existing Script Catalog.
3. Queue 006: Validator Coverage Matrix Draft.
4. Queue 003: Historical Fix Knowledge Cards.
5. Queue 005: XML Field Candidate Extraction.
6. Queue 007: Skill Checklist Drafts.
7. Queue 010: Eval Seed Cases Draft.

The first three tasks give the leader enough visibility to design the next implementation sprint.
