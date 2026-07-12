<#
.SYNOPSIS
启动 RuntimeProbe 自动进图自检（Phase 1 NoActionProbe）

.DESCRIPTION
1. 调用 launch-7vs1-coop-test.ps1 安装地图和 Mod（-NoLaunch）
2. 注入 RuntimeProbe.SC2Mod 依赖到地图
3. 注入 LibRuntimeProbe.galaxy 到地图 Base.SC2Data
4. 在地图 BankList.xml 中添加 RuntimeProbe bank 声明
5. 启动游戏
6. 启动 Python Bank watcher 监听 Bank 文件

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\runtime-probe\launch-runtime-probe.ps1

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\runtime-probe\launch-runtime-probe.ps1 -Commanders @("TerranRaynor") -Duration 60
#>
[CmdletBinding()]
param(
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string[]]$Commanders = @("TerranRaynor"),
    [string]$CompositionId = "raynor-7vs1",
    [int]$Duration = 60,
    [string]$MapSource = "",
    [string]$LiveMapName = "7vs1CoopTest.SC2Map",
    [switch]$SkipLaunch,
    [switch]$SkipWatcher
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$probeModSource = Join-Path $workspaceRoot "Mods\RuntimeProbe\RuntimeProbe.SC2Mod"
$launcherScript = Join-Path $workspaceRoot "scripts\launch-7vs1-coop-test.ps1"

Write-Host "[RuntimeProbe] Workspace: $workspaceRoot"
Write-Host "[RuntimeProbe] Probe Mod: $probeModSource"
Write-Host "[RuntimeProbe] Composition: $CompositionId"
Write-Host ""

# Step 1: 调用现有 launcher 安装地图和 Mod（不启动游戏）
Write-Host "[Step 1] Installing map and mods via launch-7vs1-coop-test.ps1 (-NoLaunch)..."

$launcherParams = @{
    NoLaunch = $true
    Sc2Root = $Sc2Root
    Commanders = $Commanders
    LiveMapName = $LiveMapName
    ForceStopSc2BeforeInstall = $true
}
if ($MapSource) {
    $launcherParams.MapSource = $MapSource
}

& $launcherScript @launcherParams
# launcher 脚本不设置退出码，用 $?(最后一个命令成功) 检查
if (-not $?) {
    throw "launch-7vs1-coop-test.ps1 failed"
}
Write-Host "[Step 1] Done."
Write-Host ""

# Step 2: 定位 live map
# 地图可能安装在 Maps/<LiveMapName> 或 Maps/7vs1/<LiveMapName>
$liveMapDir = Join-Path $Sc2Root "Maps\7vs1\$LiveMapName"
if (-not (Test-Path -LiteralPath $liveMapDir)) {
    $liveMapDir = Join-Path $Sc2Root "Maps\$LiveMapName"
}
if (-not (Test-Path -LiteralPath $liveMapDir)) {
    # 搜索所有子目录
    $found = Get-ChildItem -LiteralPath (Join-Path $Sc2Root "Maps") -Directory -Filter $LiveMapName -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $liveMapDir = $found.FullName
    }
}
if (-not (Test-Path -LiteralPath $liveMapDir)) {
    throw "Live map directory not found: $liveMapDir"
}

Write-Host "[RuntimeProbe] Live map: $liveMapDir"

# Step 3: 注入 RuntimeProbe Galaxy 库到地图 Base.SC2Data
Write-Host "[Step 3] Injecting LibRuntimeProbe.galaxy into map..."
$mapBaseData = Join-Path $liveMapDir "Base.SC2Data"
if (-not (Test-Path -LiteralPath $mapBaseData)) {
    New-Item -ItemType Directory -Path $mapBaseData -Force | Out-Null
}

$probeGalaxyHeader = Join-Path $probeModSource "Base.SC2Data\LibRuntimeProbe_h.galaxy"
$probeGalaxyImpl = Join-Path $probeModSource "Base.SC2Data\LibRuntimeProbe.galaxy"
$mapGalaxyHeader = Join-Path $mapBaseData "LibRuntimeProbe_h.galaxy"
$mapGalaxyImpl = Join-Path $mapBaseData "LibRuntimeProbe.galaxy"

Copy-Item -LiteralPath $probeGalaxyHeader -Destination $mapGalaxyHeader -Force
Copy-Item -LiteralPath $probeGalaxyImpl -Destination $mapGalaxyImpl -Force
Write-Host "  Copied: LibRuntimeProbe_h.galaxy"
Write-Host "  Copied: LibRuntimeProbe.galaxy"

# 注入 include 和 InitLibs 到地图主触发器文件
# MapScript.galaxy 可能在地图根目录或 Base.SC2Data 下
$mapScript = Join-Path $liveMapDir "MapScript.galaxy"
if (-not (Test-Path -LiteralPath $mapScript)) {
    $mapScript = Join-Path $mapBaseData "MapScript.galaxy"
}
if (Test-Path -LiteralPath $mapScript) {
    $content = Get-Content -LiteralPath $mapScript -Raw
    $modified = $false

    # 1. 注入 include（在最后一个 include 之后）
    # 必须同时注入头文件和实现文件，否则会报"函数已声明但尚未定义"
    $needHeader = $content -notmatch 'include\s+"LibRuntimeProbe_h"'
    $needImpl = $content -notmatch 'include\s+"LibRuntimeProbe"'
    if ($needHeader -or $needImpl) {
        # 找到所有 include 行，在最后一个 include 之后插入
        $lastInclude = [regex]::Matches($content, '(?m)^\s*include\s+"[^"]+"')
        if ($lastInclude.Count -gt 0) {
            $insertPos = $lastInclude[$lastInclude.Count - 1].Index + $lastInclude[$lastInclude.Count - 1].Length
            $insertLines = @()
            if ($needHeader) { $insertLines += 'include "LibRuntimeProbe_h"' }
            if ($needImpl) { $insertLines += 'include "LibRuntimeProbe"' }
            $insertBlock = "`r`n" + ($insertLines -join "`r`n")
            $content = $content.Substring(0, $insertPos) + $insertBlock + $content.Substring($insertPos)
            $modified = $true
            Write-Host "  Injected includes in MapScript.galaxy: $($insertLines -join ', ')"
        }
    } else {
        Write-Host "  MapScript.galaxy already includes LibRuntimeProbe"
    }

    # 2. 注入 InitLibs 调用（在 InitLibs 函数的最后一个 InitLib() 之后）
    if ($content -notmatch 'libRuntimeProbe_InitLib\(\)') {
        # 找到 InitLibs 函数体中的最后一个 InitLib() 调用
        $initLibsMatch = [regex]::Match($content, '(?ms)void\s+InitLibs\s*\([^)]*\)\s*\{([^}]+)\}')
        if ($initLibsMatch.Success) {
            $funcBody = $initLibsMatch.Groups[1].Value
            $lastInitCall = [regex]::Matches($funcBody, 'lib\w+_InitLib\s*\(\s*\)\s*;')
            if ($lastInitCall.Count -gt 0) {
                $lastMatch = $lastInitCall[$lastInitCall.Count - 1]
                $insertOffset = $initLibsMatch.Groups[1].Index + $lastMatch.Index + $lastMatch.Length
                $newContent = $content.Substring(0, $insertOffset) + "`r`n" + "    " +
                    'libRuntimeProbe_InitLib();' +
                    $content.Substring($insertOffset)
                $content = $newContent
                $modified = $true
                Write-Host "  Injected InitLibs call in MapScript.galaxy"
            }
        }
    } else {
        Write-Host "  MapScript.galaxy already calls libRuntimeProbe_InitLib"
    }

    if ($modified) {
        Set-Content -LiteralPath $mapScript -Value $content -NoNewline -Encoding UTF8
        Write-Host "  MapScript.galaxy updated"
    }
} else {
    Write-Host "  [WARN] MapScript.galaxy not found at $mapScript"
    Write-Host "  Galaxy library files copied but not included in MapScript"
    Write-Host "  Manual inclusion may be required"
}

# Step 4: 在地图 BankList.xml 中添加 RuntimeProbe bank 声明
Write-Host "[Step 4] Adding RuntimeProbe to BankList.xml..."
$bankListPath = Join-Path $liveMapDir "BankList.xml"
if (Test-Path -LiteralPath $bankListPath) {
    [xml]$bankList = Get-Content -LiteralPath $bankListPath -Raw
    $existing = $bankList.SelectSingleNode("/BankList/Bank[@Name='RuntimeProbe']")
    if (-not $existing) {
        $newBank = $bankList.CreateElement("Bank")
        $newBank.SetAttribute("Name", "RuntimeProbe")
        $newBank.SetAttribute("Player", "1")
        $bankList.DocumentElement.AppendChild($newBank)
        $bankList.Save($bankListPath)
        Write-Host "  Added: <Bank Name='RuntimeProbe' Player='1'/>"
    } else {
        Write-Host "  RuntimeProbe bank already declared"
    }
} else {
    # 创建 BankList.xml
    $bankListContent = '<?xml version="1.0" encoding="utf-8"?>' + "`r`n" +
        '<BankList>' + "`r`n" +
        '    <Bank Name="RuntimeProbe" Player="1"/>' + "`r`n" +
        '</BankList>'
    Set-Content -LiteralPath $bankListPath -Value $bankListContent -NoNewline -Encoding UTF8
    Write-Host "  Created BankList.xml with RuntimeProbe bank"
}

# Step 5: 复制 RuntimeProbe.SC2Mod 到 SC2 Mods 目录（可选，因为 galaxy 已直接注入）
Write-Host "[Step 5] RuntimeProbe mod injection complete (galaxy injected directly)."

Write-Host ""
Write-Host "[RuntimeProbe] Installation complete."
Write-Host ""

# Step 6: 启动游戏
if (-not $SkipLaunch) {
    Write-Host "[Step 6] Launching game..."
    $switcherPath = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
    if (-not (Test-Path -LiteralPath $switcherPath)) {
        # 尝试 SC2_x64.exe
        $versionsDir = Join-Path $Sc2Root "Versions"
        $baseDir = Get-ChildItem -LiteralPath $versionsDir -Directory -Filter "Base*" -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | Select-Object -First 1
        if ($baseDir) {
            $switcherPath = Join-Path $baseDir.FullName "SC2_x64.exe"
        }
    }

    if (-not (Test-Path -LiteralPath $switcherPath)) {
        throw "SC2 executable not found in $Sc2Root"
    }

    Write-Host "  Switcher: $switcherPath"
    Write-Host "  Map: $liveMapDir"
    # 与 launch-airo-campaign.ps1 一致：用引号包裹地图路径作为 ArgumentList
    $proc = Start-Process -FilePath $switcherPath -ArgumentList "`"$liveMapDir`"" -PassThru
    Write-Host "  SC2 PID: $($proc.Id)"
    Write-Host ""

    # 等待游戏启动
    Write-Host "  Waiting 15s for game to start..."
    Start-Sleep -Seconds 15
}

# Step 7: 启动 Python Bank watcher
if (-not $SkipWatcher) {
    Write-Host "[Step 7] Starting Python Bank watcher..."
    $runnerScript = Join-Path $PSScriptRoot "runtime_probe_runner.py"
    $banksPath = Join-Path $env:USERPROFILE "Documents\StarCraft II\Banks"
    $reportDir = Join-Path $PSScriptRoot "reports"

    $watcherArgs = @(
        "python",
        $runnerScript,
        "--banks-path", $banksPath,
        "--composition-id", $CompositionId,
        "--output-dir", $reportDir,
        "--duration", $Duration
    )

    Write-Host "  Runner: $runnerScript"
    Write-Host "  Banks: $banksPath"
    Write-Host "  Reports: $reportDir"
    Write-Host "  Duration: ${Duration}s"
    Write-Host ""

    & python $runnerScript --banks-path $banksPath --composition-id $CompositionId --output-dir $reportDir --duration $Duration
}

Write-Host ""
Write-Host "[RuntimeProbe] Done."
