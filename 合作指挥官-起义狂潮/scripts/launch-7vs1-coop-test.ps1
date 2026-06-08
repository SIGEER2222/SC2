<#
.SYNOPSIS
Install and launch the replay-derived 7vs1 coop commander test map.

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-7vs1-coop-test.ps1

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-7vs1-coop-test.ps1 -Commanders @("TerranRaynor")

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-7vs1-coop-test.ps1 -Commanders @("TerranRaynor","ZergKerrigan","ProtossArtanis","ZergAbathur","ProtossFenix","TerranTychus","TerranNova")

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-7vs1-coop-test.ps1 -MapSource "游戏数据\其他mod数据\7vs1混合地图测试\Maps\ttosh02_7vs1.SC2Map" -LiveMapName "ttosh02_7vs1.SC2Map"

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\launch-7vs1-coop-test.ps1 -MapSource ".\Maps\ttosh02_7vs1.SC2Map" -LiveMapName "ttosh02_7vs1.SC2Map" -Commanders @("ZergAbathur") -TestSpawnPreset "AbathurFusion"
#>
[CmdletBinding()]
param(
    [string]$SourceRoot = "",
    [string]$MapSource = "",
    [string]$LiveMapName = "7vs1CoopTest.SC2Map",
    [string]$StartPointPreset = "Auto",
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$SwitcherPath = "",
    [string[]]$Commanders = @(),
    [string]$Preset = "Default",
    [ValidateSet("Full", "NoVisuals", "CoreOnly")]
    [string]$AbathurPatchProfile = "Full",
    [ValidateSet("", "AbathurFusion")]
    [string]$TestSpawnPreset = "",
    [string]$CommanderPowerProfile = "AllPositiveFusion",
    [Alias("CommanderPowerPrestigeMask")]
    [int]$CommanderPowerPrestigeBonusMask = 7,
    [Alias("CommanderPowerPrestigeIndex")]
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
    [string]$CommanderPowerPresetPath = "",
    [string[]]$CommanderPowerOverride = @(),
    [switch]$SkipCommanderPowerPreset,
    [switch]$DisableAbathurRebornPatch,
    [switch]$ForceStopSc2BeforeInstall,
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "commander-power-metadata.ps1")

function Get-WorkspaceRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Resolve-DefaultSourceRoot {
    $workspaceRoot = Get-WorkspaceRoot
    $candidates = @(
        (Join-Path $workspaceRoot "游戏数据\其他mod数据\7vs1母巢之战合作指挥官bate版_SC2Replay_94137"),
        "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\游戏数据\其他mod数据\7vs1母巢之战合作指挥官bate版_SC2Replay_94137"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $workspaceRoot
}

function Resolve-DefaultMapSource {
    $workspaceRoot = Get-WorkspaceRoot
    $localMap = Join-Path $workspaceRoot "Maps\ttosh02_7vs1.SC2Map"
    if (Test-Path -LiteralPath $localMap) {
        return $localMap
    }

    return Join-Path (Resolve-DefaultSourceRoot) "s2ma_packages\pkg02\extract"
}

function Resolve-ExtensionSource {
    param([string]$SourceRoot)

    $workspaceRoot = Get-WorkspaceRoot
    $localExtension = Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod"
    if (Test-Path -LiteralPath $localExtension) {
        return $localExtension
    }

    return Join-Path $SourceRoot "s2ma_packages\pkg03\extract"
}

function Resolve-AbathurRebornPatchSource {
    $workspaceRoot = Get-WorkspaceRoot
    $localPatch = Join-Path $workspaceRoot "Mods\7vs1\7v1AbathurRebornPatch.SC2Mod"
    if (Test-Path -LiteralPath $localPatch) {
        return $localPatch
    }

    return Join-Path $workspaceRoot "游戏数据\其他mod数据\7vs1混合地图测试\Mods\7vs1\7v1AbathurRebornPatch.SC2Mod"
}

function Resolve-CommanderCatalogSource {
    $workspaceRoot = Get-WorkspaceRoot
    return (Join-Path $workspaceRoot "Mods\7vs1\CommanderCatalog.SC2Mod")
}

function Resolve-SwannSourceGameData {
    param([string]$SourceRoot)

    $sourceGameData = Join-Path $SourceRoot "s2ma_packages\pkg01\extract\base.sc2data\GameData"
    if (Test-Path -LiteralPath $sourceGameData) {
        return $sourceGameData
    }

    return ""
}

function Resolve-WorkspacePath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path (Get-WorkspaceRoot) $Path
}

function Resolve-CommanderPreset {
    param([string]$Name)

    $presets = @{
        Default = @(
            "TerranRaynor",
            "ZergKerrigan",
            "ProtossArtanis",
            "TerranNova",
            "ZergAbathurReborn",
            "ProtossFenix",
            "ProtossVorazun"
        )
        Batch1 = @(
            "TerranRaynor",
            "ZergKerrigan",
            "ProtossArtanis",
            "TerranNova",
            "ZergAbathurReborn",
            "ProtossFenix",
            "ProtossVorazun"
        )
        Batch2 = @(
            "TerranSwann",
            "ZergZagara",
            "ProtossKarax",
            "TerranHorner",
            "ZergDehaka",
            "ProtossAlarak",
            "ZergStukov"
        )
        Batch3 = @(
            "ProtossZeratul",
            "ZergStetmann",
            "TerranMengsk",
            "ProtossArtanis",
            "TerranRaynor",
            "ZergKerrigan",
            "ProtossVorazun"
        )
        TychusP1 = @(
            "TerranTychus",
            "TerranRaynor",
            "ZergKerrigan",
            "ProtossArtanis",
            "TerranNova",
            "ZergAbathurReborn",
            "ProtossFenix"
        )
    }

    if (-not $presets.ContainsKey($Name)) {
        throw "Unknown preset '$Name'. Known presets: $($presets.Keys -join ', ')"
    }

    return @($presets[$Name])
}

function Get-CampaignXCoreBankPaths {
    $paths = New-Object System.Collections.Generic.List[string]

    $liveBank = Join-Path $env:USERPROFILE "Documents\StarCraft II\Banks\CampaignXCore.SC2Bank"
    if (Test-Path -LiteralPath $liveBank) {
        $paths.Add((Resolve-Path -LiteralPath $liveBank).Path)
    }

    $accountsRoot = Join-Path $env:USERPROFILE "Documents\StarCraft II\Accounts"
    if (Test-Path -LiteralPath $accountsRoot) {
        $accountBanks = Get-ChildItem -LiteralPath $accountsRoot -Recurse -File -Filter "CampaignXCore.SC2Bank" |
            Where-Object { $_.FullName -notmatch '\\backup\\' } |
            Sort-Object LastWriteTime -Descending
        foreach ($bank in $accountBanks) {
            if ($paths -notcontains $bank.FullName) {
                $paths.Add($bank.FullName)
            }
        }
    }

    return $paths.ToArray()
}

function Get-OrCreateBankSection {
    param(
        [xml]$Xml,
        [string]$SectionName
    )

    $bank = $Xml.SelectSingleNode("/Bank")
    if (-not $bank) {
        throw "Invalid bank file: missing <Bank> root."
    }

    $section = $Xml.SelectSingleNode("/Bank/Section[@name='$SectionName']")
    if (-not $section) {
        $section = $Xml.CreateElement("Section")
        $null = $section.SetAttribute("name", $SectionName)
        $null = $bank.AppendChild($section)
    }

    return $section
}

function Get-OrCreateBankKey {
    param(
        [xml]$Xml,
        [System.Xml.XmlNode]$Section,
        [string]$KeyName
    )

    $escapedKey = $KeyName.Replace("'", "&apos;")
    $key = $Section.SelectSingleNode("Key[@name='$escapedKey']")
    if (-not $key) {
        $key = $Xml.CreateElement("Key")
        $null = $key.SetAttribute("name", $KeyName)
        $null = $Section.AppendChild($key)
    }

    return $key
}

function Set-BankStringKeyValue {
    param(
        [xml]$Xml,
        [string]$SectionName,
        [string]$KeyName,
        [string]$Value
    )

    $section = Get-OrCreateBankSection -Xml $Xml -SectionName $SectionName
    $key = Get-OrCreateBankKey -Xml $Xml -Section $section -KeyName $KeyName
    $valueNode = $key.SelectSingleNode("Value")
    if (-not $valueNode) {
        $valueNode = $Xml.CreateElement("Value")
        $null = $key.AppendChild($valueNode)
    }

    $null = $valueNode.RemoveAttribute("int")
    $null = $valueNode.SetAttribute("string", $Value)
}

function Set-BankIntKeyValue {
    param(
        [xml]$Xml,
        [string]$SectionName,
        [string]$KeyName,
        [int]$Value
    )

    $section = Get-OrCreateBankSection -Xml $Xml -SectionName $SectionName
    $key = Get-OrCreateBankKey -Xml $Xml -Section $section -KeyName $KeyName
    $valueNode = $key.SelectSingleNode("Value")
    if (-not $valueNode) {
        $valueNode = $Xml.CreateElement("Value")
        $null = $key.AppendChild($valueNode)
    }

    $null = $valueNode.RemoveAttribute("string")
    $null = $valueNode.SetAttribute("int", [string]$Value)
}

function Save-XmlDocumentWithRetry {
    param(
        [xml]$Xml,
        [string]$Path,
        [int]$RetryCount = 10,
        [int]$DelayMilliseconds = 500
    )

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            $Xml.Save($Path)
            return
        }
        catch {
            if ($attempt -ge $RetryCount) {
                throw
            }
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }
}

function Write-FileBytesWithRetry {
    param(
        [string]$Path,
        [byte[]]$Bytes,
        [int]$RetryCount = 10,
        [int]$DelayMilliseconds = 500
    )

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            [System.IO.File]::WriteAllBytes($Path, $Bytes)
            return
        }
        catch {
            if ($attempt -ge $RetryCount) {
                throw
            }
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }
}

function Set-FileTextWithRetry {
    param(
        [string]$Path,
        [string]$Text,
        [int]$RetryCount = 10,
        [int]$DelayMilliseconds = 500
    )

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            Set-Content -LiteralPath $Path -Value $Text -NoNewline -Encoding UTF8
            return
        }
        catch {
            if ($attempt -ge $RetryCount) {
                throw
            }
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }
}

function Wait-PathAvailable {
    param(
        [string]$Path,
        [int]$RetryCount = 20,
        [int]$DelayMilliseconds = 250
    )

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        if (Test-Path -LiteralPath $Path) {
            return
        }
        if ($attempt -lt $RetryCount) {
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }

    throw "Path not found after wait: $Path"
}

function Convert-TestCommanderToCommanderPowerKey {
    param([string]$Commander)

    if ($Commander -eq "ZergAbathurReborn") {
        return "AbathurReborn"
    }

    return (Convert-CommanderPowerCommanderToBankKey -Commander $Commander -WorkspaceRoot (Get-WorkspaceRoot))
}

function Resolve-CommanderPowerPresetPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-WorkspaceRoot) $Path))
}

function ConvertTo-CommanderPowerBoolInt {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Value,
        [int]$DefaultValue = 0
    )

    if ($null -eq $Value) {
        return $DefaultValue
    }

    if ($Value -is [bool]) {
        return $(if ($Value) { 1 } else { 0 })
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $DefaultValue
    }

    if ($text.Equals("true", [System.StringComparison]::OrdinalIgnoreCase)) {
        return 1
    }
    if ($text.Equals("false", [System.StringComparison]::OrdinalIgnoreCase)) {
        return 0
    }

    $intValue = 0
    if ([int]::TryParse($text, [ref]$intValue)) {
        return $(if ($intValue -gt 0) { 1 } else { 0 })
    }

    throw "Invalid boolean/int value for CommanderPower preset: $Value"
}

function ConvertTo-CommanderPowerPrestigeMask {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$CommanderRecord,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Entry,
        [int]$DefaultMask
    )

    if ($null -ne $Entry.prestige_bonus_mask) {
        return [Math]::Max(0, [Math]::Min(7, [int]$Entry.prestige_bonus_mask))
    }

    if ($null -ne $Entry.prestige_mask) {
        return [Math]::Max(0, [Math]::Min(7, [int]$Entry.prestige_mask))
    }

    if ($null -ne $Entry.prestige_slots) {
        $mask = 0
        foreach ($slot in @($Entry.prestige_slots)) {
            $slotIndex = [int]$slot
            if (($slotIndex -lt 0) -or ($slotIndex -ge @($CommanderRecord.prestiges).Count)) {
                throw ("Invalid prestige slot '{0}' for commander '{1}'." -f $slot, $CommanderRecord.runtime_commander)
            }

            $mask = ($mask -bor (1 -shl $slotIndex))
        }
        return $mask
    }

    if ($null -ne $Entry.prestige_ids) {
        $mask = 0
        foreach ($prestigeId in @($Entry.prestige_ids)) {
            $matched = $false
            foreach ($prestige in @($CommanderRecord.prestiges)) {
                if (([string]$prestige.id).Equals([string]$prestigeId, [System.StringComparison]::OrdinalIgnoreCase) -or
                    ([string]$prestige.button_id).Equals([string]$prestigeId, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $mask = ($mask -bor (1 -shl [int]$prestige.slot))
                    $matched = $true
                    break
                }
            }

            if (-not $matched) {
                throw ("Unknown prestige id '{0}' for commander '{1}'." -f $prestigeId, $CommanderRecord.runtime_commander)
            }
        }
        return $mask
    }

    return $DefaultMask
}

function ConvertTo-CommanderPowerPrestigePointIndex {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Entry,
        [int]$DefaultPointIndex
    )

    if ($null -ne $Entry.prestige_point_index) {
        return [Math]::Max(-1, [Math]::Min(3, [int]$Entry.prestige_point_index))
    }

    if ($null -ne $Entry.prestige_index) {
        return [Math]::Max(-1, [Math]::Min(3, [int]$Entry.prestige_index))
    }

    return $DefaultPointIndex
}

function ConvertTo-CommanderPowerMasteryValues {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$CommanderRecord,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Entry,
        [int]$DefaultMasteryLevel
    )

    $values = @()
    for ($masteryIndex = 0; $masteryIndex -lt @($CommanderRecord.masteries).Count; $masteryIndex++) {
        $values += $DefaultMasteryLevel
    }

    if ($null -eq $Entry.masteries) {
        return $values
    }

    if (($Entry.masteries -is [System.Management.Automation.PSCustomObject]) -or
        ($Entry.masteries -is [System.Collections.IDictionary])) {
        foreach ($property in $Entry.masteries.PSObject.Properties) {
            $index = [int]$property.Name
            if (($index -lt 0) -or ($index -ge $values.Count)) {
                throw ("Invalid mastery slot '{0}' for commander '{1}'." -f $property.Name, $CommanderRecord.runtime_commander)
            }

            $values[$index] = [Math]::Max(0, [Math]::Min(30, [int]$property.Value))
        }

        return $values
    }

    $arrayValues = @($Entry.masteries)
    if ($arrayValues.Count -ne $values.Count) {
        throw ("Commander '{0}' mastery array expected {1} values, got {2}." -f $CommanderRecord.runtime_commander, $values.Count, $arrayValues.Count)
    }

    for ($masteryIndex = 0; $masteryIndex -lt $arrayValues.Count; $masteryIndex++) {
        $values[$masteryIndex] = [Math]::Max(0, [Math]::Min(30, [int]$arrayValues[$masteryIndex]))
    }

    return $values
}

function Get-CommanderPowerPresetEntries {
    param([string]$PresetPath)

    $resolvedPath = Resolve-CommanderPowerPresetPath -Path $PresetPath
    if ([string]::IsNullOrWhiteSpace($resolvedPath)) {
        return @()
    }

    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "CommanderPower preset path not found: $resolvedPath"
    }

    $json = Get-Content -LiteralPath $resolvedPath -Encoding UTF8 -Raw | ConvertFrom-Json
    if ($null -eq $json.entries) {
        throw "CommanderPower preset file must contain an 'entries' array."
    }

    return @($json.entries)
}

function Apply-CommanderPowerOverrideEntry {
    param(
        [xml]$Xml,
        [string]$OverrideEntry
    )

    if ([string]::IsNullOrWhiteSpace($OverrideEntry)) {
        return
    }

    $parts = $OverrideEntry.Split("=", 2)
    if ($parts.Count -ne 2) {
        throw "Invalid CommanderPowerOverride entry '$OverrideEntry'. Expected Commander.Key=Value."
    }

    $fullKey = $parts[0].Trim()
    $value = $parts[1].Trim()
    $keyParts = $fullKey.Split(".", 2)
    if ($keyParts.Count -ne 2) {
        throw "Invalid CommanderPowerOverride key '$fullKey'. Expected Commander.Key."
    }

    $commanderKey = Convert-TestCommanderToCommanderPowerKey -Commander $keyParts[0].Trim()
    if ([string]::IsNullOrWhiteSpace($commanderKey)) {
        $commanderKey = $keyParts[0].Trim()
    }
    $bankKey = "$commanderKey.$($keyParts[1].Trim())"

    $intValue = 0
    if ([int]::TryParse($value, [ref]$intValue)) {
        Set-BankIntKeyValue -Xml $Xml -SectionName "CommanderPower" -KeyName $bankKey -Value $intValue
        return
    }

    Set-BankStringKeyValue -Xml $Xml -SectionName "CommanderPower" -KeyName $bankKey -Value $value
}

function Set-CampaignXCoreCommanderPowerPreset {
    param(
        [string[]]$SelectedCommanders,
        [string]$Profile,
        [int]$PrestigeBonusMask,
        [Nullable[int]]$PrestigePointIndex,
        [int]$EnablePrestiges,
        [int]$EnableMasteries,
        [int]$MasteryLevel,
        [Nullable[int]]$Mastery0,
        [Nullable[int]]$Mastery1,
        [Nullable[int]]$Mastery2,
        [Nullable[int]]$Mastery3,
        [Nullable[int]]$Mastery4,
        [Nullable[int]]$Mastery5,
        [string]$PresetPath,
        [string[]]$Overrides
    )

    $bankPaths = @(Get-CampaignXCoreBankPaths)
    if ($bankPaths.Count -eq 0) {
        Write-Warning "CampaignXCore.SC2Bank not found; skipping CommanderPower preset."
        return
    }

    $normalizedMasteryLevel = [Math]::Max(0, [Math]::Min(30, $MasteryLevel))
    $normalizedPrestigeBonusMask = [Math]::Max(0, [Math]::Min(7, $PrestigeBonusMask))
    $normalizedEnablePrestiges = if ($EnablePrestiges -gt 0) { 1 } else { 0 }
    $normalizedEnableMasteries = if ($EnableMasteries -gt 0) { 1 } else { 0 }
    $normalizedPrestigePointIndex = -1
    if ($null -ne $PrestigePointIndex) {
        $normalizedPrestigePointIndex = [Math]::Max(-1, [Math]::Min(3, [int]$PrestigePointIndex))
    }
    $masteryOverrides = @(
        $Mastery0,
        $Mastery1,
        $Mastery2,
        $Mastery3,
        $Mastery4,
        $Mastery5
    )
    $commanderSettings = [ordered]@{}
    foreach ($selectedCommander in $SelectedCommanders) {
        $commanderKey = Convert-TestCommanderToCommanderPowerKey -Commander $selectedCommander
        if ([string]::IsNullOrWhiteSpace($commanderKey)) {
            continue
        }

        $commanderMasteryValues = @()
        for ($masteryIndex = 0; $masteryIndex -le 5; $masteryIndex++) {
            $masteryValue = $normalizedMasteryLevel
            if ($null -ne $masteryOverrides[$masteryIndex]) {
                $masteryValue = [Math]::Max(0, [Math]::Min(30, [int]$masteryOverrides[$masteryIndex]))
            }
            $commanderMasteryValues += $masteryValue
        }

        $commanderSettings[$commanderKey] = @{
            Profile = $Profile
            EnablePrestiges = $normalizedEnablePrestiges
            EnableMasteries = $normalizedEnableMasteries
            PrestigePointIndex = $normalizedPrestigePointIndex
            PrestigeIndex = $normalizedPrestigePointIndex
            PrestigeBonusMask = $normalizedPrestigeBonusMask
            PrestigeMask = $normalizedPrestigeBonusMask
            MasteryDefault = $normalizedMasteryLevel
            Masteries = $commanderMasteryValues
        }
    }

    foreach ($entry in @(Get-CommanderPowerPresetEntries -PresetPath $PresetPath)) {
        $entryCommander = [string]$entry.commander
        if ([string]::IsNullOrWhiteSpace($entryCommander)) {
            throw "CommanderPower preset entry is missing required field 'commander'."
        }

        if ($entryCommander -eq "ZergAbathurReborn") {
            throw "CommanderPower preset does not support ZergAbathurReborn. Keep using direct CommanderPowerOverride or legacy Abathur patch controls for that path."
        }

        $commanderRecord = Resolve-CommanderPowerCommanderRecord -Commander $entryCommander -WorkspaceRoot (Get-WorkspaceRoot)
        if ($null -eq $commanderRecord) {
            throw "Unknown commander in CommanderPower preset: $entryCommander"
        }

        $bankCommander = [string]$commanderRecord.bank_commander
        $entryMasteryDefault = $normalizedMasteryLevel
        if ($null -ne $entry.mastery_default) {
            $entryMasteryDefault = [Math]::Max(0, [Math]::Min(30, [int]$entry.mastery_default))
        }

        $commanderSettings[$bankCommander] = @{
            Profile = $(if ($null -ne $entry.profile -and -not [string]::IsNullOrWhiteSpace([string]$entry.profile)) { [string]$entry.profile } else { $Profile })
            EnablePrestiges = (ConvertTo-CommanderPowerBoolInt -Value $entry.enable_prestiges -DefaultValue $normalizedEnablePrestiges)
            EnableMasteries = (ConvertTo-CommanderPowerBoolInt -Value $entry.enable_masteries -DefaultValue $normalizedEnableMasteries)
            PrestigePointIndex = (ConvertTo-CommanderPowerPrestigePointIndex -Entry $entry -DefaultPointIndex $normalizedPrestigePointIndex)
            PrestigeIndex = (ConvertTo-CommanderPowerPrestigePointIndex -Entry $entry -DefaultPointIndex $normalizedPrestigePointIndex)
            PrestigeBonusMask = (ConvertTo-CommanderPowerPrestigeMask -CommanderRecord $commanderRecord -Entry $entry -DefaultMask $normalizedPrestigeBonusMask)
            PrestigeMask = (ConvertTo-CommanderPowerPrestigeMask -CommanderRecord $commanderRecord -Entry $entry -DefaultMask $normalizedPrestigeBonusMask)
            MasteryDefault = $entryMasteryDefault
            Masteries = (ConvertTo-CommanderPowerMasteryValues -CommanderRecord $commanderRecord -Entry $entry -DefaultMasteryLevel $entryMasteryDefault)
        }
    }

    foreach ($bankPath in $bankPaths) {
        [xml]$xml = Get-Content -LiteralPath $bankPath -Raw

        if ($commanderSettings.Count -gt 0) {
            Set-BankStringKeyValue -Xml $xml -SectionName "Ach" -KeyName "Commander" -Value @($commanderSettings.Keys)[0]
        }

        foreach ($commanderKey in $commanderSettings.Keys) {
            $setting = $commanderSettings[$commanderKey]
            Set-BankStringKeyValue -Xml $xml -SectionName "CommanderPower" -KeyName "$commanderKey.Profile" -Value $setting.Profile
            Set-BankIntKeyValue -Xml $xml -SectionName "CommanderPower" -KeyName "$commanderKey.EnablePrestiges" -Value $setting.EnablePrestiges
            Set-BankIntKeyValue -Xml $xml -SectionName "CommanderPower" -KeyName "$commanderKey.EnableMasteries" -Value $setting.EnableMasteries
            Set-BankIntKeyValue -Xml $xml -SectionName "CommanderPower" -KeyName "$commanderKey.PrestigePointIndex" -Value $setting.PrestigePointIndex
            Set-BankIntKeyValue -Xml $xml -SectionName "CommanderPower" -KeyName "$commanderKey.PrestigeIndex" -Value $setting.PrestigeIndex
            Set-BankIntKeyValue -Xml $xml -SectionName "CommanderPower" -KeyName "$commanderKey.PrestigeBonusMask" -Value $setting.PrestigeBonusMask
            Set-BankIntKeyValue -Xml $xml -SectionName "CommanderPower" -KeyName "$commanderKey.PrestigeMask" -Value $setting.PrestigeMask
            Set-BankIntKeyValue -Xml $xml -SectionName "CommanderPower" -KeyName "$commanderKey.MasteryDefault" -Value $setting.MasteryDefault
            for ($masteryIndex = 0; $masteryIndex -le 5; $masteryIndex++) {
                $masteryValue = [int]$setting.Masteries[$masteryIndex]
                Set-BankIntKeyValue -Xml $xml -SectionName "CommanderPower" -KeyName "$commanderKey.Mastery$masteryIndex" -Value $masteryValue
            }
        }
        if ($commanderSettings.Count -gt 0) {
            Set-BankIntKeyValue -Xml $xml -SectionName "CommanderPowerRuntime" -KeyName "PreserveBankPreset" -Value ([Math]::Max(1, $commanderSettings.Count))
        }

        foreach ($overrideEntry in $Overrides) {
            Apply-CommanderPowerOverrideEntry -Xml $xml -OverrideEntry $overrideEntry
        }

        Save-XmlDocumentWithRetry -Xml $xml -Path $bankPath
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
            if (($attempt -ge $RetryCount) -or (-not (Test-Path -LiteralPath $Path))) {
                throw
            }
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }
}

function Remove-UnsupportedLiveRuntimeRoots {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Sc2Root,
        [string[]]$AllowedDependencies = @()
    )

    $removed = New-Object 'System.Collections.Generic.List[string]'
    $modsRoot = Join-Path $Sc2Root "Mods"
    if (-not (Test-Path -LiteralPath $modsRoot)) {
        return $removed.ToArray()
    }

    $allowed7vs1Mods = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($dependency in $AllowedDependencies) {
        if (-not (Test-WorkspaceModDependency -Dependency $dependency)) {
            continue
        }

        $relativePath = Convert-DependencyToRelativePath -Dependency $dependency
        if ($relativePath -like 'Mods\7vs1\*.SC2Mod') {
            $null = $allowed7vs1Mods.Add((Split-Path -Path $relativePath -Leaf))
        }
    }

    foreach ($entry in Get-ChildItem -LiteralPath $modsRoot -Force -ErrorAction SilentlyContinue) {
        if ($entry.Name -notlike 'XM*') {
            continue
        }

        Remove-DirectoryWithRetry -Path $entry.FullName
        $null = $removed.Add(("Mods\{0}" -f $entry.Name))
    }

    $mods7vs1Root = Join-Path $modsRoot "7vs1"
    if (Test-Path -LiteralPath $mods7vs1Root) {
        foreach ($entry in Get-ChildItem -LiteralPath $mods7vs1Root -Force -ErrorAction SilentlyContinue) {
            if (($entry.Name -notlike '*.SC2Mod') -or $allowed7vs1Mods.Contains($entry.Name)) {
                continue
            }

            Remove-DirectoryWithRetry -Path $entry.FullName
            $null = $removed.Add(("Mods\7vs1\{0}" -f $entry.Name))
        }
    }

    return $removed.ToArray()
}

function Remove-LegacyLiveRuntimeRoots {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Sc2Root,
        [string[]]$AllowedDependencies = @()
    )

    return Remove-UnsupportedLiveRuntimeRoots -Sc2Root $Sc2Root -AllowedDependencies $AllowedDependencies
}

function Set-DocumentInfoDependencies {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string[]]$Dependencies
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Wait-PathAvailable -Path $Path
    }

    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    $doc = $xml.SelectSingleNode("/DocInfo")
    if (-not $doc) {
        throw "Invalid DocumentInfo: missing /DocInfo in $Path"
    }

    $old = $xml.SelectSingleNode("/DocInfo/Dependencies")
    if ($old) {
        $null = $doc.RemoveChild($old)
    }

    $dependenciesNode = $xml.CreateElement("Dependencies")
    foreach ($dependency in $Dependencies) {
        $valueNode = $xml.CreateElement("Value")
        $valueNode.InnerText = $dependency
        $null = $dependenciesNode.AppendChild($valueNode)
    }

    $insertBefore = $doc.SelectSingleNode("Screenshot|PatchNote|Preload|HowToPlayBasic|HowToPlayAdvanced")
    if ($insertBefore) {
        $null = $doc.InsertBefore($dependenciesNode, $insertBefore)
    }
    else {
        $null = $doc.AppendChild($dependenciesNode)
    }

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $settings.Indent = $true
    $settings.NewLineChars = "`r`n"
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try {
        $xml.Save($writer)
    }
    finally {
        $writer.Close()
    }
}

function Test-ByteSequenceAt {
    param(
        [byte[]]$Bytes,
        [int]$Offset,
        [byte[]]$Needle
    )

    if ($Offset + $Needle.Length -gt $Bytes.Length) {
        return $false
    }

    for ($i = 0; $i -lt $Needle.Length; $i++) {
        if ($Bytes[$Offset + $i] -ne $Needle[$i]) {
            return $false
        }
    }

    return $true
}

function Find-DocumentHeaderDependencyStart {
    param([byte[]]$Bytes)

    $markers = @(
        [System.Text.Encoding]::UTF8.GetBytes("file:"),
        [System.Text.Encoding]::UTF8.GetBytes("bnet:")
    )

    for ($offset = 4; $offset -lt $Bytes.Length; $offset++) {
        foreach ($marker in $markers) {
            if (-not (Test-ByteSequenceAt -Bytes $Bytes -Offset $offset -Needle $marker)) {
                continue
            }

            $count = [System.BitConverter]::ToUInt32($Bytes, $offset - 4)
            if (($count -gt 0) -and ($count -lt 128)) {
                return $offset
            }
        }
    }

    throw "DocumentHeader dependency table not found."
}

function Get-DocumentHeaderDependencyEndOffset {
    param(
        [byte[]]$Bytes,
        [int]$Start,
        [uint32]$Count
    )

    $offset = $Start
    for ($index = 0; $index -lt $Count; $index++) {
        while (($offset -lt $Bytes.Length) -and ($Bytes[$offset] -ne 0)) {
            $offset++
        }
        if ($offset -ge $Bytes.Length) {
            throw "DocumentHeader dependency string is not null-terminated."
        }
        $offset++
    }

    return $offset
}

function Set-DocumentHeaderDependencies {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string[]]$Dependencies
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Wait-PathAvailable -Path $Path
    }

    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($Path)
    $dependencyStart = Find-DocumentHeaderDependencyStart -Bytes $bytes
    $countOffset = $dependencyStart - 4
    $currentCount = [System.BitConverter]::ToUInt32($bytes, $countOffset)
    $dependencyEnd = Get-DocumentHeaderDependencyEndOffset -Bytes $bytes -Start $dependencyStart -Count $currentCount
    $dependencyBytes = [System.Text.Encoding]::UTF8.GetBytes((($Dependencies -join "`0") + "`0"))
    $countBytes = [System.BitConverter]::GetBytes([uint32]$Dependencies.Count)
    $stream = New-Object System.IO.MemoryStream

    $stream.Write($bytes, 0, $countOffset)
    $stream.Write($countBytes, 0, $countBytes.Length)
    $stream.Write($dependencyBytes, 0, $dependencyBytes.Length)
    $stream.Write($bytes, $dependencyEnd, $bytes.Length - $dependencyEnd)

    Write-FileBytesWithRetry -Path $Path -Bytes $stream.ToArray()
}

function Set-PackageDependencies {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageRoot,
        [Parameter(Mandatory = $true)]
        [string[]]$Dependencies
    )

    Set-DocumentInfoDependencies -Path (Join-Path $PackageRoot "DocumentInfo") -Dependencies $Dependencies
    Set-DocumentHeaderDependencies -Path (Join-Path $PackageRoot "DocumentHeader") -Dependencies $Dependencies
}

function Get-DocumentInfoDependencies {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Wait-PathAvailable -Path $Path
    }

    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    return @($xml.SelectNodes("/DocInfo/Dependencies/Value") | ForEach-Object { [string]$_.InnerText })
}

function Add-DependencyUnique {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Dependencies,
        [Parameter(Mandatory = $true)]
        [string]$Dependency
    )

    if ($Dependencies -contains $Dependency) {
        return $Dependencies
    }

    return @($Dependencies + $Dependency)
}

function Get-DependencyFileTarget {
    param([string]$Dependency)

    $parts = $Dependency.Split(',')
    $target = $parts[$parts.Count - 1]
    if ($target -like 'file:*') {
        return ($target -replace '\\', '/')
    }

    return ""
}

function Normalize-MapRuntimeDependencies {
    param([string[]]$Dependencies)

    $libertyStory = "bnet:自由之翼剧情 (战役)/0.0/999,file:Campaigns/LibertyStory.SC2Campaign"
    $libertyMod = "bnet:自由之翼 (Mod)/0.0/999,file:Mods/Liberty.SC2Mod"
    $normalized = @($libertyStory, $libertyMod)

    foreach ($dependency in $Dependencies) {
        $target = Get-DependencyFileTarget -Dependency $dependency
        if (($target -eq "file:Campaigns/LibertyStory.SC2Campaign") -or
            ($target -eq "file:Mods/Liberty.SC2Mod")) {
            continue
        }

        if ($dependency -like "file:*") {
            $dependency = ($dependency -replace '\\', '/')
        }
        $normalized = Add-DependencyUnique -Dependencies $normalized -Dependency $dependency
    }

    return $normalized
}

function Test-AnyLocalModDependency {
    param([string]$Dependency)

    return $Dependency -like 'file:Mods/*'
}

function Test-WorkspaceModDependency {
    param([string]$Dependency)

    if (-not (Test-AnyLocalModDependency -Dependency $Dependency)) {
        return $false
    }

    $normalized = $Dependency.Replace('\', '/').ToLowerInvariant()
    return ($normalized -like 'file:mods/7vs1/*.sc2mod') -or
        ($normalized -eq 'file:mods/kit_mutations.sc2mod')
}

function Assert-SupportedWorkspaceModDependency {
    param([string]$Dependency)

    if ((Test-AnyLocalModDependency -Dependency $Dependency) -and
        (-not (Test-WorkspaceModDependency -Dependency $Dependency))) {
        throw "Unsupported workspace dependency '$Dependency'. 7vs1 smoke/install only allows file:Mods/7vs1/*.SC2Mod and file:Mods/kit_mutations.SC2Mod. Remove stale unsupported local mod references from DocumentInfo."
    }
}

function Assert-NoUnsupportedWorkspaceDependency {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Dependencies,
        [string]$DependencyOwner = "dependency list"
    )

    foreach ($dependency in $Dependencies) {
        Assert-SupportedWorkspaceModDependency -Dependency $dependency
    }
}

function Convert-DependencyToRelativePath {
    param([string]$Dependency)

    if (-not (Test-WorkspaceModDependency -Dependency $Dependency)) {
        Assert-SupportedWorkspaceModDependency -Dependency $Dependency
        throw "Unsupported local dependency path: $Dependency"
    }

    return $Dependency.Substring(5).Replace('/', '\')
}

function Resolve-WorkspaceDependencySource {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Dependency,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot
    )

    $relativePath = Convert-DependencyToRelativePath -Dependency $Dependency
    $sourcePath = Join-Path $WorkspaceRoot $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Workspace dependency source not found for ${Dependency}: $sourcePath"
    }

    return $sourcePath
}

function Resolve-LiveDependencyDestination {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Dependency,
        [Parameter(Mandatory = $true)]
        [string]$Sc2Root
    )

    return (Join-Path $Sc2Root (Convert-DependencyToRelativePath -Dependency $Dependency))
}

function Resolve-WorkspaceModDependencyClosure {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Dependencies,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot
    )

    $queue = New-Object 'System.Collections.Generic.Queue[string]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $closure = New-Object 'System.Collections.Generic.List[string]'

foreach ($dependency in $Dependencies) {
    Assert-SupportedWorkspaceModDependency -Dependency $dependency
    if (Test-WorkspaceModDependency -Dependency $dependency) {
        $queue.Enqueue($dependency)
    }
}

    while ($queue.Count -gt 0) {
        $dependency = $queue.Dequeue()
        if (-not $seen.Add($dependency)) {
            continue
        }

        $null = $closure.Add($dependency)
        $sourceRoot = Resolve-WorkspaceDependencySource -Dependency $dependency -WorkspaceRoot $WorkspaceRoot
        $documentInfoPath = Join-Path $sourceRoot 'DocumentInfo'
        if (-not (Test-Path -LiteralPath $documentInfoPath)) {
            continue
        }

    foreach ($childDependency in (Get-DocumentInfoDependencies -Path $documentInfoPath)) {
        Assert-SupportedWorkspaceModDependency -Dependency $childDependency
        if (Test-WorkspaceModDependency -Dependency $childDependency) {
            $queue.Enqueue($childDependency)
        }
        }
    }

    return $closure.ToArray()
}

function Install-WorkspaceModDependencyClosure {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Dependencies,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)]
        [string]$Sc2Root,
        [string[]]$SkipDependencies = @()
    )

    $skipSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($dependency in $SkipDependencies) {
        if (-not [string]::IsNullOrWhiteSpace($dependency)) {
            $null = $skipSet.Add($dependency)
        }
    }

    $installed = New-Object 'System.Collections.Generic.List[string]'
    foreach ($dependency in (Resolve-WorkspaceModDependencyClosure -Dependencies $Dependencies -WorkspaceRoot $WorkspaceRoot)) {
        if ($skipSet.Contains($dependency)) {
            continue
        }

        $sourceRoot = Resolve-WorkspaceDependencySource -Dependency $dependency -WorkspaceRoot $WorkspaceRoot
        $liveRoot = Resolve-LiveDependencyDestination -Dependency $dependency -Sc2Root $Sc2Root
        Copy-DirectoryClean -Source $sourceRoot -Destination $liveRoot
        $null = $installed.Add($dependency)
    }

    return $installed.ToArray()
}

function Get-CodexStartPoints {
    param([string]$Preset)

    if ($Preset -eq "JungleTtosh02") {
        return @(
            @(179.5, 22.5),
            @(75.0, 150.0),
            @(126.0, 148.0),
            @(195.0, 140.0),
            @(40.0, 80.0),
            @(118.0, 80.0),
            @(195.0, 78.0),
            @(112.0, 30.0)
        )
    }

    if ($Preset -ne "Default") {
        throw "Unknown start point preset '$Preset'. Known presets: Auto, Default, JungleTtosh02"
    }

    return @(
        @(17.2722, 167.6455),
        @(61.2580, 177.7963),
        @(180.3906, 176.9645),
        @(179.5000, 85.5000),
        @(175.0556, 12.0603),
        @(112.8891, 12.5356),
        @(32.5000, 12.5000),
        @(11.5000, 90.5000)
    )
}

function Get-MapObjectStartPointOverrides {
    param([string]$MapSource)

    $objectsPath = Join-Path $MapSource "Objects"
    if (-not (Test-Path -LiteralPath $objectsPath)) {
        return @{}
    }

    $text = Get-Content -LiteralPath $objectsPath -Raw
    $overrides = @{}
    $matches = [regex]::Matches(
        $text,
        '<ObjectPoint\b[^>]*\bPosition="(?<x>-?\d+(?:\.\d+)?),(?<y>-?\d+(?:\.\d+)?),[^"]*"[^>]*\bType="StartLoc"[^>]*\bName="Start Location (?:P)?(?<player>\d+)\b[^"]*"',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    foreach ($match in $matches) {
        $player = [int]$match.Groups['player'].Value
        if (($player -lt 1) -or ($player -gt 8)) {
            continue
        }

        $overrides[$player] = @(
            [double]::Parse($match.Groups['x'].Value, [System.Globalization.CultureInfo]::InvariantCulture),
            [double]::Parse($match.Groups['y'].Value, [System.Globalization.CultureInfo]::InvariantCulture)
        )
    }

    return $overrides
}

function Resolve-StartPoints {
    param(
        [string]$Preset,
        [string]$MapSource,
        [string]$LiveMapName
    )

    if ($Preset -eq "Auto") {
        $mapName = [System.IO.Path]::GetFileName($MapSource)
        if (($mapName -like "ttosh02*") -or ($LiveMapName -like "ttosh02*")) {
            $Preset = "JungleTtosh02"
        }
        else {
            $Preset = "Default"
        }
    }

    $points = @(Get-CodexStartPoints -Preset $Preset)
    $objectOverrides = Get-MapObjectStartPointOverrides -MapSource $MapSource
    foreach ($player in $objectOverrides.Keys) {
        $points[$player - 1] = @($objectOverrides[$player][0], $objectOverrides[$player][1])
    }

    return $points
}

function Get-CodexStartPointFunction {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FunctionName,
        [Parameter(Mandatory = $true)]
        [object[]]$Points
    )

    $functionBlock = New-Object System.Text.StringBuilder
    [void]$functionBlock.AppendLine("point $FunctionName (int lp_player) {")
    for ($i = 0; $i -lt $Points.Count; $i++) {
        $player = $i + 1
        $x = ([double]$Points[$i][0]).ToString("0.####", [System.Globalization.CultureInfo]::InvariantCulture)
        $y = ([double]$Points[$i][1]).ToString("0.####", [System.Globalization.CultureInfo]::InvariantCulture)
        [void]$functionBlock.AppendLine("    if (lp_player == $player) { return Point($x, $y); }")
    }
    [void]$functionBlock.AppendLine("    return Point(0.0, 0.0);")
    [void]$functionBlock.AppendLine("}")
    [void]$functionBlock.AppendLine("")

    return $functionBlock.ToString()
}

function Add-SafeStartPointOverride {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$FunctionName,
        [Parameter(Mandatory = $true)]
        [string]$InsertionAnchor,
        [Parameter(Mandatory = $true)]
        [object[]]$StartPoints
    )

    $text = Get-Content -LiteralPath $Path -Raw
    $definitionPattern = "point\s+$([regex]::Escape($FunctionName))\s*\("
    if ($text -notmatch $definitionPattern) {
        $anchorIndex = $text.IndexOf($InsertionAnchor, [System.StringComparison]::Ordinal)
        if ($anchorIndex -lt 0) {
            throw "Could not find insertion anchor '$InsertionAnchor' in $Path"
        }

        $text = $text.Insert($anchorIndex, (Get-CodexStartPointFunction -FunctionName $FunctionName -Points $StartPoints))
    }

    $text = [regex]::Replace($text, 'PlayerStartLocation\(', "$FunctionName(")
    Set-FileTextWithRetry -Path $Path -Text $text
}

function Disable-LiveRewardGrants {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $text = Get-Content -LiteralPath $Path -Raw
    $text = [regex]::Replace(
        $text,
        '(?m)^\s*PlayerAddReward\([^\r\n]*\);\s*$',
        '    // Codex local smoke test: PlayerAddReward omitted because SC2Switcher has no reward authority.'
    )
    Set-FileTextWithRetry -Path $Path -Text $text
}

function Patch-LiveTychusUiGuards {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $text = Get-Content -LiteralPath $Path -Raw

    $text = $text.Replace(
        '    libKCUI_gv_cU_TychusSquadBar[UnitGetOwner(lp_tychusBarUnit)] = lp_tychusBarUnit;',
        @'
    if ((lp_tychusBarUnit == null) || (UnitGetOwner(lp_tychusBarUnit) < 1) || (UnitGetOwner(lp_tychusBarUnit) > libKCOR_gv_cCC_MAXPLAYERS)) {
        return ;
    }
    libKCUI_gv_cU_TychusSquadBar[UnitGetOwner(lp_tychusBarUnit)] = lp_tychusBarUnit;
'@
    )

    $targetFramePattern = '(?s)    if \(\(lv_squadindex == -1\)\) \{\s+return ;\s+\}\s+libNtve_gf_SetDialogItemUnit\(libKCUI_gv_cU_TychusSquadUnitFrames\[lv_squadindex\]\[lp_player\], lp_targetUnit, PlayerGroupAll\(\)\);\s+libNtve_gf_SetDialogItemUnit\(libKCUI_gv_cU_TychusSquadUnitTargets\[lv_squadindex\]\[lp_player\], lp_targetUnit, PlayerGroupAll\(\)\);'
    $targetFrameReplacement = @'
    if ((lv_squadindex < 0) || (lv_squadindex >= libKCUI_gv_cUC_TYCHUS_MAX_SQUAD_SIZE) || (lp_player < 1) || (lp_player > libKCOR_gv_cCC_MAXPLAYERS)) {
        return ;
    }
    if ((libKCUI_gv_cU_TychusSquadUnitFrames[lv_squadindex][lp_player] <= 0) || (libKCUI_gv_cU_TychusSquadUnitTargets[lv_squadindex][lp_player] <= 0)) {
        return ;
    }

    libNtve_gf_SetDialogItemUnit(libKCUI_gv_cU_TychusSquadUnitFrames[lv_squadindex][lp_player], lp_targetUnit, PlayerGroupAll());
    libNtve_gf_SetDialogItemUnit(libKCUI_gv_cU_TychusSquadUnitTargets[lv_squadindex][lp_player], lp_targetUnit, PlayerGroupAll());
'@
    $newText = [regex]::Replace($text, $targetFramePattern, $targetFrameReplacement, 1)
    if ($newText -ne $text) {
        $text = $newText
    }

    Set-FileTextWithRetry -Path $Path -Text $text
}

function Patch-LiveAbathurBiomassScaleGuard {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $text = Get-Content -LiteralPath $Path -Raw
    $text = $text.Replace(
        '        ActorSendAsText(libNtve_gf_MainActorofUnit(lp_biomassUnit), TextExpressionAssemble("Param/Expression/lib_KMIS_AED708CF"));',
        '        // Codex local smoke test: skip actor scale message when the copied test map has no valid biomass actor info.'
    )
    $text = $text.Replace(
        '        ActorSendAsText(libNtve_gf_MainActorofUnit(lp_biomassUnit), TextExpressionAssemble("Param/Expression/lib_KMIS_139DC70E"));',
        '        // Codex local smoke test: skip actor scale message when the copied test map has no valid biomass actor info.'
    )
    Set-FileTextWithRetry -Path $Path -Text $text
}

function Patch-LiveAbathurCommanderBridge {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LibKPVPPath,
        [Parameter(Mandatory = $true)]
        [string]$LibKCORPath,
        [Parameter(Mandatory = $true)]
        [string]$LibKCUIPath,
        [Parameter(Mandatory = $true)]
        [string]$LibKMISPath
    )

    $kpvp = Get-Content -LiteralPath $LibKPVPPath -Raw
    $kpvp = $kpvp.Replace(
        '    if (auto9643C0DF_val == "ZergAbathur") {',
        '    if ((auto9643C0DF_val == "ZergAbathur") || (auto9643C0DF_val == "ZergAbathurReborn")) {'
    )
    $kpvp = $kpvp.Replace(
        '        if ((TechTreeUpgradeCount(lp_player, "AbathurCommander", c_techCountCompleteOnly) == 1)) {',
        '        if (((TechTreeUpgradeCount(lp_player, "AbathurCommander", c_techCountCompleteOnly) == 1) || (TechTreeUpgradeCount(lp_player, "AbathurRebornCommander", c_techCountCompleteOnly) == 1))) {'
    )
    Set-FileTextWithRetry -Path $LibKPVPPath -Text $kpvp

    $kcor = Get-Content -LiteralPath $LibKCORPath -Raw
    if ($kcor -notmatch 'ZergAbathurReborn') {
        $kcor = [regex]::Replace(
            $kcor,
            'else if \(autoBAA82F24_val == "ZergAbathur"\)\s*\{\s*return "char_Abathur";\s*\}',
            @'
else if (autoBAA82F24_val == "ZergAbathur") {
        return "char_Abathur";
    }
    else if (autoBAA82F24_val == "ZergAbathurReborn") {
        return "char_Abathur";
    }
'@,
            1
        )
        $kcor = [regex]::Replace(
            $kcor,
            'else if \(auto7BF4C060_val == "ZergAbathur"\)\s*\{\s*return "Abathur";\s*\}',
            @'
else if (auto7BF4C060_val == "ZergAbathur") {
        return "Abathur";
    }
    else if (auto7BF4C060_val == "ZergAbathurReborn") {
        return "Abathur";
    }
'@,
            1
        )
    }
    Set-FileTextWithRetry -Path $LibKCORPath -Text $kcor

    $kcui = Get-Content -LiteralPath $LibKCUIPath -Raw
    $kcui = [regex]::Replace(
        $kcui,
        'else if \(auto25C94ED4_val == "ZergAbathur"\)\s*\{\s*libKCUI_gf_CU_GPInitAbathur\(lp_player\);\s*\}',
        @'
else if (auto25C94ED4_val == "ZergAbathur") {
        libKCUI_gf_CU_GPInitAbathur(lp_player);
    }
    else if (auto25C94ED4_val == "ZergAbathurReborn") {
        libKCUI_gf_CU_GPInitAbathur(lp_player);
    }
'@,
        1
    )
    Set-FileTextWithRetry -Path $LibKCUIPath -Text $kcui

    $kmis = Get-Content -LiteralPath $LibKMISPath -Raw
    if ($kmis -notmatch 'libKMIS_gf_codex_is_abathur_commander') {
        $helperAnchor = "//--------------------------------------------------------------------------------------------------`r`n// Trigger: CM_Abathur_ToxicNestDeathFailsafe"
        if ($kmis -notlike "*$helperAnchor*") {
            $helperAnchor = "//--------------------------------------------------------------------------------------------------`n// Trigger: CM_Abathur_ToxicNestDeathFailsafe"
        }
        if ($kmis -notlike "*$helperAnchor*") {
            throw "Could not find Abathur helper insertion point in $LibKMISPath"
        }

        $helperBlock = @'
//--------------------------------------------------------------------------------------------------
bool libKMIS_gf_codex_is_abathur_commander (string lp_commander) {
    return ((lp_commander == "ZergAbathur") || (lp_commander == "ZergAbathurReborn"));
}

bool libKMIS_gf_codex_has_abathur_upgrade (int lp_player) {
    return ((TechTreeUpgradeCount(lp_player, "AbathurCommander", c_techCountCompleteOnly) == 1) || (TechTreeUpgradeCount(lp_player, "AbathurRebornCommander", c_techCountCompleteOnly) == 1));
}

playergroup libKMIS_gf_codex_abathur_players () {
    playergroup lv_players;

    lv_players = libKCOR_gf_CC_PlayersOfCommander("ZergAbathur");
    libNtve_gf_AddPlayerGroupToPlayerGroup(libKCOR_gf_CC_PlayersOfCommander("ZergAbathurReborn"), lv_players);
    return lv_players;
}

int libKMIS_gf_codex_first_abathur_player_in_group (playergroup lp_group) {
    int lv_player;

    lv_player = libKCOR_gf_CC_PlayerOfCommanderInGroupFirst("ZergAbathur", lp_group);
    if (lv_player <= 0) {
        lv_player = libKCOR_gf_CC_PlayerOfCommanderInGroupFirst("ZergAbathurReborn", lp_group);
    }
    return lv_player;
}

int libKMIS_gf_codex_first_abathur_player () {
    return libKMIS_gf_codex_first_abathur_player_in_group(libKMIS_gf_codex_abathur_players());
}

//--------------------------------------------------------------------------------------------------
'@
        $kmis = $kmis.Replace($helperAnchor, ($helperBlock + $helperAnchor))
    }

    $kmis = $kmis.Replace(
        '        else if (autoEB535506_val == "ZergAbathur") {',
        '        else if ((autoEB535506_val == "ZergAbathur") || (autoEB535506_val == "ZergAbathurReborn")) {'
    )
    $kmis = $kmis.Replace(
        '    auto55ADB699_g = libKCOR_gf_CC_PlayersOfCommander("ZergAbathur");',
        @'
    auto55ADB699_g = libKCOR_gf_CC_PlayersOfCommander("ZergAbathur");
    libNtve_gf_AddPlayerGroupToPlayerGroup(libKCOR_gf_CC_PlayersOfCommander("ZergAbathurReborn"), auto55ADB699_g);
'@
    )
    $kmis = $kmis.Replace(
        '        if (!((libKCOR_gf_ActiveCommanderForPlayer(UnitGetOwner(EventUnit())) == "ZergAbathur"))) {',
        '        if (!(libKMIS_gf_codex_is_abathur_commander(libKCOR_gf_ActiveCommanderForPlayer(UnitGetOwner(EventUnit()))))) {'
    )
    $kmis = $kmis.Replace(
        '    CatalogFieldValueModify(c_gameCatalogEffect, "BrutalizeDamage", "Amount", libKCOR_gf_CC_PlayerOfCommanderInGroupFirst("ZergAbathur", libKCOR_gf_CC_PlayersOfCommander("ZergAbathur")), "3", c_upgradeOperationAdd);',
        '    CatalogFieldValueModify(c_gameCatalogEffect, "BrutalizeDamage", "Amount", libKMIS_gf_codex_first_abathur_player(), "3", c_upgradeOperationAdd);'
    )
    $kmis = $kmis.Replace(
        '    CatalogFieldValueModify(c_gameCatalogWeapon, "Brutalize", "Level", libKCOR_gf_CC_PlayerOfCommanderInGroupFirst("ZergAbathur", libKCOR_gf_CC_PlayersOfCommander("ZergAbathur")), "1", c_upgradeOperationAdd);',
        '    CatalogFieldValueModify(c_gameCatalogWeapon, "Brutalize", "Level", libKMIS_gf_codex_first_abathur_player(), "1", c_upgradeOperationAdd);'
    )
    $kmis = $kmis.Replace(
        '        CatalogFieldValueSet(c_gameCatalogWeapon, "Brutalize", "Icon", libKCOR_gf_CC_PlayerOfCommanderInGroupFirst("ZergAbathur", libKCOR_gf_CC_PlayersOfCommander("ZergAbathur")), "Assets\\Textures\\btn-upgrade-zerg-meleeattacks-level1.dds");',
        '        CatalogFieldValueSet(c_gameCatalogWeapon, "Brutalize", "Icon", libKMIS_gf_codex_first_abathur_player(), "Assets\\Textures\\btn-upgrade-zerg-meleeattacks-level1.dds");'
    )
    $kmis = $kmis.Replace(
        '        CatalogFieldValueSet(c_gameCatalogWeapon, "Brutalize", "Icon", libKCOR_gf_CC_PlayerOfCommanderInGroupFirst("ZergAbathur", libKCOR_gf_CC_PlayersOfCommander("ZergAbathur")), "Assets\\Textures\\btn-upgrade-zerg-meleeattacks-level2.dds");',
        '        CatalogFieldValueSet(c_gameCatalogWeapon, "Brutalize", "Icon", libKMIS_gf_codex_first_abathur_player(), "Assets\\Textures\\btn-upgrade-zerg-meleeattacks-level2.dds");'
    )
    $kmis = $kmis.Replace(
        '        CatalogFieldValueSet(c_gameCatalogWeapon, "Brutalize", "Icon", libKCOR_gf_CC_PlayerOfCommanderInGroupFirst("ZergAbathur", libKCOR_gf_CC_PlayersOfCommander("ZergAbathur")), "Assets\\Textures\\btn-upgrade-zerg-meleeattacks-level3.dds");',
        '        CatalogFieldValueSet(c_gameCatalogWeapon, "Brutalize", "Icon", libKMIS_gf_codex_first_abathur_player(), "Assets\\Textures\\btn-upgrade-zerg-meleeattacks-level3.dds");'
    )
    $kmis = $kmis.Replace(
        '        if ((libKCOR_gf_ActiveCommanderForPlayer(lv_indexPlayer) == "ZergAbathur") && (libNtve_gf_PlayerIsEnemy(lv_indexPlayer, UnitGetOwner(EventUnit()), libNtve_ge_PlayerRelation_AllyMutual) == false) && (PlayerStatus(lv_indexPlayer) == c_playerStatusActive)) {',
        '        if (libKMIS_gf_codex_is_abathur_commander(libKCOR_gf_ActiveCommanderForPlayer(lv_indexPlayer)) && (libNtve_gf_PlayerIsEnemy(lv_indexPlayer, UnitGetOwner(EventUnit()), libNtve_ge_PlayerRelation_AllyMutual) == false) && (PlayerStatus(lv_indexPlayer) == c_playerStatusActive)) {'
    )
    $kmis = $kmis.Replace(
        '    TriggerAddEventPlayerEffectUsed(libKMIS_gt_CM_Abathur_BiomassPickup, c_playerAny, "BiomassPickupDummy");',
        @'
    TriggerAddEventPlayerEffectUsed(libKMIS_gt_CM_Abathur_BiomassPickup, c_playerAny, "BiomassPickupDummy");
    TriggerAddEventPlayerEffectUsed(libKMIS_gt_CM_Abathur_BiomassPickup, c_playerAny, "BiomassPickupDummyAbathurReborn");
'@
    )
    $kmis = $kmis.Replace(
        '(libKCOR_gf_ActiveCommanderForPlayer(lv_killedPlayer) == "ZergAbathur")',
        'libKMIS_gf_codex_is_abathur_commander(libKCOR_gf_ActiveCommanderForPlayer(lv_killedPlayer))'
    )
    $kmis = $kmis.Replace(
        '(libKCOR_gf_ActiveCommanderForPlayer(UnitGetOwner(EventUnit())) == "ZergAbathur")',
        'libKMIS_gf_codex_is_abathur_commander(libKCOR_gf_ActiveCommanderForPlayer(UnitGetOwner(EventUnit())))'
    )
    $kmis = $kmis.Replace(
        '((libNtve_gf_TriggeringProgressUnitType() == "RavagerAbathur") || (libNtve_gf_TriggeringProgressUnitType() == "GuardianMP") || (libNtve_gf_TriggeringProgressUnitType() == "Devourer"))',
        '((libNtve_gf_TriggeringProgressUnitType() == "RavagerAbathur") || (libNtve_gf_TriggeringProgressUnitType() == "GuardianMP") || (libNtve_gf_TriggeringProgressUnitType() == "Devourer") || (libNtve_gf_TriggeringProgressUnitType() == "RavagerAbathurReborn") || (libNtve_gf_TriggeringProgressUnitType() == "GuardianMPAbathurReborn") || (libNtve_gf_TriggeringProgressUnitType() == "DevourerAbathurReborn"))'
    )
    $kmis = $kmis.Replace(
        '    lv_abathurAllyOfKillingPlayer = libKCOR_gf_CC_PlayerOfCommanderInGroupFirst("ZergAbathur", libKCOR_gf_MutualAlliedCommandersofPlayerCoutInactiveAndSelf(libNtve_gf_KillingPlayer()));',
        '    lv_abathurAllyOfKillingPlayer = libKMIS_gf_codex_first_abathur_player_in_group(libKCOR_gf_MutualAlliedCommandersofPlayerCoutInactiveAndSelf(libNtve_gf_KillingPlayer()));'
    )
    $kmis = $kmis.Replace(
        '        if (!((TechTreeUpgradeCount(EventPlayer(), "AbathurCommander", c_techCountCompleteOnly) == 1))) {',
        '        if (!(libKMIS_gf_codex_has_abathur_upgrade(EventPlayer()))) {'
    )
    $kmis = $kmis.Replace(
        @'
    lv_casterPlayer = UnitGetOwner(EventUnit());
    if ((UnitAbilityChargeInfo(EventUnit(), AbilityCommand("SpawnToxicNest", 0), c_unitAbilChargeCountLeft) > 0.0)) {
        UISetTargetingOrder(PlayerGroupSingle(lv_casterPlayer), libKMIS_gv_cM_GlobalCasterUnitGroup[lv_casterPlayer], OrderTargetingPoint(AbilityCommand("SpawnToxicNest", 0), UnitGetPosition(libKMIS_gv_cM_GlobalCasterUnit[lv_casterPlayer])), false);
    }
'@,
        @'
    lv_casterPlayer = UnitGetOwner(EventUnit());
    if (libKMIS_gf_codex_is_abathur_commander(libKCOR_gf_ActiveCommanderForPlayer(lv_casterPlayer)) && (UnitAbilityChargeInfo(EventUnit(), AbilityCommand("SpawnToxicNestAbathurReborn", 0), c_unitAbilChargeCountLeft) > 0.0)) {
        UISetTargetingOrder(PlayerGroupSingle(lv_casterPlayer), libKMIS_gv_cM_GlobalCasterUnitGroup[lv_casterPlayer], OrderTargetingPoint(AbilityCommand("SpawnToxicNestAbathurReborn", 0), UnitGetPosition(libKMIS_gv_cM_GlobalCasterUnit[lv_casterPlayer])), false);
    }
    else if ((UnitAbilityChargeInfo(EventUnit(), AbilityCommand("SpawnToxicNest", 0), c_unitAbilChargeCountLeft) > 0.0)) {
        UISetTargetingOrder(PlayerGroupSingle(lv_casterPlayer), libKMIS_gv_cM_GlobalCasterUnitGroup[lv_casterPlayer], OrderTargetingPoint(AbilityCommand("SpawnToxicNest", 0), UnitGetPosition(libKMIS_gv_cM_GlobalCasterUnit[lv_casterPlayer])), false);
    }
'@
    )
    $kmis = $kmis.Replace(
        '    TriggerAddEventUnitAbility(libKMIS_gt_CM_Abathur_ToxicNest, null, AbilityCommand("SpawnToxicNest", 0), c_unitAbilStageAll, false);',
        @'
    TriggerAddEventUnitAbility(libKMIS_gt_CM_Abathur_ToxicNest, null, AbilityCommand("SpawnToxicNest", 0), c_unitAbilStageAll, false);
    TriggerAddEventUnitAbility(libKMIS_gt_CM_Abathur_ToxicNest, null, AbilityCommand("SpawnToxicNestAbathurReborn", 0), c_unitAbilStageAll, false);
'@
    )
    $kmis = $kmis.Replace(
        '    TriggerAddEventPlayerEffectUsed(libKMIS_gt_CM_Abathur_SwarmHostLocustLaunchCast, c_playerAny, "LocustCreateSet");',
        @'
    TriggerAddEventPlayerEffectUsed(libKMIS_gt_CM_Abathur_SwarmHostLocustLaunchCast, c_playerAny, "LocustCreateSet");
    TriggerAddEventPlayerEffectUsed(libKMIS_gt_CM_Abathur_SwarmHostLocustLaunchCast, c_playerAny, "AbathurRebornLocustCreateSet");
'@
    )
    $kmis = $kmis.Replace(
        @'
    lv_cooldown = UnitAbilityGetCooldown(lv_unit, "RavagerAbathurCorrosiveBile", "Abil/RavagerAbathurCorrosiveBile");
    lv_multiplier = UnitWeaponSpeedMultiplier(lv_unit, 1);
    UnitAbilityReset(lv_unit, AbilityCommand("RavagerAbathurCorrosiveBile", 0), c_spendLocationAll);
    UnitAbilityAddCooldown(lv_unit, "RavagerAbathurCorrosiveBile", "Abil/RavagerAbathurCorrosiveBile", (lv_cooldown*lv_multiplier));
'@,
        @'
    if (libKMIS_gf_codex_is_abathur_commander(libKCOR_gf_ActiveCommanderForPlayer(UnitGetOwner(lv_unit)))) {
        lv_cooldown = UnitAbilityGetCooldown(lv_unit, "RavagerAbathurCorrosiveBileLegacyAbathurReborn", "Abil/RavagerAbathurCorrosiveBileLegacyAbathurReborn");
        lv_multiplier = UnitWeaponSpeedMultiplier(lv_unit, 1);
        UnitAbilityReset(lv_unit, AbilityCommand("RavagerAbathurCorrosiveBileLegacyAbathurReborn", 0), c_spendLocationAll);
        UnitAbilityAddCooldown(lv_unit, "RavagerAbathurCorrosiveBileLegacyAbathurReborn", "Abil/RavagerAbathurCorrosiveBileLegacyAbathurReborn", (lv_cooldown*lv_multiplier));
    }
    else {
        lv_cooldown = UnitAbilityGetCooldown(lv_unit, "RavagerAbathurCorrosiveBile", "Abil/RavagerAbathurCorrosiveBile");
        lv_multiplier = UnitWeaponSpeedMultiplier(lv_unit, 1);
        UnitAbilityReset(lv_unit, AbilityCommand("RavagerAbathurCorrosiveBile", 0), c_spendLocationAll);
        UnitAbilityAddCooldown(lv_unit, "RavagerAbathurCorrosiveBile", "Abil/RavagerAbathurCorrosiveBile", (lv_cooldown*lv_multiplier));
    }
'@
    )
    $kmis = $kmis.Replace(
        '    TriggerAddEventPlayerEffectUsed(libKMIS_gt_CM_Abathur_RavagerSpellCooldown, c_playerAny, "RavagerCorrosiveBileAoeLaunchSet");',
        @'
    TriggerAddEventPlayerEffectUsed(libKMIS_gt_CM_Abathur_RavagerSpellCooldown, c_playerAny, "RavagerCorrosiveBileAoeLaunchSet");
    TriggerAddEventPlayerEffectUsed(libKMIS_gt_CM_Abathur_RavagerSpellCooldown, c_playerAny, "RavagerCorrosiveBileAoeLaunchSetAbathurReborn");
'@
    )
    Set-FileTextWithRetry -Path $LibKMISPath -Text $kmis
}

function Validate-LiveAbathurRebornInstall {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MapLive,
        [Parameter(Mandatory = $true)]
        [string]$ExtensionLive,
        [Parameter(Mandatory = $true)]
        [string]$PatchLive
    )

    $mapInfo = Get-Content -LiteralPath (Join-Path $MapLive "DocumentInfo") -Raw
    $mapDependencies = Get-DocumentInfoDependencies -Path (Join-Path $MapLive "DocumentInfo")
    $patchInfo = Get-Content -LiteralPath (Join-Path $PatchLive "DocumentInfo") -Raw
    $kpvp = Get-Content -LiteralPath (Join-Path $ExtensionLive "Base.SC2Data\LibKPVP.galaxy") -Raw
    $kcor = Get-Content -LiteralPath (Join-Path $ExtensionLive "Base.SC2Data\LibKCOR.galaxy") -Raw
    $kcui = Get-Content -LiteralPath (Join-Path $ExtensionLive "Base.SC2Data\LibKCUI.galaxy") -Raw
    $kmis = Get-Content -LiteralPath (Join-Path $ExtensionLive "Base.SC2Data\LibKMIS.galaxy") -Raw

    foreach ($required in @(
        'file:Mods/7vs1/CoopZeroPop.SC2Mod',
        'file:Mods/7vs1/CommanderCatalog.SC2Mod',
        'file:Mods/7vs1/7v1AbathurRebornPatch.SC2Mod'
    )) {
        if (-not $mapInfo.Contains($required)) {
            throw "Live map dependency missing: $required"
        }
    }

    foreach ($required in @(
        'file:Mods/7vs1/CoopZeroPop.SC2Mod',
        'bnet:Co-op Mission/0.0/999,file:Mods/StarCoop/StarCoop.SC2Mod'
    )) {
        if (-not $patchInfo.Contains($required)) {
            throw "Live patch dependency missing: $required"
        }
    }

    foreach ($pair in @(
        @{Name='LibKPVP'; Text=$kpvp; Needle='ZergAbathurReborn'},
        @{Name='LibKCOR'; Text=$kcor; Needle='ZergAbathurReborn'},
        @{Name='LibKCUI'; Text=$kcui; Needle='ZergAbathurReborn'},
        @{Name='LibKMIS'; Text=$kmis; Needle='AbathurRebornCommander'},
        @{Name='LibKMIS'; Text=$kmis; Needle='BiomassPickupDummyAbathurReborn'},
        @{Name='LibKMIS'; Text=$kmis; Needle='RavagerCorrosiveBileAoeLaunchSetAbathurReborn'}
    )) {
        if (-not $pair.Text.Contains($pair.Needle)) {
            throw "$($pair.Name) bridge missing: $($pair.Needle)"
        }
    }
}

function Validate-LiveBaseTestlineInstall {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MapLive,
        [Parameter(Mandatory = $true)]
        [string]$ExtensionLive
    )

    $mapInfo = Get-Content -LiteralPath (Join-Path $MapLive "DocumentInfo") -Raw
    $mapDependencies = Get-DocumentInfoDependencies -Path (Join-Path $MapLive "DocumentInfo")
    $kpvp = Get-Content -LiteralPath (Join-Path $ExtensionLive "Base.SC2Data\LibKPVP.galaxy") -Raw

    if (-not $mapInfo.Contains('file:Mods/7vs1/CoopZeroPop.SC2Mod')) {
        throw 'Live base testline dependency missing: file:Mods/7vs1/CoopZeroPop.SC2Mod'
    }
    if (-not $mapInfo.Contains('file:Mods/7vs1/CommanderCatalog.SC2Mod')) {
        throw 'Live base testline dependency missing: file:Mods/7vs1/CommanderCatalog.SC2Mod'
    }

    Assert-NoUnsupportedWorkspaceDependency -Dependencies $mapDependencies -DependencyOwner "live map DocumentInfo"

    $hasSecondaryDependency = $false
    foreach ($marker in @(
        'file:Campaigns/LibertyStory.SC2Campaign',
        'file:Campaigns/Void.SC2Campaign',
        'file:Mods/Liberty.SC2Mod',
        'file:Mods/VoidMulti.SC2Mod'
    )) {
        if ($mapInfo.Contains($marker)) {
            $hasSecondaryDependency = $true
            break
        }
    }

    if (-not $hasSecondaryDependency) {
        throw 'Live base testline dependency closure missing a map-side runtime dependency beyond CoopZeroPop.'
    }

    if ($kpvp.Contains('libKPVP_gf_codex_init_7vs1_test_commanders') -eq $false) {
        throw 'Live base testline missing commander test override.'
    }
}

function Set-AbathurRebornPatchProfile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PatchRoot,
        [Parameter(Mandatory = $true)]
        [string]$Profile
    )

    if ($Profile -eq "Full") {
        return
    }

    $gameDataRoot = Join-Path $PatchRoot "Base.SC2Data\GameData"
    if (-not (Test-Path -LiteralPath $gameDataRoot)) {
        throw "Abathur patch GameData directory not found: $gameDataRoot"
    }

    $keep = @("GameData.xml")
    if ($Profile -eq "NoVisuals") {
        $keep += @(
            "AbilData.xml",
            "BehaviorData.xml",
            "ButtonData.xml",
            "CommanderData.xml",
            "EffectData.xml",
            "RequirementData.xml",
            "RequirementNodeData.xml",
            "UnitData.xml",
            "UpgradeData.xml",
            "UserData.xml",
            "ValidatorData.xml",
            "WeaponData.xml"
        )
    }
    elseif ($Profile -eq "CoreOnly") {
        $keep += @(
            "AbilData.xml",
            "ButtonData.xml",
            "CommanderData.xml",
            "EffectData.xml",
            "RequirementData.xml",
            "RequirementNodeData.xml",
            "UnitData.xml",
            "UpgradeData.xml",
            "UserData.xml",
            "ValidatorData.xml"
        )
    }
    else {
        throw "Unknown Abathur patch profile: $Profile"
    }

    foreach ($file in Get-ChildItem -LiteralPath $gameDataRoot -File) {
        if ($keep -contains $file.Name) {
            continue
        }
        Remove-Item -LiteralPath $file.FullName -Force
    }
}

function Save-XmlDocument {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument]$Document,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try {
        $Document.Save($writer)
    }
    finally {
        $writer.Close()
    }
}

function Get-OrCreateCatalogXml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    [xml]$xml = New-Object System.Xml.XmlDocument
    if (Test-Path -LiteralPath $Path) {
        $xml.Load($Path)
    }
    else {
        $declaration = $xml.CreateXmlDeclaration("1.0", "utf-8", $null)
        [void]$xml.AppendChild($declaration)
        [void]$xml.AppendChild($xml.CreateElement("Catalog"))
    }

    if ($null -eq $xml.Catalog) {
        throw "Expected Catalog root in $Path"
    }

    return $xml
}

function Merge-CatalogEntriesById {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceGameData,
        [Parameter(Mandatory = $true)]
        [string]$LiveGameData,
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        [Parameter(Mandatory = $true)]
        [string[]]$Ids
    )

    $sourcePath = Join-Path $SourceGameData $FileName
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Source catalog not found: $sourcePath"
    }

    $livePath = Join-Path $LiveGameData $FileName
    $liveParent = Split-Path -Parent $livePath
    if (-not (Test-Path -LiteralPath $liveParent)) {
        New-Item -ItemType Directory -Path $liveParent -Force | Out-Null
    }

    [xml]$sourceXml = Get-Content -LiteralPath $sourcePath -Raw
    if ($null -eq $sourceXml.Catalog) {
        throw "Expected Catalog root in $sourcePath"
    }

    $liveXml = Get-OrCreateCatalogXml -Path $livePath
    foreach ($id in $Ids) {
        $escapedId = $id.Replace("'", "&apos;")
        $sourceNode = $sourceXml.SelectSingleNode("/Catalog/*[@id='$escapedId']")
        if ($null -eq $sourceNode) {
            throw "Catalog id '$id' not found in $sourcePath"
        }

        $existing = $liveXml.SelectSingleNode("/Catalog/*[@id='$escapedId']")
        $imported = $liveXml.ImportNode($sourceNode, $true)
        if ($null -ne $existing) {
            [void]$liveXml.DocumentElement.ReplaceChild($imported, $existing)
        }
        else {
            [void]$liveXml.DocumentElement.AppendChild($imported)
        }
    }

    Save-XmlDocument -Document $liveXml -Path $livePath
}

function Normalize-LiveKelMorianWorkerUnitData {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiveGameData
    )

    $unitDataPath = Join-Path $LiveGameData "UnitData.xml"
    if (-not (Test-Path -LiteralPath $unitDataPath)) {
        throw "Live UnitData not found: $unitDataPath"
    }

    [xml]$unitXml = Get-Content -LiteralPath $unitDataPath -Raw
    $worker = $unitXml.SelectSingleNode('/Catalog/CUnit[@id="KelMorianWorker"]')
    if ($null -eq $worker) {
        throw "KelMorianWorker not found in $unitDataPath"
    }

    foreach ($link in @("stop", "move", "TerranBuild")) {
        $nodes = @($worker.SelectNodes("AbilArray[@Link='$link']"))
        foreach ($node in $nodes) {
            [void]$worker.RemoveChild($node)
        }
    }

    foreach ($link in @("KelMorianWorkerRepair", "KelMorianWorkerBuild")) {
        if ($null -eq $worker.SelectSingleNode("AbilArray[@Link='$link']")) {
            $ability = $unitXml.CreateElement("AbilArray")
            [void]$ability.SetAttribute("Link", $link)
            [void]$worker.InsertBefore($ability, $worker.SelectSingleNode("CardLayouts"))
        }
    }

    Save-XmlDocument -Document $unitXml -Path $unitDataPath
}

function Patch-LiveSwannKelMorianWorkerData {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceGameData,
        [Parameter(Mandatory = $true)]
        [string]$LiveGameData
    )

    if (-not (Test-Path -LiteralPath $SourceGameData)) {
        throw "Swann source GameData not found: $SourceGameData"
    }

    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "UnitData.xml" -Ids @("KelMorianWorker")
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "AbilData.xml" -Ids @("KelMorianWorkerRepair", "KelMorianWorkerBuild")
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "EffectData.xml" -Ids @("KelMorianWorkerRepair")
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "BehaviorData.xml" -Ids @("KelMorianWorkerCloak")
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "ValidatorData.xml" -Ids @("HaveSwannCommanderWorkerCloak")
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "ButtonData.xml" -Ids @(
        "BuildKelMorianMissileTurret",
        "PermanentlyCloakedKelMorianWorker",
        "KelMorianAssist",
        "BuildDrakkenLaserDrill",
        "BuildLaserTurret",
        "BuildKelMorianRocketTurret",
        "TrainKelMorianWorkers"
    )
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "RequirementData.xml" -Ids @(
        "HaveAdvancedConstruction",
        "HaveSwannCommander",
        "HaveSwannCommanderKelMorianWorkerCloak",
        "HaveSwannCommanderKelMorianWorkerRocketTurret",
        "DrakkenLaserRequirements"
    )
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "RequirementNodeData.xml" -Ids @(
        "CountUpgradeAdvancedConstructionCompleteOnly",
        "CountUpgradeSwannCommanderCompleteOnly",
        "CountUpgradeSwannCommanderKelMorianWorkerRocketTurretCompleteOnly",
        "CountUpgradeSwannCommanderWorkerCloakCompleteOnly"
    )
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "UpgradeData.xml" -Ids @(
        "AdvancedConstruction",
        "SwannCommanderKelMorianWorkerRocketTurret"
    )
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "ModelData.xml" -Ids @("KelMorianWorker")
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "ActorData.xml" -Ids @("KelMorianWorker", "KelMorianWorkerDropModel")
    Normalize-LiveKelMorianWorkerUnitData -LiveGameData $LiveGameData
}

function Set-LiveCommanderTestOverride {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LibPath,
        [Parameter(Mandatory = $true)]
        [string[]]$SelectedCommanders,
        [string]$TestSpawnPreset = ""
    )

    if (($SelectedCommanders.Count -lt 1) -or ($SelectedCommanders.Count -gt 7)) {
        throw "Expected 1-7 commanders. Got $($SelectedCommanders.Count)."
    }

    $known = @(
        "ZergAbathur",
        "ZergAbathurReborn",
        "ProtossAlarak",
        "ProtossArtanis",
        "ZergDehaka",
        "ProtossFenix",
        "TerranHorner",
        "ProtossKarax",
        "ZergKerrigan",
        "TerranMengsk",
        "TerranNova",
        "TerranRaynor",
        "ZergStetmann",
        "ZergStukov",
        "TerranSwann",
        "TerranTychus",
        "ProtossVorazun",
        "ZergZagara",
        "ProtossZeratul"
    )

    foreach ($commander in $SelectedCommanders) {
        if ($known -notcontains $commander) {
            throw "Unknown commander '$commander'. Known commanders: $($known -join ', ')"
        }
    }

    $text = Get-Content -LiteralPath $LibPath -Raw
    if ($text -match "libKPVP_gf_codex_init_7vs1_test_commanders") {
        return
    }

    $functionBlock = New-Object System.Text.StringBuilder
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("//--------------------------------------------------------------------------------------------------")
    [void]$functionBlock.AppendLine("// Codex live test override: initialize local test commanders without Battle.net lobby attrs.")
    [void]$functionBlock.AppendLine("//--------------------------------------------------------------------------------------------------")
    [void]$functionBlock.AppendLine("void libKPVP_gf_codex_add_special_groups (string lp_commander, int lp_player) {")
    [void]$functionBlock.AppendLine("    if (lp_commander == `"ZergAbathur`") {")
    [void]$functionBlock.AppendLine("        PlayerGroupAdd(libKPVP_gv_abathur_players, lp_player);")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_commander == `"ZergDehaka`") {")
    [void]$functionBlock.AppendLine("        PlayerGroupAdd(libKPVP_gv_dehaka_players, lp_player);")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_commander == `"TerranHorner`") {")
    [void]$functionBlock.AppendLine("        libNtve_gf_AddPlayerGroupToPlayerGroup(libNtve_gf_AlliesEnemiesOfPlayerCountInactiveAndSelf(libNtve_ge_PlayerRelation_AllyMutual, lp_player), libKPVP_gv_han_allies);")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_commander == `"TerranMengsk`") {")
    [void]$functionBlock.AppendLine("        PlayerGroupAdd(libKPVP_gv_mengsk_players, lp_player);")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_commander == `"TerranTychus`") {")
    [void]$functionBlock.AppendLine("        PlayerGroupAdd(libKPVP_gv_tychus_players, lp_player);")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("}")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("void libKPVP_gf_codex_apply_swann_worker_tech (int lp_player) {")
    [void]$functionBlock.AppendLine("    int lv_build;")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("    libNtve_gf_SetUpgradeLevelForPlayer(lp_player, `"SwannCommander`", 1);")
    [void]$functionBlock.AppendLine("    libNtve_gf_SetUpgradeLevelForPlayer(lp_player, `"CommanderLevel`", 15);")
    [void]$functionBlock.AppendLine("    TechTreeAbilityAllow(lp_player, AbilityCommand(`"KelMorianWorkerBuild`", 0), true);")
    [void]$functionBlock.AppendLine("    lv_build = 1;")
    [void]$functionBlock.AppendLine("    while (lv_build <= 24) {")
    [void]$functionBlock.AppendLine("        TechTreeAbilityAllow(lp_player, AbilityCommand(`"KelMorianWorkerBuild`", lv_build), true);")
    [void]$functionBlock.AppendLine("        lv_build = lv_build + 1;")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    TechTreeAbilityAllow(lp_player, AbilityCommand(`"KelMorianWorkerRepair`", 0), true);")
    [void]$functionBlock.AppendLine("    TechTreeAbilityAllow(lp_player, AbilityCommand(`"AdvancedConstructionAuto`", 0), true);")
    [void]$functionBlock.AppendLine("    UIDisplayMessage(PlayerGroupSingle(lp_player), c_messageAreaChat, StringToText((`"Codex test init: TerranSwann KelMorianWorker tech enabled. Workers=`" + IntToString(UnitGroupCount(UnitGroup(`"KelMorianWorker`", lp_player, RegionEntireMap(), UnitFilter(0, 0, (1 << c_targetFilterMissile), (1 << (c_targetFilterDead - 32)) | (1 << (c_targetFilterHidden - 32))), 0), c_unitCountAlive)))));")
    [void]$functionBlock.AppendLine("}")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("void libKPVP_gf_codex_abathur_apply_full_biomass (unit lp_unit, int lp_player, int lp_stack) {")
    [void]$functionBlock.AppendLine("    if (lp_unit == null) {")
    [void]$functionBlock.AppendLine("        return;")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    libKMIS_gf_CM_Abathur_BiomassSetStack(lp_unit, lp_stack);")
    [void]$functionBlock.AppendLine("    libKMIS_gf_CM_Abathur_BiomassScale(lp_unit, true);")
    [void]$functionBlock.AppendLine("    libKMIS_gf_CM_Abathur_BiomassMerge(lp_unit, lp_stack);")
    [void]$functionBlock.AppendLine("}")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("void libKPVP_gf_codex_spawn_abathur_fusion_units (int lp_player) {")
    [void]$functionBlock.AppendLine("    point lv_start;")
    [void]$functionBlock.AppendLine("    unit lv_unit;")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("    lv_start = libKPVP_gf_codex_start_point(lp_player);")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("    libNtve_gf_CreateUnitsWithDefaultFacing(1, `"BrutaliskAbathur`", c_unitCreateIgnorePlacement, lp_player, Point(PointGetX(lv_start) + 10.0, PointGetY(lv_start) + 6.0));")
    [void]$functionBlock.AppendLine("    lv_unit = UnitLastCreated();")
    [void]$functionBlock.AppendLine("    libKPVP_gf_codex_abathur_apply_full_biomass(lv_unit, lp_player, 200);")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("    libNtve_gf_CreateUnitsWithDefaultFacing(1, `"LeviathanAbathur`", c_unitCreateIgnorePlacement, lp_player, Point(PointGetX(lv_start) + 14.0, PointGetY(lv_start) + 10.0));")
    [void]$functionBlock.AppendLine("    lv_unit = UnitLastCreated();")
    [void]$functionBlock.AppendLine("    libKPVP_gf_codex_abathur_apply_full_biomass(lv_unit, lp_player, 200);")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("    libNtve_gf_CreateUnitsWithDefaultFacing(1, `"RavagerAbathur`", c_unitCreateIgnorePlacement, lp_player, Point(PointGetX(lv_start) + 6.0, PointGetY(lv_start) + 12.0));")
    [void]$functionBlock.AppendLine("    lv_unit = UnitLastCreated();")
    [void]$functionBlock.AppendLine("    libKPVP_gf_codex_abathur_apply_full_biomass(lv_unit, lp_player, 200);")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("    libNtve_gf_CreateUnitsWithDefaultFacing(1, `"MutaliskAbathur`", c_unitCreateIgnorePlacement, lp_player, Point(PointGetX(lv_start) + 2.0, PointGetY(lv_start) + 14.0));")
    [void]$functionBlock.AppendLine("    lv_unit = UnitLastCreated();")
    [void]$functionBlock.AppendLine("    libKPVP_gf_codex_abathur_apply_full_biomass(lv_unit, lp_player, 200);")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("    UIDisplayMessage(PlayerGroupSingle(lp_player), c_messageAreaChat, StringToText(`"Codex test init: Abathur fusion verification units spawned.`"));")
    [void]$functionBlock.AppendLine("}")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("void libKPVP_gf_codex_run_test_spawn_preset (int lp_player, string lp_commander) {")
    if ($TestSpawnPreset -eq "AbathurFusion") {
        [void]$functionBlock.AppendLine("    if (lp_commander == `"ZergAbathur`") {")
        [void]$functionBlock.AppendLine("        libKPVP_gf_codex_spawn_abathur_fusion_units(lp_player);")
        [void]$functionBlock.AppendLine("    }")
    }
    [void]$functionBlock.AppendLine("}")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("void libKPVP_gf_codex_init_test_player (int lp_player, string lp_commander) {")
    [void]$functionBlock.AppendLine("    libKPVP_gf_reset_skins_for_player(lp_player);")
    [void]$functionBlock.AppendLine("    libKPVP_gv_players_names[lp_player] = PlayerName(lp_player);")
    [void]$functionBlock.AppendLine("    libKPVP_gf_set_commander_for_player(lp_commander, lp_player);")
    [void]$functionBlock.AppendLine("    libKPVP_gf_codex_add_special_groups(lp_commander, lp_player);")
    [void]$functionBlock.AppendLine("    if (lp_commander == `"TerranSwann`") {")
    [void]$functionBlock.AppendLine("        libKPVP_gf_codex_apply_swann_worker_tech(lp_player);")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    if (lp_commander == `"TerranSwann`") {")
        [void]$functionBlock.AppendLine("        libKPVP_gf_codex_apply_swann_worker_tech(lp_player);")
    [void]$functionBlock.AppendLine("    }")
    if (-not [string]::IsNullOrWhiteSpace($TestSpawnPreset)) {
        [void]$functionBlock.AppendLine("    libKPVP_gf_codex_run_test_spawn_preset(lp_player, lp_commander);")
    }
    [void]$functionBlock.AppendLine("}")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("void libKPVP_gf_codex_init_7vs1_test_commanders () {")
    for ($i = 0; $i -lt $SelectedCommanders.Count; $i++) {
        $player = $i + 1
        [void]$functionBlock.AppendLine("    libKPVP_gf_codex_init_test_player($player, `"$($SelectedCommanders[$i])`");")
    }
    [void]$functionBlock.AppendLine("}")

    $insertBefore = "//--------------------------------------------------------------------------------------------------`r`nvoid libKPVP_gt_player_defeated_Init"
    if ($text -notlike "*$insertBefore*") {
        $insertBefore = "//--------------------------------------------------------------------------------------------------`nvoid libKPVP_gt_player_defeated_Init"
    }
    if ($text -notlike "*$insertBefore*") {
        throw "Could not find insertion point for test commander function in $LibPath"
    }
    $text = $text.Replace($insertBefore, ($functionBlock.ToString() + $insertBefore))

    $pattern = '(?s)autoEE3370AE_g = PlayerGroupActive\(\);\s+lv_player = -1;\s+while \(true\) \{.*?\n\s+\}\s+UnitEventSetNullVariableInvalid\(true\);'
    $replacement = "lv_with_random_ai = false;`r`n    autoEE3370AE_g = PlayerGroupActive();`r`n    libKPVP_gf_codex_init_7vs1_test_commanders();`r`n    UnitEventSetNullVariableInvalid(true);"
    $newText = [regex]::Replace($text, $pattern, $replacement, 1)
    if ($newText -eq $text) {
        throw "Could not replace original commander selection loop in $LibPath"
    }

    Set-FileTextWithRetry -Path $LibPath -Text $newText
}

function Stop-RunningSc2 {
    $processNames = @("SC2_x64", "SC2Switcher_x64", "BlizzardError")

    foreach ($processName in $processNames) {
        $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if (-not $running) {
            continue
        }

        foreach ($proc in $running) {
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

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Resolve-DefaultSourceRoot
}

if ([string]::IsNullOrWhiteSpace($SwitcherPath)) {
    $SwitcherPath = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
}

if ([string]::IsNullOrWhiteSpace($MapSource)) {
    $mapSource = Resolve-DefaultMapSource
}
else {
    $mapSource = Resolve-WorkspacePath -Path $MapSource
}
$effectiveStartPoints = Resolve-StartPoints -Preset $StartPointPreset -MapSource $mapSource -LiveMapName $LiveMapName
$effectiveStartPointLabel = if ($StartPointPreset -ne "Auto") {
    $StartPointPreset
}
elseif (([System.IO.Path]::GetFileName($mapSource) -like "ttosh02*") -or ($LiveMapName -like "ttosh02*")) {
    "JungleTtosh02"
}
else {
    "Default+Objects"
}
$extensionSource = Resolve-ExtensionSource -SourceRoot $SourceRoot
$abathurRebornPatchSource = Resolve-AbathurRebornPatchSource
$commanderCatalogSource = Resolve-CommanderCatalogSource
$swannSourceGameData = Resolve-SwannSourceGameData -SourceRoot $SourceRoot
$mapLive = Join-Path (Join-Path $Sc2Root "Maps\7vs1") $LiveMapName
$extensionLive = Join-Path $Sc2Root "Mods\7vs1\CoopZeroPop.SC2Mod"
$abathurRebornPatchLive = Join-Path $Sc2Root "Mods\7vs1\7v1AbathurRebornPatch.SC2Mod"

if (-not (Test-Path -LiteralPath $SwitcherPath)) {
    throw "SwitcherPath not found: $SwitcherPath"
}
if (-not (Test-Path -LiteralPath $commanderCatalogSource)) {
    throw "CommanderCatalog source not found: $commanderCatalogSource"
}

$defaultCommanderSlots = Resolve-CommanderPreset -Name $Preset
$explicitCommanders = ($Commanders.Count -gt 0)

if ($Commanders.Count -eq 0) {
    $Commanders = @($defaultCommanderSlots)
}

if ($effectiveStartPointLabel -eq "JungleTtosh02") {
    if (-not $explicitCommanders) {
        $Commanders = @($Commanders[0])
    }
    elseif ($Commanders.Count -ne 1) {
        throw "ttosh02_7vs1 keeps the original mission enemy slots. Test exactly one commander at a time, for example: -Commanders @('TerranSwann')."
    }
}

if (($Commanders.Count -lt 1) -or ($Commanders.Count -gt 7)) {
    throw "Expected 1-7 commanders. Got $($Commanders.Count)."
}

$effectiveCommanders = @($Commanders)
$useAbathurBiomassGuard = ($effectiveCommanders -contains "ZergAbathur") -or ($effectiveCommanders -contains "ZergAbathurReborn")

if ($DisableAbathurRebornPatch) {
    foreach ($commander in $effectiveCommanders) {
        if ($commander -eq "ZergAbathurReborn") {
            throw "DisableAbathurRebornPatch cannot be used with ZergAbathurReborn selected."
        }
    }
}

$useAbathurRebornPatch = (-not $DisableAbathurRebornPatch) -and ($effectiveCommanders -contains "ZergAbathurReborn")

if (-not $SkipCommanderPowerPreset) {
    Set-CampaignXCoreCommanderPowerPreset `
        -SelectedCommanders $effectiveCommanders `
        -Profile $CommanderPowerProfile `
        -PrestigeBonusMask $CommanderPowerPrestigeBonusMask `
        -PrestigePointIndex $CommanderPowerPrestigePointIndex `
        -EnablePrestiges $CommanderPowerEnablePrestiges `
        -EnableMasteries $CommanderPowerEnableMasteries `
        -MasteryLevel $CommanderPowerMasteryLevel `
        -Mastery0 $CommanderPowerMastery0 `
        -Mastery1 $CommanderPowerMastery1 `
        -Mastery2 $CommanderPowerMastery2 `
        -Mastery3 $CommanderPowerMastery3 `
        -Mastery4 $CommanderPowerMastery4 `
        -Mastery5 $CommanderPowerMastery5 `
        -PresetPath $CommanderPowerPresetPath `
        -Overrides $CommanderPowerOverride
}

if ($ForceStopSc2BeforeInstall -or (-not $NoLaunch)) {
    Stop-RunningSc2
}

Copy-DirectoryClean -Source $mapSource -Destination $mapLive
Copy-DirectoryClean -Source $extensionSource -Destination $extensionLive
if ($useAbathurRebornPatch) {
    Copy-DirectoryClean -Source $abathurRebornPatchSource -Destination $abathurRebornPatchLive
    Set-AbathurRebornPatchProfile -PatchRoot $abathurRebornPatchLive -Profile $AbathurPatchProfile
}

$extensionDependencies = @(
    "bnet:Void Multi (Mod)/0.0/999,file:Mods/VoidMulti.SC2Mod",
    "bnet:Co-op Mission/0.0/999,file:Mods/StarCoop/StarCoop.SC2Mod"
)
$abathurRebornPatchDependencies = @(
    "bnet:Void Multi (Mod)/0.0/999,file:Mods/VoidMulti.SC2Mod",
    "bnet:Co-op Mission/0.0/999,file:Mods/StarCoop/StarCoop.SC2Mod",
    "file:Mods/7vs1/CoopZeroPop.SC2Mod"
)
$mapDependencies = @(
    Get-DocumentInfoDependencies -Path (Join-Path $mapLive "DocumentInfo")
)
$mapDependencies = Normalize-MapRuntimeDependencies -Dependencies $mapDependencies
$mapDependencies = Add-DependencyUnique -Dependencies $mapDependencies -Dependency "file:Mods/7vs1/CoopZeroPop.SC2Mod"
$mapDependencies = Add-DependencyUnique -Dependencies $mapDependencies -Dependency "file:Mods/7vs1/CommanderCatalog.SC2Mod"
if ($useAbathurRebornPatch) {
    $mapDependencies = Add-DependencyUnique -Dependencies $mapDependencies -Dependency "file:Mods/7vs1/7v1AbathurRebornPatch.SC2Mod"
}

Assert-NoUnsupportedWorkspaceDependency -Dependencies $extensionDependencies -DependencyOwner "extension dependencies"
Assert-NoUnsupportedWorkspaceDependency -Dependencies $mapDependencies -DependencyOwner "map dependencies"
if ($useAbathurRebornPatch) {
    Assert-NoUnsupportedWorkspaceDependency -Dependencies $abathurRebornPatchDependencies -DependencyOwner "Abathur reborn patch dependencies"
}

$liveAllowedDependencies = New-Object 'System.Collections.Generic.List[string]'
$liveAllowedDependencies.AddRange([string[]]$extensionDependencies)
$liveAllowedDependencies.AddRange([string[]]$mapDependencies)
if ($useAbathurRebornPatch) {
    $liveAllowedDependencies.AddRange([string[]]$abathurRebornPatchDependencies)
}

$removedUnsupportedLiveRuntimeRoots = Remove-UnsupportedLiveRuntimeRoots `
    -Sc2Root $Sc2Root `
    -AllowedDependencies $liveAllowedDependencies.ToArray()

Set-PackageDependencies -PackageRoot $extensionLive -Dependencies $extensionDependencies
if ($useAbathurRebornPatch) {
    Set-PackageDependencies -PackageRoot $abathurRebornPatchLive -Dependencies $abathurRebornPatchDependencies
}
Set-PackageDependencies -PackageRoot $mapLive -Dependencies $mapDependencies

$workspaceDependencySkips = @(
    "file:Mods/7vs1/CoopZeroPop.SC2Mod"
)
if ($useAbathurRebornPatch) {
    $workspaceDependencySkips += "file:Mods/7vs1/7v1AbathurRebornPatch.SC2Mod"
}
$installedWorkspaceDependencyMods = Install-WorkspaceModDependencyClosure `
    -Dependencies $mapDependencies `
    -WorkspaceRoot (Get-WorkspaceRoot) `
    -Sc2Root $Sc2Root `
    -SkipDependencies $workspaceDependencySkips

$liveLibKPVP = Join-Path $extensionLive "Base.SC2Data\LibKPVP.galaxy"
Set-LiveCommanderTestOverride -LibPath $liveLibKPVP -SelectedCommanders $effectiveCommanders -TestSpawnPreset $TestSpawnPreset
Add-SafeStartPointOverride -Path $liveLibKPVP -FunctionName "libKPVP_gf_codex_start_point" -InsertionAnchor "void libKPVP_gf_apply_peace_time" -StartPoints $effectiveStartPoints

$liveGameData = Join-Path $extensionLive "Base.SC2Data\GameData"
if (($effectiveCommanders -contains "TerranSwann") -and $swannSourceGameData) {
    Patch-LiveSwannKelMorianWorkerData -SourceGameData $swannSourceGameData -LiveGameData $liveGameData
}
elseif ($effectiveCommanders -contains "TerranSwann") {
    throw "TerranSwann test requires SourceRoot with replay pkg01 GameData. Pass -SourceRoot to a replay extract root."
}

$liveLibKCOR = Join-Path $extensionLive "Base.SC2Data\LibKCOR.galaxy"
Add-SafeStartPointOverride -Path $liveLibKCOR -FunctionName "libKCOR_gf_codex_start_point" -InsertionAnchor "void libKCOR_gf_CC_ApplyRaceTechZerg" -StartPoints $effectiveStartPoints

$liveLibKMIS = Join-Path $extensionLive "Base.SC2Data\LibKMIS.galaxy"
Add-SafeStartPointOverride -Path $liveLibKMIS -FunctionName "libKMIS_gf_codex_start_point" -InsertionAnchor "void libKMIS_gf_CM_Zeratul_GiveProphecyHint" -StartPoints $effectiveStartPoints
Disable-LiveRewardGrants -Path $liveLibKMIS
$liveLibKCUI = Join-Path $extensionLive "Base.SC2Data\LibKCUI.galaxy"
Patch-LiveTychusUiGuards -Path $liveLibKCUI
if ($useAbathurRebornPatch) {
    Patch-LiveAbathurCommanderBridge -LibKPVPPath $liveLibKPVP -LibKCORPath $liveLibKCOR -LibKCUIPath $liveLibKCUI -LibKMISPath $liveLibKMIS
    Validate-LiveAbathurRebornInstall -MapLive $mapLive -ExtensionLive $extensionLive -PatchLive $abathurRebornPatchLive
}
else {
    Validate-LiveBaseTestlineInstall -MapLive $mapLive -ExtensionLive $extensionLive
}

# Re-apply the CommanderPower bank preset at the end of the install path so
# the final bank state wins even if any install/validation helper touched it.
if (-not $SkipCommanderPowerPreset) {
    Set-CampaignXCoreCommanderPowerPreset `
        -SelectedCommanders $effectiveCommanders `
        -Profile $CommanderPowerProfile `
        -PrestigeBonusMask $CommanderPowerPrestigeBonusMask `
        -PrestigePointIndex $CommanderPowerPrestigePointIndex `
        -EnablePrestiges $CommanderPowerEnablePrestiges `
        -EnableMasteries $CommanderPowerEnableMasteries `
        -MasteryLevel $CommanderPowerMasteryLevel `
        -Mastery0 $CommanderPowerMastery0 `
        -Mastery1 $CommanderPowerMastery1 `
        -Mastery2 $CommanderPowerMastery2 `
        -Mastery3 $CommanderPowerMastery3 `
        -Mastery4 $CommanderPowerMastery4 `
        -Mastery5 $CommanderPowerMastery5 `
        -PresetPath $CommanderPowerPresetPath `
        -Overrides $CommanderPowerOverride
}

Write-Host "Installed map: $mapLive"
Write-Host "Installed extension mod: $extensionLive"
if ($removedUnsupportedLiveRuntimeRoots.Count -gt 0) {
    Write-Host "Removed unsupported live runtime roots: $($removedUnsupportedLiveRuntimeRoots -join ', ')"
}
else {
    Write-Host "Removed unsupported live runtime roots: none"
}
if ($installedWorkspaceDependencyMods.Count -gt 0) {
    Write-Host "Installed workspace dependency mods: $($installedWorkspaceDependencyMods -join ', ')"
}
else {
    Write-Host "Installed workspace dependency mods: none"
}
if ($useAbathurRebornPatch) {
    Write-Host "Installed Abathur reborn patch mod: $abathurRebornPatchLive"
    Write-Host "Abathur reborn patch profile: $AbathurPatchProfile"
}
else {
    Write-Host "Installed Abathur reborn patch mod: not needed for current commander set"
}
Write-Host "Requested commanders: $($Commanders -join ', ')"
Write-Host "Test commanders P1-P$($effectiveCommanders.Count): $($effectiveCommanders -join ', ')"
Write-Host "Start point preset: $effectiveStartPointLabel"
if (-not $SkipCommanderPowerPreset) {
    Write-Host "Commander power profile: $CommanderPowerProfile"
    Write-Host "Commander power prestige bonus mask: $CommanderPowerPrestigeBonusMask"
    Write-Host "Commander power prestige point index: $CommanderPowerPrestigePointIndex"
    Write-Host "Commander power enable prestiges: $CommanderPowerEnablePrestiges"
    Write-Host "Commander power enable masteries: $CommanderPowerEnableMasteries"
    Write-Host "Commander power mastery level: $CommanderPowerMasteryLevel"
    Write-Host "Commander power mastery overrides: [$CommanderPowerMastery0,$CommanderPowerMastery1,$CommanderPowerMastery2,$CommanderPowerMastery3,$CommanderPowerMastery4,$CommanderPowerMastery5]"
    if (-not [string]::IsNullOrWhiteSpace($CommanderPowerPresetPath)) {
        Write-Host "Commander power preset path: $(Resolve-CommanderPowerPresetPath -Path $CommanderPowerPresetPath)"
    }
    if ($CommanderPowerOverride.Count -gt 0) {
        Write-Host "Commander power overrides: $($CommanderPowerOverride -join '; ')"
    }
}

if (-not $NoLaunch) {
    Write-Host "Launching map: $mapLive"
    & $SwitcherPath $mapLive
}
