[CmdletBinding()]
param(
    [string]$MapSource = "",
    [string]$LiveMapName = "ttosh02_7vs1.SC2Map",
    [string[]]$Commanders = @("TerranRaynor"),
    [int]$WaitSeconds = 50,
    [string]$EvidencePath = "",
    [string]$CommanderPowerProfile = "Prestige4",
    [Nullable[int]]$CommanderPowerPrestigeBonusMask = $null,
    [Nullable[int]]$CommanderPowerPrestigePointIndex = $null,
    [int]$CommanderPowerEnablePrestiges = 1,
    [int]$CommanderPowerEnableMasteries = 1,
    [int]$CommanderPowerMasteryLevel = 30,
    [Nullable[int]]$CommanderPowerMastery0 = $null,
    [Nullable[int]]$CommanderPowerMastery1 = $null,
    [Nullable[int]]$CommanderPowerMastery2 = $null,
    [Nullable[int]]$CommanderPowerMastery3 = $null,
    [Nullable[int]]$CommanderPowerMastery4 = $null,
    [Nullable[int]]$CommanderPowerMastery5 = $null,
    [string[]]$CommanderPowerOverride = @(),
    [ValidateSet("Full", "NoVisuals", "CoreOnly")]
    [string]$AbathurPatchProfile = "Full"
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

function Get-LogTimestampFromName {
    param([System.IO.FileSystemInfo]$Item)

    if (-not $Item) {
        return $null
    }

    if ($Item.Name -match '^(\d{4})-(\d{2})-(\d{2}) (\d{2})\.(\d{2})\.(\d{2}) ') {
        return [datetime]::new(
            [int]$matches[1],
            [int]$matches[2],
            [int]$matches[3],
            [int]$matches[4],
            [int]$matches[5],
            [int]$matches[6])
    }

    return $null
}

function Test-LogItemStartedAfter {
    param(
        [System.IO.FileSystemInfo]$Item,
        [datetime]$StartedAt
    )

    if (-not $Item) {
        return $false
    }

    $nameTimestamp = Get-LogTimestampFromName -Item $Item
    if ($null -ne $nameTimestamp) {
        return ($nameTimestamp -ge $StartedAt.AddSeconds(-2))
    }

    return ($Item.CreationTime -ge $StartedAt.AddSeconds(-2))
}

function Convert-ToPsSingleQuotedLiteral {
    param([string]$Value)

    return "'" + $Value.Replace("'", "''") + "'"
}

function Stop-RunningSc2 {
    $names = @("SC2_x64", "SC2Switcher_x64", "BlizzardError")
    $processes = @()
    foreach ($name in $names) {
        $processes += @(Get-Process -Name $name -ErrorAction SilentlyContinue)
    }

    foreach ($process in $processes) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }

    foreach ($process in $processes) {
        try {
            Wait-Process -Id $process.Id -Timeout 10 -ErrorAction SilentlyContinue
        }
        catch {
        }
    }

    Start-Sleep -Seconds 2
}

function Get-CampaignXCoreBankPaths {
    $paths = New-Object System.Collections.Generic.List[string]

    $liveBank = Join-Path $env:USERPROFILE "Documents\StarCraft II\Banks\CampaignXCore.SC2Bank"
    if (Test-Path -LiteralPath $liveBank) {
        $paths.Add((Resolve-Path -LiteralPath $liveBank).Path)
    }

    $accountsRoot = Join-Path $env:USERPROFILE "Documents\StarCraft II\Accounts"
    if (Test-Path -LiteralPath $accountsRoot) {
        Get-ChildItem -LiteralPath $accountsRoot -Recurse -File -Filter "CampaignXCore.SC2Bank" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\backup\\' } |
            Sort-Object LastWriteTime -Descending |
            ForEach-Object {
                if ($paths -notcontains $_.FullName) {
                    $paths.Add($_.FullName)
                }
            }
    }

    return $paths.ToArray()
}

function Remove-BankSection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$SectionName
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    $section = $xml.SelectSingleNode("/Bank/Section[@name='$SectionName']")
    if ($section) {
        [void]$section.ParentNode.RemoveChild($section)
        $xml.Save($Path)
    }
}

function Clear-RuntimeDebugBankEvidence {
    foreach ($bankPath in (Get-CampaignXCoreBankPaths)) {
        Remove-BankSection -Path $bankPath -SectionName "XMRuntimeDebug"
    }
}

function Convert-TestCommanderToRuntimeCommander {
    param([string]$Commander)

    $value = $Commander
    if ($value.StartsWith("Terran")) {
        $value = $value.Substring(6)
    }
    elseif ($value.StartsWith("Zerg")) {
        $value = $value.Substring(4)
    }
    elseif ($value.StartsWith("Protoss")) {
        $value = $value.Substring(7)
    }

    if ($value -eq "Horner") {
        return "Mira"
    }
    if ($value -eq "AbathurReborn") {
        return "AbathurReborn"
    }

    return $value
}

function Get-BankStringValue {
    param(
        [Parameter(Mandatory = $true)]
        [xml]$Xml,
        [Parameter(Mandatory = $true)]
        [string]$SectionName,
        [Parameter(Mandatory = $true)]
        [string]$KeyName
    )

    if (($null -eq $Xml) -or ($null -eq $Xml.DocumentElement)) {
        return ""
    }

    $node = $Xml.SelectSingleNode("/Bank/Section[@name='$SectionName']/Key[@name='$KeyName']/Value")
    if (-not $node) {
        return ""
    }

    return [string]$node.string
}

function Get-BankIntValue {
    param(
        [Parameter(Mandatory = $true)]
        [xml]$Xml,
        [Parameter(Mandatory = $true)]
        [string]$SectionName,
        [Parameter(Mandatory = $true)]
        [string]$KeyName
    )

    if (($null -eq $Xml) -or ($null -eq $Xml.DocumentElement)) {
        return ""
    }

    $node = $Xml.SelectSingleNode("/Bank/Section[@name='$SectionName']/Key[@name='$KeyName']/Value")
    if (-not $node) {
        return ""
    }

    return [string]$node.int
}

function Get-RuntimeDebugBankEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$StartedAt,
        [string]$RunId = ""
    )

    foreach ($bankPath in (Get-CampaignXCoreBankPaths)) {
        $item = Get-Item -LiteralPath $bankPath -ErrorAction SilentlyContinue
        if ((-not $item) -or ($item.LastWriteTime -lt $StartedAt.AddSeconds(-2))) {
            continue
        }

        $rawXml = Get-Content -LiteralPath $bankPath -Raw -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($rawXml)) {
            continue
        }

        try {
            [xml]$xml = $rawXml
        }
        catch {
            continue
        }

        if (($null -eq $xml) -or ($null -eq $xml.DocumentElement)) {
            continue
        }

        $section = $xml.SelectSingleNode("/Bank/Section[@name='XMRuntimeDebug']")
        if (-not $section) {
            continue
        }

        $evidenceRunId = Get-BankStringValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "RunId"
        if ((-not [string]::IsNullOrWhiteSpace($RunId)) -and ($evidenceRunId -ne $RunId)) {
            continue
        }

        return [pscustomobject]@{
            Path = $bankPath
            LastWriteTime = $item.LastWriteTime
            RunId = $evidenceRunId
            LastPhase = Get-BankStringValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "LastPhase"
            Commander = Get-BankStringValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "Commander"
            PrimaryCommander = Get-BankStringValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "PrimaryCommander"
            AchCommander = Get-BankStringValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "AchCommander"
            TownHallUnit = Get-BankStringValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "TownHallUnit"
            WorkerUnit = Get-BankStringValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "WorkerUnit"
            SecondUnit = Get-BankStringValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "SecondUnit"
            TownHallCount = Get-BankIntValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "TownHallCount"
            WorkerCount = Get-BankIntValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "WorkerCount"
            SecondUnitCount = Get-BankIntValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "SecondUnitCount"
        }
    }

    return $null
}

function Test-RuntimeDebugBaseEvidenceComplete {
    param([object]$Evidence)

    if (-not $Evidence) {
        return $false
    }

    if ($Evidence.LastPhase -eq "InitializeBase.exit") {
        return $true
    }

    return ((-not [string]::IsNullOrWhiteSpace($Evidence.TownHallUnit)) -and
        (-not [string]::IsNullOrWhiteSpace($Evidence.WorkerUnit)) -and
        (-not [string]::IsNullOrWhiteSpace($Evidence.TownHallCount)) -and
        (-not [string]::IsNullOrWhiteSpace($Evidence.WorkerCount)))
}

function Export-RuntimeDebugEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [object]$Evidence,
        [Parameter(Mandatory = $true)]
        [string[]]$ExpectedCommanders
    )

    $payload = [ordered]@{
        generated_at = (Get-Date).ToString("o")
        evidence_type = "sc2_bank_runtime_debug"
        expected_commanders = $ExpectedCommanders
        source_bank = $Evidence.Path
        source_bank_last_write = $Evidence.LastWriteTime.ToString("o")
        run_id = $Evidence.RunId
        last_phase = $Evidence.LastPhase
        commander = $Evidence.Commander
        primary_commander = $Evidence.PrimaryCommander
        ach_commander = $Evidence.AchCommander
        town_hall_unit = $Evidence.TownHallUnit
        worker_unit = $Evidence.WorkerUnit
        second_unit = $Evidence.SecondUnit
        town_hall_count = $Evidence.TownHallCount
        worker_count = $Evidence.WorkerCount
        second_unit_count = $Evidence.SecondUnitCount
    }

    $payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $Path -Encoding UTF8
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

if ([string]::IsNullOrWhiteSpace($EvidencePath)) {
    $safeCommander = ($Commanders -join "_") -replace "[^A-Za-z0-9_]+", "_"
    $EvidencePath = Join-Path $artifactRoot ("tmp-smoke-{0}-{1}.evidence.json" -f ([System.IO.Path]::GetFileNameWithoutExtension($LiveMapName)), $safeCommander)
}
else {
    $EvidencePath = Resolve-WorkspacePath $EvidencePath
}
$evidenceDirectory = Split-Path -Parent $EvidencePath
if (-not [string]::IsNullOrWhiteSpace($evidenceDirectory)) {
    $null = New-Item -ItemType Directory -Path $evidenceDirectory -Force
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
Clear-RuntimeDebugBankEvidence
$runStartedAt = Get-Date
$runId = "{0:N}" -f ([guid]::NewGuid())

$quotedLaunchPath = Convert-ToPsSingleQuotedLiteral (Join-Path $workspaceRoot "scripts\launch-7vs1-coop-test.ps1")
$quotedMapSource = Convert-ToPsSingleQuotedLiteral $resolvedMapSource
$quotedLiveMapName = Convert-ToPsSingleQuotedLiteral $LiveMapName
$quotedAbathurPatchProfile = Convert-ToPsSingleQuotedLiteral $AbathurPatchProfile
$quotedCommanderPowerProfile = Convert-ToPsSingleQuotedLiteral $CommanderPowerProfile
$quotedCommanders = @($Commanders | ForEach-Object { Convert-ToPsSingleQuotedLiteral $_ })
$launchCommand = "& $quotedLaunchPath -MapSource $quotedMapSource -LiveMapName $quotedLiveMapName -AbathurPatchProfile $quotedAbathurPatchProfile -Commanders @(" + ($quotedCommanders -join ",") + ")"
$launchCommand += " -TestRunId " + (Convert-ToPsSingleQuotedLiteral $runId)
$launchCommand += " -CommanderPowerProfile $quotedCommanderPowerProfile"
if ($null -ne $CommanderPowerPrestigeBonusMask) {
    $launchCommand += " -CommanderPowerPrestigeBonusMask $CommanderPowerPrestigeBonusMask"
}
if ($null -ne $CommanderPowerPrestigePointIndex) {
    $launchCommand += " -CommanderPowerPrestigePointIndex $CommanderPowerPrestigePointIndex"
}
$launchCommand += " -CommanderPowerEnablePrestiges $CommanderPowerEnablePrestiges"
$launchCommand += " -CommanderPowerEnableMasteries $CommanderPowerEnableMasteries"
$launchCommand += " -CommanderPowerMasteryLevel $CommanderPowerMasteryLevel"
if ($null -ne $CommanderPowerMastery0) {
    $launchCommand += " -CommanderPowerMastery0 $CommanderPowerMastery0"
}
if ($null -ne $CommanderPowerMastery1) {
    $launchCommand += " -CommanderPowerMastery1 $CommanderPowerMastery1"
}
if ($null -ne $CommanderPowerMastery2) {
    $launchCommand += " -CommanderPowerMastery2 $CommanderPowerMastery2"
}
if ($null -ne $CommanderPowerMastery3) {
    $launchCommand += " -CommanderPowerMastery3 $CommanderPowerMastery3"
}
if ($null -ne $CommanderPowerMastery4) {
    $launchCommand += " -CommanderPowerMastery4 $CommanderPowerMastery4"
}
if ($null -ne $CommanderPowerMastery5) {
    $launchCommand += " -CommanderPowerMastery5 $CommanderPowerMastery5"
}
foreach ($overrideEntry in $CommanderPowerOverride) {
    $launchCommand += " -CommanderPowerOverride " + (Convert-ToPsSingleQuotedLiteral $overrideEntry)
}
$launchArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-Command", $launchCommand
)

Stop-RunningSc2
$launcher = Start-Process -FilePath "pwsh" -ArgumentList $launchArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $launcherStdout -RedirectStandardError $launcherStderr

$runtimeEvidence = $null
$latestRuntimeEvidence = $null
$deadline = (Get-Date).AddSeconds($WaitSeconds)
while ((Get-Date) -lt $deadline) {
    $latestRuntimeEvidence = Get-RuntimeDebugBankEvidence -StartedAt $runStartedAt -RunId $runId
    if (Test-RuntimeDebugBaseEvidenceComplete -Evidence $latestRuntimeEvidence) {
        $runtimeEvidence = $latestRuntimeEvidence
        break
    }

    Start-Sleep -Seconds 2
}

if ((-not $runtimeEvidence) -and $latestRuntimeEvidence) {
    $runtimeEvidence = $latestRuntimeEvidence
}

if ($runtimeEvidence) {
    Export-RuntimeDebugEvidence -Path $EvidencePath -Evidence $runtimeEvidence -ExpectedCommanders $Commanders
}

Stop-RunningSc2

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
    $newScriptError = ((-not $beforeScriptError) -or ($afterScriptError.FullName -ne $beforeScriptError.FullName) -or ($afterScriptError.LastWriteTime -gt $beforeScriptError.LastWriteTime)) -and
        (Test-LogItemStartedAfter -Item $afterScriptError -StartedAt $runStartedAt)
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
Write-Output ("SMOKE_EVIDENCE={0}" -f $EvidencePath)
Write-Output "SMOKE_EVIDENCE_MODE=sc2_bank_runtime_debug"
Write-Output ("SMOKE_RUN_ID={0}" -f $runId)
$expectedRuntimeCommanders = @($Commanders | ForEach-Object { Convert-TestCommanderToRuntimeCommander -Commander $_ })
$bankMatch = $false
if ($runtimeEvidence) {
    $bankMatch = @($expectedRuntimeCommanders).Contains($runtimeEvidence.Commander)
    Write-Output ("SMOKE_BANK_SOURCE={0}" -f $runtimeEvidence.Path)
    Write-Output ("SMOKE_BANK_RUN_ID={0}" -f $runtimeEvidence.RunId)
    Write-Output ("SMOKE_BANK_LASTPHASE={0}" -f $runtimeEvidence.LastPhase)
    Write-Output ("SMOKE_BANK_COMMANDER={0}" -f $runtimeEvidence.Commander)
    Write-Output ("SMOKE_BANK_EXPECTED_COMMANDERS={0}" -f ($expectedRuntimeCommanders -join ","))
    Write-Output ("SMOKE_BANK_PRIMARY_COMMANDER={0}" -f $runtimeEvidence.PrimaryCommander)
    Write-Output ("SMOKE_BANK_ACH_COMMANDER={0}" -f $runtimeEvidence.AchCommander)
    Write-Output ("SMOKE_BANK_TOWNHALL_UNIT={0}" -f $runtimeEvidence.TownHallUnit)
    Write-Output ("SMOKE_BANK_WORKER_UNIT={0}" -f $runtimeEvidence.WorkerUnit)
    Write-Output ("SMOKE_BANK_SECOND_UNIT={0}" -f $runtimeEvidence.SecondUnit)
    Write-Output ("SMOKE_BANK_TOWNHALL_COUNT={0}" -f $runtimeEvidence.TownHallCount)
    Write-Output ("SMOKE_BANK_WORKER_COUNT={0}" -f $runtimeEvidence.WorkerCount)
    Write-Output ("SMOKE_BANK_SECOND_UNIT_COUNT={0}" -f $runtimeEvidence.SecondUnitCount)
}
Write-Output ("SMOKE_BANK_EVIDENCE={0}" -f ([int]($null -ne $runtimeEvidence)))
Write-Output ("SMOKE_BANK_MATCH={0}" -f ([int]$bankMatch))
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
elseif (-not $runtimeEvidence) {
    $suggestedStatus = "no_runtime_bank_evidence"
}
elseif (-not (Test-RuntimeDebugBaseEvidenceComplete -Evidence $runtimeEvidence)) {
    $suggestedStatus = "no_runtime_base_evidence"
}
elseif (-not $bankMatch) {
    $suggestedStatus = "commander_mismatch"
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
