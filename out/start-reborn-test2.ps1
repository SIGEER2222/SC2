$ErrorActionPreference = 'Continue'
$launcher = 'e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\reborn\launch-reborn-commander.ps1'
$logFile = 'e:\Code\MyMod\SC2\out\reborn-raynor-launch.log'
$errFile = 'e:\Code\MyMod\SC2\out\reborn-raynor-launch.err'

# Remove old logs
Remove-Item -LiteralPath $logFile -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $errFile -ErrorAction SilentlyContinue

# Run launcher in a background job
$job = Start-Job -ScriptBlock {
    param($launcher, $logFile, $errFile)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $launcher -Commander TerranRaynor -MapName 'zexpedition03_reborn_port.SC2Map' -EnableRuntimeProbe -SkipWait *>&1 | Out-File -FilePath $logFile -Encoding UTF8
} -ArgumentList $launcher, $logFile

Write-Host "Job ID: $($job.Id)"
Write-Host "Waiting up to 120s for job to complete..."
$job | Wait-Job -Timeout 120 | Out-Null

if ($job.State -eq 'Completed') {
    Write-Host "Job completed. Output:"
    Receive-Job $job | Out-File -FilePath $logFile -Encoding UTF8 -Append
} elseif ($job.State -eq 'Running') {
    Write-Host "Job still running after 120s, stopping..."
    $job | Stop-Job
} else {
    Write-Host "Job state: $($job.State)"
    Write-Host "Job output:"
    Receive-Job $job
}

Remove-Job $job -Force

if (Test-Path $logFile) {
    Write-Host "`n=== LOG (last 60 lines) ==="
    Get-Content $logFile -Tail 60
}
