[CmdletBinding()]
param(
    [string]$OfficialCommandersRoot = "",
    [string]$LocalizedZhRoot = "",
    [string]$LocalizedEnRoot = "",
    [string]$OutputPath = ""
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

function Get-CommanderOrder {
    return @(
        "Raynor",
        "Kerrigan",
        "Artanis",
        "Swann",
        "Zagara",
        "Vorazun",
        "Karax",
        "Abathur",
        "Alarak",
        "Nova",
        "Stukov",
        "Fenix",
        "Dehaka",
        "Horner",
        "Tychus",
        "Zeratul",
        "Stetmann",
        "Mengsk"
    )
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

function Resolve-LocalizedValue {
    param(
        [hashtable]$Map,
        [string[]]$Keys
    )

    foreach ($key in $Keys) {
        if ([string]::IsNullOrWhiteSpace($key)) {
            continue
        }

        if ($Map.ContainsKey($key)) {
            return [string]$Map[$key]
        }
    }

    return ""
}

function Get-BankCommanderName {
    param([string]$OfficialFolder)

    if ($OfficialFolder -eq "Horner") {
        return "Mira"
    }

    return $OfficialFolder
}

function Get-ConcreteBankKeys {
    param([string]$BankCommander)

    $masteryKeys = @(0..5 | ForEach-Object { "{0}.Mastery{1}" -f $BankCommander, $_ })
    return [ordered]@{
        profile = "{0}.Profile" -f $BankCommander
        enable_prestiges = "{0}.EnablePrestiges" -f $BankCommander
        prestige_bonus_mask = "{0}.PrestigeBonusMask" -f $BankCommander
        prestige_mask = "{0}.PrestigeMask" -f $BankCommander
        prestige_point_index = "{0}.PrestigePointIndex" -f $BankCommander
        prestige_index = "{0}.PrestigeIndex" -f $BankCommander
        enable_masteries = "{0}.EnableMasteries" -f $BankCommander
        mastery_default = "{0}.MasteryDefault" -f $BankCommander
        mastery_slots = $masteryKeys
    }
}

function New-PrestigeEntry {
    param(
        [pscustomobject]$Prestige,
        [int]$Slot,
        [string]$ButtonId,
        [hashtable]$ZhMap,
        [hashtable]$EnMap
    )

    $nameKeyCandidates = @(
        "Button/Name/$ButtonId",
        "Button/Name/$($Prestige.id)",
        "Button/Name/$($Prestige.primary_upgrade)"
    )
    $tooltipKeyCandidates = @(
        "Button/Tooltip/$ButtonId",
        "Button/Tooltip/$($Prestige.id)",
        "Button/Tooltip/$($Prestige.primary_upgrade)"
    )

    $supplements = @()
    foreach ($supplement in @($Prestige.upgrade_supplements)) {
        $supplements += [ordered]@{
            id = [string]$supplement.id
            upgrade = [string]$supplement.upgrade
            supplement_upgrades = @($supplement.supplement_upgrades)
        }
    }

    return [ordered]@{
        slot = $Slot
        bit_mask = [int][math]::Pow(2, $Slot)
        id = [string]$Prestige.id
        button_id = $ButtonId
        primary_upgrade = [string]$Prestige.primary_upgrade
        name_key = $nameKeyCandidates[0]
        tooltip_key = $tooltipKeyCandidates[0]
        name = (Resolve-LocalizedValue -Map $ZhMap -Keys $nameKeyCandidates)
        tooltip = (Resolve-LocalizedValue -Map $ZhMap -Keys $tooltipKeyCandidates)
        name_en = (Resolve-LocalizedValue -Map $EnMap -Keys $nameKeyCandidates)
        tooltip_en = (Resolve-LocalizedValue -Map $EnMap -Keys $tooltipKeyCandidates)
        secondary_upgrades_shared = @($Prestige.secondary_upgrades_shared)
        secondary_upgrades_self = @($Prestige.secondary_upgrades_self)
        suppress_upgrades = @($Prestige.suppress_upgrades)
        disable_units = @($Prestige.disable_units)
        enable_units = @($Prestige.enable_units)
        disable_abils = @($Prestige.disable_abils)
        enable_abils = @($Prestige.enable_abils)
        upgrade_supplement_ids = @($Prestige.upgrade_supplement_ids)
        upgrade_supplements = $supplements
    }
}

function New-MasteryEntry {
    param(
        [pscustomobject]$Mastery,
        [int]$Slot
    )

    return [ordered]@{
        slot = $Slot
        id = [string]$Mastery.id
        category = [int]$Mastery.category
        name = [string]$Mastery.name
        name_key = [string]$Mastery.name_key
        upgrade = [string]$Mastery.upgrade
        talent_data = [string]$Mastery.talent_data
        point_increments = @($Mastery.point_increments)
        value_format = [string]$Mastery.value_format
        value_format_key = [string]$Mastery.value_format_key
    }
}

function New-CommanderEntry {
    param(
        [string]$Folder,
        [string]$OfficialCommandersRoot,
        [xml]$CommanderDataXml,
        [hashtable]$ZhMap,
        [hashtable]$EnMap
    )

    $commanderRoot = Join-Path $OfficialCommandersRoot $Folder
    $commander = Get-Content -LiteralPath (Join-Path $commanderRoot "commander.json") -Encoding UTF8 -Raw | ConvertFrom-Json
    $progression = Get-Content -LiteralPath (Join-Path $commanderRoot "progression.json") -Encoding UTF8 -Raw | ConvertFrom-Json
    $prestiges = Get-Content -LiteralPath (Join-Path $commanderRoot "prestiges.json") -Encoding UTF8 -Raw | ConvertFrom-Json

    $bankCommander = Get-BankCommanderName -OfficialFolder $Folder
    $prestigeButtonIds = @(Get-CommanderPrestigeButtonIds -CommanderDataXml $CommanderDataXml -CommanderId $Folder)
    $prestigeEntries = @()
    for ($index = 0; $index -lt @($prestiges).Count; $index++) {
        $buttonId = if ($index -lt $prestigeButtonIds.Count) { $prestigeButtonIds[$index] } else { [string]$prestiges[$index].id }
        $prestigeEntries += New-PrestigeEntry -Prestige $prestiges[$index] -Slot $index -ButtonId $buttonId -ZhMap $ZhMap -EnMap $EnMap
    }

    $masteryEntries = @()
    for ($index = 0; $index -lt @($progression.masteries).Count; $index++) {
        $masteryEntries += New-MasteryEntry -Mastery $progression.masteries[$index] -Slot $index
    }

    $entry = [ordered]@{
        runtime_commander = [string]$commander.id
        bank_commander = $bankCommander
        generated_commander = $Folder
        official_folder = $Folder
        official_short_id = [string]$commander.short_id
        display_name = [string]$commander.name
        default_upgrades = @($commander.default_upgrades)
        default_ability_commands = @($commander.default_ability_commands)
        bank_keys = (Get-ConcreteBankKeys -BankCommander $bankCommander)
        prestiges = $prestigeEntries
        masteries = $masteryEntries
    }

    if ($Folder -eq "Abathur") {
        $entry.default_prestige_bonus_mask = 5
    }

    return $entry
}

$workspaceRoot = Get-CommanderPowerWorkspaceRoot
$rebornRoots = @(Get-RebornWorkRepoRoots)
$discoveryRoots = @($workspaceRoot) + $rebornRoots
$officialCandidates = @(
    $OfficialCommandersRoot,
    (Find-OfficialCommandersRoot -SearchRoots $discoveryRoots)
)
$zhCandidates = @(
    $LocalizedZhRoot,
    (Find-LibertyGamestringPath -SearchRoots $discoveryRoots -LocaleFolder "zhcn.sc2data")
)
$enCandidates = @(
    $LocalizedEnRoot,
    (Find-LibertyGamestringPath -SearchRoots $discoveryRoots -LocaleFolder "enus.sc2data")
)
$commanderDataCandidates = @(
    (Find-LibertyCommanderDataPath -SearchRoots $discoveryRoots)
)

$resolvedOfficialCommandersRoot = Resolve-ExistingPath -Label "Official commanders root" -Candidates $officialCandidates
$resolvedLocalizedZhRoot = Resolve-ExistingPath -Label "Localized zhCN strings" -Candidates $zhCandidates
$resolvedLocalizedEnRoot = Resolve-ExistingPath -Label "Localized enUS strings" -Candidates $enCandidates
$resolvedCommanderDataPath = Resolve-ExistingPath -Label "Liberty commanderdata.xml" -Candidates $commanderDataCandidates
$resolvedOutputPath = if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    Get-CommanderPowerMetadataPath -WorkspaceRoot $workspaceRoot
}
else {
    $OutputPath
}

$zhMap = Read-LocalizedStringMap -Path $resolvedLocalizedZhRoot
$enMap = Read-LocalizedStringMap -Path $resolvedLocalizedEnRoot
[xml]$commanderDataXml = Get-Content -LiteralPath $resolvedCommanderDataPath -Encoding UTF8 -Raw

$commanderEntries = @()
foreach ($folder in Get-CommanderOrder) {
    $commanderEntries += New-CommanderEntry `
        -Folder $folder `
        -OfficialCommandersRoot $resolvedOfficialCommandersRoot `
        -CommanderDataXml $commanderDataXml `
        -ZhMap $zhMap `
        -EnMap $enMap
}

$metadata = [ordered]@{
    schema_version = 1
    generated_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    source = [ordered]@{
        official_commanders_root = $resolvedOfficialCommandersRoot
        localized_zh_path = $resolvedLocalizedZhRoot
        localized_en_path = $resolvedLocalizedEnRoot
        liberty_commanderdata_path = $resolvedCommanderDataPath
    }
    control_schema = [ordered]@{
        key_suffixes = @(
            "Profile",
            "EnablePrestiges",
            "PrestigeBonusMask",
            "PrestigeMask",
            "PrestigePointIndex",
            "PrestigeIndex",
            "EnableMasteries",
            "MasteryDefault",
            "Mastery0",
            "Mastery1",
            "Mastery2",
            "Mastery3",
            "Mastery4",
            "Mastery5"
        )
        default_profile = "Prestige4"
        default_enable_prestiges = 1
        default_prestige_bonus_mask = 7
        default_prestige_mask = 7
        default_prestige_point_index = -1
        default_prestige_index = -1
        default_enable_masteries = 1
        default_mastery_default = 30
        mastery_slot_count = 6
        prestige_slot_count = 3
    }
    commanders = $commanderEntries
}

$outputDirectory = Split-Path -Parent $resolvedOutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$json = $metadata | ConvertTo-Json -Depth 32
[System.IO.File]::WriteAllText($resolvedOutputPath, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ("COMMANDER_POWER_METADATA_EXPORT=PASS commanders={0} output={1}" -f $commanderEntries.Count, $resolvedOutputPath)
