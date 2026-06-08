function Get-CommanderPowerWorkspaceRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Get-CommanderPowerMetadataPath {
    param(
        [string]$WorkspaceRoot = ""
    )

    if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
        $WorkspaceRoot = Get-CommanderPowerWorkspaceRoot
    }

    return (Join-Path $WorkspaceRoot "Shared\CommanderPower\commander-power-metadata.json")
}

function Get-CommanderPowerMetadata {
    param(
        [string]$WorkspaceRoot = ""
    )

    $path = Get-CommanderPowerMetadataPath -WorkspaceRoot $WorkspaceRoot
    if (-not (Test-Path -LiteralPath $path)) {
        throw "CommanderPower metadata not found: $path"
    }

    return (Get-Content -LiteralPath $path -Encoding UTF8 -Raw | ConvertFrom-Json)
}

function Get-CommanderPowerCommanderSpecs {
    param(
        [string]$WorkspaceRoot = ""
    )

    $metadata = Get-CommanderPowerMetadata -WorkspaceRoot $WorkspaceRoot
    $specs = New-Object System.Collections.Generic.List[hashtable]
    foreach ($commander in $metadata.commanders) {
        $specs.Add(@{
                Runtime = [string]$commander.runtime_commander
                Bank = [string]$commander.bank_commander
                Generated = [string]$commander.generated_commander
                OfficialFolder = [string]$commander.official_folder
            }) | Out-Null
    }

    return $specs.ToArray()
}

function Resolve-CommanderPowerCommanderRecord {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Commander,
        [string]$WorkspaceRoot = ""
    )

    if ([string]::IsNullOrWhiteSpace($Commander)) {
        return $null
    }

    $metadata = Get-CommanderPowerMetadata -WorkspaceRoot $WorkspaceRoot
    $normalized = $Commander.Trim()

    foreach ($record in $metadata.commanders) {
        foreach ($candidate in @(
                [string]$record.runtime_commander,
                [string]$record.bank_commander,
                [string]$record.generated_commander,
                [string]$record.official_folder,
                [string]$record.official_short_id
            )) {
            if ([string]::IsNullOrWhiteSpace($candidate)) {
                continue
            }

            if ($candidate.Equals($normalized, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $record
            }
        }
    }

    return $null
}

function Convert-CommanderPowerCommanderToBankKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Commander,
        [string]$WorkspaceRoot = ""
    )

    $record = Resolve-CommanderPowerCommanderRecord -Commander $Commander -WorkspaceRoot $WorkspaceRoot
    if ($null -eq $record) {
        return ""
    }

    return [string]$record.bank_commander
}
