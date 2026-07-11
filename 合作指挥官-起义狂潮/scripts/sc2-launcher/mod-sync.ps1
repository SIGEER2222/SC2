<#
.SYNOPSIS
  Mod synchronization module for SC2 commander launchers.
.DESCRIPTION
  Handles syncing mods from workspace source to SC2 live directory.
  Separated from map logic to keep mod and map concerns independent.
#>

function Sync-ModToLive {
    <#
    .SYNOPSIS
      Sync a single mod from workspace to SC2 live directory.
    .PARAMETER ModRelPath
      Relative path under Mods/ (e.g. "7vs1\CoreRuntime.SC2Mod" or "kit_mutations.SC2Mod")
    .PARAMETER ProjRoot
      Workspace root (project source)
    .PARAMETER Sc2Root
      SC2 installation root (live target)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModRelPath,
        [Parameter(Mandatory=$true)]
        [string]$ProjRoot,
        [Parameter(Mandatory=$true)]
        [string]$Sc2Root
    )
    $src = Join-Path $ProjRoot "Mods\$ModRelPath"
    $dst = Join-Path $Sc2Root "Mods\$ModRelPath"
    if (-not (Test-Path $src)) {
        Write-Host "WARN: mod source not found: $src"
        return
    }
    $dstParent = Split-Path $dst -Parent
    if (-not (Test-Path $dstParent)) {
        [System.IO.Directory]::CreateDirectory($dstParent) | Out-Null
    }
    if (Test-Path $src -PathType Container) {
        if (Test-Path $dst) { [System.IO.Directory]::Delete($dst, $true) }
        [System.IO.Directory]::CreateDirectory($dst) | Out-Null
        robocopy $src $dst /MIR /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
    } else {
        [System.IO.File]::Copy($src, $dst, $true)
    }
    Write-Host "SYNC: $ModRelPath"
}

function Sync-ModSet {
    <#
    .SYNOPSIS
      Sync a list of mods from workspace to live.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$ModRelPaths,
        [Parameter(Mandatory=$true)]
        [string]$ProjRoot,
        [Parameter(Mandatory=$true)]
        [string]$Sc2Root
    )
    foreach ($mod in $ModRelPaths) {
        Sync-ModToLive -ModRelPath $mod -ProjRoot $ProjRoot -Sc2Root $Sc2Root
    }
}

function Remove-StaleCommanderUnitsMods {
    <#
    .SYNOPSIS
      Remove unselected CommanderUnits_*.SC2Mod from live directory.
      Called after syncing only the selected commander's mod.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Sc2Root,
        [string[]]$AllowedModNames = @()
    )
    $live7vs1Root = Join-Path $Sc2Root "Mods\7vs1"
    $staleMods = Get-ChildItem $live7vs1Root -Directory -Filter "CommanderUnits_*.SC2Mod" -ErrorAction SilentlyContinue |
        Where-Object { $AllowedModNames -notcontains $_.Name }
    foreach ($stale in $staleMods) {
        [System.IO.Directory]::Delete($stale.FullName, $true)
        Write-Host "CLEAN: removed stale $($stale.Name) from live"
    }
}
