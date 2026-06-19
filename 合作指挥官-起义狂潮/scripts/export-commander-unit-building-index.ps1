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
            Add-SetValue -Set $tokens -Value "SI"
        }
        "Fenix" {
            Add-SetValue -Set $tokens -Value "Purifier"
        }
        "Dehaka" {
            Add-SetValue -Set $tokens -Value "Primal"
        }
    }

    return @($tokens | Sort-Object)
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

    if (Test-IsStructureUnit -UnitIndex $UnitIndex -UnitId $UnitId) {
        return "Building"
    }

    $editorCategories = Get-EffectiveUnitValue -UnitIndex $UnitIndex -UnitId $UnitId -ChildName "EditorCategories"
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
    if ($UnitId -match "^CoopCaster|^CoopAssistCaster") {
        $tags.Add("TopBarCaster") | Out-Null
    }

    return (@($tags | Select-Object -Unique) -join ", ")
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
        [string]$UnitId,
        [System.Collections.Generic.HashSet[string]]$Visited = $null
    )

    if ([string]::IsNullOrWhiteSpace($UnitId)) {
        return ""
    }

    if (($null -ne $LocalizedNames) -and $LocalizedNames.Unit.ContainsKey($UnitId)) {
        return [string]$LocalizedNames.Unit[$UnitId]
    }

    if (($null -ne $LocalizedNames) -and $LocalizedNames.ArmyCategory.ContainsKey($UnitId)) {
        return [string]$LocalizedNames.ArmyCategory[$UnitId]
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
            $localizedAlias = Get-LocalizedUnitName -LocalizedNames $LocalizedNames -UnitIndex $UnitIndex -UnitId $aliasValue -Visited $Visited
            if (-not [string]::IsNullOrWhiteSpace($localizedAlias)) {
                return $localizedAlias
            }
        }
    }

    $localizedParent = Get-LocalizedUnitName -LocalizedNames $LocalizedNames -UnitIndex $UnitIndex -UnitId $record.Parent -Visited $Visited
    if (-not [string]::IsNullOrWhiteSpace($localizedParent)) {
        return $localizedParent
    }

    foreach ($buttonFace in @($record.Node.SelectNodes('CardLayouts/LayoutButtons[@Face]'))) {
        $face = [string]$buttonFace.Face
        if (($null -ne $LocalizedNames) -and (-not [string]::IsNullOrWhiteSpace($face)) -and $LocalizedNames.Button.ContainsKey($face)) {
            return [string]$LocalizedNames.Button[$face]
        }
    }

    return ""
}

function Get-CommanderUnitRows {
    param(
        $CommanderRecord,
        [hashtable]$UnitIndex,
        [hashtable]$LocalizedNames
    )

    $rows = New-Object System.Collections.Generic.List[object]
    $seen = New-StringSet
    $dedicatedFile = "UnitData_{0}.xml" -f [string]$CommanderRecord.official_short_id
    $tokens = @(Get-CommanderMatchTokens -CommanderRecord $CommanderRecord)

    foreach ($record in $UnitIndex.Values) {
        $include = $false
        if (@($record.Sources) -contains $dedicatedFile) {
            $include = $true
        }
        else {
            $leaderAlias = Get-EffectiveUnitValue -UnitIndex $UnitIndex -UnitId $record.Id -ChildName "LeaderAlias"
            foreach ($token in $tokens) {
                if ($record.Id -like "*$token*") {
                    $include = $true
                    break
                }
                if ((-not [string]::IsNullOrWhiteSpace($leaderAlias)) -and $leaderAlias.Equals($token, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $include = $true
                    break
                }
            }
        }

        if ((-not $include) -or (-not $seen.Add($record.Id))) {
            continue
        }

        $rows.Add([pscustomobject]@{
                Id = $record.Id
                NameZhCN = Get-LocalizedUnitName -LocalizedNames $LocalizedNames -UnitIndex $UnitIndex -UnitId $record.Id
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
$unitPaths = @(Get-CatalogXmlPaths -GameDataRoot $gameDataRoot -BaseName "UnitData")
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
            $unitIndex[$id].Parent = [string]$node.parent
            $unitIndex[$id].Node = $node
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
$lines.Add("Rule: prefer commander-specific `UnitData_<Commander>.xml` entries, then supplement with shared-file units that carry commander-specific IDs or leader aliases.") | Out-Null
$lines.Add("") | Out-Null

foreach ($shortId in (Get-CommanderOrder)) {
    if (-not $commandersByShortId.ContainsKey($shortId)) {
        continue
    }

    $commander = $commandersByShortId[$shortId]
    $localizedPaths = Get-LocalizedNameFileCandidates -WorkspaceRoot $workspaceRoot -CommanderShortId $shortId
    $localizedNames = Import-LocalizedUnitNames -Paths $localizedPaths
    $rows = @(Get-CommanderUnitRows -CommanderRecord $commander -UnitIndex $unitIndex -LocalizedNames $localizedNames)
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
