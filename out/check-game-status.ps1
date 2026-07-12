Start-Sleep -Seconds 60
Write-Host '=== SC2 Process ==='
$sc2 = Get-Process SC2_x64 -ErrorAction SilentlyContinue
if ($sc2) {
    Write-Host "  PID: $($sc2.Id), StartTime: $($sc2.StartTime)"
} else {
    Write-Host "  SC2_x64 NOT running"
}
Write-Host '=== GameLogs (latest 5) ==='
Get-ChildItem 'C:\Users\22448\Documents\StarCraft II\GameLogs' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 5 Name, LastWriteTime, Length
Write-Host '=== ScriptError check ==='
$se = Get-ChildItem 'C:\Users\22448\Documents\StarCraft II\GameLogs' -Filter '*ScriptError*' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if ($se) {
    Write-Host "  ScriptError found: $($se.Name)"
    Write-Host "  Content (first 500 chars):"
    $content = Get-Content $se.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) { Write-Host $content.Substring(0, [Math]::Min(500, $content.Length)) }
} else {
    Write-Host "  No ScriptError files"
}
Write-Host '=== RuntimeProbe Bank ==='
$bankPath = 'C:\Users\22448\Documents\StarCraft II\Banks\RuntimeProbe.SC2Bank'
if (Test-Path $bankPath) {
    $bankFile = Get-Item $bankPath
    Write-Host "  Bank exists! Size: $($bankFile.Length), Modified: $($bankFile.LastWriteTime)"
} else {
    Write-Host "  Bank NOT found"
}
