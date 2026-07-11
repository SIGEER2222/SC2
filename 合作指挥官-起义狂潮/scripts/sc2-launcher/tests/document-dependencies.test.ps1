<#
.SYNOPSIS
  Roundtrip + consistency tests for document-dependencies module.
.DESCRIPTION
  Tests:
    1. Read simple.DocumentHeader -> 2 deps
    2. Write same deps back -> read again -> identical (on temp copy, fixture stays read-only)
    3. Compare-DocumentDependencySets returns Equal=true for same sets
    4. Test-DocumentDependencyConsistency flags duplicates
    5. Test-DocumentDependencyConsistency flags empty entries
    6. Roundtrip on reborn-zexpedition03.DocumentHeader (on temp copy)
    7. DocumentHeader vs DocumentInfo consistency (on temp copies)
    8. Write then read on a fresh temp file
  Fixtures are NEVER modified — all write tests run on temp copies.
  Exit code 0 = all pass, non-zero = failures.
#>
$ErrorActionPreference = "Stop"

$fixtureDir = Join-Path $PSScriptRoot "fixtures\document-dependencies"
$moduleRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $moduleRoot "document-dependencies.ps1")

$pass = 0
$fail = 0
$failures = @()
$tempFiles = @()

function Assert-True {
    param([string]$Name, [bool]$Cond, [string]$Detail = "")
    if ($Cond) {
        $script:pass++
        Write-Host "  PASS: $Name"
    } else {
        $script:fail++
        $script:failures += $Name + $(if ($Detail) { " - $Detail" } else { "" })
        Write-Host "  FAIL: $Name" -ForegroundColor Red
        if ($Detail) { Write-Host "        $Detail" -ForegroundColor Red }
    }
}

function New-TempCopy {
    <#
    .SYNOPSIS
      Copy a fixture file to a temp location so the fixture stays read-only.
      Returns the temp path. All temp files are cleaned up at the end.
    #>
    param([string]$Source)
    $tempPath = Join-Path $env:TEMP "test-fixture-$([System.Guid]::NewGuid().ToString('N').Substring(0,8)).bin"
    [System.IO.File]::Copy($Source, $tempPath, $true)
    $script:tempFiles += $tempPath
    return $tempPath
}

function Cleanup-TempFiles {
    foreach ($f in $script:tempFiles) {
        if (Test-Path -LiteralPath $f) { [System.IO.File]::Delete($f) }
    }
    # Also clean up any stray backup files in fixture dir
    Get-ChildItem -LiteralPath $fixtureDir -Filter "*.roundtrip-bak" -ErrorAction SilentlyContinue | ForEach-Object {
        [System.IO.File]::Delete($_.FullName)
    }
}

Write-Host "=== document-dependencies roundtrip tests ==="

# === Test 1: Read simple.DocumentHeader (read-only) ===
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

# === Test 2: Roundtrip on temp copy of simple.DocumentHeader ===
if (Test-Path -LiteralPath $simpleHeader) {
    $tempSimple = New-TempCopy -Source $simpleHeader
    $rt = Test-DocumentDependencyRoundtrip -HeaderPath $tempSimple
    Assert-True "Simple header roundtrip valid (temp copy)" $rt.Valid
    Assert-True "Simple header roundtrip dep count matches" ($rt.OriginalDeps.Count -eq $rt.RoundtripDeps.Count) "orig=$($rt.OriginalDeps.Count) rt=$($rt.RoundtripDeps.Count)"
    Assert-True "Simple header roundtrip first dep stable" ($rt.RoundtripDeps[0] -eq "file:Mods/Test1.SC2Mod") "got $($rt.RoundtripDeps[0])"
    # Verify fixture is unchanged
    $fixtureDepsAfter = Read-DocumentHeaderDependencies -Path $simpleHeader
    Assert-True "Fixture unchanged after temp-copy roundtrip" ($fixtureDepsAfter.Count -eq 2) "fixture deps count changed to $($fixtureDepsAfter.Count)"
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

# === Test 6: Roundtrip on temp copy of reborn-zexpedition03.DocumentHeader ===
$rebornHeader = Join-Path $fixtureDir "reborn-zexpedition03.DocumentHeader"
if (Test-Path -LiteralPath $rebornHeader) {
    $tempRebornHeader = New-TempCopy -Source $rebornHeader
    $rebornRt = Test-DocumentDependencyRoundtrip -HeaderPath $tempRebornHeader
    Assert-True "Reborn header roundtrip valid (temp copy)" $rebornRt.Valid ($rebornRt.Errors -join '; ')
    Assert-True "Reborn header roundtrip count stable" ($rebornRt.OriginalDeps.Count -eq $rebornRt.RoundtripDeps.Count) "orig=$($rebornRt.OriginalDeps.Count) rt=$($rebornRt.RoundtripDeps.Count)"
    # Verify fixture is unchanged
    $fixtureRebornAfter = Read-DocumentHeaderDependencies -Path $rebornHeader
    $fixtureRebornBefore = Read-DocumentHeaderDependencies -Path (New-TempCopy -Source $rebornHeader)
    Assert-True "Reborn fixture unchanged after temp-copy roundtrip" ($fixtureRebornAfter.Count -eq $fixtureRebornBefore.Count) "fixture deps count changed"

    # === Test 7: Header vs Info consistency (on temp copies) ===
    $rebornInfo = Join-Path $fixtureDir "reborn-zexpedition03.DocumentInfo"
    if (Test-Path -LiteralPath $rebornInfo) {
        $tempRebornInfo = New-TempCopy -Source $rebornInfo
        $rebornConsistency = Test-DocumentDependencyRoundtrip -HeaderPath $tempRebornHeader -InfoPath $tempRebornInfo
        # The source map's DocumentHeader and DocumentInfo are intentionally inconsistent
        # (header has campaign deps + backslash paths, info has forward-slash paths).
        # The tool must DETECT this mismatch - that's its job. The launcher's
        # Set-MapDependencies will rewrite both to the same list at runtime.
        Assert-True "Reborn header vs info mismatch is detected" (-not $rebornConsistency.HeaderVsInfoDiff.Equal) "tool reported Equal=true but source map is known to be inconsistent"
        Assert-True "Reborn header vs info diff has OnlyInA" ($rebornConsistency.HeaderVsInfoDiff.OnlyInA.Count -gt 0) "expected header-only deps"
        Assert-True "Reborn header vs info diff has OnlyInB" ($rebornConsistency.HeaderVsInfoDiff.OnlyInB.Count -gt 0) "expected info-only deps"
    } else {
        Write-Host "SKIP: reborn-zexpedition03.DocumentInfo fixture missing"
    }
} else {
    Write-Host "SKIP: reborn-zexpedition03.DocumentHeader fixture missing (run generate-fixtures.ps1 first)"
}

# === Test 8: Write then read on a fresh temp file ===
$tempPath = Join-Path $env:TEMP "test-docheader-$([System.Guid]::NewGuid().ToString('N').Substring(0,8)).bin"
$script:tempFiles += $tempPath
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
    # Cleanup handled by Cleanup-TempFiles
}

# === Cleanup all temp files ===
Cleanup-TempFiles

Write-Host ""
Write-Host "=== Summary: $pass passed, $fail failed ==="
if ($fail -gt 0) {
    Write-Host "Failures:" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
exit 0
