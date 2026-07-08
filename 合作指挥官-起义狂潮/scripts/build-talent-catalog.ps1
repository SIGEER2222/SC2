# Build TalentCatalog galaxy script from Shared/Talents/*.json
# Pure ASCII to avoid codepage issues.

$ErrorActionPreference = "Stop"

$scriptsRoot = $PSScriptRoot
$workspaceRoot = Split-Path -Parent $scriptsRoot
$talentsDir = Join-Path $workspaceRoot "Shared\Talents"
$outPath = Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\LibE0EAE146_TalentCatalog.galaxy"

if (-not (Test-Path -LiteralPath $talentsDir)) {
    throw "Talents dir not found: $talentsDir"
}

# Load all JSON files (skip _Common for now, HexTalents handled separately)
$jsonFiles = Get-ChildItem -LiteralPath $talentsDir -Filter "*.json" | Where-Object { $_.Name -ne "_Common.json" }

$sb = New-Object System.Text.StringBuilder

[void]$sb.AppendLine("// ============================================================================")
[void]$sb.AppendLine("// AUTO-GENERATED FILE. DO NOT EDIT MANUALLY.")
[void]$sb.AppendLine("// Source: Shared/Talents/*.json")
[void]$sb.AppendLine("// Generator: scripts/build-talent-catalog.ps1")
[void]$sb.AppendLine("// ============================================================================")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("include ""LibE0EAE146_h""")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("// ---- Bank key helpers ----")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("// Read talent level from Bank: <Commander>.<TalentId> in CommanderTalents section")
[void]$sb.AppendLine("int libE0EAE146_gf_TalentBankValue (string lp_commander, string lp_talentId) {")
[void]$sb.AppendLine("    bank lv_bank = BankLoad(""CampaignXCore"", 1);")
[void]$sb.AppendLine("    string lv_key = lp_commander + ""."" + lp_talentId;")
[void]$sb.AppendLine("    if (BankKeyExists(lv_bank, ""CommanderTalents"", lv_key)) {")
[void]$sb.AppendLine("        return BankValueGetAsInt(lv_bank, ""CommanderTalents"", lv_key);")
[void]$sb.AppendLine("    }")
[void]$sb.AppendLine("    return 0;")
[void]$sb.AppendLine("}")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("bool libE0EAE146_gf_TalentBankEnabled (string lp_commander, string lp_talentId) {")
[void]$sb.AppendLine("    return (libE0EAE146_gf_TalentBankValue(lp_commander, lp_talentId) > 0);")
[void]$sb.AppendLine("}")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("// Read extra option flag: <Commander>.<TalentId>.<OptionId>")
[void]$sb.AppendLine("bool libE0EAE146_gf_TalentExtraOptionEnabled (string lp_commander, string lp_talentId, string lp_optionId) {")
[void]$sb.AppendLine("    bank lv_bank = BankLoad(""CampaignXCore"", 1);")
[void]$sb.AppendLine("    string lv_key = lp_commander + ""."" + lp_talentId + ""."" + lp_optionId;")
[void]$sb.AppendLine("    if (BankKeyExists(lv_bank, ""CommanderTalents"", lv_key)) {")
[void]$sb.AppendLine("        return (BankValueGetAsInt(lv_bank, ""CommanderTalents"", lv_key) > 0);")
[void]$sb.AppendLine("    }")
[void]$sb.AppendLine("    return false;")
[void]$sb.AppendLine("}")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("// ---- Per-commander talent apply functions ----")
[void]$sb.AppendLine("")

$dispatcherCases = New-Object System.Text.StringBuilder

foreach ($jf in $jsonFiles) {
    $json = Get-Content -LiteralPath $jf.FullName -Encoding UTF8 -Raw | ConvertFrom-Json
    $cmdRuntime = $json.commander
    $cmdShort = [System.IO.Path]::GetFileNameWithoutExtension($jf.Name)
    $talents = $json.talents

    if (-not $talents -or $talents.Count -eq 0) {
        # Empty talents (Alenger etc.), generate stub
        [void]$sb.AppendLine("// ${cmdRuntime}: no talents (empty config)")
        [void]$sb.AppendLine("void libE0EAE146_gf_Apply${cmdShort}Talents (int lp_player) {")
        [void]$sb.AppendLine("    // No talents defined for this commander")
        [void]$sb.AppendLine("}")
        [void]$sb.AppendLine("")
        [void]$dispatcherCases.AppendLine("    if (lp_commander == ""$cmdRuntime"") { libE0EAE146_gf_Apply${cmdShort}Talents(lp_player); return true; }")
        continue
    }

    [void]$sb.AppendLine("// ${cmdRuntime}: $($talents.Count) talents")
    [void]$sb.AppendLine("void libE0EAE146_gf_Apply${cmdShort}Talents (int lp_player) {")
    [void]$sb.AppendLine("    string lv_cmd = ""$cmdRuntime"";")

    # Galaxy requires all locals at function top. Pre-scan level talents and
    # declare one int per level talent (lv_lvl_<index>) before any logic.
    $levelIdx = 0
    foreach ($t in $talents) {
        if ($t.type -eq "level") {
            [void]$sb.AppendLine("    int lv_lvl_${levelIdx};")
            $levelIdx++
        }
    }

    $talentIdx = 0
    $levelIdx = 0
    foreach ($t in $talents) {
        $tid = $t.id
        $ttype = $t.type

        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("    // [$talentIdx] ${ttype}: $($t.name) ($tid)")

        if ($ttype -eq "switch") {
            [void]$sb.AppendLine("    if (libE0EAE146_gf_TalentBankEnabled(lv_cmd, ""$tid"")) {")

            # Apply upgrades
            if ($t.upgrades -and $t.upgrades.Count -gt 0) {
                foreach ($upg in $t.upgrades) {
                    [void]$sb.AppendLine("        libE0EAE146_gf_CommanderPowerSetUpgradeAtLeast(lp_player, ""$upg"", 1);")
                }
            }

            # Apply supplement_upgrades
            if ($t.supplement_upgrades -and $t.supplement_upgrades.Count -gt 0) {
                foreach ($sup in $t.supplement_upgrades) {
                    $target = $sup.target
                    foreach ($supUpg in $sup.supplements) {
                        [void]$sb.AppendLine("        libE0EAE146_gf_CommanderPowerSetUpgradeAtLeast(lp_player, ""$supUpg"", 1);")
                    }
                }
            }

            # Apply suppress_upgrades (TechTreeUpgradeRemoveLevel)
            if ($t.suppress_upgrades -and $t.suppress_upgrades.Count -gt 0) {
                foreach ($supUpg in $t.suppress_upgrades) {
                    [void]$sb.AppendLine("        TechTreeUpgradeRemoveLevel(lp_player, ""$supUpg"", 1);")
                }
            }

            # Apply enable/disable units
            if ($t.enable_units -and $t.enable_units.Count -gt 0) {
                foreach ($u in $t.enable_units) {
                    [void]$sb.AppendLine("        TechTreeUnitAllow(lp_player, ""$u"", true);")
                }
            }
            if ($t.disable_units -and $t.disable_units.Count -gt 0) {
                foreach ($u in $t.disable_units) {
                    [void]$sb.AppendLine("        TechTreeUnitAllow(lp_player, ""$u"", false);")
                }
            }

            # Apply enable/disable abils
            # TechTreeAbilityAllow native signature: (int player, abilcmd abilCmd, bool allow)
            # abilcmd must be constructed via AbilityCommand(abilLink, cmdIndex).
            if ($t.enable_abils -and $t.enable_abils.Count -gt 0) {
                foreach ($a in $t.enable_abils) {
                    $abil = $a.abil
                    [void]$sb.AppendLine("        TechTreeAbilityAllow(lp_player, AbilityCommand(""$abil"", 0), true);")
                }
            }
            if ($t.disable_abils -and $t.disable_abils.Count -gt 0) {
                foreach ($a in $t.disable_abils) {
                    $abil = $a.abil
                    [void]$sb.AppendLine("        TechTreeAbilityAllow(lp_player, AbilityCommand(""$abil"", 0), false);")
                }
            }

            # Apply extra_options
            if ($t.extra_options -and $t.extra_options.Count -gt 0) {
                foreach ($opt in $t.extra_options) {
                    $optId = $opt.id
                    [void]$sb.AppendLine("        if (libE0EAE146_gf_TalentExtraOptionEnabled(lv_cmd, ""$tid"", ""$optId"")) {")
                    if ($opt.upgrades -and $opt.upgrades.Count -gt 0) {
                        foreach ($optUpg in $opt.upgrades) {
                            [void]$sb.AppendLine("            libE0EAE146_gf_CommanderPowerSetUpgradeAtLeast(lp_player, ""$optUpg"", 1);")
                        }
                    }
                    [void]$sb.AppendLine("        }")
                }
            }

            [void]$sb.AppendLine("    }")
        }
        elseif ($ttype -eq "level") {
            $upg = $t.upgrade
            [void]$sb.AppendLine("    lv_lvl_${levelIdx} = libE0EAE146_gf_TalentBankValue(lv_cmd, ""$tid"");")
            [void]$sb.AppendLine("    if (lv_lvl_${levelIdx} > 0) {")
            [void]$sb.AppendLine("        libE0EAE146_gf_CommanderPowerSetUpgradeAtLeast(lp_player, ""$upg"", lv_lvl_${levelIdx});")
            [void]$sb.AppendLine("    }")
            $levelIdx++
        }
        elseif ($ttype -eq "common") {
            [void]$sb.AppendLine("    if (libE0EAE146_gf_TalentBankEnabled(lv_cmd, ""$tid"")) {")
            if ($t.upgrades -and $t.upgrades.Count -gt 0) {
                foreach ($upg in $t.upgrades) {
                    [void]$sb.AppendLine("        libE0EAE146_gf_CommanderPowerSetUpgradeAtLeast(lp_player, ""$upg"", 1);")
                }
            }
            [void]$sb.AppendLine("    }")
        }

        $talentIdx++
    }

    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("")

    # Add to dispatcher
    [void]$dispatcherCases.AppendLine("    if (lp_commander == ""$cmdRuntime"") { libE0EAE146_gf_Apply${cmdShort}Talents(lp_player); return true; }")
}

# Generate dispatcher
[void]$sb.AppendLine("// ---- Dispatcher ----")
[void]$sb.AppendLine("bool libE0EAE146_gf_ApplyTalentsForCommander (int lp_player, string lp_commander) {")
[void]$sb.Append($dispatcherCases.ToString())
[void]$sb.AppendLine("    return false;")
[void]$sb.AppendLine("}")
[void]$sb.AppendLine("")

# Write output
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))

# Count stats
$totalTalents = 0
foreach ($jf in $jsonFiles) {
    $json = Get-Content -LiteralPath $jf.FullName -Encoding UTF8 -Raw | ConvertFrom-Json
    if ($json.talents) { $totalTalents += $json.talents.Count }
}

Write-Host "Generated: $outPath"
Write-Host "Commanders: $($jsonFiles.Count)"
Write-Host "Total talents: $totalTalents"
