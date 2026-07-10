---
name: file-operations
description: Safely create, edit, move, rename, or delete repository files using native file-operation tools instead of shell-based content writes. Invoke before every task that mutates files, including code, scripts, configuration, documentation, SC2 map directories, and generated manifests.
---

# Safe File Operations

Invoke this skill before the first filesystem mutation in every edit task.

## Mandatory Write Path

- Use native file create, patch, edit, move, rename, and delete operations.
- Use `apply_patch` for manual content changes.
- Read the current file before patching it and preserve unrelated user changes.
- Keep mutations scoped to the files required by the current task.
- Re-read or diff edited files after each logical change.

## Forbidden Shell Writes

Do not create or modify repository contents with:

- PowerShell `Out-File`, `Set-Content`, `Add-Content`, `Export-*`, or redirection.
- Shell `>`, `>>`, `tee`, `echo` pipelines, or here-string write pipelines.
- Inline Python, Node.js, PowerShell, or batch snippets whose purpose is writing files.
- Temporary generated scripts such as `$scriptPath` filled by `Out-File` or `Set-Content`.

Shell commands remain allowed for read-only inspection, validation, tests, and checked-in generators
whose documented purpose is deterministic artifact generation.

## Generated Artifacts

1. Load the relevant domain skill.
2. Run the checked-in generator instead of recreating its logic in the shell.
3. Verify the exact generated paths and diff.
4. Do not replace native file editing with an ad hoc temporary script.

## Completion Gate

- No forbidden shell-write command was used for repository content.
- Intended files changed and unrelated files remained intact.
- Final diff and validation results were reviewed.
