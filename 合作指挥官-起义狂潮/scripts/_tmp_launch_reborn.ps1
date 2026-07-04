$ErrorActionPreference = "Stop"

$mapSrc = "E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods\emptytest.SC2Map"
$mapDst = "E:\SC2\SC2new\StarCraft II\Maps\7vs1\emptytest.SC2Map"
$rebornSrc = "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\crys_the_swarm_reborn.SC2Mod"
$rebornDst = "E:\SC2\SC2new\StarCraft II\Mods\crys_the_swarm_reborn.SC2Mod"
$switcher = "E:\SC2\SC2new\StarCraft II\Support64\SC2Switcher_x64.exe"
$logsRoot = "C:\Users\22448\Documents\StarCraft II\GameLogs"

Write-Host "[1/5] Stopping SC2..."
Get-Process -Name "SC2_x64","SC2Switcher_x64","BlizzardError" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "[2/5] Clearing logs..."
if (Test-Path -LiteralPath $logsRoot) {
    Get-ChildItem -LiteralPath $logsRoot -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "[3/5] Syncing map..."
if (Test-Path -LiteralPath $mapDst) { Remove-Item -LiteralPath $mapDst -Recurse -Force }
Copy-Item -LiteralPath $mapSrc -Destination $mapDst -Recurse -Force

Write-Host "[4/5] Syncing reborn mod..."
if (Test-Path -LiteralPath $rebornDst) { Remove-Item -LiteralPath $rebornDst -Recurse -Force }
Copy-Item -LiteralPath $rebornSrc -Destination $rebornDst -Recurse -Force

Write-Host "[5/5] Launching game..."
& $switcher $mapDst
Write-Host "Done!"
