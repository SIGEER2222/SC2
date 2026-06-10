[CmdletBinding()]
param(
    [string]$StoragePath = "E:\SC2\SC2new\StarCraft II",
    [string]$AssetPath = "Assets\Textures\avenger_coop.dds",
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot "web-launcher\mutator-test-avenger.dds"
}

$toolRoot = "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\tools\casc\CascDump\bin\Debug\net9.0"
$managedDll = Join-Path $toolRoot "CascLib.NET.dll"
$nativeDllDir = Join-Path $toolRoot "runtimes\win-x64\native"

if (-not (Test-Path -LiteralPath $managedDll)) {
    throw "CascLib.NET.dll not found: $managedDll"
}
if (-not (Test-Path -LiteralPath $nativeDllDir)) {
    throw "Casc native dir not found: $nativeDllDir"
}

$env:PATH = "$nativeDllDir;$env:PATH"
Add-Type -Path $managedDll

$storageType = [Type]::GetType("CascLib.NET.CascStorage, CascLib.NET", $true)
$storage = [Activator]::CreateInstance($storageType, @($StoragePath))
try {
    $input = $storage.OpenFile($AssetPath)
    try {
        $outDir = Split-Path -Parent $OutputPath
        if (-not (Test-Path -LiteralPath $outDir)) {
            New-Item -ItemType Directory -Path $outDir | Out-Null
        }
        $output = [System.IO.File]::Create($OutputPath)
        try {
            $input.CopyTo($output)
        }
        finally {
            $output.Dispose()
        }
    }
    finally {
        $input.Dispose()
    }
}
finally {
    $storage.Dispose()
}

Get-Item -LiteralPath $OutputPath | Select-Object FullName, Length, LastWriteTime
