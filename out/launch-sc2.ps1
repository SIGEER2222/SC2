$map = 'E:\SC2\SC2new\StarCraft II\Maps\zexpedition03_reborn_port.SC2Map'
$switcher = 'E:\SC2\SC2new\StarCraft II\Support64\SC2Switcher_x64.exe'
Start-Process -FilePath $switcher -ArgumentList "`"$map`""
Write-Host "Game launched at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
