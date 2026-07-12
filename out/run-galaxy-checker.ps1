# Run galaxy-checker on live map Base.SC2Data
$workspaceRoot = "E:\Code\MyMod\SC2"
$sc2Root = "E:\SC2\SC2new\StarCraft II"
$mapBaseData = Join-Path $sc2Root "Maps\zexpedition03_reborn_port.SC2Map\Base.SC2Data"

# Discover project directory
$projDir = $null
Get-ChildItem -LiteralPath $workspaceRoot -Directory | ForEach-Object {
    $candidate = $_.FullName
    $testPath = Join-Path $candidate "scripts\galaxy-checker\dist\cli.mjs"
    if (Test-Path -LiteralPath $testPath) {
        $projDir = $candidate
    }
}

if (-not $projDir) {
    Write-Host "ERROR: Could not find project directory" -ForegroundColor Red
    exit 1
}

$checker = Join-Path $projDir "scripts\galaxy-checker\dist\cli.mjs"
Write-Host "Running galaxy-checker on: $mapBaseData" -ForegroundColor Cyan
Write-Host "Checker: $checker" -ForegroundColor Cyan
Write-Host ""

& node $checker $mapBaseData --format text 2>&1

Write-Host "`nChecker exit code: $LASTEXITCODE"
