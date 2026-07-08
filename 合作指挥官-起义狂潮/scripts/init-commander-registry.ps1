# init-commander-registry.ps1
# Initialize Shared/Commanders/ JSON configs (pure ASCII to avoid gb2312 encoding issues).
# Display names are resolved by web-launcher from GameStrings.txt; not stored here.

$ErrorActionPreference = 'Stop'
$projectRoot = Resolve-Path "$PSScriptRoot\.."
$outDir = Join-Path $projectRoot 'Shared\Commanders'

$traeWrite = Join-Path $projectRoot 'scripts\trae-write.ps1'
if (-not (Test-Path $traeWrite)) {
    $traeWrite = 'c:\Users\22448\.trae-cn\skills\file-ops\scripts\trae-write.ps1'
}

if (-not (Test-Path $outDir)) {
    $traeMkdir = Join-Path $projectRoot 'scripts\trae-mkdir.ps1'
    if (-not (Test-Path $traeMkdir)) {
        $traeMkdir = 'c:\Users\22448\.trae-cn\skills\file-ops\scripts\trae-mkdir.ps1'
    }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $traeMkdir $outDir
}

# Each commander config. runtime_init points to galaxy function name (without lib prefix).
# special_init types: create_caster_unit / init_veterancy / add_supply
$commanders = @(
    @{ file='Raynor.json'; json=@{ runtime_name='Raynor'; race='Terran'; console_skin='ConsoleTerran_Default'; runtime_init='RaynorRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@('TerranRaynor'); runtime_checkpoints=@('InitializeBase.beforeRaynorRuntime','InitializeBase.afterRaynorRuntime') } },
    @{ file='RaynorX.json'; json=@{ runtime_name='RaynorX'; race='Terran'; console_skin='ConsoleTerran_Default'; runtime_init='RaynorXRuntimeInit'; runtime_init_lib='libE0EAE147'; special_init=@(); supply_bonus=0; aliases=@(); runtime_checkpoints=@('InitializeBase.beforeRaynorXRuntime','InitializeBase.afterRaynorXRuntime') } },
    @{ file='Kerrigan.json'; json=@{ runtime_name='Kerrigan'; race='Zerg'; console_skin='ConsoleZerg_Default'; runtime_init='KerriganRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } },
    @{ file='TestZerg.json'; json=@{ runtime_name='TestZerg'; race='Zerg'; console_skin='ConsoleZerg_Default'; runtime_init='TestZergRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } },
    @{ file='Abathur.json'; json=@{ runtime_name='Abathur'; race='Zerg'; console_skin='ConsoleZerg_Abathur'; runtime_init='AbathurRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@('AbathurCustom'); runtime_checkpoints=@() } },
    @{ file='AbathurReborn.json'; json=@{ runtime_name='AbathurReborn'; race='Zerg'; console_skin='ConsoleZerg_Abathur'; runtime_init='AbathurRebornRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } },
    @{ file='Zagara.json'; json=@{ runtime_name='Zagara'; race='Zerg'; console_skin='ConsoleZerg_Zagara'; runtime_init='ZagaraRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } },
    @{ file='Alarak.json'; json=@{ runtime_name='Alarak'; race='Protoss'; console_skin='ConsoleProtoss_Forged'; runtime_init='AlarakRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } },
    @{ file='Artanis.json'; json=@{ runtime_name='Artanis'; race='Protoss'; console_skin='ConsoleProtoss_Default'; runtime_init='ArtanisRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } },
    @{ file='Fenix.json'; json=@{ runtime_name='Fenix'; race='Protoss'; console_skin='ConsoleProtoss_Fenix'; runtime_init='FenixRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } },
    @{ file='Karax.json'; json=@{ runtime_name='Karax'; race='Protoss'; console_skin='ConsoleProtoss_Default'; runtime_init='KaraxRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } },
    @{ file='Vorazun.json'; json=@{ runtime_name='Vorazun'; race='Protoss'; console_skin='ConsoleProtoss_Default'; runtime_init='VorazunRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } },
    @{ file='Zeratul.json'; json=@{ runtime_name='Zeratul'; race='Protoss'; console_skin='ConsoleProtoss_Ihanrii'; runtime_init='ZeratulRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } },
    @{ file='Stukov.json'; json=@{ runtime_name='Stukov'; race='Zerg'; console_skin='ConsoleZerg_Classic'; runtime_init='StukovRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } },
    @{ file='Dehaka.json'; json=@{ runtime_name='Dehaka'; race='Zerg'; console_skin='ConsoleZerg_Dehaka'; runtime_init='DehakaRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(@{type='add_supply';amount=60;rpg_only=$true}); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } },
    @{ file='Tychus.json'; json=@{ runtime_name='Tychus'; race='Terran'; console_skin='ConsoleTerran_Classic'; runtime_init='TychusRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(@{type='create_caster_unit';unit='CoopCasterTychus';gp_init_commander='Tychus';squad_init=@{hero_count=4;abil='Abil/TychusTrain';tech_type='CoopTechTychusSquad';event_structure='Event_TychusHeroStructureCreate';event_main='Event_TychusHeroMainBuilding'};rpg_only=$true}); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } },
    @{ file='Horner.json'; json=@{ runtime_name='Horner'; race='Terran'; console_skin='ConsoleTerran_Horner'; runtime_init='HornerRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@('Mira','HanHorner','HanAndHorner'); runtime_checkpoints=@() } },
    @{ file='Nova.json'; json=@{ runtime_name='Nova'; race='Terran'; console_skin='ConsoleTerran_CovertOps'; runtime_init='NovaRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } },
    @{ file='Mengsk.json'; json=@{ runtime_name='Mengsk'; race='Terran'; console_skin='ConsoleTerran_Imperial'; runtime_init='MengskRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(@{type='init_veterancy'}); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } },
    @{ file='Swann.json'; json=@{ runtime_name='Swann'; race='Terran'; console_skin='ConsoleTerran_Swann'; runtime_init='SwannRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } },
    @{ file='Stetmann.json'; json=@{ runtime_name='Stetmann'; race='Zerg'; console_skin='ConsoleZerg_Mecha'; runtime_init='StetmannRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } },
    @{ file='Izsha.json'; json=@{ runtime_name='Izsha'; race='Zerg'; console_skin=''; runtime_init='IzshaRuntimeInit'; runtime_init_lib='libE0EAE146'; special_init=@(); supply_bonus=0; aliases=@(); runtime_checkpoints=@() } }
)

$count = 0
foreach ($entry in $commanders) {
    $path = Join-Path $outDir $entry.file
    $jsonStr = $entry.json | ConvertTo-Json -Depth 10 -Compress
    & powershell -NoProfile -ExecutionPolicy Bypass -File $traeWrite $path $jsonStr
    $count++
}

Write-Host "Created $count commander JSON files in $outDir"
