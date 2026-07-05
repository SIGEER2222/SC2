[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,
    [string]$OutputRoot = ""
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'commander-power-metadata.ps1')

function Resolve-AbsolutePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Copy-RelativeFile {
    param(
        [Parameter(Mandatory = $true)][string]$SourceFile,
        [Parameter(Mandatory = $true)][string]$DestinationRoot,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    $destinationPath = Join-Path $DestinationRoot $RelativePath
    $destinationDir = Split-Path -Parent $destinationPath
    Ensure-Directory -Path $destinationDir
    Copy-Item -LiteralPath $SourceFile -Destination $destinationPath -Force
}

function Test-CommanderFileHit {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][object]$Commander
    )

    $tokens = @(
        [string]$Commander.runtime_commander,
        [string]$Commander.bank_commander,
        [string]$Commander.generated_commander,
        [string]$Commander.official_folder,
        [string]$Commander.official_short_id,
        [string]$Commander.display_name
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    foreach ($token in $tokens) {
        if ($RelativePath -match [regex]::Escape($token)) {
            return $true
        }
    }

    return $false
}

$sourceRoot = Resolve-AbsolutePath $SourceRoot
if (-not (Test-Path -LiteralPath $sourceRoot)) {
    throw "SourceRoot not found: $sourceRoot"
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $outputRoot = Join-Path $sourceRoot '_by-commander'
}
else {
    $outputRoot = Resolve-AbsolutePath $OutputRoot
}

Ensure-Directory -Path $outputRoot

$metadata = Get-CommanderPowerMetadata -WorkspaceRoot (Split-Path -Parent $PSScriptRoot)
$commanders = @($metadata.commanders)

$allFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File | Where-Object {
        $_.FullName -notlike (Join-Path $outputRoot '*')
    })

$sharedRoot = Join-Path $outputRoot '_shared'
Ensure-Directory -Path $sharedRoot

$commanderRoots = @{}
foreach ($commander in $commanders) {
    $folderName = [string]$commander.generated_commander
    if ([string]::IsNullOrWhiteSpace($folderName)) {
        $folderName = [string]$commander.bank_commander
    }
    if ([string]::IsNullOrWhiteSpace($folderName)) {
        continue
    }

    $commanderRoot = Join-Path $outputRoot $folderName
    Ensure-Directory -Path $commanderRoot
    $commanderRoots[$folderName] = $commanderRoot
}

$manifestRows = New-Object System.Collections.Generic.List[object]

foreach ($file in $allFiles) {
    $relativePath = [System.IO.Path]::GetRelativePath($sourceRoot, $file.FullName)
    $hits = @()
    foreach ($commander in $commanders) {
        if (Test-CommanderFileHit -RelativePath $relativePath -Commander $commander) {
            $hits += [string]$commander.generated_commander
        }
    }

    if ($hits.Count -eq 0) {
        Copy-RelativeFile -SourceFile $file.FullName -DestinationRoot $sharedRoot -RelativePath $relativePath
        $manifestRows.Add([pscustomobject]@{
                RelativePath = $relativePath
                Bucket       = '_shared'
                Commanders   = ''
            }) | Out-Null
        continue
    }

    foreach ($bucket in ($hits | Sort-Object -Unique)) {
        $destinationRoot = $commanderRoots[$bucket]
        if ($null -eq $destinationRoot) {
            continue
        }

        Copy-RelativeFile -SourceFile $file.FullName -DestinationRoot $destinationRoot -RelativePath $relativePath
    }

    $manifestRows.Add([pscustomobject]@{
            RelativePath = $relativePath
            Bucket       = ($hits | Sort-Object -Unique) -join ','
            Commanders   = ($hits | Sort-Object -Unique) -join ','
        }) | Out-Null
}

$manifestPath = Join-Path $outputRoot 'split-manifest.csv'
$manifestRows | Sort-Object RelativePath | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8

$summaryPath = Join-Path $outputRoot 'README.md'
$summary = New-Object System.Collections.Generic.List[string]
$summary.Add('# Unpacked replay split by commander') | Out-Null
$summary.Add('') | Out-Null
$summary.Add('Source: ' + $sourceRoot) | Out-Null
$summary.Add('Shared bucket: ' + $sharedRoot) | Out-Null
$summary.Add('Manifest: ' + $manifestPath) | Out-Null
$summary.Add('') | Out-Null
$summary.Add('## Buckets') | Out-Null
foreach ($commander in ($commanders | Sort-Object display_name)) {
    $folderName = [string]$commander.generated_commander
    if ([string]::IsNullOrWhiteSpace($folderName)) {
        $folderName = [string]$commander.bank_commander
    }

    if ([string]::IsNullOrWhiteSpace($folderName)) {
        continue
    }

    $summary.Add('- ' + [string]$commander.display_name + ' => ' + $folderName) | Out-Null
}

$summary.Add('') | Out-Null
$summary.Add('## Notes') | Out-Null
$summary.Add('- Files whose names or paths include a commander token are copied into that commander bucket.') | Out-Null
$summary.Add('- Files that do not match any commander token stay in `_shared`.') | Out-Null
$summary.Add('- This is a physical split for inspection and browsing, not a semantic XML rewrite.') | Out-Null
$summary | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host ('Split source: ' + $sourceRoot)
Write-Host ('Output root: ' + $outputRoot)
Write-Host ('Shared bucket: ' + $sharedRoot)
Write-Host ('Manifest: ' + $manifestPath)
Write-Host ('README: ' + $summaryPath)
