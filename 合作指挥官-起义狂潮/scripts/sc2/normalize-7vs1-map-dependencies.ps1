[CmdletBinding()]
param(
    [string]$MapsRoot = "",
    [string[]]$Maps = @()
)

$ErrorActionPreference = "Stop"

function Resolve-WorkspacePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        return [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot "Maps"))
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    $workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    return [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot $Path))
}

function Get-DocumentInfoDependencies {
    param([string]$Path)

    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    return @($xml.SelectNodes('/DocInfo/Dependencies/Value') | ForEach-Object {
        [string]$_.InnerText
    })
}

function Get-DocumentInfoPreload {
    param([string]$Path)

    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    return @($xml.SelectNodes('/DocInfo/Preload/Value') | ForEach-Object {
        [string]$_.InnerText
    })
}

function Write-DocumentInfo {
    param(
        [string]$Path,
        [string[]]$Dependencies,
        [string[]]$Preload
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('<?xml version="1.0" encoding="utf-8"?>')
    $lines.Add('<DocInfo>')
    $lines.Add('    <Dependencies>')
    foreach ($dependency in $Dependencies) {
        $escaped = [System.Security.SecurityElement]::Escape($dependency)
        $lines.Add("        <Value>$escaped</Value>")
    }
    $lines.Add('    </Dependencies>')

    if ($Preload.Count -gt 0) {
        $lines.Add('    <Preload>')
        foreach ($value in $Preload) {
            $escaped = [System.Security.SecurityElement]::Escape($value)
            $lines.Add("        <Value>$escaped</Value>")
        }
        $lines.Add('    </Preload>')
    }

    $lines.Add('</DocInfo>')
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

function Normalize-FileDependency {
    param([string]$Value)

    if ($Value -like 'file:*') {
        return ($Value -replace '\\', '/')
    }

    return $Value
}

function Get-IncludeLibIds {
    param([string]$MapScriptPath)

    return @(Select-String -Path $MapScriptPath -Pattern '^include "Lib[0-9A-F]+"' | ForEach-Object {
        if ($_.Line -match '"(Lib[0-9A-F]+)"') {
            $matches[1]
        }
    })
}

function Get-RequiredXMDependencies {
    param([string[]]$LibIds)

    $libToDependency = @{
        'Lib0940FFB7' = 'file:Mods/XM/XMNova.SC2Mod'
        'Lib4B62E36B' = 'file:Mods/XM/XMSwann.SC2Mod'
        'Lib81FF3B49' = 'file:Mods/XM/XMTychus.SC2Mod'
        'Lib975E2FE9' = 'file:Mods/XM/XMStetmann.SC2Mod'
        'LibA1BA7A9F' = 'file:Mods/XM/XMAbathur.SC2Mod'
        'LibA2FC17B7' = 'file:Mods/XM/XMAlarak.SC2Mod'
        'LibB7B23F0D' = 'file:Mods/XM/XMSCV.SC2Mod'
        'LibBE3BBD9F' = 'file:Mods/XM/XMStukov.SC2Mod'
        'LibC0F50AA6' = 'file:Mods/XM/XMMengsk.SC2Mod'
        'LibD0E57A9C' = 'file:Mods/XM/XMKerrigan.SC2Mod'
        'LibDA886FA0' = 'file:Mods/XM/XMMira.SC2Mod'
        'LibDF8E6945' = 'file:Mods/XM/XMDehaka.SC2Mod'
    }

    $dependencies = New-Object System.Collections.Generic.List[string]
    foreach ($libId in $LibIds) {
        if ($libToDependency.ContainsKey($libId)) {
            Add-UniqueDependency -Dependencies $dependencies -Value $libToDependency[$libId]
        }
    }
    return $dependencies.ToArray()
}

function Test-ByteSequenceAt {
    param(
        [byte[]]$Bytes,
        [int]$Offset,
        [byte[]]$Needle
    )

    if ($Offset + $Needle.Length -gt $Bytes.Length) {
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

function Get-DocumentHeaderDependencies {
    param(
        [byte[]]$Bytes,
        [int]$Start,
        [uint32]$Count
    )

    $dependencies = New-Object System.Collections.Generic.List[string]
    $offset = $Start

    for ($index = 0; $index -lt $Count; $index++) {
        $end = $offset
        while (($end -lt $Bytes.Length) -and ($Bytes[$end] -ne 0)) {
            $end++
        }

        if ($end -ge $Bytes.Length) {
            throw "DocumentHeader dependency string is not null-terminated."
        }

        $dependencies.Add([System.Text.Encoding]::UTF8.GetString($Bytes, $offset, $end - $offset))
        $offset = $end + 1
    }

    return [pscustomobject]@{
        Dependencies = $dependencies.ToArray()
        EndOffset = $offset
    }
}

function Set-DocumentHeaderDependencies {
    param(
        [string]$Path,
        [string[]]$Dependencies
    )

    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($Path)
    $dependencyStart = Find-DocumentHeaderDependencyStart -Bytes $bytes
    $countOffset = $dependencyStart - 4
    $currentCount = [System.BitConverter]::ToUInt32($bytes, $countOffset)
    $currentInfo = Get-DocumentHeaderDependencies -Bytes $bytes -Start $dependencyStart -Count $currentCount

    if (($currentInfo.Dependencies.Count -eq $Dependencies.Count) -and
        (($currentInfo.Dependencies -join "`n") -eq ($Dependencies -join "`n"))) {
        return
    }

    $dependencyBytes = [System.Text.Encoding]::UTF8.GetBytes((($Dependencies -join "`0") + "`0"))
    $countBytes = [System.BitConverter]::GetBytes([uint32]$Dependencies.Count)
    $stream = New-Object System.IO.MemoryStream

    $stream.Write($bytes, 0, $countOffset)
    $stream.Write($countBytes, 0, $countBytes.Length)
    $stream.Write($dependencyBytes, 0, $dependencyBytes.Length)
    $stream.Write($bytes, $currentInfo.EndOffset, $bytes.Length - $currentInfo.EndOffset)

    [System.IO.File]::WriteAllBytes($Path, $stream.ToArray())
}

$libertyStory = 'bnet:自由之翼剧情 (战役)/0.0/999,file:Campaigns/LibertyStory.SC2Campaign'
$coopZeroPop = 'file:Mods/7vs1/CoopZeroPop.SC2Mod'
$coreMod = 'file:Mods/7vs1/7v1Core.SC2Mod'
$kitMutations = 'file:Mods/kit_mutations.SC2Mod'
$xmFinalPatterns = @(
    'file:Mods/XM/XMFinal.SC2Mod',
    'file:Mods\XM\XMFinal.SC2Mod'
)

$resolvedMapsRoot = Resolve-WorkspacePath -Path $MapsRoot
if (-not (Test-Path -LiteralPath $resolvedMapsRoot)) {
    throw "MapsRoot not found: $resolvedMapsRoot"
}

$targets = Get-ChildItem -LiteralPath $resolvedMapsRoot -Directory |
    Where-Object { $_.Name -like '*_7vs1.SC2Map' }

if ($Maps.Count -gt 0) {
    $nameSet = @{}
    foreach ($name in $Maps) {
        $nameSet[$name] = $true
    }
    $targets = $targets | Where-Object { $nameSet.ContainsKey($_.Name) }
}

$targets = $targets | Sort-Object Name

foreach ($map in $targets) {
    if ($map.Name -eq 'ttosh02_7vs1.SC2Map') {
        Write-Output ("SKIPPED {0} special_baseline" -f $map.Name)
        continue
    }

    $documentInfoPath = Join-Path $map.FullName 'DocumentInfo'
    $documentHeaderPath = Join-Path $map.FullName 'DocumentHeader'
    $mapScriptPath = Join-Path $map.FullName 'MapScript.galaxy'
    $baseDataPath = Join-Path $map.FullName 'Base.SC2Data'
    $localLibE0Path = Join-Path $baseDataPath 'LibE0EAE146.galaxy'

    $existingDependencies = @(Get-DocumentInfoDependencies -Path $documentInfoPath | ForEach-Object {
        Normalize-FileDependency -Value $_
    })
    $preload = Get-DocumentInfoPreload -Path $documentInfoPath
    $includeLibIds = Get-IncludeLibIds -MapScriptPath $mapScriptPath
    $requiredXMDependencies = Get-RequiredXMDependencies -LibIds $includeLibIds

    $newDependencies = New-Object System.Collections.Generic.List[string]

    foreach ($dependency in $existingDependencies) {
        if ($dependency -like 'bnet:*') {
            Add-UniqueDependency -Dependencies $newDependencies -Value $dependency
        }
    }

    Add-UniqueDependency -Dependencies $newDependencies -Value $coopZeroPop
    Add-UniqueDependency -Dependencies $newDependencies -Value $coreMod

    if ($existingDependencies -contains $kitMutations) {
        Add-UniqueDependency -Dependencies $newDependencies -Value $kitMutations
    }

    foreach ($dependency in $requiredXMDependencies) {
        Add-UniqueDependency -Dependencies $newDependencies -Value $dependency
    }

    foreach ($dependency in $existingDependencies) {
        if ($xmFinalPatterns -contains $dependency) {
            continue
        }

        if (($dependency -like 'file:Mods/XM/*.SC2Mod') -or ($dependency -like 'file:Mods/XM/*.SC2Mod'.Replace('/', '\'))) {
            continue
        }

        if ($dependency -eq $coopZeroPop -or $dependency -eq $kitMutations) {
            continue
        }

        if ($dependency -like 'bnet:*') {
            continue
        }

        Add-UniqueDependency -Dependencies $newDependencies -Value $dependency
    }

    Write-DocumentInfo -Path $documentInfoPath -Dependencies $newDependencies.ToArray() -Preload $preload
    Set-DocumentHeaderDependencies -Path $documentHeaderPath -Dependencies $newDependencies.ToArray()
    if (Test-Path -LiteralPath $localLibE0Path) {
        Remove-Item -LiteralPath $localLibE0Path -Force
    }

    Write-Output ("NORMALIZED {0} deps={1}" -f $map.Name, $newDependencies.Count)
}
