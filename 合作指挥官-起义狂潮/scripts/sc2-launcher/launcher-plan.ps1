<#
.SYNOPSIS
  CompositionPlan-like plan computation for SC2 commander launchers.
.DESCRIPTION
  Computes a LauncherCompatibilityPlan from launcher config + selected commander/map.
  The plan captures:
  - source/generated map paths
  - selected commander slot
  - dependency layers (L1 reborn base, L2 alenger, L4 commander package)
  - galaxy injection list (with owner + reason)
  - document rewrite (DocumentHeader + DocumentInfo dependency arrays)
  - validation status placeholders

  Used by:
  - launch-reborn-commander.ps1 -DryRun   (compute + emit plan, no writes)
  - launch-reborn-commander.ps1 (real run) (compute plan, write to out/compositions/, then execute)
  - CI / diff tooling for plan stability checks
#>

function New-LauncherPlan {
    <#
    .SYNOPSIS
      Compute the full LauncherCompatibilityPlan for a commander+map selection.
    .PARAMETER Commander
      Selected commander id (e.g. TerranRaynor).
    .PARAMETER MapName
      Map file name (e.g. zexpedition03_reborn_port.SC2Map).
    .PARAMETER ProjRoot
      Workspace root.
    .PARAMETER Sc2Root
      SC2 installation root (live target).
    .PARAMETER Configs
      Optional pre-loaded configs hashtable (keys: commander-units-mapping, alenger-mods, reborn-dependencies).
    .OUTPUTS
      PSCustomObject matching launcher-plan.schema.json.
    #>
    param(
        [Parameter(Mandatory=$true)][string]$Commander,
        [Parameter(Mandatory=$true)][string]$MapName,
        [Parameter(Mandatory=$true)][string]$ProjRoot,
        [Parameter(Mandatory=$true)][string]$Sc2Root,
        [hashtable]$Configs = @{}
    )

    $sharedRoot = Join-Path $ProjRoot "Shared\Launcher"

    # Load configs if not provided
    if (-not $Configs.ContainsKey("commander-units-mapping")) {
        $Configs["commander-units-mapping"] = Get-Content -LiteralPath (Join-Path $sharedRoot "commander-units-mapping.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    if (-not $Configs.ContainsKey("alenger-mods")) {
        $Configs["alenger-mods"] = Get-Content -LiteralPath (Join-Path $sharedRoot "alenger-mods.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    if (-not $Configs.ContainsKey("reborn-dependencies")) {
        $Configs["reborn-dependencies"] = Get-Content -LiteralPath (Join-Path $sharedRoot "reborn-dependencies.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    $cmdMap    = $Configs["commander-units-mapping"]
    $alenger   = $Configs["alenger-mods"]
    $reborn    = $Configs["reborn-dependencies"]

    # Resolve selected commander mod
    $selectedSuffix = $null
    if ($cmdMap.mappings.PSObject.Properties.Name -contains $Commander) {
        $selectedSuffix = $cmdMap.mappings.$Commander
    }
    $selectedCommanderUnitsMod = if ($selectedSuffix) { "CommanderUnits_$selectedSuffix" } else { $null }

    # Map paths
    $sourceMapPath = Join-Path $ProjRoot "Maps\$MapName"
    $generatedMapPath = Join-Path $Sc2Root "Maps\$MapName"

    # === Dependency layers ===
    # L1: Reborn original base mods (synced to live)
    # Some baseMods are transitive deps (loaded by other mods, not direct map deps)
    # — they appear in baseMods but not in baseDependencyPaths.
    $l1Entries = @()
    foreach ($modRel in $reborn.baseMods) {
        $modBaseName = [System.IO.Path]::GetFileName($modRel)
        $depPath = $null
        foreach ($bdp in $reborn.baseDependencyPaths) {
            if ($bdp -like "*$modBaseName") { $depPath = $bdp; break }
        }
        $reason = if ($depPath) { "Reborn base mod (direct map dependency)" } else { "Reborn base mod (transitive - synced but not direct map dependency)" }
        $l1Entries += [PSCustomObject]@{
            path   = $depPath
            source = "Mods\$modRel"
            reason = $reason
        }
    }

    # L2: Alenger adapter bootstrap (hardcoded by CoreRuntime)
    # Disabled: 37 Alenger deps cause game crash during loading.
    # Galaxy files are injected separately via Sync-MapRuntimeLibraries.
    $l2Entries = @()

    # L4: Selected commander package (only the chosen one)
    $l4Entries = @()
    if ($selectedCommanderUnitsMod) {
        $l4Entries += [PSCustomObject]@{
            path   = "file:Mods/7vs1/$selectedCommanderUnitsMod.SC2Mod"
            source = "Mods\7vs1\$selectedCommanderUnitsMod.SC2Mod"
            reason = "Selected commander package"
        }
    }

    # === Galaxy injection list ===
    $galaxyInjection = @()
    $injectRoot = Join-Path $ProjRoot $reborn.galaxyInjection.sourceRoot
    $selectedCommanderGalaxyAdded = @{}

    foreach ($pattern in $reborn.galaxyInjection.sourcePatterns) {
        $modDirs = Get-ChildItem -LiteralPath $injectRoot -Directory -Filter $pattern -ErrorAction SilentlyContinue
        foreach ($modDir in $modDirs) {
            $modBase = Join-Path $modDir.FullName "Base.SC2Data"
            if (-not (Test-Path -LiteralPath $modBase)) { continue }
            $galaxyFiles = Get-ChildItem -LiteralPath $modBase -File -Filter "*.galaxy" -ErrorAction SilentlyContinue
            foreach ($gf in $galaxyFiles) {
                # Determine owner
                $owner = if ($modDir.Name -like "CommanderUnits_$selectedSuffix.SC2Mod") {
                    "Commander.$Commander"
                } elseif ($modDir.Name -like "CommanderUnits_*.SC2Mod") {
                    "Commander.Unselected"
                } else {
                    "CoreRuntime.AdapterBootstrap"
                }
                # Determine reason + flags
                $reason = if ($owner -eq "Commander.$Commander") {
                    "Selected commander runtime"
                } elseif ($owner -eq "Commander.Unselected") {
                    "CoreRuntime LibE0EAE146.galaxy compatibility include (unselected commander)"
                } else {
                    "CoreRuntime AdapterBootstrap compatibility include"
                }
                $compatOnly = ($owner -ne "Commander.$Commander")
                $selectedRequired = -not $compatOnly

                $galaxyInjection += [PSCustomObject]@{
                    file                      = "Base.SC2Data/$($gf.Name)"
                    owner                     = $owner
                    source                    = "Mods\$($reborn.galaxyInjection.sourceRoot)\$($modDir.Name)\Base.SC2Data\$($gf.Name)"
                    reason                    = $reason
                    selectedCommanderRequired = $selectedRequired
                    compatibilityOnly         = $compatOnly
                }
            }
        }
    }

    # === Document rewrite (DocumentHeader + DocumentInfo share same dep list) ===
    $runtimeDeps = @() + $reborn.baseDependencyPaths
    if ($selectedCommanderUnitsMod) {
        $runtimeDeps += "file:Mods/7vs1/$selectedCommanderUnitsMod.SC2Mod"
    }
    # De-duplicate while preserving order
    $seen = @{}
    $uniqueDeps = @()
    foreach ($d in $runtimeDeps) {
        if (-not $seen.ContainsKey($d)) {
            $seen[$d] = $true
            $uniqueDeps += $d
        }
    }

    # === Build plan object ===
    # Determine map family prefix for compositionId
    $mapFamily = $reborn.family
    $mapBaseName = [System.IO.Path]::GetFileNameWithoutExtension($MapName)
    $compositionId = "${mapFamily}.${mapBaseName}__p1-${Commander}"

    $plan = [PSCustomObject]@{
        schemaVersion  = 1
        kind           = "LauncherCompatibilityPlan"
        compositionId  = $compositionId
        mapProfile     = "$mapFamily.$mapBaseName"
        sourceMap      = $sourceMapPath
        generatedMap   = $generatedMapPath
        selectedCommander = $Commander
        selectedCommanderUnitsMod = $selectedCommanderUnitsMod
        slots          = [PSCustomObject]@{
            "1" = [PSCustomObject]@{
                commander        = $Commander
                commanderPackage = if ($selectedSuffix) { "Commander.$Commander" } else { $null }
            }
        }
        dependencyLayers = @(
            [PSCustomObject]@{ layer = "L1"; name = "Reborn base mods"; entries = $l1Entries },
            [PSCustomObject]@{ layer = "L2"; name = "Alenger adapter bootstrap (CoreRuntime hardcoded)"; entries = $l2Entries },
            [PSCustomObject]@{ layer = "L4"; name = "Selected commander package"; entries = $l4Entries }
        )
        galaxyInjection = $galaxyInjection
        documentRewrite = [PSCustomObject]@{
            DocumentHeader = $uniqueDeps
            DocumentInfo   = $uniqueDeps
        }
        validation = [PSCustomObject]@{
            configSchema       = "pending"
            documentRoundtrip  = "pending"
            galaxyChecker      = "pending"
            runtimeSmoke       = "pending"
        }
        migration = [PSCustomObject]@{
            targetSchema = "scripts/sc2-composer/schema/CompositionPlan.schema.json"
            status       = "transitional"
            knownDebt    = @(
                [PSCustomObject]@{
                    id               = "core-runtime-full-include"
                    reason           = "CoreRuntime LibE0EAE146.galaxy hardcodes include of all commander Runtime files, forcing unselected commander galaxy files to be injected into map Base.SC2Data"
                    removalCondition = "generated bootstrap only includes selected commander Runtime, verified by Raynor/Kerrigan/Karax triple regression"
                },
                [PSCustomObject]@{
                    id               = "galaxy-directory-scan"
                    reason           = "galaxyInjection is built via Get-ChildItem directory scan; undeclared files may be injected; no GalaxyManifest explicit declaration"
                    removalCondition = "Shared/Galaxy/reborn-compat-galaxy-manifest.json covers all injection entries, launcher reads from manifest, undeclared files not injected"
                },
                [PSCustomObject]@{
                    id               = "launcher-config-as-temporary-source"
                    reason           = "Shared/Launcher/*.json are Reborn transitional configs, duplicating commander mapping and deps that also exist in Shared/Commanders, DataCenter.json, MapProfile"
                    removalCondition = "sc2-composer plan can generate equivalent CompositionPlan from Shared/Commanders + MapProfile + DataCenter, Shared/Launcher frozen as read-only compat shim"
                },
                [PSCustomObject]@{
                    id               = "alenger-adapter-bootstrap-hardcoded"
                    reason           = "LibE0EAE146_AdapterBootstrap.galaxy hardcodes include of LibA1ADAPTER through LibA13ADAPTER, forcing all 24 Alenger mods to be full dependencies"
                    removalCondition = "AdapterBootstrap changed to on-demand include or generated bootstrap trim, verified by Alenger3 single-combo regression"
                },
                [PSCustomObject]@{
                    id               = "schema-not-validated-by-ajv"
                    reason           = "config-validation.ps1 now uses validate-config.mjs (minimal node JSON Schema validator) for structural checks, but it is not a full ajv implementation; complex schema features (oneOf, anyOf, $ref, format) are not supported"
                    removalCondition = "ajv-cli (or equivalent full JSON Schema validator) installed and integrated into -CheckOnly, all 4 schema files fully enforced"
                }
            )
        }
        generatedAt = (Get-Date).ToString("o")
    }

    return $plan
}

function Export-LauncherPlan {
    <#
    .SYNOPSIS
      Write a LauncherCompatibilityPlan to out/compositions/ as JSON.
    .PARAMETER Plan
      Plan object from New-LauncherPlan.
    .PARAMETER ProjRoot
      Workspace root (output goes to $ProjRoot/out/compositions/).
    .PARAMETER Pretty
      If true, indent JSON. Default: true.
    .OUTPUTS
      Path to the written JSON file.
    #>
    param(
        [Parameter(Mandatory=$true)]$Plan,
        [Parameter(Mandatory=$true)][string]$ProjRoot,
        [switch]$Pretty
    )
    $outDir = Join-Path $ProjRoot "out\compositions"
    if (-not (Test-Path -LiteralPath $outDir)) {
        [System.IO.Directory]::CreateDirectory($outDir) | Out-Null
    }
    $fileName = "$($Plan.compositionId).launcher-plan.json"
    $outPath = Join-Path $outDir $fileName

    $depth = if ($Pretty) { 6 } else { 1 }
    $json = $Plan | ConvertTo-Json -Depth $depth
    [System.IO.File]::WriteAllText($outPath, $json, [System.Text.UTF8Encoding]::new($false))
    return $outPath
}

function Test-LauncherPlanStable {
    <#
    .SYNOPSIS
      Run New-LauncherPlan twice and compare JSON output for stability.
      Returns true if both runs produce identical JSON (after generatedAt normalization).
    .PARAMETER PlanInputs
      Hashtable of inputs to pass to New-LauncherPlan.
    .OUTPUTS
      PSCustomObject with .Stable (bool), .Diff (string), .Run1Path, .Run2Path
    #>
    param(
        [Parameter(Mandatory=$true)][hashtable]$PlanInputs,
        [string]$OutDir
    )

    $plan1 = New-LauncherPlan @PlanInputs
    $plan2 = New-LauncherPlan @PlanInputs

    # Normalize generatedAt for comparison
    $plan1.generatedAt = "NORMALIZED"
    $plan2.generatedAt = "NORMALIZED"

    $json1 = $plan1 | ConvertTo-Json -Depth 6
    $json2 = $plan2 | ConvertTo-Json -Depth 6

    $stable = ($json1 -eq $json2)

    $result = [PSCustomObject]@{
        Stable = $stable
        Diff   = if (-not $stable) { Compare-Object ($json1 -split "`n") ($json2 -split "`n") | Out-String } else { "" }
    }
    return $result
}

function Read-CompositionPlan {
    <#
    .SYNOPSIS
      读取 sc2-composer 生成的 CompositionPlan.json，转换为 launcher 可消费的执行参数。
      这是 Priority 1 的核心：让 launcher 消费 plan 而非自己从 config 计算。
    .DESCRIPTION
      从 CompositionPlan 提取：
      - mapName / commander / selectedCommanderUnitsMod
      - modSyncList（从 dependencies.always + dependencies.commander 提取 source 路径）
      - galaxyInjection（从 bootstrap.galaxyIncludes 提取，配合 GalaxyManifest 定位源文件）
      - documentDeps（dependencies.always + commander 的所有 path）
    .PARAMETER PlanPath
      CompositionPlan.json 文件路径。
    .PARAMETER ProjRoot
      项目根目录。
    .OUTPUTS
      PSCustomObject with: mapName, commander, selectedCommanderUnitsMod, modSyncList,
      galaxyInjectionEntries, documentDeps, compositionId, sourceMap, generatedMap, rawPlan
    #>
    param(
        [Parameter(Mandatory=$true)][string]$PlanPath,
        [Parameter(Mandatory=$true)][string]$ProjRoot
    )

    if (-not (Test-Path -LiteralPath $PlanPath)) {
        throw "CompositionPlan not found: $PlanPath"
    }

    $plan = Get-Content -LiteralPath $PlanPath -Raw -Encoding UTF8 | ConvertFrom-Json

    # 从 plan.map.source 提取 mapName（格式: Maps/<mapName>.SC2Map）
    $mapSource = $plan.map.source
    $mapName = [System.IO.Path]::GetFileName($mapSource)

    # 从 commanderSlots[0] 提取 commander
    $commander = $plan.commanderSlots[0].commanderId

    # 从 _compat 提取 selectedCommanderUnitsMod（过渡期字段）
    $selectedCommanderUnitsMod = $null
    if ($plan._compat -and $plan._compat.selectedCommanderUnitsMod) {
        $selectedCommanderUnitsMod = $plan._compat.selectedCommanderUnitsMod
    } else {
        # Fallback: 从 dependencies.commander 路径推导
        foreach ($cd in $plan.dependencies.commander) {
            foreach ($d in $cd.dependencies) {
                if ($d.path -match 'CommanderUnits_(\w+)\.SC2Mod') {
                    $selectedCommanderUnitsMod = "CommanderUnits_$($Matches[1])"
                    break
                }
            }
        }
    }

    # sourceMap / generatedMap
    $sourceMap = if ($plan._compat -and $plan._compat.sourceMap) { $plan._compat.sourceMap } else { Join-Path $ProjRoot $mapSource }
    $generatedMap = if ($plan._compat -and $plan._compat.generatedMap) { $plan._compat.generatedMap } else { Join-Path $Sc2Root "Maps\$mapName" }

    # modSyncList: 从 dependencies.always + commander 提取需要同步的 mod 目录
    # always 条目 path 格式: file:Mods/7vs1/xxx.SC2Mod → source: Mods\7vs1\xxx.SC2Mod
    $modSyncList = @()
    foreach ($d in $plan.dependencies.always) {
        $modRel = $d.path -replace '^file:', '' -replace '/', '\'
        $modSyncList += $modRel
    }
    foreach ($cd in $plan.dependencies.commander) {
        foreach ($d in $cd.dependencies) {
            $modRel = $d.path -replace '^file:', '' -replace '/', '\'
            $modSyncList += $modRel
        }
    }

    # documentDeps: 所有 path（保持顺序，去重）
    $documentDeps = @()
    $seen = @{}
    foreach ($d in $plan.dependencies.always) {
        if (-not $seen.ContainsKey($d.path)) { $seen[$d.path] = $true; $documentDeps += $d.path }
    }
    foreach ($cd in $plan.dependencies.commander) {
        foreach ($d in $cd.dependencies) {
            if (-not $seen.ContainsKey($d.path)) { $seen[$d.path] = $true; $documentDeps += $d.path }
        }
    }

    # galaxyInjectionEntries: 从 bootstrap.galaxyIncludes 提取
    # 配合 GalaxyManifest 定位每个文件的 source 路径
    $galaxyInjectionEntries = @()
    $manifestPath = Join-Path $ProjRoot "Shared\Galaxy\reborn-compat-galaxy-manifest.json"
    $manifest = $null
    if (Test-Path -LiteralPath $manifestPath) {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    foreach ($inc in $plan.bootstrap.galaxyIncludes) {
        $entry = [PSCustomObject]@{
            file    = $inc.path
            purpose = $inc.purpose
            source  = $null
        }
        # 从 manifest 查找 source
        if ($manifest) {
            foreach ($me in $manifest.entries) {
                if ($me.file -eq $inc.path) {
                    $entry.source = $me.sourceMod + '\Base.SC2Data\' + ($inc.path -replace '^Base\.SC2Data/', '')
                    break
                }
            }
        }
        $galaxyInjectionEntries += $entry
    }

    return [PSCustomObject]@{
        mapName                   = $mapName
        commander                 = $commander
        selectedCommanderUnitsMod = $selectedCommanderUnitsMod
        sourceMap                 = $sourceMap
        generatedMap              = $generatedMap
        compositionId             = $plan.planId
        modSyncList               = $modSyncList
        documentDeps              = $documentDeps
        galaxyInjectionEntries    = $galaxyInjectionEntries
        rawPlan                   = $plan
        planPath                  = $PlanPath
    }
}
