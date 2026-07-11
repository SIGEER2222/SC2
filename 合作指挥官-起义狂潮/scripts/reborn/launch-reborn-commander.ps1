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

  Uses shared modules from scripts/sc2-launcher/ and config from Shared/Launcher/.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Commander,
    [string]$MapName = "zexpedition03_reborn_port.SC2Map",
    [switch]$NoLaunch,
    [switch]$SkipWait
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

# === Load project-specific dependency scripts ===
. (Join-Path $ScriptsRoot "commander-power-metadata.ps1")
. (Join-Path $ScriptsRoot "sc2\campaignxcore-bank.ps1")

function Convert-TestCommanderToCommanderPowerKey {
    param([string]$Commander)
    return (Convert-CommanderPowerCommanderToBankKey -Commander $Commander -WorkspaceRoot $ProjRoot)
}

# === Load configuration ===
$rebornConfig = Import-LauncherConfig -Name "reborn-dependencies"
$alengerConfig = Import-LauncherConfig -Name "alenger-mods"

# === Main flow ===
Write-Host "=== Reborn Commander Launcher ==="
Write-Host "Commander: $Commander"
Write-Host "Map: $MapName"

# Always stop SC2 before syncing to avoid file locks
Stop-RunningSc2
Clear-GameLogs

# --- MOD SYNC SECTION ---
# Sync Reborn base + bridge + 7vs1 core + shared mods (from config)
Sync-ModSet -ModRelPaths $rebornConfig.baseMods -ProjRoot $ProjRoot -Sc2Root $Sc2Root

# Sync only the selected commander's CommanderUnits mod (on-demand loading).
# Galaxy files for ALL commanders are injected from workspace source later
# (Sync-MapRuntimeLibraries) to satisfy LibE0EAE146.galaxy's hardcoded includes.
$selectedCommanderUnitsMod = Get-CommanderUnitsModName -Commander $Commander
if ($selectedCommanderUnitsMod) {
    Sync-ModToLive -ModRelPath "7vs1\$selectedCommanderUnitsMod.SC2Mod" -ProjRoot $ProjRoot -Sc2Root $Sc2Root
}

# Remove unselected CommanderUnits mods from live directory (stale from previous runs)
$allowedCommanderUnits = @()
if ($selectedCommanderUnitsMod) {
    $allowedCommanderUnits += "$selectedCommanderUnitsMod.SC2Mod"
}
Remove-StaleCommanderUnitsMods -Sc2Root $Sc2Root -AllowedModNames $allowedCommanderUnits

# Sync ALL Alenger mods (referenced by CoreRuntime's LibE0EAE146_AdapterBootstrap).
Sync-ModSet -ModRelPaths $alengerConfig.mods -ProjRoot $ProjRoot -Sc2Root $Sc2Root

# Validate commander name
if ($rebornConfig.validCommanders -notcontains $Commander) {
    Write-Host "WARN: unknown commander $Commander, Bank may not select correctly"
}

# --- MAP SYNC SECTION ---
Sync-MapToLive -MapName $MapName -ProjRoot $ProjRoot -Sc2Root $Sc2Root

# Build preserve list of map-owned galaxy files (ship with source map)
$sourceMapBaseData = Join-Path $ProjRoot "Maps\$MapName\Base.SC2Data"
$preserveNames = @{}
if (Test-Path $sourceMapBaseData) {
    $sourceGalaxyFiles = Get-ChildItem $sourceMapBaseData -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
    foreach ($gf in $sourceGalaxyFiles) {
        $preserveNames[$gf.Name] = $true
    }
}

# Clean stale runtime galaxy files (preserve map-owned source files)
Clean-MapRuntimeLibraries -MapPath $MapLivePath -PreserveNames $preserveNames

# Inject galaxy files from workspace (CommanderUnits + Alenger*Adapter, NOT CoreRuntime)
Sync-MapRuntimeLibraries `
    -MapPath $MapLivePath `
    -ProjRoot $ProjRoot `
    -SourcePatterns $rebornConfig.galaxyInjection.sourcePatterns `
    -SourceRoot $rebornConfig.galaxyInjection.sourceRoot

# --- DEPENDENCY REWRITE SECTION ---
# Build runtime dependency list: base deps + alenger deps + selected commander mod
$runtimeDeps = @() + $rebornConfig.baseDependencyPaths + $alengerConfig.dependencyPaths
if ($selectedCommanderUnitsMod) {
    $runtimeDeps += "file:Mods/7vs1/$selectedCommanderUnitsMod.SC2Mod"
}
Set-MapDependencies -MapPath $MapLivePath -Dependencies $runtimeDeps

# --- BANK SECTION ---
Write-Host "Writing CampaignXCore Bank..."
Set-CampaignXCorePrimaryCommander -SelectedCommanders @($Commander)
Set-CampaignXCoreTestRunId -RunId "RebornCommander"

# --- LAUNCH SECTION ---
if ($NoLaunch) {
    Write-Host "NoLaunch mode, skip launch"
    exit 0
}

$switcher = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
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
