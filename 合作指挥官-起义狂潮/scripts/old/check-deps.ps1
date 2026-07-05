param(
    [string]$GameRoot = "E:\SC2\SC2new\StarCraft II"
)

$checked = @{}
$missing = @()
$found = @()

function Parse-DocumentInfo {
    param([string]$ModPath)

    if (Test-Path $ModPath -PathType Container) {
        $docInfoPath = Join-Path $ModPath "DocumentInfo"
        if (Test-Path $docInfoPath -PathType Leaf) {
            try {
                [xml]$xml = Get-Content $docInfoPath -Raw -Encoding UTF8
                $deps = @()
                if ($xml.DocInfo.Dependencies) {
                    foreach ($v in $xml.DocInfo.Dependencies.Value) {
                        $deps += $v
                    }
                }
                return $deps
            } catch {
                return @()
            }
        } else {
            # 检查是否有 DocumentInfo.version 文件说明这是文档格式
            $docInfoVerPath = Join-Path $ModPath "DocumentInfo.version"
            if (Test-Path $docInfoVerPath -PathType Leaf) {
                # 有 version 文件但没有 DocumentInfo 文件，可能是 mod 文件
                return @("__NO_DOCINFO__")
            }
            return @()
        }
    } else {
        # .SC2Mod 文件（MPQ 压缩包），无法直接读取 DocumentInfo
        return @("__MPQ_FILE__")
    }
}

function Resolve-DepPath {
    param([string]$Dep)

    # 解析 "bnet:name/version/id,file:path" 或 "file:path" 格式
    $filePart = $null
    if ($Dep -match "^bnet:") {
        $parts = $Dep -split ",", 2
        if ($parts.Length -eq 2 -and $parts[1] -match "^file:(.+)$") {
            $filePart = $matches[1]
        } else {
            return @{ Type = "bnet-only"; Raw = $Dep }
        }
    } elseif ($Dep -match "^file:(.+)$") {
        $filePart = $matches[1]
    } else {
        return @{ Type = "unknown"; Raw = $Dep }
    }

    # 规范化路径分隔符
    $filePart = $filePart -replace "\\", "/"
    $fullPath = Join-Path $script:GameRoot $filePart
    return @{ Type = "file"; Path = $filePart; FullPath = $fullPath }
}

function Check-DepRecursive {
    param(
        [string]$ModPath,
        [string]$Indent = ""
    )

    if ($script:checked.ContainsKey($ModPath)) { return }
    $script:checked[$ModPath] = $true

    $relPath = $ModPath -replace [regex]::Escape($script:GameRoot + "\"), ""
    Write-Host ("$Indent$relPath") -NoNewline

    if (-not (Test-Path $ModPath)) {
        Write-Host " [MISSING]" -ForegroundColor Red
        $script:missing += $ModPath
        return
    }

    Write-Host " [OK]" -ForegroundColor Green
    $script:found += $ModPath

    $deps = Parse-DocumentInfo -ModPath $ModPath
    if ($deps -contains "__MPQ_FILE__") {
        Write-Host "$Indent  (MPQ compressed file, cannot read DocumentInfo)" -ForegroundColor Yellow
        return
    }
    if ($deps -contains "__NO_DOCINFO__") {
        Write-Host "$Indent  (no DocumentInfo file)" -ForegroundColor Yellow
        return
    }

    foreach ($dep in $deps) {
        $resolved = Resolve-DepPath -Dep $dep
        if ($resolved.Type -eq "file") {
            Write-Host ("$Indent  -> $($dep)") -NoNewline
            if (-not (Test-Path $resolved.FullPath)) {
                Write-Host " [MISSING]" -ForegroundColor Red
                $script:missing += $resolved.FullPath
            } else {
                Write-Host ""
                Check-DepRecursive -ModPath $resolved.FullPath -Indent ($Indent + "    ")
            }
        } elseif ($resolved.Type -eq "bnet-only") {
            Write-Host ("$Indent  -> $($dep) [bnet-only, requires Battle.net cache]") -ForegroundColor Cyan
        } else {
            Write-Host ("$Indent  -> $($dep) [unknown format]") -ForegroundColor Magenta
        }
    }
}

# 从地图 DocumentInfo 开始
$mapDocInfo = "E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Maps\abathur_test_map\DocumentInfo"
Write-Host "=== Map DocumentInfo ===" -ForegroundColor White
[xml]$mapXml = Get-Content $mapDocInfo -Raw -Encoding UTF8
foreach ($v in $mapXml.DocInfo.Dependencies.Value) {
    $resolved = Resolve-DepPath -Dep $v
    if ($resolved.Type -eq "file") {
        Write-Host ("Map -> $($v)") -NoNewline
        if (-not (Test-Path $resolved.FullPath)) {
            Write-Host " [MISSING]" -ForegroundColor Red
            $script:missing += $resolved.FullPath
        } else {
            Write-Host ""
            Check-DepRecursive -ModPath $resolved.FullPath -Indent "  "
        }
    } elseif ($resolved.Type -eq "bnet-only") {
        Write-Host ("Map -> $($v) [bnet-only, requires Battle.net cache]") -ForegroundColor Cyan
    } else {
        Write-Host ("Map -> $($v) [unknown]") -ForegroundColor Magenta
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor White
Write-Host "Total checked: $($script:checked.Count)"
Write-Host "Found: $($script:found.Count)"
Write-Host "Missing: $($script:missing.Count)"
if ($script:missing.Count -gt 0) {
    Write-Host ""
    Write-Host "=== Missing Dependencies ===" -ForegroundColor Red
    foreach ($m in $script:missing) {
        Write-Host "  $m" -ForegroundColor Red
    }
}
