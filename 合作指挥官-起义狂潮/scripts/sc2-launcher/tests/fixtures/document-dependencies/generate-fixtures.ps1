<#
.SYNOPSIS
  Generate test fixtures for document-dependencies roundtrip tests.
.DESCRIPTION
  Creates:
    simple.DocumentHeader               - minimal binary header with 2 deps
    reborn-zexpedition03.DocumentHeader - copy from actual reborn port map
  Run once after checkout to populate fixtures directory.
#>
$ErrorActionPreference = "Stop"

$fixtureDir = $PSScriptRoot
# scripts/sc2-launcher/tests/fixtures/document-dependencies -> 合作指挥官-起义狂潮 (workspace root)
# 5 Split-Path -Parent calls
$projRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $fixtureDir))))

# === simple.DocumentHeader ===
# Format: <prefix bytes> + count(uint32 LE) + null-terminated UTF-8 strings
# Minimal prefix: 4 bytes of zeros (placeholder for real header prefix)
$simpleDeps = @("file:Mods/Test1.SC2Mod", "file:Mods/Test2.SC2Mod")
$prefix = [byte[]](0x00, 0x00, 0x00, 0x00)
$countBytes = [System.BitConverter]::GetBytes([uint32]$simpleDeps.Count)
$depBytes = [System.Text.Encoding]::UTF8.GetBytes(($simpleDeps -join "`0") + "`0")
$stream = New-Object System.IO.MemoryStream
$stream.Write($prefix, 0, $prefix.Length)
$stream.Write($countBytes, 0, $countBytes.Length)
$stream.Write($depBytes, 0, $depBytes.Length)
$simplePath = Join-Path $fixtureDir "simple.DocumentHeader"
[System.IO.File]::WriteAllBytes($simplePath, $stream.ToArray())
Write-Host "Generated: $simplePath ($($simpleDeps.Count) deps)"

# === reborn-zexpedition03.DocumentHeader ===
$rebornMapHeader = Join-Path $projRoot "Maps\zexpedition03_reborn_port.SC2Map\DocumentHeader"
$rebornFixturePath = Join-Path $fixtureDir "reborn-zexpedition03.DocumentHeader"
if (Test-Path -LiteralPath $rebornMapHeader) {
    [System.IO.File]::Copy($rebornMapHeader, $rebornFixturePath, $true)
    Write-Host "Copied: $rebornFixturePath (from $rebornMapHeader)"
} else {
    Write-Host "WARN: reborn map DocumentHeader not found at $rebornMapHeader"
    Write-Host "      Skipping reborn-zexpedition03.DocumentHeader fixture"
}

# === reborn-zexpedition03.DocumentInfo ===
$rebornMapInfo = Join-Path $projRoot "Maps\zexpedition03_reborn_port.SC2Map\DocumentInfo"
$rebornInfoFixturePath = Join-Path $fixtureDir "reborn-zexpedition03.DocumentInfo"
if (Test-Path -LiteralPath $rebornMapInfo) {
    [System.IO.File]::Copy($rebornMapInfo, $rebornInfoFixturePath, $true)
    Write-Host "Copied: $rebornInfoFixturePath (from $rebornMapInfo)"
} else {
    Write-Host "WARN: reborn map DocumentInfo not found at $rebornMapInfo"
    Write-Host "      Skipping reborn-zexpedition03.DocumentInfo fixture"
}

Write-Host ""
Write-Host "Fixture generation complete."
