[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "commander-power-metadata.ps1")

function Get-WorkspaceRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [Parameter(Mandatory = $true)]
        [string]$Needle,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Text.Contains($Needle)) {
        throw $Message
    }
}

function Get-CommanderSpecs {
    return @(Get-CommanderPowerCommanderSpecs -WorkspaceRoot (Get-WorkspaceRoot))
}

$workspaceRoot = Get-WorkspaceRoot
$generatedPath = Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\LibE0EAE146_CommanderPowerGenerated.galaxy"
$bridgePath = Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\LibKCOR.galaxy"
$launchPath = Join-Path $workspaceRoot "scripts\validate-7vs1-commander-power.ps1"

$generatedText = Get-Content -LiteralPath $generatedPath -Raw
$bridgeText = Get-Content -LiteralPath $bridgePath -Raw
$launchText = Get-Content -LiteralPath $launchPath -Raw
$specs = @(Get-CommanderSpecs)

Assert-Contains -Text $launchText -Needle 'Get-CommanderPowerCommanderSpecs' -Message "Launch validator must consume CommanderPower metadata helper instead of hardcoded commander specs."

foreach ($spec in $specs) {
    Assert-Contains -Text $generatedText -Needle ('if (lp_commander == "{0}") {{' -f $spec.Bank) -Message ("Generated profile dispatcher missing bank commander '{0}'." -f $spec.Bank)
    Assert-Contains -Text $generatedText -Needle ('libE0EAE146_gf_CommanderPowerGeneratedApply{0}(lp_player);' -f $spec.Generated) -Message ("Generated profile apply call missing for '{0}'." -f $spec.Generated)
    Assert-Contains -Text $generatedText -Needle ('lv_prestigeMask = libE0EAE146_gf_CommanderPowerPrestigeMask("{0}");' -f $spec.Bank) -Message ("Generated prestige-mask read missing for '{0}'." -f $spec.Bank)
    for ($masteryIndex = 0; $masteryIndex -le 5; $masteryIndex++) {
        Assert-Contains -Text $generatedText -Needle ('libE0EAE146_gf_CommanderPowerMasteryLevel("{0}", {1})' -f $spec.Bank, $masteryIndex) -Message ("Generated mastery slot {1} missing for '{0}'." -f $spec.Bank, $masteryIndex)
    }

    Assert-Contains -Text $bridgeText -Needle ('lp_commander == "{0}"' -f $spec.Runtime) -Message ("Lobby->bank mapping missing runtime match for '{0}'." -f $spec.Runtime)
    Assert-Contains -Text $bridgeText -Needle ('return "{0}";' -f $spec.Bank) -Message ("Lobby->bank mapping missing bank return for '{0}'." -f $spec.Bank)
    Assert-Contains -Text $bridgeText -Needle ('.PrestigePointIndex"), lv_prestigeIndex, -1') -Message ("Lobby bridge missing prestige point index write for '{0}'." -f $spec.Bank)
    Assert-Contains -Text $bridgeText -Needle ('.PrestigeBonusMask"), lv_prestigeMask, -1') -Message ("Lobby bridge missing prestige bonus mask write for '{0}'." -f $spec.Bank)
}

$achBitHits = Get-ChildItem -LiteralPath (Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data") -Filter "LibE0EAE146*.galaxy" |
    Select-String -Pattern "AchBit"
$allowedAchBitPaths = @(
    (Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\LibE0EAE146.galaxy")
)

foreach ($hit in $achBitHits) {
    if ($allowedAchBitPaths -notcontains $hit.Path) {
        throw ("Unexpected AchBit runtime dependency remains: {0}:{1}" -f $hit.Path, $hit.LineNumber)
    }
}

if (@($achBitHits).Count -ne 2) {
    throw ("Unexpected AchBit reference count. Expected 2 allowed hits, got {0}." -f @($achBitHits).Count)
}

Write-Host ("COMMANDER_POWER_RUNTIME_COVERAGE_VALIDATE=PASS commanders={0} achbit_hits={1}" -f $specs.Count, @($achBitHits).Count)
