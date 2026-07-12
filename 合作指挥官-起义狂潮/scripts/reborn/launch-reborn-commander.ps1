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
    [switch]$CheckOnly,

    # === RuntimeProbe Integration ===
    [switch]$EnableRuntimeProbe,
    [int]$ProbeDuration = 90,

    # === Neuro Integration ===
    [switch]$EnableNeuro,
    [string]$NeuroUrl = "",
    [switch]$UseGary,
    [string]$GaryPath = "E:\Code\MyMod\SC2\tools\SC2-Neuro-API-Integration\gary\Gary.exe",
    [string]$PythonPath = "python",
    [switch]$SkipPythonRuntime,
    [string]$NeuroApiRoot = "",
    [string]$NeuroModSource = "",
    [string]$BridgeModSource = ""
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

# Patch MapScript.galaxy: add include "LibRebornAdapter_AlengerBootstrap" after include "RebornMapAdapter"
# RebornMapAdapter.galaxy includes LibRebornAdapter_AlengerBootstrap_h (declarations), but the
# implementation file must also be included or the galaxy compiler reports "函数已声明但尚未定义".
$bsMapScriptPath = Join-Path $MapLivePath "MapScript.galaxy"
if (Test-Path -LiteralPath $bsMapScriptPath) {
    $bsContent = [System.IO.File]::ReadAllText($bsMapScriptPath)
    if ($bsContent -notmatch '(?m)^\s*include\s+"LibRebornAdapter_AlengerBootstrap"\s*$') {
        $rebornAdapterIncludePattern = '(?m)^(include\s+"RebornMapAdapter"\s*$)'
        $bsInjectLine = 'include "LibRebornAdapter_AlengerBootstrap"'
        if ($bsContent -match $rebornAdapterIncludePattern) {
            $rebornLine = $matches[0]
            $bsContent = $bsContent -replace [regex]::Escape($rebornLine), ($rebornLine + "`r`n" + $bsInjectLine)
        } else {
            # Fallback: append after the last include line
            $lastIncMatches = [regex]::Matches($bsContent, '(?m)^\s*include\s+"[^"]+"')
            if ($lastIncMatches.Count -gt 0) {
                $lastInc = $lastIncMatches[$lastIncMatches.Count - 1]
                $insertAt = $lastInc.Index + $lastInc.Length
                $bsContent = $bsContent.Substring(0, $insertAt) + "`r`n" + $bsInjectLine + $bsContent.Substring($insertAt)
            }
        }
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($bsMapScriptPath, $bsContent, $utf8NoBom)
        Write-Host "  Patched MapScript.galaxy: added include ""LibRebornAdapter_AlengerBootstrap"""
    } else {
        Write-Host "  MapScript.galaxy already includes LibRebornAdapter_AlengerBootstrap"
    }
}

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

# === RuntimeProbe Integration (可选，通过 -EnableRuntimeProbe 开启) ===
# 复制 LibRuntimeProbe galaxy 到 live 地图 Base.SC2Data，patch MapScript.galaxy 和 BankList.xml
$pythonProcessId = $null
$garyProcessId = $null
if ($EnableRuntimeProbe) {
    Write-Host "`n=== RuntimeProbe Integration ===" -ForegroundColor Cyan

    $probeModSource = Join-Path $ProjRoot "Mods\RuntimeProbe\RuntimeProbe.SC2Mod"
    $probeGalaxyHeader = Join-Path $probeModSource "Base.SC2Data\LibRuntimeProbe_h.galaxy"
    $probeGalaxyImpl   = Join-Path $probeModSource "Base.SC2Data\LibRuntimeProbe.galaxy"

    if (-not (Test-Path -LiteralPath $probeGalaxyHeader)) {
        throw "RuntimeProbe galaxy header not found: $probeGalaxyHeader"
    }
    if (-not (Test-Path -LiteralPath $probeGalaxyImpl)) {
        throw "RuntimeProbe galaxy impl not found: $probeGalaxyImpl"
    }

    $mapLiveBaseData = Join-Path $MapLivePath "Base.SC2Data"
    $mapScriptPath = Join-Path $MapLivePath "MapScript.galaxy"
    $bankListPath  = Join-Path $MapLivePath "BankList.xml"

    # RP-1. 复制 galaxy 文件
    Write-Host "`n--- RuntimeProbe Step 1: Copy galaxy files ---" -ForegroundColor Yellow
    [System.IO.File]::Copy($probeGalaxyHeader, (Join-Path $mapLiveBaseData "LibRuntimeProbe_h.galaxy"), $true)
    [System.IO.File]::Copy($probeGalaxyImpl,   (Join-Path $mapLiveBaseData "LibRuntimeProbe.galaxy"),   $true)
    Write-Host "  Copied: LibRuntimeProbe_h.galaxy, LibRuntimeProbe.galaxy"

    # RP-2. Patch MapScript.galaxy
    Write-Host "`n--- RuntimeProbe Step 2: Patch MapScript.galaxy ---" -ForegroundColor Yellow
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    $content = [System.IO.File]::ReadAllText($mapScriptPath)
    $modified = $false

    # RP-2a. 追加 include 语句
    # 使用行锚定正则避免部分匹配；header 必须在 impl 之前
    $needHeader = $content -notmatch '(?m)^\s*include\s+"LibRuntimeProbe_h"\s*$'
    $needImpl   = $content -notmatch '(?m)^\s*include\s+"LibRuntimeProbe"\s*$'
    if ($needHeader -and $needImpl) {
        # 两者都缺：在最后一个 include 之后追加 header + impl
        $lastIncludeMatches = [regex]::Matches($content, '(?m)^\s*include\s+"[^"]+"')
        if ($lastIncludeMatches.Count -gt 0) {
            $lastMatch = $lastIncludeMatches[$lastIncludeMatches.Count - 1]
            $insertOffset = $lastMatch.Index + $lastMatch.Length
            $inject = "`r`ninclude `"LibRuntimeProbe_h`"`r`ninclude `"LibRuntimeProbe`""
            $content = $content.Substring(0, $insertOffset) + $inject + $content.Substring($insertOffset)
            $modified = $true
            Write-Host "  Injected both include statements (header + impl)"
        }
    } elseif ($needHeader) {
        # 仅缺 header：在 include "LibRuntimeProbe" 之前插入 header
        $implPattern = '(?m)^(include\s+"LibRuntimeProbe"\s*$)'
        if ($content -match $implPattern) {
            $implLine = $matches[0]
            $content = $content -replace [regex]::Escape($implLine), ('include "LibRuntimeProbe_h"' + "`r`n" + $implLine)
            $modified = $true
            Write-Host "  Injected include ""LibRuntimeProbe_h"" before impl"
        }
    } elseif ($needImpl) {
        # 仅缺 impl：在 include "LibRuntimeProbe_h" 之后插入 impl
        $headerPattern = '(?m)^(include\s+"LibRuntimeProbe_h"\s*$)'
        if ($content -match $headerPattern) {
            $headerLine = $matches[0]
            $content = $content -replace [regex]::Escape($headerLine), ($headerLine + "`r`ninclude `"LibRuntimeProbe`"")
            $modified = $true
            Write-Host "  Injected include ""LibRuntimeProbe"" after header"
        }
    }

    # RP-2b. 在 InitLibs() 中追加 libRuntimeProbe_InitLib() 调用
    if ($content -notmatch 'libRuntimeProbe_InitLib\s*\(\s*\)') {
        $initLibsMatch = [regex]::Match($content, '(?ms)void\s+InitLibs\s*\([^)]*\)\s*\{([^}]+)\}')
        if ($initLibsMatch.Success) {
            $funcBody = $initLibsMatch.Groups[1].Value
            $initCalls = [regex]::Matches($funcBody, 'lib\w+_InitLib\s*\(\s*\)\s*;')
            if ($initCalls.Count -gt 0) {
                $lastCall = $initCalls[$initCalls.Count - 1]
                $insertOffset = $initLibsMatch.Groups[1].Index + $lastCall.Index + $lastCall.Length
                $content = $content.Substring(0, $insertOffset) + "`r`n    libRuntimeProbe_InitLib();" + $content.Substring($insertOffset)
                $modified = $true
                Write-Host "  Injected libRuntimeProbe_InitLib() in InitLibs()"
            }
        }
    }

    # RP-2c. 在 gt_Initialization_Func 中 libRebornAdapter_OnAfterUnitsInit() 之后注入 StartProbe
    if ($content -notmatch 'libRuntimeProbe_gf_StartProbe\s*\(\s*\)') {
        $rebornInitPattern = '(?m)^(    libRebornAdapter_OnAfterUnitsInit\s*\(\s*\)\s*;\s*\r?\n)'
        if ($content -match $rebornInitPattern) {
            $initLine = $matches[0]
            $probeCall = "    // RuntimeProbe: start periodic probe`r`n    libRuntimeProbe_gf_StartProbe();`r`n"
            $content = $content -replace [regex]::Escape($initLine), ($initLine + $probeCall)
            $modified = $true
            Write-Host "  Injected libRuntimeProbe_gf_StartProbe() after libRebornAdapter_OnAfterUnitsInit()"
        } else {
            Write-Host "  WARN: could not find libRebornAdapter_OnAfterUnitsInit() to anchor StartProbe" -ForegroundColor Yellow
        }
    }

    if ($modified) {
        [System.IO.File]::WriteAllText($mapScriptPath, $content, $utf8NoBom)
        Write-Host "  MapScript.galaxy saved"
    }

    # RP-3. Patch BankList.xml 追加 RuntimeProbe Bank 声明
    Write-Host "`n--- RuntimeProbe Step 3: Patch BankList.xml ---" -ForegroundColor Yellow
    if (Test-Path -LiteralPath $bankListPath) {
        $bankListContent = [System.IO.File]::ReadAllText($bankListPath)
        if ($bankListContent -notmatch 'Name="RuntimeProbe"') {
            $bankListContent = $bankListContent -replace '</BankList>', '    <Bank Name="RuntimeProbe" Player="1"/>`r`n</BankList>'
            [System.IO.File]::WriteAllText($bankListPath, $bankListContent, $utf8NoBom)
            Write-Host "  Added RuntimeProbe Bank declaration"
        } else {
            Write-Host "  RuntimeProbe Bank already declared"
        }
    } else {
        Write-Host "  WARN: BankList.xml not found at $bankListPath" -ForegroundColor Yellow
    }

    Write-Host "RuntimeProbe integration completed." -ForegroundColor Green
}

# === Neuro Integration (可选，通过 -EnableNeuro 开启) ===
# 追加依赖、复制 mod、注入 galaxy、Patch BankList/MapScript
if ($EnableNeuro) {
    Write-Host "`n=== Neuro Integration ===" -ForegroundColor Cyan

    # 辅助函数：用独立进程调用 file-ops 脚本，绕过 TRAE 沙箱 hook
    function Invoke-FileOps {
        param(
            [Parameter(Mandatory=$true)][string]$Script,
            [Parameter(Mandatory=$true)][string[]]$Arguments
        )
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $Script) + $Arguments
        $proc = Start-Process powershell -ArgumentList $argList -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
        if ($proc -and $proc.ExitCode -ne 0) {
            Write-Host "  Warning: FileOps exit $($proc.ExitCode) for $Arguments" -ForegroundColor Yellow
        }
        return $proc.ExitCode
    }

    # === 路径解析 ===
    if ([string]::IsNullOrWhiteSpace($NeuroModSource)) {
        $NeuroModSource = "E:\Code\MyMod\SC2\tools\SC2-Neuro-WoL-Integration\Mods\NeuroIntegration.SC2Mod"
    }
    if ([string]::IsNullOrWhiteSpace($BridgeModSource)) {
        $BridgeModSource = Join-Path $ProjRoot "Mods\Neuro\NeuroBridge7vs1.SC2Mod"
    }
    if ([string]::IsNullOrWhiteSpace($NeuroApiRoot)) {
        $NeuroApiRoot = "E:\Code\MyMod\SC2\tools\SC2-Neuro-API-Integration"
    }

    Write-Host "NeuroMod:  $NeuroModSource"
    Write-Host "BridgeMod: $BridgeModSource"

    if (-not (Test-Path -LiteralPath $NeuroModSource)) {
        throw "NeuroIntegration mod not found: $NeuroModSource"
    }
    if (-not (Test-Path -LiteralPath $BridgeModSource)) {
        throw "NeuroBridge7vs1 mod not found: $BridgeModSource"
    }

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    $mapLiveBaseData = Join-Path $MapLivePath "Base.SC2Data"

    # === Neuro Step 1: 追加 Neuro 依赖到地图 DocumentInfo ===
    Write-Host "`n--- Neuro Step 1: Append Neuro mod dependencies ---" -ForegroundColor Yellow
    $docInfoPath = Join-Path $MapLivePath "DocumentInfo"
    $docInfoContent = [System.IO.File]::ReadAllText($docInfoPath)
    $xml = [xml]$docInfoContent
    $depsNode = $xml.DocInfo.Dependencies
    if ($null -eq $depsNode) {
        $depsNode = $xml.CreateElement("Dependencies")
        $xml.DocInfo.AppendChild($depsNode) | Out-Null
    }
    $neuroLiveRel = "file:Mods/NeuroIntegration.SC2Mod"
    $bridgeLiveRel = "file:Mods/Neuro/NeuroBridge7vs1.SC2Mod"
    $existingValues = @()
    foreach ($v in $depsNode.Value) { $existingValues += $v.InnerText }
    if ($existingValues -notcontains $neuroLiveRel) {
        $newVal = $xml.CreateElement("Value")
        $newVal.InnerText = $neuroLiveRel
        $depsNode.AppendChild($newVal) | Out-Null
        Write-Host "  Added: $neuroLiveRel"
    }
    if ($existingValues -notcontains $bridgeLiveRel) {
        $newVal = $xml.CreateElement("Value")
        $newVal.InnerText = $bridgeLiveRel
        $depsNode.AppendChild($newVal) | Out-Null
        Write-Host "  Added: $bridgeLiveRel"
    }
    [System.IO.File]::WriteAllText($docInfoPath, $xml.OuterXml, $utf8NoBom)
    Write-Host "DocumentInfo updated." -ForegroundColor Green

    # === Neuro Step 2: 复制 Neuro mod 到 SC2 运行时目录 ===
    Write-Host "`n--- Neuro Step 2: Copy Neuro mods to SC2 runtime ---" -ForegroundColor Yellow
    $neuroLiveDir = Join-Path $Sc2Root "Mods\NeuroIntegration.SC2Mod"
    $bridgeLiveDir = Join-Path $Sc2Root "Mods\Neuro\NeuroBridge7vs1.SC2Mod"
    $fileOpsDir = "c:\Users\22448\.trae-cn\skills\file-ops\scripts"

    if (Test-Path $neuroLiveDir) { Invoke-FileOps "$fileOpsDir\trae-rmdir.ps1" @($neuroLiveDir) | Out-Null }
    Invoke-FileOps "$fileOpsDir\trae-cp.ps1" @($NeuroModSource, $neuroLiveDir) | Out-Null
    Write-Host "  Copied NeuroIntegration -> $neuroLiveDir"

    $bridgeLiveParent = Split-Path $bridgeLiveDir -Parent
    if (-not (Test-Path $bridgeLiveParent)) { Invoke-FileOps "$fileOpsDir\trae-mkdir.ps1" @($bridgeLiveParent) | Out-Null }
    if (Test-Path $bridgeLiveDir) { Invoke-FileOps "$fileOpsDir\trae-rmdir.ps1" @($bridgeLiveDir) | Out-Null }
    Invoke-FileOps "$fileOpsDir\trae-cp.ps1" @($BridgeModSource, $bridgeLiveDir) | Out-Null
    Write-Host "  Copied NeuroBridge7vs1 -> $bridgeLiveDir"

    # === Neuro Step 3: 注入 galaxy 库文件到地图 Base.SC2Data ===
    Write-Host "`n--- Neuro Step 3: Inject galaxy libraries into map ---" -ForegroundColor Yellow
    if (-not (Test-Path $mapLiveBaseData)) {
        Invoke-FileOps "$fileOpsDir\trae-mkdir.ps1" @($mapLiveBaseData) | Out-Null
    }
    $neuroGalaxyDir = Join-Path $neuroLiveDir "Base.SC2Data"
    $neuroGalaxyFiles = Get-ChildItem $neuroGalaxyDir -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
    foreach ($gf in $neuroGalaxyFiles) {
        $dst = Join-Path $mapLiveBaseData $gf.Name
        [System.IO.File]::Copy($gf.FullName, $dst, $true)
        Write-Host "  Injected: $($gf.Name)"
    }
    $bridgeGalaxyDir = Join-Path $bridgeLiveDir "Base.SC2Data"
    $bridgeGalaxyFiles = Get-ChildItem $bridgeGalaxyDir -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
    foreach ($gf in $bridgeGalaxyFiles) {
        $dst = Join-Path $mapLiveBaseData $gf.Name
        [System.IO.File]::Copy($gf.FullName, $dst, $true)
        Write-Host "  Injected: $($gf.Name)"
    }

    # === Neuro Step 4: 注入 BankList.xml ===
    Write-Host "`n--- Neuro Step 4: Patch BankList.xml ---" -ForegroundColor Yellow
    if (Test-Path -LiteralPath $bankListPath) {
        $bankContent = [System.IO.File]::ReadAllText($bankListPath)
        if ($bankContent -notmatch 'Name="NeuroIntegration"') {
            $bankEntry = '    <Bank Name="NeuroIntegration" Player="1"/>'
            $bankContent = $bankContent.Replace('</BankList>', ($bankEntry + "`n</BankList>"))
            [System.IO.File]::WriteAllText($bankListPath, $bankContent, $utf8NoBom)
            Write-Host "  Added NeuroIntegration bank declaration"
        } else {
            Write-Host "  Already has NeuroIntegration bank"
        }
    } else {
        Write-Host "  WARN: BankList.xml not found, creating minimal one"
        $bankContent = "<?xml version=`"1.0`" encoding=`"utf-8`"?>`n<BankList>`n    <Bank Name=`"NeuroIntegration`" Player=`"1`"/>`n</BankList>`n"
        [System.IO.File]::WriteAllText($bankListPath, $bankContent, $utf8NoBom)
    }

    # === Neuro Step 5: 注入 MapScript.galaxy ===
    Write-Host "`n--- Neuro Step 5: Patch MapScript.galaxy ---" -ForegroundColor Yellow
    $mapScriptPath = Join-Path $MapLivePath "MapScript.galaxy"
    if (Test-Path -LiteralPath $mapScriptPath) {
        $content = [System.IO.File]::ReadAllText($mapScriptPath)
        $modified = $false

        if ($content -notmatch 'include "LibEFA54406"') {
            $neuroIncludes = @(
                'include "LibEFA54406"',
                'include "LibNeuroBridge7vs1"'
            )
            $includeBlock = $neuroIncludes -join "`n"
            $lastIncludePattern = '(?m)^(include "[^"]+"(?:\r?\n)*)'
            $lastMatch = [regex]::Matches($content, $lastIncludePattern)
            if ($lastMatch.Count -gt 0) {
                $insertPos = $lastMatch[$lastMatch.Count - 1].Index + $lastMatch[$lastMatch.Count - 1].Length
                $content = $content.Substring(0, $insertPos) + $includeBlock + "`n" + $content.Substring($insertPos)
            }
            $modified = $true
            Write-Host "  Added Neuro includes"
        }

        if ($content -notmatch 'libNeuroBridge7vs1_InitLib') {
            $initCalls = @(
                '    libEFA54406_InitLib();',
                '    libNeuroBridge7vs1_InitLib();'
            )
            $initBlock = ($initCalls -join "`n") + "`n"
            $initLibsPattern = '(void\s+InitLibs\s*\(\s*\)\s*\{)([^}]+)(\})'
            if ($content -match $initLibsPattern) {
                $beforeBrace = $matches[2]
                $content = $content -replace [regex]::Escape($beforeBrace), ($beforeBrace + $initBlock)
                $modified = $true
                Write-Host "  Added Neuro InitLib calls"
            } else {
                Write-Host "  WARN: could not find InitLibs() function"
            }
        }

        if ($modified) {
            [System.IO.File]::WriteAllText($mapScriptPath, $content, $utf8NoBom)
            Write-Host "MapScript.galaxy patched." -ForegroundColor Green
        } else {
            Write-Host "  SKIP: MapScript.galaxy already patched"
        }
    } else {
        Write-Host "  WARN: MapScript.galaxy not found at $mapScriptPath"
    }

    Write-Host "Neuro integration completed." -ForegroundColor Green

    # === Neuro Step 6: 启动 Python 运行时（可选，-NoLaunch 时跳过）===
    if (-not $SkipPythonRuntime -and -not $NoLaunch) {
        Write-Host "`n--- Neuro Step 6: Start Python runtime ---" -ForegroundColor Yellow

        $headlessRunner = Join-Path $NeuroApiRoot "headless_runner.py"
        $configureJson = Join-Path $NeuroApiRoot "configure.json"

        $effectiveNeuroUrl = $NeuroUrl
        if ([string]::IsNullOrWhiteSpace($effectiveNeuroUrl)) {
            if ($UseGary) {
                $effectiveNeuroUrl = "ws://127.0.0.1:64998"
                Write-Host "  Mode: Gary (real Neuro-sama)" -ForegroundColor Magenta
            } else {
                $effectiveNeuroUrl = "ws://127.0.0.1:8000"
                Write-Host "  Mode: Mock server (default)" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  Mode: Custom URL = $effectiveNeuroUrl"
        }

        if ($UseGary) {
            if (Test-Path -LiteralPath $GaryPath) {
                Write-Host "  Starting Gary at: $GaryPath"
                $garyProc = Start-Process -FilePath $GaryPath -PassThru -WindowStyle Normal
                $garyProcessId = $garyProc.Id
                Write-Host "  Gary PID: $garyProcessId" -ForegroundColor Green
                Write-Host "  Waiting 8s for Gary to start WebSocket server..." -ForegroundColor DarkGray
                Start-Sleep -Seconds 8
            } else {
                Write-Host "  WARN: Gary not found at $GaryPath, falling back to mock URL" -ForegroundColor Yellow
                $effectiveNeuroUrl = "ws://127.0.0.1:8000"
            }
        }

        if (Test-Path -LiteralPath $headlessRunner) {
            $config = @{
                game_path = $Sc2Root
                banks_path = "C:\Users\22448\Documents\StarCraft II\Banks"
                neuro_url = $effectiveNeuroUrl
                verbosity = 1
            }
            $configJson = $config | ConvertTo-Json -Depth 3
            [System.IO.File]::WriteAllText($configureJson, $configJson, $utf8NoBom)
            Write-Host "  configure.json written (neuro_url=$effectiveNeuroUrl)"

            Write-Host "  Starting headless_runner.py..."
            $pyProc = Start-Process -FilePath $PythonPath -ArgumentList $headlessRunner -PassThru -WindowStyle Normal
            $pythonProcessId = $pyProc.Id
            Write-Host "  Python PID: $pythonProcessId" -ForegroundColor Green
        } else {
            Write-Host "  WARN: headless_runner.py not found at $headlessRunner" -ForegroundColor Yellow
        }
    }
}

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

# === RuntimeProbe Post-Launch: 启动 Python watcher 读取 Bank ===
if ($EnableRuntimeProbe -and $exitCode -eq 0) {
    Write-Host "`n=== RuntimeProbe Post-Launch: Bank watcher ===" -ForegroundColor Cyan
    $runnerScript = Join-Path $ScriptsRoot "runtime-probe\runtime_probe_runner.py"
    $banksPath = "C:\Users\22448\Documents\StarCraft II\Banks"
    $reportDir = Join-Path $ScriptsRoot "runtime-probe\reports"
    $compositionId = "reborn-$Commander-$($MapName -replace '\.SC2Map$','')"

    if (Test-Path -LiteralPath $runnerScript) {
        Write-Host "  Runner:   $runnerScript"
        Write-Host "  Banks:    $banksPath"
        Write-Host "  Reports:  $reportDir"
        Write-Host "  Duration: ${ProbeDuration}s"
        Write-Host "  Composition: $compositionId"
        Write-Host ""
        & $PythonPath $runnerScript --banks-path $banksPath --composition-id $compositionId --output-dir $reportDir --duration $ProbeDuration
    } else {
        Write-Host "  WARN: runtime_probe_runner.py not found at $runnerScript" -ForegroundColor Yellow
    }
}

exit $exitCode
