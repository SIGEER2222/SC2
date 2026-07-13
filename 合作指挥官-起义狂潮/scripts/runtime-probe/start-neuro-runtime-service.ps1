<#
.SYNOPSIS
Start or inspect the shared Neuro runtime service.

.DESCRIPTION
Keeps one shared runtime service for SC2 map/mod development:
  - Gary on ws://127.0.0.1:8000 when -UseGary is set
  - SC2-Neuro-API-Integration/run.py
  - RuntimeProbe web API
  - RuntimeProbe -> Neuro bridge

The script reuses existing processes and does not start a second Gary when one is already active.
#>
[CmdletBinding(DefaultParameterSetName = "Start")]
param(
    [Parameter(ParameterSetName = "Start")]
    [switch]$UseGary,
    [Parameter(ParameterSetName = "Start")]
    [switch]$NoGary,
    [Parameter(ParameterSetName = "Start")]
    [switch]$NoWeb,
    [Parameter(ParameterSetName = "Start")]
    [switch]$NoBridge,
    [Parameter(ParameterSetName = "Start")]
    [switch]$NoNeuroApi,
    [Parameter(ParameterSetName = "Start")]
    [switch]$EnableChatParser,
    [Parameter(ParameterSetName = "Start")]
    [string]$NeuroUrl = "",
    [Parameter(ParameterSetName = "Start")]
    [string]$GaryPath = "C:\Users\22448\AppData\Local\Gary\gary.exe",
    [Parameter(ParameterSetName = "Start")]
    [string]$PythonPath = "C:\Users\22448\AppData\Local\Programs\Python\Python313\python.exe",
    [Parameter(ParameterSetName = "Start")]
    [string]$NeuroApiRoot = "",
    [Parameter(ParameterSetName = "Start")]
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [Parameter(ParameterSetName = "Start")]
    [string]$BanksPath = "C:\Users\22448\Documents\StarCraft II\Banks",
    [Parameter(ParameterSetName = "Start")]
    [int]$GaryPort = 8000,
    [Parameter(ParameterSetName = "Start")]
    [int]$WebPort = 18080,
    [Parameter(ParameterSetName = "Start")]
    [int]$WaitSeconds = 8,

    [Parameter(ParameterSetName = "Status")]
    [switch]$Status,
    [Parameter(ParameterSetName = "Stop")]
    [switch]$Stop,
    [Parameter(ParameterSetName = "Restart")]
    [switch]$Restart
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$repoRoot = Split-Path -Parent $workspaceRoot
$outRoot = Join-Path $repoRoot "out\neuro-runtime"
$statePath = Join-Path $repoRoot "out\neuro-runtime-service.json"
$depsPath = Join-Path $workspaceRoot "Shared\Launcher\neuro-dependencies.json"

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Test-TcpListening {
    param([string]$HostName, [int]$Port)
    try {
        $client = [System.Net.Sockets.TcpClient]::new()
        $iar = $client.BeginConnect($HostName, $Port, $null, $null)
        $connected = $iar.AsyncWaitHandle.WaitOne(250)
        if ($connected -and $client.Connected) {
            $client.EndConnect($iar)
            $client.Close()
            return $true
        }
        $client.Close()
    } catch {
        return $false
    }
    return $false
}

function Get-ProcessByCommandLine {
    param([string]$Pattern)
    Get-CimInstance Win32_Process |
        Where-Object { $_.CommandLine -and $_.CommandLine -like "*$Pattern*" } |
        Select-Object -First 1
}

function Get-ProcessByPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object {
            try { $_.Path -and ([string]::Equals($_.Path, $Path, [System.StringComparison]::OrdinalIgnoreCase)) }
            catch { $false }
        } |
        Select-Object -First 1
}

function Invoke-ServiceJson {
    param([string]$Url)
    try {
        return Invoke-RestMethod -Uri $Url -TimeoutSec 2
    } catch {
        return $null
    }
}

function Resolve-NeuroDefaults {
    $defaults = [ordered]@{
        neuroApiRoot = $NeuroApiRoot
        defaultUrl = "ws://127.0.0.1:8000"
        garyUrl = "ws://127.0.0.1:8000"
        banksPath = $BanksPath
        mockServer = "mock_neuro_server.py"
    }
    if (Test-Path -LiteralPath $depsPath) {
        $deps = Get-Content -LiteralPath $depsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ([string]::IsNullOrWhiteSpace($defaults.neuroApiRoot) -and $deps.pythonRuntime.rootWorkspace) {
            $defaults.neuroApiRoot = Join-Path $repoRoot ([string]$deps.pythonRuntime.rootWorkspace -replace '/', '\')
        }
        if ($deps.pythonRuntime.defaultUrl) { $defaults.defaultUrl = [string]$deps.pythonRuntime.defaultUrl }
        if ($deps.pythonRuntime.garyUrl) { $defaults.garyUrl = [string]$deps.pythonRuntime.garyUrl }
        if ($deps.pythonRuntime.banksPath) { $defaults.banksPath = [string]$deps.pythonRuntime.banksPath }
        if ($deps.pythonRuntime.mockServer) { $defaults.mockServer = [string]$deps.pythonRuntime.mockServer }
    }
    if ([string]::IsNullOrWhiteSpace($defaults.neuroApiRoot)) {
        $defaults.neuroApiRoot = Join-Path $repoRoot "tools\SC2-Neuro-API-Integration"
    }
    return $defaults
}

function Read-State {
    if (Test-Path -LiteralPath $statePath) {
        try {
            return Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            return $null
        }
    }
    return $null
}

function Write-State {
    param([hashtable]$State)
    Ensure-Directory -Path (Split-Path -Parent $statePath)
    $json = $State | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($statePath, $json, [System.Text.UTF8Encoding]::new($false))
}

function Stop-RecordedProcesses {
    $state = Read-State
    if (-not $state) { return }
    foreach ($name in @("bridge", "web", "neuroApi")) {
        $pidValue = $state.processes.$name.pid
        if ($pidValue) {
            Stop-Process -Id ([int]$pidValue) -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-CurrentStatus {
    $serviceState = Read-State
    $webHealth = Invoke-ServiceJson -Url "http://127.0.0.1:$WebPort/api/health"
    $webVerdict = Invoke-ServiceJson -Url "http://127.0.0.1:$WebPort/api/verdict"
    return [ordered]@{
        timestamp = (Get-Date).ToString("o")
        statePath = $statePath
        garyListening = (Test-TcpListening -HostName "127.0.0.1" -Port $GaryPort)
        webHealth = $webHealth
        verdict = $webVerdict
        recordedState = $serviceState
    }
}

if ($Stop -or $Restart) {
    Stop-RecordedProcesses
    if ($Stop) {
        Get-CurrentStatus | ConvertTo-Json -Depth 8
        exit 0
    }
}

if ($Status) {
    Get-CurrentStatus | ConvertTo-Json -Depth 8
    exit 0
}

$defaults = Resolve-NeuroDefaults
if ([string]::IsNullOrWhiteSpace($NeuroUrl)) {
    $NeuroUrl = if ($UseGary) { $defaults.garyUrl } else { $defaults.defaultUrl }
}
$BanksPath = $defaults.banksPath
$NeuroApiRoot = $defaults.neuroApiRoot
$quotedBanksPath = "`"$BanksPath`""

Ensure-Directory -Path $outRoot
Ensure-Directory -Path (Join-Path $outRoot "logs")

$processes = [ordered]@{}

if ($UseGary -and -not $NoGary) {
    if (Test-TcpListening -HostName "127.0.0.1" -Port $GaryPort) {
        $processes.gary = @{ status = "reused-listener"; pid = $null; url = $NeuroUrl }
    } else {
        $garyProcess = Get-ProcessByPath -Path $GaryPath
        if ($garyProcess) {
            for ($i = 0; $i -lt $WaitSeconds; $i++) {
                if (Test-TcpListening -HostName "127.0.0.1" -Port $GaryPort) { break }
                Start-Sleep -Seconds 1
            }
            $processes.gary = @{ status = "reused-process"; pid = $garyProcess.Id; url = $NeuroUrl; listening = (Test-TcpListening -HostName "127.0.0.1" -Port $GaryPort) }
        } elseif (Test-Path -LiteralPath $GaryPath) {
            $garyProcess = Start-Process -FilePath $GaryPath -PassThru -WindowStyle Hidden
            for ($i = 0; $i -lt $WaitSeconds; $i++) {
                if (Test-TcpListening -HostName "127.0.0.1" -Port $GaryPort) { break }
                Start-Sleep -Seconds 1
            }
            $processes.gary = @{ status = "started"; pid = $garyProcess.Id; url = $NeuroUrl; listening = (Test-TcpListening -HostName "127.0.0.1" -Port $GaryPort) }
        } else {
            throw "Gary requested but not found at $GaryPath"
        }
    }
}

if (-not $UseGary -and -not $NoGary) {
    $mockScript = Join-Path $NeuroApiRoot $defaults.mockServer
    if ((-not (Test-TcpListening -HostName "127.0.0.1" -Port $GaryPort)) -and (Test-Path -LiteralPath $mockScript)) {
        $mockLog = Join-Path $outRoot "logs\mock-neuro.log"
        $mockErr = Join-Path $outRoot "logs\mock-neuro.err.log"
        $mockProcess = Start-Process -FilePath $PythonPath -ArgumentList @($mockScript) -WorkingDirectory $NeuroApiRoot -RedirectStandardOutput $mockLog -RedirectStandardError $mockErr -PassThru -WindowStyle Hidden
        Start-Sleep -Seconds 2
        $processes.mock = @{ status = "started"; pid = $mockProcess.Id; url = $NeuroUrl }
    } elseif (Test-TcpListening -HostName "127.0.0.1" -Port $GaryPort) {
        $processes.mock = @{ status = "reused-listener"; pid = $null; url = $NeuroUrl }
    }
}

if (-not $NoNeuroApi) {
    $runScript = Join-Path $NeuroApiRoot "run.py"
    if (Test-Path -LiteralPath $runScript) {
        $existing = Get-ProcessByCommandLine -Pattern "SC2-Neuro-API-Integration*run.py"
        $configureJson = Join-Path $NeuroApiRoot "configure.json"
        $config = @{
            game_path = $Sc2Root
            banks_path = $BanksPath
            neuro_url = $NeuroUrl
            verbosity = 1
        } | ConvertTo-Json -Depth 3
        [System.IO.File]::WriteAllText($configureJson, $config, [System.Text.UTF8Encoding]::new($false))

        if ($existing) {
            $processes.neuroApi = @{ status = "reused"; pid = [int]$existing.ProcessId; script = $runScript }
        } else {
            $apiProcess = Start-Process -FilePath $PythonPath -ArgumentList @($runScript) -WorkingDirectory $NeuroApiRoot -PassThru -WindowStyle Hidden
            $processes.neuroApi = @{ status = "started"; pid = $apiProcess.Id; script = $runScript }
            Start-Sleep -Seconds 2
        }
    } else {
        $processes.neuroApi = @{ status = "missing"; pid = $null; script = $runScript }
    }
}

if (-not $NoWeb) {
    $health = Invoke-ServiceJson -Url "http://127.0.0.1:$WebPort/api/health"
    if ($health) {
        $processes.web = @{ status = "reused"; pid = $null; url = "http://127.0.0.1:$WebPort" }
    } else {
        if (Test-TcpListening -HostName "127.0.0.1" -Port $WebPort) {
            $processes.web = @{ status = "port-busy"; pid = $null; url = "http://127.0.0.1:$WebPort" }
        } else {
            $webScript = Join-Path $PSScriptRoot "web_server.py"
            $webLog = Join-Path $outRoot "logs\web-server.log"
            $webErr = Join-Path $outRoot "logs\web-server.err.log"
            $webProcess = Start-Process -FilePath $PythonPath -ArgumentList @($webScript, "--banks-path", $quotedBanksPath, "--port", "$WebPort") -WorkingDirectory $PSScriptRoot -RedirectStandardOutput $webLog -RedirectStandardError $webErr -PassThru -WindowStyle Hidden
            Start-Sleep -Seconds 2
            $processes.web = @{ status = "started"; pid = $webProcess.Id; url = "http://127.0.0.1:$WebPort" }
        }
    }
}

if (-not $NoBridge) {
    $bridgeScript = Join-Path $PSScriptRoot "neuro_bridge.py"
    $existingBridge = Get-ProcessByCommandLine -Pattern "runtime-probe*neuro_bridge.py"
    if ($existingBridge) {
        $processes.bridge = @{ status = "reused"; pid = [int]$existingBridge.ProcessId; neuroUrl = $NeuroUrl }
    } elseif (Test-Path -LiteralPath $bridgeScript) {
        $bridgeArgs = @($bridgeScript, "--banks-path", $quotedBanksPath, "--neuro-url", $NeuroUrl, "--context-interval", "10")
        if ($EnableChatParser) { $bridgeArgs += "--enable-chat-parser" }
        $bridgeLog = Join-Path $outRoot "logs\neuro-bridge.log"
        $bridgeErr = Join-Path $outRoot "logs\neuro-bridge.err.log"
        $bridgeProcess = Start-Process -FilePath $PythonPath -ArgumentList $bridgeArgs -WorkingDirectory $PSScriptRoot -RedirectStandardOutput $bridgeLog -RedirectStandardError $bridgeErr -PassThru -WindowStyle Hidden
        $processes.bridge = @{ status = "started"; pid = $bridgeProcess.Id; neuroUrl = $NeuroUrl }
    } else {
        $processes.bridge = @{ status = "missing"; pid = $null; script = $bridgeScript }
    }
}

$state = @{
    timestamp = (Get-Date).ToString("o")
    neuroUrl = $NeuroUrl
    banksPath = $BanksPath
    webUrl = "http://127.0.0.1:$WebPort"
    useGary = [bool]$UseGary
    processes = $processes
}
Write-State -State $state

$state | ConvertTo-Json -Depth 8
