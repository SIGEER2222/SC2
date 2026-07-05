param(
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$RebornModPath = "",
    [string]$StarCoopPath = ""
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$mapSource = Join-Path $workspaceRoot "Maps\abathur_test_map"

# auto-search reborn mod (avoid non-ASCII path encoding issues, prefer workrepo)
if ([string]::IsNullOrEmpty($RebornModPath)) {
    $downloadsDir = [System.IO.Path]::Combine($env:USERPROFILE, "Downloads")
    $allFound = Get-ChildItem -LiteralPath $downloadsDir -Recurse -Directory -Filter "crys_the_swarm_reborn.SC2Mod" -ErrorAction SilentlyContinue
    $workrepo = $allFound | Where-Object { Test-Path (Join-Path $_.FullName "Base.SC2Data") } | Select-Object -First 1
    if ($workrepo) {
        $RebornModPath = $workrepo.FullName
    } elseif ($allFound) {
        $RebornModPath = $allFound[0].FullName
    }
}

$mapLive = Join-Path (Join-Path $Sc2Root "Maps\7vs1") "abathur_test.SC2Map"
$rebornLive = Join-Path (Join-Path $Sc2Root "Mods") "crys_the_swarm_reborn.SC2Mod"
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

Write-Host "=== Abathur Test Launch Script ==="
Write-Host "Map Source: $mapSource"
Write-Host "RebornModPath: $RebornModPath"
Write-Host ""

Write-Host "[1/5] Stopping SC2 processes..."
Stop-RunningSc2

Write-Host "[2/5] Clearing game logs..."
Clear-Sc2GameLogs

Write-Host "[3/5] Syncing map to game directory..."
Copy-DirectoryClean -Source $mapSource -Destination $mapLive

Write-Host "[4/5] Syncing reborn mod to game directory..."
Copy-DirectoryClean -Source $RebornModPath -Destination $rebornLive

Write-Host "[5/5] Launching game..."
Write-Host "Map path: $mapLive"
& $switcherPath $mapLive

Write-Host ""
Write-Host "Launch complete!"
