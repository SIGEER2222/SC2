<#
.SYNOPSIS
按 ID 关键词将重生虫心 mod 的 514 个单位分组到各指挥官，生成专属单位详情。

分组规则（基于单位 ID 前缀/关键词）：
  - Mengsk     : Mengsk*, Royal*（皇家建筑）
  - Stukov     : Infested*, SI*（Stukov/Izsha 系列）
  - Dehaka     : Primal*（原始虫群）
  - Zeratul    : Zeratul*, *Aiur, *Shakuras, *Taldarim, *Purifier
  - Kerrigan   : HotS*, K5Kerrigan, Spawned*
  - Narud      : Hybrid*, Void*
  - Raynor     : WarPig, Merc*, *Raynor
  - 其他       : 通用单位
#>
$ErrorActionPreference = "Stop"

$ScriptRoot = "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts"
$Explorer = Join-Path $ScriptRoot "sc2_unit_explorer.py"
$ModPath = "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\crys_the_swarm_reborn.SC2Mod"
$OutDir = "e:\Code\MyMod\SC2\其他mod\重生虫心扫描"

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$BaseMods = @(
    "E:\Code\MyMod\SC2\sc2-data-trigger\mods\core.sc2mod",
    "E:\Code\MyMod\SC2\sc2-data-trigger\mods\liberty.sc2mod",
    "E:\Code\MyMod\SC2\sc2-data-trigger\mods\swarm.sc2mod",
    "E:\Code\MyMod\SC2\sc2-data-trigger\mods\void.sc2mod"
)
$AllMods = $BaseMods + @($ModPath)

function Build-OnlyModArgs($mods) {
    $a = @()
    foreach ($m in $mods) { $a += @("--only-mod", $m) }
    return $a
}

# 从 mod 的 UnitData.xml 提取所有 CUnit id
$unitXml = Join-Path $ModPath "Base.SC2Data\GameData\UnitData.xml"
[xml]$xmlContent = Get-Content -LiteralPath $unitXml -Raw -Encoding UTF8
$allIds = @()
foreach ($node in $xmlContent.SelectNodes("//CUnit")) {
    $id = $node.GetAttribute("id")
    if ($id) { $allIds += $id }
}
Write-Host "mod UnitData.xml 定义单位: $($allIds.Count) 个" -ForegroundColor Cyan

# 指挥官分组规则（按优先级匹配）
$Rules = [ordered]@{
    "Mengsk"   = { param($id) $id -like "Mengsk*" -or $id -like "Royal*" }
    "Stukov"   = { param($id) $id -like "Infested*" -or $id -like "SI*" -or $id -eq "Stukov" }
    "Dehaka"   = { param($id) $id -like "Primal*" -or $id -like "Yeti*" -or $id -like "GiantYeti*" -or $id -eq "Dehaka" }
    "Zeratul"  = { param($id) $id -like "Zeratul*" -or $id -like "*Aiur" -or $id -like "*Shakuras" -or $id -like "*Taldarim" -or $id -like "*Purifier" -or $id -like "XelNaga*" }
    "Kerrigan" = { param($id) $id -like "HotS*" -or $id -like "K5*" -or $id -like "Spawned*" -or $id -like "HunterKiller*" -or $id -eq "Kerrigan" }
    "Narud"    = { param($id) $id -like "Hybrid*" -or $id -like "Void*" -or $id -like "VoidRift*" }
    "Raynor"   = { param($id) $id -like "WarPig*" -or $id -like "Merc*" -or $id -like "*Raynor" }
    "Mengsk2"  = { param($id) $id -like "Mengsk*" }
}

# 分组
$groups = @{}
foreach ($cmd in $Rules.Keys) { $groups[$cmd] = @() }
$groups["其他"] = @()

foreach ($id in $allIds) {
    $matched = $false
    foreach ($cmd in $Rules.Keys) {
        $rule = $Rules[$cmd]
        if (& $rule $id) {
            $groups[$cmd] += $id
            $matched = $true
            break
        }
    }
    if (-not $matched) { $groups["其他"] += $id }
}

# 移除 Mengsk2 临时分组（合并到 Mengsk）
if ($groups.ContainsKey("Mengsk2")) {
    $groups["Mengsk"] = ($groups["Mengsk"] + $groups["Mengsk2"] | Select-Object -Unique)
    $groups.Remove("Mengsk2")
}

Write-Host ""
Write-Host "=== 分组结果 ===" -ForegroundColor Cyan
foreach ($cmd in $groups.Keys | Sort-Object) {
    Write-Host ("  {0,-10}: {1} 个" -f $cmd, $groups[$cmd].Count)
}

$modArgs = Build-OnlyModArgs $AllMods

Write-Host ""
Write-Host "=== 生成各指挥官单位详情 ===" -ForegroundColor Cyan
$summary = @()

foreach ($cmd in ($groups.Keys | Sort-Object)) {
    $ids = $groups[$cmd]
    if ($ids.Count -eq 0) { continue }

    $cmdOut = Join-Path $OutDir "${cmd}_单位列表.txt"
    "=== $cmd 指挥官专属单位（共 $($ids.Count) 个） ===" | Out-File -FilePath $cmdOut -Encoding utf8
    "来源: mod UnitData.xml 按 ID 关键词分组" | Out-File -FilePath $cmdOut -Encoding utf8 -Append
    "=" * 60 | Out-File -FilePath $cmdOut -Encoding utf8 -Append
    "" | Out-File -FilePath $cmdOut -Encoding utf8 -Append

    $i = 0
    foreach ($uid in $ids) {
        $i++
        Write-Host "  [$cmd] $i/$($ids.Count) $uid" -NoNewline -ForegroundColor Gray
        & python $Explorer $uid --depth 1 @modArgs 2>$null | Out-File -FilePath $cmdOut -Encoding utf8 -Append
        "" | Out-File -FilePath $cmdOut -Encoding utf8 -Append
        Write-Host " OK" -ForegroundColor Green
    }

    $size = [math]::Round((Get-Item $cmdOut).Length/1KB, 1)
    Write-Host "  [$cmd] 完成: $($ids.Count) 个单位, $size KB" -ForegroundColor Green
    $summary += [PSCustomObject]@{
        指挥官 = $cmd
        单位数 = $ids.Count
        文件大小KB = $size
    }
}

# 更新汇总
$summaryOut = Join-Path $OutDir "汇总.md"
@"
# 重生虫心 各指挥官单位扫描汇总

## mod 信息
- 路径: ``$ModPath``
- UnitData.xml 定义单位总数: $($allIds.Count)
- 合并后单位总数（含 SC2 原生）: 1390
- 合并后能力总数: 930

## 按指挥官分组（基于单位 ID 关键词）

| 指挥官 | 单位数 | 详情文件大小 |
|--------|--------|--------|
"@ | Out-File -FilePath $summaryOut -Encoding utf8
foreach ($s in $summary) {
    "| $($s.指挥官) | $($s.单位数) | $($s.文件大小KB) KB |" | Out-File -FilePath $summaryOut -Encoding utf8 -Append
}
$totalGrouped = ($summary | Measure-Object -Property 单位数 -Sum).Sum
$otherCount = $groups["其他"].Count
@"
| **合计** | **$totalGrouped** | - |

## 分组规则

| 指挥官 | ID 关键词 |
|--------|----------|
| Mengsk | ``Mengsk*``, ``Royal*``（皇家建筑） |
| Stukov | ``Infested*``, ``SI*``, ``Stukov`` |
| Dehaka | ``Primal*``, ``Yeti*``, ``Dehaka`` |
| Zeratul | ``Zeratul*``, ``*Aiur``, ``*Shakuras``, ``*Taldarim``, ``*Purifier``, ``XelNaga*`` |
| Kerrigan | ``HotS*``, ``K5*``, ``Spawned*``, ``HunterKiller*``, ``Kerrigan`` |
| Narud | ``Hybrid*``, ``Void*``, ``VoidRift*`` |
| Raynor | ``WarPig*``, ``Merc*``, ``*Raynor`` |
| 其他 | 不匹配以上任何规则的单位（含原生 SC2 覆盖项、装饰物、武器等） |

## 说明

- 分组基于单位 ID 关键词匹配，可能与实际指挥官归属有偏差
- "其他"分组包含：原生 SC2 单位覆盖、地图装饰物、武器效果单位、Pickup 物品等
- 每个单位的详情包含：能力/卡牌/生产/建造/研究/武器/反向依赖
- 详见 ``<指挥官>_单位列表.txt`` 文件

## 文件清单
- ``全部单位列表.txt``  mod 全部 1390 个单位 ID + 名称（含 SC2 原生）
- ``全部能力列表.txt``  mod 全部 930 个能力 ID（含 SC2 原生）
- ``<指挥官>_单位列表.txt``  按指挥官分组的单位详情（depth=1）
- ``<指挥官>_关系图.txt``  起始英雄单位深度 3 展开关系图
"@ | Out-File -FilePath $summaryOut -Encoding utf8 -Append

Write-Host ""
Write-Host "=== 完成 ===" -ForegroundColor Green
Write-Host "输出目录: $OutDir"
Get-ChildItem $OutDir | Format-Table Name, @{N="Size(KB)";E={[math]::Round($_.Length/1KB,1)}} -AutoSize
