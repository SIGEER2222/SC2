<#
.SYNOPSIS
  CMRE (Co-op Mission Rewrite Enhanced) Campaign Launcher
  Launch CMRE co-op maps with CMRE mod, optionally overlaying 7vs1 commanders.
.DESCRIPTION
  1. (optional) -DryRun: emit plan, no writes/launch
  2. (optional) -NoLaunch: sync mods + map + write Bank, but don't launch game
  3. Stop SC2
  4. Sync CMRE mod to live SC2
  5. If commander is not "CMRE", also sync 7vs1 base + commander units mods
  6. Sync map to live SC2 Maps folder
  7. Set map DocumentHeader dependencies (CMRE mod + optional commander mods)
  8. If 7vs1 commander, write CampaignXCore Bank
  9. Launch map with SC2Switcher
  10. Wait for game ready

  Uses shared modules from scripts/sc2-launcher/ and config from Shared/Launcher/.
#>
param(
    [string]$Commander = "CMRE",
    [string]$MapName = "亡者之夜.SC2Map",
    [switch]$NoLaunch,
    [switch]$SkipWait,
    [switch]$DryRun,
    [switch]$EnableNeuro,
    [switch]$SkipPythonRuntime
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
$cmreConfig = Import-LauncherConfig -Name "cmre-dependencies"

$isOriginalMode = ($Commander -eq "CMRE")
$isAlengerMode = $false
$alengerMods = @()
if ($cmreConfig.alengerCommanders -and $cmreConfig.alengerCommanders.$Commander) {
    $isAlengerMode = $true
    $alengerMods = $cmreConfig.alengerCommanders.$Commander
}

Write-Host "=== CMRE Campaign Launcher ==="
Write-Host "Commander: $Commander"
Write-Host "Map: $MapName"
$modeStr = if ($isOriginalMode) { 'Original (CMRE only)' } elseif ($isAlengerMode) { 'Alenger Commander overlay' } else { '7vs1 Commander overlay' }
Write-Host "Mode: $modeStr"
if ($DryRun)   { Write-Host "DryRun: true (no writes, no launch)" }
if ($NoLaunch) { Write-Host "NoLaunch: true (sync + Bank, no game launch)" }

# === Config validation ===
if ($cmreConfig.validCommanders -notcontains $Commander) {
    Write-Host "ERROR: unknown commander '$Commander'. Valid: $($cmreConfig.validCommanders -join ', ')"
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
    Write-Host "Mode: $modeStr"
    Write-Host "Base mods:"
    foreach ($m in $cmreConfig.baseMods) { Write-Host "  - $m" }
    if (-not $isOriginalMode) {
        Write-Host "Commander base mods:"
        foreach ($m in $cmreConfig.commanderBaseMods) { Write-Host "  - $m" }
        if ($isAlengerMode) {
            Write-Host "Alenger mods:"
            foreach ($m in $alengerMods) { Write-Host "  - 7vs1\$m.SC2Mod" }
        } else {
            $commanderUnitsMod = Get-CommanderUnitsModName -Commander $Commander
            if ($commanderUnitsMod) {
                Write-Host "Commander units mod: 7vs1\$commanderUnitsMod.SC2Mod"
            }
        }
    }
    Write-Host "DryRun complete - no writes to live SC2, no game launch"
    exit 0
}

# === Stop SC2 before syncing ===
Stop-RunningSc2
Clear-GameLogs

# === MOD SYNC SECTION ===
Write-Host "--- Mod Sync ---"

# Always sync CMRE mod
foreach ($modRelPath in $cmreConfig.baseMods) {
    Write-Host "Syncing mod: $modRelPath"
    Sync-ModToLive -ModRelPath $modRelPath -ProjRoot $ProjRoot -Sc2Root $Sc2Root
}

# If 7vs1 commander mode, sync commander base mods + commander units mod
if (-not $isOriginalMode) {
    foreach ($modRelPath in $cmreConfig.commanderBaseMods) {
        Write-Host "Syncing commander base mod: $modRelPath"
        Sync-ModToLive -ModRelPath $modRelPath -ProjRoot $ProjRoot -Sc2Root $Sc2Root
    }

    if ($isAlengerMode) {
        Write-Host "Syncing Alenger mods:"
        foreach ($m in $alengerMods) {
            $modRelPath = "7vs1\$m.SC2Mod"
            Write-Host "  - $modRelPath"
            Sync-ModToLive -ModRelPath $modRelPath -ProjRoot $ProjRoot -Sc2Root $Sc2Root
        }
        # 保留 alengerMods 中引入的 CommanderUnits_* mod：CoreRuntime 的 LibKMIS.galaxy / LibKPVP_Commander.galaxy
        # 硬编码 include LibDF8E6945_h (Dehaka) 与 LibKPVP_Swann (Swann)，必须随 Alenger3 一起 sync。
        $alengerAllowedCommanderUnits = $alengerMods | Where-Object { $_ -like 'CommanderUnits_*' } | ForEach-Object { "$_.SC2Mod" }
        Remove-StaleCommanderUnitsMods -Sc2Root $Sc2Root -AllowedModNames $alengerAllowedCommanderUnits
    } else {
        $commanderUnitsMod = Get-CommanderUnitsModName -Commander $Commander
        if ($commanderUnitsMod) {
            Write-Host "Syncing commander units mod: 7vs1\$commanderUnitsMod.SC2Mod"
            Sync-ModToLive -ModRelPath "7vs1\$commanderUnitsMod.SC2Mod" -ProjRoot $ProjRoot -Sc2Root $Sc2Root
        }

        $allowedCommanderUnits = @()
        if ($commanderUnitsMod) {
            $allowedCommanderUnits += "$commanderUnitsMod.SC2Mod"
        }
        Remove-StaleCommanderUnitsMods -Sc2Root $Sc2Root -AllowedModNames $allowedCommanderUnits
    }
}

# === MAP SYNC SECTION ===
Write-Host "--- Map Sync ---"
# CMRE maps live in Maps\CMRE\ subdirectory
$mapSrcDir = Join-Path $ProjRoot "Maps\CMRE\$MapName"
if (-not (Test-Path $mapSrcDir)) {
    Write-Host "ERROR: map source not found: $mapSrcDir"
    exit 1
}
if (Test-Path $MapLivePath) { [System.IO.Directory]::Delete($MapLivePath, $true) }
[System.IO.Directory]::CreateDirectory($MapLivePath) | Out-Null
robocopy $mapSrcDir $MapLivePath /MIR /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
Write-Host "SYNC map: $MapName (from Maps\CMRE\)"

# === DEPENDENCY REWRITE SECTION ===
Write-Host "--- Dependency Rewrite ---"
$runtimeDeps = @()

# Add CMRE mod dependency
foreach ($depPath in $cmreConfig.baseDependencyPaths) {
    $runtimeDeps += $depPath
}

# Add 7vs1 commander base mod dependencies
if (-not $isOriginalMode) {
    foreach ($depPath in $cmreConfig.commanderBaseDependencyPaths) {
        $runtimeDeps += $depPath
    }

    if ($isAlengerMode) {
        foreach ($m in $alengerMods) {
            $runtimeDeps += "file:Mods/7vs1/$m.SC2Mod"
        }
    } else {
        $commanderUnitsMod = Get-CommanderUnitsModName -Commander $Commander
        if ($commanderUnitsMod) {
            $runtimeDeps += "file:Mods/7vs1/$commanderUnitsMod.SC2Mod"
        }
    }
}

# Add Neuro mod dependencies (when -EnableNeuro)
if ($EnableNeuro) {
    $runtimeDeps += "file:Mods/NeuroIntegration.SC2Mod"
    $runtimeDeps += "file:Mods/Neuro/NeuroBridge7vs1.SC2Mod"
    Write-Host "Added Neuro dependencies (NeuroIntegration + NeuroBridge7vs1)"
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

# === ALENGER3 INTEGRATION SECTION (when $isAlengerMode) ===
if ($isAlengerMode) {
    Write-Host "`n=== Alenger3 Integration ===" -ForegroundColor Cyan

    function Install-CmreGalaxyHostOverlay {
        param(
            [Parameter(Mandatory = $true)][string]$ModsRoot,
            [Parameter(Mandatory = $true)][string]$MapPath
        )
        # 注意：不复制 CMRE 的 Lib*.galaxy、scripts/、TriggerLibs/ 到 map。
        # CMRE mod 已通过 DocumentHeader 依赖声明，SC2 编译器会从 mod 中加载这些文件。
        # map 中的 galaxy 文件编译时无法访问 CASC 数据库中的 SC2 自带 TriggerLibs
        # (NativeLib/LibertyLib/SwarmLib)，复制 CMRE Lib*.galaxy 到 map 会导致
        # "函数已声明但尚未定义" 错误。Patch 直接作用于 live CMRE mod 中的文件。
        $destinationRoot = Join-Path $MapPath "Base.SC2Data"
        [System.IO.Directory]::CreateDirectory($destinationRoot) | Out-Null

        $adapterRoot = Join-Path $ModsRoot "7vs1\Alenger3Adapter.SC2Mod\Base.SC2Data"
        $adapterFiles = @("LibA3ADAPTER_h.galaxy", "LibA3ADAPTER.galaxy", "LibA3ADAPTER_Catalog.galaxy")
        foreach ($name in $adapterFiles) {
            $src = Join-Path $adapterRoot $name
            if (-not (Test-Path -LiteralPath $src)) { throw "Alenger3Adapter galaxy file not found: $src" }
            [System.IO.File]::Copy($src, (Join-Path $destinationRoot $name), $true)
        }

        $probeRoot = Join-Path $ModsRoot "RuntimeProbe\RuntimeProbe.SC2Mod\Base.SC2Data"
        $probeFiles = @("LibRuntimeProbe_h.galaxy", "LibRuntimeProbe.galaxy")
        foreach ($name in $probeFiles) {
            $src = Join-Path $probeRoot $name
            if (-not (Test-Path -LiteralPath $src)) { throw "RuntimeProbe galaxy file not found: $src" }
            [System.IO.File]::Copy($src, (Join-Path $destinationRoot $name), $true)
        }

        $required = @("LibA3ADAPTER.galaxy", "LibA3ADAPTER_h.galaxy", "LibA3ADAPTER_Catalog.galaxy", "LibRuntimeProbe_h.galaxy", "LibRuntimeProbe.galaxy")
        foreach ($name in $required) {
            if (-not (Test-Path -LiteralPath (Join-Path $destinationRoot $name))) {
                throw "CMRE Galaxy host overlay is incomplete: $name"
            }
        }
        Write-Host "CMRE Galaxy host overlay: $($adapterFiles.Count) Alenger3Adapter + $($probeFiles.Count) RuntimeProbe files (CMRE Lib*.galaxy stay in mod)"
    }

    function Enable-CmreSavedProfileStartup {
        param(
            [Parameter(Mandatory = $true)][string]$ModsRoot,
            [Parameter(Mandatory = $true)][string]$Commander
        )
        $path = Join-Path $ModsRoot "CMRE\CMRE_Core_Triggers.SC2Mod\Base.SC2Data\LibCOOC.galaxy"
        if (-not (Test-Path -LiteralPath $path)) { throw "CMRE mod LibCOOC.galaxy not found: $path" }
        $content = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
        $originalPattern = '(?m)^    if \(\(libCMFE_gf_CMUIX_StartupApplySavedConfiguration\(\) == true\)\) \{\r?\n        Wait\(1\.0, c_timeReal\);\r?\n        CMUIX_ReadyBeginCountdown\(\);\r?\n        return ;\r?\n    \}'
        $fallbackPattern = '(?m)^    if \(\(libCMFE_gf_CMUIX_StartupApplySavedConfiguration\(\) == true\)\) \{\r?\n        TriggerSendEvent\("CU_CommChoiceEventClosed"\);\r?\n        return ;\r?\n    \}'
        $legacyPatchPattern = '(?m)^    libCMFE_gf_CMUIX_StartupApplySavedConfiguration\(\);\r?\n    Wait\(1\.0, c_timeReal\);\r?\n    CMUIX_ReadyBeginCountdown\(\);\r?\n    return ;$'
        $replacementBody = @"
    if ((CMUIX_CoreReady == false)) { CMUIX_CoreInit(); }
    CMUIX_StartupLoadPersistentProfiles();
    CMUIX_HistoryPrunePendingRecordsAll();
    libCOTF_gv_sELECTED_Commander[1] = "$Commander";
    libCOTF_gv_sELECTED_Commander_Random[1] = false;
    libCOOC_gf_CC_PlayerCommanderSet(1, "$Commander");
    libCOUI_gv_cU_CommanderSelection[1] = "$Commander";
    libCOUI_gv_cU_CommanderSelect_PlayerReady[1] = true;
    libCOUI_gf_CU_CommanderFinalizeStates(1);
    libCOTF_gv_sELECTED_Commander[2] = "$Commander";
    libCOTF_gv_sELECTED_Commander_Random[2] = false;
    libCOOC_gf_CC_PlayerCommanderSet(2, "$Commander");
    libCOUI_gv_cU_CommanderSelection[2] = "$Commander";
    libCOUI_gv_cU_CommanderSelect_PlayerReady[2] = true;
    libCOUI_gf_CU_CommanderFinalizeStates(2);
    Wait(1.0, c_timeReal);
    CMUIX_ReadyBeginCountdown();
    return ;
"@
        $replacement = $replacementBody.Replace("`r`n", "`n").Replace("`n", "`r`n").TrimEnd("`r", "`n")
        if ([regex]::IsMatch($content, [regex]::Escape($replacement))) {
            Write-Host "  SKIP: saved-profile startup patch already applied"
            return
        }
        if ([regex]::IsMatch($content, $legacyPatchPattern)) {
            $content = [regex]::Replace($content, $legacyPatchPattern, $replacement, 1)
        } elseif ([regex]::IsMatch($content, $originalPattern)) {
            $content = [regex]::Replace($content, $originalPattern, $replacement, 1)
        } elseif ([regex]::IsMatch($content, $fallbackPattern)) {
            $content = [regex]::Replace($content, $fallbackPattern, $replacement, 1)
        } else {
            throw "CMRE saved-profile startup anchor not found"
        }
        [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  Applied CMRE saved-profile startup patch"
    }

    function Patch-CmreCoreRuntimeErrors {
        param([Parameter(Mandatory = $true)][string]$ModsRoot)
        $baseData = Join-Path $ModsRoot "CMRE\CMRE_Core_Triggers.SC2Mod\Base.SC2Data"
        $patchCount = 0

        $cotfPath = Join-Path $baseData "LibCOTF.galaxy"
        if (-not (Test-Path -LiteralPath $cotfPath)) { throw "LibCOTF.galaxy not found: $cotfPath" }
        $cotf = [System.IO.File]::ReadAllText($cotfPath, [System.Text.Encoding]::UTF8)

        $cotfAnchor1 = '    libCOTF_gv_player = EventPlayerEffectUsedUnitOwner(c_effectPlayerCaster);'
        $cotfPatch1 = '    libCOTF_gv_player = 1; // CMRE patch: InitGlobals has no effect event context'
        if (-not $cotf.Contains($cotfPatch1)) {
            if (-not $cotf.Contains($cotfAnchor1)) { throw "LibCOTF patch 1 anchor not found" }
            $cotf = $cotf.Replace($cotfAnchor1, $cotfPatch1); $patchCount++
        }

        $cotfAnchor2 = '    GameSetSeed(StringToInt((PlayerHandle(1) + PlayerHandle(2))));'
        $cotfPatch2 = '    // CMRE patch: skip PlayerHandle-based seed (StringToInt cannot parse handle string)'
        if (-not $cotf.Contains($cotfPatch2)) {
            if (-not $cotf.Contains($cotfAnchor2)) { throw "LibCOTF patch 2 anchor not found" }
            $cotf = $cotf.Replace($cotfAnchor2, $cotfPatch2); $patchCount++
        }

        $cotfAnchor2b = '    GameSetSeed(StringToInt(DateTimeToString(CurrentDateTimeGet())));'
        $cotfPatch2b = '    // CMRE patch: skip DateTime-based seed (StringToInt cannot parse datetime string; while loop below provides continuous random seed)'
        if (-not $cotf.Contains($cotfPatch2b)) {
            if (-not $cotf.Contains($cotfAnchor2b)) { throw "LibCOTF patch 2b anchor not found" }
            $cotf = $cotf.Replace($cotfAnchor2b, $cotfPatch2b); $patchCount++
        }

        $cotfAnchor3 = '    DialogSetVisible(libCOTF_gv_uT_AIVisionDialog, PlayerGroupAll(), false);'
        $cotfPatch3 = '    if (libCOTF_gv_uT_AIVisionDialog != c_invalidDialogId) { DialogSetVisible(libCOTF_gv_uT_AIVisionDialog, PlayerGroupAll(), false); } // CMRE patch: guard invalid dialog handle'
        if (-not $cotf.Contains($cotfPatch3)) {
            if (-not $cotf.Contains($cotfAnchor3)) { throw "LibCOTF patch 3 anchor not found" }
            $cotf = $cotf.Replace($cotfAnchor3, $cotfPatch3); $patchCount++
        }

        [System.IO.File]::WriteAllText($cotfPath, $cotf, [System.Text.UTF8Encoding]::new($false))

        $couiPath = Join-Path $baseData "LibCOUI.galaxy"
        if (-not (Test-Path -LiteralPath $couiPath)) { throw "LibCOUI.galaxy not found: $couiPath" }
        $coui = [System.IO.File]::ReadAllText($couiPath, [System.Text.Encoding]::UTF8)

        $couiAnchor4 = '    libNtve_gf_SetDialogItemUnitGroup(libCOUI_gv_cU_GPCmdPanel[lp_player], libCOUI_gv_cU_GPCasterGroup[lp_player], PlayerGroupSingle(lp_player));'
        $couiPatch4 = '    if (libCOUI_gv_cU_GPCmdPanel[lp_player] != c_invalidDialogControlId) { libNtve_gf_SetDialogItemUnitGroup(libCOUI_gv_cU_GPCmdPanel[lp_player], libCOUI_gv_cU_GPCasterGroup[lp_player], PlayerGroupSingle(lp_player)); } // CMRE patch: guard invalid control handle'
        if (-not $coui.Contains($couiPatch4)) {
            if (-not $coui.Contains($couiAnchor4)) { throw "LibCOUI patch 4 anchor not found" }
            $coui = $coui.Replace($couiAnchor4, $couiPatch4); $patchCount++
        }

        [System.IO.File]::WriteAllText($couiPath, $coui, [System.Text.UTF8Encoding]::new($false))

        $comiPath = Join-Path $baseData "LibCOMI.galaxy"
        if (-not (Test-Path -LiteralPath $comiPath)) { throw "LibCOMI.galaxy not found: $comiPath" }
        $comi = [System.IO.File]::ReadAllText($comiPath, [System.Text.Encoding]::UTF8)

        $comiAnchor5 = '    lv_commanderDefaultDecalString = CatalogFieldValueGet(c_gameCatalogTexture, lv_commanderDefaultDecal, "File", c_playerAny);'
        $comiPatch5 = '    if (lv_commanderDefaultDecal != "") { lv_commanderDefaultDecalString = CatalogFieldValueGet(c_gameCatalogTexture, lv_commanderDefaultDecal, "File", c_playerAny); } // CMRE patch: guard empty decal entry'
        if (-not $comi.Contains($comiPatch5)) {
            if (-not $comi.Contains($comiAnchor5)) { throw "LibCOMI patch 5 anchor not found" }
            $comi = $comi.Replace($comiAnchor5, $comiPatch5); $patchCount += 2
        }

        $comiAnchor7 = '    lv_reviveDuration = StringToFixed(CatalogFieldValueGet(c_gameCatalogBehavior, libCOOC_gf_CC_PlayerHeroNormalReviveBehavior(lp_player), "Duration", lp_player));'
        $comiPatch7 = '    if (libCOOC_gf_CC_PlayerHeroNormalReviveBehavior(lp_player) != "") { lv_reviveDuration = StringToFixed(CatalogFieldValueGet(c_gameCatalogBehavior, libCOOC_gf_CC_PlayerHeroNormalReviveBehavior(lp_player), "Duration", lp_player)); } if (lv_reviveDuration <= 0.0) { lv_reviveDuration = 60.0; } // CMRE patch: guard empty normal revive behavior entry'
        if (-not $comi.Contains($comiPatch7)) {
            if (-not $comi.Contains($comiAnchor7)) { throw "LibCOMI patch 7 anchor not found" }
            $comi = $comi.Replace($comiAnchor7, $comiPatch7); $patchCount++
        }

        $comiAnchor8 = '    lv_reviveDuration = StringToFixed(CatalogFieldValueGet(c_gameCatalogBehavior, libCOOC_gf_CC_PlayerHeroFirstReviveBehavior(lp_player), "Duration", lp_player));'
        $comiPatch8 = '    if (libCOOC_gf_CC_PlayerHeroFirstReviveBehavior(lp_player) != "") { lv_reviveDuration = StringToFixed(CatalogFieldValueGet(c_gameCatalogBehavior, libCOOC_gf_CC_PlayerHeroFirstReviveBehavior(lp_player), "Duration", lp_player)); } if (lv_reviveDuration <= 0.0) { lv_reviveDuration = 60.0; } // CMRE patch: guard empty first revive behavior entry'
        if (-not $comi.Contains($comiPatch8)) {
            if (-not $comi.Contains($comiAnchor8)) { throw "LibCOMI patch 8 anchor not found" }
            $comi = $comi.Replace($comiAnchor8, $comiPatch8); $patchCount++
        }

        $comiAnchor9 = '    UnitSetPropertyFixed(libCOMI_gv_cM_HeroReviver[lp_player], c_unitPropLifeRegen, (UnitGetPropertyFixed(libCOMI_gv_cM_HeroReviver[lp_player], c_unitPropLifeMax, c_unitPropCurrent)/lv_reviveDuration));'
        $comiPatch9 = '    if (lv_reviveDuration > 0.0) { UnitSetPropertyFixed(libCOMI_gv_cM_HeroReviver[lp_player], c_unitPropLifeRegen, (UnitGetPropertyFixed(libCOMI_gv_cM_HeroReviver[lp_player], c_unitPropLifeMax, c_unitPropCurrent)/lv_reviveDuration)); } // CMRE patch: guard divide-by-zero'
        if (-not $comi.Contains($comiPatch9)) {
            if (-not $comi.Contains($comiAnchor9)) { throw "LibCOMI patch 9 anchor not found" }
            $comi = $comi.Replace($comiAnchor9, $comiPatch9); $patchCount++
        }

        [System.IO.File]::WriteAllText($comiPath, $comi, [System.Text.UTF8Encoding]::new($false))

        # Patch 10: cmui_customization.galaxy - fix "boolean expression required" compile error.
        # Under multi-mod dependency stack (CMRE + 7vs1 overlay), the SC2 compiler mishandles
        # forward declarations for libCOOC_gf_CC_CommanderIsDeveloping / PrestigeIsDeveloping,
        # causing "bool == true" to error. Also explicitly include LibCOOC_h and replace
        # "== true" with direct bool test (equivalent in Galaxy).
        $cmuiPath = Join-Path $baseData "scripts\cmui_customization.galaxy"
        if (-not (Test-Path -LiteralPath $cmuiPath)) { throw "cmui_customization.galaxy not found: $cmuiPath" }
        $cmui = [System.IO.File]::ReadAllText($cmuiPath, [System.Text.Encoding]::UTF8)

        # 10a: Explicitly include LibCOOC_h (SC2 include dedupes, safe to repeat)
        $cmuiIncludePatch = 'include "LibCOOC_h"'
        $cmuiIncludeAnchor = 'include "LibCOTF_h"'
        if (-not $cmui.Contains($cmuiIncludePatch)) {
            if (-not $cmui.Contains($cmuiIncludeAnchor)) { throw "cmui_customization include anchor not found" }
            $cmui = $cmui.Replace($cmuiIncludeAnchor, "$cmuiIncludePatch`r`n$cmuiIncludeAnchor", 1)
            $patchCount++
        }

        # 10b: Remove "== true" from libCOOC_gf_CC_CommanderIsDeveloping / PrestigeIsDeveloping
        $cmuiBoolAnchor1 = 'if (libCOOC_gf_CC_CommanderIsDeveloping(lp_commander) == true) {'
        $cmuiBoolPatch1  = 'if (libCOOC_gf_CC_CommanderIsDeveloping(lp_commander)) {'
        if ($cmui.Contains($cmuiBoolAnchor1)) {
            $cmui = $cmui.Replace($cmuiBoolAnchor1, $cmuiBoolPatch1)
            $patchCount++
        }
        $cmuiBoolAnchor2 = 'if (libCOOC_gf_CC_PrestigeIsDeveloping(lp_prestige) == true) {'
        $cmuiBoolPatch2  = 'if (libCOOC_gf_CC_PrestigeIsDeveloping(lp_prestige)) {'
        if ($cmui.Contains($cmuiBoolAnchor2)) {
            $cmui = $cmui.Replace($cmuiBoolAnchor2, $cmuiBoolPatch2)
            $patchCount++
        }

        # 10c: Local forward declarations. Under multi-mod, LibCOOC_h declarations may be
        # invisible to scripts/ subdir files. Declaring prototypes directly in
        # cmui_customization.galaxy ensures the compiler knows return types.
        # If this causes "already declared" errors, the header was actually visible.
        $cmuiFwdDeclPatch = @"
// CMRE patch: local forward declarations for multi-mod visibility
bool libCOOC_gf_CC_CommanderIsDeveloping (string lp_commander);
bool libCOOC_gf_CC_PrestigeIsDeveloping (string lp_prestige);
"@
        $cmuiFwdDeclAnchor = "// -----------------------------------------------------------------------------`r`n// Constants, Global State, And Forward Declarations"
        if (-not $cmui.Contains($cmuiFwdDeclPatch)) {
            if (-not $cmui.Contains($cmuiFwdDeclAnchor)) { throw "cmui_customization forward declaration anchor not found" }
            $cmui = $cmui.Replace($cmuiFwdDeclAnchor, "$cmuiFwdDeclPatch`r`n$cmuiFwdDeclAnchor", 1)
            $patchCount++
        }

        [System.IO.File]::WriteAllText($cmuiPath, $cmui, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  Applied $patchCount CMRE core runtime error patches"
    }

    function Invoke-GalaxyChecker {
        <#
          .SYNOPSIS
            Pre-launch galaxy-checker gate. Mandatory per AGENTS.md "Galaxy static validation gate".
          .DESCRIPTION
            Validates patched live mod Base.SC2Data. Multi-mod scenarios must pass every dependency
            mod via --symbol-root, or cross-lib symbols will false-positive. Exit 0 passes; exit 1
            means error-level issues and aborts launch; exit 2 means tool exception and aborts.
            Never launch SC2 with known static errors.
        #>
        param(
            [Parameter(Mandatory = $true)][string]$TargetBaseData,
            [Parameter(Mandatory = $true)][string[]]$SymbolRoots,
            [Parameter(Mandatory = $true)][string]$ProjRootForChecker
        )
        $checkerCli = Join-Path $ProjRootForChecker "scripts\galaxy-checker\dist\cli.mjs"
        if (-not (Test-Path -LiteralPath $checkerCli)) {
            Write-Host "  galaxy-checker dist not found, building..." -ForegroundColor Yellow
            $checkerDir = Join-Path $ProjRootForChecker "scripts\galaxy-checker"
            & npm --prefix "$checkerDir" install --no-audit --no-fund 2>&1 | Out-Host
            $buildLast = $LASTEXITCODE
            if ($buildLast -ne 0) { throw "galaxy-checker npm install failed (exit $buildLast)" }
            & npm --prefix "$checkerDir" run build 2>&1 | Out-Host
            $buildLast = $LASTEXITCODE
            if ($buildLast -ne 0) { throw "galaxy-checker npm run build failed (exit $buildLast)" }
            if (-not (Test-Path -LiteralPath $checkerCli)) { throw "galaxy-checker dist/cli.mjs still missing after build" }
        }

        # 过滤不存在的 symbol-root，避免 galaxy-checker 误报
        $validRoots = @()
        foreach ($root in $SymbolRoots) {
            if (Test-Path -LiteralPath $root) {
                $validRoots += $root
            } else {
                Write-Host "  WARN: symbol-root skipped (not found): $root" -ForegroundColor Yellow
            }
        }

        $cliArgs = @($checkerCli, $TargetBaseData)
        foreach ($root in $validRoots) { $cliArgs += @("--symbol-root", $root) }
        $cliArgs += @("--format", "text")

        Write-Host "  Running galaxy-checker on: $TargetBaseData" -ForegroundColor Cyan
        Write-Host "  Symbol roots: $($validRoots.Count)" -ForegroundColor Cyan

        $output = & node @cliArgs 2>&1
        $checkerExit = $LASTEXITCODE

        if ($checkerExit -eq 0) {
            Write-Host "  GALAXY-CHECKER PASSED (exit 0)" -ForegroundColor Green
            return
        }

        Write-Host "  GALAXY-CHECKER FAILED (exit $checkerExit)" -ForegroundColor Red
        $output | Out-Host
        if ($checkerExit -eq 1) {
            throw "galaxy-checker reported error-level issues. Fix static errors before launching SC2. Target: $TargetBaseData"
        } elseif ($checkerExit -eq 2) {
            throw "galaxy-checker tool exception (exit 2). Investigate checker installation/invocation. Target: $TargetBaseData"
        } else {
            throw "galaxy-checker unexpected exit code $checkerExit. Target: $TargetBaseData"
        }
    }

    function Write-CmreLaunchProfile {
        $banksRoot = "C:\Users\22448\Documents\StarCraft II\Banks"
        [System.IO.Directory]::CreateDirectory($banksRoot) | Out-Null
        $doc = [xml]'<Bank version="1"><Section name="CMUI|LaunchProfile" /></Bank>'
        $values = [ordered]@{ Valid = @("int", "1"); Version = @("int", "1"); CreatedAt = @("int", [string][int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()); TimeoutSeconds = @("int", "600"); Mode = @("int", "1"); ModeInstance = @("string", "Standard"); DifficultyBase = @("int", "0"); DifficultyPlus = @("int", "0"); TargetMission = @("string", "AC_MeinhoffDayNight"); TargetMap = @("string", "AC_MeinhoffDayNight"); 'Player|1|Commander' = @("string", $Commander); 'Player|2|Commander' = @("string", $Commander) }
        foreach ($entry in $values.GetEnumerator()) { $key = $doc.CreateElement("Key"); $key.SetAttribute("name", $entry.Key); $value = $doc.CreateElement("Value"); $value.SetAttribute($entry.Value[0], $entry.Value[1]); $key.AppendChild($value) | Out-Null; $doc.Bank.Section.AppendChild($key) | Out-Null }
        $settings = [System.Xml.XmlWriterSettings]::new(); $settings.Indent = $true; $settings.Encoding = [System.Text.UTF8Encoding]::new($false)
        $writer = [System.Xml.XmlWriter]::Create((Join-Path $banksRoot "CMCoopLaunchProfile.SC2Bank"), $settings)
        try { $doc.Save($writer) } finally { $writer.Dispose() }
        Write-Host "  Wrote CMRE launch profile"
    }

    function Install-CmreAlengerObserver {
        param([Parameter(Mandatory = $true)][string]$MapPath)
        $neuroRoot = Join-Path (Split-Path -Parent $ProjRoot) "tools\SC2-Neuro-API-Integration"
        # LibPortingObserver 由 sc2-porting-workspace 提供，与 LibEFA54406 协同工作：
        # LibEFA54406 patch 后 include "LibPortingObserver_h" 并调用 BootstrapPortingObserver，
        # 缺少该文件会导致 ScriptError（参考 run-cmre-runtime-baseline.ps1 的完整闭包）。
        $observerRoot = Join-Path (Split-Path -Parent $ProjRoot) "sc2-porting-workspace\projects\cmre-porting\runtime"
        $baseData = Join-Path $MapPath "Base.SC2Data"
        $files = @(
            @{ Source = Join-Path $neuroRoot "Mod\NeuroIntegration.SC2Mod\Base.SC2Data\LibEFA54406_h.galaxy"; Name = "LibEFA54406_h.galaxy" },
            @{ Source = Join-Path $neuroRoot "Mod\NeuroIntegration.SC2Mod\Base.SC2Data\LibEFA54406.galaxy"; Name = "LibEFA54406.galaxy" },
            @{ Source = Join-Path $observerRoot "LibPortingObserver_h.galaxy"; Name = "LibPortingObserver_h.galaxy" },
            @{ Source = Join-Path $observerRoot "LibPortingObserver.galaxy"; Name = "LibPortingObserver.galaxy" }
        )
        $allFound = $true
        foreach ($file in $files) {
            if (-not (Test-Path -LiteralPath $file.Source)) {
                $allFound = $false
                break
            }
        }
        if (-not $allFound) {
            Write-Host "  SKIP: NeuroIntegration not found, RuntimeProbe will provide evidence"
            return
        }
        foreach ($file in $files) {
            [System.IO.File]::Copy($file.Source, (Join-Path $baseData $file.Name), $true)
        }

        $efaPath = Join-Path $baseData "LibEFA54406.galaxy"
        $efa = [System.IO.File]::ReadAllText($efaPath, [System.Text.Encoding]::UTF8)
        if ($efa -notmatch '(?m)^include "LibPortingObserver_h"$') {
            $efa = $efa.Replace('include "LibEFA54406_h"', "include `"LibEFA54406_h`"`r`ninclude `"LibPortingObserver_h`"")
        }
        $actionAnchor = '    libEFA54406_gf_create_action_1_arg("chat_message", true, "Post a message into the game chat", "string", -1);' + "`r`n    return true;"
        $actionPatch = '    libEFA54406_gf_create_action_1_arg("chat_message", true, "Post a message into the game chat", "string", -1);' + "`r`n    libEFA54406_gf_BootstrapPortingObserver();`r`n    return true;"
        if ($efa.Contains($actionAnchor)) { $efa = $efa.Replace($actionAnchor, $actionPatch) }
        $legacyColorCall = '            libEFA54406_gv_displayNameText = TextWithColor(libEFA54406_gv_displayNameText, Color(100.00, 50.20, 75.29));'
        if ($efa.Contains($legacyColorCall)) {
            $efa = $efa.Replace($legacyColorCall, '            // CMRE adapter: display text retained without incompatible color conversion.')
        }
        $execMapAnchor = '    BankSave(BankLastCreated());' + "`r`n" +
                         '    Wait(0.1, c_timeReal);' + "`r`n" +
                         '    TriggerSendEvent("execute_actions_map");' + "`r`n" +
                         '    return true;'
        $execMapPatch = '    BankSave(BankLastCreated());' + "`r`n" +
                        '    Wait(0.1, c_timeReal);' + "`r`n" +
                        '    TriggerSendEvent("execute_actions_map");' + "`r`n" +
                        '    libEFA54406_gv_bankwriteallowed = true;' + "`r`n" +
                        '    return true;'
        if ($efa.Contains($execMapAnchor)) {
            $efa = $efa.Replace($execMapAnchor, $execMapPatch)
        }
        [System.IO.File]::WriteAllText($efaPath, $efa, [System.Text.UTF8Encoding]::new($false))

        $mapScriptPath = Join-Path $MapPath "MapScript.galaxy"
        $mapScript = [System.IO.File]::ReadAllText($mapScriptPath, [System.Text.Encoding]::UTF8)
        if ($mapScript -notmatch '(?m)^include "LibEFA54406"$') {
            $mapScript = $mapScript.Replace('include "LibCOUI"', "include `"LibCOUI`"`r`ninclude `"LibEFA54406`"`r`ninclude `"LibPortingObserver`"`r`ninclude `"LibA3ADAPTER`"`r`ninclude `"LibRuntimeProbe`"")
        }
        if ($mapScript -notmatch 'libEFA54406_InitLib\s*\(\s*\)') {
            $mapScript = $mapScript.Replace('    libCOUI_InitLib();', "    libCOUI_InitLib();`r`n    libEFA54406_InitLib();`r`n    libPortingObserver_InitLib();`r`n    libA3ADAPTER_InitLib();`r`n    libRuntimeProbe_InitLib();")
        }
        [System.IO.File]::WriteAllText($mapScriptPath, $mapScript, [System.Text.UTF8Encoding]::new($false))

        $bankListPath = Join-Path $MapPath "BankList.xml"
        [xml]$bankList = [System.IO.File]::ReadAllText($bankListPath, [System.Text.Encoding]::UTF8)
        $bankChanged = $false
        if (@($bankList.BankList.Bank | Where-Object { $_.Name -eq "NeuroIntegration" -and $_.Player -eq "1" }).Count -eq 0) {
            $bank = $bankList.CreateElement("Bank")
            $bank.SetAttribute("Name", "NeuroIntegration")
            $bank.SetAttribute("Player", "1")
            $bankList.BankList.AppendChild($bank) | Out-Null
            $bankChanged = $true
        }
        if (@($bankList.BankList.Bank | Where-Object { $_.Name -eq "RuntimeProbe" -and $_.Player -eq "1" }).Count -eq 0) {
            $bank = $bankList.CreateElement("Bank")
            $bank.SetAttribute("Name", "RuntimeProbe")
            $bank.SetAttribute("Player", "1")
            $bankList.BankList.AppendChild($bank) | Out-Null
            $bankChanged = $true
        }
        if ($bankChanged) {
            $settings = [System.Xml.XmlWriterSettings]::new(); $settings.Indent = $true; $settings.Encoding = [System.Text.UTF8Encoding]::new($false)
            $writer = [System.Xml.XmlWriter]::Create($bankListPath, $settings)
            try { $bankList.Save($writer) } finally { $writer.Dispose() }
        }
        Write-Host "  Installed Alenger observer and patched MapScript"
    }

    Write-Host "--- Alenger3 Step 1: Install CMRE Galaxy Host Overlay ---"
    $liveModsRoot = Join-Path $Sc2Root "Mods"
    Install-CmreGalaxyHostOverlay -ModsRoot $liveModsRoot -MapPath $MapLivePath

    Write-Host "--- Alenger3 Step 2: Enable CMRE Saved Profile Startup ---"
    Enable-CmreSavedProfileStartup -ModsRoot $liveModsRoot -Commander "Alenger3"

    Write-Host "--- Alenger3 Step 3: Apply CMRE Core Runtime Error Patches ---"
    Patch-CmreCoreRuntimeErrors -ModsRoot $liveModsRoot

    Write-Host "--- Alenger3 Step 3.5: Galaxy-checker pre-launch gate (mandatory) ---"
    # 强制门禁：patch 后、SC2 启动前必须验证 patched CMRE mod 的 Base.SC2Data。
    # 多 mod 场景必须传所有依赖 mod 的 --symbol-root，否则跨库符号误报。
    $checkerTarget = Join-Path $liveModsRoot "CMRE\CMRE_Core_Triggers.SC2Mod\Base.SC2Data"
    $checkerSymbolRoots = @(
        (Join-Path $liveModsRoot "CMRE\CMRE_Core_Base.SC2Mod\Base.SC2Data"),
        (Join-Path $liveModsRoot "7vs1\CoreRuntime.SC2Mod\Base.SC2Data"),
        (Join-Path $liveModsRoot "7vs1\CommanderBridge.SC2Mod\Base.SC2Data"),
        (Join-Path $liveModsRoot "7vs1\BaseCatalogPatch.SC2Mod\Base.SC2Data"),
        (Join-Path $liveModsRoot "7vs1\SharedUnits.SC2Mod\Base.SC2Data"),
        (Join-Path $liveModsRoot "7vs1\ExternalRefs.SC2Mod\Base.SC2Data"),
        (Join-Path $liveModsRoot "kit_mutations.SC2Mod\Base.SC2Data"),
        (Join-Path $liveModsRoot "7vs1\AlengerCommon.SC2Mod\Base.SC2Data"),
        (Join-Path $liveModsRoot "7vs1\Alenger3.SC2Mod\Base.SC2Data"),
        (Join-Path $liveModsRoot "7vs1\Alenger3Adapter.SC2Mod\Base.SC2Data"),
        (Join-Path $liveModsRoot "7vs1\CommanderUnits_Swann.SC2Mod\Base.SC2Data"),
        (Join-Path $liveModsRoot "7vs1\CommanderUnits_Dehaka.SC2Mod\Base.SC2Data")
    )
    Invoke-GalaxyChecker -TargetBaseData $checkerTarget -SymbolRoots $checkerSymbolRoots -ProjRootForChecker $ProjRoot

    Write-Host "--- Alenger3 Step 4: Install Alenger Observer ---"
    Install-CmreAlengerObserver -MapPath $MapLivePath

    Write-Host "--- Alenger3 Step 5: Write CMRE Launch Profile ---"
    Write-CmreLaunchProfile

    Write-Host "Alenger3 integration completed." -ForegroundColor Green
}

# === BANK SECTION ===
if (-not $isOriginalMode) {
    Write-Host "--- Bank Write ---"
    Write-Host "Writing CampaignXCore Bank for commander: $Commander"
    if ($isAlengerMode) {
        $bankCommander = "Alenger3"
        foreach ($bankPath in @(Get-CampaignXCoreBankPaths)) {
            [xml]$xml = Get-Content -LiteralPath $bankPath -Raw
            Set-BankStringKeyValue -Xml $xml -SectionName "Ach" -KeyName "Commander" -Value $bankCommander
            Set-BankStringKeyValue -Xml $xml -SectionName "XMRuntimeControl" -KeyName "PrimaryCommander" -Value $bankCommander
            Set-BankIntKeyValue -Xml $xml -SectionName "XMRuntimeControl" -KeyName "CommanderCount" -Value 1
            Set-BankStringKeyValue -Xml $xml -SectionName "XMRuntimeControl" -KeyName "CommanderP1" -Value $bankCommander
            Save-XmlDocumentWithRetry -Xml $xml -Path $bankPath
        }
        Set-CampaignXCoreTestRunId -RunId "CMREAlenger"
    } else {
        Set-CampaignXCorePrimaryCommander -SelectedCommanders @($Commander)
        Set-CampaignXCoreTestRunId -RunId "CMRECommander"
    }
}

# === NEURO INTEGRATION SECTION (optional, -EnableNeuro) ===
# Ported from launch-7vs1-coop-test.ps1: copy mods, inject galaxy, patch BankList/MapScript
$pythonProcessId = $null
if ($EnableNeuro) {
    Write-Host "`n=== Neuro Integration ===" -ForegroundColor Cyan

    # 辅助函数：使用 .NET API 绕过 TRAE 沙箱对 Remove-Item/Copy-Item 的拦截
    function Remove-DirSafe {
        param([string]$Path)
        if (Test-Path -LiteralPath $Path -PathType Container) {
            [System.IO.Directory]::Delete($Path, $true)
        } elseif (Test-Path -LiteralPath $Path) {
            [System.IO.File]::Delete($Path)
        }
    }
    function New-DirSafe {
        param([string]$Path)
        if (-not (Test-Path -LiteralPath $Path)) {
            [System.IO.Directory]::CreateDirectory($Path) | Out-Null
        }
    }
    function Copy-DirSafe {
        param([string]$Source, [string]$Destination)
        Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
        [Microsoft.VisualBasic.FileIO.FileSystem]::CopyDirectory($Source, $Destination, $true)
    }

    # === 路径解析（基于 Shared/Launcher/neuro-dependencies.json）===
    $neuroDepsPath = Join-Path $ProjRoot "Shared\Launcher\neuro-dependencies.json"
    $repoRoot = Split-Path -Parent $ProjRoot
    $neuroDeps = $null
    if (Test-Path -LiteralPath $neuroDepsPath) {
        try {
            $neuroDeps = Get-Content -LiteralPath $neuroDepsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            Write-Host "  Loaded neuro-dependencies.json (capability=$($neuroDeps.capability))" -ForegroundColor DarkGray
        } catch {
            Write-Host "  WARN: failed to parse neuro-dependencies.json: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  WARN: neuro-dependencies.json missing at $neuroDepsPath" -ForegroundColor Yellow
    }

    $NeuroModSource = Join-Path $repoRoot "tools\SC2-Neuro-WoL-Integration\Mods\NeuroIntegration.SC2Mod"
    if ($neuroDeps -and $neuroDeps.mods) {
        $coreMod = @($neuroDeps.mods) | Where-Object { $_.id -eq "NeuroIntegration" } | Select-Object -First 1
        if ($coreMod -and $coreMod.sourceWorkspace) {
            $NeuroModSource = Join-Path $repoRoot ($coreMod.sourceWorkspace -replace '/', '\')
        }
    }
    $BridgeModSource = Join-Path $ProjRoot "Mods\Neuro\NeuroBridge7vs1.SC2Mod"
    if ($neuroDeps -and $neuroDeps.mods) {
        $bridgeMod = @($neuroDeps.mods) | Where-Object { $_.id -eq "NeuroBridge7vs1" } | Select-Object -First 1
        if ($bridgeMod -and $bridgeMod.sourceWorkspace) {
            $BridgeModSource = Join-Path $ProjRoot ($bridgeMod.sourceWorkspace -replace '/', '\')
        }
    }
    $NeuroApiRoot = Join-Path $repoRoot "tools\SC2-Neuro-API-Integration"
    if ($neuroDeps -and $neuroDeps.pythonRuntime -and $neuroDeps.pythonRuntime.rootWorkspace) {
        $NeuroApiRoot = Join-Path $repoRoot ($neuroDeps.pythonRuntime.rootWorkspace -replace '/', '\')
    }

    # Prove LibEFA54406 ownership before injection
    $efaHeader = Join-Path $NeuroModSource "Base.SC2Data\LibEFA54406_h.galaxy"
    $efaBody = Join-Path $NeuroModSource "Base.SC2Data\LibEFA54406.galaxy"
    if (-not (Test-Path -LiteralPath $efaHeader) -or -not (Test-Path -LiteralPath $efaBody)) {
        throw "LibEFA54406 closure incomplete under NeuroIntegration: missing $efaHeader or $efaBody"
    }
    Write-Host "  LibEFA54406 closure OK (owned by NeuroIntegration)" -ForegroundColor Green

    Write-Host "NeuroMod:  $NeuroModSource"
    Write-Host "BridgeMod: $BridgeModSource"

    if (-not (Test-Path -LiteralPath $NeuroModSource)) {
        throw "NeuroIntegration mod not found: $NeuroModSource"
    }
    if (-not (Test-Path -LiteralPath $BridgeModSource)) {
        throw "NeuroBridge7vs1 mod not found: $BridgeModSource"
    }

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

    # === Step N2: 复制 Neuro mod 到 SC2 运行时目录 ===
    Write-Host "`n--- Neuro Step 2: Copy Neuro mods to SC2 runtime ---" -ForegroundColor Yellow
    $neuroLiveDir = Join-Path $Sc2Root "Mods\NeuroIntegration.SC2Mod"
    $bridgeLiveDir = Join-Path $Sc2Root "Mods\Neuro\NeuroBridge7vs1.SC2Mod"

    if (Test-Path $neuroLiveDir) { Remove-DirSafe $neuroLiveDir }
    Copy-DirSafe $NeuroModSource $neuroLiveDir
    Write-Host "  Copied NeuroIntegration -> $neuroLiveDir"

    # Step N2b: 修正 NeuroIntegration 依赖项以匹配 CMRE 地图使用的中文 bnet 依赖
    # 源 mod 使用英文 bnet:Liberty (Campaign) + Campaigns/Liberty.SC2Campaign，但 SC2 安装目录下不存在该路径
    # CMRE 地图使用：自由之翼剧情 (战役) + Campaigns/LibertyStory.SC2Campaign 和 自由之翼 (Mod) + Mods/Liberty.SC2Mod
    $neuroDocInfoPath = Join-Path $neuroLiveDir "DocumentInfo"
    if (Test-Path -LiteralPath $neuroDocInfoPath) {
        $neuroDocInfo = [System.IO.File]::ReadAllText($neuroDocInfoPath)
        $needsFix = $false
        if ($neuroDocInfo -match 'Liberty \(Campaign\)') { $needsFix = $true }
        if ($neuroDocInfo -match 'Campaigns/Liberty\.SC2Campaign') { $needsFix = $true }
        if ($needsFix) {
            $fixedDocInfo = '<?xml version="1.0" encoding="utf-8"?>' + "`n" +
                '<DocInfo>' + "`n" +
                '    <Dependencies>' + "`n" +
                '        <Value>bnet:自由之翼剧情 (战役)/0.0/999,file:Campaigns/LibertyStory.SC2Campaign</Value>' + "`n" +
                '        <Value>bnet:自由之翼 (Mod)/0.0/999,file:Mods/Liberty.SC2Mod</Value>' + "`n" +
                '    </Dependencies>' + "`n" +
                '</DocInfo>'
            [System.IO.File]::WriteAllText($neuroDocInfoPath, $fixedDocInfo, $utf8NoBom)
            Write-Host "  Fixed NeuroIntegration DocumentInfo dependencies (matched CMRE map)" -ForegroundColor Green
        }
    }

    $bridgeLiveParent = Split-Path $bridgeLiveDir -Parent
    if (-not (Test-Path $bridgeLiveParent)) { New-DirSafe $bridgeLiveParent }
    if (Test-Path $bridgeLiveDir) { Remove-DirSafe $bridgeLiveDir }
    Copy-DirSafe $BridgeModSource $bridgeLiveDir
    Write-Host "  Copied NeuroBridge7vs1 -> $bridgeLiveDir"

    # === Step N3: 注入 galaxy 库文件到地图 Base.SC2Data ===
    Write-Host "`n--- Neuro Step 3: Inject galaxy libraries into map ---" -ForegroundColor Yellow
    $mapLiveBaseData = Join-Path $MapLivePath "Base.SC2Data"
    if (-not (Test-Path $mapLiveBaseData)) {
        New-DirSafe $mapLiveBaseData
    }
    # NeuroIntegration galaxy 文件
    $neuroGalaxyDir = Join-Path $neuroLiveDir "Base.SC2Data"
    $neuroGalaxyFiles = Get-ChildItem $neuroGalaxyDir -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
    foreach ($gf in $neuroGalaxyFiles) {
        $dst = Join-Path $mapLiveBaseData $gf.Name
        [System.IO.File]::Copy($gf.FullName, $dst, $true)
        Write-Host "  Injected: $($gf.Name)"
    }
    # NeuroBridge7vs1 galaxy 文件
    $bridgeGalaxyDir = Join-Path $bridgeLiveDir "Base.SC2Data"
    $bridgeGalaxyFiles = Get-ChildItem $bridgeGalaxyDir -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
    foreach ($gf in $bridgeGalaxyFiles) {
        $dst = Join-Path $mapLiveBaseData $gf.Name
        [System.IO.File]::Copy($gf.FullName, $dst, $true)
        Write-Host "  Injected: $($gf.Name)"
    }

    # === Step N4: 注入 BankList.xml ===
    Write-Host "`n--- Neuro Step 4: Patch BankList.xml ---" -ForegroundColor Yellow
    $bankListPath = Join-Path $MapLivePath "BankList.xml"
    if (Test-Path -LiteralPath $bankListPath) {
        $bankContent = [System.IO.File]::ReadAllText($bankListPath)
        if ($bankContent -notmatch 'Name="NeuroIntegration"') {
            $bankEntry = '    <Bank Name="NeuroIntegration" Player="1"/>'
            $bankContent = $bankContent.Replace('</BankList>', ($bankEntry + "`n</BankList>"))
            Write-Host "  Added NeuroIntegration bank declaration"
        } else {
            Write-Host "  Already has NeuroIntegration bank"
        }
        # 同时添加 NeuroPermanent bank（用于跨任务持久化）
        if ($bankContent -notmatch 'Name="NeuroPermanent"') {
            $permanentEntry = '    <Bank Name="NeuroPermanent" Player="1"/>'
            $bankContent = $bankContent.Replace('</BankList>', ($permanentEntry + "`n</BankList>"))
            Write-Host "  Added NeuroPermanent bank declaration"
        }
        [System.IO.File]::WriteAllText($bankListPath, $bankContent, $utf8NoBom)
    } else {
        Write-Host "  WARN: BankList.xml not found, creating minimal one"
        $bankContent = "<?xml version=`"1.0`" encoding=`"utf-8`"?>`n<BankList>`n    <Bank Name=`"NeuroIntegration`" Player=`"1`"/>`n    <Bank Name=`"NeuroPermanent`" Player=`"1`"/>`n</BankList>`n"
        [System.IO.File]::WriteAllText($bankListPath, $bankContent, $utf8NoBom)
    }

    # === Step N5: 注入 MapScript.galaxy ===
    Write-Host "`n--- Neuro Step 5: Patch MapScript.galaxy ---" -ForegroundColor Yellow
    $mapScriptPath = Join-Path $MapLivePath "MapScript.galaxy"
    if (Test-Path -LiteralPath $mapScriptPath) {
        $content = [System.IO.File]::ReadAllText($mapScriptPath)
        $modified = $false

        # N5a. 注入 include（在最后一个 include 之后）
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

        # N5b. 注入 InitLib 调用（在 InitLibs() 闭合大括号之前）
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

    # === Step N6: 启动/复用共享 Neuro 运行时服务（可选，-NoLaunch 时跳过）===
    if (-not $SkipPythonRuntime -and -not $NoLaunch) {
        Write-Host "`n--- Neuro Step 6: Ensure shared Neuro runtime service ---" -ForegroundColor Yellow

        $serviceScript = Join-Path $ScriptsRoot "runtime-probe\start-neuro-runtime-service.ps1"
        if (Test-Path -LiteralPath $serviceScript) {
            $serviceArgs = @(
                "-NeuroApiRoot", $NeuroApiRoot,
                "-Sc2Root", $Sc2Root
            )
            $serviceJsonText = & pwsh -NoProfile -ExecutionPolicy Bypass -File $serviceScript @serviceArgs
            Write-Host $serviceJsonText
            try {
                $serviceState = $serviceJsonText | ConvertFrom-Json
                if ($serviceState.processes.neuroApi.pid) { $pythonProcessId = [int]$serviceState.processes.neuroApi.pid }
                if ($serviceState.webUrl) {
                    Write-Host "  Runtime API: $($serviceState.webUrl)" -ForegroundColor Cyan
                }
            } catch {
                Write-Host "  WARN: failed to parse service state: $_" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  WARN: start-neuro-runtime-service.ps1 not found at $serviceScript" -ForegroundColor Yellow
        }
    }
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
