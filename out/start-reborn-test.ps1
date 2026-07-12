$launcher = 'e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\reborn\launch-reborn-commander.ps1'
$logFile = 'e:\Code\MyMod\SC2\out\reborn-raynor-launch.log'

$proc = Start-Process -FilePath 'powershell.exe' `
    -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $launcher, '-Commander', 'TerranRaynor', '-MapName', 'zexpedition03_reborn_port.SC2Map', '-EnableRuntimeProbe', '-ProbeDuration', '60') `
    -PassThru `
    -WindowStyle Normal `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError 'e:\Code\MyMod\SC2\out\reborn-raynor-launch.err'

Write-Host "Launcher PID: $($proc.Id)"
Write-Host "Log file: $logFile"
Write-Host "Started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
