<#
.SYNOPSIS
  AI 起义狂潮 (AIRO) Campaign Launcher
  Launch WoL campaign maps with RevolutionOverdrive mod, optionally overlaying 7vs1 commanders.
.DESCRIPTION
  1. (optional) -DryRun: emit plan, no writes/launch
  2. (optional) -NoLaunch: sync mods + map + write Bank, but don't launch game
  3. Stop SC2
  4. Sync RevolutionOverdrive mod to live SC2
  5. If commander is not "RevolutionOverdrive", also sync 7vs1 base + commander units mods
  6. Sync map to live SC2 Maps folder
  7. Set map DocumentHeader dependencies (RO mod + campaign deps + optional commander mods)
  8. If 7vs1 commander, write CampaignXCore Bank
  9. Launch map with SC2Switcher
  10. Wait for game ready

  Uses shared modules from scripts/sc2-launcher/ and config from Shared/Launcher/.
#>
param(
    [string]$Commander = "RevolutionOverdrive",
    [string]$MapName = "traynor01.SC2Map",
    [switch]$NoLaunch,
    [switch]$SkipWait,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# === Paths ===
$ScriptsRoot = Split-Path $PSScriptRoot -Parent
$ProjRoot = Split-Path $ScriptsRoot -Parent
$Sc2Root  = "E:\SC2\SC2new\StarCraft II"
$MapLivePath = Join-Path $Sc2Root "Maps\$MapName"

# === Load shared launcher modules ===
$script:LauncherScriptsRoot = Join-Path $ScriptsRoot "sc2-launcher"
. (Join-Path $script:LauncherScriptsRoot "common.ps1")
. (Join-Path $script:LauncherScriptsRoot "mod-sync.ps1")
. (Join-Path $script:LauncherScriptsRoot "map-sync.ps1")
. (Join-Path $script:LauncherScriptsRoot "config-validation.ps1")

# === Load project-specific dependency scripts ===
. (Join-Path $ScriptsRoot "commander-power-metadata.ps1")
. (Join-Path $ScriptsRoot "sc2\campaignxcore-bank.ps1")

function Convert-TestCommanderToCommanderPowerKey {
    param([string]$Commander)
    return (Convert-CommanderPowerCommanderToBankKey -Commander $Commander -WorkspaceRoot $ProjRoot)
}

# === Load configuration ===
$airoConfig = Import-LauncherConfig -Name "airo-dependencies"

$isOriginalMode = ($Commander -eq "RevolutionOverdrive")

Write-Host "=== AIRO Campaign Launcher ==="
Write-Host "Commander: $Commander"
Write-Host "Map: $MapName"
Write-Host "Mode: $(if ($isOriginalMode) { 'Original (RevolutionOverdrive only)' } else { '7vs1 Commander overlay' })"
if ($DryRun)   { Write-Host "DryRun: true (no writes, no launch)" }
if ($NoLaunch) { Write-Host "NoLaunch: true (sync + Bank, no game launch)" }

# === Config validation ===
if ($airoConfig.validCommanders -notcontains $Commander) {
    Write-Host "ERROR: unknown commander '$Commander'. Valid: $($airoConfig.validCommanders -join ', ')"
    exit 1
}

# Map name validation: must end with .SC2Map
if ($MapName -notmatch '\.SC2Map$') {
    Write-Host "ERROR: MapName must end with .SC2Map, got: $MapName"
    exit 1
}

# === DryRun: emit plan + exit ===
if ($DryRun) {
    $mapBaseName = [System.IO.Path]::GetFileNameWithoutExtension($MapName)
    Write-Host "=== DryRun Plan ==="
    Write-Host "Commander: $Commander"
    Write-Host "Map: $MapName"
    Write-Host "MapLivePath: $MapLivePath"
    Write-Host "Mode: $(if ($isOriginalMode) { 'Original' } else { '7vs1 Commander' })"
    Write-Host "Base mods:"
    foreach ($m in $airoConfig.baseMods) { Write-Host "  - $m" }
    if (-not $isOriginalMode) {
        Write-Host "Commander base mods:"
        foreach ($m in $airoConfig.commanderBaseMods) { Write-Host "  - $m" }
        $commanderUnitsMod = Get-CommanderUnitsModName -Commander $Commander
        if ($commanderUnitsMod) {
            Write-Host "Commander units mod: 7vs1\$commanderUnitsMod.SC2Mod"
        }
    }
    Write-Host "Campaign deps:"
    $mapKey = $mapBaseName
    if ($airoConfig.mapCampaigns.PSObject.Properties.Name -contains $mapKey) {
        foreach ($d in $airoConfig.mapCampaigns.$mapKey) { Write-Host "  - $d" }
    } else {
        Write-Host "  (none configured for $mapKey)"
    }
    Write-Host "DryRun complete - no writes to live SC2, no game launch"
    exit 0
}

# === Stop SC2 before syncing ===
Stop-RunningSc2
Clear-GameLogs

# === MOD SYNC SECTION ===
Write-Host "--- Mod Sync ---"

# Always sync RevolutionOverdrive mod
foreach ($modRelPath in $airoConfig.baseMods) {
    Write-Host "Syncing mod: $modRelPath"
    Sync-ModToLive -ModRelPath $modRelPath -ProjRoot $ProjRoot -Sc2Root $Sc2Root
}

# If 7vs1 commander mode, sync commander base mods + commander units mod
if (-not $isOriginalMode) {
    foreach ($modRelPath in $airoConfig.commanderBaseMods) {
        Write-Host "Syncing commander base mod: $modRelPath"
        Sync-ModToLive -ModRelPath $modRelPath -ProjRoot $ProjRoot -Sc2Root $Sc2Root
    }

    $commanderUnitsMod = Get-CommanderUnitsModName -Commander $Commander
    if ($commanderUnitsMod) {
        Write-Host "Syncing commander units mod: 7vs1\$commanderUnitsMod.SC2Mod"
        Sync-ModToLive -ModRelPath "7vs1\$commanderUnitsMod.SC2Mod" -ProjRoot $ProjRoot -Sc2Root $Sc2Root
    }

    # Remove unselected CommanderUnits mods from live directory
    $allowedCommanderUnits = @()
    if ($commanderUnitsMod) {
        $allowedCommanderUnits += "$commanderUnitsMod.SC2Mod"
    }
    Remove-StaleCommanderUnitsMods -Sc2Root $Sc2Root -AllowedModNames $allowedCommanderUnits
}

# === MAP SYNC SECTION ===
Write-Host "--- Map Sync ---"
# AIRO maps live in Maps\AIRO\ subdirectory, so sync directly instead of using Sync-MapToLive
# (which expects Maps\<MapName> at top level)
$mapSrcDir = Join-Path $ProjRoot "Maps\AIRO\$MapName"
if (-not (Test-Path $mapSrcDir)) {
    Write-Host "ERROR: map source not found: $mapSrcDir"
    exit 1
}
if (Test-Path $MapLivePath) { [System.IO.Directory]::Delete($MapLivePath, $true) }
[System.IO.Directory]::CreateDirectory($MapLivePath) | Out-Null
robocopy $mapSrcDir $MapLivePath /MIR /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
Write-Host "SYNC map: $MapName (from Maps\AIRO\)"

# === DEPENDENCY REWRITE SECTION ===
Write-Host "--- Dependency Rewrite ---"
$runtimeDeps = @()

# Add RO mod dependency
foreach ($depPath in $airoConfig.baseDependencyPaths) {
    $runtimeDeps += $depPath
}

# Add 7vs1 commander base mod dependencies
if (-not $isOriginalMode) {
    foreach ($depPath in $airoConfig.commanderBaseDependencyPaths) {
        $runtimeDeps += $depPath
    }
}

# Add campaign dependencies for this map
$mapKey = [System.IO.Path]::GetFileNameWithoutExtension($MapName)
if ($airoConfig.mapCampaigns.PSObject.Properties.Name -contains $mapKey) {
    foreach ($campaignDep in $airoConfig.mapCampaigns.$mapKey) {
        $runtimeDeps += $campaignDep
    }
}

Write-Host "Setting $($runtimeDeps.Count) dependencies on map..."
Set-MapDependencies -MapPath $MapLivePath -Dependencies $runtimeDeps

# === DOCUMENT ROUNDTRIP VALIDATION ===
$headerPath = Join-Path $MapLivePath "DocumentHeader"
$infoPath   = Join-Path $MapLivePath "DocumentInfo"
$rtResult = Test-DocumentDependencyRoundtrip -HeaderPath $headerPath -InfoPath $infoPath
if (-not $rtResult.Valid) {
    Write-Host "DOCUMENT ROUNDTRIP FAILED:"
    foreach ($e in $rtResult.Errors) { Write-Host "  - $e" }
    Write-Host "Aborting before launch - DocumentHeader/DocumentInfo may be corrupted"
    exit 1
}
Write-Host "DOCUMENT ROUNDTRIP VALID (header deps: $($rtResult.OriginalDeps.Count), info deps: $($rtResult.InfoDeps.Count))"

# === BANK SECTION ===
if (-not $isOriginalMode) {
    Write-Host "--- Bank Write ---"
    Write-Host "Writing CampaignXCore Bank for commander: $Commander"
    Set-CampaignXCorePrimaryCommander -SelectedCommanders @($Commander)
    Set-CampaignXCoreTestRunId -RunId "AIROCommander"
}

# === LAUNCH SECTION ===
if ($NoLaunch) {
    Write-Host "NoLaunch mode, skip launch"
    exit 0
}

$switcher = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
Write-Host "--- Launch ---"
Write-Host "Launching: $MapLivePath"
Start-Process -FilePath $switcher -ArgumentList "`"$MapLivePath`""

if ($SkipWait) {
    Write-Host "SkipWait mode, skip wait"
    exit 0
}

# Wait for game ready
$exitCode = Wait-GameReady -ScriptsRoot $ScriptsRoot
Write-Host "wait-for-game-ready exit code: $exitCode"
exit $exitCode
