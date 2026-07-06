<#
.SYNOPSIS
Split CommanderCatalog.SC2Mod into 6 independent mods.

.DESCRIPTION
Split by horizontal functional layering:
- BaseCatalogPatch.SC2Mod         Generic base patch
- CommanderUnits.SC2Mod           Lightweight commander unit data
- CommanderUnits_Stetmann.SC2Mod  Stetmann full implementation
- CommanderUnits_TychusXM.SC2Mod  TychusXM full implementation
- SharedUnits.SC2Mod              Cross-commander shared units
- ExternalRefs.SC2Mod             External extension data (Reborn + HexTalents)

The script calls global trae-*.ps1 wrapper scripts for file operations,
following the file-ops hard constraint.
#>
[CmdletBinding()]
param(
    [string]$TraeScriptRoot = "c:\Users\22448\.trae-cn\skills\file-ops\scripts"
)

$ErrorActionPreference = "Stop"

# Derive workspace root from script location (parent of scripts/ dir)
$WorkspaceRoot = Split-Path -Parent $PSScriptRoot

$sourceMod = Join-Path $WorkspaceRoot "Mods\7vs1\CommanderCatalog.SC2Mod"
$modsRoot = Join-Path $WorkspaceRoot "Mods\7vs1"

$traeMkdir = Join-Path $TraeScriptRoot "trae-mkdir.ps1"
$traeCp = Join-Path $TraeScriptRoot "trae-cp.ps1"
$traeMv = Join-Path $TraeScriptRoot "trae-mv.ps1"

if (-not (Test-Path -LiteralPath $traeMkdir)) { throw "trae-mkdir.ps1 not found: $traeMkdir" }
if (-not (Test-Path -LiteralPath $traeCp))    { throw "trae-cp.ps1 not found: $traeCp" }
if (-not (Test-Path -LiteralPath $traeMv))    { throw "trae-mv.ps1 not found: $traeMv" }

if (-not (Test-Path -LiteralPath $sourceMod)) {
    throw "Source mod not found: $sourceMod"
}

# ============================================================
# File classification
# ============================================================

$modFiles = @{
    "BaseCatalogPatch" = @(
        "AbilData.xml","ActorData.xml","BehaviorData.xml","ButtonData.xml",
        "EffectData.xml","MoverData.xml","RequirementData.xml",
        "RequirementNodeData.xml","UnitData.xml","UpgradeData.xml"
    )
    "CommanderUnits" = @(
        "AbilData_Abathur.xml","ActorData_Abathur.xml","BehaviorData_Abathur.xml",
        "EffectData_Abathur.xml","RequirementData_Abathur.xml","UnitData_Abathur.xml",
        "ValidatorData_Abathur.xml",
        "AbilData_Horner.xml","UnitData_Horner.xml",
        "AbilData_Kerrigan.xml","ActorData_Kerrigan.xml","BehaviorData_Kerrigan.xml",
        "EffectData_Kerrigan.xml","TargetSortData_Kerrigan.xml","UnitData_Kerrigan.xml",
        "UpgradeData_Kerrigan.xml",
        "AbilData_Nova.xml","ActorData_Nova.xml","BehaviorData_Nova.xml",
        "ButtonData_Nova.xml","EffectData_Nova.xml","MoverData_Nova.xml",
        "UnitData_Nova.xml",
        "AbilData_Raynor.xml","UnitData_Raynor.xml",
        "AbilData_RaynorX.xml","RequirementData_RaynorX.xml",
        "RequirementNodeData_RaynorX.xml","UnitData_RaynorX.xml","UpgradeData_RaynorX.xml",
        "UnitData_Alarak.xml","UnitData_Artanis.xml","UnitData_Dehaka.xml",
        "UnitData_Fenix.xml","UnitData_Karax.xml","UnitData_Mengsk.xml",
        "UnitData_Stukov.xml","UnitData_Swann.xml","UnitData_Vorazun.xml",
        "UnitData_Zagara.xml","UnitData_Zeratul.xml"
    )
    "CommanderUnits_Stetmann" = @(
        "AbilData_Stetmann.xml","ActorData_Stetmann.xml","AttachMethodData_Stetmann.xml",
        "BehaviorData_Stetmann.xml","ButtonData_Stetmann.xml","DataCollectionData_Stetmann.xml",
        "EffectData_Stetmann.xml","FootprintData_Stetmann.xml","ModelData_Stetmann.xml",
        "MoverData_Stetmann.xml","PlayerResponseData_Stetmann.xml","RaceData_Stetmann.xml",
        "RequirementData_Stetmann.xml","RequirementNodeData_Stetmann.xml",
        "RewardData_Stetmann.xml","SkinData_Stetmann.xml","SoundData_Stetmann.xml",
        "TargetSortData_Stetmann.xml","TurretData_Stetmann.xml","UnitData_Stetmann.xml",
        "UpgradeData_Stetmann.xml","UserData_Stetmann.xml","ValidatorData_Stetmann.xml",
        "WeaponData_Stetmann.xml"
    )
    "CommanderUnits_TychusXM" = @(
        "AbilData_TychusXM.xml","AccumulatorData_TychusXM.xml","ActorData_TychusXM.xml",
        "AttachMethodData_TychusXM.xml","BehaviorData_TychusXM.xml","ButtonData_TychusXM.xml",
        "CommanderData_TychusXM.xml","EffectData_TychusXM.xml","GameData_TychusXM.xml",
        "ModelData_TychusXM.xml","ModData_TychusXM.xml","MoverData_TychusXM.xml",
        "RequirementData_TychusXM.xml","RequirementNodeData_TychusXM.xml",
        "SkinData_TychusXM.xml","SoundData_TychusXM.xml","TargetSortData_TychusXM.xml",
        "TurretData_TychusXM.xml","UnitData_TychusXM.xml","UpgradeData_TychusXM.xml",
        "UserData_TychusXM.xml","ValidatorData_TychusXM.xml","WeaponData_TychusXM.xml"
    )
    "SharedUnits" = @(
        "UnitData_Shared_InfestedTerran.xml","UnitData_Shared_Neutral_H.xml",
        "UnitData_Shared_Neutral_I_M.xml","UnitData_Shared_Neutral_N_Z.xml",
        "UnitData_Shared_Protoss.xml","UnitData_Shared_PurifierZerg.xml",
        "UnitData_Shared_Terran_A_G.xml","UnitData_Shared_Terran_H.xml",
        "UnitData_Shared_Terran_I_V.xml","UnitData_Shared_Zerg.xml"
    )
    "ExternalRefs" = @(
        "ActorData_Reborn.xml","BehaviorData_Reborn.xml","ButtonData_Reborn.xml",
        "EffectData_Reborn.xml","ModelData_Reborn.xml","RequirementData_Reborn.xml",
        "RequirementNodeData_Reborn.xml","UnitData_Reborn.xml",
        "UpgradeData_Reborn.xml","WeaponData_Reborn.xml",
        "BehaviorData_HexTalents.xml","UpgradeData_HexTalents.xml"
    )
}

# Verify file classification
$allClassifiedFiles = $modFiles.Values | ForEach-Object { $_ } | Sort-Object -Unique
$sourceGameDataRoot = Join-Path $sourceMod "Base.SC2Data\GameData"
$sourceXmlFiles = Get-ChildItem -LiteralPath $sourceGameDataRoot -Filter "*.xml" -File | Select-Object -ExpandProperty Name | Sort-Object

$unclassified = $sourceXmlFiles | Where-Object { $_ -notin $allClassifiedFiles -and $_ -ne "GameData.xml" }
if ($unclassified.Count -gt 0) {
    Write-Warning "Unclassified XML files (will stay in source, need manual handling):"
    $unclassified | ForEach-Object { Write-Warning "  $_" }
}

$missingFiles = $allClassifiedFiles | Where-Object { $_ -notin $sourceXmlFiles }
if ($missingFiles.Count -gt 0) {
    throw "Classified files not found in source: $($missingFiles -join ', ')"
}

Write-Host "File classification verified: $($allClassifiedFiles.Count) files in $($modFiles.Count) mods"
Write-Host "Source XML files: $($sourceXmlFiles.Count)"

# ============================================================
# Create 6 new mod directory structures
# ============================================================

$newModNames = $modFiles.Keys | Sort-Object
$infraFiles = @("DocumentHeader","DocumentInfo.version","GameData.version","GameText.version")

foreach ($modName in $newModNames) {
    $modDir = Join-Path $modsRoot "$modName.SC2Mod"
    $gameDataDir = Join-Path $modDir "Base.SC2Data\GameData"
    $enUsDir = Join-Path $modDir "enUS.SC2Data\LocalizedData"
    $zhCnDir = Join-Path $modDir "zhCN.SC2Data\LocalizedData"

    & $traeMkdir $gameDataDir $enUsDir $zhCnDir | Out-Null

    foreach ($infraFile in $infraFiles) {
        $src = Join-Path $sourceMod $infraFile
        $dst = Join-Path $modDir $infraFile
        if (Test-Path -LiteralPath $src) {
            & $traeCp $src $dst | Out-Null
        }
    }

    Write-Host "Created mod structure: $modName"
}

# ============================================================
# Move XML files to each mod
# ============================================================

$movedCount = 0
foreach ($modName in $newModNames) {
    $targetGameDataDir = Join-Path $modsRoot "$modName.SC2Mod\Base.SC2Data\GameData"

    foreach ($fileName in $modFiles[$modName]) {
        $src = Join-Path $sourceGameDataRoot $fileName
        $dst = Join-Path $targetGameDataDir $fileName

        if (-not (Test-Path -LiteralPath $src)) {
            Write-Warning "Source file not found, skipping: $src"
            continue
        }

        & $traeMv $src $dst | Out-Null
        $movedCount++
    }

    Write-Host "Moved $($modFiles[$modName].Count) files to $modName"
}

Write-Host "Total moved: $movedCount files"

# ============================================================
# Copy localization files to BaseCatalogPatch
# ============================================================

$baseCatalogPatchDir = Join-Path $modsRoot "BaseCatalogPatch.SC2Mod"
$locales = @("enUS","zhCN")

foreach ($locale in $locales) {
    $srcLocaleDir = Join-Path $sourceMod "$locale.SC2Data\LocalizedData"
    $dstLocaleDir = Join-Path $baseCatalogPatchDir "$locale.SC2Data\LocalizedData"

    if (Test-Path -LiteralPath $srcLocaleDir) {
        $txtFiles = Get-ChildItem -LiteralPath $srcLocaleDir -Filter "*.txt" -File
        foreach ($txtFile in $txtFiles) {
            $dst = Join-Path $dstLocaleDir $txtFile.Name
            & $traeCp $txtFile.FullName $dst | Out-Null
        }
        Write-Host "Copied $($txtFiles.Count) $locale localization files to BaseCatalogPatch"
    }
}

# ============================================================
# Copy Preload.xml/PreloadAssetDB.txt to BaseCatalogPatch
# ============================================================

$preloadFiles = @("Preload.xml","PreloadAssetDB.txt")
foreach ($preloadFile in $preloadFiles) {
    $src = Join-Path $sourceMod $preloadFile
    $dst = Join-Path $baseCatalogPatchDir $preloadFile
    if (Test-Path -LiteralPath $src) {
        & $traeCp $src $dst | Out-Null
        Write-Host "Copied $preloadFile to BaseCatalogPatch"
    }
}

# ============================================================
# Report remaining files in source mod
# ============================================================

$remainingFiles = Get-ChildItem -LiteralPath $sourceMod -Recurse -File
Write-Host ""
Write-Host "Source mod remaining files: $($remainingFiles.Count)"
$remainingFiles | ForEach-Object { Write-Host "  $($_.FullName.Replace($sourceMod, ''))" }

Write-Host ""
Write-Host "Split completed. Next steps:"
Write-Host "  1. Create GameData.xml/DocumentInfo/ComponentList for each new mod"
Write-Host "  2. Migrate TriggerLibs 81FF3B49 to CoopZeroPop"
Write-Host "  3. Modify launch-7vs1-coop-test.ps1"
Write-Host "  4. Delete original CommanderCatalog.SC2Mod"
Write-Host "  5. Test with launch-7vs1-coop-test.ps1"
