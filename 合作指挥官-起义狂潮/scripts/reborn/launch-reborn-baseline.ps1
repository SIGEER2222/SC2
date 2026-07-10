<#
.SYNOPSIS
  重生虫心原版基线启动脚本。
  同步全部 5 个 Reborn Mod 到 SC2 目录，复制地图，启动游戏。

.DESCRIPTION
  1. 停止正在运行的 SC2 进程
  2. 同步 5 个 Reborn Mod（目录型 + MPQ 文件型）到 SC2 Mods 目录
  3. 复制目标地图到 SC2 Maps 目录
  4. 清理 GameLogs
  5. 用 SC2Switcher_x64.exe 启动游戏
  6. 等待游戏就绪

.PARAMETER MapSource
  源地图路径（解包目录或 MPQ 文件）

.PARAMETER MapName
  地图在 SC2 Maps 目录下的名字（含 .SC2Map 后缀）

.EXAMPLE
  # 启动 zexpedition03（目录型地图）
  .\scripts\reborn\launch-reborn-baseline.ps1 `
    -MapSource "C:\...\reborn\zexpedition03.SC2Map" `
    -MapName "zexpedition03.SC2Map"

.EXAMPLE
  # 启动 zstorychar（MPQ 文件型地图）
  .\scripts\reborn\launch-reborn-baseline.ps1 `
    -MapSource "C:\...\reborn\zstorychar.SC2Map" `
    -MapName "zstorychar.SC2Map"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$MapSource,

    [Parameter(Mandatory=$true)]
    [string]$MapName,

    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",

    [string]$ProjectModsRoot = "",

    [switch]$SkipLaunch,
    [switch]$SkipModSync,
    [switch]$SkipStopSc2,
    [switch]$SkipWait
)

$ErrorActionPreference = "Stop"

if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

if (-not $ProjectModsRoot) {
    $ProjectModsRoot = Join-Path $workspaceRoot "Mods"
}

$modsLiveRoot = Join-Path $Sc2Root "Mods"
$switcherPath = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
$mapsLiveRoot = Join-Path $Sc2Root "Maps"
$logsRoot = "C:\Users\22448\Documents\StarCraft II\GameLogs"
$waitScript = Join-Path $workspaceRoot "scripts\wait-for-game-ready.ps1"

# Reborn 5 mods
$rebornMods = @(
    "crys_the_swarm_reborn.SC2Mod",
    "crys_swarm_assets.SC2Mod",
    "sibirens_starhooks_common.SC2Mod",
    "sibirens_starhooks_swarmstoryutils.SC2Mod",
    "sibirens_sundries_swarm_reborn.SC2Mod"
)

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

function Sync-ModToLive {
    param([string]$ModName)
    $src = Join-Path $ProjectModsRoot $ModName
    $dst = Join-Path $modsLiveRoot $ModName

    if (-not (Test-Path -LiteralPath $src)) {
        throw "Project mod not found: $src"
    }

    $srcItem = Get-Item $src
    if ($srcItem.PSIsContainer) {
        # 目录型 Mod：用 robocopy
        if (Test-Path -LiteralPath $dst) {
            [System.IO.Directory]::Delete($dst, $true)
        }
        [System.IO.Directory]::CreateDirectory($dst) | Out-Null
        robocopy $src $dst /MIR /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) {
            throw "robocopy failed for ${ModName}: exit ${LASTEXITCODE}"
        }
        Write-Host "    [dir] ${ModName} -> $dst"
    } else {
        # MPQ 文件型 Mod：直接复制文件
        [System.IO.Directory]::CreateDirectory($modsLiveRoot) | Out-Null
        [System.IO.File]::Copy($src, $dst, $true)
        Write-Host "    [file] ${ModName} -> $dst"
    }
}

function Sync-MapToLive {
    param([string]$Source, [string]$TargetName)
    $dst = Join-Path $mapsLiveRoot $TargetName

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Map source not found: $Source"
    }

    $srcItem = Get-Item $Source
    if ($srcItem.PSIsContainer) {
        # 目录型地图
        if (Test-Path -LiteralPath $dst) {
            [System.IO.Directory]::Delete($dst, $true)
        }
        [System.IO.Directory]::CreateDirectory($dst) | Out-Null
        robocopy $Source $dst /MIR /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) {
            throw "robocopy failed for map: exit ${LASTEXITCODE}"
        }
        $fileCount = (Get-ChildItem -LiteralPath $dst -Recurse -File).Count
        Write-Host "    [dir] ${TargetName} -> $dst ($fileCount files)"
    } else {
        # MPQ 文件型地图
        [System.IO.Directory]::CreateDirectory($mapsLiveRoot) | Out-Null
        [System.IO.File]::Copy($Source, $dst, $true)
        Write-Host "    [file] ${TargetName} -> $dst"
    }
}

# ============================================================
# Main
# ============================================================

try {
    Write-Host "=== 重生虫心基线启动脚本 ===" -ForegroundColor Cyan
    Write-Host "Sc2Root:      $Sc2Root"
    Write-Host "MapSource:    $MapSource"
    Write-Host "MapName:      $MapName"
    Write-Host ""

    if (-not (Test-Path -LiteralPath $MapSource)) {
        throw "地图源不存在: $MapSource"
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

    # ---- 1. 同步 5 个 Reborn Mod ----
    if (-not $SkipModSync) {
        Write-Host ""
        Write-Host "[1] 同步 Reborn Mod 到 SC2 Mods 目录..." -ForegroundColor Cyan
        foreach ($mod in $rebornMods) {
            Sync-ModToLive -ModName $mod
        }
        Write-Host "    全部同步完成" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[1] SkipModSync 已设置，跳过 mod 同步" -ForegroundColor Yellow
    }

    # ---- 2. 复制地图 ----
    Write-Host ""
    Write-Host "[2] 复制地图..." -ForegroundColor Cyan
    Sync-MapToLive -Source $MapSource -TargetName $MapName

    # ---- 3. 清理游戏日志 ----
    Write-Host ""
    Write-Host "[3] 清理 GameLogs..." -ForegroundColor Cyan
    Clear-Sc2GameLogs
    Write-Host "    已清理" -ForegroundColor Green

    # ---- 4. 启动游戏 ----
    Write-Host ""
    Write-Host "[4] 启动游戏..." -ForegroundColor Cyan
    if ($SkipLaunch) {
        Write-Host "    SkipLaunch 已设置，跳过启动" -ForegroundColor Yellow
    } else {
        $mapLive = Join-Path $mapsLiveRoot $MapName
        Write-Host "    Launching: $mapLive"
        Start-Process -FilePath $switcherPath -ArgumentList "`"$mapLive`""
    }

    # ---- 5. 等待游戏就绪 ----
    if (-not $SkipWait -and -not $SkipLaunch) {
        Write-Host ""
        Write-Host "[5] 等待游戏就绪..." -ForegroundColor Cyan
        if (Test-Path -LiteralPath $waitScript) {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $waitScript
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    等待脚本返回非零: $LASTEXITCODE" -ForegroundColor Yellow
            } else {
                Write-Host "    游戏就绪" -ForegroundColor Green
            }
        } else {
            Write-Host "    wait-for-game-ready.ps1 未找到，跳过等待" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "=== Done ===" -ForegroundColor Green

} catch {
    Write-Host "ERROR at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -ForegroundColor Red
    throw
}