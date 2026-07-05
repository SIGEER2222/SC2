<#
.SYNOPSIS
  阿巴瑟之心测试地图 - 游戏加载检测脚本

.DESCRIPTION
  等待 SC2 进程启动，检测 Alerts.txt 出现，宽限期监听 ScriptError，
  输出加载结果。仅用于 AbathurHeartTest.SC2Map。

  退出码:
    0 = 成功（Alerts.txt 出现 + 宽限期无新错误 + 进程存活）
    1 = 失败（出现新 ScriptError 或游戏进程崩溃）
    2 = 超时（无 Alerts.txt）
#>
[CmdletBinding()]
param(
    [string]$GameLogsPath = "C:\Users\22448\Documents\StarCraft II\GameLogs",
    [int]$MaxWaitSeconds = 240,
    [int]$GracePeriodSeconds = 25,
    [int]$PollIntervalMs = 1000
)

$ErrorActionPreference = "Stop"

# 关键错误关键字（出现即视为加载失败）
$ErrorKeywords = @(
    "Script compile error",
    "was not found",
    "is not defined",
    "syntax error",
    "Cannot find",
    "Unknown function",
    "Function decl"
)

function Get-LatestFile {
    param([string]$Filter)
    return Get-ChildItem -LiteralPath $GameLogsPath -Filter $Filter -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Get-FileContent {
    param($FileInfo)
    if (-not $FileInfo) { return "" }
    try { return Get-Content -LiteralPath $FileInfo.FullName -Raw -ErrorAction SilentlyContinue }
    catch { return "" }
}

function Test-Sc2Running {
    return $null -ne (Get-Process -Name "SC2_x64" -ErrorAction SilentlyContinue)
}

function Test-ContentHasError {
    param([string]$Content)
    if ([string]::IsNullOrWhiteSpace($Content)) { return $false }
    foreach ($kw in $ErrorKeywords) {
        if ($Content -match [regex]::Escape($kw)) { return $true }
    }
    return $false
}

function Show-ScriptError {
    $log = Get-LatestFile -Filter "*ScriptError*"
    if (-not $log) { Write-Host "[无 ScriptError 文件]"; return }
    $content = Get-FileContent -FileInfo $log
    Write-Host ""
    Write-Host "===== ScriptError.txt =====" -ForegroundColor Red
    Write-Host "File: $($log.FullName)"
    Write-Host "Time: $($log.LastWriteTime)"
    Write-Host ""
    Write-Host $content
    Write-Host "============================" -ForegroundColor Red
}

Write-Host "=== 阿巴瑟之心测试地图加载检测 ===" -ForegroundColor Cyan
Write-Host "GameLogs:     $GameLogsPath"
Write-Host "MaxWait:      $MaxWaitSeconds s"
Write-Host "GracePeriod:  $GracePeriodSeconds s"
Write-Host ""

$startTime = Get-Date
$alertsTime = $null
$baselineErrorTime = $null
$baselineErrorContent = $null

while ($true) {
    $elapsed = (Get-Date) - $startTime

    # 超时
    if ($elapsed.TotalSeconds -ge $MaxWaitSeconds) {
        Write-Host ""
        Write-Warning "超时 $MaxWaitSeconds 秒"
        if (Test-Sc2Running) {
            Write-Host "游戏进程存活，但未检测到 Alerts.txt" -ForegroundColor Yellow
            exit 2
        } else {
            Write-Host "游戏进程已退出且超时" -ForegroundColor Red
            Show-ScriptError
            exit 1
        }
    }

    # 进程崩溃
    if (-not (Test-Sc2Running)) {
        Write-Host ""
        Write-Host "游戏进程已退出（崩溃）" -ForegroundColor Red
        Show-ScriptError
        exit 1
    }

    # 当前 ScriptError
    $curErrorLog = Get-LatestFile -Filter "*ScriptError*"
    $curErrorTime = if ($curErrorLog) { $curErrorLog.LastWriteTime } else { $null }
    $curErrorContent = Get-FileContent -FileInfo $curErrorLog

    # 检测 Alerts.txt
    $alertsLog = Get-LatestFile -Filter "*Alerts*"
    if ($alertsLog -and $null -eq $alertsTime) {
        $alertsTime = Get-Date
        Write-Host ""
        Write-Host ">>> 检测到 Alerts.txt: $($alertsLog.FullName)" -ForegroundColor Green
        Write-Host ">>> 开始 $GracePeriodSeconds 秒宽限期..." -ForegroundColor Green
        $baselineErrorTime = $curErrorTime
        $baselineErrorContent = $curErrorContent
        if ($curErrorLog -and (Test-ContentHasError -Content $curErrorContent)) {
            Write-Host ">>> 警告：宽限期开始时已有 ScriptError" -ForegroundColor Yellow
        }
    }

    # 宽限期检查
    if ($null -ne $alertsTime) {
        $graceElapsed = ((Get-Date) - $alertsTime).TotalSeconds

        # 检测新的 ScriptError
        $hasNewError = $false
        if ($curErrorLog) {
            if ($null -eq $baselineErrorTime) {
                $hasNewError = $true
            } elseif ($curErrorTime -gt $baselineErrorTime) {
                $hasNewError = $true
            } elseif ($curErrorContent -ne $baselineErrorContent) {
                $hasNewError = $true
            }
        }

        if ($hasNewError -and (Test-ContentHasError -Content $curErrorContent)) {
            Write-Host ""
            Write-Host ">>> 检测到新的 ScriptError" -ForegroundColor Red
            Show-ScriptError
            exit 1
        }

        # 宽限期结束
        if ($graceElapsed -ge $GracePeriodSeconds) {
            Write-Host ""
            Write-Host "=== 加载成功 ===" -ForegroundColor Green
            Write-Host "Alerts.txt:     已出现"
            Write-Host "宽限期:         $GracePeriodSeconds 秒内无新错误"
            Write-Host "总耗时:         $([math]::Round($elapsed.TotalSeconds, 1)) 秒"
            Write-Host "游戏进程:       存活"
            if ($curErrorLog) {
                Write-Host "ScriptError:    存在但无关键错误"
            } else {
                Write-Host "ScriptError:    未检测到"
            }
            exit 0
        }

        $remain = [math]::Ceiling($GracePeriodSeconds - $graceElapsed)
        Write-Progress -Activity "宽限期" -Status "$([math]::Floor($graceElapsed)) / $GracePeriodSeconds s" -PercentComplete ([math]::Floor($graceElapsed / $GracePeriodSeconds * 100))
    } else {
        $remain = [math]::Ceiling($MaxWaitSeconds - $elapsed.TotalSeconds)
        Write-Progress -Activity "等待加载" -Status "$([math]::Floor($elapsed.TotalSeconds)) / $MaxWaitSeconds s - 等待 Alerts.txt" -PercentComplete ([math]::Floor($elapsed.TotalSeconds / $MaxWaitSeconds * 100))
    }

    Start-Sleep -Milliseconds $PollIntervalMs
}
