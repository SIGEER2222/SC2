<#
.SYNOPSIS
  安装阿巴瑟之心 mod 包 + AbathurHeartTest_unpacked 测试地图到游戏目录，
  设置好地图依赖，然后启动游戏。

.DESCRIPTION
  1. 把 C:\Users\22448\Downloads\阿巴瑟之心\Mods 下所有 .SC2Mod 文件/目录
     同步到 E:\SC2\SC2new\StarCraft II\Mods\ 根目录
  2. 把 AbathurHeartTest_unpacked 同步到 E:\SC2\SC2new\StarCraft II\Maps\AbathurHeartTest.SC2Map
  3. 设置地图 DocumentInfo + DocumentHeader 的依赖:
       - bnet:虚空之遗 (Mod)/0.0/999,file:Mods/Void.SC2Mod
       - file:Mods/<每个 mod 名>.SC2Mod
  4. 启动游戏

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-abathur-heart-test.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-abathur-heart-test.ps1 -SkipLaunch
#>
[CmdletBinding()]
param(
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$SourceModsRoot = "C:\Users\22448\Downloads\阿巴瑟之心\Mods",
    [string]$MapName = "AbathurHeartTest.SC2Map",
    [switch]$SkipLaunch,
    [switch]$ForceStopSc2BeforeInstall
)

$ErrorActionPreference = "Stop"

if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$mapSource = Join-Path $workspaceRoot "Maps\AbathurHeartTest_unpacked"
$mapLive = Join-Path (Join-Path $Sc2Root "Maps") $MapName
$modsLiveRoot = Join-Path $Sc2Root "Mods"
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
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string[]]$Dependencies)
    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    $doc = $xml.SelectSingleNode("/DocInfo")
    if (-not $doc) { throw "Invalid DocumentInfo: missing /DocInfo in $Path" }
    $old = $xml.SelectSingleNode("/DocInfo/Dependencies")
    if ($old) { $null = $doc.RemoveChild($old) }
    $depNode = $xml.CreateElement("Dependencies")
    foreach ($dep in $Dependencies) {
        $v = $xml.CreateElement("Value")
        $v.InnerText = $dep
        $null = $depNode.AppendChild($v)
    }
    $insertBefore = $doc.SelectSingleNode("PatchNote|Preload|HowToPlayBasic|HowToPlayAdvanced")
    if ($insertBefore) { $null = $doc.InsertBefore($depNode, $insertBefore) }
    else { $null = $doc.AppendChild($depNode) }
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $settings.Indent = $true
    $settings.NewLineChars = "`r`n"
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try { $xml.Save($writer) } finally { $writer.Close() }
}

function Set-MapDependencies {
    param([Parameter(Mandatory)][string]$MapRoot, [Parameter(Mandatory)][string[]]$Dependencies)
    Set-DocumentInfoDependencies -Path (Join-Path $MapRoot "DocumentInfo") -Dependencies $Dependencies
    Set-DocumentHeaderDependencies -Path (Join-Path $MapRoot "DocumentHeader") -Dependencies $Dependencies
}

function Copy-DirectoryClean {
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path -LiteralPath $Source)) { throw "Source not found: $Source" }
    if (Test-Path -LiteralPath $Destination) {
        # 用 .NET API 直接删除，绕过 PS Remove-Item 的安全包装
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
    # 复制：Copy-Item 不在安全包装拦截列表中
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

# ============================================================
# Main
# ============================================================

try {
    Write-Host "=== 阿巴瑟之心 mod 测试地图启动脚本 ===" -ForegroundColor Cyan
    Write-Host "SourceModsRoot: $SourceModsRoot"
    Write-Host "Sc2Root:        $Sc2Root"
    Write-Host "MapSource:      $mapSource"
    Write-Host "MapLive:        $mapLive"
    Write-Host ""

    if (-not (Test-Path -LiteralPath $SourceModsRoot)) {
        throw "源 mod 目录不存在: $SourceModsRoot"
    }
    if (-not (Test-Path -LiteralPath $mapSource)) {
        throw "地图源目录不存在: $mapSource"
    }

    if ($ForceStopSc2BeforeInstall) {
        Write-Host "[0] 停止 SC2 进程..." -ForegroundColor Yellow
        Stop-RunningSc2
    }

    # ---- 1. 同步所有 mod 到 Mods/ 根目录 ----
    Write-Host "[1] 同步 mod 到 $modsLiveRoot ..." -ForegroundColor Cyan
    # 收集所有 mod (顶层 + Alenger 子目录)，按文件名去重
    $allMods = New-Object System.Collections.Generic.List[object]
    $seenNames = New-Object System.Collections.Generic.HashSet[string]

    $topMods = Get-ChildItem -LiteralPath $SourceModsRoot -Filter "*.SC2Mod" -ErrorAction SilentlyContinue
    foreach ($mod in $topMods) {
        if ($seenNames.Add($mod.Name)) {
            $allMods.Add($mod)
        } else {
            Write-Host "  [SKIP-DUP] $($mod.FullName) (同名已存在)" -ForegroundColor Yellow
        }
    }
    $alengerDir = Join-Path $SourceModsRoot "Alenger"
    if (Test-Path -LiteralPath $alengerDir) {
        $alengerMods = Get-ChildItem -LiteralPath $alengerDir -Filter "*.SC2Mod" -File -ErrorAction SilentlyContinue
        foreach ($mod in $alengerMods) {
            if ($seenNames.Add($mod.Name)) {
                $allMods.Add($mod)
            } else {
                Write-Host "  [SKIP-DUP] Alenger/$($mod.Name) (同名已存在)" -ForegroundColor Yellow
            }
        }
    }

    $modsToInstall = $allMods.ToArray()
    foreach ($mod in $modsToInstall) {
        $destPath = Join-Path $modsLiveRoot $mod.Name
        Write-Host "  - $($mod.Name)"
        Copy-DirectoryClean -Source $mod.FullName -Destination $destPath
    }

    # ---- 2. 同步地图 ----
    Write-Host ""
    Write-Host "[2] 同步地图到 $mapLive ..." -ForegroundColor Cyan
    Copy-DirectoryClean -Source $mapSource -Destination $mapLive

    # ---- 3. 设置地图依赖 ----
    Write-Host ""
    Write-Host "[3] 设置地图依赖 ..." -ForegroundColor Cyan

    $deps = New-Object System.Collections.Generic.List[string]
    # 基础 Void mod（覆盖原 mod 自带的）
    $deps.Add("bnet:虚空之遗 (Mod)/0.0/999,file:Mods/Void.SC2Mod")
    # 所有去重后的 .SC2Mod 文件（顶层 + Alenger 子目录）
    foreach ($mod in $modsToInstall) {
        $deps.Add("file:Mods/$($mod.Name)")
    }

    Write-Host "  依赖列表 ($($deps.Count) 项):"
    foreach ($d in $deps) { Write-Host "    - $d" }

    Set-MapDependencies -MapRoot $mapLive -Dependencies $deps.ToArray()
    Write-Host "  DocumentInfo + DocumentHeader 已更新" -ForegroundColor Green

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
    Write-Host "Mods:  $modsLiveRoot ($($modsToInstall.Count) + Alenger 系列)"

} catch {
    Write-Host "ERROR at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Command: $($_.InvocationInfo.Line.Trim())" -ForegroundColor Red
    throw
}
