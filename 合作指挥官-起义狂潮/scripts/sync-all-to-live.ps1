<#
.SYNOPSIS
Synchronize the current XM scenario tree to the live StarCraft II installation.

.DESCRIPTION
Copies the checked-in `合作指挥官版起义狂潮` mod/map tree into the live game
directory. By default this keeps `XMFinal.SC2Mod\DocumentHeader` and
`XMFinal.SC2Mod\DocumentInfo` out of the sync path so the live metadata files
you asked not to touch stay unchanged.

Map sync can use a separate source root. For the 7vs1 mixed-map work, this
defaults to `游戏数据\其他mod数据\7vs1混合地图测试\Maps`, which is populated from
the original 0.81 map package.

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-all-to-live.ps1

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-all-to-live.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ScenarioRoot = "",
    [string]$MapSourceRoot = "",
    [string]$AllowedMapRoot = "C:\Users\22448\Downloads\合作指挥官版起义狂潮0.81\Maps\XM",
    [string]$LiveRoot = "E:\SC2\SC2new\StarCraft II",
    [string[]]$Mods = @(),
    [string[]]$Maps = @(),
    [switch]$MutateXMFinalDocumentMeta,
    [switch]$SkipMods,
    [switch]$SkipMaps,
    [switch]$SkipLauncher = $true,
    [switch]$ReplacePackedLauncher,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Resolve-ScenarioRoot {
    param(
        [string]$Root,
        [string]$Preferred
    )

    if (-not [string]::IsNullOrWhiteSpace($Preferred)) {
        $full = [System.IO.Path]::GetFullPath($Preferred)
        if (Test-Path -LiteralPath (Join-Path $full "Mods\XM")) {
            return $full
        }
        throw "Scenario root not found: $Preferred"
    }

    if (Test-Path -LiteralPath (Join-Path $Root "Mods\XM")) {
        return $Root
    }

    $default = Join-Path $Root "合作指挥官版起义狂潮"
    if (Test-Path -LiteralPath (Join-Path $default "Mods\XM")) {
        return $default
    }

    $match = Get-ChildItem -LiteralPath $Root -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "Mods\XM") } |
        Select-Object -First 1

    if (-not $match) {
        throw "Could not auto-detect scenario root under '$Root'."
    }

    return $match.FullName
}

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Resolve-Names {
    param(
        [string]$Root,
        [string[]]$Requested
    )

    if ($Requested.Count -gt 0) {
        return $Requested
    }

    return @(Get-ChildItem -LiteralPath $Root -Directory | Select-Object -ExpandProperty Name)
}

function Get-ExcludedFiles {
    param([string]$Source)

    if ($MutateXMFinalDocumentMeta) {
        return @()
    }

    if ($Source -match '[\\/ ]XMFinal\.SC2Mod([\\/]|$)') {
        return @("DocumentHeader", "DocumentInfo")
    }

    return @()
}

function Test-FileMatches {
    param(
        [string]$Source,
        [string]$Target
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Source metadata file not found: $Source"
    }

    if (-not (Test-Path -LiteralPath $Target)) {
        return $false
    }

    $sourceHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash
    return $sourceHash -eq $targetHash
}

function Get-ActiveDocumentInfoDependencies {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "DocumentInfo not found: $Path"
    }

    $text = Get-Content -LiteralPath $Path -Raw
    $activeText = [regex]::Replace($text, '<!--[\s\S]*?-->', '')
    $matches = [regex]::Matches($activeText, '<Value>([^<]+)</Value>')
    $dependencies = New-Object System.Collections.Generic.List[string]

    foreach ($match in $matches) {
        $dependencies.Add($match.Groups[1].Value)
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

function Set-XMFinalLiveDocumentHeaderFromInfo {
    param([string]$XMFinalRoot)

    $documentInfo = Join-Path $XMFinalRoot "DocumentInfo"
    $documentHeader = Join-Path $XMFinalRoot "DocumentHeader"
    $dependencies = Get-ActiveDocumentInfoDependencies -Path $documentInfo

    if ($dependencies.Count -eq 0) {
        throw "No active dependencies found in $documentInfo"
    }

    if (-not (Test-Path -LiteralPath $documentHeader)) {
        throw "DocumentHeader not found: $documentHeader"
    }

    if ($DryRun) {
        Write-Output "DRYRUN_NORMALIZE_XMFINAL_DOCUMENTHEADER=$($dependencies.Count)"
        return
    }

    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($documentHeader)
    $dependencyStart = Find-DocumentHeaderDependencyStart -Bytes $bytes
    $countOffset = $dependencyStart - 4
    $currentCount = [System.BitConverter]::ToUInt32($bytes, $countOffset)
    $currentInfo = Get-DocumentHeaderDependencies -Bytes $bytes -Start $dependencyStart -Count $currentCount

    if (($currentInfo.Dependencies.Count -eq $dependencies.Count) -and
        (($currentInfo.Dependencies -join "`n") -eq ($dependencies -join "`n"))) {
        Write-Output "NORMALIZED_XMFINAL_DOCUMENTHEADER=unchanged"
        return
    }

    $dependencyBytes = [System.Text.Encoding]::UTF8.GetBytes((($dependencies -join "`0") + "`0"))
    $countBytes = [System.BitConverter]::GetBytes([uint32]$dependencies.Count)
    $stream = New-Object System.IO.MemoryStream

    $stream.Write($bytes, 0, $countOffset)
    $stream.Write($countBytes, 0, $countBytes.Length)
    $stream.Write($dependencyBytes, 0, $dependencyBytes.Length)
    $stream.Write($bytes, $currentInfo.EndOffset, $bytes.Length - $currentInfo.EndOffset)

    $backupRoot = Join-Path $WorkspaceRoot "游戏数据\其他mod数据\live-sync-backups\XMFinal.SC2Mod\$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $backupPath = Join-Path $backupRoot "DocumentHeader"
    Copy-Item -LiteralPath $documentHeader -Destination $backupPath -Force
    [System.IO.File]::WriteAllBytes($documentHeader, $stream.ToArray())

    Write-Output "NORMALIZED_XMFINAL_DOCUMENTHEADER=$($dependencies.Count)"
    Write-Output "BACKED_UP_XMFINAL_DOCUMENTHEADER=$backupPath"
}

function Assert-XMFinalDocumentMetaIsSafeToSkip {
    param(
        [string]$SourceModsRoot,
        [string]$TargetModsRoot
    )

    if ($MutateXMFinalDocumentMeta) {
        return
    }

    $sourceFinalRoot = Join-Path $SourceModsRoot "XMFinal.SC2Mod"
    $targetFinalRoot = Join-Path $TargetModsRoot "XMFinal.SC2Mod"
    $metaFiles = @("DocumentHeader", "DocumentInfo")
    $staleFiles = New-Object System.Collections.Generic.List[string]

    foreach ($fileName in $metaFiles) {
        $sourceFile = Join-Path $sourceFinalRoot $fileName
        $targetFile = Join-Path $targetFinalRoot $fileName
        if (-not (Test-FileMatches -Source $sourceFile -Target $targetFile)) {
            $staleFiles.Add($fileName)
        }
    }

    if ($staleFiles.Count -eq 0) {
        return
    }

    $files = $staleFiles -join ", "
    throw "XMFinal.SC2Mod metadata differs from the live copy ($files), but this sync would skip it. Stale XMFinal metadata can make MapScript include resolution fail, for example missing LibA1BA7A9F. Rerun with -MutateXMFinalDocumentMeta to copy the checked-in DocumentHeader/DocumentInfo, or exclude XMFinal.SC2Mod intentionally."
}

function Invoke-RobocopySync {
    param(
        [string]$Source,
        [string]$Target
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Source path not found: $Source"
    }

    $excludeFiles = Get-ExcludedFiles -Source $Source

    if ($DryRun) {
        $excludeText = if ($excludeFiles.Count -gt 0) { " EXCLUDE=$($excludeFiles -join ',')" } else { "" }
        Write-Output "DRYRUN_SYNC=$Source -> $Target$excludeText"
        return
    }

    Ensure-Directory -Path $Target

    $robocopy = Get-Command robocopy -ErrorAction SilentlyContinue
    if ($robocopy) {
        $args = @($Source, $Target, "/E", "/R:1", "/W:1", "/NFL", "/NDL", "/NP", "/MT:8")
        foreach ($name in $excludeFiles) {
            $args += "/XF"
            $args += $name
        }

        & $robocopy.Source @args | Out-Null
        $exitCode = $LASTEXITCODE
        if ($exitCode -ge 8) {
            throw "robocopy failed while syncing '$Source' to '$Target' with exit code $exitCode"
        }
        return
    }

    Get-ChildItem -LiteralPath $Source -Recurse -File | ForEach-Object {
        if ($_.Name -in $excludeFiles) {
            return
        }

        $relative = $_.FullName.Substring($Source.Length).TrimStart('\')
        $destination = Join-Path $Target $relative
        $destinationDir = Split-Path -Parent $destination
        Ensure-Directory -Path $destinationDir
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
    }
}

function Prepare-LauncherTarget {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Ensure-Directory -Path $Path
        return
    }

    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) {
        return
    }

    if (-not $ReplacePackedLauncher) {
        throw "Launcher target is a packed file: $Path. Rerun with -ReplacePackedLauncher to back it up and replace it with a directory-style Launcher.SC2Map."
    }

    $backupPath = "$Path.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if ($DryRun) {
        Write-Output "DRYRUN_BACKUP_LAUNCHER=$Path -> $backupPath"
        Write-Output "DRYRUN_REPLACE_LAUNCHER_WITH_DIRECTORY=$Path"
        return
    }

    Move-Item -LiteralPath $Path -Destination $backupPath -Force
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    Write-Output "BACKED_UP_LAUNCHER=$backupPath"
}

$scenarioRoot = Resolve-ScenarioRoot -Root $WorkspaceRoot -Preferred $ScenarioRoot
$sourceTopLevelModsRoot = Join-Path $scenarioRoot "Mods"
$sourceModsRoot = Join-Path $sourceTopLevelModsRoot "XM"
$defaultMapSourceRoot = Join-Path $WorkspaceRoot "Maps"
$legacyMapSourceRoot = Join-Path $WorkspaceRoot "游戏数据\其他mod数据\7vs1混合地图测试\Maps"
if ([string]::IsNullOrWhiteSpace($MapSourceRoot)) {
    if (Test-Path -LiteralPath $defaultMapSourceRoot) {
        $sourceMapsRoot = $defaultMapSourceRoot
    }
    elseif (Test-Path -LiteralPath $legacyMapSourceRoot) {
        $sourceMapsRoot = $legacyMapSourceRoot
    }
    else {
        $sourceMapsRoot = Join-Path $scenarioRoot "Maps\XM"
    }
}
else {
    $sourceMapsRoot = [System.IO.Path]::GetFullPath($MapSourceRoot)
}
$sourceLauncherRoot = Join-Path $WorkspaceRoot "tools\launcher_mpq"
$sourceExtraModsRoot = Join-Path (Split-Path -Parent $sourceMapsRoot) "Mods"
$targetTopLevelModsRoot = Join-Path $LiveRoot "Mods"
$targetModsRoot = Join-Path $LiveRoot "Mods\XM"
$targetMapsRoot = Join-Path $LiveRoot "Maps\XM"
$targetLauncherRoot = Join-Path $targetMapsRoot "Launcher.SC2Map"

if (-not (Test-Path -LiteralPath $sourceTopLevelModsRoot)) {
    throw "Source top-level mods root not found: $sourceTopLevelModsRoot"
}

if (-not (Test-Path -LiteralPath $sourceModsRoot)) {
    throw "Source mods root not found: $sourceModsRoot"
}

if (-not (Test-Path -LiteralPath $sourceMapsRoot)) {
    throw "Source maps root not found: $sourceMapsRoot"
}

if (-not $SkipLauncher -and -not (Test-Path -LiteralPath $sourceLauncherRoot)) {
    throw "Source launcher root not found: $sourceLauncherRoot"
}

$modNames = Resolve-Names -Root $sourceModsRoot -Requested $Mods
$mapNames = Resolve-Names -Root $sourceMapsRoot -Requested $Maps
if (($Maps.Count -eq 0) -and (-not [string]::IsNullOrWhiteSpace($AllowedMapRoot)) -and (Test-Path -LiteralPath $AllowedMapRoot)) {
    $allowedMapNames = @(Get-ChildItem -LiteralPath $AllowedMapRoot -Directory -Filter "*.SC2Map" | Select-Object -ExpandProperty Name)
    $mapNames = @($mapNames | Where-Object { $_ -in $allowedMapNames })
}

Write-Output "SCENARIO_ROOT=$scenarioRoot"
Write-Output "MAP_SOURCE_ROOT=$sourceMapsRoot"
if (Test-Path -LiteralPath $sourceExtraModsRoot) {
    Write-Output "EXTRA_MOD_SOURCE_ROOT=$sourceExtraModsRoot"
}
Write-Output "ALLOWED_MAP_ROOT=$AllowedMapRoot"
Write-Output "LIVE_ROOT=$LiveRoot"
Write-Output "DRY_RUN=$([int][bool]$DryRun)"

if (-not $SkipMods) {
    if ((Test-Path -LiteralPath $sourceExtraModsRoot) -and
        ([System.IO.Path]::GetFullPath($sourceExtraModsRoot) -ne [System.IO.Path]::GetFullPath($sourceTopLevelModsRoot))) {
        Invoke-RobocopySync -Source $sourceExtraModsRoot -Target $targetTopLevelModsRoot
        Write-Output "SYNCED_EXTRA_MOD_ROOT=$sourceExtraModsRoot"
    }

    $topLevelModNames = @(Get-ChildItem -LiteralPath $sourceTopLevelModsRoot -Directory |
        Where-Object { $_.Name -ne "XM" } |
        Select-Object -ExpandProperty Name)

    foreach ($topLevelModName in $topLevelModNames) {
        $source = Join-Path $sourceTopLevelModsRoot $topLevelModName
        $target = Join-Path $targetTopLevelModsRoot $topLevelModName
        Invoke-RobocopySync -Source $source -Target $target
        Write-Output "SYNCED_TOP_LEVEL_MOD=$topLevelModName"
    }

    foreach ($modName in $modNames) {
        $source = Join-Path $sourceModsRoot $modName
        $target = Join-Path $targetModsRoot $modName
        Invoke-RobocopySync -Source $source -Target $target
        Write-Output "SYNCED_MOD=$modName"
    }

    if ($MutateXMFinalDocumentMeta -and ($modNames -contains "XMFinal.SC2Mod")) {
        Set-XMFinalLiveDocumentHeaderFromInfo -XMFinalRoot (Join-Path $targetModsRoot "XMFinal.SC2Mod")
    }
}

if (-not $SkipMaps) {
    foreach ($mapName in $mapNames) {
        $source = Join-Path $sourceMapsRoot $mapName
        $target = Join-Path $targetMapsRoot $mapName
        Invoke-RobocopySync -Source $source -Target $target
        Write-Output "SYNCED_MAP=$mapName"
    }
}

if (-not $SkipLauncher) {
    Prepare-LauncherTarget -Path $targetLauncherRoot
    Invoke-RobocopySync -Source $sourceLauncherRoot -Target $targetLauncherRoot
    Write-Output "SYNCED_LAUNCHER=Launcher.SC2Map"
}

Write-Output "SYNC_COMPLETED=1"
