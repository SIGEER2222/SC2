[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "commander-power-metadata.ps1")
. (Join-Path $PSScriptRoot "sc2\catalog-xml.ps1")

function Get-WorkspaceRoot {
    return (Split-Path -Parent $PSScriptRoot)
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

function Read-CatalogXml {
    param([string]$Path)

    Assert-True -Condition (Test-Path -LiteralPath $Path) -Message "Catalog XML not found: $Path"
    [xml]$xml = Get-Content -LiteralPath $Path -Encoding UTF8 -Raw
    return $xml
}

function Get-UpgradeNodes {
    param(
        [xml[]]$Xmls,
        [string]$UpgradeId
    )

    $nodes = @()
    foreach ($xml in $Xmls) {
        $nodes += @($xml.SelectNodes("/Catalog/CUpgrade[@id='$UpgradeId']"))
    }

    return @($nodes)
}

function Get-RemovedEffectIndexes {
    param(
        [xml[]]$Xmls,
        [string]$UpgradeId
    )

    $removed = New-Object System.Collections.Generic.HashSet[int]
    foreach ($node in @(Get-UpgradeNodes -Xmls $Xmls -UpgradeId $UpgradeId)) {
        foreach ($effect in @($node.EffectArray)) {
            if (([string]$effect.removed) -ne "1") {
                continue
            }

            $indexText = [string]$effect.index
            if ([string]::IsNullOrWhiteSpace($indexText)) {
                continue
            }

            $indexValue = 0
            if ([int]::TryParse($indexText, [ref]$indexValue)) {
                [void]$removed.Add($indexValue)
            }
        }
    }

    return ,$removed
}

function Assert-OverlayEffect {
    param(
        [xml]$Xml,
        [string]$UpgradeId,
        [string]$Reference,
        [string]$Value,
        [string]$Operation = ""
    )

    $nodes = @(Get-UpgradeNodes -Xmls @($Xml) -UpgradeId $UpgradeId)
    Assert-True -Condition ($nodes.Count -gt 0) -Message "$UpgradeId overlay not found."

    $hit = $false
    foreach ($node in $nodes) {
        foreach ($effect in @($node.EffectArray)) {
            if (([string]$effect.Reference -ne $Reference) -or ([string]$effect.Value -ne $Value)) {
                continue
            }

            if ([string]::IsNullOrWhiteSpace($Operation) -or ([string]$effect.Operation -eq $Operation)) {
                $hit = $true
                break
            }
        }

        if ($hit) {
            break
        }
    }

    Assert-True -Condition $hit -Message ("{0} missing overlay effect Reference='{1}' Value='{2}' Operation='{3}'." -f $UpgradeId, $Reference, $Value, $Operation)
}

function Add-PrestigeUpgradeId {
    param(
        [System.Collections.Generic.HashSet[string]]$Set,
        [string]$UpgradeId
    )

    if (-not [string]::IsNullOrWhiteSpace($UpgradeId)) {
        [void]$Set.Add($UpgradeId)
    }
}

function Get-CommanderPrestigeUpgradeIds {
    param($Commander)

    $upgradeIds = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($prestige in @($Commander.prestiges)) {
        Add-PrestigeUpgradeId -Set $upgradeIds -UpgradeId ([string]$prestige.primary_upgrade)
        if ($null -ne $prestige.PSObject.Properties["fusion_primary_upgrade"]) {
            Add-PrestigeUpgradeId -Set $upgradeIds -UpgradeId ([string]$prestige.fusion_primary_upgrade)
        }
        foreach ($supplement in @($prestige.upgrade_supplements)) {
            foreach ($supplementUpgrade in @($supplement.supplement_upgrades)) {
                Add-PrestigeUpgradeId -Set $upgradeIds -UpgradeId ([string]$supplementUpgrade)
            }
        }
    }

    return @($upgradeIds | Sort-Object)
}

function Get-CommanderSuffixes {
    param($Commander)

    $suffixes = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($value in @($Commander.bank_commander, $Commander.generated_commander, $Commander.official_short_id)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
            [void]$suffixes.Add([string]$value)
        }
    }

    return $suffixes
}

function Test-UnitMatchesCommanderSuffix {
    param(
        [string]$UnitId,
        [System.Collections.Generic.HashSet[string]]$Suffixes
    )

    foreach ($suffix in $Suffixes) {
        if ($UnitId.EndsWith($suffix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Test-PrestigeMirrorCandidateUnit {
    param([string]$UnitId)

    if ($UnitId -match "Wreckage") {
        return $false
    }

    return $true
}

$workspaceRoot = Get-WorkspaceRoot
$repoRoot = Split-Path -Parent $workspaceRoot
$metadata = Get-CommanderPowerMetadata -WorkspaceRoot $workspaceRoot
$catalogGameData = Join-Path $workspaceRoot "Mods\7vs1\CommanderCatalog.SC2Mod\Base.SC2Data\GameData"
$coopZeroPopGameData = Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\GameData"
$unitXmls = Read-CatalogXmlSet -GameDataRoot $catalogGameData -BaseName "UnitData"
$overlayUpgradeXmls = Read-CatalogXmlSet -GameDataRoot $catalogGameData -BaseName "UpgradeData"
$overlayUpgradeXml = Read-CatalogXml -Path (Join-Path $catalogGameData "UpgradeData.xml")
$coopZeroPopUpgradeXml = Read-CatalogXml -Path (Join-Path $coopZeroPopGameData "UpgradeData.xml")
$coopZeroPopEffectXml = Read-CatalogXml -Path (Join-Path $coopZeroPopGameData "EffectData.xml")
$coopZeroPopRequirementXml = Read-CatalogXml -Path (Join-Path $coopZeroPopGameData "RequirementData.xml")
$coopZeroPopRequirementNodeXml = Read-CatalogXml -Path (Join-Path $coopZeroPopGameData "RequirementNodeData.xml")
$generatedGalaxyPath = Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\LibE0EAE146_CommanderPowerGenerated.galaxy"
Assert-True -Condition (Test-Path -LiteralPath $generatedGalaxyPath) -Message "Generated CommanderPower Galaxy not found: $generatedGalaxyPath"
$generatedGalaxy = Get-Content -LiteralPath $generatedGalaxyPath -Encoding UTF8 -Raw
$profileGalaxyPath = Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\LibE0EAE146_CommanderPowerProfile.galaxy"
Assert-True -Condition (Test-Path -LiteralPath $profileGalaxyPath) -Message "CommanderPower profile Galaxy not found: $profileGalaxyPath"
$profileGalaxy = Get-Content -LiteralPath $profileGalaxyPath -Encoding UTF8 -Raw
$runtimeGalaxy = $generatedGalaxy + "`n" + $profileGalaxy

$sourceUpgradePaths = @(
    (Join-Path $repoRoot "_codex_7vs1_source_root\s2ma_packages\pkg01\extract\base.sc2data\GameData\UpgradeData.xml"),
    (Join-Path $repoRoot "_codex_7vs1_source_root\s2ma_packages\pkg01\extract\base.sc2data\GameData\Commanders\CommanderTychus.xml"),
    (Join-Path $repoRoot "_codex_7vs1_source_root\s2ma_packages\pkg01\extract\base.sc2data\GameData\Commanders\FutureCommanders.xml"),
    (Join-Path $repoRoot "crys_the_swarm_reborn.SC2Mod\游戏数据\官方SC2原始文本镜像\mods\starcoop\commanders\egonstetmann.sc2mod\base.sc2data\gamedata\upgradedata.xml"),
    (Join-Path $repoRoot "crys_the_swarm_reborn.SC2Mod\游戏数据\官方SC2原始文本镜像\mods\starcoop\commanders\arcturusmengsk.sc2mod\base.sc2data\gamedata\upgradedata.xml")
)

$sourceUpgradeXmls = @()
foreach ($path in $sourceUpgradePaths) {
    if (Test-Path -LiteralPath $path) {
        $sourceUpgradeXmls += Read-CatalogXml -Path $path
    }
}

$abathurLockLayoutNodes = New-Object System.Collections.Generic.List[object]
foreach ($xml in $unitXmls) {
    foreach ($node in @($xml.SelectNodes("//LayoutButtons[@Face='CommanderPrestigeAbathurBrutaliskLocked' or @Face='CommanderPrestigeAbathurLeviathanLocked'][@Requirements='CommanderPrestigeAbathurBiomass']"))) {
        $abathurLockLayoutNodes.Add($node) | Out-Null
    }
}
Assert-True -Condition ($abathurLockLayoutNodes.Count -eq 0) -Message "Abathur biomass prestige lock overlays must not remain bound in UnitData*.xml."

$karaxLockFaces = @(
    "CommanderPrestigeKaraxPhotonCannonLocked",
    "CommanderPrestigeKaraxKhaydarinMonolithLocked",
    "CommanderPrestigeKaraxOptimizedAttackSpeedResearchLocked",
    "CommanderPrestigeKaraxChronoWaveLocked",
    "CommanderPrestigeKaraxChronoFieldLocked",
    "CommanderPrestigeKaraxChronoBoostLocked",
    "CommanderPrestigeKaraxPhotonCannonBuildLocked",
    "CommanderPrestigeKaraxKhaydarinMonolithBuildLocked"
)
$karaxLockLayoutNodes = New-Object System.Collections.Generic.List[object]
foreach ($xml in $unitXmls) {
    foreach ($face in $karaxLockFaces) {
        foreach ($node in @($xml.SelectNodes("//LayoutButtons[@Face='$face'][starts-with(@Requirements,'CommanderPrestigeKarax')]"))) {
            $karaxLockLayoutNodes.Add($node) | Out-Null
        }
    }
    foreach ($node in @($xml.SelectNodes("//LayoutButtons[starts-with(@Requirements,'KaraxLevel')]"))) {
        $karaxLockLayoutNodes.Add($node) | Out-Null
    }
}
Assert-True -Condition ($karaxLockLayoutNodes.Count -eq 0) -Message "Karax prestige fusion must not keep prestige lock overlays in UnitData*.xml."

$karaxTooltipAppenderNodes = @($unitXmls | ForEach-Object { $_.SelectNodes("//TooltipAppender[@Validator='CommanderPrestigeKaraxStructures']") })
if ($karaxTooltipAppenderNodes.Count -eq 0) {
    $buttonXml = Read-CatalogXml -Path (Join-Path $catalogGameData "ButtonData.xml")
    $karaxTooltipAppenderNodes = @($buttonXml.SelectNodes("/Catalog/CButton/TooltipAppender[@Validator='CommanderPrestigeKaraxStructures']"))
}
Assert-True -Condition ($karaxTooltipAppenderNodes.Count -eq 0) -Message "Karax prestige fusion must not keep CommanderPrestigeKaraxStructures tooltip appenders."

$karaxCommander = @($metadata.commanders | Where-Object { [string]$_.bank_commander -eq "Karax" }) | Select-Object -First 1
Assert-True -Condition ($null -ne $karaxCommander) -Message "Karax commander metadata not found."
foreach ($prestige in @($karaxCommander.prestiges)) {
    Assert-True -Condition (@($prestige.suppress_upgrades).Count -eq 0) -Message ("Karax prestige {0} still suppresses upgrades in metadata." -f [string]$prestige.id)
    Assert-True -Condition (@($prestige.disable_units).Count -eq 0) -Message ("Karax prestige {0} still disables units in metadata." -f [string]$prestige.id)
    Assert-True -Condition (@($prestige.disable_abils).Count -eq 0) -Message ("Karax prestige {0} still disables abilities in metadata." -f [string]$prestige.id)
    Assert-True -Condition (([string]$prestige.tooltip) -notmatch "缺点") -Message ("Karax prestige {0} tooltip still contains drawback text." -f [string]$prestige.id)
    Assert-True -Condition (([string]$prestige.tooltip_en) -notmatch "Disadvantage") -Message ("Karax prestige {0} English tooltip still contains drawback text." -f [string]$prestige.id)
}

$karaxRepairBeamNodes = @($coopZeroPopEffectXml.SelectNodes("/Catalog/CEffectApplyBehavior[@id='SOARepairBeamAB']/ValidatorArray[@index='5'][@removed='1']"))
Assert-True -Condition ($karaxRepairBeamNodes.Count -gt 0) -Message "Karax prestige fusion must remove the SOARepairBeamAB structure-only validator override."

$karaxHiddenRequirementNode = @($coopZeroPopRequirementNodeXml.SelectNodes("/Catalog/CRequirementConst[@id='CommanderPowerAlwaysHidden'][@parent='0']"))
Assert-True -Condition ($karaxHiddenRequirementNode.Count -gt 0) -Message "Karax prestige fusion must define CommanderPowerAlwaysHidden requirement node."
foreach ($requirementId in @("CommanderPrestigeKaraxArmy", "CommanderPrestigeKaraxStructures", "CommanderPrestigeKaraxTopBar")) {
    $requirementNodes = @($coopZeroPopRequirementXml.SelectNodes("/Catalog/CRequirement[@id='$requirementId']/NodeArray[@index='Show'][@Link='CommanderPowerAlwaysHidden']"))
    Assert-True -Condition ($requirementNodes.Count -gt 0) -Message ("Karax prestige fusion must hide requirement {0} via CommanderPowerAlwaysHidden." -f $requirementId)
}

$missingRuntimePrestigeApplications = New-Object System.Collections.Generic.List[object]
$missingPrestigeDefinitions = New-Object System.Collections.Generic.List[object]
foreach ($commander in $metadata.commanders) {
    foreach ($upgradeId in @(Get-CommanderPrestigeUpgradeIds -Commander $commander)) {
        if ($runtimeGalaxy -notmatch ('"{0}"' -f [regex]::Escape($upgradeId))) {
            $missingRuntimePrestigeApplications.Add([pscustomobject]@{
                    Commander = [string]$commander.bank_commander
                    Upgrade = $upgradeId
                }) | Out-Null
        }

        $nodes = @(Get-UpgradeNodes -Xmls ($sourceUpgradeXmls + @($overlayUpgradeXml, $coopZeroPopUpgradeXml) + $overlayUpgradeXmls) -UpgradeId $upgradeId)
        if ($nodes.Count -eq 0) {
            $missingPrestigeDefinitions.Add([pscustomobject]@{
                    Commander = [string]$commander.bank_commander
                    Upgrade = $upgradeId
                }) | Out-Null
        }
    }
}

$fusionPrestigeIds = @([regex]::Matches($runtimeGalaxy, 'CommanderPowerSetUpgradeAtLeast\([^,]+,\s*"([^"]*FusionPrestige[^"]*)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-True -Condition ($fusionPrestigeIds.Count -eq 0) -Message ("CommanderPower runtime/profile prestige applications still contain non-catalog FusionPrestige IDs:`n{0}" -f ($fusionPrestigeIds -join "`n"))
Assert-True -Condition ($missingRuntimePrestigeApplications.Count -eq 0) -Message ("Metadata prestige upgrades missing from CommanderPower runtime/profile:`n{0}" -f (($missingRuntimePrestigeApplications | Sort-Object Commander, Upgrade | Format-Table -AutoSize | Out-String).Trim()))
Assert-True -Condition ($missingPrestigeDefinitions.Count -eq 0) -Message ("Metadata prestige upgrades missing catalog/source definitions:`n{0}" -f (($missingPrestigeDefinitions | Sort-Object Commander, Upgrade | Format-Table -AutoSize | Out-String).Trim()))

$childrenByParent = @{}
foreach ($xml in $unitXmls) {
    foreach ($unit in @($xml.Catalog.CUnit)) {
        $id = [string]$unit.id
        $parent = [string]$unit.parent
        if ([string]::IsNullOrWhiteSpace($id) -or [string]::IsNullOrWhiteSpace($parent) -or ($id -eq $parent)) {
            continue
        }

        if (-not $childrenByParent.ContainsKey($parent)) {
            $childrenByParent[$parent] = New-Object System.Collections.Generic.List[string]
        }

        $childrenByParent[$parent].Add($id) | Out-Null
    }
}

$explicitRaynorBioChecks = @(
    @{ Upgrade = "CommanderPrestigeRaynorBio"; Unit = "MarineRaynor"; Fields = @("LifeMax", "LifeStart"); Value = "45" },
    @{ Upgrade = "CommanderPrestigeRaynorBio"; Unit = "MedicRaynor"; Fields = @("LifeMax", "LifeStart"); Value = "60" },
    @{ Upgrade = "CommanderPrestigeRaynorBio"; Unit = "MarauderRaynor"; Fields = @("LifeMax", "LifeStart"); Value = "125" },
    @{ Upgrade = "CommanderPrestigeRaynorBio"; Unit = "FirebatRaynor"; Fields = @("LifeMax", "LifeStart"); Value = "100" },
    @{ Upgrade = "CommanderPrestigeRaynorBioMarineUpgrade"; Unit = "MarineRaynor"; Fields = @("LifeMax", "LifeStart"); Value = "10" },
    @{ Upgrade = "CommanderPrestigeRaynorBioFirebatUpgrade"; Unit = "FirebatRaynor"; Fields = @("LifeMax", "LifeStart"); Value = "100" },
    @{ Upgrade = "CommanderPrestigeRaynorBioSuperStim"; Reference = "Abil,SuperStimpackMarineRaynor,Cost[0].Vital[Life]"; Value = "0"; Operation = "Set" },
    @{ Upgrade = "CommanderPrestigeRaynorBioSuperStim"; Reference = "Abil,StimpackMarauderRaynor,Cost[0].Vital[Life]"; Value = "0"; Operation = "Set" },
    @{ Upgrade = "CommanderPrestigeRaynorBioSuperStim"; Reference = "Abil,StimpackFirebatRaynor,Cost[0].Vital[Life]"; Value = "0"; Operation = "Set" },
    @{ Upgrade = "CommanderPrestigeRaynorBioSuperStim"; Reference = "Behavior,StimpackMarauderRaynor,Modification.VitalRegenArray[Life]"; Value = "1"; Operation = "Set" },
    @{ Upgrade = "CommanderPrestigeRaynorBioSuperStim"; Reference = "Behavior,StimpackFirebatRaynor,Modification.VitalRegenArray[Life]"; Value = "1"; Operation = "Set" }
)

foreach ($level in 1..3) {
    $explicitRaynorBioChecks += @(
        @{ Upgrade = "CommanderPrestigeRaynorBioUpgradeTerranInfantryArmorLevel$level"; Unit = "MarineRaynor"; Fields = @("LifeMax", "LifeStart"); Value = "4.5" },
        @{ Upgrade = "CommanderPrestigeRaynorBioUpgradeTerranInfantryArmorLevel$level"; Unit = "MarauderRaynor"; Fields = @("LifeMax", "LifeStart"); Value = "12.5" },
        @{ Upgrade = "CommanderPrestigeRaynorBioUpgradeTerranInfantryArmorLevel$level"; Unit = "FirebatRaynor"; Fields = @("LifeMax", "LifeStart"); Value = "10" },
        @{ Upgrade = "CommanderPrestigeRaynorBioUpgradeTerranInfantryArmorLevel$level"; Unit = "MedicRaynor"; Fields = @("LifeMax", "LifeStart"); Value = "6" }
    )
}

foreach ($check in $explicitRaynorBioChecks) {
    if ($check.ContainsKey("Reference")) {
        Assert-OverlayEffect -Xml $overlayUpgradeXml -UpgradeId $check.Upgrade -Reference $check.Reference -Value $check.Value -Operation $check.Operation
        continue
    }

    foreach ($field in $check.Fields) {
        Assert-OverlayEffect -Xml $overlayUpgradeXml -UpgradeId $check.Upgrade -Reference ("Unit,{0},{1}" -f $check.Unit, $field) -Value $check.Value
    }
}

$explicitRaynorAirChecks = @(
    @{ Unit = "VikingAssaultRaynor"; Field = "CostResource[Vespene]"; Value = "18"; Operation = "Subtract" },
    @{ Unit = "VikingRaynor"; Field = "CostResource[Vespene]"; Value = "18"; Operation = "Subtract" },
    @{ Unit = "BansheeRaynor"; Field = "CostResource[Vespene]"; Value = "24"; Operation = "Subtract" },
    @{ Unit = "BattlecruiserRaynor"; Field = "CostResource[Vespene]"; Value = "72"; Operation = "Subtract" },
    @{ Unit = "StarportRaynor"; Field = "CostResource[Vespene]"; Value = "100"; Operation = "Subtract" },
    @{ Unit = "StarportFlyingRaynor"; Field = "CostResource[Vespene]"; Value = "100"; Operation = "Subtract" }
)

foreach ($check in $explicitRaynorAirChecks) {
    Assert-OverlayEffect -Xml $overlayUpgradeXml -UpgradeId "CommanderPrestigeRaynorAir" -Reference ("Unit,{0},{1}" -f $check.Unit, $check.Field) -Value $check.Value -Operation $check.Operation
}

$missingMirrors = New-Object System.Collections.Generic.List[object]
foreach ($commander in $metadata.commanders) {
    $suffixes = Get-CommanderSuffixes -Commander $commander
    foreach ($upgradeId in @(Get-CommanderPrestigeUpgradeIds -Commander $commander)) {
        $sourceNodes = @(Get-UpgradeNodes -Xmls $sourceUpgradeXmls -UpgradeId $upgradeId)
        if ($sourceNodes.Count -eq 0) {
            continue
        }

        $removedEffectIndexes = Get-RemovedEffectIndexes -Xmls $overlayUpgradeXmls -UpgradeId $upgradeId

        $availableRefs = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($node in @(Get-UpgradeNodes -Xmls ($sourceUpgradeXmls + @($overlayUpgradeXml, $coopZeroPopUpgradeXml) + $overlayUpgradeXmls) -UpgradeId $upgradeId)) {
            foreach ($effect in @($node.EffectArray)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$effect.Reference)) {
                    [void]$availableRefs.Add([string]$effect.Reference)
                }
            }
        }

        $reportedKeys = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($node in $sourceNodes) {
            $sourceEffects = @($node.EffectArray)
            for ($effectIndex = 0; $effectIndex -lt $sourceEffects.Count; $effectIndex++) {
                if ($removedEffectIndexes.Contains($effectIndex)) {
                    continue
                }

                $effect = $sourceEffects[$effectIndex]
                $reference = [string]$effect.Reference
                if ($reference -notmatch '^Unit,([^,]+),(.+)$') {
                    continue
                }

                $sourceUnit = $Matches[1]
                $field = $Matches[2]
                if (-not $childrenByParent.ContainsKey($sourceUnit)) {
                    continue
                }

                foreach ($childUnit in $childrenByParent[$sourceUnit]) {
                    if (-not (Test-PrestigeMirrorCandidateUnit -UnitId $childUnit)) {
                        continue
                    }

                    if (-not (Test-UnitMatchesCommanderSuffix -UnitId $childUnit -Suffixes $suffixes)) {
                        continue
                    }

                    $childReference = "Unit,$childUnit,$field"
                    if ($availableRefs.Contains($childReference)) {
                        continue
                    }

                    $key = "{0}|{1}|{2}" -f $upgradeId, $childUnit, $field
                    if ($reportedKeys.Add($key)) {
                        $missingMirrors.Add([pscustomobject]@{
                                Commander = [string]$commander.bank_commander
                                Upgrade = $upgradeId
                                SourceUnit = $sourceUnit
                                PrivateUnit = $childUnit
                                Field = $field
                            }) | Out-Null
                    }
                }
            }
        }
    }
}

Assert-True -Condition ($missingMirrors.Count -eq 0) -Message ("Missing private-unit prestige effect mirrors:`n{0}" -f (($missingMirrors | Sort-Object Commander, Upgrade, PrivateUnit, Field | Format-Table -AutoSize | Out-String).Trim()))

Write-Host ("COMMANDER_POWER_PRESTIGE_FUSION_VALIDATE=PASS commanders={0} raynorBioChecks={1} raynorAirChecks={2} runtimeMissing={3} definitionMissing={4} fusionPlaceholders={5} privateUnitMirrorMissing={6}" -f @($metadata.commanders).Count, $explicitRaynorBioChecks.Count, $explicitRaynorAirChecks.Count, $missingRuntimePrestigeApplications.Count, $missingPrestigeDefinitions.Count, $fusionPrestigeIds.Count, $missingMirrors.Count)
