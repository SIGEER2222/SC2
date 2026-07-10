# 本地化扫描工具

扫描 `zhCN` 本地化文件中未翻译的英文文本。

## 工具路径

```powershell
python 合作指挥官-起义狂潮/scripts/scan_english_text.py [选项]
```

## 选项

| 选项 | 说明 |
|------|------|
| `--summary` | 只输出统计摘要 |
| `--player-only` | 只显示玩家可见的文本 |
| `--fix-report` | 输出需要修复的清单 |

## 扫描范围

- `Mods/7vs1/*` - 7vs1 合作指挥官 Mod
- `XM/*` - XM 扩展 Mod
- `Maps/*` - 所有地图

## 分类逻辑

- **玩家可见** (`[玩家]`): Button/Name, Button/Tooltip, Unit/Name, Abil/Name, Upgrade/Name, Behavior/Name, Weapon/Name 等 GameStrings 中的文本
- **编辑器内部** (`[内部]`): Effect/Name, Variable/Name, Trigger/Name 等，通常无需翻译
- **自动跳过**: XML 标记（`<s val=`, `<IMG path=`, `<d ref=` 等）、纯代码标识符

## 典型工作流

1. 运行摘要扫描：`python scripts/scan_english_text.py --summary`
2. 查看玩家可见问题：`python scripts/scan_english_text.py --player-only`
3. 手动修复 `GameStrings.txt` 中的英文 value
4. 重新扫描验证

## 结果文件

详细结果输出到 `scripts/scan_english_text_result.json`。