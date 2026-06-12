[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [int]$MaxLinesPerChunk = 1800
)

$ErrorActionPreference = 'Stop'

$baseDir = Join-Path $WorkspaceRoot 'Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data'
$sourcePath = Join-Path $baseDir 'LibKMIS.galaxy'
if (-not (Test-Path -LiteralPath $sourcePath)) { throw "Source not found: $sourcePath" }

$lines = Get-Content -LiteralPath $sourcePath -Encoding UTF8
$splitMarkers = New-Object System.Collections.Generic.List[int]
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^void libKMIS_gf_' -or $lines[$i] -match '^bool libKMIS_gf_' -or $lines[$i] -match '^int libKMIS_gf_' -or $lines[$i] -match '^fixed libKMIS_gf_' -or $lines[$i] -match '^string libKMIS_gf_' -or $lines[$i] -match '^unit libKMIS_gf_' -or $lines[$i] -match '^point libKMIS_gf_' -or $lines[$i] -match '^playergroup libKMIS_gf_' -or $lines[$i] -match '^trigger libKMIS_gf_' -or $lines[$i] -match '^text libKMIS_gf_') {
        $splitMarkers.Add($i) | Out-Null
    }
}

if ($splitMarkers.Count -eq 0) {
    throw "No function markers found in $sourcePath"
}

function Write-Chunk {
    param([string[]]$Content, [string]$Path)
    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
}

$chunkNames = New-Object System.Collections.Generic.List[string]
$current = New-Object System.Collections.Generic.List[string]
$currentLines = 0
$chunkIndex = 1

function Flush-Chunk {
    param([System.Collections.Generic.List[string]]$Buffer, [int]$Index)
    if ($Buffer.Count -eq 0) { return }
    $name = ('LibKMIS_{0:D2}.galaxy' -f $Index)
    $path = Join-Path $baseDir $name
    Write-Chunk -Content $Buffer.ToArray() -Path $path
    $count = (Get-Content -LiteralPath $path | Measure-Object -Line).Lines
    Write-Host ("{0}: {1} lines" -f $name, $count)
    $script:chunkNames.Add($name) | Out-Null
}

$preambleEnd = $splitMarkers[0] - 1
if ($preambleEnd -ge 0) {
    $current.AddRange($lines[0..$preambleEnd])
}
$currentLines = 0

for ($m = 0; $m -lt $splitMarkers.Count; $m++) {
    $start = $splitMarkers[$m]
    $end = if ($m -lt $splitMarkers.Count - 1) { $splitMarkers[$m + 1] - 1 } else { $lines.Count - 1 }
    $block = $lines[$start..$end]
    if (($currentLines -gt 0) -and (($currentLines + $block.Count) -gt $MaxLinesPerChunk)) {
        Flush-Chunk -Buffer $current -Index $chunkIndex
        $chunkIndex++
        $current = New-Object System.Collections.Generic.List[string]
        $currentLines = 0
    }
    $current.AddRange($block)
    $currentLines += $block.Count
}

Flush-Chunk -Buffer $current -Index $chunkIndex

if ($chunkNames.Count -eq 0) {
    throw "No chunks were generated for $sourcePath"
}

$includeLines = @(
    'include "TriggerLibs/NativeLib"'
    'include "TriggerLibs/LibertyLib"'
    'include "TriggerLibs/VoidLib"'
    'include "LibKPVP_h"'
    'include "LibKCOR_h"'
    'include "LibKCUI_h"'
    'include "LibDF8E6945_h"'
    'include "LibE0EAE146_h"'
    'include "LibKMIS_h"'
) + ($chunkNames | ForEach-Object { 'include "{0}"' -f $_.Substring(0, $_.Length - 7) })
Write-Chunk -Content $includeLines -Path $sourcePath

Write-Host "LibKMIS split complete"
