[CmdletBinding()]
param(
    [string]$MapsRoot = "游戏数据\其他mod数据\7vs1混合地图测试\Maps",
    [string]$SourceMapsRoot = "C:\Users\22448\Downloads\合作指挥官版起义狂潮0.81\Maps\XM",
    [switch]$FailOnMismatch
)

$ErrorActionPreference = "Stop"

function Resolve-WorkspacePath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    $workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    return [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot $Path))
}

function Get-DocumentInfoDependencies {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    return @($xml.SelectNodes('/DocInfo/Dependencies/Value') | ForEach-Object {
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

function Test-SourceHasCustomAI {
    param([string]$MapRoot)

    $componentList = Join-Path $MapRoot 'ComponentList.SC2Components'
    if (-not (Test-Path -LiteralPath $componentList)) {
        return $false
    }

    $text = Get-Content -LiteralPath $componentList -Raw
    return ($text -match 'CustomAI')
}

function Get-LocalLibCount {
    param([string]$MapRoot)

    $base = Join-Path $MapRoot 'Base.SC2Data'
    if (-not (Test-Path -LiteralPath $base)) {
        return 0
    }

    return @(Get-ChildItem -LiteralPath $base -Filter 'Lib*.galaxy' -File -ErrorAction SilentlyContinue).Count
}

function Test-HasLocalLib {
    param(
        [string]$MapRoot,
        [string]$Name
    )

    return (Test-Path -LiteralPath (Join-Path $MapRoot ("Base.SC2Data\{0}" -f $Name)))
}

function Get-MapScriptStats {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            InitializeCallCount = 0
            InitializeBaseCallCount = 0
            MapInitEventCount = 0
            StartAICallCount = 0
        }
    }

    $text = Get-Content -LiteralPath $Path -Raw
    return [pscustomobject]@{
        InitializeCallCount = ([regex]::Matches($text, 'libE0EAE146_gf_Initialize\(')).Count
        InitializeBaseCallCount = ([regex]::Matches($text, '(?m)^\s*libE0EAE146_gf_InitializeBase\(')).Count
        MapInitEventCount = ([regex]::Matches($text, 'TriggerAddEventMapInit\(')).Count
        StartAICallCount = ([regex]::Matches($text, 'TriggerExecute\(gt_StartAI')).Count
    }
}

$resolvedMapsRoot = Resolve-WorkspacePath -Path $MapsRoot
if (-not (Test-Path -LiteralPath $resolvedMapsRoot)) {
    throw "MapsRoot not found: $resolvedMapsRoot"
}

$resolvedSourceMapsRoot = Resolve-WorkspacePath -Path $SourceMapsRoot
if (-not (Test-Path -LiteralPath $resolvedSourceMapsRoot)) {
    throw "SourceMapsRoot not found: $resolvedSourceMapsRoot"
}

$variantMaps = Get-ChildItem -LiteralPath $resolvedMapsRoot -Directory |
    Where-Object { $_.Name -like '*_7vs1.SC2Map' } |
    Sort-Object Name

if ($variantMaps.Count -eq 0) {
    throw "No *_7vs1.SC2Map variants found under $resolvedMapsRoot"
}

$results = New-Object System.Collections.Generic.List[object]
$failures = New-Object System.Collections.Generic.List[string]

$libertyStory = 'bnet:自由之翼剧情 (战役)/0.0/999,file:Campaigns/LibertyStory.SC2Campaign'
$libertyMod = 'bnet:自由之翼 (Mod)/0.0/999,file:Mods/Liberty.SC2Mod'
$coopZeroPop = 'file:Mods/7vs1/CoopZeroPop.SC2Mod'
$xmCore = 'file:Mods/XM/XMCore.SC2Mod'
$xmFinalForward = 'file:Mods/XM/XMFinal.SC2Mod'
$xmFinalBack = 'file:Mods\XM\XMFinal.SC2Mod'
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

foreach ($variant in $variantMaps) {
    $sourceName = $variant.Name -replace '_7vs1(?=\.SC2Map$)', ''
    $sourcePath = Join-Path $resolvedSourceMapsRoot $sourceName
    $sourceExists = Test-Path -LiteralPath $sourcePath
    $variantDocInfo = Join-Path $variant.FullName 'DocumentInfo'
    $variantScript = Join-Path $variant.FullName 'MapScript.galaxy'
    $sourceScript = Join-Path $sourcePath 'MapScript.galaxy'

    $deps = Get-DocumentInfoDependencies -Path $variantDocInfo
    $normalizedDeps = @($deps | ForEach-Object {
        if ($_ -like 'file:*') {
            $_ -replace '\\', '/'
        }
        else {
            $_
        }
    })
    $variantScriptStats = Get-MapScriptStats -Path $variantScript
    $sourceScriptStats = if ($sourceExists) { Get-MapScriptStats -Path $sourceScript } else { Get-MapScriptStats -Path '' }
    $includeLibIds = Get-MapIncludeLibIds -Path $variantScript

    $hasCoopZeroPop = $normalizedDeps -contains $coopZeroPop
    $hasXMFinal = (($normalizedDeps -contains $xmFinalForward) -or ($normalizedDeps -contains $xmFinalBack))
    $hasLibertyStory = $normalizedDeps -contains $libertyStory
    $hasLibertyMod = $normalizedDeps -contains $libertyMod
    $hasXMCore = $normalizedDeps -contains $xmCore
    $hasLocalLib67 = Test-HasLocalLib -MapRoot $variant.FullName -Name 'Lib67C0F0E7.galaxy'
    $hasLocalLibE0 = Test-HasLocalLib -MapRoot $variant.FullName -Name 'LibE0EAE146.galaxy'
    $initializeCallCount = $variantScriptStats.InitializeCallCount
    $initializeBaseCallCount = $variantScriptStats.InitializeBaseCallCount
    $mapInitEventCount = $variantScriptStats.MapInitEventCount
    $startAICallCount = $variantScriptStats.StartAICallCount
    $localLibCount = Get-LocalLibCount -MapRoot $variant.FullName
    $sourceHasCustomAI = if ($sourceExists) { Test-SourceHasCustomAI -MapRoot $sourcePath } else { $false }
    $variantHasCustomAI = Test-SourceHasCustomAI -MapRoot $variant.FullName

    $notes = New-Object System.Collections.Generic.List[string]
    if (-not $sourceExists) { $notes.Add('missing_source') }
    if (-not $hasCoopZeroPop) { $notes.Add('missing_coopzeropop') }
    if ($hasXMFinal) { $notes.Add('still_depends_on_xmfinal') }
    if (-not $hasLibertyStory) { $notes.Add('missing_libertystory') }
    if (-not $hasLibertyMod) { $notes.Add('missing_liberty_mod') }
    if (-not $hasLocalLibE0) { $notes.Add('missing_local_libe0eae146') }
    if ((-not $hasLocalLib67) -and (-not $hasXMCore)) { $notes.Add('missing_xmcore_or_local_lib67') }
    foreach ($libId in $includeLibIds) {
        if ($libToDependency.ContainsKey($libId) -and -not ($normalizedDeps -contains $libToDependency[$libId])) {
            $notes.Add(("missing_dep_for_{0}" -f $libId.ToLowerInvariant()))
        }
    }
    if ($initializeCallCount -lt 1 -and $variant.Name -ne 'ttosh02_7vs1.SC2Map') { $notes.Add('missing_initialize') }
    if ($initializeBaseCallCount -gt 0) { $notes.Add('initializebase_not_removed') }
    if ($mapInitEventCount -ne $sourceScriptStats.MapInitEventCount) { $notes.Add('map_init_count_changed') }
    if ($startAICallCount -ne $sourceScriptStats.StartAICallCount) { $notes.Add('startai_exec_count_changed') }
    if ($sourceHasCustomAI -and -not $variantHasCustomAI) { $notes.Add('lost_customai_component') }

    $result = [pscustomobject]@{
        Map = $variant.Name
        Source = $sourceName
        HasCoopZeroPop = $hasCoopZeroPop
        HasXMFinal = $hasXMFinal
        HasLibertyStory = $hasLibertyStory
        HasLibertyMod = $hasLibertyMod
        HasXMCore = $hasXMCore
        HasLocalLib67 = $hasLocalLib67
        HasLocalLibE0 = $hasLocalLibE0
        InitializeCalls = $initializeCallCount
        InitializeBaseCalls = $initializeBaseCallCount
        MapInitEvents = $mapInitEventCount
        SourceMapInitEvents = $sourceScriptStats.MapInitEventCount
        StartAIExecCalls = $startAICallCount
        SourceStartAIExecCalls = $sourceScriptStats.StartAICallCount
        LocalLibCount = $localLibCount
        SourceHasCustomAI = $sourceHasCustomAI
        VariantHasCustomAI = $variantHasCustomAI
        Notes = ($notes -join ',')
    }
    $results.Add($result) | Out-Null

    if ($notes.Count -gt 0) {
        $failures.Add(("{0}: {1}" -f $variant.Name, ($notes -join ','))) | Out-Null
    }
}

$results | Format-Table -AutoSize | Out-String -Width 4096 | Write-Output

if ($failures.Count -eq 0) {
    Write-Output ("VALIDATION_OK maps={0}" -f $results.Count)
}
else {
    Write-Output ("VALIDATION_FAIL count={0}" -f $failures.Count)
    foreach ($failure in $failures) {
        Write-Output ("VALIDATION_FAIL_ITEM {0}" -f $failure)
    }

    if ($FailOnMismatch) {
        throw ("7vs1 variant validation failed for {0} map(s)." -f $failures.Count)
    }
}
