<#
.SYNOPSIS
启动 RuntimeProbe 自动进图自检（Bank 单次扫描模式）

.DESCRIPTION
零持续开销方案。只在游戏初始化时执行一次扫描（units + upgrades + producers），
不注册周期性 tick，游戏内运行时开销几乎为零。

流程:
  1. 调用 launch-airo-campaign.ps1 -NoLaunch 完成上游安装（mods + map + Bank）
  2. 复制 LibRuntimeProbe galaxy 文件到 live 地图
  3. Patch MapScript.galaxy：注入 include + InitLibs + StartProbe 调用
  4. Patch BankList.xml：追加 RuntimeProbe Bank 声明
  5. 启动游戏
  6. 启动 Python watcher 等待 Bank 文件并生成报告

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\runtime-probe\launch-runtime-probe.ps1

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\runtime-probe\launch-runtime-probe.ps1 -Commander "ZergKerrigan" -MapName "traynor01.SC2Map" -Duration 90
#>
[CmdletBinding()]
param(
    [string]$Commander = "ZergKerrigan",
    [string]$MapName = "traynor01.SC2Map",
    [int]$Duration = 90,
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$CompositionId = "airo-runtime-probe",
    [switch]$SkipLaunch,
    [switch]$SkipWatcher
)

$ErrorActionPreference = "Stop"

$ScriptsRoot   = Split-Path -Parent $PSScriptRoot            # .../scripts
$ProjRoot      = Split-Path -Parent $ScriptsRoot               # .../合作指挥官-起义狂潮
$probeModSource = Join-Path $ProjRoot "Mods\RuntimeProbe\RuntimeProbe.SC2Mod"
$airoLauncher   = Join-Path $ScriptsRoot "airo\launch-airo-campaign.ps1"

Write-Host "=== RuntimeProbe Launcher (Bank single-scan mode) ==="
Write-Host "Commander: $Commander"
Write-Host "MapName:   $MapName"
Write-Host "Sc2Root:   $Sc2Root"
Write-Host "ProbeMod:  $probeModSource"
Write-Host "Duration:  ${Duration}s"
Write-Host ""

# === Step 1: 上游 AIRO 安装（不启动游戏）===
Write-Host "[Step 1] Run launch-airo-campaign.ps1 -NoLaunch (upstream installer)..."
if (-not (Test-Path -LiteralPath $airoLauncher)) {
    throw "AIRO launcher not found: $airoLauncher"
}

& $airoLauncher -Commander $Commander -MapName $MapName -NoLaunch
if (-not $?) {
    throw "launch-airo-campaign.ps1 failed"
}
Write-Host "[Step 1] Done."
Write-Host ""

# === Step 2: 定位 live 地图目录 ===
$MapLivePath = Join-Path $Sc2Root "Maps\$MapName"
if (-not (Test-Path -LiteralPath $MapLivePath)) {
    throw "Live map directory not found: $MapLivePath"
}
Write-Host "[RuntimeProbe] Live map: $MapLivePath"

$mapBaseData = Join-Path $MapLivePath "Base.SC2Data"
$mapScriptPath = Join-Path $MapLivePath "MapScript.galaxy"
$bankListPath = Join-Path $MapLivePath "BankList.xml"

# === Step 3: 复制 RuntimeProbe galaxy 文件到 live 地图 ===
Write-Host "[Step 3] Copy RuntimeProbe galaxy files to live map..."
$probeGalaxyHeader = Join-Path $probeModSource "Base.SC2Data\LibRuntimeProbe_h.galaxy"
$probeGalaxyImpl   = Join-Path $probeModSource "Base.SC2Data\LibRuntimeProbe.galaxy"
$mapGalaxyHeader   = Join-Path $mapBaseData "LibRuntimeProbe_h.galaxy"
$mapGalaxyImpl     = Join-Path $mapBaseData "LibRuntimeProbe.galaxy"

if (-not (Test-Path -LiteralPath $probeGalaxyHeader)) {
    throw "Probe galaxy header not found: $probeGalaxyHeader"
}
if (-not (Test-Path -LiteralPath $probeGalaxyImpl)) {
    throw "Probe galaxy impl not found: $probeGalaxyImpl"
}

[System.IO.File]::Copy($probeGalaxyHeader, $mapGalaxyHeader, $true)
[System.IO.File]::Copy($probeGalaxyImpl,   $mapGalaxyImpl,   $true)
Write-Host "  Copied: LibRuntimeProbe_h.galaxy"
Write-Host "  Copied: LibRuntimeProbe.galaxy"

# === Step 4: Patch MapScript.galaxy ===
Write-Host "[Step 4] Patch MapScript.galaxy..."
$content = [System.IO.File]::ReadAllText($mapScriptPath)
$modified = $false

# 4a. 追加 include 语句（在最后一个 include 之后）
$needHeader = $content -notmatch 'include\s+"LibRuntimeProbe_h"'
$needImpl   = $content -notmatch 'include\s+"LibRuntimeProbe"\s'
if ($needHeader -or $needImpl) {
    $lastIncludeMatches = [regex]::Matches($content, '(?m)^\s*include\s+"[^"]+"')
    if ($lastIncludeMatches.Count -gt 0) {
        $lastMatch = $lastIncludeMatches[$lastIncludeMatches.Count - 1]
        $insertOffset = $lastMatch.Index + $lastMatch.Length
        $inject = ""
        if ($needHeader) { $inject += "`r`ninclude `"LibRuntimeProbe_h`"" }
        if ($needImpl)   { $inject += "`r`ninclude `"LibRuntimeProbe`"" }
        $content = $content.Substring(0, $insertOffset) + $inject + $content.Substring($insertOffset)
        $modified = $true
        Write-Host "  Injected include statements"
    }
}

# 4b. 在 InitLibs() 中追加 libRuntimeProbe_InitLib() 调用
if ($content -notmatch 'libRuntimeProbe_InitLib\s*\(\s*\)') {
    $initLibsMatch = [regex]::Match($content, '(?ms)void\s+InitLibs\s*\([^)]*\)\s*\{([^}]+)\}')
    if ($initLibsMatch.Success) {
        $funcBody = $initLibsMatch.Groups[1].Value
        $initCalls = [regex]::Matches($funcBody, 'lib\w+_InitLib\s*\(\s*\)\s*;')
        if ($initCalls.Count -gt 0) {
            $lastCall = $initCalls[$initCalls.Count - 1]
            $insertOffset = $initLibsMatch.Groups[1].Index + $lastCall.Index + $lastCall.Length
            $newContent = $content.Substring(0, $insertOffset) + "`r`n    libRuntimeProbe_InitLib();" +
                          $content.Substring($insertOffset)
            $content = $newContent
            $modified = $true
            Write-Host "  Injected libRuntimeProbe_InitLib() call in InitLibs()"
        }
    }
}

# 4c. 在 gt_Initialization_Func 中注入 libRuntimeProbe_gf_StartProbe() 调用
if ($content -notmatch 'libRuntimeProbe_gf_StartProbe\s*\(\s*\)') {
    $airoInitPattern = '(?m)^(    libAIROAdapter_gf_InitUnitReplacement\s*\(\s*\)\s*;\s*\r?\n)'
    if ($content -match $airoInitPattern) {
        $initLine = $matches[0]
        $probeCall = "    // RuntimeProbe: single-scan probe`r`n    libRuntimeProbe_gf_StartProbe();`r`n"
        $content = $content -replace [regex]::Escape($initLine), ($initLine + $probeCall)
        $modified = $true
        Write-Host "  Injected libRuntimeProbe_gf_StartProbe() after libAIROAdapter_gf_InitUnitReplacement()"
    }
}

if ($modified) {
    [System.IO.File]::WriteAllText($mapScriptPath, $content)
    Write-Host "  MapScript.galaxy saved"
}
Write-Host ""

# === Step 5: Patch BankList.xml ===
Write-Host "[Step 5] Patch BankList.xml..."
$bankListContent = [System.IO.File]::ReadAllText($bankListPath)
if ($bankListContent -notmatch 'Name="RuntimeProbe"') {
    $bankListContent = $bankListContent -replace '</BankList>', '    <Bank Name="RuntimeProbe" Player="1"/>`r`n</BankList>'
    [System.IO.File]::WriteAllText($bankListPath, $bankListContent)
    Write-Host "  Added RuntimeProbe Bank declaration"
} else {
    Write-Host "  RuntimeProbe Bank already declared"
}
Write-Host ""

# === Step 6: 启动游戏 ===
if (-not $SkipLaunch) {
    Write-Host "[Step 6] Launching game..."
    $switcherPath = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
    if (-not (Test-Path -LiteralPath $switcherPath)) {
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
    $proc = Start-Process -FilePath $switcherPath -ArgumentList "`"$MapLivePath`"" -PassThru
    Write-Host "  SC2 PID: $($proc.Id)"
    Write-Host "  Waiting 15s for game to start..."
    Start-Sleep -Seconds 15
}
Write-Host ""

# === Step 7: 启动 Python Bank watcher ===
if (-not $SkipWatcher) {
    Write-Host "[Step 7] Start Python Bank watcher..."
    $runnerScript = Join-Path $PSScriptRoot "runtime_probe_runner.py"
    $banksPath = "C:\Users\22448\Documents\StarCraft II\Banks"
    $reportDir = Join-Path $PSScriptRoot "reports"

    if (-not (Test-Path -LiteralPath $runnerScript)) {
        throw "Runner script not found: $runnerScript"
    }

    Write-Host "  Runner:   $runnerScript"
    Write-Host "  Banks:    $banksPath"
    Write-Host "  Reports:  $reportDir"
    Write-Host "  Duration: ${Duration}s"
    Write-Host ""

    & python $runnerScript --banks-path $banksPath --composition-id $CompositionId --output-dir $reportDir --duration $Duration
}

Write-Host ""
Write-Host "[RuntimeProbe] Done."
