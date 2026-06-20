[CmdletBinding()]
param(
    [string]$TaskName = 'CodexGoalMonitor',
    [int]$IntervalMinutes = 30,
    [int]$StaleMinutes = 45,
    [int]$CooldownMinutes = 20
)

$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'monitor-codex-goals.ps1'
if (-not (Test-Path $scriptPath)) {
    throw "Monitor script not found: $scriptPath"
}

$taskCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -StaleMinutes $StaleMinutes -CooldownMinutes $CooldownMinutes"
$startTime = (Get-Date).AddMinutes(1).ToString('HH:mm')

schtasks /Create `
    /TN $TaskName `
    /SC MINUTE `
    /MO $IntervalMinutes `
    /ST $startTime `
    /TR $taskCommand `
    /F | Out-Null

Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State, Author
