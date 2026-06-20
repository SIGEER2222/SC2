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
$script:MutatorsGameDataPath = Join-Path $script:WorkspaceRoot "Mods\kit_mutations.SC2Mod\Base.SC2Data\GameData.xml"
$script:MutatorsGameDataRoot = Join-Path $script:WorkspaceRoot "Mods\kit_mutations.SC2Mod\Base.SC2Data\GameData"
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
    if (-not (Test-Path -LiteralPath $script:MutatorsGameDataPath)) {
        throw "Mutators GameData entry not found: $script:MutatorsGameDataPath"
    }

    [xml]$gameData = Get-Content -LiteralPath $script:MutatorsGameDataPath -Raw -Encoding UTF8
    $paths = @($gameData.Includes.Catalog | ForEach-Object { [string]$_.path }) | Where-Object { $_ }
    if ($paths.Count -eq 0) {
        throw "No mutator catalog includes found in $script:MutatorsGameDataPath"
    }

    $ids = New-Object System.Collections.Generic.List[string]
    foreach ($relativePath in $paths) {
        $catalogPath = Join-Path $script:MutatorsGameDataRoot ($relativePath -replace '^GameData/', '')
        if (-not (Test-Path -LiteralPath $catalogPath)) {
            throw "Mutator catalog not found: $catalogPath"
        }

        [xml]$xml = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8
        foreach ($mutatorUser in @($xml.Catalog.CUser | Where-Object { $_.id -eq "Mutators" })) {
            foreach ($instance in @($mutatorUser.Instances)) {
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
        }
    }

    return $ids.ToArray()
}

function Get-MutatorIconMap {
    $map = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::OrdinalIgnoreCase)
    if (-not (Test-Path -LiteralPath $script:MutatorsGameDataPath)) {
        return $map
    }

    [xml]$gameData = Get-Content -LiteralPath $script:MutatorsGameDataPath -Raw -Encoding UTF8
    foreach ($relativePath in @($gameData.Includes.Catalog | ForEach-Object { [string]$_.path }) | Where-Object { $_ }) {
        $catalogPath = Join-Path $script:MutatorsGameDataRoot ($relativePath -replace '^GameData/', '')
        if (-not (Test-Path -LiteralPath $catalogPath)) {
            continue
        }

        [xml]$xml = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8
        $mutatorUsers = @($xml.Catalog.CUser | Where-Object { $_.id -eq "Mutators" })
        foreach ($mutatorUser in $mutatorUsers) {
            foreach ($instance in @($mutatorUser.Instances)) {
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
                                        defaultEnabled = ($(if ($null -ne $optionRecord.default) { [int]$optionRecord.default } else { 0 }) -gt 0)
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

function Get-CampaignXCoreBankPaths {
    $paths = New-Object System.Collections.Generic.List[string]

    $liveBank = Join-Path $env:USERPROFILE "Documents\StarCraft II\Banks\CampaignXCore.SC2Bank"
    if (Test-Path -LiteralPath $liveBank) {
        $paths.Add((Resolve-Path -LiteralPath $liveBank).Path)
    }

    $accountsRoot = Join-Path $env:USERPROFILE "Documents\StarCraft II\Accounts"
    if (Test-Path -LiteralPath $accountsRoot) {
        $accountBanks = Get-ChildItem -LiteralPath $accountsRoot -Recurse -File -Filter "CampaignXCore.SC2Bank" -ErrorAction SilentlyContinue |
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

function Get-BankIntValue {
    param(
        [xml]$Xml,
        [string]$SectionName,
        [string]$KeyName
    )

    $node = $Xml.SelectSingleNode("/Bank/Section[@name='$SectionName']/Key[@name='$KeyName']/Value")
    if (-not $node) {
        return $null
    }

    $raw = [string]$node.GetAttribute("int")
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }

    $parsed = 0
    if ([int]::TryParse($raw, [ref]$parsed)) {
        return $parsed
    }

    return $null
}

function Get-BankStringValue {
    param(
        [xml]$Xml,
        [string]$SectionName,
        [string]$KeyName
    )

    $node = $Xml.SelectSingleNode("/Bank/Section[@name='$SectionName']/Key[@name='$KeyName']/Value")
    if (-not $node) {
        return ""
    }

    return [string]$node.GetAttribute("string")
}

function Normalize-BankMapId {
    param([string]$MapId)

    $value = [string]$MapId
    if ([string]::IsNullOrWhiteSpace($value)) {
        return ""
    }

    $value = $value.Trim() -replace '\\', '/'
    if ($value.Contains('/')) {
        $value = ($value -split '/')[-1]
    }
    $value = $value -replace '\.SC2Map$', ''
    return $value
}

function Normalize-CommanderClearKey {
    param([string]$KeyName)

    $value = [string]$KeyName
    if ([string]::IsNullOrWhiteSpace($value)) {
        return ""
    }

    $separatorIndex = $value.IndexOf(':')
    if ($separatorIndex -lt 0) {
        return $value.Trim()
    }

    $commander = $value.Substring(0, $separatorIndex).Trim()
    $mapId = Normalize-BankMapId $value.Substring($separatorIndex + 1)
    if ([string]::IsNullOrWhiteSpace($commander) -or [string]::IsNullOrWhiteSpace($mapId)) {
        return $value.Trim()
    }

    return "${commander}:$mapId"
}

function Normalize-CommanderBonusKey {
    param([string]$KeyName)

    return (Normalize-CommanderClearKey -KeyName $KeyName)
}

function Get-UnlockedBankKeys {
    param(
        [xml]$Xml,
        [string]$SectionName,
        [scriptblock]$Normalizer = $null
    )

    $values = New-Object System.Collections.Generic.List[string]
    foreach ($key in @($Xml.SelectNodes("/Bank/Section[@name='$SectionName']/Key"))) {
        $keyName = [string]$key.GetAttribute("name")
        $value = Get-BankIntValue -Xml $Xml -SectionName $SectionName -KeyName $keyName
        if ($value -le 0) {
            continue
        }

        $normalized = if ($null -ne $Normalizer) { & $Normalizer $keyName } else { [string]$keyName }
        if (-not [string]::IsNullOrWhiteSpace($normalized)) {
            $values.Add($normalized)
        }
    }

    return @($values | Sort-Object -Unique)
}

function Get-ScoreConfig {
    return [pscustomobject]@{
        version = "2026-06-16"
        firstCommanderMapClearPoints = 3
        bonusObjectivePointValue = 1
        mutatorTierPoints = [pscustomobject]@{
            normal = 1
            medium = 2
            hard = 3
        }
        mutatorOverrides = @(
            [pscustomobject]@{ id = "Random"; points = 0; note = "随机入口不单独计分" }
            [pscustomobject]@{ id = "CycleRandom"; points = 0; note = "轮换随机不单独计分" }
        )
        genericBonusCosts = @(
            [pscustomobject]@{ id = "DoubleMinerals"; costMode = "perLevel"; costPerLevel = 1; label = "矿物储量倍率" }
            [pscustomobject]@{ id = "DoubleVespene"; costMode = "perLevel"; costPerLevel = 1; label = "瓦斯储量倍率" }
            [pscustomobject]@{ id = "RichResources"; costMode = "fixed"; cost = 2; label = "高产矿脉与瓦斯" }
            [pscustomobject]@{ id = "GuardianShell"; costMode = "fixed"; cost = 2; label = "守护者之壳" }
            [pscustomobject]@{ id = "CreepRegeneration"; costMode = "fixed"; cost = 1; label = "菌毯回血" }
            [pscustomobject]@{ id = "MechanicalRepair"; costMode = "fixed"; cost = 1; label = "机械维修" }
            [pscustomobject]@{ id = "ChronoBoost"; costMode = "fixed"; cost = 2; label = "时空加速" }
            [pscustomobject]@{ id = "AbathurBiomassDrop"; costMode = "fixed"; cost = 2; label = "生物质掉落" }
            [pscustomobject]@{ id = "AllyEarlyDamageReduction"; costMode = "fixed"; cost = 2; label = "盟友开局减伤" }
            [pscustomobject]@{ id = "AllySustainBoost"; costMode = "fixed"; cost = 3; label = "盟友持续强化" }
            [pscustomobject]@{ id = "MaxSupply50"; costMode = "fixed"; cost = 1; label = "人口上限+50" }
            [pscustomobject]@{ id = "ZeroSupply"; costMode = "fixed"; cost = 3; label = "单位0人口" }
        )
    }
}

function Get-CompletionPointLedger {
    param([pscustomobject]$Completion)

    $scoreConfig = Get-ScoreConfig
    $commanderClearCount = @($Completion.commanderClearKeys).Count
    $commanderBonusPoints = (@($Completion.commanderBonusScores) | Measure-Object -Property bonusScore -Sum).Sum
    if ($null -eq $commanderBonusPoints) {
        $commanderBonusPoints = 0
    }
    $objectiveCompletedCount = @($Completion.objectiveStates | Where-Object { $_.state -eq 2 }).Count
    $clearPoints = $commanderClearCount * [int]$scoreConfig.firstCommanderMapClearPoints
    $bonusCompletionCount = [Math]::Max([int]$commanderBonusPoints, [int]$objectiveCompletedCount)
    $bonusPoints = $bonusCompletionCount * [int]$scoreConfig.bonusObjectivePointValue

    return [pscustomobject]@{
        firstClearCount = $commanderClearCount
        firstClearPoints = $clearPoints
        bonusObjectiveCount = $bonusCompletionCount
        bonusObjectivePoints = $bonusPoints
        earnedPoints = $clearPoints + $bonusPoints
        objectiveStateSource = if (@($Completion.objectiveStates).Count -gt 0) { "ObjectiveState" } else { "CommanderBonus" }
    }
}

function Get-MutatorScorePoints {
    param([string]$Id)

    $scoreConfig = Get-ScoreConfig
    $override = @($scoreConfig.mutatorOverrides | Where-Object { $_.id -eq $Id } | Select-Object -First 1)
    if ($override.Count -gt 0) {
        return [int]$override[0].points
    }

    $class = Get-MutatorClass -Id $Id
    switch ([string]$class.tier) {
        "hard" { return [int]$scoreConfig.mutatorTierPoints.hard }
        "medium" { return [int]$scoreConfig.mutatorTierPoints.medium }
        default { return [int]$scoreConfig.mutatorTierPoints.normal }
    }
}

function Get-GenericBonusScoreCost {
    param(
        [string]$Id,
        [int]$Level = 0
    )

    $scoreConfig = Get-ScoreConfig
    $rule = @($scoreConfig.genericBonusCosts | Where-Object { $_.id -eq $Id } | Select-Object -First 1)
    if ($rule.Count -eq 0) {
        return 0
    }

    if ([string]$rule[0].costMode -eq "perLevel") {
        return [Math]::Max(0, [int]$Level) * [Math]::Max(0, [int]$rule[0].costPerLevel)
    }

    return [Math]::Max(0, [int]$rule[0].cost)
}

function Get-ObjectiveStateRecord {
    param(
        [string]$KeyName,
        [int]$State
    )

    $value = [string]$KeyName
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $null
    }

    if ($value.StartsWith("ObjectiveState/")) {
        $value = $value.Substring("ObjectiveState/".Length)
    }

    $parts = $value.Split(":", 4)
    if ($parts.Count -lt 4) {
        return $null
    }

    $commander = $parts[0].Trim()
    $mapId = Normalize-BankMapId $parts[1]
    $objectiveType = $parts[2].Trim()
    $objectiveIndex = 0
    if (-not [int]::TryParse($parts[3], [ref]$objectiveIndex)) {
        return $null
    }
    if ([string]::IsNullOrWhiteSpace($commander) -or [string]::IsNullOrWhiteSpace($mapId)) {
        return $null
    }

    return [pscustomobject]@{
        key = "${commander}:${mapId}:${objectiveType}:${objectiveIndex}"
        commander = $commander
        mapId = $mapId
        objectiveType = $objectiveType
        objectiveIndex = $objectiveIndex
        state = $State
    }
}

function Get-CompletionSnapshot {
    $bankPaths = @(Get-CampaignXCoreBankPaths)
    if ($bankPaths.Count -eq 0) {
        $completion = [pscustomobject]@{
            bankFound = $false
            bankPath = ""
            bankLastWriteTime = $null
            lastMap = ""
            lastCommander = ""
            mapClearIds = @()
            commanderClearKeys = @()
            mapBonusScores = @()
            commanderBonusScores = @()
            objectiveStates = @()
            unlockedBonuses = @()
            unlockedPrestiges = @()
            totalWins = 0
            lastClearTime = $null
        }
        $completion | Add-Member -NotePropertyName pointLedger -NotePropertyValue (Get-CompletionPointLedger -Completion $completion)
        return $completion
    }

    $mapClearIds = New-Object System.Collections.Generic.List[string]
    $commanderClearKeys = New-Object System.Collections.Generic.List[string]
    $mapBonusScores = New-Object 'System.Collections.Generic.Dictionary[string,int]' -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)
    $commanderBonusScores = New-Object 'System.Collections.Generic.Dictionary[string,int]' -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)
    $objectiveStateMap = New-Object 'System.Collections.Generic.Dictionary[string,object]' -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)
    $unlockedBonuses = New-Object System.Collections.Generic.List[string]
    $unlockedPrestiges = New-Object System.Collections.Generic.List[string]
    $selectedBankPath = ""
    $selectedBankWriteTime = $null
    $lastMap = ""
    $lastCommander = ""
    $lastClearTime = $null
    $totalWins = 0

    foreach ($bankPath in $bankPaths) {
        [xml]$xml = Get-Content -LiteralPath $bankPath -Raw -Encoding UTF8
        $bankItem = Get-Item -LiteralPath $bankPath
        if (($null -eq $selectedBankWriteTime) -or ($bankItem.LastWriteTime -gt $selectedBankWriteTime)) {
            $selectedBankPath = $bankPath
            $selectedBankWriteTime = $bankItem.LastWriteTime
            $lastMap = Get-BankStringValue -Xml $xml -SectionName "Progression" -KeyName "LastMap"
            $lastCommander = Get-BankStringValue -Xml $xml -SectionName "Progression" -KeyName "LastCommander"
            $lastClearTime = Get-BankIntValue -Xml $xml -SectionName "Progression" -KeyName "LastClearTime"
            $latestTotalWins = Get-BankIntValue -Xml $xml -SectionName "Progression" -KeyName "TotalWins"
            if ($latestTotalWins -gt $totalWins) {
                $totalWins = $latestTotalWins
            }
        }

        foreach ($sectionName in @("MapClear", "Finished")) {
            foreach ($key in @($xml.SelectNodes("/Bank/Section[@name='$sectionName']/Key"))) {
                $keyName = [string]$key.GetAttribute("name")
                $value = Get-BankIntValue -Xml $xml -SectionName $sectionName -KeyName $keyName
                $normalizedMapId = Normalize-BankMapId $keyName
                if (($value -gt 0) -and -not [string]::IsNullOrWhiteSpace($normalizedMapId)) {
                    $mapClearIds.Add($normalizedMapId)
                }
            }
        }

        foreach ($key in @($xml.SelectNodes("/Bank/Section[@name='CommanderClear']/Key"))) {
            $keyName = [string]$key.GetAttribute("name")
            $value = Get-BankIntValue -Xml $xml -SectionName "CommanderClear" -KeyName $keyName
            $normalizedKey = Normalize-CommanderClearKey $keyName
            if (($value -gt 0) -and -not [string]::IsNullOrWhiteSpace($normalizedKey)) {
                $commanderClearKeys.Add($normalizedKey)
            }
        }

        foreach ($key in @($xml.SelectNodes("/Bank/Section[@name='Bon']/Key"))) {
            $keyName = [string]$key.GetAttribute("name")
            $value = Get-BankIntValue -Xml $xml -SectionName "Bon" -KeyName $keyName
            $normalizedMapId = Normalize-BankMapId $keyName
            if (($value -gt 0) -and -not [string]::IsNullOrWhiteSpace($normalizedMapId)) {
                if (-not $mapBonusScores.ContainsKey($normalizedMapId) -or $value -gt $mapBonusScores[$normalizedMapId]) {
                    $mapBonusScores[$normalizedMapId] = $value
                }
            }
        }

        foreach ($key in @($xml.SelectNodes("/Bank/Section[@name='CommanderBonus']/Key"))) {
            $keyName = [string]$key.GetAttribute("name")
            $value = Get-BankIntValue -Xml $xml -SectionName "CommanderBonus" -KeyName $keyName
            $normalizedKey = Normalize-CommanderBonusKey $keyName
            if (($value -gt 0) -and -not [string]::IsNullOrWhiteSpace($normalizedKey)) {
                if (-not $commanderBonusScores.ContainsKey($normalizedKey) -or $value -gt $commanderBonusScores[$normalizedKey]) {
                    $commanderBonusScores[$normalizedKey] = $value
                }
            }
        }

        foreach ($key in @($xml.SelectNodes("/Bank/Section[@name='Progression']/Key"))) {
            $keyName = [string]$key.GetAttribute("name")
            if (-not $keyName.StartsWith("ObjectiveState")) {
                continue
            }

            $value = Get-BankIntValue -Xml $xml -SectionName "Progression" -KeyName $keyName
            if ($value -le 0) {
                continue
            }

            $record = Get-ObjectiveStateRecord -KeyName $keyName -State $value
            if ($null -ne $record) {
                $objectiveStateMap[$record.key] = $record
            }
        }

        foreach ($entry in @(Get-UnlockedBankKeys -Xml $xml -SectionName "UnlockedBonus")) {
            $unlockedBonuses.Add($entry)
        }

        foreach ($entry in @(Get-UnlockedBankKeys -Xml $xml -SectionName "UnlockedPrestige" -Normalizer { param($v) Normalize-CommanderClearKey -KeyName $v })) {
            $unlockedPrestiges.Add($entry)
        }
    }

    $completion = [pscustomobject]@{
        bankFound = $true
        bankPath = $selectedBankPath
        bankLastWriteTime = if ($selectedBankWriteTime) { $selectedBankWriteTime.ToString("o") } else { $null }
        lastMap = Normalize-BankMapId $lastMap
        lastCommander = $lastCommander
        totalWins = [int]$totalWins
        lastClearTime = if ($lastClearTime -gt 0) { [int]$lastClearTime } else { $null }
        mapClearIds = @($mapClearIds | Sort-Object -Unique)
        commanderClearKeys = @($commanderClearKeys | Sort-Object -Unique)
        mapBonusScores = @($mapBonusScores.GetEnumerator() | Sort-Object Name | ForEach-Object {
                [pscustomobject]@{
                    mapId = $_.Name
                    bonusScore = [int]$_.Value
                }
            })
        commanderBonusScores = @($commanderBonusScores.GetEnumerator() | Sort-Object Name | ForEach-Object {
                $parts = $_.Name.Split(":", 2)
                [pscustomobject]@{
                    key = $_.Name
                    commander = if ($parts.Count -gt 0) { $parts[0] } else { "" }
                    mapId = if ($parts.Count -gt 1) { $parts[1] } else { "" }
                    bonusScore = [int]$_.Value
                }
            })
        objectiveStates = @($objectiveStateMap.Values | Sort-Object key)
        unlockedBonuses = @($unlockedBonuses | Sort-Object -Unique)
        unlockedPrestiges = @($unlockedPrestiges | Sort-Object -Unique)
    }
    $completion | Add-Member -NotePropertyName pointLedger -NotePropertyValue (Get-CompletionPointLedger -Completion $completion)
    return $completion
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

function Get-LaunchScoreSummary {
    param([pscustomobject]$Request)

    $completion = Get-CompletionSnapshot
    $ledger = $completion.pointLedger
    $selectedMutators = @($Request.mutators) | Sort-Object -Unique
    $mutatorBreakdown = @($selectedMutators | ForEach-Object {
            [pscustomobject]@{
                id = [string]$_
                points = Get-MutatorScorePoints -Id ([string]$_)
            }
        })
    $mutatorPoints = (@($mutatorBreakdown) | Measure-Object -Property points -Sum).Sum
    if ($null -eq $mutatorPoints) {
        $mutatorPoints = 0
    }

    $selectedBonusIds = @($Request.genericBonuses) | Sort-Object -Unique
    $genericBonusLevels = $Request.genericBonusLevels
    $bonusBreakdown = @($selectedBonusIds | ForEach-Object {
            $bonusId = [string]$_
            $level = 0
            if ($null -ne $genericBonusLevels) {
                if ($genericBonusLevels -is [System.Collections.IDictionary]) {
                    if ($genericBonusLevels.Contains($bonusId)) {
                        $level = [int]$genericBonusLevels[$bonusId]
                    }
                }
                elseif ($genericBonusLevels.PSObject.Properties.Name -contains $bonusId) {
                    $level = [int]$genericBonusLevels.$bonusId
                }
            }

            [pscustomobject]@{
                id = $bonusId
                level = $level
                cost = Get-GenericBonusScoreCost -Id $bonusId -Level $level
            }
        })
    $bonusCost = (@($bonusBreakdown) | Measure-Object -Property cost -Sum).Sum
    if ($null -eq $bonusCost) {
        $bonusCost = 0
    }

    return [pscustomobject]@{
        completion = $completion
        earnedPoints = [int]$ledger.earnedPoints
        earnedBreakdown = $ledger
        mutatorPoints = [int]$mutatorPoints
        bonusCost = [int]$bonusCost
        balanceAfterSelection = [int]$ledger.earnedPoints + [int]$mutatorPoints - [int]$bonusCost
        mutatorBreakdown = $mutatorBreakdown
        bonusBreakdown = $bonusBreakdown
    }
}

function Get-BootstrapData {
    $commanders = @(Get-CommanderItems)
    $maps = @(Get-MapItems)
    $mutators = @(Get-MutatorItems)
    $completion = Get-CompletionSnapshot

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
            genericBonuses = @()
            genericBonusLevels = @{}
            mutatorPreset = 0
        }
        commanders = $commanders
        maps = $maps
        mutators = $mutators
        completion = $completion
        scoreSystem = Get-ScoreConfig
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

    $masteryLevel = if ($null -ne $Request.masteryLevel) { [int]$Request.masteryLevel } else { 30 }
    $masteries = @(30, 30, 30, 30, 30, 30)
    if ($null -ne $Request.masteries) {
        for ($i = 0; $i -lt [Math]::Min(6, $Request.masteries.Count); $i++) {
            $value = [int]$Request.masteries[$i]
            $masteries[$i] = [Math]::Max(0, [Math]::Min(30, $value))
        }
    }

    $selectedMutators = New-Object System.Collections.Generic.List[string]
    $allowedGenericBonuses = @(
        "DoubleMinerals",
        "DoubleVespene",
        "RichResources",
        "GuardianShell",
        "CreepRegeneration",
        "MechanicalRepair",
        "ChronoBoost",
        "AbathurBiomassDrop",
        "AllyEarlyDamageReduction",
        "AllySustainBoost",
        "MaxSupply50",
        "ZeroSupply"
    )
    $levelableGenericBonuses = @("DoubleMinerals", "DoubleVespene")
    $selectedGenericBonuses = New-Object System.Collections.Generic.List[string]
    $selectedGenericBonusLevels = New-Object 'System.Collections.Generic.Dictionary[string,int]' -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)
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
    if ($null -ne $Request.genericBonuses) {
        foreach ($bonus in @($Request.genericBonuses)) {
            $bonusId = [string]$bonus
            if ([string]::IsNullOrWhiteSpace($bonusId)) {
                continue
            }
            if ($allowedGenericBonuses -notcontains $bonusId) {
                throw "Unknown generic bonus: $bonusId"
            }
            if (-not $selectedGenericBonuses.Contains($bonusId)) {
                $selectedGenericBonuses.Add($bonusId)
            }
        }
    }
    if ($null -ne $Request.genericBonusLevels) {
        $levelEntries = @()
        if ($Request.genericBonusLevels -is [System.Collections.IDictionary]) {
            foreach ($bonusKey in $Request.genericBonusLevels.Keys) {
                $levelEntries += [pscustomobject]@{
                    Name = [string]$bonusKey
                    Value = $Request.genericBonusLevels[$bonusKey]
                }
            }
        }
        else {
            $levelEntries = @($Request.genericBonusLevels.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' })
        }
        foreach ($property in $levelEntries) {
            $bonusId = [string]$property.Name
            if ([string]::IsNullOrWhiteSpace($bonusId)) {
                continue
            }
            if ($allowedGenericBonuses -notcontains $bonusId) {
                throw "Unknown generic bonus level target: $bonusId"
            }
            if ($levelableGenericBonuses -notcontains $bonusId) {
                throw "Generic bonus '$bonusId' does not support levels."
            }
            $level = [Math]::Max(0, [Math]::Min(9, [int]$property.Value))
            if ($level -gt 0) {
                $selectedGenericBonusLevels[$bonusId] = $level
                if (-not $selectedGenericBonuses.Contains($bonusId)) {
                    $selectedGenericBonuses.Add($bonusId)
                }
            }
            elseif ($selectedGenericBonusLevels.ContainsKey($bonusId)) {
                $selectedGenericBonusLevels.Remove($bonusId) | Out-Null
            }
        }
    }
    foreach ($bonusId in $levelableGenericBonuses) {
        if ($selectedGenericBonuses.Contains($bonusId) -and (-not $selectedGenericBonusLevels.ContainsKey($bonusId))) {
            $selectedGenericBonusLevels[$bonusId] = 1
        }
    }

    $normalizedScoreRequest = [pscustomobject]@{
        commander = $commander
        map = $map
        mutators = $selectedMutators.ToArray()
        genericBonuses = $selectedGenericBonuses.ToArray()
        genericBonusLevels = [pscustomobject]@{}
    }
    foreach ($bonusId in $selectedGenericBonusLevels.Keys) {
        $normalizedScoreRequest.genericBonusLevels | Add-Member -NotePropertyName $bonusId -NotePropertyValue ([int]$selectedGenericBonusLevels[$bonusId])
    }
    $scoreSummary = Get-LaunchScoreSummary -Request $normalizedScoreRequest

    $enableMasteries = if ($Request.enableMasteries -eq $false) { 0 } else { 1 }
    $enablePrestiges = if ($Request.enablePrestiges -eq $false) { 0 } else { 1 }
    $prestigeBonusMask = if ($null -ne $Request.prestigeBonusMask) { [int]$Request.prestigeBonusMask } else { 7 }
    $prestigePointIndex = if ($null -ne $Request.prestigePointIndex) { [int]$Request.prestigePointIndex } else { -1 }
    $mutatorPreset = if ($null -ne $Request.mutatorPreset) { [int]$Request.mutatorPreset } else { 0 }
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
    if ($selectedGenericBonuses.Count -gt 0) {
        $args.Add("-GenericBonuses")
        $serializedGenericBonuses = foreach ($bonusId in $selectedGenericBonuses) {
            if ($selectedGenericBonusLevels.ContainsKey($bonusId)) {
                "{0}={1}" -f $bonusId, $selectedGenericBonusLevels[$bonusId]
            }
            else {
                $bonusId
            }
        }
        $args.Add(($serializedGenericBonuses -join ","))
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
    $scoreSummary = Get-LaunchScoreSummary -Request $Request
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
        score = $scoreSummary
    }
}

function New-LaunchPreview {
    param([pscustomobject]$Request)

    $args = ConvertTo-LaunchArgumentList -Request $Request
    $scoreSummary = Get-LaunchScoreSummary -Request $Request

    return [pscustomobject]@{
        ok = $true
        checkedAt = (Get-Date).ToString("o")
        executable = "pwsh"
        arguments = $args
        score = $scoreSummary
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

    $pidValue = if ($null -ne $Request.pid) { [int]$Request.pid } else { 0 }
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

