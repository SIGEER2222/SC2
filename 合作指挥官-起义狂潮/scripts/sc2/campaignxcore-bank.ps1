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

function Remove-BankSectionIfPresent {
    param(
        [xml]$Xml,
        [string]$SectionName
    )

    $section = $Xml.SelectSingleNode("/Bank/Section[@name='$SectionName']")
    if ($section -and $section.ParentNode) {
        $null = $section.ParentNode.RemoveChild($section)
    }
}

function Remove-BankKeyIfPresent {
    param(
        [xml]$Xml,
        [string]$SectionName,
        [string]$KeyName
    )

    $section = $Xml.SelectSingleNode("/Bank/Section[@name='$SectionName']")
    if (-not $section) {
        return
    }

    $escapedKey = $KeyName.Replace("'", "&apos;")
    $keys = @($section.SelectNodes("Key[@name='$escapedKey']"))
    foreach ($key in $keys) {
        if ($key -and $key.ParentNode) {
            $null = $key.ParentNode.RemoveChild($key)
        }
    }
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
        [bool]$UseCommanderDefaultPrestigeBonusMask = $false,
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

        $commanderPrestigeBonusMask = $normalizedPrestigeBonusMask
        if ($UseCommanderDefaultPrestigeBonusMask) {
            $commanderPrestigeBonusMask = Get-CommanderPowerDefaultPrestigeBonusMask -Commander $selectedCommander -WorkspaceRoot (Get-WorkspaceRoot)
        }

        $commanderEnablePrestiges = $normalizedEnablePrestiges
        $commanderPrestigePointIndex = $normalizedPrestigePointIndex

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
            EnablePrestiges = $commanderEnablePrestiges
            EnableMasteries = $normalizedEnableMasteries
            PrestigePointIndex = $commanderPrestigePointIndex
            PrestigeIndex = $commanderPrestigePointIndex
            PrestigeBonusMask = $commanderPrestigeBonusMask
            PrestigeMask = $commanderPrestigeBonusMask
            MasteryDefault = $normalizedMasteryLevel
            Masteries = $commanderMasteryValues
        }
    }

    foreach ($entry in @(Get-CommanderPowerPresetEntries -PresetPath $PresetPath)) {
        $entryCommander = [string]$entry.commander
        if ([string]::IsNullOrWhiteSpace($entryCommander)) {
            throw "CommanderPower preset entry is missing required field 'commander'."
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

        Remove-BankSectionIfPresent -Xml $xml -SectionName "CommanderPower"
        Remove-BankSectionIfPresent -Xml $xml -SectionName "CommanderPowerRuntime"

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

function Set-CampaignXCoreMutatorPreset {
    param(
        [string[]]$SelectedMutators,
        [int]$Preset
    )

    $bankPaths = @(Get-CampaignXCoreBankPaths)
    if ($bankPaths.Count -eq 0) {
        Write-Warning "CampaignXCore.SC2Bank not found; skipping mutator preset."
        return
    }

    $allowedMutators = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($mutator in @(
        "Random", "WalkingInfested", "InfestedTerranSpawner", "BlackFog", "TimeWarp", "UnitSpeed",
        "Magnificent", "Entomb", "Barrier", "Avenger", "SideStep", "FireFight", "LavaBurst",
        "DeathAOE", "DropPods", "SpawnBroodlings", "LaserDrill", "LongRange", "ReducedVision",
        "HybridNuke", "AllEnemiesCloaked", "LazyWorkers", "NoResources", "ConcussiveAttacks",
        "StoneZealots", "JustDie", "TemporalField", "VoidRifts", "Tornadoes", "OrbitalStrike",
        "PurifierBeam", "Blizzard", "Fear", "PhotonOverload", "SpiderMines", "CycleRandom",
        "Reanimators", "Nukes", "LifeLeech", "OopsAllCasters", "OrderCosts", "MissileBarrage",
        "Vertigo", "UndyingEvil", "Polarity", "Evolve", "UberDarkness", "TrickOrTreat",
        "FoodHunt", "SharedSupply", "DamageBounce", "Plague", "StructureSteal", "GiftFight",
        "KillKarma", "AfraidOfTheDark", "Insubordination", "HeroesFromTheStorm", "Inspiration",
        "HardenedWill", "Fireworks", "RedEnvelopes", "Sluggish", "DamageReflect", "DeathPull",
        "Propagate", "MomentOfSilence", "KillBots", "BoomBots"
    )) {
        $allowedMutators[$mutator] = $mutator
    }

    $normalizedMutators = New-Object 'System.Collections.Generic.List[string]'
    foreach ($mutatorEntry in $SelectedMutators) {
        if ([string]::IsNullOrWhiteSpace($mutatorEntry)) {
            continue
        }

        foreach ($mutator in ([string]$mutatorEntry -split '[,;]')) {
            if ([string]::IsNullOrWhiteSpace($mutator)) {
                continue
            }

            $trimmed = $mutator.Trim()
            if (-not $allowedMutators.ContainsKey($trimmed)) {
                throw "Unknown mutator '$trimmed'. Use internal mutator ids such as UnitSpeed, Barrier, Avenger, VoidRifts."
            }

            $canonicalMutator = $allowedMutators[$trimmed]
            if (-not $normalizedMutators.Contains($canonicalMutator)) {
                $normalizedMutators.Add($canonicalMutator)
            }
        }
    }

    $enabled = if (($Preset -gt 0) -or ($normalizedMutators.Count -gt 0)) { 1 } else { 0 }

    foreach ($bankPath in $bankPaths) {
        [xml]$xml = Get-Content -LiteralPath $bankPath -Raw
        Remove-BankSectionIfPresent -Xml $xml -SectionName "Mutators"

        if ($enabled -gt 0) {
            Set-BankIntKeyValue -Xml $xml -SectionName "Mutators" -KeyName "Enabled" -Value 1
            Set-BankIntKeyValue -Xml $xml -SectionName "Mutators" -KeyName "Preset" -Value $Preset
            foreach ($mutator in $normalizedMutators) {
                Set-BankIntKeyValue -Xml $xml -SectionName "Mutators" -KeyName "Selected.$mutator" -Value 1
            }
        }

        Save-XmlDocumentWithRetry -Xml $xml -Path $bankPath
    }
}

function Set-CampaignXCoreGenericBonuses {
    param(
        [string[]]$SelectedBonuses
    )

    $bankPaths = @(Get-CampaignXCoreBankPaths)
    if ($bankPaths.Count -eq 0) {
        Write-Warning "CampaignXCore.SC2Bank not found; skipping generic bonuses preset."
        return
    }

    $allowedBonuses = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($bonus in @(
        "DoubleMinerals",
        "DoubleVespene",
        "RichResources",
        "GuardianShell",
        "CreepRegeneration",
        "MechanicalRepair",
        "ChronoBoost"
    )) {
        $allowedBonuses[$bonus] = $bonus
    }

    $normalizedBonuses = New-Object 'System.Collections.Generic.List[string]'
    foreach ($bonusEntry in $SelectedBonuses) {
        if ([string]::IsNullOrWhiteSpace($bonusEntry)) {
            continue
        }

        foreach ($bonus in ([string]$bonusEntry -split '[,;]')) {
            if ([string]::IsNullOrWhiteSpace($bonus)) {
                continue
            }

            $trimmed = $bonus.Trim()
            if (-not $allowedBonuses.ContainsKey($trimmed)) {
                throw "Unknown generic bonus '$trimmed'. Allowed ids: $($allowedBonuses.Keys -join ', ')"
            }

            $canonicalBonus = $allowedBonuses[$trimmed]
            if (-not $normalizedBonuses.Contains($canonicalBonus)) {
                $normalizedBonuses.Add($canonicalBonus)
            }
        }
    }

    foreach ($bankPath in $bankPaths) {
        [xml]$xml = Get-Content -LiteralPath $bankPath -Raw
        Remove-BankSectionIfPresent -Xml $xml -SectionName "GenericBonuses"

        if ($normalizedBonuses.Count -gt 0) {
            Set-BankIntKeyValue -Xml $xml -SectionName "GenericBonuses" -KeyName "Enabled" -Value 1
            foreach ($bonus in $normalizedBonuses) {
                Set-BankIntKeyValue -Xml $xml -SectionName "GenericBonuses" -KeyName "Selected.$bonus" -Value 1
            }
        }

        Save-XmlDocumentWithRetry -Xml $xml -Path $bankPath
    }
}

function Set-CampaignXCoreTestRunId {
    param([string]$RunId)

    if ([string]::IsNullOrWhiteSpace($RunId)) {
        return
    }

    foreach ($bankPath in @(Get-CampaignXCoreBankPaths)) {
        [xml]$xml = Get-Content -LiteralPath $bankPath -Raw
        Set-BankStringKeyValue -Xml $xml -SectionName "XMRuntimeControl" -KeyName "TestRunId" -Value $RunId
        Save-XmlDocumentWithRetry -Xml $xml -Path $bankPath
    }
}

function Set-CampaignXCorePrimaryCommander {
    param([string[]]$SelectedCommanders)

    if (($null -eq $SelectedCommanders) -or ($SelectedCommanders.Count -lt 1)) {
        return
    }

    $primaryCommander = Convert-TestCommanderToCommanderPowerKey -Commander $SelectedCommanders[0]
    if ([string]::IsNullOrWhiteSpace($primaryCommander)) {
        throw "Cannot map test commander '$($SelectedCommanders[0])' to CampaignXCore Ach/Commander."
    }

    foreach ($bankPath in @(Get-CampaignXCoreBankPaths)) {
        [xml]$xml = Get-Content -LiteralPath $bankPath -Raw
        Set-BankStringKeyValue -Xml $xml -SectionName "Ach" -KeyName "Commander" -Value $primaryCommander
        Set-BankStringKeyValue -Xml $xml -SectionName "XMRuntimeControl" -KeyName "PrimaryCommander" -Value $primaryCommander
        Set-BankIntKeyValue -Xml $xml -SectionName "XMRuntimeControl" -KeyName "CommanderCount" -Value $SelectedCommanders.Count
        for ($slot = 0; $slot -lt 7; $slot++) {
            $keyName = "CommanderP$($slot + 1)"
            if ($slot -lt $SelectedCommanders.Count) {
                $slotCommander = Convert-TestCommanderToCommanderPowerKey -Commander $SelectedCommanders[$slot]
                if ([string]::IsNullOrWhiteSpace($slotCommander)) {
                    throw "Cannot map test commander '$($SelectedCommanders[$slot])' to CampaignXCore XMRuntimeControl/$keyName."
                }

                Set-BankStringKeyValue -Xml $xml -SectionName "XMRuntimeControl" -KeyName $keyName -Value $slotCommander
            }
            else {
                Remove-BankKeyIfPresent -Xml $xml -SectionName "XMRuntimeControl" -KeyName $keyName
            }
        }
        Save-XmlDocumentWithRetry -Xml $xml -Path $bankPath
    }
}
