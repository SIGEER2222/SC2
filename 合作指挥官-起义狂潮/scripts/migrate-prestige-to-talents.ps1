# Migrate prestige/mastery from commander-power-metadata.json to Shared/Talents/*.json
# Pure ASCII to avoid codepage issues.

$ErrorActionPreference = "Stop"

$scriptsRoot = $PSScriptRoot
$workspaceRoot = Split-Path -Parent $scriptsRoot
$metaPath = Join-Path $workspaceRoot "Shared\CommanderPower\commander-power-metadata.json"
$outDir = Join-Path $workspaceRoot "Shared\Talents"

if (-not (Test-Path -LiteralPath $metaPath)) {
    throw "Metadata not found: $metaPath"
}

$meta = Get-Content -LiteralPath $metaPath -Encoding UTF8 -Raw | ConvertFrom-Json

# Extract advantage text from tooltip (remove disadvantage part)
# Tooltip format: <s val="Coop_Prestige_Advantage">advantage</s>actual advantage text...<s val="Coop_Prestige_Disadvantage">disadvantage</s>actual disadvantage text...
function Extract-Advantage {
    param([string]$Tooltip)
    if ([string]::IsNullOrWhiteSpace($Tooltip)) { return "" }

    # Split on disadvantage marker, keep only first part
    $advPart = $Tooltip -split '<s val="Coop_Prestige_Disadvantage"', 2 | Select-Object -First 1

    # Remove the advantage label tag: <s val="Coop_Prestige_Advantage">advantage</s>
    $advPart = $advPart -replace '<s val="Coop_Prestige_Advantage">[^<]*</s>', ''

    # Remove any remaining HTML tags
    $advPart = $advPart -replace '<[^>]+>', ''

    # Collapse whitespace and trim
    $advPart = $advPart -replace '\s+', ' '
    return $advPart.Trim()
}

# Commanders with empty talents (no prestige/mastery)
$emptyCommanders = @("Izsha", "RaynorX", "AbathurReborn", "TestZerg", "Alenger3")

# Map runtime_commander to short name for file naming
function Get-CommanderShortName {
    param([string]$Runtime)
    # Strip race prefix: Terran/Zerg/Protoss
    if ($Runtime -match '^(?:Terran|Zerg|Protoss)(.+)$') {
        return $matches[1]
    }
    return $Runtime
}

$generated = 0
$skipped = 0

foreach ($cmd in $meta.commanders) {
    $runtime = $cmd.runtime_commander
    $displayName = $cmd.display_name
    if ([string]::IsNullOrWhiteSpace($runtime)) {
        $skipped++
        continue
    }

    $shortName = Get-CommanderShortName -Runtime $runtime
    $outPath = Join-Path $outDir "$shortName.json"

    # Check if this commander has prestiges/masteries
    $hasPrestiges = ($null -ne $cmd.prestiges -and $cmd.prestiges.Count -gt 0)
    $hasMasteries = ($null -ne $cmd.masteries -and $cmd.masteries.Count -gt 0)

    # Build talents array
    $talents = @()

    # Convert prestiges to switch talents
    if ($hasPrestiges) {
        foreach ($p in $cmd.prestiges) {
            $upgrades = @()
            if ($p.primary_upgrade) { $upgrades += $p.primary_upgrade }
            if ($p.secondary_upgrades_shared) { $upgrades += $p.secondary_upgrades_shared }
            if ($p.secondary_upgrades_self) { $upgrades += $p.secondary_upgrades_self }

            $talent = [ordered]@{
                id = $p.id
                type = "switch"
                name = $p.name
                description = (Extract-Advantage -Tooltip $p.tooltip)
                category = "prestige"
                upgrades = $upgrades
                suppress_upgrades = @($p.suppress_upgrades | Where-Object { $_ })
                supplement_upgrades = @()
                enable_units = @($p.enable_units | Where-Object { $_ })
                disable_units = @($p.disable_units | Where-Object { $_ })
                enable_abils = @($p.enable_abils | Where-Object { $_ })
                disable_abils = @($p.disable_abils | Where-Object { $_ })
                extra_options = @()
            }

            # Convert upgrade_supplements
            if ($p.upgrade_supplements) {
                foreach ($sup in $p.upgrade_supplements) {
                    $talent.supplement_upgrades += [ordered]@{
                        target = $sup.upgrade
                        supplements = @($sup.supplement_upgrades | Where-Object { $_ })
                    }
                }
            }

            # Convert extra_options
            if ($p.extra_options) {
                foreach ($opt in $p.extra_options) {
                    # Upgrade ID pattern: CommanderPrestige<CommanderShortName><OptionId>
                    # e.g. Raynor BioSuperStim -> CommanderPrestigeRaynorBioSuperStim
                    $optUpgrade = "CommanderPrestige$shortName$($opt.id)"
                    $talent.extra_options += [ordered]@{
                        id = $opt.id
                        name = $opt.name
                        description = $opt.description
                        type = $opt.type
                        default = ($opt.default -ne 0)
                        upgrades = @($optUpgrade)
                    }
                }
            }

            $talents += $talent
        }
    }

    # Convert masteries to level talents
    if ($hasMasteries) {
        foreach ($m in $cmd.masteries) {
            $pointInc = 0
            if ($m.point_increments -and $m.point_increments.Count -gt 0) {
                [float]::TryParse([string]$m.point_increments[0], [ref]$pointInc) | Out-Null
            }

            $talent = [ordered]@{
                id = $m.id
                type = "level"
                name = $m.name
                description = ""
                category = "mastery"
                max_level = 30
                upgrade = $m.upgrade
                point_increment = $pointInc
                value_format = $m.value_format
            }
            $talents += $talent
        }
    }

    # Build output object
    $output = [ordered]@{
        schema_version = 2
        commander = $runtime
        display_name = $displayName
        talents = $talents
    }

    $json = $output | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($outPath, $json, (New-Object System.Text.UTF8Encoding($false)))
    $generated++
    Write-Host "Generated: $outPath ($($talents.Count) talents)"
}

# Generate _Common.json for HexTalents (placeholder, will be filled by build-talent-catalog.ps1)
$commonPath = Join-Path $outDir "_Common.json"
$commonOutput = [ordered]@{
    schema_version = 2
    commander = "_Common"
    display_name = "common talents"
    talents = @()
}
$commonJson = $commonOutput | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($commonPath, $commonJson, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Generated: $commonPath (placeholder for HexTalents)"

Write-Host ""
Write-Host "Migration complete: $generated commander files generated, $skipped skipped"
