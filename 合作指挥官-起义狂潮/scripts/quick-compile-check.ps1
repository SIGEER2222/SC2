<#
.SYNOPSIS
快速编译验证 - 启动游戏仅检测脚本编译错误，不等进入游戏

.DESCRIPTION
比完整进图测试快很多（约20-30秒），专门用于验证脚本是否能编译通过。
如果编译失败，会立即输出 ScriptError 内容并退出游戏。
如果编译通过（30秒内没有错误），也会自动退出游戏。

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\quick-compile-check.ps1

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\quick-compile-check.ps1 -WaitSeconds 40
#>
[CmdletBinding()]
param(
    [string]$SourceRoot = "",
    [string]$MapSource = "",
    [string]$LiveMapName = "QuickCompileTest.SC2Map",
    [string]$Sc2Root = "E:\SC2\SC2new\StarCraft II",
    [string[]]$Commanders = @("TerranRaynor"),
    [int]$WaitSeconds = 30,
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "commander-power-metadata.ps1")
. (Join-Path $PSScriptRoot "sc2\campaignxcore-bank.ps1")

function Get-WorkspaceRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Resolve-DefaultSourceRoot {
    $workspaceRoot = Get-WorkspaceRoot
    $candidates = @(
        (Join-Path $workspaceRoot "游戏数据\其他mod数据\7vs1母巢之战合作指挥官bate版_SC2Replay_94137"),
        "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\游戏数据\其他mod数据\7vs1母巢之战合作指挥官bate版_SC2Replay_94137"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }
    return $workspaceRoot
}

function Resolve-DefaultMapSource {
    $workspaceRoot = Get-WorkspaceRoot
    $localMap = Join-Path $workspaceRoot "Maps\ttosh02_7vs1.SC2Map"
    if (Test-Path -LiteralPath $localMap) {
        return $localMap
    }
    return Join-Path (Resolve-DefaultSourceRoot) "s2ma_packages\pkg02\extract"
}

function Resolve-ExtensionSource {
    param([string]$SourceRoot)
    $workspaceRoot = Get-WorkspaceRoot
    $localExtension = Join-Path $workspaceRoot "Mods\7vs1\CoopZeroPop.SC2Mod"
    if (Test-Path -LiteralPath $localExtension) {
        return $localExtension
    }
    return Join-Path $SourceRoot "s2ma_packages\pkg03\extract"
}

function Resolve-CommanderCatalogSource {
    $workspaceRoot = Get-WorkspaceRoot
    return (Join-Path $workspaceRoot "Mods\7vs1\CommanderCatalog.SC2Mod")
}

function Copy-DirectoryClean {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Source directory not found: $Source"
    }
    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force -ErrorAction Stop
    }
    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

function Get-DocumentInfoDependencies {
    param([Parameter(Mandatory = $true)][string]$Path)
    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    return @($xml.SelectNodes("/DocInfo/Dependencies/Value") | ForEach-Object { [string]$_.InnerText })
}

function Add-DependencyUnique {
    param([string[]]$Dependencies, [string]$Dependency)
    if ($Dependencies -contains $Dependency) {
        return $Dependencies
    }
    return @($Dependencies + $Dependency)
}

function Normalize-MapRuntimeDependencies {
    param([string[]]$Dependencies)
    $libertyStory = "bnet:自由之翼剧情 (战役)/0.0/999,file:Campaigns/LibertyStory.SC2Campaign"
    $libertyMod = "bnet:自由之翼 (Mod)/0.0/999,file:Mods/Liberty.SC2Mod"
    $normalized = @($libertyStory, $libertyMod)
    foreach ($dependency in $Dependencies) {
        $target = $dependency.Split(',')[-1]
        if (($target -eq "file:Campaigns/LibertyStory.SC2Campaign") -or
            ($target -eq "file:Mods/Liberty.SC2Mod")) {
            continue
        }
        if ($dependency -like "file:*") {
            $dependency = $dependency -replace '\\', '/'
        }
        $normalized = Add-DependencyUnique -Dependencies $normalized -Dependency $dependency
    }
    return $normalized
}

function Test-WorkspaceModDependency {
    param([string]$Dependency)
    if (-not ($Dependency -like 'file:Mods/*')) {
        return $false
    }
    $normalized = $Dependency.Replace('\', '/').ToLowerInvariant()
    return ($normalized -like 'file:mods/7vs1/*.sc2mod') -or
           ($normalized -eq 'file:mods/kit_mutations.sc2mod') -or
           ($normalized -eq 'file:mods/starcoop/starcoop.sc2mod') -or
           ($normalized -like 'file:mods/starcoop/commanders/*.sc2mod')
}

function Convert-DependencyToRelativePath {
    param([string]$Dependency)
    if (-not (Test-WorkspaceModDependency -Dependency $Dependency)) {
        throw "Unsupported local dependency path: $Dependency"
    }
    return $Dependency.Substring(5).Replace('/', '\')
}

function Resolve-WorkspaceDependencySource {
    param([string]$Dependency, [string]$WorkspaceRoot)
    $relativePath = Convert-DependencyToRelativePath -Dependency $Dependency
    $sourcePath = Join-Path $WorkspaceRoot $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Workspace dependency source not found for ${Dependency}: $sourcePath"
    }
    return $sourcePath
}

function Resolve-LiveDependencyDestination {
    param([string]$Dependency, [string]$Sc2Root)
    return (Join-Path $Sc2Root (Convert-DependencyToRelativePath -Dependency $Dependency))
}

function Resolve-WorkspaceModDependencyClosure {
    param([string[]]$Dependencies, [string]$WorkspaceRoot)
    $queue = New-Object 'System.Collections.Generic.Queue[string]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $closure = New-Object 'System.Collections.Generic.List[string]'
    foreach ($dependency in $Dependencies) {
        if (Test-WorkspaceModDependency -Dependency $dependency) {
            $queue.Enqueue($dependency)
        }
    }
    while ($queue.Count -gt 0) {
        $dependency = $queue.Dequeue()
        if (-not $seen.Add($dependency)) {
            continue
        }
        $null = $closure.Add($dependency)
        $sourceRoot = Resolve-WorkspaceDependencySource -Dependency $dependency -WorkspaceRoot $WorkspaceRoot
        $documentInfoPath = Join-Path $sourceRoot 'DocumentInfo'
        if (-not (Test-Path -LiteralPath $documentInfoPath)) {
            continue
        }
        foreach ($childDependency in (Get-DocumentInfoDependencies -Path $documentInfoPath)) {
            if (Test-WorkspaceModDependency -Dependency $childDependency) {
                $queue.Enqueue($childDependency)
            }
        }
    }
    return $closure.ToArray()
}

function Install-WorkspaceModDependencyClosure {
    param(
        [string[]]$Dependencies,
        [string]$WorkspaceRoot,
        [string]$Sc2Root,
        [string[]]$SkipDependencies = @()
    )
    $skipSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($d in $SkipDependencies) {
        if (-not [string]::IsNullOrWhiteSpace($d)) {
            $null = $skipSet.Add($d)
        }
    }
    $installed = New-Object 'System.Collections.Generic.List[string]'
    foreach ($dependency in (Resolve-WorkspaceModDependencyClosure -Dependencies $Dependencies -WorkspaceRoot $WorkspaceRoot)) {
        if ($skipSet.Contains($dependency)) {
            continue
        }
        $sourceRoot = Resolve-WorkspaceDependencySource -Dependency $dependency -WorkspaceRoot $WorkspaceRoot
        $liveRoot = Resolve-LiveDependencyDestination -Dependency $dependency -Sc2Root $Sc2Root
        Copy-DirectoryClean -Source $sourceRoot -Destination $liveRoot
        $null = $installed.Add($dependency)
    }
    return $installed.ToArray()
}

function Sync-LiveMapRuntimeLibraries {
    param([string]$MapLive, [string[]]$RuntimeBaseRoots)
    $mapBaseDataRoot = Join-Path $MapLive "Base.SC2Data"
    if (-not (Test-Path -LiteralPath $mapBaseDataRoot)) {
        New-Item -ItemType Directory -Path $mapBaseDataRoot -Force | Out-Null
    }
    Get-ChildItem -LiteralPath $mapBaseDataRoot -Filter 'Lib*.galaxy' -File -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
    foreach ($runtimeBaseRoot in $RuntimeBaseRoots) {
        if (-not (Test-Path -LiteralPath $runtimeBaseRoot)) {
            continue
        }
        Get-ChildItem -LiteralPath $runtimeBaseRoot -Filter 'Lib*.galaxy' -File -ErrorAction SilentlyContinue |
            ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $mapBaseDataRoot $_.Name) -Force
            }
    }
}

function Set-DocumentInfoDependencies {
    param([string]$Path, [string[]]$Dependencies)
    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    $doc = $xml.SelectSingleNode("/DocInfo")
    if (-not $doc) { throw "Invalid DocumentInfo: missing /DocInfo in $Path" }
    $old = $xml.SelectSingleNode("/DocInfo/Dependencies")
    if ($old) { $null = $doc.RemoveChild($old) }
    $dependenciesNode = $xml.CreateElement("Dependencies")
    foreach ($dependency in $Dependencies) {
        $valueNode = $xml.CreateElement("Value")
        $valueNode.InnerText = $dependency
        $null = $dependenciesNode.AppendChild($valueNode)
    }
    $insertBefore = $doc.SelectSingleNode("PatchNote|Preload|HowToPlayBasic|HowToPlayAdvanced")
    if ($insertBefore) {
        $null = $doc.InsertBefore($dependenciesNode, $insertBefore)
    } else {
        $null = $doc.AppendChild($dependenciesNode)
    }
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $settings.Indent = $true
    $settings.NewLineChars = "`r`n"
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try { $xml.Save($writer) } finally { $writer.Close() }
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
    for ($index = 0; $index -lt $Count; $index++) {
        while (($offset -lt $Bytes.Length) -and ($Bytes[$offset] -ne 0)) { $offset++ }
        if ($offset -ge $Bytes.Length) { throw "DocumentHeader dependency string is not null-terminated." }
        $offset++
    }
    return $offset
}

function Set-DocumentHeaderDependencies {
    param([string]$Path, [string[]]$Dependencies)
    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($Path)
    $dependencyStart = Find-DocumentHeaderDependencyStart -Bytes $bytes
    $countOffset = $dependencyStart - 4
    $currentCount = [System.BitConverter]::ToUInt32($bytes, $countOffset)
    $dependencyEnd = Get-DocumentHeaderDependencyEndOffset -Bytes $bytes -Start $dependencyStart -Count $currentCount
    $dependencyBytes = [System.Text.Encoding]::UTF8.GetBytes((($Dependencies -join "`0") + "`0"))
    $countBytes = [System.BitConverter]::GetBytes([uint32]$Dependencies.Count)
    $stream = New-Object System.IO.MemoryStream
    $stream.Write($bytes, 0, $countOffset)
    $stream.Write($countBytes, 0, $countBytes.Length)
    $stream.Write($dependencyBytes, 0, $dependencyBytes.Length)
    $stream.Write($bytes, $dependencyEnd, $bytes.Length - $dependencyEnd)
    [System.IO.File]::WriteAllBytes($Path, $stream.ToArray())
}

function Set-PackageDependencies {
    param([string]$PackageRoot, [string[]]$Dependencies)
    Set-DocumentInfoDependencies -Path (Join-Path $PackageRoot "DocumentInfo") -Dependencies $Dependencies
    Set-DocumentHeaderDependencies -Path (Join-Path $PackageRoot "DocumentHeader") -Dependencies $Dependencies
}

function Stop-RunningSc2 {
    $processNames = @("SC2_x64", "SC2Switcher_x64", "BlizzardError")
    foreach ($processName in $processNames) {
        $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if (-not $running) { continue }
        foreach ($proc in $running) {
            try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop }
            catch { Write-Warning "Could not stop $processName (PID $($proc.Id)): $($_.Exception.Message)" }
        }
    }
    Start-Sleep -Seconds 2
}

function Clear-Sc2GameLogs {
    $logsRoot = "C:\Users\22448\Documents\StarCraft II\GameLogs"
    if (-not (Test-Path -LiteralPath $logsRoot)) { return }
    Get-ChildItem -LiteralPath $logsRoot -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop }
        catch { Write-Warning "Could not remove SC2 log entry '$($_.FullName)': $($_.Exception.Message)" }
    }
}

function Get-LatestScriptError {
    $logsRoot = "C:\Users\22448\Documents\StarCraft II\GameLogs"
    if (-not (Test-Path -LiteralPath $logsRoot)) { return $null }
    $latest = Get-ChildItem -LiteralPath $logsRoot -Filter "*ScriptError*.txt" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($latest) { return $latest.FullName }
    return $null
}

$SwitcherPath = Join-Path $Sc2Root "Support64\SC2Switcher_x64.exe"

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Resolve-DefaultSourceRoot
}
if ([string]::IsNullOrWhiteSpace($MapSource)) {
    $MapSource = Resolve-DefaultMapSource
} else {
    if (-not [System.IO.Path]::IsPathRooted($MapSource)) {
        $MapSource = Join-Path (Get-WorkspaceRoot) $MapSource
    }
}

$extensionSource = Resolve-ExtensionSource -SourceRoot $SourceRoot
$commanderCatalogSource = Resolve-CommanderCatalogSource
$mapLive = Join-Path (Join-Path $Sc2Root "Maps\7vs1") $LiveMapName
$extensionLive = Join-Path $Sc2Root "Mods\7vs1\CoopZeroPop.SC2Mod"

if (-not (Test-Path -LiteralPath $SwitcherPath)) { throw "SwitcherPath not found: $SwitcherPath" }
if (-not (Test-Path -LiteralPath $commanderCatalogSource)) { throw "CommanderCatalog source not found: $commanderCatalogSource" }

Write-Host "=" * 70
Write-Host "快速编译验证"
Write-Host "=" * 70
Write-Host "等待时间: $WaitSeconds 秒"
Write-Host ""

Write-Host "步骤 1/4: 清理日志和旧进程..."
Stop-RunningSc2
Clear-Sc2GameLogs

Write-Host "步骤 2/4: 安装地图和Mod到游戏目录..."
Copy-DirectoryClean -Source $MapSource -Destination $mapLive
Copy-DirectoryClean -Source $extensionSource -Destination $extensionLive

$extensionDependencies = @(
    "bnet:Void Multi (Mod)/0.0/999,file:Mods/VoidMulti.SC2Mod",
    "bnet:Co-op Mission/0.0/999,file:Mods/StarCoop/StarCoop.SC2Mod"
)
$mapDependencies = @(Get-DocumentInfoDependencies -Path (Join-Path $mapLive "DocumentInfo"))
$mapDependencies = Normalize-MapRuntimeDependencies -Dependencies $mapDependencies
$mapDependencies = Add-DependencyUnique -Dependencies $mapDependencies -Dependency "file:Mods/7vs1/CoopZeroPop.SC2Mod"
$mapDependencies = Add-DependencyUnique -Dependencies $mapDependencies -Dependency "file:Mods/7vs1/CommanderCatalog.SC2Mod"

$workspaceDependencySkips = @("file:Mods/7vs1/CoopZeroPop.SC2Mod")
$installed = Install-WorkspaceModDependencyClosure `
    -Dependencies $mapDependencies `
    -WorkspaceRoot (Get-WorkspaceRoot) `
    -Sc2Root $Sc2Root `
    -SkipDependencies $workspaceDependencySkips

$extensionBaseData = Join-Path $extensionLive "Base.SC2Data"
$kitMutationsLive = Join-Path (Resolve-LiveDependencyDestination -Dependency "file:Mods/kit_mutations.SC2Mod" -Sc2Root $Sc2Root) "Base.SC2Data"
Sync-LiveMapRuntimeLibraries -MapLive $mapLive -RuntimeBaseRoots @($extensionBaseData, $kitMutationsLive)

Set-PackageDependencies -PackageRoot $extensionLive -Dependencies $extensionDependencies
Set-PackageDependencies -PackageRoot $mapLive -Dependencies $mapDependencies

Set-CampaignXCoreCommanderPowerPreset `
    -SelectedCommanders $Commanders `
    -Profile "Default" `
    -EnablePrestiges 0 `
    -EnableMasteries 0 `
    -MasteryLevel 0

Write-Host "步骤 3/4: 启动游戏（等待 $WaitSeconds 秒检测编译错误）..."
Write-Host ""

if ($NoLaunch) {
    Write-Host "NoLaunch 模式，跳过启动。地图已安装到: $mapLive"
    exit 0
}

$proc = Start-Process -FilePath $SwitcherPath -ArgumentList "`"$mapLive`"" -PassThru

$scriptErrorFound = $false
$errorPath = $null
$startTime = Get-Date

for ($i = 0; $i -lt $WaitSeconds; $i++) {
    Start-Sleep -Seconds 1
    
    $errorPath = Get-LatestScriptError
    if ($errorPath) {
        $scriptErrorFound = $true
        Write-Host ""
        Write-Host "检测到 ScriptError！（启动后 $($i + 1) 秒）"
        Write-Host ""
        break
    }
    
    $elapsed = (Get-Date) - $startTime
    Write-Progress -Activity "等待编译结果..." -Status "已等待 $($elapsed.Seconds) / $WaitSeconds 秒" -PercentComplete ([math]::Min(100, ($elapsed.Seconds / $WaitSeconds) * 100))
}

Write-Progress -Activity "等待编译结果..." -Completed

Write-Host "步骤 4/4: 关闭游戏..."
Stop-RunningSc2

Write-Host ""
Write-Host "=" * 70
if ($scriptErrorFound) {
    Write-Host "结果: 编译失败" -ForegroundColor Red
    Write-Host "=" * 70
    Write-Host ""
    Write-Host "错误文件: $errorPath"
    Write-Host ""
    Write-Host "----- 错误内容 -----"
    Get-Content -LiteralPath $errorPath -Encoding UTF8
    Write-Host "-------------------"
    exit 1
} else {
    Write-Host "结果: 编译通过（$WaitSeconds 秒内未检测到 ScriptError）" -ForegroundColor Green
    Write-Host "=" * 70
    Write-Host ""
    Write-Host "注意：编译通过不代表运行时没有问题，"
    Write-Host "      只是说明脚本语法和依赖没有错误。"
    exit 0
}
