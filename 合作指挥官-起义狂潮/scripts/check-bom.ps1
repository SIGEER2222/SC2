$path = "E:\Code\MyMod\SC2\" + [char]0x5408 + [char]0x4F5C + [char]0x6307 + [char]0x6325 + [char]0x5B98 + "-" + [char]0x8D77 + [char]0x4E49 + [char]0x72C2 + [char]0x6F6E + "\scripts\launch-abathur-reborn-coop.ps1"
Write-Host "Path: $path"
Write-Host "Exists: $(Test-Path -LiteralPath $path)"

$bytes = [System.IO.File]::ReadAllBytes($path)
Write-Host "Total bytes: $($bytes.Length)"
Write-Host "First 4 bytes: $(($bytes[0..3] | ForEach-Object { $_.ToString('X2') }) -join ' ')"

$hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
Write-Host "Has UTF-8 BOM: $hasBom"

$crlf = 0; $lfOnly = 0; $crOnly = 0
for ($i = 0; $i -lt $bytes.Length; $i++) {
    if ($bytes[$i] -eq 10) {
        if ($i -gt 0 -and $bytes[$i-1] -eq 13) { $crlf++ } else { $lfOnly++ }
    } elseif ($bytes[$i] -eq 13 -and ($i -eq $bytes.Length-1 -or $bytes[$i+1] -ne 10)) {
        $crOnly++
    }
}
Write-Host "CRLF: $crlf, LF only: $lfOnly, CR only: $crOnly"

# Parse
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
