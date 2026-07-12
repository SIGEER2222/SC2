<#
.SYNOPSIS
统一启动 RuntimeProbe 副官系统（游戏 + Web 面板 + Neuro 桥接）

.DESCRIPTION
一个脚本启动所有组件:
  1. 调用 launch-runtime-probe.ps1 完成游戏安装和启动（Bank 模式）
  2. 后台启动 Web 服务器（http://127.0.0.1:8080）
  3. 后台启动 Neuro 桥接器（连接 Neuro WebSocket）

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\runtime-probe\start-advisor.ps1

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\runtime-probe\start-advisor.ps1 -Commander "ZergKerrigan" -MapName "traynor01.SC2Map" -NeuroUrl "ws://127.0.0.1:41840"
#>
[CmdletBinding()]
param(
    [string]$Commander = "ZergKerrigan",
    [string]$MapName = "traynor01.SC2Map",
    [int]$Duration = 300,
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$CompositionId = "airo-runtime-probe",
    [string]$NeuroUrl = "ws://127.0.0.1:41840",
    [int]$WebPort = 8080,
    [string]$BanksPath = "C:\Users\22448\Documents\StarCraft II\Banks",
    [switch]$SkipNeuro,
    [switch]$SkipWeb,
    [switch]$SkipGame
)

$ErrorActionPreference = "Stop"
$ScriptsRoot = Split-Path -Parent $PSScriptRoot

Write-Host "======================================" -ForegroundColor Cyan
Write-Host " RuntimeProbe 副官系统统一启动" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Commander: $Commander"
Write-Host "MapName:   $MapName"
Write-Host "WebPort:   $WebPort"
Write-Host "NeuroUrl:  $NeuroUrl"
Write-Host "Duration:  ${Duration}s"
Write-Host "SkipGame:  $SkipGame"
Write-Host "SkipWeb:   $SkipWeb"
Write-Host "SkipNeuro: $SkipNeuro"
Write-Host ""

# === Step 1: 启动游戏（Bank 模式）===
if (-not $SkipGame) {
    Write-Host "[Step 1] Launching game (RuntimeProbe Bank mode)..." -ForegroundColor Yellow
    $gameLauncher = Join-Path $PSScriptRoot "launch-runtime-probe.ps1"
    $gameArgs = @(
        "-Commander", $Commander,
        "-MapName", $MapName,
        "-Duration", "$Duration",
        "-Sc2Root", $Sc2Root,
        "-CompositionId", $CompositionId,
        "-SkipWatcher"  # 由 Web 服务器接管监听
    )

    # 后台启动游戏（不阻塞）
    $gameJob = Start-Job -ScriptBlock {
        param($launcher, $args)
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $launcher @args
    } -ArgumentList $gameLauncher, $gameArgs

    Write-Host "  Game job started: $($gameJob.Id)"
    Write-Host "  Waiting 30s for game to initialize..."
    Start-Sleep -Seconds 30
}
Write-Host ""

# === Step 2: 启动 Web 服务器 ===
$webProcess = $null
if (-not $SkipWeb) {
    Write-Host "[Step 2] Starting Web server..." -ForegroundColor Yellow
    $webScript = Join-Path $PSScriptRoot "web_server.py"
    $webProcess = Start-Process -FilePath "python" -ArgumentList @(
        $webScript,
        "--banks-path", "`"$BanksPath`"",
        "--port", "$WebPort"
    ) -PassThru -NoNewWindow

    Write-Host "  Web server PID: $($webProcess.Id)"
    Write-Host "  Panel URL: http://127.0.0.1:$WebPort" -ForegroundColor Green
    Start-Sleep -Seconds 2
}
Write-Host ""

# === Step 3: 启动 Neuro 桥接 ===
$neuroProcess = $null
if (-not $SkipNeuro) {
    Write-Host "[Step 3] Starting Neuro bridge..." -ForegroundColor Yellow
    $neuroScript = Join-Path $PSScriptRoot "neuro_bridge.py"
    $neuroProcess = Start-Process -FilePath "python" -ArgumentList @(
        $neuroScript,
        "--banks-path", "`"$BanksPath`"",
        "--neuro-url", $NeuroUrl,
        "--context-interval", "10"
    ) -PassThru -NoNewWindow

    Write-Host "  Neuro bridge PID: $($neuroProcess.Id)"
    Start-Sleep -Seconds 2
}
Write-Host ""

# === 状态汇总 ===
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " 副官系统已启动" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
if (-not $SkipWeb) {
    Write-Host "  Web 面板:   http://127.0.0.1:$WebPort" -ForegroundColor Green
}
if (-not $SkipNeuro) {
    Write-Host "  Neuro 桥接: $NeuroUrl" -ForegroundColor Green
}
Write-Host ""
Write-Host "按 Ctrl+C 停止所有组件..." -ForegroundColor Yellow
Write-Host ""

# === 等待游戏结束 ===
try {
    while ($true) {
        if ($gameJob) {
            $jobState = Get-Job -Id $gameJob.Id -ErrorAction SilentlyContinue
            if ($jobState -and $jobState.State -eq "Completed") {
                Write-Host "Game job completed." -ForegroundColor Yellow
                break
            }
        }
        Start-Sleep -Seconds 5
    }
} finally {
    Write-Host "Stopping components..." -ForegroundColor Yellow

    if ($neuroProcess -and -not $neuroProcess.HasExited) {
        Stop-Process -Id $neuroProcess.Id -Force -ErrorAction SilentlyContinue
        Write-Host "  Neuro bridge stopped"
    }

    if ($webProcess -and -not $webProcess.HasExited) {
        Stop-Process -Id $webProcess.Id -Force -ErrorAction SilentlyContinue
        Write-Host "  Web server stopped"
    }

    if ($gameJob) {
        Stop-Job -Id $gameJob.Id -ErrorAction SilentlyContinue
        Remove-Job -Id $gameJob.Id -Force -ErrorAction SilentlyContinue
    }

    # 停止 SC2
    Get-Process | Where-Object { $_.ProcessName -match 'SC2|StarCraft' } | ForEach-Object {
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }

    Write-Host "All components stopped." -ForegroundColor Green
}
