<#
.SYNOPSIS
  Clean up TRAE chat session local files (inactive beyond specified days).

.DESCRIPTION
  TRAE AI Agent sessions leave three types of local residue:
    1. Sandbox config: Trae Solo CN\ModularData\ai-agent\sandbox\<sandboxId>.json + <sandboxId>-hooks.json
    2. Session attachments: .trae-cn\attachments\<sessionId>\
    3. Session work dir: .trae-cn\work\<sessionId>\ (exists at runtime)

  This script scans the sandbox directory, checks LastWriteTime for session activity,
  and deletes residue files for sessions inactive beyond the specified days.

  Note: database.db session content is managed by TRAE runtime and locked by process.
  This script does NOT touch database.db. To clean DB records, close TRAE first.

.PARAMETER Days
  Inactivity threshold in days, default 1.

.PARAMETER DryRun
  List files to delete without actually deleting.

.EXAMPLE
  .\cleanup-trae-sessions.ps1 -DryRun
  Preview what would be cleaned (no files deleted)

.EXAMPLE
  .\cleanup-trae-sessions.ps1 -Days 1
  Clean sessions inactive for more than 1 day

.EXAMPLE
  .\cleanup-trae-sessions.ps1 -Days 7
  Clean sessions inactive for more than 7 days
#>

param(
    [int]$Days = 1,
    [switch]$DryRun,
    [string]$SandboxDir = "",
    [string]$TraeCnDir = ""
)

# ============================================================
# Path detection
# ============================================================

$homeDir = $env:USERPROFILE

if (-not $SandboxDir) {
    $SandboxDir = Join-Path $homeDir "AppData\Roaming\Trae Solo CN\ModularData\ai-agent\sandbox"
}
if (-not $TraeCnDir) {
    $TraeCnDir = Join-Path $homeDir ".trae-cn"
}

$AttachmentsDir = Join-Path $TraeCnDir "attachments"
$WorkDirBase = Join-Path $TraeCnDir "work"

# ============================================================
# Validate paths
# ============================================================

if (-not (Test-Path $SandboxDir)) {
    Write-Host "Sandbox dir not found: $SandboxDir" -ForegroundColor Red
    Write-Host "Ensure TRAE Solo CN is installed, or specify -SandboxDir" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "=== TRAE Session Cleanup ===" -ForegroundColor Cyan
Write-Host "Sandbox dir:  $SandboxDir"
Write-Host ".trae-cn dir: $TraeCnDir"
Write-Host "Threshold:    $Days day(s)"
if ($DryRun) { Write-Host "Mode:         DryRun (preview only)" -ForegroundColor Yellow }
Write-Host ""

# ============================================================
# Scan sandbox JSON files
# ============================================================

# Match <id>.json only, exclude <id>-hooks.json
$sessionFiles = Get-ChildItem $SandboxDir -Filter "*.json" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch "-hooks\.json$" } |
    Sort-Object LastWriteTime

if ($sessionFiles.Count -eq 0) {
    Write-Host "No session files found." -ForegroundColor Yellow
    exit 0
}

$threshold = (Get-Date).AddDays(-$Days)
$toDelete = @()
$kept = @()

foreach ($f in $sessionFiles) {
    $isActive = $f.LastWriteTime -gt $threshold
    $sandboxId = $f.BaseName

    # Parse JSON to extract sessionId from file_inherit_user paths
    $sessionId = $null
    try {
        $config = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($perm in $config.permission) {
            if ($perm.file_inherit_user -match "attachments[\\/](.+)$") {
                $sessionId = $matches[1]
                break
            }
        }
    } catch {
        $sessionId = $sandboxId
    }

    $entry = @{
        SandboxId   = $sandboxId
        SessionId   = $sessionId
        LastActive  = $f.LastWriteTime
        SandboxFile = $f.FullName
        HooksFile   = Join-Path $SandboxDir "$sandboxId-hooks.json"
        Attachments = if ($sessionId) { Join-Path $AttachmentsDir $sessionId } else { $null }
        Work        = if ($sessionId) { Join-Path $WorkDirBase $sessionId } else { $null }
    }

    if ($isActive) {
        $kept += $entry
    } else {
        $toDelete += $entry
    }
}

# ============================================================
# Report
# ============================================================

Write-Host "--- Kept sessions (active, $($kept.Count)) ---" -ForegroundColor Green
foreach ($e in $kept) {
    $age = [math]::Round(((Get-Date) - $e.LastActive).TotalHours, 1)
    Write-Host ("  [KEEP] {0}  last: {1}  ({2}h ago)" -f $e.SandboxId, $e.LastActive.ToString("yyyy-MM-dd HH:mm"), $age)
}

Write-Host ""
Write-Host "--- Sessions to clean (inactive > $Days day(s), $($toDelete.Count)) ---" -ForegroundColor Yellow
foreach ($e in $toDelete) {
    $age = [math]::Round(((Get-Date) - $e.LastActive).TotalDays, 1)
    Write-Host ("  [CLEAN] {0}  last: {1}  ({2}d ago)" -f $e.SandboxId, $e.LastActive.ToString("yyyy-MM-dd HH:mm"), $age)
    Write-Host ("           sessionId: {0}" -f $e.SessionId) -ForegroundColor DarkGray
}

if ($toDelete.Count -eq 0) {
    Write-Host ""
    Write-Host "No sessions to clean." -ForegroundColor Green
    exit 0
}

# ============================================================
# Execute deletion
# ============================================================

if ($DryRun) {
    Write-Host ""
    Write-Host "[DryRun] No files deleted. Remove -DryRun to execute." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Deleting..." -ForegroundColor Cyan

$deletedCount = 0
$deletedSize = 0
$failedCount = 0

foreach ($e in $toDelete) {
    $items = @(
        @{ Path = $e.SandboxFile; Type = "file"; Label = "sandbox" }
        @{ Path = $e.HooksFile;   Type = "file"; Label = "hooks" }
    )
    if ($e.Attachments) { $items += @{ Path = $e.Attachments; Type = "dir"; Label = "attachments" } }
    if ($e.Work)        { $items += @{ Path = $e.Work;        Type = "dir"; Label = "work" } }

    foreach ($item in $items) {
        $p = $item.Path
        if (-not (Test-Path $p)) { continue }

        try {
            $size = 0
            if ($item.Type -eq "file") {
                $size = (Get-Item $p).Length
                Remove-Item -Path $p -Force -ErrorAction Stop
            } else {
                $size = (Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue |
                         Measure-Object -Property Length -Sum).Sum
                Remove-Item -Path $p -Force -Recurse -ErrorAction Stop
            }
            $deletedSize += $size
            $deletedCount++
            Write-Host ("  [OK]   {0,-12} {1}" -f $item.Label, $p) -ForegroundColor Green
        } catch {
            $failedCount++
            Write-Host ("  [FAIL] {0,-12} {1}: {2}" -f $item.Label, $p, $_.Exception.Message) -ForegroundColor Red
        }
    }
}

# ============================================================
# Summary
# ============================================================

Write-Host ""
Write-Host "=== Cleanup Complete ===" -ForegroundColor Cyan
Write-Host "Deleted items:  $deletedCount"
Write-Host "Freed space:    $([math]::Round($deletedSize / 1MB, 2)) MB"
if ($failedCount -gt 0) {
    Write-Host "Failed:         $failedCount" -ForegroundColor Red
}
Write-Host ""
Write-Host "Note: database.db session records were NOT cleaned (locked by TRAE process)."
Write-Host "      To clean DB records, close TRAE first and handle manually."
Write-Host ""
