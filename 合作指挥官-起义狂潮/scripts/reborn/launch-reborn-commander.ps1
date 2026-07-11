<#
.SYNOPSIS
  Reborn Commander Launcher
  Overlay 7vs1 commander system on Reborn map.
.DESCRIPTION
  1. (optional) CheckOnly: validate config + plan, no writes
  2. (optional) DryRun: compute plan + emit baseline report, no writes/launch
  3. (optional) -Plan: consume sc2-composer CompositionPlan.json as execution source
  4. Stop SC2
  5. Sync Reborn mod + 7vs1 CoreRuntime/CommanderBridge/CommanderUnits to live
  6. Write CampaignXCore Bank (commander selection)
  7. Launch map with SC2Switcher
  8. Run wait-for-game-ready.ps1

  Uses shared modules from scripts/sc2-launcher/ and config from Shared/Launcher/.
  When -Plan is provided, execution parameters (mods, galaxy injection, document deps)
  are read from the CompositionPlan.json instead of computed from -Commander/-MapName.
#>
param(
    [string]$Commander,
    [string]$MapName = "zexpedition03_reborn_port.SC2Map",
    [string]$Plan,
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

# === -Plan mode: consume CompositionPlan.json ===
$planMode = $false
$planExec = $null
if ($Plan) {
    if (-not (Test-Path -LiteralPath $Plan)) {
        Write-Host "ERROR: CompositionPlan not found: $Plan"
        exit 1
    }
    $planExec = Read-CompositionPlan -PlanPath $Plan -ProjRoot $ProjRoot
    # Override Commander/MapName from plan
    $Commander = $planExec.commander
    $MapName = $planExec.mapName
    $MapLivePath = Join-Path $Sc2Root "Maps\$MapName"
    $planMode = $true
    Write-Host "=== Reborn Commander Launcher (Plan mode) ==="
    Write-Host "Plan: $Plan"
    Write-Host "Commander: $Commander (from plan)"
    Write-Host "Map: $MapName (from plan)"
} else {
    if (-not $Commander) {
        Write-Host "ERROR: -Commander is required when -Plan is not specified"
        exit 1
    }
    Write-Host "=== Reborn Commander Launcher ==="
    Write-Host "Commander: $Commander"
    Write-Host "Map: $MapName"
}
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
# NOTE: use $launcherPlan (not $plan) — $Plan param is case-insensitive and typed [string].
$launcherPlan = New-LauncherPlan -Commander $Commander -MapName $MapName -ProjRoot $ProjRoot -Sc2Root $Sc2Root

# === Alenger on-demand resolution ===
# Normalize commander ID (TerranAlenger3 → Alenger3) to match commanderToAlenger keys
$alengerBaseName = $null
$racePrefixes = @('Terran', 'Zerg', 'Protoss')
if ($Commander -like 'Alenger*') {
    $alengerBaseName = $Commander
} else {
    foreach ($prefix in $racePrefixes) {
        if ($Commander -like "$prefix`Alenger*") {
            $alengerBaseName = $Commander.Substring($prefix.Length)
            break
        }
    }
}
$selectedAlengerMods = @()
if ($alengerBaseName -and $alengerConfig.commanderToAlenger.PSObject.Properties.Name -contains $alengerBaseName) {
    $selectedAlengerMods = @($alengerConfig.commanderToAlenger.$alengerBaseName)
}

# PS 5.1 compatibility: ensure validation object exists and properties are settable
if ($null -eq $launcherPlan.validation) {
    $launcherPlan | Add-Member -NotePropertyName validation -NotePropertyValue ([PSCustomObject]@{
        configSchema      = "pass"
        documentRoundtrip = "pending"
        galaxyChecker     = "pending"
        runtimeSmoke      = "pending"
    }) -Force
} elseif ($null -eq $launcherPlan.validation.configSchema) {
    $launcherPlan.validation | Add-Member -NotePropertyName configSchema -NotePropertyValue "pass" -Force
} else {
    $launcherPlan.validation.configSchema = "pass"
}

# === CheckOnly: emit plan + exit ===
if ($CheckOnly) {
    $planPath = Export-LauncherPlan -Plan $launcherPlan -ProjRoot $ProjRoot -Pretty
    Write-Host "PLAN emitted: $planPath"
    Write-Host "Plan summary:"
    Write-Host "  compositionId: $($launcherPlan.compositionId)"
    Write-Host "  dependencyLayers: $($launcherPlan.dependencyLayers.Count)"
    Write-Host "  galaxyInjection: $($launcherPlan.galaxyInjection.Count) files"
    Write-Host "  documentRewrite: $($launcherPlan.documentRewrite.DocumentHeader.Count) deps"
    exit 0
}

# === DryRun: emit plan + baseline report + exit ===
if ($DryRun) {
    $planPath = Export-LauncherPlan -Plan $launcherPlan -ProjRoot $ProjRoot -Pretty
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
        compositionId = $launcherPlan.compositionId
        commander     = $Commander
        map           = $MapName
        sourceMap     = $launcherPlan.sourceMap
        generatedMap  = $launcherPlan.generatedMap
        modSync       = @()
        staleModClean = @()
        dependencyRewrite = $launcherPlan.documentRewrite.DocumentHeader
        galaxyInject  = $launcherPlan.galaxyInjection | ForEach-Object { $_.file }
        documentHeaderDeps = $launcherPlan.documentRewrite.DocumentHeader
        documentInfoDeps   = $launcherPlan.documentRewrite.DocumentInfo
        generatedAt   = (Get-Date).ToString("o")
    }
    # Populate modSync + staleModClean from plan layers
    foreach ($layer in $launcherPlan.dependencyLayers) {
        foreach ($entry in $layer.entries) {
            $baseline.modSync += $entry.source
        }
    }
    # Stale commander units = all CommanderUnits_* except selected
    $allCommanderUnits = Get-ChildItem -LiteralPath (Join-Path $ProjRoot "Mods\7vs1") -Directory -Filter "CommanderUnits_*.SC2Mod" -ErrorAction SilentlyContinue
    $selectedModName = if ($launcherPlan.selectedCommanderUnitsMod) { "$($launcherPlan.selectedCommanderUnitsMod).SC2Mod" } else { "" }
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
    $md += "- CompositionId: $($launcherPlan.compositionId)"
    $md += "- SourceMap: $($launcherPlan.sourceMap)"
    $md += "- GeneratedMap: $($launcherPlan.generatedMap)"
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
    $md += "- configSchema: $($launcherPlan.validation.configSchema)"
    $md += "- documentRoundtrip: $($launcherPlan.validation.documentRoundtrip)"
    $md += "- galaxyChecker: $($launcherPlan.validation.galaxyChecker)"
    $md += "- runtimeSmoke: $($launcherPlan.validation.runtimeSmoke)"
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
if ($planMode) {
    # Plan mode: sync mods from plan.modSyncList
    Write-Host "MOD SYNC (plan-driven): $($planExec.modSyncList.Count) mods"
    Sync-ModSet -ModRelPaths $planExec.modSyncList -ProjRoot $ProjRoot -Sc2Root $Sc2Root
    $selectedCommanderUnitsMod = $planExec.selectedCommanderUnitsMod
} else {
    # Legacy mode: sync from config
    Sync-ModSet -ModRelPaths $rebornConfig.baseMods -ProjRoot $ProjRoot -Sc2Root $Sc2Root

    # Sync only the selected commander's CommanderUnits mod (on-demand loading).
    # Galaxy files for ALL commanders are injected from workspace source later
    # (Sync-MapRuntimeLibraries) to satisfy LibE0EAE146.galaxy's hardcoded includes.
    $selectedCommanderUnitsMod = Get-CommanderUnitsModName -Commander $Commander
    if ($selectedCommanderUnitsMod) {
        Sync-ModToLive -ModRelPath "7vs1\$selectedCommanderUnitsMod.SC2Mod" -ProjRoot $ProjRoot -Sc2Root $Sc2Root
    }

    # Sync only selected Alenger mods (on-demand loading)
    if ($selectedAlengerMods.Count -gt 0) {
        Write-Host "Alenger on-demand sync: $($selectedAlengerMods.Count) mods ($alengerBaseName)"
        foreach ($modName in $selectedAlengerMods) {
            Sync-ModToLive -ModRelPath "7vs1\$modName.SC2Mod" -ProjRoot $ProjRoot -Sc2Root $Sc2Root
        }
    }
}

# Remove unselected CommanderUnits mods from live directory (stale from previous runs)
$allowedCommanderUnits = @()
if ($selectedCommanderUnitsMod) {
    $allowedCommanderUnits += "$selectedCommanderUnitsMod.SC2Mod"
}
Remove-StaleCommanderUnitsMods -Sc2Root $Sc2Root -AllowedModNames $allowedCommanderUnits

# Validate commander name
if ($rebornConfig.validCommanders -notcontains $Commander) {
    Write-Host "WARN: unknown commander $Commander, Bank may not select correctly"
}

# --- MAP SYNC SECTION ---
Sync-MapToLive -MapName $MapName -ProjRoot $ProjRoot -Sc2Root $Sc2Root

# Build preserve list of map-owned galaxy files (ship with source map).
# RebornMapAdapter must always come from RebornMapAdapter.SC2Mod, not map stubs.
$sourceMapBaseData = Join-Path $ProjRoot "Maps\$MapName\Base.SC2Data"
$rebornAdapterGalaxyNames = @('RebornMapAdapter.galaxy', 'RebornMapAdapter_h.galaxy', 'LibRebornAdapter_AlengerBootstrap_h.galaxy')
$preserveNames = @{}
if (Test-Path $sourceMapBaseData) {
    $sourceGalaxyFiles = Get-ChildItem $sourceMapBaseData -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
    foreach ($gf in $sourceGalaxyFiles) {
        if ($rebornAdapterGalaxyNames -contains $gf.Name) { continue }
        $preserveNames[$gf.Name] = $true
    }
}

# Clean stale runtime galaxy files (preserve map-owned source files)
Clean-MapRuntimeLibraries -MapPath $MapLivePath -PreserveNames $preserveNames

# Inject galaxy files
if ($planMode) {
    # Plan mode: manifest-driven injection (Priority 2)
    Sync-MapRuntimeLibrariesFromManifest `
        -MapPath $MapLivePath `
        -ProjRoot $ProjRoot `
        -GalaxyInjectionEntries $planExec.galaxyInjectionEntries
} else {
    # Legacy mode: directory-scan injection
    Sync-MapRuntimeLibraries `
        -MapPath $MapLivePath `
        -ProjRoot $ProjRoot `
        -SourcePatterns $rebornConfig.galaxyInjection.sourcePatterns `
        -SourceRoot $rebornConfig.galaxyInjection.sourceRoot
}

# Ensure live map loads RebornMapAdapter from mod (include resolves map Base.SC2Data first).
$adapterModBase = Join-Path $ProjRoot "Mods\Reborn\RebornMapAdapter.SC2Mod\Base.SC2Data"
$mapLiveBaseData = Join-Path $MapLivePath "Base.SC2Data"
foreach ($adapterFile in $rebornAdapterGalaxyNames) {
    $src = Join-Path $adapterModBase $adapterFile
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $mapLiveBaseData $adapterFile) -Force
    }
}

# === Generate and inject AlengerBootstrap galaxy ===
# The generated LibRebornAdapter_AlengerBootstrap.galaxy contains include directives
# for only the selected commander's Alenger adapters, replacing the old hardcoded
# AdapterBootstrap that forced all 24 Alenger mods to load.
$alengerBootstrapCli = Join-Path $ScriptsRoot "sc2-composer\src\alengerBootstrapCli.mjs"
$alengerBootstrapOutput = Join-Path $mapLiveBaseData "LibRebornAdapter_AlengerBootstrap.galaxy"
$sharedRoot = Join-Path $ProjRoot "Shared\Launcher"
$alengerModsJsonPath = Join-Path $sharedRoot "alenger-mods.json"

Write-Host "Generating AlengerBootstrap for $Commander..."
& node $alengerBootstrapCli --commander $Commander --output $alengerBootstrapOutput --alenger-mods $alengerModsJsonPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: AlengerBootstrap generation failed (exit $LASTEXITCODE)"
    exit 1
}
Write-Host "AlengerBootstrap injected: $alengerBootstrapOutput"

# --- DEPENDENCY REWRITE SECTION ---
if ($planMode) {
    # Plan mode: use document deps from plan
    $runtimeDeps = $planExec.documentDeps
} else {
    # Legacy mode: use launcher plan document deps (base + on-demand Alenger + commander + campaign)
    $runtimeDeps = @($launcherPlan.documentRewrite.DocumentHeader)
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
if ($null -ne $launcherPlan.validation) {
    if ($null -eq $launcherPlan.validation.documentRoundtrip) {
        $launcherPlan.validation | Add-Member -NotePropertyName documentRoundtrip -NotePropertyValue "pass" -Force
    } else {
        $launcherPlan.validation.documentRoundtrip = "pass"
    }
}
Write-Host "DOCUMENT ROUNDTRIP VALID (header deps: $($rtResult.OriginalDeps.Count), info deps: $($rtResult.InfoDeps.Count))"

# Emit plan after execution (captures actual state post-rewrite)
$planPath = Export-LauncherPlan -Plan $launcherPlan -ProjRoot $ProjRoot -Pretty
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
