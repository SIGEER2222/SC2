<#
.SYNOPSIS
  Map synchronization and dependency management module for SC2 commander launchers.
.DESCRIPTION
  Handles:
  - Syncing map from workspace to SC2 live directory
  - Cleaning/injecting galaxy files to map Base.SC2Data
  - Rewriting DocumentHeader/DocumentInfo dependencies
  Separated from mod logic to keep map and mod concerns independent.
#>

# === DocumentHeader binary dependency rewrite ===
function Test-ByteSequenceAt {
    param([byte[]]$Bytes, [int]$Offset, [byte[]]$Needle)
    if ($Offset + $Needle.Length -gt $Bytes.Length) { return $false }
    for ($i = 0; $i -lt $Needle.Length; $i++) {
        if ($Bytes[$Offset + $i] -ne $Needle[$i]) { return $false }
    }
    return $true
}

function Find-DocumentHeaderDependencyStart {
    param([byte[]]$Bytes)
    $markers = @(
        [System.Text.Encoding]::UTF8.GetBytes("file:"),
        [System.Text.Encoding]::UTF8.GetBytes("bnet:")
    )
    for ($offset = 4; $offset -lt $Bytes.Length; $offset++) {
        foreach ($marker in $markers) {
            if (-not (Test-ByteSequenceAt -Bytes $Bytes -Offset $offset -Needle $marker)) { continue }
            $count = [System.BitConverter]::ToUInt32($Bytes, $offset - 4)
            if (($count -gt 0) -and ($count -lt 128)) { return $offset }
        }
    }
    throw "DocumentHeader dependency table not found."
}

function Get-DocumentHeaderDependencyEndOffset {
    param([byte[]]$Bytes, [int]$Start, [uint32]$Count)
    $offset = $Start
    for ($index = 0; $index -lt $Count; $index++) {
        while (($offset -lt $Bytes.Length) -and ($Bytes[$offset] -ne 0)) { $offset++ }
        if ($offset -ge $Bytes.Length) { throw "DocumentHeader dependency string is not null-terminated." }
        $offset++
    }
    return $offset
}

function Set-DocumentHeaderDependencies {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string[]]$Dependencies
    )
    if (-not (Test-Path -LiteralPath $Path)) { throw "DocumentHeader not found: $Path" }
    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($Path)
    $dependencyStart = Find-DocumentHeaderDependencyStart -Bytes $bytes
    $countOffset = $dependencyStart - 4
    $currentCount = [System.BitConverter]::ToUInt32($bytes, $countOffset)
    $dependencyEnd = Get-DocumentHeaderDependencyEndOffset -Bytes $bytes -Start $dependencyStart -Count $currentCount
    $dependencyBytes = [System.Text.Encoding]::UTF8.GetBytes((($Dependencies -join "`0") + "`0"))
    $countBytes = [System.BitConverter]::GetBytes([uint32]$Dependencies.Count)
    $stream = New-Object System.IO.MemoryStream
    $stream.Write($bytes, 0, $countOffset)
    $stream.Write($countBytes, 0, $countBytes.Length)
    $stream.Write($dependencyBytes, 0, $dependencyBytes.Length)
    $stream.Write($bytes, $dependencyEnd, $bytes.Length - $dependencyEnd)
    [System.IO.File]::WriteAllBytes($Path, $stream.ToArray())
}

function Set-DocumentInfoDependencies {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string[]]$Dependencies
    )
    $xml = "<?xml version='1.0' encoding='utf-8'?>`n<DocInfo>`n    <Dependencies>`n"
    foreach ($dep in $Dependencies) {
        $xml += "        <Value>$dep</Value>`n"
    }
    $xml += "    </Dependencies>`n"
    # Preserve Preload section if it exists in original
    $origContent = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    if ($origContent -match '(?s)<Preload>.*?</Preload>') {
        $preloadSection = $matches[0]
        $xml += "    $preloadSection`n"
    }
    $xml += "</DocInfo>"
    [System.IO.File]::WriteAllText($Path, $xml, [System.Text.Encoding]::UTF8)
}

function Set-MapDependencies {
    param(
        [Parameter(Mandatory=$true)][string]$MapPath,
        [Parameter(Mandatory=$true)][string[]]$Dependencies
    )
    Set-DocumentInfoDependencies -Path (Join-Path $MapPath "DocumentInfo") -Dependencies $Dependencies
    Set-DocumentHeaderDependencies -Path (Join-Path $MapPath "DocumentHeader") -Dependencies $Dependencies
    Write-Host "SET DEPS: $($Dependencies.Count) dependencies written to map"
}

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
