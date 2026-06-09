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
$script:LogsRoot = Join-Path $script:WorkspaceRoot "logs"
$script:MutatorStringsPath = Join-Path $script:WorkspaceRoot "Mods\kit_mutations.SC2Mod\zhCN.SC2Data\LocalizedData\GameStrings.txt"
$script:MutatorsXmlPath = Join-Path $script:WorkspaceRoot "Mods\kit_mutations.SC2Mod\Base.SC2Data\GameData\Mutators.xml"
$script:LaunchProcesses = @{}

foreach ($requiredPath in @($script:LaunchScript, $script:MetadataPath, $script:MapsRoot, $script:WebRoot)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required path not found: $requiredPath"
    }
}
if (-not (Test-Path -LiteralPath $script:LogsRoot)) {
    New-Item -ItemType Directory -Path $script:LogsRoot | Out-Null
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
    $text = Get-Content -LiteralPath $script:LaunchScript -Raw -Encoding UTF8
    $match = [regex]::Match(
        $text,
        'foreach \(\$mutator in @\((?<body>.*?)\)\) \{\s*\$allowedMutators',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    if (-not $match.Success) {
        throw "Could not parse mutator allow-list from $script:LaunchScript"
    }

    return @([regex]::Matches($match.Groups["body"].Value, '"([^"]+)"') | ForEach-Object {
            $_.Groups[1].Value
        })
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
            $displayName = [string]$_.display_name
            if ([string]::IsNullOrWhiteSpace($displayName)) {
                $displayName = [string]$_.runtime_commander
            }

            [pscustomobject]@{
                runtime = [string]$_.runtime_commander
                displayName = $displayName
                bankCommander = [string]$_.bank_commander
                generatedCommander = [string]$_.generated_commander
                prestiges = @($_.prestiges | ForEach-Object {
                        [pscustomobject]@{
                            slot = [int]$_.slot
                            bitMask = [int]$_.bit_mask
                            id = [string]$_.id
                            name = [string]$_.name
                            nameEn = [string]$_.name_en
                            tooltip = ConvertFrom-SC2Text ([string]$_.tooltip)
                        }
                    })
                masteries = @($_.masteries | ForEach-Object {
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

            [pscustomobject]@{
                id = $id
                name = $name
                description = $description
                icon = $icon
                iconReady = $false
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
            mutatorPreset = 0
        }
        commanders = $commanders
        maps = $maps
        mutators = $mutators
        resourcePlan = [pscustomobject]@{
            text = "GameStrings.txt 已接入"
            icons = "当前提供 SC2 DDS 路径引用，后续转换为浏览器 PNG"
            audio = "后续从 PreloadAssetDB/assets 索引音效引用"
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
        webRoot = $script:WebRoot
        launchScript = $script:LaunchScript
        sampleArgs = $sampleArgs
    } | ConvertTo-Json -Depth 4
    return
}

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
