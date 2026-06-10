<#
.SYNOPSIS
Local Web launcher for 7vs1 coop commander test maps.

.DESCRIPTION
Serves a dependency-free Web UI and delegates game installation/launching to
launch-7vs1-coop-test.ps1. The Web layer owns selection and display only; the
existing launch script remains the authority for map install, bank writes, and
SC2Switcher invocation.
#>
[CmdletBinding()]
param(
    [int]$Port = 17761,
    [string]$HostName = "127.0.0.1",
    [switch]$SelfTest,
    [switch]$NoOpen
)

$ErrorActionPreference = "Stop"

$script:WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$script:LaunchScript = Join-Path $PSScriptRoot "launch-7vs1-coop-test.ps1"
$script:MetadataPath = Join-Path $script:WorkspaceRoot "Shared\CommanderPower\commander-power-metadata.json"
$script:MapsRoot = Join-Path $script:WorkspaceRoot "Maps"
$script:WebRoot = Join-Path $script:WorkspaceRoot "web-launcher"
$script:AssetsCacheRoot = Join-Path $script:WebRoot "assets-cache"
$script:RealCommanderPortraitRoot = Join-Path $script:WebRoot "exported-real-commander-images"
$script:LogsRoot = Join-Path $script:WorkspaceRoot "logs"
$script:MutatorStringsPath = Join-Path $script:WorkspaceRoot "Mods\kit_mutations.SC2Mod\zhCN.SC2Data\LocalizedData\GameStrings.txt"
$script:MutatorsXmlPath = Join-Path $script:WorkspaceRoot "Mods\kit_mutations.SC2Mod\Base.SC2Data\GameData\Mutators.xml"
$script:LaunchProcesses = @{}
$script:AssetSourceConfig = $null
$script:CommanderExactPortraitMap = @{
    TerranRaynor   = "TerranRaynor.png"
    ZergKerrigan   = "ZergKerrigan.png"
    ProtossArtanis = "ProtossArtanis.png"
    ZergZagara     = "ZergZagara.png"
    ProtossAlarak  = "ProtossAlarak.png"
    TerranNova     = "TerranNova.png"
    ProtossFenix   = "ProtossFenix.png"
    ZergDehaka     = "ZergDehaka.png"
    TerranTychus   = "TerranTychus.png"
    ProtossZeratul = "ProtossZeratul.png"
    TerranSwann    = "TerranSwann.png"
    ZergStukov     = "ZergStukov.png"
    TerranHorner   = "TerranHorner.png"
    TerranMengsk   = "TerranMengsk.png"
    ZergStetmann   = "ZergStetmann.png"
    ZergAbathur    = "ZergAbathur.png"
    ProtossKarax   = "ProtossKarax.png"
    ProtossVorazun = "ProtossVorazun.png"
}
$script:CommanderInlineStatusMap = @{
    TerranSwann  = "partial-inline"
    ZergStukov   = "partial-inline"
    TerranHorner = "partial-inline"
    TerranNova   = "partial-inline"
    TerranTychus = "partial-inline"
    TerranMengsk = "partial-inline"
    ZergStetmann = "partial-inline"
    ZergDehaka   = "partial-inline"
}
$script:MutatorFallbackArtMap = @{
    AfraidOfTheDark     = @("btn-command-move")
    AllEnemiesCloaked   = @("btn-ability-zeratul-sentry-eclipseprotocol")
    Avenger             = @("btn-upgrade-zerg-abathur-biomass")
    Barrier             = @("btn-ability-zeratul-immortal-enternitybarrier")
    BlackFog            = @("btn-ability-zeratul-sentry-eclipseprotocol")
    Blizzard            = @("btn-ability-zeratul-disruptor-clusternova")
    BoomBots            = @("btn-ability-hornerhan-battlecruiser-yamato")
    ConcussiveAttacks   = @("btn-upgrade-tychus-warhound-thunderboltmissiles")
    CycleRandom         = @("btn-command-move")
    DamageBounce        = @("btn-upgrade-swann-defensivematrix")
    DamageReflect       = @("btn-upgrade-swann-defensivematrix")
    DeathAOE            = @("btn-ability-tychus-reaper-demolitioncharge")
    DeathPull           = @("btn-ability-zeratul-stalker-vengeanceofthevoid")
    DropPods            = @("Talent-Raynor-Level08-OrbitalDropPods")
    Entomb              = @("btn-building-stukov-infestedcommandcenter")
    Evolve              = @("btn-upgrade-zerg-abathur-biomass")
    Fear                = @("btn-ability-dehaka-damagereductionwhilemoving")
    FireFight           = @("btn-ability-mengsk-topbar-contaminatedstrike")
    Fireworks           = @("btn-ability-stetmann-garytravelingdamageorb")
    FoodHunt            = @("Talent-Swann-Level05-VespeneDrone")
    GiftFight           = @("btn-ability-stetmann-scrapdrop")
    HardenedWill        = @("btn-ability-alarak-reliquaryofsouls")
    HeroesFromTheStorm  = @("btn-ability-alarak-reliquaryofsouls")
    HybridNuke          = @("btn-ability-mengsk-topbar-contaminatedstrike")
    InfestedTerranSpawner = @("btn-building-stukov-infestedbarracks")
    Inspiration         = @("btn-ability-kerrigan-wildmutation")
    Insubordination     = @("btn-ability-mengsk-commandcenter-drafttroopers")
    JustDie             = @("btn-upgrade-tychus-warhound-umojanframe")
    KillBots            = @("btn-ability-tychus-warhound-deployturret")
    KillKarma           = @("btn-ability-mengsk-ghost-staticempblast")
    LaserDrill          = @("btn-tips-laserdrillcontrol")
    LavaBurst           = @("btn-ability-stetmann-garytravelingdamageorb")
    LazyWorkers         = @("Talent-Swann-Level05-VespeneDrone")
    LifeLeech           = @("btn-ability-zerg-dehaka-consume")
    LongRange           = @("btn-ability-zeratul-stalker-phasebattery")
    Magnificent         = @("btn-ability-stetmann-garymassteleport")
    MissileBarrage      = @("btn-ability-mengsk-topbar-contaminatedstrike")
    MomentOfSilence     = @("btn-ability-tychus-spectre-ultrasonicpulse")
    NoResources         = @("btn-ability-mengsk-commandcenter-draftlaborers")
    Nukes               = @("btn-ability-hornerhan-battlecruiser-yamato")
    OopsAllCasters      = @("btn-ability-alarak-reliquaryofsouls")
    OrbitalStrike       = @("btn-ability-mengsk-topbar-contaminatedstrike")
    OrderCosts          = @("btn-ability-mengsk-commandcenter-draftlaborers")
    PhotonOverload      = @("btn-upgrade-karax_solarlance")
    Plague              = @("btn-ability-zerg-stukov-summonpsiemitter")
    Polarity            = @("btn-ability-zeratul-darktemplar-blink")
    Propagate           = @("btn-ability-zerg-dehaka-levelup")
    PurifierBeam        = @("btn-upgrade-karax_solarlance")
    Random              = @("btn-command-move")
    Reanimators         = @("btn-ability-zerg-dehaka-levelup")
    RedEnvelopes        = @("btn-ability-stetmann-scrapdrop")
    ReducedVision       = @("btn-ability-zeratul-observer-sensorarray")
    SharedSupply        = @("Talent-Swann-Level08-ImprovedSCVs")
    SideStep            = @("btn-ability-zeratul-darktemplar-blink")
    Sluggish            = @("btn-ability-dehaka-damagereductionwhilemoving")
    SpawnBroodlings     = @("btn-ability-kerrigan-wildmutation")
    SpiderMines         = @("btn-ability-tychus-warhound-deployturret")
    StoneZealots        = @("BTN-Upgrade-Artanis-SingularityCharge")
    StructureSteal      = @("btn-building-terran-commandcentermengsk")
    TemporalField       = @("btn-ability-stetmann-garymassteleport")
    TimeWarp            = @("btn-ability-stetmann-garymassteleport")
    Tornadoes           = @("btn-ability-stetmann-garytravelingdamageorb")
    TrickOrTreat        = @("btn-ability-stetmann-scrapdrop")
    UberDarkness        = @("btn-ability-zeratul-sentry-eclipseprotocol")
    UndyingEvil         = @("btn-ability-zerg-dehaka-levelup")
    UnitSpeed           = @("btn-upgrade-tychus-tychus-sureshotnetwork")
    Vertigo             = @("btn-ability-stetmann-garytravelingdamageorb")
    VoidRifts           = @("btn-ability-zeratul-stalker-vengeanceofthevoid")
    WalkingInfested     = @("btn-building-stukov-infestedbarracks")
}

foreach ($requiredPath in @($script:LaunchScript, $script:MetadataPath, $script:MapsRoot, $script:WebRoot)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required path not found: $requiredPath"
    }
}
if (-not (Test-Path -LiteralPath $script:RealCommanderPortraitRoot)) {
    New-Item -ItemType Directory -Path $script:RealCommanderPortraitRoot | Out-Null
}
if (-not (Test-Path -LiteralPath $script:LogsRoot)) {
    New-Item -ItemType Directory -Path $script:LogsRoot | Out-Null
}
if (-not (Test-Path -LiteralPath $script:AssetsCacheRoot)) {
    New-Item -ItemType Directory -Path $script:AssetsCacheRoot | Out-Null
}

function Get-AssetSourceConfig {
    if ($null -ne $script:AssetSourceConfig) {
        return $script:AssetSourceConfig
    }

    $metadata = Get-Content -LiteralPath $script:MetadataPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $officialCommandersRoot = [string]$metadata.source.official_commanders_root
    $officialBase = if ([string]::IsNullOrWhiteSpace($officialCommandersRoot)) {
        ""
    }
    else {
        Split-Path -Parent $officialCommandersRoot
    }

    $script:AssetSourceConfig = [pscustomobject]@{
        officialBase = $officialBase
        previewJpgRoot = if ($officialBase) { Join-Path $officialBase "icon-assets\preview-jpg\Assets\Textures" } else { "" }
        previewPngRoot = if ($officialBase) { Join-Path $officialBase "icon-assets\preview-png\Assets\Textures" } else { "" }
        mutationWingAssets = "C:\Users\22448\Downloads\因子之翼\kit_liberty_mutation_challenge.SC2Mod\Assets\Textures"
    }
    return $script:AssetSourceConfig
}

function Get-CommanderIntegrationStatus {
    param([string]$Runtime)

    if ($script:CommanderInlineStatusMap.ContainsKey($Runtime)) {
        return [pscustomobject]@{
            code = "partial-inline"
            label = "部分内联"
            tone = "warn"
            note = "威望/精通协议已验证，但仍有专属初始化保留在共享内联分支。"
        }
    }

    return [pscustomobject]@{
        code = "verified"
        label = "已验证"
        tone = "ok"
        note = "已进入 CommanderPower 校验矩阵，可作为常规测试入口。"
    }
}

function Get-TextureBaseName {
    param([string]$AssetRef)

    if ([string]::IsNullOrWhiteSpace($AssetRef)) {
        return ""
    }
    return [System.IO.Path]::GetFileNameWithoutExtension($AssetRef.Trim())
}

function Get-AssetCacheBucketPath {
    param([string]$Bucket)

    $path = Join-Path $script:AssetsCacheRoot $Bucket
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
    return $path
}

function Get-RealCommanderPortraitPath {
    param([string]$FileName)

    if ([string]::IsNullOrWhiteSpace($FileName)) {
        return ""
    }

    $candidate = Join-Path $script:RealCommanderPortraitRoot $FileName
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return $candidate
    }
    return ""
}

function Get-FileVersionQuery {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return ""
    }

    $item = Get-Item -LiteralPath $Path
    return "?v=$($item.LastWriteTimeUtc.Ticks)"
}

function Clear-StaleCommanderCache {
    $commandersCacheRoot = Get-AssetCacheBucketPath -Bucket "commanders"
    $staleFiles = Get-ChildItem -LiteralPath $commandersCacheRoot -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -ieq ".jpg" -or
            $_.Extension -ieq ".jpeg" -or
            $_.BaseName -match '-'
        }

    foreach ($file in $staleFiles) {
        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
    }
}

function Get-PreviewAssetPath {
    param([string]$BaseName)

    if ([string]::IsNullOrWhiteSpace($BaseName)) {
        return ""
    }

    $config = Get-AssetSourceConfig
    foreach ($candidate in @(
            (Join-Path $config.previewJpgRoot ($BaseName + ".jpg")),
            (Join-Path $config.previewPngRoot ($BaseName + ".png"))
        )) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }
    return ""
}

function Copy-AssetToCache {
    param(
        [string]$Bucket,
        [string]$LogicalId,
        [string[]]$BaseNames
    )

    $targetDir = Get-AssetCacheBucketPath -Bucket $Bucket
    $safeId = ($LogicalId -replace '[^A-Za-z0-9_-]', '_')

    foreach ($baseName in @($BaseNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $sourcePath = Get-PreviewAssetPath -BaseName $baseName
        if (-not $sourcePath) {
            continue
        }

        $extension = [System.IO.Path]::GetExtension($sourcePath).ToLowerInvariant()
        $safeBaseName = ($baseName -replace '[^A-Za-z0-9_-]', '_')
        $targetPath = Join-Path $targetDir ($safeId + "-" + $safeBaseName + $extension)
        $needsCopy = $true
        if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
            $sourceInfo = Get-Item -LiteralPath $sourcePath
            $targetInfo = Get-Item -LiteralPath $targetPath
            $needsCopy = $sourceInfo.LastWriteTimeUtc -gt $targetInfo.LastWriteTimeUtc
        }
        if ($needsCopy) {
            Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
        }
        return "/assets-cache/$Bucket/$([System.IO.Path]::GetFileName($targetPath))"
    }

    return ""
}

function Resolve-CommanderPortrait {
    param([string]$Runtime)

    $portraitFileName = if ($script:CommanderExactPortraitMap.ContainsKey($Runtime)) {
        [string]$script:CommanderExactPortraitMap[$Runtime]
    }
    else {
        ""
    }

    $portraitPath = Get-RealCommanderPortraitPath -FileName $portraitFileName
    if ($portraitPath) {
        $targetDir = Get-AssetCacheBucketPath -Bucket "commanders"
        $targetName = "$Runtime$([System.IO.Path]::GetExtension($portraitPath).ToLowerInvariant())"
        $targetPath = Join-Path $targetDir $targetName
        $needsCopy = $true
        if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
            $sourceInfo = Get-Item -LiteralPath $portraitPath
            $targetInfo = Get-Item -LiteralPath $targetPath
            $needsCopy = $sourceInfo.LastWriteTimeUtc -gt $targetInfo.LastWriteTimeUtc
        }
        if ($needsCopy) {
            Copy-Item -LiteralPath $portraitPath -Destination $targetPath -Force
        }
        $versionQuery = Get-FileVersionQuery -Path $targetPath
        return [pscustomobject]@{
            image = "/assets-cache/commanders/$([System.IO.Path]::GetFileName($targetPath))$versionQuery"
            source = "portrait-exact"
            sourceLabel = "真实头像"
        }
    }

    return [pscustomobject]@{
        image = ""
        source = "missing"
        sourceLabel = "待补头像"
    }
}

function Get-DefaultMutatorArtNames {
    param([string]$Category)

    switch ($Category) {
        "environment" { return @("btn-upgrade-karax_solarlance", "btn-ability-stetmann-garytravelingdamageorb") }
        "enemy" { return @("btn-upgrade-zerg-abathur-biomass", "btn-ability-kerrigan-wildmutation") }
        "economy" { return @("Talent-Swann-Level05-VespeneDrone", "btn-ability-mengsk-commandcenter-draftlaborers") }
        "defense" { return @("btn-ability-zeratul-immortal-enternitybarrier", "btn-upgrade-swann-defensivematrix") }
        "random" { return @("btn-command-move", "btn-ability-stetmann-garymassteleport") }
        default { return @("btn-command-move", "btn-ability-kerrigan-wildmutation") }
    }
}

function Resolve-CommanderImage {
    param([string]$Runtime)

    return (Resolve-CommanderPortrait -Runtime $Runtime).image
}

function Resolve-MutatorImage {
    param(
        [string]$Id,
        [string]$Icon,
        [string]$Category
    )

    $baseNames = New-Object System.Collections.Generic.List[string]
    $iconBaseName = Get-TextureBaseName -AssetRef $Icon
    if ($iconBaseName) {
        $baseNames.Add($iconBaseName)
    }

    $exactImage = Copy-AssetToCache -Bucket "mutators" -LogicalId $Id -BaseNames @($iconBaseName)
    if ($exactImage) {
        return [pscustomobject]@{
            image = $exactImage
            source = "icon-exact"
            sourceLabel = "游戏图标"
        }
    }

    $fallbackBaseNames = New-Object System.Collections.Generic.List[string]
    if ($script:MutatorFallbackArtMap.ContainsKey($Id)) {
        foreach ($name in @($script:MutatorFallbackArtMap[$Id])) {
            $fallbackBaseNames.Add([string]$name)
        }
    }
    foreach ($name in @(Get-DefaultMutatorArtNames -Category $Category)) {
        $fallbackBaseNames.Add([string]$name)
    }

    $fallbackImage = Copy-AssetToCache -Bucket "mutators" -LogicalId $Id -BaseNames $fallbackBaseNames.ToArray()
    if ($fallbackImage) {
        return [pscustomobject]@{
            image = $fallbackImage
            source = "icon-fallback"
            sourceLabel = "主题回退"
        }
    }

    return [pscustomobject]@{
        image = ""
        source = "missing"
        sourceLabel = "未命中"
    }
}

function ConvertFrom-SC2Text {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $clean = $Text -replace '<n\s*/>', ' '
    $clean = $clean -replace '<[^>]+>', ''
    $clean = $clean -replace '\s+', ' '
    return $clean.Trim()
}

function Get-LocalizedStringMap {
    $map = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::OrdinalIgnoreCase)
    if (-not (Test-Path -LiteralPath $script:MutatorStringsPath)) {
        return $map
    }

    foreach ($line in Get-Content -LiteralPath $script:MutatorStringsPath -Encoding UTF8) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            continue
        }

        $index = $line.IndexOf("=")
        if ($index -lt 1) {
            continue
        }

        $key = $line.Substring(0, $index)
        $value = $line.Substring($index + 1)
        $map[$key] = (ConvertFrom-SC2Text $value)
    }

    return $map
}

function Get-MutatorIdsFromLaunchScript {
    if (-not (Test-Path -LiteralPath $script:MutatorsXmlPath)) {
        throw "Mutators.xml not found: $script:MutatorsXmlPath"
    }

    [xml]$xml = Get-Content -LiteralPath $script:MutatorsXmlPath -Raw -Encoding UTF8
    $mutatorUser = @($xml.Catalog.CUser | Where-Object { $_.id -eq "Mutators" } | Select-Object -First 1)
    if ($mutatorUser.Count -eq 0) {
        throw "Could not find CUser id='Mutators' in $script:MutatorsXmlPath"
    }

    $ids = New-Object System.Collections.Generic.List[string]
    foreach ($instance in @($mutatorUser[0].Instances)) {
        $id = [string]$instance.Id
        if ([string]::IsNullOrWhiteSpace($id) -or $id -eq "[Default]") {
            continue
        }

        $customAllowed = $false
        foreach ($intNode in @($instance.Int)) {
            $field = @($intNode.Field | Where-Object { $_.Id -eq "CustomAllowed" } | Select-Object -First 1)
            if ($field.Count -gt 0 -and [string]$intNode.Int -eq "1") {
                $customAllowed = $true
                break
            }
        }

        if ($customAllowed) {
            $ids.Add($id)
        }
    }

    return $ids.ToArray()
}

function Get-MutatorIconMap {
    $map = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::OrdinalIgnoreCase)
    if (-not (Test-Path -LiteralPath $script:MutatorsXmlPath)) {
        return $map
    }

    [xml]$xml = Get-Content -LiteralPath $script:MutatorsXmlPath -Raw -Encoding UTF8
    $mutatorUser = @($xml.Catalog.CUser | Where-Object { $_.id -eq "Mutators" } | Select-Object -First 1)
    if ($mutatorUser.Count -eq 0) {
        return $map
    }

    foreach ($instance in @($mutatorUser[0].Instances)) {
        $id = [string]$instance.Id
        if ([string]::IsNullOrWhiteSpace($id) -or $id -eq "[Default]") {
            continue
        }

        foreach ($image in @($instance.Image)) {
            $field = @($image.Field | Where-Object { $_.Id -eq "Icon" } | Select-Object -First 1)
            if ($field.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$image.Image)) {
                $map[$id] = [string]$image.Image
                break
            }
        }
    }

    return $map
}

function Get-CommanderItems {
    $metadata = Get-Content -LiteralPath $script:MetadataPath -Raw -Encoding UTF8 | ConvertFrom-Json

    return @($metadata.commanders | ForEach-Object {
            $commanderRecord = $_
            $displayName = [string]$commanderRecord.display_name
            if ([string]::IsNullOrWhiteSpace($displayName)) {
                $displayName = [string]$commanderRecord.runtime_commander
            }
            $runtime = [string]$commanderRecord.runtime_commander
            $bankCommander = [string]$commanderRecord.bank_commander
            $portrait = Resolve-CommanderPortrait -Runtime $runtime
            $status = Get-CommanderIntegrationStatus -Runtime $runtime

            [pscustomobject]@{
                runtime = $runtime
                displayName = $displayName
                bankCommander = $bankCommander
                generatedCommander = [string]$commanderRecord.generated_commander
                image = $portrait.image
                imageReady = -not [string]::IsNullOrWhiteSpace($portrait.image)
                imageSource = $portrait.source
                imageSourceLabel = $portrait.sourceLabel
                integrationStatus = $status.label
                integrationStatusCode = $status.code
                integrationTone = $status.tone
                integrationNote = $status.note
                defaultPrestigeBonusMask = if ($null -ne $commanderRecord.default_prestige_bonus_mask) { [int]$commanderRecord.default_prestige_bonus_mask } else { 7 }
                defaultPrestigePointIndex = if ($null -ne $commanderRecord.default_prestige_point_index) { [int]$commanderRecord.default_prestige_point_index } else { -1 }
                prestiges = @($commanderRecord.prestiges | ForEach-Object {
                        $prestigeRecord = $_
                        $prestigeBitMask = [int]$prestigeRecord.bit_mask
                        [pscustomobject]@{
                            slot = [int]$prestigeRecord.slot
                            bitMask = $prestigeBitMask
                            id = [string]$prestigeRecord.id
                            name = [string]$prestigeRecord.name
                            nameEn = [string]$prestigeRecord.name_en
                            tooltip = ConvertFrom-SC2Text ([string]$prestigeRecord.tooltip)
                            extraOptions = @($prestigeRecord.extra_options | ForEach-Object {
                                    $optionRecord = $_
                                    $enabledValue = if ($null -ne $optionRecord.enabled_value) { [int]$optionRecord.enabled_value } else { 1 }
                                    $bankKey = [string]$optionRecord.bank_key
                                    [pscustomobject]@{
                                        id = [string]$optionRecord.id
                                        bankKey = $bankKey
                                        name = [string]$optionRecord.name
                                        description = ConvertFrom-SC2Text ([string]$optionRecord.description)
                                        type = if ([string]::IsNullOrWhiteSpace([string]$optionRecord.type)) { "toggle" } else { [string]$optionRecord.type }
                                        defaultEnabled = ((if ($null -ne $optionRecord.default) { [int]$optionRecord.default } else { 0 }) -gt 0)
                                        enabledValue = $enabledValue
                                        requiresPrestigeMask = if ($null -ne $optionRecord.requires_prestige_mask) { [int]$optionRecord.requires_prestige_mask } else { $prestigeBitMask }
                                        overrideValue = if ([string]::IsNullOrWhiteSpace($bankKey)) { "" } else { "$bankCommander.$bankKey=$enabledValue" }
                                    }
                                })
                        }
                    })
                masteries = @($commanderRecord.masteries | ForEach-Object {
                        [pscustomobject]@{
                            slot = [int]$_.slot
                            category = [int]$_.category
                            id = [string]$_.id
                            name = [string]$_.name
                            valueFormat = [string]$_.value_format
                        }
                    })
            }
        } | Sort-Object displayName)
}

function Get-MapDisplayName {
    param([string]$MapPath)

    $stringsPath = Join-Path $MapPath "zhCN.SC2Data\LocalizedData\GameStrings.txt"
    if (-not (Test-Path -LiteralPath $stringsPath)) {
        return [System.IO.Path]::GetFileName($MapPath)
    }

    foreach ($line in Get-Content -LiteralPath $stringsPath -Encoding UTF8) {
        if ($line.StartsWith("DocInfo/Name=")) {
            $name = $line.Substring("DocInfo/Name=".Length).Trim()
            if (-not [string]::IsNullOrWhiteSpace($name)) {
                return $name
            }
        }
    }

    return [System.IO.Path]::GetFileName($MapPath)
}

function Get-MapItems {
    return @(Get-ChildItem -LiteralPath $script:MapsRoot -Directory -Filter "*_7vs1.SC2Map" |
        Sort-Object Name |
        ForEach-Object {
            $title = Get-MapDisplayName -MapPath $_.FullName
            [pscustomobject]@{
                id = $_.Name
                displayName = if ($title -eq $_.Name) { $_.Name } else { "$title ($($_.Name))" }
                title = $title
                path = $_.FullName
            }
        })
}

function Get-MutatorItems {
    $strings = Get-LocalizedStringMap
    $icons = Get-MutatorIconMap
    $ids = Get-MutatorIdsFromLaunchScript

    return @($ids | ForEach-Object {
            $id = [string]$_
            $nameKey = "UserData/Mutators/$($id)_Name"
            $descriptionKey = "UserData/Mutators/$($id)_Description"
            $name = if ($strings.ContainsKey($nameKey)) { $strings[$nameKey] } else { $id }
            $description = if ($strings.ContainsKey($descriptionKey)) { $strings[$descriptionKey] } else { "" }
            $icon = if ($icons.ContainsKey($id)) { $icons[$id] } else { "" }
            $class = Get-MutatorClass -Id $id
            $image = Resolve-MutatorImage -Id $id -Icon $icon -Category $class.category

            [pscustomobject]@{
                id = $id
                name = $name
                description = $description
                icon = $icon
                image = $image.image
                iconReady = -not [string]::IsNullOrWhiteSpace($image.image)
                imageSource = $image.source
                imageSourceLabel = $image.sourceLabel
                category = $class.category
                tier = $class.tier
            }
        })
}

function Get-MutatorClass {
    param([string]$Id)

    $environment = @(
        "BlackFog", "TimeWarp", "Magnificent", "FireFight", "LavaBurst", "TemporalField", "Tornadoes",
        "OrbitalStrike", "PurifierBeam", "Blizzard", "Nukes", "UberDarkness", "Vertigo", "AfraidOfTheDark"
    )
    $enemy = @(
        "WalkingInfested", "InfestedTerranSpawner", "UnitSpeed", "Avenger", "SideStep", "DeathAOE",
        "DropPods", "SpawnBroodlings", "LongRange", "ReducedVision", "HybridNuke", "AllEnemiesCloaked",
        "JustDie", "Reanimators", "LifeLeech", "OopsAllCasters", "UndyingEvil", "Polarity", "Evolve",
        "HeroesFromTheStorm", "Inspiration", "HardenedWill", "Sluggish", "DamageReflect", "DeathPull",
        "Propagate", "MomentOfSilence"
    )
    $economy = @(
        "Entomb", "LazyWorkers", "NoResources", "OrderCosts", "TrickOrTreat", "FoodHunt",
        "SharedSupply", "RedEnvelopes", "KillBots", "BoomBots", "MissileBarrage"
    )
    $defense = @(
        "Barrier", "ConcussiveAttacks", "StoneZealots", "PhotonOverload", "SpiderMines",
        "DamageBounce", "Plague", "StructureSteal", "GiftFight", "KillKarma", "Insubordination"
    )
    $random = @("Random", "CycleRandom")
    $hard = @(
        "VoidRifts", "Nukes", "MissileBarrage", "Polarity", "Propagate", "KillBots", "BoomBots",
        "MomentOfSilence", "HeroesFromTheStorm", "JustDie", "Avenger", "LifeLeech", "Evolve",
        "DamageReflect", "DeathPull", "Plague"
    )
    $medium = @(
        "BlackFog", "TimeWarp", "UnitSpeed", "Magnificent", "DeathAOE", "DropPods", "LaserDrill",
        "LongRange", "ReducedVision", "HybridNuke", "AllEnemiesCloaked", "TemporalField", "Tornadoes",
        "OrbitalStrike", "PurifierBeam", "Blizzard", "Fear", "PhotonOverload", "SpiderMines",
        "Reanimators", "OrderCosts", "UndyingEvil", "UberDarkness", "FoodHunt", "SharedSupply",
        "DamageBounce", "StructureSteal", "GiftFight", "KillKarma", "AfraidOfTheDark", "Insubordination"
    )

    $category = "other"
    if ($random -contains $Id) { $category = "random" }
    elseif ($environment -contains $Id) { $category = "environment" }
    elseif ($enemy -contains $Id) { $category = "enemy" }
    elseif ($economy -contains $Id) { $category = "economy" }
    elseif ($defense -contains $Id) { $category = "defense" }

    $tier = "normal"
    if ($hard -contains $Id) { $tier = "hard" }
    elseif ($medium -contains $Id) { $tier = "medium" }

    return [pscustomobject]@{
        category = $category
        tier = $tier
    }
}

function Get-BootstrapData {
    $commanders = @(Get-CommanderItems)
    $maps = @(Get-MapItems)
    $mutators = @(Get-MutatorItems)

    return [pscustomobject]@{
        generatedAt = (Get-Date).ToString("o")
        workspaceRoot = $script:WorkspaceRoot
        launchScript = $script:LaunchScript
        counts = [pscustomobject]@{
            commanders = $commanders.Count
            maps = $maps.Count
            mutators = $mutators.Count
        }
        defaults = [pscustomobject]@{
            commander = if ($commanders.Count -gt 0) { $commanders[0].runtime } else { "" }
            map = if ($maps.Count -gt 0) { "ttosh02_7vs1.SC2Map" } else { "" }
            masteryLevel = 15
            masterySlots = @(15, 15, 15, 15, 15, 15)
            prestigeBonusMask = 7
            prestigePointIndex = -1
            enableMasteries = $true
            enablePrestiges = $true
            commanderOverrides = @()
            mutatorPreset = 0
        }
        commanders = $commanders
        maps = $maps
        mutators = $mutators
        resourcePlan = [pscustomobject]@{
            text = "指挥官 / 因子文字与协议元数据已接入"
            icons = "本地缓存真实 SC2 贴图；优先命中提取图标，缺失项回退到同主题游戏贴图"
            audio = "音效仍保留为后续目标"
        }
    }
}

function ConvertTo-LaunchArgumentList {
    param([pscustomobject]$Request)

    $commanders = @(Get-CommanderItems)
    $maps = @(Get-MapItems)
    $mutatorIds = @(Get-MutatorIdsFromLaunchScript)

    $commander = [string]$Request.commander
    $map = [string]$Request.map
    if ([string]::IsNullOrWhiteSpace($commander) -or (@($commanders | Where-Object { $_.runtime -eq $commander }).Count -eq 0)) {
        throw "Unknown commander: $commander"
    }
    $mapItem = @($maps | Where-Object { $_.id -eq $map } | Select-Object -First 1)
    if ($mapItem.Count -eq 0) {
        throw "Unknown map: $map"
    }

    $masteryLevel = [int]($Request.masteryLevel ?? 30)
    $masteries = @(30, 30, 30, 30, 30, 30)
    if ($null -ne $Request.masteries) {
        for ($i = 0; $i -lt [Math]::Min(6, $Request.masteries.Count); $i++) {
            $value = [int]$Request.masteries[$i]
            $masteries[$i] = [Math]::Max(0, [Math]::Min(30, $value))
        }
    }

    $selectedMutators = New-Object System.Collections.Generic.List[string]
    if ($null -ne $Request.mutators) {
        foreach ($mutator in @($Request.mutators)) {
            $mutatorId = [string]$mutator
            if ([string]::IsNullOrWhiteSpace($mutatorId)) {
                continue
            }
            if ($mutatorIds -notcontains $mutatorId) {
                throw "Unknown mutator: $mutatorId"
            }
            if (-not $selectedMutators.Contains($mutatorId)) {
                $selectedMutators.Add($mutatorId)
            }
        }
    }

    $enableMasteries = if ($Request.enableMasteries -eq $false) { 0 } else { 1 }
    $enablePrestiges = if ($Request.enablePrestiges -eq $false) { 0 } else { 1 }
    $prestigeBonusMask = [int]($Request.prestigeBonusMask ?? 7)
    $prestigePointIndex = [int]($Request.prestigePointIndex ?? -1)
    $mutatorPreset = [int]($Request.mutatorPreset ?? 0)
    $noLaunch = if ($Request.noLaunch -eq $true) { $true } else { $false }
    $selectedCommanderOverrides = New-Object System.Collections.Generic.List[string]
    if ($null -ne $Request.commanderOverrides) {
        foreach ($overrideEntry in @($Request.commanderOverrides)) {
            $overrideText = [string]$overrideEntry
            if ([string]::IsNullOrWhiteSpace($overrideText)) {
                continue
            }
            if ($overrideText -notmatch '^[^.]+\.[^=]+=.+$') {
                throw "Invalid commander override: $overrideText"
            }
            if (-not $selectedCommanderOverrides.Contains($overrideText)) {
                $selectedCommanderOverrides.Add($overrideText)
            }
        }
    }

    $args = New-Object System.Collections.Generic.List[string]
    foreach ($entry in @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $script:LaunchScript,
            "-MapSource", $mapItem[0].path,
            "-LiveMapName", $mapItem[0].id,
            "-Commanders", $commander,
            "-CommanderPowerMasteryLevel", [string]$masteryLevel,
            "-CommanderPowerEnableMasteries", [string]$enableMasteries,
            "-CommanderPowerEnablePrestiges", [string]$enablePrestiges,
            "-CommanderPowerPrestigeBonusMask", [string]$prestigeBonusMask,
            "-CommanderPowerPrestigePointIndex", [string]$prestigePointIndex
        )) {
        $args.Add([string]$entry)
    }

    for ($i = 0; $i -lt 6; $i++) {
        $args.Add("-CommanderPowerMastery$i")
        $args.Add([string]$masteries[$i])
    }
    foreach ($overrideText in $selectedCommanderOverrides) {
        $args.Add("-CommanderPowerOverride")
        $args.Add($overrideText)
    }
    if ($selectedMutators.Count -gt 0) {
        $args.Add("-Mutators")
        $args.Add(($selectedMutators.ToArray() -join ","))
    }
    $args.Add("-MutatorPreset")
    $args.Add([string]$mutatorPreset)
    if ($noLaunch) {
        $args.Add("-NoLaunch")
    }

    return $args.ToArray()
}

function Start-LaunchProcess {
    param([pscustomobject]$Request)

    $args = ConvertTo-LaunchArgumentList -Request $Request
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $stdout = Join-Path $script:LogsRoot "web-launcher-$stamp.out.log"
    $stderr = Join-Path $script:LogsRoot "web-launcher-$stamp.err.log"

    $process = Start-Process -FilePath "pwsh" `
        -ArgumentList $args `
        -WorkingDirectory $script:WorkspaceRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr `
        -PassThru
    $script:LaunchProcesses[[string]$process.Id] = $process

    return [pscustomobject]@{
        ok = $true
        pid = $process.Id
        startedAt = (Get-Date).ToString("o")
        stdout = $stdout
        stderr = $stderr
        arguments = $args
    }
}

function New-LaunchPreview {
    param([pscustomobject]$Request)

    $args = ConvertTo-LaunchArgumentList -Request $Request

    return [pscustomobject]@{
        ok = $true
        checkedAt = (Get-Date).ToString("o")
        executable = "pwsh"
        arguments = $args
        commandLine = "pwsh " + (($args | ForEach-Object {
                    if ($_ -match '[\s"]') {
                        '"' + ($_ -replace '"', '\"') + '"'
                    }
                    else {
                        $_
                    }
                }) -join " ")
    }
}

function Get-LogTail {
    param(
        [string]$Path,
        [int]$Tail = 80
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return ""
    }

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $logsRootFull = [System.IO.Path]::GetFullPath($script:LogsRoot)
    if (-not $fullPath.StartsWith($logsRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Log path is outside logs root: $Path"
    }

    return ((Get-Content -LiteralPath $fullPath -Encoding UTF8 -Tail $Tail -ErrorAction SilentlyContinue) -join "`n")
}

function Get-LaunchStatus {
    param([pscustomobject]$Request)

    $pidValue = [int]($Request.pid ?? 0)
    $processKey = [string]$pidValue
    $process = if ($script:LaunchProcesses.ContainsKey($processKey)) {
        $script:LaunchProcesses[$processKey]
    }
    elseif ($pidValue -gt 0) {
        Get-Process -Id $pidValue -ErrorAction SilentlyContinue
    }
    else {
        $null
    }
    $running = $false
    $exitCode = $null
    if ($null -ne $process) {
        try {
            $process.Refresh()
            $running = -not $process.HasExited
            if ($process.HasExited) {
                $exitCode = $process.ExitCode
            }
        }
        catch {
            $running = $false
        }
    }

    return [pscustomobject]@{
        ok = $true
        pid = $pidValue
        running = $running
        checkedAt = (Get-Date).ToString("o")
        exitCode = $exitCode
        stdout = [pscustomobject]@{
            path = [string]$Request.stdout
            tail = Get-LogTail -Path ([string]$Request.stdout)
        }
        stderr = [pscustomobject]@{
            path = [string]$Request.stderr
            tail = Get-LogTail -Path ([string]$Request.stderr)
        }
    }
}

function Send-Json {
    param(
        [System.Net.HttpListenerContext]$Context,
        [object]$Value,
        [int]$StatusCode = 200
    )

    $json = $Value | ConvertTo-Json -Depth 12
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = "application/json; charset=utf-8"
    $Context.Response.ContentLength64 = $bytes.Length
    $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Context.Response.OutputStream.Close()
}

function Close-ResponseQuietly {
    param([System.Net.HttpListenerContext]$Context)

    try {
        $Context.Response.OutputStream.Close()
    }
    catch {
    }
    try {
        $Context.Response.Close()
    }
    catch {
    }
}

function Send-Text {
    param(
        [System.Net.HttpListenerContext]$Context,
        [string]$Text,
        [int]$StatusCode = 200,
        [string]$ContentType = "text/plain; charset=utf-8"
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = $ContentType
    $Context.Response.ContentLength64 = $bytes.Length
    $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Context.Response.OutputStream.Close()
}

function Get-RequestJson {
    param([System.Net.HttpListenerRequest]$Request)

    $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
    try {
        $body = $reader.ReadToEnd()
    }
    finally {
        $reader.Dispose()
    }

    if ([string]::IsNullOrWhiteSpace($body)) {
        return [pscustomobject]@{}
    }

    return ($body | ConvertFrom-Json)
}

function Get-ContentType {
    param([string]$Path)

    switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        ".html" { return "text/html; charset=utf-8" }
        ".css" { return "text/css; charset=utf-8" }
        ".js" { return "application/javascript; charset=utf-8" }
        ".json" { return "application/json; charset=utf-8" }
        ".png" { return "image/png" }
        ".jpg" { return "image/jpeg" }
        ".jpeg" { return "image/jpeg" }
        ".svg" { return "image/svg+xml" }
        default { return "application/octet-stream" }
    }
}

function Send-StaticFile {
    param(
        [System.Net.HttpListenerContext]$Context,
        [string]$RawPath
    )

    $relative = [System.Uri]::UnescapeDataString($RawPath.TrimStart("/"))
    if ([string]::IsNullOrWhiteSpace($relative)) {
        $relative = "index.html"
    }
    $relative = $relative -replace '/', [System.IO.Path]::DirectorySeparatorChar
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $script:WebRoot $relative))
    $webRootFull = [System.IO.Path]::GetFullPath($script:WebRoot)
    if (-not $fullPath.StartsWith($webRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        Send-Text -Context $Context -Text "Forbidden" -StatusCode 403
        return
    }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        Send-Text -Context $Context -Text "Not found" -StatusCode 404
        return
    }

    $bytes = [System.IO.File]::ReadAllBytes($fullPath)
    $Context.Response.StatusCode = 200
    $Context.Response.ContentType = Get-ContentType $fullPath
    $Context.Response.ContentLength64 = $bytes.Length
    $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Context.Response.OutputStream.Close()
}

function Invoke-Request {
    param([System.Net.HttpListenerContext]$Context)

    $path = $Context.Request.Url.AbsolutePath
    $method = $Context.Request.HttpMethod.ToUpperInvariant()

    try {
        if ($method -eq "GET" -and $path -eq "/api/health") {
            Send-Json -Context $Context -Value ([pscustomobject]@{ ok = $true; time = (Get-Date).ToString("o") })
            return
        }
        if ($method -eq "GET" -and $path -eq "/api/bootstrap") {
            Send-Json -Context $Context -Value (Get-BootstrapData)
            return
        }
        if ($method -eq "POST" -and $path -eq "/api/launch") {
            $request = Get-RequestJson -Request $Context.Request
            Send-Json -Context $Context -Value (Start-LaunchProcess -Request $request)
            return
        }
        if ($method -eq "POST" -and $path -eq "/api/preview") {
            $request = Get-RequestJson -Request $Context.Request
            Send-Json -Context $Context -Value (New-LaunchPreview -Request $request)
            return
        }
        if ($method -eq "POST" -and $path -eq "/api/launch-status") {
            $request = Get-RequestJson -Request $Context.Request
            Send-Json -Context $Context -Value (Get-LaunchStatus -Request $request)
            return
        }
        if ($method -eq "GET") {
            Send-StaticFile -Context $Context -RawPath $path
            return
        }

        Send-Text -Context $Context -Text "Method not allowed" -StatusCode 405
    }
    catch {
        try {
            Send-Json -Context $Context -StatusCode 500 -Value ([pscustomobject]@{
                    ok = $false
                    error = $_.Exception.Message
                })
        }
        catch {
            Close-ResponseQuietly -Context $Context
        }
    }
}

if ($SelfTest) {
    Clear-StaleCommanderCache
    $bootstrap = Get-BootstrapData
    $sampleRequest = [pscustomobject]@{
        commander = $bootstrap.defaults.commander
        map = $bootstrap.defaults.map
        enablePrestiges = $true
        enableMasteries = $true
        prestigeBonusMask = 7
        prestigePointIndex = -1
        masteryLevel = 15
        masteries = @(15, 15, 15, 15, 15, 15)
        commanderOverrides = @()
        mutators = @($bootstrap.mutators | Select-Object -First 3 -ExpandProperty id)
        mutatorPreset = 0
        noLaunch = $true
    }
    $sampleArgs = ConvertTo-LaunchArgumentList -Request $sampleRequest

    [pscustomobject]@{
        ok = $true
        commanders = $bootstrap.counts.commanders
        maps = $bootstrap.counts.maps
        mutators = $bootstrap.counts.mutators
        firstCommander = @($bootstrap.commanders | Select-Object -First 1)
        firstMutator = @($bootstrap.mutators | Select-Object -First 1)
        webRoot = $script:WebRoot
        launchScript = $script:LaunchScript
        sampleArgs = $sampleArgs
    } | ConvertTo-Json -Depth 4
    return
}

Clear-StaleCommanderCache

$prefix = "http://$HostName`:$Port/"
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($prefix)
$listener.Start()

Write-Host "7vs1 Web launcher: $prefix"
Write-Host "Serving: $script:WebRoot"
Write-Host "Press Ctrl+C to stop."

if (-not $NoOpen) {
    Start-Process $prefix | Out-Null
}

try {
    while ($listener.IsListening) {
        try {
            $context = $listener.GetContext()
            Invoke-Request -Context $context
        }
        catch [System.Net.HttpListenerException] {
            if ($listener.IsListening) {
                Write-Warning $_.Exception.Message
            }
        }
        catch {
            Write-Warning $_.Exception.Message
        }
    }
}
finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
}
