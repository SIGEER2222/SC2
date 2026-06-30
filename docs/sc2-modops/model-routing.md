# SC2Mod AI Model Routing

## Goal

Route every task to the cheapest model that can safely perform it, while reserving stronger models for reasoning-heavy or high-risk decisions.

## Task Scoring

Each task receives four scores from 1 to 5.

| Score | Meaning |
|---|---|
| `TokenVolume` | Amount of text or files to read, summarize, or transform. |
| `ReasoningRisk` | Depth of SC2 semantic judgment required. |
| `BlastRadius` | Damage caused by a wrong answer or patch. |
| `Verifiability` | How easily tools or scripts can verify the result. Higher means easier to verify. |

## Routing Rules

| Condition | Route |
|---|---|
| High token volume, low reasoning, high verifiability | Cheap or free model |
| High token volume, high reasoning | Cheap model compresses, strong model decides |
| Low token volume, high reasoning | Strong model directly |
| High blast radius, low verifiability | Strong model plus human confirmation point |
| Fully deterministic | Script or tool, not AI |

## Model Tiers

### Tier 0: Deterministic Tools

Use for:

- XML parsing.
- Galaxy function indexing.
- File manifests and hashes.
- Catalog graph extraction.
- Validator execution.
- Diff statistics.
- Package generation.

AI may write or review these tools, but should not replace their execution with guesses.

### Tier 1: Cheap Or Free Worker Models

Use for:

- File inventory summaries.
- Chunking and metadata drafts.
- Knowledge card drafts.
- Historical report classification.
- XML field candidate labeling.
- Validator requirement drafts.
- Skill checklist drafts.
- Changelog and report drafts.
- Low-risk one-to-one transform proposals.

Allowed outputs:

- Draft Markdown.
- JSONL candidate records.
- Candidate checklists.
- Patch proposals in a temporary area.
- Extracted labels and summaries.

Forbidden outputs:

- Final SC2 semantic conclusions.
- Mainline patch application.
- Direct DocumentHeader changes.
- Catalog node deletion decisions.
- "Fix complete" claims.

### Tier 2: Standard Implementation Models

Use for:

- Small parser or script implementation under a strong-model design.
- Draft validators with clear acceptance criteria.
- Template-based skill generation.
- Low-risk refactors inside platform tooling.

These outputs require review when they affect schemas, validators, or SC2 assets.

### Tier 3: Strong Reasoning Models

Use for:

- Project architecture.
- Catalog graph schema.
- XML reference semantics.
- Inheritance and override interpretation.
- Multi-mod dependency reasoning.
- Galaxy runtime entry-point reasoning.
- Validator blocking-rule design.
- Review of large worker-generated outputs.
- Final task conclusions.

## Permission Matrix

| Action | Cheap Model | Standard Model | Strong Model | Tool |
|---|---:|---:|---:|---:|
| Summarize docs | Yes | Yes | Yes | Optional |
| Generate JSONL candidates | Yes | Yes | Yes | Yes |
| Define schema | Draft only | Draft only | Yes | No |
| Implement parser | No | Yes | Review | Yes |
| Run validator | No | No | No | Yes |
| Author validator rule | Draft only | Draft | Yes | Execute |
| Modify SC2 assets | Draft only | Low-risk draft | Approve | Apply |
| Modify DocumentHeader | No | No | Approve only | Apply |
| Final fix conclusion | No | No | Yes | Evidence |

## Review Triggers

Strong-model review is required when:

- A patch changes `DocumentHeader`, `DocumentInfo`, dependency order, or package layout.
- A patch deletes or disables Catalog nodes.
- A patch changes shared units, shared abilities, or runtime allowlists.
- A validator introduces a blocking rule.
- RAG content contradicts structured graph evidence.
- A cheap model output contains uncertain SC2 semantic claims.

## Cost Control

- Use cheap models to compress large context before strong-model review.
- Store summaries and extracted records so repeated scans are not paid twice.
- Cache tool outputs by file hash.
- Prefer schemas and validators over repeated natural-language reasoning.
- Promote a cheap-model task only after repeated manual or strong-model approval shows stable quality.

## Future Fine-Tuning Policy

Fine-tuning is not part of the first phase. Consider it only after enough validated examples exist.

Good fine-tuning candidates:

- XML field classification.
- Knowledge card formatting.
- Log summarization format.
- Task routing classification.
- Validator template generation.

Poor fine-tuning candidates:

- SC2 mechanism closure judgment.
- Multi-mod dependency decisions.
- High-risk patch approval.
- Final bug-fix conclusions.
