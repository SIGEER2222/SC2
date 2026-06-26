# 使用 .NET 方法复制文件，绕过 Copy-Item 的包装器

$sourceDocInfo = "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\合作指挥官版起义狂潮\Mods\XM\XMFinal.SC2Mod\DocumentInfo"
$sourceDocHeader = "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\合作指挥官版起义狂潮\Mods\XM\XMFinal.SC2Mod\DocumentHeader"

$liveDocInfo = "E:\SC2\SC2new\StarCraft II\Mods\XM\XMFinal.SC2Mod\DocumentInfo"
$liveDocHeader = "E:\SC2\SC2new\StarCraft II\Mods\XM\XMFinal.SC2Mod\DocumentHeader"

# 读取源文件
$docInfoContent = [System.IO.File]::ReadAllText($sourceDocInfo, [System.Text.Encoding]::UTF8)
$docHeaderBytes = [System.IO.File]::ReadAllBytes($sourceDocHeader)

Write-Host "Read source files"
Write-Host "  DocumentInfo length: $($docInfoContent.Length)"
Write-Host "  DocumentHeader length: $($docHeaderBytes.Length)"

# 写入目标文件
[System.IO.File]::WriteAllText($liveDocInfo, $docInfoContent, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllBytes($liveDocHeader, $docHeaderBytes)

Write-Host "`nWrote to live files"

# 验证
[xml]$xml = Get-Content $liveDocInfo
$infoDeps = $xml.DocInfo.Dependencies.Value
Write-Host "`nDocumentInfo dependencies: $($infoDeps.Count)"

$headerBytes = [System.IO.File]::ReadAllBytes($liveDocHeader)
$headerCount = [BitConverter]::ToInt32($headerBytes, 0x2C)
Write-Host "DocumentHeader dependencies: $headerCount"

Write-Host "`nDone!"
