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

# Sync ALL CommanderUnits mods (galaxy code references all commanders' functions for compilation)
$allCommanderUnitsMods = @(
    "7vs1\CommanderUnits_Raynor.SC2Mod"
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
# 7vs1 CoreRuntime galaxy libs reference Lib*.galaxy from CommanderUnits mods.
# SC2 include system does not search mod dependencies for galaxy files,
# so they must be physically copied to the map Base.SC2Data directory.
function Sync-MapRuntimeLibraries {
    $mapBaseData = Join-Path $Sc2Root "Maps\$MapName\Base.SC2Data"
    if (-not (Test-Path $mapBaseData)) {
        [System.IO.Directory]::CreateDirectory($mapBaseData) | Out-Null
    }

    $mods7vs1Root = Join-Path $Sc2Root "Mods\7vs1"
    $skipMods = @("CoopZeroPop")

    $count = 0
    $modDirs = Get-ChildItem $mods7vs1Root -Directory -Filter "*.SC2Mod" -ErrorAction SilentlyContinue
    foreach ($modDir in $modDirs) {
        $modName = $modDir.Name -replace '\.SC2Mod$', ''
        if ($skipMods -contains $modName) {
            continue
        }

        $modBase = Join-Path $modDir.FullName "Base.SC2Data"
        if (-not (Test-Path $modBase)) {
            continue
        }

        $galaxyFiles = Get-ChildItem $modBase -File -Filter "Lib*.galaxy" -ErrorAction SilentlyContinue
        foreach ($gf in $galaxyFiles) {
            $dst = Join-Path $mapBaseData $gf.Name
            [System.IO.File]::Copy($gf.FullName, $dst, $true)
            $count++
        }
    }
    Write-Host "SYNC galaxy libs: $count files copied to map Base.SC2Data"
}

Sync-MapRuntimeLibraries

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
