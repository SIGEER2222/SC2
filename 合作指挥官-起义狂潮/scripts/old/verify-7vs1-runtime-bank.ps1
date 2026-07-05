[CmdletBinding()]
param(
    [string]$BankPath = "C:\Users\22448\Documents\StarCraft II\Banks\CampaignXCore.SC2Bank",
    [string]$ExpectedCommander = "",
    [string]$ExpectedRunId = "",
    [string]$ExpectedMapId = "",
    [string]$ExpectedTownHall = "",
    [string]$ExpectedWorker = "",
    [string]$ExpectedSecondUnit = "",
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"

function Get-BankKeyValue {
    param(
        [Parameter(Mandatory = $true)]
        [xml]$Xml,
        [Parameter(Mandatory = $true)]
        [string]$SectionName,
        [Parameter(Mandatory = $true)]
        [string]$KeyName
    )

    $node = $Xml.SelectSingleNode("/Bank/Section[@name='$SectionName']/Key[@name='$KeyName']/Value")
    if (-not $node) {
        return $null
    }

    if ($node.HasAttribute("string")) {
        return [string]$node.GetAttribute("string")
    }
    if ($node.HasAttribute("int")) {
        return [string]$node.GetAttribute("int")
    }

    return $null
}

if (-not (Test-Path -LiteralPath $BankPath)) {
    throw "Bank file not found: $BankPath"
}

[xml]$xml = Get-Content -LiteralPath $BankPath -Raw

$result = [ordered]@{
    bank_path = $BankPath
    bank_last_write = (Get-Item -LiteralPath $BankPath).LastWriteTime.ToString("o")
    runtime_control = [ordered]@{
        test_run_id = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeControl" -KeyName "TestRunId"
        primary_commander = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeControl" -KeyName "PrimaryCommander"
        commander_p1 = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeControl" -KeyName "CommanderP1"
    }
    ach = [ordered]@{
        commander = Get-BankKeyValue -Xml $xml -SectionName "Ach" -KeyName "Commander"
    }
    runtime_debug = [ordered]@{
        run_id = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "RunId"
        commander = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "Commander"
        primary_commander = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "PrimaryCommander"
        ach_commander = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "AchCommander"
        last_phase = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "LastPhase"
        town_hall_unit = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "TownHallUnit"
        worker_unit = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "WorkerUnit"
        second_unit = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "SecondUnit"
        town_hall_count = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "TownHallCount"
        worker_count = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "WorkerCount"
        second_unit_count = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "SecondUnitCount"
        train_hydra_allowed = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "KerriganTrainHydraAllowed"
        train_muta_allowed = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "KerriganTrainMutaAllowed"
        train_ultra_allowed = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "KerriganTrainUltraAllowed"
        command_center_trace_unit = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "CommanderAchTrace_CommandCenter_Unit"
        worker_trace_unit = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "CommanderAchTrace_Worker_Unit"
        second_unit_trace_unit = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeDebug" -KeyName "CommanderAchTrace_SecondUnit_Unit"
    }
    runtime_visual_probe = [ordered]@{
        run_id = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeVisualProbe" -KeyName "RunId"
        commander = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeVisualProbe" -KeyName "Commander"
        last_source = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeVisualProbe" -KeyName "LastSource"
        kerrigan_town_hall = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeVisualProbe" -KeyName "KerriganTownHall_ValueA"
        kerrigan_town_hall_private = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeVisualProbe" -KeyName "KerriganTownHall_ValueB"
        kerrigan_larva = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeVisualProbe" -KeyName "KerriganLarva_ValueA"
        kerrigan_larva_private = Get-BankKeyValue -Xml $xml -SectionName "XMRuntimeVisualProbe" -KeyName "KerriganLarva_ValueB"
    }
}

$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param(
        [string]$Name,
        [string]$Expected,
        [string]$Actual
    )

    $passed = ($Expected -eq $Actual)
    $checks.Add([ordered]@{
        name = $Name
        passed = $passed
        expected = $Expected
        actual = $Actual
    })
}

if ($ExpectedCommander) {
    Add-Check -Name "runtime_control.primary_commander" -Expected $ExpectedCommander -Actual $result.runtime_control.primary_commander
    Add-Check -Name "runtime_debug.commander" -Expected $ExpectedCommander -Actual $result.runtime_debug.commander
    Add-Check -Name "ach.commander" -Expected $ExpectedCommander -Actual $result.ach.commander
}
if ($ExpectedRunId) {
    Add-Check -Name "runtime_control.test_run_id" -Expected $ExpectedRunId -Actual $result.runtime_control.test_run_id
    Add-Check -Name "runtime_debug.run_id" -Expected $ExpectedRunId -Actual $result.runtime_debug.run_id
}
if ($ExpectedMapId) {
    Add-Check -Name "runtime_visual_probe.commander" -Expected $ExpectedCommander -Actual $result.runtime_visual_probe.commander
}
if ($ExpectedTownHall) {
    Add-Check -Name "runtime_debug.town_hall_unit" -Expected $ExpectedTownHall -Actual $result.runtime_debug.town_hall_unit
}
if ($ExpectedWorker) {
    Add-Check -Name "runtime_debug.worker_unit" -Expected $ExpectedWorker -Actual $result.runtime_debug.worker_unit
}
if ($ExpectedSecondUnit) {
    Add-Check -Name "runtime_debug.second_unit" -Expected $ExpectedSecondUnit -Actual $result.runtime_debug.second_unit
}

$result["checks"] = @($checks)
$result["passed"] = (@($checks | Where-Object { -not $_.passed }).Count -eq 0)

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
    exit 0
}

Write-Output ("BANK_PATH={0}" -f $result.bank_path)
Write-Output ("BANK_LAST_WRITE={0}" -f $result.bank_last_write)
Write-Output ("RUNTIME_CONTROL_TEST_RUN_ID={0}" -f $result.runtime_control.test_run_id)
Write-Output ("RUNTIME_CONTROL_PRIMARY_COMMANDER={0}" -f $result.runtime_control.primary_commander)
Write-Output ("ACH_COMMANDER={0}" -f $result.ach.commander)
Write-Output ("RUNTIME_DEBUG_COMMANDER={0}" -f $result.runtime_debug.commander)
Write-Output ("RUNTIME_DEBUG_LAST_PHASE={0}" -f $result.runtime_debug.last_phase)
Write-Output ("RUNTIME_DEBUG_TOWN_HALL_UNIT={0}" -f $result.runtime_debug.town_hall_unit)
Write-Output ("RUNTIME_DEBUG_WORKER_UNIT={0}" -f $result.runtime_debug.worker_unit)
Write-Output ("RUNTIME_DEBUG_SECOND_UNIT={0}" -f $result.runtime_debug.second_unit)
Write-Output ("RUNTIME_DEBUG_TOWN_HALL_COUNT={0}" -f $result.runtime_debug.town_hall_count)
Write-Output ("RUNTIME_DEBUG_WORKER_COUNT={0}" -f $result.runtime_debug.worker_count)
Write-Output ("RUNTIME_DEBUG_SECOND_UNIT_COUNT={0}" -f $result.runtime_debug.second_unit_count)
Write-Output ("KERRIGAN_TRAIN_HYDRA_ALLOWED={0}" -f $result.runtime_debug.train_hydra_allowed)
Write-Output ("KERRIGAN_TRAIN_MUTA_ALLOWED={0}" -f $result.runtime_debug.train_muta_allowed)
Write-Output ("KERRIGAN_TRAIN_ULTRA_ALLOWED={0}" -f $result.runtime_debug.train_ultra_allowed)
Write-Output ("RUNTIME_VISUAL_LAST_SOURCE={0}" -f $result.runtime_visual_probe.last_source)
Write-Output ("RUNTIME_VISUAL_KERRIGAN_TOWN_HALL={0}" -f $result.runtime_visual_probe.kerrigan_town_hall)
Write-Output ("RUNTIME_VISUAL_KERRIGAN_TOWN_HALL_PRIVATE={0}" -f $result.runtime_visual_probe.kerrigan_town_hall_private)
Write-Output ("RUNTIME_VISUAL_KERRIGAN_LARVA={0}" -f $result.runtime_visual_probe.kerrigan_larva)
Write-Output ("RUNTIME_VISUAL_KERRIGAN_LARVA_PRIVATE={0}" -f $result.runtime_visual_probe.kerrigan_larva_private)
foreach ($check in $checks) {
    Write-Output ("CHECK_{0}={1} expected={2} actual={3}" -f $check.name.ToUpper().Replace(".", "_"), $(if ($check.passed) { "PASS" } else { "FAIL" }), $check.expected, $check.actual)
}
Write-Output ("VERIFY_PASS={0}" -f $(if ($result.passed) { 1 } else { 0 }))
