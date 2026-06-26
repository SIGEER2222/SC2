# 重新创建 Mods\XM 目录并复制所有模组
$ErrorActionPreference = "Stop"

$rebornMods = "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\合作指挥官版起义狂潮\Mods\XM"
$sc2ModsXm = "E:\SC2\SC2new\StarCraft II\Mods\XM"

# 创建目录
if (-not (Test-Path $sc2ModsXm)) {
    [System.IO.Directory]::CreateDirectory($sc2ModsXm) | Out-Null
    Write-Host "Created directory: $sc2ModsXm"
}

# 复制所有模组
$mods = Get-ChildItem $rebornMods -Directory
Write-Host "`nFound $($mods.Count) mods in source"

$copied = 0
foreach ($mod in $mods) {
    $dest = Join-Path $sc2ModsXm $mod.Name
    
    if (Test-Path $dest) {
        Write-Host "  Skip (exists): $($mod.Name)"
        continue
    }
    
    # 用 .NET 方法递归复制目录
    function Copy-DirectoryNet {
        param($Source, $Destination)
        
        if (-not [System.IO.Directory]::Exists($Destination)) {
            [System.IO.Directory]::CreateDirectory($Destination) | Out-Null
        }
        
        foreach ($file in [System.IO.Directory]::GetFiles($Source)) {
            $fileName = [System.IO.Path]::GetFileName($file)
            $destFile = Join-Path $Destination $fileName
            [System.IO.File]::Copy($file, $destFile, $true)
        }
        
        foreach ($dir in [System.IO.Directory]::GetDirectories($Source)) {
            $dirName = [System.IO.Path]::GetFileName($dir)
            $destDir = Join-Path $Destination $dirName
            Copy-DirectoryNet -Source $dir -Destination $destDir
        }
    }
    
    Copy-DirectoryNet -Source $mod.FullName -Destination $dest
    Write-Host "  Copied: $($mod.Name)"
    $copied++
}

Write-Host "`nDone! Copied $copied mods"

# 验证 XMFinal
$finalInfo = Join-Path $sc2ModsXm "XMFinal.SC2Mod\DocumentInfo"
if (Test-Path $finalInfo) {
    [xml]$xml = Get-Content $finalInfo
    $deps = $xml.DocInfo.Dependencies.Value
    Write-Host "`nXMFinal DocumentInfo dependencies: $($deps.Count)"
    
    $finalHeader = Join-Path $sc2ModsXm "XMFinal.SC2Mod\DocumentHeader"
    $headerBytes = [System.IO.File]::ReadAllBytes($finalHeader)
    $headerCount = [BitConverter]::ToInt32($headerBytes, 0x2C)
    Write-Host "XMFinal DocumentHeader dependencies: $headerCount"
}
