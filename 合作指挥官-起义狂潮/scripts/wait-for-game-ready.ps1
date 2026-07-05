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
        "Unknown function",
        "参数类型同函数定义不匹配",
        "脚本读取失败",
        "函数已声明但尚未定义"
    ),
    [string[]]$WarnKeywords = @(
        "出现触发器错误",
        "无权调用"
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

# 提取 ScriptError 内容中包含致命错误关键字的行
# 用于精确比较两次 ScriptError 之间是否新增了致命错误（避免 LastWriteTime 变化但内容相同的误报）
function Get-FatalErrorLines {
    param([string]$Content)
    if ([string]::IsNullOrWhiteSpace($Content)) { return @() }
    $lines = $Content -split "`r?`n"
    $fatalLines = @()
    foreach ($line in $lines) {
        foreach ($keyword in $ErrorKeywords) {
            if ($line -match [regex]::Escape($keyword)) {
                $fatalLines += $line.Trim()
                break
            }
        }
    }
    return $fatalLines
}

function Get-ScriptWarnings {
    $content = Get-ScriptErrorContent
    if ([string]::IsNullOrWhiteSpace($content)) { return @() }
    $warnings = @()
    foreach ($keyword in $WarnKeywords) {
        if ($content -match [regex]::Escape($keyword)) {
            $warnings += $keyword
        }
    }
    return $warnings
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

        # 只在致命错误内容真正增加时才报错（避免 LastWriteTime 变化但内容相同的误报）
        # 比较 baseline 之后新增的致命错误行
        $hasNewFatalError = $false
        if ($currentScriptError -and (Test-HasScriptError)) {
            if ($null -eq $scriptErrorBaselineContent) {
                # baseline 时无 ScriptError，现在有致命错误
                $hasNewFatalError = $true
            } elseif ($currentScriptErrorContent -ne $scriptErrorBaselineContent) {
                # 内容有变化，检查是否新增了致命错误行
                $currentFatalLines = Get-FatalErrorLines $currentScriptErrorContent
                $baselineFatalLines = Get-FatalErrorLines $scriptErrorBaselineContent
                foreach ($line in $currentFatalLines) {
                    if ($baselineFatalLines -notcontains $line) {
                        $hasNewFatalError = $true
                        break
                    }
                }
            }
        }

        if ($hasNewFatalError) {
            Write-Host ""
            Write-Error "New fatal script error detected!"
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
                $warnings = Get-ScriptWarnings
                if ($warnings.Count -gt 0) {
                    Write-Host "ScriptError: Exists with runtime warnings (non-fatal): $($warnings -join ', ')"
                } else {
                    Write-Host "ScriptError: Exists but no critical error"
                }
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