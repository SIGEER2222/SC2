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

function Test-MapHasLocalizedPublicLibs {
    param([string]$MapRoot)

    $baseDataRoot = Join-Path $MapRoot 'Base.SC2Data'
    if (-not (Test-Path -LiteralPath $baseDataRoot)) {
        return $false
    }

    $lib67 = Join-Path $baseDataRoot 'Lib67C0F0E7.galaxy'
    $libE0 = Join-Path $baseDataRoot 'LibE0EAE146.galaxy'
    return (Test-Path -LiteralPath $lib67) -and (Test-Path -LiteralPath $libE0)
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

function Get-DependencyFileTarget {
    param([string]$Value)

    $parts = $Value.Split(',')
    $target = $parts[$parts.Count - 1]
    if ($target -like 'file:*') {
        return ($target -replace '\\', '/')
    }

    return ''
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

$libertyStoryName = ([string]([char]0x81EA) + [string]([char]0x7531) + [string]([char]0x4E4B) + [string]([char]0x7FFC) + [string]([char]0x5267) + [string]([char]0x60C5) + ' (' + [string]([char]0x6218) + [string]([char]0x5F79) + ')')
$libertyModName = ([string]([char]0x81EA) + [string]([char]0x7531) + [string]([char]0x4E4B) + [string]([char]0x7FFC) + ' (Mod)')
$libertyStory = "bnet:$libertyStoryName/0.0/999,file:Campaigns/LibertyStory.SC2Campaign"
$libertyMod = "bnet:$libertyModName/0.0/999,file:Mods/Liberty.SC2Mod"
$coopZeroPop = 'file:Mods/7vs1/CoopZeroPop.SC2Mod'
$commanderCatalog = 'file:Mods/7vs1/CommanderCatalog.SC2Mod'
$kitMutations = 'file:Mods/kit_mutations.SC2Mod'
$xmFinalPatterns = @(
    'file:Mods/XM/XMFinal.SC2Mod',
    'file:Mods\XM\XMFinal.SC2Mod'
)

$resolvedMapsRoot = Resolve-WorkspacePath -Path $MapsRoot
if (-not (Test-Path -LiteralPath $resolvedMapsRoot)) {
    throw "MapsRoot not found: $resolvedMapsRoot"
}

if ($Maps.Count -gt 0) {
    $nameSet = @{}
    foreach ($name in $Maps) {
        $nameSet[$name] = $true
    }
    $targets = Get-ChildItem -LiteralPath $resolvedMapsRoot -Directory |
        Where-Object { $nameSet.ContainsKey($_.Name) }
}
else {
    $targets = Get-ChildItem -LiteralPath $resolvedMapsRoot -Directory |
        Where-Object { $_.Name -like '*_7vs1.SC2Map' }
}

$targets = $targets | Sort-Object Name

foreach ($map in $targets) {
    $documentInfoPath = Join-Path $map.FullName 'DocumentInfo'
    $documentHeaderPath = Join-Path $map.FullName 'DocumentHeader'
    $existingDependencies = @(Get-DocumentInfoDependencies -Path $documentInfoPath | ForEach-Object {
        Normalize-FileDependency -Value $_
    })
    $preload = Get-DocumentInfoPreload -Path $documentInfoPath
    $includeLibIds = Get-MapIncludeLibIds -Path (Join-Path $map.FullName 'MapScript.galaxy')

    $newDependencies = New-Object System.Collections.Generic.List[string]
    Add-UniqueDependency -Dependencies $newDependencies -Value $libertyStory
    Add-UniqueDependency -Dependencies $newDependencies -Value $libertyMod

    foreach ($dependency in $existingDependencies) {
        $dependencyTarget = Get-DependencyFileTarget -Value $dependency
        if (($dependencyTarget -eq 'file:Campaigns/LibertyStory.SC2Campaign') -or
            ($dependencyTarget -eq 'file:Mods/Liberty.SC2Mod')) {
            continue
        }

        if ($dependency -like 'bnet:*' -and $dependency -ne $libertyStory -and $dependency -ne $libertyMod) {
            Add-UniqueDependency -Dependencies $newDependencies -Value $dependency
        }
    }

    Add-UniqueDependency -Dependencies $newDependencies -Value $coopZeroPop
    Add-UniqueDependency -Dependencies $newDependencies -Value $commanderCatalog
    if (($map.Name -eq 'ttosh02_7vs1.SC2Map') -or ($includeLibIds -contains 'LibA070801C')) {
        Add-UniqueDependency -Dependencies $newDependencies -Value $kitMutations
    }

    foreach ($dependency in $existingDependencies) {
        if ($xmFinalPatterns -contains $dependency) {
            continue
        }

        if (($dependency -like 'file:Mods/XM/*.SC2Mod') -or ($dependency -like 'file:Mods/XM/*.SC2Mod'.Replace('/', '\'))) {
            continue
        }

        if ($dependency -eq $coopZeroPop -or $dependency -eq $commanderCatalog -or $dependency -eq $kitMutations) {
            continue
        }

        if ($dependency -like 'bnet:*') {
            continue
        }

        Add-UniqueDependency -Dependencies $newDependencies -Value $dependency
    }

    Write-DocumentInfo -Path $documentInfoPath -Dependencies $newDependencies.ToArray() -Preload $preload
    Set-DocumentHeaderDependencies -Path $documentHeaderPath -Dependencies $newDependencies.ToArray()

    Write-Output ("NORMALIZED {0} deps={1}" -f $map.Name, $newDependencies.Count)
}
