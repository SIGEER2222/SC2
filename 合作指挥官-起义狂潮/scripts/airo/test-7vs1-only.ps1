<#
.SYNOPSIS
  排除法测试：只加载 7vs1 mod（不加载 RO mod）+ traynor01 地图
  用于确认崩溃是 RO mod + 7vs1 冲突还是 traynor01 + 7vs1 不兼容
#>
param(
    [string]$MapName = "traynor01.SC2Map",
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"

$ScriptsRoot = Split-Path $PSScriptRoot -Parent
$ProjRoot = Split-Path $ScriptsRoot -Parent
$Sc2Root  = "E:\SC2\SC2new\StarCraft II"
$MapLivePath = Join-Path $Sc2Root "Maps\$MapName"

# Load shared modules
$script:LauncherScriptsRoot = Join-Path $ScriptsRoot "sc2-launcher"
. (Join-Path $script:LauncherScriptsRoot "common.ps1")
. (Join-Path $script:LauncherScriptsRoot "mod-sync.ps1")
. (Join-Path $script:LauncherScriptsRoot "map-sync.ps1")
. (Join-Path $script:LauncherScriptsRoot "config-validation.ps1")

Write-Host "=== Exclusion Test: 7vs1 only (no RO mod) ==="
Write-Host "Map: $MapName"

Stop-RunningSc2
Clear-GameLogs

# --- MOD SYNC: only 7vs1 mods, NO RO mod ---
$commanderBaseMods = @(
    "7vs1\CoreRuntime.SC2Mod",
    "7vs1\CommanderBridge.SC2Mod"
)
foreach ($modRelPath in $commanderBaseMods) {
    Write-Host "Syncing: $modRelPath"
    Sync-ModToLive -ModRelPath $modRelPath -ProjRoot $ProjRoot -Sc2Root $Sc2Root
}
Sync-ModToLive -ModRelPath "7vs1\CommanderUnits_Raynor.SC2Mod" -ProjRoot $ProjRoot -Sc2Root $Sc2Root
Remove-StaleCommanderUnitsMods -Sc2Root $Sc2Root -AllowedModNames @("CommanderUnits_Raynor.SC2Mod")

# --- MAP SYNC ---
$mapSrcDir = Join-Path $ProjRoot "Maps\AIRO\$MapName"
if (Test-Path $MapLivePath) { [System.IO.Directory]::Delete($MapLivePath, $true) }
[System.IO.Directory]::CreateDirectory($MapLivePath) | Out-Null
robocopy $mapSrcDir $MapLivePath /MIR /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
Write-Host "SYNC map: $MapName"

# --- GALAXY INJECTION ---
$mapLiveBaseData = Join-Path $MapLivePath "Base.SC2Data"

# Inject CommanderUnits_* galaxy
Sync-MapRuntimeLibraries `
    -MapPath $MapLivePath `
    -ProjRoot $ProjRoot `
    -SourcePatterns @("CommanderUnits_*.SC2Mod") `
    -SourceRoot "Mods\7vs1"

# Inject CoreRuntime galaxy
$coreRuntimeBaseData = Join-Path $ProjRoot "Mods\7vs1\CoreRuntime.SC2Mod\Base.SC2Data"
if (Test-Path $coreRuntimeBaseData) {
    $coreGalaxyFiles = Get-ChildItem $coreRuntimeBaseData -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
    $coreCount = 0
    foreach ($gf in $coreGalaxyFiles) {
        $dst = Join-Path $mapLiveBaseData $gf.Name
        [System.IO.File]::Copy($gf.FullName, $dst, $true)
        $coreCount++
    }
    Write-Host "SYNC CoreRuntime galaxy: $coreCount files"
}

# Inject CommanderBridge galaxy
$commanderBridgeBaseData = Join-Path $ProjRoot "Mods\7vs1\CommanderBridge.SC2Mod\Base.SC2Data"
if (Test-Path $commanderBridgeBaseData) {
    $bridgeGalaxyFiles = Get-ChildItem $commanderBridgeBaseData -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
    $bridgeCount = 0
    foreach ($gf in $bridgeGalaxyFiles) {
        $dst = Join-Path $mapLiveBaseData $gf.Name
        [System.IO.File]::Copy($gf.FullName, $dst, $true)
        $bridgeCount++
    }
    Write-Host "SYNC CommanderBridge galaxy: $bridgeCount files"
}

# --- DEPENDENCY REWRITE: only 7vs1 deps + campaign deps, NO RO mod ---
$runtimeDeps = @(
    "file:Mods/7vs1/CoreRuntime.SC2Mod",
    "file:Mods/7vs1/CommanderBridge.SC2Mod",
    "bnet:自由之翼剧情 (战役)/0.0/999,file:Campaigns/LibertyStory.SC2Campaign",
    "bnet:自由之翼 (Mod)/0.0/999,file:Mods/Liberty.SC2Mod",
    "bnet:Void Story (Campaign)/0.0/999,file:Campaigns/VoidStory.SC2Campaign"
)

Write-Host "Setting $($runtimeDeps.Count) dependencies (NO RO mod)..."
Set-MapDependencies -MapPath $MapLivePath -Dependencies $runtimeDeps
Write-Host "Dependencies set."

if ($NoLaunch) {
    Write-Host "NoLaunch mode, exit."
    exit 0
}

# --- LAUNCH ---
$sc2Exe = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
Write-Host "Launching: $MapLivePath"
Start-Process -FilePath $sc2Exe -ArgumentList "`"$MapLivePath`""

# --- WAIT ---
$waitScript = Join-Path $ScriptsRoot "wait-for-game-ready.ps1"
& $waitScript -MaxWait 180
exit $LASTEXITCODE
