---
name: "safe-rm"
description: "Safely removes files and directories using wrapper scripts. Invoke when user wants to delete files/directories instead of using raw Remove-Item commands."
---

# Safe File/Directory Removal

This skill provides safe file and directory deletion by using wrapper scripts that avoid direct dangerous PowerShell commands.

## Usage

When user wants to delete files or directories, use the appropriate wrapper script:

### Delete a single file
```powershell
powershell -File scripts/trae-rm.ps1 "path/to/file.txt"
```

### Delete a directory and all its contents
```powershell
powershell -File scripts/trae-rmdir.ps1 "path/to/directory"
```

## Wrapper Scripts Location

- `scripts/trae-rm.ps1` - Deletes a single file with confirmation feedback
- `scripts/trae-rmdir.ps1` - Recursively deletes a directory with confirmation feedback

## When to Use

- User explicitly asks to delete files or directories
- User asks to remove something with `Remove-Item` or `Remove-Item -Recurse`
- User wants to clean up temporary files or directories

## Safety Notes

- These wrapper scripts use `-ErrorAction SilentlyContinue` to suppress errors
- They verify deletion with `Test-Path` after execution
- They output success/failure messages for clarity
