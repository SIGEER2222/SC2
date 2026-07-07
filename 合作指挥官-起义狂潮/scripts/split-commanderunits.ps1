# Split CommanderUnits.SC2Mod into 17 per-commander mods.
# Pure ASCII to avoid codepage issues.

$ErrorActionPreference = "Stop"

$scriptsRoot = $PSScriptRoot
$workspaceRoot = Split-Path -Parent $scriptsRoot
$modsRoot = Join-Path $workspaceRoot "Mods\7vs1"
$sourceMod = Join-Path $modsRoot "CommanderUnits.SC2Mod"
$sourceGameData = Join-Path $sourceMod "Base.SC2Data\GameData"

if (-not (Test-Path -LiteralPath $sourceGameData)) {
    throw "Source GameData not found: $sourceGameData"
}

# Commander name -> list of XML file names
$commanderFiles = [ordered]@{
    "Abathur"  = @("AbilData_Abathur.xml","ActorData_Abathur.xml","BehaviorData_Abathur.xml","EffectData_Abathur.xml","RequirementData_Abathur.xml","UnitData_Abathur.xml","ValidatorData_Abathur.xml")
    "Horner"   = @("AbilData_Horner.xml","UnitData_Horner.xml")
    "Kerrigan" = @("AbilData_Kerrigan.xml","ActorData_Kerrigan.xml","BehaviorData_Kerrigan.xml","EffectData_Kerrigan.xml","TargetSortData_Kerrigan.xml","UnitData_Kerrigan.xml","UpgradeData_Kerrigan.xml")
    "Nova"     = @("AbilData_Nova.xml","ActorData_Nova.xml","BehaviorData_Nova.xml","ButtonData_Nova.xml","EffectData_Nova.xml","MoverData_Nova.xml","UnitData_Nova.xml")
    "Raynor"   = @("AbilData_Raynor.xml","UnitData_Raynor.xml")
    "RaynorX"  = @("AbilData_RaynorX.xml","RequirementData_RaynorX.xml","RequirementNodeData_RaynorX.xml","UnitData_RaynorX.xml","UpgradeData_RaynorX.xml")
    "Alarak"   = @("UnitData_Alarak.xml")
    "Artanis"  = @("UnitData_Artanis.xml")
    "Dehaka"   = @("UnitData_Dehaka.xml")
    "Fenix"    = @("UnitData_Fenix.xml")
    "Karax"    = @("UnitData_Karax.xml")
    "Mengsk"   = @("UnitData_Mengsk.xml")
    "Stukov"   = @("UnitData_Stukov.xml")
    "Swann"    = @("UnitData_Swann.xml")
    "Vorazun"  = @("UnitData_Vorazun.xml")
    "Zagara"   = @("UnitData_Zagara.xml")
    "Zeratul"  = @("UnitData_Zeratul.xml")
}

# Base dependencies (same as CommanderUnits original)
$baseDeps = @(
    "bnet:Void Multi (Mod)/0.0/999,file:Mods/Void.SC2Mod",
    "bnet:Co-op Mission/0.0/999,file:Mods/StarCoop.SC2Mod"
)

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-File {
    param([string]$path, [string]$content)
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent)) {
        [void][System.IO.Directory]::CreateDirectory($parent)
    }
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

function Create-ModInfrastructure {
    param([string]$modName)

    $modDir = Join-Path $modsRoot "$modName.SC2Mod"
    if (-not (Test-Path -LiteralPath $modDir)) {
        [void][System.IO.Directory]::CreateDirectory($modDir)
    }

    # DocumentInfo
    $depsXml = ""
    foreach ($d in ($baseDeps + @("file:Mods/7vs1/BaseCatalogPatch.SC2Mod"))) {
        $depsXml += "    <Dependency value=`"$d`"/>`r`n"
    }
    $docInfo = "<?xml version=`"1.0`" encoding=`"utf-8`"?>`r`n<DocInfo>`r`n  <EditorCategories value=`"UpgradeCategory:Protoss`"/>`r`n  $depsXml</DocInfo>`r`n"
    Write-File (Join-Path $modDir "DocumentInfo") $docInfo

    # ComponentList
    $compList = '<?xml version="1.0" encoding="utf-8"?>' + "`r`n" +
                '<Components>' + "`r`n" +
                '    <DataComponent Type="gada">GameData</DataComponent>' + "`r`n" +
                '    <DataComponent Type="text" Locale="enUS">GameText</DataComponent>' + "`r`n" +
                '    <DataComponent Type="text" Locale="zhCN">GameText</DataComponent>' + "`r`n" +
                '    <DataComponent Type="info">DocumentInfo</DataComponent>' + "`r`n" +
                '</Components>' + "`r`n"
    Write-File (Join-Path $modDir "ComponentList.SC2Components") $compList

    # GameData.xml (empty catalog)
    $gameDataXml = '<?xml version="1.0" encoding="utf-8"?>' + "`r`n" + '<Catalog/>' + "`r`n"
    $gameDataDir = Join-Path $modDir "Base.SC2Data\GameData"
    if (-not (Test-Path -LiteralPath $gameDataDir)) {
        [void][System.IO.Directory]::CreateDirectory($gameDataDir)
    }
    Write-File (Join-Path $gameDataDir "GameData.xml") $gameDataXml

    # Version files
    Write-File (Join-Path $modDir "DocumentInfo.version") "1"
    Write-File (Join-Path $modDir "GameData.version") "1"
    Write-File (Join-Path $modDir "GameText.version") "1"

    # LocalizedData directories (empty for now, split-localization.ps1 fills them)
    foreach ($locale in @("enUS","zhCN")) {
        $locDir = Join-Path $modDir "$locale.SC2Data\LocalizedData"
        if (-not (Test-Path -LiteralPath $locDir)) {
            [void][System.IO.Directory]::CreateDirectory($locDir)
        }
    }

    # Copy DocumentHeader from source mod (for binary dependency info)
    $srcHeader = Join-Path $sourceMod "DocumentHeader"
    $dstHeader = Join-Path $modDir "DocumentHeader"
    if (Test-Path -LiteralPath $srcHeader) {
        [System.IO.File]::Copy($srcHeader, $dstHeader, $true)
    }

    return $modDir
}

$movedCount = 0
$createdCount = 0

foreach ($commander in $commanderFiles.Keys) {
    $modName = "CommanderUnits_$commander"
    Write-Host "Creating mod: $modName"
    $modDir = Create-ModInfrastructure -modName $modName
    $createdCount++

    $dstGameData = Join-Path $modDir "Base.SC2Data\GameData"
    foreach ($fileName in $commanderFiles[$commander]) {
        $srcFile = Join-Path $sourceGameData $fileName
        $dstFile = Join-Path $dstGameData $fileName
        if (-not (Test-Path -LiteralPath $srcFile)) {
            Write-Warning "Source file not found: $srcFile"
            continue
        }
        [System.IO.File]::Move($srcFile, $dstFile)
        $movedCount++
    }
}

Write-Host ""
Write-Host "=== Summary ==="
Write-Host "Mods created: $createdCount"
Write-Host "Files moved : $movedCount"

# Verify source GameData now only has GameData.xml
$remaining = Get-ChildItem -LiteralPath $sourceGameData -File
Write-Host "Remaining in source GameData: $($remaining.Count) file(s)"
foreach ($r in $remaining) { Write-Host "  $($r.Name)" }
