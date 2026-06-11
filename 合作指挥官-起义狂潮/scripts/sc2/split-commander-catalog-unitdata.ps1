[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'catalog-xml.ps1')

function Save-CatalogXml {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument]$Document,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try {
        $Document.Save($writer)
    }
    finally {
        $writer.Close()
    }
}

function New-CatalogDocument {
    $xml = New-Object System.Xml.XmlDocument
    $declaration = $xml.CreateXmlDeclaration('1.0', 'utf-8', $null)
    [void]$xml.AppendChild($declaration)
    [void]$xml.AppendChild($xml.CreateElement('Catalog'))
    return $xml
}

function Get-CommanderBucket {
    param([string]$UnitId)

    $commanderOrder = @(
        'Raynor',
        'Abathur',
        'Stukov',
        'Alarak',
        'Artanis',
        'Kerrigan',
        'Swann',
        'Dehaka',
        'Fenix',
        'Nova',
        'Mengsk',
        'Vorazun',
        'Zagara',
        'Zeratul',
        'Karax',
        'Tychus',
        'Horner'
    )

    foreach ($commander in $commanderOrder) {
        if ($UnitId -match [regex]::Escape($commander)) {
            return $commander
        }
    }

    return $null
}

function Get-SharedBucket {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$Unit
    )

    $race = [string]$Unit.Race.value
    switch ($race) {
        'Terr' {
            $id = [string]$Unit.id
            if ($id.Length -eq 0) {
                return 'UnitData_Shared_Terran_I_V'
            }

            if ($id[0] -eq 'H') {
                return 'UnitData_Shared_Terran_H'
            }

            if ($id[0] -lt 'H') {
                return 'UnitData_Shared_Terran_A_G'
            }

            return 'UnitData_Shared_Terran_I_V'
        }
        'Zerg' { return 'UnitData_Shared_Zerg' }
        'Prot' { return 'UnitData_Shared_Protoss' }
        'InfT' { return 'UnitData_Shared_InfestedTerran' }
        'PZrg' { return 'UnitData_Shared_PurifierZerg' }
    }

    $id = [string]$Unit.id
    if ([string]::IsNullOrWhiteSpace($id)) {
        return 'UnitData'
    }

    if ($id[0] -lt 'H') {
        return 'UnitData'
    }

    if ($id[0] -eq 'H') {
        return 'UnitData_Shared_Neutral_H'
    }

    if ($id[0] -lt 'N') {
        return 'UnitData_Shared_Neutral_I_M'
    }

    return 'UnitData_Shared_Neutral_N_Z'
}

$gameDataRoot = Join-Path $WorkspaceRoot 'Mods\7vs1\CommanderCatalog.SC2Mod\Base.SC2Data\GameData'
$sourcePath = Join-Path $gameDataRoot 'UnitData.xml'
if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Source UnitData not found: $sourcePath"
}

[xml]$sourceXml = Get-Content -LiteralPath $sourcePath -Encoding UTF8 -Raw
if ($null -eq $sourceXml.Catalog) {
    throw "Expected Catalog root in $sourcePath"
}

$groups = [ordered]@{
    UnitData = New-CatalogDocument
    UnitData_Shared_Neutral_H = New-CatalogDocument
    UnitData_Shared_Neutral_I_M = New-CatalogDocument
    UnitData_Shared_Neutral_N_Z = New-CatalogDocument
    UnitData_Shared_Terran_A_G = New-CatalogDocument
    UnitData_Shared_Terran_H = New-CatalogDocument
    UnitData_Shared_Terran_I_V = New-CatalogDocument
    UnitData_Shared_Zerg = New-CatalogDocument
    UnitData_Shared_Protoss = New-CatalogDocument
    UnitData_Shared_InfestedTerran = New-CatalogDocument
    UnitData_Shared_PurifierZerg = New-CatalogDocument
}

$commanderGroups = New-Object 'System.Collections.Generic.Dictionary[string,System.Xml.XmlDocument]'

foreach ($unit in @($sourceXml.Catalog.CUnit)) {
    $bucket = Get-CommanderBucket -UnitId ([string]$unit.id)
    if ($null -eq $bucket) {
        $bucket = Get-SharedBucket -Unit $unit
    }

    if (-not $groups.Contains($bucket)) {
        if (-not $commanderGroups.ContainsKey($bucket)) {
            $commanderGroups[$bucket] = New-CatalogDocument
        }
    }

    $targetDoc = $null
    if ($groups.Contains($bucket)) {
        $targetDoc = $groups[$bucket]
    }
    else {
        $targetDoc = $commanderGroups[$bucket]
    }

    $imported = $targetDoc.ImportNode($unit, $true)
    [void]$targetDoc.DocumentElement.AppendChild($imported)
}

foreach ($unitFile in (Get-ChildItem -LiteralPath $gameDataRoot -File -Filter 'UnitData*.xml')) {
    if ($unitFile.Name -eq 'UnitData.xml') {
        continue
    }

    Remove-Item -LiteralPath $unitFile.FullName -Force
}

foreach ($entry in $groups.GetEnumerator()) {
    $path = Join-Path $gameDataRoot ('{0}.xml' -f $entry.Key)
    if ($entry.Value.DocumentElement.HasChildNodes) {
        Save-CatalogXml -Document $entry.Value -Path $path
        Write-Host ("{0}.xml: {1} units" -f $entry.Key, @($entry.Value.Catalog.CUnit).Count)
    }
}

foreach ($key in ($commanderGroups.Keys | Sort-Object)) {
    $doc = $commanderGroups[$key]
    $path = Join-Path $gameDataRoot ('UnitData_{0}.xml' -f $key)
    Save-CatalogXml -Document $doc -Path $path
    Write-Host ("UnitData_{0}.xml: {1} units" -f $key, @($doc.Catalog.CUnit).Count)
}

Write-Host ("Split complete: {0}" -f $sourcePath)
