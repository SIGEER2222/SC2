"""分析 Unit 冲突分类"""
import json
from collections import Counter
from pathlib import Path

report_path = Path(r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮\docs\reborn-port\catalog-diff.json")
with open(report_path, "r", encoding="utf-8") as f:
    data = json.load(f)

# Unit redefined conflicts
unit_conflicts = [c for c in data["conflicts"] if c["cat_name"] == "Unit" and c["conflict_type"] == "redefined"]
print(f"Total Unit redefined: {len(unit_conflicts)}")
print()

# Group by prefix
prefixes = Counter()
for c in unit_conflicts:
    eid = c["entry_id"]
    if eid.startswith("SI"):
        prefixes["SI_*"] += 1
    elif eid.startswith("Primal"):
        prefixes["Primal*"] += 1
    elif eid.startswith("Crys"):
        prefixes["Crys*"] += 1
    elif eid.startswith("Story"):
        prefixes["Story*"] += 1
    elif eid.startswith("ZSwarm"):
        prefixes["ZSwarm*"] += 1
    elif eid.startswith("Zerg"):
        prefixes["Zerg*"] += 1
    elif eid.startswith("Terran"):
        prefixes["Terran*"] += 1
    elif eid.startswith("Protoss"):
        prefixes["Protoss*"] += 1
    elif eid.startswith("Marine"):
        prefixes["Marine*"] += 1
    elif eid.startswith("Marauder"):
        prefixes["Marauder*"] += 1
    elif eid.startswith("Barracks"):
        prefixes["Barracks*"] += 1
    elif eid.startswith("Factory"):
        prefixes["Factory*"] += 1
    elif eid.startswith("Starport"):
        prefixes["Starport*"] += 1
    elif eid.startswith("Command"):
        prefixes["Command*"] += 1
    elif eid.startswith("Supply"):
        prefixes["Supply*"] += 1
    elif eid.startswith("Raven"):
        prefixes["Raven*"] += 1
    elif eid.startswith("Battle"):
        prefixes["Battle*"] += 1
    elif eid.startswith("Siege"):
        prefixes["Siege*"] += 1
    elif eid.startswith("Ghost"):
        prefixes["Ghost*"] += 1
    elif eid.startswith("Reaper"):
        prefixes["Reaper*"] += 1
    elif eid.startswith("Viking"):
        prefixes["Viking*"] += 1
    elif eid.startswith("Banshee"):
        prefixes["Banshee*"] += 1
    elif eid.startswith("Medivac"):
        prefixes["Medivac*"] += 1
    elif eid.startswith("Thor"):
        prefixes["Thor*"] += 1
    elif eid.startswith("Hellion"):
        prefixes["Hellion*"] += 1
    elif eid.startswith("Widow"):
        prefixes["Widow*"] += 1
    elif eid.startswith("Cyclone"):
        prefixes["Cyclone*"] += 1
    elif eid.startswith("Liberator"):
        prefixes["Liberator*"] += 1
    elif eid.startswith("SCV"):
        prefixes["SCV*"] += 1
    elif eid.startswith("Orbital"):
        prefixes["Orbital*"] += 1
    elif eid.startswith("Bunker"):
        prefixes["Bunker*"] += 1
    elif eid.startswith("Missile"):
        prefixes["Missile*"] += 1
    elif eid.startswith("Sensor"):
        prefixes["Sensor*"] += 1
    elif eid.startswith("Engineering"):
        prefixes["Engineering*"] += 1
    elif eid.startswith("Armory"):
        prefixes["Armory*"] += 1
    elif eid.startswith("Fusion"):
        prefixes["Fusion*"] += 1
    elif eid.startswith("TechLab"):
        prefixes["TechLab*"] += 1
    elif eid.startswith("Reactor"):
        prefixes["Reactor*"] += 1
    elif eid.startswith("Nuke"):
        prefixes["Nuke*"] += 1
    elif eid.startswith("Auto"):
        prefixes["Auto*"] += 1
    elif eid.startswith("Turret"):
        prefixes["Turret*"] += 1
    elif eid.startswith("Academy"):
        prefixes["Academy*"] += 1
    elif eid.startswith("Planetary"):
        prefixes["Planetary*"] += 1
    elif eid.startswith("Drone"):
        prefixes["Drone*"] += 1
    elif eid.startswith("Larva"):
        prefixes["Larva*"] += 1
    elif eid.startswith("Queen"):
        prefixes["Queen*"] += 1
    elif eid.startswith("Overlord"):
        prefixes["Overlord*"] += 1
    elif eid.startswith("Overseer"):
        prefixes["Overseer*"] += 1
    elif eid.startswith("Hydralisk"):
        prefixes["Hydralisk*"] += 1
    elif eid.startswith("Roach"):
        prefixes["Roach*"] += 1
    elif eid.startswith("Baneling"):
        prefixes["Baneling*"] += 1
    elif eid.startswith("Mutalisk"):
        prefixes["Mutalisk*"] += 1
    elif eid.startswith("Corruptor"):
        prefixes["Corruptor*"] += 1
    elif eid.startswith("Infestor"):
        prefixes["Infestor*"] += 1
    elif eid.startswith("Ultralisk"):
        prefixes["Ultralisk*"] += 1
    elif eid.startswith("Brood"):
        prefixes["Brood*"] += 1
    elif eid.startswith("Swarm"):
        prefixes["Swarm*"] += 1
    elif eid.startswith("Viper"):
        prefixes["Viper*"] += 1
    elif eid.startswith("Lurker"):
        prefixes["Lurker*"] += 1
    elif eid.startswith("Extractor"):
        prefixes["Extractor*"] += 1
    elif eid.startswith("Spawning"):
        prefixes["Spawning*"] += 1
    elif eid.startswith("Evolution"):
        prefixes["Evolution*"] += 1
    elif eid.startswith("Spine"):
        prefixes["Spine*"] += 1
    elif eid.startswith("Spore"):
        prefixes["Spore*"] += 1
    elif eid.startswith("Hatchery"):
        prefixes["Hatchery*"] += 1
    elif eid.startswith("Creep"):
        prefixes["Creep*"] += 1
    elif eid.startswith("Nydus"):
        prefixes["Nydus*"] += 1
    elif eid.startswith("Infested"):
        prefixes["Infested*"] += 1
    elif eid.startswith("Lair"):
        prefixes["Lair*"] += 1
    elif eid.startswith("Hive"):
        prefixes["Hive*"] += 1
    elif eid.startswith("Greater"):
        prefixes["Greater*"] += 1
    elif eid.startswith("Ravager"):
        prefixes["Ravager*"] += 1
    elif eid.startswith("Abathur"):
        prefixes["Abathur*"] += 1
    elif eid.startswith("Dehaka"):
        prefixes["Dehaka*"] += 1
    elif eid.startswith("Izsha"):
        prefixes["Izsha*"] += 1
    elif eid.startswith("Zagara"):
        prefixes["Zagara*"] += 1
    elif eid.startswith("Kerrigan"):
        prefixes["Kerrigan*"] += 1
    elif eid.startswith("Stukov"):
        prefixes["Stukov*"] += 1
    elif eid.startswith("Raynor"):
        prefixes["Raynor*"] += 1
    elif eid.startswith("Swann"):
        prefixes["Swann*"] += 1
    elif eid.startswith("Karax"):
        prefixes["Karax*"] += 1
    elif eid.startswith("Vorazun"):
        prefixes["Vorazun*"] += 1
    elif eid.startswith("Alarak"):
        prefixes["Alarak*"] += 1
    elif eid.startswith("Fenix"):
        prefixes["Fenix*"] += 1
    elif eid.startswith("Nova"):
        prefixes["Nova*"] += 1
    elif eid.startswith("Horner"):
        prefixes["Horner*"] += 1
    elif eid.startswith("Tychus"):
        prefixes["Tychus*"] += 1
    elif eid.startswith("Zeratul"):
        prefixes["Zeratul*"] += 1
    elif eid.startswith("Mengsk"):
        prefixes["Mengsk*"] += 1
    elif eid.startswith("Stetmann"):
        prefixes["Stetmann*"] += 1
    elif eid.startswith("Artanis"):
        prefixes["Artanis*"] += 1
    else:
        prefixes[eid[:10]] += 1

print("Unit conflict prefixes:")
for prefix, count in prefixes.most_common(30):
    print(f"  {prefix:30s}: {count:4d}")

# Also show Reborn-only and 7vs1-only
reborn_only = [c for c in data["conflicts"] if c["cat_name"] == "Unit" and c["conflict_type"] == "reborn_only"]
seven_only = [c for c in data["conflicts"] if c["cat_name"] == "Unit" and c["conflict_type"] == "7vs1_only"]
print(f"\nReborn-only units: {len(reborn_only)}")
print(f"7vs1-only units: {len(seven_only)}")

# Show some Reborn-only unit IDs
print("\nSample Reborn-only units (first 20):")
for c in reborn_only[:20]:
    print(f"  {c['entry_id']}")

print("\nSample 7vs1-only units (first 20):")
for c in seven_only[:20]:
    print(f"  {c['entry_id']}")