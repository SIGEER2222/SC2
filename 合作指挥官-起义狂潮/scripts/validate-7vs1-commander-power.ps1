[CmdletBinding()]
param(
    [string]$SourceRoot = "",
    [string]$MapSource = "",
    [string]$LiveMapName = "ttosh02_7vs1.SC2Map",
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$CommanderPowerProfile = "Prestige4",
    [string[]]$Commanders = @(),
    [Alias("IncludePrestigeMaskMatrix")]
    [switch]$IncludePrestigeBonusMaskMatrix,
    [switch]$IncludeMasteryOverrideSmoke,
    [int]$LaunchRetryCount = 2,
    [int]$LaunchRetryDelaySeconds = 2,
    [switch]$StopOnFailure
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "commander-power-metadata.ps1")

function Get-WorkspaceRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Resolve-DefaultMapSource {
    return (Join-Path (Get-WorkspaceRoot) "Maps\ttosh02_7vs1.SC2Map")
}

function Resolve-DefaultSourceRoot {
    $workspaceRoot = Get-WorkspaceRoot
    $candidates = @(
        "E:\Code\MyMod\SC2\_codex_7vs1_source_root",
        (Join-Path $workspaceRoot "游戏数据\其他mod数据\7vs1母巢之战合作指挥官bate版_SC2Replay_94137"),
        "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\游戏数据\其他mod数据\7vs1母巢之战合作指挥官bate版_SC2Replay_94137"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return ""
}

function Get-LaunchScriptPath {
    return (Join-Path $PSScriptRoot "launch-7vs1-coop-test.ps1")
}

function Get-CommanderSpecs {
    return @(Get-CommanderPowerCommanderSpecs -WorkspaceRoot (Get-WorkspaceRoot) | ForEach-Object {
            @{
                Runtime = $_.Runtime
                Bank = $_.Bank
            }
        })
}

function Get-TargetCommanderSpecs {
    param(
        [object[]]$Specs,
        [string[]]$Requested
    )

    if ($Requested.Count -eq 0) {
        return $Specs
    }

    $requestedSet = @{}
    foreach ($name in $Requested) {
        $requestedSet[$name] = $true
    }

    return @($Specs | Where-Object {
        $requestedSet.ContainsKey($_.Runtime) -or $requestedSet.ContainsKey($_.Bank)
    })
}

function Get-CampaignXCoreBankPaths {
    $paths = New-Object System.Collections.Generic.List[string]

    $liveBank = Join-Path $env:USERPROFILE "Documents\StarCraft II\Banks\CampaignXCore.SC2Bank"
    if (Test-Path -LiteralPath $liveBank) {
        $paths.Add((Resolve-Path -LiteralPath $liveBank).Path)
    }

    $accountsRoot = Join-Path $env:USERPROFILE "Documents\StarCraft II\Accounts"
    if (Test-Path -LiteralPath $accountsRoot) {
        Get-ChildItem -LiteralPath $accountsRoot -Recurse -File -Filter "CampaignXCore.SC2Bank" |
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

function Get-BankKeyNode {
    param(
        [xml]$Xml,
        [string]$SectionName,
        [string]$KeyName
    )

    return $Xml.SelectSingleNode("/Bank/Section[@name='$SectionName']/Key[@name='$KeyName']/Value")
}

function Get-BankIntValue {
    param(
        [xml]$Xml,
        [string]$SectionName,
        [string]$KeyName
    )

    $node = Get-BankKeyNode -Xml $Xml -SectionName $SectionName -KeyName $KeyName
    if (-not $node) {
        return $null
    }

    if ($node.Attributes["int"]) {
        return [int]$node.Attributes["int"].Value
    }

    return $null
}

function Get-BankStringValue {
    param(
        [xml]$Xml,
        [string]$SectionName,
        [string]$KeyName
    )

    $node = Get-BankKeyNode -Xml $Xml -SectionName $SectionName -KeyName $KeyName
    if (-not $node) {
        return $null
    }

    if ($node.Attributes["string"]) {
        return [string]$node.Attributes["string"].Value
    }

    return $null
}

function Add-CheckFailure {
    param(
        [System.Collections.Generic.List[string]]$Failures,
        [string]$Message
    )

    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        $Failures.Add($Message) | Out-Null
    }
}

function Test-BankScenario {
    param(
        [string]$BankPath,
        [string]$CommanderBankKey,
        [hashtable]$Scenario
    )

    [xml]$xml = Get-Content -LiteralPath $BankPath -Raw
    $failures = New-Object System.Collections.Generic.List[string]

    $achCommander = Get-BankStringValue -Xml $xml -SectionName "Ach" -KeyName "Commander"
    if ($achCommander -ne $CommanderBankKey) {
        Add-CheckFailure -Failures $failures -Message ("Ach/Commander expected={0} actual={1}" -f $CommanderBankKey, $achCommander)
    }

    $profile = Get-BankStringValue -Xml $xml -SectionName "CommanderPower" -KeyName ("{0}.Profile" -f $CommanderBankKey)
    if ($profile -ne $Scenario.Profile) {
        Add-CheckFailure -Failures $failures -Message ("Profile expected={0} actual={1}" -f $Scenario.Profile, $profile)
    }

    $enablePrestiges = Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName ("{0}.EnablePrestiges" -f $CommanderBankKey)
    if ($enablePrestiges -ne $Scenario.EnablePrestiges) {
        Add-CheckFailure -Failures $failures -Message ("EnablePrestiges expected={0} actual={1}" -f $Scenario.EnablePrestiges, $enablePrestiges)
    }

    $enableMasteries = Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName ("{0}.EnableMasteries" -f $CommanderBankKey)
    if ($enableMasteries -ne $Scenario.EnableMasteries) {
        Add-CheckFailure -Failures $failures -Message ("EnableMasteries expected={0} actual={1}" -f $Scenario.EnableMasteries, $enableMasteries)
    }

    $prestigePointIndex = Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName ("{0}.PrestigePointIndex" -f $CommanderBankKey)
    if ($prestigePointIndex -ne $Scenario.PrestigePointIndex) {
        Add-CheckFailure -Failures $failures -Message ("PrestigePointIndex expected={0} actual={1}" -f $Scenario.PrestigePointIndex, $prestigePointIndex)
    }

    $prestigeIndex = Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName ("{0}.PrestigeIndex" -f $CommanderBankKey)
    if ($prestigeIndex -ne $Scenario.PrestigePointIndex) {
        Add-CheckFailure -Failures $failures -Message ("PrestigeIndex expected={0} actual={1}" -f $Scenario.PrestigePointIndex, $prestigeIndex)
    }

    $prestigeBonusMask = Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName ("{0}.PrestigeBonusMask" -f $CommanderBankKey)
    if ($prestigeBonusMask -ne $Scenario.PrestigeBonusMask) {
        Add-CheckFailure -Failures $failures -Message ("PrestigeBonusMask expected={0} actual={1}" -f $Scenario.PrestigeBonusMask, $prestigeBonusMask)
    }

    $prestigeMask = Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName ("{0}.PrestigeMask" -f $CommanderBankKey)
    if ($prestigeMask -ne $Scenario.PrestigeBonusMask) {
        Add-CheckFailure -Failures $failures -Message ("PrestigeMask expected={0} actual={1}" -f $Scenario.PrestigeBonusMask, $prestigeMask)
    }

    $masteryDefault = Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName ("{0}.MasteryDefault" -f $CommanderBankKey)
    if ($masteryDefault -ne $Scenario.MasteryDefault) {
        Add-CheckFailure -Failures $failures -Message ("MasteryDefault expected={0} actual={1}" -f $Scenario.MasteryDefault, $masteryDefault)
    }

    for ($masteryIndex = 0; $masteryIndex -le 5; $masteryIndex++) {
        $keyName = ("{0}.Mastery{1}" -f $CommanderBankKey, $masteryIndex)
        $actualValue = Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName $keyName
        $expectedValue = $Scenario.MasteryValues[$masteryIndex]
        if ($actualValue -ne $expectedValue) {
            Add-CheckFailure -Failures $failures -Message ("{0} expected={1} actual={2}" -f $keyName, $expectedValue, $actualValue)
        }
    }

    return $failures.ToArray()
}

function Invoke-LaunchPreset {
    param(
        [string]$LaunchScriptPath,
        [string]$CommanderRuntime,
        [hashtable]$Scenario,
        [string]$SourceRoot,
        [string]$MapSource,
        [string]$LiveMapName,
        [string]$Sc2Root
    )

    $argumentList = New-Object System.Collections.Generic.List[string]
    $argumentList.Add("-NoProfile") | Out-Null
    $argumentList.Add("-ExecutionPolicy") | Out-Null
    $argumentList.Add("Bypass") | Out-Null
    $argumentList.Add("-File") | Out-Null
    $argumentList.Add($LaunchScriptPath) | Out-Null
    $argumentList.Add("-NoLaunch") | Out-Null
    $argumentList.Add("-ForceStopSc2BeforeInstall") | Out-Null
    $argumentList.Add("-MapSource") | Out-Null
    $argumentList.Add($MapSource) | Out-Null
    $argumentList.Add("-LiveMapName") | Out-Null
    $argumentList.Add($LiveMapName) | Out-Null
    $argumentList.Add("-Sc2Root") | Out-Null
    $argumentList.Add($Sc2Root) | Out-Null
    $argumentList.Add("-Commanders") | Out-Null
    $argumentList.Add($CommanderRuntime) | Out-Null
    $argumentList.Add("-CommanderPowerProfile") | Out-Null
    $argumentList.Add($Scenario.Profile) | Out-Null
    $argumentList.Add("-CommanderPowerPrestigeBonusMask") | Out-Null
    $argumentList.Add([string]$Scenario.PrestigeBonusMask) | Out-Null
    $argumentList.Add("-CommanderPowerEnablePrestiges") | Out-Null
    $argumentList.Add([string]$Scenario.EnablePrestiges) | Out-Null
    $argumentList.Add("-CommanderPowerEnableMasteries") | Out-Null
    $argumentList.Add([string]$Scenario.EnableMasteries) | Out-Null
    $argumentList.Add("-CommanderPowerMasteryLevel") | Out-Null
    $argumentList.Add([string]$Scenario.MasteryDefault) | Out-Null

    if (-not [string]::IsNullOrWhiteSpace($SourceRoot)) {
        $argumentList.Add("-SourceRoot") | Out-Null
        $argumentList.Add($SourceRoot) | Out-Null
    }

    if ($null -ne $Scenario.PrestigePointIndex) {
        $argumentList.Add("-CommanderPowerPrestigePointIndex") | Out-Null
        $argumentList.Add([string]$Scenario.PrestigePointIndex) | Out-Null
    }

    for ($masteryIndex = 0; $masteryIndex -le 5; $masteryIndex++) {
        $overrideKey = ("Mastery{0}" -f $masteryIndex)
        if ($Scenario.ContainsKey($overrideKey)) {
            $argumentList.Add(("-CommanderPowerMastery{0}" -f $masteryIndex)) | Out-Null
            $argumentList.Add([string]$Scenario[$overrideKey]) | Out-Null
        }
    }

    $exitCode = 0
    $launchOutput = @()
    try {
        $launchOutput = @(& powershell @($argumentList.ToArray()) 2>&1 | ForEach-Object { [string]$_ })
        $exitCode = if ($LASTEXITCODE -is [int]) { [int]$LASTEXITCODE } else { 0 }
    }
    catch {
        $exitCode = 1
        $launchOutput = @($launchOutput + @([string]$_.Exception.Message))
    }

    return [pscustomobject]@{
        ExitCode = [int]$exitCode
        Output = @($launchOutput)
    }
}

function Invoke-LaunchPresetWithRetry {
    param(
        [string]$LaunchScriptPath,
        [string]$CommanderRuntime,
        [hashtable]$Scenario,
        [string]$SourceRoot,
        [string]$MapSource,
        [string]$LiveMapName,
        [string]$Sc2Root,
        [int]$RetryCount,
        [int]$RetryDelaySeconds
    )

    $attempt = 0
    $result = $null
    $maxAttempts = [Math]::Max(1, $RetryCount)

    while ($attempt -lt $maxAttempts) {
        $attempt += 1
        $result = Invoke-LaunchPreset `
            -LaunchScriptPath $LaunchScriptPath `
            -CommanderRuntime $CommanderRuntime `
            -Scenario $Scenario `
            -SourceRoot $SourceRoot `
            -MapSource $MapSource `
            -LiveMapName $LiveMapName `
            -Sc2Root $Sc2Root

        if ($result.ExitCode -eq 0) {
            break
        }

        if ($attempt -lt $maxAttempts) {
            Start-Sleep -Seconds ([Math]::Max(0, $RetryDelaySeconds))
        }
    }

    return [pscustomobject]@{
        Attempts = $attempt
        ExitCode = [int]$result.ExitCode
        Output = @($result.Output)
    }
}

$workspaceRoot = Get-WorkspaceRoot
$launchScriptPath = Get-LaunchScriptPath
if (-not (Test-Path -LiteralPath $launchScriptPath)) {
    throw "Launch script not found: $launchScriptPath"
}

$metadata = Get-CommanderPowerMetadata -WorkspaceRoot $workspaceRoot
$defaultPrestigeBonusMaskByRuntime = @{}
foreach ($commander in @($metadata.commanders)) {
    $runtime = [string]$commander.runtime_commander
    if ([string]::IsNullOrWhiteSpace($runtime)) {
        continue
    }

    $defaultPrestigeBonusMaskByRuntime[$runtime] = Get-CommanderPowerDefaultPrestigeBonusMask -Commander $runtime -WorkspaceRoot $workspaceRoot
}

if ([string]::IsNullOrWhiteSpace($MapSource)) {
    $MapSource = Resolve-DefaultMapSource
}
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Resolve-DefaultSourceRoot
}

$logsRoot = Join-Path $workspaceRoot "logs"
if (-not (Test-Path -LiteralPath $logsRoot)) {
    New-Item -ItemType Directory -Path $logsRoot -Force | Out-Null
}

$allSpecs = Get-CommanderSpecs
$targetSpecs = Get-TargetCommanderSpecs -Specs $allSpecs -Requested $Commanders
if ($targetSpecs.Count -eq 0) {
    throw "No matching commanders selected."
}

$scenarios = New-Object System.Collections.Generic.List[hashtable]
$scenarios.Add(@{
    Name = "full_fusion"
    Profile = $CommanderPowerProfile
    EnablePrestiges = 1
    EnableMasteries = 1
    PrestigePointIndex = -1
    PrestigeBonusMask = 7
    MasteryDefault = 30
    MasteryValues = @(30, 30, 30, 30, 30, 30)
}) | Out-Null
$scenarios.Add(@{
    Name = "prestiges_off"
    Profile = $CommanderPowerProfile
    EnablePrestiges = 0
    EnableMasteries = 1
    PrestigePointIndex = -1
    PrestigeBonusMask = 7
    MasteryDefault = 30
    MasteryValues = @(30, 30, 30, 30, 30, 30)
}) | Out-Null
$scenarios.Add(@{
    Name = "masteries_off"
    Profile = $CommanderPowerProfile
    EnablePrestiges = 1
    EnableMasteries = 0
    PrestigePointIndex = -1
    PrestigeBonusMask = 7
    MasteryDefault = 30
    MasteryValues = @(30, 30, 30, 30, 30, 30)
}) | Out-Null

if ($IncludeMasteryOverrideSmoke) {
    $scenarios.Add(@{
        Name = "mastery_override_smoke"
        Profile = $CommanderPowerProfile
        EnablePrestiges = 1
        EnableMasteries = 1
        PrestigePointIndex = -1
        PrestigeBonusMask = 7
        MasteryDefault = 30
        Mastery0 = 0
        Mastery1 = 3
        Mastery2 = 6
        Mastery3 = 9
        Mastery4 = 12
        Mastery5 = 15
        MasteryValues = @(0, 3, 6, 9, 12, 15)
    }) | Out-Null
}

if ($IncludePrestigeBonusMaskMatrix) {
    $scenarios.Add(@{
        Name = "prestige_bonus_mask_bit1_override"
        Profile = $CommanderPowerProfile
        EnablePrestiges = 1
        EnableMasteries = 1
        PrestigePointIndex = 3
        PrestigeBonusMask = 1
        MasteryDefault = 30
        MasteryValues = @(30, 30, 30, 30, 30, 30)
    }) | Out-Null
    $scenarios.Add(@{
        Name = "prestige_bonus_mask_bit2_override"
        Profile = $CommanderPowerProfile
        EnablePrestiges = 1
        EnableMasteries = 1
        PrestigePointIndex = 1
        PrestigeBonusMask = 2
        MasteryDefault = 30
        MasteryValues = @(30, 30, 30, 30, 30, 30)
    }) | Out-Null
    $scenarios.Add(@{
        Name = "prestige_bonus_mask_bit3_override"
        Profile = $CommanderPowerProfile
        EnablePrestiges = 1
        EnableMasteries = 1
        PrestigePointIndex = 2
        PrestigeBonusMask = 4
        MasteryDefault = 30
        MasteryValues = @(30, 30, 30, 30, 30, 30)
    }) | Out-Null
    $scenarios.Add(@{
        Name = "prestige_bonus_mask_mix12_override"
        Profile = $CommanderPowerProfile
        EnablePrestiges = 1
        EnableMasteries = 1
        PrestigePointIndex = 3
        PrestigeBonusMask = 3
        MasteryDefault = 30
        MasteryValues = @(30, 30, 30, 30, 30, 30)
    }) | Out-Null
    $scenarios.Add(@{
        Name = "prestige_bonus_mask_mix13_override"
        Profile = $CommanderPowerProfile
        EnablePrestiges = 1
        EnableMasteries = 1
        PrestigePointIndex = 2
        PrestigeBonusMask = 5
        MasteryDefault = 30
        MasteryValues = @(30, 30, 30, 30, 30, 30)
    }) | Out-Null
    $scenarios.Add(@{
        Name = "prestige_bonus_mask_mix23_override"
        Profile = $CommanderPowerProfile
        EnablePrestiges = 1
        EnableMasteries = 1
        PrestigePointIndex = 1
        PrestigeBonusMask = 6
        MasteryDefault = 30
        MasteryValues = @(30, 30, 30, 30, 30, 30)
    }) | Out-Null
}

$results = New-Object System.Collections.Generic.List[object]
$bankPaths = @(Get-CampaignXCoreBankPaths)
if ($bankPaths.Count -eq 0) {
    throw "No CampaignXCore.SC2Bank files found."
}

foreach ($spec in $targetSpecs) {
    $defaultPrestigeBonusMask = 7
    if ($defaultPrestigeBonusMaskByRuntime.ContainsKey($spec.Runtime)) {
        $defaultPrestigeBonusMask = [int]$defaultPrestigeBonusMaskByRuntime[$spec.Runtime]
    }

    foreach ($scenario in $scenarios) {
        $effectiveScenario = [ordered]@{}
        foreach ($key in $scenario.Keys) {
            $effectiveScenario[$key] = $scenario[$key]
        }
        if ($scenario.Name -in @("full_fusion", "prestiges_off", "masteries_off", "mastery_override_smoke")) {
            $effectiveScenario.PrestigeBonusMask = $defaultPrestigeBonusMask
        }

        Write-Host ("VALIDATE commander={0} scenario={1}" -f $spec.Runtime, $effectiveScenario.Name)
        $launchResult = Invoke-LaunchPresetWithRetry `
            -LaunchScriptPath $launchScriptPath `
            -CommanderRuntime $spec.Runtime `
            -Scenario $effectiveScenario `
            -SourceRoot $SourceRoot `
            -MapSource $MapSource `
            -LiveMapName $LiveMapName `
            -Sc2Root $Sc2Root `
            -RetryCount $LaunchRetryCount `
            -RetryDelaySeconds $LaunchRetryDelaySeconds

        $scenarioFailures = New-Object System.Collections.Generic.List[string]
        if ($launchResult.ExitCode -ne 0) {
            $launchText = ($launchResult.Output -join " || ").Trim()
            if ([string]::IsNullOrWhiteSpace($launchText)) {
                $launchText = "(no stderr/stdout captured)"
            }
            $scenarioFailures.Add(("launch failed attempts={0} exit={1} output={2}" -f $launchResult.Attempts, $launchResult.ExitCode, $launchText)) | Out-Null
        }
        else {
            foreach ($bankPath in $bankPaths) {
                $bankFailures = @(Test-BankScenario -BankPath $bankPath -CommanderBankKey $spec.Bank -Scenario $effectiveScenario)
                foreach ($failure in $bankFailures) {
                    $scenarioFailures.Add(("{0} :: {1}" -f $bankPath, $failure)) | Out-Null
                }
            }
        }

        $status = if ($scenarioFailures.Count -eq 0) { "PASS" } else { "FAIL" }
        $results.Add([pscustomobject]@{
            CommanderRuntime = $spec.Runtime
            CommanderBank = $spec.Bank
            Scenario = $scenario.Name
            Status = $status
            FailureCount = $scenarioFailures.Count
            Failures = ($scenarioFailures -join " || ")
        }) | Out-Null

        if (($scenarioFailures.Count -gt 0) -and $StopOnFailure) {
            break
        }
    }

    if ($StopOnFailure -and ($results | Where-Object { ($_.CommanderRuntime -eq $spec.Runtime) -and ($_.Status -eq "FAIL") })) {
        break
    }
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportJsonPath = Join-Path $logsRoot ("validate-7vs1-commander-power-" + $timestamp + ".json")
$reportTxtPath = Join-Path $logsRoot ("validate-7vs1-commander-power-" + $timestamp + ".txt")

$results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportJsonPath -Encoding UTF8
$results |
    Select-Object CommanderRuntime, CommanderBank, Scenario, Status, FailureCount, Failures |
    Format-Table -AutoSize | Out-String -Width 4096 |
    Set-Content -LiteralPath $reportTxtPath -Encoding UTF8

$failCount = @($results | Where-Object { $_.Status -eq "FAIL" }).Count
$passCount = @($results | Where-Object { $_.Status -eq "PASS" }).Count

Write-Host ("VALIDATION_REPORT_JSON={0}" -f $reportJsonPath)
Write-Host ("VALIDATION_REPORT_TXT={0}" -f $reportTxtPath)
Write-Host ("VALIDATION_SUMMARY pass={0} fail={1} scenarios={2}" -f $passCount, $failCount, $results.Count)

if ($failCount -gt 0) {
    exit 1
}
