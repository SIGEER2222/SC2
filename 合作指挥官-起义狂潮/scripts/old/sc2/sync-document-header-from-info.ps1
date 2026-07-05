[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DocumentInfoPath,
    [Parameter(Mandatory = $true)]
    [string]$DocumentHeaderPath
)

$ErrorActionPreference = "Stop"

function Read-DocumentInfoXml {
    param([string]$Path)

    $raw = Get-Content -LiteralPath $Path -Raw
    $docInfoEnd = $raw.IndexOf('</DocInfo>')
    if ($docInfoEnd -ge 0) {
        $raw = $raw.Substring(0, $docInfoEnd + '</DocInfo>'.Length)
    }

    [xml]$xml = $raw
    return $xml
}

function Get-ActiveDocumentInfoDependencies {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "DocumentInfo not found: $Path"
    }

    $xml = Read-DocumentInfoXml -Path $Path
    $entries = New-Object System.Collections.Generic.List[string]

    foreach ($node in @($xml.SelectNodes('/DocInfo/Flags/Value'))) {
        $entries.Add([string]$node.InnerText) | Out-Null
    }

    foreach ($node in @($xml.SelectNodes('/DocInfo/Dependencies/Value'))) {
        $entries.Add([string]$node.InnerText) | Out-Null
    }

    return $entries.ToArray()
}

function Get-ActiveDocumentInfoDependenciesOnly {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "DocumentInfo not found: $Path"
    }

    $xml = Read-DocumentInfoXml -Path $Path
    return @($xml.SelectNodes('/DocInfo/Dependencies/Value') | ForEach-Object {
        [string]$_.InnerText
    })
}

function Test-ByteSequenceAt {
    param(
        [byte[]]$Bytes,
        [int]$Offset,
        [byte[]]$Needle
    )

    if ($Offset + $Needle.Length -gt $Bytes.Length) {
        return $false
    }

    for ($i = 0; $i -lt $Needle.Length; $i++) {
        if ($Bytes[$Offset + $i] -ne $Needle[$i]) {
            return $false
        }
    }

    return $true
}

function Find-DocumentHeaderDependencyStart {
    param([byte[]]$Bytes)

    $markers = @(
        [System.Text.Encoding]::UTF8.GetBytes("ExtensionMod"),
        [System.Text.Encoding]::UTF8.GetBytes("file:"),
        [System.Text.Encoding]::UTF8.GetBytes("bnet:")
    )

    for ($offset = 4; $offset -lt $Bytes.Length; $offset++) {
        foreach ($marker in $markers) {
            if (-not (Test-ByteSequenceAt -Bytes $Bytes -Offset $offset -Needle $marker)) {
                continue
            }

            $count = [System.BitConverter]::ToUInt32($Bytes, $offset - 4)
            if (($count -gt 0) -and ($count -lt 128)) {
                return $offset
            }
        }
    }

    throw "DocumentHeader dependency table not found: $DocumentHeaderPath"
}

function Get-DocumentHeaderDependencies {
    param(
        [byte[]]$Bytes,
        [int]$Start,
        [uint32]$Count
    )

    $dependencies = New-Object System.Collections.Generic.List[string]
    $offset = $Start

    for ($index = 0; $index -lt $Count; $index++) {
        $end = $offset
        while (($end -lt $Bytes.Length) -and ($Bytes[$end] -ne 0)) {
            $end++
        }

        if ($end -ge $Bytes.Length) {
            throw "DocumentHeader dependency string is not null-terminated: $DocumentHeaderPath"
        }

        $dependencies.Add([System.Text.Encoding]::UTF8.GetString($Bytes, $offset, $end - $offset)) | Out-Null
        $offset = $end + 1
    }

    return [pscustomobject]@{
        Dependencies = $dependencies.ToArray()
        EndOffset = $offset
    }
}

if (-not (Test-Path -LiteralPath $DocumentHeaderPath)) {
    throw "DocumentHeader not found: $DocumentHeaderPath"
}

$dependencies = Get-ActiveDocumentInfoDependencies -Path $DocumentInfoPath
[byte[]]$bytes = [System.IO.File]::ReadAllBytes($DocumentHeaderPath)
$dependencyStart = Find-DocumentHeaderDependencyStart -Bytes $bytes
$countOffset = $dependencyStart - 4
$currentCount = [System.BitConverter]::ToUInt32($bytes, $countOffset)
$currentInfo = Get-DocumentHeaderDependencies -Bytes $bytes -Start $dependencyStart -Count $currentCount

if (($currentInfo.Dependencies.Count -eq $dependencies.Count) -and
    (($currentInfo.Dependencies -join "`n") -eq ($dependencies -join "`n"))) {
    Write-Output "UNCHANGED $DocumentHeaderPath"
    exit 0
}

$dependencyBytes = [System.Text.Encoding]::UTF8.GetBytes((($dependencies -join "`0") + "`0"))
$countBytes = [System.BitConverter]::GetBytes([uint32]$dependencies.Count)
$stream = New-Object System.IO.MemoryStream

$stream.Write($bytes, 0, $countOffset)
$stream.Write($countBytes, 0, $countBytes.Length)
$stream.Write($dependencyBytes, 0, $dependencyBytes.Length)
$stream.Write($bytes, $currentInfo.EndOffset, $bytes.Length - $currentInfo.EndOffset)

[System.IO.File]::WriteAllBytes($DocumentHeaderPath, $stream.ToArray())
Write-Output "UPDATED $DocumentHeaderPath dependencies=$($dependencies.Count)"
