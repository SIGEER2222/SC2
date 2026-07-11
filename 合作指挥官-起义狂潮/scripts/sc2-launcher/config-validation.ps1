<#
.SYNOPSIS
  Configuration validation module for SC2 commander launchers.
.DESCRIPTION
  Validates launcher JSON configs against schema and semantic rules:
  - JSON parseable
  - schemaVersion supported
  - commander id / mod suffix uniqueness
  - dependency path non-empty
  - workspace / live path resolvable
  - galaxy inject rule matches >= 1 file
  - unknown commander fails
  - duplicate dependency fails

  Returns a result object with .Valid (bool), .Errors (string[]), .Warnings (string[]).
  Callers should check $result.Valid before proceeding with map/mod sync.
#>

function Test-LauncherConfig {
    <#
    .SYNOPSIS
      Validate all launcher configs for a given commander + map family.
    .PARAMETER Commander
      Selected commander id (e.g. TerranRaynor). Empty to skip commander check.
    .PARAMETER MapFamily
      Map family name (e.g. reborn). Empty to skip family check.
    .PARAMETER ProjRoot
      Workspace root for path resolution.
    .PARAMETER Configs
      Optional hashtable of pre-loaded configs. If omitted, configs are loaded from Shared/Launcher/.
    #>
    param(
        [string]$Commander = "",
        [string]$MapFamily = "reborn",
        [Parameter(Mandatory=$true)]
        [string]$ProjRoot,
        [hashtable]$Configs = @{}
    )

    $result = [PSCustomObject]@{
        Valid    = $true
        Errors   = @()
        Warnings = @()
    }

    function Add-Error { param([string]$Msg) $result.Valid = $false; $result.Errors += $Msg }
    function Add-Warning { param([string]$Msg) $result.Warnings += $Msg }

    $sharedRoot = Join-Path $ProjRoot "Shared\Launcher"

    # --- Load configs if not provided ---
    if (-not $Configs.ContainsKey("commander-units-mapping")) {
        $path = Join-Path $sharedRoot "commander-units-mapping.json"
        if (-not (Test-Path -LiteralPath $path)) {
            Add-Error "commander-units-mapping.json not found at: $path"
            return $result
        }
        try {
            $Configs["commander-units-mapping"] = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            Add-Error "commander-units-mapping.json is not valid JSON: $($_.Exception.Message)"
            return $result
        }
    }

    if (-not $Configs.ContainsKey("alenger-mods")) {
        $path = Join-Path $sharedRoot "alenger-mods.json"
        if (-not (Test-Path -LiteralPath $path)) {
            Add-Error "alenger-mods.json not found at: $path"
            return $result
        }
        try {
            $Configs["alenger-mods"] = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            Add-Error "alenger-mods.json is not valid JSON: $($_.Exception.Message)"
            return $result
        }
    }

    if (-not $Configs.ContainsKey("reborn-dependencies")) {
        $path = Join-Path $sharedRoot "reborn-dependencies.json"
        if (-not (Test-Path -LiteralPath $path)) {
            Add-Error "reborn-dependencies.json not found at: $path"
            return $result
        }
        try {
            $Configs["reborn-dependencies"] = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            Add-Error "reborn-dependencies.json is not valid JSON: $($_.Exception.Message)"
            return $result
        }
    }

    # --- Validate commander-units-mapping ---
    $cmdMap = $Configs["commander-units-mapping"]
    if (-not $cmdMap.mappings) {
        Add-Error "commander-units-mapping.json missing required field: mappings"
    } else {
        # schemaVersion check (if present, must be 1)
        if ($cmdMap.PSObject.Properties.Name -contains "schemaVersion" -and $cmdMap.schemaVersion -ne 1) {
            Add-Error "commander-units-mapping.schemaVersion unsupported: $($cmdMap.schemaVersion) (expected 1)"
        }
        # mod suffix uniqueness
        $suffixes = @()
        foreach ($prop in $cmdMap.mappings.PSObject.Properties) {
            $suffixes += $prop.Value
        }
        $dupSuffixes = $suffixes | Group-Object | Where-Object { $_.Count -gt 1 }
        foreach ($dup in $dupSuffixes) {
            Add-Error "Duplicate mod suffix in commander-units-mapping: '$($dup.Name)' appears $($dup.Count) times"
        }
        # commander check
        if ($Commander -ne "") {
            if ($cmdMap.mappings.PSObject.Properties.Name -notcontains $Commander) {
                Add-Error "Unknown commander: '$Commander' not in commander-units-mapping.mappings"
            }
        }
    }

    # --- Validate alenger-mods ---
    $alenger = $Configs["alenger-mods"]
    if (-not $alenger.mods -or -not $alenger.dependencyPaths) {
        Add-Error "alenger-mods.json missing required fields: mods, dependencyPaths"
    } else {
        if ($alenger.PSObject.Properties.Name -contains "schemaVersion" -and $alenger.schemaVersion -ne 1) {
            Add-Error "alenger-mods.schemaVersion unsupported: $($alenger.schemaVersion) (expected 1)"
        }
        # duplicates
        $modDups = $alenger.mods | Group-Object | Where-Object { $_.Count -gt 1 }
        foreach ($dup in $modDups) {
            Add-Error "Duplicate alenger mod: '$($dup.Name)' appears $($dup.Count) times"
        }
        $depDups = $alenger.dependencyPaths | Group-Object | Where-Object { $_.Count -gt 1 }
        foreach ($dup in $depDups) {
            Add-Error "Duplicate alenger dependency path: '$($dup.Name)' appears $($dup.Count) times"
        }
        # length match
        if ($alenger.mods.Count -ne $alenger.dependencyPaths.Count) {
            Add-Error "alenger-mods: mods count ($($alenger.mods.Count)) != dependencyPaths count ($($alenger.dependencyPaths.Count))"
        }
        # workspace path existence
        for ($i = 0; $i -lt $alenger.mods.Count; $i++) {
            $modRel = $alenger.mods[$i]
            $modSrc = Join-Path $ProjRoot "Mods\$modRel"
            if (-not (Test-Path -LiteralPath $modSrc)) {
                Add-Error "alenger mod source not found: Mods\$modRel"
            }
        }
    }

    # --- Validate reborn-dependencies ---
    $reborn = $Configs["reborn-dependencies"]
    if (-not $reborn.baseMods -or -not $reborn.baseDependencyPaths -or -not $reborn.galaxyInjection -or -not $reborn.validCommanders) {
        Add-Error "reborn-dependencies.json missing required fields: baseMods, baseDependencyPaths, galaxyInjection, validCommanders"
    } else {
        if ($reborn.PSObject.Properties.Name -contains "schemaVersion" -and $reborn.schemaVersion -ne 1) {
            Add-Error "reborn-dependencies.schemaVersion unsupported: $($reborn.schemaVersion) (expected 1)"
        }
        # base mods duplicates
        $baseModDups = $reborn.baseMods | Group-Object | Where-Object { $_.Count -gt 1 }
        foreach ($dup in $baseModDups) {
            Add-Error "Duplicate reborn base mod: '$($dup.Name)' appears $($dup.Count) times"
        }
        $baseDepDups = $reborn.baseDependencyPaths | Group-Object | Where-Object { $_.Count -gt 1 }
        foreach ($dup in $baseDepDups) {
            Add-Error "Duplicate reborn base dependency path: '$($dup.Name)' appears $($dup.Count) times"
        }
        # family check
        if ($MapFamily -ne "" -and $reborn.family -ne $MapFamily) {
            Add-Error "reborn-dependencies.family mismatch: expected '$MapFamily', got '$($reborn.family)'"
        }
        # valid commander check
        if ($Commander -ne "" -and $reborn.validCommanders -notcontains $Commander) {
            Add-Error "Unknown commander for reborn family: '$Commander' not in validCommanders"
        }
        # base mod path existence
        foreach ($modRel in $reborn.baseMods) {
            $modSrc = Join-Path $ProjRoot "Mods\$modRel"
            if (-not (Test-Path -LiteralPath $modSrc)) {
                Add-Error "reborn base mod source not found: Mods\$modRel"
            }
        }
        # galaxy injection rule matches >= 1 file
        $injectRoot = Join-Path $ProjRoot $reborn.galaxyInjection.sourceRoot
        if (-not (Test-Path -LiteralPath $injectRoot)) {
            Add-Error "galaxyInjection.sourceRoot not found: $($reborn.galaxyInjection.sourceRoot)"
        } else {
            $totalMatches = 0
            foreach ($pattern in $reborn.galaxyInjection.sourcePatterns) {
                $matched = Get-ChildItem -LiteralPath $injectRoot -Directory -Filter $pattern -ErrorAction SilentlyContinue
                $totalMatches += $matched.Count
            }
            if ($totalMatches -eq 0) {
                Add-Error "galaxyInjection.sourcePatterns matched 0 directories in $($reborn.galaxyInjection.sourceRoot)"
            }
        }
    }

    return $result
}

function Format-LauncherConfigValidation {
    <#
    .SYNOPSIS
      Render a Test-LauncherConfig result as a human-readable string.
    #>
    param($Result)
    $lines = @()
    if ($Result.Valid) {
        $lines += "CONFIG VALID"
    } else {
        $lines += "CONFIG INVALID"
    }
    if ($Result.Errors.Count -gt 0) {
        $lines += "Errors ($($Result.Errors.Count)):"
        foreach ($e in $Result.Errors) { $lines += "  - $e" }
    }
    if ($Result.Warnings.Count -gt 0) {
        $lines += "Warnings ($($Result.Warnings.Count)):"
        foreach ($w in $Result.Warnings) { $lines += "  - $w" }
    }
    return ($lines -join "`n")
}
