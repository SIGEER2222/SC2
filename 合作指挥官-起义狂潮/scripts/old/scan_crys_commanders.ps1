<#
.SYNOPSIS
扫描重生虫心 mod 各指挥官的单位/建筑关系图。

每个指挥官对应一个起始英雄单位，通过该单位向下展开 depth=3 的关系图，
可以看到该指挥官能生产/建造/研究的完整体系。

输出到 "其他mod/重生虫心扫描/" 目录：
  - 全部单位列表.txt         mod 定义的 514 个单位 ID + 名称
  - 全部能力列表.txt         mod 定义的全部能力 ID
  - <指挥官>_关系图.txt      起始单位深度展开（depth=3）
  - 汇总.md                  15 个指挥官对比
#>
$ErrorActionPreference = "Stop"

$ScriptRoot = "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts"
$Explorer = Join-Path $ScriptRoot "sc2_unit_explorer.py"
$ModPath = "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\crys_the_swarm_reborn.SC2Mod"
$OutDir = "e:\Code\MyMod\SC2\其他mod\重生虫心扫描"

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

# 基础 mod 链
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

# 15 个指挥官 + 起始单位（从 Lib48DF4533.galaxy gt_CommanderStart_Func 提取）
$Commanders = [ordered]@{
    "Abathur"  = @("HunterKiller")
    "Dehaka"   = @("PrimalHydralisk2", "PrimalIgniter")
    "Izsha"    = @("SIQueen")
    "Karass"   = @("HighArchonTemplar")
    "Kerrigan" = @("K5Kerrigan")
    "Naktul"   = @("Queen")
    "Narud"    = @("RevenantGun")
    "Raynor"   = @("WarPig")
    "Stukov"   = @("InfestedMarine")
    "Tosh"     = @("Witch")
    "Urun"     = @("Huntress")
    "Warfield" = @("Grizzly")
    "Mengsk"   = @("MengskMarauder")
    "Zagara"   = @("InfestedAbomination")
    "Zeratul"  = @("StalkerShakuras")
}

Write-Host "=== 重生虫心 各指挥官单位扫描 ===" -ForegroundColor Cyan
Write-Host "mod: $ModPath"
Write-Host "输出目录: $OutDir"
Write-Host ""

$modArgs = Build-OnlyModArgs $AllMods

# 1) 全部单位列表
Write-Host "[1/3] 生成全部单位列表..." -ForegroundColor Yellow
$unitsOut = Join-Path $OutDir "全部单位列表.txt"
& python $Explorer --list-units @modArgs 2>$null | Out-File -FilePath $unitsOut -Encoding utf8
$unitCount = (Get-Content $unitsOut | Where-Object { $_ -match "^\s*\S" }).Count
Write-Host "  单位总数: $unitCount" -ForegroundColor Green

# 2) 全部能力列表
Write-Host "[2/3] 生成全部能力列表..." -ForegroundColor Yellow
$abilOut = Join-Path $OutDir "全部能力列表.txt"
& python $Explorer --list-abilities @modArgs 2>$null | Out-File -FilePath $abilOut -Encoding utf8
$abilCount = (Get-Content $abilOut | Where-Object { $_ -match "^\s*\S" }).Count
Write-Host "  能力总数: $abilCount" -ForegroundColor Green

# 3) 各指挥官关系图
Write-Host "[3/3] 生成各指挥官单位关系图..." -ForegroundColor Yellow
$summary = @()
foreach ($cmd in $Commanders.Keys) {
    $heroUnits = $Commanders[$cmd]
    $cmdOut = Join-Path $OutDir "${cmd}_关系图.txt"

    "=== $cmd 指挥官单位关系图 ===" | Out-File -FilePath $cmdOut -Encoding utf8
    "起始英雄: $($heroUnits -join ', ')" | Out-File -FilePath $cmdOut -Encoding utf8 -Append
    "展开深度: 3" | Out-File -FilePath $cmdOut -Encoding utf8 -Append
    "=" * 60 | Out-File -FilePath $cmdOut -Encoding utf8 -Append
    "" | Out-File -FilePath $cmdOut -Encoding utf8 -Append

    foreach ($hero in $heroUnits) {
        Write-Host "  [$cmd] 展开 $hero ..." -NoNewline -ForegroundColor Gray
        & python $Explorer $hero --depth 3 @modArgs 2>$null | Out-File -FilePath $cmdOut -Encoding utf8 -Append
        "" | Out-File -FilePath $cmdOut -Encoding utf8 -Append
        Write-Host " OK" -ForegroundColor Green
    }

    $size = [math]::Round((Get-Item $cmdOut).Length/1KB, 1)
    Write-Host "  [$cmd] 完成: $size KB" -ForegroundColor Green
    $summary += [PSCustomObject]@{
        指挥官 = $cmd
        起始英雄 = $heroUnits -join ", "
        关系图大小KB = $size
    }
}

# 汇总
$summaryOut = Join-Path $OutDir "汇总.md"
@"
# 重生虫心 各指挥官单位扫描汇总

## mod 信息
- 路径: ``$ModPath``
- 总单位数: $unitCount
- 总能力数: $abilCount

## 15 个指挥官

| 指挥官 | 起始英雄 | 关系图大小 |
|--------|----------|--------|
"@ | Out-File -FilePath $summaryOut -Encoding utf8
foreach ($s in $summary) {
    "| $($s.指挥官) | $($s.起始英雄) | $($s.关系图大小KB) KB |" | Out-File -FilePath $summaryOut -Encoding utf8 -Append
}
@"

## 说明

- 起始单位来源: Lib48DF4533.galaxy 的 ``gt_CommanderStart_Func``，每个指挥官选中后替换 K5Kerrigan
- Raynor 会将玩家种族设为 Terr（人族）
- 关系图展开深度: 3（起始英雄 → 直接生产 → 二级生产）
- 除 Kerrigan 外，所有指挥官的 K5Kerrigan 会被替换为对应英雄单位
- Tosh 指挥官存在但不在 Random 随机池中

## 文件清单
- `全部单位列表.txt`  mod 全部单位 ID + 名称
- `全部能力列表.txt`  mod 全部能力 ID
- `<指挥官>_关系图.txt`  起始单位深度 3 展开关系图
"@ | Out-File -FilePath $summaryOut -Encoding utf8 -Append

Write-Host ""
Write-Host "=== 完成 ===" -ForegroundColor Green
Write-Host "输出目录: $OutDir"
Get-ChildItem $OutDir | Format-Table Name, @{N="Size(KB)";E={[math]::Round($_.Length/1KB,1)}} -AutoSize
