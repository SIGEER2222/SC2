$path = "E:\Code\MyMod\SC2\" + [char]0x5408 + [char]0x4F5C + [char]0x6307 + [char]0x6325 + [char]0x5B98 + "-" + [char]0x8D77 + [char]0x4E49 + [char]0x72C2 + [char]0x6F6E + "\scripts\launch-abathur-reborn-coop.ps1"
Write-Host "Converting: $path"

# Read as UTF-8 (the file is UTF-8 without BOM)
$content = [System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))
Write-Host "Read $($content.Length) chars"

# Normalize line endings to CRLF
$content = $content -replace "`r`n", "`n" -replace "`n", "`r`n"

# Write back as UTF-8 with BOM
$utf8Bom = [System.Text.UTF8Encoding]::new($true)
[System.IO.File]::WriteAllText($path, $content, $utf8Bom)
Write-Host "Written as UTF-8 with BOM + CRLF" -ForegroundColor Green

# Verify
$bytes = [System.IO.File]::ReadAllBytes($path)
$hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
Write-Host "Has BOM now: $hasBom"

# Parse check
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors -and $errors.Count -gt 0) {
    Write-Host "PARSE ERRORS:" -ForegroundColor Red
    foreach ($e in $errors) {
        Write-Host "  Line $($e.Extent.StartLineNumber) Col $($e.Extent.StartColumnNumber): $($e.Message)"
    }
} else {
    Write-Host "PARSE OK: no syntax errors" -ForegroundColor Green
}
