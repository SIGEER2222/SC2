"""追加 Alenger3 指挥官条目到 commander-power-metadata.json"""
import json
from pathlib import Path

meta_path = Path(r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Shared\CommanderPower\commander-power-metadata.json")
with open(meta_path, "r", encoding="utf-8") as f:
    data = json.load(f)

# 检查是否已存在
existing = [c for c in data["commanders"] if c.get("runtime_commander") == "TerranAlenger3"]
if existing:
    print(f"[SKIP] 已存在 TerranAlenger3 条目，将移除后重新添加")
    data["commanders"] = [c for c in data["commanders"] if c.get("runtime_commander") != "TerranAlenger3"]

# 新增 Alenger3 条目（最小字段，无 prestiges/masteries）
alenger3_entry = {
    "runtime_commander": "TerranAlenger3",
    "bank_commander": "Alenger3",
    "generated_commander": "Alenger3",
    "official_folder": "Alenger3",
    "official_short_id": "Alenger3",
    "display_name": "疯批帝国",
    "default_upgrades": [],
    "default_ability_commands": [],
    "bank_keys": {
        "profile": "Alenger3.Profile",
        "enable_prestiges": "Alenger3.EnablePrestiges",
        "prestige_bonus_mask": "Alenger3.PrestigeBonusMask",
        "prestige_mask": "Alenger3.PrestigeMask",
        "prestige_point_index": "Alenger3.PrestigePointIndex",
        "prestige_index": "Alenger3.PrestigeIndex",
        "enable_masteries": "Alenger3.EnableMasteries",
        "mastery_default": "Alenger3.MasteryDefault",
        "mastery_slots": [
            "Alenger3.Mastery0", "Alenger3.Mastery1", "Alenger3.Mastery2",
            "Alenger3.Mastery3", "Alenger3.Mastery4", "Alenger3.Mastery5"
        ]
    },
    "prestiges": [],
    "masteries": [],
    "start_talents": [],
    "note": "从 3疯批帝国.SC2Mod 移植，自带 LibDE538C36 运行时"
}

data["commanders"].append(alenger3_entry)

with open(meta_path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"已追加 TerranAlenger3 条目")
print(f"当前指挥官总数: {len(data['commanders'])}")
print(f"runtime_commander 列表:")
for c in data["commanders"]:
    print(f"  - {c.get('runtime_commander')}: {c.get('display_name')}")
