[CmdletBinding()]
param(
    [string]$PresetPath = "Shared\CommanderPower\commander-power-preset-example.json",
    # Use a multi-commander map here; ttosh02 keeps the original enemy slot layout and only tolerates one commander.
    [string]$MapSource = "Maps\thanson01_7vs1.SC2Map",
    [string]$LiveMapName = "thanson01_7vs1.SC2Map"
)

$ErrorActionPreference = "Stop"

function Get-WorkspaceRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Resolve-WorkspacePath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-WorkspaceRoot) $Path))
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
    if ($null -eq $node) {
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
    if ($null -eq $node) {
        return $null
    }

    if ($node.Attributes["string"]) {
        return [string]$node.Attributes["string"].Value
    }

    return $null
}

function Assert-Equal {
    param(
        [object]$Actual,
        [object]$Expected,
        [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw ("{0} expected={1} actual={2}" -f $Message, $Expected, $Actual)
    }
}

$workspaceRoot = Get-WorkspaceRoot
$resolvedPresetPath = Resolve-WorkspacePath -Path $PresetPath
$resolvedMapSource = Resolve-WorkspacePath -Path $MapSource
$launchPath = Join-Path $workspaceRoot "scripts\launch-7vs1-coop-test.ps1"

& $launchPath `
    -MapSource $resolvedMapSource `
    -LiveMapName $LiveMapName `
    -Commanders @("TerranRaynor", "TerranHorner") `
    -CommanderPowerPresetPath $resolvedPresetPath `
    -NoLaunch

$bankPaths = @(Get-CampaignXCoreBankPaths)
if ($bankPaths.Count -eq 0) {
    throw "CampaignXCore.SC2Bank not found after preset install."
}

foreach ($bankPath in $bankPaths) {
    [xml]$xml = Get-Content -LiteralPath $bankPath -Encoding UTF8 -Raw

    Assert-Equal -Actual (Get-BankStringValue -Xml $xml -SectionName "Ach" -KeyName "Commander") -Expected "Raynor" -Message "$bankPath Ach/Commander"

    Assert-Equal -Actual (Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName "Raynor.PrestigeBonusMask") -Expected 5 -Message "$bankPath Raynor.PrestigeBonusMask"
    Assert-Equal -Actual (Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName "Raynor.PrestigeMask") -Expected 5 -Message "$bankPath Raynor.PrestigeMask"
    Assert-Equal -Actual (Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName "Raynor.PrestigePointIndex") -Expected -1 -Message "$bankPath Raynor.PrestigePointIndex"
    Assert-Equal -Actual (Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName "Raynor.PrestigeIndex") -Expected -1 -Message "$bankPath Raynor.PrestigeIndex"
    Assert-Equal -Actual (Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName "Raynor.Mastery0") -Expected 17 -Message "$bankPath Raynor.Mastery0"
    Assert-Equal -Actual (Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName "Raynor.Mastery5") -Expected 3 -Message "$bankPath Raynor.Mastery5"

    Assert-Equal -Actual (Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName "Mira.PrestigeBonusMask") -Expected 5 -Message "$bankPath Mira.PrestigeBonusMask"
    Assert-Equal -Actual (Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName "Mira.PrestigeMask") -Expected 5 -Message "$bankPath Mira.PrestigeMask"
    Assert-Equal -Actual (Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName "Mira.PrestigePointIndex") -Expected 2 -Message "$bankPath Mira.PrestigePointIndex"
    Assert-Equal -Actual (Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName "Mira.PrestigeIndex") -Expected 2 -Message "$bankPath Mira.PrestigeIndex"
    Assert-Equal -Actual (Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName "Mira.MasteryDefault") -Expected 12 -Message "$bankPath Mira.MasteryDefault"
    Assert-Equal -Actual (Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName "Mira.Mastery0") -Expected 30 -Message "$bankPath Mira.Mastery0"
    Assert-Equal -Actual (Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName "Mira.Mastery1") -Expected 12 -Message "$bankPath Mira.Mastery1"
    Assert-Equal -Actual (Get-BankIntValue -Xml $xml -SectionName "CommanderPower" -KeyName "Mira.Mastery5") -Expected 9 -Message "$bankPath Mira.Mastery5"
}

Write-Host ("COMMANDER_POWER_PRESET_FILE_VALIDATE=PASS preset={0} banks={1}" -f $resolvedPresetPath, $bankPaths.Count)
