$logDir = "C:\Users\22448\Documents\StarCraft II\GameLogs"
if (-not (Test-Path -LiteralPath $logDir)) {
    Write-Host "Log directory not found: $logDir"
    exit 0
}

$files = Get-ChildItem -LiteralPath $logDir -Filter "*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 10
Write-Host "===== Recent Game Log Files ====="
foreach ($f in $files) {
    Write-Host ("  {0}  ({1} bytes, {2})" -f $f.Name, $f.Length, $f.LastWriteTime)
}

Write-Host ""
Write-Host "===== Checking for ScriptError ====="
$scriptErrors = $files | Where-Object { $_.Name -like "*ScriptError*" -or $_.Name -like "*Error*" }
if ($scriptErrors) {
    foreach ($e in $scriptErrors) {
        Write-Host "FOUND ERROR LOG: $($e.Name)"
        $content = Get-Content -LiteralPath $e.FullName -Encoding UTF8
        Write-Host "--- Content (first 50 lines) ---"
        $content | Select-Object -First 50
        Write-Host "--- End ---"
    }
} else {
    Write-Host "No ScriptError files found in recent logs"
}

Write-Host ""
Write-Host "===== Checking for XMLAlerts ====="
$xmlAlerts = $files | Where-Object { $_.Name -like "*XML*" -or $_.Name -like "*Alert*" }
if ($xmlAlerts) {
    foreach ($a in $xmlAlerts) {
        Write-Host "FOUND XML ALERT: $($a.Name)"
        $content = Get-Content -LiteralPath $a.FullName -Encoding UTF8
        Write-Host "--- Content (first 50 lines) ---"
        $content | Select-Object -First 50
        Write-Host "--- End ---"
    }
} else {
    Write-Host "No XML alert files found in recent logs"
}

Write-Host ""
Write-Host "===== Most Recent Log Content (first 30 lines) ====="
if ($files) {
    $latest = $files[0]
    Write-Host "File: $($latest.Name)"
    $content = Get-Content -LiteralPath $latest.FullName -Encoding UTF8
    $content | Select-Object -First 30
}
