param(
    [Parameter(Mandatory = $true)]
    [string]$MapPath,
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$SwitcherPath = "",
    [string[]]$Commanders = @(),
    [string]$CommanderPowerProfile = "Prestige4",
    [Alias("CommanderPowerPrestigeMask")]
    [Nullable[int]]$CommanderPowerPrestigeBonusMask = $null,
    [Alias("CommanderPowerPrestigeIndex")]
    [Nullable[int]]$CommanderPowerPrestigePointIndex = $null,
    [int]$CommanderPowerEnablePrestiges = 1,
    [int]$CommanderPowerEnableMasteries = 1,
    [int]$CommanderPowerMasteryLevel = 30,
    [Nullable[int]]$CommanderPowerMastery0 = $null,
    [Nullable[int]]$CommanderPowerMastery1 = $null,
    [Nullable[int]]$CommanderPowerMastery2 = $null,
    [Nullable[int]]$CommanderPowerMastery3 = $null,
    [Nullable[int]]$CommanderPowerMastery4 = $null,
    [Nullable[int]]$CommanderPowerMastery5 = $null,
    [string]$CommanderPowerPresetPath = "",
    [string[]]$CommanderPowerOverride = @(),
    [string[]]$Mutators = @(),
    [string[]]$GenericBonuses = @(),
    [string]$VoicePack = "Default",
    [ValidateRange(0, 3)]
    [int]$MutatorPreset = 0,
    [string]$TestRunId = "",
    [switch]$SkipCommanderPowerPreset,
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"

# 生成 TestRunId
if ([string]::IsNullOrWhiteSpace($TestRunId)) {
    $TestRunId = [guid]::NewGuid().ToString("N")
}

# 加载 Bank 写入库和指挥官元数据
. (Join-Path $PSScriptRoot "commander-power-metadata.ps1")
. (Join-Path $PSScriptRoot "sc2\campaignxcore-bank.ps1")

function Get-WorkspaceRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

# campaignxcore-bank.ps1 的 Apply-CommanderPowerOverrideEntry / Set-CampaignXCorePrimaryCommander
# 依赖此包装函数（与 launch-7vs1-coop-test.ps1 保持一致）
function Convert-TestCommanderToCommanderPowerKey {
    param([string]$Commander)

    return (Convert-CommanderPowerCommanderToBankKey -Commander $Commander -WorkspaceRoot (Get-WorkspaceRoot))
}

# campaignxcore-bank.ps1 的 Get-CommanderPowerPresetEntries 依赖此函数
# （与 launch-7vs1-coop-test.ps1 保持一致）
function Resolve-CommanderPowerPresetPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-WorkspaceRoot) $Path))
}

# 解析 SwitcherPath
if ([string]::IsNullOrWhiteSpace($SwitcherPath)) {
    $SwitcherPath = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
}

if (-not (Test-Path -LiteralPath $SwitcherPath)) {
    throw "SwitcherPath not found: $SwitcherPath"
}

# 解析地图路径（支持相对路径，相对于 workspace root）
$resolvedMapPath = $MapPath
if (-not [System.IO.Path]::IsPathRooted($resolvedMapPath)) {
    $resolvedMapPath = Join-Path (Get-WorkspaceRoot) $resolvedMapPath
}
if (-not (Test-Path -LiteralPath $resolvedMapPath)) {
    throw "MapPath not found: $resolvedMapPath"
}

Write-Host "=== XM Scenario Launcher ===" -ForegroundColor Cyan
Write-Host "Map:        $resolvedMapPath"
Write-Host "Commanders: $($Commanders -join ', ')"
Write-Host "TestRunId:  $TestRunId"
Write-Host ""

# 计算 $useCommanderDefaultPrestigeBonusMask（与 launch-7vs1-coop-test.ps1 一致）
$useCommanderDefaultPrestigeBonusMask = -not $PSBoundParameters.ContainsKey("CommanderPowerPrestigeBonusMask")

$effectiveCommanders = @($Commanders)

# -------- 1. 写 Bank --------
if (-not $SkipCommanderPowerPreset) {
    Set-CampaignXCoreCommanderPowerPreset `
        -SelectedCommanders $effectiveCommanders `
        -Profile $CommanderPowerProfile `
        -PrestigeBonusMask $CommanderPowerPrestigeBonusMask `
        -UseCommanderDefaultPrestigeBonusMask $useCommanderDefaultPrestigeBonusMask `
        -PrestigePointIndex $CommanderPowerPrestigePointIndex `
        -EnablePrestiges $CommanderPowerEnablePrestiges `
        -EnableMasteries $CommanderPowerEnableMasteries `
        -MasteryLevel $CommanderPowerMasteryLevel `
        -Mastery0 $CommanderPowerMastery0 `
        -Mastery1 $CommanderPowerMastery1 `
        -Mastery2 $CommanderPowerMastery2 `
        -Mastery3 $CommanderPowerMastery3 `
        -Mastery4 $CommanderPowerMastery4 `
        -Mastery5 $CommanderPowerMastery5 `
        -PresetPath $CommanderPowerPresetPath `
        -Overrides $CommanderPowerOverride
}
Set-CampaignXCoreMutatorPreset -SelectedMutators $Mutators -Preset $MutatorPreset
Set-CampaignXCoreGenericBonuses -SelectedBonuses $GenericBonuses
Set-CampaignXCoreVoicePackSelection -SelectedCommanders $effectiveCommanders -VoicePack $VoicePack
Set-CampaignXCorePrimaryCommander -SelectedCommanders $effectiveCommanders
Set-CampaignXCoreTestRunId -RunId $TestRunId

Write-Host "[OK] Bank written to CampaignXCore.SC2Bank" -ForegroundColor Green

# -------- 2. 停止现有 SC2 进程 --------
if (-not $NoLaunch) {
    $processNames = @("SC2_x64", "SC2Switcher_x64", "BlizzardError")
    foreach ($processName in $processNames) {
        $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if (-not $running) { continue }
        foreach ($proc in $running) {
            try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop } catch { }
        }
    }
    Start-Sleep -Seconds 2

    # -------- 3. 清理 GameLogs --------
    $logsRoot = "C:\Users\22448\Documents\StarCraft II\GameLogs"
    if (Test-Path -LiteralPath $logsRoot) {
        Get-ChildItem -LiteralPath $logsRoot -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop } catch { }
        }
    }

    # -------- 4. 用 SC2Switcher 启动地图 --------
    Write-Host "[INFO] Launching SC2Switcher with map: $resolvedMapPath" -ForegroundColor Yellow
    Start-Process -FilePath $SwitcherPath -ArgumentList "`"$resolvedMapPath`""
    Write-Host "[OK] SC2Switcher launched" -ForegroundColor Green
}

Write-Host "=== Done ===" -ForegroundColor Cyan
