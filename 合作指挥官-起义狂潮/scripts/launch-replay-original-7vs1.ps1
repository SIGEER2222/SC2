[CmdletBinding()]
param(
    [string]$ReplayExtractRoot = "E:\Code\MyMod\SC2\合作指挥官-起义狂潮\游戏数据\其他mod数据\7vs1母巢之战合作指挥官bate版_SC2Replay_94137",
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$LiveMapName = "ReplayOriginal7vs1.SC2Map",
    [string]$LiveModName = "ReplayOriginal7vs1.SC2Mod",
    [string]$OfficialMirrorRoot = "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\游戏数据\官方SC2原始文本镜像\mods",
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"

function Remove-DirectoryWithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [int]$RetryCount = 5,
        [int]$DelayMilliseconds = 400
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            return
        }
        catch {
            if (-not (Test-Path -LiteralPath $Path)) {
                return
            }

            if ($attempt -ge $RetryCount) {
                throw
            }

            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }
}

function Copy-DirectoryClean {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Source directory not found: $Source"
    }

    if (Test-Path -LiteralPath $Destination) {
        Remove-DirectoryWithRetry -Path $Destination
    }

    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

function Replace-InFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$OldValue,
        [Parameter(Mandatory = $true)]
        [string]$NewValue
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "File not found for patching: $Path"
    }

    $content = Get-Content -LiteralPath $Path -Raw
    if (-not $content.Contains($OldValue)) {
        throw "Patch target not found in ${Path}: $OldValue"
    }

    $updated = $content.Replace($OldValue, $NewValue)
    Set-Content -LiteralPath $Path -Value $updated -Encoding utf8
}

function Stop-RunningSc2 {
    foreach ($processName in @("SC2_x64", "SC2Switcher_x64", "BlizzardError")) {
        foreach ($proc in @(Get-Process -Name $processName -ErrorAction SilentlyContinue)) {
            try {
                Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            }
            catch {
                Write-Warning "Could not stop $processName (PID $($proc.Id)): $($_.Exception.Message)"
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

$switcherPath = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
$mapSource = Join-Path $ReplayExtractRoot "s2ma_packages\pkg02\extract"
$modSource = Join-Path $ReplayExtractRoot "s2ma_packages\pkg03\extract"
$alliedCommandersSource = Join-Path $ReplayExtractRoot "s2ma_packages\pkg05\extract"
$liveMapPath = Join-Path (Join-Path $Sc2Root "Maps\ReplayOriginal7vs1") $LiveMapName
$liveModPath = Join-Path $Sc2Root ("Mods\{0}" -f $LiveModName)
$liveAlliedCommandersPath = Join-Path $Sc2Root "Mods\ReplayOriginal7vs1_AlliedCommanders.SC2Mod"
$officialVoidMultiSource = Join-Path $OfficialMirrorRoot "voidmulti.sc2mod"
$officialStarCoopSource = Join-Path $OfficialMirrorRoot "starcoop\starcoop.sc2mod"
$officialMengskSource = Join-Path $OfficialMirrorRoot "starcoop\commanders\arcturusmengsk.sc2mod"
$officialStetmannSource = Join-Path $OfficialMirrorRoot "starcoop\commanders\egonstetmann.sc2mod"
$liveVoidMultiPath = Join-Path $Sc2Root "Mods\VoidMulti.SC2Mod"
$liveStarCoopPath = Join-Path $Sc2Root "Mods\StarCoop\StarCoop.SC2Mod"
$liveMengskPath = Join-Path $Sc2Root "Mods\StarCoop\Commanders\ArcturusMengsk.SC2Mod"
$liveStetmannPath = Join-Path $Sc2Root "Mods\StarCoop\Commanders\EgonStetmann.SC2Mod"

if (-not (Test-Path -LiteralPath $switcherPath)) {
    throw "SC2 switcher not found: $switcherPath"
}

if (-not (Test-Path -LiteralPath (Join-Path $mapSource "MapInfo"))) {
    throw "Replay map package is incomplete: $mapSource"
}

if (-not (Test-Path -LiteralPath (Join-Path $modSource "DocumentInfo"))) {
    throw "Replay extension mod package is incomplete: $modSource"
}

if (-not (Test-Path -LiteralPath (Join-Path $alliedCommandersSource "DocumentInfo"))) {
    throw "Replay Allied Commanders package is incomplete: $alliedCommandersSource"
}

foreach ($dependencySource in @(
    $officialVoidMultiSource,
    $officialStarCoopSource,
    $officialMengskSource,
    $officialStetmannSource
)) {
    if (-not (Test-Path -LiteralPath $dependencySource)) {
        throw "Missing required official dependency source: $dependencySource"
    }
}

Stop-RunningSc2
Clear-Sc2GameLogs
Copy-DirectoryClean -Source $mapSource -Destination $liveMapPath
Copy-DirectoryClean -Source $modSource -Destination $liveModPath
Copy-DirectoryClean -Source $alliedCommandersSource -Destination $liveAlliedCommandersPath
Copy-DirectoryClean -Source $officialVoidMultiSource -Destination $liveVoidMultiPath
Copy-DirectoryClean -Source $officialStarCoopSource -Destination $liveStarCoopPath
Copy-DirectoryClean -Source $officialMengskSource -Destination $liveMengskPath
Copy-DirectoryClean -Source $officialStetmannSource -Destination $liveStetmannPath

$liveMapDocInfo = Join-Path $liveMapPath "DocumentInfo"
$liveModDocInfo = Join-Path $liveModPath "DocumentInfo"
$liveAlliedCommandersDocInfo = Join-Path $liveAlliedCommandersPath "DocumentInfo"

Replace-InFile -Path $liveMapDocInfo `
    -OldValue "<Value>bnet:Allied Commanders/0.0/74766</Value>" `
    -NewValue "<Value>file:Mods/ReplayOriginal7vs1_AlliedCommanders.SC2Mod</Value>"

Replace-InFile -Path $liveModDocInfo `
    -OldValue "<Value>bnet:Void Multi (Mod)/0.0/999,file:Mods/VoidMulti.SC2Mod</Value>" `
    -NewValue "<Value>file:Mods/VoidMulti.SC2Mod</Value>"

Replace-InFile -Path $liveModDocInfo `
    -OldValue "<Value>bnet:Co-op Mission/0.0/999,file:Mods/StarCoop/StarCoop.SC2Mod</Value>" `
    -NewValue "<Value>file:Mods/StarCoop/StarCoop.SC2Mod</Value>"

Replace-InFile -Path $liveAlliedCommandersDocInfo `
    -OldValue "<Value>bnet:Co-op Mission/0.0/999,file:Mods/StarCoop/StarCoop.SC2Mod</Value>" `
    -NewValue "<Value>file:Mods/StarCoop/StarCoop.SC2Mod</Value>"

Write-Host "Installed replay-original map: $liveMapPath"
Write-Host "Installed replay-original mod: $liveModPath"
Write-Host "Installed replay-original Allied Commanders mod: $liveAlliedCommandersPath"
Write-Host "Installed official dependency mod: $liveVoidMultiPath"
Write-Host "Installed official dependency mod: $liveStarCoopPath"
Write-Host "Installed official dependency mod: $liveMengskPath"
Write-Host "Installed official dependency mod: $liveStetmannPath"

if (-not $NoLaunch) {
    Write-Host "Launching replay-original 7vs1..."
    & $switcherPath -run $liveMapPath -testmod $liveModPath
}
