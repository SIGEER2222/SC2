"""
从 collect_commander_units.py 的输出中过滤掉状态变体（Burrowed/Flying/Uprooted/Lowered），
生成 LibEmptyTestCatalog.galaxy。
"""
import sys
import os

# 状态变体后缀 - 这些不是独立单位，只是状态切换
STATE_SUFFIXES = ["Burrowed", "Flying", "Uprooted", "Lowered"]

# WarpGate 是 Gateway 的活跃状态变体，但可以保留（折跃门机制）
# SupplyDepotLowered 是降落后的补给站，不保留

def is_state_variant(uid):
    """判断是否为状态变体"""
    for suffix in STATE_SUFFIXES:
        if uid.endswith(suffix) and uid != suffix:  # 避免误判
            return True
    if uid == "WarpGate":
        return False  # 保留折跃门
    return False

def main():
    # 124 个单位（从 collect_commander_units.py 输出）
    all_units = [
        "Larva", "Drone", "Overlord", "Corruptor",
        "Zergling", "Hydralisk", "Mutalisk", "Ultralisk", "Roach",
        "Infestor", "Viper", "SwarmHostMP", "Baneling",
        "HotSHunter", "HotSSplitterlingBig", "Scourge",
        "Brutalisk", "Pygalisk", "ZerglingToxic", "FrostFiend",
        "BileTitan", "Igniter", "Ravager", "HunterKiller",
        "Hydralisk2", "MutaliskChar", "Mamba", "MutaliskAnkylos",
        "Mesmer", "BaneHost", "VespidHost", "UltraliskSavage",
        "UltraliskKaldir", "IzshaGuardian", "Kraken", "Blightbringer",
        "Omegalisk", "Leviathan", "DefilerMP", "BroodLord",
        "Hatchery", "CreepTumor", "Extractor", "SpawningPool",
        "EvolutionChamber", "HydraliskDen", "Spire", "UltraliskCavern",
        "InfestationPit", "NydusNetwork", "BanelingNest", "RoachWarren",
        "SpineCrawler", "SporeCrawler", "PrimalSunkenColony",
        "CommandCenter", "SupplyDepot", "Refinery", "Barracks",
        "EngineeringBay", "MissileTurret", "Bunker", "SensorTower",
        "GhostAcademy", "Factory", "Starport", "Armory",
        "FusionCore", "HeavyTurret", "PerditionTurret", "EarthsplitterOrdnance",
        "PsiDisruptor", "DominionGarrison", "ThrallHatchery",
        "RoyalBarracks", "RoyalFactory", "RoyalStarport",
        "Nexus", "Pylon", "Assimilator", "Gateway", "Forge",
        "FleetBeacon", "TwilightCouncil", "PhotonCannon", "Stargate",
        "TemplarArchive", "DarkShrine", "RoboticsBay", "RoboticsFacility",
        "CyberneticsCore", "PsiLinkSpire",
        "DroneBurrowed", "Overseer", "ZerglingBurrowed", "HydraliskBurrowed",
        "UltraliskBurrowed", "RoachBurrowed", "InfestorBurrowed",
        "SwarmHostBurrowedMP", "BanelingBurrowed", "ToxicZerglingBurrowed",
        "FrostFiendBurrowed", "IgniterBurrowed", "RavagerBurrowed",
        "HydraliskParalyticBurrowed", "BaneHostBurrowed", "SavageBurrowed",
        "DefilerMPBurrowed",
        "Lair", "Hive", "CreepTumorBurrowed", "GreaterSpire",
        "SpineCrawlerUprooted", "SporeCrawlerUprooted",
        "CommandCenterFlying", "PlanetaryFortress", "OrbitalCommand",
        "OrbitalCommandFlying", "SupplyDepotLowered",
        "BarracksFlying", "FactoryFlying", "StarportFlying", "WarpGate",
    ]
    
    # 过滤掉状态变体
    filtered = [u for u in all_units if not is_state_variant(u)]
    
    print(f"原始: {len(all_units)} 个")
    print(f"过滤后: {len(filtered)} 个")
    print(f"移除的状态变体:")
    removed = [u for u in all_units if is_state_variant(u)]
    for u in removed:
        print(f"  - {u}")
    print()
    
    # 生成 galaxy 代码
    n = len(filtered)
    print(f"// Abathur 单位列表 ({n} 个，含升级/变异链)")
    print(f"const int gv_c_EmptyTestCommanderCount = 1;")
    print(f"const int gv_c_EmptyTestTotalUnits = {n};")
    print()
    print(f'string[1] gv_EmptyTestCommanders;')
    print(f'int[1] gv_EmptyTestUnitOffsets;')
    print(f'int[1] gv_EmptyTestUnitCounts;')
    print(f'string[{n}] gv_EmptyTestUnits;')
    print()
    print(f'void libEmptyTestCatalog_InitLib () {{')
    print(f'    gv_EmptyTestCommanders[0] = "Reborn";')
    print(f'    gv_EmptyTestUnitOffsets[0] = 0;')
    print(f'    gv_EmptyTestUnitCounts[0] = {n};')
    print()
    for i, u in enumerate(filtered):
        print(f'    gv_EmptyTestUnits[{i}] = "{u}";')
    print(f'}}')

if __name__ == "__main__":
    main()
