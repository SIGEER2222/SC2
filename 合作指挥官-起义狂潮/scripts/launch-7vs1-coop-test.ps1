<#
.SYNOPSIS
Install and launch the replay-derived 7vs1 coop commander test map.

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-7vs1-coop-test.ps1

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-7vs1-coop-test.ps1 -Commanders @("TerranRaynor")

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-7vs1-coop-test.ps1 -Commanders @("TerranRaynor","ZergKerrigan","ProtossArtanis","ZergAbathur","ProtossFenix","TerranTychus","TerranNova")

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-7vs1-coop-test.ps1 -MapSource "游戏数据\其他mod数据\7vs1混合地图测试\Maps\ttosh02_7vs1.SC2Map" -LiveMapName "ttosh02_7vs1.SC2Map"

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-7vs1-coop-test.ps1 -MapSource ".\Maps\ttosh02_7vs1.SC2Map" -LiveMapName "ttosh02_7vs1.SC2Map" -Commanders @("ZergAbathur") -TestSpawnPreset "AbathurFusion"
#>
[CmdletBinding()]
param(
    [string]$SourceRoot = "",
    [string]$MapSource = "",
    [string]$LiveMapName = "7vs1CoopTest.SC2Map",
    [string]$StartPointPreset = "Auto",
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$SwitcherPath = "",
    [string[]]$Commanders = @(),
    [string]$Preset = "Default",
    [ValidateSet("", "AbathurFusion")]
    [string]$TestSpawnPreset = "",
    [string]$CommanderPowerProfile = "Prestige4",
    [Alias("CommanderPowerPrestigeMask")]
    [Nullable[int]]$CommanderPowerPrestigeBonusMask = $null,
    [Alias("CommanderPowerPrestigeIndex")]
    [Nullable[int]]$CommanderPowerPrestigePointIndex = $null,
    [int]$CommanderPowerEnablePrestiges = 1,
    [int]$CommanderPowerEnableMasteries = 1,
    [int]$CommanderPowerMasteryLevel = 30,
    [Nullable[int]]$CommanderPowerMastery0 = $null,
    [Nullable[int]]$CommanderPowerMastery1 = $null,
    [Nullable[int]]$CommanderPowerMastery2 = $null,
    [Nullable[int]]$CommanderPowerMastery3 = $null,
    [Nullable[int]]$CommanderPowerMastery4 = $null,
    [Nullable[int]]$CommanderPowerMastery5 = $null,
    [string]$CommanderPowerPresetPath = "",
    [string[]]$CommanderPowerOverride = @(),
    [string[]]$Mutators = @(),
    [string[]]$GenericBonuses = @(),
    [string]$VoicePack = "Default",
    [ValidateRange(0, 3)]
    [int]$MutatorPreset = 0,
    [string]$TestRunId = "",
    [switch]$SkipCommanderPowerPreset,
    [switch]$ForceStopSc2BeforeInstall,
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($TestRunId)) {
    $TestRunId = [guid]::NewGuid().ToString("N")
}

. (Join-Path $PSScriptRoot "commander-power-metadata.ps1")
. (Join-Path $PSScriptRoot "sc2\campaignxcore-bank.ps1")

function Get-WorkspaceRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Resolve-DefaultSourceRoot {
    $workspaceRoot = Get-WorkspaceRoot
    $candidates = @(
        (Join-Path $workspaceRoot "游戏数据\其他mod数据\7vs1母巢之战合作指挥官bate版_SC2Replay_94137"),
        "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\游戏数据\其他mod数据\7vs1母巢之战合作指挥官bate版_SC2Replay_94137"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $workspaceRoot
}

function Resolve-DefaultMapSource {
    $workspaceRoot = Get-WorkspaceRoot
    $localMap = Join-Path $workspaceRoot "Maps\ttosh02_7vs1.SC2Map"
    if (Test-Path -LiteralPath $localMap) {
        return $localMap
    }

    return Join-Path (Resolve-DefaultSourceRoot) "s2ma_packages\pkg02\extract"
}

function Resolve-ExtensionSource {
    param([string]$SourceRoot)

    $workspaceRoot = Get-WorkspaceRoot
    $localExtension = Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod"
    if (Test-Path -LiteralPath $localExtension) {
        return $localExtension
    }

    return Join-Path $SourceRoot "s2ma_packages\pkg03\extract"
}

function Get-SplitCatalogModDependencies {
    return @(
        "file:Mods/7vs1/BaseCatalogPatch.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_Abathur.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_Horner.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_Kerrigan.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_Nova.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_Raynor.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_RaynorX.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_Alarak.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_Artanis.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_Dehaka.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_Fenix.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_Karax.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_Mengsk.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_Stukov.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_Swann.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_Vorazun.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_Zagara.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_Zeratul.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_Stetmann.SC2Mod",
        "file:Mods/7vs1/CommanderUnits_TychusXM.SC2Mod",
        "file:Mods/7vs1/SharedUnits.SC2Mod",
        "file:Mods/7vs1/ExternalRefs.SC2Mod"
    )
}

function Resolve-WorkspacePath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path (Get-WorkspaceRoot) $Path
}

function Resolve-CommanderPreset {
    param([string]$Name)

    $presets = @{
        Default = @(
            "TerranRaynor",
            "ZergKerrigan",
            "ProtossArtanis",
            "TerranNova",
            "ZergAbathur",
            "ProtossFenix",
            "ProtossVorazun"
        )
        Batch1 = @(
            "TerranRaynor",
            "ZergKerrigan",
            "ProtossArtanis",
            "TerranNova",
            "ZergAbathur",
            "ProtossFenix",
            "ProtossVorazun"
        )
        Batch2 = @(
            "TerranSwann",
            "ZergZagara",
            "ProtossKarax",
            "TerranHorner",
            "ZergDehaka",
            "ProtossAlarak",
            "ZergStukov"
        )
        Batch3 = @(
            "ProtossZeratul",
            "ZergStetmann",
            "TerranMengsk",
            "ProtossArtanis",
            "TerranRaynor",
            "ZergKerrigan",
            "ProtossVorazun"
        )
        TychusP1 = @(
            "TerranTychus",
            "TerranRaynor",
            "ZergKerrigan",
            "ProtossArtanis",
            "TerranNova",
            "ZergAbathur",
            "ProtossFenix"
        )
    }

    if (-not $presets.ContainsKey($Name)) {
        throw "Unknown preset '$Name'. Known presets: $($presets.Keys -join ', ')"
    }

    return @($presets[$Name])
}

function Write-FileBytesWithRetry {
    param(
        [string]$Path,
        [byte[]]$Bytes,
        [int]$RetryCount = 10,
        [int]$DelayMilliseconds = 500
    )

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            [System.IO.File]::WriteAllBytes($Path, $Bytes)
            return
        }
        catch {
            if ($attempt -ge $RetryCount) {
                throw
            }
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }
}

function Set-FileTextWithRetry {
    param(
        [string]$Path,
        [string]$Text,
        [int]$RetryCount = 10,
        [int]$DelayMilliseconds = 500
    )

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            Set-Content -LiteralPath $Path -Value $Text -NoNewline -Encoding UTF8
            return
        }
        catch {
            if ($attempt -ge $RetryCount) {
                throw
            }
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }
}

function Merge-LiveCommanderCatalogUnitData {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$LiveGameDataRoots
    )

    function Remove-StetmannPrestigeLockButtons {
        param([xml]$CatalogXml)

        foreach ($removedFace in @(
            'CommanderPrestigeStetmannMechaInfestorLocked',
            'CommanderPrestigeStetmannChargingProtocolResearchLocked',
            'CommanderPrestigeStetmannBonusRavagerResearchLocked',
            'CommanderPrestigeStetmannRecycleMechaInfestorLocked',
            'CommanderPrestigeStetmannMechaInfestorBuildLocked'
        )) {
            foreach ($removedNode in @($CatalogXml.SelectNodes("/Catalog/CUnit/CardLayouts/LayoutButtons[@Face='$removedFace']"))) {
                if ($null -ne $removedNode.ParentNode) {
                    [void]$removedNode.ParentNode.RemoveChild($removedNode)
                }
            }
        }
    }

    # The first directory is the base (BaseCatalogPatch) where UnitData.xml lives
    $basePath = Join-Path $LiveGameDataRoots[0] 'UnitData.xml'
    if (-not (Test-Path -LiteralPath $basePath)) {
        throw "Live BaseCatalogPatch UnitData.xml not found: $basePath"
    }

    [xml]$baseXml = Get-Content -LiteralPath $basePath -Encoding UTF8 -Raw
    if ($null -eq $baseXml.Catalog) {
        throw "Expected Catalog root in $basePath"
    }

    # Scan all provided directories for UnitData*.xml files (except UnitData.xml)
    $splitPaths = @()
    foreach ($root in $LiveGameDataRoots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }
        $found = Get-ChildItem -LiteralPath $root -File -Filter 'UnitData*.xml' |
            Where-Object { $_.Name -ne 'UnitData.xml' }
        $splitPaths += $found
    }
    $splitPaths = $splitPaths | Sort-Object Name

    foreach ($path in $splitPaths) {
        [xml]$splitXml = Get-Content -LiteralPath $path.FullName -Encoding UTF8 -Raw
        if ($null -eq $splitXml.Catalog) {
            throw "Expected Catalog root in $($path.FullName)"
        }

        foreach ($unit in @($splitXml.Catalog.CUnit)) {
            $id = [string]$unit.id
            if ([string]::IsNullOrWhiteSpace($id)) {
                continue
            }

            $escapedId = $id.Replace("'", "&apos;")
            $existing = $baseXml.SelectSingleNode("/Catalog/CUnit[@id='$escapedId']")
            $imported = $baseXml.ImportNode($unit, $true)
            if ($null -ne $existing) {
                [void]$baseXml.DocumentElement.ReplaceChild($imported, $existing)
            }
            else {
                [void]$baseXml.DocumentElement.AppendChild($imported)
            }
        }
    }

    Remove-StetmannPrestigeLockButtons -CatalogXml $baseXml

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $writer = [System.Xml.XmlWriter]::Create($basePath, $settings)
    try {
        $baseXml.Save($writer)
    }
    finally {
        $writer.Close()
    }

    [xml]$verifyXml = Get-Content -LiteralPath $basePath -Encoding UTF8 -Raw
    foreach ($requiredId in @('HatcheryKerrigan', 'DroneKerrigan', 'OverlordKerrigan')) {
        if ($null -eq $verifyXml.SelectSingleNode("/Catalog/CUnit[@id='$requiredId']")) {
            throw "Live CommanderCatalog merge missing required Kerrigan unit: $requiredId"
        }
    }

    foreach ($removedFace in @(
        'CommanderPrestigeStetmannMechaInfestorLocked',
        'CommanderPrestigeStetmannChargingProtocolResearchLocked',
        'CommanderPrestigeStetmannBonusRavagerResearchLocked',
        'CommanderPrestigeStetmannRecycleMechaInfestorLocked',
        'CommanderPrestigeStetmannMechaInfestorBuildLocked'
    )) {
        if ($null -ne $verifyXml.SelectSingleNode("/Catalog/CUnit/CardLayouts/LayoutButtons[@Face='$removedFace']")) {
            throw "Live CommanderCatalog merge kept removed Stetmann lock button: $removedFace"
        }
    }
}

function Wait-PathAvailable {
    param(
        [string]$Path,
        [int]$RetryCount = 20,
        [int]$DelayMilliseconds = 250
    )

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        if (Test-Path -LiteralPath $Path) {
            return
        }
        if ($attempt -lt $RetryCount) {
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }

    throw "Path not found after wait: $Path"
}

function Normalize-DelimitedStringArray {
    param([string[]]$Values)

    $normalized = New-Object System.Collections.Generic.List[string]
    foreach ($value in @($Values)) {
        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }

        foreach ($item in ([string]$value -split '[,;]')) {
            $trimmed = $item.Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                $normalized.Add($trimmed)
            }
        }
    }

    return $normalized.ToArray()
}

function Convert-TestCommanderToCommanderPowerKey {
    param([string]$Commander)

    return (Convert-CommanderPowerCommanderToBankKey -Commander $Commander -WorkspaceRoot (Get-WorkspaceRoot))
}

$Mutators = Normalize-DelimitedStringArray -Values $Mutators
$GenericBonuses = Normalize-DelimitedStringArray -Values $GenericBonuses
$VoicePack = [string]$VoicePack

function Resolve-CommanderPowerPresetPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-WorkspaceRoot) $Path))
}

$useCommanderDefaultPrestigeBonusMask = -not $PSBoundParameters.ContainsKey("CommanderPowerPrestigeBonusMask")

function Copy-DirectoryClean {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Source directory not found: $Source"
    }

    if (Test-Path -LiteralPath $Destination) {
        Remove-DirectoryWithRetry -Path $Destination
    }

    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

function Remove-DirectoryWithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [int]$RetryCount = 5,
        [int]$DelayMilliseconds = 400
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            return
        }
        catch {
            if (-not (Test-Path -LiteralPath $Path)) {
                return
            }
            if ($attempt -ge $RetryCount) {
                throw
            }
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }
}

function Sync-LiveMapRuntimeLibraries {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MapLive,
        [Parameter(Mandatory = $true)]
        [string[]]$RuntimeBaseRoots
    )

    $mapBaseDataRoot = Join-Path $MapLive "Base.SC2Data"
    if (-not (Test-Path -LiteralPath $mapBaseDataRoot)) {
        New-Item -ItemType Directory -Path $mapBaseDataRoot -Force | Out-Null
    }

    # 保留地图自带的测试库（如 LibEmptyTestCatalog.galaxy），只删除从 runtime 注入的库文件
    Get-ChildItem -LiteralPath $mapBaseDataRoot -Filter 'Lib*.galaxy' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike 'LibEmptyTest*.galaxy' } | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Force
    }

    foreach ($runtimeBaseRoot in $RuntimeBaseRoots) {
        if (-not (Test-Path -LiteralPath $runtimeBaseRoot)) {
            continue
        }

        Get-ChildItem -LiteralPath $runtimeBaseRoot -Filter 'Lib*.galaxy' -File -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $mapBaseDataRoot $_.Name) -Force
        }
    }
}

function Remove-UnsupportedLiveRuntimeRoots {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Sc2Root,
        [string[]]$AllowedDependencies = @()
    )

    $removed = New-Object 'System.Collections.Generic.List[string]'
    $modsRoot = Join-Path $Sc2Root "Mods"
    if (-not (Test-Path -LiteralPath $modsRoot)) {
        return $removed.ToArray()
    }

    $allowed7vs1Mods = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($dependency in $AllowedDependencies) {
        if (-not (Test-WorkspaceModDependency -Dependency $dependency)) {
            continue
        }

        $relativePath = Convert-DependencyToRelativePath -Dependency $dependency
        if ($relativePath -like 'Mods\7vs1\*.SC2Mod') {
            $null = $allowed7vs1Mods.Add((Split-Path -Path $relativePath -Leaf))
        }
    }

    foreach ($entry in Get-ChildItem -LiteralPath $modsRoot -Force -ErrorAction SilentlyContinue) {
        if ($entry.Name -notlike 'XM*') {
            continue
        }

        Remove-DirectoryWithRetry -Path $entry.FullName
        $null = $removed.Add(("Mods\{0}" -f $entry.Name))
    }

    $mods7vs1Root = Join-Path $modsRoot "7vs1"
    if (Test-Path -LiteralPath $mods7vs1Root) {
        foreach ($entry in Get-ChildItem -LiteralPath $mods7vs1Root -Force -ErrorAction SilentlyContinue) {
            if (($entry.Name -notlike '*.SC2Mod') -or $allowed7vs1Mods.Contains($entry.Name)) {
                continue
            }

            Remove-DirectoryWithRetry -Path $entry.FullName
            $null = $removed.Add(("Mods\7vs1\{0}" -f $entry.Name))
        }
    }

    return $removed.ToArray()
}

function Remove-LegacyLiveRuntimeRoots {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Sc2Root,
        [string[]]$AllowedDependencies = @()
    )

    return Remove-UnsupportedLiveRuntimeRoots -Sc2Root $Sc2Root -AllowedDependencies $AllowedDependencies
}

function Set-DocumentInfoDependencies {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string[]]$Dependencies
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Wait-PathAvailable -Path $Path
    }

    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    $doc = $xml.SelectSingleNode("/DocInfo")
    if (-not $doc) {
        throw "Invalid DocumentInfo: missing /DocInfo in $Path"
    }

    $old = $xml.SelectSingleNode("/DocInfo/Dependencies")
    if ($old) {
        $null = $doc.RemoveChild($old)
    }

    $dependenciesNode = $xml.CreateElement("Dependencies")
    foreach ($dependency in $Dependencies) {
        $valueNode = $xml.CreateElement("Value")
        $valueNode.InnerText = $dependency
        $null = $dependenciesNode.AppendChild($valueNode)
    }

    $insertBefore = $doc.SelectSingleNode("PatchNote|Preload|HowToPlayBasic|HowToPlayAdvanced")
    if ($insertBefore) {
        $null = $doc.InsertBefore($dependenciesNode, $insertBefore)
    }
    else {
        $null = $doc.AppendChild($dependenciesNode)
    }

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $settings.Indent = $true
    $settings.NewLineChars = "`r`n"
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try {
        $xml.Save($writer)
    }
    finally {
        $writer.Close()
    }
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
        Wait-PathAvailable -Path $Path
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

    Write-FileBytesWithRetry -Path $Path -Bytes $stream.ToArray()
}

function Set-PackageDependencies {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageRoot,
        [Parameter(Mandatory = $true)]
        [string[]]$Dependencies
    )

    Set-DocumentInfoDependencies -Path (Join-Path $PackageRoot "DocumentInfo") -Dependencies $Dependencies
    Set-DocumentHeaderDependencies -Path (Join-Path $PackageRoot "DocumentHeader") -Dependencies $Dependencies
}

function Get-DocumentInfoDependencies {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Wait-PathAvailable -Path $Path
    }

    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    return @($xml.SelectNodes("/DocInfo/Dependencies/Value") | ForEach-Object { [string]$_.InnerText })
}

function Add-DependencyUnique {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Dependencies,
        [Parameter(Mandatory = $true)]
        [string]$Dependency
    )

    if ($Dependencies -contains $Dependency) {
        return $Dependencies
    }

    return @($Dependencies + $Dependency)
}

function Get-DependencyFileTarget {
    param([string]$Dependency)

    $parts = $Dependency.Split(',')
    $target = $parts[$parts.Count - 1]
    if ($target -like 'file:*') {
        return ($target -replace '\\', '/')
    }

    return ""
}

function Normalize-MapRuntimeDependencies {
    param([string[]]$Dependencies)

    $libertyStory = "bnet:自由之翼剧情 (战役)/0.0/999,file:Campaigns/LibertyStory.SC2Campaign"
    $libertyMod = "bnet:自由之翼 (Mod)/0.0/999,file:Mods/Liberty.SC2Mod"
    $normalized = @($libertyStory, $libertyMod)

    foreach ($dependency in $Dependencies) {
        $target = Get-DependencyFileTarget -Dependency $dependency
        if (($target -eq "file:Campaigns/LibertyStory.SC2Campaign") -or
            ($target -eq "file:Mods/Liberty.SC2Mod")) {
            continue
        }

        if ($dependency -like "file:*") {
            $dependency = ($dependency -replace '\\', '/')
        }
        $normalized = Add-DependencyUnique -Dependencies $normalized -Dependency $dependency
    }

    return $normalized
}

function Test-AnyLocalModDependency {
    param([string]$Dependency)

    return $Dependency -like 'file:Mods/*'
}

function Test-WorkspaceModDependency {
    param([string]$Dependency)

    if (-not (Test-AnyLocalModDependency -Dependency $Dependency)) {
        return $false
    }

    $normalized = $Dependency.Replace('\', '/').ToLowerInvariant()
    return ($normalized -like 'file:mods/7vs1/*.sc2mod') -or
        ($normalized -eq 'file:mods/kit_mutations.sc2mod') -or
        ($normalized -eq 'file:mods/starcoop/starcoop.sc2mod') -or
        ($normalized -like 'file:mods/starcoop/commanders/*.sc2mod')
}

function Assert-SupportedWorkspaceModDependency {
    param([string]$Dependency)

    if ((Test-AnyLocalModDependency -Dependency $Dependency) -and
        (-not (Test-WorkspaceModDependency -Dependency $Dependency))) {
        throw "Unsupported workspace dependency '$Dependency'. 7vs1 smoke/install only allows file:Mods/7vs1/*.SC2Mod, file:Mods/kit_mutations.SC2Mod, and file:Mods/StarCoop/*.SC2Mod dependencies. Remove stale unsupported local mod references from DocumentInfo."
    }
}

function Assert-NoUnsupportedWorkspaceDependency {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Dependencies,
        [string]$DependencyOwner = "dependency list"
    )

    foreach ($dependency in $Dependencies) {
        Assert-SupportedWorkspaceModDependency -Dependency $dependency
    }
}

function Convert-DependencyToRelativePath {
    param([string]$Dependency)

    if (-not (Test-WorkspaceModDependency -Dependency $Dependency)) {
        Assert-SupportedWorkspaceModDependency -Dependency $Dependency
        throw "Unsupported local dependency path: $Dependency"
    }

    return $Dependency.Substring(5).Replace('/', '\')
}

function Resolve-UnpackedStarCoopDependencySource {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Dependency,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot
    )

    $normalized = $Dependency.Replace('\', '/').ToLowerInvariant()
    $sourceName = switch ($normalized) {
        'file:mods/starcoop/starcoop.sc2mod' { 'Co-op Mission_StarCoop.SC2Mod'; break }
        'file:mods/starcoop/commanders/arcturusmengsk.sc2mod' { 'Co-op Mission_ArcturusMengsk.SC2Mod'; break }
        'file:mods/starcoop/commanders/egonstetmann.sc2mod' { 'Co-op Mission_EgonStetmann.SC2Mod'; break }
        default { '' }
    }

    if ([string]::IsNullOrWhiteSpace($sourceName)) {
        return ''
    }

    $repoRoot = Split-Path -Parent $WorkspaceRoot
    $sourcePath = Join-Path (Join-Path $repoRoot "解包数据") $sourceName
    if (Test-Path -LiteralPath $sourcePath) {
        return $sourcePath
    }

    return ''
}

function Resolve-WorkspaceDependencySource {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Dependency,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot
    )

    $unpackedStarCoopSource = Resolve-UnpackedStarCoopDependencySource -Dependency $Dependency -WorkspaceRoot $WorkspaceRoot
    if (-not [string]::IsNullOrWhiteSpace($unpackedStarCoopSource)) {
        return $unpackedStarCoopSource
    }

    $relativePath = Convert-DependencyToRelativePath -Dependency $Dependency
    $sourcePath = Join-Path $WorkspaceRoot $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Workspace dependency source not found for ${Dependency}: $sourcePath"
    }

    return $sourcePath
}

function Resolve-LiveDependencyDestination {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Dependency,
        [Parameter(Mandatory = $true)]
        [string]$Sc2Root
    )

    return (Join-Path $Sc2Root (Convert-DependencyToRelativePath -Dependency $Dependency))
}

function Resolve-WorkspaceModDependencyClosure {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Dependencies,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot
    )

    $queue = New-Object 'System.Collections.Generic.Queue[string]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $closure = New-Object 'System.Collections.Generic.List[string]'

foreach ($dependency in $Dependencies) {
    Assert-SupportedWorkspaceModDependency -Dependency $dependency
    if (Test-WorkspaceModDependency -Dependency $dependency) {
        $queue.Enqueue($dependency)
    }
}

    while ($queue.Count -gt 0) {
        $dependency = $queue.Dequeue()
        if (-not $seen.Add($dependency)) {
            continue
        }

        $null = $closure.Add($dependency)
        $sourceRoot = Resolve-WorkspaceDependencySource -Dependency $dependency -WorkspaceRoot $WorkspaceRoot
        $documentInfoPath = Join-Path $sourceRoot 'DocumentInfo'
        if (-not (Test-Path -LiteralPath $documentInfoPath)) {
            continue
        }

    foreach ($childDependency in (Get-DocumentInfoDependencies -Path $documentInfoPath)) {
        Assert-SupportedWorkspaceModDependency -Dependency $childDependency
        if (Test-WorkspaceModDependency -Dependency $childDependency) {
            $queue.Enqueue($childDependency)
        }
        }
    }

    return $closure.ToArray()
}

function Install-WorkspaceModDependencyClosure {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Dependencies,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)]
        [string]$Sc2Root,
        [string[]]$SkipDependencies = @()
    )

    $skipSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($dependency in $SkipDependencies) {
        if (-not [string]::IsNullOrWhiteSpace($dependency)) {
            $null = $skipSet.Add($dependency)
        }
    }

    $installed = New-Object 'System.Collections.Generic.List[string]'
    foreach ($dependency in (Resolve-WorkspaceModDependencyClosure -Dependencies $Dependencies -WorkspaceRoot $WorkspaceRoot)) {
        if ($skipSet.Contains($dependency)) {
            continue
        }

        $sourceRoot = Resolve-WorkspaceDependencySource -Dependency $dependency -WorkspaceRoot $WorkspaceRoot
        $liveRoot = Resolve-LiveDependencyDestination -Dependency $dependency -Sc2Root $Sc2Root
        Copy-DirectoryClean -Source $sourceRoot -Destination $liveRoot
        $null = $installed.Add($dependency)
    }

    return $installed.ToArray()
}

function Get-EffectiveLiveRuntimeLibraryPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MapLive,
        [Parameter(Mandatory = $true)]
        [string]$ExtensionLive,
        [Parameter(Mandatory = $true)]
        [string]$LibraryName
    )

    $mapLibraryPath = Join-Path $MapLive "Base.SC2Data\$LibraryName"
    if (Test-Path -LiteralPath $mapLibraryPath) {
        return $mapLibraryPath
    }

    return (Join-Path $ExtensionLive "Base.SC2Data\$LibraryName")
}

function Assert-GeneratedLibraryIncludeCoverage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [Parameter(Mandatory = $true)]
        [string]$Context,
        [string[]]$RequiredPrefixes = @()
    )

    $includedNames = @(
        [regex]::Matches($Text, '(?m)^\s*include\s+"([^"]+)"') |
            ForEach-Object { $_.Groups[1].Value } |
            Sort-Object -Unique
    )

    foreach ($prefix in $RequiredPrefixes) {
        if ($Text -notmatch ("(?m)(?<![A-Za-z0-9_])lib{0}_" -f [regex]::Escape($prefix))) {
            continue
        }

        $mainInclude = "Lib$prefix"
        $headerInclude = "Lib${prefix}_h"
        if (($includedNames -contains $mainInclude) -or ($includedNames -contains $headerInclude)) {
            continue
        }

        throw "$Context references lib$prefix helpers but is missing include `"$mainInclude`" or `"$headerInclude`"."
    }
}

function Validate-LiveBaseTestlineInstall {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MapLive,
        [Parameter(Mandatory = $true)]
        [string]$ExtensionLive,
        [Parameter(Mandatory = $true)]
        [string[]]$SelectedCommanders
    )

    $mapInfo = Get-Content -LiteralPath (Join-Path $MapLive "DocumentInfo") -Raw
    $mapDependencies = Get-DocumentInfoDependencies -Path (Join-Path $MapLive "DocumentInfo")
    $mapKpvpPath = Join-Path $MapLive "Base.SC2Data\LibKPVP.galaxy"
    $mapKpvp = if (Test-Path -LiteralPath $mapKpvpPath) { Get-Content -LiteralPath $mapKpvpPath -Raw } else { "" }
    $kpvp = Get-Content -LiteralPath (Join-Path $ExtensionLive "Base.SC2Data\LibKPVP.galaxy") -Raw
    $effectiveKpvp = Get-Content -LiteralPath (Get-EffectiveLiveRuntimeLibraryPath -MapLive $MapLive -ExtensionLive $ExtensionLive -LibraryName "LibKPVP.galaxy") -Raw
    $effectiveKmis = Get-Content -LiteralPath (Get-EffectiveLiveRuntimeLibraryPath -MapLive $MapLive -ExtensionLive $ExtensionLive -LibraryName "LibKMIS.galaxy") -Raw
    if (-not $mapInfo.Contains('file:Mods/7vs1/CoopZeroPop.SC2Mod')) {
        throw 'Live base testline dependency missing: file:Mods/7vs1/CoopZeroPop.SC2Mod'
    }
    foreach ($catalogDep in (Get-SplitCatalogModDependencies)) {
        if (-not $mapInfo.Contains($catalogDep)) {
            throw "Live base testline dependency missing: $catalogDep"
        }
    }

    Assert-NoUnsupportedWorkspaceDependency -Dependencies $mapDependencies -DependencyOwner "live map DocumentInfo"

    $hasSecondaryDependency = $false
    foreach ($marker in @(
        'file:Campaigns/LibertyStory.SC2Campaign',
        'file:Campaigns/Void.SC2Campaign',
        'file:Mods/Liberty.SC2Mod',
        'file:Mods/VoidMulti.SC2Mod'
    )) {
        if ($mapInfo.Contains($marker)) {
            $hasSecondaryDependency = $true
            break
        }
    }

    if (-not $hasSecondaryDependency) {
        throw 'Live base testline dependency closure missing a map-side runtime dependency beyond CoopZeroPop.'
    }

    foreach ($pair in @(
        @{Name='effective LibKPVP'; Text=$effectiveKpvp},
        @{Name='extension LibKPVP'; Text=$kpvp},
        @{Name='map LibKPVP'; Text=$mapKpvp}
    )) {
        if ($pair.Text.Contains('libKPVP_gf_codex_init_7vs1_test_commanders')) {
            throw "Live base testline still contains obsolete commander init override in $($pair.Name)."
        }
    }

    if ($effectiveKpvp.Contains('libKPVP_gf_codex_commander_attribute_for_player')) {
        throw 'Live base testline still contains obsolete commander attribute helper on the effective LibKPVP.'
    }
    if ($effectiveKpvp.Contains('include "LibKPVP_Commander"') -eq $false) {
        throw 'Live base testline effective LibKPVP is not including LibKPVP_Commander.'
    }
    $effectiveKpvpCommander = Join-Path (Split-Path -Parent (Get-EffectiveLiveRuntimeLibraryPath -MapLive $MapLive -ExtensionLive $ExtensionLive -LibraryName "LibKPVP.galaxy")) "LibKPVP_Commander.galaxy"
    if (-not (Test-Path -LiteralPath $effectiveKpvpCommander)) {
        throw 'Live base testline missing LibKPVP_Commander.galaxy.'
    }
    $kpvpCommander = Get-Content -LiteralPath $effectiveKpvpCommander -Raw
    if ($kpvpCommander.Contains('string libKPVP_gf_codex_commander_attribute_from_bank_key (string lp_bankKey) {') -eq $false) {
        throw 'Live base testline LibKPVP_Commander.galaxy is missing the commander attribute mapping helper.'
    }
    if ($kpvpCommander.Contains('string libKPVP_gf_codex_commander_attribute_for_runtime_player (int lp_player) {') -eq $false) {
        throw 'Live base testline LibKPVP_Commander.galaxy is missing the runtime player attribute resolver.'
    }
    if ($effectiveKpvp.Contains('auto0C816381_val = libKPVP_gf_codex_commander_attribute_for_runtime_player(lv_player);') -eq $false) {
        throw 'Live base testline effective LibKPVP is not bound to the XMRuntimeControl commander resolver.'
    }
    if ($effectiveKpvp.Contains('libKPVP_gf_codex_start_point')) {
        throw 'Live base testline still contains injected start point override on the effective LibKPVP.'
    }
    if ($effectiveKpvp.Contains('auto814DE7B0_g = libKCOR_gf_CommanderPlayers()') -eq $false) {
        throw 'Live base testline effective LibKPVP STARTPVP is not filtered to CommanderPlayers.'
    }
    Assert-GeneratedLibraryIncludeCoverage -Text $effectiveKpvp -Context 'Live base testline LibKPVP' -RequiredPrefixes @('E0EAE146')

    Assert-GeneratedLibraryIncludeCoverage -Text $effectiveKmis -Context 'Live base testline LibKMIS' -RequiredPrefixes @('DF8E6945', 'E0EAE146')
}

function Stop-RunningSc2 {
    $processNames = @("SC2_x64", "SC2Switcher_x64", "BlizzardError")

    foreach ($processName in $processNames) {
        $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if (-not $running) {
            continue
        }

        foreach ($proc in $running) {
            try {
                Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            }
            catch {
                Write-Warning "Could not stop $processName (PID $($proc.Id)): $($_.Exception.Message)"
            }
        }
    }

    Start-Sleep -Seconds 2
}

function Clear-Sc2TextureReductionCache {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Sc2Root
    )

    $cacheRoot = Join-Path $Sc2Root "SC2Data\data"
    if (-not (Test-Path -LiteralPath $cacheRoot)) {
        return
    }

    # 注意：data.025 是 1GB 的数据文件（不是缓存），删除会导致 SC2 报
    # e_fileCorruptRepairable (NGDP:E_REPAIR) 错误并需要重新下载 3.5GB。
    # 此处只清理 shmem 共享内存文件。
    foreach ($cacheName in @("shmem")) {
        $cachePath = Join-Path $cacheRoot $cacheName
        if (-not (Test-Path -LiteralPath $cachePath)) {
            continue
        }

        Remove-Item -LiteralPath $cachePath -Force -ErrorAction SilentlyContinue
    }
}

function Clear-Sc2GameLogs {
    $logsRoot = "C:\Users\22448\Documents\StarCraft II\GameLogs"
    if (-not (Test-Path -LiteralPath $logsRoot)) {
        return
    }

    Get-ChildItem -LiteralPath $logsRoot -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Could not remove SC2 log entry '$($_.FullName)': $($_.Exception.Message)"
        }
    }
}

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Resolve-DefaultSourceRoot
}

if ([string]::IsNullOrWhiteSpace($SwitcherPath)) {
    $SwitcherPath = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
}

if ([string]::IsNullOrWhiteSpace($MapSource)) {
    $mapSource = Resolve-DefaultMapSource
}
else {
    $mapSource = Resolve-WorkspacePath -Path $MapSource
}
$extensionSource = Resolve-ExtensionSource -SourceRoot $SourceRoot
$mapLive = Join-Path (Join-Path $Sc2Root "Maps\7vs1") $LiveMapName
$extensionLive = Join-Path $Sc2Root "Mods\7vs1\CoopZeroPop.SC2Mod"

if (-not (Test-Path -LiteralPath $SwitcherPath)) {
    throw "SwitcherPath not found: $SwitcherPath"
}
$workspaceRoot = Get-WorkspaceRoot
foreach ($catalogDep in (Get-SplitCatalogModDependencies)) {
    $catalogLocalPath = Join-Path $workspaceRoot ($catalogDep -replace '^file:', '')
    if (-not (Test-Path -LiteralPath $catalogLocalPath)) {
        throw "Split catalog mod not found in workspace: $catalogLocalPath"
    }
}

$defaultCommanderSlots = Resolve-CommanderPreset -Name $Preset
$explicitCommanders = ($Commanders.Count -gt 0)

if ($Commanders.Count -eq 0) {
    $Commanders = @($defaultCommanderSlots)
}

if (([System.IO.Path]::GetFileName($mapSource) -like "ttosh02*") -or ($LiveMapName -like "ttosh02*")) {
    if (-not $explicitCommanders) {
        $Commanders = @($Commanders[0])
    }
    elseif ($Commanders.Count -ne 1) {
        throw "ttosh02_7vs1 keeps the original mission enemy slots. Test exactly one commander at a time, for example: -Commanders @('TerranSwann')."
    }
}

if (($Commanders.Count -lt 1) -or ($Commanders.Count -gt 7)) {
    throw "Expected 1-7 commanders. Got $($Commanders.Count)."
}

$effectiveCommanders = @($Commanders)

if (-not $SkipCommanderPowerPreset) {
    Set-CampaignXCoreCommanderPowerPreset `
        -SelectedCommanders $effectiveCommanders `
        -Profile $CommanderPowerProfile `
        -PrestigeBonusMask $CommanderPowerPrestigeBonusMask `
        -UseCommanderDefaultPrestigeBonusMask $useCommanderDefaultPrestigeBonusMask `
        -PrestigePointIndex $CommanderPowerPrestigePointIndex `
        -EnablePrestiges $CommanderPowerEnablePrestiges `
        -EnableMasteries $CommanderPowerEnableMasteries `
        -MasteryLevel $CommanderPowerMasteryLevel `
        -Mastery0 $CommanderPowerMastery0 `
        -Mastery1 $CommanderPowerMastery1 `
        -Mastery2 $CommanderPowerMastery2 `
        -Mastery3 $CommanderPowerMastery3 `
        -Mastery4 $CommanderPowerMastery4 `
        -Mastery5 $CommanderPowerMastery5 `
        -PresetPath $CommanderPowerPresetPath `
        -Overrides $CommanderPowerOverride
}
Set-CampaignXCoreMutatorPreset -SelectedMutators $Mutators -Preset $MutatorPreset
Set-CampaignXCoreGenericBonuses -SelectedBonuses $GenericBonuses
Set-CampaignXCoreVoicePackSelection -SelectedCommanders $effectiveCommanders -VoicePack $VoicePack
Set-CampaignXCorePrimaryCommander -SelectedCommanders $effectiveCommanders
Set-CampaignXCoreTestRunId -RunId $TestRunId
Set-CampaignXCoreTestSpawnPreset -TestSpawnPreset $TestSpawnPreset

if ($ForceStopSc2BeforeInstall -or (-not $NoLaunch)) {
    Stop-RunningSc2
}

if (-not $NoLaunch) {
    Clear-Sc2GameLogs
    Clear-Sc2TextureReductionCache -Sc2Root $Sc2Root
}

Copy-DirectoryClean -Source $mapSource -Destination $mapLive
Copy-DirectoryClean -Source $extensionSource -Destination $extensionLive

$extensionDependencies = @(
    "bnet:Void Multi (Mod)/0.0/999,file:Mods/VoidMulti.SC2Mod",
    "bnet:Co-op Mission/0.0/999,file:Mods/StarCoop/StarCoop.SC2Mod"
)
$mapDependencies = @(
    Get-DocumentInfoDependencies -Path (Join-Path $mapLive "DocumentInfo")
)
$mapDependencies = Normalize-MapRuntimeDependencies -Dependencies $mapDependencies
if ($LiveMapName -ne "emptytest.SC2Map") {
    $mapDependencies = Add-DependencyUnique -Dependencies $mapDependencies -Dependency "file:Mods/7vs1/CoopZeroPop.SC2Mod"
}
$mapDependencies = Add-DependencyUnique -Dependencies $mapDependencies -Dependency "file:Mods/7vs1/Alenger3.SC2Mod"
$mapDependencies = Add-DependencyUnique -Dependencies $mapDependencies -Dependency "file:Mods/7vs1/Alenger3Adapter.SC2Mod"
foreach ($catalogDep in (Get-SplitCatalogModDependencies)) {
    $mapDependencies = Add-DependencyUnique -Dependencies $mapDependencies -Dependency $catalogDep
}
# Remove the legacy CommanderCatalog.SC2Mod dependency now that it is split into the six mods above.
$mapDependencies = @($mapDependencies | Where-Object { $_ -ne 'file:Mods/7vs1/CommanderCatalog.SC2Mod' })
# Remove the legacy CommanderUnits.SC2Mod dependency now that it is split into 17 per-commander mods.
$mapDependencies = @($mapDependencies | Where-Object { $_ -ne 'file:Mods/7vs1/CommanderUnits.SC2Mod' })

Assert-NoUnsupportedWorkspaceDependency -Dependencies $extensionDependencies -DependencyOwner "extension dependencies"
Assert-NoUnsupportedWorkspaceDependency -Dependencies $mapDependencies -DependencyOwner "map dependencies"

$liveAllowedDependencies = New-Object 'System.Collections.Generic.List[string]'
$liveAllowedDependencies.AddRange([string[]]$extensionDependencies)
$liveAllowedDependencies.AddRange([string[]]$mapDependencies)

$removedUnsupportedLiveRuntimeRoots = Remove-UnsupportedLiveRuntimeRoots `
    -Sc2Root $Sc2Root `
    -AllowedDependencies $liveAllowedDependencies.ToArray()

Set-PackageDependencies -PackageRoot $extensionLive -Dependencies $extensionDependencies
Set-PackageDependencies -PackageRoot $mapLive -Dependencies $mapDependencies

$workspaceDependencySkips = @(
    "file:Mods/7vs1/CoopZeroPop.SC2Mod"
)
$installedWorkspaceDependencyMods = Install-WorkspaceModDependencyClosure `
    -Dependencies $mapDependencies `
    -WorkspaceRoot (Get-WorkspaceRoot) `
    -Sc2Root $Sc2Root `
    -SkipDependencies $workspaceDependencySkips

$extensionBaseData = Join-Path $extensionLive "Base.SC2Data"
$kitMutationsLiveBaseData = Join-Path (Resolve-LiveDependencyDestination -Dependency "file:Mods/kit_mutations.SC2Mod" -Sc2Root $Sc2Root) "Base.SC2Data"
if ($LiveMapName -ne "emptytest.SC2Map") {
    Sync-LiveMapRuntimeLibraries `
        -MapLive $mapLive `
        -RuntimeBaseRoots @(
            $extensionBaseData,
            $kitMutationsLiveBaseData
        )
}
$effectiveRuntimeBaseData = Split-Path -Parent (Get-EffectiveLiveRuntimeLibraryPath -MapLive $mapLive -ExtensionLive $extensionLive -LibraryName "LibKPVP.galaxy")

$liveGameData = Join-Path $extensionLive "Base.SC2Data\GameData"
$liveCommanderCatalogGameDataRoots = @()
foreach ($catalogDep in (Get-SplitCatalogModDependencies)) {
    $liveCommanderCatalogGameDataRoots += (Join-Path (Resolve-LiveDependencyDestination -Dependency $catalogDep -Sc2Root $Sc2Root) "Base.SC2Data\GameData")
}
Merge-LiveCommanderCatalogUnitData -LiveGameDataRoots $liveCommanderCatalogGameDataRoots
if ($LiveMapName -ne "emptytest.SC2Map") {
    Validate-LiveBaseTestlineInstall -MapLive $mapLive -ExtensionLive $extensionLive -SelectedCommanders $effectiveCommanders
}

# Re-apply the CommanderPower bank preset at the end of the install path so
# the final bank state wins even if any install/validation helper touched it.
if (-not $SkipCommanderPowerPreset) {
    Set-CampaignXCoreCommanderPowerPreset `
        -SelectedCommanders $effectiveCommanders `
        -Profile $CommanderPowerProfile `
        -PrestigeBonusMask $CommanderPowerPrestigeBonusMask `
        -PrestigePointIndex $CommanderPowerPrestigePointIndex `
        -EnablePrestiges $CommanderPowerEnablePrestiges `
        -EnableMasteries $CommanderPowerEnableMasteries `
        -MasteryLevel $CommanderPowerMasteryLevel `
        -Mastery0 $CommanderPowerMastery0 `
        -Mastery1 $CommanderPowerMastery1 `
        -Mastery2 $CommanderPowerMastery2 `
        -Mastery3 $CommanderPowerMastery3 `
        -Mastery4 $CommanderPowerMastery4 `
        -Mastery5 $CommanderPowerMastery5 `
        -PresetPath $CommanderPowerPresetPath `
        -Overrides $CommanderPowerOverride
}
Set-CampaignXCoreMutatorPreset -SelectedMutators $Mutators -Preset $MutatorPreset
Set-CampaignXCoreGenericBonuses -SelectedBonuses $GenericBonuses
Set-CampaignXCoreVoicePackSelection -SelectedCommanders $effectiveCommanders -VoicePack $VoicePack
Set-CampaignXCorePrimaryCommander -SelectedCommanders $effectiveCommanders
Set-CampaignXCoreTestRunId -RunId $TestRunId
Set-CampaignXCoreTestSpawnPreset -TestSpawnPreset $TestSpawnPreset

Write-Host "Installed map: $mapLive"
Write-Host "Installed extension mod: $extensionLive"
if ($removedUnsupportedLiveRuntimeRoots.Count -gt 0) {
    Write-Host "Removed unsupported live runtime roots: $($removedUnsupportedLiveRuntimeRoots -join ', ')"
}
else {
    Write-Host "Removed unsupported live runtime roots: none"
}
if ($installedWorkspaceDependencyMods.Count -gt 0) {
    Write-Host "Installed workspace dependency mods: $($installedWorkspaceDependencyMods -join ', ')"
}
else {
    Write-Host "Installed workspace dependency mods: none"
}
Write-Host "Requested commanders: $($Commanders -join ', ')"
Write-Host "Test commanders P1-P$($effectiveCommanders.Count): $($effectiveCommanders -join ', ')"
if (-not $SkipCommanderPowerPreset) {
    Write-Host "Commander power profile: $CommanderPowerProfile"
    Write-Host "Commander power prestige bonus mask: $CommanderPowerPrestigeBonusMask"
    Write-Host "Commander power prestige point index: $CommanderPowerPrestigePointIndex"
    Write-Host "Commander power enable prestiges: $CommanderPowerEnablePrestiges"
    Write-Host "Commander power enable masteries: $CommanderPowerEnableMasteries"
    Write-Host "Commander power mastery level: $CommanderPowerMasteryLevel"
    Write-Host "Commander power mastery overrides: [$CommanderPowerMastery0,$CommanderPowerMastery1,$CommanderPowerMastery2,$CommanderPowerMastery3,$CommanderPowerMastery4,$CommanderPowerMastery5]"
    if (-not [string]::IsNullOrWhiteSpace($CommanderPowerPresetPath)) {
        Write-Host "Commander power preset path: $(Resolve-CommanderPowerPresetPath -Path $CommanderPowerPresetPath)"
    }
    if ($CommanderPowerOverride.Count -gt 0) {
        Write-Host "Commander power overrides: $($CommanderPowerOverride -join '; ')"
    }
}
if (($Mutators.Count -gt 0) -or ($MutatorPreset -gt 0)) {
    Write-Host "Mutator preset: $MutatorPreset"
    Write-Host "Mutators: $($Mutators -join ', ')"
}
else {
    Write-Host "Mutators: bank disabled; lobby Attribute011/default controls apply"
}
if ($GenericBonuses.Count -gt 0) {
    Write-Host "Generic bonuses: $($GenericBonuses -join ', ')"
}
Write-Host "Voice pack: $VoicePack"

if (-not $NoLaunch) {
    Write-Host "Launching map: $mapLive"
    & $SwitcherPath $mapLive
}
