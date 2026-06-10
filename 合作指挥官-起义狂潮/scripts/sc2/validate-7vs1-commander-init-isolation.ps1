param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$mapsRoot = Join-Path $WorkspaceRoot 'Maps'
$launchScriptPath = Join-Path $WorkspaceRoot 'scripts\launch-7vs1-coop-test.ps1'
$captureScriptPath = Join-Path $WorkspaceRoot 'scripts\capture-7vs1-ingame-smoke.ps1'

Assert-True (Test-Path -LiteralPath $mapsRoot) "Missing maps root: $mapsRoot"
Assert-True (Test-Path -LiteralPath $launchScriptPath) "Missing launch script: $launchScriptPath"
Assert-True (Test-Path -LiteralPath $captureScriptPath) "Missing capture script: $captureScriptPath"

$launchScript = Get-Content -LiteralPath $launchScriptPath -Raw -Encoding UTF8
$captureScript = Get-Content -LiteralPath $captureScriptPath -Raw -Encoding UTF8

Assert-True ($launchScript.Contains('Get-EffectiveLiveRuntimeLibraryPath -MapLive $mapLive -ExtensionLive $extensionLive -LibraryName "LibKPVP.galaxy"')) `
    'Launch script must patch the effective LibKPVP, not assume extension LibKPVP wins over map-local runtime libraries.'
Assert-True (-not $launchScript.Contains('Add-SafeStartPointOverride -Path $libKPVP')) `
    'Launch script must not inject start point overrides into live LibKPVP.'
Assert-True (-not $launchScript.Contains('-StartPoints $effectiveStartPoints')) `
    'Launch script must not pass custom start point tables into live patch helpers.'
Assert-True ($launchScript.Contains('still contains forced lobby commander attribute override')) `
    'Launch validation must reject forced lobby commander attribute overrides.'
Assert-True (-not $launchScript.Contains('libKPVP_gf_codex_init_7vs1_test_commanders();')) `
    'Launch script must not replace the original commander selection loop.'
Assert-True ($launchScript.Contains('Live base testline still contains obsolete commander init override')) `
    'Launch validation must reject obsolete commander init override leftovers.'

Assert-True ($captureScript.Contains('Get-LogTimestampFromName')) `
    'Capture script must parse SC2 log filename timestamps.'
Assert-True ($captureScript.Contains('Test-LogItemStartedAfter -Item $afterScriptError -StartedAt $runStartedAt')) `
    'Capture script must not report old ScriptError logs as new errors based only on LastWriteTime.'

$maps = @(Get-ChildItem -LiteralPath $mapsRoot -Directory -Filter '*_7vs1.SC2Map' | Sort-Object Name)
Assert-True ($maps.Count -gt 0) "No *_7vs1.SC2Map directories found under $mapsRoot"

$checked = 0
foreach ($map in $maps) {
    $kpvpPath = Join-Path $map.FullName 'Base.SC2Data\LibKPVP.galaxy'
    Assert-True (Test-Path -LiteralPath $kpvpPath) "Map missing local LibKPVP.galaxy: $($map.Name)"

    $kpvp = Get-Content -LiteralPath $kpvpPath -Raw -Encoding UTF8
    Assert-True (-not $kpvp.Contains('libKPVP_gf_codex_init_7vs1_test_commanders')) `
        "Map contains obsolete commander init override: $($map.Name)"
    Assert-True ($kpvp.Contains('auto814DE7B0_g = libKCOR_gf_CommanderPlayers();')) `
        "Map STARTPVP race loop is not filtered to CommanderPlayers: $($map.Name)"
    Assert-True ($kpvp.Contains('auto9B654530_g = libKCOR_gf_CommanderPlayers();')) `
        "Map STARTPVP supply loop is not filtered to CommanderPlayers: $($map.Name)"
    Assert-True ($kpvp.Contains('autoB401BABE_g = libKCOR_gf_CommanderPlayers();')) `
        "Map STARTPVP top-panel loop is not filtered to CommanderPlayers: $($map.Name)"
    $checked++
}

Write-Output ("COMMANDER_INIT_ISOLATION_VALIDATE=PASS maps={0}" -f $checked)
