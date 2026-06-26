# 设置 bank 为 AbathurReborn 并启动 ttosh03b 地图
$ErrorActionPreference = "Continue"

# 杀掉旧进程
Get-Process -Name "SC2_x64","SC2Switcher_x64","BlizzardError" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# 设置 Bank
$bankPath = "C:\Users\22448\Documents\StarCraft II\Banks\CampaignXCore.SC2Bank"
if (Test-Path $bankPath) {
    [xml]$xml = Get-Content $bankPath
    
    # 设置 CommanderP1
    $key = $xml.SelectSingleNode("/Bank/Section[@name='Ach']/Key[@name='CommanderP1']")
    if ($key) {
        $val = $key.SelectSingleNode("Value")
        if ($val) {
            $val.SetAttribute("string", "AbathurReborn")
            $val.RemoveAttribute("int")
        }
    }
    
    # 设置 PrimaryCommander
    $key2 = $xml.SelectSingleNode("/Bank/Section[@name='Ach']/Key[@name='PrimaryCommander']")
    if ($key2) {
        $val2 = $key2.SelectSingleNode("Value")
        if ($val2) {
            $val2.SetAttribute("string", "AbathurReborn")
            $val2.RemoveAttribute("int")
        }
    }
    
    $xml.Save($bankPath)
    Write-Host "Set bank to AbathurReborn"
}

# 启动地图
$mapPath = "C:\Users\22448\Downloads\合作指挥官版起义狂潮0.81\Maps\XM\ttosh03b.SC2Map"
$switcher = "E:\SC2\SC2new\StarCraft II\Support64\SC2Switcher_x64.exe"

Write-Host "Launching: $mapPath"
Write-Host "Switcher: $switcher"

& $switcher $mapPath
Write-Host "Game launched, waiting 45 seconds..."
Start-Sleep -Seconds 45

# 检查进程
$procs = Get-Process -Name "SC2_x64","SC2Switcher_x64" -ErrorAction SilentlyContinue
if ($procs) {
    Write-Host "SC2 is running:"
    $procs | ForEach-Object { Write-Host "  $($_.ProcessName) - $($_.MainWindowTitle)" }
} else {
    Write-Host "SC2 is NOT running!"
}

# 检查 ScriptError
$logDir = "C:\Users\22448\Documents\StarCraft II\GameLogs"
if (Test-Path $logDir) {
    $errorLogs = Get-ChildItem $logDir -Filter "*ScriptError*" | Sort-Object LastWriteTime -Descending | Select-Object -First 3
    if ($errorLogs) {
        Write-Host "`nRecent ScriptError logs:"
        $errorLogs | ForEach-Object { Write-Host "  $($_.Name) - $($_.LastWriteTime)" }
        $latest = $errorLogs[0]
        Write-Host "`nLatest ScriptError content:"
        Get-Content $latest.FullName
    } else {
        Write-Host "`nNo ScriptError logs found"
    }
}
