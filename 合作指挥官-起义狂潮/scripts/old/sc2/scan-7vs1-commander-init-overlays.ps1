[CmdletBinding()]
param(
    [string]$MapsRoot = "",
    [string]$SourceMapsRoot = "",
    [string]$OutputRoot = "",
    [switch]$FailOnHighRisk
)

$ErrorActionPreference = "Stop"

function Resolve-WorkspacePath {
    param(
        [string]$Path,
        [string]$DefaultRelativePath
    )

    $workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot $DefaultRelativePath))
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot $Path))
}

function Resolve-SourceMapsRoot {
    param([string]$Path)

    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        return Resolve-WorkspacePath -Path $Path -DefaultRelativePath '..\_codex_7vs1_source_root'
    }

    $downloadsRoot = Join-Path $env:USERPROFILE 'Downloads'
    if (Test-Path -LiteralPath $downloadsRoot) {
        $candidates = @(Get-ChildItem -LiteralPath $downloadsRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like '*0.81*' } |
            ForEach-Object { Join-Path $_.FullName 'Maps\XM' } |
            Where-Object { Test-Path -LiteralPath $_ })
        if ($candidates.Count -gt 0) {
            return [System.IO.Path]::GetFullPath($candidates[0])
        }
    }

    $workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    return [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot '..\_codex_7vs1_source_root'))
}

function Get-ObjectUnits {
    param([string]$ObjectsPath)

    if (-not (Test-Path -LiteralPath $ObjectsPath)) {
        return @()
    }

    [xml]$xml = Get-Content -LiteralPath $ObjectsPath -Raw -Encoding UTF8
    return @($xml.SelectNodes('//ObjectUnit') | ForEach-Object {
        $flags = @{}
        foreach ($flag in @($_.SelectNodes('./Flag'))) {
            $flags[$flag.GetAttribute('Index')] = $flag.GetAttribute('Value')
        }

        [pscustomobject]@{
            Id           = $_.GetAttribute('Id')
            UnitType     = $_.GetAttribute('UnitType')
            Player       = $_.GetAttribute('Player')
            Position     = $_.GetAttribute('Position')
            UnitNoCreate = ($flags.ContainsKey('UnitNoCreate') -and $flags['UnitNoCreate'] -eq '1')
        }
    })
}

function Get-UnitKey {
    param([object]$Unit)

    return ('{0}|{1}' -f $Unit.Player, $Unit.UnitType)
}

function Get-CountsByKey {
    param([object[]]$Units)

    $counts = @{}
    foreach ($unit in $Units) {
        $key = Get-UnitKey -Unit $unit
        if (-not $counts.ContainsKey($key)) {
            $counts[$key] = 0
        }
        $counts[$key] += 1
    }
    return $counts
}

function Test-CommanderThemedUnit {
    param([string]$UnitType)

    if ([string]::IsNullOrWhiteSpace($UnitType)) {
        return $false
    }

    return ($UnitType -match '(Raynor|Swann|Nova|Mengsk|Horner|Tychus|Kerrigan|Zagara|Abathur|Dehaka|Stetmann|Stukov|Karax|Fenix|Vorazun|Alarak|Zeratul|Artanis|CoopCaster|SolarForge|DrakkenLaserDrill|ACHeroSpawnPlacement|HH|SI)')
}

function Get-InitOverlayKind {
    param([string]$UnitType)

    $heroStructures = @(
        'ACHeroSpawnPlacement',
        'FenixAltarOfPsiStorms',
        'SolarForgeKarax',
        'SolarForge',
        'DamagedSolarForge',
        'UnfinishedDrakkenLaserDrillCoop',
        'DrakkenLaserDrillCoop',
        'ZeratulACArtifact'
    )
    $coreStructures = @(
        'CommandCenter',
        'CommandCenterRaynor',
        'CommandCenterSwann',
        'OrbitalCommand',
        'OrbitalCommandRaynor',
        'PlanetaryFortress',
        'HHCommandCenter',
        'TychusCommandCenter',
        'SICommandCenter',
        'InfestedCommandCenter',
        'Hatchery',
        'DehakaHatchery',
        'Lair',
        'Hive',
        'Nexus'
    )
    $startupWorkers = @(
        'SCV',
        'SCVRaynor',
        'SCVSwann',
        'HHSCV',
        'TychusSCV',
        'SISCV',
        'InfestedSCV',
        'Drone',
        'DehakaDrone',
        'Probe'
    )

    if ($heroStructures -contains $UnitType) {
        return 'HeroStructureOrBeacon'
    }
    if ($coreStructures -contains $UnitType) {
        return 'CoreBaseStructure'
    }
    if ($startupWorkers -contains $UnitType) {
        return 'StartupWorker'
    }
    if ($UnitType -like 'CoopCaster*') {
        return 'CommanderCaster'
    }
    if (Test-CommanderThemedUnit -UnitType $UnitType) {
        return 'CommanderThemedUnit'
    }

    return 'OtherPlayerUnit'
}

function Get-RiskLevel {
    param(
        [string]$Kind,
        [string]$Player,
        [int]$CreatedCount,
        [int]$NewInVariantCount
    )

    if ($Player -ne '1') {
        return 'Info'
    }
    if ($CreatedCount -le 0) {
        return 'NoCreate'
    }
    if ($Kind -in @('HeroStructureOrBeacon', 'CoreBaseStructure', 'CommanderCaster')) {
        if ($NewInVariantCount -gt 0) {
            return 'High'
        }
        return 'Medium'
    }
    if (($Kind -eq 'CommanderThemedUnit') -and ($NewInVariantCount -gt 0)) {
        return 'Medium'
    }

    return 'Info'
}

$resolvedMapsRoot = Resolve-WorkspacePath -Path $MapsRoot -DefaultRelativePath 'Maps'
if (-not (Test-Path -LiteralPath $resolvedMapsRoot)) {
    throw "MapsRoot not found: $resolvedMapsRoot"
}

$resolvedSourceMapsRoot = Resolve-SourceMapsRoot -Path $SourceMapsRoot
$sourceAvailable = Test-Path -LiteralPath $resolvedSourceMapsRoot

$resolvedOutputRoot = Resolve-WorkspacePath -Path $OutputRoot -DefaultRelativePath 'logs'
New-Item -ItemType Directory -Path $resolvedOutputRoot -Force | Out-Null

$variantMaps = Get-ChildItem -LiteralPath $resolvedMapsRoot -Directory |
    Where-Object { $_.Name -like '*_7vs1.SC2Map' } |
    Sort-Object Name

if ($variantMaps.Count -eq 0) {
    throw "No *_7vs1.SC2Map variants found under $resolvedMapsRoot"
}

$rows = New-Object System.Collections.Generic.List[object]

foreach ($variant in $variantMaps) {
    $sourceName = $variant.Name -replace '_7vs1(?=\.SC2Map$)', ''
    $sourcePath = Join-Path $resolvedSourceMapsRoot $sourceName
    $variantObjectsPath = Join-Path $variant.FullName 'Objects'
    $sourceObjectsPath = Join-Path $sourcePath 'Objects'
    $variantUnits = @(Get-ObjectUnits -ObjectsPath $variantObjectsPath)
    $sourceUnits = @(Get-ObjectUnits -ObjectsPath $sourceObjectsPath)
    $sourceCounts = Get-CountsByKey -Units $sourceUnits

    $grouped = $variantUnits |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_.Player) } |
        Group-Object -Property Player, UnitType

    foreach ($group in $grouped) {
        $sample = $group.Group[0]
        $key = Get-UnitKey -Unit $sample
        $sourceCount = if ($sourceCounts.ContainsKey($key)) { $sourceCounts[$key] } else { 0 }
        $variantCount = $group.Count
        $noCreateCount = @($group.Group | Where-Object { $_.UnitNoCreate }).Count
        $createdCount = $variantCount - $noCreateCount
        $newInVariantCount = [Math]::Max(0, $variantCount - $sourceCount)
        $kind = Get-InitOverlayKind -UnitType $sample.UnitType
        $isTracked = ($sample.Player -eq '1') -or ($kind -ne 'OtherPlayerUnit')

        if (-not $isTracked) {
            continue
        }

        $risk = Get-RiskLevel -Kind $kind -Player $sample.Player -CreatedCount $createdCount -NewInVariantCount $newInVariantCount
        $positions = @($group.Group | Select-Object -First 5 | ForEach-Object { $_.Position }) -join ';'
        $ids = @($group.Group | Select-Object -First 5 | ForEach-Object { $_.Id }) -join ';'

        $rows.Add([pscustomobject]@{
            Map               = $variant.Name
            SourceMapExists   = (Test-Path -LiteralPath $sourcePath)
            Player            = $sample.Player
            UnitType          = $sample.UnitType
            Kind              = $kind
            Risk              = $risk
            VariantCount      = $variantCount
            SourceCount       = $sourceCount
            NewInVariantCount = $newInVariantCount
            CreatedCount      = $createdCount
            NoCreateCount     = $noCreateCount
            SampleIds         = $ids
            SamplePositions   = $positions
        }) | Out-Null
    }
}

$allPath = Join-Path $resolvedOutputRoot '7vs1-commander-init-overlays.csv'
$riskPath = Join-Path $resolvedOutputRoot '7vs1-commander-init-overlay-risks.csv'
$summaryPath = Join-Path $resolvedOutputRoot '7vs1-commander-init-overlay-summary.txt'

$rows |
    Sort-Object Map, Risk, Player, UnitType |
    Export-Csv -LiteralPath $allPath -NoTypeInformation -Encoding UTF8

$riskRows = @($rows | Where-Object { $_.Risk -in @('High', 'Medium') } | Sort-Object Risk, Map, Player, UnitType)
$riskRows | Export-Csv -LiteralPath $riskPath -NoTypeInformation -Encoding UTF8

$summaryLines = New-Object System.Collections.Generic.List[string]
$summaryLines.Add(("MapsRoot: {0}" -f $resolvedMapsRoot)) | Out-Null
$summaryLines.Add(("SourceMapsRoot: {0}" -f $resolvedSourceMapsRoot)) | Out-Null
$summaryLines.Add(("SourceAvailable: {0}" -f $sourceAvailable)) | Out-Null
$summaryLines.Add(("VariantMaps: {0}" -f $variantMaps.Count)) | Out-Null
$summaryLines.Add(("TrackedRows: {0}" -f $rows.Count)) | Out-Null
$summaryLines.Add(("RiskRows: {0}" -f $riskRows.Count)) | Out-Null
$summaryLines.Add("") | Out-Null
$summaryLines.Add("Risk summary by map:") | Out-Null
foreach ($entry in @($riskRows | Group-Object Map | Sort-Object Name)) {
    $high = @($entry.Group | Where-Object { $_.Risk -eq 'High' }).Count
    $medium = @($entry.Group | Where-Object { $_.Risk -eq 'Medium' }).Count
    $summaryLines.Add(("- {0}: High={1}; Medium={2}" -f $entry.Name, $high, $medium)) | Out-Null
}

$summaryLines | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host ("Scanned {0} maps." -f $variantMaps.Count)
Write-Host ("All rows: {0}" -f $allPath)
Write-Host ("Risk rows: {0}" -f $riskPath)
Write-Host ("Summary: {0}" -f $summaryPath)

if ($riskRows.Count -gt 0) {
    $riskRows | Select-Object -First 40 Map, Risk, Player, UnitType, Kind, VariantCount, SourceCount, NewInVariantCount, CreatedCount, NoCreateCount | Format-Table -AutoSize
}

if ($FailOnHighRisk -and (@($riskRows | Where-Object { $_.Risk -eq 'High' }).Count -gt 0)) {
    throw "High-risk commander initialization overlays found. See $riskPath"
}
