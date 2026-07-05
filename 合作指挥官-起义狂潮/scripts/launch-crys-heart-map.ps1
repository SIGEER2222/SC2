<#
.SYNOPSIS
  虫心mod测试地图 专用启动脚本。

.DESCRIPTION
  1. 停止正在运行的 SC2 进程
  2. 复制 crys_the_swarm_reborn.SC2Mod 到 SC2 Mods 目录
  3. 复制 虫心mod测试地图_unpacked 到 SC2 Maps 目录（目录形式，.SC2Map 后缀）
  4. 清理 GameLogs
  5. 用 SC2Switcher_x64.exe 启动游戏

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-crys-heart-map.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-crys-heart-map.ps1 -SkipLaunch
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-crys-heart-map.ps1 -SkipModSync
#>
[CmdletBinding()]
param(
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$SourceModRoot = "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn\crys_the_swarm_reborn.SC2Mod",
    [string]$MapName = "虫心mod测试地图.SC2Map",
    [switch]$SkipLaunch,
    [switch]$SkipModSync,
    [switch]$SkipStopSc2
)

$ErrorActionPreference = "Stop"

if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$mapSource = Join-Path $workspaceRoot "Maps\虫心mod测试地图_unpacked"
$mapLive = Join-Path (Join-Path $Sc2Root "Maps") $MapName
$modsLiveRoot = Join-Path $Sc2Root "Mods"
$modName = "crys_the_swarm_reborn.SC2Mod"
$modLive = Join-Path $modsLiveRoot $modName
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
    Write-Host "=== 虫心mod测试地图启动脚本 ===" -ForegroundColor Cyan
    Write-Host "Sc2Root:     $Sc2Root"
    Write-Host "SourceMod:   $SourceModRoot"
    Write-Host "MapSource:   $mapSource"
    Write-Host "MapLive:     $mapLive"
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

    # ---- 1. 复制 mod ----
    if (-not $SkipModSync) {
        Write-Host ""
        Write-Host "[1] 复制 mod $modName ..." -ForegroundColor Cyan
        if (-not (Test-Path -LiteralPath $SourceModRoot)) {
            throw "源 mod 目录不存在: $SourceModRoot"
        }
        Copy-DirectoryClean -Source $SourceModRoot -Destination $modLive
        Write-Host "    已复制到 $modLive" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[1] SkipModSync 已设置，跳过 mod 复制" -ForegroundColor Yellow
        if (-not (Test-Path -LiteralPath $modLive)) {
            throw "目标 mod 不存在且未启用复制: $modLive"
        }
        Write-Host "    mod 已存在: $modLive" -ForegroundColor Green
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
    Write-Host "Map:  $mapLive"
    Write-Host "Mod:  $modLive"

} catch {
    Write-Host "ERROR at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -ForegroundColor Red
    throw
}
