#Requires -Version 5.1
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Commander,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$MapPath,

    [string]$SourceRebornRoot = "C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\合作指挥官版起义狂潮",
    [string]$SC2Root = "E:\SC2\SC2new\StarCraft II",
    [string]$SwitcherPath = "E:\SC2\SC2new\StarCraft II\Support64\SC2Switcher_x64.exe",
    [int]$WaitSeconds = 45,
    [string]$ScreenshotPath = ""
)

$ErrorActionPreference = "Stop"

# ============================================================
# Helper Functions
# ============================================================

function Write-FileBytesWithRetry {
    param(
        [string]$Path,
        [byte[]]$Bytes,
        [int]$RetryCount = 10,
        [int]$DelayMilliseconds = 500
    )

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            [System.IO.File]::WriteAllBytes($Path, $Bytes)
            return
        }
        catch {
            if ($attempt -ge $RetryCount) {
                throw
            }
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }
}

function Set-FileTextWithRetry {
    param(
        [string]$Path,
        [string]$Text,
        [int]$RetryCount = 10,
        [int]$DelayMilliseconds = 500
    )

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            [System.IO.File]::WriteAllText($Path, $Text, [System.Text.Encoding]::UTF8)
            return
        }
        catch {
            if ($attempt -ge $RetryCount) {
                throw
            }
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }
}

function Wait-PathAvailable {
    param(
        [string]$Path,
        [int]$RetryCount = 20,
        [int]$DelayMilliseconds = 250
    )

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        if (Test-Path -LiteralPath $Path) {
            return
        }
        if ($attempt -lt $RetryCount) {
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }

    throw "Path not found after wait: $Path"
}

function Copy-DirectoryNet {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not [System.IO.Directory]::Exists($Source)) {
        throw "Source directory not found: $Source"
    }

    if (-not [System.IO.Directory]::Exists($Destination)) {
        [System.IO.Directory]::CreateDirectory($Destination) | Out-Null
    }

    foreach ($file in [System.IO.Directory]::GetFiles($Source)) {
        $fileName = [System.IO.Path]::GetFileName($file)
        $destFile = Join-Path $Destination $fileName
        [System.IO.File]::Copy($file, $destFile, $true)
    }

    foreach ($dir in [System.IO.Directory]::GetDirectories($Source)) {
        $dirName = [System.IO.Path]::GetFileName($dir)
        $destDir = Join-Path $Destination $dirName
        Copy-DirectoryNet -Source $dir -Destination $destDir
    }
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

function Get-DocumentInfoDependencies {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Wait-PathAvailable -Path $Path
    }

    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    return @($xml.SelectNodes("/DocInfo/Dependencies/Value") | ForEach-Object { [string]$_.InnerText })
}

function Set-DocumentInfoDependencies {
    param(
        [string]$Path,
        [string[]]$Dependencies
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Wait-PathAvailable -Path $Path
    }

    [xml]$xml = Get-Content -LiteralPath $Path -Raw
    $doc = $xml.SelectSingleNode("/DocInfo")
    if (-not $doc) {
        throw "Invalid DocumentInfo: missing /DocInfo in $Path"
    }

    $old = $xml.SelectSingleNode("/DocInfo/Dependencies")
    if ($old) {
        $null = $doc.RemoveChild($old)
    }

    $dependenciesNode = $xml.CreateElement("Dependencies")
    foreach ($dependency in $Dependencies) {
        $valueNode = $xml.CreateElement("Value")
        $valueNode.InnerText = $dependency
        $null = $dependenciesNode.AppendChild($valueNode)
    }

    $insertBefore = $doc.SelectSingleNode("PatchNote|Preload|HowToPlayBasic|HowToPlayAdvanced")
    if ($insertBefore) {
        $null = $doc.InsertBefore($dependenciesNode, $insertBefore)
    }
    else {
        $null = $doc.AppendChild($dependenciesNode)
    }

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $settings.Indent = $true
    $settings.NewLineChars = "`r`n"
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try {
        $xml.Save($writer)
    }
    finally {
        $writer.Close()
    }
}

function Set-DocumentHeaderDependencies {
    param(
        [string]$Path,
        [string[]]$Dependencies
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Wait-PathAvailable -Path $Path
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

    Write-FileBytesWithRetry -Path $Path -Bytes $stream.ToArray()
}

function Set-PackageDependencies {
    param(
        [string]$PackageRoot,
        [string[]]$Dependencies
    )

    Set-DocumentInfoDependencies -Path (Join-Path $PackageRoot "DocumentInfo") -Dependencies $Dependencies
    Set-DocumentHeaderDependencies -Path (Join-Path $PackageRoot "DocumentHeader") -Dependencies $Dependencies
}

# ============================================================
# Main Workflow
# ============================================================

Write-Host "========================================"
Write-Host "  XM Reborn Commander Launcher"
Write-Host "========================================"
Write-Host ""
Write-Host "Commander: $Commander"
Write-Host "Map: $MapPath"
Write-Host ""

# Step 1: Stop running SC2 processes
Write-Host "[1/6] Stopping running SC2 processes..."
$processNames = @("SC2_x64", "SC2Switcher_x64", "BlizzardError")
foreach ($procName in $processNames) {
    $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($procs) {
        foreach ($p in $procs) {
            try {
                Stop-Process -Id $p.Id -Force -ErrorAction Stop
                Write-Host "  Stopped $procName (PID $($p.Id))"
            }
            catch {
                Write-Warning "  Could not stop $procName (PID $($p.Id)): $($_.Exception.Message)"
            }
        }
    }
}
Start-Sleep -Seconds 2
Write-Host "  Done."
Write-Host ""

# Step 2: Copy all XM mods from reborn source
Write-Host "[2/6] Copying XM mods from reborn source..."
$sourceXmMods = Join-Path $SourceRebornRoot "Mods\XM"
$destXmMods = Join-Path $SC2Root "Mods\XM"

if (-not [System.IO.Directory]::Exists($sourceXmMods)) {
    throw "Source XM mods directory not found: $sourceXmMods"
}

if (-not [System.IO.Directory]::Exists($destXmMods)) {
    [System.IO.Directory]::CreateDirectory($destXmMods) | Out-Null
    Write-Host "  Created directory: $destXmMods"
}

$modDirs = [System.IO.Directory]::GetDirectories($sourceXmMods)
$copied = 0
$skipped = 0

foreach ($modDir in $modDirs) {
    $modName = [System.IO.Path]::GetFileName($modDir)
    $destMod = Join-Path $destXmMods $modName

    if ([System.IO.Directory]::Exists($destMod)) {
        $skipped++
    }
    else {
        Copy-DirectoryNet -Source $modDir -Destination $destMod
        Write-Host "  Copied: $modName"
        $copied++
    }
}

Write-Host "  Done. Copied: $copied, Skipped (exists): $skipped"
Write-Host ""

# Step 3: Set up XMFinal dependencies (from source DocumentInfo, both files consistent)
Write-Host "[3/6] Setting up XMFinal dependencies..."
$sourceFinal = Join-Path $sourceXmMods "XMFinal.SC2Mod"
$liveFinal = Join-Path $destXmMods "XMFinal.SC2Mod"

if (-not [System.IO.Directory]::Exists($liveFinal)) {
    throw "XMFinal.SC2Mod not found in live directory: $liveFinal"
}

# Read dependencies from source DocumentInfo
$sourceDocInfo = Join-Path $sourceFinal "DocumentInfo"
if (-not [System.IO.File]::Exists($sourceDocInfo)) {
    throw "Source XMFinal DocumentInfo not found: $sourceDocInfo"
}

$sourceDependencies = Get-DocumentInfoDependencies -Path $sourceDocInfo
Write-Host "  Source DocumentInfo has $($sourceDependencies.Count) dependencies"

# Apply to live XMFinal (both DocumentInfo and DocumentHeader)
Set-PackageDependencies -PackageRoot $liveFinal -Dependencies $sourceDependencies

# Verify
$liveInfoDeps = Get-DocumentInfoDependencies -Path (Join-Path $liveFinal "DocumentInfo")
$liveHeaderDeps = Get-DocumentHeaderDependencies -Path (Join-Path $liveFinal "DocumentHeader")

Write-Host "  Live DocumentInfo: $($liveInfoDeps.Count) deps"
Write-Host "  Live DocumentHeader: $($liveHeaderDeps.Count) deps"

if ($liveInfoDeps.Count -ne $liveHeaderDeps.Count) {
    Write-Warning "  WARNING: DocumentInfo and DocumentHeader dependency counts differ!"
}

$diffs = Compare-Object $liveInfoDeps $liveHeaderDeps
if ($diffs) {
    Write-Warning "  WARNING: Dependency list mismatch between DocumentInfo and DocumentHeader!"
    $diffs | ForEach-Object { Write-Host "    $($_.SideIndicator): $($_.InputObject)" }
}
else {
    Write-Host "  Dependencies are consistent between DocumentInfo and DocumentHeader"
}
Write-Host ""

# Step 4: Set bank for commander
Write-Host "[4/6] Setting CampaignXCore bank to '$Commander'..."
$bankPaths = @()

$documentsBank = Join-Path $env:USERPROFILE "Documents\StarCraft II\Banks\CampaignXCore.SC2Bank"
if ([System.IO.File]::Exists($documentsBank)) {
    $bankPaths += $documentsBank
}

$accountsRoot = Join-Path $env:USERPROFILE "Documents\StarCraft II\Accounts"
if ([System.IO.Directory]::Exists($accountsRoot)) {
    $accountBanks = Get-ChildItem -LiteralPath $accountsRoot -Recurse -File -Filter "CampaignXCore.SC2Bank" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\backup\\' } |
        Sort-Object LastWriteTime -Descending
    
    foreach ($b in $accountBanks) {
        if ($bankPaths -notcontains $b.FullName) {
            $bankPaths += $b.FullName
        }
    }
}

if ($bankPaths.Count -eq 0) {
    Write-Warning "  No CampaignXCore.SC2Bank found!"
}
else {
    foreach ($bankPath in $bankPaths) {
        try {
            [xml]$xml = Get-Content -LiteralPath $bankPath -Raw
            
            $bank = $xml.SelectSingleNode("/Bank")
            if (-not $bank) {
                Write-Warning "  Invalid bank file (missing <Bank>): $bankPath"
                continue
            }

            $section = $xml.SelectSingleNode("/Bank/Section[@name='Ach']")
            if (-not $section) {
                $section = $xml.CreateElement("Section")
                $null = $section.SetAttribute("name", "Ach")
                $null = $bank.AppendChild($section)
            }

            @("CommanderP1", "PrimaryCommander", "Commander") | ForEach-Object {
                $keyName = $_
                $key = $xml.SelectSingleNode("/Bank/Section[@name='Ach']/Key[@name='$keyName']")
                if (-not $key) {
                    $key = $xml.CreateElement("Key")
                    $null = $key.SetAttribute("name", $keyName)
                    $null = $section.AppendChild($key)
                }

                $valueNode = $key.SelectSingleNode("Value")
                if (-not $valueNode) {
                    $valueNode = $xml.CreateElement("Value")
                    $null = $key.AppendChild($valueNode)
                }

                $null = $valueNode.RemoveAttribute("int")
                $null = $valueNode.SetAttribute("string", $Commander)
            }

            $xml.Save($bankPath)
            Write-Host "  Updated: $bankPath"
        }
        catch {
            Write-Warning "  Failed to update $bankPath : $($_.Exception.Message)"
        }
    }
}
Write-Host ""

# Step 5: Launch the game
Write-Host "[5/6] Launching SC2..."
if (-not (Test-Path -LiteralPath $SwitcherPath)) {
    throw "SC2Switcher not found: $SwitcherPath"
}
if (-not (Test-Path -LiteralPath $MapPath)) {
    throw "Map file not found: $MapPath"
}

$launchStartedAt = Get-Date
& $SwitcherPath $MapPath
Write-Host "  Game launched, waiting $WaitSeconds seconds..."
Write-Host ""

Start-Sleep -Seconds $WaitSeconds

# Step 6: Verify and report
Write-Host "[6/6] Verifying launch result..."
Write-Host ""

$procs = Get-Process -Name "SC2_x64","SC2Switcher_x64" -ErrorAction SilentlyContinue
if ($procs) {
    Write-Host "  SC2 process status:"
    $procs | ForEach-Object {
        $title = if ($_.MainWindowTitle) { $_.MainWindowTitle } else { "(no title)" }
        Write-Host "    $($_.ProcessName) (PID $($_.Id)): $title"
    }
}
else {
    Write-Host "  WARNING: No SC2 process found!"
}
Write-Host ""

# Check for ScriptError
$logDir = Join-Path $env:USERPROFILE "Documents\StarCraft II\GameLogs"
if ([System.IO.Directory]::Exists($logDir)) {
    $errorLogs = Get-ChildItem -LiteralPath $logDir -Filter "*ScriptError*" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $launchStartedAt } |
        Sort-Object LastWriteTime -Descending
    
    if ($errorLogs) {
        Write-Host "  ScriptError logs found (newest first):"
        $errorLogs | ForEach-Object { Write-Host "    $($_.Name) - $($_.LastWriteTime)" }
        Write-Host ""
        Write-Host "  Latest ScriptError content (first 50 lines):"
        $latest = $errorLogs[0]
        $content = Get-Content $latest.FullName -Head 50
        $content | ForEach-Object { Write-Host "    $_" }
    }
    else {
        Write-Host "  No new ScriptError logs since launch."
    }
}
Write-Host ""

# Take screenshot
if ($ScreenshotPath -or $true) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $screen = [System.Windows.Forms.Screen]::PrimaryScreen
        $bounds = $screen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)

        if (-not $ScreenshotPath) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $ScreenshotPath = Join-Path $PSScriptRoot "screenshot-$Commander-$timestamp.png"
        }

        $bitmap.Save($ScreenshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $graphics.Dispose()
        $bitmap.Dispose()
        Write-Host "  Screenshot saved to: $ScreenshotPath"
    }
    catch {
        Write-Warning "  Failed to take screenshot: $($_.Exception.Message)"
    }
}
Write-Host ""

Write-Host "========================================"
Write-Host "  Launch complete!"
Write-Host "========================================"
