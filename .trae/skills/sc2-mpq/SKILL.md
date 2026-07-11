---
name: "sc2-mpq"
description: "Pack/unpack SC2Map/SC2Mod files using MPQEditor. Invoke when editing SC2 map data files (XML) or repacking modified maps. Handles extraction and repacking with automatic script generation."
---

# SC2 MPQ 打包/解包

SC2Map/SC2Mod 文件是 MPQ (MoPaQ) 格式归档。本 skill 提供解包和打包工具。

## 工具位置

| 文件 | 用途 |
|------|------|
| `.trae/skills/sc2-mpq/MPQEditor.exe` | MPQEditor (Ladybug) 解包工具 |
| `.trae/skills/sc2-mpq/scripts/extract-sc2map.ps1` | 解包脚本 (MPQEditor + mpyq 备选) |
| `.trae/skills/sc2-mpq/scripts/extract_mpq.py` | Python mpyq 解包脚本 (备选方案) |
| `.trae/skills/sc2-mpq/scripts/pack-sc2map.ps1` | 打包包装脚本 |
| `.trae/skills/sc2-mpq/scripts/pack_mpq.py` | Python MPQ 打包脚本 (Blizzard 原始 hash) |
| `.trae/skills/sc2-mpq/scripts/verify_mpq.py` | MPQ 完整性验证脚本 |

## 解包地图

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".trae/skills/sc2-mpq/scripts/extract-sc2map.ps1" "<map_path>" "<output_dir>" "<filter>"
```

参数:
- `map_path`: SC2Map 或 SC2Mod 文件路径
- `output_dir`: 解包输出目录
- `filter`: 可选，文件过滤（默认 `*`，如 `*.xml` 只解包 XML）
- `-UseMpyq`: 强制使用 mpyq（路径含特殊字符时使用）

示例:
```powershell
# 解包所有文件
powershell -NoProfile -ExecutionPolicy Bypass -File ".trae/skills/sc2-mpq/scripts/extract-sc2map.ps1" "map.SC2Map" "extracted"

# 只解包 XML
powershell -NoProfile -ExecutionPolicy Bypass -File ".trae/skills/sc2-mpq/scripts/extract-sc2map.ps1" "map.SC2Map" "extracted" "*.xml"

# 路径含特殊字符时强制使用 mpyq
powershell -NoProfile -ExecutionPolicy Bypass -File ".trae/skills/sc2-mpq/scripts/extract-sc2map.ps1" "map~~.SC2Map" "extracted" "*" -UseMpyq
```

也可直接调用 Python:
```powershell
python .trae/skills/sc2-mpq/scripts/extract_mpq.py "map.SC2Map" "extracted" "*.xml"
```

## 打包地图

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".trae/skills/sc2-mpq/scripts/pack-sc2map.ps1" "<input_dir>" "<output_path>"
```

参数:
- `input_dir`: 解包后的目录（包含所有文件）
- `output_path`: 输出的 SC2Map/SC2Mod 文件路径

内部使用 Python 脚本 `pack_mpq.py` 直接构建 MPQ 文件，兼容 Blizzard 原始 hash 函数。

也可以直接调用 Python:
```powershell
python .trae/skills/sc2-mpq/scripts/pack_mpq.py "<input_dir>" "<output_path>"
```

示例:
```powershell
# 打包回地图
powershell -NoProfile -ExecutionPolicy Bypass -File ".trae/skills/sc2-mpq/scripts/pack-sc2map.ps1" "extracted" "new_map.SC2Map"
```

## 验证 MPQ 完整性

打包后建议验证文件完整性:
```powershell
python .trae/skills/sc2-mpq/scripts/verify_mpq.py "<mpq_path>"
```

输出所有文件是否可读，以及 MPQ header 信息。

## 典型工作流

1. 解包: `extract-sc2map.ps1 "map.SC2Map" "work" "*"`
2. 修改 `work/Base.SC2Data/GameData/` 下的 XML 数据文件
3. 打包: `pack-sc2map.ps1 "work" "map.SC2Map"`
4. 验证: `python scripts/verify_mpq.py "map.SC2Map"`
5. 进图测试

## 复制 SC2Map 文件

**重要**: MPQEditor Shell Extension 会拦截 `.SC2Map` 文件操作，导致 PowerShell 的 `Copy-Item` 失败。复制 `.SC2Map` 文件时必须使用 Python:

```python
import shutil
shutil.copyfile(src, dst)
```

## 技术细节

### MPQ 格式

MPQ 文件结构:
- Header (32 字节): magic `MPQ\x1a` + 元数据
- Hash Table: 16 字节/条目，加密存储，文件名 hash 索引
- Block Table: 16 字节/条目，加密存储，文件数据描述
- File Data: 按 sector 存储

### pack_mpq.py 实现要点

1. **Hash 函数**: 使用 Blizzard 原始加密表（256 行 × 5 列），mpyq 兼容
2. **Hash Table 字段顺序**: `name_a=HASH_A(type=1), name_b=HASH_B(type=2)` (不是 TABLE_OFFSET)
3. **加密/解密**: XOR 对称加密，seed2 更新必须使用原始值 (plaintext)，不能使用加密后的值
4. **文件存储**: 使用标准 sector-based 存储 (flags=0x80000000)，不用 SINGLE_UNIT (0x81000000)
5. **Sector Offset Table**: 文件数据前有 (num_sectors + 1) 个 uint32 条目
6. **(listfile)**: 第一个 block entry，包含所有文件名列表

### MPQEditor 的限制

- `add` 命令只能合并 MPQ 文件，不能添加普通文件
- Shell Extension 会拦截 `.SC2Map` 路径操作
- 路径含特殊字符（如 `~~`）时可能失败

### 依赖

- Python 3.x
- mpyq 库: `pip install mpyq`

## 注意事项

- 打包前确保目标输出路径不存在，或脚本会自动删除旧文件
- 路径包含中文时，`Resolve-Path` 可能无法正确解析，脚本中使用 `.NET FileInfo` 获取完整路径
- 打包后的 MPQ 文件可直接被 SC2 游戏读取（已验证 halo_v3.SC2Map 进图无 ScriptError）
- 不要用 `git add .` 暂存，只暂存明确指定的文件
