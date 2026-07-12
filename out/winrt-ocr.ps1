# 使用 Windows.Media.Ocr 进行截图 OCR 分析
# 需要 Windows 10+ 和中文语言包

param(
    [Parameter(Mandatory=$true)]
    [string]$ImagePath
)

if (-not (Test-Path $ImagePath)) {
    Write-Host "ERROR: file not found: $ImagePath" -ForegroundColor Red
    exit 1
}

# 加载 WinRT 类型
Add-Type -AssemblyName System.Runtime.WindowsRuntime

$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | `
    Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | `
    Select-Object -First 1).MakeGenericMethod([Windows.Foundation.IAsyncOperation])

function AwaitOperation($winRtTask, $resultType) {
    $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | `
        Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | `
        Where-Object { $_.GetParameters()[0].ParameterType.GetGenericArguments()[0].Name -eq $resultType.Name } | `
        Select-Object -First 1).MakeGenericMethod($resultType)
    $netTask = $asTask.Invoke($null, @($winRtTask))
    $netTask.Wait(-1) | Out-Null
    $netTask.Result
}

function AwaitAction($winRtAction) {
    $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | `
        Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' } | `
        Select-Object -First 1)
    $netTask = $asTask.Invoke($null, @($winRtAction))
    $netTask.Wait(-1) | Out-Null
}

# 获取 OCR 语言列表
[Windows.Media.Ocr.OcrEngine,Windows.Media.Ocr,ContentType=WindowsRuntime] | Out-Null
$langs = [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages
Write-Host "Available OCR languages: $($langs.Count)"
foreach ($lang in $langs) {
    Write-Host "  - $($lang.LanguageTag)"
}

if ($langs.Count -eq 0) {
    Write-Host "No OCR language available!" -ForegroundColor Red
    exit 1
}

# 优先选中文
$selectedLang = $langs | Where-Object { $_.LanguageTag -like "zh*" } | Select-Object -First 1
if ($selectedLang -eq $null) {
    $selectedLang = $langs[0]
}

Write-Host "`nUsing language: $($selectedLang.LanguageTag)" -ForegroundColor Cyan
$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($selectedLang)
if ($engine -eq $null) {
    Write-Host "Failed to create OCR engine" -ForegroundColor Red
    exit 1
}

# 加载图片
$absPath = (Resolve-Path $ImagePath).Path
Write-Host "`nLoading image: $absPath"

[Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
[Windows.Storage.FileAccessMode,Windows.Storage,ContentType=WindowsRuntime] | Out-Null

# 用 StorageFile.GetFileFromPathAsync
$getFileMethod = [Windows.Storage.StorageFile].GetMethod('GetFileFromPathAsync')
$storageFileTask = $getFileMethod.Invoke($null, @($absPath))

# 等待获取文件
$fileType = [Windows.Storage.StorageFile]
$storageFile = AwaitOperation $storageFileTask $fileType
Write-Host "StorageFile loaded: $($storageFile.Path)"

# 打开文件流
$openTask = $storageFile.OpenAsync([Windows.Storage.FileAccessMode]::Read)
$streamType = [Windows.Storage.Streams.IRandomAccessStream]
$stream = AwaitOperation $openTask $streamType
Write-Host "Stream opened"

# 创建 BitmapDecoder
[Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime] | Out-Null
$createTask = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)
$decoderType = [Windows.Graphics.Imaging.BitmapDecoder]
$decoder = AwaitOperation $createTask $decoderType
Write-Host "Decoder created, pixel width: $($decoder.PixelWidth), height: $($decoder.PixelHeight)"

# 获取 SoftwareBitmap
$getBitmapTask = $decoder.GetSoftwareBitmapAsync()
$bitmapType = [Windows.Graphics.Imaging.SoftwareBitmap]
$bitmap = AwaitOperation $getBitmapTask $bitmapType
Write-Host "SoftwareBitmap obtained: $($bitmap.PixelWidth)x$($bitmap.PixelHeight)"

# OCR 识别
$ocrTask = $engine.RecognizeAsync($bitmap)
$resultType = [Windows.Media.Ocr.OcrResult]
$result = AwaitOperation $ocrTask $resultType

Write-Host "`n=== OCR Result ===" -ForegroundColor Green
Write-Host $result.Text

Write-Host "`n=== Lines ===" -ForegroundColor Yellow
$lineIdx = 0
foreach ($line in $result.Lines) {
    Write-Host "Line ${lineIdx}: $($line.Text)"
    $lineIdx++
}

# 提取所有单词及其位置
Write-Host "`n=== Words with positions ===" -ForegroundColor Magenta
foreach ($line in $result.Lines) {
    foreach ($word in $line.Words) {
        $rect = $word.BoundingRect
        Write-Host "  '$($word.Text)' at X=$($rect.X), Y=$($rect.Y), W=$($rect.Width), H=$($rect.Height)"
    }
}
