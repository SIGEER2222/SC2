<#
.SYNOPSIS
重新扫描重生虫心 mod 原创指挥官，补上 Abathur。

Abathur 是 mod 实现的指挥官（虽然 SC2 原版合作也有 Abathur，但 mod 版本独立）。
其专属单位从 CommanderUnits 能力（AbilData.xml）提取：
  Blightbringer, BroodLord, Brutalisk, Devourer, IzshaGuardian, Kraken,
  Leviathan, Mamba, Mesmer, MutaliskAnkylos, MutaliskChar, Omegalisk

同时新增 7 个原创指挥官保持不变：Izsha, Karass, Naktul, Narud, Tosh, Urun, Warfield

每个指挥官的输出文件包含两部分：
  1. 单位/建筑概览（中文备注）：表格列出中文名、ID、类型（单位/建筑）、主要技能
  2. 详细关系图：python 工具的文本输出（depth=1）

输出覆盖之前的扫描结果。
#>
$ErrorActionPreference = "Continue"  # 用 Continue：python 工具的 [INFO] 写到 stderr，Stop 会把它当成终止错误

$ScriptRoot = "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts"
$Explorer = Join-Path $ScriptRoot "sc2_unit_explorer.py"
$ModPath = "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\crys_the_swarm_reborn.SC2Mod"
$OutDir = "e:\Code\MyMod\SC2\其他mod\重生虫心扫描"

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

# === 1. SC2 原生单位集合 ===
$BaseMods = @(
    "E:\Code\MyMod\SC2\sc2-data-trigger\mods\core.sc2mod",
    "E:\Code\MyMod\SC2\sc2-data-trigger\mods\liberty.sc2mod",
    "E:\Code\MyMod\SC2\sc2-data-trigger\mods\swarm.sc2mod",
    "E:\Code\MyMod\SC2\sc2-data-trigger\mods\void.sc2mod"
)
$nativeIds = @{}
foreach ($mod in $BaseMods) {
    $files = Get-ChildItem -Path $mod -Recurse -Filter "UnitData.xml" -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        $content = Get-Content $f.FullName -Raw -Encoding UTF8
        $ms = [regex]::Matches($content, '<CUnit\s+id="([^"]+)"')
        foreach ($m in $ms) { $nativeIds[$m.Groups[1].Value] = $true }
    }
}
Write-Host "SC2 原生单位: $($nativeIds.Count) 个" -ForegroundColor Cyan

# === 2. mod UnitData.xml 单位 ===
$modUnitXml = Join-Path $ModPath "Base.SC2Data\GameData\UnitData.xml"
[xml]$modXml = Get-Content -LiteralPath $modUnitXml -Raw -Encoding UTF8
$modIds = @()
foreach ($node in $modXml.SelectNodes("//CUnit")) {
    $id = $node.GetAttribute("id")
    if ($id) { $modIds += $id }
}
$newIds = $modIds | Where-Object { -not $nativeIds.ContainsKey($_) }
Write-Host "mod 独有单位: $($newIds.Count) 个" -ForegroundColor Cyan
Write-Host ""

# === 3. 指挥官分组（8 个，含 Abathur） ===
# Abathur 是虫族指挥官，单位来源为 Larva 变异 + Drone 建造(ZergBuild) + Devourer(需 Corruptor 变异)
$Commanders = [ordered]@{
    "Abathur"  = @{ Hero = "HunterKiller"; Dynamic = $true }
    "Izsha"    = @{ Hero = "SIQueen";       Pattern = "^SI" }
    "Karass"   = @{ Hero = "HighArchonTemplar"; Pattern = "HighArchon|Templar|Anchorite|Magistra|Kraith" }
    "Naktul"   = @{ Hero = "Queen";         Pattern = "^Queen|BroodMother" }
    "Narud"    = @{ Hero = "RevenantGun";   Pattern = "Revenant|Hybrid|Void|Maar|VoidRift" }
    "Tosh"     = @{ Hero = "Witch";         Pattern = "Witch|Mandrake|Possessed|Spectre|Voodoo|Tosh" }
    "Urun"     = @{ Hero = "Huntress";      Pattern = "Huntress|Gloomstalker|Warlock|Fury|Jaeger" }
    "Warfield" = @{ Hero = "Grizzly";       Pattern = "Grizzly|Condor|Gorgon|WarPig|Spartan|Warfield" }
}

# 分组
$groups = @{}
foreach ($cmd in $Commanders.Keys) { $groups[$cmd] = @() }

# 构造 mod 加载参数（用于动态提取 Abathur 单位）
$AllMods = $BaseMods + @($ModPath)
function Build-OnlyModArgs($mods) {
    $a = @()
    foreach ($m in $mods) { $a += @("--only-mod", $m) }
    return $a
}
$modArgs = Build-OnlyModArgs $AllMods

# Abathur: 动态从 Larva(变异单位) + Drone(ZergBuild 建筑) 提取完整列表
Write-Host "动态提取 Abathur 单位/建筑..." -ForegroundColor Cyan
$larvaJson = & python $Explorer Larva --depth 1 --format json @modArgs 2>$null | ConvertFrom-Json
$droneJson = & python $Explorer Drone --depth 1 --format json @modArgs 2>$null | ConvertFrom-Json
$abathurIds = [System.Collections.Generic.List[string]]::new()
# Larva 可变异单位（含跳虫、幼雷兽、莽兽等）
foreach ($t in $larvaJson.trains) {
    if ($t.unit_id -and (-not $abathurIds.Contains($t.unit_id))) { $abathurIds.Add($t.unit_id) }
}
# Drone 的 ZergBuild 建筑（孵化场、血池、刺蛇穴等）
foreach ($b in $droneJson.builds) {
    if ($b.abil_id -eq "ZergBuild" -and $b.unit_id -and (-not $abathurIds.Contains($b.unit_id))) {
        $abathurIds.Add($b.unit_id)
    }
}
# 补充：Corruptor 可变异为 Devourer/BroodLord（morphs_to 不在 Larva trains 中）
$corruptorJson = & python $Explorer Corruptor --depth 1 --format json @modArgs 2>$null | ConvertFrom-Json
if ($corruptorJson.morphs_to) {
    foreach ($m in $corruptorJson.morphs_to) {
        if ($m.target_unit_id -and (-not $abathurIds.Contains($m.target_unit_id))) {
            $abathurIds.Add($m.target_unit_id)
        }
    }
}
$groups["Abathur"] = $abathurIds
Write-Host "  Abathur: $($abathurIds.Count) 个 (Larva变异 + ZergBuild建筑 + Corruptor变异)" -ForegroundColor Gray

# 其他指挥官: 用关键词从 mod 独有单位中匹配
foreach ($id in $newIds) {
    foreach ($cmd in @("Izsha","Karass","Naktul","Narud","Tosh","Urun","Warfield")) {
        $pattern = $Commanders[$cmd].Pattern
        if ($id -match $pattern) { $groups[$cmd] += $id }
    }
}

Write-Host "=== 分组结果 ===" -ForegroundColor Cyan
foreach ($cmd in $Commanders.Keys) {
    Write-Host ("  {0,-10}: {1} 个 (起始英雄: {2})" -f $cmd, $groups[$cmd].Count, $Commanders[$cmd].Hero)
}

# === 4. 生成详情 ===
# ($AllMods / $modArgs 已在前面定义)

# 标准能力（不作为"主要技能"展示）—— 按 abil_id 过滤
$StandardAbils = @("stop", "move", "attack")

# SC2 原生虫族单位/建筑中文名映射（原生 mods 无 zhCN，需手动补充）
$NativeZhNames = @{
    # 基础单位
    "Zergling" = "跳虫"; "Mutalisk" = "异龙"; "Ultralisk" = "雷兽"
    "Corruptor" = "腐化者"; "Viper" = "飞蛇"; "SwarmHostMP" = "虫群宿主"
    "Scourge" = "蝎虫"; "Ravager" = "破坏者"
    "HotSHunter" = "猎手"; "HotSSplitterlingBig" = "分裂虫"
    "BroodLordCocoon" = "巢虫领主茧"; "Digester" = "消化者"
    # 建筑
    "Hatchery" = "孵化场"; "CreepTumor" = "蠕变肿瘤"; "Extractor" = "萃取厂"
    "SpawningPool" = "血池"; "EvolutionChamber" = "进化腔"
    "HydraliskDen" = "刺蛇穴"; "Spire" = "尖塔"; "UltraliskCavern" = "雷兽窟"
    "InfestationPit" = "感染坑"; "NydusNetwork" = "尼德斯网络"
    "BanelingNest" = "爆虫巢"; "RoachWarren" = "蟑螂穴"
    "SpineCrawler" = "脊针爬虫"; "SporeCrawler" = "孢子爬虫"
}

# 从 JSON 节点提取摘要信息：返回 [中文名, 类型, 主要技能(中文，逗号分隔)]
function Get-UnitSummary($json) {
    if ($null -eq $json) { return @("[未知]", "?", "") }
    $name = $json.name
    # 若 python 工具返回的是 ID（无中文名），尝试用原生映射表补充
    if ((-not $name) -or ($name -eq $json.unit_id)) {
        $uid = $json.unit_id
        if ($NativeZhNames.ContainsKey($uid)) { $name = $NativeZhNames[$uid] }
    }
    if (-not $name) { $name = $json.unit_id }
    # 类型判断：attributes 含 Structure → 建筑；否则单位
    $attrs = $json.attributes
    $type = "单位"
    if ($attrs -and ($attrs -contains "Structure")) { $type = "建筑" }
    # 主要技能：从 card_layouts 取 face_name（已由 python 工具解析为中文）
    # 过滤掉标准能力（stop/move/attack）和重复项
    $skills = @()
    if ($json.card_layouts) {
        foreach ($card in $json.card_layouts) {
            $aid = $card.abil_id
            # 跳过标准能力 stop/move/attack
            if ($aid -and ($StandardAbils -contains $aid)) { continue }
            # 优先用 face_name（中文），无则用 face（英文 ID）
            $nm = $card.face_name
            if (-not $nm) { $nm = $card.face }
            if (-not $nm) { continue }
            # 去重（不同卡牌可能同名）
            if ($skills -notcontains $nm) { $skills += $nm }
        }
    }
    $skillStr = $skills -join "、"
    return @($name, $type, $skillStr)
}

Write-Host ""
Write-Host "=== 生成各指挥官详情 ===" -ForegroundColor Cyan
$summary = @()

foreach ($cmd in $Commanders.Keys) {
    $hero = $Commanders[$cmd].Hero
    $ids = $groups[$cmd]

    # 起始英雄关系图（depth=3）
    $heroOut = Join-Path $OutDir "${cmd}_起始英雄关系图.txt"
    "=== $cmd 指挥官 ===" | Out-File -FilePath $heroOut -Encoding utf8
    "起始英雄: $hero" | Out-File -FilePath $heroOut -Encoding utf8 -Append
    "展开深度: 3" | Out-File -FilePath $heroOut -Encoding utf8 -Append
    "=" * 60 | Out-File -FilePath $heroOut -Encoding utf8 -Append
    "" | Out-File -FilePath $heroOut -Encoding utf8 -Append
    Write-Host "  [$cmd] 起始英雄 $hero ..." -NoNewline -ForegroundColor Gray
    & python $Explorer $hero --depth 3 @modArgs 2>$null | Out-File -FilePath $heroOut -Encoding utf8 -Append
    Write-Host " OK" -ForegroundColor Green

    # 专属单位详情（depth=1）+ 中文摘要
    $unitsOut = Join-Path $OutDir "${cmd}_专属单位.txt"
    $src = if ($cmd -eq "Abathur") { "来源: Larva 变异单位 + Drone ZergBuild 建筑 + Corruptor 变异（动态提取）" } else { "来源: mod 独有单位按 ID 关键词分组（$($Commanders[$cmd].Pattern)）" }
    "=== $cmd 指挥官专属单位（共 $($ids.Count) 个） ===" | Out-File -FilePath $unitsOut -Encoding utf8
    $src | Out-File -FilePath $unitsOut -Encoding utf8 -Append
    "=" * 60 | Out-File -FilePath $unitsOut -Encoding utf8 -Append
    "" | Out-File -FilePath $unitsOut -Encoding utf8 -Append

    # === 中文摘要表 ===
    Write-Host "  [$cmd] 生成中文摘要表 ..." -NoNewline -ForegroundColor Gray
    $summaryRows = @()
    $i = 0
    foreach ($uid in $ids) {
        $i++
        # 用 JSON 格式获取结构化数据用于摘要
        $jsonOut = & python $Explorer $uid --depth 1 --format json @modArgs 2>$null
        $jsonData = $null
        if ($jsonOut) {
            try { $jsonData = $jsonOut | ConvertFrom-Json } catch { $jsonData = $null }
        }
        $info = Get-UnitSummary $jsonData
        $summaryRows += [PSCustomObject]@{
            No   = $i
            Name = $info[0]
            Id   = $uid
            Type = $info[1]
            Skills = $info[2]
        }
    }
    Write-Host " OK" -ForegroundColor Green

    "## 单位/建筑概览（中文备注）" | Out-File -FilePath $unitsOut -Encoding utf8 -Append
    "" | Out-File -FilePath $unitsOut -Encoding utf8 -Append
    "| # | 中文名 | ID | 类型 | 主要技能 |" | Out-File -FilePath $unitsOut -Encoding utf8 -Append
    "|---|--------|----|------|----------|" | Out-File -FilePath $unitsOut -Encoding utf8 -Append
    foreach ($r in $summaryRows) {
        "| $($r.No) | $($r.Name) | $($r.Id) | $($r.Type) | $($r.Skills) |" | Out-File -FilePath $unitsOut -Encoding utf8 -Append
    }
    "" | Out-File -FilePath $unitsOut -Encoding utf8 -Append
    "=" * 60 | Out-File -FilePath $unitsOut -Encoding utf8 -Append
    "" | Out-File -FilePath $unitsOut -Encoding utf8 -Append

    # === 详细关系图 ===
    "## 详细关系图" | Out-File -FilePath $unitsOut -Encoding utf8 -Append
    "" | Out-File -FilePath $unitsOut -Encoding utf8 -Append
    $i = 0
    foreach ($uid in $ids) {
        $i++
        Write-Host "  [$cmd] $i/$($ids.Count) $uid" -NoNewline -ForegroundColor Gray
        & python $Explorer $uid --depth 1 @modArgs 2>$null | Out-File -FilePath $unitsOut -Encoding utf8 -Append
        "" | Out-File -FilePath $unitsOut -Encoding utf8 -Append
        Write-Host " OK" -ForegroundColor Green
    }

    $heroSize = [math]::Round((Get-Item $heroOut).Length/1KB, 1)
    $unitsSize = [math]::Round((Get-Item $unitsOut).Length/1KB, 1)
    Write-Host "  [$cmd] 完成: 英雄 $heroSize KB, 专属单位 $($ids.Count) 个 $unitsSize KB" -ForegroundColor Green
    $summary += [PSCustomObject]@{
        指挥官 = $cmd
        起始英雄 = $hero
        专属单位数 = $ids.Count
        英雄图KB = $heroSize
        单位图KB = $unitsSize
    }
}

# mod 独有单位总列表
$allNewOut = Join-Path $OutDir "mod独有单位列表.txt"
"=== 重生虫心 mod 独有单位（共 $($newIds.Count) 个，非 SC2 原生） ===" | Out-File -FilePath $allNewOut -Encoding utf8
$newIds | Out-File -FilePath $allNewOut -Encoding utf8 -Append

# 汇总
$summaryOut = Join-Path $OutDir "汇总.md"
@"
# 重生虫心 mod 指挥官扫描汇总

## 范围

扫描 mod 实现的 8 个指挥官（含 mod 版 Abathur）：
**Abathur, Izsha, Karass, Naktul, Narud, Tosh, Urun, Warfield**

## 单位筛选

- SC2 原生单位: $($nativeIds.Count) 个
- mod 独有单位: $($newIds.Count) 个

## 8 个指挥官

| 指挥官 | 起始英雄 | 专属单位数 | 英雄图 | 单位图 |
|--------|----------|--------|--------|--------|
"@ | Out-File -FilePath $summaryOut -Encoding utf8
foreach ($s in $summary) {
    "| $($s.指挥官) | $($s.起始英雄) | $($s.专属单位数) | $($s.英雄图KB) KB | $($s.单位图KB) KB |" | Out-File -FilePath $summaryOut -Encoding utf8 -Append
}
$totalUnits = ($summary | Measure-Object -Property 专属单位数 -Sum).Sum
@"
| **合计** | - | **$totalUnits** | - | - |

## 分组规则

| 指挥官 | 起始英雄 | 单位来源 |
|--------|----------|----------|
| Abathur | HunterKiller | 动态提取：Larva 变异单位 + Drone ZergBuild 建筑 + Corruptor 变异（含跳虫/雷兽/孵化场/血池等基础虫族单位建筑） |
| Izsha | SIQueen | ``^SI`` |
| Karass | HighArchonTemplar | ``HighArchon``, ``Templar``, ``Anchorite``, ``Magistra``, ``Kraith`` |
| Naktul | Queen | ``^Queen``, ``BroodMother`` |
| Narud | RevenantGun | ``Revenant``, ``Hybrid``, ``Void``, ``Maar`` |
| Tosh | Witch | ``Witch``, ``Mandrake``, ``Possessed``, ``Spectre``, ``Tosh`` |
| Urun | Huntress | ``Huntress``, ``Gloomstalker``, ``Warlock``, ``Fury``, ``Jaeger`` |
| Warfield | Grizzly | ``Grizzly``, ``Condor``, ``Gorgon``, ``WarPig``, ``Spartan``, ``Warfield`` |

## 说明

- Abathur 虽然在 SC2 原版合作模式中存在，但本 mod 是独立实现版本
- Abathur 单位/建筑来源：Larva(幼虫) 变异列表 + Drone(工蜂) ZergBuild 建造列表 + Corruptor(腐化者) 变异列表，含基础虫族单位(跳虫/刺蛇/雷兽等)和建筑(孵化场/血池/刺蛇穴等)
- 其他 7 个指挥官为 mod 原创指挥官
- 排除的 SC2 原版合作指挥官：Raynor, Kerrigan, Stukov, Dehaka, Mengsk, Zeratul, Zagara
- 每个指挥官的 ``_专属单位.txt`` 文件顶部含"单位/建筑概览（中文备注）"表格

## 文件清单
- ``mod独有单位列表.txt``  mod 独有 $($newIds.Count) 个单位 ID
- ``<指挥官>_起始英雄关系图.txt``  起始英雄深度 3 展开关系图
- ``<指挥官>_专属单位.txt``  指挥官专属单位详情（顶部中文摘要表 + 下方详细关系图 depth=1）
"@ | Out-File -FilePath $summaryOut -Encoding utf8 -Append

Write-Host ""
Write-Host "=== 完成 ===" -ForegroundColor Green
Write-Host "输出目录: $OutDir"
Get-ChildItem $OutDir | Format-Table Name, @{N="Size(KB)";E={[math]::Round($_.Length/1KB,1)}} -AutoSize
