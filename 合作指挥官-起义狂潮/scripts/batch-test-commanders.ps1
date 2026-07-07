# Batch test all commanders after CommanderUnits split.
# Pure ASCII to avoid codepage issues.

$ErrorActionPreference = "Continue"

$scriptsRoot = $PSScriptRoot
$workspaceRoot = Split-Path -Parent $scriptsRoot
$launchScript = Join-Path $scriptsRoot "launch-7vs1-coop-test.ps1"
$waitScript = Join-Path $scriptsRoot "wait-for-game-ready.ps1"

# Commanders to test (Raynor/Kerrigan already tested, RaynorX is Raynor extension)
$commanders = @(
    "ZergAbathur",
    "TerranHorner",
    "TerranNova",
    "ProtossAlarak",
    "ProtossArtanis",
    "ZergDehaka",
    "ProtossFenix",
    "ProtossKarax",
    "TerranMengsk",
    "ZergStukov",
    "TerranSwann",
    "ProtossVorazun",
    "ZergZagara",
    "ProtossZeratul",
    "TerranTychus",
    "ZergStetmann"
)

$results = @()
$total = $commanders.Count
$idx = 0

foreach ($cmd in $commanders) {
    $idx++
    Write-Host ""
    Write-Host "========================================"
    Write-Host "[$idx/$total] Testing: $cmd"
    Write-Host "========================================"

    # Stop any running SC2
    Get-Process -Name 'SC2_x64','SC2Switcher_x64' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # Clean old logs
    $logs = "C:\Users\22448\Documents\StarCraft II\GameLogs"
    if (Test-Path $logs) {
        Get-ChildItem -LiteralPath $logs -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^(ScriptError|Alerts)\.txt$' } |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
    }

    # Launch
    $launchOk = $true
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $launchScript -Commanders @($cmd) 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) {
            $launchOk = $false
            Write-Host "LAUNCH FAILED (exit $LASTEXITCODE)"
        }
    } catch {
        $launchOk = $false
        Write-Host "LAUNCH EXCEPTION: $_"
    }

    if (-not $launchOk) {
        $results += [PSCustomObject]@{ Commander=$cmd; Status="LAUNCH_FAIL"; Time=""; Detail="" }
        continue
    }

    # Wait for game ready
    $waitOk = $true
    $waitOutput = ""
    try {
        $waitOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $waitScript 2>&1 | Out-String
        Write-Host $waitOutput
        if ($LASTEXITCODE -ne 0) {
            $waitOk = $false
        }
    } catch {
        $waitOk = $false
        $waitOutput = "EXCEPTION: $_"
    }

    # Parse result
    $status = "UNKNOWN"
    $time = ""
    if ($waitOutput -match 'Total time:\s*([\d.]+)\s*s') { $time = $matches[1] + "s" }
    if ($waitOutput -match 'ScriptError:\s*Not detected') { $status = "PASS" }
    elseif ($waitOutput -match 'ScriptError:\s*Detected') { $status = "FAIL_ScriptError" }
    elseif ($waitOutput -match 'Game process:\s*Exited') { $status = "FAIL_Crash" }
    elseif ($waitOutput -match 'Timeout') { $status = "TIMEOUT" }
    elseif (-not $waitOk) { $status = "WAIT_FAIL" }

    # Extract ScriptError detail if any
    $detail = ""
    if ($status -like "FAIL*") {
        $scriptErr = Get-ChildItem -LiteralPath $logs -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq 'ScriptError.txt' } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($scriptErr) {
            $errContent = Get-Content -LiteralPath $scriptErr.FullName -Encoding UTF8 -Raw -ErrorAction SilentlyContinue
            if ($errContent) {
                $detail = ($errContent -split "`n" | Select-Object -First 5) -join " | "
            }
        }
    }

    $results += [PSCustomObject]@{ Commander=$cmd; Status=$status; Time=$time; Detail=$detail }

    # Stop game before next iteration
    Get-Process -Name 'SC2_x64','SC2Switcher_x64' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "========================================"
Write-Host "=== Batch Test Summary ==="
Write-Host "========================================"
$results | Format-Table -AutoSize

$pass = ($results | Where-Object { $_.Status -eq "PASS" }).Count
$fail = ($results | Where-Object { $_.Status -ne "PASS" }).Count
Write-Host ""
Write-Host "PASS: $pass / $($results.Count)"
Write-Host "FAIL: $fail / $($results.Count)"

if ($fail -gt 0) {
    Write-Host ""
    Write-Host "=== Failed Commanders ==="
    $results | Where-Object { $_.Status -ne "PASS" } | Format-Table -AutoSize
}

# Save results to file
$reportPath = Join-Path $workspaceRoot "docs\commander-split-test-report.txt"
$reportDir = Split-Path -Parent $reportPath
if (-not (Test-Path -LiteralPath $reportDir)) {
    [void][System.IO.Directory]::CreateDirectory($reportDir)
}
$report = "Commander Split Test Report`r`n"
$report += "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n"
$report += "========================================`r`n`r`n"
foreach ($r in $results) {
    $report += "$($r.Commander) | $($r.Status) | $($r.Time)`r`n"
    if ($r.Detail) { $report += "  Detail: $($r.Detail)`r`n" }
}
$report += "`r`nPASS: $pass / $($results.Count)`r`n"
$report += "FAIL: $fail / $($results.Count)`r`n"
[System.IO.File]::WriteAllText($reportPath, $report, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ""
Write-Host "Report saved to: $reportPath"
