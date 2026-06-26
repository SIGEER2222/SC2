# 复制地图到游戏目录并启动测试
$ErrorActionPreference = "Stop"

# 源地图
$sourceMap = "C:\Users\22448\Downloads\合作指挥官版起义狂潮0.81\Maps\XM\ttosh03b.SC2Map"

# 目标目录
$destDir = "E:\SC2\SC2new\StarCraft II\Maps\XM"
$destMap = Join-Path $destDir "ttosh03b.SC2Map"

# 创建目标目录
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    Write-Host "Created directory: $destDir"
}

# 用 .NET 方法复制目录
function Copy-DirectoryNet {
    param($Source, $Destination)
    
    if (-not [System.IO.Directory]::Exists($Source)) {
        throw "Source not found: $Source"
    }
    
    if (-not [System.IO.Directory]::Exists($Destination)) {
        [System.IO.Directory]::CreateDirectory($Destination) | Out-Null
    }
    
    foreach ($file in [System.IO.Directory]::GetFiles($Source)) {
        $name = [System.IO.Path]::GetFileName($file)
        [System.IO.File]::Copy($file, (Join-Path $Destination $name), $true)
    }
    
    foreach ($dir in [System.IO.Directory]::GetDirectories($Source)) {
        $name = [System.IO.Path]::GetFileName($dir)
        Copy-DirectoryNet -Source $dir -Destination (Join-Path $Destination $name)
    }
}

Write-Host "Copying map to game directory..."
Copy-DirectoryNet -Source $sourceMap -Destination $destMap
Write-Host "  Done: $destMap"

# 验证
$docInfo = Join-Path $destMap "DocumentInfo"
if (Test-Path $docInfo) {
    [xml]$xml = Get-Content $docInfo
    $deps = $xml.DocInfo.Dependencies.Value
    Write-Host "`nMap dependencies:"
    $deps | ForEach-Object { Write-Host "  $_" }
}

Write-Host "`nMap path for launch: $destMap"
