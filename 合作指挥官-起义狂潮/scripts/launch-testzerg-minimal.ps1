<#
.SYNOPSIS
TestZerg 极简启动脚本 - 只保留必要的逻辑，避免其他指挥官配置干扰。

.DESCRIPTION
专门用于测试 TestZerg 指挥官的轻量级启动脚本。
只做最基本的：安装 mod、设置 bank、启动游戏。
不加载复杂的 CommanderPower 预设，不触发其他指挥官逻辑。

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-testzerg-minimal.ps1
#>
[CmdletBinding()]
param(
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$MapSource = "",
    [string]$LiveMapName = "7vs1CoopTest.SC2Map",
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"

function Get-WorkspaceRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Resolve-DefaultMapSource {
    $workspaceRoot = Get-WorkspaceRoot
    $localMap = Join-Path $workspaceRoot "Maps\ttosh02_7vs1.SC2Map"
    if (Test-Path -LiteralPath $localMap) {
        return $localMap
    }
    throw "Default map not found. Specify -MapSource."
}

function Stop-RunningSc2 {
    $processNames = @("SC2_x64", "SC2Switcher_x64", "BlizzardError")
    foreach ($processName in $processNames) {
        $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($running) {
            foreach ($proc in $running) {
                try {
                    Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                }
                catch {
                    Write-Warning "Could not stop $processName (PID $($proc.Id)): $($_.Exception.Message)"
                }
            }
        }
    }
    Start-Sleep -Seconds 2
}

function Clear-Sc2GameLogs {
    $logsRoot = "C:\Users\22448\Documents\StarCraft II\GameLogs"
    if (-not (Test-Path -LiteralPath $logsRoot)) {
        return
    }
    Get-ChildItem -LiteralPath $logsRoot -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Could not remove SC2 log entry '$($_.FullName)': $($_.Exception.Message)"
        }
    }
}

function Copy-DirectoryClean {
    param(
        [string]$Source,
        [string]$Destination
    )
    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Source directory not found: $Source"
    }
    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force -ErrorAction Stop
    }
    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

function Set-BankCommander {
    param([string]$Commander)
    $bankPath = "C:\Users\22448\Documents\StarCraft II\Banks\CampaignXCore.SC2Bank"
    if (-not (Test-Path -LiteralPath $bankPath)) {
        throw "Bank file not found: $bankPath"
    }
    $content = Get-Content -LiteralPath $bankPath -Raw -Encoding UTF8

    $content = $content -replace '<Key name="Commander">\s*<Value string="[^"]*" />', "<Key name=`"Commander`">`n      <Value string=`"$Commander`" />"
    $content = $content -replace '<Key name="CommanderP1">\s*<Value string="[^"]*" />', "<Key name=`"CommanderP1`">`n      <Value string=`"$Commander`" />"
    $content = $content -replace '<Key name="PrimaryCommander">\s*<Value string="[^"]*" />', "<Key name=`"PrimaryCommander`">`n      <Value string=`"$Commander`" />"

    Set-Content -LiteralPath $bankPath -Value $content -Encoding UTF8 -NoNewline
    Write-Host "Bank commander set to: $Commander"
}

$workspaceRoot = Get-WorkspaceRoot
$switcherPath = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
$extensionSource = Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod"
$commanderCatalogSource = Join-Path $workspaceRoot "Mods\7vs1\CommanderCatalog.SC2Mod"

if (-not (Test-Path -LiteralPath $switcherPath)) {
    throw "Switcher not found: $switcherPath"
}
if (-not (Test-Path -LiteralPath $extensionSource)) {
    throw "Extension mod not found: $extensionSource"
}
if (-not (Test-Path -LiteralPath $commanderCatalogSource)) {
    throw "CommanderCatalog mod not found: $commanderCatalogSource"
}

if ([string]::IsNullOrWhiteSpace($MapSource)) {
    $mapSource = Resolve-DefaultMapSource
}
else {
    $mapSource = Join-Path $workspaceRoot $MapSource
}

$mapLive = Join-Path (Join-Path $Sc2Root "Maps\7vs1") $LiveMapName
$extensionLive = Join-Path $Sc2Root "Mods\7vs1\CoopZeroPop.SC2Mod"
$commanderCatalogLive = Join-Path $Sc2Root "Mods\7vs1\CommanderCatalog.SC2Mod"

Write-Host "=== TestZerg Minimal Launcher ===" -ForegroundColor Cyan
Write-Host "Map source: $mapSource"
Write-Host "Extension source: $extensionSource"

if (-not $NoLaunch) {
    Stop-RunningSc2
    Clear-Sc2GameLogs
}

Write-Host "Installing map..."
Copy-DirectoryClean -Source $mapSource -Destination $mapLive

Write-Host "Installing extension mod..."
Copy-DirectoryClean -Source $extensionSource -Destination $extensionLive

Write-Host "Installing CommanderCatalog mod..."
Copy-DirectoryClean -Source $commanderCatalogSource -Destination $commanderCatalogLive

Write-Host "Setting TestZerg in bank..."
Set-BankCommander -Commander "TestZerg"

Write-Host "Done. Launch command:"
Write-Host "  & $switcherPath $mapLive" -ForegroundColor Green

if (-not $NoLaunch) {
    Write-Host "Launching game..."
    & $switcherPath $mapLive
}
