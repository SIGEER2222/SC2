# Sprint 001 Worker Prompts

## Usage

Copy one prompt per worker. Do not assign multiple workers to the same output path. Cheap workers should write draft artifacts only and must not modify SC2 assets.

For this sprint, prefer draft outputs under:

```text
artifacts/sc2-modops/sprint-001/<worker-id>/
```

The leader can promote reviewed outputs into stable `kb/`, `reports/`, `evals/`, or `skills-draft/` locations later.

## Common Worker Header

Use this at the start of every delegated prompt:

```text
You are a cheap-model worker in the SC2Mod AI development platform project.

You are not alone in the repository. Other agents may be working on separate output paths. Do not revert or modify changes you did not make.

You produce drafts only. Do not edit SC2 assets, maps, Catalog XML, Galaxy runtime files, DocumentHeader, or DocumentInfo. Do not claim final SC2 semantic conclusions.

Every claim must cite a source path. Mark uncertainty explicitly. Prefer JSONL, Markdown tables, and short summaries over long narrative.
```

## Worker RKB Prompt: Galaxy Editor Reference KB Seed

```text
<COMMON WORKER HEADER>

Task ID: S001-RKB
Owner: Worker RKB
Model tier: cheap

Goal:
Create the first Galaxy Editor / SC2 Editor reference knowledge-base seed before project-specific repo analysis.

Inputs:
- docs/sc2-modops/galaxy-editor-reference-kb-plan.md
- Public SC2 Editor / Galaxy Editor / Data Editor / Trigger Editor / GalaxyScript reference sources.

Do:
- Collect candidate reference sources.
- Classify each source by trust tier T0-T4 using galaxy-editor-reference-kb-plan.md.
- Mark topics covered by each source.
- Draft an editor concept glossary with source URLs.
- Draft a reference chunking plan for RAG ingestion.
- Flag outdated or version-sensitive sources.

Do not:
- Treat AI summaries as primary sources.
- Produce final SC2 semantic rules.
- Claim a source is official unless the source itself supports that.
- Copy large copyrighted passages into the repository.
- Edit SC2 assets.

Output paths:
- artifacts/sc2-modops/sprint-001/worker-rkb/source-trust-map.md
- artifacts/sc2-modops/sprint-001/worker-rkb/reference-sources.jsonl
- artifacts/sc2-modops/sprint-001/worker-rkb/editor-glossary-draft.md
- artifacts/sc2-modops/sprint-001/worker-rkb/reference-chunking-plan.md

JSONL fields for reference-sources:
source_url, source_title, source_tier, retrieved_date, topics, summary, key_terms, version_notes, confidence, outdated_risk, usable_for, not_usable_for.

Final response:
List changed/created files, the top trusted source candidates, and the highest outdated-risk sources.
```

## Worker A Prompt: Source Inventory And Module Map

```text
<COMMON WORKER HEADER>

Task ID: S001-A
Owner: Worker A
Model tier: cheap

Goal:
Create a draft source inventory and module map for the SC2 repository.

Inputs:
- Repository root.
- Top-level SC2Mod and SC2Map folders.
- Existing docs and scripts folders.

Do:
- List candidate SC2 source assets.
- Classify paths by type: mod, map, xml, galaxy, localization, document, script, artifact, unknown.
- Identify large files and generated-looking files.
- Record uncertainty.

Do not:
- Edit any source files.
- Infer gameplay behavior.
- Classify a folder as generated unless evidence is stated.

Output paths:
- artifacts/sc2-modops/sprint-001/worker-a/source-inventory-draft.jsonl
- artifacts/sc2-modops/sprint-001/worker-a/source-inventory-summary.md

JSONL fields:
path, asset_type, module_guess, reason, confidence.

Final response:
List changed/created files and the top 5 uncertainties.
```

## Worker B Prompt: Script Catalog

```text
<COMMON WORKER HEADER>

Task ID: S001-B
Owner: Worker B
Model tier: cheap

Goal:
Create a draft catalog of existing scripts and their likely purpose.

Inputs:
- scripts/
- Documents that mention launchers, validators, export scripts, repair scripts, or web launchers.

Do:
- Summarize each script's visible purpose.
- Identify likely inputs and outputs.
- Classify each script as launcher, validator, sync, repair, export, web-ui, or unknown.
- Flag risky scripts that copy, delete, restore, launch, or patch assets.

Do not:
- Run scripts.
- Modify scripts.
- Claim behavior beyond visible code or documentation.

Output paths:
- artifacts/sc2-modops/sprint-001/worker-b/script-catalog-draft.jsonl
- artifacts/sc2-modops/sprint-001/worker-b/script-catalog-summary.md

JSONL fields:
path, category, purpose, inputs, outputs, risk_notes, confidence.

Final response:
List changed/created files, script counts by category, and unknown/high-risk scripts.
```

## Worker C Prompt: Validator Coverage Matrix

```text
<COMMON WORKER HEADER>

Task ID: S001-C
Owner: Worker C
Model tier: cheap

Goal:
Create a draft matrix showing which SC2Mod risk areas currently have validators and where gaps remain.

Inputs:
- Existing validator scripts.
- Historical bug reports if available.
- docs/sc2-modops/cheap-model-workqueue.md

Do:
- Map validator scripts to risk areas.
- Identify risk areas that appear uncovered.
- Suggest future validators as drafts.

Do not:
- Author final blocking rules.
- Claim coverage without a script path.
- Edit validators.

Output path:
- artifacts/sc2-modops/sprint-001/worker-c/validation-coverage-draft.md

Required columns:
Risk area | Existing script | Covered behavior | Known gap | Suggested future validator | Confidence

Final response:
List changed/created files and the highest-priority uncovered risk areas.
```

## Worker D Prompt: Historical Fix Knowledge Cards

```text
<COMMON WORKER HEADER>

Task ID: S001-D
Owner: Worker D
Model tier: cheap

Goal:
Turn confirmed historical SC2 fixes into draft knowledge cards.

Inputs:
- Project docs.
- Historical progress notes.
- Existing AI output documents if present.
- Reviewed Wave 1 inventory outputs if available.

Do:
- Create one card per confirmed fix pattern.
- Extract symptom, evidence, root cause, fix, validation, and future guardrail.
- Separate evidence from inference.

Do not:
- Turn uncertain notes into confirmed facts.
- Rewrite original reports.
- Create final platform rules.

Output path:
- artifacts/sc2-modops/sprint-001/worker-d/cards/<topic>.md

Card template:
Title, Source paths, Symptom, Evidence, Root cause, Fix, Validation, Future guardrail, Confidence, Open questions.

Final response:
List changed/created files and the cards with low confidence.
```

## Worker E Prompt: XML Candidate Reference Fields

```text
<COMMON WORKER HEADER>

Task ID: S001-E
Owner: Worker E
Model tier: cheap

Goal:
Extract candidate XML fields that may reference other Catalog entries.

Inputs:
- Representative GameData/*.xml files.
- Reviewed source inventory if available.

Do:
- Identify fields that look like references to other Catalog entries.
- Group by source node type and candidate target type.
- Provide examples.

Do not:
- Define final graph semantics.
- Infer target type without examples.
- Modify XML.

Output paths:
- artifacts/sc2-modops/sprint-001/worker-e/candidate-reference-fields.jsonl
- artifacts/sc2-modops/sprint-001/worker-e/xml-reference-field-candidates.md

JSONL fields:
source_file, source_node_type, field_path, example_value, candidate_target_type, reason, confidence.

Final response:
List changed/created files and the fields that need strong-model review.
```

## Worker F Prompt: Skill Checklist Drafts

```text
<COMMON WORKER HEADER>

Task ID: S001-F
Owner: Worker F
Model tier: cheap

Goal:
Draft checklists for the first SC2Mod AI skills.

Inputs:
- docs/sc2-modops/project-charter.md
- docs/sc2-modops/task-protocol.md
- Reviewed Wave 1 and Wave 2 outputs if available.

Do:
- Draft checklists for sc2-catalog-closure, sc2-commander-audit, sc2-map-dependency, sc2-galaxy-runtime, and sc2-validator-author.
- Include inputs, steps, outputs, forbidden actions, and validation.
- Mark proposed semantic rules as proposed.

Do not:
- Create final SKILL.md files.
- Add semantic rules without source citations or proposed markers.

Output paths:
- artifacts/sc2-modops/sprint-001/worker-f/sc2-catalog-closure-checklist.md
- artifacts/sc2-modops/sprint-001/worker-f/sc2-commander-audit-checklist.md
- artifacts/sc2-modops/sprint-001/worker-f/sc2-map-dependency-checklist.md
- artifacts/sc2-modops/sprint-001/worker-f/sc2-galaxy-runtime-checklist.md
- artifacts/sc2-modops/sprint-001/worker-f/sc2-validator-author-checklist.md

Final response:
List changed/created files and any rules that need strong-model approval.
```

## Worker G Prompt: Eval Seed Cases

```text
<COMMON WORKER HEADER>

Task ID: S001-G
Owner: Worker G
Model tier: cheap

Goal:
Draft seed eval cases for task routing and Catalog closure quality.

Inputs:
- Reviewed knowledge cards.
- Validator matrix.
- docs/sc2-modops/task-protocol.md

Do:
- Generate eval cases with a question, relevant evidence, correct conclusion, common wrong conclusion, and expected gate.
- Cite evidence paths.
- Use plausible SC2Mod failure modes.

Do not:
- Invent incidents.
- Mark eval cases as final.
- Create artificial wrong conclusions that no real model would make.

Output paths:
- artifacts/sc2-modops/sprint-001/worker-g/sc2-task-routing.jsonl
- artifacts/sc2-modops/sprint-001/worker-g/catalog-closure-cases.jsonl

JSONL fields:
case_id, question, evidence_paths, correct_conclusion, common_wrong_conclusion, expected_gate, confidence.

Final response:
List changed/created files and the cases with low confidence.
```
