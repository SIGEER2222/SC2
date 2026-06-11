[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Get-WorkspaceRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Get-FunctionBlock {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [Parameter(Mandatory = $true)]
        [string]$Signature
    )

    $start = $Text.IndexOf($Signature)
    if ($start -lt 0) {
        throw "Function signature not found: $Signature"
    }

    $braceStart = $Text.IndexOf("{", $start)
    if ($braceStart -lt 0) {
        throw "Function body start not found: $Signature"
    }

    $depth = 0
    for ($i = $braceStart; $i -lt $Text.Length; $i++) {
        $char = $Text[$i]
        if ($char -eq '{') {
            $depth++
        }
        elseif ($char -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return $Text.Substring($start, ($i - $start + 1))
            }
        }
    }

    throw "Function body end not found: $Signature"
}

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Needle,
        [string]$Message
    )

    if (-not $Text.Contains($Needle)) {
        throw $Message
    }
}

$workspaceRoot = Get-WorkspaceRoot
$profilePath = Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\LibE0EAE146_CommanderPowerProfile.galaxy"
$bridgePath = Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\LibKCOR.galaxy"

$profileText = Get-Content -LiteralPath $profilePath -Raw
$bridgeText = Get-Content -LiteralPath $bridgePath -Raw

$masteryDefaultBlock = Get-FunctionBlock -Text $profileText -Signature "int libE0EAE146_gf_CommanderPowerMasteryDefaultLevel (string lp_commander)"
Assert-Contains -Text $masteryDefaultBlock -Needle "libE0EAE146_gf_CommanderPowerMasteriesEnabled(lp_commander)" -Message "Mastery default level must respect EnableMasteries."
Assert-Contains -Text $masteryDefaultBlock -Needle "return 0;" -Message "Mastery default level must return 0 when masteries are disabled."

$masteryLevelBlock = Get-FunctionBlock -Text $profileText -Signature "int libE0EAE146_gf_CommanderPowerMasteryLevel (string lp_commander, int lp_masteryIndex)"
Assert-Contains -Text $masteryLevelBlock -Needle "libE0EAE146_gf_CommanderPowerMasteriesEnabled(lp_commander)" -Message "Mastery slot lookup must respect EnableMasteries."

$profileNameBlock = Get-FunctionBlock -Text $profileText -Signature "string libE0EAE146_gf_CommanderPowerProfileName (string lp_commander)"
Assert-Contains -Text $profileNameBlock -Needle 'libE0EAE146_gf_CommanderPowerBankStringOrDefault(lp_commander, "Profile", "Prestige4")' -Message "Commander power profile default must be Prestige4."

$prestigePointIndexBlock = Get-FunctionBlock -Text $profileText -Signature "int libE0EAE146_gf_CommanderPowerPrestigePointIndex (string lp_commander)"
Assert-Contains -Text $prestigePointIndexBlock -Needle 'libE0EAE146_gf_CommanderPowerBankKeyExists(lp_commander, "PrestigePointIndex")' -Message "Prestige point index must honor explicit PrestigePointIndex overrides."
Assert-Contains -Text $prestigePointIndexBlock -Needle 'libE0EAE146_gf_CommanderPowerBankIntOrDefault(lp_commander, "PrestigePointIndex", -1)' -Message "Prestige point index fallback must preserve legacy default."
Assert-Contains -Text $prestigePointIndexBlock -Needle 'libE0EAE146_gf_CommanderPowerBankIntOrDefault(lp_commander, "PrestigeIndex", -1)' -Message "Prestige point index must fall back to legacy PrestigeIndex."

$prestigeBonusMaskBlock = Get-FunctionBlock -Text $profileText -Signature "int libE0EAE146_gf_CommanderPowerPrestigeBonusMask (string lp_commander)"
Assert-Contains -Text $prestigeBonusMaskBlock -Needle "libE0EAE146_gf_CommanderPowerPrestigesEnabled(lp_commander)" -Message "Prestige bonus mask must respect EnablePrestiges."
Assert-Contains -Text $prestigeBonusMaskBlock -Needle 'libE0EAE146_gf_CommanderPowerBankKeyExists(lp_commander, "PrestigeBonusMask")' -Message "Prestige bonus mask must honor explicit PrestigeBonusMask overrides."
Assert-Contains -Text $prestigeBonusMaskBlock -Needle 'lv_defaultMask = libE0EAE146_gf_CommanderPowerDefaultPrestigeBonusMask(lp_commander);' -Message "Prestige bonus mask must resolve the Prestige4 default through the helper."
Assert-Contains -Text $prestigeBonusMaskBlock -Needle 'libE0EAE146_gf_CommanderPowerBankIntOrDefault(lp_commander, "PrestigeBonusMask", lv_defaultMask)' -Message "Prestige bonus mask fallback must preserve the Prestige4 default."
Assert-Contains -Text $prestigeBonusMaskBlock -Needle 'libE0EAE146_gf_CommanderPowerBankKeyExists(lp_commander, "PrestigeMask")' -Message "Prestige bonus mask must still accept the legacy PrestigeMask key."
Assert-Contains -Text $prestigeBonusMaskBlock -Needle 'libE0EAE146_gf_CommanderPowerPrestigePointIndex(lp_commander)' -Message "Prestige bonus mask fallback must consult the prestige point index."

$prestigeMaskBlock = Get-FunctionBlock -Text $profileText -Signature "int libE0EAE146_gf_CommanderPowerPrestigeMask (string lp_commander)"
Assert-Contains -Text $prestigeMaskBlock -Needle 'libE0EAE146_gf_CommanderPowerPrestigeBonusMask(lp_commander)' -Message "Prestige mask compatibility wrapper must delegate to the bonus-mask helper."

$bridgeBlock = Get-FunctionBlock -Text $bridgeText -Signature "void libKCOR_gf_CC_SyncCommanderPowerToBank (int lp_player)"
Assert-Contains -Text $bridgeBlock -Needle "lv_prestigeMask = 7;" -Message "Lobby bridge must default enabled prestige fusion to all-positive mask."
Assert-Contains -Text $bridgeBlock -Needle '(lv_bankCommander + ".PrestigePointIndex"), lv_prestigeIndex, -1' -Message "Lobby bridge must write the computed prestige point index."
Assert-Contains -Text $bridgeBlock -Needle '(lv_bankCommander + ".PrestigeBonusMask"), lv_prestigeMask, -1' -Message "Lobby bridge must write the computed prestige bonus mask."
Assert-Contains -Text $bridgeBlock -Needle '(lv_bankCommander + ".PrestigeIndex"), lv_prestigeIndex, -1' -Message "Lobby bridge must keep the legacy prestige index key."
Assert-Contains -Text $bridgeBlock -Needle '(lv_bankCommander + ".PrestigeMask"), lv_prestigeMask, -1' -Message "Lobby bridge must keep the legacy prestige mask key."

Write-Host "COMMANDER_POWER_PROTOCOL_VALIDATE=PASS"
