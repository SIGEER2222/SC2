param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$OriginalSourceRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path '_codex_7vs1_source_root')
)

$ErrorActionPreference = 'Stop'

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

$sharedRoot = Join-Path $WorkspaceRoot 'Shared\7vs1PublicLibs\Base.SC2Data'
$runtimeSafetyPath = Join-Path $sharedRoot 'LibE0EAE146_RuntimeSafety.galaxy'
$basePath = Join-Path $sharedRoot 'LibE0EAE146.galaxy'
$commanderCatalogGameData = Join-Path $WorkspaceRoot 'Mods\7vs1\CommanderCatalog.SC2Mod\Base.SC2Data\GameData'
$commanderCatalogAbilDataPath = Join-Path $commanderCatalogGameData 'AbilData.xml'
$commanderCatalogActorDataPath = Join-Path $commanderCatalogGameData 'ActorData.xml'
$commanderCatalogUnitDataPath = Join-Path $commanderCatalogGameData 'UnitData.xml'

if (!(Test-Path -LiteralPath $runtimeSafetyPath)) {
    throw "Missing runtime safety file: $runtimeSafetyPath"
}
if (!(Test-Path -LiteralPath $basePath)) {
    throw "Missing base runtime file: $basePath"
}

$runtimeSafety = Get-Content -LiteralPath $runtimeSafetyPath -Raw -Encoding UTF8
$baseRuntime = Get-Content -LiteralPath $basePath -Raw -Encoding UTF8

Assert-Contains $runtimeSafety 'bool\s+libE0EAE146_gf_CommanderUseOriginal7v1SharedOpeners\s*\(\)\s*\{\s*return\s+true;' 'Original 7v1 shared opener strategy must default to true.'
Assert-Contains $runtimeSafety 'bool\s+libE0EAE146_gf_CommanderUsePrivateTechFilter\s*\(\s*string\s+lp_commander\s*\)\s*\{\s*(?s:.*?)lp_commander\s*==\s*"Raynor"(?s:.*?)return\s+true;(?s:.*?)return\s+false;' 'Private tech filters must default to false except the currently catalog-backed Raynor private chain.'

$openerTechCalls = ([regex]::Matches($baseRuntime, 'libE0EAE146_gf_ApplyOriginal7v1OpenerTech\(1,\s*libE0EAE146_gv_commander\);')).Count
if ($openerTechCalls -lt 2) {
    throw "InitializeBase must apply original opener tech before unit creation and after commander runtime. Found calls: $openerTechCalls"
}

$expectedOpeners = @(
    @{ Commander = 'Raynor'; TownHall = 'CommandCenterRaynor'; Worker = 'SCVRaynor'; Second = 'MarineRaynor' },
    @{ Commander = 'Swann'; TownHall = 'CommandCenter'; Worker = 'SCV'; Second = 'Marine' },
    @{ Commander = 'Nova'; TownHall = 'CommandCenter'; Worker = 'SCV'; Second = 'Marine' },
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

if (!(Test-Path -LiteralPath $commanderCatalogAbilDataPath)) {
    throw "Missing CommanderCatalog Raynor ability data: $commanderCatalogAbilDataPath"
}
if (!(Test-Path -LiteralPath $commanderCatalogActorDataPath)) {
    throw "Missing CommanderCatalog Raynor actor data: $commanderCatalogActorDataPath"
}
if (!(Test-Path -LiteralPath $commanderCatalogUnitDataPath)) {
    throw "Missing CommanderCatalog Raynor unit data: $commanderCatalogUnitDataPath"
}
$commanderCatalogAbilData = Get-Content -LiteralPath $commanderCatalogAbilDataPath -Raw -Encoding UTF8
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

$commanderCatalogUnitData = Get-Content -LiteralPath $commanderCatalogUnitDataPath -Raw -Encoding UTF8
Assert-FixedContains $commanderCatalogUnitData '<LayoutButtons index="2" Face="OrbitalCommand" Type="AbilCmd" AbilCmd="UpgradeToOrbitalRaynor,Execute" Requirements="" Row="2" Column="0" />' 'CommandCenterRaynor must expose UpgradeToOrbitalRaynor on the original fixed command-card index with no requirements.'
Assert-FixedContains $commanderCatalogUnitData '<TechTreeProducedUnitArray value="OrbitalCommandRaynor" />' 'CommandCenterRaynor must declare OrbitalCommandRaynor as a produced morph target.'

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
