<#
.SYNOPSIS
Create infrastructure files for the 6 split mods and fix DocumentHeader dependencies.

.DESCRIPTION
For each new mod, creates:
- DocumentInfo (XML with correct dependencies)
- ComponentList.SC2Components
- Base.SC2Data/GameData/GameData.xml (empty Catalog)
And modifies DocumentHeader binary to reflect correct dependencies.

Uses the same DocumentHeader binary manipulation logic as launch-7vs1-coop-test.ps1.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$modsRoot = Join-Path $WorkspaceRoot "Mods\7vs1"

# ============================================================
# Dependency definitions for each mod
# ============================================================

$baseDeps = @(
    "bnet:Void Multi (Mod)/0.0/999,file:Mods/VoidMulti.SC2Mod",
    "bnet:Co-op Mission/0.0/999,file:Mods/StarCoop/StarCoop.SC2Mod"
)

$modDependencies = @{
    "BaseCatalogPatch" = @($baseDeps)
    "CommanderUnits" = @($baseDeps + @("file:Mods/7vs1/BaseCatalogPatch.SC2Mod"))
    "CommanderUnits_Stetmann" = @($baseDeps + @("file:Mods/7vs1/BaseCatalogPatch.SC2Mod"))
    "CommanderUnits_TychusXM" = @($baseDeps + @("file:Mods/7vs1/BaseCatalogPatch.SC2Mod"))
    "SharedUnits" = @($baseDeps)
    "ExternalRefs" = @($baseDeps)
}

# ============================================================
# DocumentHeader binary manipulation functions
# (copied from launch-7vs1-coop-test.ps1)
# ============================================================

function Test-ByteSequenceAt {
    param([byte[]]$Bytes, [int]$Offset, [byte[]]$Needle)

    if (($Offset + $Needle.Length) -gt $Bytes.Length) {
        return $false
    }

    for ($i = 0; $i -lt $Needle.Length; $i++) {
        if ($Bytes[$Offset + $i] -ne $Needle[$i]) {
            return $false
        }
    }

    return $true
}

function Find-DocumentHeaderDependencyStart {
    param([byte[]]$Bytes)

    $markers = @(
        [System.Text.Encoding]::UTF8.GetBytes("file:"),
        [System.Text.Encoding]::UTF8.GetBytes("bnet:")
    )

    for ($offset = 4; $offset -lt $Bytes.Length; $offset++) {
        foreach ($marker in $markers) {
            if (-not (Test-ByteSequenceAt -Bytes $Bytes -Offset $offset -Needle $marker)) {
                continue
            }

            $count = [System.BitConverter]::ToUInt32($Bytes, $offset - 4)
            if (($count -gt 0) -and ($count -lt 128)) {
                return $offset
            }
        }
    }

    throw "DocumentHeader dependency table not found."
}

function Get-DocumentHeaderDependencyEndOffset {
    param(
        [byte[]]$Bytes,
        [int]$Start,
        [uint32]$Count
    )

    $offset = $Start
    for ($index = 0; $index -lt $Count; $index++) {
        while (($offset -lt $Bytes.Length) -and ($Bytes[$offset] -ne 0)) {
            $offset++
        }
        if ($offset -ge $Bytes.Length) {
            throw "DocumentHeader dependency string is not null-terminated."
        }
        $offset++
    }

    return $offset
}

function Set-DocumentHeaderDependencies {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string[]]$Dependencies
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "DocumentHeader not found: $Path"
    }

    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($Path)
    $dependencyStart = Find-DocumentHeaderDependencyStart -Bytes $bytes
    $countOffset = $dependencyStart - 4
    $currentCount = [System.BitConverter]::ToUInt32($bytes, $countOffset)
    $dependencyEnd = Get-DocumentHeaderDependencyEndOffset -Bytes $bytes -Start $dependencyStart -Count $currentCount
    $dependencyBytes = [System.Text.Encoding]::UTF8.GetBytes((($Dependencies -join "`0") + "`0"))
    $countBytes = [System.BitConverter]::GetBytes([uint32]$Dependencies.Count)
    $stream = New-Object System.IO.MemoryStream

    $stream.Write($bytes, 0, $countOffset)
    $stream.Write($countBytes, 0, $countBytes.Length)
    $stream.Write($dependencyBytes, 0, $dependencyBytes.Length)
    $stream.Write($bytes, $dependencyEnd, $bytes.Length - $dependencyEnd)

    [System.IO.File]::WriteAllBytes($Path, $stream.ToArray())
}

# ============================================================
# Create infrastructure files for each mod
# ============================================================

$componentListXml = '<?xml version="1.0" encoding="utf-8"?>' + "`r`n" +
    '<Components>' + "`r`n" +
    '    <DataComponent Type="gada">GameData</DataComponent>' + "`r`n" +
    '    <DataComponent Type="text" Locale="enUS">GameText</DataComponent>' + "`r`n" +
    '    <DataComponent Type="text" Locale="zhCN">GameText</DataComponent>' + "`r`n" +
    '    <DataComponent Type="info">DocumentInfo</DataComponent>' + "`r`n" +
    '</Components>'

$emptyGameDataXml = '<?xml version="1.0" encoding="utf-8"?>' + "`r`n" + '<Catalog/>'

foreach ($modName in $modDependencies.Keys) {
    $modDir = Join-Path $modsRoot "$modName.SC2Mod"
    $deps = $modDependencies[$modName]

    Write-Host "Processing: $modName"

    # Create DocumentInfo
    $docInfoPath = Join-Path $modDir "DocumentInfo"
    $depValues = ($deps | ForEach-Object { "        <Value>$_</Value>" }) -join "`r`n"
    $docInfoXml = '<?xml version="1.0" encoding="utf-8"?>' + "`r`n" +
        '<DocInfo>' + "`r`n" +
        '    <Flags>' + "`r`n" +
        '        <Value>ExtensionMod</Value>' + "`r`n" +
        '    </Flags>' + "`r`n" +
        '    <Dependencies>' + "`r`n" +
        $depValues + "`r`n" +
        '    </Dependencies>' + "`r`n" +
        '</DocInfo>'
    [System.IO.File]::WriteAllText($docInfoPath, $docInfoXml, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  Created DocumentInfo with $($deps.Count) dependencies"

    # Create ComponentList.SC2Components
    $componentListPath = Join-Path $modDir "ComponentList.SC2Components"
    [System.IO.File]::WriteAllText($componentListPath, $componentListXml, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  Created ComponentList.SC2Components"

    # Create GameData.xml (empty Catalog)
    $gameDataXmlPath = Join-Path $modDir "Base.SC2Data\GameData\GameData.xml"
    [System.IO.File]::WriteAllText($gameDataXmlPath, $emptyGameDataXml, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  Created GameData.xml"

    # Modify DocumentHeader dependencies
    # Note: The original CommanderCatalog DocumentHeader has ExtensionMod flag string
    # mixed in with dependency strings, which prevents Find-DocumentHeaderDependencyStart
    # from locating the dependency table. We skip DocumentHeader modification and rely
    # on the map's DocumentInfo for mod loading order. The DocumentInfo XML already
    # declares the correct dependencies for documentation purposes.
    $docHeaderPath = Join-Path $modDir "DocumentHeader"
    if (Test-Path -LiteralPath $docHeaderPath) {
        Write-Host "  DocumentHeader kept as-is (relies on map DocumentInfo for load order)"
    } else {
        Write-Warning "  DocumentHeader not found: $docHeaderPath"
    }
}

Write-Host ""
Write-Host "Infrastructure creation completed."
