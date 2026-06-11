[CmdletBinding()]
param()

function Get-CatalogXmlPaths {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GameDataRoot,
        [Parameter(Mandatory = $true)]
        [string]$BaseName
    )

    $pattern = "$BaseName*.xml"
    $paths = @(Get-ChildItem -LiteralPath $GameDataRoot -File -Filter $pattern | Sort-Object Name | ForEach-Object { $_.FullName })
    if ($paths.Count -eq 0) {
        throw "No catalog XML files found for '$BaseName' under: $GameDataRoot"
    }

    return @($paths)
}

function Read-CatalogXml {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Catalog XML not found: $Path"
    }

    [xml]$xml = Get-Content -LiteralPath $Path -Encoding UTF8 -Raw
    return $xml
}

function Read-CatalogXmlSet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GameDataRoot,
        [Parameter(Mandatory = $true)]
        [string]$BaseName
    )

    $xmls = New-Object System.Collections.Generic.List[xml]
    foreach ($path in (Get-CatalogXmlPaths -GameDataRoot $GameDataRoot -BaseName $BaseName)) {
        $xmls.Add((Read-CatalogXml -Path $path)) | Out-Null
    }

    return @($xmls)
}

function Get-CatalogNodesById {
    param(
        [Parameter(Mandatory = $true)]
        [xml[]]$Xmls,
        [Parameter(Mandatory = $true)]
        [string]$TagName,
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    $escapedId = $Id.Replace("'", "&apos;")
    $nodes = @()
    foreach ($xml in $Xmls) {
        $nodes += @($xml.SelectNodes("/Catalog/$TagName[@id='$escapedId']"))
    }

    return @($nodes)
}

function Get-CatalogNodeById {
    param(
        [Parameter(Mandatory = $true)]
        [xml[]]$Xmls,
        [Parameter(Mandatory = $true)]
        [string]$TagName,
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    $nodes = @(Get-CatalogNodesById -Xmls $Xmls -TagName $TagName -Id $Id)
    if ($nodes.Count -eq 0) {
        throw "$TagName '$Id' not found."
    }

    return $nodes[$nodes.Count - 1]
}

