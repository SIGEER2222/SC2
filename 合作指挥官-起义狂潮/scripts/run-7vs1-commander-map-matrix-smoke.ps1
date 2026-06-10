[CmdletBinding()]
param(
    [string]$MapsRoot = "",
    [string]$ReportRoot = "",
    [int]$WaitSeconds = 50,
    [ValidateSet("Batch", "Solo")]
    [string]$Mode = "Solo",
    [int]$MaxRuns = 0,
    [switch]$Resume,
    [switch]$StopOnFailure,
    [ValidateSet("Full", "NoVisuals", "CoreOnly")]
    [string]$AbathurPatchProfile = "Full",
    [string[]]$ExcludeCommanders = @(),
    [string[]]$IncludeCommanders = @(),
    [string[]]$MapNames = @()
)

$ErrorActionPreference = "Stop"

function Get-WorkspaceRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Convert-ToSafeName {
    param([string]$Value)
    return ($Value -replace "[^A-Za-z0-9_.-]+", "_")
}

function Get-MatrixCommanders {
    return @(
        "TerranRaynor",
        "ZergKerrigan",
        "ProtossArtanis",
        "TerranNova",
        "ZergAbathur",
        "ProtossFenix",
        "ProtossVorazun",
        "TerranSwann",
        "ZergZagara",
        "ProtossKarax",
        "TerranHorner",
        "ZergDehaka",
        "ProtossAlarak",
        "ZergStukov",
        "ProtossZeratul",
        "ZergStetmann",
        "TerranMengsk",
        "TerranTychus"
    )
}

function Get-CommanderBatches {
    return @(
        [pscustomobject]@{
            Name = "Batch1"
            Commanders = @(
                "TerranRaynor",
                "ZergKerrigan",
                "ProtossArtanis",
                "TerranNova",
                "ZergAbathur",
                "ProtossFenix",
                "ProtossVorazun"
            )
        },
        [pscustomobject]@{
            Name = "Batch2"
            Commanders = @(
                "TerranSwann",
                "ZergZagara",
                "ProtossKarax",
                "TerranHorner",
                "ZergDehaka",
                "ProtossAlarak",
                "ZergStukov"
            )
        },
        [pscustomobject]@{
            Name = "Batch3"
            Commanders = @(
                "ProtossZeratul",
                "ZergStetmann",
                "TerranMengsk",
                "TerranTychus",
                "ProtossArtanis",
                "TerranRaynor",
                "ZergKerrigan"
            )
        }
    )
}

function Remove-ExcludedCommanders {
    param([string[]]$Commanders)

    $normalizedIncludes = @($IncludeCommanders | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($normalizedIncludes.Count -gt 0) {
        $Commanders = @($Commanders | Where-Object { $normalizedIncludes -contains $_ })
    }

    $normalizedExcludes = @($ExcludeCommanders | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($ExcludeCommanders.Count -eq 0) {
        return @($Commanders)
    }

    return @($Commanders | Where-Object { $normalizedExcludes -notcontains $_ })
}

function Convert-SmokeOutputToMap {
    param([string[]]$Lines)

    $result = @{}
    foreach ($line in $Lines) {
        if ($line -match "^(SMOKE_[^=]+)=(.*)$") {
            $result[$matches[1]] = $matches[2]
        }
    }

    return $result
}

function Test-SmokeOutputOk {
    param([hashtable]$Smoke)

    $hasBaseEvidence = ($Smoke["SMOKE_BANK_LASTPHASE"] -eq "InitializeBase.exit") -or
        ((-not [string]::IsNullOrWhiteSpace($Smoke["SMOKE_BANK_TOWNHALL_UNIT"])) -and
        (-not [string]::IsNullOrWhiteSpace($Smoke["SMOKE_BANK_WORKER_UNIT"])) -and
        (-not [string]::IsNullOrWhiteSpace($Smoke["SMOKE_BANK_TOWNHALL_COUNT"])) -and
        (-not [string]::IsNullOrWhiteSpace($Smoke["SMOKE_BANK_WORKER_COUNT"])))

    if (($Smoke["SMOKE_NEW_CRASH"] -eq "1") -or
        ($Smoke["SMOKE_NEW_SCRIPTERROR"] -eq "1") -or
        ($Smoke["SMOKE_BANK_EVIDENCE"] -ne "1") -or
        (-not $hasBaseEvidence) -or
        ($Smoke["SMOKE_BANK_MATCH"] -ne "1")) {
        return $false
    }

    if ($Smoke.ContainsKey("SMOKE_LAUNCH_EXITCODE") -and
        (-not [string]::IsNullOrWhiteSpace($Smoke["SMOKE_LAUNCH_EXITCODE"])) -and
        ($Smoke["SMOKE_LAUNCH_EXITCODE"] -ne "0")) {
        return $false
    }

    if (-not $Smoke.ContainsKey("SMOKE_EVIDENCE")) {
        return $false
    }

    return (Test-Path -LiteralPath $Smoke["SMOKE_EVIDENCE"])
}

function Invoke-SmokeRun {
    param(
        [System.IO.DirectoryInfo]$Map,
        [string]$RunName,
        [string[]]$Commanders,
        [string]$ReportDirectory,
        [int]$Wait
    )

    $smokeScript = Join-Path (Get-WorkspaceRoot) "scripts\capture-7vs1-ingame-smoke.ps1"
    $safeMap = Convert-ToSafeName ([System.IO.Path]::GetFileNameWithoutExtension($Map.Name))
    $safeRun = Convert-ToSafeName $RunName
    $stdout = Join-Path $ReportDirectory ("{0}__{1}.stdout.txt" -f $safeMap, $safeRun)
    $stderr = Join-Path $ReportDirectory ("{0}__{1}.stderr.txt" -f $safeMap, $safeRun)
    $evidence = Join-Path $ReportDirectory ("{0}__{1}.evidence.json" -f $safeMap, $safeRun)

    $output = & $smokeScript `
        -MapSource $Map.FullName `
        -LiveMapName $Map.Name `
        -Commanders $Commanders `
        -WaitSeconds $Wait `
        -EvidencePath $evidence `
        -AbathurPatchProfile $AbathurPatchProfile 2>&1

    $output | Set-Content -LiteralPath $stdout -Encoding UTF8
    if ($LASTEXITCODE -and ($LASTEXITCODE -ne 0)) {
        "smoke script exited with code $LASTEXITCODE" | Set-Content -LiteralPath $stderr -Encoding UTF8
    }
    elseif (Test-Path -LiteralPath $stderr) {
        Remove-Item -LiteralPath $stderr -Force
    }

    $smoke = Convert-SmokeOutputToMap -Lines @($output)
    $ok = Test-SmokeOutputOk -Smoke $smoke

    return [pscustomobject]@{
        Timestamp = (Get-Date).ToString("o")
        Map = $Map.Name
        Run = $RunName
        Commanders = ($Commanders -join ",")
        Mode = $Mode
        Ok = $ok
        SuggestedStatus = $smoke["SMOKE_SUGGESTED_STATUS"]
        NewCrash = $smoke["SMOKE_NEW_CRASH"]
        NewScriptError = $smoke["SMOKE_NEW_SCRIPTERROR"]
        NewAlerts = $smoke["SMOKE_NEW_ALERTS"]
        Evidence = $smoke["SMOKE_EVIDENCE"]
        BankCommander = $smoke["SMOKE_BANK_COMMANDER"]
        BankMatch = $smoke["SMOKE_BANK_MATCH"]
        SmokeOutput = $stdout
        SmokeError = $(if (Test-Path -LiteralPath $stderr) { $stderr } else { "" })
    }
}

$workspaceRoot = Get-WorkspaceRoot
if ([string]::IsNullOrWhiteSpace($MapsRoot)) {
    $MapsRoot = Join-Path $workspaceRoot "Maps"
}
if ([string]::IsNullOrWhiteSpace($ReportRoot)) {
    $ReportRoot = Join-Path $workspaceRoot ("logs\matrix-smoke-{0:yyyyMMdd-HHmmss}" -f (Get-Date))
}

$null = New-Item -ItemType Directory -Path $ReportRoot -Force
$ReportRoot = (Resolve-Path -LiteralPath $ReportRoot).ProviderPath
$jsonlPath = Join-Path $ReportRoot "matrix-results.jsonl"
$csvPath = Join-Path $ReportRoot "matrix-results.csv"
$knownRuns = @{}
if ($Resume -and (Test-Path -LiteralPath $jsonlPath)) {
    Get-Content -LiteralPath $jsonlPath | ForEach-Object {
        if (-not [string]::IsNullOrWhiteSpace($_)) {
            $row = $_ | ConvertFrom-Json
            $knownRuns[("{0}|{1}" -f $row.Map, $row.Run)] = $true
        }
    }
}

$maps = @(Get-ChildItem -LiteralPath $MapsRoot -Directory -Filter "*_7vs1.SC2Map" | Sort-Object Name)
if ($maps.Count -eq 0) {
    throw "No *_7vs1.SC2Map directories found under $MapsRoot"
}
$normalizedMapNames = @($MapNames | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($normalizedMapNames.Count -gt 0) {
    $maps = @($maps | Where-Object { $normalizedMapNames -contains $_.Name -or $normalizedMapNames -contains [System.IO.Path]::GetFileNameWithoutExtension($_.Name) })
    if ($maps.Count -eq 0) {
        throw "MapNames filter matched no maps: $($normalizedMapNames -join ', ')"
    }
}

$plannedRuns = New-Object System.Collections.Generic.List[object]
foreach ($map in $maps) {
if ($Mode -eq "Solo") {
        foreach ($commander in (Remove-ExcludedCommanders -Commanders (Get-MatrixCommanders))) {
            $plannedRuns.Add([pscustomobject]@{
                Map = $map
                Name = $commander
                Commanders = @($commander)
            })
        }
    }
    else {
        foreach ($batch in Get-CommanderBatches) {
            $commanders = @(Remove-ExcludedCommanders -Commanders $batch.Commanders)
            if ($commanders.Count -eq 0) {
                continue
            }
            $plannedRuns.Add([pscustomobject]@{
                Map = $map
                Name = $batch.Name
                Commanders = @($commanders)
            })
        }
    }
}

$completed = 0
$failed = 0
$executed = 0
foreach ($run in $plannedRuns) {
    $key = "{0}|{1}" -f $run.Map.Name, $run.Name
    if ($knownRuns.ContainsKey($key)) {
        continue
    }
    if (($MaxRuns -gt 0) -and ($executed -ge $MaxRuns)) {
        break
    }

    $executed++
    Write-Host ("RUN {0}/{1} map={2} run={3} commanders={4}" -f $executed, $plannedRuns.Count, $run.Map.Name, $run.Name, ($run.Commanders -join ","))
    $result = Invoke-SmokeRun -Map $run.Map -RunName $run.Name -Commanders $run.Commanders -ReportDirectory $ReportRoot -Wait $WaitSeconds
    ($result | ConvertTo-Json -Compress) | Add-Content -LiteralPath $jsonlPath -Encoding UTF8
    if ($result.Ok) {
        $completed++
        Write-Host ("OK map={0} run={1}" -f $result.Map, $result.Run)
    }
    else {
        $failed++
        Write-Host ("FAIL map={0} run={1} status={2} output={3}" -f $result.Map, $result.Run, $result.SuggestedStatus, $result.SmokeOutput)
        if ($StopOnFailure) {
            break
        }
    }
}

$rows = @()
if (Test-Path -LiteralPath $jsonlPath) {
    $rows = @(Get-Content -LiteralPath $jsonlPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json })
    $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
}

$totalRows = @($rows).Count
$failedRows = @($rows | Where-Object { -not $_.Ok })
$alertRows = @($rows | Where-Object { $_.NewAlerts -eq "1" })
$summaryPath = Join-Path $ReportRoot "summary.md"
@(
    "# 7vs1 commander/map smoke matrix",
    "",
    "- Generated: $(Get-Date -Format o)",
    "- Mode: $Mode",
    "- WaitSeconds: $WaitSeconds",
    "- ExcludeCommanders: $(if ($ExcludeCommanders.Count -gt 0) { $ExcludeCommanders -join ',' } else { 'None' })",
    "- Maps: $($maps.Count)",
    "- PlannedRuns: $($plannedRuns.Count)",
    "- RecordedRuns: $totalRows",
    "- FailedRuns: $(@($failedRows).Count)",
    "- AlertRuns: $(@($alertRows).Count)",
    "- ResultsCsv: $csvPath",
    "",
    "## Failed Runs",
    ""
) | Set-Content -LiteralPath $summaryPath -Encoding UTF8

if (@($failedRows).Count -eq 0) {
    "- None" | Add-Content -LiteralPath $summaryPath -Encoding UTF8
}
else {
    foreach ($row in $failedRows) {
        ("- {0} / {1}: status={2}, crash={3}, scriptError={4}, alerts={5}, output={6}" -f $row.Map, $row.Run, $row.SuggestedStatus, $row.NewCrash, $row.NewScriptError, $row.NewAlerts, $row.SmokeOutput) |
            Add-Content -LiteralPath $summaryPath -Encoding UTF8
    }
}

@(
    "",
    "## Alert Runs",
    ""
) | Add-Content -LiteralPath $summaryPath -Encoding UTF8

if (@($alertRows).Count -eq 0) {
    "- None" | Add-Content -LiteralPath $summaryPath -Encoding UTF8
}
else {
    foreach ($row in $alertRows) {
        ("- {0} / {1}: status={2}, output={3}" -f $row.Map, $row.Run, $row.SuggestedStatus, $row.SmokeOutput) |
            Add-Content -LiteralPath $summaryPath -Encoding UTF8
    }
}

Write-Host "MATRIX_SUMMARY=$summaryPath"
Write-Host "MATRIX_RESULTS_JSONL=$jsonlPath"
Write-Host "MATRIX_RESULTS_CSV=$csvPath"
Write-Host "MATRIX_RECORDED=$totalRows"
Write-Host "MATRIX_FAILED=$(@($failedRows).Count)"
Write-Host "MATRIX_ALERTS=$(@($alertRows).Count)"

if (@($failedRows).Count -gt 0) {
    exit 1
}
