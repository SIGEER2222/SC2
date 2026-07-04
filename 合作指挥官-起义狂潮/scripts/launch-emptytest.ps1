param(
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$RebornModPath = "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\crys_the_swarm_reborn.SC2Mod",
    [string]$StarCoopPath = ""
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$mapSource = Join-Path $workspaceRoot "Mods\emptytest.SC2Map"
if ([string]::IsNullOrEmpty($StarCoopPath)) {
    $StarCoopPath = [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot "游戏数据\官方SC2原始文本镜像\mods\starcoop"))
    if (-not (Test-Path -LiteralPath $StarCoopPath)) {
        $StarCoopPath = ""
    }
}

$mapLive = Join-Path (Join-Path $Sc2Root "Maps\7vs1") "emptytest.SC2Map"
$rebornLive = Join-Path (Join-Path $Sc2Root "Mods") "crys_the_swarm_reborn.SC2Mod"
$starCoopLive = Join-Path (Join-Path $Sc2Root "Mods\StarCoop") "StarCoop.SC2Mod"
$switcherPath = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
$logsRoot = "C:\Users\22448\Documents\StarCraft II\GameLogs"

function Stop-RunningSc2 {
    $processNames = @("SC2_x64", "SC2Switcher_x64", "BlizzardError")
    foreach ($processName in $processNames) {
        $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if (-not $running) { continue }
        foreach ($proc in $running) {
            try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop }
            catch { Write-Warning "Could not stop $processName (PID $($proc.Id)): $($_.Exception.Message)" }
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

function Copy-DirectoryClean {
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path -LiteralPath $Source)) { throw "Source not found: $Source" }
    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force -ErrorAction Stop
    }
    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

Write-Host "=== emptytest launch script (Reborn) ==="
Write-Host "RebornModPath: $RebornModPath"
Write-Host ""

Write-Host "[1/6] Stopping SC2 processes..."
Stop-RunningSc2

Write-Host "[2/6] Clearing game logs..."
Clear-Sc2GameLogs

Write-Host "[3/6] Syncing map to game directory..."
Copy-DirectoryClean -Source $mapSource -Destination $mapLive

Write-Host "[4/6] Syncing StarCoop to game directory..."
if ($StarCoopPath -ne "") {
    Copy-DirectoryClean -Source $StarCoopPath -Destination $starCoopLive
} else {
    Write-Host "  (skipped - no StarCoop path)"
}

Write-Host "[5/6] Syncing reborn mod to game directory..."
Copy-DirectoryClean -Source $RebornModPath -Destination $rebornLive

Write-Host "[6/6] Launching game..."
Write-Host "Map path: $mapLive"
& $switcherPath $mapLive

Write-Host ""
Write-Host "Launch complete!"
