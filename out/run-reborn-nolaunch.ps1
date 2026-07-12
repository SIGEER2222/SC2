# Run Reborn launcher with RuntimeProbe enabled, NoLaunch mode
# Discovers project directory dynamically to avoid Chinese path mojibake

$workspaceRoot = "E:\Code\MyMod\SC2"

# Discover project directory (Chinese path)
$projDir = $null
Get-ChildItem -LiteralPath $workspaceRoot -Directory | ForEach-Object {
    $candidate = $_.FullName
    $testPath = Join-Path $candidate "scripts\reborn\launch-reborn-commander.ps1"
    if (Test-Path -LiteralPath $testPath) {
        $projDir = $candidate
    }
}

if (-not $projDir) {
    Write-Host "ERROR: Could not find project directory" -ForegroundColor Red
    exit 1
}

Write-Host "Project directory: $projDir" -ForegroundColor Green

$launcher = Join-Path $projDir "scripts\reborn\launch-reborn-commander.ps1"

# Run the launcher with RuntimeProbe, NoLaunch
& $launcher -Commander TerranRaynor -MapName zexpedition03_reborn_port.SC2Map -EnableRuntimeProbe -NoLaunch

Write-Host "`nLauncher exit code: $LASTEXITCODE" -ForegroundColor $(if ($LASTEXITCODE -eq 0) { 'Green' } else { 'Red' })
