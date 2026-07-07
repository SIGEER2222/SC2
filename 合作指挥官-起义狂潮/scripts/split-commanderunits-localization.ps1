# Split CommanderUnits localization to 17 per-commander mods.
# Pure ASCII to avoid codepage issues.

$ErrorActionPreference = "Stop"

$scriptsRoot = $PSScriptRoot
$workspaceRoot = Split-Path -Parent $scriptsRoot
$modsRoot = Join-Path $workspaceRoot "Mods\7vs1"
$sourceMod = Join-Path $modsRoot "CommanderUnits.SC2Mod"

if (-not (Test-Path -LiteralPath $sourceMod)) {
    throw "Source mod not found: $sourceMod"
}

# Commanders sorted by name length desc (RaynorX before Raynor)
$commanders = @(
    "RaynorX","Stukov","Mengsk","Zeratul","Vorazun","Zagara","Artanis","Dehaka","Fenix","Karax",
    "Alarak","Abathur","Horner","Kerrigan","Nova","Raynor","Swann"
) | Sort-Object { $_.Length } -Descending

function Get-CommanderForLine {
    param([string]$line)

    if ($line -notmatch '^[^/=]+/[^/=]+/([A-Za-z0-9_]+)') {
        return $null
    }
    $id = $matches[1]

    foreach ($cmd in $commanders) {
        if ($id.StartsWith($cmd)) { return $cmd }
    }

    # Try embedded commander name (e.g. CommanderPrestige{Cmdr}, ReviveAbility{Cmdr})
    foreach ($cmd in $commanders) {
        if ($id -match $cmd) { return $cmd }
    }

    return $null
}

$locales = @("enUS","zhCN")
$fileNames = @("GameStrings.txt","ObjectStrings.txt","GameHotkeys.txt")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$totalIn = 0
$totalOut = 0
$unmatched = 0

foreach ($locale in $locales) {
    $srcDir = Join-Path $sourceMod "$locale.SC2Data\LocalizedData"
    if (-not (Test-Path -LiteralPath $srcDir)) {
        Write-Host "Skip locale (no dir): $locale"
        continue
    }

    foreach ($fileName in $fileNames) {
        $srcFile = Join-Path $srcDir $fileName
        if (-not (Test-Path -LiteralPath $srcFile)) {
            continue
        }

        $lines = [System.IO.File]::ReadAllLines($srcFile, $utf8NoBom)
        $nonEmpty = @($lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        Write-Host "Processing $locale/$fileName : $($nonEmpty.Count) lines"
        $totalIn += $nonEmpty.Count

        # Group by commander
        $groups = @{}
        $localUnmatched = @()

        foreach ($line in $nonEmpty) {
            $cmd = Get-CommanderForLine -line $line
            if ($null -eq $cmd) {
                $localUnmatched += $line
                $unmatched++
            } else {
                if (-not $groups.ContainsKey($cmd)) {
                    $groups[$cmd] = New-Object System.Collections.Generic.List[string]
                }
                $groups[$cmd].Add($line)
            }
        }

        # Write to each commander mod (clean then write)
        foreach ($cmd in ($groups.Keys | Sort-Object)) {
            $modDir = Join-Path $modsRoot "CommanderUnits_$cmd.SC2Mod"
            $dstDir = Join-Path $modDir "$locale.SC2Data\LocalizedData"
            if (-not (Test-Path -LiteralPath $dstDir)) {
                [void][System.IO.Directory]::CreateDirectory($dstDir)
            }
            $dstFile = Join-Path $dstDir $fileName

            # Clean existing file
            if (Test-Path -LiteralPath $dstFile) {
                [System.IO.File]::Delete($dstFile)
            }

            $content = ($groups[$cmd] -join "`r`n") + "`r`n"
            [System.IO.File]::WriteAllText($dstFile, $content, $utf8NoBom)
            $totalOut += $groups[$cmd].Count

            Write-Host ("  {0,-25} : {1,5} lines" -f "CommanderUnits_$cmd", $groups[$cmd].Count)
        }

        # Unmatched lines go to BaseCatalogPatch (preserve as generic)
        if ($localUnmatched.Count -gt 0) {
            $baseDir = Join-Path $modsRoot "BaseCatalogPatch.SC2Mod\$locale.SC2Data\LocalizedData"
            $baseFile = Join-Path $baseDir $fileName
            $appendContent = ($localUnmatched -join "`r`n") + "`r`n"
            [System.IO.File]::AppendAllText($baseFile, $appendContent, $utf8NoBom)
            $totalOut += $localUnmatched.Count
            Write-Host ("  {0,-25} : {1,5} lines (unmatched -> BaseCatalogPatch)" -f "(unmatched)", $localUnmatched.Count)
        }
    }
}

Write-Host ""
Write-Host "=== Coverage Check ==="
Write-Host "Total input lines : $totalIn"
Write-Host "Total output lines: $totalOut"
Write-Host "Unmatched lines   : $unmatched"
if ($totalIn -eq $totalOut) {
    Write-Host "PASS: Coverage 100%"
} else {
    Write-Host "FAIL: Lost $($totalIn - $totalOut) lines"
    exit 1
}
