# Run galaxy-checker and filter for RuntimeProbe/AlengerBootstrap errors
$workspaceRoot = "E:\Code\MyMod\SC2"
$sc2Root = "E:\SC2\SC2new\StarCraft II"
$mapBaseData = Join-Path $sc2Root "Maps\zexpedition03_reborn_port.SC2Map\Base.SC2Data"

$projDir = $null
Get-ChildItem -LiteralPath $workspaceRoot -Directory | ForEach-Object {
    $candidate = $_.FullName
    $testPath = Join-Path $candidate "scripts\galaxy-checker\dist\cli.mjs"
    if (Test-Path -LiteralPath $testPath) {
        $projDir = $candidate
    }
}

$checker = Join-Path $projDir "scripts\galaxy-checker\dist\cli.mjs"
$output = & node $checker $mapBaseData --format text 2>&1 | Out-String

# Filter for RuntimeProbe, AlengerBootstrap, RebornMapAdapter errors
$lines = $output -split "`n"
$relevantErrors = $lines | Where-Object {
    $_ -match 'RuntimeProbe|AlengerBootstrap|RebornMapAdapter' -and $_ -match '\[ERROR\]'
}

if ($relevantErrors.Count -gt 0) {
    Write-Host "=== Relevant errors (RuntimeProbe/AlengerBootstrap/RebornMapAdapter) ===" -ForegroundColor Red
    $relevantErrors | ForEach-Object { Write-Host $_ -ForegroundColor Red }
} else {
    Write-Host "=== No errors for RuntimeProbe/AlengerBootstrap/RebornMapAdapter ===" -ForegroundColor Green
}

# Also check for any "declared but not defined" type errors
$declaredErrors = $lines | Where-Object { $_ -match 'declared|未定义|undefined' -and $_ -match '\[ERROR\]' }
if ($declaredErrors.Count -gt 0) {
    Write-Host "`n=== 'declared/undefined' errors ===" -ForegroundColor Yellow
    $declaredErrors | Select-Object -First 10 | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$errorCount = ($lines | Where-Object { $_ -match '\[ERROR\]' }).Count
$warnCount = ($lines | Where-Object { $_ -match '\[WARN' }).Count
Write-Host "Total errors: $errorCount"
Write-Host "Total warnings: $warnCount"
