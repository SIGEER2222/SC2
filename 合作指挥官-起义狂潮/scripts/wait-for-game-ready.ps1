<#
.SYNOPSIS
智能等待 SC2 游戏加载完成并检测是否有报错，替代固定 120 秒等待。

.DESCRIPTION
通过轮询 GameLogs 目录和游戏进程状态，智能判断：
- 失败：Alerts.txt 出现后 20 秒内出现新的 ScriptError / 游戏进程崩溃退出
- 成功：Alerts.txt 出现 + 等待 20 秒无新 ScriptError + 游戏进程存活

重要：脚本不会删除任何日志文件，保留完整错误信息供调试。

.EXAMPLE
  pwsh -File .\scripts\wait-for-game-ready.ps1

.EXAMPLE
  pwsh -File .\scripts\wait-for-game-ready.ps1 -MaxWaitSeconds 180 -GracePeriodSeconds 20
#>
[CmdletBinding()]
param(
    [string]$GameLogsPath = "C:\Users\22448\Documents\StarCraft II\GameLogs",
    [int]$MaxWaitSeconds = 180,
    [int]$GracePeriodSeconds = 20,
    [int]$PollIntervalMs = 1000,
    [string[]]$ErrorKeywords = @(
        "Script compile error",
        "脚本编译错误",
        "脚本读取失败",
        "解析函数行出错",
        "was not found",
        "is not defined",
        "syntax error",
        "Cannot find",
        "Cannot find function",
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
    if (-not $errorLog) {
        return ""
    }
    try {
        return Get-Content -LiteralPath $errorLog.FullName -Raw -ErrorAction SilentlyContinue
    }
    catch {
        return ""
    }
}

function Test-HasScriptError {
    $content = Get-ScriptErrorContent
    if ([string]::IsNullOrWhiteSpace($content)) {
        return $false
    }
    foreach ($keyword in $ErrorKeywords) {
        if ($content -match [regex]::Escape($keyword)) {
            return $true
        }
    }
    return $false
}

function Test-Sc2ProcessRunning {
    $sc2 = Get-Process -Name "SC2_x64" -ErrorAction SilentlyContinue
    return ($null -ne $sc2)
}

function Write-ScriptErrorReport {
    $errorLog = Get-ScriptErrorLogPath
    if (-not $errorLog) {
        Write-Host "未找到 ScriptError 文件"
        return
    }
    $content = Get-ScriptErrorContent
    if ([string]::IsNullOrWhiteSpace($content)) {
        Write-Host "ScriptError 文件内容为空"
        return
    }
    Write-Host ""
    Write-Host "===== ScriptError.txt 报错内容 ====="
    Write-Host "文件: $($errorLog.FullName)"
    Write-Host "时间: $($errorLog.LastWriteTime)"
    Write-Host ""
    Write-Host $content
    Write-Host "====================================="
}

$startTime = Get-Date
$alertsDetectedTime = $null
$scriptErrorBaselineTime = $null
$scriptErrorBaselineContent = $null

Write-Host "=== 智能等待游戏加载 ==="
Write-Host "GameLogs: $GameLogsPath"
Write-Host "最大等待: ${MaxWaitSeconds}s"
Write-Host "宽限期: Alerts.txt 出现后等待 ${GracePeriodSeconds}s 无新 ScriptError 才算成功"
Write-Host ""

while ($true) {
    $elapsed = (Get-Date) - $startTime
    if ($elapsed.TotalSeconds -ge $MaxWaitSeconds) {
        Write-Host ""
        Write-Warning "超时 (${MaxWaitSeconds}s)"
        if (Test-Sc2ProcessRunning) {
            Write-Host "游戏进程仍在运行，但未检测到 Alerts.txt"
            Write-Host "请手动检查游戏状态"
            exit 2
        }
        else {
            Write-Error "游戏进程已退出，且超时"
            Write-ScriptErrorReport
            exit 1
        }
    }

    # 检查游戏进程
    if (-not (Test-Sc2ProcessRunning)) {
        Write-Host ""
        Write-Error "游戏进程已退出（崩溃/加载失败）"
        Write-ScriptErrorReport
        exit 1
    }

    # 获取当前 ScriptError 状态
    $currentScriptError = Get-ScriptErrorLogPath
    $currentScriptErrorTime = if ($currentScriptError) { $currentScriptError.LastWriteTime } else { $null }
    $currentScriptErrorContent = Get-ScriptErrorContent

    # 检查是否有 Alerts.txt
    $alertsLog = Get-AlertsLogPath
    if ($alertsLog -and $null -eq $alertsDetectedTime) {
        $alertsDetectedTime = Get-Date
        Write-Host ""
        Write-Host ">>> 检测到 Alerts.txt: $($alertsLog.FullName)"
        Write-Host ">>> 开始 ${GracePeriodSeconds}s 宽限期观察..."
        # 记录此时的 ScriptError 状态作为基线
        $scriptErrorBaselineTime = $currentScriptErrorTime
        $scriptErrorBaselineContent = $currentScriptErrorContent
        if ($currentScriptError -and (Test-HasScriptError)) {
            Write-Host ">>> 宽限期开始时已存在 ScriptError，将观察是否有更新"
        }
    }

    # 如果已检测到 Alerts.txt，进入宽限期观察
    if ($null -ne $alertsDetectedTime) {
        $graceElapsed = ((Get-Date) - $alertsDetectedTime).TotalSeconds
        
        # 检查是否有新的 ScriptError 或 ScriptError 内容更新
        $hasNewScriptError = $false
        if ($currentScriptError) {
            # 基线不存在，现在出现了 -> 新错误
            if ($null -eq $scriptErrorBaselineTime) {
                $hasNewScriptError = $true
                Write-Host ">>> 宽限期内出现新的 ScriptError"
            }
            # 基线存在，但时间更新了 -> 新错误
            elseif ($currentScriptErrorTime -gt $scriptErrorBaselineTime) {
                $hasNewScriptError = $true
                Write-Host ">>> 宽限期内 ScriptError 有更新"
            }
            # 基线存在，内容不同了 -> 新错误
            elseif ($currentScriptErrorContent -ne $scriptErrorBaselineContent) {
                $hasNewScriptError = $true
                Write-Host ">>> 宽限期内 ScriptError 内容有变化"
            }
        }

        if ($hasNewScriptError -and (Test-HasScriptError)) {
            Write-Host ""
            Write-Error "宽限期内检测到新的脚本错误！"
            Write-ScriptErrorReport
            exit 1
        }

        # 宽限期结束，检查最终状态
        if ($graceElapsed -ge $GracePeriodSeconds) {
            Write-Host ""
            Write-Host "=== 游戏加载完成 ==="
            Write-Host "Alerts.txt 已出现"
            Write-Host "宽限期 ${GracePeriodSeconds}s 内无新 ScriptError"
            Write-Host "总耗时: $([math]::Round($elapsed.TotalSeconds, 1))s"
            Write-Host "游戏进程: 运行中"
            if ($currentScriptError) {
                Write-Host "ScriptError: 存在但无关键错误（宽限期内无更新）"
            } else {
                Write-Host "ScriptError: 未检测到"
            }
            exit 0
        }

        $graceRemaining = [math]::Ceiling($GracePeriodSeconds - $graceElapsed)
        Write-Progress -Activity "宽限期观察" `
            -Status "已观察 $([math]::Floor($graceElapsed))s / 剩余 ${graceRemaining}s" `
            -PercentComplete ([math]::Min(100, [math]::Floor($graceElapsed / $GracePeriodSeconds * 100)))
    }
    else {
        # 还没检测到 Alerts.txt，继续等待
        $remaining = [math]::Ceiling($MaxWaitSeconds - $elapsed.TotalSeconds)
        Write-Progress -Activity "等待游戏加载" `
            -Status "已等待 $([math]::Floor($elapsed.TotalSeconds))s / 剩余 ${remaining}s | 等待 Alerts.txt..." `
            -PercentComplete ([math]::Min(100, [math]::Floor($elapsed.TotalSeconds / $MaxWaitSeconds * 100)))
    }

    Start-Sleep -Milliseconds $PollIntervalMs
}