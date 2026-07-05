<#
.SYNOPSIS
  阿巴瑟指挥官启动地图（虫心mod测试地图_unpacked）启动脚本。

.DESCRIPTION
  地图:    合作指挥官-起义狂潮/Maps/虫心mod测试地图_unpacked
  依赖:    Mods/crys_the_swarm_reborn.SC2Mod (已存在于 SC2 Mods 目录)
  机制:    Bank(cryswarmcoop) 的 Commanders/Commander=Abathur 字段触发 mod 自动启动阿巴瑟指挥官
           mod 在 MapInit 中:
             1. SetUpgradeLevelForPlayer(p, "Abathur", 1)  -> 解锁阿巴瑟子菜单和单位
             2. 把玩家1的 K5Kerrigan 替换为 HunterKiller（阿巴瑟英雄单位）

  本脚本:
    1. 同步地图到 SC2 Maps 目录 (AbathurRebornCoopTest.SC2Map)
    2. 同步地图 DocumentInfo + DocumentHeader 的依赖:
         - bnet:虚空之遗 (Mod)/0.0/999,file:Mods/Void.SC2Mod
         - file:Mods/crys_the_swarm_reborn.SC2Mod
    3. 清理游戏日志
    4. 启动游戏

  前置条件:
    - SC2 Mods 目录中已存在 crys_the_swarm_reborn.SC2Mod
    - C:\Users\22448\Documents\StarCraft II\Banks\cryswarmcoop.SC2Bank 中 Commanders/Commander="Abathur"

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-abathur-reborn-coop.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-abathur-reborn-coop.ps1 -SkipLaunch
#>
[CmdletBinding()]
param(
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$MapName = "AbathurRebornCoopTest.SC2Map",
    [string]$SourceModName = "crys_the_swarm_reborn.SC2Mod",
    [switch]$SkipLaunch,
    [switch]$ForceStopSc2BeforeInstall
)

$ErrorActionPreference = "Stop"

if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$mapSource = Join-Path $workspaceRoot "Maps\虫心mod测试地图_unpacked"
$mapLive = Join-Path (Join-Path $Sc2Root "Maps") $MapName
$modsLiveRoot = Join-Path $Sc2Root "Mods"
$switcherPath = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
$logsRoot = "C:\Users\22448\Documents\StarCraft II\GameLogs"
$sourceModPath = Join-Path $modsLiveRoot $SourceModName

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

function Write-FileBytesWithRetry {
    param([string]$Path, [byte[]]$Bytes, [int]$RetryCount = 10, [int]$DelayMs = 500)
    for ($i = 1; $i -le $RetryCount; $i++) {
        try { [System.IO.File]::WriteAllBytes($Path, $Bytes); return }
        catch { if ($i -ge $RetryCount) { throw }; Start-Sleep -Milliseconds $DelayMs }
    }
}

function Test-ByteSequenceAt {
    param([byte[]]$Bytes, [int]$Offset, [byte[]]$Needle)
    if ($Offset + $Needle.Length -gt $Bytes.Length) { return $false }
    for ($i = 0; $i -lt $Needle.Length; $i++) {
        if ($Bytes[$Offset + $i] -ne $Needle[$i]) { return $false }
    }
    return $true
}

function Find-DocumentHeaderDependencyStart {
    param([byte[]]$Bytes)
    $markers = @(
        [System.Text.Encoding]::UTF8.GetBytes("file:"),
        [System.Text.Encoding]::UTF8.GetBytes("bnet:")
    )
    for ($offset = 4; $offset -lt $Bytes.Length; $offset++) {
        foreach ($marker in $markers) {
            if (-not (Test-ByteSequenceAt -Bytes $Bytes -Offset $offset -Needle $marker)) { continue }
            $count = [System.BitConverter]::ToUInt32($Bytes, $offset - 4)
            if (($count -gt 0) -and ($count -lt 128)) { return $offset }
        }
    }
    throw "DocumentHeader dependency table not found."
}

function Get-DocumentHeaderDependencyEndOffset {
    param([byte[]]$Bytes, [int]$Start, [uint32]$Count)
    $offset = $Start
    for ($i = 0; $i -lt $Count; $i++) {
        while (($offset -lt $Bytes.Length) -and ($Bytes[$offset] -ne 0)) { $offset++ }
        if ($offset -ge $Bytes.Length) { throw "dep string not null-terminated" }
        $offset++
    }
    return $offset
}

function Set-DocumentHeaderDependencies {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string[]]$Dependencies)
    if (-not (Test-Path -LiteralPath $Path)) { throw "DocumentHeader not found: $Path" }
    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($Path)
    $depStart = Find-DocumentHeaderDependencyStart -Bytes $bytes
    $countOffset = $depStart - 4
    $currentCount = [System.BitConverter]::ToUInt32($bytes, $countOffset)
    $depEnd = Get-DocumentHeaderDependencyEndOffset -Bytes $bytes -Start $depStart -Count $currentCount
    $depBytes = [System.Text.Encoding]::UTF8.GetBytes((($Dependencies -join "`0") + "`0"))
    $countBytes = [System.BitConverter]::GetBytes([uint32]$Dependencies.Count)
    $stream = New-Object System.IO.MemoryStream
    $stream.Write($bytes, 0, $countOffset)
    $stream.Write($countBytes, 0, $countBytes.Length)
    $stream.Write($depBytes, 0, $depBytes.Length)
    $stream.Write($bytes, $depEnd, $bytes.Length - $depEnd)
    Write-FileBytesWithRetry -Path $Path -Bytes $stream.ToArray()
}

function Set-DocumentInfoDependencies {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string[]]$Dependencies, [string[]]$BankPreloads)
    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    $doc = $xml.SelectSingleNode("/DocInfo")
    if (-not $doc) { throw "Invalid DocumentInfo: missing /DocInfo in $Path" }

    # 替换 Dependencies
    $old = $xml.SelectSingleNode("/DocInfo/Dependencies")
    if ($old) { $null = $doc.RemoveChild($old) }
    $depNode = $xml.CreateElement("Dependencies")
    foreach ($dep in $Dependencies) {
        $v = $xml.CreateElement("Value")
        $v.InnerText = $dep
        $null = $depNode.AppendChild($v)
    }

    # 替换 Preload
    $oldPreload = $xml.SelectSingleNode("/DocInfo/Preload")
    if ($oldPreload) { $null = $doc.RemoveChild($oldPreload) }
    $preloadNode = $xml.CreateElement("Preload")
    foreach ($preload in $BankPreloads) {
        $v = $xml.CreateElement("Value")
        $v.InnerText = $preload
        $null = $preloadNode.AppendChild($v)
    }

    $insertBefore = $doc.SelectSingleNode("PatchNote|HowToPlayBasic|HowToPlayAdvanced")
    if ($insertBefore) {
        $null = $doc.InsertBefore($depNode, $insertBefore)
        $null = $doc.InsertBefore($preloadNode, $insertBefore)
    } else {
        $null = $doc.AppendChild($depNode)
        $null = $doc.AppendChild($preloadNode)
    }
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $settings.Indent = $true
    $settings.NewLineChars = "`r`n"
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try { $xml.Save($writer) } finally { $writer.Close() }
}

function Set-MapDependencies {
    param([Parameter(Mandatory)][string]$MapRoot, [Parameter(Mandatory)][string[]]$Dependencies, [string[]]$BankPreloads)
    Set-DocumentInfoDependencies -Path (Join-Path $MapRoot "DocumentInfo") -Dependencies $Dependencies -BankPreloads $BankPreloads
    Set-DocumentHeaderDependencies -Path (Join-Path $MapRoot "DocumentHeader") -Dependencies $Dependencies
}

function Copy-DirectoryClean {
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path -LiteralPath $Source)) { throw "Source not found: $Source" }
    if (Test-Path -LiteralPath $Destination) {
        $item = Get-Item -LiteralPath $Destination -Force
        if ($item.PSIsContainer) {
            [System.IO.Directory]::Delete($Destination, $true)
        } else {
            [System.IO.File]::Delete($Destination)
        }
    }
    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent)) {
        [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

# ============================================================
# Main
# ============================================================

try {
    Write-Host "=== 阿巴瑟指挥官启动地图 (虫心mod测试地图_unpacked) ===" -ForegroundColor Cyan
    Write-Host "Sc2Root:    $Sc2Root"
    Write-Host "MapSource:  $mapSource"
    Write-Host "MapLive:     $mapLive"
    Write-Host "SourceMod:   $sourceModPath"
    Write-Host ""

    if (-not (Test-Path -LiteralPath $mapSource)) {
        throw "地图源目录不存在: $mapSource"
    }
    if (-not (Test-Path -LiteralPath $sourceModPath)) {
        throw "源 mod 不存在于 SC2 Mods 目录: $sourceModPath (请先安装 crys_the_swarm_reborn mod 及其依赖)"
    }

    if ($ForceStopSc2BeforeInstall) {
        Write-Host "[0] 停止 SC2 进程..." -ForegroundColor Yellow
        Stop-RunningSc2
    }

    # ---- 1. 同步地图 ----
    Write-Host ""
    Write-Host "[1] 同步地图到 $mapLive ..." -ForegroundColor Cyan
    Copy-DirectoryClean -Source $mapSource -Destination $mapLive

    # ---- 2. 设置地图依赖 ----
    Write-Host ""
    Write-Host "[2] 设置地图依赖 ..." -ForegroundColor Cyan

    $deps = @(
        "bnet:虚空之遗 (Mod)/0.0/999,file:Mods/Void.SC2Mod",
        "file:Mods/$SourceModName"
    )
    $bankPreloads = @(
        "Bank;cryswarmcoop;1"
    )

    Write-Host "  依赖列表 ($($deps.Count) 项):"
    foreach ($d in $deps) { Write-Host "    - $d" }
    Write-Host "  Bank Preload ($($bankPreloads.Count) 项):"
    foreach ($b in $bankPreloads) { Write-Host "    - $b" }

    Set-MapDependencies -MapRoot $mapLive -Dependencies $deps -BankPreloads $bankPreloads
    Write-Host "  DocumentInfo + DocumentHeader 已更新" -ForegroundColor Green

    # ---- 3. 验证 Bank 文件存在 ----
    Write-Host ""
    Write-Host "[3] 验证 Bank 文件 ..." -ForegroundColor Cyan
    $bankFile = "C:\Users\22448\Documents\StarCraft II\Banks\cryswarmcoop.SC2Bank"
    if (-not (Test-Path -LiteralPath $bankFile)) {
        Write-Host "  [警告] Bank 文件不存在: $bankFile" -ForegroundColor Yellow
        Write-Host "  请手动创建 Bank 文件，内容示例:" -ForegroundColor Yellow
        Write-Host '  <Bank version="1"><Section name="Commanders"><Key name="Commander"><Value text="Abathur"/></Key></Section></Bank>' -ForegroundColor Yellow
    } else {
        [xml]$bankXml = Get-Content -LiteralPath $bankFile -Raw
        $cmdNode = $bankXml.SelectSingleNode("/Bank/Section[@name='Commanders']/Key[@name='Commander']/Value")
        if ($cmdNode) {
            $cmdValue = $cmdNode.GetAttribute("text")
            Write-Host "  Bank OK: Commanders/Commander = '$cmdValue'" -ForegroundColor Green
            if ($cmdValue -ne "Abathur") {
                Write-Host "  [警告] 当前 Commander 不是 'Abathur'，阿巴瑟指挥官不会启动" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [警告] Bank 中没有 Commanders/Commander 字段" -ForegroundColor Yellow
        }
    }

    # ---- 4. 清理游戏日志 ----
    Write-Host ""
    Write-Host "[4] 清理游戏日志 ..." -ForegroundColor Cyan
    Clear-Sc2GameLogs

    # ---- 5. 启动游戏 ----
    Write-Host ""
    Write-Host "[5] 启动游戏 ..." -ForegroundColor Cyan
    if ($SkipLaunch) {
        Write-Host "  SkipLaunch 已设置，跳过启动" -ForegroundColor Yellow
    } else {
        Stop-RunningSc2
        if (-not (Test-Path -LiteralPath $switcherPath)) {
            throw "SC2Switcher not found: $switcherPath"
        }
        Write-Host "  Launching: $mapLive"
        & $switcherPath $mapLive
    }

    Write-Host ""
    Write-Host "=== Done ===" -ForegroundColor Green
    Write-Host "Map:   $mapLive"
    Write-Host "Mod:    $sourceModPath"
    Write-Host "Bank:   C:\Users\22448\Documents\StarCraft II\Banks\cryswarmcoop.SC2Bank (Commander=Abathur)"

} catch {
    Write-Host "ERROR at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Command: $($_.InvocationInfo.Line.Trim())" -ForegroundColor Red
    throw
}
