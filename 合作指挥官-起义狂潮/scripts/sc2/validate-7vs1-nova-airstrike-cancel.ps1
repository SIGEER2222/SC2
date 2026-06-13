param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -notmatch $Pattern) {
        throw $Message
    }
}

$sharedRoot = Join-Path $WorkspaceRoot 'Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data'
$libKmisPath = Join-Path $sharedRoot 'LibKMIS.galaxy'
$abilDataNovaPath = Join-Path $WorkspaceRoot 'Mods\7vs1\CommanderCatalog.SC2Mod\Base.SC2Data\GameData\AbilData_Nova.xml'

if (!(Test-Path -LiteralPath $libKmisPath)) {
    throw "Missing LibKMIS.galaxy: $libKmisPath"
}
if (!(Test-Path -LiteralPath $abilDataNovaPath)) {
    throw "Missing Nova ability data: $abilDataNovaPath"
}

$libKmis = Get-Content -LiteralPath $libKmisPath -Raw -Encoding UTF8
$abilDataNova = Get-Content -LiteralPath $abilDataNovaPath -Raw -Encoding UTF8

Assert-Contains `
    $abilDataNova `
    '<CAbilBehavior id="NovaGriffinBombingRunActivate">(?s:.*?)<CmdButtonArray index="Off" DefaultButtonFace="Cancel"' `
    'Nova bombing run behavior ability must expose the Cancel/Off command.'

Assert-Contains `
    $libKmis `
    'TriggerAddEventUnitBehaviorChange\(libKMIS_gt_CM_SoATargetingDeactivated,\s*null,\s*"NovaGriffinBombingRunActivate",\s*c_unitBehaviorChangeDeactivate\);' `
    'Nova bombing run behavior deactivation must be handled by the shared SoA targeting deactivation trigger.'

Assert-Contains `
    $libKmis `
    'bool\s+libKMIS_gt_CM_SoATargetingDeactivated_Func\s*\(\s*bool\s+testConds,\s*bool\s+runActions\s*\)\s*\{(?s:.*?)lv_behavior\s*=\s*EventUnitBehavior\(\);(?s:.*?)lv_behavior\s*==\s*"NovaGriffinBombingRunActivate"(?s:.*?)libKMIS_gf_CM_SoATargetingCancel\(lv_casterPlayer\);(?s:.*?)libKMIS_gf_CM_SoATargetingModeExit\(lv_casterPlayer\);' `
    'Nova bombing run Cancel/Off deactivation must route through shared cancel cleanup before exiting targeting mode.'

Assert-Contains `
    $libKmis `
    'EventTargetModeAbilCmd\(\)\s*==\s*AbilityCommand\("NovaGriffinBombingRunTargetingDummy",\s*0\)' `
    'Nova bombing run point-targeting command must be accepted by target-mode cancel.'

Assert-Contains `
    $libKmis `
    'EventTargetModeAbilCmd\(\)\s*==\s*AbilityCommand\("NovaGriffinBombingRunExecute",\s*0\)' `
    'Nova bombing run direction-targeting command must be accepted by target-mode cancel.'

Write-Host 'VALIDATION_OK novaAirstrikeCancel=1'
