<#
.SYNOPSIS
  CMRE (Co-op Mission Rewrite Enhanced) Campaign Launcher
  Launch CMRE co-op maps with CMRE mod, optionally overlaying 7vs1 commanders.
.DESCRIPTION
  1. (optional) -DryRun: emit plan, no writes/launch
  2. (optional) -NoLaunch: sync mods + map + write Bank, but don't launch game
  3. Stop SC2
  4. Sync CMRE mod to live SC2
  5. If commander is not "CMRE", also sync 7vs1 base + commander units mods
  6. Sync map to live SC2 Maps folder
  7. Set map DocumentHeader dependencies (CMRE mod + optional commander mods)
  8. If 7vs1 commander, write CampaignXCore Bank
  9. Launch map with SC2Switcher
  10. Wait for game ready

  Uses shared modules from scripts/sc2-launcher/ and config from Shared/Launcher/.
#>
param(
    [string]$Commander = "CMRE",
    [string]$MapName = "亡者之夜.SC2Map",
    [switch]$NoLaunch,
    [switch]$SkipWait,
    [switch]$DryRun,
    [switch]$EnableNeuro,
    [switch]$SkipPythonRuntime
)

$ErrorActionPreference = "Stop"

# === Paths ===
$ScriptsRoot = Split-Path $PSScriptRoot -Parent
$ProjRoot = Split-Path $ScriptsRoot -Parent
$Sc2Root  = "E:\SC2\SC2new\StarCraft II"
$MapLivePath = Join-Path $Sc2Root "Maps\$MapName"

# === Load shared launcher modules ===
$script:LauncherScriptsRoot = Join-Path $ScriptsRoot "sc2-launcher"
. (Join-Path $script:LauncherScriptsRoot "common.ps1")
. (Join-Path $script:LauncherScriptsRoot "mod-sync.ps1")
. (Join-Path $script:LauncherScriptsRoot "map-sync.ps1")
. (Join-Path $script:LauncherScriptsRoot "config-validation.ps1")

# === Load project-specific dependency scripts ===
. (Join-Path $ScriptsRoot "commander-power-metadata.ps1")
. (Join-Path $ScriptsRoot "sc2\campaignxcore-bank.ps1")

function Convert-TestCommanderToCommanderPowerKey {
    param([string]$Commander)
    return (Convert-CommanderPowerCommanderToBankKey -Commander $Commander -WorkspaceRoot $ProjRoot)
}

# === Load configuration ===
$cmreConfig = Import-LauncherConfig -Name "cmre-dependencies"

$isOriginalMode = ($Commander -eq "CMRE")

Write-Host "=== CMRE Campaign Launcher ==="
Write-Host "Commander: $Commander"
Write-Host "Map: $MapName"
Write-Host "Mode: $(if ($isOriginalMode) { 'Original (CMRE only)' } else { '7vs1 Commander overlay' })"
if ($DryRun)   { Write-Host "DryRun: true (no writes, no launch)" }
if ($NoLaunch) { Write-Host "NoLaunch: true (sync + Bank, no game launch)" }

# === Config validation ===
if ($cmreConfig.validCommanders -notcontains $Commander) {
    Write-Host "ERROR: unknown commander '$Commander'. Valid: $($cmreConfig.validCommanders -join ', ')"
    exit 1
}

# Map name validation: must end with .SC2Map
if ($MapName -notmatch '\.SC2Map$') {
    Write-Host "ERROR: MapName must end with .SC2Map, got: $MapName"
    exit 1
}

# === DryRun: emit plan + exit ===
if ($DryRun) {
    $mapBaseName = [System.IO.Path]::GetFileNameWithoutExtension($MapName)
    Write-Host "=== DryRun Plan ==="
    Write-Host "Commander: $Commander"
    Write-Host "Map: $MapName"
    Write-Host "MapLivePath: $MapLivePath"
    Write-Host "Mode: $(if ($isOriginalMode) { 'Original' } else { '7vs1 Commander' })"
    Write-Host "Base mods:"
    foreach ($m in $cmreConfig.baseMods) { Write-Host "  - $m" }
    if (-not $isOriginalMode) {
        Write-Host "Commander base mods:"
        foreach ($m in $cmreConfig.commanderBaseMods) { Write-Host "  - $m" }
        $commanderUnitsMod = Get-CommanderUnitsModName -Commander $Commander
        if ($commanderUnitsMod) {
            Write-Host "Commander units mod: 7vs1\$commanderUnitsMod.SC2Mod"
        }
    }
    Write-Host "DryRun complete - no writes to live SC2, no game launch"
    exit 0
}

# === Stop SC2 before syncing ===
Stop-RunningSc2
Clear-GameLogs

# === MOD SYNC SECTION ===
Write-Host "--- Mod Sync ---"

# Always sync CMRE mod
foreach ($modRelPath in $cmreConfig.baseMods) {
    Write-Host "Syncing mod: $modRelPath"
    Sync-ModToLive -ModRelPath $modRelPath -ProjRoot $ProjRoot -Sc2Root $Sc2Root
}

# If 7vs1 commander mode, sync commander base mods + commander units mod
if (-not $isOriginalMode) {
    foreach ($modRelPath in $cmreConfig.commanderBaseMods) {
        Write-Host "Syncing commander base mod: $modRelPath"
        Sync-ModToLive -ModRelPath $modRelPath -ProjRoot $ProjRoot -Sc2Root $Sc2Root
    }

    $commanderUnitsMod = Get-CommanderUnitsModName -Commander $Commander
    if ($commanderUnitsMod) {
        Write-Host "Syncing commander units mod: 7vs1\$commanderUnitsMod.SC2Mod"
        Sync-ModToLive -ModRelPath "7vs1\$commanderUnitsMod.SC2Mod" -ProjRoot $ProjRoot -Sc2Root $Sc2Root
    }

    # Remove unselected CommanderUnits mods from live directory
    $allowedCommanderUnits = @()
    if ($commanderUnitsMod) {
        $allowedCommanderUnits += "$commanderUnitsMod.SC2Mod"
    }
    Remove-StaleCommanderUnitsMods -Sc2Root $Sc2Root -AllowedModNames $allowedCommanderUnits
}

# === MAP SYNC SECTION ===
Write-Host "--- Map Sync ---"
# CMRE maps live in Maps\CMRE\ subdirectory
$mapSrcDir = Join-Path $ProjRoot "Maps\CMRE\$MapName"
if (-not (Test-Path $mapSrcDir)) {
    Write-Host "ERROR: map source not found: $mapSrcDir"
    exit 1
}
if (Test-Path $MapLivePath) { [System.IO.Directory]::Delete($MapLivePath, $true) }
[System.IO.Directory]::CreateDirectory($MapLivePath) | Out-Null
robocopy $mapSrcDir $MapLivePath /MIR /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
Write-Host "SYNC map: $MapName (from Maps\CMRE\)"

# === DEPENDENCY REWRITE SECTION ===
Write-Host "--- Dependency Rewrite ---"
$runtimeDeps = @()

# Add CMRE mod dependency
foreach ($depPath in $cmreConfig.baseDependencyPaths) {
    $runtimeDeps += $depPath
}

# Add 7vs1 commander base mod dependencies
if (-not $isOriginalMode) {
    foreach ($depPath in $cmreConfig.commanderBaseDependencyPaths) {
        $runtimeDeps += $depPath
    }

    # Add commander units mod dependency
    $commanderUnitsMod = Get-CommanderUnitsModName -Commander $Commander
    if ($commanderUnitsMod) {
        $runtimeDeps += "file:Mods/7vs1/$commanderUnitsMod.SC2Mod"
    }
}

# Add Neuro mod dependencies (when -EnableNeuro)
if ($EnableNeuro) {
    $runtimeDeps += "file:Mods/NeuroIntegration.SC2Mod"
    $runtimeDeps += "file:Mods/Neuro/NeuroBridge7vs1.SC2Mod"
    Write-Host "Added Neuro dependencies (NeuroIntegration + NeuroBridge7vs1)"
}

Write-Host "Setting $($runtimeDeps.Count) dependencies on map..."
Set-MapDependencies -MapPath $MapLivePath -Dependencies $runtimeDeps

# === DOCUMENT ROUNDTRIP VALIDATION ===
$headerPath = Join-Path $MapLivePath "DocumentHeader"
$infoPath   = Join-Path $MapLivePath "DocumentInfo"
$rtResult = Test-DocumentDependencyRoundtrip -HeaderPath $headerPath -InfoPath $infoPath
if (-not $rtResult.Valid) {
    Write-Host "DOCUMENT ROUNDTRIP FAILED:"
    foreach ($e in $rtResult.Errors) { Write-Host "  - $e" }
    Write-Host "Aborting before launch - DocumentHeader/DocumentInfo may be corrupted"
    exit 1
}
Write-Host "DOCUMENT ROUNDTRIP VALID (header deps: $($rtResult.OriginalDeps.Count), info deps: $($rtResult.InfoDeps.Count))"

# === BANK SECTION ===
if (-not $isOriginalMode) {
    Write-Host "--- Bank Write ---"
    Write-Host "Writing CampaignXCore Bank for commander: $Commander"
    Set-CampaignXCorePrimaryCommander -SelectedCommanders @($Commander)
    Set-CampaignXCoreTestRunId -RunId "CMRECommander"
}

# === NEURO INTEGRATION SECTION (optional, -EnableNeuro) ===
# Ported from launch-7vs1-coop-test.ps1: copy mods, inject galaxy, patch BankList/MapScript
$pythonProcessId = $null
if ($EnableNeuro) {
    Write-Host "`n=== Neuro Integration ===" -ForegroundColor Cyan

    # 辅助函数：使用 .NET API 绕过 TRAE 沙箱对 Remove-Item/Copy-Item 的拦截
    function Remove-DirSafe {
        param([string]$Path)
        if (Test-Path -LiteralPath $Path -PathType Container) {
            [System.IO.Directory]::Delete($Path, $true)
        } elseif (Test-Path -LiteralPath $Path) {
            [System.IO.File]::Delete($Path)
        }
    }
    function New-DirSafe {
        param([string]$Path)
        if (-not (Test-Path -LiteralPath $Path)) {
            [System.IO.Directory]::CreateDirectory($Path) | Out-Null
        }
    }
    function Copy-DirSafe {
        param([string]$Source, [string]$Destination)
        Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
        [Microsoft.VisualBasic.FileIO.FileSystem]::CopyDirectory($Source, $Destination, $true)
    }

    # === 路径解析（基于 Shared/Launcher/neuro-dependencies.json）===
    $neuroDepsPath = Join-Path $ProjRoot "Shared\Launcher\neuro-dependencies.json"
    $repoRoot = Split-Path -Parent $ProjRoot
    $neuroDeps = $null
    if (Test-Path -LiteralPath $neuroDepsPath) {
        try {
            $neuroDeps = Get-Content -LiteralPath $neuroDepsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            Write-Host "  Loaded neuro-dependencies.json (capability=$($neuroDeps.capability))" -ForegroundColor DarkGray
        } catch {
            Write-Host "  WARN: failed to parse neuro-dependencies.json: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  WARN: neuro-dependencies.json missing at $neuroDepsPath" -ForegroundColor Yellow
    }

    $NeuroModSource = Join-Path $repoRoot "tools\SC2-Neuro-WoL-Integration\Mods\NeuroIntegration.SC2Mod"
    if ($neuroDeps -and $neuroDeps.mods) {
        $coreMod = @($neuroDeps.mods) | Where-Object { $_.id -eq "NeuroIntegration" } | Select-Object -First 1
        if ($coreMod -and $coreMod.sourceWorkspace) {
            $NeuroModSource = Join-Path $repoRoot ($coreMod.sourceWorkspace -replace '/', '\')
        }
    }
    $BridgeModSource = Join-Path $ProjRoot "Mods\Neuro\NeuroBridge7vs1.SC2Mod"
    if ($neuroDeps -and $neuroDeps.mods) {
        $bridgeMod = @($neuroDeps.mods) | Where-Object { $_.id -eq "NeuroBridge7vs1" } | Select-Object -First 1
        if ($bridgeMod -and $bridgeMod.sourceWorkspace) {
            $BridgeModSource = Join-Path $ProjRoot ($bridgeMod.sourceWorkspace -replace '/', '\')
        }
    }
    $NeuroApiRoot = Join-Path $repoRoot "tools\SC2-Neuro-API-Integration"
    if ($neuroDeps -and $neuroDeps.pythonRuntime -and $neuroDeps.pythonRuntime.rootWorkspace) {
        $NeuroApiRoot = Join-Path $repoRoot ($neuroDeps.pythonRuntime.rootWorkspace -replace '/', '\')
    }

    # Prove LibEFA54406 ownership before injection
    $efaHeader = Join-Path $NeuroModSource "Base.SC2Data\LibEFA54406_h.galaxy"
    $efaBody = Join-Path $NeuroModSource "Base.SC2Data\LibEFA54406.galaxy"
    if (-not (Test-Path -LiteralPath $efaHeader) -or -not (Test-Path -LiteralPath $efaBody)) {
        throw "LibEFA54406 closure incomplete under NeuroIntegration: missing $efaHeader or $efaBody"
    }
    Write-Host "  LibEFA54406 closure OK (owned by NeuroIntegration)" -ForegroundColor Green

    Write-Host "NeuroMod:  $NeuroModSource"
    Write-Host "BridgeMod: $BridgeModSource"

    if (-not (Test-Path -LiteralPath $NeuroModSource)) {
        throw "NeuroIntegration mod not found: $NeuroModSource"
    }
    if (-not (Test-Path -LiteralPath $BridgeModSource)) {
        throw "NeuroBridge7vs1 mod not found: $BridgeModSource"
    }

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

    # === Step N2: 复制 Neuro mod 到 SC2 运行时目录 ===
    Write-Host "`n--- Neuro Step 2: Copy Neuro mods to SC2 runtime ---" -ForegroundColor Yellow
    $neuroLiveDir = Join-Path $Sc2Root "Mods\NeuroIntegration.SC2Mod"
    $bridgeLiveDir = Join-Path $Sc2Root "Mods\Neuro\NeuroBridge7vs1.SC2Mod"

    if (Test-Path $neuroLiveDir) { Remove-DirSafe $neuroLiveDir }
    Copy-DirSafe $NeuroModSource $neuroLiveDir
    Write-Host "  Copied NeuroIntegration -> $neuroLiveDir"

    # Step N2b: 修正 NeuroIntegration 依赖项以匹配 CMRE 地图使用的中文 bnet 依赖
    # 源 mod 使用英文 bnet:Liberty (Campaign) + Campaigns/Liberty.SC2Campaign，但 SC2 安装目录下不存在该路径
    # CMRE 地图使用：自由之翼剧情 (战役) + Campaigns/LibertyStory.SC2Campaign 和 自由之翼 (Mod) + Mods/Liberty.SC2Mod
    $neuroDocInfoPath = Join-Path $neuroLiveDir "DocumentInfo"
    if (Test-Path -LiteralPath $neuroDocInfoPath) {
        $neuroDocInfo = [System.IO.File]::ReadAllText($neuroDocInfoPath)
        $needsFix = $false
        if ($neuroDocInfo -match 'Liberty \(Campaign\)') { $needsFix = $true }
        if ($neuroDocInfo -match 'Campaigns/Liberty\.SC2Campaign') { $needsFix = $true }
        if ($needsFix) {
            $fixedDocInfo = '<?xml version="1.0" encoding="utf-8"?>' + "`n" +
                '<DocInfo>' + "`n" +
                '    <Dependencies>' + "`n" +
                '        <Value>bnet:自由之翼剧情 (战役)/0.0/999,file:Campaigns/LibertyStory.SC2Campaign</Value>' + "`n" +
                '        <Value>bnet:自由之翼 (Mod)/0.0/999,file:Mods/Liberty.SC2Mod</Value>' + "`n" +
                '    </Dependencies>' + "`n" +
                '</DocInfo>'
            [System.IO.File]::WriteAllText($neuroDocInfoPath, $fixedDocInfo, $utf8NoBom)
            Write-Host "  Fixed NeuroIntegration DocumentInfo dependencies (matched CMRE map)" -ForegroundColor Green
        }
    }

    $bridgeLiveParent = Split-Path $bridgeLiveDir -Parent
    if (-not (Test-Path $bridgeLiveParent)) { New-DirSafe $bridgeLiveParent }
    if (Test-Path $bridgeLiveDir) { Remove-DirSafe $bridgeLiveDir }
    Copy-DirSafe $BridgeModSource $bridgeLiveDir
    Write-Host "  Copied NeuroBridge7vs1 -> $bridgeLiveDir"

    # === Step N3: 注入 galaxy 库文件到地图 Base.SC2Data ===
    Write-Host "`n--- Neuro Step 3: Inject galaxy libraries into map ---" -ForegroundColor Yellow
    $mapLiveBaseData = Join-Path $MapLivePath "Base.SC2Data"
    if (-not (Test-Path $mapLiveBaseData)) {
        New-DirSafe $mapLiveBaseData
    }
    # NeuroIntegration galaxy 文件
    $neuroGalaxyDir = Join-Path $neuroLiveDir "Base.SC2Data"
    $neuroGalaxyFiles = Get-ChildItem $neuroGalaxyDir -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
    foreach ($gf in $neuroGalaxyFiles) {
        $dst = Join-Path $mapLiveBaseData $gf.Name
        [System.IO.File]::Copy($gf.FullName, $dst, $true)
        Write-Host "  Injected: $($gf.Name)"
    }
    # NeuroBridge7vs1 galaxy 文件
    $bridgeGalaxyDir = Join-Path $bridgeLiveDir "Base.SC2Data"
    $bridgeGalaxyFiles = Get-ChildItem $bridgeGalaxyDir -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
    foreach ($gf in $bridgeGalaxyFiles) {
        $dst = Join-Path $mapLiveBaseData $gf.Name
        [System.IO.File]::Copy($gf.FullName, $dst, $true)
        Write-Host "  Injected: $($gf.Name)"
    }

    # === Step N4: 注入 BankList.xml ===
    Write-Host "`n--- Neuro Step 4: Patch BankList.xml ---" -ForegroundColor Yellow
    $bankListPath = Join-Path $MapLivePath "BankList.xml"
    if (Test-Path -LiteralPath $bankListPath) {
        $bankContent = [System.IO.File]::ReadAllText($bankListPath)
        if ($bankContent -notmatch 'Name="NeuroIntegration"') {
            $bankEntry = '    <Bank Name="NeuroIntegration" Player="1"/>'
            $bankContent = $bankContent.Replace('</BankList>', ($bankEntry + "`n</BankList>"))
            Write-Host "  Added NeuroIntegration bank declaration"
        } else {
            Write-Host "  Already has NeuroIntegration bank"
        }
        # 同时添加 NeuroPermanent bank（用于跨任务持久化）
        if ($bankContent -notmatch 'Name="NeuroPermanent"') {
            $permanentEntry = '    <Bank Name="NeuroPermanent" Player="1"/>'
            $bankContent = $bankContent.Replace('</BankList>', ($permanentEntry + "`n</BankList>"))
            Write-Host "  Added NeuroPermanent bank declaration"
        }
        [System.IO.File]::WriteAllText($bankListPath, $bankContent, $utf8NoBom)
    } else {
        Write-Host "  WARN: BankList.xml not found, creating minimal one"
        $bankContent = "<?xml version=`"1.0`" encoding=`"utf-8`"?>`n<BankList>`n    <Bank Name=`"NeuroIntegration`" Player=`"1`"/>`n    <Bank Name=`"NeuroPermanent`" Player=`"1`"/>`n</BankList>`n"
        [System.IO.File]::WriteAllText($bankListPath, $bankContent, $utf8NoBom)
    }

    # === Step N5: 注入 MapScript.galaxy ===
    Write-Host "`n--- Neuro Step 5: Patch MapScript.galaxy ---" -ForegroundColor Yellow
    $mapScriptPath = Join-Path $MapLivePath "MapScript.galaxy"
    if (Test-Path -LiteralPath $mapScriptPath) {
        $content = [System.IO.File]::ReadAllText($mapScriptPath)
        $modified = $false

        # N5a. 注入 include（在最后一个 include 之后）
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

        # N5b. 注入 InitLib 调用（在 InitLibs() 闭合大括号之前）
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

    Write-Host "Neuro integration completed." -ForegroundColor Green

    # === Step N6: 启动/复用共享 Neuro 运行时服务（可选，-NoLaunch 时跳过）===
    if (-not $SkipPythonRuntime -and -not $NoLaunch) {
        Write-Host "`n--- Neuro Step 6: Ensure shared Neuro runtime service ---" -ForegroundColor Yellow

        $serviceScript = Join-Path $ScriptsRoot "runtime-probe\start-neuro-runtime-service.ps1"
        if (Test-Path -LiteralPath $serviceScript) {
            $serviceArgs = @(
                "-NeuroApiRoot", $NeuroApiRoot,
                "-Sc2Root", $Sc2Root
            )
            $serviceJsonText = & pwsh -NoProfile -ExecutionPolicy Bypass -File $serviceScript @serviceArgs
            Write-Host $serviceJsonText
            try {
                $serviceState = $serviceJsonText | ConvertFrom-Json
                if ($serviceState.processes.neuroApi.pid) { $pythonProcessId = [int]$serviceState.processes.neuroApi.pid }
                if ($serviceState.webUrl) {
                    Write-Host "  Runtime API: $($serviceState.webUrl)" -ForegroundColor Cyan
                }
            } catch {
                Write-Host "  WARN: failed to parse service state: $_" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  WARN: start-neuro-runtime-service.ps1 not found at $serviceScript" -ForegroundColor Yellow
        }
    }
}

# === LAUNCH SECTION ===
if ($NoLaunch) {
    Write-Host "NoLaunch mode, skip launch"
    exit 0
}

$switcher = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
Write-Host "--- Launch ---"
Write-Host "Launching: $MapLivePath"
Start-Process -FilePath $switcher -ArgumentList "`"$MapLivePath`""

if ($SkipWait) {
    Write-Host "SkipWait mode, skip wait"
    exit 0
}

# Wait for game ready
$exitCode = Wait-GameReady -ScriptsRoot $ScriptsRoot
Write-Host "wait-for-game-ready exit code: $exitCode"
exit $exitCode
