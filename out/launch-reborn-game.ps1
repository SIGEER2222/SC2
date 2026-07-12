# Launch Reborn map with TerranRaynor commander and RuntimeProbe
$workspaceRoot = "E:\Code\MyMod\SC2"

$projDir = $null
Get-ChildItem -LiteralPath $workspaceRoot -Directory | ForEach-Object {
    $candidate = $_.FullName
    $testPath = Join-Path $candidate "scripts\reborn\launch-reborn-commander.ps1"
    if (Test-Path -LiteralPath $testPath) {
        $projDir = $candidate
    }
}

$launcher = Join-Path $projDir "scripts\reborn\launch-reborn-commander.ps1"
Write-Host "Launching: $launcher" -ForegroundColor Green

& $launcher -Commander TerranRaynor -MapName zexpedition03_reborn_port.SC2Map -EnableRuntimeProbe -ProbeDuration 60

Write-Host "`nLauncher exit code: $LASTEXITCODE" -ForegroundColor $(if ($LASTEXITCODE -eq 0) { 'Green' } else { 'Red' })
