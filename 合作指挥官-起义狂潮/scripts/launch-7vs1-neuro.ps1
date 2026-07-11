<#
.SYNOPSIS
在 7vs1 合作指挥官地图上叠加 Neuro-sama 集成。

.DESCRIPTION
此脚本是 launch-7vs1-coop-test.ps1 的薄包装层：
1. 调用原脚本（-NoLaunch）完成 7vs1 依赖重写 + 地图安装
2. 对 mapLive 追加 NeuroIntegration + NeuroBridge7vs1 依赖
3. 注入 BankList.xml（NeuroIntegration Bank）
4. 注入 MapScript.galaxy（include + InitLib）
5. 复制 galaxy 库文件到地图 Base.SC2Data
6. 后台启动 Python 运行时（headless_runner.py）
7. 启动 SC2

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-7vs1-neuro.ps1 -Commanders @("TerranRaynor")

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-7vs1-neuro.ps1 -Commanders @("TerranRaynor") -MapSource ".\Maps\traynor01_7vs1.SC2Map" -LiveMapName "traynor01_7vs1.SC2Map"
#>
[CmdletBinding()]
param(
    [string]$MapSource = "",
    [string]$LiveMapName = "traynor01_7vs1.SC2Map",
    [string[]]$Commanders = @("TerranRaynor"),
    [string]$Preset = "Default",
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$SwitcherPath = "",
    [switch]$NoLaunch,
    [switch]$StartPythonRuntime,
    [switch]$SkipPythonRuntime,
    [string]$PythonPath = "C:\Users\22448\AppData\Local\Programs\Python\Python313\python.exe",
    [string]$NeuroApiRoot = "",
    [string]$NeuroModSource = "",
    [string]$BridgeModSource = ""
)

$ErrorActionPreference = 'Stop'

# === 路径解析 ===
$workspaceRoot = Resolve-Path "E:\Code\MyMod\SC2\合作指挥官-起义狂潮"
$scriptsRoot = Join-Path $workspaceRoot "scripts"

if ([string]::IsNullOrWhiteSpace($NeuroModSource)) {
    $NeuroModSource = "E:\Code\MyMod\SC2\tools\SC2-Neuro-WoL-Integration\Mods\NeuroIntegration.SC2Mod"
}
if ([string]::IsNullOrWhiteSpace($BridgeModSource)) {
    $BridgeModSource = Join-Path $workspaceRoot "Mods\Neuro\NeuroBridge7vs1.SC2Mod"
}
if ([string]::IsNullOrWhiteSpace($NeuroApiRoot)) {
    $NeuroApiRoot = "E:\Code\MyMod\SC2\tools\SC2-Neuro-API-Integration"
}
if ([string]::IsNullOrWhiteSpace($SwitcherPath)) {
    $SwitcherPath = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
}

$mapLive = Join-Path (Join-Path $Sc2Root "Maps\7vs1") $LiveMapName
$mapLiveBaseData = Join-Path $mapLive "Base.SC2Data"

Write-Host "=== Neuro 7vs1 Integration Launcher ===" -ForegroundColor Cyan
Write-Host "Workspace: $workspaceRoot"
Write-Host "MapLive:   $mapLive"
Write-Host "NeuroMod:  $NeuroModSource"
Write-Host "BridgeMod: $BridgeModSource"

# === 校验源文件存在 ===
if (-not (Test-Path -LiteralPath $NeuroModSource)) {
    throw "NeuroIntegration mod not found: $NeuroModSource"
}
if (-not (Test-Path -LiteralPath $BridgeModSource)) {
    throw "NeuroBridge7vs1 mod not found: $BridgeModSource"
}
if (-not (Test-Path -LiteralPath $NeuroApiRoot)) {
    throw "Neuro API root not found: $NeuroApiRoot"
}

# === Step 1: 调用 7vs1 脚本安装基础环境（不启动游戏）===
Write-Host "`n--- Step 1: Install 7vs1 base (via launch-7vs1-coop-test.ps1 -NoLaunch) ---" -ForegroundColor Yellow

$vs1Script = Join-Path $scriptsRoot "launch-7vs1-coop-test.ps1"
if (-not (Test-Path -LiteralPath $vs1Script)) {
    throw "7vs1 launch script not found: $vs1Script"
}

Write-Host "Executing: pwsh -File $vs1Script -NoLaunch -Sc2Root '$Sc2Root'"
& pwsh -NoProfile -ExecutionPolicy Bypass -File $vs1Script `
    -NoLaunch `
    -Sc2Root $Sc2Root `
    -MapSource $MapSource `
    -LiveMapName $LiveMapName `
    -Commanders $Commanders `
    -Preset $Preset
if ($LASTEXITCODE -ne 0) {
    throw "7vs1 base install failed with exit code $LASTEXITCODE"
}
Write-Host "7vs1 base install completed." -ForegroundColor Green

# === Step 2: 追加 Neuro 依赖到地图 DocumentInfo ===
Write-Host "`n--- Step 2: Append Neuro mod dependencies ---" -ForegroundColor Yellow

$docInfoPath = Join-Path $mapLive "DocumentInfo"
$docHeaderPath = Join-Path $mapLive "DocumentHeader"

# 读取现有依赖
$docInfoContent = [System.IO.File]::ReadAllText($docInfoPath)
$xml = [xml]$docInfoContent
$depsNode = $xml.DocInfo.Dependencies
if ($null -eq $depsNode) {
    $depsNode = $xml.CreateElement("Dependencies")
    $xml.DocInfo.AppendChild($depsNode) | Out-Null
}

# NeuroIntegration mod 目标路径（相对于 SC2 根目录）
$neuroLiveRel = "file:Mods/NeuroIntegration.SC2Mod"
$bridgeLiveRel = "file:Mods/Neuro/NeuroBridge7vs1.SC2Mod"

# 检查是否已存在
$existingValues = @()
foreach ($v in $depsNode.Value) { $existingValues += $v.InnerText }
if ($existingValues -notcontains $neuroLiveRel) {
    $newVal = $xml.CreateElement("Value")
    $newVal.InnerText = $neuroLiveRel
    $depsNode.AppendChild($newVal) | Out-Null
    Write-Host "  Added: $neuroLiveRel"
}
if ($existingValues -notcontains $bridgeLiveRel) {
    $newVal = $xml.CreateElement("Value")
    $newVal.InnerText = $bridgeLiveRel
    $depsNode.AppendChild($newVal) | Out-Null
    Write-Host "  Added: $bridgeLiveRel"
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($docInfoPath, $xml.OuterXml, $utf8NoBom)
Write-Host "DocumentInfo updated." -ForegroundColor Green

# === Step 3: 复制 Neuro mod 到 SC2 运行时目录 ===
Write-Host "`n--- Step 3: Copy Neuro mods to SC2 runtime ---" -ForegroundColor Yellow

$neuroLiveDir = Join-Path $Sc2Root "Mods\NeuroIntegration.SC2Mod"
$bridgeLiveDir = Join-Path $Sc2Root "Mods\Neuro\NeuroBridge7vs1.SC2Mod"

# 复制 NeuroIntegration
if (Test-Path $neuroLiveDir) { Remove-Item $neuroLiveDir -Recurse -Force }
Copy-Item $NeuroModSource $neuroLiveDir -Recurse -Force
Write-Host "  Copied NeuroIntegration -> $neuroLiveDir"

# 复制 NeuroBridge7vs1
$bridgeLiveParent = Split-Path $bridgeLiveDir -Parent
if (-not (Test-Path $bridgeLiveParent)) { New-Item -ItemType Directory -Path $bridgeLiveParent -Force | Out-Null }
if (Test-Path $bridgeLiveDir) { Remove-Item $bridgeLiveDir -Recurse -Force }
Copy-Item $BridgeModSource $bridgeLiveDir -Recurse -Force
Write-Host "  Copied NeuroBridge7vs1 -> $bridgeLiveDir"

# === Step 4: 注入 galaxy 库文件到地图 Base.SC2Data ===
Write-Host "`n--- Step 4: Inject galaxy libraries into map ---" -ForegroundColor Yellow

if (-not (Test-Path $mapLiveBaseData)) {
    New-Item -ItemType Directory -Path $mapLiveBaseData -Force | Out-Null
}

# NeuroIntegration 的 galaxy 文件
$neuroGalaxyDir = Join-Path $neuroLiveDir "Base.SC2Data"
$neuroGalaxyFiles = Get-ChildItem $neuroGalaxyDir -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
foreach ($gf in $neuroGalaxyFiles) {
    $dst = Join-Path $mapLiveBaseData $gf.Name
    [System.IO.File]::Copy($gf.FullName, $dst, $true)
    Write-Host "  Injected: $($gf.Name)"
}

# NeuroBridge7vs1 的 galaxy 文件
$bridgeGalaxyDir = Join-Path $bridgeLiveDir "Base.SC2Data"
$bridgeGalaxyFiles = Get-ChildItem $bridgeGalaxyDir -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
foreach ($gf in $bridgeGalaxyFiles) {
    $dst = Join-Path $mapLiveBaseData $gf.Name
    [System.IO.File]::Copy($gf.FullName, $dst, $true)
    Write-Host "  Injected: $($gf.Name)"
}

# === Step 5: 注入 BankList.xml ===
Write-Host "`n--- Step 5: Patch BankList.xml ---" -ForegroundColor Yellow

$bankListPath = Join-Path $mapLive "BankList.xml"
if (Test-Path -LiteralPath $bankListPath) {
    $bankContent = [System.IO.File]::ReadAllText($bankListPath)
    if ($bankContent -notmatch 'Name="NeuroIntegration"') {
        $bankEntry = '    <Bank Name="NeuroIntegration" Player="1"/>'
        $bankContent = $bankContent.Replace('</BankList>', ($bankEntry + "`n</BankList>"))
        [System.IO.File]::WriteAllText($bankListPath, $bankContent, $utf8NoBom)
        Write-Host "  Added NeuroIntegration bank declaration"
    } else {
        Write-Host "  Already has NeuroIntegration bank"
    }
} else {
    Write-Host "  WARN: BankList.xml not found, creating minimal one"
    $bankContent = "<?xml version=`"1.0`" encoding=`"utf-8`"?>`n<BankList>`n    <Bank Name=`"NeuroIntegration`" Player=`"1`"/>`n</BankList>`n"
    [System.IO.File]::WriteAllText($bankListPath, $bankContent, $utf8NoBom)
}

# === Step 6: 注入 MapScript.galaxy ===
Write-Host "`n--- Step 6: Patch MapScript.galaxy ---" -ForegroundColor Yellow

$mapScriptPath = Join-Path $mapLive "MapScript.galaxy"
if (Test-Path -LiteralPath $mapScriptPath) {
    $content = [System.IO.File]::ReadAllText($mapScriptPath)
    $modified = $false

    # 6a. 注入 include（在最后一个 include 之后）
    if ($content -notmatch 'include "LibEFA54406"') {
        $neuroIncludes = @(
            'include "LibEFA54406"',
            'include "LibNeuroBridge7vs1"'
        )
        $includeBlock = $neuroIncludes -join "`n"
        $lastIncludePattern = '(?m)^(include "[^"]+"(?:\r?\n)*)'
        $lastMatch = [regex]::Matches($content, $lastIncludePattern)
        if ($lastMatch.Count -gt 0) {
            $insertPos = $lastMatch[$lastMatch.Count - 1].Index + $lastMatch[$lastMatch.Count - 1].Length
            $content = $content.Substring(0, $insertPos) + $includeBlock + "`n" + $content.Substring($insertPos)
        }
        $modified = $true
        Write-Host "  Added Neuro includes"
    }

    # 6b. 注入 InitLib 调用（在 InitLibs() 闭合大括号之前）
    if ($content -notmatch 'libNeuroBridge7vs1_InitLib') {
        $initCalls = @(
            '    libEFA54406_InitLib();',
            '    libNeuroBridge7vs1_InitLib();'
        )
        $initBlock = ($initCalls -join "`n") + "`n"
        $initLibsPattern = '(void\s+InitLibs\s*\(\s*\)\s*\{)([^}]+)(\})'
        if ($content -match $initLibsPattern) {
            $beforeBrace = $matches[2]
            $content = $content -replace [regex]::Escape($beforeBrace), ($beforeBrace + $initBlock)
            $modified = $true
            Write-Host "  Added Neuro InitLib calls"
        } else {
            Write-Host "  WARN: could not find InitLibs() function"
        }
    }

    if ($modified) {
        [System.IO.File]::WriteAllText($mapScriptPath, $content, $utf8NoBom)
        Write-Host "MapScript.galaxy patched." -ForegroundColor Green
    } else {
        Write-Host "  SKIP: MapScript.galaxy already patched"
    }
} else {
    Write-Host "  WARN: MapScript.galaxy not found at $mapScriptPath"
}

# === Step 7: 启动 Python 运行时（可选）===
$pythonProcessId = $null
if (-not $SkipPythonRuntime -and -not $NoLaunch) {
    Write-Host "`n--- Step 7: Start Python runtime ---" -ForegroundColor Yellow

    $headlessRunner = Join-Path $NeuroApiRoot "headless_runner.py"
    $configureJson = Join-Path $NeuroApiRoot "configure.json"

    if (Test-Path -LiteralPath $headlessRunner) {
        if (-not (Test-Path -LiteralPath $configureJson)) {
            # 创建默认配置
            $config = @{
                game_path = $Sc2Root
                banks_path = "C:\Users\22448\Documents\StarCraft II\Banks"
                neuro_url = "ws://127.0.0.1:8000"
                verbosity = 1
            }
            $configJson = $config | ConvertTo-Json -Depth 3
            [System.IO.File]::WriteAllText($configureJson, $configJson, $utf8NoBom)
            Write-Host "  Created configure.json"
        }

        Write-Host "  Starting headless_runner.py..."
        $pyProc = Start-Process -FilePath $PythonPath `
            -ArgumentList @($headlessRunner) `
            -WorkingDirectory $NeuroApiRoot `
            -WindowStyle Normal -PassThru
        $pythonProcessId = $pyProc.Id
        Write-Host "  Python runtime PID: $pythonProcessId" -ForegroundColor Green
    } else {
        Write-Host "  WARN: headless_runner.py not found at $headlessRunner"
    }
} else {
    Write-Host "`n--- Step 7: Skipped Python runtime (SkipPythonRuntime or NoLaunch) ---"
}

# === Step 8: 启动 SC2 ===
if (-not $NoLaunch) {
    Write-Host "`n--- Step 8: Launch SC2 ---" -ForegroundColor Yellow
    Write-Host "  Map: $mapLive"
    Write-Host "  Switcher: $SwitcherPath"
    & $SwitcherPath $mapLive
} else {
    Write-Host "`n--- Step 8: Skipped SC2 launch (NoLaunch) ---"
}

Write-Host "`n=== Neuro 7vs1 Integration Complete ===" -ForegroundColor Cyan
if ($pythonProcessId) {
    Write-Host "Python runtime PID: $pythonProcessId (close manually when done)"
}
