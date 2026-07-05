units = [
    'Drone',
    'Zergling',
    'Overlord',
    'Hydralisk',
    'Mutalisk',
    'Ultralisk',
    'Roach',
    'Infestor',
    'Corruptor',
    'Viper',
    'SwarmHostMP',
    'Baneling',
    'HotSHunter',
    'HotSSplitterlingBig',
    'Scourge',
    'Brutalisk',
    'Pygalisk',
    'ZerglingToxic',
    'FrostFiend',
    'BileTitan',
    'Igniter',
    'Ravager',
    'HunterKiller',
    'Hydralisk2',
    'MutaliskChar',
    'Mamba',
    'MutaliskAnkylos',
    'Mesmer',
    'BaneHost',
    'VespidHost',
    'UltraliskSavage',
    'UltraliskKaldir',
    'IzshaGuardian',
    'Kraken',
    'Blightbringer',
    'Omegalisk',
    'Leviathan',
    'DefilerMP',
    'BroodLord',
    'Hatchery',
    'CreepTumor',
    'Extractor',
    'SpawningPool',
    'EvolutionChamber',
    'HydraliskDen',
    'Spire',
    'UltraliskCavern',
    'InfestationPit',
    'NydusNetwork',
    'BanelingNest',
    'RoachWarren',
    'SpineCrawler',
    'SporeCrawler',
    'PrimalSunkenColony',
]

n = len(units)
print(f'//================================================================================')
print(f'// LibEmptyTestCatalog.galaxy - Abathur 专属单位 ({n}个)')
print(f'// 来源：重生虫心扫描 - Abathur_专属单位.txt')
print(f'//================================================================================')
print()
print(f'const int gv_c_EmptyTestCommanderCount = 1;')
print(f'const int gv_c_EmptyTestTotalUnits = {n};')
print()
print(f'string[1] gv_EmptyTestCommanders;')
print(f'int[1] gv_EmptyTestUnitOffsets;')
print(f'int[1] gv_EmptyTestUnitCounts;')
print(f'string[{n}] gv_EmptyTestUnits;')
print()
print(f'void libEmptyTestCatalog_InitLib () {{')
print(f'    gv_EmptyTestCommanders[0] = "Abathur";')
print(f'    gv_EmptyTestUnitOffsets[0] = 0;')
print(f'    gv_EmptyTestUnitCounts[0] = {n};')
print()
for i, u in enumerate(units):
    print(f'    gv_EmptyTestUnits[{i}] = "{u}";')
print(f'}}')
