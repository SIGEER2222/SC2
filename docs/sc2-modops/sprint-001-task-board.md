# Sprint 001 Task Board

## Sprint Goal

Create the first reviewable evidence base for the SC2Mod AI development platform. The first priority is a Galaxy Editor / SC2 Editor reference knowledge-base seed, followed by project inventories, classifications, draft knowledge records, and candidate validator coverage without changing SC2 assets.

## Execution Policy

- Cheap workers produce drafts only.
- Strong reviewer owns schema approval, semantic decisions, and final acceptance.
- Deterministic scripts should be preferred for file discovery, hashing, and validation.
- No worker may edit SC2 assets, `DocumentHeader`, `DocumentInfo`, map files, or runtime Galaxy code during this sprint.
- All outputs must cite source paths.

## Roles

| Role | Model Tier | Responsibility |
|---|---|---|
| Leader | Strong | Owns sprint scope, task routing, review order, and final acceptance. |
| Worker A | Cheap | Source inventory and module map draft. |
| Worker B | Cheap | Script catalog draft. |
| Worker C | Cheap | Validator coverage matrix draft. |
| Worker D | Cheap | Historical fix knowledge-card drafts. |
| Worker E | Cheap | XML candidate reference-field extraction. |
| Worker F | Cheap | Skill checklist drafts. |
| Worker G | Cheap | Eval seed case drafts. |
| Tool Runner | Deterministic | Executes scripts, schemas, stats, and validation commands. |
| Reviewer | Strong | Reviews worker drafts and decides what becomes platform rules. |

## Wave 0: Immediate Dispatch - Galaxy Editor Reference KB

Wave 0 builds the external/reference knowledge layer before the platform overfits to the current repository. This is the first task group to dispatch.

### S001-RKB: Galaxy Editor Reference KB Seed

Owner: Worker RKB.

Model tier: cheap.

Priority: P0.

Inputs:

- Public Galaxy Editor / SC2 Editor documentation and tutorial sources.
- `docs/sc2-modops/galaxy-editor-reference-kb-plan.md`.

Forbidden:

- Do not treat AI summaries as primary sources.
- Do not produce final SC2 semantic rules.
- Do not claim a source is official unless the source itself supports that.
- Do not scrape or copy large copyrighted passages into the repository.

Outputs:

```text
artifacts/sc2-modops/sprint-001/worker-rkb/source-trust-map.md
artifacts/sc2-modops/sprint-001/worker-rkb/reference-sources.jsonl
artifacts/sc2-modops/sprint-001/worker-rkb/editor-glossary-draft.md
artifacts/sc2-modops/sprint-001/worker-rkb/reference-chunking-plan.md
```

Acceptance:

- Sources are tiered by trust level.
- Every glossary term cites a source URL.
- Version-sensitive sources are flagged.
- Strong reviewer can decide which sources are allowed into Reference KB.

Reviewer: Strong reviewer.

## Wave 1: Project Evidence Dispatch

Wave 1 gives the leader enough repository visibility to plan implementation work. It should start after Wave 0 source tiers are drafted, but it can run in parallel once Worker RKB has produced the initial source list.

### S001-A: Source Inventory And Module Map

Owner: Worker A.

Model tier: cheap.

Priority: P0.

Inputs:

- Repository root.
- Top-level SC2Mod and SC2Map folders.
- Existing docs and scripts folders.

Forbidden:

- Do not edit source files.
- Do not infer gameplay behavior.
- Do not classify a folder as generated unless evidence is stated.

Outputs:

```text
kb/raw-manifest/source-inventory-draft.jsonl
reports/source-inventory-summary.md
```

Required fields per JSONL record:

```json
{
  "path": "",
  "asset_type": "mod|map|xml|galaxy|localization|document|script|artifact|unknown",
  "module_guess": "",
  "reason": "",
  "confidence": "low|medium|high"
}
```

Acceptance:

- Covers top-level project assets.
- Includes source paths.
- Marks uncertainty instead of guessing.

Reviewer: Leader.

### S001-B: Script Catalog

Owner: Worker B.

Model tier: cheap.

Priority: P0.

Inputs:

- `scripts/`
- Any docs that mention launchers, validators, export scripts, or repair scripts.

Forbidden:

- Do not run scripts unless separately instructed.
- Do not modify scripts.
- Do not claim script behavior beyond visible code or documentation.

Outputs:

```text
kb/raw-manifest/script-catalog-draft.jsonl
reports/script-catalog-summary.md
```

Required fields per JSONL record:

```json
{
  "path": "",
  "category": "launcher|validator|sync|repair|export|web-ui|unknown",
  "purpose": "",
  "inputs": [],
  "outputs": [],
  "risk_notes": "",
  "confidence": "low|medium|high"
}
```

Acceptance:

- Every script has a category or `unknown`.
- Risky scripts are flagged.
- Source path is included for each claim.

Reviewer: Leader.

### S001-C: Validator Coverage Matrix Draft

Owner: Worker C.

Model tier: cheap.

Priority: P0.

Inputs:

- Existing validator scripts.
- Historical bug reports if available.
- `docs/sc2-modops/cheap-model-workqueue.md`.

Forbidden:

- Do not author final blocking rules.
- Do not claim coverage without a script path.
- Do not edit validators.

Outputs:

```text
docs/sc2-modops/validation-coverage-draft.md
```

Required matrix columns:

```text
Risk area | Existing script | Covered behavior | Known gap | Suggested future validator | Confidence
```

Acceptance:

- Identifies covered and uncovered risk areas.
- Separates confirmed coverage from suggested coverage.

Reviewer: Strong reviewer.

## Wave 2: Dispatch After Wave 1

### S001-D: Historical Fix Knowledge Cards

Owner: Worker D.

Model tier: cheap.

Priority: P1.

Inputs:

- Project docs.
- Historical progress notes.
- Existing AI output documents if present.
- Wave 1 source and script inventories.

Forbidden:

- Do not turn uncertain notes into confirmed facts.
- Do not rewrite original reports.
- Do not create final rules.

Outputs:

```text
kb/cards/draft/<topic>.md
```

Card template:

```text
Title:
Source paths:
Symptom:
Evidence:
Root cause:
Fix:
Validation:
Future guardrail:
Confidence:
Open questions:
```

Acceptance:

- Each card cites source paths.
- Each card separates evidence from inference.

Reviewer: Strong reviewer.

### S001-E: XML Candidate Reference Fields

Owner: Worker E.

Model tier: cheap.

Priority: P1.

Inputs:

- Representative `GameData/*.xml` files.
- Wave 1 source inventory.

Forbidden:

- Do not define final graph semantics.
- Do not infer target type without examples.
- Do not modify XML.

Outputs:

```text
kb/catalog/candidate-reference-fields.jsonl
reports/xml-reference-field-candidates.md
```

Required fields per JSONL record:

```json
{
  "source_file": "",
  "source_node_type": "",
  "field_path": "",
  "example_value": "",
  "candidate_target_type": "",
  "reason": "",
  "confidence": "low|medium|high"
}
```

Acceptance:

- Provides examples for candidate reference fields.
- Marks ambiguous fields as low confidence.

Reviewer: Strong reviewer.

## Wave 3: Dispatch After First Review

### S001-F: Skill Checklist Drafts

Owner: Worker F.

Model tier: cheap.

Priority: P2.

Inputs:

- `docs/sc2-modops/project-charter.md`
- `docs/sc2-modops/task-protocol.md`
- Reviewed Wave 1 and Wave 2 outputs.

Forbidden:

- Do not create final `SKILL.md` files.
- Do not add semantic rules without source citations.

Outputs:

```text
skills-draft/sc2-catalog-closure/checklist.md
skills-draft/sc2-commander-audit/checklist.md
skills-draft/sc2-map-dependency/checklist.md
skills-draft/sc2-galaxy-runtime/checklist.md
skills-draft/sc2-validator-author/checklist.md
```

Acceptance:

- Each checklist has inputs, steps, outputs, forbidden actions, and validation.
- Any proposed rule is marked `proposed`.

Reviewer: Leader.

### S001-G: Eval Seed Cases

Owner: Worker G.

Model tier: cheap.

Priority: P2.

Inputs:

- Reviewed knowledge cards.
- Validator matrix.
- Task protocol.

Forbidden:

- Do not invent incidents.
- Do not mark eval cases as final.

Outputs:

```text
evals/draft/sc2-task-routing.jsonl
evals/draft/catalog-closure-cases.jsonl
```

Required fields per JSONL record:

```json
{
  "case_id": "",
  "question": "",
  "evidence_paths": [],
  "correct_conclusion": "",
  "common_wrong_conclusion": "",
  "expected_gate": "",
  "confidence": "low|medium|high"
}
```

Acceptance:

- Every eval case cites evidence paths.
- Wrong conclusions are plausible failure modes, not artificial strawmen.

Reviewer: Strong reviewer.

## Leader-Owned Tasks

### S001-L1: Output Directory Decision

Owner: Leader.

Model tier: strong.

Decision:

- Confirm whether `kb/`, `reports/`, `evals/`, and `skills-draft/` should live at repository root or under `artifacts/sc2-modops/` for first drafts.

Default for this sprint:

- Draft worker outputs should use `artifacts/sc2-modops/sprint-001/` unless the leader explicitly promotes them.

### S001-L2: Schema Review

Owner: Strong reviewer.

Model tier: strong.

Inputs:

- Wave 1 and Wave 2 JSONL drafts.

Decision:

- Approve, revise, or reject draft schemas before implementation tools depend on them.

### S001-L3: Implementation Backlog

Owner: Leader.

Model tier: strong.

Inputs:

- Reviewed Wave 1 outputs.

Output:

```text
docs/sc2-modops/sprint-002-implementation-backlog.md
```

Goal:

- Convert reviewed discovery results into concrete parser, indexer, and validator implementation tasks.

## Dependency Order

```text
S001-RKB
  -> Strong review of source tiers
  -> S001-A + S001-B + S001-C
  -> Leader review
  -> S001-D + S001-E
  -> Strong review
  -> S001-F + S001-G
  -> Sprint 002 implementation backlog
```

## Done Definition

Sprint 001 is done when:

- Galaxy Editor reference source tiers exist and are reviewed.
- Wave 1 outputs exist and are reviewed.
- Wave 2 outputs exist and are reviewed.
- Draft skill and eval materials exist.
- No SC2 assets were modified.
- Sprint 002 implementation backlog is ready.
