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

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Needle,
        [string]$Message
    )

    Assert-True -Condition $Text.Contains($Needle) -Message $Message
}

function Get-CatalogNode {
    param(
        [xml]$Xml,
        [string]$TagName,
        [string]$Id
    )

    $nodes = @($Xml.SelectNodes("/Catalog/$TagName[@id='$Id']"))
    Assert-True -Condition ($nodes.Count -gt 0) -Message "$TagName '$Id' not found."
    return $nodes[$nodes.Count - 1]
}

function Get-CombinedCatalogNode {
    param(
        [xml[]]$Xmls,
        [string]$TagName,
        [string]$Id
    )

    return (Get-CatalogNodeById -Xmls $Xmls -TagName $TagName -Id $Id)
}

function Get-UpgradeIdsInFiles {
    param([string[]]$Paths)

    $ids = New-Object System.Collections.Generic.HashSet[string]
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        $text = Get-Content -LiteralPath $path -Encoding UTF8 -Raw
        foreach ($match in [regex]::Matches($text, '<CUpgrade\s+id="([^"]+)"')) {
            [void]$ids.Add($match.Groups[1].Value)
        }
    }

    return $ids
}

function Get-Level4FamiliesWithoutLevel5 {
    param([string[]]$Paths)

    $ids = Get-UpgradeIdsInFiles -Paths $Paths
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($id in $ids) {
        if (-not $id.EndsWith("Level4")) {
            continue
        }

        $level5 = $id.Substring(0, $id.Length - 1) + "5"
        if (-not $ids.Contains($level5)) {
            $missing.Add($id) | Out-Null
        }
    }

    return @($missing | Sort-Object)
}

function Assert-ResearchInfo {
    param(
        [xml]$Xml,
        [string]$AbilityId,
        [string]$Index,
        [string]$UpgradeId,
        [string]$ButtonId,
        [string]$RequirementId
    )

    $ability = Get-CatalogNode -Xml $Xml -TagName "CAbilResearch" -Id $AbilityId
    $info = @($ability.InfoArray | Where-Object { [string]$_.index -eq $Index } | Select-Object -First 1)
    Assert-True -Condition ($null -ne $info) -Message "$AbilityId missing InfoArray $Index."
    Assert-True -Condition ([string]$info.Upgrade -eq $UpgradeId) -Message "$AbilityId $Index expected Upgrade=$UpgradeId, got '$($info.Upgrade)'."
    Assert-True -Condition ([string]$info.Button.DefaultButtonFace -eq $ButtonId) -Message "$AbilityId $Index expected Button=$ButtonId, got '$($info.Button.DefaultButtonFace)'."
    if (-not [string]::IsNullOrWhiteSpace($RequirementId)) {
        Assert-True -Condition ([string]$info.Button.Requirements -eq $RequirementId) -Message "$AbilityId $Index expected Requirements=$RequirementId, got '$($info.Button.Requirements)'."
    }
}

function Assert-LayoutButton {
    param(
        [xml[]]$Xmls,
        [string]$UnitId,
        [string]$Face,
        [string]$AbilCmd
    )

    $unit = Get-CombinedCatalogNode -Xmls $Xmls -TagName "CUnit" -Id $UnitId
    $button = @($unit.CardLayouts.LayoutButtons | Where-Object {
            ([string]$_.Face -eq $Face) -and ([string]$_.AbilCmd -eq $AbilCmd)
        } | Select-Object -First 1)
    Assert-True -Condition ($null -ne $button) -Message "$UnitId command card missing $Face -> $AbilCmd."
}

function Assert-UpgradeTargets {
    param(
        [xml]$Xml,
        [string]$UpgradeId,
        [string[]]$AffectedUnits,
        [string[]]$ArmorEffectUnits = @()
    )

    $upgrade = Get-CatalogNode -Xml $Xml -TagName "CUpgrade" -Id $UpgradeId
    foreach ($unit in $AffectedUnits) {
        $hit = @($upgrade.AffectedUnitArray | Where-Object { [string]$_.value -eq $unit } | Select-Object -First 1)
        Assert-True -Condition ($null -ne $hit) -Message "$UpgradeId missing AffectedUnitArray $unit."
    }

    foreach ($unit in $ArmorEffectUnits) {
        foreach ($field in @("LifeArmor", "LifeArmorLevel")) {
            $reference = "Unit,$unit,$field"
            $hit = @($upgrade.EffectArray | Where-Object { [string]$_.Reference -eq $reference } | Select-Object -First 1)
            Assert-True -Condition ($null -ne $hit) -Message "$UpgradeId missing actual armor effect $reference."
        }
    }
}

function Assert-UpgradeParent {
    param(
        [xml]$Xml,
        [string]$UpgradeId,
        [string]$ParentId
    )

    $upgrade = Get-CatalogNode -Xml $Xml -TagName "CUpgrade" -Id $UpgradeId
    Assert-True -Condition ([string]$upgrade.parent -eq $ParentId) -Message "$UpgradeId expected parent $ParentId, got '$($upgrade.parent)'."
}

$workspaceRoot = Get-WorkspaceRoot
$repoRoot = Split-Path -Parent $workspaceRoot
$metadata = Get-CommanderPowerMetadata -WorkspaceRoot $workspaceRoot
$generatedPath = Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\LibE0EAE146_CommanderPowerGenerated.galaxy"
$closurePath = Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\LibE0EAE146_CommanderPowerGeneratedClosure.galaxy"
$generatedText = Get-Content -LiteralPath $generatedPath -Encoding UTF8 -Raw
$closureText = Get-Content -LiteralPath $closurePath -Encoding UTF8 -Raw

Assert-True -Condition (@($metadata.commanders).Count -eq 18) -Message "Expected 18 CommanderPower commanders."
foreach ($commander in $metadata.commanders) {
    $bank = [string]$commander.bank_commander
    $generated = [string]$commander.generated_commander

    Assert-True -Condition (@($commander.prestiges).Count -eq 3) -Message "$bank must expose 3 independent prestige bonus slots."
    Assert-True -Condition (@($commander.masteries).Count -eq 6) -Message "$bank must expose 6 independent mastery slots."
    Assert-Contains -Text $generatedText -Needle ('lv_prestigeMask = libE0EAE146_gf_CommanderPowerPrestigeMask("{0}");' -f $bank) -Message "$bank generated prestige bonus mask read missing."
    Assert-Contains -Text $generatedText -Needle ('libE0EAE146_gf_CommanderPowerGeneratedApply{0}Prestiges' -f $generated) -Message "$bank generated prestige apply function missing."
    Assert-Contains -Text $generatedText -Needle ('libE0EAE146_gf_CommanderPowerGeneratedApply{0}Masteries' -f $generated) -Message "$bank generated mastery apply function missing."
    Assert-Contains -Text $generatedText -Needle ('libE0EAE146_gf_CommanderPowerGeneratedApply{0}Closure' -f $generated) -Message "$bank generated closure hook missing."

    for ($slot = 0; $slot -lt 6; $slot++) {
        $mastery = $commander.masteries[$slot]
        Assert-True -Condition ([int]$mastery.slot -eq $slot) -Message "$bank mastery slot order mismatch at $slot."
        Assert-Contains -Text $generatedText -Needle ('libE0EAE146_gf_CommanderPowerMasteryLevel("{0}", {1})' -f $bank, $slot) -Message "$bank mastery slot $slot level read missing."
        Assert-Contains -Text $generatedText -Needle ('"{0}"' -f [string]$mastery.upgrade) -Message "$bank mastery slot $slot upgrade '$($mastery.upgrade)' not applied."
    }

    for ($slot = 0; $slot -lt 3; $slot++) {
        $prestige = $commander.prestiges[$slot]
        Assert-True -Condition ([int]$prestige.slot -eq $slot) -Message "$bank prestige slot order mismatch at $slot."
        Assert-True -Condition ([int]$prestige.bit_mask -eq (1 -shl $slot)) -Message "$bank prestige slot $slot bit mask mismatch."
        Assert-Contains -Text $generatedText -Needle ('BitMaskTrueIndexIs(lv_prestigeMask, {0})' -f $slot) -Message "$bank prestige slot $slot bit check missing."
    }
}

$catalogGameData = Join-Path $workspaceRoot "Mods\7vs1\CommanderCatalog.SC2Mod\Base.SC2Data\GameData"
$abilXml = Read-CatalogXml -Path (Join-Path $catalogGameData "AbilData.xml")
$buttonXml = Read-CatalogXml -Path (Join-Path $catalogGameData "ButtonData.xml")
$requirementXml = Read-CatalogXml -Path (Join-Path $catalogGameData "RequirementData.xml")
$requirementNodeXml = Read-CatalogXml -Path (Join-Path $catalogGameData "RequirementNodeData.xml")
$unitXmls = Read-CatalogXmlSet -GameDataRoot $catalogGameData -BaseName "UnitData"
$upgradeXml = Read-CatalogXml -Path (Join-Path $catalogGameData "UpgradeData.xml")

$raynorTechs = @(
    @{ Unit = "EngineeringBayRaynor"; Ability = "EngineeringBayResearchRaynor"; Face = "TerranInfantryWeaponsLevel1"; Cmd = "Research3"; Upgrade = "TerranInfantryWeaponsLevel1"; Button = ""; Requirement = ""; Units = @("MarineRaynor", "FirebatRaynor", "MarauderRaynor"); ArmorUnits = @() },
    @{ Unit = "EngineeringBayRaynor"; Ability = "EngineeringBayResearchRaynor"; Face = "TerranInfantryWeaponsLevel2"; Cmd = "Research4"; Upgrade = "TerranInfantryWeaponsLevel2"; Button = ""; Requirement = ""; Units = @("MarineRaynor", "FirebatRaynor", "MarauderRaynor"); ArmorUnits = @() },
    @{ Unit = "EngineeringBayRaynor"; Ability = "EngineeringBayResearchRaynor"; Face = "TerranInfantryWeaponsLevel3"; Cmd = "Research5"; Upgrade = "TerranInfantryWeaponsLevel3"; Button = ""; Requirement = ""; Units = @("MarineRaynor", "FirebatRaynor", "MarauderRaynor"); ArmorUnits = @() },
    @{ Unit = "EngineeringBayRaynor"; Ability = "EngineeringBayResearchRaynor"; Face = "TerranInfantryWeaponsLevel4"; Cmd = "Research19"; Upgrade = "TerranInfantryWeaponsLevel4"; Button = ""; Requirement = ""; Units = @("MarineRaynor", "FirebatRaynor", "MarauderRaynor"); ArmorUnits = @() },
    @{ Unit = "EngineeringBayRaynor"; Ability = "EngineeringBayResearchRaynor"; Face = "TerranInfantryWeaponsLevel5"; Cmd = "Research21"; Upgrade = "TerranInfantryWeaponsLevel5"; Button = "TerranInfantryWeaponsLevel5"; Requirement = "LearnTerranInfantryWeapon5Raynor"; Units = @("MarineRaynor", "FirebatRaynor", "MarauderRaynor"); ArmorUnits = @() },
    @{ Unit = "EngineeringBayRaynor"; Ability = "EngineeringBayResearchRaynor"; Face = "TerranInfantryArmorLevel1"; Cmd = "Research7"; Upgrade = "TerranInfantryArmorsLevel1"; Button = ""; Requirement = ""; Units = @("SCVRaynor", "MarineRaynor", "MedicRaynor", "FirebatRaynor", "MarauderRaynor"); ArmorUnits = @("SCVRaynor", "MarineRaynor", "MedicRaynor", "FirebatRaynor", "MarauderRaynor") },
    @{ Unit = "EngineeringBayRaynor"; Ability = "EngineeringBayResearchRaynor"; Face = "TerranInfantryArmorLevel2"; Cmd = "Research8"; Upgrade = "TerranInfantryArmorsLevel2"; Button = ""; Requirement = ""; Units = @("SCVRaynor", "MarineRaynor", "MedicRaynor", "FirebatRaynor", "MarauderRaynor"); ArmorUnits = @("SCVRaynor", "MarineRaynor", "MedicRaynor", "FirebatRaynor", "MarauderRaynor") },
    @{ Unit = "EngineeringBayRaynor"; Ability = "EngineeringBayResearchRaynor"; Face = "TerranInfantryArmorLevel3"; Cmd = "Research9"; Upgrade = "TerranInfantryArmorsLevel3"; Button = ""; Requirement = ""; Units = @("SCVRaynor", "MarineRaynor", "MedicRaynor", "FirebatRaynor", "MarauderRaynor"); ArmorUnits = @("SCVRaynor", "MarineRaynor", "MedicRaynor", "FirebatRaynor", "MarauderRaynor") },
    @{ Unit = "EngineeringBayRaynor"; Ability = "EngineeringBayResearchRaynor"; Face = "TerranInfantryArmorLevel4"; Cmd = "Research20"; Upgrade = "TerranInfantryArmorsLevel4"; Button = ""; Requirement = ""; Units = @("SCVRaynor", "MarineRaynor", "MedicRaynor", "FirebatRaynor", "MarauderRaynor"); ArmorUnits = @("SCVRaynor", "MarineRaynor", "MedicRaynor", "FirebatRaynor", "MarauderRaynor") },
    @{ Unit = "EngineeringBayRaynor"; Ability = "EngineeringBayResearchRaynor"; Face = "TerranInfantryArmorLevel5"; Cmd = "Research22"; Upgrade = "TerranInfantryArmorsLevel5"; Button = "TerranInfantryArmorLevel5"; Requirement = "LearnTerranInfantryArmor5Raynor"; Units = @("SCVRaynor", "MarineRaynor", "MedicRaynor", "FirebatRaynor", "MarauderRaynor"); ArmorUnits = @("SCVRaynor", "MarineRaynor", "MedicRaynor", "FirebatRaynor", "MarauderRaynor") },
    @{ Unit = "ArmoryRaynor"; Ability = "ArmoryResearchRaynor"; Face = "TerranVehicleAndShipWeaponsLevel1"; Cmd = "Research1"; Upgrade = "TerranVehicleAndShipWeaponsLevel1"; Button = ""; Requirement = ""; Units = @("VultureRaynor", "SiegeTankRaynor", "SiegeTankSiegedRaynor", "VikingRaynor", "VikingAssaultRaynor", "BansheeRaynor", "BattlecruiserRaynor"); ArmorUnits = @() },
    @{ Unit = "ArmoryRaynor"; Ability = "ArmoryResearchRaynor"; Face = "TerranVehicleAndShipWeaponsLevel2"; Cmd = "Research2"; Upgrade = "TerranVehicleAndShipWeaponsLevel2"; Button = ""; Requirement = ""; Units = @("VultureRaynor", "SiegeTankRaynor", "SiegeTankSiegedRaynor", "VikingRaynor", "VikingAssaultRaynor", "BansheeRaynor", "BattlecruiserRaynor"); ArmorUnits = @() },
    @{ Unit = "ArmoryRaynor"; Ability = "ArmoryResearchRaynor"; Face = "TerranVehicleAndShipWeaponsLevel3"; Cmd = "Research3"; Upgrade = "TerranVehicleAndShipWeaponsLevel3"; Button = ""; Requirement = ""; Units = @("VultureRaynor", "SiegeTankRaynor", "SiegeTankSiegedRaynor", "VikingRaynor", "VikingAssaultRaynor", "BansheeRaynor", "BattlecruiserRaynor"); ArmorUnits = @() },
    @{ Unit = "ArmoryRaynor"; Ability = "ArmoryResearchRaynor"; Face = "TerranVehicleAndShipWeaponsLevel4"; Cmd = "Research7"; Upgrade = "TerranVehicleAndShipWeaponsLevel4"; Button = ""; Requirement = ""; Units = @("VultureRaynor", "SiegeTankRaynor", "SiegeTankSiegedRaynor", "VikingRaynor", "VikingAssaultRaynor", "BansheeRaynor", "BattlecruiserRaynor"); ArmorUnits = @() },
    @{ Unit = "ArmoryRaynor"; Ability = "ArmoryResearchRaynor"; Face = "TerranVehicleAndShipWeaponsLevel5"; Cmd = "Research9"; Upgrade = "TerranVehicleAndShipWeaponsLevel5"; Button = "TerranVehicleAndShipWeaponsLevel5"; Requirement = "LearnTerranVehicleAndShipWeapon5Raynor"; Units = @("VultureRaynor", "SiegeTankRaynor", "SiegeTankSiegedRaynor", "VikingRaynor", "VikingAssaultRaynor", "BansheeRaynor", "BattlecruiserRaynor"); ArmorUnits = @() },
    @{ Unit = "ArmoryRaynor"; Ability = "ArmoryResearchRaynor"; Face = "TerranVehicleAndShipPlatingLevel1"; Cmd = "Research4"; Upgrade = "TerranVehicleAndShipArmorsLevel1"; Button = ""; Requirement = ""; Units = @("VultureRaynor", "SiegeTankRaynor", "SiegeTankSiegedRaynor", "VikingRaynor", "VikingAssaultRaynor", "BansheeRaynor", "BattlecruiserRaynor"); ArmorUnits = @("VultureRaynor", "SiegeTankRaynor", "SiegeTankSiegedRaynor", "VikingRaynor", "VikingAssaultRaynor", "BansheeRaynor", "BattlecruiserRaynor") },
    @{ Unit = "ArmoryRaynor"; Ability = "ArmoryResearchRaynor"; Face = "TerranVehicleAndShipPlatingLevel2"; Cmd = "Research5"; Upgrade = "TerranVehicleAndShipArmorsLevel2"; Button = ""; Requirement = ""; Units = @("VultureRaynor", "SiegeTankRaynor", "SiegeTankSiegedRaynor", "VikingRaynor", "VikingAssaultRaynor", "BansheeRaynor", "BattlecruiserRaynor"); ArmorUnits = @("VultureRaynor", "SiegeTankRaynor", "SiegeTankSiegedRaynor", "VikingRaynor", "VikingAssaultRaynor", "BansheeRaynor", "BattlecruiserRaynor") },
    @{ Unit = "ArmoryRaynor"; Ability = "ArmoryResearchRaynor"; Face = "TerranVehicleAndShipPlatingLevel3"; Cmd = "Research6"; Upgrade = "TerranVehicleAndShipArmorsLevel3"; Button = ""; Requirement = ""; Units = @("VultureRaynor", "SiegeTankRaynor", "SiegeTankSiegedRaynor", "VikingRaynor", "VikingAssaultRaynor", "BansheeRaynor", "BattlecruiserRaynor"); ArmorUnits = @("VultureRaynor", "SiegeTankRaynor", "SiegeTankSiegedRaynor", "VikingRaynor", "VikingAssaultRaynor", "BansheeRaynor", "BattlecruiserRaynor") },
    @{ Unit = "ArmoryRaynor"; Ability = "ArmoryResearchRaynor"; Face = "TerranVehicleAndShipPlatingLevel4"; Cmd = "Research8"; Upgrade = "TerranVehicleAndShipArmorsLevel4"; Button = ""; Requirement = ""; Units = @("VultureRaynor", "SiegeTankRaynor", "SiegeTankSiegedRaynor", "VikingRaynor", "VikingAssaultRaynor", "BansheeRaynor", "BattlecruiserRaynor"); ArmorUnits = @("VultureRaynor", "SiegeTankRaynor", "SiegeTankSiegedRaynor", "VikingRaynor", "VikingAssaultRaynor", "BansheeRaynor", "BattlecruiserRaynor") },
    @{ Unit = "ArmoryRaynor"; Ability = "ArmoryResearchRaynor"; Face = "TerranVehicleAndShipPlatingLevel5"; Cmd = "Research10"; Upgrade = "TerranVehicleAndShipArmorsLevel5"; Button = "TerranVehicleAndShipPlatingLevel5"; Requirement = "LearnTerranVehicleAndShipArmor5Raynor"; Units = @("VultureRaynor", "SiegeTankRaynor", "SiegeTankSiegedRaynor", "VikingRaynor", "VikingAssaultRaynor", "BansheeRaynor", "BattlecruiserRaynor"); ArmorUnits = @("VultureRaynor", "SiegeTankRaynor", "SiegeTankSiegedRaynor", "VikingRaynor", "VikingAssaultRaynor", "BansheeRaynor", "BattlecruiserRaynor") }
)

foreach ($tech in $raynorTechs) {
    Assert-LayoutButton -Xmls $unitXmls -UnitId $tech.Unit -Face $tech.Face -AbilCmd ("{0},{1}" -f $tech.Ability, $tech.Cmd)
    if (-not [string]::IsNullOrWhiteSpace($tech.Button)) {
        [void](Get-CatalogNode -Xml $buttonXml -TagName "CButton" -Id $tech.Button)
        [void](Get-CatalogNode -Xml $requirementXml -TagName "CRequirement" -Id $tech.Requirement)
        Assert-ResearchInfo -Xml $abilXml -AbilityId $tech.Ability -Index $tech.Cmd -UpgradeId $tech.Upgrade -ButtonId $tech.Button -RequirementId $tech.Requirement
    }
    Assert-UpgradeTargets -Xml $upgradeXml -UpgradeId $tech.Upgrade -AffectedUnits $tech.Units -ArmorEffectUnits $tech.ArmorUnits
}

$genericTerranTechs = @(
    @{ Unit = "EngineeringBay"; Ability = "EngineeringBayResearch"; Face = "TerranInfantryWeaponsLevel5"; Cmd = "Research26"; Upgrade = "TerranInfantryWeaponsLevel5"; Button = "TerranInfantryWeaponsLevel5"; Requirement = "LearnTerranInfantryWeapon5"; Parent = "TerranInfantryWeaponsLevel4" },
    @{ Unit = "EngineeringBay"; Ability = "EngineeringBayResearch"; Face = "TerranInfantryArmorLevel5"; Cmd = "Research27"; Upgrade = "TerranInfantryArmorsLevel5"; Button = "TerranInfantryArmorLevel5"; Requirement = "LearnTerranInfantryArmor5"; Parent = "TerranInfantryArmorsLevel4" },
    @{ Unit = "Armory"; Ability = "ArmoryResearchVoidCoop"; Face = "TerranVehicleAndShipWeaponsLevel5"; Cmd = "Research19"; Upgrade = "TerranVehicleAndShipWeaponsLevel5"; Button = "TerranVehicleAndShipWeaponsLevel5"; Requirement = "LearnTerranVehicleAndShipWeapon5"; Parent = "TerranVehicleAndShipWeaponsLevel4" },
    @{ Unit = "Armory"; Ability = "ArmoryResearchVoidCoop"; Face = "TerranVehicleAndShipPlatingLevel5"; Cmd = "Research20"; Upgrade = "TerranVehicleAndShipArmorsLevel5"; Button = "TerranVehicleAndShipPlatingLevel5"; Requirement = "LearnTerranVehicleAndShipArmor5"; Parent = "TerranVehicleAndShipArmorsLevel4" }
)

foreach ($tech in $genericTerranTechs) {
    Assert-LayoutButton -Xmls $unitXmls -UnitId $tech.Unit -Face $tech.Face -AbilCmd ("{0},{1}" -f $tech.Ability, $tech.Cmd)
    [void](Get-CatalogNode -Xml $buttonXml -TagName "CButton" -Id $tech.Button)
    [void](Get-CatalogNode -Xml $requirementXml -TagName "CRequirement" -Id $tech.Requirement)
    Assert-ResearchInfo -Xml $abilXml -AbilityId $tech.Ability -Index $tech.Cmd -UpgradeId $tech.Upgrade -ButtonId $tech.Button -RequirementId $tech.Requirement
    Assert-UpgradeParent -Xml $upgradeXml -UpgradeId $tech.Upgrade -ParentId $tech.Parent
}

$zeratulTechs = @(
    @{ Unit = "Forge"; Ability = "ForgeResearchZeratul"; Face = "ZeratulWeaponsLevel4"; Cmd = "Research10"; Upgrade = "ZeratulWeaponsLevel4"; Button = "ZeratulWeaponsLevel4"; Requirement = "LearnZeratulWeapon4" },
    @{ Unit = "Forge"; Ability = "ForgeResearchZeratul"; Face = "ZeratulWeaponsLevel5"; Cmd = "Research11"; Upgrade = "ZeratulWeaponsLevel5"; Button = "ZeratulWeaponsLevel5"; Requirement = "LearnZeratulWeapon5"; Parent = "ZeratulWeaponsLevel4" },
    @{ Unit = "Forge"; Ability = "ForgeResearchZeratul"; Face = "ZeratulArmorLevel4"; Cmd = "Research12"; Upgrade = "ZeratulArmorsLevel4"; Button = "ZeratulArmorLevel4"; Requirement = "LearnZeratulArmor4" },
    @{ Unit = "Forge"; Ability = "ForgeResearchZeratul"; Face = "ZeratulArmorLevel5"; Cmd = "Research13"; Upgrade = "ZeratulArmorsLevel5"; Button = "ZeratulArmorLevel5"; Requirement = "LearnZeratulArmor5"; Parent = "ZeratulArmorsLevel4" },
    @{ Unit = "Forge"; Ability = "ForgeResearchZeratul"; Face = "ZeratulShieldsLevel4"; Cmd = "Research14"; Upgrade = "ZeratulShieldsLevel4"; Button = "ZeratulShieldsLevel4"; Requirement = "LearnZeratulShield4" },
    @{ Unit = "Forge"; Ability = "ForgeResearchZeratul"; Face = "ZeratulShieldsLevel5"; Cmd = "Research15"; Upgrade = "ZeratulShieldsLevel5"; Button = "ZeratulShieldsLevel5"; Requirement = "LearnZeratulShield5"; Parent = "ZeratulShieldsLevel4" }
)

foreach ($tech in $zeratulTechs) {
    Assert-LayoutButton -Xmls $unitXmls -UnitId $tech.Unit -Face $tech.Face -AbilCmd ("{0},{1}" -f $tech.Ability, $tech.Cmd)
    [void](Get-CatalogNode -Xml $buttonXml -TagName "CButton" -Id $tech.Button)
    [void](Get-CatalogNode -Xml $requirementXml -TagName "CRequirement" -Id $tech.Requirement)
    Assert-ResearchInfo -Xml $abilXml -AbilityId $tech.Ability -Index $tech.Cmd -UpgradeId $tech.Upgrade -ButtonId $tech.Button -RequirementId $tech.Requirement
    if (-not [string]::IsNullOrWhiteSpace($tech.Parent)) {
        Assert-UpgradeParent -Xml $upgradeXml -UpgradeId $tech.Upgrade -ParentId $tech.Parent
    }
}

$genericProtossTechs = @(
    @{ Unit = "Forge"; Ability = "ForgeResearch"; Face = "ProtossAlarakWeaponsLevel4"; Cmd = "Research25"; Upgrade = "ProtossGroundWeaponsLevel4"; Button = "ProtossAlarakWeaponsLevel4"; Requirement = "LearnProtossWeapons4"; Parent = "ProtossGroundWeaponsLevel3" },
    @{ Unit = "Forge"; Ability = "ForgeResearch"; Face = "ProtossAlarakWeaponsLevel5"; Cmd = "Research26"; Upgrade = "ProtossGroundWeaponsLevel5"; Button = "ProtossAlarakWeaponsLevel5"; Requirement = "LearnProtossWeapons5"; Parent = "ProtossGroundWeaponsLevel4" },
    @{ Unit = "Forge"; Ability = "ForgeResearch"; Face = "ProtossAlarakArmorLevel4"; Cmd = "Research27"; Upgrade = "ProtossGroundArmorsLevel4"; Button = "ProtossAlarakArmorLevel4"; Requirement = "LearnProtossArmor4"; Parent = "ProtossGroundArmorsLevel3" },
    @{ Unit = "Forge"; Ability = "ForgeResearch"; Face = "ProtossAlarakArmorLevel5"; Cmd = "Research28"; Upgrade = "ProtossGroundArmorsLevel5"; Button = "ProtossAlarakArmorLevel5"; Requirement = "LearnProtossArmor5"; Parent = "ProtossGroundArmorsLevel4" },
    @{ Unit = "CyberneticsCore"; Ability = "CyberneticsCoreResearch"; Face = "ProtossAirWeaponsLevel4"; Cmd = "Research24"; Upgrade = "ProtossAirWeaponsLevel4"; Button = "ProtossAirWeaponsLevel4"; Requirement = "LearnProtossAirWeapon4"; Parent = "ProtossAirWeaponsLevel3" },
    @{ Unit = "CyberneticsCore"; Ability = "CyberneticsCoreResearch"; Face = "ProtossAirWeaponsLevel5"; Cmd = "Research25"; Upgrade = "ProtossAirWeaponsLevel5"; Button = "ProtossAirWeaponsLevel5"; Requirement = "LearnProtossAirWeapon5"; Parent = "ProtossAirWeaponsLevel4" },
    @{ Unit = "CyberneticsCore"; Ability = "CyberneticsCoreResearch"; Face = "ProtossAirArmorLevel4"; Cmd = "Research26"; Upgrade = "ProtossAirArmorsLevel4"; Button = "ProtossAirArmorLevel4"; Requirement = "LearnProtossAirArmor4"; Parent = "ProtossAirArmorsLevel3" },
    @{ Unit = "CyberneticsCore"; Ability = "CyberneticsCoreResearch"; Face = "ProtossAirArmorLevel5"; Cmd = "Research27"; Upgrade = "ProtossAirArmorsLevel5"; Button = "ProtossAirArmorLevel5"; Requirement = "LearnProtossAirArmor5"; Parent = "ProtossAirArmorsLevel4" }
)

foreach ($tech in $genericProtossTechs) {
    Assert-LayoutButton -Xmls $unitXmls -UnitId $tech.Unit -Face $tech.Face -AbilCmd ("{0},{1}" -f $tech.Ability, $tech.Cmd)
    [void](Get-CatalogNode -Xml $buttonXml -TagName "CButton" -Id $tech.Button)
    [void](Get-CatalogNode -Xml $requirementXml -TagName "CRequirement" -Id $tech.Requirement)
    Assert-ResearchInfo -Xml $abilXml -AbilityId $tech.Ability -Index $tech.Cmd -UpgradeId $tech.Upgrade -ButtonId $tech.Button -RequirementId $tech.Requirement
    Assert-UpgradeParent -Xml $upgradeXml -UpgradeId $tech.Upgrade -ParentId $tech.Parent
}

$zergFiveTierTechs = @(
    @{ Units = @("EvolutionChamber"); Ability = "evolutionchamberresearch"; Face = "ZergGroundAttacksLevel4"; Cmd = "Research16"; Upgrade = "ZagaraGroundAttacksLevel4"; Button = "ZergGroundAttacksLevel4"; Requirement = "LearnZagaraGroundAttack4"; Parent = "ZagaraGroundAttacksLevel3" },
    @{ Units = @("EvolutionChamber"); Ability = "evolutionchamberresearch"; Face = "ZergGroundAttacksLevel5"; Cmd = "Research17"; Upgrade = "ZagaraGroundAttacksLevel5"; Button = "ZergGroundAttacksLevel5"; Requirement = "LearnZagaraGroundAttack5"; Parent = "ZagaraGroundAttacksLevel4" },
    @{ Units = @("Spire", "GreaterSpire", "ScourgeNest"); Ability = "SpireResearch"; Face = "zergflyerattack4"; Cmd = "Research16"; Upgrade = "ZergFlyerWeaponsLevel4"; Button = "zergflyerattack4"; Requirement = "LearnZergFlyerAttack4"; Parent = "ZergFlyerWeaponsLevel3" },
    @{ Units = @("Spire", "GreaterSpire", "ScourgeNest"); Ability = "SpireResearch"; Face = "zergflyerattack5"; Cmd = "Research17"; Upgrade = "ZergFlyerWeaponsLevel5"; Button = "zergflyerattack5"; Requirement = "LearnZergFlyerAttack5"; Parent = "ZergFlyerWeaponsLevel4" },
    @{ Units = @("Spire", "GreaterSpire", "ScourgeNest"); Ability = "SpireResearch"; Face = "zergflyerarmor4"; Cmd = "Research18"; Upgrade = "ZergFlyerArmorsLevel4"; Button = "zergflyerarmor4"; Requirement = "LearnZergFlyerArmor4"; Parent = "ZergFlyerArmorsLevel3" },
    @{ Units = @("Spire", "GreaterSpire", "ScourgeNest"); Ability = "SpireResearch"; Face = "zergflyerarmor5"; Cmd = "Research19"; Upgrade = "ZergFlyerArmorsLevel5"; Button = "zergflyerarmor5"; Requirement = "LearnZergFlyerArmor5"; Parent = "ZergFlyerArmorsLevel4" }
)

foreach ($tech in $zergFiveTierTechs) {
    foreach ($unit in $tech.Units) {
        Assert-LayoutButton -Xmls $unitXmls -UnitId $unit -Face $tech.Face -AbilCmd ("{0},{1}" -f $tech.Ability, $tech.Cmd)
    }
    [void](Get-CatalogNode -Xml $buttonXml -TagName "CButton" -Id $tech.Button)
    [void](Get-CatalogNode -Xml $requirementXml -TagName "CRequirement" -Id $tech.Requirement)
    Assert-ResearchInfo -Xml $abilXml -AbilityId $tech.Ability -Index $tech.Cmd -UpgradeId $tech.Upgrade -ButtonId $tech.Button -RequirementId $tech.Requirement
    Assert-UpgradeParent -Xml $upgradeXml -UpgradeId $tech.Upgrade -ParentId $tech.Parent
}

foreach ($nodeId in @(
        "CountUpgradeTerranInfantryWeaponsLevel4CompleteOnlyRaynor",
        "CountUpgradeTerranInfantryWeaponsLevel5QueuedOrBetterRaynor",
        "CountUpgradeTerranInfantryArmorsLevel4CompleteOnlyRaynor",
        "CountUpgradeTerranInfantryArmorsLevel5QueuedOrBetterRaynor",
        "CountUpgradeTerranVehicleAndShipWeaponsLevel4CompleteOnlyRaynor",
        "CountUpgradeTerranVehicleAndShipWeaponsLevel5QueuedOrBetterRaynor",
        "CountUpgradeTerranVehicleAndShipArmorsLevel4CompleteOnlyRaynor",
        "CountUpgradeTerranVehicleAndShipArmorsLevel5QueuedOrBetterRaynor"
    )) {
    [void](Get-CatalogNode -Xml $requirementNodeXml -TagName "CRequirementCountUpgrade" -Id $nodeId)
}

$currentUpgradePaths = @(
    (Join-Path $catalogGameData "UpgradeData.xml")
)
$sourceUpgradePaths = @(
    (Join-Path $repoRoot "_codex_7vs1_source_root\s2ma_packages\pkg01\extract\base.sc2data\GameData\UpgradeData.xml"),
    (Join-Path $repoRoot "_codex_7vs1_source_root\s2ma_packages\pkg01\extract\base.sc2data\GameData\Commanders\CommanderTychus.xml"),
    (Join-Path $repoRoot "_codex_7vs1_source_root\s2ma_packages\pkg01\extract\base.sc2data\GameData\Commanders\FutureCommanders.xml"),
    (Join-Path $repoRoot "_codex_7vs1_source_root\s2ma_packages\pkg15_abathur_reborn_patch\extract\Base.SC2Data\GameData\UpgradeData.xml")
)

$currentMissing = @(Get-Level4FamiliesWithoutLevel5 -Paths $currentUpgradePaths)
$sourceMissing = @(Get-Level4FamiliesWithoutLevel5 -Paths $sourceUpgradePaths)
$knownSourceMissing = @(
    "SIBarracksTrainInfestedCivilianLevel4",
    "SIBarracksTrainInfestedMarineLevel4",
    "TerranInfantryArmorsLevel4",
    "TerranInfantryWeaponsLevel4",
    "TerranVehicleAndShipArmorsLevel4",
    "TerranVehicleAndShipWeaponsLevel4",
    "ZeratulArmorsLevel4",
    "ZeratulShieldsLevel4",
    "ZeratulWeaponsLevel4"
)
$unexpectedSourceMissing = @($sourceMissing | Where-Object { $knownSourceMissing -notcontains $_ })
Assert-True -Condition ($unexpectedSourceMissing.Count -eq 0) -Message ("Unexpected source Level4 without Level5: {0}" -f ($unexpectedSourceMissing -join ", "))

$closureLines = @($closureText -split "`n" | Where-Object { $_ -match "CommanderPowerGeneratedApply.*Closure" })
Write-Host ("COMMANDER_POWER_ATTACK_ARMOR_COVERAGE_VALIDATE=PASS commanders={0} raynorTechs={1} genericTerranTechs={2} zeratulTechs={3} genericProtossTechs={4} zergFiveTierTechs={5} currentLevel4WithoutLevel5={6} sourceKnownLevel4WithoutLevel5={7} closureLines={8}" -f @($metadata.commanders).Count, $raynorTechs.Count, $genericTerranTechs.Count, $zeratulTechs.Count, $genericProtossTechs.Count, $zergFiveTierTechs.Count, $currentMissing.Count, $sourceMissing.Count, $closureLines.Count)
if ($sourceMissing.Count -gt 0) {
    Write-Host ("SOURCE_LEVEL4_WITHOUT_LEVEL5_KNOWN={0}" -f ($sourceMissing -join ","))
}
