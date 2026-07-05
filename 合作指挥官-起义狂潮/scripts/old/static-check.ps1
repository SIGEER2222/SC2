$ErrorActionPreference = "Continue"
chcp 65001 | Out-Null

$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modRoot = Split-Path -Parent $baseDir
$xmDir = Join-Path $modRoot "XM\XMAbathurReborn.SC2Mod\Base.SC2Data\GameData"

Write-Host "===== XML Validation ====="
$xmlFiles = @(
    "AbilData_Reborn.xml",
    "UnitData_Reborn.xml",
    "ActorData_Reborn.xml",
    "ButtonData_Reborn.xml",
    "WeaponData_Reborn.xml",
    "GameData.xml"
)

foreach ($f in $xmlFiles) {
    $fullPath = Join-Path $xmDir $f
    if (-not (Test-Path -LiteralPath $fullPath)) {
        Write-Host "MISSING: $f (path: $fullPath)"
        continue
    }
    try {
        $content = Get-Content -LiteralPath $fullPath -Encoding UTF8 | Out-String
        $xml = [xml]$content
        $nodeCount = $xml.Catalog.ChildNodes.Count
        Write-Host "OK: $f ($nodeCount nodes)"
    } catch {
        Write-Host "ERROR: $f - $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "===== Galaxy Syntax Check ====="
$galaxyFile = Join-Path $modRoot "Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data\LibE0EAE146_AbathurRebornRuntime.galaxy"
$content = Get-Content -LiteralPath $galaxyFile | Out-String
$openBraces = ([char[]]$content | Where-Object { $_ -eq '{' }).Count
$closeBraces = ([char[]]$content | Where-Object { $_ -eq '}' }).Count
$lineCount = ($content -split "`n").Count
Write-Host "Galaxy file lines: $lineCount"
Write-Host "Open braces: $openBraces"
Write-Host "Close braces: $closeBraces"
if ($openBraces -eq $closeBraces) {
    Write-Host "OK: Braces balanced"
} else {
    Write-Host "ERROR: Unbalanced braces (diff: $($openBraces - $closeBraces))"
}

Write-Host ""
Write-Host "===== All Galaxy Files Brace Check ====="
$galaxyDir = Join-Path $modRoot "Mods\7vs1\CoopZeroPop.SC2Mod\Base.SC2Data"
$galaxyFiles = Get-ChildItem -Path $galaxyDir -Filter "*.galaxy" -Recurse
$errorCount = 0
foreach ($gf in $galaxyFiles) {
    $gc = Get-Content -LiteralPath $gf.FullName | Out-String
    $ob = ([char[]]$gc | Where-Object { $_ -eq '{' }).Count
    $cb = ([char[]]$gc | Where-Object { $_ -eq '}' }).Count
    if ($ob -ne $cb) {
        Write-Host "ERROR: $($gf.Name) - open:$ob close:$cb"
        $errorCount++
    }
}
if ($errorCount -eq 0) {
    Write-Host "OK: All $($galaxyFiles.Count) galaxy files have balanced braces"
} else {
    Write-Host "$errorCount files with unbalanced braces"
}

Write-Host ""
Write-Host "===== Element Counts ====="
$abilContent = Get-Content -LiteralPath (Join-Path $xmDir "AbilData_Reborn.xml") -Encoding UTF8 | Out-String
$abilXml = [xml]$abilContent
$abilCount = ($abilXml.Catalog.ChildNodes | Where-Object { $_.LocalName -like "CAbil*" }).Count
Write-Host "AbilData_Reborn.xml: $abilCount abilities"

$unitContent = Get-Content -LiteralPath (Join-Path $xmDir "UnitData_Reborn.xml") -Encoding UTF8 | Out-String
$unitXml = [xml]$unitContent
$unitCount = ($unitXml.Catalog.ChildNodes | Where-Object { $_.LocalName -eq "CUnit" }).Count
Write-Host "UnitData_Reborn.xml: $unitCount units"

$actorContent = Get-Content -LiteralPath (Join-Path $xmDir "ActorData_Reborn.xml") -Encoding UTF8 | Out-String
$actorXml = [xml]$actorContent
$actorCount = ($actorXml.Catalog.ChildNodes | Where-Object { $_.LocalName -like "CActor*" }).Count
Write-Host "ActorData_Reborn.xml: $actorCount actors"

$buttonContent = Get-Content -LiteralPath (Join-Path $xmDir "ButtonData_Reborn.xml") -Encoding UTF8 | Out-String
$buttonXml = [xml]$buttonContent
$buttonCount = ($buttonXml.Catalog.ChildNodes | Where-Object { $_.LocalName -eq "CButton" }).Count
Write-Host "ButtonData_Reborn.xml: $buttonCount buttons"

$weaponContent = Get-Content -LiteralPath (Join-Path $xmDir "WeaponData_Reborn.xml") -Encoding UTF8 | Out-String
$weaponXml = [xml]$weaponContent
$weaponCount = ($weaponXml.Catalog.ChildNodes | Where-Object { $_.LocalName -like "CWeapon*" }).Count
Write-Host "WeaponData_Reborn.xml: $weaponCount weapons"

Write-Host ""
Write-Host "===== Static analysis complete ====="
