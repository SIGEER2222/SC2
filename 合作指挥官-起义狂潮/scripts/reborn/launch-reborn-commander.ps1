<#
.SYNOPSIS
  Reborn Commander Launcher
  Overlay 7vs1 commander system on Reborn map.
.DESCRIPTION
  1. (optional) CheckOnly: validate config + plan, no writes
  2. (optional) DryRun: compute plan + emit baseline report, no writes/launch
  3. Stop SC2
  4. Sync Reborn mod + 7vs1 CoreRuntime/CommanderBridge/CommanderUnits to live
  5. Write CampaignXCore Bank (commander selection)
  6. Launch map with SC2Switcher
  7. Run wait-for-game-ready.ps1

  Uses shared modules from scripts/sc2-launcher/ and config from Shared/Launcher/.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Commander,
    [string]$MapName = "zexpedition03_reborn_port.SC2Map",
    [switch]$NoLaunch,
    [switch]$SkipWait,
    [switch]$DryRun,
    [switch]$CheckOnly
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
. (Join-Path $script:LauncherScriptsRoot "launcher-plan.ps1")

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
if ($DryRun)   { Write-Host "Mode: DryRun (no writes, no launch)" }
if ($CheckOnly) { Write-Host "Mode: CheckOnly (config + plan validation, no writes)" }

# === Config validation (always run, hard-fail on invalid) ===
$configResult = Test-LauncherConfig -Commander $Commander -MapFamily "reborn" -ProjRoot $ProjRoot
if (-not $configResult.Valid) {
    Write-Host (Format-LauncherConfigValidation -Result $configResult)
    Write-Host "CONFIG VALIDATION FAILED - aborting before any map/mod writes"
    exit 1
}
Write-Host "CONFIG VALID"

# === Compute launcher plan ===
$plan = New-LauncherPlan -Commander $Commander -MapName $MapName -ProjRoot $ProjRoot -Sc2Root $Sc2Root
$plan.validation.configSchema = "pass"

# === CheckOnly: emit plan + exit ===
if ($CheckOnly) {
    $planPath = Export-LauncherPlan -Plan $plan -ProjRoot $ProjRoot -Pretty
    Write-Host "PLAN emitted: $planPath"
    Write-Host "Plan summary:"
    Write-Host "  compositionId: $($plan.compositionId)"
    Write-Host "  dependencyLayers: $($plan.dependencyLayers.Count)"
    Write-Host "  galaxyInjection: $($plan.galaxyInjection.Count) files"
    Write-Host "  documentRewrite: $($plan.documentRewrite.DocumentHeader.Count) deps"
    exit 0
}

# === DryRun: emit plan + baseline report + exit ===
if ($DryRun) {
    $planPath = Export-LauncherPlan -Plan $plan -ProjRoot $ProjRoot -Pretty
    Write-Host "PLAN emitted: $planPath"

    # Emit baseline report
    # NOTE: Plan called for docs/经验总结/reborn-launcher-baselines/ but Windows
    # PowerShell 5.1 reads .ps1 files as system codepage (not UTF-8) without BOM,
    # which mojibake's Chinese string literals. Using ASCII path out/baselines/ instead.
    $baselineDir = Join-Path $ProjRoot "out\baselines"
    if (-not (Test-Path -LiteralPath $baselineDir)) {
        [System.IO.Directory]::CreateDirectory($baselineDir) | Out-Null
    }
    $today = (Get-Date).ToString("yyyy-MM-dd")
    $mapBaseName = [System.IO.Path]::GetFileNameWithoutExtension($MapName)
    $baselineJsonPath = Join-Path $baselineDir "${mapBaseName}__${Commander}__${today}.json"
    $baselineMdPath   = Join-Path $baselineDir "${mapBaseName}__${Commander}__${today}.md"

    $baseline = [PSCustomObject]@{
        schemaVersion = 1
        kind          = "LauncherBaselineReport"
        compositionId = $plan.compositionId
        commander     = $Commander
        map           = $MapName
        sourceMap     = $plan.sourceMap
        generatedMap  = $plan.generatedMap
        modSync       = @()
        staleModClean = @()
        dependencyRewrite = $plan.documentRewrite.DocumentHeader
        galaxyInject  = $plan.galaxyInjection | ForEach-Object { $_.file }
        documentHeaderDeps = $plan.documentRewrite.DocumentHeader
        documentInfoDeps   = $plan.documentRewrite.DocumentInfo
        generatedAt   = (Get-Date).ToString("o")
    }
    # Populate modSync + staleModClean from plan layers
    foreach ($layer in $plan.dependencyLayers) {
        foreach ($entry in $layer.entries) {
            $baseline.modSync += $entry.source
        }
    }
    # Stale commander units = all CommanderUnits_* except selected
    $allCommanderUnits = Get-ChildItem -LiteralPath (Join-Path $ProjRoot "Mods\7vs1") -Directory -Filter "CommanderUnits_*.SC2Mod" -ErrorAction SilentlyContinue
    $selectedModName = if ($plan.selectedCommanderUnitsMod) { "$($plan.selectedCommanderUnitsMod).SC2Mod" } else { "" }
    foreach ($cu in $allCommanderUnits) {
        if ($cu.Name -ne $selectedModName) {
            $baseline.staleModClean += $cu.Name
        }
    }

    $baselineJson = $baseline | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($baselineJsonPath, $baselineJson, [System.Text.UTF8Encoding]::new($false))

    # Markdown summary
    $md = @()
    $md += "# Reborn Launcher Baseline - $mapBaseName x $Commander"
    $md += ""
    $md += "- Generated: $($baseline.generatedAt)"
    $md += "- CompositionId: $($plan.compositionId)"
    $md += "- SourceMap: $($plan.sourceMap)"
    $md += "- GeneratedMap: $($plan.generatedMap)"
    $md += ""
    $md += "## Mod Sync ($($baseline.modSync.Count) mods)"
    foreach ($m in $baseline.modSync) { $md += "- $m" }
    $md += ""
    $md += "## Stale CommanderUnits Cleanup ($($baseline.staleModClean.Count) mods)"
    foreach ($m in $baseline.staleModClean) { $md += "- $m" }
    $md += ""
    $md += "## Galaxy Injection ($($baseline.galaxyInject.Count) files)"
    foreach ($f in $baseline.galaxyInject) { $md += "- $f" }
    $md += ""
    $md += "## DocumentHeader Dependencies ($($baseline.documentHeaderDeps.Count))"
    foreach ($d in $baseline.documentHeaderDeps) { $md += "- $d" }
    $md += ""
    $md += "## Validation"
    $md += "- configSchema: $($plan.validation.configSchema)"
    $md += "- documentRoundtrip: $($plan.validation.documentRoundtrip)"
    $md += "- galaxyChecker: $($plan.validation.galaxyChecker)"
    $md += "- runtimeSmoke: $($plan.validation.runtimeSmoke)"
    [System.IO.File]::WriteAllText($baselineMdPath, ($md -join "`n"), [System.Text.UTF8Encoding]::new($false))

    Write-Host "BASELINE JSON: $baselineJsonPath"
    Write-Host "BASELINE MD:   $baselineMdPath"
    Write-Host "DryRun complete - no writes to live SC2, no game launch"
    exit 0
}

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

# --- DOCUMENT ROUNDTRIP VALIDATION ---
$headerPath = Join-Path $MapLivePath "DocumentHeader"
$infoPath   = Join-Path $MapLivePath "DocumentInfo"
$rtResult = Test-DocumentDependencyRoundtrip -HeaderPath $headerPath -InfoPath $infoPath
if (-not $rtResult.Valid) {
    Write-Host "DOCUMENT ROUNDTRIP FAILED:"
    foreach ($e in $rtResult.Errors) { Write-Host "  - $e" }
    Write-Host "Aborting before launch - DocumentHeader/DocumentInfo may be corrupted"
    exit 1
}
$plan.validation.documentRoundtrip = "pass"
Write-Host "DOCUMENT ROUNDTRIP VALID (header deps: $($rtResult.OriginalDeps.Count), info deps: $($rtResult.InfoDeps.Count))"

# Emit plan after execution (captures actual state post-rewrite)
$planPath = Export-LauncherPlan -Plan $plan -ProjRoot $ProjRoot -Pretty
Write-Host "PLAN emitted: $planPath"

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
