$path = 'e:\Code\MyMod\SC2\合作指挥官-起义狂潮\Maps\abathur_test_map\DocumentHeader'
$bytes = [System.IO.File]::ReadAllBytes($path)
$text = [System.Text.Encoding]::UTF8.GetString($bytes)
$matches = [regex]::Matches($text, '(file:[^\x00]+|bnet:[^\x00]+)')
foreach ($m in $matches) { Write-Host $m.Value }
