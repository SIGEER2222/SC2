[CmdletBinding()]
param(
    [string]$MapsRoot = "",
    [string]$ExpectedBankCommander = "",
    [switch]$CheckLiveBankCommander,
    [switch]$FailOnMismatch
)

$ErrorActionPreference = "Stop"

function Resolve-WorkspacePath {
    param([string]$Path)

    $workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot "Maps"))
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot $Path))
}

function Assert-Contains {
    param(
        [System.Collections.Generic.List[string]]$Failures,
        [string]$Text,
        [string]$Needle,
        [string]$Message
    )

    if (-not $Text.Contains($Needle)) {
        $Failures.Add($Message) | Out-Null
    }
}

function Assert-Regex {
    param(
        [System.Collections.Generic.List[string]]$Failures,
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -notmatch $Pattern) {
        $Failures.Add($Message) | Out-Null
    }
}

function Test-BankListHasCampaignXCore {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    return [bool]($xml.SelectSingleNode('/BankList/Bank[@Name="CampaignXCore" and @Player="1"]'))
}

function Get-CampaignXCoreBankPaths {
    $paths = New-Object System.Collections.Generic.List[string]

    $liveBank = Join-Path $env:USERPROFILE "Documents\StarCraft II\Banks\CampaignXCore.SC2Bank"
    if (Test-Path -LiteralPath $liveBank) {
        $paths.Add((Resolve-Path -LiteralPath $liveBank).Path)
    }

    $accountsRoot = Join-Path $env:USERPROFILE "Documents\StarCraft II\Accounts"
    if (Test-Path -LiteralPath $accountsRoot) {
        $accountBanks = Get-ChildItem -LiteralPath $accountsRoot -Recurse -File -Filter "CampaignXCore.SC2Bank" |
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

function Get-BankString {
    param(
        [string]$Path,
        [string]$Section,
        [string]$Key
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }

    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    $node = $xml.SelectSingleNode("/Bank/Section[@name='$Section']/Key[@name='$Key']/Value")
    if (-not $node) {
        return ""
    }

    return [string]$node.GetAttribute("string")
}

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sharedBase = Join-Path $workspaceRoot 'Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data'
$sharedMainPath = Join-Path $sharedBase 'LibE0EAE146.galaxy'
$sharedHeaderPath = Join-Path $sharedBase 'LibE0EAE146_h.galaxy'
$sharedRewardsPath = Join-Path $sharedBase 'LibE0EAE146_ProgressionRewards.galaxy'
$resolvedMapsRoot = Resolve-WorkspacePath -Path $MapsRoot

if (-not (Test-Path -LiteralPath $sharedMainPath)) {
    throw "Shared main lib not found: $sharedMainPath"
}
if (-not (Test-Path -LiteralPath $sharedHeaderPath)) {
    throw "Shared header not found: $sharedHeaderPath"
}
if (-not (Test-Path -LiteralPath $sharedRewardsPath)) {
    throw "Shared reward lib not found: $sharedRewardsPath"
}
if (-not (Test-Path -LiteralPath $resolvedMapsRoot)) {
    throw "MapsRoot not found: $resolvedMapsRoot"
}

$failures = New-Object System.Collections.Generic.List[string]
$sharedMain = Get-Content -LiteralPath $sharedMainPath -Raw
$sharedHeader = Get-Content -LiteralPath $sharedHeaderPath -Raw
$sharedRewards = Get-Content -LiteralPath $sharedRewardsPath -Raw

Assert-Contains -Failures $failures -Text $sharedMain -Needle 'include "LibE0EAE146_ProgressionRewards"' -Message 'Shared LibE0EAE146 must include LibE0EAE146_ProgressionRewards.'
Assert-Contains -Failures $failures -Text $sharedMain -Needle 'XMProgression_Init(1);' -Message 'Initialize must load reward/achievement progression from CampaignXCore.'
Assert-Contains -Failures $failures -Text $sharedMain -Needle 'XMBlessing_ApplySelected(1);' -Message 'StartGame must apply selected blessing after map runtime starts.'
Assert-Contains -Failures $failures -Text $sharedMain -Needle 'XMProgression_RecordVictory(1, lv_map, libE0EAE146_gv_commander, libE0EAE146_gv_bon, libE0EAE146_gv_commanderHeroDeathCount);' -Message 'FinishLevel must record victory rewards before the victory panel transition.'

foreach ($signature in @(
    'void XMProgression_Init (int lp_player);',
    'void XMBlessing_ApplySelected (int lp_player);',
    'void XMChallenge_ResetRuntimeState (int lp_player);',
    'bool XMChallenge_IsLoneHeroForbiddenUnit (unit lp_unit, int lp_player);',
    'int XMChallenge_CountCombatUnits (int lp_player, bool lp_mechanicalOnly);',
    'void XMChallenge_EvaluateOnVictoryEx (int lp_player, string lp_mapId, string lp_commanderId, int lp_bonusScore, int lp_heroDeaths);',
    'void XMProgression_RecordVictory (int lp_player, string lp_mapId, string lp_commanderId, int lp_bonusScore, int lp_heroDeaths);',
    'void XMReward_Unlock (int lp_player, string lp_rewardId);'
)) {
    Assert-Contains -Failures $failures -Text $sharedHeader -Needle $signature -Message ("Shared header missing reward declaration: {0}" -f $signature)
}

foreach ($needle in @(
    'BankValueSetFromInt(BankLastCreated(), "Achievement"',
    'BankValueSetFromInt(BankLastCreated(), "AchievementProgress"',
    'BankValueSetFromInt(BankLastCreated(), "Blessing"',
    'BankValueSetFromString(BankLastCreated(), "Blessing", "Selected"',
    'BankValueSetFromString(BankLastCreated(), "Challenge", "Active"',
    'BankValueSetFromInt(BankLastCreated(), "ChallengeBest"',
    'BankValueSetFromInt(BankLastCreated(), "Reward"',
    'BankValueSetFromInt(BankLastCreated(), "Progression", "TotalWins"',
    'BankValueSetFromInt(BankLastCreated(), "MapClear"',
    'BankValueSetFromInt(BankLastCreated(), "CommanderClear"',
    'BankValueSetFromInt(BankLastCreated(), "CommanderBonus"'
)) {
    Assert-Contains -Failures $failures -Text $sharedRewards -Needle $needle -Message ("Reward lib missing bank write/read contract: {0}" -f $needle)
}

if ($sharedRewards.Contains('BankValueSetFromInt(BankLastCreated(), "Progression", "ObjectiveState"') -eq $false -and $sharedRewards.Contains('ObjectiveState') -eq $true) {
    $failures.Add('Reward lib references ObjectiveState but missing expected bank write pattern.') | Out-Null
}

foreach ($needle in @(
    'XMChallenge_ResetRuntimeState(lp_player);',
    'TriggerAddEventUnitCreated(libE0EAE146_gt_XMChallengeUnitCreated, null, null, null);',
    'TriggerAddEventUnitTrainProgress(libE0EAE146_gt_XMChallengeUnitTrainComplete, null, c_unitProgressStageComplete);',
    'TriggerAddEventUnitConstructProgress(libE0EAE146_gt_XMChallengeUnitConstructComplete, null, c_unitProgressStageComplete);',
    'TriggerAddEventUnitAbility(libE0EAE146_gt_XMChallengeUnitMorphComplete, null, null, c_abilMorphStageUnitEnd, false);',
    'if (lv_challenge == "ChallengeLoneHero")',
    'if (!libE0EAE146_gv_xmChallengeLoneHeroFailed[lp_player])',
    'XMAchievement_Unlock(lp_player, "ACH_CHALLENGE_LONE_HERO_CLEAR");',
    'else if (lv_challenge == "ChallengeSteelTorrent")',
    'XMAchievement_Unlock(lp_player, "ACH_CHALLENGE_STEEL_TORRENT_CLEAR");',
    'XMChallenge_CountCombatUnits(lp_player, true) >= 20',
    'else if (lv_challenge == "ChallengeFirepowerCoverage")',
    'XMAchievement_Unlock(lp_player, "ACH_CHALLENGE_FIREPOWER_COVERAGE_CLEAR");',
    'XMChallenge_CountCombatUnits(lp_player, false) >= 35'
)) {
    Assert-Contains -Failures $failures -Text $sharedRewards -Needle $needle -Message ("Reward lib missing challenge runtime closure: {0}" -f $needle)
}

foreach ($needle in @(
    'libE0EAE146_gv_xmProgressionRunBlessingApplied[lp_player]',
    'PlayerModifyPropertyInt(lp_player, c_playerPropMinerals, c_playerPropOperAdd, lp_minerals);',
    'PlayerModifyPropertyInt(lp_player, c_playerPropVespene, c_playerPropOperAdd, lp_vespene);',
    'if (lv_selected == "BlessingResourceRich")',
    'else if (lv_selected == "BlessingGoldenMinerals")',
    'else if (lv_selected == "BlessingGuardianShell")',
    'libE0EAE146_gf_XMProgression_GuardianShellBuffer(lp_player);',
    'UnitSetPropertyFixed(lv_unit, c_unitPropShields'
)) {
    Assert-Contains -Failures $failures -Text $sharedRewards -Needle $needle -Message ("Reward lib missing blessing runtime effect: {0}" -f $needle)
}

Assert-Regex -Failures $failures -Text $sharedRewards -Pattern 'if\s*\(lp_bonusScore >= 3\)\s*\{\s*XMAchievement_Unlock\(lp_player, "ACH_CHALLENGE_FULL_BONUS_CLEAR"\);' -Message 'ChallengeFullBonus must be gated by bonus score.'
Assert-Regex -Failures $failures -Text $sharedRewards -Pattern 'if\s*\(lp_heroDeaths <= 0\)\s*\{\s*XMAchievement_Unlock\(lp_player, "ACH_CHALLENGE_NO_HERO_DEATH_CLEAR"\);' -Message 'ChallengeNoHeroDeath must be gated by hero death count.'
if (([regex]::Matches($sharedRewards, [regex]::Escape('if ((lv_bestTime <= 0) || (lv_clearTime < lv_bestTime))')).Count) -lt 2) {
    $failures.Add('MapBest and ChallengeBest must only update on first or faster clear time.') | Out-Null
}

$maps = @(Get-ChildItem -LiteralPath $resolvedMapsRoot -Directory | Where-Object { $_.Name -like '*_7vs1.SC2Map' } | Sort-Object Name)
if ($maps.Count -eq 0) {
    throw "No *_7vs1.SC2Map variants found under $resolvedMapsRoot"
}

$results = New-Object System.Collections.Generic.List[object]
foreach ($map in $maps) {
    $notes = New-Object System.Collections.Generic.List[string]
    $mainPath = Join-Path $map.FullName 'Base.SC2Data\LibE0EAE146.galaxy'
    $headerPath = Join-Path $map.FullName 'Base.SC2Data\LibE0EAE146_h.galaxy'
    $rewardsPath = Join-Path $map.FullName 'Base.SC2Data\LibE0EAE146_ProgressionRewards.galaxy'
    $bankListPath = Join-Path $map.FullName 'BankList.xml'

    if (-not (Test-Path -LiteralPath $mainPath)) {
        $notes.Add('missing_libe0eae146') | Out-Null
    }
    else {
        $text = Get-Content -LiteralPath $mainPath -Raw
        if (-not $text.Contains('include "LibE0EAE146_ProgressionRewards"')) { $notes.Add('missing_reward_include') | Out-Null }
        if (-not $text.Contains('XMProgression_Init(1);')) { $notes.Add('missing_progression_init_call') | Out-Null }
        if (-not $text.Contains('XMBlessing_ApplySelected(1);')) { $notes.Add('missing_blessing_apply_call') | Out-Null }
        if (-not $text.Contains('XMProgression_RecordVictory(1, lv_map, libE0EAE146_gv_commander, libE0EAE146_gv_bon, libE0EAE146_gv_commanderHeroDeathCount);')) { $notes.Add('missing_victory_record_call') | Out-Null }
    }

    if (-not (Test-Path -LiteralPath $headerPath)) {
        $notes.Add('missing_libe0eae146_h') | Out-Null
    }
    else {
        $text = Get-Content -LiteralPath $headerPath -Raw
        if (-not $text.Contains('void XMProgression_RecordVictory (int lp_player, string lp_mapId, string lp_commanderId, int lp_bonusScore, int lp_heroDeaths);')) { $notes.Add('missing_record_victory_declaration') | Out-Null }
    }

    if (-not (Test-Path -LiteralPath $rewardsPath)) {
        $notes.Add('missing_progression_rewards_lib') | Out-Null
    }
    else {
        $text = Get-Content -LiteralPath $rewardsPath -Raw
        if (-not $text.Contains('BankValueSetFromInt(BankLastCreated(), "Progression", "TotalWins"')) { $notes.Add('missing_total_wins_bank_write') | Out-Null }
        if (-not $text.Contains('BankValueSetFromInt(BankLastCreated(), "MapClear"')) { $notes.Add('missing_map_clear_bank_write') | Out-Null }
        if (-not $text.Contains('BankValueSetFromInt(BankLastCreated(), "CommanderClear"')) { $notes.Add('missing_commander_clear_bank_write') | Out-Null }
        if (-not $text.Contains('BankValueSetFromInt(BankLastCreated(), "CommanderBonus"')) { $notes.Add('missing_commander_bonus_bank_write') | Out-Null }
        if (-not $text.Contains('BankValueSetFromInt(BankLastCreated(), "Progression", "ObjectiveState"')) { $notes.Add('missing_objective_state_bank_write') | Out-Null }
        if (-not $text.Contains('if (lv_selected == "BlessingResourceRich")')) { $notes.Add('missing_resource_rich_blessing_effect') | Out-Null }
        if (-not $text.Contains('else if (lv_selected == "BlessingGoldenMinerals")')) { $notes.Add('missing_golden_minerals_blessing_effect') | Out-Null }
        if (-not $text.Contains('else if (lv_selected == "BlessingGuardianShell")')) { $notes.Add('missing_guardian_shell_blessing_effect') | Out-Null }
        if (([regex]::Matches($text, [regex]::Escape('if ((lv_bestTime <= 0) || (lv_clearTime < lv_bestTime))')).Count) -lt 2) { $notes.Add('missing_best_time_guard') | Out-Null }
    }

    if (-not (Test-BankListHasCampaignXCore -Path $bankListPath)) {
        $notes.Add('missing_campaignxcore_banklist') | Out-Null
    }

    $results.Add([pscustomobject]@{
        Map = $map.Name
        HasCampaignXCoreBank = Test-BankListHasCampaignXCore -Path $bankListPath
        Notes = ($notes -join ',')
    }) | Out-Null

    foreach ($note in $notes) {
        $failures.Add(("{0}: {1}" -f $map.Name, $note)) | Out-Null
    }
}

if ($CheckLiveBankCommander -or -not [string]::IsNullOrWhiteSpace($ExpectedBankCommander)) {
    $bankPaths = @(Get-CampaignXCoreBankPaths)
    if ($bankPaths.Count -eq 0) {
        $failures.Add('CampaignXCore.SC2Bank not found for live bank commander validation.') | Out-Null
    }
    foreach ($bankPath in $bankPaths) {
        $actualCommander = Get-BankString -Path $bankPath -Section "Ach" -Key "Commander"
        if ([string]::IsNullOrWhiteSpace($actualCommander)) {
            $failures.Add(("Bank missing Ach/Commander: {0}" -f $bankPath)) | Out-Null
        }
        elseif (-not [string]::IsNullOrWhiteSpace($ExpectedBankCommander) -and $actualCommander -ne $ExpectedBankCommander) {
            $failures.Add(("Bank Ach/Commander mismatch: {0}; expected={1}; actual={2}" -f $bankPath, $ExpectedBankCommander, $actualCommander)) | Out-Null
        }
    }
}

$results | Format-Table -AutoSize | Out-String -Width 4096 | Write-Output

if ($failures.Count -eq 0) {
    Write-Output ("VALIDATION_OK maps={0}" -f $maps.Count)
}
else {
    Write-Output ("VALIDATION_FAIL count={0}" -f $failures.Count)
    foreach ($failure in $failures) {
        Write-Output ("VALIDATION_FAIL_ITEM {0}" -f $failure)
    }

    if ($FailOnMismatch) {
        throw ("7vs1 reward/achievement validation failed for {0} item(s)." -f $failures.Count)
    }
}
