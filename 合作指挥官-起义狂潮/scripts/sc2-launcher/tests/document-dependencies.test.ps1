<#
.SYNOPSIS
  Roundtrip + consistency tests for document-dependencies module.
.DESCRIPTION
  Tests:
    1. Read simple.DocumentHeader -> 2 deps
    2. Write same deps back -> read again -> identical
    3. Compare-DocumentDependencySets returns Equal=true for same sets
    4. Test-DocumentDependencyConsistency flags duplicates
    5. Test-DocumentDependencyConsistency flags empty entries
    6. Roundtrip on reborn-zexpedition03.DocumentHeader (if fixture exists)
    7. DocumentHeader vs DocumentInfo consistency (if both fixtures exist)
  Exit code 0 = all pass, non-zero = failures.
#>
$ErrorActionPreference = "Stop"

$fixtureDir = Join-Path $PSScriptRoot "fixtures\document-dependencies"
$moduleRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $moduleRoot "document-dependencies.ps1")

$pass = 0
$fail = 0
$failures = @()

function Assert-True {
    param([string]$Name, [bool]$Cond, [string]$Detail = "")
    if ($Cond) {
        $script:pass++
        Write-Host "  PASS: $Name"
    } else {
        $script:fail++
        $script:failures += $Name + $(if ($Detail) { " — $Detail" } else { "" })
        Write-Host "  FAIL: $Name" -ForegroundColor Red
        if ($Detail) { Write-Host "        $Detail" -ForegroundColor Red }
    }
}

Write-Host "=== document-dependencies roundtrip tests ==="

# === Test 1: Read simple.DocumentHeader ===
$simpleHeader = Join-Path $fixtureDir "simple.DocumentHeader"
if (Test-Path -LiteralPath $simpleHeader) {
    $deps = Read-DocumentHeaderDependencies -Path $simpleHeader
    Assert-True "Read simple.DocumentHeader returns 2 deps" ($deps.Count -eq 2) "got $($deps.Count)"
    Assert-True "First dep is file:Mods/Test1.SC2Mod" ($deps[0] -eq "file:Mods/Test1.SC2Mod") "got $($deps[0])"
    Assert-True "Second dep is file:Mods/Test2.SC2Mod" ($deps[1] -eq "file:Mods/Test2.SC2Mod") "got $($deps[1])"
} else {
    Write-Host "SKIP: simple.DocumentHeader fixture missing (run generate-fixtures.ps1 first)"
    $script:fail++
    $script:failures += "simple.DocumentHeader fixture missing"
}

# === Test 2: Roundtrip on simple.DocumentHeader (with backup) ===
if (Test-Path -LiteralPath $simpleHeader) {
    $rt = Test-DocumentDependencyRoundtrip -HeaderPath $simpleHeader -Backup
    Assert-True "Simple header roundtrip valid" $rt.Valid
    Assert-True "Simple header roundtrip dep count matches" ($rt.OriginalDeps.Count -eq $rt.RoundtripDeps.Count) "orig=$($rt.OriginalDeps.Count) rt=$($rt.RoundtripDeps.Count)"
    Assert-True "Simple header roundtrip first dep stable" ($rt.RoundtripDeps[0] -eq "file:Mods/Test1.SC2Mod") "got $($rt.RoundtripDeps[0])"
    # Cleanup backup
    $bak = "$simpleHeader.roundtrip-bak"
    if (Test-Path -LiteralPath $bak) { [System.IO.File]::Delete($bak) }
}

# === Test 3: Compare-DocumentDependencySets ===
$setA = @("file:Mods/X.SC2Mod", "file:Mods/Y.SC2Mod", "file:Mods/Z.SC2Mod")
$setB = @("file:Mods/Y.SC2Mod", "file:Mods/Z.SC2Mod", "file:Mods/X.SC2Mod")
$cmp = Compare-DocumentDependencySets -A $setA -B $setB
Assert-True "Compare sets equal (order-insensitive)" $cmp.Equal "OnlyInA=$($cmp.OnlyInA) OnlyInB=$($cmp.OnlyInB)"

$setC = @("file:Mods/X.SC2Mod", "file:Mods/W.SC2Mod")
$cmp2 = Compare-DocumentDependencySets -A $setA -B $setC
Assert-True "Compare sets not equal when different" (-not $cmp2.Equal)
Assert-True "Compare sets OnlyInA has Y,Z" ($cmp2.OnlyInA.Count -eq 2) "got $($cmp2.OnlyInA.Count)"
Assert-True "Compare sets OnlyInB has W" ($cmp2.OnlyInB.Count -eq 1) "got $($cmp2.OnlyInB.Count)"

# === Test 4: Consistency flags duplicates ===
$dupDeps = @("file:Mods/A.SC2Mod", "file:Mods/A.SC2Mod", "file:Mods/B.SC2Mod")
$dupResult = Test-DocumentDependencyConsistency -Dependencies $dupDeps
Assert-True "Consistency flags duplicates" (-not $dupResult.Valid)
Assert-True "Consistency reports 1 duplicate error" ($dupResult.Errors.Count -eq 1) "got $($dupResult.Errors.Count)"

# === Test 5: Consistency flags empty entries ===
$emptyDeps = @("file:Mods/A.SC2Mod", "", "file:Mods/B.SC2Mod")
$emptyResult = Test-DocumentDependencyConsistency -Dependencies $emptyDeps
Assert-True "Consistency flags empty entries" (-not $emptyResult.Valid)

# === Test 6: Roundtrip on reborn-zexpedition03.DocumentHeader ===
$rebornHeader = Join-Path $fixtureDir "reborn-zexpedition03.DocumentHeader"
if (Test-Path -LiteralPath $rebornHeader) {
    $rebornRt = Test-DocumentDependencyRoundtrip -HeaderPath $rebornHeader -Backup
    Assert-True "Reborn header roundtrip valid" $rebornRt.Valid ($rebornRt.Errors -join '; ')
    Assert-True "Reborn header roundtrip count stable" ($rebornRt.OriginalDeps.Count -eq $rebornRt.RoundtripDeps.Count) "orig=$($rebornRt.OriginalDeps.Count) rt=$($rebornRt.RoundtripDeps.Count)"
    # Cleanup backup
    $rebornBak = "$rebornHeader.roundtrip-bak"
    if (Test-Path -LiteralPath $rebornBak) { [System.IO.File]::Delete($rebornBak) }

    # === Test 7: Header vs Info consistency ===
    $rebornInfo = Join-Path $fixtureDir "reborn-zexpedition03.DocumentInfo"
    if (Test-Path -LiteralPath $rebornInfo) {
        $rebornConsistency = Test-DocumentDependencyRoundtrip -HeaderPath $rebornHeader -InfoPath $rebornInfo -Backup
        # The source map's DocumentHeader and DocumentInfo are intentionally inconsistent
        # (header has campaign deps + backslash paths, info has forward-slash paths).
        # The tool must DETECT this mismatch — that's its job. The launcher's
        # Set-MapDependencies will rewrite both to the same list at runtime.
        Assert-True "Reborn header vs info mismatch is detected" (-not $rebornConsistency.HeaderVsInfoDiff.Equal) "tool reported Equal=true but source map is known to be inconsistent"
        Assert-True "Reborn header vs info diff has OnlyInA" ($rebornConsistency.HeaderVsInfoDiff.OnlyInA.Count -gt 0) "expected header-only deps"
        Assert-True "Reborn header vs info diff has OnlyInB" ($rebornConsistency.HeaderVsInfoDiff.OnlyInB.Count -gt 0) "expected info-only deps"
        # Cleanup backup
        $rebornInfoBak = "$rebornInfo.roundtrip-bak"
        if (Test-Path -LiteralPath $rebornInfoBak) { [System.IO.File]::Delete($rebornInfoBak) }
        $rebornHeaderBak2 = "$rebornHeader.roundtrip-bak"
        if (Test-Path -LiteralPath $rebornHeaderBak2) { [System.IO.File]::Delete($rebornHeaderBak2) }
    } else {
        Write-Host "SKIP: reborn-zexpedition03.DocumentInfo fixture missing"
    }
} else {
    Write-Host "SKIP: reborn-zexpedition03.DocumentHeader fixture missing (run generate-fixtures.ps1 first)"
}

# === Test 8: Write then read on a fresh temp file ===
$tempPath = Join-Path $env:TEMP "test-docheader-$([System.Guid]::NewGuid().ToString('N').Substring(0,8)).bin"
try {
    # Build a minimal valid DocumentHeader with prefix + count + deps
    $prefix = [byte[]](0x00, 0x00, 0x00, 0x00)
    $testDeps = @("file:Mods/Write1.SC2Mod", "file:Mods/Write2.SC2Mod", "file:Mods/Write3.SC2Mod")
    $countBytes = [System.BitConverter]::GetBytes([uint32]$testDeps.Count)
    $depBytes = [System.Text.Encoding]::UTF8.GetBytes(($testDeps -join "`0") + "`0")
    $stream = New-Object System.IO.MemoryStream
    $stream.Write($prefix, 0, $prefix.Length)
    $stream.Write($countBytes, 0, $countBytes.Length)
    $stream.Write($depBytes, 0, $depBytes.Length)
    [System.IO.File]::WriteAllBytes($tempPath, $stream.ToArray())

    # Write different deps
    $newDeps = @("file:Mods/NewA.SC2Mod", "file:Mods/NewB.SC2Mod")
    Write-DocumentHeaderDependencies -Path $tempPath -Dependencies $newDeps
    $readBack = Read-DocumentHeaderDependencies -Path $tempPath
    Assert-True "Write then read returns new deps count" ($readBack.Count -eq 2) "got $($readBack.Count)"
    Assert-True "Write then read first dep correct" ($readBack[0] -eq "file:Mods/NewA.SC2Mod") "got $($readBack[0])"
    Assert-True "Write then read second dep correct" ($readBack[1] -eq "file:Mods/NewB.SC2Mod") "got $($readBack[1])"
} finally {
    if (Test-Path -LiteralPath $tempPath) { [System.IO.File]::Delete($tempPath) }
}

Write-Host ""
Write-Host "=== Summary: $pass passed, $fail failed ==="
if ($fail -gt 0) {
    Write-Host "Failures:" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
exit 0
