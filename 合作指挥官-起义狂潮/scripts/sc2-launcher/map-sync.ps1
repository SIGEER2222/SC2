<#
.SYNOPSIS
  Map synchronization module for SC2 commander launchers.
.DESCRIPTION
  Handles:
  - Syncing map from workspace to SC2 live directory
  - Cleaning/injecting galaxy files to map Base.SC2Data
  DocumentHeader/DocumentInfo dependency rewrite lives in document-dependencies.ps1,
  which is dot-sourced below. Set-MapDependencies is re-exported from there.
  Separated from mod logic to keep map and mod concerns independent.
#>

# === Document dependency operations (read/write/roundtrip/compare) ===
. (Join-Path $PSScriptRoot "document-dependencies.ps1")

# === Map sync ===
function Sync-MapToLive {
    <#
    .SYNOPSIS
      Sync map directory from workspace to SC2 live using robocopy mirror.
    #>
    param(
        [Parameter(Mandatory=$true)][string]$MapName,
        [Parameter(Mandatory=$true)][string]$ProjRoot,
        [Parameter(Mandatory=$true)][string]$Sc2Root
    )
    $src = Join-Path $ProjRoot "Maps\$MapName"
    $dst = Join-Path $Sc2Root "Maps\$MapName"
    if (Test-Path $dst) { [System.IO.Directory]::Delete($dst, $true) }
    [System.IO.Directory]::CreateDirectory($dst) | Out-Null
    robocopy $src $dst /MIR /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
    Write-Host "SYNC map: $MapName"
}

# === Galaxy file management ===
function Clean-MapRuntimeLibraries {
    <#
    .SYNOPSIS
      Remove runtime-injected Lib*.galaxy files from map Base.SC2Data.
      Called before injection to clear stale files from previous runs.
    .PARAMETER PreserveNames
      Hashtable of galaxy file names (key) to preserve (map-owned source files).
    #>
    param(
        [Parameter(Mandatory=$true)][string]$MapPath,
        [hashtable]$PreserveNames = @{}
    )
    $mapBaseData = Join-Path $MapPath "Base.SC2Data"
    if (-not (Test-Path $mapBaseData)) { return }

    $galaxyFiles = Get-ChildItem $mapBaseData -File -Filter "Lib*.galaxy" -ErrorAction SilentlyContinue
    $count = 0
    foreach ($gf in $galaxyFiles) {
        if ($PreserveNames.ContainsKey($gf.Name)) {
            continue
        }
        [System.IO.File]::Delete($gf.FullName)
        $count++
    }
    if ($count -gt 0) {
        $preserveCount = $PreserveNames.Count
        Write-Host "CLEAN: removed $count stale runtime galaxy files (preserved $preserveCount map-owned galaxy files)"
    }
}

function Sync-MapRuntimeLibraries {
    <#
    .SYNOPSIS
      Inject galaxy files from workspace mod sources to map Base.SC2Data.
      Only injects from specified glob patterns (e.g. CommanderUnits_*, Alenger*Adapter).
      Does NOT inject CoreRuntime galaxy files — those load via mod dependency chain.
    #>
    param(
        [Parameter(Mandatory=$true)][string]$MapPath,
        [Parameter(Mandatory=$true)][string]$ProjRoot,
        [Parameter(Mandatory=$true)][string[]]$SourcePatterns,
        [string]$SourceRoot = "Mods\7vs1"
    )
    $mapBaseData = Join-Path $MapPath "Base.SC2Data"
    if (-not (Test-Path $mapBaseData)) {
        [System.IO.Directory]::CreateDirectory($mapBaseData) | Out-Null
    }

    $workspaceSourceRoot = Join-Path $ProjRoot $SourceRoot
    $count = 0

    foreach ($pattern in $SourcePatterns) {
        $modDirs = Get-ChildItem $workspaceSourceRoot -Directory -Filter $pattern -ErrorAction SilentlyContinue
        foreach ($modDir in $modDirs) {
            $modBase = Join-Path $modDir.FullName "Base.SC2Data"
            if (-not (Test-Path $modBase)) { continue }
            $galaxyFiles = Get-ChildItem $modBase -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
            foreach ($gf in $galaxyFiles) {
                $dst = Join-Path $mapBaseData $gf.Name
                [System.IO.File]::Copy($gf.FullName, $dst, $true)
                $count++
            }
        }
    }

    Write-Host "SYNC galaxy libs: $count files injected from workspace"
}

function Sync-MapRuntimeLibrariesFromManifest {
    <#
    .SYNOPSIS
      Inject galaxy files from GalaxyManifest entries to map Base.SC2Data.
      Priority 2: replaces directory-scan injection with explicit manifest-driven injection.
      Only injects files declared in the manifest — undeclared files are NOT injected.
    .PARAMETER MapPath
      Target map directory path (live SC2 Maps dir).
    .PARAMETER ProjRoot
      Workspace root for resolving sourceMod paths.
    .PARAMETER GalaxyInjectionEntries
      Array of entries with .file (e.g. "Base.SC2Data/LibX.galaxy") and .source
      (e.g. "Mods/7vs1/CommanderUnits_Raynor.SC2Mod\Base.SC2Data\LibX.galaxy").
      Typically from Read-CompositionPlan output.
    #>
    param(
        [Parameter(Mandatory=$true)][string]$MapPath,
        [Parameter(Mandatory=$true)][string]$ProjRoot,
        [Parameter(Mandatory=$true)]$GalaxyInjectionEntries
    )
    $mapBaseData = Join-Path $MapPath "Base.SC2Data"
    if (-not (Test-Path $mapBaseData)) {
        [System.IO.Directory]::CreateDirectory($mapBaseData) | Out-Null
    }

    $count = 0
    $missing = 0
    foreach ($entry in $GalaxyInjectionEntries) {
        # entry.source is like "Mods/7vs1/CommanderUnits_Raynor.SC2Mod\Base.SC2Data\LibX.galaxy"
        # entry.file is like "Base.SC2Data/LibX.galaxy"
        $srcPath = if ($entry.source) {
            Join-Path $ProjRoot ($entry.source -replace '/', '\')
        } else {
            # source not resolved from manifest — skip with warning
            Write-Host "WARN: no source for $($entry.file) (not in GalaxyManifest)"
            $missing++
            continue
        }

        if (-not (Test-Path -LiteralPath $srcPath)) {
            Write-Host "WARN: source not found: $srcPath ($($entry.file))"
            $missing++
            continue
        }

        # Destination filename: just the galaxy filename (flat in Base.SC2Data)
        $fileName = [System.IO.Path]::GetFileName($entry.file)
        $dst = Join-Path $mapBaseData $fileName
        [System.IO.File]::Copy($srcPath, $dst, $true)
        $count++
    }

    Write-Host "SYNC galaxy libs (manifest): $count files injected, $missing missing"
}
