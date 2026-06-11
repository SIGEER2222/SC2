[CmdletBinding()]
param(
    [string]$MapsRoot = "",
    [string]$TemplateMap = "ttosh02_7vs1.SC2Map",
    [string[]]$Maps = @()
)

$ErrorActionPreference = "Stop"

function Resolve-WorkspacePath {
    param([string]$Path)

    $workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot "Maps"))
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot $Path))
}

function Read-DocumentInfoXml {
    param([string]$Path)

    $raw = Get-Content -LiteralPath $Path -Raw
    $docInfoEnd = $raw.IndexOf('</DocInfo>')
    if ($docInfoEnd -ge 0) {
        $raw = $raw.Substring(0, $docInfoEnd + '</DocInfo>'.Length)
    }

    [xml]$xml = $raw
    return $xml
}

function Get-DocumentInfoDependencies {
    param([string]$Path)

    $xml = Read-DocumentInfoXml -Path $Path
    return @($xml.SelectNodes('/DocInfo/Dependencies/Value') | ForEach-Object {
        [string]$_.InnerText
    })
}

function Get-DocumentInfoPreload {
    param([string]$Path)

    $xml = Read-DocumentInfoXml -Path $Path
    return @($xml.SelectNodes('/DocInfo/Preload/Value') | ForEach-Object {
        [string]$_.InnerText
    })
}

function Remove-MapBaseDataDuplicates {
    param(
        [string]$MapBaseDataRoot,
        [string]$CanonicalRuntimeRoot
    )

    if (-not (Test-Path -LiteralPath $MapBaseDataRoot)) {
        return
    }

    Get-ChildItem -LiteralPath $MapBaseDataRoot -Filter '*.galaxy' -File | ForEach-Object {
        $sharedRuntimePath = Join-Path $CanonicalRuntimeRoot $_.Name
        if (Test-Path -LiteralPath $sharedRuntimePath) {
            Remove-Item -LiteralPath $_.FullName -Force
        }
    }
}

function Write-DocumentInfo {
    param(
        [string]$Path,
        [string[]]$Dependencies,
        [string[]]$Preload
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('<?xml version="1.0" encoding="utf-8"?>') | Out-Null
    $lines.Add('<DocInfo>') | Out-Null
    $lines.Add('    <Dependencies>') | Out-Null
    foreach ($dependency in $Dependencies) {
        $escaped = [System.Security.SecurityElement]::Escape($dependency)
        $lines.Add("        <Value>$escaped</Value>") | Out-Null
    }
    $lines.Add('    </Dependencies>') | Out-Null

    if ($Preload.Count -gt 0) {
        $lines.Add('    <Preload>') | Out-Null
        foreach ($value in $Preload) {
            $escaped = [System.Security.SecurityElement]::Escape($value)
            $lines.Add("        <Value>$escaped</Value>") | Out-Null
        }
        $lines.Add('    </Preload>') | Out-Null
    }

    $lines.Add('</DocInfo>') | Out-Null
    $content = ($lines -join "`n") + "`n"
    [System.IO.File]::WriteAllText($Path, $content, [System.Text.UTF8Encoding]::new($false))
}

function Add-UniqueDependency {
    param(
        [System.Collections.Generic.List[string]]$Dependencies,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    if (-not $Dependencies.Contains($Value)) {
        $Dependencies.Add($Value) | Out-Null
    }
}

function Get-DependencyFileTarget {
    param([string]$Value)

    $parts = $Value.Split(',')
    $target = $parts[$parts.Count - 1]
    if ($target -like 'file:*') {
        return ($target -replace '\\', '/')
    }

    return ''
}

function Test-IsUnexpected7vs1Dependency {
    param([string]$Dependency)

    return (($Dependency -match '^file:Mods[/\\]7vs1[/\\].+?\.SC2Mod$') -and
        ($Dependency -notmatch '^file:Mods[/\\]7vs1[/\\](CoopZeroPop|CommanderCatalog)\.SC2Mod$'))
}

$mapsRoot = Resolve-WorkspacePath -Path $MapsRoot
$templateRoot = Join-Path $mapsRoot $TemplateMap
if (-not (Test-Path -LiteralPath $templateRoot)) {
    throw "Template map not found: $templateRoot"
}

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$coopZeroPopBase = Join-Path $workspaceRoot 'Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data'
if (-not (Test-Path -LiteralPath $coopZeroPopBase)) {
    throw "CoopZeroPop base data not found: $coopZeroPopBase"
}

$libertyStoryName = ([string]([char]0x81EA) + [string]([char]0x7531) + [string]([char]0x4E4B) + [string]([char]0x7FFC) + [string]([char]0x5267) + [string]([char]0x60C5) + ' (' + [string]([char]0x6218) + [string]([char]0x5F79) + ')')
$libertyModName = ([string]([char]0x81EA) + [string]([char]0x7531) + [string]([char]0x4E4B) + [string]([char]0x7FFC) + ' (Mod)')
$libertyStory = "bnet:$libertyStoryName/0.0/999,file:Campaigns/LibertyStory.SC2Campaign"
$libertyMod = "bnet:$libertyModName/0.0/999,file:Mods/Liberty.SC2Mod"
$coopZeroPop = 'file:Mods/7vs1/CoopZeroPop.SC2Mod'
$commanderCatalog = 'file:Mods/7vs1/CommanderCatalog.SC2Mod'
$kitMutations = 'file:Mods/kit_mutations.SC2Mod'

$allMaps = Get-ChildItem -LiteralPath $mapsRoot -Directory | Where-Object { $_.Name -like '*_7vs1.SC2Map' } | Sort-Object Name
if ($Maps.Count -gt 0) {
    $nameSet = @{}
    foreach ($name in $Maps) {
        $nameSet[$name] = $true
    }
    $targets = @($allMaps | Where-Object { $nameSet.ContainsKey($_.Name) })
}
else {
    $targets = @($allMaps)
}

foreach ($map in $targets) {
    $documentInfoPath = Join-Path $map.FullName 'DocumentInfo'
    $documentHeaderPath = Join-Path $map.FullName 'DocumentHeader'
    $baseDataRoot = Join-Path $map.FullName 'Base.SC2Data'
    $mapScriptPath = Join-Path $map.FullName 'MapScript.galaxy'
    $existingDependencies = @(Get-DocumentInfoDependencies -Path $documentInfoPath)
    $preload = Get-DocumentInfoPreload -Path $documentInfoPath
    $newDependencies = New-Object System.Collections.Generic.List[string]

    Add-UniqueDependency -Dependencies $newDependencies -Value $libertyStory
    Add-UniqueDependency -Dependencies $newDependencies -Value $libertyMod
    Add-UniqueDependency -Dependencies $newDependencies -Value $coopZeroPop
    Add-UniqueDependency -Dependencies $newDependencies -Value $commanderCatalog

    foreach ($dependency in $existingDependencies) {
        $normalized = if ($dependency -like 'file:*') { $dependency -replace '\\', '/' } else { $dependency }
        $dependencyTarget = Get-DependencyFileTarget -Value $normalized
        if (Test-IsUnexpected7vs1Dependency -Dependency $normalized) {
            continue
        }
        if (($dependencyTarget -eq 'file:Campaigns/LibertyStory.SC2Campaign') -or
            ($dependencyTarget -eq 'file:Mods/Liberty.SC2Mod')) {
            continue
        }
        if ($normalized -eq ($coopZeroPop -replace '\\', '/')) {
            continue
        }
        if ($normalized -eq ($commanderCatalog -replace '\\', '/')) {
            continue
        }
        if ($normalized -eq ($kitMutations -replace '\\', '/')) {
            Add-UniqueDependency -Dependencies $newDependencies -Value $kitMutations
            continue
        }
        if ($normalized -eq ($libertyStory -replace '\\', '/')) {
            continue
        }
        if ($normalized -eq ($libertyMod -replace '\\', '/')) {
            continue
        }
        Add-UniqueDependency -Dependencies $newDependencies -Value $dependency
    }

    if (-not (Test-Path -LiteralPath $baseDataRoot)) {
        New-Item -ItemType Directory -Path $baseDataRoot -Force | Out-Null
    }

    Remove-MapBaseDataDuplicates -MapBaseDataRoot $baseDataRoot -CanonicalRuntimeRoot $coopZeroPopBase

    Write-DocumentInfo -Path $documentInfoPath -Dependencies $newDependencies.ToArray() -Preload $preload
    & (Join-Path $PSScriptRoot 'sync-document-header-from-info.ps1') -DocumentInfoPath $documentInfoPath -DocumentHeaderPath $documentHeaderPath | Out-Null

    Write-Output ("LOCALIZED {0} deps={1}" -f $map.Name, $newDependencies.Count)
}
