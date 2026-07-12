$ErrorActionPreference = "Stop"
$ScriptsRoot = "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts"
$ProjRoot = "e:\Code\MyMod\SC2\合作指挥官-起义狂潮"
$Sc2Root = "E:\SC2\SC2new\StarCraft II"

. "$ScriptsRoot\sc2-launcher\common.ps1"
. "$ScriptsRoot\sc2-launcher\mod-sync.ps1"
. "$ScriptsRoot\sc2-launcher\map-sync.ps1"
. "$ScriptsRoot\sc2-launcher\document-dependencies.ps1"
. "$ScriptsRoot\sc2-launcher\launcher-plan.ps1"

$plan = New-LauncherPlan -Commander "ZergStetmann" -MapName "zevolutionbaneling2_reborn_port.SC2Map" -ProjRoot $ProjRoot -Sc2Root $Sc2Root
Write-Host "Plan type: $($plan.GetType().Name)"
Write-Host "validation type: $($plan.validation.GetType().Name)"
Write-Host "validation members:"
$plan.validation | Get-Member -MemberType Properties | ForEach-Object { Write-Host "  $($_.Name)" }
$plan.validation.configSchema = "pass"
Write-Host "After set: $($plan.validation.configSchema)"
