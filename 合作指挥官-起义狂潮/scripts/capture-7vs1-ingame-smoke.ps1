[CmdletBinding()]
param(
    [string]$MapSource = "",
    [string]$LiveMapName = "ttosh02_7vs1.SC2Map",
    [string[]]$Commanders = @("TerranRaynor"),
    [int]$WaitSeconds = 50,
    [string]$ScreenshotPath = ""
)

$ErrorActionPreference = "Stop"

function Get-WorkspaceRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Resolve-WorkspacePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path (Get-WorkspaceRoot) $Path
}

function Get-LatestItem {
    param(
        [string]$Root,
        [string]$Filter,
        [switch]$Directory
    )

    if (-not (Test-Path -LiteralPath $Root)) {
        return $null
    }

    $items = if ($Directory) {
        Get-ChildItem -LiteralPath $Root -Directory -Filter $Filter -ErrorAction SilentlyContinue
    }
    else {
        Get-ChildItem -LiteralPath $Root -File -Filter $Filter -ErrorAction SilentlyContinue
    }

    return @($items | Sort-Object LastWriteTime -Descending | Select-Object -First 1)[0]
}

function Stop-RunningSc2 {
    $names = @("SC2_x64", "SC2Switcher_x64", "BlizzardError")
    foreach ($name in $names) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

$workspaceRoot = Get-WorkspaceRoot
$artifactRoot = Join-Path $workspaceRoot "logs"
$null = New-Item -ItemType Directory -Path $artifactRoot -Force
$logsRoot = Join-Path $env:USERPROFILE "Documents\StarCraft II\GameLogs"
if ([string]::IsNullOrWhiteSpace($MapSource)) {
    $defaultLocalMap = Join-Path $workspaceRoot "Maps\ttosh02_7vs1.SC2Map"
    if (Test-Path -LiteralPath $defaultLocalMap) {
        $resolvedMapSource = $defaultLocalMap
    }
    else {
        $resolvedMapSource = Resolve-WorkspacePath "游戏数据\其他mod数据\7vs1混合地图测试\Maps\ttosh02_7vs1.SC2Map"
    }
}
else {
    $resolvedMapSource = Resolve-WorkspacePath $MapSource
}

if ([string]::IsNullOrWhiteSpace($ScreenshotPath)) {
    $safeCommander = ($Commanders -join "_") -replace "[^A-Za-z0-9_]+", "_"
    $ScreenshotPath = Join-Path $artifactRoot ("tmp-smoke-{0}-{1}.png" -f ([System.IO.Path]::GetFileNameWithoutExtension($LiveMapName)), $safeCommander)
}
else {
    $ScreenshotPath = Resolve-WorkspacePath $ScreenshotPath
}

$safeMapName = ([System.IO.Path]::GetFileNameWithoutExtension($LiveMapName)) -replace "[^A-Za-z0-9_]+", "_"
$safeCommander = ($Commanders -join "_") -replace "[^A-Za-z0-9_]+", "_"
$launcherStdout = Join-Path $artifactRoot ("tmp-launch-{0}-{1}.stdout.txt" -f $safeMapName, $safeCommander)
$launcherStderr = Join-Path $artifactRoot ("tmp-launch-{0}-{1}.stderr.txt" -f $safeMapName, $safeCommander)

$tempOutputs = @($launcherStdout, $launcherStderr)
foreach ($tempOutput in $tempOutputs) {
    if (Test-Path -LiteralPath $tempOutput) {
        Remove-Item -LiteralPath $tempOutput -Force -ErrorAction SilentlyContinue
    }
}

$beforeCrashDir = Get-LatestItem -Root $logsRoot -Filter "* Crash" -Directory
$beforeScriptError = Get-LatestItem -Root $logsRoot -Filter "*ScriptError.txt"
$beforeAlerts = Get-LatestItem -Root $logsRoot -Filter "*Alerts.txt"
$beforeUi = Get-LatestItem -Root $logsRoot -Filter "*UI.txt"
$beforeGraphics = Get-LatestItem -Root $logsRoot -Filter "*Graphics.txt"
$beforeSystem = Get-LatestItem -Root $logsRoot -Filter "*SystemInfo.txt"

$launchArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $workspaceRoot "scripts\launch-7vs1-coop-test.ps1"),
    "-MapSource", $resolvedMapSource,
    "-LiveMapName", $LiveMapName,
    "-Commanders"
)
$launchArgs += $Commanders

Stop-RunningSc2
$launcher = Start-Process -FilePath "pwsh" -ArgumentList $launchArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $launcherStdout -RedirectStandardError $launcherStderr

Start-Sleep -Seconds $WaitSeconds

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
$graphics = [System.Drawing.Graphics]::FromImage($bmp)
$graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
$bmp.Save($ScreenshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bmp.Dispose()

$afterCrashDir = Get-LatestItem -Root $logsRoot -Filter "* Crash" -Directory
$afterScriptError = Get-LatestItem -Root $logsRoot -Filter "*ScriptError.txt"
$afterAlerts = Get-LatestItem -Root $logsRoot -Filter "*Alerts.txt"
$afterUi = Get-LatestItem -Root $logsRoot -Filter "*UI.txt"
$afterGraphics = Get-LatestItem -Root $logsRoot -Filter "*Graphics.txt"
$afterSystem = Get-LatestItem -Root $logsRoot -Filter "*SystemInfo.txt"

$newCrash = $false
if ($afterCrashDir) {
    $newCrash = (-not $beforeCrashDir) -or ($afterCrashDir.LastWriteTime -gt $beforeCrashDir.LastWriteTime)
}

$newScriptError = $false
if ($afterScriptError) {
    $newScriptError = (-not $beforeScriptError) -or ($afterScriptError.LastWriteTime -gt $beforeScriptError.LastWriteTime)
}

$newAlerts = $false
if ($afterAlerts) {
    $newAlerts = (-not $beforeAlerts) -or ($afterAlerts.LastWriteTime -gt $beforeAlerts.LastWriteTime)
}

$newUi = $false
if ($afterUi) {
    $newUi = (-not $beforeUi) -or ($afterUi.LastWriteTime -gt $beforeUi.LastWriteTime)
}

$newGraphics = $false
if ($afterGraphics) {
    $newGraphics = (-not $beforeGraphics) -or ($afterGraphics.LastWriteTime -gt $beforeGraphics.LastWriteTime)
}

$newSystem = $false
if ($afterSystem) {
    $newSystem = (-not $beforeSystem) -or ($afterSystem.LastWriteTime -gt $beforeSystem.LastWriteTime)
}

Write-Output ("SMOKE_COMMANDERS={0}" -f ($Commanders -join ","))
Write-Output ("SMOKE_SCREENSHOT={0}" -f $ScreenshotPath)
Write-Output ("SMOKE_LAUNCH_EXITED={0}" -f ([int]$launcher.HasExited))
if ($launcher.HasExited) {
    Write-Output ("SMOKE_LAUNCH_EXITCODE={0}" -f $launcher.ExitCode)
}
Write-Output ("SMOKE_NEW_CRASH={0}" -f ([int]$newCrash))
if ($afterCrashDir) {
    Write-Output ("SMOKE_CRASH_DIR={0}" -f $afterCrashDir.FullName)
}
Write-Output ("SMOKE_NEW_SCRIPTERROR={0}" -f ([int]$newScriptError))
if ($afterScriptError) {
    Write-Output ("SMOKE_SCRIPTERROR={0}" -f $afterScriptError.FullName)
}
Write-Output ("SMOKE_NEW_SYSTEM={0}" -f ([int]$newSystem))
if ($afterSystem) {
    Write-Output ("SMOKE_SYSTEM={0}" -f $afterSystem.FullName)
}
Write-Output ("SMOKE_NEW_GRAPHICS={0}" -f ([int]$newGraphics))
if ($afterGraphics) {
    Write-Output ("SMOKE_GRAPHICS={0}" -f $afterGraphics.FullName)
}
Write-Output ("SMOKE_NEW_UI={0}" -f ([int]$newUi))
if ($afterUi) {
    Write-Output ("SMOKE_UI={0}" -f $afterUi.FullName)
}
Write-Output ("SMOKE_NEW_ALERTS={0}" -f ([int]$newAlerts))
if ($afterAlerts) {
    Write-Output ("SMOKE_ALERTS={0}" -f $afterAlerts.FullName)
}
Write-Output ("SMOKE_LAUNCH_STDOUT={0}" -f $launcherStdout)
if (Test-Path -LiteralPath $launcherStdout) {
    Get-Content -LiteralPath $launcherStdout -Tail 80 | ForEach-Object {
        Write-Output ("LAUNCH_STDOUT> {0}" -f $_)
    }
}
Write-Output ("SMOKE_LAUNCH_STDERR={0}" -f $launcherStderr)
if (Test-Path -LiteralPath $launcherStderr) {
    Get-Content -LiteralPath $launcherStderr -Tail 80 | ForEach-Object {
        Write-Output ("LAUNCH_STDERR> {0}" -f $_)
    }
}

$suggestedStatus = "unknown"
if ($newCrash) {
    $suggestedStatus = "crash"
}
elseif ($newScriptError) {
    $suggestedStatus = "script_error"
}
elseif ($newAlerts) {
    $suggestedStatus = "ingame_or_alerted"
}
elseif ($newGraphics -or $newSystem) {
    $suggestedStatus = "login_required"
}

Write-Output ("SMOKE_SUGGESTED_STATUS={0}" -f $suggestedStatus)

Stop-RunningSc2

if (-not $launcher.HasExited) {
    try {
        Wait-Process -Id $launcher.Id -Timeout 5 -ErrorAction SilentlyContinue
    }
    catch {
    }
}
