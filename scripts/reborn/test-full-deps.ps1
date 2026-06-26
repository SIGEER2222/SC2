# 测试完整依赖的 XMFinal
$ErrorActionPreference = "Stop"

# 源 XMFinal（完整依赖）
$sourceFinal = "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\合作指挥官版起义狂潮\Mods\XM\XMFinal.SC2Mod"
$liveFinal = "E:\SC2\SC2new\StarCraft II\Mods\XM\XMFinal.SC2Mod"

# 复制源文件（只复制 DocumentInfo 和 DocumentHeader）
Copy-Item (Join-Path $sourceFinal "DocumentInfo") (Join-Path $liveFinal "DocumentInfo") -Force
Copy-Item (Join-Path $sourceFinal "DocumentHeader") (Join-Path $liveFinal "DocumentHeader") -Force

Write-Host "Copied DocumentInfo and DocumentHeader from source"

# 验证
[xml]$xml = Get-Content (Join-Path $liveFinal "DocumentInfo")
$infoDeps = $xml.DocInfo.Dependencies.Value
Write-Host "DocumentInfo dependencies: $($infoDeps.Count)"

$bytes = [System.IO.File]::ReadAllBytes((Join-Path $liveFinal "DocumentHeader"))
$headerCount = [BitConverter]::ToInt32($bytes, 0x2C)
Write-Host "DocumentHeader dependencies: $headerCount"

Write-Host "`nDone - XMFinal restored to source dependencies"
