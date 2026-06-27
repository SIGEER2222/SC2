[xml]$xml = Get-Content 'E:\tmp\hexcoop_pvp_0110_unpack\Base.SC2Data\GameData\UserData.xml' -Encoding UTF8

$gameStringsPath = 'E:\tmp\hexcoop_pvp_0110_unpack\zhCN.SC2Data\LocalizedData\GameStrings.txt'
$stringMap = @{}
Get-Content $gameStringsPath -Encoding UTF8 | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        $key = $Matches[1].Trim()
        $val = $Matches[2]
        $stringMap[$key] = $val
    }
}

function Resolve-Text($textRef) {
    if ($textRef -eq '' -or $textRef -eq $null) { return '' }
    if ($stringMap.ContainsKey($textRef)) {
        return $stringMap[$textRef]
    }
    return $textRef
}

$allTalents = @{}
$xml.Catalog.CUser | Where-Object { $_.id -eq 'TNX_Ability_description' } | ForEach-Object {
    $_.Instances | ForEach-Object {
        $id = $_.Id
        $nameRef = ''
        $descRef = ''
        $icon = ''
        $rarity = 0
        $maxCount = 1
        $upgrade = ''

        if ($_.Text) {
            $_.Text | ForEach-Object {
                if ($_.Field.Id -eq '天赋名称') { $nameRef = $_.Text }
                if ($_.Field.Id -eq '天赋效果描述文本') { $descRef = $_.Text }
            }
        }
        if ($_.Image) {
            $_.Image | ForEach-Object {
                if ($_.Field.Id -eq '天赋图标') { $icon = $_.Image }
            }
        }
        if ($_.Int) {
            $_.Int | ForEach-Object {
                if ($_.Field.Id -eq '天赋稀有度') { $rarity = [int]$_.Int }
                if ($_.Field.Id -eq '最大选择次数') { $maxCount = [int]$_.Int }
            }
        }
        if ($_.Upgrade) {
            $_.Upgrade | ForEach-Object {
                if ($_.Field.Id -eq '天赋对应升级') { $upgrade = $_.Upgrade }
            }
        }

        $name = Resolve-Text $nameRef
        $desc = Resolve-Text $descRef
        $desc = $desc -replace '<n/>', "`n  "

        $allTalents[$id] = [PSCustomObject]@{
            Id       = $id
            Name     = $name
            Desc     = $desc
            Icon     = $icon
            Rarity   = $rarity
            MaxCount = $maxCount
            Upgrade  = $upgrade
        }
    }
}

$commonWhite = @()
$commonBlue = @()
$commonRed = @()
$xml.Catalog.CUser | Where-Object { $_.id -eq 'TNX_Ability_List' } | ForEach-Object {
    $_.Instances | ForEach-Object {
        $listId = $_.Id
        if ($_.User) {
            $_.User | ForEach-Object {
                $talentId = $_.Instance
                if ($listId -eq '通用白色天赋') { $commonWhite += $talentId }
                if ($listId -eq '通用蓝色天赋') { $commonBlue += $talentId }
                if ($listId -eq '通用红色天赋') { $commonRed += $talentId }
            }
        }
    }
}

$commanderTalents = @{}
$xml.Catalog.CUser | Where-Object { $_.id -eq 'TNX_Exclusive_Ability_List' } | ForEach-Object {
    $_.Instances | ForEach-Object {
        $commander = $_.Id
        if ($commander -eq '[Default]') { return }
        $white = @()
        $blue = @()
        $red = @()
        if ($_.User) {
            $_.User | ForEach-Object {
                $talentId = $_.Instance
                $field = $_.Field.Id
                if ($field -eq '白色天赋列表' -and $talentId -ne '[Default]') { $white += $talentId }
                if ($field -eq '蓝色天赋列表' -and $talentId -ne '[Default]') { $blue += $talentId }
                if ($field -eq '红色天赋列表' -and $talentId -ne '[Default]') { $red += $talentId }
            }
        }
        $commanderTalents[$commander] = [PSCustomObject]@{
            White = $white
            Blue  = $blue
            Red   = $red
        }
    }
}

$output = @()
$output += '# 海克斯合作PVP 天赋全览'
$output += ''
$output += '数据源：海克斯合作PVP 0.110 - UserData.xml + zhCN GameStrings.txt'
$output += ''

$output += '## 一、通用天赋'
$output += ''
$output += ('### 白色（普通） - 共 ' + $commonWhite.Count + ' 个')
$output += ''
$i = 1
foreach ($t in $commonWhite) {
    if ($allTalents.ContainsKey($t)) {
        $tal = $allTalents[$t]
        $displayName = if ($tal.Name) { $tal.Name } else { $t }
        $output += ($i.ToString() + '. **' + $displayName + '** (`' + $t + '`)')
        if ($tal.Desc) {
            $output += ('   - 效果: ' + $tal.Desc)
        }
        $output += ('   - 最大选择: ' + $tal.MaxCount + '次')
        if ($tal.Upgrade) {
            $output += ('   - 关联升级: ' + $tal.Upgrade)
        }
        $output += ''
        $i++
    }
}

$output += ('### 蓝色（稀有） - 共 ' + $commonBlue.Count + ' 个')
$output += ''
$i = 1
foreach ($t in $commonBlue) {
    if ($allTalents.ContainsKey($t)) {
        $tal = $allTalents[$t]
        $displayName = if ($tal.Name) { $tal.Name } else { $t }
        $output += ($i.ToString() + '. **' + $displayName + '** (`' + $t + '`)')
        if ($tal.Desc) {
            $output += ('   - 效果: ' + $tal.Desc)
        }
        $output += ('   - 最大选择: ' + $tal.MaxCount + '次')
        if ($tal.Upgrade) {
            $output += ('   - 关联升级: ' + $tal.Upgrade)
        }
        $output += ''
        $i++
    }
}

$output += ('### 红色（传说） - 共 ' + $commonRed.Count + ' 个')
$output += ''
$i = 1
foreach ($t in $commonRed) {
    if ($allTalents.ContainsKey($t)) {
        $tal = $allTalents[$t]
        $displayName = if ($tal.Name) { $tal.Name } else { $t }
        $output += ($i.ToString() + '. **' + $displayName + '** (`' + $t + '`)')
        if ($tal.Desc) {
            $output += ('   - 效果: ' + $tal.Desc)
        }
        $output += ('   - 最大选择: ' + $tal.MaxCount + '次')
        if ($tal.Upgrade) {
            $output += ('   - 关联升级: ' + $tal.Upgrade)
        }
        $output += ''
        $i++
    }
}

$output += '## 二、指挥官专属天赋'
$output += ''
$commanderNames = $commanderTalents.Keys | Sort-Object
foreach ($commander in $commanderNames) {
    $ct = $commanderTalents[$commander]
    $total = $ct.White.Count + $ct.Blue.Count + $ct.Red.Count
    $output += ('### ' + $commander + '（共 ' + $total + ' 个）')
    $output += ''
    if ($ct.White.Count -gt 0) {
        $output += ('**白色 (' + $ct.White.Count + '):**')
        $output += ''
        foreach ($t in $ct.White) {
            if ($allTalents.ContainsKey($t)) {
                $tal = $allTalents[$t]
                $displayName = if ($tal.Name) { $tal.Name } else { $t }
                $output += ('- **' + $displayName + '** (`' + $t + '`)')
                if ($tal.Desc) {
                    $output += ('  - 效果: ' + $tal.Desc)
                }
                $output += ('  - 最大' + $tal.MaxCount + '次')
                if ($tal.Upgrade) {
                    $output += ('  - 升级: ' + $tal.Upgrade)
                }
            }
            else {
                $output += ('- ' + $t)
            }
            $output += ''
        }
    }
    if ($ct.Blue.Count -gt 0) {
        $output += ('**蓝色 (' + $ct.Blue.Count + '):**')
        $output += ''
        foreach ($t in $ct.Blue) {
            if ($allTalents.ContainsKey($t)) {
                $tal = $allTalents[$t]
                $displayName = if ($tal.Name) { $tal.Name } else { $t }
                $output += ('- **' + $displayName + '** (`' + $t + '`)')
                if ($tal.Desc) {
                    $output += ('  - 效果: ' + $tal.Desc)
                }
                $output += ('  - 最大' + $tal.MaxCount + '次')
                if ($tal.Upgrade) {
                    $output += ('  - 升级: ' + $tal.Upgrade)
                }
            }
            else {
                $output += ('- ' + $t)
            }
            $output += ''
        }
    }
    if ($ct.Red.Count -gt 0) {
        $output += ('**红色 (' + $ct.Red.Count + '):**')
        $output += ''
        foreach ($t in $ct.Red) {
            if ($allTalents.ContainsKey($t)) {
                $tal = $allTalents[$t]
                $displayName = if ($tal.Name) { $tal.Name } else { $t }
                $output += ('- **' + $displayName + '** (`' + $t + '`)')
                if ($tal.Desc) {
                    $output += ('  - 效果: ' + $tal.Desc)
                }
                $output += ('  - 最大' + $tal.MaxCount + '次')
                if ($tal.Upgrade) {
                    $output += ('  - 升级: ' + $tal.Upgrade)
                }
            }
            else {
                $output += ('- ' + $t)
            }
            $output += ''
        }
    }
}

$output += '## 三、有明确升级关联的天赋汇总'
$output += ''
$output += '| 天赋ID | 中文名 | 关联升级 | 稀有度 | 最大选择次数 |'
$output += '|--------|--------|----------|--------|-------------|'
foreach ($tal in ($allTalents.Values | Sort-Object Id)) {
    if ($tal.Upgrade -ne '' -and $tal.Upgrade -ne $null) {
        $rarityStr = '白'
        if ($tal.Rarity -eq 1) { $rarityStr = '蓝' }
        if ($tal.Rarity -eq 2) { $rarityStr = '红' }
        $displayName = if ($tal.Name) { $tal.Name } else { '-' }
        $output += ('| ' + $tal.Id + ' | ' + $displayName + ' | ' + $tal.Upgrade + ' | ' + $rarityStr + ' | ' + $tal.MaxCount + ' |')
    }
}

$output | Out-File -FilePath 'E:\Code\MyMod\SC2\合作指挥官-起义狂潮\docs\海克斯天赋全览.md' -Encoding UTF8
Write-Host 'Done!'
Write-Host ('Total talents: ' + $allTalents.Count)
Write-Host ('Common white: ' + $commonWhite.Count)
Write-Host ('Common blue: ' + $commonBlue.Count)
Write-Host ('Common red: ' + $commonRed.Count)
Write-Host ('Commanders: ' + $commanderTalents.Count)
Write-Host ('GameStrings entries: ' + $stringMap.Count)
