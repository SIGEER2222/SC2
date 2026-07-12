<#
.SYNOPSIS
  读取并分析 StarCraft II GameLogs 中的 ScriptError.txt 文件。
.DESCRIPTION
  扫描 GameLogs 目录，找到最新的 ScriptError.txt，解析其中的错误内容并分类：
  - 致命错误 (Fatal)：编译错误、未定义函数、语法错误等，会导致脚本无法加载
  - 触发器错误 (TriggerError)：运行时触发器执行错误，通常是无效参数或缺失对象
  - 警告 (Warning)：非致命的运行时警告

  支持指定具体文件路径或自动查找最新文件。
.PARAMETER GameLogsPath
  GameLogs 目录路径，默认为当前用户的 Documents\StarCraft II\GameLogs
.PARAMETER File
  指定具体的 ScriptError.txt 文件路径。若提供则只分析该文件，不扫描目录。
.PARAMETER All
  列出所有 ScriptError 文件而非只分析最新的。
.EXAMPLE
  .\read-script-error.ps1
  分析最新的 ScriptError.txt
.EXAMPLE
  .\read-script-error.ps1 -File "C:\Users\22448\Documents\StarCraft II\GameLogs\2026-07-11 17.46.23 ScriptError.txt"
  分析指定文件
.EXAMPLE
  .\read-script-error.ps1 -All
  列出所有 ScriptError 文件及其摘要
#>
[CmdletBinding()]
param(
    [string]$GameLogsPath = "C:\Users\22448\Documents\StarCraft II\GameLogs",
    [string]$File,
    [switch]$All
)

$ErrorActionPreference = "Stop"

# === 错误分类关键字 ===
# 致命错误：编译期错误，会导致脚本完全无法加载
$FatalKeywords = @(
    "Script compile error",
    "was not found",
    "is not defined",
    "syntax error",
    "Cannot find",
    "Unknown function",
    "参数类型同函数定义不匹配",
    "脚本读取失败",
    "函数已声明但尚未定义",
    "无法找到Include文件",
    "解析函数行出错",
    "Galaxy数组的定义需要在类型后添加维度"
)

# 触发器错误：运行时触发器执行错误，不会阻止脚本加载但会导致功能异常
$TriggerErrorKeywords = @(
    "出现触发器错误",
    "无法从",
    "参数中获取",
    "无权调用"
)

# === 辅助函数 ===

function Get-ScriptErrorFiles {
    param([string]$Path)
    return Get-ChildItem -LiteralPath $Path -Filter "*ScriptError*" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
}

function Get-LatestScriptErrorFile {
    param([string]$Path)
    $files = Get-ScriptErrorFiles -Path $Path
    return $files | Select-Object -First 1
}

function Read-ScriptErrorContent {
    param([string]$FilePath)
    if (-not (Test-Path -LiteralPath $FilePath)) { return "" }
    try {
        # SC2 生成的 ScriptError.txt 是 UTF-8 编码
        # PS5.1 默认用系统代码页(GBK)读取，必须显式指定 UTF-8
        return [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)
    } catch {
        return ""
    }
}

# 解析 ScriptError 内容，提取错误条目
# ScriptError.txt 格式：
#   - 文件头：===== 分隔的元信息（Executable, LocalTime, Version 等）
#   - 错误行：单行错误描述
#   - 位置行：以 "   Near line XXX in funcName() in file.galaxy" 格式标注位置
function Parse-ScriptErrorContent {
    param([string]$Content)

    $result = [PSCustomObject]@{
        Header      = @()
        FatalErrors = @()
        TriggerErrors = @()
        Warnings    = @()
        Unknowns    = @()
    }

    if ([string]::IsNullOrWhiteSpace($Content)) { return $result }

    $lines = $Content -split "`r?`n"
    $inHeader = $true
    $currentError = $null

    foreach ($line in $lines) {
        # 跳过空行
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        # 跳过分隔线
        if ($line -match '^=+$') { continue }

        # 文件头部分：从 "====" 分隔线之后到第一个错误行之前
        if ($inHeader) {
            if ($line -match '^\s*<') {
                $result.Header += $line
                continue
            }
            if ($line -match '^(Executable|Parent|Grandparent|LocalTime|ComputerUser|ComputerName|Exe\.|Version|DataBuild|CodeBranch|CodeRevision|Locale\.|AccountCountry|AgentVersion|StarCraft II)') {
                $result.Header += $line
                continue
            }
            $inHeader = $false
        }

        # 位置行：以 "   Near line" 开头
        if ($line -match '^\s+Near line (\d+) in (\w+)\(\) in (.+)$') {
            if ($currentError) {
                $currentError | Add-Member -NotePropertyName Line -NotePropertyValue $Matches[1] -Force
                $currentError | Add-Member -NotePropertyName Function -NotePropertyValue $Matches[2] -Force
                $currentError | Add-Member -NotePropertyName Source -NotePropertyValue $Matches[3] -Force
            }
            continue
        }

        # 位置行变体：包含文件名但不完全匹配上述格式
        if ($line -match '^\s+Near line (\d+) in (.+)$') {
            if ($currentError) {
                $currentError | Add-Member -NotePropertyName Line -NotePropertyValue $Matches[1] -Force
                $currentError | Add-Member -NotePropertyName Source -NotePropertyValue $Matches[2] -Force
            }
            continue
        }

        # 错误分类
        $matchedCategory = $null
        $message = $line.Trim()

        # 附属行：Script compile error 的附加信息行
        # "脚本代码：..." 和 "         脚本代码：..." 是 Fatal 错误的附属行
        if ($message -match '^脚本代码：' -or $message -match '^\s+脚本代码：') {
            if ($currentError -and $currentError.Category -eq "Fatal") {
                $currentError | Add-Member -NotePropertyName Detail -NotePropertyValue $message -Force
            }
            continue
        }

        # 检查是否是致命错误
        foreach ($kw in $FatalKeywords) {
            if ($message -match [regex]::Escape($kw)) {
                $matchedCategory = "Fatal"
                break
            }
        }

        # 检查是否是触发器错误
        if (-not $matchedCategory) {
            foreach ($kw in $TriggerErrorKeywords) {
                if ($message -match [regex]::Escape($kw)) {
                    $matchedCategory = "TriggerError"
                    break
                }
            }
        }

        # 未匹配任何分类，归为 Unknown
        if (-not $matchedCategory) {
            $matchedCategory = "Unknown"
        }

        # "本局游戏中该错误的最终报告" 是结束标记
        if ($message -match '本局游戏中该错误的最终报告') {
            $currentError = $null
            continue
        }

        $currentError = [PSCustomObject]@{
            Message   = $message
            Category  = $matchedCategory
            Line      = $null
            Function  = $null
            Source    = $null
        }

        switch ($matchedCategory) {
            "Fatal"         { $result.FatalErrors += $currentError }
            "TriggerError"  { $result.TriggerErrors += $currentError }
            "Unknown"       { $result.Unknowns += $currentError }
        }
    }

    return $result
}

function Format-ErrorEntry {
    param($Entry)
    $output = "  [$($Entry.Category)] $($Entry.Message)"
    if ($Entry.Line) { $output += " (line $($Entry.Line)" }
    if ($Entry.Function) { $output += " in $($Entry.Function)()" }
    if ($Entry.Source) { $output += " @ $($Entry.Source)" }
    if ($Entry.Line -or $Entry.Function -or $Entry.Source) { $output += ")" }
    if ($Entry.Detail) { $output += "`n      $($Entry.Detail)" }
    return $output
}

function Write-ScriptErrorAnalysis {
    param(
        [string]$FilePath,
        [string]$Content
    )

    $fileInfo = Get-Item -LiteralPath $FilePath
    $parsed = Parse-ScriptErrorContent -Content $Content

    # 提取 LocalTime
    $localTime = ""
    foreach ($h in $parsed.Header) {
        if ($h -match 'LocalTime\s+(.+)') { $localTime = $Matches[1].Trim(); break }
    }

    # 提取 Parameters（地图路径）
    $mapPath = ""
    foreach ($h in $parsed.Header) {
        if ($h -match '<Parameters>\s+"([^"]+)"') { $mapPath = $Matches[1]; break }
    }

    Write-Host ""
    Write-Host "===== ScriptError Analysis ====="
    Write-Host "File:      $FilePath"
    Write-Host "Time:      $($fileInfo.LastWriteTime)"
    if ($localTime) { Write-Host "LocalTime: $localTime" }
    if ($mapPath) { Write-Host "Map:       $mapPath" }
    Write-Host ""

    $totalCount = $parsed.FatalErrors.Count + $parsed.TriggerErrors.Count + $parsed.Unknowns.Count

    if ($totalCount -eq 0) {
        Write-Host "No errors found in ScriptError file."
        Write-Host "================================"
        return
    }

    Write-Host "Summary:"
    Write-Host "  Fatal Errors:     $($parsed.FatalErrors.Count)"
    Write-Host "  Trigger Errors:   $($parsed.TriggerErrors.Count)"
    Write-Host "  Unknown:          $($parsed.Unknowns.Count)"
    Write-Host "  Total:            $totalCount"
    Write-Host ""

    if ($parsed.FatalErrors.Count -gt 0) {
        Write-Host "--- Fatal Errors (编译期错误，脚本无法加载) ---"
        foreach ($e in $parsed.FatalErrors) {
            Write-Host (Format-ErrorEntry -Entry $e)
        }
        Write-Host ""
    }

    if ($parsed.TriggerErrors.Count -gt 0) {
        Write-Host "--- Trigger Errors (运行时触发器错误) ---"
        # 去重显示（同一错误可能重复多次）
        $seen = @{}
        foreach ($e in $parsed.TriggerErrors) {
            $key = "$($e.Message)|$($e.Line)|$($e.Function)|$($e.Source)"
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                Write-Host (Format-ErrorEntry -Entry $e)
            }
        }
        Write-Host ""
    }

    if ($parsed.Unknowns.Count -gt 0) {
        Write-Host "--- Unknown Lines ---"
        foreach ($e in $parsed.Unknowns) {
            Write-Host (Format-ErrorEntry -Entry $e)
        }
        Write-Host ""
    }

    Write-Host "================================"
}

# === 主逻辑 ===

if ($File) {
    # 分析指定文件
    if (-not (Test-Path -LiteralPath $File)) {
        Write-Error "File not found: $File"
        exit 1
    }
    $content = Read-ScriptErrorContent -FilePath $File
    Write-ScriptErrorAnalysis -FilePath $File -Content $content
}
elseif ($All) {
    # 列出所有 ScriptError 文件
    $files = Get-ScriptErrorFiles -Path $GameLogsPath
    if ($files.Count -eq 0) {
        Write-Host "No ScriptError files found in: $GameLogsPath"
        exit 0
    }
    Write-Host "=== All ScriptError Files ==="
    Write-Host "Total: $($files.Count) files"
    Write-Host ""
    foreach ($f in $files) {
        $content = Read-ScriptErrorContent -FilePath $f.FullName
        $parsed = Parse-ScriptErrorContent -Content $content
        $total = $parsed.FatalErrors.Count + $parsed.TriggerErrors.Count + $parsed.Unknowns.Count
        Write-Host ("[{0}] {1}" -f $f.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss"), $f.Name)
        Write-Host "  Fatal: $($parsed.FatalErrors.Count)  Trigger: $($parsed.TriggerErrors.Count)  Total: $total"
    }
}
else {
    # 分析最新文件
    $latest = Get-LatestScriptErrorFile -Path $GameLogsPath
    if (-not $latest) {
        Write-Host "No ScriptError file found in: $GameLogsPath"
        Write-Host "Game may not have generated any errors, or GameLogs path is incorrect."
        exit 0
    }
    $content = Read-ScriptErrorContent -FilePath $latest.FullName
    Write-ScriptErrorAnalysis -FilePath $latest.FullName -Content $content
}
