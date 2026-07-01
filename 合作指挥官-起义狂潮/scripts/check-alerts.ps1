$logDir = "C:\Users\22448\Documents\StarCraft II\GameLogs"
$alertFiles = Get-ChildItem -LiteralPath $logDir -Filter "*Alerts*" | Sort-Object LastWriteTime -Descending
if ($alertFiles) {
    $alertFile = $alertFiles[0]
    Write-Host "===== Reading: $($alertFile.Name) ====="
    $content = Get-Content -LiteralPath $alertFile.FullName -Encoding UTF8
    Write-Host "Total lines: $($content.Count)"
    Write-Host ""
    Write-Host "===== Lines mentioning Reborn/Abathur/XML errors ====="
    $matched = $content | Where-Object { $_ -match "Reborn|Abathur|XML|parse|invalid|CommanderUnits|NaturalCamouflage|Cliffjumper|CombatDrone|MineralEfficiency|VespeneEfficiency|FastMorphing|LarvaTrainSwarm2|TrainQueen|AbilData" }
    if ($matched) {
        $matched | Select-Object -First 50
    } else {
        Write-Host "No matching lines found"
    }
    Write-Host ""
    Write-Host "===== Last 30 lines of Alerts ====="
    $content | Select-Object -Last 30
} else {
    Write-Host "No Alerts files found"
}
