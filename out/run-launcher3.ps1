Set-Location 'e:\Code\MyMod\SC2'
$projDir = $null
Get-ChildItem -Directory | ForEach-Object {
    $test = Join-Path $_.FullName 'scripts\reborn\launch-reborn-commander.ps1'
    if (Test-Path $test) { $projDir = $_.FullName }
}
if (-not $projDir) {
    Write-Host "ERROR: could not find project dir with scripts\reborn\launch-reborn-commander.ps1"
    exit 1
}
Write-Host "Project dir: $projDir"
$launcher = Join-Path $projDir 'scripts\reborn\launch-reborn-commander.ps1'

try {
    & $launcher -Commander TerranRaynor -MapName 'zexpedition03_reborn_port.SC2Map' -EnableRuntimeProbe -NoLaunch
    Write-Host "LAUNCHER_EXIT_CODE: $LASTEXITCODE"
} catch {
    Write-Host "EXCEPTION: $($_.Exception.Message)"
}
Write-Host "DONE"
