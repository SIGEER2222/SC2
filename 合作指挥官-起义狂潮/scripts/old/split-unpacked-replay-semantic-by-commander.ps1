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

function Save-XmlDocument {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument]$Document,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try {
        $Document.Save($writer)
    }
    finally {
        $writer.Close()
    }
}

function New-XmlDocumentWithRoot {
    param([Parameter(Mandatory = $true)][System.Xml.XmlDocument]$SourceXml)

    $doc = New-Object System.Xml.XmlDocument
    $decl = $doc.CreateXmlDeclaration('1.0', 'utf-8', $null)
    [void]$doc.AppendChild($decl)
    $root = $doc.ImportNode($SourceXml.DocumentElement, $false)
    [void]$doc.AppendChild($root)
    return $doc
}

function Get-CommanderTokens {
    param([Parameter(Mandatory = $true)][object]$Commander)

    @(
        [string]$Commander.runtime_commander
        [string]$Commander.bank_commander
        [string]$Commander.generated_commander
        [string]$Commander.official_folder
        [string]$Commander.official_short_id
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
}

function Get-CommanderHitsFromText {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][object[]]$Commanders
    )

    $hits = New-Object System.Collections.Generic.List[string]
    foreach ($commander in $Commanders) {
        foreach ($token in (Get-CommanderTokens -Commander $commander)) {
            if ($Text.IndexOf($token, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $hits.Add([string]$commander.generated_commander) | Out-Null
                break
            }
        }
    }

    return @($hits | Sort-Object -Unique)
}

function Copy-FileToBucket {
    param(
        [Parameter(Mandatory = $true)][string]$SourceFile,
        [Parameter(Mandatory = $true)][string]$BucketRoot,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    $dest = Join-Path $BucketRoot $RelativePath
    Ensure-Directory -Path (Split-Path -Parent $dest)
    Copy-Item -LiteralPath $SourceFile -Destination $dest -Force
}

function Write-TextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )

    Ensure-Directory -Path (Split-Path -Parent $Path)
    Set-Content -LiteralPath $Path -Value $Text -Encoding UTF8
}

$sourceRoot = Resolve-AbsolutePath $SourceRoot
if (-not (Test-Path -LiteralPath $sourceRoot)) {
    throw "SourceRoot not found: $sourceRoot"
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $outputRoot = Join-Path $sourceRoot '_semantic-by-commander'
}
else {
    $outputRoot = Resolve-AbsolutePath $OutputRoot
}

Ensure-Directory -Path $outputRoot

$metadata = Get-CommanderPowerMetadata -WorkspaceRoot (Split-Path -Parent $PSScriptRoot)
$commanders = @($metadata.commanders)

$commanderRoots = @{}
foreach ($commander in $commanders) {
    $bucket = [string]$commander.generated_commander
    if ([string]::IsNullOrWhiteSpace($bucket)) {
        $bucket = [string]$commander.bank_commander
    }
    if ([string]::IsNullOrWhiteSpace($bucket)) {
        continue
    }

    $bucketRoot = Join-Path $outputRoot $bucket
    Ensure-Directory -Path $bucketRoot
    $commanderRoots[$bucket] = $bucketRoot
}

$sharedRoot = Join-Path $outputRoot '_shared'
Ensure-Directory -Path $sharedRoot

$scanRoots = New-Object System.Collections.Generic.List[string]
$packageRoot = Join-Path $sourceRoot 's2ma_packages'
if (Test-Path -LiteralPath $packageRoot) {
    foreach ($pkg in @(Get-ChildItem -LiteralPath $packageRoot -Directory)) {
        $extractRoot = Join-Path $pkg.FullName 'extract'
        if (Test-Path -LiteralPath $extractRoot) {
            $scanRoots.Add($extractRoot) | Out-Null
        }
    }
}
if ($scanRoots.Count -eq 0) {
    $scanRoots.Add($sourceRoot) | Out-Null
}

$manifest = New-Object System.Collections.Generic.List[object]

foreach ($scanRoot in $scanRoots) {
    $files = @(Get-ChildItem -LiteralPath $scanRoot -Recurse -File | Where-Object { $_.FullName -notlike (Join-Path $outputRoot '*') })
    foreach ($file in $files) {
        $relativePath = [System.IO.Path]::GetRelativePath($sourceRoot, $file.FullName)
        $extension = [System.IO.Path]::GetExtension($file.Name).ToLowerInvariant()
        $isXml = ($extension -eq '.xml')
        $copiedBuckets = New-Object System.Collections.Generic.List[string]

        if ($isXml) {
            try {
                [xml]$xml = Get-Content -LiteralPath $file.FullName -Encoding UTF8 -Raw
                if (($null -eq $xml.DocumentElement) -or (-not $xml.DocumentElement.HasChildNodes)) {
                    Copy-FileToBucket -SourceFile $file.FullName -BucketRoot $sharedRoot -RelativePath $relativePath
                    $copiedBuckets.Add('_shared') | Out-Null
                }
                else {
                    $sharedDoc = New-XmlDocumentWithRoot -SourceXml $xml
                    $bucketDocs = @{}
                    $childElements = @($xml.DocumentElement.ChildNodes | Where-Object { $_.NodeType -eq 'Element' })

                    foreach ($child in $childElements) {
                        $hits = Get-CommanderHitsFromText -Text $child.OuterXml -Commanders $commanders
                        if ($hits.Count -eq 0) {
                            $imported = $sharedDoc.ImportNode($child, $true)
                            [void]$sharedDoc.DocumentElement.AppendChild($imported)
                            continue
                        }

                        foreach ($hit in $hits) {
                            if (-not $bucketDocs.ContainsKey($hit)) {
                                $bucketDocs[$hit] = New-XmlDocumentWithRoot -SourceXml $xml
                            }
                            $imported = $bucketDocs[$hit].ImportNode($child, $true)
                            [void]$bucketDocs[$hit].DocumentElement.AppendChild($imported)
                        }
                    }

                    if ($sharedDoc.DocumentElement.HasChildNodes) {
                        $sharedPath = Join-Path $sharedRoot $relativePath
                        Save-XmlDocument -Document $sharedDoc -Path $sharedPath
                        $copiedBuckets.Add('_shared') | Out-Null
                    }

                    foreach ($bucket in ($bucketDocs.Keys | Sort-Object)) {
                        $doc = $bucketDocs[$bucket]
                        if (-not $doc.DocumentElement.HasChildNodes) {
                            continue
                        }

                        $bucketRoot = $commanderRoots[$bucket]
                        if ($null -eq $bucketRoot) {
                            continue
                        }

                        $bucketPath = Join-Path $bucketRoot $relativePath
                        Save-XmlDocument -Document $doc -Path $bucketPath
                        $copiedBuckets.Add($bucket) | Out-Null
                    }
                }
            }
            catch {
                Copy-FileToBucket -SourceFile $file.FullName -BucketRoot $sharedRoot -RelativePath $relativePath
                $copiedBuckets.Clear()
                $copiedBuckets.Add('_shared') | Out-Null
            }
        }
        else {
            try {
                $text = Get-Content -LiteralPath $file.FullName -Encoding UTF8 -Raw
                $hits = Get-CommanderHitsFromText -Text $text -Commanders $commanders
                if ($hits.Count -eq 0) {
                    Copy-FileToBucket -SourceFile $file.FullName -BucketRoot $sharedRoot -RelativePath $relativePath
                    $copiedBuckets.Add('_shared') | Out-Null
                }
                else {
                    foreach ($hit in $hits) {
                        $bucketRoot = $commanderRoots[$hit]
                        if ($null -eq $bucketRoot) {
                            continue
                        }

                        Copy-FileToBucket -SourceFile $file.FullName -BucketRoot $bucketRoot -RelativePath $relativePath
                        $copiedBuckets.Add($hit) | Out-Null
                    }
                }
            }
            catch {
                Copy-FileToBucket -SourceFile $file.FullName -BucketRoot $sharedRoot -RelativePath $relativePath
                $copiedBuckets.Clear()
                $copiedBuckets.Add('_shared') | Out-Null
            }
        }

        $manifest.Add([pscustomobject]@{
                RelativePath = $relativePath
                Buckets      = ($copiedBuckets | Sort-Object -Unique) -join ','
            }) | Out-Null
    }
}

$manifestPath = Join-Path $outputRoot 'split-manifest.csv'
$manifest | Sort-Object RelativePath | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8

$summaryPath = Join-Path $outputRoot 'README.md'
$summary = New-Object System.Collections.Generic.List[string]
$summary.Add('# Semantic split by commander') | Out-Null
$summary.Add('') | Out-Null
$summary.Add('Source: ' + $sourceRoot) | Out-Null
$summary.Add('Shared bucket: ' + $sharedRoot) | Out-Null
$summary.Add('Manifest: ' + $manifestPath) | Out-Null
$summary.Add('') | Out-Null
$summary.Add('## Buckets') | Out-Null
foreach ($commander in ($commanders | Sort-Object display_name)) {
    $bucket = [string]$commander.generated_commander
    if ([string]::IsNullOrWhiteSpace($bucket)) {
        $bucket = [string]$commander.bank_commander
    }
    if ([string]::IsNullOrWhiteSpace($bucket)) {
        continue
    }

    $summary.Add('- ' + [string]$commander.display_name + ' => ' + $bucket) | Out-Null
}

$summary.Add('') | Out-Null
$summary.Add('## Notes') | Out-Null
$summary.Add('- XML files are split by node content, with matching nodes duplicated into commander buckets and unmatched nodes kept in _shared.') | Out-Null
$summary.Add('- Non-XML text files are copied by content hit; binary or unreadable files fall back to _shared.') | Out-Null
$summary | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host 'Semantic split source: ' + $sourceRoot
Write-Host 'Output root: ' + $outputRoot
Write-Host 'Shared bucket: ' + $sharedRoot
Write-Host 'Manifest: ' + $manifestPath
Write-Host 'README: ' + $summaryPath
