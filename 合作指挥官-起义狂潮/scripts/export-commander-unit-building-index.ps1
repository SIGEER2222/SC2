[CmdletBinding()]
param(
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "commander-power-metadata.ps1")
. (Join-Path $PSScriptRoot "sc2\catalog-xml.ps1")

function Get-WorkspaceRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Resolve-OutputPath {
    param(
        [string]$WorkspaceRoot,
        [string]$RequestedPath
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        return $RequestedPath
    }

    $fileName = "commander-unit-building-index-{0}.md" -f (Get-Date -Format "yyyy-MM-dd")
    return (Join-Path $WorkspaceRoot ("docs\" + $fileName))
}

function Get-LocalizedNameFileCandidates {
    param(
        [string]$WorkspaceRoot,
        [string]$CommanderShortId
    )

    $paths = New-Object System.Collections.Generic.List[string]
    $modPath = Join-Path $WorkspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod\zhCN.SC2Data\LocalizedData\GameStrings.txt"
    if (Test-Path -LiteralPath $modPath) {
        $paths.Add($modPath) | Out-Null
    }

    $semanticRoot = Join-Path $WorkspaceRoot "游戏数据\其他mod数据\7vs1母巢之战合作指挥官bate版_SC2Replay_94137\_semantic-game-data-by-commander-v2"
    if (Test-Path -LiteralPath $semanticRoot) {
        $sharedPaths = @(Get-ChildItem -LiteralPath $semanticRoot -Recurse -Filter "GameStrings.txt" -File -ErrorAction SilentlyContinue | Where-Object {
                $_.FullName -like "*_shared*" -and $_.FullName -match "[\\\/]zhcn\.sc2data[\\\/]LocalizedData[\\\/]GameStrings\.txt$|[\\\/]zhCN\.SC2Data[\\\/]LocalizedData[\\\/]GameStrings\.txt$"
            } | Sort-Object FullName | Select-Object -ExpandProperty FullName)
        foreach ($path in $sharedPaths) {
            if (-not $paths.Contains($path)) {
                $paths.Add($path) | Out-Null
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($CommanderShortId)) {
            $commanderRoot = Join-Path $semanticRoot $CommanderShortId
            if (Test-Path -LiteralPath $commanderRoot) {
                $commanderPaths = @(Get-ChildItem -LiteralPath $commanderRoot -Recurse -Filter "GameStrings.txt" -File -ErrorAction SilentlyContinue | Where-Object {
                        $_.FullName -match "[\\\/]zhcn\.sc2data[\\\/]LocalizedData[\\\/]GameStrings\.txt$|[\\\/]zhCN\.SC2Data[\\\/]LocalizedData[\\\/]GameStrings\.txt$"
                    } | Sort-Object FullName | Select-Object -ExpandProperty FullName)
                foreach ($path in $commanderPaths) {
                    if (-not $paths.Contains($path)) {
                        $paths.Add($path) | Out-Null
                    }
                }
            }
        }
    }

    $gameRoot = ""
    $profilePath = "C:\Users\22448\AppData\Roaming\@scnexus\app-main\SCNexusStorage\store-profile.json"
    if (Test-Path -LiteralPath $profilePath) {
        try {
            $profile = Get-Content -LiteralPath $profilePath -Encoding UTF8 -Raw | ConvertFrom-Json
            if ($null -ne $profile.active_profile.env.GAME_ROOT) {
                $gameRoot = [string]$profile.active_profile.env.GAME_ROOT
            }
        }
        catch {
        }
    }

    if ([string]::IsNullOrWhiteSpace($gameRoot)) {
        $fallbackGameRoot = "E:\SC2\SC2new\StarCraft II"
        if (Test-Path -LiteralPath $fallbackGameRoot) {
            $gameRoot = $fallbackGameRoot
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($gameRoot) -and (Test-Path -LiteralPath $gameRoot)) {
        foreach ($relativePath in @(
                "Mods\VoidMulti.SC2Mod\zhcn.sc2data\localizeddata\gamestrings.txt",
                "Mods\StarCoop\StarCoop.SC2Mod\zhcn.sc2data\localizeddata\gamestrings.txt"
            )) {
            $candidate = Join-Path $gameRoot $relativePath
            if ((Test-Path -LiteralPath $candidate) -and (-not $paths.Contains($candidate))) {
                $paths.Add($candidate) | Out-Null
            }
        }

        if ($CommanderShortId -eq "Stetmann") {
            $candidate = Join-Path $gameRoot "Mods\StarCoop\Commanders\EgonStetmann.SC2Mod\zhcn.sc2data\localizeddata\gamestrings.txt"
            if ((Test-Path -LiteralPath $candidate) -and (-not $paths.Contains($candidate))) {
                $paths.Add($candidate) | Out-Null
            }
        }

        if ($CommanderShortId -eq "Mengsk") {
            $candidate = Join-Path $gameRoot "Mods\StarCoop\Commanders\ArcturusMengsk.SC2Mod\zhcn.sc2data\localizeddata\gamestrings.txt"
            if ((Test-Path -LiteralPath $candidate) -and (-not $paths.Contains($candidate))) {
                $paths.Add($candidate) | Out-Null
            }
        }
    }

    return @($paths)
}

function Get-AdditionalUnitCatalogPaths {
    param([string]$WorkspaceRoot)

    $paths = New-Object System.Collections.Generic.List[string]
    $semanticRoot = Join-Path $WorkspaceRoot "游戏数据\其他mod数据\7vs1母巢之战合作指挥官bate版_SC2Replay_94137"

    foreach ($relativePath in @(
            "Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\GameData\UnitData.xml",
            "s2ma_packages\pkg01\extract\base.sc2data\GameData\Commanders\FutureCommanders.xml",
            "_semantic-game-data-by-commander\Mengsk\s2ma_packages\pkg01\extract\base.sc2data\GameData\UnitData.xml",
            "_semantic-game-data-by-commander-v2\_shared\s2ma_packages\pkg01\extract\base.sc2data\GameData\UnitData.xml",
            "_semantic-game-data-by-commander-v2\_shared\s2ma_packages\pkg02\extract\Base.SC2Data\GameData\UnitData.xml",
            "_semantic-game-data-by-commander-v2\_shared\s2ma_packages\pkg03\extract\Base.SC2Data\GameData\UnitData.xml"
        )) {
        if ($relativePath.StartsWith("Mods\", [System.StringComparison]::OrdinalIgnoreCase)) {
            $candidate = Join-Path $WorkspaceRoot $relativePath
        }
        else {
            $candidate = Join-Path $semanticRoot $relativePath
        }
        if ((Test-Path -LiteralPath $candidate) -and (-not $paths.Contains($candidate))) {
            $paths.Add($candidate) | Out-Null
        }
    }

    return @($paths)
}

function New-StringSet {
    return ,([System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase))
}

function Add-SetValue {
    param(
        [object]$Set,
        [string]$Value
    )

    if (($null -ne $Set) -and (-not [string]::IsNullOrWhiteSpace($Value))) {
        [void]$Set.Add($Value)
    }
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

function Get-CommanderMatchTokens {
    param($CommanderRecord)

    if ($null -eq $CommanderRecord) {
        return @()
    }

    $tokens = New-StringSet
    foreach ($value in @(
            [string]$CommanderRecord.official_short_id,
            [string]$CommanderRecord.bank_commander,
            [string]$CommanderRecord.generated_commander,
            [string]$CommanderRecord.official_folder
        )) {
        Add-SetValue -Set $tokens -Value $value
    }

    switch ([string]$CommanderRecord.official_short_id) {
        "Horner" {
            Add-SetValue -Set $tokens -Value "HH"
            Add-SetValue -Set $tokens -Value "Mira"
        }
        "Stukov" {
            Add-SetValue -Set $tokens -Value "StukovInfested"
        }
        "Fenix" {
            Add-SetValue -Set $tokens -Value "Purifier"
        }
        "Dehaka" {
            Add-SetValue -Set $tokens -Value "DehakaPrimal"
        }
    }

    return @($tokens | Sort-Object)
}

function Get-CommanderSharedUnitIds {
    param($CommanderRecord)

    if ($null -eq $CommanderRecord) {
        return @()
    }

    $commonTerranEconomy = @(
        "CommandCenter",
        "Refinery",
        "SCV",
        "SupplyDepot"
    )

    $commonTerranProduction = @(
        "Armory",
        "Barracks",
        "Bunker",
        "EngineeringBay",
        "Factory",
        "FusionCore",
        "MissileTurret",
        "SensorTower",
        "Starport"
    )

    $commonProtossEconomy = @(
        "Assimilator",
        "Nexus",
        "Probe",
        "Pylon"
    )

    $commonZergEconomy = @(
        "Drone",
        "Extractor",
        "Hatchery",
        "Lair",
        "Hive",
        "Larva",
        "Overlord",
        "Overseer"
    )

    $commonZergTech = @(
        "BanelingNest",
        "EvolutionChamber",
        "GreaterSpire",
        "HydraliskDen",
        "InfestationPit",
        "RoachWarren",
        "SpawningPool",
        "SpineCrawler",
        "SporeCrawler",
        "Spire",
        "UltraliskCavern"
    )

    switch ([string]$CommanderRecord.official_short_id) {
        "Raynor" {
            return @(
                $commonTerranEconomy +
                $commonTerranProduction +
                @(
                    "Banshee",
                    "Battlecruiser",
                    "Cyclone",
                    "Firebat",
                    "Goliath",
                    "Hellbat",
                    "Hellion",
                    "Marauder",
                    "Marine",
                    "Medic",
                    "Reaper",
                    "SiegeTank",
                    "SiegeTankSieged",
                    "VikingAssault",
                    "VikingFighter",
                    "Vulture",
                    "Wraith"
                )
            )
        }
        "Kerrigan" {
            return @(
                $commonZergEconomy +
                $commonZergTech +
                @(
                    "BroodLord",
                    "BroodLordCocoon",
                    "Hydralisk",
                    "HydraliskLurker",
                    "HydraliskLurkerBurrowed",
                    "Infestor",
                    "Mutalisk",
                    "NydusCanal",
                    "NydusNetwork",
                    "OverlordTransport",
                    "Queen",
                    "Ravager",
                    "Roach",
                    "Ultralisk",
                    "Zergling"
                )
            )
        }
        "Artanis" {
            return @(
                $commonProtossEconomy +
                @(
                    "Carrier",
                    "CyberneticsCore",
                    "Dragoon",
                    "FleetBeacon",
                    "Forge",
                    "Gateway",
                    "HighArchonTemplar",
                    "HighTemplar",
                    "Immortal",
                    "Observer",
                    "ObserverSiegeMode",
                    "PhotonCannon",
                    "Phoenix",
                    "Reaver",
                    "RoboticsBay",
                    "RoboticsFacility",
                    "Scout",
                    "SolarForge",
                    "Stargate",
                    "Tempest",
                    "TemplarArchive",
                    "TwilightCouncil",
                    "WarpGate",
                    "WarpPrism",
                    "WarpPrismPhasing",
                    "Zealot"
                )
            )
        }
        "Vorazun" {
            return @(
                $commonProtossEconomy +
                @(
                    "CorsairMP",
                    "DarkArchon",
                    "DarkShrine",
                    "DarkTemplarShakuras",
                    "FleetBeacon",
                    "Forge",
                    "Gateway",
                    "Observer",
                    "Oracle",
                    "PhotonCannon",
                    "Scout",
                    "Stargate",
                    "TemplarArchive",
                    "TwilightCouncil",
                    "VoidRay",
                    "WarpPrism",
                    "WarpPrismPhasing",
                    "WarpGate"
                )
            )
        }
        "Karax" {
            return @(
                $commonProtossEconomy +
                @(
                    "Carrier",
                    "Colossus",
                    "CyberneticsCore",
                    "FleetBeacon",
                    "Forge",
                    "Gateway",
                    "Immortal",
                    "KhaydarinMonolith",
                    "Observer",
                    "Phoenix",
                    "PhotonCannon",
                    "RoboticsBay",
                    "RoboticsFacility",
                    "SentryPhasing",
                    "ShieldBattery",
                    "Stargate",
                    "TwilightCouncil",
                    "WarpGate",
                    "WarpPrism",
                    "ZealotPurifier"
                )
            )
        }
        "Fenix" {
            return @(
                $commonProtossEconomy +
                @(
                    "Adept",
                    "AdeptFenix",
                    "Carrier",
                    "Colossus",
                    "ColossusPurifier",
                    "CyberneticsCore",
                    "Disruptor",
                    "FenixClolarionCarrier",
                    "FenixMojoScout",
                    "FenixTaldarinImmortal",
                    "FenixTalisAdept",
                    "FenixWarbringerColossus",
                    "FleetBeacon",
                    "Forge",
                    "Gateway",
                    "Immortal",
                    "Observer",
                    "Purifier",
                    "Scout",
                    "SentryFenix",
                    "RoboticsBay",
                    "RoboticsFacility",
                    "Stargate",
                    "TwilightCouncil",
                    "WarpGate"
                )
            )
        }
        "Alarak" {
            return @(
                $commonProtossEconomy +
                @(
                    "Ascendant",
                    "CyberneticsCore",
                    "Gateway",
                    "Havoc",
                    "RoboticsBay",
                    "RoboticsFacility",
                    "Stalker",
                    "Slayer",
                    "Supplicant",
                    "TemplarArchive",
                    "TwilightCouncil",
                    "Vanguard",
                    "WarpGate",
                    "WarpPrism",
                    "Wrathwalker"
                )
            )
        }
        "Swann" {
            return @(
                $commonTerranEconomy +
                $commonTerranProduction +
                @(
                    "Cyclone",
                    "Goliath",
                    "Hellion",
                    "HellionTank",
                    "SiegeTank",
                    "SiegeTankSieged",
                    "Thor",
                    "VikingAssault",
                    "VikingFighter",
                    "Wraith"
                )
            )
        }
        "Zagara" {
            return @(
                $commonZergEconomy +
                $commonZergTech +
                @(
                    "Baneling",
                    "BanelingNest",
                    "Corruptor",
                    "Infestor",
                    "Mutalisk",
                    "Roach",
                    "Scourge",
                    "Zergling"
                )
            )
        }
        "Abathur" {
            return @(
                $commonZergEconomy +
                $commonZergTech +
                @(
                    "Brutalisk",
                    "BrutaliskAbathur",
                    "BrutaliskAbathurBurrowed",
                    "Hydralisk",
                    "Larva",
                    "Mutalisk",
                    "Queen",
                    "Ravager",
                    "RavagerAbathur",
                    "RavagerAbathurBurrowed",
                    "Roach",
                    "SwarmHostMP"
                )
            )
        }
        "Nova" {
            return @(
                $commonTerranEconomy +
                $commonTerranProduction +
                @(
                    "Banshee",
                    "Battlecruiser",
                    "Ghost",
                    "Hellbat",
                    "Liberator",
                    "Marauder",
                    "Marine",
                    "Medivac",
                    "Raven",
                    "Reaper",
                    "SiegeTank",
                    "SiegeTankSieged",
                    "Thor",
                    "VikingAssault",
                    "VikingFighter"
                )
            )
        }
        "Stukov" {
            return @(
                $commonTerranEconomy +
                $commonTerranProduction +
                @(
                    "InfestedBanshee",
                    "InfestedCivilian",
                    "InfestedDiamondback",
                    "InfestedSiegeTank",
                    "InfestedTerran",
                    "InfestedTerranEgg",
                    "InfestedTerranStructure",
                    "InfestedVikingFighter",
                    "InfestedLiberator",
                    "InfestedMarine",
                    "InfestedMarauder",
                    "InfestedReaper",
                    "InfestedSiegeTankSieged"
                )
            )
        }
        "Dehaka" {
            return @(
                $commonZergEconomy +
                $commonZergTech +
                @(
                    "DehakaBrutalisk",
                    "DehakaCoop",
                    "DehakaGuardian",
                    "DehakaImpaler",
                    "DehakaMutalisk",
                    "DehakaPackLeader",
                    "DehakaPrimal"
                )
            )
        }
        "Horner" {
            return @(
                $commonTerranEconomy +
                $commonTerranProduction +
                @(
                    "HHBattlecruiser",
                    "HHHellion",
                    "HHHellionTank",
                    "HHRaven",
                    "HHReaper",
                    "HHReaperFlying",
                    "HHVikingAssault",
                    "HHVikingFighter",
                    "HHWidowMine",
                    "HHWidowMineBurrowed",
                    "HHWraith",
                    "MiraStarportMissile"
                )
            )
        }
        "Tychus" {
            return @(
                "TychusChaingun",
                "TychusCommando"
            )
        }
        "Zeratul" {
            return @(
                $commonProtossEconomy +
                @(
                    "AutomatedAssimilatorZeratul",
                    "ColossusPurifier",
                    "CorsairMP",
                    "DarkArchon",
                    "DarkShrine",
                    "DarkTemplarShakuras",
                    "Disruptor",
                    "Gateway",
                    "Immortal",
                    "Observer",
                    "ObserverSiegeMode",
                    "PhotonCannon",
                    "Purifier",
                    "Reaver",
                    "RoboticsBay",
                    "RoboticsFacility",
                    "Scout",
                    "Sentry",
                    "Stalker",
                    "Tempest",
                    "VoidRay",
                    "WarpPrism",
                    "WarpPrismPhasing",
                    "Zealot",
                    "ZealotPurifier",
                    "ZeratulACArtifact",
                    "ZeratulCoop",
                    "ZeratulCoopReviveBeacon",
                    "ZeratulCyberneticsCore",
                    "ZeratulDarkArchon",
                    "ZeratulDarkShrine",
                    "ZeratulDarkTemplar",
                    "ZeratulDisruptor",
                    "ZeratulGateway",
                    "ZeratulHeroDarkArchon",
                    "ZeratulImmortal",
                    "ZeratulKhaydarinMonolith",
                    "ZeratulNexus",
                    "ZeratulObserver",
                    "ZeratulObserverSiegeMode",
                    "ZeratulPhotonCannon",
                    "ZeratulProbe",
                    "ZeratulRoboticsBay",
                    "ZeratulRoboticsFacility",
                    "ZeratulSentry",
                    "ZeratulStalker",
                    "ZeratulSummonKarass",
                    "ZeratulSummonVoidRay",
                    "ZeratulSummonZealot",
                    "ZeratulTransportVoidSeeker",
                    "ZeratulWarpPrism",
                    "ZeratulWarpPrismPhasing",
                    "ZeratulXelNagaConstruct",
                    "ZeratulXelNagaConstructCyan"
                )
            )
        }
        "Mengsk" {
            return @(
                $commonTerranEconomy +
                $commonTerranProduction +
                @(
                    "Battlecruiser",
                    "Bunker",
                    "Ghost",
                    "Marauder",
                    "Marine",
                    "MengskBanshee",
                    "MengskBC",
                    "MengskDiamondback",
                    "MengskFirebat",
                    "MengskGoliath",
                    "MengskHellion",
                    "MengskMarauder",
                    "MengskMarine",
                    "MengskMedic",
                    "MengskReaper",
                    "MengskSiegeTank",
                    "MengskSiegeTankSieged",
                    "MengskThor",
                    "MengskVikingAssault",
                    "MengskVikingFighter",
                    "MengskWraith",
                    "Medic",
                    "Medivac",
                    "SiegeTank",
                    "SiegeTankSieged",
                    "Thor",
                    "VikingAssault",
                    "VikingFighter"
                )
            )
        }
    }

    return @()
}

function Get-FixedLocalizedUnitNames {
    return @{
        AdeptFenix = "使徒"
        Alarak = "阿拉纳克"
        AlarakCoop = "阿拉纳克"
        AlarakReviveBeacon = "阿拉纳克信标"
        Assimilator = "瓦斯采集器"
        AutomatedAssimilatorZeratul = "古代吸纳舱"
        Armory = "军械库"
        Barracks = "兵营"
        Bunker = "地堡"
        BanelingNest = "爆虫巢"
        Carrier = "航母"
        Colossus = "巨像"
        CommandCenter = "指挥中心"
        CyberneticsCore = "控制芯核"
        DarkArchon = "黑暗执政官"
        DarkShrine = "黑暗圣坛"
        DarkTemplarShakuras = "黑暗圣堂武士"
        DehakaCoopReviveCocoon = "德哈卡的巢穴"
        DehakaHatchery = "原始主巢"
        DehakaHatcheryUprooted = "原始主巢"
        Dragoon = "龙骑士"
        Drone = "工蜂"
        EngineeringBay = "工程站"
        EvolutionChamber = "进化腔"
        Extractor = "萃取器"
        Factory = "工厂"
        FleetBeacon = "舰队航标"
        Forge = "锻炉"
        FusionCore = "聚变芯体"
        GarysDen = "盖瑞的房间"
        Gateway = "传送门"
        GreaterSpire = "巨型尖塔"
        Hatchery = "孵化场"
        Havoc = "潜伏者"
        Hive = "主巢"
        HighArchon = "高阶执政官"
        HighArchonTemplar = "高阶执政官"
        HighTemplar = "高阶圣堂武士"
        HydraliskDen = "刺蛇巢"
        InfestationPit = "感染深渊"
        Immortal = "不朽者"
        KhaydarinMonolith = "凯达林巨石"
        Lair = "虫穴"
        Larva = "幼虫"
        MengskBanshee = "皇家女妖"
        MengskBC = "皇家战列巡航舰"
        MengskDiamondback = "皇家响尾蛇"
        MengskFirebat = "皇家火蝠"
        MengskGoliath = "皇家歌利亚"
        MengskHellion = "皇家恶火"
        MengskMarauder = "皇家劫掠者"
        MengskMarine = "皇家陆战队员"
        MengskMedic = "皇家医疗兵"
        MengskReaper = "皇家收割者"
        MengskSiegeTank = "皇家攻城坦克"
        MengskSiegeTankSieged = "皇家攻城坦克"
        MengskThor = "皇家雷神"
        MengskVikingAssault = "皇家维京"
        MengskVikingFighter = "皇家维京"
        MengskWraith = "皇家怨灵"
        Marauder = "劫掠者"
        Marine = "陆战队员"
        Medic = "医疗兵"
        MissileTurret = "导弹塔"
        Nexus = "星灵枢纽"
        Observer = "侦测器"
        ObserverSiegeMode = "侦测器"
        Oracle = "先知"
        Overlord = "王虫"
        Overseer = "监察王虫"
        Pylon = "水晶塔"
        Probe = "探机"
        Purifier = "净化者"
        Reaper = "收割者"
        Ravager = "破坏者"
        Refinery = "精炼厂"
        Roach = "蟑螂"
        RoachWarren = "蟑螂巢"
        RoboticsBay = "机械台"
        RoboticsFacility = "机械制造厂"
        SCV = "SCV"
        Scout = "侦察机"
        SensorTower = "感应塔"
        Sentry = "哨兵"
        SentryPhasing = "能量者"
        SentryFenix = "保护者"
        ShieldBattery = "护盾充能器"
        SiegeTank = "攻城坦克"
        SiegeTankSieged = "攻城坦克"
        SolarForge = "太阳锻炉"
        SpawningPool = "孵化池"
        SpineCrawler = "脊针爬虫"
        Spire = "尖塔"
        SporeCrawler = "孢子爬虫"
        Starport = "星港"
        Stalker = "追猎者"
        StalkerFenix = "追猎者"
        StalkerPurifier = "追猎者净化者"
        StalkerShakuras = "黑暗追猎者"
        Stukov = "斯托科夫"
        SupplyDepot = "补给站"
        Supplicant = "死徒"
        SwarmHostMP = "飞蛇宿主"
        Tempest = "风暴战舰"
        TemplarArchive = "圣堂武士文献馆"
        Thor = "雷神"
        TwilightCouncil = "暮光议会"
        Ultralisk = "雷兽"
        UltraliskCavern = "雷兽窟"
        VoidRay = "虚空辉光舰"
        Vanguard = "先锋"
        WarPrism = "折跃棱镜"
        WarpPrism = "折跃棱镜"
        WarpPrismPhasing = "折跃棱镜"
        WarpGate = "折跃门"
        Wrathwalker = "怒火巨像"
        Phoenix = "凤凰"
        PhotonCannon = "光子炮台"
        Reaver = "掠夺者"
        Stargate = "星际之门"
        TychusChaingun = "抢手"
        TychusCommando = "枪王"
        Zealot = "狂热者"
        ZealotPurifier = "狂热者净化者"
        Zeratul = "泽拉图"
        ZeratulACArtifact = "神器储放台"
        ZeratulCoop = "泽拉图"
        ZeratulCoopReviveBeacon = "泽拉图的信标"
        ZeratulCyberneticsCore = "芯核锻炉"
        ZeratulDarkArchon = "黑暗执政官"
        ZeratulDarkShrine = "虚空圣坛"
        ZeratulDarkTemplar = "虚空圣堂武士"
        ZeratulDisruptor = "萨尔纳加禁绝者"
        ZeratulGateway = "萨尔纳加通道"
        ZeratulHeroDarkArchon = "瑟达斯"
        ZeratulImmortal = "萨尔纳加执行者"
        ZeratulKhaydarinMonolith = "超立方水晶碑"
        ZeratulNexus = "古代星核"
        ZeratulObserver = "萨尔纳加观察者"
        ZeratulObserverSiegeMode = "萨尔纳加观察者"
        ZeratulPhotonCannon = "超立方光子炮"
        ZeratulProbe = "萨尔纳加先驱"
        ZeratulRoboticsBay = "构造体研究所"
        ZeratulRoboticsFacility = "构造体制造厂"
        ZeratulSentry = "萨尔纳加盾卫"
        ZeratulStalker = "萨尔纳加伏击者"
        ZeratulSummonKarass = "泰布洛斯"
        ZeratulSummonVoidRay = "虚空舰"
        ZeratulSummonZealot = "狂战士"
        ZeratulTransportVoidSeeker = "虚空追寻者"
        ZeratulWarpPrism = "萨尔纳加虚空阵列"
        ZeratulWarpPrismPhasing = "萨尔纳加虚空阵列"
        ZeratulXelNagaConstruct = "精华化身"
        ZeratulXelNagaConstructCyan = "形态化身"
    }
}

function Get-FixedBuildingUnitIds {
    return @(
        "Armory",
        "Assimilator",
        "AutomatedAssimilatorZeratul",
        "BanelingNest",
        "Barracks",
        "Bunker",
        "CommandCenter",
        "CyberneticsCore",
        "DarkShrine",
        "EngineeringBay",
        "EvolutionChamber",
        "Extractor",
        "Factory",
        "FleetBeacon",
        "Forge",
        "FusionCore",
        "GarysDen",
        "Gateway",
        "GreaterSpire",
        "Hatchery",
        "Hive",
        "HydraliskDen",
        "InfestationPit",
        "Lair",
        "MissileTurret",
        "Nexus",
        "PhotonCannon",
        "Pylon",
        "Refinery",
        "RoachWarren",
        "RoboticsBay",
        "RoboticsFacility",
        "SensorTower",
        "ShieldBattery",
        "SolarForge",
        "SpawningPool",
        "SpineCrawler",
        "Spire",
        "SporeCrawler",
        "Stargate",
        "Starport",
        "SupplyDepot",
        "TemplarArchive",
        "TwilightCouncil",
        "UltraliskCavern",
        "WarpGate",
        "DehakaBarracks",
        "DehakaCoopReviveCocoon",
        "DehakaDakrunStructure",
        "DehakaGlevigStructure",
        "DehakaMurvarStructure",
        "ZeratulCoopReviveBeacon",
        "ZeratulCyberneticsCore",
        "ZeratulDarkShrine",
        "ZeratulGateway",
        "ZeratulKhaydarinMonolith",
        "ZeratulNexus",
        "ZeratulPhotonCannon",
        "ZeratulRoboticsBay",
        "ZeratulRoboticsFacility"
    )
}

function Get-DedicatedSourceOwners {
    param(
        [string[]]$SourceNames
    )

    $owners = New-StringSet
    foreach ($sourceName in @($SourceNames)) {
        if ([string]::IsNullOrWhiteSpace($sourceName)) {
            continue
        }

        if ($sourceName -match '^UnitData_([A-Za-z0-9]+)\.xml$') {
            $candidate = [string]$matches[1]
            if ($candidate -notmatch '^Shared') {
                Add-SetValue -Set $owners -Value $candidate
            }
        }
    }

    return @($owners | Sort-Object)
}

function Get-CommanderUpgradeTooltipMap {
    param(
        [string]$UpgradeDataPath,
        [string]$CommanderShortId
    )

    $result = @{}
    if ([string]::IsNullOrWhiteSpace($UpgradeDataPath) -or (-not (Test-Path -LiteralPath $UpgradeDataPath))) {
        return $result
    }

    $prefix = "AC{0}" -f $CommanderShortId
    foreach ($line in @(Get-Content -LiteralPath $UpgradeDataPath -Encoding UTF8)) {
        if ($line -notmatch 'Reference="(Unit|Button),([^",]+),(Description|Tooltip|AlertTooltip|Name)" Value="(?:Button/Tooltip|Unit/Name)/(AC[^"]+)"') {
            continue
        }

        $unitId = [string]$matches[2]
        $key = [string]$matches[4]
        if (-not $key.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        if (-not $result.ContainsKey($unitId)) {
            $result[$unitId] = $key
        }
    }

    return $result
}

function Get-CommanderUpgradeNameMap {
    param(
        [string]$UpgradeDataPath,
        [string]$CommanderShortId
    )

    $result = @{}
    if ([string]::IsNullOrWhiteSpace($UpgradeDataPath) -or (-not (Test-Path -LiteralPath $UpgradeDataPath))) {
        return $result
    }

    $prefix = "AC{0}" -f $CommanderShortId
    foreach ($line in @(Get-Content -LiteralPath $UpgradeDataPath -Encoding UTF8)) {
        if ($line -notmatch 'Reference="(Unit|Button),([^",]+),Name" Value="Unit/Name/(AC[^"]+)"') {
            continue
        }

        $unitId = [string]$matches[2]
        $key = [string]$matches[3]
        if (-not $key.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        if (-not $result.ContainsKey($unitId)) {
            $result[$unitId] = $key
        }
    }

    return $result
}

function Get-UnitNodeValue {
    param(
        [System.Xml.XmlNode]$Node,
        [string]$ChildName
    )

    if ($null -eq $Node) {
        return ""
    }

    $child = $Node.SelectSingleNode($ChildName)
    if ($null -eq $child) {
        return ""
    }

    return [string]$child.value
}

function Test-UnitNodeHasValue {
    param(
        [System.Xml.XmlNode]$Node,
        [string]$XPath,
        [string]$ExpectedValue = ""
    )

    if ($null -eq $Node) {
        return $false
    }

    $match = $Node.SelectSingleNode($XPath)
    if ($null -eq $match) {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($ExpectedValue)) {
        return $true
    }

    return ([string]$match.value -eq $ExpectedValue)
}

function Get-EffectiveUnitValue {
    param(
        [hashtable]$UnitIndex,
        [string]$UnitId,
        [string]$ChildName,
        [System.Collections.Generic.HashSet[string]]$Visited = $null
    )

    if ([string]::IsNullOrWhiteSpace($UnitId) -or (-not $UnitIndex.ContainsKey($UnitId))) {
        return ""
    }

    if ($null -eq $Visited) {
        $Visited = New-StringSet
    }

    if (-not $Visited.Add($UnitId)) {
        return ""
    }

    $record = $UnitIndex[$UnitId]
    if (($null -eq $record) -or ($null -eq $record.Node)) {
        return ""
    }

    $value = Get-UnitNodeValue -Node $record.Node -ChildName $ChildName
    if (-not [string]::IsNullOrWhiteSpace($value)) {
        return $value
    }

    return Get-EffectiveUnitValue -UnitIndex $UnitIndex -UnitId $record.Parent -ChildName $ChildName -Visited $Visited
}

function Get-EffectiveUnitAttributeValue {
    param(
        [hashtable]$UnitIndex,
        [string]$UnitId,
        [string]$AttributeName,
        [System.Collections.Generic.HashSet[string]]$Visited = $null
    )

    if ([string]::IsNullOrWhiteSpace($UnitId) -or (-not $UnitIndex.ContainsKey($UnitId))) {
        return ""
    }

    if ($null -eq $Visited) {
        $Visited = New-StringSet
    }

    if (-not $Visited.Add($UnitId)) {
        return ""
    }

    $record = $UnitIndex[$UnitId]
    if ($null -eq $record) {
        return ""
    }

    if (($null -eq $record.Node) -or ($null -eq $record.Node.Attributes)) {
        return Get-EffectiveUnitAttributeValue -UnitIndex $UnitIndex -UnitId $record.Parent -AttributeName $AttributeName -Visited $Visited
    }

    foreach ($attribute in @($record.Node.Attributes)) {
        if (($null -ne $attribute) -and (([string]$attribute.index -eq $AttributeName) -and (-not [string]::IsNullOrWhiteSpace([string]$attribute.value)))) {
            return [string]$attribute.value
        }
    }

    return Get-EffectiveUnitAttributeValue -UnitIndex $UnitIndex -UnitId $record.Parent -AttributeName $AttributeName -Visited $Visited
}

function Test-IsStructureUnit {
    param(
        [hashtable]$UnitIndex,
        [string]$UnitId,
        [System.Collections.Generic.HashSet[string]]$Visited = $null
    )

    if ([string]::IsNullOrWhiteSpace($UnitId) -or (-not $UnitIndex.ContainsKey($UnitId))) {
        return $false
    }

    if ($null -eq $Visited) {
        $Visited = New-StringSet
    }

    if (-not $Visited.Add($UnitId)) {
        return $false
    }

    $record = $UnitIndex[$UnitId]
    if (($null -eq $record) -or ($null -eq $record.Node)) {
        return $false
    }

    if (Test-UnitNodeHasValue -Node $record.Node -XPath 'Collide[@index="Structure"]' -ExpectedValue '1') {
        return $true
    }

    if (Test-UnitNodeHasValue -Node $record.Node -XPath 'CardLayouts/LayoutButtons[contains(@Face,"Lift")]') {
        return $true
    }

    if (Test-UnitNodeHasValue -Node $record.Node -XPath 'Footprint') {
        return $true
    }

    if (Test-UnitNodeHasValue -Node $record.Node -XPath 'PlacementFootprint') {
        return $true
    }

    return Test-IsStructureUnit -UnitIndex $UnitIndex -UnitId $record.Parent -Visited $Visited
}

function Get-UnitCategory {
    param(
        [hashtable]$UnitIndex,
        [string]$UnitId
    )

    if (($UnitId -match '^SoACaster|^CoopCaster|^CoopAssistCaster') -or ($UnitId -eq 'CoopGlobalCaster')) {
        return "Support"
    }

    $fixedBuildingIds = New-StringSet
    foreach ($buildingId in @(Get-FixedBuildingUnitIds)) {
        Add-SetValue -Set $fixedBuildingIds -Value $buildingId
    }
    if ($fixedBuildingIds.Contains($UnitId)) {
        return "Building"
    }

    if (($null -ne $UnitIndex) -and $UnitIndex.ContainsKey($UnitId)) {
        $parent = [string]$UnitIndex[$UnitId].Parent
        if ((-not [string]::IsNullOrWhiteSpace($parent)) -and $fixedBuildingIds.Contains($parent)) {
            return "Building"
        }
    }

    $editorCategories = Get-EffectiveUnitValue -UnitIndex $UnitIndex -UnitId $UnitId -ChildName "EditorCategories"
    $heroic = (Get-EffectiveUnitAttributeValue -UnitIndex $UnitIndex -UnitId $UnitId -AttributeName "Heroic") -eq "1"
    if ($editorCategories -match "ObjectType:Structure") {
        if (-not $heroic) {
            return "Building"
        }
    }
    if (Test-IsStructureUnit -UnitIndex $UnitIndex -UnitId $UnitId) {
        if (-not $heroic) {
            return "Building"
        }
    }
    if ($editorCategories -match "ObjectType:Structure") {
        if ($heroic) {
            return "Unit"
        }
        return "Building"
    }
    if ($editorCategories -match "ObjectType:Other") {
        return "Support"
    }

    if ($UnitId -match "(Cocoon|Egg|Burrowed|Flying|Sieged|Assault|Phasing|Uprooted)") {
        return "Variant"
    }

    return "Unit"
}

function Get-UnitTags {
    param(
        [hashtable]$UnitIndex,
        [string]$UnitId
    )

    $tags = New-Object System.Collections.Generic.List[string]
    $editorCategories = Get-EffectiveUnitValue -UnitIndex $UnitIndex -UnitId $UnitId -ChildName "EditorCategories"
    if ($editorCategories -match "ObjectType:Hero") {
        $tags.Add("Hero") | Out-Null
    }
    if ($UnitId -match "Cocoon|Egg") {
        $tags.Add("Cocoon/Egg") | Out-Null
    }
    if ($UnitId -match "Burrowed") {
        $tags.Add("Burrowed") | Out-Null
    }
    if ($UnitId -match "Flying") {
        $tags.Add("FlyingStructure") | Out-Null
    }
    if ($UnitId -match "Sieged|Assault|Phasing|Uprooted") {
        $tags.Add("MorphState") | Out-Null
    }
    if ($UnitId -match "^SoACaster|^CoopCaster|^CoopAssistCaster") {
        $tags.Add("TopBarCaster") | Out-Null
    }

    return (@($tags | Select-Object -Unique) -join ", ")
}

function Test-IsIndexableCommanderUnit {
    param(
        [hashtable]$UnitIndex,
        [string]$UnitId
    )

    if ([string]::IsNullOrWhiteSpace($UnitId)) {
        return $false
    }

    if ($UnitId -match '^(MutatorAmon|Mutator|PowerRadius_)') {
        return $false
    }

    if ($UnitId -match '^(Artanis|Zeratul|Stetmann)Void|^Artanis$|^Stetmann$') {
        return $false
    }

    if ($UnitId -match '^CommanderPrestige') {
        return $false
    }

    if ($UnitId -match '^(PurifierGuardianEscort|RoguePurifier|SOAPurifierBeamUnit|ZealotPurifierReviveCorpse)$') {
        return $false
    }

    if ($UnitId -match '(Weapon|Missile|Dummy|Placeholder|Placement|Targeter|Strafer|CellBlock|Precursor|Blocker|FootPrint|RockTower|Terrain)$') {
        return $false
    }

    if ($UnitId -match '(Weapon|Missile|Dummy|Placeholder|Placement|Targeter|Strafer|CellBlock|Precursor|Blocker|FootPrint|RockTower|Terrain)') {
        $category = Get-UnitCategory -UnitIndex $UnitIndex -UnitId $UnitId
        if ($category -ne "Building") {
            return $false
        }
    }

    if (($null -ne $UnitIndex) -and $UnitIndex.ContainsKey($UnitId)) {
        $parent = [string]$UnitIndex[$UnitId].Parent
        if ($parent -match '^MISSILE|^ITEM$|^DESTRUCTIBLE$|^SMCHARACTER$') {
            return $false
        }
    }

    return $true
}

function Escape-MarkdownCell {
    param([string]$Value)

    if ($null -eq $Value) {
        return ""
    }

    return (($Value -replace "\|", "\\|") -replace "\r?\n", "<br>")
}

function Parse-LocalizedValue {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    $parts = $Value -split '\s+///\s+', 2
    return $parts[0].Trim()
}

function New-LocalizedNameIndex {
    return @{
        Unit = @{}
        Button = @{}
        ArmyCategory = @{}
    }
}

function Add-LocalizedNameEntry {
    param(
        [hashtable]$Index,
        [string]$Bucket,
        [string]$Key,
        [string]$Value
    )

    if (($null -eq $Index) -or [string]::IsNullOrWhiteSpace($Bucket) -or [string]::IsNullOrWhiteSpace($Key) -or [string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    if (($Index.ContainsKey($Bucket)) -and (-not $Index[$Bucket].ContainsKey($Key))) {
        $Index[$Bucket][$Key] = $Value
    }
}

function Import-LocalizedUnitNames {
    param(
        [string[]]$Paths
    )

    $nameIndex = New-LocalizedNameIndex
    foreach ($path in @($Paths)) {
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        foreach ($line in @(Get-Content -LiteralPath $path -Encoding UTF8)) {
            if ($line -match '^Unit/Name/([^=]+)=(.*)$') {
                $unitId = [string]$matches[1]
                $unitName = Parse-LocalizedValue -Value ([string]$matches[2])
                Add-LocalizedNameEntry -Index $nameIndex -Bucket "Unit" -Key $unitId -Value $unitName
            }
            elseif ($line -match '^Button/Name/([^=]+)=(.*)$') {
                $buttonId = [string]$matches[1]
                $buttonName = Parse-LocalizedValue -Value ([string]$matches[2])
                Add-LocalizedNameEntry -Index $nameIndex -Bucket "Button" -Key $buttonId -Value $buttonName
            }
            elseif ($line -match '^ArmyCategory/Name/([^=]+)=(.*)$') {
                $categoryId = [string]$matches[1]
                $categoryName = Parse-LocalizedValue -Value ([string]$matches[2])
                Add-LocalizedNameEntry -Index $nameIndex -Bucket "ArmyCategory" -Key $categoryId -Value $categoryName
            }
        }
    }

    return $nameIndex
}

function Get-LocalizedUnitName {
    param(
        [hashtable]$LocalizedNames,
        [hashtable]$UnitIndex,
        [hashtable]$CommanderNameMap = $null,
        [string]$UnitId,
        [System.Collections.Generic.HashSet[string]]$Visited = $null
    )

    if ([string]::IsNullOrWhiteSpace($UnitId)) {
        return ""
    }

    $fixedNames = Get-FixedLocalizedUnitNames
    if ($fixedNames.ContainsKey($UnitId)) {
        return [string]$fixedNames[$UnitId]
    }

    if (($null -ne $LocalizedNames) -and $LocalizedNames.Unit.ContainsKey($UnitId)) {
        return [string]$LocalizedNames.Unit[$UnitId]
    }

    if (($null -ne $LocalizedNames) -and $LocalizedNames.ArmyCategory.ContainsKey($UnitId)) {
        return [string]$LocalizedNames.ArmyCategory[$UnitId]
    }

    if (($null -ne $CommanderNameMap) -and $CommanderNameMap.ContainsKey($UnitId)) {
        $nameKey = [string]$CommanderNameMap[$UnitId]
        if (($null -ne $LocalizedNames) -and $LocalizedNames.Unit.ContainsKey($nameKey)) {
            return [string]$LocalizedNames.Unit[$nameKey]
        }
    }

    if (($null -eq $UnitIndex) -or (-not $UnitIndex.ContainsKey($UnitId))) {
        return ""
    }

    if ($null -eq $Visited) {
        $Visited = New-StringSet
    }

    if (-not $Visited.Add($UnitId)) {
        return ""
    }

    $record = $UnitIndex[$UnitId]
    if ($null -eq $record) {
        return ""
    }

    foreach ($aliasChild in @("SelectAlias", "SubgroupAlias", "HotkeyAlias")) {
        $aliasValue = Get-UnitNodeValue -Node $record.Node -ChildName $aliasChild
        if ((-not [string]::IsNullOrWhiteSpace($aliasValue)) -and ($aliasValue -ne $UnitId)) {
            $localizedAlias = Get-LocalizedUnitName -LocalizedNames $LocalizedNames -UnitIndex $UnitIndex -CommanderNameMap $CommanderNameMap -UnitId $aliasValue -Visited $Visited
            if (-not [string]::IsNullOrWhiteSpace($localizedAlias)) {
                return $localizedAlias
            }
        }
    }

    $localizedParent = Get-LocalizedUnitName -LocalizedNames $LocalizedNames -UnitIndex $UnitIndex -CommanderNameMap $CommanderNameMap -UnitId $record.Parent -Visited $Visited
    if (-not [string]::IsNullOrWhiteSpace($localizedParent)) {
        return $localizedParent
    }

    return ""
}

function Get-CommanderUnitRows {
    param(
        $CommanderRecord,
        [hashtable]$UnitIndex,
        [hashtable]$LocalizedNames,
        [hashtable]$CommanderTooltipMap,
        [hashtable]$CommanderNameMap
    )

    $rows = New-Object System.Collections.Generic.List[object]
    $seen = New-StringSet
    $dedicatedFile = "UnitData_{0}.xml" -f [string]$CommanderRecord.official_short_id
    $tokens = @(Get-CommanderMatchTokens -CommanderRecord $CommanderRecord)
    $sharedUnitIds = New-StringSet
    foreach ($unitId in @(Get-CommanderSharedUnitIds -CommanderRecord $CommanderRecord)) {
        Add-SetValue -Set $sharedUnitIds -Value $unitId
    }

    foreach ($record in $UnitIndex.Values) {
        $include = $false
        $dedicatedOwners = @(Get-DedicatedSourceOwners -SourceNames @($record.Sources))
        $hasForeignDedicatedOwner = (@($dedicatedOwners).Count -gt 0) -and (-not (@($dedicatedOwners) -contains [string]$CommanderRecord.official_short_id))

        if (@($record.Sources) -contains $dedicatedFile) {
            $include = $true
        }
        else {
            if ($sharedUnitIds.Contains($record.Id)) {
                $include = $true
            }
            elseif (($null -ne $CommanderTooltipMap) -and $CommanderTooltipMap.ContainsKey($record.Id)) {
                $include = $true
            }
            elseif (-not $hasForeignDedicatedOwner) {
                $leaderAlias = Get-EffectiveUnitValue -UnitIndex $UnitIndex -UnitId $record.Id -ChildName "LeaderAlias"
                foreach ($token in $tokens) {
                    if (($token.Length -ge 6) -and ($record.Id -like "*$token*")) {
                        $include = $true
                        break
                    }
                    if ((-not [string]::IsNullOrWhiteSpace($leaderAlias)) -and $leaderAlias.Equals($token, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $include = $true
                        break
                    }
                }
            }
        }

        if ((-not $include) -or (-not $seen.Add($record.Id))) {
            continue
        }

        if (-not (Test-IsIndexableCommanderUnit -UnitIndex $UnitIndex -UnitId $record.Id)) {
            continue
        }

        $rows.Add([pscustomobject]@{
                Id = $record.Id
                NameZhCN = Get-LocalizedUnitName -LocalizedNames $LocalizedNames -UnitIndex $UnitIndex -CommanderNameMap $CommanderNameMap -UnitId $record.Id
                Parent = $record.Parent
                Category = Get-UnitCategory -UnitIndex $UnitIndex -UnitId $record.Id
                Tags = Get-UnitTags -UnitIndex $UnitIndex -UnitId $record.Id
                Sources = (@($record.Sources | Sort-Object -Unique) -join ", ")
            }) | Out-Null
    }

    return @(
        $rows |
        Sort-Object @{ Expression = {
                    switch ($_.Category) {
                        "Building" { 0 }
                        "Unit" { 1 }
                        "Variant" { 2 }
                        default { 3 }
                    }
                }
            }, Id
    )
}

$workspaceRoot = Get-WorkspaceRoot
$outputPath = Resolve-OutputPath -WorkspaceRoot $workspaceRoot -RequestedPath $OutputPath
$outputDir = Split-Path -Parent $outputPath
if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$gameDataRoot = Join-Path $workspaceRoot "Mods\7vs1\CommanderCatalog.SC2Mod\Base.SC2Data\GameData"
$unitPaths = @(
    @(Get-CatalogXmlPaths -GameDataRoot $gameDataRoot -BaseName "UnitData") +
    @(Get-AdditionalUnitCatalogPaths -WorkspaceRoot $workspaceRoot)
) | Select-Object -Unique
$upgradeDataPath = Join-Path $workspaceRoot "游戏数据\其他mod数据\7vs1母巢之战合作指挥官bate版_SC2Replay_94137\_semantic-by-commander\_shared\s2ma_packages\pkg01\extract\base.sc2data\GameData\UpgradeData.xml"
$metadata = Get-CommanderPowerMetadata -WorkspaceRoot $workspaceRoot

$unitIndex = @{}
foreach ($path in $unitPaths) {
    [xml]$xml = Get-Content -LiteralPath $path -Encoding UTF8 -Raw
    $sourceName = Split-Path -Leaf $path
    foreach ($node in @($xml.SelectNodes("/Catalog/CUnit[@id]"))) {
        $id = [string]$node.id
        if ([string]::IsNullOrWhiteSpace($id)) {
            continue
        }

        if (-not $unitIndex.ContainsKey($id)) {
            $unitIndex[$id] = [pscustomobject]@{
                Id = $id
                Parent = [string]$node.parent
                Node = $node
                Sources = New-Object System.Collections.Generic.List[string]
            }
        }
        else {
            if (-not [string]::IsNullOrWhiteSpace([string]$node.parent)) {
                $unitIndex[$id].Parent = [string]$node.parent
            }
            if (@($node.ChildNodes).Count -gt 0) {
                $unitIndex[$id].Node = $node
            }
        }

        if (-not @($unitIndex[$id].Sources).Contains($sourceName)) {
            $unitIndex[$id].Sources.Add($sourceName) | Out-Null
        }
    }
}

$commandersByShortId = @{}
foreach ($commander in @($metadata.commanders)) {
    $commandersByShortId[[string]$commander.official_short_id] = $commander
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Commander Unit And Building Index") | Out-Null
$lines.Add("") | Out-Null
$lines.Add(("Generated: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))) | Out-Null
$lines.Add("") | Out-Null
$lines.Add("Source: local `CommanderCatalog.SC2Mod/Base.SC2Data/GameData/UnitData*.xml` files in this repository.") | Out-Null
$lines.Add("Rule: prefer commander-specific `UnitData_<Commander>.xml` entries, then supplement with shared-file units that carry commander-specific XML markers or curated shared-tech baselines.") | Out-Null
$lines.Add("") | Out-Null

foreach ($shortId in (Get-CommanderOrder)) {
    if (-not $commandersByShortId.ContainsKey($shortId)) {
        continue
    }

    $commander = $commandersByShortId[$shortId]
    $localizedPaths = Get-LocalizedNameFileCandidates -WorkspaceRoot $workspaceRoot -CommanderShortId $shortId
    $localizedNames = Import-LocalizedUnitNames -Paths $localizedPaths
    $commanderTooltipMap = Get-CommanderUpgradeTooltipMap -UpgradeDataPath $upgradeDataPath -CommanderShortId $shortId
    $commanderNameMap = Get-CommanderUpgradeNameMap -UpgradeDataPath $upgradeDataPath -CommanderShortId $shortId
    $rows = @(Get-CommanderUnitRows -CommanderRecord $commander -UnitIndex $unitIndex -LocalizedNames $localizedNames -CommanderTooltipMap $commanderTooltipMap -CommanderNameMap $commanderNameMap)
    $buildingCount = @($rows | Where-Object { $_.Category -eq "Building" }).Count
    $unitCount = @($rows | Where-Object { $_.Category -eq "Unit" }).Count
    $variantCount = @($rows | Where-Object { $_.Category -eq "Variant" }).Count
    $supportCount = @($rows | Where-Object { $_.Category -eq "Support" }).Count

    $lines.Add(("## {0} (`{1}`)" -f [string]$commander.display_name, [string]$commander.official_short_id)) | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add(("Counts: buildings {0}, units {1}, variants {2}, support {3}." -f $buildingCount, $unitCount, $variantCount, $supportCount)) | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("| Catalog ID | Name ZH | Category | Parent | Tags | Source Files |") | Out-Null
    $lines.Add("| --- | --- | --- | --- | --- | --- |") | Out-Null
    foreach ($row in $rows) {
        $lines.Add((
                "| `{0}` | {1} | {2} | `{3}` | {4} | `{5}` |" -f
                (Escape-MarkdownCell $row.Id),
                (Escape-MarkdownCell $row.NameZhCN),
                (Escape-MarkdownCell $row.Category),
                (Escape-MarkdownCell $row.Parent),
                (Escape-MarkdownCell $row.Tags),
                (Escape-MarkdownCell $row.Sources)
            )) | Out-Null
    }
    $lines.Add("") | Out-Null
}

[System.IO.File]::WriteAllText($outputPath, ($lines -join [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))
Write-Output ("COMMANDER_UNIT_BUILDING_INDEX_WRITTEN={0}" -f $outputPath)
