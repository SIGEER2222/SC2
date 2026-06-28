<#
.SYNOPSIS
Smart wait for SC2 game loading and detect errors.
#>
[CmdletBinding()]
param(
    [string]$GameLogsPath = "C:\Users\22448\Documents\StarCraft II\GameLogs",
    [int]$MaxWaitSeconds = 180,
    [int]$GracePeriodSeconds = 20,
    [int]$PollIntervalMs = 1000,
    [string[]]$ErrorKeywords = @(
        "Script compile error",
        "was not found",
        "is not defined",
        "syntax error",
        "Cannot find",
        "Unknown function"
    )
)

$ErrorActionPreference = "Stop"

function Get-ScriptErrorLogPath {
    $latest = Get-ChildItem -LiteralPath $GameLogsPath -Filter "*ScriptError*" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    return $latest
}

function Get-AlertsLogPath {
    $latest = Get-ChildItem -LiteralPath $GameLogsPath -Filter "*Alerts*" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    return $latest
}

function Get-ScriptErrorContent {
    $errorLog = Get-ScriptErrorLogPath
    if (-not $errorLog) { return "" }
    try {
        return Get-Content -LiteralPath $errorLog.FullName -Raw -ErrorAction SilentlyContinue
    } catch {
        return ""
    }
}

function Test-HasScriptError {
    $content = Get-ScriptErrorContent
    if ([string]::IsNullOrWhiteSpace($content)) { return $false }
    foreach ($keyword in $ErrorKeywords) {
        if ($content -match [regex]::Escape($keyword)) { return $true }
    }
    return $false
}

function Test-Sc2ProcessRunning {
    $sc2 = Get-Process -Name "SC2_x64" -ErrorAction SilentlyContinue
    return ($null -ne $sc2)
}

function Write-ScriptErrorReport {
    $errorLog = Get-ScriptErrorLogPath
    if (-not $errorLog) { Write-Host "No ScriptError file"; return }
    $content = Get-ScriptErrorContent
    if ([string]::IsNullOrWhiteSpace($content)) { Write-Host "ScriptError empty"; return }
    Write-Host ""
    Write-Host "===== ScriptError.txt ====="
    Write-Host "File: $($errorLog.FullName)"
    Write-Host "Time: $($errorLog.LastWriteTime)"
    Write-Host ""
    Write-Host $content
    Write-Host "============================"
}

$startTime = Get-Date
$alertsDetectedTime = $null
$scriptErrorBaselineTime = $null
$scriptErrorBaselineContent = $null

Write-Host "=== Smart Wait for Game ==="
Write-Host "GameLogs: $GameLogsPath"
Write-Host "MaxWait: $MaxWaitSeconds s"
Write-Host "GracePeriod: $GracePeriodSeconds s"
Write-Host ""

while ($true) {
    $elapsed = (Get-Date) - $startTime
    if ($elapsed.TotalSeconds -ge $MaxWaitSeconds) {
        Write-Host ""
        Write-Warning "Timeout after $MaxWaitSeconds seconds"
        if (Test-Sc2ProcessRunning) {
            Write-Host "Game process running, but no Alerts.txt detected"
            exit 2
        } else {
            Write-Error "Game process exited and timeout"
            Write-ScriptErrorReport
            exit 1
        }
    }

    if (-not (Test-Sc2ProcessRunning)) {
        Write-Host ""
        Write-Error "Game process exited (crash)"
        Write-ScriptErrorReport
        exit 1
    }

    $currentScriptError = Get-ScriptErrorLogPath
    $currentScriptErrorTime = if ($currentScriptError) { $currentScriptError.LastWriteTime } else { $null }
    $currentScriptErrorContent = Get-ScriptErrorContent

    $alertsLog = Get-AlertsLogPath
    if ($alertsLog -and $null -eq $alertsDetectedTime) {
        $alertsDetectedTime = Get-Date
        Write-Host ""
        Write-Host ">>> Alerts.txt detected: $($alertsLog.FullName)"
        Write-Host ">>> Starting $GracePeriodSeconds s grace period..."
        $scriptErrorBaselineTime = $currentScriptErrorTime
        $scriptErrorBaselineContent = $currentScriptErrorContent
        if ($currentScriptError -and (Test-HasScriptError)) {
            Write-Host ">>> ScriptError exists at start, observing for updates"
        }
    }

    if ($null -ne $alertsDetectedTime) {
        $graceElapsed = ((Get-Date) - $alertsDetectedTime).TotalSeconds
        
        $hasNewScriptError = $false
        if ($currentScriptError) {
            if ($null -eq $scriptErrorBaselineTime) {
                $hasNewScriptError = $true
                Write-Host ">>> New ScriptError appeared"
            } elseif ($currentScriptErrorTime -gt $scriptErrorBaselineTime) {
                $hasNewScriptError = $true
                Write-Host ">>> ScriptError updated"
            } elseif ($currentScriptErrorContent -ne $scriptErrorBaselineContent) {
                $hasNewScriptError = $true
                Write-Host ">>> ScriptError content changed"
            }
        }

        if ($hasNewScriptError -and (Test-HasScriptError)) {
            Write-Host ""
            Write-Error "New script error detected!"
            Write-ScriptErrorReport
            exit 1
        }

        if ($graceElapsed -ge $GracePeriodSeconds) {
            Write-Host ""
            Write-Host "=== Game Loading Complete ==="
            Write-Host "Alerts.txt appeared"
            Write-Host "No new ScriptError in $GracePeriodSeconds s"
            Write-Host "Total time: $([math]::Round($elapsed.TotalSeconds, 1)) s"
            Write-Host "Game process: Running"
            if ($currentScriptError) {
                Write-Host "ScriptError: Exists but no critical error"
            } else {
                Write-Host "ScriptError: Not detected"
            }
            exit 0
        }

        $graceRemaining = [math]::Ceiling($GracePeriodSeconds - $graceElapsed)
        Write-Progress -Activity "Grace Period" -Status "$([math]::Floor($graceElapsed)) / $GracePeriodSeconds s" -PercentComplete ([math]::Floor($graceElapsed / $GracePeriodSeconds * 100))
    } else {
        $remaining = [math]::Ceiling($MaxWaitSeconds - $elapsed.TotalSeconds)
        Write-Progress -Activity "Waiting" -Status "$([math]::Floor($elapsed.TotalSeconds)) / $MaxWaitSeconds s - Waiting for Alerts.txt" -PercentComplete ([math]::Floor($elapsed.TotalSeconds / $MaxWaitSeconds * 100))
    }

    Start-Sleep -Milliseconds $PollIntervalMs
}