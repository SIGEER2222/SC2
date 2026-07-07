# Split localization files from BaseCatalogPatch to individual mods.
# Uses .NET File API to avoid PowerShell native command restrictions.
# Pure ASCII comments to avoid gb2312 codepage parsing issues.

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$modsRoot = Join-Path $workspaceRoot "Mods\7vs1"
$baseMod = Join-Path $modsRoot "BaseCatalogPatch.SC2Mod"

# Commander to mod mapping (sorted by name length desc for prefix matching)
$commanderToMod = [ordered]@{
    "CommanderPrestige" = ""  # placeholder, handled specially
}

# Direct commander prefix -> mod name
$prefixToMod = @{
    "Tychus"    = "CommanderUnits_TychusXM"
    "Stetmann"  = "CommanderUnits_Stetmann"
    "Abathur"   = "CommanderUnits"
    "Kerrigan"  = "CommanderUnits"
    "Nova"      = "CommanderUnits"
    "RaynorX"   = "CommanderUnits"
    "Raynor"    = "CommanderUnits"
    "Horner"    = "CommanderUnits"
    "Swann"     = "CommanderUnits"
    "Zagara"    = "CommanderUnits"
    "Artanis"   = "CommanderUnits"
    "Vorazun"   = "CommanderUnits"
    "Karax"     = "CommanderUnits"
    "Alarak"    = "CommanderUnits"
    "Fenix"     = "CommanderUnits"
    "Zeratul"   = "CommanderUnits"
    "Stukov"    = "CommanderUnits"
    "Mengsk"    = "CommanderUnits"
    "Dehaka"    = "CommanderUnits"
}

# Sort prefixes by length descending (RaynorX before Raynor, etc.)
$sortedPrefixes = $prefixToMod.Keys | Sort-Object { $_.Length } -Descending

function Get-ModForLine {
    param([string]$line)

    if ($line -notmatch '^[^/=]+/[^/=]+/([A-Za-z0-9_]+)') {
        return "BaseCatalogPatch"
    }
    $id = $matches[1]

    # Reborn / HexTalents -> ExternalRefs
    if ($id -like "*Reborn*") { return "ExternalRefs" }
    if ($id -like "*HexTalents*") { return "ExternalRefs" }

    # Shared -> SharedUnits
    if ($id -like "*Shared*") { return "SharedUnits" }

    # Direct commander prefix
    foreach ($pfx in $sortedPrefixes) {
        if ($id.StartsWith($pfx)) {
            return $prefixToMod[$pfx]
        }
    }

    # CommanderPrestige{Cmdr}...
    if ($id -match '^CommanderPrestige([A-Za-z0-9]+)') {
        $rest = $matches[1]
        foreach ($pfx in $sortedPrefixes) {
            if ($rest.StartsWith($pfx)) {
                return $prefixToMod[$pfx]
            }
        }
    }

    # ReviveAbility{Cmdr}
    if ($id -match '^ReviveAbility([A-Za-z0-9]+)') {
        $rest = $matches[1]
        foreach ($pfx in $sortedPrefixes) {
            if ($rest.StartsWith($pfx)) {
                return $prefixToMod[$pfx]
            }
        }
    }

    # Artillery{Cmdr}..., NuclearAnnihilation{Cmdr}, BunkerDepot{Cmdr} etc.
    # Check if any commander name appears as a word in the ID
    foreach ($pfx in $sortedPrefixes) {
        if ($id -match "^(.+)$pfx(.*)$") {
            return $prefixToMod[$pfx]
        }
    }

    return "BaseCatalogPatch"
}

$locales = @("enUS", "zhCN")
$fileNames = @("GameStrings.txt", "ObjectStrings.txt", "GameHotkeys.txt")

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$stats = @{}
$totalIn = 0
$totalOut = 0

foreach ($locale in $locales) {
    $srcDir = Join-Path $baseMod "$locale.SC2Data\LocalizedData"

    foreach ($fileName in $fileNames) {
        $srcFile = Join-Path $srcDir $fileName
        if (-not (Test-Path -LiteralPath $srcFile)) {
            Write-Host "Skip (not found): $locale/$fileName"
            continue
        }

        $lines = [System.IO.File]::ReadAllLines($srcFile, $utf8NoBom)
        $nonEmpty = @($lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        Write-Host "Processing $locale/$fileName : $($nonEmpty.Count) non-empty lines"
        $totalIn += $nonEmpty.Count

        # Group lines by target mod
        $groups = @{}

        foreach ($line in $nonEmpty) {
            $modName = Get-ModForLine -line $line
            if (-not $groups.ContainsKey($modName)) {
                $groups[$modName] = New-Object System.Collections.Generic.List[string]
            }
            $groups[$modName].Add($line)
        }

        # Clean existing files in all mods for this locale/fileName before writing
        $allMods = @("BaseCatalogPatch", "CommanderUnits", "CommanderUnits_TychusXM", "CommanderUnits_Stetmann", "SharedUnits", "ExternalRefs")
        foreach ($cleanMod in $allMods) {
            $cleanDir = Join-Path $modsRoot "$cleanMod.SC2Mod\$locale.SC2Data\LocalizedData"
            $cleanFile = Join-Path $cleanDir $fileName
            if (Test-Path -LiteralPath $cleanFile) {
                [System.IO.File]::Delete($cleanFile)
            }
        }

        # Write to each mod (overwrite mode)
        foreach ($modName in ($groups.Keys | Sort-Object)) {
            $modDir = Join-Path $modsRoot "$modName.SC2Mod"
            $dstDir = Join-Path $modDir "$locale.SC2Data\LocalizedData"
            if (-not (Test-Path -LiteralPath $dstDir)) {
                [void][System.IO.Directory]::CreateDirectory($dstDir)
            }
            $dstFile = Join-Path $dstDir $fileName

            $content = ($groups[$modName] -join "`r`n") + "`r`n"
            [System.IO.File]::WriteAllText($dstFile, $content, $utf8NoBom)

            $key = "$locale/$fileName -> $modName"
            $stats[$key] = $groups[$modName].Count
            $totalOut += $groups[$modName].Count

            Write-Host ("  {0,-45} : {1,5} lines" -f $modName, $groups[$modName].Count)
        }
    }
}

Write-Host ""
Write-Host "=== Coverage Check ==="
Write-Host "Total input lines : $totalIn"
Write-Host "Total output lines: $totalOut"
if ($totalIn -eq $totalOut) {
    Write-Host "PASS: Coverage 100%"
} else {
    Write-Host "FAIL: Lost $($totalIn - $totalOut) lines"
    exit 1
}

Write-Host ""
Write-Host "=== Detailed Stats ==="
foreach ($key in ($stats.Keys | Sort-Object)) {
    Write-Host ("  {0,-55} : {1,5}" -f $key, $stats[$key])
}
