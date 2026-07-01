<#
.SYNOPSIS
Launch 7vs1 coop test with XMAbathurReborn.SC2Mod loaded.

.DESCRIPTION
This script wraps launch-7vs1-coop-test.ps1:
1. Copies XM\XMAbathurReborn.SC2Mod to SC2 Mods\7vs1\
2. Removes non-existent dependencies from XMAbathurReborn (SwarmStory, swarmstoryutil)
3. Adds XMAbathurReborn as a dependency of CoopZeroPop (transitive load)
4. Launches the game

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-abathur-reborn.ps1

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-abathur-reborn.ps1 -SkipLaunch
#>
[CmdletBinding()]
param(
    [string[]]$Commanders = @("ZergAbathurReborn"),
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$LiveMapName = "7vs1CoopTest.SC2Map",
    [string]$Preset = "Default",
    [string]$TestSpawnPreset = "",
    [switch]$SkipLaunch,
    [switch]$ForceStopSc2BeforeInstall
)

$ErrorActionPreference = "Stop"

# workspaceRoot = parent of scripts/
if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$workspaceRoot = Split-Path -Parent $PSScriptRoot
Write-Host "PSScriptRoot=$PSScriptRoot"
Write-Host "workspaceRoot=$workspaceRoot"

# ============================================================
# Helper functions (copied from launch-7vs1-coop-test.ps1)
# ============================================================

function Write-FileBytesWithRetry {
    param(
        [string]$Path,
        [byte[]]$Bytes,
        [int]$RetryCount = 10,
        [int]$DelayMilliseconds = 500
    )
    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            [System.IO.File]::WriteAllBytes($Path, $Bytes)
            return
        }
        catch {
            if ($attempt -ge $RetryCount) { throw }
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }
}

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
        if ($offset -ge $Bytes.Length) {
            throw "DocumentHeader dependency string is not null-terminated."
        }
        $offset++
    }
    return $offset
}

function Set-DocumentHeaderDependencies {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Dependencies
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "DocumentHeader not found: $Path"
    }
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
    Write-FileBytesWithRetry -Path $Path -Bytes $stream.ToArray()
}

function Set-DocumentInfoDependencies {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Dependencies
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "DocumentInfo not found: $Path"
    }
    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    $doc = $xml.SelectSingleNode("/DocInfo")
    if (-not $doc) { throw "Invalid DocumentInfo: missing /DocInfo in $Path" }
    $old = $xml.SelectSingleNode("/DocInfo/Dependencies")
    if ($old) { $null = $doc.RemoveChild($old) }
    $dependenciesNode = $xml.CreateElement("Dependencies")
    foreach ($dependency in $Dependencies) {
        $valueNode = $xml.CreateElement("Value")
        $valueNode.InnerText = $dependency
        $null = $dependenciesNode.AppendChild($valueNode)
    }
    $insertBefore = $doc.SelectSingleNode("PatchNote|Preload|HowToPlayBasic|HowToPlayAdvanced")
    if ($insertBefore) {
        $null = $doc.InsertBefore($dependenciesNode, $insertBefore)
    } else {
        $null = $doc.AppendChild($dependenciesNode)
    }
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $settings.Indent = $true
    $settings.NewLineChars = "`r`n"
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try { $xml.Save($writer) } finally { $writer.Close() }
}

function Set-PackageDependencies {
    param(
        [Parameter(Mandatory)][string]$PackageRoot,
        [Parameter(Mandatory)][string[]]$Dependencies
    )
    Set-DocumentInfoDependencies -Path (Join-Path $PackageRoot "DocumentInfo") -Dependencies $Dependencies
    Set-DocumentHeaderDependencies -Path (Join-Path $PackageRoot "DocumentHeader") -Dependencies $Dependencies
}

function Get-DocumentInfoDependencies {
    param([Parameter(Mandatory)][string]$Path)
    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    return @($xml.SelectNodes("/DocInfo/Dependencies/Value") | ForEach-Object { [string]$_.InnerText })
}

function Add-DependencyUnique {
    param([string[]]$Dependencies, [string]$Dependency)
    if ($Dependencies -contains $Dependency) { return $Dependencies }
    return @($Dependencies + $Dependency)
}

function Copy-DirectoryClean {
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Source directory not found: $Source"
    }
    if (Test-Path -LiteralPath $Destination) {
        [System.IO.Directory]::Delete($Destination, $true)
    }
    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent)) {
        [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

function Stop-RunningSc2 {
    foreach ($processName in @("SC2_x64", "SC2Switcher_x64", "BlizzardError")) {
        $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if (-not $running) { continue }
        foreach ($proc in $running) {
            try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop } catch {}
        }
    }
    Start-Sleep -Seconds 2
}

# ============================================================
# Main logic
# ============================================================

try {

$xmModSource = Join-Path $workspaceRoot "XM\XMAbathurReborn.SC2Mod"
$xmModDest = Join-Path $Sc2Root "Mods\7vs1\XMAbathurReborn.SC2Mod"
$coopZeroPopLive = Join-Path $Sc2Root "Mods\7vs1\CoopZeroPop.SC2Mod"
$mapLive = Join-Path $Sc2Root "Maps\7vs1\$LiveMapName"

Write-Host "xmModSource=$xmModSource"

if (-not (Test-Path -LiteralPath $xmModSource)) {
    throw "XMAbathurReborn source not found: $xmModSource"
}

# Step 1: Run launch-7vs1-coop-test.ps1 (-NoLaunch mode)
$launchScript = Join-Path $workspaceRoot "scripts\launch-7vs1-coop-test.ps1"
if (-not (Test-Path -LiteralPath $launchScript)) {
    throw "launch script not found: $launchScript"
}

Write-Host "=== Step 1: Run launch-7vs1-coop-test.ps1 (-NoLaunch) ===" -ForegroundColor Cyan
$launchArgs = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $launchScript,
    "-NoLaunch",
    "-Commanders", $Commanders
)
if ($ForceStopSc2BeforeInstall) { $launchArgs += "-ForceStopSc2BeforeInstall" }
& powershell @launchArgs
if ($LASTEXITCODE -ne 0) {
    throw "launch-7vs1-coop-test.ps1 failed with exit code $LASTEXITCODE"
}

# Step 2: Install XMAbathurReborn.SC2Mod to SC2 Mods\7vs1\
Write-Host ""
Write-Host "=== Step 2: Install XMAbathurReborn.SC2Mod to SC2 Mods\7vs1\ ===" -ForegroundColor Cyan
Copy-DirectoryClean -Source $xmModSource -Destination $xmModDest
Write-Host "Copied: $xmModDest"

# Step 3: Clean XMAbathurReborn dependencies (remove entries pointing to non-existent files)
Write-Host ""
Write-Host "=== Step 3: Clean XMAbathurReborn dependencies ===" -ForegroundColor Cyan

$xmDocInfoPath = Join-Path $xmModDest "DocumentInfo"
$xmDeps = Get-DocumentInfoDependencies -Path $xmDocInfoPath
Write-Host "Original dependencies:"
foreach ($dep in $xmDeps) { Write-Host "  - $dep" }

# For file: dependencies, extract the path and check if it exists in SC2 dir.
# For bnet: dependencies that also have a file: fallback, check the file: part.
$filteredDeps = @()
foreach ($dep in $xmDeps) {
    $shouldKeep = $true
    # Extract the file: portion (may appear after a comma in bnet: entries)
    $filePart = $null
    $idx = $dep.IndexOf("file:")
    if ($idx -ge 0) {
        $filePart = $dep.Substring($idx + 5).Trim()
    }

    if ($filePart) {
        # Normalize backslashes to forward slashes for Join-Path compatibility
        $normalizedPath = $filePart -replace '\\', '/'
        $fullPath = Join-Path $Sc2Root $normalizedPath
        if (-not (Test-Path -LiteralPath $fullPath)) {
            $shouldKeep = $false
            Write-Host "  Removed (file not found in SC2 dir): $dep" -ForegroundColor Yellow
            Write-Host "    Checked: $fullPath" -ForegroundColor DarkGray
        }
    }

    if ($shouldKeep) {
        $filteredDeps += $dep
    }
}

Write-Host "Updated dependencies:"
foreach ($dep in $filteredDeps) { Write-Host "  - $dep" }

Set-PackageDependencies -PackageRoot $xmModDest -Dependencies $filteredDeps
Write-Host "Updated XMAbathurReborn DocumentInfo + DocumentHeader"

# Step 4: Add XMAbathurReborn as dependency of CoopZeroPop AND the map (direct + transitive)
Write-Host ""
Write-Host "=== Step 4: Add XMAbathurReborn as dependency ===" -ForegroundColor Cyan

$xmDepKey = "file:Mods/7vs1/XMAbathurReborn.SC2Mod"

# 4a: Add to CoopZeroPop
$coopDeps = Get-DocumentInfoDependencies -Path (Join-Path $coopZeroPopLive "DocumentInfo")
$updatedCoopDeps = Add-DependencyUnique -Dependencies $coopDeps -Dependency $xmDepKey
if ($updatedCoopDeps.Count -eq $coopDeps.Count) {
    Write-Host "XMAbathurReborn already in CoopZeroPop deps, skipping" -ForegroundColor Yellow
} else {
    Write-Host "Adding to CoopZeroPop: $xmDepKey"
    Set-PackageDependencies -PackageRoot $coopZeroPopLive -Dependencies $updatedCoopDeps
    Write-Host "Updated CoopZeroPop DocumentInfo + DocumentHeader"
}

# 4b: Add to map directly (ensures game loads it even if transitive deps don't work)
$mapDeps = Get-DocumentInfoDependencies -Path (Join-Path $mapLive "DocumentInfo")
$updatedMapDeps = Add-DependencyUnique -Dependencies $mapDeps -Dependency $xmDepKey
if ($updatedMapDeps.Count -eq $mapDeps.Count) {
    Write-Host "XMAbathurReborn already in map deps, skipping" -ForegroundColor Yellow
} else {
    Write-Host "Adding to map: $xmDepKey"
    Set-PackageDependencies -PackageRoot $mapLive -Dependencies $updatedMapDeps
    Write-Host "Updated map DocumentInfo + DocumentHeader"
}

# Step 5: Launch game
Write-Host ""
Write-Host "=== Step 5: Launch game ===" -ForegroundColor Cyan
if ($SkipLaunch) {
    Write-Host "SkipLaunch set, skipping launch" -ForegroundColor Yellow
} else {
    Stop-RunningSc2
    $switcherPath = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
    if (-not (Test-Path -LiteralPath $switcherPath)) {
        throw "SC2Switcher not found: $switcherPath"
    }
    Write-Host "Launching: $mapLive"
    & $switcherPath $mapLive
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "XMAbathurReborn installed and added as CoopZeroPop dependency"
Write-Host "Game map: $mapLive"

} catch {
    Write-Host "ERROR at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Command: $($_.InvocationInfo.Line.Trim())" -ForegroundColor Red
    throw
}
