param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$OriginalSourceRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path '_codex_7vs1_source_root')
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'catalog-xml.ps1')

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-FixedContains {
    param(
        [string]$Text,
        [string]$Needle,
        [string]$Message
    )

    if (!$Text.Contains($Needle)) {
        throw $Message
    }
}

$sharedRoot = Join-Path $WorkspaceRoot 'Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data'
$runtimeSafetyPath = Join-Path $sharedRoot 'LibE0EAE146_RuntimeSafety.galaxy'
$basePath = Join-Path $sharedRoot 'LibE0EAE146.galaxy'
$startSquadsPath = Join-Path $sharedRoot 'LibE0EAE146_CommanderStartSquads.galaxy'
$stukovRuntimePath = Join-Path $sharedRoot 'LibE0EAE146_StukovRuntime.galaxy'
$commanderCatalogGameData = Join-Path $WorkspaceRoot 'Mods\7vs1\CommanderCatalog.SC2Mod\Base.SC2Data\GameData'
$commanderCatalogAbilDataPath = Join-Path $commanderCatalogGameData 'AbilData.xml'
$commanderCatalogActorDataPath = Join-Path $commanderCatalogGameData 'ActorData.xml'
$commanderCatalogButtonDataPath = Join-Path $commanderCatalogGameData 'ButtonData.xml'
$commanderCatalogEffectDataPath = Join-Path $commanderCatalogGameData 'EffectData.xml'
$commanderCatalogUnitDataPaths = Get-CatalogXmlPaths -GameDataRoot $commanderCatalogGameData -BaseName 'UnitData'

if (!(Test-Path -LiteralPath $runtimeSafetyPath)) {
    throw "Missing runtime safety file: $runtimeSafetyPath"
}
if (!(Test-Path -LiteralPath $basePath)) {
    throw "Missing base runtime file: $basePath"
}
if (!(Test-Path -LiteralPath $startSquadsPath)) {
    throw "Missing commander start squads file: $startSquadsPath"
}
if (!(Test-Path -LiteralPath $stukovRuntimePath)) {
    throw "Missing Stukov runtime file: $stukovRuntimePath"
}

$runtimeSafety = Get-Content -LiteralPath $runtimeSafetyPath -Raw -Encoding UTF8
$baseRuntime = Get-Content -LiteralPath $basePath -Raw -Encoding UTF8
$startSquadsRuntime = Get-Content -LiteralPath $startSquadsPath -Raw -Encoding UTF8
$stukovRuntime = Get-Content -LiteralPath $stukovRuntimePath -Raw -Encoding UTF8

Assert-Contains $runtimeSafety 'bool\s+libE0EAE146_gf_CommanderUseOriginal7v1SharedOpeners\s*\(\)\s*\{\s*return\s+true;' 'Original 7v1 shared opener strategy must default to true.'
Assert-Contains $runtimeSafety 'bool\s+libE0EAE146_gf_CommanderUsePrivateTechFilter\s*\(\s*string\s+lp_commander\s*\)\s*\{\s*return\s+false;\s*\}' 'Private tech filters must default to false while opener tech stays catalog-backed.'

$openerTechCalls = ([regex]::Matches($baseRuntime, 'libE0EAE146_gf_ApplyOriginal7v1OpenerTech\(1,\s*libE0EAE146_gv_commander\);')).Count
if ($openerTechCalls -lt 2) {
    throw "InitializeBase must apply original opener tech before unit creation and after commander runtime. Found calls: $openerTechCalls"
}

$kerriganStartSquadStart = $startSquadsRuntime.IndexOf('void libE0EAE146_gf_KerriganCreateMapStartSquad ')
$kerriganStartSquadEnd = $startSquadsRuntime.IndexOf('void libE0EAE146_gf_KerriganCreateMapStartSquadInRegion ', $kerriganStartSquadStart)
if ($kerriganStartSquadStart -lt 0 -or $kerriganStartSquadEnd -lt 0) {
    throw 'Missing Kerrigan map start squad function.'
}
$kerriganStartSquad = $startSquadsRuntime.Substring($kerriganStartSquadStart, $kerriganStartSquadEnd - $kerriganStartSquadStart)
if ($kerriganStartSquad -match '"Hydralisk"') {
    throw 'Kerrigan map start squads must create HydraliskKerrigan, not generic Hydralisk, so spawned hydralisks keep the Kerrigan morph command card.'
}
Assert-FixedContains $kerriganStartSquad '"HydraliskKerrigan"' 'Kerrigan map start squads must reference HydraliskKerrigan.'

$expectedOpeners = @(
    @{ Commander = 'Raynor'; TownHall = 'CommandCenterRaynor'; Worker = 'SCVRaynor'; Second = 'MarineRaynor' },
    @{ Commander = 'Swann'; TownHall = 'CommandCenterSwann'; Worker = 'SCVSwann'; Second = 'Marine' },
    @{ Commander = 'Nova'; TownHall = 'CommandCenterNova'; Worker = 'SCVNova'; Second = 'MarineNova' },
    @{ Commander = 'Mengsk'; TownHall = 'CommandCenter'; Worker = 'SCV'; Second = 'Marine' },
    @{ Commander = 'Horner'; TownHall = 'HHCommandCenter'; Worker = 'HHSCV'; Second = 'Reaper' },
    @{ Commander = 'Tychus'; TownHall = 'TychusCommandCenter'; Worker = 'TychusSCV'; Second = 'Marine' },
    @{ Commander = 'Kerrigan'; TownHall = 'Hatchery'; Worker = 'Drone'; Second = 'Overlord' },
    @{ Commander = 'Zagara'; TownHall = 'Hatchery'; Worker = 'Drone'; Second = 'Overlord' },
    @{ Commander = 'Abathur'; TownHall = 'Hatchery'; Worker = 'Drone'; Second = 'Overlord' },
    @{ Commander = 'Stetmann'; TownHall = 'Hatchery'; Worker = 'Drone'; Second = 'Overlord' },
    @{ Commander = 'Stukov'; TownHall = 'SICommandCenter'; Worker = 'SISCV'; Second = 'SIInfestedTrooper' },
    @{ Commander = 'Dehaka'; TownHall = 'DehakaHatchery'; Worker = 'DehakaDrone'; Second = 'Zergling' },
    @{ Commander = 'Artanis'; TownHall = 'Nexus'; Worker = 'Probe'; Second = 'Zealot' },
    @{ Commander = 'Karax'; TownHall = 'Nexus'; Worker = 'Probe'; Second = 'Zealot' },
    @{ Commander = 'Vorazun'; TownHall = 'Nexus'; Worker = 'Probe'; Second = 'Zealot' },
    @{ Commander = 'Alarak'; TownHall = 'Nexus'; Worker = 'Probe'; Second = 'Zealot' },
    @{ Commander = 'Fenix'; TownHall = 'Nexus'; Worker = 'Probe'; Second = 'Zealot' },
    @{ Commander = 'Zeratul'; TownHall = 'Nexus'; Worker = 'Probe'; Second = 'Zealot' }
)

foreach ($entry in $expectedOpeners) {
    foreach ($unit in @($entry.TownHall, $entry.Worker, $entry.Second)) {
        Assert-Contains $runtimeSafety ([regex]::Escape('"' + $unit + '"')) "Expected opener unit '$unit' for commander '$($entry.Commander)' is not referenced in RuntimeSafety."
    }
}

Assert-FixedContains $stukovRuntime 'libNtve_gf_CreateUnitsWithDefaultFacing(1, "CoopCasterStukov", c_unitCreateIgnorePlacement, lp_player, RegionGetBoundsMin(RegionEntireMap()));' 'Stukov runtime must create the hidden topbar caster away from the playable center.'
Assert-FixedContains $stukovRuntime 'libNtve_gf_CreateUnitsWithDefaultFacing(1, "InfestedStukovCoop", 0, lp_player, lp_heroPoint);' 'Stukov runtime must keep the battlefield InfestedStukovCoop hero when hero creation is enabled.'
Assert-FixedContains $stukovRuntime 'lib67C0F0E7_gf_CU_GPInit(lp_player, "Stukov", lv_caster, null);' 'Stukov runtime must bind the Stukov topbar to CoopCasterStukov, not to a battlefield hero.'
if ($stukovRuntime -match 'lib67C0F0E7_gf_CU_GPInit\(\s*lp_player,\s*"Stukov",\s*lv_hero') {
    throw 'Stukov runtime must not bind the topbar to the battlefield InfestedStukovCoop hero; keep CoopCasterStukov as the topbar caster.'
}

if (!(Test-Path -LiteralPath $commanderCatalogAbilDataPath)) {
    throw "Missing CommanderCatalog Raynor ability data: $commanderCatalogAbilDataPath"
}
if (!(Test-Path -LiteralPath $commanderCatalogActorDataPath)) {
    throw "Missing CommanderCatalog Raynor actor data: $commanderCatalogActorDataPath"
}
if (!(Test-Path -LiteralPath $commanderCatalogButtonDataPath)) {
    throw "Missing CommanderCatalog button data: $commanderCatalogButtonDataPath"
}
if (!(Test-Path -LiteralPath $commanderCatalogEffectDataPath)) {
    throw "Missing CommanderCatalog effect data: $commanderCatalogEffectDataPath"
}
if ($commanderCatalogUnitDataPaths.Count -eq 0) {
    throw "Missing CommanderCatalog Raynor unit data: $commanderCatalogGameData\UnitData*.xml"
}
$commanderCatalogAbilData = Get-Content -LiteralPath $commanderCatalogAbilDataPath -Raw -Encoding UTF8
$commanderCatalogButtonData = Get-Content -LiteralPath $commanderCatalogButtonDataPath -Raw -Encoding UTF8
$commanderCatalogEffectData = Get-Content -LiteralPath $commanderCatalogEffectDataPath -Raw -Encoding UTF8
$commanderCatalogUnitData = ($commanderCatalogUnitDataPaths | ForEach-Object { Get-Content -LiteralPath $_ -Raw -Encoding UTF8 }) -join "`n"
$commanderCatalogUnitXmls = Read-CatalogXmlSet -GameDataRoot $commanderCatalogGameData -BaseName 'UnitData'
foreach ($ability in @(
    'CommandCenterTrainRaynor',
    'TerranBuildRaynor',
    'UpgradeToOrbitalRaynor',
    'BarracksTrainRaynor',
    'FactoryTrainRaynor',
    'StarportTrainRaynor'
)) {
    Assert-Contains $commanderCatalogAbilData ('id="' + [regex]::Escape($ability) + '"') "CommanderCatalog AbilData missing Raynor ability: $ability"
}
Assert-Contains $commanderCatalogAbilData 'id="InfestedStukovCoopInfestedTerrans"(?s:.*?)Effect index="0" value="InfestedStukovCoopInfestedTerrans"' 'CommanderCatalog AbilData must define Stukov hero Infested Terrans with its spawn effect.'
foreach ($effect in @(
    'InfestedStukovCoopInfestedTerrans',
    'InfestedStukovCoopInfestedTerransLayEgg',
    'InfestedStukovCoopInfestedTerransInitialSet'
)) {
    Assert-Contains $commanderCatalogEffectData ('id="' + [regex]::Escape($effect) + '"') "CommanderCatalog EffectData missing Stukov hero summon effect: $effect"
}
foreach ($button in @(
    'SIStukovPlaceHordeRallyTopBar',
    'SIStukovInfestStructure',
    'SIStukovInfestStructureUpgraded',
    'StukovSummonApocalisk',
    'StukovSummonAleksander',
    'InfestedStukovCoopInfestedTerrans'
)) {
    Assert-Contains $commanderCatalogButtonData ('id="' + [regex]::Escape($button) + '"(?s:.*?)Icon value=') "CommanderCatalog ButtonData missing icon-backed Stukov button: $button"
}

$buttonIds = [System.Collections.Generic.HashSet[string]]::new()
[xml]$commanderCatalogButtonXml = $commanderCatalogButtonData
foreach ($node in $commanderCatalogButtonXml.Catalog.ChildNodes) {
    if (($node.NodeType -eq 'Element') -and ($node.Name -eq 'CButton') -and $node.HasAttribute('id')) {
        [void]$buttonIds.Add($node.GetAttribute('id'))
    }
}
$sourceButtonIds = [System.Collections.Generic.HashSet[string]]::new()
$sourceButtonPath = Join-Path $OriginalSourceRoot 's2ma_packages\pkg01\extract\base.sc2data\GameData\ButtonData.xml'
if (!(Test-Path -LiteralPath $sourceButtonPath)) {
    throw "Missing original 7v1 ButtonData source: $sourceButtonPath"
}
[xml]$sourceButtonXml = Get-Content -LiteralPath $sourceButtonPath -Raw -Encoding UTF8
foreach ($node in $sourceButtonXml.Catalog.ChildNodes) {
    if (($node.NodeType -eq 'Element') -and ($node.Name -eq 'CButton') -and $node.HasAttribute('id')) {
        [void]$sourceButtonIds.Add($node.GetAttribute('id'))
    }
}
$globalCasterUnits = @(
    'CoopCasterAbathur',
    'CoopCasterAlarak',
    'CoopCasterDehaka',
    'CoopCasterHorner',
    'CoopCasterMengsk',
    'CoopCasterNova',
    'CoopCasterRaynor',
    'CoopCasterStetmann',
    'CoopCasterStukov',
    'CoopCasterSwann',
    'CoopCasterZeratul',
    'CoopCasterZeratulSpecialization',
    'CasterDehaka',
    'CasterMira',
    'SoACasterArtanis',
    'SoACasterFenix',
    'SoACasterKarax',
    'SoACasterVorazun'
)
$missingCasterButtonFaces = @()
foreach ($casterUnit in $globalCasterUnits) {
    $unitNodes = @(Get-CatalogNodesById -Xmls $commanderCatalogUnitXmls -TagName 'CUnit' -Id $casterUnit)
    if ($unitNodes.Count -eq 0) {
        continue
    }
    $unitNode = $unitNodes[$unitNodes.Count - 1]
    foreach ($card in $unitNode.CardLayouts) {
        foreach ($layoutButton in $card.LayoutButtons) {
            if ($layoutButton.Face) {
                $face = [string]$layoutButton.Face
                if ((!$buttonIds.Contains($face)) -and $sourceButtonIds.Contains($face)) {
                    $missingCasterButtonFaces += ("{0}/{1}" -f $casterUnit, $face)
                }
            }
        }
    }
}
if ($missingCasterButtonFaces.Count -gt 0) {
    throw ("CommanderCatalog ButtonData missing source-defined global caster button faces: {0}" -f (($missingCasterButtonFaces | Sort-Object -Unique) -join ', '))
}

$commanderCatalogActorData = Get-Content -LiteralPath $commanderCatalogActorDataPath -Raw -Encoding UTF8
$raynorConstructedActors = @(
    'CommandCenterRaynor',
    'BarracksRaynor',
    'FactoryRaynor',
    'StarportRaynor',
    'SupplyDepotRaynor',
    'RefineryRaynor',
    'EngineeringBayRaynor',
    'BunkerRaynor',
    'MissileTurretRaynor',
    'SensorTowerRaynor',
    'ArmoryRaynor',
    'FusionCoreRaynor',
    'TechLabRaynor',
    'ReactorRaynor',
    'BarracksTechLabRaynor',
    'BarracksReactorRaynor',
    'FactoryTechLabRaynor',
    'FactoryReactorRaynor',
    'StarportTechLabRaynor',
    'StarportReactorRaynor'
)
foreach ($actor in $raynorConstructedActors) {
    Assert-FixedContains $commanderCatalogActorData ('Terms="UnitConstruction.{0}.Start" Send="Create"' -f $actor) "CommanderCatalog ActorData missing Raynor construction actor create event: $actor"
}
foreach ($actor in @('SCVRaynor', 'MarineRaynor', 'CommandCenterRaynor')) {
    Assert-FixedContains $commanderCatalogActorData ('Terms="UnitBirth.{0}" Send="Create"' -f $actor) "CommanderCatalog ActorData missing Raynor unit birth create event: $actor"
}

Assert-FixedContains $commanderCatalogUnitData '<LayoutButtons index="2" Face="OrbitalCommand" Type="AbilCmd" AbilCmd="UpgradeToOrbitalRaynor,Execute" Requirements="" Row="2" Column="0" />' 'CommandCenterRaynor must expose UpgradeToOrbitalRaynor on the original fixed command-card index with no requirements.'
Assert-FixedContains $commanderCatalogUnitData '<TechTreeProducedUnitArray value="OrbitalCommandRaynor" />' 'CommandCenterRaynor must declare OrbitalCommandRaynor as a produced morph target.'
Assert-Contains $commanderCatalogUnitData 'CUnit id="InfestedStukovCoop"(?s:.*?)AbilArray Link="InfestedStukovCoopInfestedTerrans"(?s:.*?)AbilArray Link="SIStukovExplodeInfested" removed="1"' 'CommanderCatalog UnitData must add Stukov hero Infested Terrans and remove Explode Infested.'
Assert-Contains $commanderCatalogUnitData 'CUnit id="InfestedStukovCoop"(?s:.*?)CardLayouts index="0" removed="1"(?s:.*?)LayoutButtons Face="InfestedStukovCoopInfestedTerrans" Type="AbilCmd" AbilCmd="InfestedStukovCoopInfestedTerrans,Execute" Row="2" Column="1"' 'CommanderCatalog UnitData must place Stukov hero Infested Terrans on the hero command card.'

$filterGuards = @{
    Raynor = 'Raynor'
    Zagara = 'Zagara'
    Kerrigan = 'Kerrigan'
    Abathur = 'Abathur'
    Fenix = 'Fenix'
    Karax = 'Karax'
}

foreach ($pair in $filterGuards.GetEnumerator()) {
    $file = Join-Path $sharedRoot ("LibE0EAE146_{0}Runtime.galaxy" -f $pair.Key)
    if (!(Test-Path -LiteralPath $file)) {
        throw "Missing commander runtime: $file"
    }
    $text = Get-Content -LiteralPath $file -Raw -Encoding UTF8
    $pattern = 'if\s*\(\s*libE0EAE146_gf_CommanderUsePrivateTechFilter\("' + [regex]::Escape($pair.Value) + '"\)\s*\)\s*\{\s*(?s:.*?)ApplyTechFilter\(lp_player\);\s*\}'
    Assert-Contains $text $pattern "Private tech filter in $($pair.Key) runtime is not guarded by CommanderUsePrivateTechFilter."
}

$raceDataPath = Join-Path $OriginalSourceRoot 's2ma_packages\pkg01\extract\base.sc2data\GameData\RaceData.xml'
$tythusDataPath = Join-Path $OriginalSourceRoot 's2ma_packages\pkg01\extract\base.sc2data\GameData\Commanders\CommanderTychus.xml'
$futureDataPath = Join-Path $OriginalSourceRoot 's2ma_packages\pkg01\extract\base.sc2data\GameData\Commanders\FutureCommanders.xml'
foreach ($sourcePath in @($raceDataPath, $tythusDataPath, $futureDataPath)) {
    if (!(Test-Path -LiteralPath $sourcePath)) {
        throw "Missing original 7v1 comparison source: $sourcePath"
    }
}

$raceData = Get-Content -LiteralPath $raceDataPath -Raw -Encoding UTF8
$tythusData = Get-Content -LiteralPath $tythusDataPath -Raw -Encoding UTF8
$futureData = Get-Content -LiteralPath $futureDataPath -Raw -Encoding UTF8

foreach ($pattern in @(
    '<CRace id="Terr">(?s:.*?)<StartingUnitArray index="1" Count="12" Unit="SCV">',
    '<CRace id="Zerg">(?s:.*?)<StartingUnitArray index="1" Count="12" Unit="Drone">',
    '<CRace id="Prot">(?s:.*?)<StartingUnitArray index="1" Count="12" Unit="Probe">',
    '<CRace id="InfT">(?s:.*?)<StartingUnitArray Unit="SICommandCenter">(?s:.*?)<StartingUnitArray Count="12" Unit="SISCV">',
    '<CRace id="TerH">(?s:.*?)<StartingUnitArray Unit="HHCommandCenter">(?s:.*?)<StartingUnitArray Count="12" Unit="HHSCV">',
    '<CRace id="PZrg">(?s:.*?)<StartingUnitArray Unit="DehakaHatchery">(?s:.*?)<StartingUnitArray Count="12" Unit="DehakaDrone">'
)) {
    Assert-Contains $raceData $pattern "Original RaceData expected opener pattern missing: $pattern"
}

Assert-Contains $tythusData '<CRace id="TerT">(?s:.*?)<StartingUnitArray Unit="TychusCommandCenter">(?s:.*?)<StartingUnitArray Count="12" Unit="TychusSCV">' 'Original Tychus RaceData expected opener pattern missing.'
Assert-Contains $futureData '<CRace id="ProZ">(?s:.*?)<StartingUnitArray Unit="Nexus">(?s:.*?)<StartingUnitArray Count="12" Unit="Probe">' 'Original Zeratul FutureCommanders RaceData expected opener pattern missing.'

Write-Host ("VALIDATION_OK commanders={0} guardedPrivateFilters={1} openerTechCalls={2}" -f $expectedOpeners.Count, $filterGuards.Count, $openerTechCalls)
