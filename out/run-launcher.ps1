$ErrorActionPreference = 'Continue'
try {
    & 'e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\reborn\launch-reborn-commander.ps1' -Commander TerranRaynor -MapName 'zexpedition03_reborn_port.SC2Map' -EnableRuntimeProbe -NoLaunch
    Write-Host "LAUNCHER_EXIT_CODE: $LASTEXITCODE"
} catch {
    Write-Host "EXCEPTION: $($_.Exception.Message)"
    Write-Host "STACK: $($_.ScriptStackTrace)"
}
Write-Host "DONE"
