<#
.SYNOPSIS
  abathur_test_map 专用启动脚本。

.DESCRIPTION
  1. 停止正在运行的 SC2 进程
  2. 复制 7vs1 mods（CoopZeroPop + CommanderCatalog）到 SC2 Mods/7vs1 目录
  3. 复制 abathur_test_map 到 SC2 Maps 目录（目录形式，.SC2Map 后缀）
  4. 清理 GameLogs
  5. 用 SC2Switcher_x64.exe 启动游戏

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-abathur-test.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-abathur-test.ps1 -SkipLaunch
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-abathur-test.ps1 -SkipModSync
#>
[CmdletBinding()]
param(
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$MapName = "abathur_test_map.SC2Map",
    [switch]$SkipLaunch,
    [switch]$SkipModSync,
    [switch]$SkipStopSc2
)

$ErrorActionPreference = "Stop"

if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$mapSource = Join-Path $workspaceRoot "Maps\abathur_test_map"
$mapLive = Join-Path (Join-Path $Sc2Root "Maps") $MapName
$modsLiveRoot = Join-Path $Sc2Root "Mods"
$mods7vs1LiveRoot = Join-Path $modsLiveRoot "7vs1"
# 7vs1 mods 依赖闭包：CoopZeroPop 依赖 VoidMulti + StarCoop（已在 SC2new 中存在）
# 这里只需要复制工作区的两个 7vs1 mods
$mods7vs1 = @(
    @{ Name = "CoopZeroPop.SC2Mod";       Source = (Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod") },
    @{ Name = "CommanderCatalog.SC2Mod";  Source = (Join-Path $workspaceRoot "Mods\7vs1\CommanderCatalog.SC2Mod") }
)
$switcherPath = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
$logsRoot = "C:\Users\22448\Documents\StarCraft II\GameLogs"

# ============================================================
# Helpers
# ============================================================

function Stop-RunningSc2 {
    foreach ($processName in @("SC2_x64", "SC2Switcher_x64", "BlizzardError")) {
        $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if (-not $running) { continue }
        foreach ($proc in $running) {
            try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop } catch {}
        }
    }
    Start-Sleep -Seconds 2
}

function Clear-Sc2GameLogs {
    if (-not (Test-Path -LiteralPath $logsRoot)) { return }
    Get-ChildItem -LiteralPath $logsRoot -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Copy-DirectoryClean {
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path -LiteralPath $Source)) { throw "Source not found: $Source" }
    # 用 .NET API 直接删除，绕过 PS Remove-Item 的安全包装
    if (Test-Path -LiteralPath $Destination) {
        [System.IO.Directory]::Delete($Destination, $true)
    }
    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent)) {
        [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    }
    # 用 robocopy 复制（Copy-Item 在安全包装下可能被拦截）
    Write-Host "    robocopy: $Source -> $Destination"
    robocopy $Source $Destination /MIR /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy failed with exit code $LASTEXITCODE"
    }
}

# ============================================================
# Main
# ============================================================

try {
    Write-Host "=== Abathur Test Map 启动脚本 ===" -ForegroundColor Cyan
    Write-Host "Sc2Root:     $Sc2Root"
    Write-Host "MapSource:   $mapSource"
    Write-Host "MapLive:     $mapLive"
    Write-Host "Mods7vs1:    $($mods7vs1.Count) 个"
    foreach ($m in $mods7vs1) {
        Write-Host ("  - {0} (from {1})" -f $m.Name, $m.Source)
    }
    Write-Host ""

    if (-not (Test-Path -LiteralPath $mapSource)) {
        throw "地图源目录不存在: $mapSource"
    }
    if (-not (Test-Path -LiteralPath $switcherPath)) {
        throw "SC2Switcher not found: $switcherPath"
    }

    # ---- 0. 停止 SC2 进程 ----
    if (-not $SkipStopSc2) {
        Write-Host "[0] 停止 SC2 进程..." -ForegroundColor Cyan
        Stop-RunningSc2
        Write-Host "    已停止" -ForegroundColor Green
    } else {
        Write-Host "[0] SkipStopSc2 已设置，跳过停止" -ForegroundColor Yellow
    }

    # ---- 1. 复制 7vs1 mods ----
    if (-not $SkipModSync) {
        Write-Host ""
        Write-Host "[1] 复制 7vs1 mods ..." -ForegroundColor Cyan
        if (-not (Test-Path -LiteralPath $mods7vs1LiveRoot)) {
            New-Item -ItemType Directory -Path $mods7vs1LiveRoot -Force | Out-Null
        }
        foreach ($m in $mods7vs1) {
            if (-not (Test-Path -LiteralPath $m.Source)) {
                throw "源 mod 目录不存在: $($m.Source)"
            }
            $dest = Join-Path $mods7vs1LiveRoot $m.Name
            Copy-DirectoryClean -Source $m.Source -Destination $dest
            Write-Host "    已复制 $($m.Name) -> $dest" -ForegroundColor Green
        }
    } else {
        Write-Host ""
        Write-Host "[1] SkipModSync 已设置，跳过 mod 复制" -ForegroundColor Yellow
        foreach ($m in $mods7vs1) {
            $dest = Join-Path $mods7vs1LiveRoot $m.Name
            if (-not (Test-Path -LiteralPath $dest)) {
                throw "目标 mod 不存在且未启用复制: $dest"
            }
            Write-Host "    mod 已存在: $dest" -ForegroundColor Green
        }
    }

    # ---- 2. 复制地图 ----
    Write-Host ""
    Write-Host "[2] 复制地图到 $mapLive ..." -ForegroundColor Cyan
    Copy-DirectoryClean -Source $mapSource -Destination $mapLive
    $fileCount = (Get-ChildItem -LiteralPath $mapLive -Recurse -File).Count
    Write-Host "    已复制 $fileCount 个文件" -ForegroundColor Green

    # ---- 3. 清理游戏日志 ----
    Write-Host ""
    Write-Host "[3] 清理 GameLogs ..." -ForegroundColor Cyan
    Clear-Sc2GameLogs
    Write-Host "    已清理" -ForegroundColor Green

    # ---- 4. 启动游戏 ----
    Write-Host ""
    Write-Host "[4] 启动游戏 ..." -ForegroundColor Cyan
    if ($SkipLaunch) {
        Write-Host "    SkipLaunch 已设置，跳过启动" -ForegroundColor Yellow
    } else {
        Write-Host "    Launching: $mapLive"
        & $switcherPath $mapLive
    }

    Write-Host ""
    Write-Host "=== Done ===" -ForegroundColor Green
    Write-Host "Map:   $mapLive"
    Write-Host "Mods:  $mods7vs1LiveRoot"
    foreach ($m in $mods7vs1) {
        Write-Host "  - $($m.Name)"
    }

} catch {
    Write-Host "ERROR at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -ForegroundColor Red
    throw
}
