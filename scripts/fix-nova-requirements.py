import re

file_path = "E:/Code/MyMod/SC2/合作指挥官-起义狂潮/Mods/7vs1/CoopZeroPop.SC2Mod/Base.SC2Data/GameData/UnitData.xml"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Barracks TrainGhostNova: 加 Requirements="HaveNovaCommander"
content = content.replace(
    '<LayoutButtons index="20" Face="TrainGhostNova" AbilCmd="BarracksTrainNova,Train3" Column="2"/>',
    '<LayoutButtons index="20" Face="TrainGhostNova" AbilCmd="BarracksTrainNova,Train3" Requirements="HaveNovaCommander" Column="2"/>'
)

# 2. Barracks TrainMarauderNova: Requirements="" -> Requirements="HaveNovaCommander"
content = content.replace(
    '<LayoutButtons index="22">\n                <Face value="TrainMarauderNova"/>\n                <Type value="AbilCmd"/>\n                <AbilCmd value="BarracksTrainNova,Train2"/>\n                <Requirements value=""/>\n                <Row value="0"/>\n                <Column value="1"/>\n            </LayoutButtons>',
    '<LayoutButtons index="22">\n                <Face value="TrainMarauderNova"/>\n                <Type value="AbilCmd"/>\n                <AbilCmd value="BarracksTrainNova,Train2"/>\n                <Requirements value="HaveNovaCommander"/>\n                <Row value="0"/>\n                <Column value="1"/>\n            </LayoutButtons>'
)

# 3. Barracks MasteryNovaArmyAttackSpeedAppend: 加 HaveNovaCommander 到需求
content = content.replace(
    '<LayoutButtons index="21">\n                <Face value="MasteryNovaArmyAttackSpeedAppend"/>\n                <Type value="Passive"/>\n                <AbilCmd value=""/>\n                <Requirements value="HaveMasteryNovaArmyAttackSpeed"/>\n                <Row value="1"/>\n                <Column value="0"/>\n            </LayoutButtons>',
    '<LayoutButtons index="21">\n                <Face value="MasteryNovaArmyAttackSpeedAppend"/>\n                <Type value="Passive"/>\n                <AbilCmd value=""/>\n                <Requirements value="HaveNovaCommanderAndMasteryNovaArmyAttackSpeed"/>\n                <Row value="1"/>\n                <Column value="0"/>\n            </LayoutButtons>'
)

# 4. Barracks MasteryNovaArmyOOCRegenSpeedAppend: 加 HaveNovaCommander 到需求
content = content.replace(
    '<LayoutButtons Face="MasteryNovaArmyOOCRegenSpeedAppend" Type="Passive" Requirements="HaveMasteryNovaArmyOOCRegenSpeed" Row="1" Column="1"/>',
    '<LayoutButtons Face="MasteryNovaArmyOOCRegenSpeedAppend" Type="Passive" Requirements="HaveNovaCommanderAndMasteryNovaArmyOOCRegenSpeed" Row="1" Column="1"/>'
)

# 5. Factory TrainHellbatNova
content = content.replace(
    '<LayoutButtons index="22" Face="TrainHellbatNova" AbilCmd="FactoryTrainNova,Train3" Column="0"/>',
    '<LayoutButtons index="22" Face="TrainHellbatNova" AbilCmd="FactoryTrainNova,Train3" Requirements="HaveNovaCommander" Column="0"/>'
)

# 6. Factory TrainSiegeTankNova
content = content.replace(
    '<LayoutButtons index="23" Face="TrainSiegeTankNova" AbilCmd="FactoryTrainNova,Train2" Row="0" Column="2"/>',
    '<LayoutButtons index="23" Face="TrainSiegeTankNova" AbilCmd="FactoryTrainNova,Train2" Requirements="HaveNovaCommander" Row="0" Column="2"/>'
)

# 7. Factory TrainGoliathNova
content = content.replace(
    '<LayoutButtons index="24" Face="TrainGoliathNova" AbilCmd="FactoryTrainNova,Train1" Column="1"/>',
    '<LayoutButtons index="24" Face="TrainGoliathNova" AbilCmd="FactoryTrainNova,Train1" Requirements="HaveNovaCommander" Column="1"/>'
)

# 8. Factory MasteryNovaArmyAttackSpeedAppend
content = content.replace(
    '<LayoutButtons index="25">\n                <Face value="MasteryNovaArmyAttackSpeedAppend"/>\n                <Type value="Passive"/>\n                <AbilCmd value=""/>\n                <Requirements value="HaveMasteryNovaArmyAttackSpeed"/>\n                <Row value="1"/>\n                <Column value="0"/>\n            </LayoutButtons>',
    '<LayoutButtons index="25">\n                <Face value="MasteryNovaArmyAttackSpeedAppend"/>\n                <Type value="Passive"/>\n                <AbilCmd value=""/>\n                <Requirements value="HaveNovaCommanderAndMasteryNovaArmyAttackSpeed"/>\n                <Row value="1"/>\n                <Column value="0"/>\n            </LayoutButtons>'
)

# 9. Factory MasteryNovaArmyOOCRegenSpeedAppend
content = content.replace(
    '<LayoutButtons index="27" Face="MasteryNovaArmyOOCRegenSpeedAppend" Requirements="HaveMasteryNovaArmyOOCRegenSpeed"/>',
    '<LayoutButtons index="27" Face="MasteryNovaArmyOOCRegenSpeedAppend" Requirements="HaveNovaCommanderAndMasteryNovaArmyOOCRegenSpeed"/>'
)

# 10. Starport TrainBansheeNova (index=17)
content = content.replace(
    '<LayoutButtons index="17" Face="TrainBansheeNova" AbilCmd="StarportTrainNova,Train1" Column="1"/>',
    '<LayoutButtons index="17" Face="TrainBansheeNova" AbilCmd="StarportTrainNova,Train1" Requirements="HaveNovaCommander" Column="1"/>'
)

# 11. Starport TrainLiberatorNova
content = content.replace(
    '<LayoutButtons index="19" Face="TrainLiberatorNova" AbilCmd="StarportTrainNova,Train3" Row="0"/>',
    '<LayoutButtons index="19" Face="TrainLiberatorNova" AbilCmd="StarportTrainNova,Train3" Requirements="HaveNovaCommander" Row="0"/>'
)

# 12. Starport TrainBansheeNova (index=20, duplicate?)
content = content.replace(
    '<LayoutButtons index="20" Face="TrainBansheeNova" AbilCmd="StarportTrainNova,Train1" Column="1"/>',
    '<LayoutButtons index="20" Face="TrainBansheeNova" AbilCmd="StarportTrainNova,Train1" Requirements="HaveNovaCommander" Column="1"/>'
)

# 13. Starport TrainRavenNova
content = content.replace(
    '<LayoutButtons index="22" Face="TrainRavenNova" AbilCmd="StarportTrainNova,Train2" Column="2"/>',
    '<LayoutButtons index="22" Face="TrainRavenNova" AbilCmd="StarportTrainNova,Train2" Requirements="HaveNovaCommander" Column="2"/>'
)

# 14. Starport MasteryNovaArmyAttackSpeedAppend (index=24)
content = content.replace(
    '<LayoutButtons index="24" Face="MasteryNovaArmyAttackSpeedAppend" Requirements="HaveMasteryNovaArmyAttackSpeed"/>',
    '<LayoutButtons index="24" Face="MasteryNovaArmyAttackSpeedAppend" Requirements="HaveNovaCommanderAndMasteryNovaArmyAttackSpeed"/>'
)

# 15. Starport MasteryNovaArmyOOCRegenSpeedAppend (index=25)
content = content.replace(
    '<LayoutButtons index="25" Face="MasteryNovaArmyOOCRegenSpeedAppend" Requirements="HaveMasteryNovaArmyOOCRegenSpeed" Column="1"/>',
    '<LayoutButtons index="25" Face="MasteryNovaArmyOOCRegenSpeedAppend" Requirements="HaveNovaCommanderAndMasteryNovaArmyOOCRegenSpeed" Column="1"/>'
)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("UnitData.xml 更新完成")
