function Disable-LiveRewardGrants {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $text = Get-Content -LiteralPath $Path -Raw
    $text = [regex]::Replace(
        $text,
        '(?m)^\s*PlayerAddReward\([^\r\n]*\);\s*$',
        '    // Codex local smoke test: PlayerAddReward omitted because SC2Switcher has no reward authority.'
    )
    Set-FileTextWithRetry -Path $Path -Text $text
}

function Patch-LiveTychusUiGuards {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $text = Get-Content -LiteralPath $Path -Raw

    $text = $text.Replace(
        '    libKCUI_gv_cU_TychusSquadBar[UnitGetOwner(lp_tychusBarUnit)] = lp_tychusBarUnit;',
        @'
    if ((lp_tychusBarUnit == null) || (UnitGetOwner(lp_tychusBarUnit) < 1) || (UnitGetOwner(lp_tychusBarUnit) > libKCOR_gv_cCC_MAXPLAYERS)) {
        return ;
    }
    libKCUI_gv_cU_TychusSquadBar[UnitGetOwner(lp_tychusBarUnit)] = lp_tychusBarUnit;
'@
    )

    $targetFramePattern = '(?s)    if \(\(lv_squadindex == -1\)\) \{\s+return ;\s+\}\s+libNtve_gf_SetDialogItemUnit\(libKCUI_gv_cU_TychusSquadUnitFrames\[lv_squadindex\]\[lp_player\], lp_targetUnit, PlayerGroupAll\(\)\);\s+libNtve_gf_SetDialogItemUnit\(libKCUI_gv_cU_TychusSquadUnitTargets\[lv_squadindex\]\[lp_player\], lp_targetUnit, PlayerGroupAll\(\)\);'
    $targetFrameReplacement = @'
    if ((lv_squadindex < 0) || (lv_squadindex >= libKCUI_gv_cUC_TYCHUS_MAX_SQUAD_SIZE) || (lp_player < 1) || (lp_player > libKCOR_gv_cCC_MAXPLAYERS)) {
        return ;
    }
    if ((libKCUI_gv_cU_TychusSquadUnitFrames[lv_squadindex][lp_player] <= 0) || (libKCUI_gv_cU_TychusSquadUnitTargets[lv_squadindex][lp_player] <= 0)) {
        return ;
    }

    libNtve_gf_SetDialogItemUnit(libKCUI_gv_cU_TychusSquadUnitFrames[lv_squadindex][lp_player], lp_targetUnit, PlayerGroupAll());
    libNtve_gf_SetDialogItemUnit(libKCUI_gv_cU_TychusSquadUnitTargets[lv_squadindex][lp_player], lp_targetUnit, PlayerGroupAll());
'@
    $newText = [regex]::Replace($text, $targetFramePattern, $targetFrameReplacement, 1)
    if ($newText -ne $text) {
        $text = $newText
    }

    Set-FileTextWithRetry -Path $Path -Text $text
}

function Patch-LiveAbathurBiomassScaleGuard {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $text = Get-Content -LiteralPath $Path -Raw
    $text = $text.Replace(
        '        ActorSendAsText(libNtve_gf_MainActorofUnit(lp_biomassUnit), TextExpressionAssemble("Param/Expression/lib_KMIS_AED708CF"));',
        '        // Codex local smoke test: skip actor scale message when the copied test map has no valid biomass actor info.'
    )
    $text = $text.Replace(
        '        ActorSendAsText(libNtve_gf_MainActorofUnit(lp_biomassUnit), TextExpressionAssemble("Param/Expression/lib_KMIS_139DC70E"));',
        '        // Codex local smoke test: skip actor scale message when the copied test map has no valid biomass actor info.'
    )
    Set-FileTextWithRetry -Path $Path -Text $text
}

function Save-XmlDocument {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument]$Document,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try {
        $Document.Save($writer)
    }
    finally {
        $writer.Close()
    }
}

function Get-OrCreateCatalogXml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    [xml]$xml = New-Object System.Xml.XmlDocument
    if (Test-Path -LiteralPath $Path) {
        $xml.Load($Path)
    }
    else {
        $declaration = $xml.CreateXmlDeclaration("1.0", "utf-8", $null)
        [void]$xml.AppendChild($declaration)
        [void]$xml.AppendChild($xml.CreateElement("Catalog"))
    }

    if ($null -eq $xml.Catalog) {
        throw "Expected Catalog root in $Path"
    }

    return $xml
}

function Merge-CatalogEntriesById {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceGameData,
        [Parameter(Mandatory = $true)]
        [string]$LiveGameData,
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        [Parameter(Mandatory = $true)]
        [string[]]$Ids
    )

    $sourcePath = Join-Path $SourceGameData $FileName
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Source catalog not found: $sourcePath"
    }

    $livePath = Join-Path $LiveGameData $FileName
    $liveParent = Split-Path -Parent $livePath
    if (-not (Test-Path -LiteralPath $liveParent)) {
        New-Item -ItemType Directory -Path $liveParent -Force | Out-Null
    }

    [xml]$sourceXml = Get-Content -LiteralPath $sourcePath -Raw
    if ($null -eq $sourceXml.Catalog) {
        throw "Expected Catalog root in $sourcePath"
    }

    $liveXml = Get-OrCreateCatalogXml -Path $livePath
    foreach ($id in $Ids) {
        $escapedId = $id.Replace("'", "&apos;")
        $sourceNode = $sourceXml.SelectSingleNode("/Catalog/*[@id='$escapedId']")
        if ($null -eq $sourceNode) {
            throw "Catalog id '$id' not found in $sourcePath"
        }

        $existing = $liveXml.SelectSingleNode("/Catalog/*[@id='$escapedId']")
        $imported = $liveXml.ImportNode($sourceNode, $true)
        if ($null -ne $existing) {
            [void]$liveXml.DocumentElement.ReplaceChild($imported, $existing)
        }
        else {
            [void]$liveXml.DocumentElement.AppendChild($imported)
        }
    }

    Save-XmlDocument -Document $liveXml -Path $livePath
}

function Normalize-LiveKelMorianWorkerUnitData {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiveGameData
    )

    $unitDataPath = Join-Path $LiveGameData "UnitData.xml"
    if (-not (Test-Path -LiteralPath $unitDataPath)) {
        throw "Live UnitData not found: $unitDataPath"
    }

    [xml]$unitXml = Get-Content -LiteralPath $unitDataPath -Raw
    $worker = $unitXml.SelectSingleNode('/Catalog/CUnit[@id="KelMorianWorker"]')
    if ($null -eq $worker) {
        throw "KelMorianWorker not found in $unitDataPath"
    }

    foreach ($link in @("stop", "move", "TerranBuild")) {
        $nodes = @($worker.SelectNodes("AbilArray[@Link='$link']"))
        foreach ($node in $nodes) {
            [void]$worker.RemoveChild($node)
        }
    }

    foreach ($link in @("KelMorianWorkerRepair", "KelMorianWorkerBuild")) {
        if ($null -eq $worker.SelectSingleNode("AbilArray[@Link='$link']")) {
            $ability = $unitXml.CreateElement("AbilArray")
            [void]$ability.SetAttribute("Link", $link)
            [void]$worker.InsertBefore($ability, $worker.SelectSingleNode("CardLayouts"))
        }
    }

    Save-XmlDocument -Document $unitXml -Path $unitDataPath
}

function Patch-LiveSwannKelMorianWorkerData {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceGameData,
        [Parameter(Mandatory = $true)]
        [string]$LiveGameData
    )

    if (-not (Test-Path -LiteralPath $SourceGameData)) {
        throw "Swann source GameData not found: $SourceGameData"
    }

    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "UnitData.xml" -Ids @("KelMorianWorker")
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "AbilData.xml" -Ids @("KelMorianWorkerRepair", "KelMorianWorkerBuild")
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "EffectData.xml" -Ids @("KelMorianWorkerRepair")
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "BehaviorData.xml" -Ids @("KelMorianWorkerCloak")
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "ValidatorData.xml" -Ids @("HaveSwannCommanderWorkerCloak")
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "ButtonData.xml" -Ids @(
        "BuildKelMorianMissileTurret",
        "PermanentlyCloakedKelMorianWorker",
        "KelMorianAssist",
        "BuildDrakkenLaserDrill",
        "BuildLaserTurret",
        "BuildKelMorianRocketTurret",
        "TrainKelMorianWorkers"
    )
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "RequirementData.xml" -Ids @(
        "HaveAdvancedConstruction",
        "HaveSwannCommander",
        "HaveSwannCommanderKelMorianWorkerCloak",
        "HaveSwannCommanderKelMorianWorkerRocketTurret",
        "DrakkenLaserRequirements"
    )
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "RequirementNodeData.xml" -Ids @(
        "CountUpgradeAdvancedConstructionCompleteOnly",
        "CountUpgradeSwannCommanderCompleteOnly",
        "CountUpgradeSwannCommanderKelMorianWorkerRocketTurretCompleteOnly",
        "CountUpgradeSwannCommanderWorkerCloakCompleteOnly"
    )
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "UpgradeData.xml" -Ids @(
        "AdvancedConstruction",
        "SwannCommanderKelMorianWorkerRocketTurret"
    )
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "ModelData.xml" -Ids @("KelMorianWorker")
    Merge-CatalogEntriesById -SourceGameData $SourceGameData -LiveGameData $LiveGameData -FileName "ActorData.xml" -Ids @("KelMorianWorker", "KelMorianWorkerDropModel")
    Normalize-LiveKelMorianWorkerUnitData -LiveGameData $LiveGameData
}

function Apply-LiveCommanderTestPatches {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseDataRoot,
        [Parameter(Mandatory = $true)]
        [string[]]$SelectedCommanders,
        [string]$TestSpawnPreset = "",
        [bool]$ApplySupportPatches = $true
    )

    $libKPVP = Join-Path $BaseDataRoot "LibKPVP.galaxy"
    if (-not (Test-Path -LiteralPath $libKPVP)) {
        return
    }

    Set-LiveCommanderTestOverride -LibPath $libKPVP -SelectedCommanders $SelectedCommanders -TestSpawnPreset $TestSpawnPreset
    if (-not $ApplySupportPatches) {
        return
    }

    $libKMIS = Join-Path $BaseDataRoot "LibKMIS.galaxy"
    if (Test-Path -LiteralPath $libKMIS) {
        Disable-LiveRewardGrants -Path $libKMIS
    }

    $libKCUI = Join-Path $BaseDataRoot "LibKCUI.galaxy"
    if (Test-Path -LiteralPath $libKCUI) {
        Patch-LiveTychusUiGuards -Path $libKCUI
    }
}

function Set-LiveRuntimePrimaryCommanderOverride {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseDataRoot,
        [Parameter(Mandatory = $true)]
        [string[]]$SelectedCommanders
    )

    if (($null -eq $SelectedCommanders) -or ($SelectedCommanders.Count -lt 1)) {
        return
    }

    $primaryCommander = Convert-TestCommanderToCommanderPowerKey -Commander $SelectedCommanders[0]
    if ([string]::IsNullOrWhiteSpace($primaryCommander)) {
        throw "Cannot map test commander '$($SelectedCommanders[0])' to runtime primary commander."
    }

    $runtimeSafety = Join-Path $BaseDataRoot "LibE0EAE146_RuntimeSafety.galaxy"
    if (-not (Test-Path -LiteralPath $runtimeSafety)) {
        return
    }

    $text = Get-Content -LiteralPath $runtimeSafety -Raw
    $pattern = '(?s)string libE0EAE146_gf_CodexTestPrimaryCommander \(\) \{\s*return ".*?";\s*\}'
    $replacement = "string libE0EAE146_gf_CodexTestPrimaryCommander () {`r`n    return `"$primaryCommander`";`r`n}"
    $newText = [regex]::Replace($text, $pattern, $replacement, 1)
    if ($newText -eq $text) {
        if ($text -match [regex]::Escape($replacement)) {
            return
        }
        throw "Could not patch runtime primary commander override in $runtimeSafety"
    }

    Set-FileTextWithRetry -Path $runtimeSafety -Text $newText
}

function Set-LiveCommanderTestOverride {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LibPath,
        [Parameter(Mandatory = $true)]
        [string[]]$SelectedCommanders,
        [string]$TestSpawnPreset = ""
    )

    if (($SelectedCommanders.Count -lt 1) -or ($SelectedCommanders.Count -gt 7)) {
        throw "Expected 1-7 commanders. Got $($SelectedCommanders.Count)."
    }

    $known = @(
        "ZergAbathur",
        "ProtossAlarak",
        "ProtossArtanis",
        "ZergDehaka",
        "ProtossFenix",
        "TerranHorner",
        "ProtossKarax",
        "ZergKerrigan",
        "TerranMengsk",
        "TerranNova",
        "TerranRaynor",
        "ZergStetmann",
        "ZergStukov",
        "TerranSwann",
        "TerranTychus",
        "ProtossVorazun",
        "ZergZagara",
        "ProtossZeratul"
    )

    foreach ($commander in $SelectedCommanders) {
        if ($known -notcontains $commander) {
            throw "Unknown commander '$commander'. Known commanders: $($known -join ', ')"
        }
    }

    $text = Get-Content -LiteralPath $LibPath -Raw
    $oldCodexBlockPattern = '(?s)\r?\n//--------------------------------------------------------------------------------------------------\r?\n// Codex live test override: initialize local test commanders without Battle\.net lobby attrs\.\r?\n//--------------------------------------------------------------------------------------------------\r?\nvoid libKPVP_gf_codex_add_special_groups .*?(?=//--------------------------------------------------------------------------------------------------\r?\nvoid libKPVP_gt_player_defeated_Init)'
    $text = [regex]::Replace($text, $oldCodexBlockPattern, "")
    $codexBlockPattern = '(?s)\r?\n//--------------------------------------------------------------------------------------------------\r?\n// Codex live test override: .*?\r?\n//--------------------------------------------------------------------------------------------------\r?\n(?:string|void) libKPVP_gf_codex_.*?(?=//--------------------------------------------------------------------------------------------------\r?\nvoid libKPVP_gt_player_defeated_Init)'
    $text = [regex]::Replace($text, $codexBlockPattern, "")

    $functionBlock = New-Object System.Text.StringBuilder
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("//--------------------------------------------------------------------------------------------------")
    [void]$functionBlock.AppendLine("// Codex live test override: sync commander runtime state for local smoke tests.")
    [void]$functionBlock.AppendLine("//--------------------------------------------------------------------------------------------------")
    [void]$functionBlock.AppendLine("string libKPVP_gf_codex_commander_attribute_from_bank_key (string lp_bankKey) {")
    [void]$functionBlock.AppendLine("    if (lp_bankKey == `"Abathur`") {")
    [void]$functionBlock.AppendLine("        return `"0001`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_bankKey == `"Alarak`") {")
    [void]$functionBlock.AppendLine("        return `"0002`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_bankKey == `"Artanis`") {")
    [void]$functionBlock.AppendLine("        return `"0003`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_bankKey == `"Dehaka`") {")
    [void]$functionBlock.AppendLine("        return `"0004`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_bankKey == `"Fenix`") {")
    [void]$functionBlock.AppendLine("        return `"0005`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_bankKey == `"Horner`") {")
    [void]$functionBlock.AppendLine("        return `"0006`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_bankKey == `"Karax`") {")
    [void]$functionBlock.AppendLine("        return `"0007`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_bankKey == `"Kerrigan`") {")
    [void]$functionBlock.AppendLine("        return `"0008`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_bankKey == `"Nova`") {")
    [void]$functionBlock.AppendLine("        return `"0009`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_bankKey == `"Raynor`") {")
    [void]$functionBlock.AppendLine("        return `"0010`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_bankKey == `"Stukov`") {")
    [void]$functionBlock.AppendLine("        return `"0011`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_bankKey == `"Swann`") {")
    [void]$functionBlock.AppendLine("        return `"0012`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_bankKey == `"Vorazun`") {")
    [void]$functionBlock.AppendLine("        return `"0013`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_bankKey == `"Zagara`") {")
    [void]$functionBlock.AppendLine("        return `"0014`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_bankKey == `"Tychus`") {")
    [void]$functionBlock.AppendLine("        return `"0016`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_bankKey == `"Zeratul`") {")
    [void]$functionBlock.AppendLine("        return `"0017`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_bankKey == `"Stetmann`") {")
    [void]$functionBlock.AppendLine("        return `"0018`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    else if (lp_bankKey == `"Mengsk`") {")
    [void]$functionBlock.AppendLine("        return `"0019`";")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("    return `"`";")
    [void]$functionBlock.AppendLine("}")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("string libKPVP_gf_codex_commander_attribute_for_runtime_player (int lp_player) {")
    [void]$functionBlock.AppendLine("    string lv_bankKey;")
    [void]$functionBlock.AppendLine("    string lv_bankAttribute;")
    [void]$functionBlock.AppendLine("    string lv_slotKey;")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("    lv_bankKey = `"`";")
    [void]$functionBlock.AppendLine("    lv_slotKey = (`"CommanderP`" + IntToString(lp_player));")
    [void]$functionBlock.AppendLine("    BankLoad(`"CampaignXCore`", 1);")
    [void]$functionBlock.AppendLine("    if (BankKeyExists(BankLastCreated(), `"XMRuntimeControl`", lv_slotKey)) {")
    [void]$functionBlock.AppendLine("        lv_bankKey = BankValueGetAsString(BankLastCreated(), `"XMRuntimeControl`", lv_slotKey);")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    if ((lv_bankKey == `"`") && BankKeyExists(BankLastCreated(), `"XMRuntimeControl`", `"PrimaryCommander`")) {")
    [void]$functionBlock.AppendLine('        lv_bankKey = BankValueGetAsString(BankLastCreated(), "XMRuntimeControl", "PrimaryCommander");')
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    lv_bankAttribute = libKPVP_gf_codex_commander_attribute_from_bank_key(lv_bankKey);")
    [void]$functionBlock.AppendLine("    if (lv_bankAttribute != `"`") {")
    [void]$functionBlock.AppendLine("        return lv_bankAttribute;")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine('    return GameAttributePlayerValue("[bnet:local/0.0/223536]1", lp_player);')
    [void]$functionBlock.AppendLine("}")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("void libKPVP_gf_codex_apply_swann_worker_tech (int lp_player) {")
    [void]$functionBlock.AppendLine("    int lv_build;")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("    libNtve_gf_SetUpgradeLevelForPlayer(lp_player, `"SwannCommander`", 1);")
    [void]$functionBlock.AppendLine("    libNtve_gf_SetUpgradeLevelForPlayer(lp_player, `"CommanderLevel`", 15);")
    [void]$functionBlock.AppendLine("    TechTreeAbilityAllow(lp_player, AbilityCommand(`"KelMorianWorkerBuild`", 0), true);")
    [void]$functionBlock.AppendLine("    lv_build = 1;")
    [void]$functionBlock.AppendLine("    while (lv_build <= 24) {")
    [void]$functionBlock.AppendLine("        TechTreeAbilityAllow(lp_player, AbilityCommand(`"KelMorianWorkerBuild`", lv_build), true);")
    [void]$functionBlock.AppendLine("        lv_build = lv_build + 1;")
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("    TechTreeAbilityAllow(lp_player, AbilityCommand(`"KelMorianWorkerRepair`", 0), true);")
    [void]$functionBlock.AppendLine("    TechTreeAbilityAllow(lp_player, AbilityCommand(`"AdvancedConstructionAuto`", 0), true);")
    [void]$functionBlock.AppendLine("    UIDisplayMessage(PlayerGroupSingle(lp_player), c_messageAreaChat, StringToText((`"Codex test init: TerranSwann KelMorianWorker tech enabled. Workers=`" + IntToString(UnitGroupCount(UnitGroup(`"KelMorianWorker`", lp_player, RegionEntireMap(), UnitFilter(0, 0, (1 << c_targetFilterMissile), (1 << (c_targetFilterDead - 32)) | (1 << (c_targetFilterHidden - 32))), 0), c_unitCountAlive)))));")
    [void]$functionBlock.AppendLine("}")
    [void]$functionBlock.AppendLine("")
    if ($TestSpawnPreset -eq "AbathurFusion") {
        [void]$functionBlock.AppendLine("void libKPVP_gf_codex_abathur_apply_full_biomass (unit lp_unit, int lp_player, int lp_stack) {")
        [void]$functionBlock.AppendLine("    if (lp_unit == null) {")
        [void]$functionBlock.AppendLine("        return;")
        [void]$functionBlock.AppendLine("    }")
        [void]$functionBlock.AppendLine("    libKMIS_gf_CM_Abathur_BiomassSetStack(lp_unit, lp_stack);")
        [void]$functionBlock.AppendLine("    libKMIS_gf_CM_Abathur_BiomassScale(lp_unit, true);")
        [void]$functionBlock.AppendLine("    libKMIS_gf_CM_Abathur_BiomassMerge(lp_unit, lp_stack);")
        [void]$functionBlock.AppendLine("}")
        [void]$functionBlock.AppendLine("")
        [void]$functionBlock.AppendLine("void libKPVP_gf_codex_spawn_abathur_fusion_biomass (int lp_player) {")
        [void]$functionBlock.AppendLine("    libE0EAE146_gf_InitializeAbathurBiomass(lp_player, `"BiomassPickupDummy`");")
        [void]$functionBlock.AppendLine("    UIDisplayMessage(PlayerGroupSingle(lp_player), c_messageAreaChat, StringToText(`"Codex test init: Abathur biomass initialized at the player start.`"));")
        [void]$functionBlock.AppendLine("}")
        [void]$functionBlock.AppendLine("")
        [void]$functionBlock.AppendLine("void libKPVP_gf_codex_spawn_abathur_fusion_units (int lp_player) {")
        [void]$functionBlock.AppendLine("    point lv_start;")
        [void]$functionBlock.AppendLine("    unit lv_unit;")
        [void]$functionBlock.AppendLine("")
        [void]$functionBlock.AppendLine("    lv_start = PlayerStartLocation(lp_player);")
        [void]$functionBlock.AppendLine("")
        [void]$functionBlock.AppendLine("    libNtve_gf_CreateUnitsWithDefaultFacing(1, `"BrutaliskAbathur`", c_unitCreateIgnorePlacement, lp_player, Point(PointGetX(lv_start) + 10.0, PointGetY(lv_start) + 6.0));")
        [void]$functionBlock.AppendLine("    lv_unit = UnitLastCreated();")
        [void]$functionBlock.AppendLine("    libKPVP_gf_codex_abathur_apply_full_biomass(lv_unit, lp_player, 200);")
        [void]$functionBlock.AppendLine("")
        [void]$functionBlock.AppendLine("    libNtve_gf_CreateUnitsWithDefaultFacing(1, `"LeviathanAbathur`", c_unitCreateIgnorePlacement, lp_player, Point(PointGetX(lv_start) + 14.0, PointGetY(lv_start) + 10.0));")
        [void]$functionBlock.AppendLine("    lv_unit = UnitLastCreated();")
        [void]$functionBlock.AppendLine("    libKPVP_gf_codex_abathur_apply_full_biomass(lv_unit, lp_player, 200);")
        [void]$functionBlock.AppendLine("")
        [void]$functionBlock.AppendLine("    libNtve_gf_CreateUnitsWithDefaultFacing(1, `"RavagerAbathur`", c_unitCreateIgnorePlacement, lp_player, Point(PointGetX(lv_start) + 6.0, PointGetY(lv_start) + 12.0));")
        [void]$functionBlock.AppendLine("    lv_unit = UnitLastCreated();")
        [void]$functionBlock.AppendLine("    libKPVP_gf_codex_abathur_apply_full_biomass(lv_unit, lp_player, 200);")
        [void]$functionBlock.AppendLine("")
        [void]$functionBlock.AppendLine("    libNtve_gf_CreateUnitsWithDefaultFacing(1, `"MutaliskAbathur`", c_unitCreateIgnorePlacement, lp_player, Point(PointGetX(lv_start) + 2.0, PointGetY(lv_start) + 14.0));")
        [void]$functionBlock.AppendLine("    lv_unit = UnitLastCreated();")
        [void]$functionBlock.AppendLine("    libKPVP_gf_codex_abathur_apply_full_biomass(lv_unit, lp_player, 200);")
        [void]$functionBlock.AppendLine("")
        [void]$functionBlock.AppendLine("    UIDisplayMessage(PlayerGroupSingle(lp_player), c_messageAreaChat, StringToText(`"Codex test init: Abathur fusion verification units spawned.`"));")
        [void]$functionBlock.AppendLine("}")
        [void]$functionBlock.AppendLine("")
        [void]$functionBlock.AppendLine("void libKPVP_gf_codex_run_test_spawn_preset (int lp_player, string lp_commander) {")
        [void]$functionBlock.AppendLine("    if (lp_commander == `"ZergAbathur`") {")
        [void]$functionBlock.AppendLine("        libKPVP_gf_codex_spawn_abathur_fusion_biomass(lp_player);")
        [void]$functionBlock.AppendLine("        libKPVP_gf_codex_spawn_abathur_fusion_units(lp_player);")
        [void]$functionBlock.AppendLine("    }")
        [void]$functionBlock.AppendLine("}")
        [void]$functionBlock.AppendLine("")
    }
    [void]$functionBlock.AppendLine("void libKPVP_gf_codex_post_lobby_init () {")
    [void]$functionBlock.AppendLine("    int lv_player;")
    [void]$functionBlock.AppendLine("    string lv_commander;")
    [void]$functionBlock.AppendLine("    playergroup autoCodexCommanders_g;")
    [void]$functionBlock.AppendLine("")
    [void]$functionBlock.AppendLine("    autoCodexCommanders_g = libKCOR_gf_CommanderPlayers();")
    [void]$functionBlock.AppendLine("    lv_player = -1;")
    [void]$functionBlock.AppendLine("    while (true) {")
    [void]$functionBlock.AppendLine("        lv_player = PlayerGroupNextPlayer(autoCodexCommanders_g, lv_player);")
    [void]$functionBlock.AppendLine("        if (lv_player < 0) { break; }")
    [void]$functionBlock.AppendLine("        lv_commander = libKCOR_gf_ActiveCommanderForPlayer(lv_player);")
    [void]$functionBlock.AppendLine("        if (lv_commander == `"TerranSwann`") {")
    [void]$functionBlock.AppendLine("            libKPVP_gf_codex_apply_swann_worker_tech(lv_player);")
    [void]$functionBlock.AppendLine("        }")
    if (-not [string]::IsNullOrWhiteSpace($TestSpawnPreset)) {
        [void]$functionBlock.AppendLine("        libKPVP_gf_codex_run_test_spawn_preset(lv_player, lv_commander);")
    }
    [void]$functionBlock.AppendLine("    }")
    [void]$functionBlock.AppendLine("}")

    $insertBefore = "//--------------------------------------------------------------------------------------------------`r`nvoid libKPVP_gt_player_defeated_Init"
    if ($text -notlike "*$insertBefore*") {
        $insertBefore = "//--------------------------------------------------------------------------------------------------`nvoid libKPVP_gt_player_defeated_Init"
    }
    if ($text -notlike "*$insertBefore*") {
        throw "Could not find insertion point for test commander function in $LibPath"
    }
    $text = $text.Replace($insertBefore, ($functionBlock.ToString() + $insertBefore))

    $runtimeCommanderLine = 'auto0C816381_val = libKPVP_gf_codex_commander_attribute_for_runtime_player(lv_player);'
    $lobbyCommanderLine = 'auto0C816381_val = GameAttributePlayerValue("[bnet:local/0.0/223536]1", lv_player);'
    if ($text.Contains($lobbyCommanderLine)) {
        $newText = $text.Replace($lobbyCommanderLine, $runtimeCommanderLine)
    }
    elseif ($text.Contains($runtimeCommanderLine)) {
        $newText = $text
    }
    else {
        throw "Could not find commander attribute assignment in $LibPath"
    }

    if ($newText -notmatch "libKPVP_gf_codex_post_lobby_init\(\);") {
        $newText = $newText.Replace("    UnitEventSetNullVariableInvalid(true);", "    UnitEventSetNullVariableInvalid(true);`r`n    libKPVP_gf_codex_post_lobby_init();")
    }

    Set-FileTextWithRetry -Path $LibPath -Text $newText
}
