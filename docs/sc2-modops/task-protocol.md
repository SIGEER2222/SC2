# SC2Mod AI Task Protocol

## Purpose

Define a repeatable task format so multiple AI agents can work on SC2Mod development without losing evidence, ownership, or review state.

## Task Record

Every nontrivial task should have a task record with this shape:

```json
{
  "task_id": "sc2mod-YYYYMMDD-001",
  "title": "Short task title",
  "status": "draft|assigned|in_progress|review|validated|blocked|done",
  "owner": "planner|collector|analyst|implementer|reviewer|validator|archivist",
  "model_tier": "tool|cheap|standard|strong",
  "risk": {
    "token_volume": 1,
    "reasoning_risk": 1,
    "blast_radius": 1,
    "verifiability": 1
  },
  "inputs": [],
  "outputs": [],
  "evidence": [],
  "forbidden_actions": [],
  "validation": [],
  "handoff_notes": ""
}
```

## Required Sections

### Objective

State what should be accomplished in one or two sentences.

### Scope

List included paths, modules, maps, or documents.

### Non-Scope

List what must not be touched. This is required for tasks involving SC2 assets.

### Evidence Inputs

List the source files, graph queries, RAG records, validator output, or logs used by the agent.

### Expected Output

Prefer structured output:

- Markdown report.
- JSONL records.
- Candidate patch.
- Validator draft.
- Knowledge card draft.
- Final reviewed patch.

### Validation

Every task must say how its output will be checked.

Examples:

- JSON schema validation.
- Strong-model review.
- Script execution.
- Diff inspection.
- Catalog graph query.
- In-game or editor round-trip test.

## Agent Roles

### Planner

Strong model. Breaks work into tasks, assigns model tiers, sets forbidden actions, and defines acceptance criteria.

### Collector

Cheap model. Gathers files, summaries, metadata, and candidate knowledge. Does not make final semantic claims.

### Indexer

Tool. Runs deterministic parsers and graph builders.

### Analyst

Strong model. Interprets structured facts, RAG results, and SC2 semantics.

### Implementer

Standard or strong model depending on risk. Produces patches or scripts under explicit scope.

### Reviewer

Strong model. Reviews diff, evidence, SC2 semantic closure, and validation sufficiency.

### Validator

Tool. Executes checks. Does not infer success beyond configured rules.

### Archivist

Cheap model. Turns reviewed conclusions into reports, knowledge cards, and future task references.

## Handoff Format

Each handoff should include:

```text
Task:
Owner:
Status:
Inputs used:
Outputs produced:
Evidence:
Uncertainties:
Forbidden actions respected:
Next required action:
```

## Completion Rules

A task may be marked done only when:

- Required outputs exist.
- Validation has passed or known gaps are explicitly documented.
- High-risk decisions have strong-model review.
- Any reusable lesson has been converted into a knowledge card, validator request, or skill rule.

## Blocked Rules

Mark blocked only when:

- Required source files are missing.
- Required tool execution fails repeatedly.
- The task needs human/editor/in-game verification that cannot be simulated.
- The requested change would violate permission boundaries.

## SC2-Specific Guardrails

- Do not infer closure from command-card visibility alone.
- Do not treat shared Catalog references as commander-owned behavior without evidence.
- Do not modify dependency metadata without impact notes.
- Do not delete Catalog nodes based only on name similarity.
- Do not claim runtime behavior without checking Galaxy entry paths or live validation where needed.
- Separate official evidence, project-specific adaptation, and AI inference in all reports.
