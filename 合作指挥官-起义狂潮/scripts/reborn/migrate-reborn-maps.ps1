<#
.SYNOPSIS
  Reborn 地图批量迁移工具
  将源包 Reborn 地图复制为 _reborn_port 后缀的可运行地图，并生成对应 MapProfile。

.DESCRIPTION
  工作流程：
  1. 遍历内置的 29 张 Reborn 地图清单（排除已迁移的 zexpedition03）
  2. 将源地图目录复制为 <name>_reborn_port.SC2Map 到目标目录
  3. 不修改 DocumentHeader（启动器 launch-reborn-commander.ps1 会在运行时重写依赖）
  4. 不修改 MapScript.galaxy（保持原生战役初始化逻辑）
  5. 为每张地图生成 MapProfile：Mods/Reborn/MapProfiles/<name>.json
     - 基于 zexpedition03.json 模板结构
     - commanderSlots[0].commanderId = null（运行时由启动器选择）
  6. 生成迁移报告：out/migration-report-<timestamp>.json

  脚本内部的 Copy-Item / robocopy 属于脚本逻辑（由用户运行），非 AI 直接执行仓库写入。

.PARAMETER SourceRoot
  源地图根目录。默认为 source-manifest.json 中的 sourceRoot。

.PARAMETER TargetDir
  目标地图目录，默认为 <项目根>/Maps/。

.PARAMETER Maps
  逗号分隔的地图名列表，仅迁移指定地图。不指定则迁移全部 29 张。
  示例：-Maps "zchar01,zchar02,zstorychar"

.PARAMETER DryRun
  仅输出迁移计划，不实际复制文件或写入 MapProfile。

.PARAMETER Force
  目标地图或 MapProfile 已存在时强制覆盖。默认跳过已存在文件。

.EXAMPLE
  # 查看迁移计划（不写入）
  .\migrate-reborn-maps.ps1 -DryRun

.EXAMPLE
  # 迁移全部 29 张地图
  .\migrate-reborn-maps.ps1

.EXAMPLE
  # 仅迁移指定地图，强制覆盖
  .\migrate-reborn-maps.ps1 -Maps "zchar01,zchar02" -Force
#>
param(
    [string]$SourceRoot = "",
    [string]$TargetDir = "",
    [string]$Maps = "",
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# ==============================================================================
# 路径解析
# ==============================================================================
$ScriptsRoot = Split-Path $PSScriptRoot -Parent        # scripts/
$ProjRoot    = Split-Path $ScriptsRoot -Parent          # 合作指挥官-起义狂潮/
$MapProfileDir = Join-Path $ProjRoot "Mods\Reborn\MapProfiles"
$OutDir      = Join-Path $ProjRoot "out"

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    # 默认源根目录（与 source-manifest.json 一致）
    $SourceRoot = "C:\Users\22448\Downloads\重生虫心0.71汉化版（新） (2)\reborn"
}
if ([string]::IsNullOrWhiteSpace($TargetDir)) {
    $TargetDir = Join-Path $ProjRoot "Maps"
}

# ==============================================================================
# 内置地图清单（29 张，排除已迁移的 zexpedition03）
# subfolder: 源地图在 SourceRoot 下的相对子目录（evolution 地图位于 evolution/ 子目录）
# mapId: MapProfile 中的 mapId 字段（PascalCase，去除前导零）
# displayName: MapProfile 中的 mapName 字段
# ==============================================================================
function Get-RebornMapCatalog {
    # 返回有序数组，每项包含 name, mapId, displayName, subfolder
    $catalog = @(
        # 剧情枢纽图（6张）
        @{ name = "zstorychar";        mapId = "ZStoryChar";           displayName = "Story - Char";          subfolder = "" },
        @{ name = "zstoryexpedition";  mapId = "ZStoryExpedition";     displayName = "Story - Expedition";    subfolder = "" },
        @{ name = "zstoryhybrid";      mapId = "ZStoryHybrid";         displayName = "Story - Hybrid";        subfolder = "" },
        @{ name = "zstorykorhal";      mapId = "ZStoryKorhal";         displayName = "Story - Korhal";        subfolder = "" },
        @{ name = "zstoryspace";       mapId = "ZStorySpace";          displayName = "Story - Space";         subfolder = "" },
        @{ name = "zstoryzerus";       mapId = "ZStoryZerus";          displayName = "Story - Zerus";         subfolder = "" },

        # 任务图（18张）
        @{ name = "zchar01";           mapId = "ZChar1";               displayName = "Char 1 - Domination";           subfolder = "" },
        @{ name = "zchar02";           mapId = "ZChar2";               displayName = "Char 2 - Fire in the Sky";      subfolder = "" },
        @{ name = "zchar03";           mapId = "ZChar3";               displayName = "Char 3 - Old Soldiers";         subfolder = "" },
        @{ name = "zexpedition01";     mapId = "ZExpedition1";         displayName = "Expedition 1 - Lost Soldier";   subfolder = "" },
        @{ name = "zexpedition02";     mapId = "ZExpedition2";         displayName = "Expedition 2 - Secret Cargo";   subfolder = "" },
        @{ name = "zhybrid01";         mapId = "ZHybrid1";             displayName = "Hybrid 1 - Infested";           subfolder = "" },
        @{ name = "zhybrid02";         mapId = "ZHybrid2";             displayName = "Hybrid 2 - Enemy Within";       subfolder = "" },
        @{ name = "zhybrid03";         mapId = "ZHybrid3";             displayName = "Hybrid 3 - Hand of Darkness";   subfolder = "" },
        @{ name = "zkorhal01";         mapId = "ZKorhal1";             displayName = "Korhal 1 - The Reckoning";      subfolder = "" },
        @{ name = "zkorhal02";         mapId = "ZKorhal2";             displayName = "Korhal 2 - True Colors";        subfolder = "" },
        @{ name = "zkorhal03";         mapId = "ZKorhal3";             displayName = "Korhal 3 - The Reckoning";      subfolder = "" },
        @{ name = "zlab01";            mapId = "ZLab1";                displayName = "Lab 1 - Lab Rat";               subfolder = "" },
        @{ name = "zlab02";            mapId = "ZLab2";                displayName = "Lab 2 - Echoes of the Future";  subfolder = "" },
        @{ name = "zlab03";            mapId = "ZLab3";                displayName = "Lab 3 - Supreme";               subfolder = "" },
        @{ name = "zspace01";          mapId = "ZSpace1";              displayName = "Space 1 - Waking the Ancient";  subfolder = "" },
        @{ name = "zspace02";          mapId = "ZSpace2";              displayName = "Space 2 - The Crucible";        subfolder = "" },
        @{ name = "zzerus01";          mapId = "ZZerus1";              displayName = "Zerus 1 - The Forgotten";       subfolder = "" },
        @{ name = "zzerus02";          mapId = "ZZerus2";              displayName = "Zerus 2 - The Path of Ascension"; subfolder = "" },
        @{ name = "zzerus03";          mapId = "ZZerus3";              displayName = "Zerus 3 - Supreme";             subfolder = "" },

        # 进化图（4张，源地图位于 evolution/ 子目录）
        @{ name = "zevolutionbaneling2"; mapId = "ZEvolutionBaneling2";  displayName = "Evolution - Baneling";   subfolder = "evolution" },
        @{ name = "zevolutionhydralisk"; mapId = "ZEvolutionHydralisk";  displayName = "Evolution - Hydralisk";  subfolder = "evolution" },
        @{ name = "zevolutionroach";     mapId = "ZEvolutionRoach";      displayName = "Evolution - Roach";      subfolder = "evolution" },
        @{ name = "zevolutionzergling";  mapId = "ZEvolutionZergling";   displayName = "Evolution - Zergling";   subfolder = "evolution" }
    )
    return $catalog
}

# ==============================================================================
# MapProfile 模板生成函数
# 基于 zexpedition03.json 结构，确保所有 MapProfile 字段一致
# ==============================================================================
function New-MapProfileObject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MapId,
        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    # 使用有序 PSCustomObject 保证 JSON 键顺序与模板一致
    # 键顺序：schemaVersion, mapFamily, mapId, mapName, mapAdapter, entryType,
    #         commanderSlots, pairPatches, requiredDependencies, bankProtection,
    #         victoryCondition, defeatCondition
    $profile = [ordered]@{
        schemaVersion = 1
        mapFamily     = "RebornHotS"
        mapId         = $MapId
        mapName       = $DisplayName
        mapAdapter    = "reborn"
        entryType     = "direct"
        commanderSlots = @(
            [ordered]@{
                slotIndex           = 0
                playerId            = 1
                commanderId         = $null
                allowRuntimeOverride = $true
                startPosition       = "default"
            }
        )
        pairPatches = @()
        requiredDependencies = [ordered]@{
            always = @(
                "file:Mods/crys_the_swarm_reborn.SC2Mod",
                "file:Mods/Reborn/RebornBridge.SC2Mod",
                "file:Mods/Reborn/RebornMapAdapter.SC2Mod"
            )
        }
        bankProtection = [ordered]@{
            protectedBanks = @(
                "cryswarmcoop",
                "ZCampaign",
                "ZCampaignStats",
                "ZStory",
                "ZArmy",
                "TCampaign"
            )
            playerBanks = [ordered]@{
                "1" = "cryswarmcoop"
            }
        }
        victoryCondition = [ordered]@{
            type    = "native"
            trigger = "libRebornAdapter_TriggerVictory"
        }
        defeatCondition = [ordered]@{
            type    = "native"
            trigger = "libRebornAdapter_TriggerDefeat"
        }
    }

    return [PSCustomObject]$profile
}

# ==============================================================================
# 写入 MapProfile JSON 文件
# 使用 ConvertTo-Json 序列化，UTF-8 无 BOM 编码
# ==============================================================================
function Write-MapProfileJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Profile
    )

    $json = $Profile | ConvertTo-Json -Depth 10
    # UTF-8 无 BOM，与现有 zexpedition03.json 保持一致
    [System.IO.File]::WriteAllText($OutputPath, $json, [System.Text.UTF8Encoding]::new($false))
}

# ==============================================================================
# 单张地图迁移
# ==============================================================================
function Invoke-SingleMapMigration {
    param(
        [Parameter(Mandatory = $true)]
        $MapEntry,
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,
        [Parameter(Mandatory = $true)]
        [string]$TargetMapDir,
        [Parameter(Mandatory = $true)]
        [string]$TargetProfileDir,
        [switch]$DryRun,
        [switch]$Force
    )

    $name = $MapEntry.name
    $sourceMapName = "$name.SC2Map"
    $targetMapName = "${name}_reborn_port.SC2Map"

    # 源路径（处理 evolution 子目录）
    if ([string]::IsNullOrEmpty($MapEntry.subfolder)) {
        $sourceMapPath = Join-Path $SourceRoot $sourceMapName
    } else {
        $sourceMapPath = Join-Path (Join-Path $SourceRoot $MapEntry.subfolder) $sourceMapName
    }
    $targetMapPath = Join-Path $TargetMapDir $targetMapName
    $targetProfilePath = Join-Path $TargetProfileDir "$name.json"

    $result = [ordered]@{
        name           = $name
        mapId          = $MapEntry.mapId
        displayName    = $MapEntry.displayName
        sourceMapPath  = $sourceMapPath
        targetMapPath  = $targetMapPath
        targetProfilePath = $targetProfilePath
        sourceExists   = (Test-Path -LiteralPath $sourceMapPath)
        targetMapExists = (Test-Path -LiteralPath $targetMapPath)
        profileExists  = (Test-Path -LiteralPath $targetProfilePath)
        mapCopied      = $false
        profileWritten = $false
        skipped        = $false
        skipReason     = ""
        errors         = @()
    }

    # DryRun 模式：只记录计划，不执行
    if ($DryRun) {
        return [PSCustomObject]$result
    }

    # 检查源地图是否存在
    if (-not $result.sourceExists) {
        $result.errors += "源地图不存在: $sourceMapPath"
        return [PSCustomObject]$result
    }

    # --- 复制地图目录 ---
    # 脚本内部使用 Copy-Item（脚本逻辑，非 AI 直接写入仓库文件）
    if ($result.targetMapExists -and -not $Force) {
        $result.skipped = $true
        $result.skipReason = "目标地图已存在（使用 -Force 覆盖）: $targetMapPath"
    } else {
        try {
            # 如果已存在且 Force，先删除旧目录再复制
            if ($result.targetMapExists -and $Force) {
                Remove-Item -LiteralPath $targetMapPath -Recurse -Force
            }
            Copy-Item -LiteralPath $sourceMapPath -Destination $targetMapPath -Recurse -Force
            $result.mapCopied = $true
        } catch {
            $result.errors += "复制地图失败: $($_.Exception.Message)"
        }
    }

    # --- 写入 MapProfile ---
    # 注意：不覆盖已存在的 MapProfile（除非 Force），保护用户手动调整
    if ($result.profileExists -and -not $Force) {
        if (-not $result.skipped) {
            $result.skipped = $true
        }
        $result.skipReason += " MapProfile 已存在（使用 -Force 覆盖）: $targetProfilePath"
    } else {
        try {
            $profile = New-MapProfileObject -MapId $MapEntry.mapId -DisplayName $MapEntry.displayName
            Write-MapProfileJson -OutputPath $targetProfilePath -Profile $profile
            $result.profileWritten = $true
        } catch {
            $result.errors += "写入 MapProfile 失败: $($_.Exception.Message)"
        }
    }

    return [PSCustomObject]$result
}

# ==============================================================================
# 主流程
# ==============================================================================
Write-Host "=== Reborn 地图批量迁移工具 ==="
Write-Host "SourceRoot:    $SourceRoot"
Write-Host "TargetDir:     $TargetDir"
Write-Host "MapProfileDir: $MapProfileDir"
if ($DryRun) { Write-Host "Mode: DryRun（仅输出计划，不实际写入）" }
if ($Force)  { Write-Host "Force: 已启用（覆盖已存在文件）" }
Write-Host ""

# 获取完整地图清单
$fullCatalog = Get-RebornMapCatalog

# 按参数过滤地图列表
$selectedMaps = @()
if ([string]::IsNullOrWhiteSpace($Maps)) {
    $selectedMaps = $fullCatalog
} else {
    $requestedNames = $Maps -split ',' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -ne "" }
    foreach ($entry in $fullCatalog) {
        if ($requestedNames -contains $entry.name) {
            $selectedMaps += $entry
        }
    }
    # 报告未识别的地图名
    $knownNames = $fullCatalog | ForEach-Object { $_.name }
    foreach ($req in $requestedNames) {
        if ($knownNames -notcontains $req) {
            Write-Host "WARN: 未识别的地图名 '$req'，已跳过"
        }
    }
}

Write-Host "待迁移地图数: $($selectedMaps.Count) / $($fullCatalog.Count)（总计 29 张，排除已迁移的 zexpedition03）"
Write-Host ""

# 执行迁移
$results = @()
foreach ($entry in $selectedMaps) {
    $r = Invoke-SingleMapMigration `
        -MapEntry $entry `
        -SourceRoot $SourceRoot `
        -TargetMapDir $TargetDir `
        -TargetProfileDir $MapProfileDir `
        -DryRun:$DryRun `
        -Force:$Force
    $results += $r

    # 控制台输出单张地图状态
    $status = if ($DryRun) {
        if ($r.sourceExists) { "PLANNED" } else { "SOURCE_MISSING" }
    } elseif ($r.errors.Count -gt 0) {
        "ERROR"
    } elseif ($r.skipped) {
        "SKIPPED"
    } else {
        "DONE"
    }
    Write-Host ("  [{0}] {1,-28} -> {2}" -f $status, $entry.name, $r.targetMapPath)
    if ($r.errors.Count -gt 0) {
        foreach ($e in $r.errors) { Write-Host "      ERROR: $e" }
    }
}

# ==============================================================================
# 生成迁移报告
# ==============================================================================
$timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$reportPath = Join-Path $OutDir "migration-report-$timestamp.json"

# 使用 @() 包装确保 Where-Object 结果始终是数组（PS 5.1 单项匹配时 .Count 为空）
$summary = [ordered]@{
    total      = @($selectedMaps).Count
    planned    = @($results | Where-Object { $DryRun -and $_.sourceExists }).Count
    copied     = @($results | Where-Object { -not $DryRun -and $_.mapCopied }).Count
    profilesWritten = @($results | Where-Object { -not $DryRun -and $_.profileWritten }).Count
    skipped    = @($results | Where-Object { -not $DryRun -and $_.skipped }).Count
    errors     = @($results | Where-Object { $_.errors.Count -gt 0 }).Count
    sourceMissing = @($results | Where-Object { -not $_.sourceExists }).Count
}

$report = [ordered]@{
    schemaVersion = 1
    kind          = "RebornMapMigrationReport"
    generatedAt   = (Get-Date).ToString("o")
    dryRun        = [bool]$DryRun
    force         = [bool]$Force
    sourceRoot    = $SourceRoot
    targetDir     = $TargetDir
    mapProfileDir = $MapProfileDir
    summary       = $summary
    maps          = $results
}

# 确保输出目录存在
if (-not (Test-Path -LiteralPath $OutDir)) {
    [System.IO.Directory]::CreateDirectory($OutDir) | Out-Null
}

$reportJson = $report | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($reportPath, $reportJson, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "=== 迁移报告 ==="
Write-Host "Report: $reportPath"
Write-Host ("总计: {0} | 已计划: {1} | 已复制: {2} | 已写Profile: {3} | 跳过: {4} | 错误: {5} | 源缺失: {6}" -f `
    $summary.total, $summary.planned, $summary.copied, $summary.profilesWritten, `
    $summary.skipped, $summary.errors, $summary.sourceMissing)

if ($DryRun) {
    Write-Host ""
    Write-Host "DryRun 完成 - 未复制任何文件，未写入任何 MapProfile"
    Write-Host "去除 -DryRun 参数以执行实际迁移"
}

# 返回报告对象供调用方使用
return $report
