[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [int]$MaxLines = 1800
)

$ErrorActionPreference = 'Stop'

function New-CatalogDocument {
    $xml = New-Object System.Xml.XmlDocument
    $decl = $xml.CreateXmlDeclaration('1.0', 'utf-8', $null)
    [void]$xml.AppendChild($decl)
    [void]$xml.AppendChild($xml.CreateElement('Catalog'))
    return $xml
}

function Save-CatalogDocument {
    param([System.Xml.XmlDocument]$Document, [string]$Path)
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try { $Document.Save($writer) }
    finally { $writer.Close() }
}

function Measure-CatalogDocumentLines {
    param([System.Xml.XmlDocument]$Document)
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $sw = New-Object System.IO.StringWriter
    $writer = [System.Xml.XmlWriter]::Create($sw, $settings)
    try { $Document.Save($writer) }
    finally { $writer.Close() }
    return (@($sw.ToString() -split "`r?`n")).Count
}

function New-ItemCatalogDocument {
    param([System.Xml.XmlElement]$Item)
    $doc = New-CatalogDocument
    $imported = $doc.ImportNode($Item, $true)
    [void]$doc.DocumentElement.AppendChild($imported)
    return $doc
}

$gameDataRoot = Join-Path $WorkspaceRoot 'Mods\kit_mutations.SC2Mod\Base.SC2Data\GameData'
$sourcePath = Join-Path $gameDataRoot 'Mutators.xml'
$gameDataXmlPath = Join-Path (Split-Path -Parent $gameDataRoot) 'GameData.xml'

[xml]$sourceXml = Get-Content -LiteralPath $sourcePath -Encoding UTF8 -Raw
[xml]$gameDataXml = Get-Content -LiteralPath $gameDataXmlPath -Encoding UTF8 -Raw

$topNodes = @($sourceXml.Catalog.ChildNodes | Where-Object { $_.NodeType -eq 'Element' })
$output = New-Object System.Collections.Generic.List[object]
$current = New-CatalogDocument

function Flush-Current {
    param([System.Xml.XmlDocument]$Document)
    if ($Document.DocumentElement.HasChildNodes) {
        $output.Add($Document) | Out-Null
    }
}

foreach ($node in $topNodes) {
    if ($node.Name -eq 'CUser') {
        $instances = @($node.SelectNodes('Instances'))
        $template = New-CatalogDocument
        $templateNode = $template.ImportNode($node, $true)
        [void]$template.DocumentElement.AppendChild($templateNode)

        if ((Measure-CatalogDocumentLines -Document $template) -le $MaxLines) {
            if ((Measure-CatalogDocumentLines -Document $current) -gt 0) {
                Flush-Current -Document $current
                $current = New-CatalogDocument
            }
            [void]$current.DocumentElement.AppendChild($current.ImportNode($node, $true))
            continue
        }

        $base = New-CatalogDocument
        $baseNode = $base.ImportNode($node, $true)
        while ($baseNode.Instances.Count -gt 1) {
            [void]$baseNode.RemoveChild($baseNode.Instances[$baseNode.Instances.Count - 1])
            if ((Measure-CatalogDocumentLines -Document $base) -le $MaxLines) {
                break
            }
        }

        if ((Measure-CatalogDocumentLines -Document $current) -gt 0) {
            Flush-Current -Document $current
            $current = New-CatalogDocument
        }
        [void]$current.DocumentElement.AppendChild($current.ImportNode($baseNode, $true))
        Flush-Current -Document $current
        $current = New-CatalogDocument

        for ($i = 0; $i -lt $instances.Count; $i++) {
            $chunkDoc = New-CatalogDocument
            $chunkNode = $chunkDoc.ImportNode($node, $true)
            while ($chunkNode.Instances.Count -gt 0) {
                [void]$chunkNode.RemoveChild($chunkNode.Instances[0])
            }
            [void]$chunkNode.AppendChild($instances[$i].CloneNode($true))
            [void]$chunkDoc.DocumentElement.AppendChild($chunkNode)
            if ((Measure-CatalogDocumentLines -Document $chunkDoc) -gt $MaxLines) {
                throw "Cannot fit CUser '$($node.id)' instance '$($instances[$i].Id)' within $MaxLines lines."
            }
            $output.Add($chunkDoc) | Out-Null
        }
        continue
    }

    $testDoc = New-CatalogDocument
    [void]$testDoc.DocumentElement.AppendChild($testDoc.ImportNode($node, $true))
    if ((Measure-CatalogDocumentLines -Document $testDoc) -gt $MaxLines) {
        throw "Top-level node '$($node.Name)' exceeds $MaxLines lines and is not a CUser block."
    }

    [void]$current.DocumentElement.AppendChild($current.ImportNode($node, $true))
    if ((Measure-CatalogDocumentLines -Document $current) -gt $MaxLines) {
        [void]$current.DocumentElement.RemoveChild($current.DocumentElement.LastChild)
        Flush-Current -Document $current
        $current = New-CatalogDocument
        [void]$current.DocumentElement.AppendChild($current.ImportNode($node, $true))
    }
}

Flush-Current -Document $current

Remove-Item -LiteralPath (Join-Path $gameDataRoot 'Mutators_*.xml') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $sourcePath -Force

$chunkNames = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $output.Count; $i++) {
    $name = ('Mutators_{0:D2}.xml' -f ($i + 1))
    $path = Join-Path $gameDataRoot $name
    Save-CatalogDocument -Document $output[$i] -Path $path
    $chunkNames.Add($name) | Out-Null
    Write-Host ("{0}: {1} lines" -f $name, (Get-Content -LiteralPath $path | Measure-Object -Line).Lines)
}

while ($gameDataXml.Includes.Catalog) {
    [void]$gameDataXml.Includes.RemoveChild($gameDataXml.Includes.Catalog[0])
}
foreach ($name in $chunkNames) {
    $catalog = $gameDataXml.CreateElement('Catalog')
    [void]$catalog.SetAttribute('path', ('GameData/{0}' -f $name))
    [void]$gameDataXml.Includes.AppendChild($catalog)
}

$settings = New-Object System.Xml.XmlWriterSettings
$settings.Indent = $true
$settings.Encoding = New-Object System.Text.UTF8Encoding($false)
$writer = [System.Xml.XmlWriter]::Create($gameDataXmlPath, $settings)
try { $gameDataXml.Save($writer) }
finally { $writer.Close() }

Write-Host ("Mutators split complete: {0} chunks" -f $chunkNames.Count)
