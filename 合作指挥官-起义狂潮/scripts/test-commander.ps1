param(
    [Parameter(Mandatory=$true)][string]$Commander,
    [string]$Map = "tzeratul02_7vs1.SC2Map"
)
$ErrorActionPreference = 'Stop'
# 用 $PSCommandPath 推导路径，避免硬编码中文路径（PS5.1 读脚本时中文可能乱码）
$thisScript = $PSCommandPath
if (-not $thisScript) { $thisScript = $MyInvocation.MyCommand.Path }
$scriptDir = Split-Path $thisScript -Parent
$workspace = Split-Path $scriptDir -Parent

# 停止上一个游戏
Stop-Process -Name SC2_x64 -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# 启动
Write-Output "=== [$Commander] Launching on $Map ==="
Push-Location $workspace
& "$scriptDir\launch-7vs1-coop-test.ps1" -MapSource ".\Maps\$Map" -LiveMapName $Map -Commanders @($Commander) 2>&1 | Select-Object -Last 3
Pop-Location

# 等待加载
Write-Output "=== [$Commander] Waiting for game ready ==="
$waitResult = & "$scriptDir\wait-for-game-ready.ps1" 2>&1
$waitResult | Select-Object -Last 8

if ($LASTEXITCODE -ne 0) {
    Write-Output "=== [$Commander] FAILED (wait exit $LASTEXITCODE) ==="
    Write-Output $waitResult
    exit 1
}

# 截图
Start-Sleep -Seconds 3
Add-Type -AssemblyName System.Drawing,System.Windows.Forms
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bitmap = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
$stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$shotPath = "C:\Users\22448\AppData\Local\Temp\codex-test-$Commander-$stamp.png"
$bitmap.Save($shotPath)
$graphics.Dispose(); $bitmap.Dispose()
Write-Output "=== [$Commander] Screenshot: $shotPath ==="

# OCR
Write-Output "=== [$Commander] OCR (zh-Hans-CN) ==="
$ocrText = & python "$scriptDir\ocr-screenshot.py" $shotPath 2>&1
if ($ocrText) {
    $preview = $ocrText.Substring(0, [Math]::Min(400, $ocrText.Length))
    Write-Output $preview
} else {
    Write-Output "(OCR returned empty)"
}

Write-Output "=== [$Commander] DONE ==="
