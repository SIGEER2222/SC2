import re
import sys

catalog_path = r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods\emptytest.SC2Map\Base.SC2Data\LibEmptyTestCatalog.galaxy"
alerts_path = r"C:\Users\22448\Documents\StarCraft II\GameLogs\2026-07-04 19.45.24 Alerts.txt"
output_path = catalog_path

fallback_units = set()
with open(alerts_path, "r", encoding="utf-8", errors="ignore") as f:
    for line in f:
        m = re.search(r'Scope\[([^\]]+), Unit\] Unable to create unit actor.*fallback sphere', line)
        if m:
            fallback_units.add(m.group(1))

print(f"Fallback units found: {len(fallback_units)}")

with open(catalog_path, "r", encoding="utf-8") as f:
    content = f.read()

unit_pattern = re.compile(r'gv_EmptyTestUnits\[(\d+)\] = "([^"]+)"')
units = unit_pattern.findall(content)
print(f"Total units in catalog: {len(units)}")

filtered_units = [(idx, name) for idx, name in units if name not in fallback_units]
print(f"Units after filtering: {len(filtered_units)}")

new_content_lines = []
init_start = content.find("void libEmptyTestCatalog_InitLib () {")
init_end = content.find("}", init_start)
prefix = content[:init_start]
suffix = content[init_end:]

new_content_lines.append(prefix)
new_content_lines.append("void libEmptyTestCatalog_InitLib () {\n")
new_content_lines.append('    gv_EmptyTestCommanders[0] = "Reborn";\n')
new_content_lines.append('    gv_EmptyTestUnitOffsets[0] = 0;\n')
new_content_lines.append(f'    gv_EmptyTestUnitCounts[0] = {len(filtered_units)};\n\n')

for new_idx, (old_idx, name) in enumerate(filtered_units):
    new_content_lines.append(f'    gv_EmptyTestUnits[{new_idx}] = "{name}";\n')

new_content_lines.append("}\n")

final_content = "".join(new_content_lines)

const_total = re.search(r'const int gv_c_EmptyTestTotalUnits = (\d+);', final_content)
if const_total:
    final_content = final_content.replace(
        f'const int gv_c_EmptyTestTotalUnits = {const_total.group(1)};',
        f'const int gv_c_EmptyTestTotalUnits = {len(filtered_units)};'
    )

array_decl = re.search(r'string\[(\d+)\] gv_EmptyTestUnits;', final_content)
if array_decl:
    final_content = final_content.replace(
        f'string[{array_decl.group(1)}] gv_EmptyTestUnits;',
        f'string[{len(filtered_units)}] gv_EmptyTestUnits;'
    )

with open(output_path, "w", encoding="utf-8") as f:
    f.write(final_content)

print(f"Written to {output_path}")
print(f"Filtered out {len(units) - len(filtered_units)} units with missing models")
