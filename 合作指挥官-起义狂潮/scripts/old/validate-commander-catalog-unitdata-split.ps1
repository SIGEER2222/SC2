[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'sc2\catalog-xml.ps1')

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$catalogGameData = Join-Path $WorkspaceRoot 'Mods\7vs1\CommanderCatalog.SC2Mod\Base.SC2Data\GameData'
$paths = Get-CatalogXmlPaths -GameDataRoot $catalogGameData -BaseName 'UnitData'
$xmls = Read-CatalogXmlSet -GameDataRoot $catalogGameData -BaseName 'UnitData'

$seen = New-Object 'System.Collections.Generic.HashSet[string]'
$dupes = New-Object System.Collections.Generic.List[string]
foreach ($xml in $xmls) {
    foreach ($unit in @($xml.Catalog.CUnit)) {
        $id = [string]$unit.id
        if ([string]::IsNullOrWhiteSpace($id)) {
            continue
        }

        if (-not $seen.Add($id)) {
            $dupes.Add($id) | Out-Null
        }
    }
}

$maxLines = 0
foreach ($path in $paths) {
    $lineCount = (Get-Content -LiteralPath $path -Encoding UTF8 | Measure-Object -Line).Lines
    if ($lineCount -gt $maxLines) {
        $maxLines = $lineCount
    }
}

Assert-True -Condition ($dupes.Count -eq 0) -Message ("Duplicate UnitData ids detected:`n{0}" -f (($dupes | Sort-Object -Unique) -join "`n"))
Assert-True -Condition ($maxLines -le 2000) -Message ("UnitData split regression: found file over 2000 lines ({0})." -f $maxLines)

Write-Host ("UNITDATA_SPLIT_VALIDATE=PASS files={0} ids={1} maxLines={2}" -f $paths.Count, $seen.Count, $maxLines)

