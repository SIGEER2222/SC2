$xmDir = "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\XM\XMAbathurReborn.SC2Mod\Base.SC2Data\GameData"

# Check file encoding (BOM)
$files = @("AbilData_Reborn.xml", "UnitData_Reborn.xml", "ActorData_Reborn.xml", "ButtonData_Reborn.xml", "WeaponData_Reborn.xml", "GameData.xml", "EffectData_Reborn.xml", "BehaviorData_Reborn.xml")
Write-Host "===== File Encoding Check ====="
foreach ($f in $files) {
    $path = Join-Path $xmDir $f
    if (Test-Path -LiteralPath $path) {
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $hasBOM = $false
        $bomType = "No BOM"
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $hasBOM = $true
            $bomType = "UTF-8 BOM"
        } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
            $hasBOM = $true
            $bomType = "UTF-16 LE BOM"
        } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
            $hasBOM = $true
            $bomType = "UTF-16 BE BOM"
        }
        Write-Host ("  {0}: {1} (size: {2} bytes, first 3 bytes: 0x{3:X2} 0x{4:X2} 0x{5:X2})" -f $f, $bomType, $bytes.Length, $bytes[0], $bytes[1], $bytes[2])
    } else {
        Write-Host "  ${f}: NOT FOUND"
    }
}

# Check for invalid XML characters in AbilData_Reborn.xml
Write-Host ""
Write-Host "===== AbilData_Reborn.xml Content Check ====="
$abilPath = Join-Path $xmDir "AbilData_Reborn.xml"
$content = Get-Content -LiteralPath $abilPath -Encoding UTF8
$lineCount = $content.Count
Write-Host "Total lines: $lineCount"

# Check for common XML issues
$issues = @()
for ($i = 0; $i -lt $content.Count; $i++) {
    $line = $content[$i]
    $lineNum = $i + 1
    # Check for unclosed tags
    if ($line -match '<CAbil' -and $line -notmatch '</CAbil' -and $line -notmatch '/>') {
        # This is normal for multi-line elements
    }
    # Check for invalid characters
    if ($line -match '[\x00-\x08\x0B\x0C\x0E-\x1F]') {
        $issues += "Line ${lineNum}: Invalid control character"
    }
    # Check for double encoding
    if ($line -match '&amp;#|&amp;amp;') {
        $issues += "Line ${lineNum}: Possible double encoding: $line"
    }
}

if ($issues.Count -eq 0) {
    Write-Host "No common XML issues found"
} else {
    Write-Host "Found $($issues.Count) issues:"
    $issues | Select-Object -First 20
}

# Check if all CAbil elements are properly closed
Write-Host ""
Write-Host "===== CAbil Element Count ====="
$openCount = ($content | Where-Object { $_ -match '<CAbil' -and $_ -notmatch '</CAbil' -and $_ -notmatch '/>' }).Count
$closeCount = ($content | Where-Object { $_ -match '</CAbil' }).Count
$selfCloseCount = ($content | Where-Object { $_ -match '<CAbil.*-/>' }).Count
Write-Host "Opening CAbil tags: $openCount"
Write-Host "Closing CAbil tags: $closeCount"
Write-Host "Self-closing CAbil tags: $selfCloseCount"

# List all CAbil IDs
Write-Host ""
Write-Host "===== All CAbil IDs in AbilData_Reborn.xml ====="
$abilIds = @()
foreach ($line in $content) {
    if ($line -match '<CAbil\w+\s+id="([^"]+)"') {
        $abilIds += $matches[1]
    }
}
Write-Host "Total abilities: $($abilIds.Count)"
$abilIds | ForEach-Object { Write-Host "  $_" }
