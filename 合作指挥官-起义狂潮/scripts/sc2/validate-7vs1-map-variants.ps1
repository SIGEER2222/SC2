[CmdletBinding()]
param(
    [string]$MapsRoot = "",
    [string]$SourceMapsRoot = "C:\Users\22448\Downloads\合作指挥官版起义狂潮0.81\Maps\XM",
    [switch]$FailOnMismatch
)

$ErrorActionPreference = "Stop"

function Resolve-WorkspacePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $preferredMapsRoot = Join-Path $workspaceRoot "Maps"
        if (Test-Path -LiteralPath $preferredMapsRoot) {
            return [System.IO.Path]::GetFullPath($preferredMapsRoot)
        }

        $legacyMapsRoot = Join-Path $workspaceRoot "游戏数据\其他mod数据\7vs1混合地图测试\Maps"
        return [System.IO.Path]::GetFullPath($legacyMapsRoot)
    }

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

function Get-PrivateXMDependencies {
    param([string[]]$Dependencies)

    return @($Dependencies | Where-Object { $_ -match '^file:Mods[/\\]XM[/\\].+?\.SC2Mod$' })
}

function Get-Unexpected7vs1Dependencies {
    param([string[]]$Dependencies)

    return @($Dependencies | Where-Object {
        ($_ -match '^file:Mods[/\\]7vs1[/\\].+?\.SC2Mod$') -and
        ($_ -notmatch '^file:Mods[/\\]7vs1[/\\](CoopZeroPop|CommanderCatalog)\.SC2Mod$')
    })
}

function Test-HasDependencyTarget {
    param(
        [string[]]$Dependencies,
        [string]$Target
    )

    return [bool](@($Dependencies | Where-Object {
        ($_ -eq $Target) -or ($_ -like ("*," + $Target))
    }).Count -gt 0)
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

function Get-DuplicateDependencyTargets {
    param([string[]]$Dependencies)

    $seen = @{}
    $duplicates = New-Object System.Collections.Generic.List[string]
    foreach ($dependency in $Dependencies) {
        $target = Get-DependencyFileTarget -Value $dependency
        if ([string]::IsNullOrWhiteSpace($target)) {
            continue
        }
        if ($seen.ContainsKey($target)) {
            if (-not $duplicates.Contains($target)) {
                $duplicates.Add($target) | Out-Null
            }
            continue
        }
        $seen[$target] = $true
    }

    return $duplicates.ToArray()
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

$libertyStoryTarget = 'file:Campaigns/LibertyStory.SC2Campaign'
$libertyModTarget = 'file:Mods/Liberty.SC2Mod'
$coopZeroPop = 'file:Mods/7vs1/CoopZeroPop.SC2Mod'
$commanderCatalog = 'file:Mods/7vs1/CommanderCatalog.SC2Mod'
$kitMutations = 'file:Mods/kit_mutations.SC2Mod'
$xmFinalForward = 'file:Mods/XM/XMFinal.SC2Mod'
$xmFinalBack = 'file:Mods\XM\XMFinal.SC2Mod'

foreach ($variant in $variantMaps) {
    $sourceName = $variant.Name -replace '_7vs1(?=\.SC2Map$)', ''
    $sourcePath = Join-Path $resolvedSourceMapsRoot $sourceName
    $sourceExists = Test-Path -LiteralPath $sourcePath
    $variantDocInfo = Join-Path $variant.FullName 'DocumentInfo'
    $sourceDocInfo = Join-Path $sourcePath 'DocumentInfo'
    $variantScript = Join-Path $variant.FullName 'MapScript.galaxy'
    $sourceScript = Join-Path $sourcePath 'MapScript.galaxy'

    $deps = Get-DocumentInfoDependencies -Path $variantDocInfo
    $sourceDeps = if ($sourceExists) { Get-DocumentInfoDependencies -Path $sourceDocInfo } else { @() }
    $normalizedDeps = @($deps | ForEach-Object {
        if ($_ -like 'file:*') {
            $_ -replace '\\', '/'
        }
        else {
            $_
        }
    })
    $normalizedSourceDeps = @($sourceDeps | ForEach-Object {
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
    $hasCommanderCatalog = $normalizedDeps -contains $commanderCatalog
    $hasKitMutations = $normalizedDeps -contains $kitMutations
    $unexpected7vs1Deps = Get-Unexpected7vs1Dependencies -Dependencies $normalizedDeps
    $hasUnexpected7vs1Dependency = $unexpected7vs1Deps.Count -gt 0
    $hasXMFinal = (($normalizedDeps -contains $xmFinalForward) -or ($normalizedDeps -contains $xmFinalBack))
    $hasLibertyStory = Test-HasDependencyTarget -Dependencies $normalizedDeps -Target $libertyStoryTarget
    $hasLibertyMod = Test-HasDependencyTarget -Dependencies $normalizedDeps -Target $libertyModTarget
    $duplicateDependencyTargets = Get-DuplicateDependencyTargets -Dependencies $normalizedDeps
    $sourceHasLibertyStory = Test-HasDependencyTarget -Dependencies $normalizedSourceDeps -Target $libertyStoryTarget
    $sourceHasLibertyMod = Test-HasDependencyTarget -Dependencies $normalizedSourceDeps -Target $libertyModTarget
    $privateXMDeps = Get-PrivateXMDependencies -Dependencies $normalizedDeps
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
    if (-not $hasCommanderCatalog) { $notes.Add('missing_commandercatalog') }
    if ($hasXMFinal) { $notes.Add('still_depends_on_xmfinal') }
    if ($privateXMDeps.Count -gt 0) { $notes.Add('still_depends_on_private_xm') }
    if ($sourceHasLibertyStory -and -not $hasLibertyStory) { $notes.Add('missing_libertystory') }
    if ($sourceHasLibertyMod -and -not $hasLibertyMod) { $notes.Add('missing_liberty_mod') }
    foreach ($duplicateDependencyTarget in $duplicateDependencyTargets) {
        $notes.Add(("duplicate_dependency_target:{0}" -f $duplicateDependencyTarget))
    }
    foreach ($dependency in $normalizedDeps) {
        $target = Get-DependencyFileTarget -Value $dependency
        if (($target -eq $libertyStoryTarget) -and ($dependency -ne 'bnet:自由之翼剧情 (战役)/0.0/999,file:Campaigns/LibertyStory.SC2Campaign')) {
            $notes.Add('noncanonical_libertystory_bnet')
        }
        if (($target -eq $libertyModTarget) -and ($dependency -ne 'bnet:自由之翼 (Mod)/0.0/999,file:Mods/Liberty.SC2Mod')) {
            $notes.Add('noncanonical_liberty_mod_bnet')
        }
    }
    if ($variant.Name -eq 'ttosh02_7vs1.SC2Map') {
        if (-not $hasKitMutations) { $notes.Add('missing_kit_mutations') }
    }
    foreach ($unexpected7vs1Dep in $unexpected7vs1Deps) {
        $notes.Add(("unexpected_7vs1_dependency:{0}" -f $unexpected7vs1Dep))
    }
    if (-not $hasLocalLibE0) { $notes.Add('missing_local_libe0eae146') }
    if (-not $hasLocalLib67) { $notes.Add('missing_local_lib67c0f0e7') }
    foreach ($libId in $includeLibIds) {
        if ($libId -eq 'LibA070801C') {
            if (-not $hasKitMutations) {
                $notes.Add('missing_dep_for_liba070801c')
            }
            continue
        }

        if (-not (Test-HasLocalLib -MapRoot $variant.FullName -Name ("{0}.galaxy" -f $libId))) {
            $notes.Add(("missing_local_lib_for_{0}" -f $libId.ToLowerInvariant()))
        }
    }
    if ($initializeCallCount -lt 1) { $notes.Add('missing_initialize') }
    if ($initializeBaseCallCount -lt 1) { $notes.Add('missing_initializebase') }
    if ($mapInitEventCount -ne $sourceScriptStats.MapInitEventCount) { $notes.Add('map_init_count_changed') }
    if ($startAICallCount -ne $sourceScriptStats.StartAICallCount) { $notes.Add('startai_exec_count_changed') }
    if ($sourceHasCustomAI -and -not $variantHasCustomAI) { $notes.Add('lost_customai_component') }

    $result = [pscustomobject]@{
        Map = $variant.Name
        Source = $sourceName
        HasCoopZeroPop = $hasCoopZeroPop
        HasCommanderCatalog = $hasCommanderCatalog
        HasKitMutations = $hasKitMutations
        HasUnexpected7vs1Dependency = $hasUnexpected7vs1Dependency
        HasXMFinal = $hasXMFinal
        HasLibertyStory = $hasLibertyStory
        HasLibertyMod = $hasLibertyMod
        SourceHasLibertyStory = $sourceHasLibertyStory
        SourceHasLibertyMod = $sourceHasLibertyMod
        PrivateXMDependencyCount = $privateXMDeps.Count
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
