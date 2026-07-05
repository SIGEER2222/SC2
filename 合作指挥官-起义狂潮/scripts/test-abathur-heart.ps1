<#
.SYNOPSIS
  阿巴瑟之心测试 - 一体化启动脚本

.DESCRIPTION
  完整流程：停止 SC2 → 同步 mod + 地图 → 设置依赖 → 启动游戏 → 等待加载 → 报告结果
  新建脚本，避免与旧的 launch-abathur-test.ps1 / launch-abathur-reborn.ps1 冲突。

  退出码:
    0 = 加载成功（Alerts.txt 出现 + 宽限期无新错误 + 进程存活）
    1 = 加载失败（出现新 ScriptError 或游戏进程崩溃）
    2 = 超时（无 Alerts.txt）
    3 = 安装失败
#>
[CmdletBinding()]
param(
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$SourceModsRoot = "C:\Users\22448\Downloads\阿巴瑟之心\Mods",
    [string]$MapSourceDir = "E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Maps\AbathurHeartTest_unpacked",
    [string]$MapName = "AbathurHeartTest.SC2Map",
    [int]$MaxWaitSeconds = 240,
    [int]$GracePeriodSeconds = 25,
    [switch]$SkipInstall,
    [switch]$SkipWait,
    [string[]]$ModFilter = @(),
    # -Commander: 按指挥官 identifier 过滤（不区分大小写，包含匹配）
    #   例: "Cmdr_Abathur" / "Violets_Kerrigan" / "Violets_"（前缀匹配所有 Violets 子组）
    #   空字符串 = 不过滤，生成全部 25 个指挥官组
    [string]$Commander = ""
)

$ErrorActionPreference = "Stop"

# ============================================================
# 路径
# ============================================================
$mapLive = Join-Path (Join-Path $Sc2Root "Maps") $MapName
$modsLiveRoot = Join-Path $Sc2Root "Mods"
$sc2exe = Join-Path $Sc2Root "Versions\Base97425\SC2_x64.exe"
$switcherPath = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"
$logsRoot = "C:\Users\22448\Documents\StarCraft II\GameLogs"

# ============================================================
# 辅助函数
# ============================================================

function Stop-Sc2Processes {
    foreach ($name in @("SC2_x64", "SC2Switcher_x64", "BlizzardError")) {
        $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
        if (-not $procs) { continue }
        foreach ($p in $procs) {
            try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch {}
        }
    }
    Start-Sleep -Seconds 3
}

function Clear-GameLogs {
    if (-not (Test-Path -LiteralPath $logsRoot)) { return }
    Get-ChildItem -LiteralPath $logsRoot -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            if ($_.PSIsContainer) {
                [System.IO.Directory]::Delete($_.FullName, $true)
            } else {
                [System.IO.File]::Delete($_.FullName)
            }
        } catch {}
    }
}

function Test-ByteSequenceAt {
    param([byte[]]$Bytes, [int]$Offset, [byte[]]$Needle)
    if ($Offset + $Needle.Length -gt $Bytes.Length) { return $false }
    for ($i = 0; $i -lt $Needle.Length; $i++) {
        if ($Bytes[$Offset + $i] -ne $Needle[$i]) { return $false }
    }
    return $true
}

function Find-DocumentHeaderDependencyStart {
    param([byte[]]$Bytes)
    $markers = @(
        [System.Text.Encoding]::UTF8.GetBytes("file:"),
        [System.Text.Encoding]::UTF8.GetBytes("bnet:")
    )
    for ($offset = 4; $offset -lt $Bytes.Length; $offset++) {
        foreach ($marker in $markers) {
            if (-not (Test-ByteSequenceAt -Bytes $Bytes -Offset $offset -Needle $marker)) { continue }
            $count = [System.BitConverter]::ToUInt32($Bytes, $offset - 4)
            if (($count -gt 0) -and ($count -lt 128)) { return $offset }
        }
    }
    throw "DocumentHeader dependency table not found."
}

function Get-DocumentHeaderDependencyEndOffset {
    param([byte[]]$Bytes, [int]$Start, [uint32]$Count)
    $offset = $Start
    for ($i = 0; $i -lt $Count; $i++) {
        while (($offset -lt $Bytes.Length) -and ($Bytes[$offset] -ne 0)) { $offset++ }
        if ($offset -ge $Bytes.Length) { throw "dep string not null-terminated" }
        $offset++
    }
    return $offset
}

function Set-DocumentHeaderDependencies {
    param([string]$Path, [string[]]$Dependencies)
    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($Path)
    $depStart = Find-DocumentHeaderDependencyStart -Bytes $bytes
    $countOffset = $depStart - 4
    $currentCount = [System.BitConverter]::ToUInt32($bytes, $countOffset)
    $depEnd = Get-DocumentHeaderDependencyEndOffset -Bytes $bytes -Start $depStart -Count $currentCount
    $depBytes = [System.Text.Encoding]::UTF8.GetBytes((($Dependencies -join "`0") + "`0"))
    $countBytes = [System.BitConverter]::GetBytes([uint32]$Dependencies.Count)
    $stream = New-Object System.IO.MemoryStream
    $stream.Write($bytes, 0, $countOffset)
    $stream.Write($countBytes, 0, $countBytes.Length)
    $stream.Write($depBytes, 0, $depBytes.Length)
    $stream.Write($bytes, $depEnd, $bytes.Length - $depEnd)
    [System.IO.File]::WriteAllBytes($Path, $stream.ToArray())
}

function Set-DocumentInfoDependencies {
    param([string]$Path, [string[]]$Dependencies)
    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    $doc = $xml.SelectSingleNode("/DocInfo")
    if (-not $doc) { throw "Invalid DocumentInfo: missing /DocInfo in $Path" }
    $old = $xml.SelectSingleNode("/DocInfo/Dependencies")
    if ($old) { $null = $doc.RemoveChild($old) }
    $depNode = $xml.CreateElement("Dependencies")
    foreach ($dep in $Dependencies) {
        $v = $xml.CreateElement("Value")
        $v.InnerText = $dep
        $null = $depNode.AppendChild($v)
    }
    $insertBefore = $doc.SelectSingleNode("PatchNote|Preload|HowToPlayBasic|HowToPlayAdvanced")
    if ($insertBefore) { $null = $doc.InsertBefore($depNode, $insertBefore) }
    else { $null = $doc.AppendChild($depNode) }
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $settings.Indent = $true
    $settings.NewLineChars = "`r`n"
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try { $xml.Save($writer) } finally { $writer.Close() }
}

function Sync-Directory {
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path -LiteralPath $Source)) { throw "Source not found: $Source" }
    if (Test-Path -LiteralPath $Destination) {
        $item = Get-Item -LiteralPath $Destination -Force
        if ($item.PSIsContainer) {
            [System.IO.Directory]::Delete($Destination, $true)
        } else {
            [System.IO.File]::Delete($Destination)
        }
    }
    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent)) {
        [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

function Set-CommanderFilter {
    param([string]$MapScriptPath, [string]$Commander)
    if (-not (Test-Path -LiteralPath $MapScriptPath)) {
        throw "MapScript.galaxy not found: $MapScriptPath"
    }
    $content = [System.IO.File]::ReadAllText($MapScriptPath)
    # 匹配 gv_commanderFilter = "..."; （无论原值是什么）
    $pattern = 'gv_commanderFilter\s*=\s*"[^"]*"\s*;'
    if ($Commander -eq "") {
        $replacement = 'gv_commanderFilter = "";'
    } else {
        $replacement = 'gv_commanderFilter = "' + $Commander + '";'
    }
    $newContent = [regex]::Replace($content, $pattern, $replacement)
    if ($newContent -eq $content) {
        Write-Host "  [WARN] 未找到 gv_commanderFilter 赋值语句，未做修改" -ForegroundColor Yellow
        return
    }
    [System.IO.File]::WriteAllText($MapScriptPath, $newContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  gv_commanderFilter 已设置为: `"$Commander`"" -ForegroundColor Green
}

# ============================================================
# Main
# ============================================================

try {
    Write-Host "=== 阿巴瑟之心测试 (一体化) ===" -ForegroundColor Cyan
    Write-Host "Sc2Root:         $Sc2Root"
    Write-Host "SourceModsRoot:  $SourceModsRoot"
    Write-Host "MapSourceDir:    $MapSourceDir"
    Write-Host "MapLive:         $mapLive"
    if ($Commander -ne "") {
        Write-Host "Commander:       $Commander （仅生成匹配的指挥官组）" -ForegroundColor Magenta
    } else {
        Write-Host "Commander:       （未指定，生成全部 25 个指挥官组）"
    }
    Write-Host ""

    if (-not (Test-Path -LiteralPath $sc2exe)) { throw "SC2_x64.exe not found: $sc2exe" }
    if (-not (Test-Path -LiteralPath $switcherPath)) { throw "SC2Switcher_x64.exe not found: $switcherPath" }

    # ---- 1. 停止 SC2 + 清理日志 ----
    Write-Host "[1/5] 停止 SC2 进程并清理日志..." -ForegroundColor Cyan
    Stop-Sc2Processes
    Clear-GameLogs

    if (-not $SkipInstall) {
        # ---- 2. 同步 mod ----
        Write-Host "[2/5] 同步 mod 到 $modsLiveRoot ..." -ForegroundColor Cyan
        $allMods = New-Object System.Collections.Generic.List[object]
        $seenNames = New-Object System.Collections.Generic.HashSet[string]

        $topMods = Get-ChildItem -LiteralPath $SourceModsRoot -Filter "*.SC2Mod" -ErrorAction SilentlyContinue
        foreach ($mod in $topMods) {
            # 应用 ModFilter（如果指定）
            if ($ModFilter.Count -gt 0) {
                $matched = $false
                foreach ($pattern in $ModFilter) {
                    if ($mod.Name -like $pattern) { $matched = $true; break }
                }
                if (-not $matched) { continue }
            }
            if ($seenNames.Add($mod.Name)) {
                $allMods.Add([PSCustomObject]@{
                    Name = $mod.Name
                    FullName = $mod.FullName
                    RelativePath = $mod.Name  # 顶层 mod 直接放在 Mods/
                })
            }
        }
        $alengerDir = Join-Path $SourceModsRoot "Alenger"
        if (Test-Path -LiteralPath $alengerDir) {
            $alengerMods = Get-ChildItem -LiteralPath $alengerDir -Filter "*.SC2Mod" -File -ErrorAction SilentlyContinue
            foreach ($mod in $alengerMods) {
                # 应用 ModFilter
                if ($ModFilter.Count -gt 0) {
                    $matched = $false
                    foreach ($pattern in $ModFilter) {
                        if ($mod.Name -like $pattern) { $matched = $true; break }
                    }
                    if (-not $matched) { continue }
                }
                if ($seenNames.Add($mod.Name)) {
                    # Alenger 子目录的 mod 保持子目录结构：Mods/Alenger/xxx
                    $allMods.Add([PSCustomObject]@{
                        Name = $mod.Name
                        FullName = $mod.FullName
                        RelativePath = "Alenger/" + $mod.Name
                    })
                }
            }
        }

        $modsToInstall = $allMods.ToArray()
        foreach ($mod in $modsToInstall) {
            $destPath = Join-Path $modsLiveRoot $mod.RelativePath
            Write-Host "  - $($mod.RelativePath)"
            Sync-Directory -Source $mod.FullName -Destination $destPath
        }
        Write-Host "  共 $($modsToInstall.Count) 个 mod"

        # ---- 3. 同步地图 ----
        Write-Host ""
        Write-Host "[3/5] 同步地图到 $mapLive ..." -ForegroundColor Cyan
        Sync-Directory -Source $MapSourceDir -Destination $mapLive

        # 应用 Commander 过滤（修改 mapLive 下的 MapScript.galaxy，不动源文件）
        if ($Commander -ne "") {
            Write-Host "  应用 Commander 过滤..." -ForegroundColor Cyan
            Set-CommanderFilter -MapScriptPath (Join-Path $mapLive "MapScript.galaxy") -Commander $Commander
        }

        # ---- 4. 设置依赖 ----
        Write-Host ""
        Write-Host "[4/5] 设置地图依赖..." -ForegroundColor Cyan
        $deps = New-Object System.Collections.Generic.List[string]
        $deps.Add("bnet:虚空之遗 (Mod)/0.0/999,file:Mods/Void.SC2Mod")
        foreach ($mod in $modsToInstall) {
            # 使用 mod 的相对路径作为依赖路径
            # 注意：SC2 依赖路径用反斜杠 \（和 mod 的 DocumentInfo 中一致）
            $depPath = "file:Mods\" + $mod.RelativePath.Replace("/", "\")
            $deps.Add($depPath)
        }
        Write-Host "  依赖 ($($deps.Count) 项):"
        foreach ($d in $deps) { Write-Host "    - $d" }

        Set-DocumentInfoDependencies -Path (Join-Path $mapLive "DocumentInfo") -Dependencies $deps.ToArray()
        Set-DocumentHeaderDependencies -Path (Join-Path $mapLive "DocumentHeader") -Dependencies $deps.ToArray()
        Write-Host "  DocumentInfo + DocumentHeader 已更新" -ForegroundColor Green
    } else {
        Write-Host "[2-4] SkipInstall=true，跳过同步和依赖设置" -ForegroundColor Yellow
    }

    # ---- 5. 启动游戏 ----
    Write-Host ""
    Write-Host "[5/5] 启动游戏..." -ForegroundColor Cyan
    Write-Host "  Map: $mapLive"
    Write-Host "  Switcher: $switcherPath"
    # 用 SC2Switcher 启动（和 launch-7vs1 一样的方式）
    & $switcherPath $mapLive
    Start-Sleep -Seconds 2
    $sc2Proc = Get-Process -Name "SC2_x64" -ErrorAction SilentlyContinue
    if ($sc2Proc) {
        Write-Host "  PID: $($sc2Proc.Id)" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] SC2_x64 进程未启动" -ForegroundColor Yellow
    }

    if ($SkipWait) {
        Write-Host "  SkipWait=true，不等待加载" -ForegroundColor Yellow
        exit 0
    }

    # ---- 6. 等待加载 ----
    Write-Host ""
    Write-Host "=== 等待游戏加载 ===" -ForegroundColor Cyan
    Write-Host "MaxWait:     $MaxWaitSeconds s"
    Write-Host "GracePeriod: $GracePeriodSeconds s"
    Write-Host ""

    $errorKeywords = @(
        "Script compile error",
        "was not found",
        "is not defined",
        "syntax error",
        "Cannot find",
        "Unknown function",
        "Function decl"
    )

    function Get-LatestFile {
        param([string]$Filter)
        return Get-ChildItem -LiteralPath $logsRoot -Filter $Filter -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }

    function Get-FileContent {
        param($FileInfo)
        if (-not $FileInfo) { return "" }
        try { return Get-Content -LiteralPath $FileInfo.FullName -Raw -ErrorAction SilentlyContinue }
        catch { return "" }
    }

    function Test-Sc2Running {
        return $null -ne (Get-Process -Name "SC2_x64" -ErrorAction SilentlyContinue)
    }

    function Test-ContentHasError {
        param([string]$Content)
        if ([string]::IsNullOrWhiteSpace($Content)) { return $false }
        foreach ($kw in $errorKeywords) {
            if ($Content -match [regex]::Escape($kw)) { return $true }
        }
        return $false
    }

    function Show-ScriptError {
        $log = Get-LatestFile -Filter "*ScriptError*"
        if (-not $log) { Write-Host "[无 ScriptError 文件]"; return }
        $content = Get-FileContent -FileInfo $log
        Write-Host ""
        Write-Host "===== ScriptError.txt =====" -ForegroundColor Red
        Write-Host "File: $($log.FullName)"
        Write-Host "Time: $($log.LastWriteTime)"
        Write-Host ""
        Write-Host $content
        Write-Host "============================" -ForegroundColor Red
    }

    $startTime = Get-Date
    $alertsTime = $null
    $baselineErrorTime = $null
    $baselineErrorContent = $null

    while ($true) {
        $elapsed = (Get-Date) - $startTime

        if ($elapsed.TotalSeconds -ge $MaxWaitSeconds) {
            Write-Host ""
            Write-Warning "超时 $MaxWaitSeconds 秒"
            if (Test-Sc2Running) {
                Write-Host "游戏进程存活，但未检测到 Alerts.txt" -ForegroundColor Yellow
                exit 2
            } else {
                Write-Host "游戏进程已退出且超时" -ForegroundColor Red
                Show-ScriptError
                exit 1
            }
        }

        if (-not (Test-Sc2Running)) {
            Write-Host ""
            Write-Host "游戏进程已退出（崩溃）" -ForegroundColor Red
            Show-ScriptError
            exit 1
        }

        $curErrorLog = Get-LatestFile -Filter "*ScriptError*"
        $curErrorTime = if ($curErrorLog) { $curErrorLog.LastWriteTime } else { $null }
        $curErrorContent = Get-FileContent -FileInfo $curErrorLog

        $alertsLog = Get-LatestFile -Filter "*Alerts*"
        if ($alertsLog -and $null -eq $alertsTime) {
            $alertsTime = Get-Date
            Write-Host ""
            Write-Host ">>> 检测到 Alerts.txt: $($alertsLog.FullName)" -ForegroundColor Green
            Write-Host ">>> 开始 $GracePeriodSeconds 秒宽限期..." -ForegroundColor Green
            $baselineErrorTime = $curErrorTime
            $baselineErrorContent = $curErrorContent
            if ($curErrorLog -and (Test-ContentHasError -Content $curErrorContent)) {
                Write-Host ">>> 警告：宽限期开始时已有 ScriptError" -ForegroundColor Yellow
            }
        }

        if ($null -ne $alertsTime) {
            $graceElapsed = ((Get-Date) - $alertsTime).TotalSeconds

            $hasNewError = $false
            if ($curErrorLog) {
                if ($null -eq $baselineErrorTime) {
                    $hasNewError = $true
                } elseif ($curErrorTime -gt $baselineErrorTime) {
                    $hasNewError = $true
                } elseif ($curErrorContent -ne $baselineErrorContent) {
                    $hasNewError = $true
                }
            }

            if ($hasNewError -and (Test-ContentHasError -Content $curErrorContent)) {
                Write-Host ""
                Write-Host ">>> 检测到新的 ScriptError" -ForegroundColor Red
                Show-ScriptError
                exit 1
            }

            if ($graceElapsed -ge $GracePeriodSeconds) {
                Write-Host ""
                Write-Host "=== 加载成功 ===" -ForegroundColor Green
                Write-Host "Alerts.txt:     已出现"
                Write-Host "宽限期:         $GracePeriodSeconds 秒内无新错误"
                Write-Host "总耗时:         $([math]::Round($elapsed.TotalSeconds, 1)) 秒"
                Write-Host "游戏进程:       存活"
                if ($curErrorLog) {
                    Write-Host "ScriptError:    存在但无关键错误"
                } else {
                    Write-Host "ScriptError:    未检测到"
                }
                exit 0
            }

            Write-Progress -Activity "宽限期" -Status "$([math]::Floor($graceElapsed)) / $GracePeriodSeconds s" -PercentComplete ([math]::Floor($graceElapsed / $GracePeriodSeconds * 100))
        } else {
            Write-Progress -Activity "等待加载" -Status "$([math]::Floor($elapsed.TotalSeconds)) / $MaxWaitSeconds s - 等待 Alerts.txt" -PercentComplete ([math]::Floor($elapsed.TotalSeconds / $MaxWaitSeconds * 100))
        }

        Start-Sleep -Milliseconds 1000
    }

} catch {
    Write-Host ""
    Write-Host "=== 异常退出 ===" -ForegroundColor Red
    Write-Host "ERROR at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Command: $($_.InvocationInfo.Line.Trim())" -ForegroundColor Red
    exit 3
}
