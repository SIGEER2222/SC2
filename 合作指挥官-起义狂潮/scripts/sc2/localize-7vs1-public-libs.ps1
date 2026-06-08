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

function Get-MapIncludeLibIds {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    return @(Select-String -Path $Path -Pattern '^include "Lib[0-9A-F]+"' | ForEach-Object {
        if ($_.Line -match '"(Lib[0-9A-F]+)"') {
            $matches[1]
        }
    })
}

function Test-MapNeedsFullCommanderRuntime {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    return [bool](Select-String -Path $Path -Pattern 'libE0EAE146_gf_Initialize\(|libE0EAE146_gf_InitializeBase\(' -Quiet)
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

$templateBase = Join-Path $templateRoot 'Base.SC2Data'
$templateLib67 = Join-Path $templateBase 'Lib67C0F0E7.galaxy'
$templateLibE0 = Join-Path $templateBase 'LibE0EAE146.galaxy'
if (-not (Test-Path -LiteralPath $templateLib67)) {
    throw "Template public lib missing: $templateLib67"
}
if (-not (Test-Path -LiteralPath $templateLibE0)) {
    throw "Template public lib missing: $templateLibE0"
}

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sharedLibBase = Join-Path $workspaceRoot 'Shared\7vs1PublicLibs\Base.SC2Data'
if (-not (Test-Path -LiteralPath $sharedLibBase)) {
    throw "Shared 7vs1 public lib base data not found: $sharedLibBase"
}

$libertyStory = 'bnet:自由之翼剧情 (战役)/0.0/999,file:Campaigns/LibertyStory.SC2Campaign'
$libertyMod = 'bnet:自由之翼 (Mod)/0.0/999,file:Mods/Liberty.SC2Mod'
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
    $includeLibIds = @(Get-MapIncludeLibIds -Path $mapScriptPath)
    $needsFullCommanderRuntime = Test-MapNeedsFullCommanderRuntime -Path $mapScriptPath
    $newDependencies = New-Object System.Collections.Generic.List[string]

    Add-UniqueDependency -Dependencies $newDependencies -Value $libertyStory
    Add-UniqueDependency -Dependencies $newDependencies -Value $libertyMod
    Add-UniqueDependency -Dependencies $newDependencies -Value $coopZeroPop
    Add-UniqueDependency -Dependencies $newDependencies -Value $commanderCatalog

    foreach ($dependency in $existingDependencies) {
        $normalized = if ($dependency -like 'file:*') { $dependency -replace '\\', '/' } else { $dependency }
        if (Test-IsUnexpected7vs1Dependency -Dependency $normalized) {
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

    if ($needsFullCommanderRuntime) {
        Get-ChildItem -LiteralPath $sharedLibBase -Filter '*.galaxy' | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $baseDataRoot $_.Name) -Force
        }
    }
    else {
        Copy-Item -LiteralPath $templateLib67 -Destination (Join-Path $baseDataRoot 'Lib67C0F0E7.galaxy') -Force
        Copy-Item -LiteralPath $templateLibE0 -Destination (Join-Path $baseDataRoot 'LibE0EAE146.galaxy') -Force
        foreach ($libId in $includeLibIds) {
            if (($libId -eq 'Lib67C0F0E7') -or ($libId -eq 'LibE0EAE146') -or ($libId -eq 'LibA070801C')) {
                continue
            }

            $sourceLib = Join-Path $sharedLibBase ($libId + '.galaxy')
            if (-not (Test-Path -LiteralPath $sourceLib)) {
                throw "Shared lib missing from shared base data: $sourceLib"
            }

            Copy-Item -LiteralPath $sourceLib -Destination (Join-Path $baseDataRoot ($libId + '.galaxy')) -Force

            $sourceHeader = Join-Path $sharedLibBase ($libId + '_h.galaxy')
            if (Test-Path -LiteralPath $sourceHeader) {
                Copy-Item -LiteralPath $sourceHeader -Destination (Join-Path $baseDataRoot ($libId + '_h.galaxy')) -Force
            }
        }
    }

    Write-DocumentInfo -Path $documentInfoPath -Dependencies $newDependencies.ToArray() -Preload $preload
    & (Join-Path $PSScriptRoot 'sync-document-header-from-info.ps1') -DocumentInfoPath $documentInfoPath -DocumentHeaderPath $documentHeaderPath | Out-Null

    Write-Output ("LOCALIZED {0} deps={1}" -f $map.Name, $newDependencies.Count)
}
