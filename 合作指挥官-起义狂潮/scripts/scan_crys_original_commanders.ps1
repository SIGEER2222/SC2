<#
.SYNOPSIS
只扫描重生虫心 mod 自己新增的指挥官（7 个非 SC2 原版合作指挥官）。

筛出 mod 独有单位（非 SC2 原版 958 个），按 7 个原创指挥官分组：
  - Izsha    : SI* (SIQueen 等)
  - Karass   : HighArchon*, Templar*
  - Naktul   : Queen*, SI*
  - Narud    : Revenant*, Hybrid*, Void*
  - Tosh     : Witch*, Mandrake*, Possessed*
  - Urun     : Huntress*, Gloomstalker*, Warlock*
  - Warfield : Grizzly*, Condor*, Gorgon*

每个指挥官输出：
  - <指挥官>_起始英雄关系图.txt  (depth=3)
  - <指挥官>_专属单位.txt        (depth=1, 只含 mod 独有单位)
#>
$ErrorActionPreference = "Stop"

$ScriptRoot = "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts"
$Explorer = Join-Path $ScriptRoot "sc2_unit_explorer.py"
$ModPath = "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\crys_the_swarm_reborn.SC2Mod"
$OutDir = "e:\Code\MyMod\SC2\其他mod\重生虫心扫描"

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

# === 1. 构建 SC2 原生单位 ID 集合 ===
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

# === 2. 加载重生 mod 单位 ID ===
$modUnitXml = Join-Path $ModPath "Base.SC2Data\GameData\UnitData.xml"
[xml]$modXml = Get-Content -LiteralPath $modUnitXml -Raw -Encoding UTF8
$modIds = @()
foreach ($node in $modXml.SelectNodes("//CUnit")) {
    $id = $node.GetAttribute("id")
    if ($id) { $modIds += $id }
}
Write-Host "重生 mod UnitData.xml 单位: $($modIds.Count) 个" -ForegroundColor Cyan

# === 3. 筛出 mod 独有单位（非原生）===
$newIds = $modIds | Where-Object { -not $nativeIds.ContainsKey($_) }
Write-Host "mod 独有单位（非原生）: $($newIds.Count) 个" -ForegroundColor Cyan
Write-Host ""

# === 4. 按 7 个 mod 原创指挥官分组 ===
$Commanders = [ordered]@{
    "Izsha"    = @{ Hero = "SIQueen";       Pattern = "^SI" }
    "Karass"   = @{ Hero = "HighArchonTemplar"; Pattern = "HighArchon|Templar|Anchorite|Magistra|Kraith" }
    "Naktul"   = @{ Hero = "Queen";         Pattern = "^Queen|BroodMother" }
    "Narud"    = @{ Hero = "RevenantGun";   Pattern = "Revenant|Hybrid|Void|Maar|VoidRift" }
    "Tosh"     = @{ Hero = "Witch";         Pattern = "Witch|Mandrake|Possessed|Spectre|Voodoo|Tosh" }
    "Urun"     = @{ Hero = "Huntress";      Pattern = "Huntress|Gloomstalker|Warlock|Huntress|Fury|Jaeger" }
    "Warfield" = @{ Hero = "Grizzly";       Pattern = "Grizzly|Condor|Gorgon|WarPig|Spartan|Warfield" }
}

# 分组
$groups = @{}
$matched = @{}
foreach ($cmd in $Commanders.Keys) {
    $groups[$cmd] = @()
    $matched[$cmd] = @{}
}

foreach ($id in $newIds) {
    foreach ($cmd in $Commanders.Keys) {
        $pattern = $Commanders[$cmd].Pattern
        if ($id -match $pattern) {
            if (-not $matched[$cmd].ContainsKey($id)) {
                $groups[$cmd] += $id
                $matched[$cmd][$id] = $true
            }
        }
    }
}

Write-Host "=== 分组结果（仅 mod 独有单位） ===" -ForegroundColor Cyan
foreach ($cmd in $Commanders.Keys) {
    Write-Host ("  {0,-10}: {1} 个 (起始英雄: {2})" -f $cmd, $groups[$cmd].Count, $Commanders[$cmd].Hero)
}

# === 5. 生成详情 ===
$AllMods = $BaseMods + @($ModPath)
function Build-OnlyModArgs($mods) {
    $a = @()
    foreach ($m in $mods) { $a += @("--only-mod", $m) }
    return $a
}
$modArgs = Build-OnlyModArgs $AllMods

Write-Host ""
Write-Host "=== 生成各指挥官详情 ===" -ForegroundColor Cyan
$summary = @()

foreach ($cmd in $Commanders.Keys) {
    $hero = $Commanders[$cmd].Hero
    $ids = $groups[$cmd]

    # 起始英雄关系图（depth=3）
    $heroOut = Join-Path $OutDir "${cmd}_起始英雄关系图.txt"
    "=== $cmd 指挥官（mod 原创指挥官） ===" | Out-File -FilePath $heroOut -Encoding utf8
    "起始英雄: $hero" | Out-File -FilePath $heroOut -Encoding utf8 -Append
    "展开深度: 3" | Out-File -FilePath $heroOut -Encoding utf8 -Append
    "=" * 60 | Out-File -FilePath $heroOut -Encoding utf8 -Append
    "" | Out-File -FilePath $heroOut -Encoding utf8 -Append
    Write-Host "  [$cmd] 起始英雄 $hero ..." -NoNewline -ForegroundColor Gray
    & python $Explorer $hero --depth 3 @modArgs 2>$null | Out-File -FilePath $heroOut -Encoding utf8 -Append
    Write-Host " OK" -ForegroundColor Green

    # 专属单位详情（depth=1）
    $unitsOut = Join-Path $OutDir "${cmd}_专属单位.txt"
    "=== $cmd 指挥官专属单位（共 $($ids.Count) 个，mod 独有） ===" | Out-File -FilePath $unitsOut -Encoding utf8
    "分组关键词: $($Commanders[$cmd].Pattern)" | Out-File -FilePath $unitsOut -Encoding utf8 -Append
    "=" * 60 | Out-File -FilePath $unitsOut -Encoding utf8 -Append
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
# 重生虫心 mod 原创指挥官扫描汇总

## 范围

只扫描重生虫心 mod 自己原创的 7 个指挥官（非 SC2 原版合作指挥官）：
**Izsha, Karass, Naktul, Narud, Tosh, Urun, Warfield**

排除的 SC2 原版合作指挥官：Raynor, Kerrigan, Stukov, Abathur, Dehaka, Mengsk, Zeratul, Zagara

## 单位筛选

- SC2 原生单位: $($nativeIds.Count) 个（core/liberty/swarm/void）
- 重生 mod UnitData.xml 定义: $($modIds.Count) 个
- **mod 独有单位（非原生）: $($newIds.Count) 个**

## 7 个原创指挥官

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

| 指挥官 | ID 关键词 |
|--------|----------|
| Izsha | ``^SI`` |
| Karass | ``HighArchon``, ``Templar``, ``Anchorite``, ``Magistra``, ``Kraith`` |
| Naktul | ``^Queen``, ``BroodMother`` |
| Narud | ``Revenant``, ``Hybrid``, ``Void``, ``Maar`` |
| Tosh | ``Witch``, ``Mandrake``, ``Possessed``, ``Spectre``, ``Tosh`` |
| Urun | ``Huntress``, ``Gloomstalker``, ``Warlock``, ``Fury``, ``Jaeger`` |
| Warfield | ``Grizzly``, ``Condor``, ``Gorgon``, ``WarPig``, ``Spartan``, ``Warfield`` |

## 文件清单
- ``mod独有单位列表.txt``  mod 独有的 $($newIds.Count) 个单位 ID
- ``<指挥官>_起始英雄关系图.txt``  起始英雄深度 3 展开关系图
- ``<指挥官>_专属单位.txt``  指挥官专属单位详情（depth=1）
"@ | Out-File -FilePath $summaryOut -Encoding utf8 -Append

Write-Host ""
Write-Host "=== 完成 ===" -ForegroundColor Green
Write-Host "输出目录: $OutDir"
Get-ChildItem $OutDir | Format-Table Name, @{N="Size(KB)";E={[math]::Round($_.Length/1KB,1)}} -AutoSize
