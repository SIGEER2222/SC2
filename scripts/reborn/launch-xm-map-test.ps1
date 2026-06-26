<#
.SYNOPSIS
Launch an XM map with a specific commander by updating CampaignXCore and opening the map directly.

.DESCRIPTION
By default this script restores the live XMFinal dependency table from the
source mod before launch. Real XM maps can hard-initialize commander helper
libraries that do not match the selected commander, so commander-only
dependency filtering is opt-in via -EnableXMFinalCommanderDependencyFilter.

.EXAMPLE
  .\scripts\launch-xm-map.ps1 -Commander Kerrigan -MapPath "E:\SC2\SC2new\StarCraft II\Maps\XM\ttosh03b.SC2Map"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Commander,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$MapPath,

    [string]$BankPath = "",
    [string]$SwitcherPath = "E:\SC2\SC2new\StarCraft II\Support64\SC2Switcher_x64.exe",
    [int]$ProbeSeconds = 0,
    [switch]$SkipXMFinalCommanderDependencyFilter,
    [switch]$EnableXMFinalCommanderDependencyFilter,
    [switch]$IncludeXMFinalMutatorDependencies
)

$ErrorActionPreference = "Stop"

$commanderAliases = @{
    "Nove" = "Nova"
}

$commanderPrivateDependencies = @{
    "Abathur" = "file:Mods\XM\XMAbathur.SC2Mod"
    "AbathurReborn" = "file:Mods\XM\XMAbathurReborn.SC2Mod"
    "Alarak" = "file:Mods\XM\XMAlarak.SC2Mod"
    "Artanis" = "file:Mods\XM\XMArtanis.SC2Mod"
    "Dehaka" = "file:Mods\XM\XMDehaka.SC2Mod"
    "Fenix" = "file:Mods\XM\XMFenix.SC2Mod"
    "Karax" = "file:Mods\XM\XMKarax.SC2Mod"
    "Kerrigan" = "file:Mods\XM\XMKerrigan.SC2Mod"
    "Mengsk" = "file:Mods\XM\XMMengsk.SC2Mod"
    "Mira" = "file:Mods\XM\XMMira.SC2Mod"
    "Nova" = "file:Mods\XM\XMNova.SC2Mod"
    "Probe" = "file:Mods\XM\XMProbe.SC2Mod"
    "Raynor" = "file:Mods\XM\XMRaynor.SC2Mod"
    "SCV" = "file:Mods\XM\XMSCV.SC2Mod"
    "Stetmann" = "file:Mods\XM\XMStetmann.SC2Mod"
    "Stukov" = "file:Mods\XM\XMStukov.SC2Mod"
    "Swann" = "file:Mods\XM\XMSwann.SC2Mod"
    "Tychus" = "file:Mods\XM\XMTychus.SC2Mod"
    "Vorazun" = "file:Mods\XM\XMVorazun.SC2Mod"
    "Zagara" = "file:Mods\XM\XMZagara.SC2Mod"
    "Zeratul" = "file:Mods\XM\XMZeratul.SC2Mod"
}

$xmFinalOptionalMutatorDependencies = @(
    "file:Mods\kit_mutations.SC2Mod",
    "file:Mods\XM\XMMutator.SC2Mod"
)

function Resolve-CommanderName {
    param([string]$Name)

    if ($commanderAliases.ContainsKey($Name)) {
        return $commanderAliases[$Name]
    }

    if ($commanderPrivateDependencies.ContainsKey($Name)) {
        return $Name
    }

    throw "Unknown commander '$Name'. Known commanders: $((@($commanderPrivateDependencies.Keys) + @($commanderAliases.Keys) | Sort-Object) -join ', ')"
}

function Get-WorkspaceRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Get-LiveRootFromMapPath {
    param([string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $marker = "\Maps\"
    $index = $fullPath.IndexOf($marker, [System.StringComparison]::OrdinalIgnoreCase)
    if ($index -lt 0) {
        throw "Could not infer StarCraft II live root from MapPath: $Path"
    }

    return $fullPath.Substring(0, $index)
}

function Get-ActiveDocumentInfoDependencies {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "DocumentInfo not found: $Path"
    }

    $text = Get-Content -LiteralPath $Path -Raw
    $activeText = [regex]::Replace($text, '<!--[\s\S]*?-->', '')
    return @([regex]::Matches($activeText, '<Value>([^<]+)</Value>') | ForEach-Object {
        $_.Groups[1].Value
    })
}

function Set-DocumentInfoDependencies {
    param(
        [string]$Path,
        [string[]]$Dependencies
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('<?xml version="1.0" encoding="utf-8"?>')
    $lines.Add('<DocInfo>')
    $lines.Add('    <Dependencies>')
    foreach ($dependency in $Dependencies) {
        $lines.Add("        <Value>$dependency</Value>")
    }
    $lines.Add('    </Dependencies>')
    $lines.Add('</DocInfo>')

    Set-Content -LiteralPath $Path -Value ($lines -join "`r`n") -NoNewline -Encoding UTF8
}

function Test-ByteSequenceAt {
    param(
        [byte[]]$Bytes,
        [int]$Offset,
        [byte[]]$Needle
    )

    if ($Offset + $Needle.Length -gt $Bytes.Length) {
        return $false
    }

    for ($i = 0; $i -lt $Needle.Length; $i++) {
        if ($Bytes[$Offset + $i] -ne $Needle[$i]) {
            return $false
        }
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
            if (-not (Test-ByteSequenceAt -Bytes $Bytes -Offset $offset -Needle $marker)) {
                continue
            }

            $count = [System.BitConverter]::ToUInt32($Bytes, $offset - 4)
            if (($count -gt 0) -and ($count -lt 128)) {
                return $offset
            }
        }
    }

    throw "DocumentHeader dependency table not found."
}

function Get-DocumentHeaderDependencyEndOffset {
    param(
        [byte[]]$Bytes,
        [int]$Start,
        [uint32]$Count
    )

    $offset = $Start
    for ($index = 0; $index -lt $Count; $index++) {
        while (($offset -lt $Bytes.Length) -and ($Bytes[$offset] -ne 0)) {
            $offset++
        }
        if ($offset -ge $Bytes.Length) {
            throw "DocumentHeader dependency string is not null-terminated."
        }
        $offset++
    }

    return $offset
}

function Get-DocumentHeaderDependencies {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "DocumentHeader not found: $Path"
    }

    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($Path)
    $dependencyStart = Find-DocumentHeaderDependencyStart -Bytes $bytes
    $countOffset = $dependencyStart - 4
    $count = [System.BitConverter]::ToUInt32($bytes, $countOffset)
    $dependencies = New-Object System.Collections.Generic.List[string]
    $offset = $dependencyStart

    for ($index = 0; $index -lt $count; $index++) {
        $start = $offset
        while (($offset -lt $bytes.Length) -and ($bytes[$offset] -ne 0)) {
            $offset++
        }
        if ($offset -ge $bytes.Length) {
            throw "DocumentHeader dependency string is not null-terminated."
        }

        $dependencies.Add([System.Text.Encoding]::UTF8.GetString($bytes, $start, $offset - $start))
        $offset++
    }

    return $dependencies.ToArray()
}

function Set-DocumentHeaderDependencies {
    param(
        [string]$Path,
        [string[]]$Dependencies
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "DocumentHeader not found: $Path"
    }

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

function Get-LiveXMFinalDocumentPaths {
    param([string]$MapFilePath)

    $liveRoot = Get-LiveRootFromMapPath -Path $MapFilePath
    $liveXMFinalRoot = Join-Path $liveRoot "Mods\XM\XMFinal.SC2Mod"
    return [pscustomobject]@{
        Root = $liveXMFinalRoot
        DocumentInfo = Join-Path $liveXMFinalRoot "DocumentInfo"
        DocumentHeader = Join-Path $liveXMFinalRoot "DocumentHeader"
    }
}

function Write-LiveXMFinalDependencyState {
    param(
        [string]$CommanderName,
        [string]$MapFilePath,
        [string]$Label,
        [bool]$AllowOtherCommanderDependencies = $false
    )

    if (-not $commanderPrivateDependencies.ContainsKey($CommanderName)) {
        Write-Host "XMFINAL_LIVE_DEP_${Label}_SKIP=no-private-dependency-mapping"
        return
    }

    $paths = Get-LiveXMFinalDocumentPaths -MapFilePath $MapFilePath
    $selectedDependency = $commanderPrivateDependencies[$CommanderName]
    $allCommanderDependencies = @($commanderPrivateDependencies.Values)
    $infoDependencies = Get-ActiveDocumentInfoDependencies -Path $paths.DocumentInfo
    $headerDependencies = Get-DocumentHeaderDependencies -Path $paths.DocumentHeader
    $infoOtherCommanders = @($infoDependencies | Where-Object { ($_ -in $allCommanderDependencies) -and ($_ -ne $selectedDependency) })
    $headerOtherCommanders = @($headerDependencies | Where-Object { ($_ -in $allCommanderDependencies) -and ($_ -ne $selectedDependency) })
    $infoMissing = -not ($infoDependencies -contains $selectedDependency)
    $headerMissing = -not ($headerDependencies -contains $selectedDependency)
    $infoJoined = $infoDependencies -join ";"
    $headerJoined = $headerDependencies -join ";"

    Write-Host "XMFINAL_LIVE_DEP_${Label}_INFO=count=$($infoDependencies.Count)|has_expected=$(-not $infoMissing)|other_commanders=$($infoOtherCommanders -join ';')|deps=$infoJoined"
    Write-Host "XMFINAL_LIVE_DEP_${Label}_HEADER=count=$($headerDependencies.Count)|has_expected=$(-not $headerMissing)|other_commanders=$($headerOtherCommanders -join ';')|deps=$headerJoined"

    $hasUnexpectedCommanderDependencies = (-not $AllowOtherCommanderDependencies) -and
        (($infoOtherCommanders.Count -gt 0) -or ($headerOtherCommanders.Count -gt 0))

    if (($infoMissing -or $headerMissing) -or $hasUnexpectedCommanderDependencies -or ($infoJoined -ne $headerJoined)) {
        Write-Host "XMFINAL_LIVE_DEP_DRIFT=1|label=$Label|expected=$selectedDependency|root=$($paths.Root)"
    }
}

function Set-LiveXMFinalCommanderDependencies {
    param(
        [string]$CommanderName,
        [string]$MapFilePath,
        [bool]$IncludeMutatorDependencies
    )

    if (-not $commanderPrivateDependencies.ContainsKey($CommanderName)) {
        Write-Warning "No XMFinal commander dependency mapping for '$CommanderName'; leaving live XMFinal dependencies unchanged."
        return
    }

    $workspaceRoot = Get-WorkspaceRoot
    $sourceDocumentInfo = Join-Path $workspaceRoot "合作指挥官版起义狂潮\Mods\XM\XMFinal.SC2Mod\DocumentInfo"
    $livePaths = Get-LiveXMFinalDocumentPaths -MapFilePath $MapFilePath
    $liveDocumentInfo = $livePaths.DocumentInfo
    $liveDocumentHeader = $livePaths.DocumentHeader
    $selectedDependency = $commanderPrivateDependencies[$CommanderName]
    $allCommanderDependencies = @($commanderPrivateDependencies.Values)
    $sourceDependencies = Get-ActiveDocumentInfoDependencies -Path $sourceDocumentInfo
    $filteredDependencies = New-Object System.Collections.Generic.List[string]

    foreach ($dependency in $sourceDependencies) {
        if (($dependency -in $allCommanderDependencies) -and ($dependency -ne $selectedDependency)) {
            continue
        }
        if ((-not $IncludeMutatorDependencies) -and ($dependency -in $xmFinalOptionalMutatorDependencies)) {
            continue
        }
        $filteredDependencies.Add($dependency)
    }

    if ($sourceDependencies -notcontains $selectedDependency) {
        Write-Warning "Selected dependency '$selectedDependency' is not active in source XMFinal DocumentInfo; leaving live XMFinal dependencies unchanged."
        return
    }

    $stamp = "$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')-$([System.Guid]::NewGuid().ToString('N').Substring(0, 8))"
    $backupRoot = Join-Path $workspaceRoot "游戏数据\其他mod数据\live-launch-backups\XMFinal.SC2Mod\$stamp"
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    Copy-Item -LiteralPath $liveDocumentInfo -Destination (Join-Path $backupRoot "DocumentInfo") -Force
    Copy-Item -LiteralPath $liveDocumentHeader -Destination (Join-Path $backupRoot "DocumentHeader") -Force
    Set-DocumentInfoDependencies -Path $liveDocumentInfo -Dependencies $filteredDependencies.ToArray()
    Set-DocumentHeaderDependencies -Path $liveDocumentHeader -Dependencies $filteredDependencies.ToArray()

    $mutatorMode = if ($IncludeMutatorDependencies) { "included" } else { "excluded" }
    Write-Host "XMFinal live dependencies filtered for ${CommanderName}: $($filteredDependencies.Count) (optional mutators $mutatorMode; mutator runtime is catalog-gated)"
    Write-Host "XMFINAL_LIVE_DEP_BACKUP=$backupRoot"
}

function Set-LiveXMFinalSourceDependencies {
    param([string]$MapFilePath)

    $workspaceRoot = Get-WorkspaceRoot
    $sourceDocumentInfo = Join-Path $workspaceRoot "合作指挥官版起义狂潮\Mods\XM\XMFinal.SC2Mod\DocumentInfo"
    $livePaths = Get-LiveXMFinalDocumentPaths -MapFilePath $MapFilePath
    $liveDocumentInfo = $livePaths.DocumentInfo
    $liveDocumentHeader = $livePaths.DocumentHeader
    $sourceDependencies = Get-ActiveDocumentInfoDependencies -Path $sourceDocumentInfo

    if ($sourceDependencies.Count -eq 0) {
        throw "No active dependencies found in source XMFinal DocumentInfo: $sourceDocumentInfo"
    }

    $currentInfoDependencies = Get-ActiveDocumentInfoDependencies -Path $liveDocumentInfo
    $currentHeaderDependencies = Get-DocumentHeaderDependencies -Path $liveDocumentHeader
    if ((($currentInfoDependencies -join "`n") -eq ($sourceDependencies -join "`n")) -and
        (($currentHeaderDependencies -join "`n") -eq ($sourceDependencies -join "`n"))) {
        Write-Host "XMFinal live dependencies restored from source: unchanged ($($sourceDependencies.Count))"
        return
    }

    $stamp = "$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')-$([System.Guid]::NewGuid().ToString('N').Substring(0, 8))"
    $backupRoot = Join-Path $workspaceRoot "游戏数据\其他mod数据\live-launch-backups\XMFinal.SC2Mod\$stamp"
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    Copy-Item -LiteralPath $liveDocumentInfo -Destination (Join-Path $backupRoot "DocumentInfo") -Force
    Copy-Item -LiteralPath $liveDocumentHeader -Destination (Join-Path $backupRoot "DocumentHeader") -Force

    Set-DocumentInfoDependencies -Path $liveDocumentInfo -Dependencies $sourceDependencies
    Set-DocumentHeaderDependencies -Path $liveDocumentHeader -Dependencies $sourceDependencies

    Write-Host "XMFinal live dependencies restored from source: $($sourceDependencies.Count)"
    Write-Host "XMFINAL_LIVE_DEP_BACKUP=$backupRoot"
}

function Get-CampaignXCoreBankPaths {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath)) {
            throw "BankPath not found: $ExplicitPath"
        }
        return @((Resolve-Path -LiteralPath $ExplicitPath).Path)
    }

    $paths = New-Object System.Collections.Generic.List[string]

    $liveBank = Join-Path $env:USERPROFILE "Documents\StarCraft II\Banks\CampaignXCore.SC2Bank"
    if (Test-Path -LiteralPath $liveBank) {
        $paths.Add((Resolve-Path -LiteralPath $liveBank).Path)
    }

    $root = Join-Path $env:USERPROFILE "Documents\StarCraft II\Accounts"
    if (-not (Test-Path -LiteralPath $root)) {
        throw "StarCraft II accounts root not found: $root"
    }

    $candidate = Get-ChildItem -LiteralPath $root -Recurse -File -Filter "CampaignXCore.SC2Bank" |
        Where-Object { $_.FullName -notmatch '\\backup\\' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $candidate) {
        throw "CampaignXCore.SC2Bank not found under $root"
    }

    $accountBank = $candidate.FullName
    if ($paths.Count -eq 0 -or ($paths -notcontains $accountBank)) {
        $paths.Add($accountBank)
    }

    return $paths.ToArray()
}

function Set-BankCommander {
    param(
        [string]$Path,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    [xml]$xml = Get-Content -LiteralPath $Path -Raw

    $bank = $xml.SelectSingleNode("/Bank")
    if (-not $bank) {
        throw "Invalid bank file: missing <Bank> root."
    }

    $section = $xml.SelectSingleNode("/Bank/Section[@name='Ach']")
    if (-not $section) {
        $section = $xml.CreateElement("Section")
        $null = $section.SetAttribute("name", "Ach")
        $null = $bank.AppendChild($section)
    }

    $key = $xml.SelectSingleNode("/Bank/Section[@name='Ach']/Key[@name='Commander']")
    if (-not $key) {
        $key = $xml.CreateElement("Key")
        $null = $key.SetAttribute("name", "Commander")
        $null = $section.AppendChild($key)
    }

    $valueNode = $xml.SelectSingleNode("/Bank/Section[@name='Ach']/Key[@name='Commander']/Value")
    if (-not $valueNode) {
        $valueNode = $xml.CreateElement("Value")
        $null = $valueNode.SetAttribute("string", $Value)
        $null = $key.AppendChild($valueNode)
    }

    $null = $valueNode.RemoveAttribute("int")
    $null = $valueNode.SetAttribute("string", $Value)

    $xml.Save($Path)
}

function Stop-RunningSc2 {
    $processNames = @("SC2_x64", "SC2Switcher_x64", "BlizzardError")

    foreach ($processName in $processNames) {
        $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if (-not $running) {
            continue
        }

        foreach ($proc in $running) {
            try {
                Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            }
            catch {
                Write-Warning "Could not stop $processName (PID $($proc.Id)): $($_.Exception.Message)"
            }
        }
    }

    $deadline = (Get-Date).AddSeconds(12)
    do {
        $remaining = @(Get-Process -Name $processNames -ErrorAction SilentlyContinue)
        if ($remaining.Count -eq 0) {
            return
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)

    Write-Warning "SC2 processes still present after stop wait: $((@($remaining | ForEach-Object { "$($_.ProcessName):$($_.Id)" }) -join ', '))"
}

function Get-Sc2LogParameter {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }

    if ((Get-Item -LiteralPath $Path).Length -eq 0) {
        return ""
    }

    $text = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    $match = [regex]::Match($text, '<Parameters>\s+"([^"]+)"')
    if ($match.Success) {
        return $match.Groups[1].Value
    }

    return ""
}

function Write-Sc2LaunchProbe {
    param(
        [datetime]$StartedAfter,
        [string]$ExpectedMapPath,
        [string]$CommanderName,
        [int]$WaitSeconds,
        [bool]$AllowOtherCommanderDependencies = $false
    )

    if ($WaitSeconds -le 0) {
        return
    }

    Start-Sleep -Seconds $WaitSeconds

    Write-LiveXMFinalDependencyState -CommanderName $CommanderName -MapFilePath $ExpectedMapPath -Label "AFTER_PROBE" -AllowOtherCommanderDependencies $AllowOtherCommanderDependencies

    $expectedFullPath = [System.IO.Path]::GetFullPath($ExpectedMapPath)
    $logRoot = Join-Path $env:USERPROFILE "Documents\StarCraft II\GameLogs"
    Write-Host "SC2_PROBE_SECONDS=$WaitSeconds"

    $processes = @(Get-Process -Name "SC2_x64", "SC2Switcher_x64", "BlizzardError" -ErrorAction SilentlyContinue)
    if ($processes.Count -eq 0) {
        Write-Host "SC2_PROBE_PROCESS=<none>"
    }
    foreach ($proc in $processes) {
        $responding = $null
        $commandLine = ""
        try {
            $responding = $proc.Responding
        }
        catch {
            $responding = ""
        }
        try {
            $cimProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction Stop
            $commandLine = $cimProcess.CommandLine
        }
        catch {
            $commandLine = ""
        }
        Write-Host "SC2_PROBE_PROCESS=$($proc.ProcessName)|pid=$($proc.Id)|responding=$responding|title=$($proc.MainWindowTitle)|cmd=$commandLine"
    }

    if (-not (Test-Path -LiteralPath $logRoot)) {
        Write-Host "SC2_PROBE_LOG_ROOT_MISSING=$logRoot"
        return
    }

    $logs = @(Get-ChildItem -LiteralPath $logRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            ($_.LastWriteTime -ge $StartedAfter) -and
            ($_.Name -match '^(Alerts|.*Graphics|.*SystemInfo|.*Crash.*)\.txt$')
        } |
        Sort-Object LastWriteTime, FullName)

    if ($logs.Count -eq 0) {
        Write-Host "SC2_PROBE_LOG=<none>"
        return
    }

    foreach ($log in $logs) {
        $parameter = Get-Sc2LogParameter -Path $log.FullName
        $parameterMatches = $false
        if (-not [string]::IsNullOrWhiteSpace($parameter)) {
            $parameterMatches = ([System.IO.Path]::GetFullPath($parameter) -ieq $expectedFullPath)
        }
        Write-Host "SC2_PROBE_LOG=$($log.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))|bytes=$($log.Length)|match=$parameterMatches|parameter=$parameter|path=$($log.FullName)"
    }
}

$launchLockName = "Global\XMFinalLiveDependencyLaunchLock"
$launchMutex = New-Object System.Threading.Mutex($false, $launchLockName)
$launchLockAcquired = $false

try {
    Write-Host "XM_LAUNCH_LOCK_WAIT=$launchLockName"
    $launchLockAcquired = $launchMutex.WaitOne([TimeSpan]::FromMinutes(10))
    if (-not $launchLockAcquired) {
        throw "Timed out waiting for launch lock: $launchLockName"
    }
    Write-Host "XM_LAUNCH_LOCK_ACQUIRED=$launchLockName"

    Stop-RunningSc2
    $Commander = Resolve-CommanderName -Name $Commander

    if (-not (Test-Path -LiteralPath $SwitcherPath)) {
        throw "SwitcherPath not found: $SwitcherPath"
    }

    if (-not (Test-Path -LiteralPath $MapPath)) {
        throw "MapPath not found: $MapPath"
    }

    if ($SkipXMFinalCommanderDependencyFilter) {
        Write-Host "XMFinal live dependency management skipped for map: $(Split-Path -Leaf $MapPath)"
    }
    elseif ($EnableXMFinalCommanderDependencyFilter) {
        Set-LiveXMFinalCommanderDependencies -CommanderName $Commander -MapFilePath $MapPath -IncludeMutatorDependencies ([bool]$IncludeXMFinalMutatorDependencies)
        Write-LiveXMFinalDependencyState -CommanderName $Commander -MapFilePath $MapPath -Label "BEFORE_LAUNCH"
    }
    else {
        Set-LiveXMFinalSourceDependencies -MapFilePath $MapPath
        Write-LiveXMFinalDependencyState -CommanderName $Commander -MapFilePath $MapPath -Label "BEFORE_LAUNCH" -AllowOtherCommanderDependencies $true
    }

    foreach ($bankFile in (Get-CampaignXCoreBankPaths -ExplicitPath $BankPath)) {
        Set-BankCommander -Path $bankFile -Value $Commander
    }

    Write-Host "Launching map: $MapPath"
    Write-Host "Commander: $Commander"

    $launchStartedAt = Get-Date
    & $SwitcherPath $MapPath
    Write-Sc2LaunchProbe -StartedAfter $launchStartedAt -ExpectedMapPath $MapPath -CommanderName $Commander -WaitSeconds $ProbeSeconds -AllowOtherCommanderDependencies (-not $EnableXMFinalCommanderDependencyFilter)
}
finally {
    if ($launchLockAcquired) {
        $launchMutex.ReleaseMutex()
        Write-Host "XM_LAUNCH_LOCK_RELEASED=$launchLockName"
    }
    $launchMutex.Dispose()
}
