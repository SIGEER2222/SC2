<#
.SYNOPSIS
启动 RuntimeProbe 自动进图自检（基于 AIRO Campaign Launcher）

.DESCRIPTION
复用 launch-airo-campaign.ps1 的完整安装流程（mods + map + Bank + MapScript patches），
然后在 live 地图上额外注入 RuntimeProbe 探针：
  1. 调用 launch-airo-campaign.ps1 -NoLaunch 完成上游安装（不启动游戏）
  2. 复制 LibRuntimeProbe_h.galaxy / LibRuntimeProbe.galaxy 到 live 地图 Base.SC2Data
  3. Patch MapScript.galaxy：追加 include + InitLibs() 中追加 libRuntimeProbe_InitLib() 调用
  4. Patch BankList.xml：追加 <Bank Name="RuntimeProbe" Player="1"/>
  5. 启动游戏（与 AIRO 启动器一致：SC2Switcher_x64.exe "MapLivePath"）
  6. 启动 Python Bank watcher 监听 RuntimeProbe.SC2Bank

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

Write-Host "=== RuntimeProbe Launcher (AIRO upstream) ==="
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

# === Step 2: 定位 live 地图目录（AIRO 装到 Maps\<MapName>）===
$MapLivePath = Join-Path $Sc2Root "Maps\$MapName"
if (-not (Test-Path -LiteralPath $MapLivePath)) {
    throw "Live map directory not found: $MapLivePath"
}
Write-Host "[RuntimeProbe] Live map: $MapLivePath"

# === Step 3: 复制 RuntimeProbe galaxy 文件到 live 地图 Base.SC2Data ===
Write-Host "[Step 3] Inject LibRuntimeProbe.galaxy into live map..."
$mapBaseData = Join-Path $MapLivePath "Base.SC2Data"
if (-not (Test-Path -LiteralPath $mapBaseData)) {
    [System.IO.Directory]::CreateDirectory($mapBaseData) | Out-Null
}

$probeGalaxyHeader = Join-Path $probeModSource "Base.SC2Data\LibRuntimeProbe_h.galaxy"
$probeGalaxyImpl   = Join-Path $probeModSource "Base.SC2Data\LibRuntimeProbe.galaxy"
$mapGalaxyHeader   = Join-Path $mapBaseData "LibRuntimeProbe_h.galaxy"
$mapGalaxyImpl     = Join-Path $mapBaseData "LibRuntimeProbe.galaxy"

if (-not (Test-Path -LiteralPath $probeGalaxyHeader)) {
    throw "Probe header not found: $probeGalaxyHeader"
}
if (-not (Test-Path -LiteralPath $probeGalaxyImpl)) {
    throw "Probe impl not found: $probeGalaxyImpl"
}

[System.IO.File]::Copy($probeGalaxyHeader, $mapGalaxyHeader, $true)
[System.IO.File]::Copy($probeGalaxyImpl,   $mapGalaxyImpl,   $true)
Write-Host "  Copied: LibRuntimeProbe_h.galaxy"
Write-Host "  Copied: LibRuntimeProbe.galaxy"

# === Step 4: Patch MapScript.galaxy（追加 include + InitLib 调用）===
Write-Host "[Step 4] Patch MapScript.galaxy..."
$mapScriptPath = Join-Path $MapLivePath "MapScript.galaxy"
if (-not (Test-Path -LiteralPath $mapScriptPath)) {
    throw "MapScript.galaxy not found: $mapScriptPath"
}

$content = [System.IO.File]::ReadAllText($mapScriptPath)
$modified = $false

# 4a. 注入 include（在最后一个 include 之后追加）
#     必须同时注入头文件和实现文件，否则 galaxy 编译器报"函数已声明但尚未定义"。
$needHeader = $content -notmatch 'include\s+"LibRuntimeProbe_h"'
$needImpl   = $content -notmatch 'include\s+"LibRuntimeProbe"\s'
if ($needHeader -or $needImpl) {
    $lastIncludeMatches = [regex]::Matches($content, '(?m)^\s*include\s+"[^"]+"')
    if ($lastIncludeMatches.Count -gt 0) {
        $last = $lastIncludeMatches[$lastIncludeMatches.Count - 1]
        $insertPos = $last.Index + $last.Length
        $insertLines = @()
        if ($needHeader) { $insertLines += 'include "LibRuntimeProbe_h"' }
        if ($needImpl)   { $insertLines += 'include "LibRuntimeProbe"' }
        $insertBlock = "`r`n" + ($insertLines -join "`r`n")
        $content = $content.Substring(0, $insertPos) + $insertBlock + $content.Substring($insertPos)
        $modified = $true
        Write-Host "  Injected includes: $($insertLines -join ', ')"
    } else {
        Write-Host "  WARN: no include lines found in MapScript.galaxy, skipping include injection"
    }
} else {
    Write-Host "  MapScript.galaxy already includes LibRuntimeProbe"
}

# 4b. 在 InitLibs() 函数体内最后一个 libXXX_InitLib() 调用之后追加 libRuntimeProbe_InitLib()
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
        } else {
            Write-Host "  WARN: no libXXX_InitLib() calls found in InitLibs() body"
        }
    } else {
        Write-Host "  WARN: InitLibs() function not found in MapScript.galaxy"
    }
} else {
    Write-Host "  MapScript.galaxy already calls libRuntimeProbe_InitLib"
}

# 4c. 在 gt_Initialization_Func 中 libAIROAdapter_gf_InitUnitReplacement() 之后
#     注入 libRuntimeProbe_gf_StartProbe() 调用。
#     StartProbe 注册周期性 tick 触发器并执行第一次状态写入。
#     必须在 gt_Initialization_Func 中调用（而非 InitLib），因为此时触发器系统已就绪。
if ($content -notmatch 'libRuntimeProbe_gf_StartProbe\s*\(\s*\)') {
    $airoInitPattern = '(?m)^(    libAIROAdapter_gf_InitUnitReplacement\s*\(\s*\)\s*;\s*\r?\n)'
    if ($content -match $airoInitPattern) {
        $initLine = $matches[0]
        $probeCall = "    // RuntimeProbe: start periodic probe`r`n    libRuntimeProbe_gf_StartProbe();`r`n"
        $content = $content -replace [regex]::Escape($initLine), ($initLine + $probeCall)
        $modified = $true
        Write-Host "  Injected libRuntimeProbe_gf_StartProbe() after libAIROAdapter_gf_InitUnitReplacement()"
    } else {
        Write-Host "  WARN: libAIROAdapter_gf_InitUnitReplacement() not found, cannot inject StartProbe"
    }
} else {
    Write-Host "  MapScript.galaxy already calls libRuntimeProbe_gf_StartProbe"
}

if ($modified) {
    [System.IO.File]::WriteAllText($mapScriptPath, $content, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  MapScript.galaxy updated"
}

# === Step 5: Patch BankList.xml（追加 RuntimeProbe Bank 声明）===
Write-Host "[Step 5] Patch BankList.xml..."
$bankListPath = Join-Path $MapLivePath "BankList.xml"
if (-not (Test-Path -LiteralPath $bankListPath)) {
    throw "BankList.xml not found: $bankListPath"
}

$bankContent = [System.IO.File]::ReadAllText($bankListPath)
if ($bankContent -notmatch 'Name="RuntimeProbe"') {
    $bankEntry = '    <Bank Name="RuntimeProbe" Player="1"/>'
    $bankContent = $bankContent.Replace('</BankList>', ($bankEntry + "`r`n</BankList>"))
    [System.IO.File]::WriteAllText($bankListPath, $bankContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  Added: <Bank Name='RuntimeProbe' Player='1'/>"
} else {
    Write-Host "  RuntimeProbe bank already declared"
}

Write-Host ""
Write-Host "[RuntimeProbe] Installation complete."
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
    Write-Host "  Map:      $MapLivePath"
    # 与 launch-airo-campaign.ps1 一致：用引号包裹地图路径作为 ArgumentList
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
    $banksPath = Join-Path $env:USERPROFILE "Documents\StarCraft II\Banks"
    $reportDir = Join-Path $PSScriptRoot "reports"

    if (-not (Test-Path -LiteralPath $runnerScript)) {
        throw "Runner script not found: $runnerScript"
    }

    Write-Host "  Runner:    $runnerScript"
    Write-Host "  Banks:     $banksPath"
    Write-Host "  Reports:   $reportDir"
    Write-Host "  Duration:  ${Duration}s"
    Write-Host ""

    & python $runnerScript --banks-path $banksPath --composition-id $CompositionId --output-dir $reportDir --duration $Duration
}

Write-Host ""
Write-Host "[RuntimeProbe] Done."
