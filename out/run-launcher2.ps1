Set-Location 'e:\Code\MyMod\SC2'
$launcherDir = Get-ChildItem -Directory | Where-Object { $_.Name -like '* uprising*' -or $_.Name -match '[\u4e00-\u9fff]' } | Select-Object -First 1
if (-not $launcherDir) {
    $candidates = Get-ChildItem -Directory
    Write-Host "Candidates:"
    $candidates | ForEach-Object { Write-Host "  $($_.Name)" }
    exit 1
}
$projDir = $launcherDir.FullName
Write-Host "Project dir: $projDir"
$launcher = Join-Path $projDir 'scripts\reborn\launch-reborn-commander.ps1'
Write-Host "Launcher: $launcher"
if (-not (Test-Path $launcher)) {
    Write-Host "ERROR: launcher not found"
    exit 1
}

try {
    & $launcher -Commander TerranRaynor -MapName 'zexpedition03_reborn_port.SC2Map' -EnableRuntimeProbe -NoLaunch
    Write-Host "LAUNCHER_EXIT_CODE: $LASTEXITCODE"
} catch {
    Write-Host "EXCEPTION: $($_.Exception.Message)"
}
Write-Host "DONE"
