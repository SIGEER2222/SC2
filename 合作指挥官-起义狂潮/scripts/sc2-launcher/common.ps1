<#
.SYNOPSIS
  Shared utilities for SC2 commander launchers.
.DESCRIPTION
  Provides common functions used by both 7vs1 and Reborn launchers:
  - Path resolution (workspace root, SC2 root, live paths)
  - SC2 process management (stop running instances)
  - GameLogs cleanup
  - Configuration loading (JSON manifests from Shared/Launcher/)
#>

# Default SC2 installation root. Override via $Sc2Root parameter in caller.
$script:DefaultSc2Root = "E:\SC2\SC2new\StarCraft II"

function Get-LauncherWorkspaceRoot {
    # Caller must set $LauncherScriptsRoot before dot-sourcing this module.
    if (-not $script:LauncherScriptsRoot) {
        throw "LauncherScriptsRoot not set. Caller must set `$script:LauncherScriptsRoot before importing common.ps1"
    }
    # scripts/sc2-launcher/common.ps1 -> scripts/sc2-launcher -> scripts -> workspace root
    return (Split-Path -Parent (Split-Path -Parent $script:LauncherScriptsRoot))
}

function Get-LauncherSc2Root {
    param([string]$Override = "")
    if (-not [string]::IsNullOrWhiteSpace($Override)) { return $Override }
    return $script:DefaultSc2Root
}

function Get-LauncherSharedRoot {
    return (Join-Path (Get-LauncherWorkspaceRoot) "Shared\Launcher")
}

# === Configuration loading ===
function Import-LauncherConfig {
    param([string]$Name)
    $path = Join-Path (Get-LauncherSharedRoot) "$Name.json"
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Launcher config not found: $path"
    }
    return (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-CommanderUnitsModSuffix {
    param([string]$Commander)
    $config = Import-LauncherConfig -Name "commander-units-mapping"
    if ($config.mappings.PSObject.Properties.Name -contains $Commander) {
        return $config.mappings.$Commander
    }
    return $null
}

function Get-CommanderUnitsModName {
    param([string]$Commander)
    $suffix = Get-CommanderUnitsModSuffix -Commander $Commander
    if ($suffix) { return "CommanderUnits_$suffix" }
    return $null
}

# === SC2 process management ===
function Stop-RunningSc2 {
    Get-Process -Name "SC2_x64","SC2Switcher_x64" -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 2
}

# === GameLogs cleanup ===
function Clear-GameLogs {
    $logsRoot = "C:\Users\22448\Documents\StarCraft II\GameLogs"
    $logFiles = Get-ChildItem $logsRoot -File -ErrorAction SilentlyContinue
    foreach ($lf in $logFiles) {
        [System.IO.File]::Delete($lf.FullName)
    }
}

# === Wait for game ready ===
function Wait-GameReady {
    param([string]$ScriptsRoot)
    $waitScript = Join-Path $ScriptsRoot "wait-for-game-ready.ps1"
    Write-Host "Waiting for game ready..."
    & powershell -NoProfile -ExecutionPolicy Bypass -File $waitScript
    return $LASTEXITCODE
}
