$path = 'E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\launch-abathur-reborn-coop.ps1'
$bytes = [System.IO.File]::ReadAllBytes($path)
Write-Host ('Total bytes: ' + $bytes.Length)
Write-Host ('First 4 bytes: ' + ($bytes[0..3] | ForEach-Object { $_.ToString('X2') }) -join ' ')

$crlf = 0; $lfOnly = 0; $crOnly = 0
for ($i = 0; $i -lt $bytes.Length; $i++) {
    if ($bytes[$i] -eq 10) {
        if ($i -gt 0 -and $bytes[$i-1] -eq 13) { $crlf++ } else { $lfOnly++ }
    } elseif ($bytes[$i] -eq 13 -and ($i -eq $bytes.Length-1 -or $bytes[$i+1] -ne 10)) {
        $crOnly++
    }
}
Write-Host ('CRLF: ' + $crlf + ', LF only: ' + $lfOnly + ', CR only: ' + $crOnly)

# Count total lines as PowerShell would see them
$content = [System.IO.File]::ReadAllText($path)
$lineCount = ($content -split "`n").Count
Write-Host ('Line count (split by LF): ' + $lineCount)

# Check for null bytes
$nullCount = 0
for ($i = 0; $i -lt $bytes.Length; $i++) {
    if ($bytes[$i] -eq 0) { $nullCount++ }
}
Write-Host ('Null bytes: ' + $nullCount)

# Parse to find errors
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors -and $errors.Count -gt 0) {
    Write-Host 'PARSE ERRORS:' -ForegroundColor Red
    foreach ($e in $errors) {
        Write-Host ('  Line ' + $e.Extent.StartLineNumber + ' Col ' + $e.Extent.StartColumnNumber + ': ' + $e.Message)
        Write-Host ('    Text: ' + $e.Extent.Text)
    }
} else {
    Write-Host 'PARSE OK: no syntax errors' -ForegroundColor Green
}
