<#
.SYNOPSIS
  Reborn Commander Launcher
  Overlay 7vs1 commander system on Reborn map.
.DESCRIPTION
  1. Stop SC2
  2. Sync Reborn mod + 7vs1 CoreRuntime/CommanderBridge/CommanderUnits to live
  3. Write CampaignXCore Bank (commander selection)
  4. Launch map with SC2Switcher
  5. Run wait-for-game-ready.ps1
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Commander,
    [string]$MapName = "zexpedition03_reborn_port.SC2Map",
    [switch]$NoLaunch,
    [switch]$SkipWait
)

$ErrorActionPreference = "Stop"

# === Paths (use $PSScriptRoot to avoid Chinese path encoding issues) ===
$ScriptsRoot = Split-Path $PSScriptRoot -Parent
$ProjRoot = Split-Path $ScriptsRoot -Parent
$Sc2Root  = "E:\SC2\SC2new\StarCraft II"

# === Load dependency scripts ===
. (Join-Path $ScriptsRoot "commander-power-metadata.ps1")
. (Join-Path $ScriptsRoot "sc2\campaignxcore-bank.ps1")

# === DocumentHeader/DocumentInfo dependency rewrite functions ===
# Copied from launch-7vs1-coop-test.ps1 to dynamically set map dependencies
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
    param([Parameter(Mandatory=$true)][string]$Path, [Parameter(Mandatory=$true)][string[]]$Dependencies)
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
    param([Parameter(Mandatory=$true)][string]$Path, [Parameter(Mandatory=$true)][string[]]$Dependencies)
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
    param([string[]]$Dependencies)
    $mapPath = Join-Path $Sc2Root "Maps\$MapName"
    Set-DocumentInfoDependencies -Path (Join-Path $mapPath "DocumentInfo") -Dependencies $Dependencies
    Set-DocumentHeaderDependencies -Path (Join-Path $mapPath "DocumentHeader") -Dependencies $Dependencies
    Write-Host "SET DEPS: $($Dependencies.Count) dependencies written to map"
}

function Get-WorkspaceRoot {
    return $ProjRoot
}

function Convert-TestCommanderToCommanderPowerKey {
    param([string]$Commander)
    return (Convert-CommanderPowerCommanderToBankKey -Commander $Commander -WorkspaceRoot $ProjRoot)
}

# === 1. Stop SC2 ===
function Stop-RunningSc2 {
    Get-Process -Name "SC2_x64","SC2Switcher_x64" -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 2
}

# === 2. Sync mod ===
function Sync-Mod {
    param([string]$ModRelPath)
    $src = Join-Path $ProjRoot "Mods\$ModRelPath"
    $dst = Join-Path $Sc2Root "Mods\$ModRelPath"
    if (-not (Test-Path $src)) {
        Write-Host "WARN: mod source not found: $src"
        return
    }
    $dstParent = Split-Path $dst -Parent
    if (-not (Test-Path $dstParent)) {
        [System.IO.Directory]::CreateDirectory($dstParent) | Out-Null
    }
    if (Test-Path $src -PathType Container) {
        if (Test-Path $dst) { [System.IO.Directory]::Delete($dst, $true) }
        [System.IO.Directory]::CreateDirectory($dst) | Out-Null
        robocopy $src $dst /MIR /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
    } else {
        [System.IO.File]::Copy($src, $dst, $true)
    }
    Write-Host "SYNC: $ModRelPath"
}

# === 3. Sync map ===
function Sync-Map {
    $src = Join-Path $ProjRoot "Maps\$MapName"
    $dst = Join-Path $Sc2Root "Maps\$MapName"
    if (Test-Path $dst) { [System.IO.Directory]::Delete($dst, $true) }
    [System.IO.Directory]::CreateDirectory($dst) | Out-Null
    robocopy $src $dst /MIR /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
    Write-Host "SYNC map: $MapName"
}

# === 4. Clear logs ===
function Clear-GameLogs {
    $logsRoot = "C:\Users\22448\Documents\StarCraft II\GameLogs"
    $logFiles = Get-ChildItem $logsRoot -File -ErrorAction SilentlyContinue
    foreach ($lf in $logFiles) {
        $rmScript = "c:\Users\22448\.trae-cn\skills\file-ops\scripts\trae-rm.ps1"
        if (Test-Path $rmScript) {
            powershell -NoProfile -ExecutionPolicy Bypass -File $rmScript $lf.FullName 2>$null
        }
    }
}

# === Main flow ===
Write-Host "=== Reborn Commander Launcher ==="
Write-Host "Commander: $Commander"
Write-Host "Map: $MapName"

# Always stop SC2 before syncing to avoid file locks
Stop-RunningSc2
Clear-GameLogs

# Sync Reborn base mods
Sync-Mod "crys_the_swarm_reborn.SC2Mod"
Sync-Mod "crys_swarm_assets.SC2Mod"
Sync-Mod "sibirens_starhooks_common.SC2Mod"
Sync-Mod "sibirens_starhooks_swarmstoryutils.SC2Mod"
Sync-Mod "sibirens_sundries_swarm_reborn.SC2Mod"

# Sync Reborn bridge mods
Sync-Mod "Reborn\RebornBridge.SC2Mod"
Sync-Mod "Reborn\RebornMapAdapter.SC2Mod"

# Sync 7vs1 commander system mods
Sync-Mod "7vs1\CoreRuntime.SC2Mod"
Sync-Mod "7vs1\CommanderBridge.SC2Mod"
Sync-Mod "7vs1\BaseCatalogPatch.SC2Mod"

# Sync kit_mutations (provides LibA070801C mutator runtime, required by LibE0EAE146_MutatorRuntime)
Sync-Mod "kit_mutations.SC2Mod"

# Sync ALL CommanderUnits mods (galaxy code references all commanders' functions for compilation)
$allCommanderUnitsMods = @(
    "7vs1\CommanderUnits_Raynor.SC2Mod"
    "7vs1\CommanderUnits_RaynorX.SC2Mod"
    "7vs1\CommanderUnits_Nova.SC2Mod"
    "7vs1\CommanderUnits_Swann.SC2Mod"
    "7vs1\CommanderUnits_Horner.SC2Mod"
    "7vs1\CommanderUnits_Mengsk.SC2Mod"
    "7vs1\CommanderUnits_TychusXM.SC2Mod"
    "7vs1\CommanderUnits_Kerrigan.SC2Mod"
    "7vs1\CommanderUnits_Abathur.SC2Mod"
    "7vs1\CommanderUnits_Zagara.SC2Mod"
    "7vs1\CommanderUnits_Stukov.SC2Mod"
    "7vs1\CommanderUnits_Dehaka.SC2Mod"
    "7vs1\CommanderUnits_Stetmann.SC2Mod"
    "7vs1\CommanderUnits_Artanis.SC2Mod"
    "7vs1\CommanderUnits_Vorazun.SC2Mod"
    "7vs1\CommanderUnits_Karax.SC2Mod"
    "7vs1\CommanderUnits_Fenix.SC2Mod"
    "7vs1\CommanderUnits_Alarak.SC2Mod"
    "7vs1\CommanderUnits_Zeratul.SC2Mod"
)

# Also sync shared mods needed for galaxy compilation
Sync-Mod "7vs1\SharedUnits.SC2Mod"
Sync-Mod "7vs1\ExternalRefs.SC2Mod"

foreach ($mod in $allCommanderUnitsMods) {
    Sync-Mod $mod
}

# Sync ALL Alenger mods (referenced by CoreRuntime's LibE0EAE146_AdapterBootstrap).
# 7vs1 launcher adds all 24 Alenger mods as DocumentHeader dependencies.
$alengerMods = @(
    "7vs1\AlengerCommon.SC2Mod"
    "7vs1\Alenger1.SC2Mod"
    "7vs1\Alenger1Adapter.SC2Mod"
    "7vs1\Alenger2.SC2Mod"
    "7vs1\Alenger2Adapter.SC2Mod"
    "7vs1\Alenger3.SC2Mod"
    "7vs1\Alenger3Adapter.SC2Mod"
    "7vs1\Alenger6.SC2Mod"
    "7vs1\Alenger6Adapter.SC2Mod"
    "7vs1\Alenger7.SC2Mod"
    "7vs1\Alenger7Adapter.SC2Mod"
    "7vs1\Alenger8.SC2Mod"
    "7vs1\Alenger8Runtime.SC2Mod"
    "7vs1\Alenger8Adapter.SC2Mod"
    "7vs1\Alenger9.SC2Mod"
    "7vs1\Alenger9Adapter.SC2Mod"
    "7vs1\Alenger10.SC2Mod"
    "7vs1\Alenger10Adapter.SC2Mod"
    "7vs1\Alenger11.SC2Mod"
    "7vs1\Alenger11Adapter.SC2Mod"
    "7vs1\Alenger12.SC2Mod"
    "7vs1\Alenger12Adapter.SC2Mod"
    "7vs1\Alenger13.SC2Mod"
    "7vs1\Alenger13Adapter.SC2Mod"
)
foreach ($mod in $alengerMods) {
    Sync-Mod $mod
}

# Validate commander name
$validCommanders = @(
    "TerranRaynor","TerranNova","TerranSwann","TerranHorner","TerranMengsk","TerranTychus",
    "ZergKerrigan","ZergAbathur","ZergZagara","ZergStukov","ZergDehaka","ZergStetmann",
    "ProtossArtanis","ProtossVorazun","ProtossKarax","ProtossFenix","ProtossAlarak","ProtossZeratul"
)
if ($validCommanders -notcontains $Commander) {
    Write-Host "WARN: unknown commander $Commander, Bank may not select correctly"
}

# Sync map
Sync-Map

# === Galaxy library sync ===
# SC2 loads galaxy files through mod dependency chain, NOT by copying to map.
# Clean up previously injected 7vs1 runtime galaxy files from map Base.SC2Data,
# but preserve galaxy files that ship with the source map (e.g. Lib48DF4533.galaxy).
function Clean-MapRuntimeLibraries {
    $mapBaseData = Join-Path $Sc2Root "Maps\$MapName\Base.SC2Data"
    if (-not (Test-Path $mapBaseData)) {
        return
    }

    # Build a set of galaxy file names that exist in the source map; these are
    # map-owned and must never be deleted (only runtime-injected files are cleaned).
    $sourceMapBaseData = Join-Path $ProjRoot "Maps\$MapName\Base.SC2Data"
    $preserveNames = @{}
    if (Test-Path $sourceMapBaseData) {
        $sourceGalaxyFiles = Get-ChildItem $sourceMapBaseData -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
        foreach ($gf in $sourceGalaxyFiles) {
            $preserveNames[$gf.Name] = $true
        }
    }

    $galaxyFiles = Get-ChildItem $mapBaseData -File -Filter "Lib*.galaxy" -ErrorAction SilentlyContinue
    $count = 0
    foreach ($gf in $galaxyFiles) {
        if ($preserveNames.ContainsKey($gf.Name)) {
            continue
        }
        [System.IO.File]::Delete($gf.FullName)
        $count++
    }
    if ($count -gt 0) {
        Write-Host "CLEAN: removed $count stale runtime galaxy files (preserved $($preserveNames.Count) map-owned galaxy files)"
    }
}

Clean-MapRuntimeLibraries

# === Set runtime dependencies ===
# Do NOT copy 7vs1 runtime galaxy files to map Base.SC2Data.
# 7vs1 reference map (ttosh02_7vs1) keeps Base.SC2Data empty and loads all
# galaxy files via mod dependencies. Copying galaxy files to Base.SC2Data
# causes nested include resolution failures (LibE0EAE146.galaxy includes
# Lib67C0F0E7 etc. fail even when files are present in Base.SC2Data).
#
# Rewrite DocumentHeader/DocumentInfo to include all required mods:
# - Reborn base + bridge mods
# - 7vs1 CoreRuntime + CommanderBridge + BaseCatalogPatch + SharedUnits + ExternalRefs
# - All 24 Alenger mods (required by CoreRuntime's LibE0EAE146_AdapterBootstrap)
# - All 18 CommanderUnits mods (galaxy code references all commanders)
# - kit_mutations (provides LibA070801C mutator runtime)
$runtimeDeps = @(
    "file:Mods/crys_the_swarm_reborn.SC2Mod"
    "file:Mods/RebornBridge.SC2Mod"
    "file:Mods/RebornMapAdapter.SC2Mod"
    "file:Mods/kit_mutations.SC2Mod"
    "file:Mods/7vs1/BaseCatalogPatch.SC2Mod"
    "file:Mods/7vs1/CommanderBridge.SC2Mod"
    "file:Mods/7vs1/CoreRuntime.SC2Mod"
    "file:Mods/7vs1/AlengerCommon.SC2Mod"
    "file:Mods/7vs1/Alenger3.SC2Mod"
    "file:Mods/7vs1/Alenger3Adapter.SC2Mod"
    "file:Mods/7vs1/Alenger1.SC2Mod"
    "file:Mods/7vs1/Alenger1Adapter.SC2Mod"
    "file:Mods/7vs1/Alenger6.SC2Mod"
    "file:Mods/7vs1/Alenger6Adapter.SC2Mod"
    "file:Mods/7vs1/Alenger8.SC2Mod"
    "file:Mods/7vs1/Alenger8Runtime.SC2Mod"
    "file:Mods/7vs1/Alenger8Adapter.SC2Mod"
    "file:Mods/7vs1/Alenger9.SC2Mod"
    "file:Mods/7vs1/Alenger9Adapter.SC2Mod"
    "file:Mods/7vs1/Alenger12.SC2Mod"
    "file:Mods/7vs1/Alenger12Adapter.SC2Mod"
    "file:Mods/7vs1/Alenger13.SC2Mod"
    "file:Mods/7vs1/Alenger13Adapter.SC2Mod"
    "file:Mods/7vs1/Alenger2.SC2Mod"
    "file:Mods/7vs1/Alenger2Adapter.SC2Mod"
    "file:Mods/7vs1/Alenger7.SC2Mod"
    "file:Mods/7vs1/Alenger7Adapter.SC2Mod"
    "file:Mods/7vs1/Alenger10.SC2Mod"
    "file:Mods/7vs1/Alenger10Adapter.SC2Mod"
    "file:Mods/7vs1/Alenger11.SC2Mod"
    "file:Mods/7vs1/Alenger11Adapter.SC2Mod"
    "file:Mods/7vs1/SharedUnits.SC2Mod"
    "file:Mods/7vs1/ExternalRefs.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_Raynor.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_Nova.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_Swann.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_Horner.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_Mengsk.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_TychusXM.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_Kerrigan.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_Abathur.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_Zagara.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_Stukov.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_Dehaka.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_Stetmann.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_Artanis.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_Vorazun.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_Karax.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_Fenix.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_Alarak.SC2Mod"
    "file:Mods/7vs1/CommanderUnits_Zeratul.SC2Mod"
)

Set-MapDependencies -Dependencies $runtimeDeps

# Write Bank
Write-Host "Writing CampaignXCore Bank..."
Set-CampaignXCorePrimaryCommander -SelectedCommanders @($Commander)
Set-CampaignXCoreTestRunId -RunId "RebornCommander"

# Launch
if ($NoLaunch) {
    Write-Host "NoLaunch mode, skip launch"
    exit 0
}

$switcher = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
$mapPath = Join-Path $Sc2Root "Maps\$MapName"
Write-Host "Launching: $mapPath"
Start-Process -FilePath $switcher -ArgumentList "`"$mapPath`""

if ($SkipWait) {
    Write-Host "SkipWait mode, skip wait"
    exit 0
}

# Wait for game ready
$waitScript = Join-Path $ScriptsRoot "wait-for-game-ready.ps1"
Write-Host "Waiting for game ready..."
& powershell -NoProfile -ExecutionPolicy Bypass -File $waitScript
$exitCode = $LASTEXITCODE
Write-Host "wait-for-game-ready exit code: $exitCode"
exit $exitCode
