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

function Get-AiroAdapterModName {
    <#
    .SYNOPSIS
      Resolve commander to AIRO adapter mod relative path under Mods/AIRO/.
      Returns empty string when no adapter is mapped for this commander.
    #>
    param([string]$Commander)
    if ($null -eq $airoConfig.adapterMapping) { return "" }
    $prop = $airoConfig.adapterMapping.PSObject.Properties.Name -contains $Commander
    if (-not $prop) { return "" }
    return [string]$airoConfig.adapterMapping.$Commander
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

    # Sync AIRO adapter mod (per-commander unit replacement implementation)
    $adapterModRel = Get-AiroAdapterModName -Commander $Commander
    if ($adapterModRel -ne "") {
        Write-Host "Syncing AIRO adapter mod: AIRO\$adapterModRel.SC2Mod"
        Sync-ModToLive -ModRelPath "AIRO\$adapterModRel.SC2Mod" -ProjRoot $ProjRoot -Sc2Root $Sc2Root
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

# === GALAXY INJECTION SECTION ===
# LibE0EAE146.galaxy (CoreRuntime) hardcodes includes for ALL 19 commander runtime
# galaxies (LibE0EAE146_AbathurRuntime, ..._RaynorRuntime, etc) plus 30+ core
# libraries (LibE0EAE146_ProgressionRewards, MutatorCatalog, CoreInfra, etc).
# On maps that don't ship with these galaxy files (e.g. vanilla WoL campaign maps),
# the galaxy compiler cannot resolve includes via mod dependency chain alone —
# the files must be physically present in map Base.SC2Data.
# Inject ALL CommanderUnits_*.SC2Mod + CoreRuntime galaxy files into map.
if (-not $isOriginalMode) {
    Write-Host "--- Galaxy Injection ---"
    $sourceMapBaseData = Join-Path $ProjRoot "Maps\AIRO\$MapName\Base.SC2Data"
    $preserveNames = @{}
    if (Test-Path $sourceMapBaseData) {
        $sourceGalaxyFiles = Get-ChildItem $sourceMapBaseData -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
        foreach ($gf in $sourceGalaxyFiles) {
            $preserveNames[$gf.Name] = $true
        }
    }
    Clean-MapRuntimeLibraries -MapPath $MapLivePath -PreserveNames $preserveNames

    # 1. Inject CommanderUnits_*.SC2Mod galaxy files (commander runtimes + adapters)
    Sync-MapRuntimeLibraries `
        -MapPath $MapLivePath `
        -ProjRoot $ProjRoot `
        -SourcePatterns $airoConfig.galaxyInjection.sourcePatterns `
        -SourceRoot $airoConfig.galaxyInjection.sourceRoot

    # 2. Inject CoreRuntime galaxy files (LibE0EAE146 + 30+ core libraries)
    # These are required by LibE0EAE146.galaxy's include chain but don't auto-resolve
    # on non-7vs1-native maps.
    $coreRuntimeBaseData = Join-Path $ProjRoot "Mods\7vs1\CoreRuntime.SC2Mod\Base.SC2Data"
    $mapLiveBaseData = Join-Path $MapLivePath "Base.SC2Data"
    if (Test-Path $coreRuntimeBaseData) {
        $coreGalaxyFiles = Get-ChildItem $coreRuntimeBaseData -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
        $coreCount = 0
        foreach ($gf in $coreGalaxyFiles) {
            $dst = Join-Path $mapLiveBaseData $gf.Name
            [System.IO.File]::Copy($gf.FullName, $dst, $true)
            $coreCount++
        }
        Write-Host "SYNC CoreRuntime galaxy: $coreCount files injected"
    }

    # 3. Inject CommanderBridge galaxy files (LibE0EAE146_HeroRevive, HeroStructures, etc.)
    # These are in CommanderBridge.SC2Mod, not CommanderUnits_*, so sourcePatterns doesn't match.
    $commanderBridgeBaseData = Join-Path $ProjRoot "Mods\7vs1\CommanderBridge.SC2Mod\Base.SC2Data"
    if (Test-Path $commanderBridgeBaseData) {
        $bridgeGalaxyFiles = Get-ChildItem $commanderBridgeBaseData -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
        $bridgeCount = 0
        foreach ($gf in $bridgeGalaxyFiles) {
            $dst = Join-Path $mapLiveBaseData $gf.Name
            [System.IO.File]::Copy($gf.FullName, $dst, $true)
            $bridgeCount++
        }
        Write-Host "SYNC CommanderBridge galaxy: $bridgeCount files injected"
    }

    # 3b. Inject kit_mutations galaxy files (LibA070801C — mutator runtime)
    # LibE0EAE146_MutatorRuntime.galaxy calls libA070801C_gf_EnableDisableMutator,
    # which is defined in kit_mutations.SC2Mod. Without this injection the galaxy
    # compiler fails with "解析函数行出错" on the mutator clear function.
    $kitMutationsBaseData = Join-Path $ProjRoot "Mods\kit_mutations.SC2Mod\Base.SC2Data"
    if (Test-Path $kitMutationsBaseData) {
        $kitMutGalaxyFiles = Get-ChildItem $kitMutationsBaseData -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
        $kitMutCount = 0
        foreach ($gf in $kitMutGalaxyFiles) {
            $dst = Join-Path $mapLiveBaseData $gf.Name
            [System.IO.File]::Copy($gf.FullName, $dst, $true)
            $kitMutCount++
        }
        Write-Host "SYNC kit_mutations galaxy: $kitMutCount files injected"
    }

    # 3c. Inject AIROAdapter galaxy files (unit replacement system)
    # LibAIROAdapter provides:
    #   - Start location cleanup (removes original Terran units at PlayerStartLocation)
    #   - Event-driven unit replacement (replaces IronWarrior/Marine/etc with commander units)
    # Without this, commander units coexist with original Terran units (mixed units).
    $airoAdapterBaseData = Join-Path $ProjRoot "Mods\AIRO\AIROAdapter.SC2Mod\Base.SC2Data"
    if (Test-Path $airoAdapterBaseData) {
        $adapterGalaxyFiles = Get-ChildItem $airoAdapterBaseData -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
        $adapterCount = 0
        foreach ($gf in $adapterGalaxyFiles) {
            $dst = Join-Path $mapLiveBaseData $gf.Name
            [System.IO.File]::Copy($gf.FullName, $dst, $true)
            $adapterCount++
        }
        Write-Host "SYNC AIROAdapter galaxy: $adapterCount files injected"
    }

    # 3d. Inject per-commander AIRO adapter galaxy files (interface implementation)
    # LibAIROAdapter declares libAIROAdapterInterface_* functions, but the implementation
    # lives in a per-commander adapter (e.g. LibAIROAdapter_ZergKerrigan.galaxy). Without
    # injecting this file, the galaxy linker reports unresolved symbols and the entire
    # map script fails to compile.
    $adapterModRel = Get-AiroAdapterModName -Commander $Commander
    if ($adapterModRel -ne "") {
        $adapterSrcBaseData = Join-Path $ProjRoot "Mods\AIRO\$adapterModRel.SC2Mod\Base.SC2Data"
        if (Test-Path $adapterSrcBaseData) {
            $adapterImplFiles = Get-ChildItem $adapterSrcBaseData -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
            $implCount = 0
            foreach ($gf in $adapterImplFiles) {
                $dst = Join-Path $mapLiveBaseData $gf.Name
                [System.IO.File]::Copy($gf.FullName, $dst, $true)
                $implCount++
            }
            Write-Host "SYNC AIRO adapter ($Commander) galaxy: $implCount files injected"
        } else {
            Write-Host "WARN: adapter source not found: $adapterSrcBaseData"
        }
    }

    # 4. Patch MapScript.galaxy to include 7vs1 galaxy libraries
    # traynor01 (and other WoL campaign maps) have MapScript.galaxy that only includes
    # RO mod's galaxy files (LibWoLC, LibCamp, etc). 7vs1's LibE0EAE146 and its
    # dependencies must be included and initialized for the commander system to work.
    # This patch is applied to the live copy only — source map is untouched.
    $mapScriptPath = Join-Path $MapLivePath "MapScript.galaxy"
    if (Test-Path -LiteralPath $mapScriptPath) {
        Write-Host "--- MapScript.galaxy Patch ---"
        $content = [System.IO.File]::ReadAllText($mapScriptPath)
        $modified = $false

        # 4a. Insert 7vs1 includes after the last existing include line
        if ($content -notmatch 'include "LibE0EAE146"') {
            $sevenOneIncludes = @(
                'include "LibA070801C"',
                'include "Lib67C0F0E7"',
                'include "LibC0F50AA6"',
                'include "Lib81FF3B49"',
                'include "LibDF8E6945"',
                'include "LibBE3BBD9F"',
                'include "Lib0940FFB7"',
                'include "Lib4B62E36B"',
                'include "Lib975E2FE9"',
                'include "LibE0EAE146"',
                'include "LibAIROAdapter"'
            )
            $includeBlock = $sevenOneIncludes -join "`n"
            $lastIncludePattern = '(?m)^(include "[^"]+"(?:\r?\n)*)'
            $lastMatch = [regex]::Matches($content, $lastIncludePattern)
            if ($lastMatch.Count -gt 0) {
                $insertPos = $lastMatch[$lastMatch.Count - 1].Index + $lastMatch[$lastMatch.Count - 1].Length
                $content = $content.Substring(0, $insertPos) + $includeBlock + "`n" + $content.Substring($insertPos)
            }

            # Insert init calls before the closing brace of InitLibs()
            $initCalls = @(
                '    libA070801C_InitLib();',
                '    lib67C0F0E7_InitLib();',
                '    libC0F50AA6_InitLib();',
                '    lib81FF3B49_InitLib();',
                '    libDF8E6945_InitLib();',
                '    libBE3BBD9F_InitLib();',
                '    lib0940FFB7_InitLib();',
                '    lib4B62E36B_InitLib();',
                '    lib975E2FE9_InitLib();',
                '    libE0EAE146_InitLib();',
                '    libAIROAdapter_InitLib();'
            )
            $initBlock = $initCalls -join "`n" + "`n"
            $initLibsPattern = '(void\s+InitLibs\s*\(\s*\)\s*\{)([^}]+)(\})'
            if ($content -match $initLibsPattern) {
                $beforeBrace = $matches[2]
                $content = $content -replace [regex]::Escape($beforeBrace), ($beforeBrace + $initBlock + "`n")
            }
            $modified = $true
            Write-Host "  Added 11 includes + 11 init calls"
        }

        # 4a-bis. Insert per-commander adapter include after LibAIROAdapter
        # The adapter (e.g. LibAIROAdapter_ZergKerrigan) implements the
        # libAIROAdapterInterface_* functions declared in LibAIROAdapterInterface_h.
        # Without this include the galaxy linker fails with unresolved symbols.
        $adapterModRel4 = Get-AiroAdapterModName -Commander $Commander
        if ($adapterModRel4 -ne "") {
            $adapterSrcBase4 = Join-Path $ProjRoot "Mods\AIRO\$adapterModRel4.SC2Mod\Base.SC2Data"
            if (Test-Path $adapterSrcBase4) {
                $adapterGalaxyImplFiles = Get-ChildItem $adapterSrcBase4 -File -Filter "*.galaxy" -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -notmatch '_h\.galaxy$' }
                foreach ($gf in $adapterGalaxyImplFiles) {
                    $incName = [System.IO.Path]::GetFileNameWithoutExtension($gf.Name)
                    if ($content -notmatch ("include `"" + [regex]::Escape($incName) + "`"")) {
                        $adapterIncludeLine = "include `"$incName`""
                        $libAiroIncludePattern = '(?m)^include "LibAIROAdapter"\r?\n'
                        if ($content -match $libAiroIncludePattern) {
                            $content = $content -replace [regex]::Escape($matches[0]), ($matches[0] + $adapterIncludeLine + "`n")
                        } else {
                            # Fallback: append after last include line
                            $lastInc = [regex]::Matches($content, $lastIncludePattern)
                            if ($lastInc.Count -gt 0) {
                                $insertPos = $lastInc[$lastInc.Count - 1].Index + $lastInc[$lastInc.Count - 1].Length
                                $content = $content.Substring(0, $insertPos) + $adapterIncludeLine + "`n" + $content.Substring($insertPos)
                            }
                        }
                        $modified = $true
                        Write-Host "  Added adapter include: $incName"
                    }
                }
            }
        }

        # 4b. Inject CoreRuntime initialization into gt_Initialization_Func
        # InitLib() only initializes library variables — it does NOT create commander units.
        # Unit creation requires calling libE0EAE146_gf_Initialize() (loads Bank, sets
        # commander global) + libE0EAE146_gf_InitializeMapBaseScenario() (creates town hall,
        # workers, hero at player start location).
        # Pattern follows RebornMapAdapter: inject after gt_Init03Units trigger execute.
        $mapId = [System.IO.Path]::GetFileNameWithoutExtension($MapName)
        if ($content -notmatch 'libE0EAE146_gf_InitializeMapBaseScenario') {
            $init03Pattern = '(?m)^(    TriggerExecute\(gt_Init03[^\r\n]+\r?\n)'
            if ($content -match $init03Pattern) {
                $initLine = $matches[0]
                $coreInitCall = "    // AIRO: 7vs1 commander overlay initialization`n    libE0EAE146_gf_Initialize(true);`n    libE0EAE146_gf_InitializeMapBaseScenario(`"$mapId`");`n    // AIRO: unit replacement system (cleanup + event listener)`n    libAIROAdapter_gf_InitUnitReplacement();`n"
                $content = $content -replace [regex]::Escape($initLine), ($initLine + $coreInitCall)
                $modified = $true
                Write-Host "  Injected CoreRuntime + AIROAdapter init after gt_Init03 trigger (mapId=$mapId)"
            } else {
                Write-Host "  WARN: could not find gt_Init03 trigger to inject CoreRuntime init"
            }
        }

        if ($modified) {
            [System.IO.File]::WriteAllText($mapScriptPath, $content, [System.Text.UTF8Encoding]::new($false))
        } else {
            Write-Host "  SKIP: MapScript.galaxy already fully patched"
        }
    } else {
        Write-Host "WARN: MapScript.galaxy not found at $mapScriptPath"
    }

    # 4c. Patch BankList.xml to add CampaignXCore bank declaration
    # libE0EAE146_gf_Initialize calls BankLoad("CampaignXCore", 1), which requires
    # the map's BankList.xml to declare <Bank Name="CampaignXCore" Player="1"/>.
    # Without this declaration, BankLoad returns null and commander resolution fails
    # silently — units are never created.
    $bankListPath = Join-Path $MapLivePath "BankList.xml"
    if (Test-Path -LiteralPath $bankListPath) {
        $bankContent = [System.IO.File]::ReadAllText($bankListPath)
        if ($bankContent -notmatch 'Name="CampaignXCore"') {
            $bankEntry = '    <Bank Name="CampaignXCore" Player="1"/>'
            $bankContent = $bankContent.Replace('</BankList>', ($bankEntry + "`n</BankList>"))
            [System.IO.File]::WriteAllText($bankListPath, $bankContent, [System.Text.UTF8Encoding]::new($false))
            Write-Host "PATCHED BankList.xml: added CampaignXCore declaration"
        }
    } else {
        Write-Host "WARN: BankList.xml not found at $bankListPath"
    }

    # 5. Patch LibE0EAE146.galaxy to remove CampaignLib include
    # RO mod has its own LibCamp (library name "Camp"), 7vs1's CampaignLib also uses "Camp".
    # Both define libCamp_* constants → duplicate declaration crash.
    # Fix: remove CampaignLib include from LibE0EAE146.galaxy live copy.
    # RO mod's LibCamp provides libCamp_InitVariables() which LibE0EAE146 calls.
    $libE0EAE146Path = Join-Path $mapLiveBaseData "LibE0EAE146.galaxy"
    if (Test-Path -LiteralPath $libE0EAE146Path) {
        $libContent = [System.IO.File]::ReadAllText($libE0EAE146Path)
        if ($libContent -match 'include "TriggerLibs/CampaignLib"') {
            $libContent = $libContent -replace '(?m)^include "TriggerLibs/CampaignLib"\r?\n', ''
            [System.IO.File]::WriteAllText($libE0EAE146Path, $libContent, [System.Text.UTF8Encoding]::new($false))
            Write-Host "PATCHED LibE0EAE146.galaxy: removed CampaignLib include (avoids LibCamp name conflict)"
        }
    }
}

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

    # Add commander units mod dependency
    # Without this, commander-specific units (BarracksRaynor, etc.) are not in catalog
    # and libNtve_gf_CreateUnitsWithDefaultFacing fails with "无效的单位类型".
    $commanderUnitsMod = Get-CommanderUnitsModName -Commander $Commander
    if ($commanderUnitsMod) {
        $runtimeDeps += "file:Mods/7vs1/$commanderUnitsMod.SC2Mod"
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
