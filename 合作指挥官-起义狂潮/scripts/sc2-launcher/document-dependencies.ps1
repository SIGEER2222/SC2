<#
.SYNOPSIS
  DocumentHeader / DocumentInfo dependency table reader, writer, and roundtrip tester.
.DESCRIPTION
  Extracted from map-sync.ps1 to provide testable binary dependency operations.
  DocumentHeader format: count(uint32 LE) + null-terminated UTF-8 strings.
  DocumentInfo format: XML with <Dependencies><Value>...</Value></Dependencies>.

  Public functions:
    Read-DocumentHeaderDependencies    - parse binary header -> string[]
    Write-DocumentHeaderDependencies   - write string[] -> binary header
    Read-DocumentInfoDependencies      - parse XML info -> string[]
    Write-DocumentInfoDependencies     - write string[] -> XML info
    Test-DocumentDependencyRoundtrip   - read -> write -> read consistency
    Compare-DocumentDependencySets     - set-diff two string[]
    Test-DocumentDependencyConsistency - empty/duplicate/header-vs-info checks
    Set-MapDependencies                - orchestrate write to both files
#>

# === Internal binary helpers ===
function Test-ByteSequenceAt {
    param([byte[]]$Bytes, [int]$Offset, [byte[]]$Needle)
    if ($Offset + $Needle.Length -gt $Bytes.Length) { return $false }
    for ($i = 0; $i -lt $Needle.Length; $i++) {
        if ($Bytes[$Offset + $i] -ne $Needle[$i]) { return $false }
    }
    return $true
}

function Find-DocumentHeaderDependencyStart {
    <#
    .SYNOPSIS
      Locate the offset of the first dependency string in DocumentHeader.
      Looks for "file:" or "bnet:" preceded by a sane uint32 count.
    #>
    param([byte[]]$Bytes)
    $markers = @(
        [System.Text.Encoding]::UTF8.GetBytes("file:"),
        [System.Text.Encoding]::UTF8.GetBytes("bnet:")
    )
    for ($offset = 4; $offset -lt $Bytes.Length; $offset++) {
        foreach ($marker in $markers) {
            if (-not (Test-ByteSequenceAt -Bytes $Bytes -Offset $offset -Needle $marker)) { continue }
            $count = [System.BitConverter]::ToUInt32($Bytes, $offset - 4)
            if (($count -gt 0) -and ($count -lt 128)) { return $offset }
        }
    }
    throw "DocumentHeader dependency table not found."
}

function Get-DocumentHeaderDependencyEndOffset {
    <#
    .SYNOPSIS
      Walk past $Count null-terminated strings starting at $Start, return offset after last null.
    #>
    param([byte[]]$Bytes, [int]$Start, [uint32]$Count)
    $offset = $Start
    for ($index = 0; $index -lt $Count; $index++) {
        while (($offset -lt $Bytes.Length) -and ($Bytes[$offset] -ne 0)) { $offset++ }
        if ($offset -ge $Bytes.Length) { throw "DocumentHeader dependency string is not null-terminated." }
        $offset++
    }
    return $offset
}

# === Public read/write ===
function Read-DocumentHeaderDependencies {
    <#
    .SYNOPSIS
      Parse DocumentHeader binary and return the dependency strings.
    .OUTPUTS
      string[] (empty array if no dependencies found)
    #>
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "DocumentHeader not found: $Path" }
    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($Path)
    try {
        $dependencyStart = Find-DocumentHeaderDependencyStart -Bytes $bytes
    } catch {
        return @()
    }
    $countOffset = $dependencyStart - 4
    $currentCount = [System.BitConverter]::ToUInt32($bytes, $countOffset)
    $deps = @()
    $offset = $dependencyStart
    for ($i = 0; $i -lt $currentCount; $i++) {
        $end = $offset
        while (($end -lt $bytes.Length) -and ($bytes[$end] -ne 0)) { $end++ }
        $dep = [System.Text.Encoding]::UTF8.GetString($bytes, $offset, $end - $offset)
        $deps += $dep
        $offset = $end + 1
    }
    return $deps
}

function Write-DocumentHeaderDependencies {
    <#
    .SYNOPSIS
      Rewrite DocumentHeader binary with the given dependency strings.
      Preserves the prefix (before count) and suffix (after dependency table).
    #>
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string[]]$Dependencies
    )
    if (-not (Test-Path -LiteralPath $Path)) { throw "DocumentHeader not found: $Path" }
    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($Path)
    $dependencyStart = Find-DocumentHeaderDependencyStart -Bytes $bytes
    $countOffset = $dependencyStart - 4
    $currentCount = [System.BitConverter]::ToUInt32($bytes, $countOffset)
    $dependencyEnd = Get-DocumentHeaderDependencyEndOffset -Bytes $bytes -Start $dependencyStart -Count $currentCount
    $depArray = @($Dependencies)
    $dependencyBytes = [System.Text.Encoding]::UTF8.GetBytes(($depArray -join "`0") + "`0")
    $countBytes = [System.BitConverter]::GetBytes([uint32]$depArray.Count)
    $stream = New-Object System.IO.MemoryStream
    $stream.Write($bytes, 0, $countOffset)
    $stream.Write($countBytes, 0, $countBytes.Length)
    $stream.Write($dependencyBytes, 0, $dependencyBytes.Length)
    $stream.Write($bytes, $dependencyEnd, $bytes.Length - $dependencyEnd)
    [System.IO.File]::WriteAllBytes($Path, $stream.ToArray())
}

function Read-DocumentInfoDependencies {
    <#
    .SYNOPSIS
      Parse DocumentInfo XML and return the <Value> entries under <Dependencies>.
    .OUTPUTS
      string[] (empty array if no Dependencies element)
    #>
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "DocumentInfo not found: $Path" }
    $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $deps = @()
    if ($content -match '(?s)<Dependencies>(.*?)</Dependencies>') {
        $depsBlock = $matches[1]
        $matches2 = [regex]::Matches($depsBlock, '<Value>(.*?)</Value>')
        foreach ($m in $matches2) {
            $deps += $m.Groups[1].Value
        }
    }
    return $deps
}

function Write-DocumentInfoDependencies {
    <#
    .SYNOPSIS
      Rewrite DocumentInfo XML with the given dependency strings.
      Preserves <Preload> section if present in the original.
    #>
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string[]]$Dependencies
    )
    $depArray = @($Dependencies)
    $xml = "<?xml version='1.0' encoding='utf-8'?>`n<DocInfo>`n    <Dependencies>`n"
    foreach ($dep in $depArray) {
        $xml += "        <Value>$dep</Value>`n"
    }
    $xml += "    </Dependencies>`n"
    $origContent = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    if ($origContent -match '(?s)<Preload>.*?</Preload>') {
        $preloadSection = $matches[0]
        $xml += "    $preloadSection`n"
    }
    $xml += "</DocInfo>"
    [System.IO.File]::WriteAllText($Path, $xml, [System.Text.Encoding]::UTF8)
}

# === Consistency + roundtrip ===
function Compare-DocumentDependencySets {
    <#
    .SYNOPSIS
      Set-diff two dependency arrays (order-insensitive).
    .OUTPUTS
      PSCustomObject with:
        OnlyInA    - string[] present in A but not B
        OnlyInB    - string[] present in B but not A
        InBoth     - string[] in both
        Equal      - bool, true if sets match
    #>
    param(
        [Parameter(Mandatory=$true)][string[]]$A,
        [Parameter(Mandatory=$true)][string[]]$B
    )
    $setA = [System.Collections.Generic.HashSet[string]]::new([string[]]$A)
    $setB = [System.Collections.Generic.HashSet[string]]::new([string[]]$B)
    $onlyA = @()
    foreach ($x in $setA) { if (-not $setB.Contains($x)) { $onlyA += $x } }
    $onlyB = @()
    foreach ($x in $setB) { if (-not $setA.Contains($x)) { $onlyB += $x } }
    $both = @()
    foreach ($x in $setA) { if ($setB.Contains($x)) { $both += $x } }
    return [PSCustomObject]@{
        OnlyInA = $onlyA
        OnlyInB = $onlyB
        InBoth  = $both
        Equal   = ($onlyA.Count -eq 0 -and $onlyB.Count -eq 0)
    }
}

function Test-DocumentDependencyConsistency {
    <#
    .SYNOPSIS
      Validate a single dependency array for empty entries and duplicates.
    .OUTPUTS
      PSCustomObject with .Valid (bool), .Errors (string[]), .Warnings (string[])
    #>
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string[]]$Dependencies
    )
    $result = [PSCustomObject]@{ Valid = $true; Errors = @(); Warnings = @() }
    $depArray = @($Dependencies)
    # empty entries
    foreach ($d in $depArray) {
        if ([string]::IsNullOrWhiteSpace($d)) {
            $result.Valid = $false
            $result.Errors += "Empty dependency entry found"
        }
    }
    # duplicates
    $dups = $depArray | Group-Object | Where-Object { $_.Count -gt 1 }
    foreach ($dup in $dups) {
        $result.Valid = $false
        $result.Errors += "Duplicate dependency: '$($dup.Name)' appears $($dup.Count) times"
    }
    return $result
}

function Test-DocumentDependencyRoundtrip {
    <#
    .SYNOPSIS
      Read current DocumentHeader deps -> write them back -> read again -> compare.
      Also checks DocumentHeader vs DocumentInfo consistency if both paths provided.
    .PARAMETER HeaderPath
      Path to DocumentHeader file.
    .PARAMETER InfoPath
      Path to DocumentInfo file (optional). If provided, header vs info consistency is checked.
    .PARAMETER Backup
      If true, backs up original files before write test.
    .OUTPUTS
      PSCustomObject with:
        Valid            - bool
        Errors           - string[]
        Warnings         - string[]
        OriginalDeps     - string[] (read before write)
        RoundtripDeps    - string[] (read after write)
        InfoDeps         - string[] (read from DocumentInfo, if provided)
        HeaderVsInfoDiff - Compare-DocumentDependencySets result (if InfoPath provided)
    #>
    param(
        [Parameter(Mandatory=$true)][string]$HeaderPath,
        [string]$InfoPath = "",
        [switch]$Backup
    )
    $result = [PSCustomObject]@{
        Valid            = $true
        Errors           = @()
        Warnings         = @()
        OriginalDeps     = @()
        RoundtripDeps    = @()
        InfoDeps         = @()
        HeaderVsInfoDiff = $null
    }
    function RT-Error { param([string]$Msg) $result.Valid = $false; $result.Errors += $Msg }
    function RT-Warning { param([string]$Msg) $result.Warnings += $Msg }

    if (-not (Test-Path -LiteralPath $HeaderPath)) {
        RT-Error "DocumentHeader not found: $HeaderPath"
        return $result
    }

    # Backup if requested
    if ($Backup) {
        $bakHeader = "$HeaderPath.roundtrip-bak"
        [System.IO.File]::Copy($HeaderPath, $bakHeader, $true)
        if ($InfoPath -and (Test-Path -LiteralPath $InfoPath)) {
            $bakInfo = "$InfoPath.roundtrip-bak"
            [System.IO.File]::Copy($InfoPath, $bakInfo, $true)
        }
    }

    # Step 1: read original
    try {
        $original = Read-DocumentHeaderDependencies -Path $HeaderPath
        $result.OriginalDeps = $original
    } catch {
        RT-Error "Read-DocumentHeaderDependencies failed: $($_.Exception.Message)"
        return $result
    }

    # Step 2: consistency of the original set
    $consistency = Test-DocumentDependencyConsistency -Dependencies $original
    if (-not $consistency.Valid) {
        foreach ($e in $consistency.Errors) { RT-Error $e }
    }

    # Step 3: write back the same deps
    try {
        Write-DocumentHeaderDependencies -Path $HeaderPath -Dependencies $original
    } catch {
        RT-Error "Write-DocumentHeaderDependencies failed: $($_.Exception.Message)"
        return $result
    }

    # Step 4: read again
    try {
        $roundtrip = Read-DocumentHeaderDependencies -Path $HeaderPath
        $result.RoundtripDeps = $roundtrip
    } catch {
        RT-Error "Read after write failed: $($_.Exception.Message)"
        return $result
    }

    # Step 5: compare original vs roundtrip (order-sensitive for byte stability)
    if ($original.Count -ne $roundtrip.Count) {
        RT-Error "Roundtrip count mismatch: original=$($original.Count), roundtrip=$($roundtrip.Count)"
    } else {
        for ($i = 0; $i -lt $original.Count; $i++) {
            if ($original[$i] -ne $roundtrip[$i]) {
                RT-Error "Roundtrip mismatch at index $i`: '$($original[$i])' != '$($roundtrip[$i])'"
                break
            }
        }
    }

    # Step 6: DocumentInfo consistency
    if ($InfoPath) {
        if (-not (Test-Path -LiteralPath $InfoPath)) {
            RT-Warning "DocumentInfo not found: $InfoPath (skip header-vs-info check)"
        } else {
            try {
                $infoDeps = Read-DocumentInfoDependencies -Path $InfoPath
                $result.InfoDeps = $infoDeps
                $diff = Compare-DocumentDependencySets -A $original -B $infoDeps
                $result.HeaderVsInfoDiff = $diff
                if (-not $diff.Equal) {
                    RT-Error "DocumentHeader vs DocumentInfo dependency sets differ"
                    if ($diff.OnlyInA.Count -gt 0) {
                        RT-Error "  Only in DocumentHeader: $($diff.OnlyInA -join ', ')"
                    }
                    if ($diff.OnlyInB.Count -gt 0) {
                        RT-Error "  Only in DocumentInfo: $($diff.OnlyInB -join ', ')"
                    }
                }
            } catch {
                RT-Error "Read-DocumentInfoDependencies failed: $($_.Exception.Message)"
            }
        }
    }

    return $result
}

# === Orchestration (kept here so map-sync.ps1 can delegate) ===
function Set-MapDependencies {
    <#
    .SYNOPSIS
      Write dependency list to both DocumentInfo and DocumentHeader of a map.
    #>
    param(
        [Parameter(Mandatory=$true)][string]$MapPath,
        [Parameter(Mandatory=$true)][string[]]$Dependencies
    )
    Write-DocumentInfoDependencies -Path (Join-Path $MapPath "DocumentInfo") -Dependencies $Dependencies
    Write-DocumentHeaderDependencies -Path (Join-Path $MapPath "DocumentHeader") -Dependencies $Dependencies
    Write-Host "SET DEPS: $($Dependencies.Count) dependencies written to map"
}
