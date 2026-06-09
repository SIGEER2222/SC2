<#
.SYNOPSIS
Local WinForms launcher for the 7vs1 coop commander test maps.

.DESCRIPTION
Collects commander, map, mastery, prestige, and mutator choices, then invokes
launch-7vs1-coop-test.ps1. The launcher does not implement its own map install
or bank write path; it delegates to the existing tested script.
#>
[CmdletBinding()]
param(
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$script:LaunchScript = Join-Path $PSScriptRoot "launch-7vs1-coop-test.ps1"
$script:MetadataPath = Join-Path $script:WorkspaceRoot "Shared\CommanderPower\commander-power-metadata.json"
$script:MapsRoot = Join-Path $script:WorkspaceRoot "Maps"
$script:LogsRoot = Join-Path $script:WorkspaceRoot "logs"
. (Join-Path $PSScriptRoot "commander-power-metadata.ps1")

if (-not (Test-Path -LiteralPath $script:LaunchScript)) {
    throw "Launch script not found: $script:LaunchScript"
}
if (-not (Test-Path -LiteralPath $script:MetadataPath)) {
    throw "Commander metadata not found: $script:MetadataPath"
}
if (-not (Test-Path -LiteralPath $script:LogsRoot)) {
    New-Item -ItemType Directory -Path $script:LogsRoot | Out-Null
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

function Get-CommanderItems {
    $metadata = Get-Content -LiteralPath $script:MetadataPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $items = foreach ($commander in $metadata.commanders) {
        $displayName = [string]$commander.display_name
        $runtime = [string]$commander.runtime_commander
        if ([string]::IsNullOrWhiteSpace($displayName)) {
            $displayName = $runtime
        }

        [pscustomobject]@{
            Label = "$displayName ($runtime)"
            Runtime = $runtime
            Record = $commander
        }
    }

    return @($items | Sort-Object Label)
}

function Get-MapItems {
    if (-not (Test-Path -LiteralPath $script:MapsRoot)) {
        throw "Maps folder not found: $script:MapsRoot"
    }

    return @(Get-ChildItem -LiteralPath $script:MapsRoot -Directory -Filter "*_7vs1.SC2Map" |
        Sort-Object Name |
        ForEach-Object {
            [pscustomobject]@{
                Label = $_.Name
                Name = $_.Name
                FullName = $_.FullName
            }
        })
}

function New-Label {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 120,
        [int]$Height = 24
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, $Height)
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    return $label
}

function New-Numeric {
    param(
        [int]$X,
        [int]$Y,
        [int]$Minimum = 0,
        [int]$Maximum = 30,
        [int]$Value = 30,
        [int]$Width = 70
    )

    $numeric = New-Object System.Windows.Forms.NumericUpDown
    $numeric.Location = New-Object System.Drawing.Point($X, $Y)
    $numeric.Size = New-Object System.Drawing.Size($Width, 24)
    $numeric.Minimum = $Minimum
    $numeric.Maximum = $Maximum
    $numeric.Value = [Math]::Max($Minimum, [Math]::Min($Maximum, $Value))
    return $numeric
}

function ConvertTo-ArgumentList {
    param(
        [string]$MapSource,
        [string]$LiveMapName,
        [string]$Commander,
        [int]$MasteryLevel,
        [int[]]$Masteries,
        [int]$EnableMasteries,
        [int]$EnablePrestiges,
        [int]$PrestigeBonusMask,
        [int]$PrestigePointIndex,
        [string[]]$Mutators,
        [int]$MutatorPreset,
        [bool]$NoLaunch
    )

    $args = New-Object System.Collections.Generic.List[string]
    $args.Add("-NoProfile")
    $args.Add("-ExecutionPolicy")
    $args.Add("Bypass")
    $args.Add("-File")
    $args.Add($script:LaunchScript)
    $args.Add("-MapSource")
    $args.Add($MapSource)
    $args.Add("-LiveMapName")
    $args.Add($LiveMapName)
    $args.Add("-Commanders")
    $args.Add($Commander)
    $args.Add("-CommanderPowerMasteryLevel")
    $args.Add([string]$MasteryLevel)
    $args.Add("-CommanderPowerEnableMasteries")
    $args.Add([string]$EnableMasteries)
    $args.Add("-CommanderPowerEnablePrestiges")
    $args.Add([string]$EnablePrestiges)
    $args.Add("-CommanderPowerPrestigeBonusMask")
    $args.Add([string]$PrestigeBonusMask)
    $args.Add("-CommanderPowerPrestigePointIndex")
    $args.Add([string]$PrestigePointIndex)

    for ($i = 0; $i -lt 6; $i++) {
        $args.Add("-CommanderPowerMastery$i")
        $args.Add([string]$Masteries[$i])
    }

    if ($Mutators.Count -gt 0) {
        $args.Add("-Mutators")
        $args.Add(($Mutators -join ","))
    }

    $args.Add("-MutatorPreset")
    $args.Add([string]$MutatorPreset)

    if ($NoLaunch) {
        $args.Add("-NoLaunch")
    }

    return $args.ToArray()
}

$commanders = Get-CommanderItems
$maps = Get-MapItems
$mutatorIds = Get-MutatorIdsFromLaunchScript

if ($SelfTest) {
    if ($commanders.Count -eq 0) {
        throw "No commanders loaded."
    }
    if ($maps.Count -eq 0) {
        throw "No maps loaded."
    }
    if ($mutatorIds.Count -eq 0) {
        throw "No mutators loaded."
    }

    $sampleArgs = ConvertTo-ArgumentList `
        -MapSource $maps[0].FullName `
        -LiveMapName $maps[0].Name `
        -Commander $commanders[0].Runtime `
        -MasteryLevel 30 `
        -Masteries @(30, 30, 30, 30, 30, 30) `
        -EnableMasteries 1 `
        -EnablePrestiges 1 `
        -PrestigeBonusMask 7 `
        -PrestigePointIndex -1 `
        -Mutators @($mutatorIds | Select-Object -First 3) `
        -MutatorPreset 0 `
        -NoLaunch $true

    [pscustomobject]@{
        Commanders = $commanders.Count
        Maps = $maps.Count
        Mutators = $mutatorIds.Count
        SampleCommander = $commanders[0].Runtime
        SampleMap = $maps[0].Name
        SampleMutators = (($mutatorIds | Select-Object -First 3) -join ",")
        SampleCommand = "pwsh " + ($sampleArgs -join " ")
    } | Format-List
    return
}

[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = "7vs1 Coop Launcher"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(1060, 760)
$form.MinimumSize = New-Object System.Drawing.Size(980, 700)
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

$leftGroup = New-Object System.Windows.Forms.GroupBox
$leftGroup.Text = "基础设置"
$leftGroup.Location = New-Object System.Drawing.Point(12, 12)
$leftGroup.Size = New-Object System.Drawing.Size(500, 190)
$form.Controls.Add($leftGroup)

$leftGroup.Controls.Add((New-Label "地图" 16 32 80))
$mapCombo = New-Object System.Windows.Forms.ComboBox
$mapCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$mapCombo.Location = New-Object System.Drawing.Point(96, 32)
$mapCombo.Size = New-Object System.Drawing.Size(370, 28)
$mapCombo.DataSource = $maps
$mapCombo.DisplayMember = "Label"
$leftGroup.Controls.Add($mapCombo)

$leftGroup.Controls.Add((New-Label "指挥官" 16 72 80))
$commanderCombo = New-Object System.Windows.Forms.ComboBox
$commanderCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$commanderCombo.Location = New-Object System.Drawing.Point(96, 72)
$commanderCombo.Size = New-Object System.Drawing.Size(370, 28)
$commanderCombo.DataSource = $commanders
$commanderCombo.DisplayMember = "Label"
$leftGroup.Controls.Add($commanderCombo)

$enableMasteries = New-Object System.Windows.Forms.CheckBox
$enableMasteries.Text = "启用精通"
$enableMasteries.Checked = $true
$enableMasteries.Location = New-Object System.Drawing.Point(96, 112)
$enableMasteries.Size = New-Object System.Drawing.Size(100, 24)
$leftGroup.Controls.Add($enableMasteries)

$leftGroup.Controls.Add((New-Label "精通等级" 220 112 80))
$masteryLevel = New-Numeric 300 112 0 90 30 70
$leftGroup.Controls.Add($masteryLevel)

$noLaunch = New-Object System.Windows.Forms.CheckBox
$noLaunch.Text = "只安装不启动"
$noLaunch.Checked = $false
$noLaunch.Location = New-Object System.Drawing.Point(96, 148)
$noLaunch.Size = New-Object System.Drawing.Size(130, 24)
$leftGroup.Controls.Add($noLaunch)

$prestigeGroup = New-Object System.Windows.Forms.GroupBox
$prestigeGroup.Text = "威望"
$prestigeGroup.Location = New-Object System.Drawing.Point(530, 12)
$prestigeGroup.Size = New-Object System.Drawing.Size(500, 190)
$form.Controls.Add($prestigeGroup)

$enablePrestiges = New-Object System.Windows.Forms.CheckBox
$enablePrestiges.Text = "启用威望奖励"
$enablePrestiges.Checked = $true
$enablePrestiges.Location = New-Object System.Drawing.Point(16, 32)
$enablePrestiges.Size = New-Object System.Drawing.Size(130, 24)
$prestigeGroup.Controls.Add($enablePrestiges)

$prestigeGroup.Controls.Add((New-Label "奖励掩码" 16 68 80))
$prestigeMask = New-Numeric 96 68 0 7 7 70
$prestigeGroup.Controls.Add($prestigeMask)

$prestigeGroup.Controls.Add((New-Label "当前威望" 190 68 80))
$prestigeIndex = New-Object System.Windows.Forms.ComboBox
$prestigeIndex.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$prestigeIndex.Location = New-Object System.Drawing.Point(270, 68)
$prestigeIndex.Size = New-Object System.Drawing.Size(190, 28)
$prestigeIndex.Items.Add("不指定 (-1)") | Out-Null
$prestigeIndex.Items.Add("P0 默认 (0)") | Out-Null
$prestigeIndex.Items.Add("P1 (1)") | Out-Null
$prestigeIndex.Items.Add("P2 (2)") | Out-Null
$prestigeIndex.Items.Add("P3 (3)") | Out-Null
$prestigeIndex.SelectedIndex = 0
$prestigeGroup.Controls.Add($prestigeIndex)

$prestigeInfo = New-Object System.Windows.Forms.TextBox
$prestigeInfo.Location = New-Object System.Drawing.Point(16, 108)
$prestigeInfo.Size = New-Object System.Drawing.Size(444, 58)
$prestigeInfo.Multiline = $true
$prestigeInfo.ReadOnly = $true
$prestigeInfo.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$prestigeGroup.Controls.Add($prestigeInfo)

$masteryGroup = New-Object System.Windows.Forms.GroupBox
$masteryGroup.Text = "精通加点"
$masteryGroup.Location = New-Object System.Drawing.Point(12, 212)
$masteryGroup.Size = New-Object System.Drawing.Size(500, 270)
$form.Controls.Add($masteryGroup)

$masteryLabels = New-Object System.Collections.Generic.List[System.Windows.Forms.Label]
$masteryInputs = New-Object System.Collections.Generic.List[System.Windows.Forms.NumericUpDown]
for ($i = 0; $i -lt 6; $i++) {
    $y = 30 + ($i * 34)
    $label = New-Label "Mastery $i" 16 $y 330
    $input = New-Numeric 370 $y 0 30 30 70
    $masteryGroup.Controls.Add($label)
    $masteryGroup.Controls.Add($input)
    $masteryLabels.Add($label)
    $masteryInputs.Add($input)
}

$setAllMasteries = New-Object System.Windows.Forms.Button
$setAllMasteries.Text = "全部 30"
$setAllMasteries.Location = New-Object System.Drawing.Point(16, 234)
$setAllMasteries.Size = New-Object System.Drawing.Size(90, 28)
$masteryGroup.Controls.Add($setAllMasteries)

$clearMasteries = New-Object System.Windows.Forms.Button
$clearMasteries.Text = "清零"
$clearMasteries.Location = New-Object System.Drawing.Point(116, 234)
$clearMasteries.Size = New-Object System.Drawing.Size(90, 28)
$masteryGroup.Controls.Add($clearMasteries)

$mutatorGroup = New-Object System.Windows.Forms.GroupBox
$mutatorGroup.Text = "因子"
$mutatorGroup.Location = New-Object System.Drawing.Point(530, 212)
$mutatorGroup.Size = New-Object System.Drawing.Size(500, 380)
$form.Controls.Add($mutatorGroup)

$mutatorSearch = New-Object System.Windows.Forms.TextBox
$mutatorSearch.Location = New-Object System.Drawing.Point(16, 28)
$mutatorSearch.Size = New-Object System.Drawing.Size(300, 26)
$mutatorGroup.Controls.Add($mutatorSearch)

$mutatorPresetLabel = New-Label "预设" 330 28 40
$mutatorGroup.Controls.Add($mutatorPresetLabel)
$mutatorPreset = New-Object System.Windows.Forms.ComboBox
$mutatorPreset.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$mutatorPreset.Location = New-Object System.Drawing.Point(372, 28)
$mutatorPreset.Size = New-Object System.Drawing.Size(90, 28)
foreach ($value in 0..3) {
    $mutatorPreset.Items.Add([string]$value) | Out-Null
}
$mutatorPreset.SelectedIndex = 0
$mutatorGroup.Controls.Add($mutatorPreset)

$mutatorList = New-Object System.Windows.Forms.CheckedListBox
$mutatorList.CheckOnClick = $true
$mutatorList.Location = New-Object System.Drawing.Point(16, 64)
$mutatorList.Size = New-Object System.Drawing.Size(446, 260)
$mutatorGroup.Controls.Add($mutatorList)

$mutatorButtonsY = 334
$selectVisibleMutators = New-Object System.Windows.Forms.Button
$selectVisibleMutators.Text = "选中可见"
$selectVisibleMutators.Location = New-Object System.Drawing.Point(16, $mutatorButtonsY)
$selectVisibleMutators.Size = New-Object System.Drawing.Size(90, 28)
$mutatorGroup.Controls.Add($selectVisibleMutators)

$clearMutators = New-Object System.Windows.Forms.Button
$clearMutators.Text = "清空因子"
$clearMutators.Location = New-Object System.Drawing.Point(116, $mutatorButtonsY)
$clearMutators.Size = New-Object System.Drawing.Size(90, 28)
$mutatorGroup.Controls.Add($clearMutators)

$selectedMutatorCount = New-Label "已选 0" 226 $mutatorButtonsY 120
$mutatorGroup.Controls.Add($selectedMutatorCount)

$commandBox = New-Object System.Windows.Forms.TextBox
$commandBox.Location = New-Object System.Drawing.Point(12, 600)
$commandBox.Size = New-Object System.Drawing.Size(1018, 54)
$commandBox.Multiline = $true
$commandBox.ReadOnly = $true
$commandBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$form.Controls.Add($commandBox)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "开始游戏"
$startButton.Location = New-Object System.Drawing.Point(12, 666)
$startButton.Size = New-Object System.Drawing.Size(120, 34)
$form.Controls.Add($startButton)

$previewButton = New-Object System.Windows.Forms.Button
$previewButton.Text = "刷新命令"
$previewButton.Location = New-Object System.Drawing.Point(144, 666)
$previewButton.Size = New-Object System.Drawing.Size(100, 34)
$form.Controls.Add($previewButton)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "就绪"
$statusLabel.Location = New-Object System.Drawing.Point(260, 672)
$statusLabel.Size = New-Object System.Drawing.Size(760, 24)
$statusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$form.Controls.Add($statusLabel)

$script:MutatorChecked = @{}
foreach ($id in $mutatorIds) {
    $script:MutatorChecked[$id] = $false
}

function Refresh-MutatorList {
    $filter = $mutatorSearch.Text.Trim()
    $mutatorList.Items.Clear()
    foreach ($id in $mutatorIds) {
        if (($filter.Length -gt 0) -and ($id.IndexOf($filter, [System.StringComparison]::OrdinalIgnoreCase) -lt 0)) {
            continue
        }
        $index = $mutatorList.Items.Add($id)
        $mutatorList.SetItemChecked($index, [bool]$script:MutatorChecked[$id])
    }
}

function Get-SelectedMutators {
    return @($script:MutatorChecked.GetEnumerator() |
        Where-Object { $_.Value } |
        Sort-Object Name |
        ForEach-Object { $_.Name })
}

function Update-MutatorCount {
    $selectedMutatorCount.Text = "已选 $((Get-SelectedMutators).Count)"
}

function Get-SelectedPrestigePointIndex {
    switch ($prestigeIndex.SelectedIndex) {
        0 { return -1 }
        1 { return 0 }
        2 { return 1 }
        3 { return 2 }
        4 { return 3 }
        default { return -1 }
    }
}

function Update-CommanderDetails {
    $item = $commanderCombo.SelectedItem
    if ($null -eq $item) {
        return
    }

    $record = $item.Record
    $masteries = @($record.masteries)
    for ($i = 0; $i -lt 6; $i++) {
        if ($i -lt $masteries.Count) {
            $name = [string]$masteries[$i].name
            if ([string]::IsNullOrWhiteSpace($name)) {
                $name = [string]$masteries[$i].id
            }
            $category = [string]$masteries[$i].category
            $masteryLabels[$i].Text = "槽 $i / 组 $category：$name"
        }
        else {
            $masteryLabels[$i].Text = "槽 $i"
        }
    }

    $prestigeLines = New-Object System.Collections.Generic.List[string]
    foreach ($prestige in @($record.prestiges)) {
        $slot = [int]$prestige.slot + 1
        $name = [string]$prestige.name
        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = [string]$prestige.id
        }
        $prestigeLines.Add(("P{0}: {1}" -f $slot, $name))
    }
    $prestigeInfo.Text = ($prestigeLines -join [Environment]::NewLine)

    $prestigeMask.Value = Get-CommanderPowerDefaultPrestigeBonusMask -Commander ([string]$record.runtime_commander) -WorkspaceRoot $script:WorkspaceRoot
}

function Get-CurrentArguments {
    $map = $mapCombo.SelectedItem
    $commander = $commanderCombo.SelectedItem
    if (($null -eq $map) -or ($null -eq $commander)) {
        return @()
    }

    $masteries = for ($i = 0; $i -lt 6; $i++) {
        [int]$masteryInputs[$i].Value
    }

    return ConvertTo-ArgumentList `
        -MapSource $map.FullName `
        -LiveMapName $map.Name `
        -Commander $commander.Runtime `
        -MasteryLevel ([int]$masteryLevel.Value) `
        -Masteries $masteries `
        -EnableMasteries ($(if ($enableMasteries.Checked) { 1 } else { 0 })) `
        -EnablePrestiges ($(if ($enablePrestiges.Checked) { 1 } else { 0 })) `
        -PrestigeBonusMask ([int]$prestigeMask.Value) `
        -PrestigePointIndex (Get-SelectedPrestigePointIndex) `
        -Mutators (Get-SelectedMutators) `
        -MutatorPreset ([int]$mutatorPreset.SelectedItem) `
        -NoLaunch $noLaunch.Checked
}

function Update-CommandPreview {
    $args = Get-CurrentArguments
    $quoted = foreach ($arg in $args) {
        if ($arg -match '[\s()]') {
            '"' + ($arg -replace '"', '\"') + '"'
        }
        else {
            $arg
        }
    }
    $commandBox.Text = "pwsh " + ($quoted -join " ")
}

$commanderCombo.Add_SelectedIndexChanged({
        Update-CommanderDetails
        Update-CommandPreview
    })

$mapCombo.Add_SelectedIndexChanged({ Update-CommandPreview })
$masteryLevel.Add_ValueChanged({ Update-CommandPreview })
$enableMasteries.Add_CheckedChanged({ Update-CommandPreview })
$enablePrestiges.Add_CheckedChanged({ Update-CommandPreview })
$prestigeMask.Add_ValueChanged({ Update-CommandPreview })
$prestigeIndex.Add_SelectedIndexChanged({ Update-CommandPreview })
$mutatorPreset.Add_SelectedIndexChanged({ Update-CommandPreview })
$noLaunch.Add_CheckedChanged({ Update-CommandPreview })
foreach ($input in $masteryInputs) {
    $input.Add_ValueChanged({ Update-CommandPreview })
}

$setAllMasteries.Add_Click({
        foreach ($input in $masteryInputs) {
            $input.Value = 30
        }
        Update-CommandPreview
    })

$clearMasteries.Add_Click({
        foreach ($input in $masteryInputs) {
            $input.Value = 0
        }
        Update-CommandPreview
    })

$mutatorSearch.Add_TextChanged({
        Refresh-MutatorList
    })

$mutatorList.Add_ItemCheck({
        param($sender, $eventArgs)
        $id = [string]$sender.Items[$eventArgs.Index]
        $script:MutatorChecked[$id] = ($eventArgs.NewValue -eq [System.Windows.Forms.CheckState]::Checked)
        $form.BeginInvoke([Action]{
                Update-MutatorCount
                Update-CommandPreview
            }) | Out-Null
    })

$selectVisibleMutators.Add_Click({
        for ($i = 0; $i -lt $mutatorList.Items.Count; $i++) {
            $id = [string]$mutatorList.Items[$i]
            $script:MutatorChecked[$id] = $true
            $mutatorList.SetItemChecked($i, $true)
        }
        Update-MutatorCount
        Update-CommandPreview
    })

$clearMutators.Add_Click({
        foreach ($id in @($script:MutatorChecked.Keys)) {
            $script:MutatorChecked[$id] = $false
        }
        Refresh-MutatorList
        Update-MutatorCount
        Update-CommandPreview
    })

$previewButton.Add_Click({ Update-CommandPreview })

$startButton.Add_Click({
        try {
            $args = Get-CurrentArguments
            if ($args.Count -eq 0) {
                throw "No launch arguments were generated."
            }

            $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $stdout = Join-Path $script:LogsRoot "launcher-$stamp.stdout.txt"
            $stderr = Join-Path $script:LogsRoot "launcher-$stamp.stderr.txt"
            $process = Start-Process -FilePath "pwsh" `
                -ArgumentList $args `
                -RedirectStandardOutput $stdout `
                -RedirectStandardError $stderr `
                -PassThru `
                -WindowStyle Hidden

            $statusLabel.Text = "已启动 pid=$($process.Id) stdout=$stdout stderr=$stderr"
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                $_.Exception.Message,
                "启动失败",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    })

Refresh-MutatorList
Update-MutatorCount
Update-CommanderDetails
Update-CommandPreview

[void][System.Windows.Forms.Application]::Run($form)
