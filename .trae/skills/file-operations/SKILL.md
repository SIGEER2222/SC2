---
name: "file-operations"
description: "Safely create, edit, move, rename, or delete repository files using the editor's native file-operation capability instead of shell-based content writes. Invoke before every task that mutates files, including code, scripts, configuration, documentation, SC2 map directories, and generated manifests."
---

# Safe File Operations

Invoke this skill before the first filesystem mutation in every edit task.

## Mandatory Write Path

- Use the editor's native file create, patch, edit, move, rename, and delete operations.
- For manual content changes, use the native patch/edit operation.
- Read the current file before patching it, and preserve unrelated user changes.
- Keep each mutation scoped to the files required by the current task.
- Re-read or diff the edited files after the mutation.

## Forbidden Shell Writes

Do not create or modify file contents with shell commands, including:

- PowerShell `Out-File`, `Set-Content`, `Add-Content`, `Export-*`, or redirection operators.
- Shell `>`, `>>`, `tee`, `echo` pipelines, or here-string pipelines that write files.
- Inline Python, Node.js, PowerShell, or batch snippets whose purpose is to write repository files.
- Temporary generated scripts such as `$scriptPath` followed by `Out-File` or `Set-Content`.

Shell commands remain allowed for read-only inspection, validation, tests, and running an existing
repository tool whose documented purpose is deterministic artifact generation.

## Generated Artifacts

When an existing tool generates files:

1. Invoke the relevant domain skill first.
2. Run the existing checked-in generator instead of recreating its logic in the shell.
3. Verify the exact generated paths and diff.
4. Do not replace a native file edit with an ad hoc temporary script.

## Completion Gate

Do not claim completion until:

- No forbidden shell-write command was used for repository content.
- The intended files were changed and unrelated files were preserved.
- The final diff and validation results were reviewed.
