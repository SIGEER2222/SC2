<#
.SYNOPSIS
智能等待 SC2 游戏加载完成并检测是否有报错，替代固定 120 秒等待。

.DESCRIPTION
通过轮询 GameLogs 目录和游戏进程状态，智能判断：
- 失败：ScriptError.txt 出现脚本错误 / 游戏进程崩溃退出
- 成功：游戏进程存活 + Alerts.txt 写入稳定（加载完成）+ 无严重脚本错误

.EXAMPLE
  pwsh -File .\scripts\wait-for-game-ready.ps1

.EXAMPLE
  pwsh -File .\scripts\wait-for-game-ready.ps1 -MaxWaitSeconds 180 -StableSeconds 15
#>
[CmdletBinding()]
param(
    [string]$GameLogsPath = "C:\Users\22448\Documents\StarCraft II\GameLogs",
    [int]$MaxWaitSeconds = 180,
    [int]$StableSeconds = 10,
    [int]$PollIntervalMs = 1000,
    [string[]]$ErrorKeywords = @(
        "Script compile error",
        "脚本编译错误",
        "脚本读取失败",
        "解析函数行出错",
        "was not found",
        "is not defined",
        "syntax error"
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

function Test-ScriptErrorExists {
    $errorLog = Get-ScriptErrorLogPath
    if (-not $errorLog) {
        return $false
    }

    try {
        $content = Get-Content -LiteralPath $errorLog.FullName -Raw -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($content)) {
            return $false
        }
        foreach ($keyword in $ErrorKeywords) {
            if ($content -match [regex]::Escape($keyword)) {
                Write-Host "检测到脚本错误关键词: $keyword"
                Write-Host "错误日志: $($errorLog.FullName)"
                Write-Host "----- 错误内容 -----"
                Write-Host $content
                Write-Host "-------------------"
                return $true
            }
        }
    }
    catch {
        return $false
    }

    return $false
}

function Test-Sc2ProcessRunning {
    $sc2 = Get-Process -Name "SC2_x64" -ErrorAction SilentlyContinue
    return ($null -ne $sc2)
}

function Get-AlertsLogSize {
    $alertsLog = Get-AlertsLogPath
    if (-not $alertsLog) {
        return 0
    }
    return $alertsLog.Length
}

$startTime = Get-Date
$lastAlertsSize = -1
$stableSince = $null

Write-Host "=== 智能等待游戏加载 ==="
Write-Host "GameLogs: $GameLogsPath"
Write-Host "最大等待: ${MaxWaitSeconds}s"
Write-Host "稳定判定: Alerts.txt ${StableSeconds}s 无新内容视为加载完成"
Write-Host ""

while ($true) {
    $elapsed = (Get-Date) - $startTime
    if ($elapsed.TotalSeconds -ge $MaxWaitSeconds) {
        Write-Host ""
        Write-Warning "超时 (${MaxWaitSeconds}s)，未检测到明确的成功或失败信号"
        if (Test-Sc2ProcessRunning) {
            Write-Host "游戏进程仍在运行，视为进入游戏（但请人工确认）"
            exit 0
        }
        else {
            Write-Error "游戏进程已退出，且超时未检测到明确错误"
            exit 1
        }
    }

    if (-not (Test-Sc2ProcessRunning)) {
        Write-Host ""
        Write-Error "游戏进程已退出（崩溃/加载失败）"
        if (Test-ScriptErrorExists) {
            Write-Host "同时检测到脚本错误（见上方）"
        }
        exit 1
    }

    if (Test-ScriptErrorExists) {
        Write-Host ""
        Write-Error "检测到脚本错误（见上方日志）"
        exit 1
    }

    $currentAlertsSize = Get-AlertsLogSize
    if ($currentAlertsSize -eq $lastAlertsSize -and $currentAlertsSize -gt 0) {
        if ($null -eq $stableSince) {
            $stableSince = Get-Date
        }
        $stableElapsed = ((Get-Date) - $stableSince).TotalSeconds
        if ($stableElapsed -ge $StableSeconds) {
            Write-Host ""
            Write-Host "=== 游戏加载完成 ==="
            Write-Host "Alerts.txt 已稳定 ${StableSeconds}s 无新内容"
            Write-Host "总耗时: $([math]::Round($elapsed.TotalSeconds, 1))s"
            Write-Host "游戏进程: 运行中"
            Write-Host "脚本错误: 未检测到"
            exit 0
        }
    }
    else {
        $stableSince = $null
    }

    $lastAlertsSize = $currentAlertsSize

    $remaining = [math]::Ceiling($MaxWaitSeconds - $elapsed.TotalSeconds)
    $stableStatus = if ($stableSince) { "稳定中 $([math]::Floor(((Get-Date) - $stableSince).TotalSeconds))/${StableSeconds}s" } else { "加载中" }
    Write-Progress -Activity "等待游戏加载" `
        -Status "已等待 $([math]::Floor($elapsed.TotalSeconds))s / 剩余 ${remaining}s | $stableStatus" `
        -PercentComplete ([math]::Min(100, [math]::Floor($elapsed.TotalSeconds / $MaxWaitSeconds * 100)))

    Start-Sleep -Milliseconds $PollIntervalMs
}
