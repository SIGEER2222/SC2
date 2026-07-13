<#
.SYNOPSIS
在 7vs1 合作指挥官地图上叠加 Neuro-sama 集成。

.DESCRIPTION
薄包装：统一转发到 launch-7vs1-coop-test.ps1 -EnableNeuro。
依赖闭包与注入清单见：
  Shared/Launcher/neuro-dependencies.json
  Shared/Galaxy/neuro-7vs1-galaxy-manifest.json

Neuro 连接模式：
- Mock 模式（默认）：ws://127.0.0.1:8000，launch 会在需要时自动拉起 mock_neuro_server.py
- Gary 真实模式（-UseGary）：自动启动 gary.exe，连接 ws://127.0.0.1:8000
- 自定义 URL（-NeuroUrl "ws://host:port"）

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-7vs1-neuro.ps1 -Commanders @("TerranRaynor")

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-7vs1-neuro.ps1 -Commanders @("TerranRaynor") -NoLaunch -SkipPythonRuntime

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-7vs1-neuro.ps1 -Commanders @("TerranRaynor") -UseGary
#>
[CmdletBinding()]
param(
    [string]$MapSource = "",
    [string]$LiveMapName = "7vs1CoopTest.SC2Map",
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
    [string]$BridgeModSource = "",
    [string]$NeuroUrl = "",
    [switch]$UseGary,
    [string]$GaryPath = "C:\Users\22448\AppData\Local\Gary\gary.exe",
    [switch]$EnableChatParser,
    [switch]$ApiListen,
    [int]$ApiPort = 5000
)

$ErrorActionPreference = 'Stop'

$workspaceRoot = Resolve-Path "E:\Code\MyMod\SC2\合作指挥官-起义狂潮"
$scriptsRoot = Join-Path $workspaceRoot "scripts"
$vs1Script = Join-Path $scriptsRoot "launch-7vs1-coop-test.ps1"

if (-not (Test-Path -LiteralPath $vs1Script)) {
    throw "7vs1 launch script not found: $vs1Script"
}

Write-Host "=== Neuro 7vs1 Integration Launcher (thin wrapper) ===" -ForegroundColor Cyan
Write-Host "Delegating to launch-7vs1-coop-test.ps1 -EnableNeuro"
Write-Host "Closure facts: Shared/Launcher/neuro-dependencies.json"
Write-Host "Galaxy manifest: Shared/Galaxy/neuro-7vs1-galaxy-manifest.json"

$forward = @{
    EnableNeuro       = $true
    LiveMapName       = $LiveMapName
    Commanders        = $Commanders
    Preset            = $Preset
    Sc2Root           = $Sc2Root
    PythonPath        = $PythonPath
    GaryPath          = $GaryPath
}

if (-not [string]::IsNullOrWhiteSpace($MapSource)) { $forward.MapSource = $MapSource }
if (-not [string]::IsNullOrWhiteSpace($SwitcherPath)) { $forward.SwitcherPath = $SwitcherPath }
if (-not [string]::IsNullOrWhiteSpace($NeuroApiRoot)) { $forward.NeuroApiRoot = $NeuroApiRoot }
if (-not [string]::IsNullOrWhiteSpace($NeuroModSource)) { $forward.NeuroModSource = $NeuroModSource }
if (-not [string]::IsNullOrWhiteSpace($BridgeModSource)) { $forward.BridgeModSource = $BridgeModSource }
if (-not [string]::IsNullOrWhiteSpace($NeuroUrl)) { $forward.NeuroUrl = $NeuroUrl }
if ($NoLaunch) { $forward.NoLaunch = $true }
if ($SkipPythonRuntime) { $forward.SkipPythonRuntime = $true }
if ($UseGary) { $forward.UseGary = $true }
if ($EnableChatParser) { $forward.EnableChatParser = $true }
if ($ApiListen) {
    $forward.ApiListen = $true
    $forward.ApiPort = $ApiPort
}

# StartPythonRuntime is the historical inverse of SkipPythonRuntime; keep both working.
if ($StartPythonRuntime -and $SkipPythonRuntime) {
    throw "Cannot combine -StartPythonRuntime with -SkipPythonRuntime"
}

& $vs1Script @forward
exit $LASTEXITCODE
