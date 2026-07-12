<#
.SYNOPSIS
  Copy CMRE development package assets to the project.
.DESCRIPTION
  Copies maps and mods from the CMRE development package to the project structure.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$CmrePackagePath
)

$ErrorActionPreference = "Stop"

$ScriptsRoot = Split-Path $PSScriptRoot -Parent
$ProjRoot = Split-Path $ScriptsRoot -Parent

Write-Host "=== Copying CMRE Assets ==="
Write-Host "CMRE Package Path: $CmrePackagePath"
Write-Host "Project Root: $ProjRoot"

# Validate source path
if (-not (Test-Path $CmrePackagePath)) {
    Write-Host "ERROR: CMRE package path does not exist: $CmrePackagePath"
    exit 1
}

# Copy maps
$mapsSrc = Join-Path $CmrePackagePath "Maps"
$mapsDest = Join-Path $ProjRoot "Maps\CMRE"
if (Test-Path $mapsSrc) {
    Write-Host "Copying maps from $mapsSrc to $mapsDest"
    if (-not (Test-Path $mapsDest)) {
        New-Item -ItemType Directory -Path $mapsDest -Force | Out-Null
    }
    robocopy $mapsSrc $mapsDest /E /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
}

# Copy mods
$modsSrc = Join-Path $CmrePackagePath "Mods"
$modsDest = Join-Path $ProjRoot "Mods\CMRE"
if (Test-Path $modsSrc) {
    Write-Host "Copying mods from $modsSrc to $modsDest"
    if (-not (Test-Path $modsDest)) {
        New-Item -ItemType Directory -Path $modsDest -Force | Out-Null
    }
    robocopy $modsSrc $modsDest /E /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
}

Write-Host "CMRE assets copied successfully!"
