[CmdletBinding()]
param(
    [string]$OfficialCommandersRoot = "",
    [string]$LocalizedZhRoot = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "commander-power-metadata.ps1")

function Resolve-ExistingPath {
    param(
        [object[]]$Candidates,
        [string]$Label
    )

    foreach ($candidate in $Candidates) {
        $candidateValues = if (($candidate -is [System.Collections.IEnumerable]) -and (-not ($candidate -is [string]))) {
            @($candidate)
        }
        else {
            @($candidate)
        }

        foreach ($candidateValue in $candidateValues) {
            if ([string]::IsNullOrWhiteSpace($candidateValue)) {
                continue
            }

            if (Test-Path -LiteralPath $candidateValue) {
                return (Resolve-Path -LiteralPath $candidateValue).Path
            }
        }
    }

    throw "$Label not found. Candidates: $($Candidates -join '; ')"
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-NormalizedPrestigeTooltip {
    param(
        [string]$OfficialFolder,
        [string]$Tooltip
    )

    if ($OfficialFolder -eq "Karax") {
        $disadvantageMarker = "<n/><n/><s val=`"Coop_Prestige_Disadvantage`">"
        $markerIndex = $Tooltip.IndexOf($disadvantageMarker)
        if ($markerIndex -ge 0) {
            return $Tooltip.Substring(0, $markerIndex).TrimEnd("`t")
        }
    }

    return $Tooltip
}

function Read-LocalizedStringMap {
    param([string]$Path)

    $map = @{}
    Get-Content -LiteralPath $Path -Encoding UTF8 | ForEach-Object {
        if ([string]::IsNullOrWhiteSpace($_)) {
            return
        }

        $separatorIndex = $_.IndexOf("=")
        if ($separatorIndex -lt 0) {
            return
        }

        $key = $_.Substring(0, $separatorIndex).Trim()
        $value = $_.Substring($separatorIndex + 1)
        if (-not [string]::IsNullOrWhiteSpace($key)) {
            $map[$key] = $value
        }
    }

    return $map
}

function Get-WorkspaceRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Get-RebornWorkRepoRoots {
    $roots = New-Object System.Collections.Generic.List[string]
    $currentLocation = (Get-Location).Path
    if (-not [string]::IsNullOrWhiteSpace($currentLocation)) {
        $roots.Add($currentLocation) | Out-Null
    }

    $downloadsRoot = Join-Path $env:USERPROFILE "Downloads"
    if (Test-Path -LiteralPath $downloadsRoot) {
        Get-ChildItem -LiteralPath $downloadsRoot -Directory -Recurse -Depth 2 -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq "reborn_workrepo" } |
            Sort-Object FullName |
            ForEach-Object {
                if ($roots -notcontains $_.FullName) {
                    $roots.Add($_.FullName) | Out-Null
                }
            }
    }

    return $roots.ToArray()
}

function Find-OfficialCommandersRoot {
    param([string[]]$SearchRoots)

    foreach ($root in $SearchRoots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        $match = Get-ChildItem -LiteralPath $root -Directory -Recurse -Depth 6 -ErrorAction SilentlyContinue |
            Where-Object {
                ($_.Name -eq "commanders") -and
                (Test-Path -LiteralPath (Join-Path $_.FullName "Abathur")) -and
                (Test-Path -LiteralPath (Join-Path $_.FullName "Raynor")) -and
                (Test-Path -LiteralPath (Join-Path $_.FullName "Mengsk"))
            } |
            Sort-Object FullName |
            Select-Object -First 1

        if ($match) {
            return $match.FullName
        }
    }

    return ""
}

function Find-LibertyGamestringPath {
    param(
        [string[]]$SearchRoots,
        [string]$LocaleFolder
    )

    foreach ($root in $SearchRoots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        $match = Get-ChildItem -LiteralPath $root -File -Recurse -Filter "gamestrings.txt" -ErrorAction SilentlyContinue |
            Where-Object {
                ($_.FullName -like "*liberty.sc2mod*") -and
                ($_.FullName -like "*$LocaleFolder*") -and
                ($_.FullName -like "*localizeddata*")
            } |
            Sort-Object FullName |
            Select-Object -First 1

        if ($match) {
            return $match.FullName
        }
    }

    return ""
}

function Find-LibertyCommanderDataPath {
    param([string[]]$SearchRoots)

    foreach ($root in $SearchRoots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        $match = Get-ChildItem -LiteralPath $root -File -Recurse -Filter "commanderdata.xml" -ErrorAction SilentlyContinue |
            Where-Object {
                ($_.FullName -like "*liberty.sc2mod*") -and
                ($_.FullName -like "*base.sc2data*gamedata*")
            } |
            Sort-Object FullName |
            Select-Object -First 1

        if ($match) {
            return $match.FullName
        }
    }

    return ""
}

function Get-CommanderPrestigeButtonIds {
    param(
        [xml]$CommanderDataXml,
        [string]$CommanderId
    )

    $nodes = $CommanderDataXml.SelectNodes("/Catalog/CCommander[@id='$CommanderId']/PrestigeArray")
    return @($nodes | ForEach-Object { [string]$_.value })
}

$workspaceRoot = Get-WorkspaceRoot
$rebornRoots = @(Get-RebornWorkRepoRoots)
$discoveryRoots = @($workspaceRoot) + $rebornRoots
$metadata = Get-CommanderPowerMetadata -WorkspaceRoot $workspaceRoot
$metadataPath = Get-CommanderPowerMetadataPath -WorkspaceRoot $workspaceRoot
$runtimeCoveragePath = Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\LibE0EAE146_CommanderPowerGenerated.galaxy"
$bridgePath = Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\LibKCOR.galaxy"
$launchPath = Join-Path $workspaceRoot "scripts\launch-7vs1-coop-test.ps1"

$officialCandidates = @(
    $OfficialCommandersRoot,
    (Find-OfficialCommandersRoot -SearchRoots $discoveryRoots)
)
$zhCandidates = @(
    $LocalizedZhRoot,
    (Find-LibertyGamestringPath -SearchRoots $discoveryRoots -LocaleFolder "zhcn.sc2data")
)
$commanderDataCandidates = @(
    (Find-LibertyCommanderDataPath -SearchRoots $discoveryRoots)
)

$resolvedOfficialCommandersRoot = Resolve-ExistingPath -Label "Official commanders root" -Candidates $officialCandidates
$resolvedLocalizedZhRoot = Resolve-ExistingPath -Label "Localized zhCN strings" -Candidates $zhCandidates
$resolvedCommanderDataPath = Resolve-ExistingPath -Label "Liberty commanderdata.xml" -Candidates $commanderDataCandidates

$zhMap = Read-LocalizedStringMap -Path $resolvedLocalizedZhRoot
[xml]$commanderDataXml = Get-Content -LiteralPath $resolvedCommanderDataPath -Encoding UTF8 -Raw
$generatedText = Get-Content -LiteralPath $runtimeCoveragePath -Raw
$bridgeText = Get-Content -LiteralPath $bridgePath -Raw
$launchText = Get-Content -LiteralPath $launchPath -Raw

Assert-True -Condition ($metadata.schema_version -eq 1) -Message "Unsupported commander-power metadata schema version."
Assert-True -Condition (@($metadata.commanders).Count -eq 18) -Message ("CommanderPower metadata expected 18 commanders, got {0}." -f @($metadata.commanders).Count)
Assert-True -Condition ([int]$metadata.control_schema.mastery_slot_count -eq 6) -Message "CommanderPower metadata mastery slot count must stay at 6."
Assert-True -Condition ([int]$metadata.control_schema.prestige_slot_count -eq 3) -Message "CommanderPower metadata prestige slot count must stay at 3."
Assert-True -Condition (@($metadata.control_schema.key_suffixes) -contains "PrestigeBonusMask") -Message "CommanderPower metadata must expose PrestigeBonusMask."
Assert-True -Condition (@($metadata.control_schema.key_suffixes) -contains "PrestigePointIndex") -Message "CommanderPower metadata must expose PrestigePointIndex."
Assert-True -Condition ([int]$metadata.control_schema.default_prestige_bonus_mask -eq 7) -Message "CommanderPower metadata default prestige bonus mask must stay at 7."
Assert-True -Condition ([int]$metadata.control_schema.default_prestige_point_index -eq -1) -Message "CommanderPower metadata default prestige point index must stay at -1."

$abathurCommander = @($metadata.commanders | Where-Object { [string]$_.runtime_commander -eq "ZergAbathur" } | Select-Object -First 1)
Assert-True -Condition ($abathurCommander.Count -eq 1) -Message "CommanderPower metadata must include ZergAbathur."
Assert-True -Condition ([int]$abathurCommander[0].default_prestige_bonus_mask -eq 5) -Message "Abathur default prestige bonus mask must be 5."

$seenRuntime = @{}
$seenBank = @{}
$seenFolder = @{}

foreach ($commander in $metadata.commanders) {
    $runtimeCommander = [string]$commander.runtime_commander
    $bankCommander = [string]$commander.bank_commander
    $generatedCommander = [string]$commander.generated_commander
    $officialFolder = [string]$commander.official_folder

    Assert-True -Condition (-not $seenRuntime.ContainsKey($runtimeCommander)) -Message ("Duplicate runtime commander in metadata: {0}" -f $runtimeCommander)
    Assert-True -Condition (-not $seenBank.ContainsKey($bankCommander)) -Message ("Duplicate bank commander in metadata: {0}" -f $bankCommander)
    Assert-True -Condition (-not $seenFolder.ContainsKey($officialFolder)) -Message ("Duplicate official folder in metadata: {0}" -f $officialFolder)
    $seenRuntime[$runtimeCommander] = $true
    $seenBank[$bankCommander] = $true
    $seenFolder[$officialFolder] = $true

    $commanderRoot = Join-Path $resolvedOfficialCommandersRoot $officialFolder
    $commanderJson = Get-Content -LiteralPath (Join-Path $commanderRoot "commander.json") -Encoding UTF8 -Raw | ConvertFrom-Json
    $progressionJson = Get-Content -LiteralPath (Join-Path $commanderRoot "progression.json") -Encoding UTF8 -Raw | ConvertFrom-Json
    $prestigesJson = Get-Content -LiteralPath (Join-Path $commanderRoot "prestiges.json") -Encoding UTF8 -Raw | ConvertFrom-Json
    $prestigeButtonIds = @(Get-CommanderPrestigeButtonIds -CommanderDataXml $commanderDataXml -CommanderId $officialFolder)

    Assert-True -Condition ($runtimeCommander -eq [string]$commanderJson.id) -Message ("Runtime commander mismatch for {0}" -f $officialFolder)
    Assert-True -Condition ($generatedCommander -eq $officialFolder) -Message ("Generated commander mismatch for {0}" -f $officialFolder)
    Assert-True -Condition ([string]$commander.display_name -eq [string]$commanderJson.name) -Message ("Display name mismatch for {0}" -f $officialFolder)

    Assert-True -Condition (@($commander.masteries).Count -eq 6) -Message ("Metadata mastery count mismatch for {0}" -f $officialFolder)
    Assert-True -Condition (@($progressionJson.masteries).Count -eq 6) -Message ("Official mastery count mismatch for {0}" -f $officialFolder)
    for ($slot = 0; $slot -lt 6; $slot++) {
        $metadataMastery = $commander.masteries[$slot]
        $officialMastery = $progressionJson.masteries[$slot]

        Assert-True -Condition ([int]$metadataMastery.slot -eq $slot) -Message ("Mastery slot mismatch for {0} slot {1}" -f $officialFolder, $slot)
        Assert-True -Condition ([string]$metadataMastery.id -eq [string]$officialMastery.id) -Message ("Mastery id mismatch for {0} slot {1}" -f $officialFolder, $slot)
        Assert-True -Condition ([string]$metadataMastery.upgrade -eq [string]$officialMastery.upgrade) -Message ("Mastery upgrade mismatch for {0} slot {1}" -f $officialFolder, $slot)
        Assert-True -Condition ([int]$metadataMastery.category -eq [int]$officialMastery.category) -Message ("Mastery category mismatch for {0} slot {1}" -f $officialFolder, $slot)
    }

    Assert-True -Condition (@($commander.prestiges).Count -eq 3) -Message ("Metadata prestige count mismatch for {0}" -f $officialFolder)
    Assert-True -Condition (@($commanderJson.prestige_ids).Count -eq 3) -Message ("Official prestige id count mismatch for {0}" -f $officialFolder)
    Assert-True -Condition (@($prestigesJson).Count -eq 3) -Message ("Official prestige count mismatch for {0}" -f $officialFolder)
    Assert-True -Condition ($prestigeButtonIds.Count -eq 3) -Message ("Liberty commanderdata prestige count mismatch for {0}" -f $officialFolder)
    Assert-True -Condition ([string]$commander.bank_keys.prestige_bonus_mask -eq ("{0}.PrestigeBonusMask" -f $bankCommander)) -Message ("Prestige bonus mask bank key mismatch for {0}" -f $officialFolder)
    Assert-True -Condition ([string]$commander.bank_keys.prestige_point_index -eq ("{0}.PrestigePointIndex" -f $bankCommander)) -Message ("Prestige point index bank key mismatch for {0}" -f $officialFolder)
    Assert-True -Condition ([string]$commander.bank_keys.prestige_mask -eq ("{0}.PrestigeMask" -f $bankCommander)) -Message ("Prestige mask bank key mismatch for {0}" -f $officialFolder)
    Assert-True -Condition ([string]$commander.bank_keys.prestige_index -eq ("{0}.PrestigeIndex" -f $bankCommander)) -Message ("Prestige index bank key mismatch for {0}" -f $officialFolder)
    for ($slot = 0; $slot -lt 3; $slot++) {
        $metadataPrestige = $commander.prestiges[$slot]
        $officialPrestige = $prestigesJson[$slot]
        $buttonId = [string]$prestigeButtonIds[$slot]
        $expectedNameKey = "Button/Name/{0}" -f $buttonId
        $expectedTooltipKey = "Button/Tooltip/{0}" -f $buttonId

        Assert-True -Condition ([int]$metadataPrestige.slot -eq $slot) -Message ("Prestige slot mismatch for {0} slot {1}" -f $officialFolder, $slot)
        Assert-True -Condition ([int]$metadataPrestige.bit_mask -eq (1 -shl $slot)) -Message ("Prestige bit mask mismatch for {0} slot {1}" -f $officialFolder, $slot)
        Assert-True -Condition ([string]$metadataPrestige.id -eq [string]$commanderJson.prestige_ids[$slot]) -Message ("Prestige id mismatch for {0} slot {1}" -f $officialFolder, $slot)
        Assert-True -Condition ([string]$metadataPrestige.button_id -eq $buttonId) -Message ("Prestige button id mismatch for {0} slot {1}" -f $officialFolder, $slot)
        Assert-True -Condition ([string]$metadataPrestige.id -eq [string]$officialPrestige.id) -Message ("Prestige payload mismatch for {0} slot {1}" -f $officialFolder, $slot)
        Assert-True -Condition ([string]$metadataPrestige.primary_upgrade -eq [string]$officialPrestige.primary_upgrade) -Message ("Prestige primary upgrade mismatch for {0} slot {1}" -f $officialFolder, $slot)
        if (($officialFolder -eq "Nova") -and ($slot -eq 2)) {
            $fusionPrimaryUpgrade = ""
            if ($null -ne $metadataPrestige.PSObject.Properties["fusion_primary_upgrade"]) {
                $fusionPrimaryUpgrade = [string]$metadataPrestige.fusion_primary_upgrade
            }
            Assert-True -Condition ($fusionPrimaryUpgrade -eq "CommanderPowerNovaSuperCloakFusion") -Message "Nova slot 2 must declare fusion_primary_upgrade=CommanderPowerNovaSuperCloakFusion."
        }
        if (($officialFolder -eq "Stetmann") -and ($slot -eq 0)) {
            $fusionPrimaryUpgrade = ""
            if ($null -ne $metadataPrestige.PSObject.Properties["fusion_primary_upgrade"]) {
                $fusionPrimaryUpgrade = [string]$metadataPrestige.fusion_primary_upgrade
            }
            Assert-True -Condition ($fusionPrimaryUpgrade -eq "CommanderPowerStetmannStetellitesFusion") -Message "Stetmann slot 0 must declare fusion_primary_upgrade=CommanderPowerStetmannStetellitesFusion."
        }
        if (($officialFolder -eq "Stetmann") -and ($slot -eq 1)) {
            $fusionPrimaryUpgrade = ""
            if ($null -ne $metadataPrestige.PSObject.Properties["fusion_primary_upgrade"]) {
                $fusionPrimaryUpgrade = [string]$metadataPrestige.fusion_primary_upgrade
            }
            Assert-True -Condition ($fusionPrimaryUpgrade -eq "CommanderPowerStetmannGaryFusion") -Message "Stetmann slot 1 must declare fusion_primary_upgrade=CommanderPowerStetmannGaryFusion."
        }
        Assert-True -Condition ([string]$metadataPrestige.name_key -eq $expectedNameKey) -Message ("Prestige name key mismatch for {0} slot {1}" -f $officialFolder, $slot)
        Assert-True -Condition ([string]$metadataPrestige.tooltip_key -eq $expectedTooltipKey) -Message ("Prestige tooltip key mismatch for {0} slot {1}" -f $officialFolder, $slot)
        Assert-True -Condition ($zhMap.ContainsKey($expectedNameKey)) -Message ("Missing zhCN prestige name for {0} slot {1}" -f $officialFolder, $slot)
        Assert-True -Condition ($zhMap.ContainsKey($expectedTooltipKey)) -Message ("Missing zhCN prestige tooltip for {0} slot {1}" -f $officialFolder, $slot)
        Assert-True -Condition ([string]$metadataPrestige.name -eq [string]$zhMap[$expectedNameKey]) -Message ("Prestige zhCN name mismatch for {0} slot {1}" -f $officialFolder, $slot)
        $expectedTooltip = Get-NormalizedPrestigeTooltip -OfficialFolder $officialFolder -Tooltip ([string]$zhMap[$expectedTooltipKey])
        Assert-True -Condition ([string]$metadataPrestige.tooltip -eq $expectedTooltip) -Message ("Prestige zhCN tooltip mismatch for {0} slot {1}" -f $officialFolder, $slot)
    }

    Assert-True -Condition ($generatedText.Contains(('if (lp_commander == "{0}") {{' -f $bankCommander))) -Message ("Generated runtime dispatcher missing {0}" -f $bankCommander)
    Assert-True -Condition ($generatedText.Contains(('libE0EAE146_gf_CommanderPowerGeneratedApply{0}(lp_player);' -f $generatedCommander))) -Message ("Generated runtime apply missing {0}" -f $generatedCommander)
    Assert-True -Condition ($generatedText.Contains(('lv_prestigeMask = libE0EAE146_gf_CommanderPowerPrestigeMask("{0}");' -f $bankCommander))) -Message ("Generated runtime prestige read missing {0}" -f $bankCommander)
    Assert-True -Condition ($bridgeText.Contains(('lp_commander == "{0}"' -f $runtimeCommander))) -Message ("Lobby bridge runtime mapping missing {0}" -f $runtimeCommander)
    Assert-True -Condition ($bridgeText.Contains(('return "{0}";' -f $bankCommander))) -Message ("Lobby bridge bank mapping missing {0}" -f $bankCommander)
}

Assert-True -Condition ($launchText.Contains("Convert-TestCommanderToCommanderPowerKey")) -Message "Launch script must route commander names through CommanderPower metadata helpers."
Assert-True -Condition ($generatedText.Contains('"CommanderPowerNovaSuperCloakFusion"')) -Message "Generated runtime must reference CommanderPowerNovaSuperCloakFusion for Nova fusion prestige."
Assert-True -Condition ($generatedText.Contains('"CommanderPowerStetmannStetellitesFusion"')) -Message "Generated runtime must reference CommanderPowerStetmannStetellitesFusion for Stetmann fusion prestige."
Assert-True -Condition ($generatedText.Contains('"CommanderPowerStetmannGaryFusion"')) -Message "Generated runtime must reference CommanderPowerStetmannGaryFusion for Stetmann fusion prestige."

Write-Host ("COMMANDER_POWER_METADATA_VALIDATE=PASS commanders={0} metadata={1}" -f @($metadata.commanders).Count, $metadataPath)
