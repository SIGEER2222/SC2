# Launch game with RuntimeProbe, wait 120 seconds for RaynorTrainProbe to complete
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
Write-Host "Launching game with RuntimeProbe (ProbeDuration=120)..." -ForegroundColor Cyan

& $launcher -Commander TerranRaynor -MapName zexpedition03_reborn_port.SC2Map -EnableRuntimeProbe -ProbeDuration 120

Write-Host "`nLauncher exit code: $LASTEXITCODE" -ForegroundColor $(if ($LASTEXITCODE -eq 0) { 'Green' } else { 'Red' })
