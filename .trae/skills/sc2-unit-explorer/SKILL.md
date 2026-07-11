---
name: "sc2-unit-explorer"
description: "Scans SC2 mods to extract unit/building/ability relationships without launching the game. Invoke when user wants to analyze a mod's unit production chains, tech tree, or commander-specific units, or asks 'what units does mod X add / which units can Y build'."
---

# SC2 Unit Explorer

This skill analyzes StarCraft 2 mods (`.SC2Mod` / `.sc2mod`) offline and extracts complete unit relationships — abilities, production, construction, research, weapons, reverse dependencies, and galaxy runtime modifications — without launching the game.

## Tool Location

- **CLI 入口**: `E:\Code\MyMod\SC2\tools\sc2-galaxy-toolkit\packages\sc2-unit-explorer\lib\src\cli.js`
- **源码**: `E:\Code\MyMod\SC2\tools\sc2-galaxy-toolkit\packages\sc2-unit-explorer\src\cli.ts`
- **运行时**: Node.js (>=22.0.0)
- **底层**: TypeScript monorepo（sc2-data + sc2-galaxy-lang + sc2-unit-explorer）

## 相比旧 Python 版的增强

- **Galaxy 运行时解析**: 基于 AST 提取 `UnitAbilityAdd` / `TechTreeUnitAllow` / `TechTreeAbilityAllow` 及 `gf_*` 封装函数，不再仅限于静态 XML
- **深度 XML 合并**: 完整 SC2 合并语义（id/index/Row+Column/value/Link 匹配 + removed="1" + 递归合并）
- **反向索引**: 谁生产我 / 谁建造我 / 谁变异成我
- **Parent 继承链**: 递归合并父类属性
- **性能**: 72 个 galaxy 文件 0 解析错误，326 个科技树操作，与 Python regex 完全一致

## When to Invoke

- 用户问 "mod X 新增了哪些单位 / 有什么建筑 / 能生产什么"
- 用户想扫描 mod 的指挥官专属单位
- 用户想对比不同 mod 的单位生产链
- 用户问单位关系（谁能生产 X，Y 能生产什么，反向依赖）
- 用户想从 mod 的 `UnitData.xml` 提取单位列表
- 用户想识别 mod 原创单位（排除 SC2 原版单位）
- 用户想了解 galaxy 脚本运行时对单位/能力的动态修改

## Core Mod Loading Chain

工具默认按顺序合并多层 mod（后者覆盖前者）:

1. **Base SC2 mods**（始终先加载）:
   - `E:\Code\MyMod\SC2\sc2-data-trigger\mods\core.sc2mod`
   - `E:\Code\MyMod\SC2\sc2-data-trigger\mods\liberty.sc2mod`
   - `E:\Code\MyMod\SC2\sc2-data-trigger\mods\swarm.sc2mod`
   - `E:\Code\MyMod\SC2\sc2-data-trigger\mods\void.sc2mod`
   - `E:\Code\MyMod\SC2\合作指挥官-起义狂潮\游戏数据\官方SC2原始文本镜像\mods\starcoop\starcoop.sc2mod`
   - `E:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods\7vs1\CoopZeroPop.SC2Mod`

2. 自动追加 `Mods\7vs1\` 和 `XM\` 下所有 `*.SC2Mod` 子目录

3. 可用 `--only-mod` 覆盖默认加载链

## Commands

### 调用模板

```powershell
node "E:\Code\MyMod\SC2\tools\sc2-galaxy-toolkit\packages\sc2-unit-explorer\lib\src\cli.js" [选项] [UnitID]
```

### 1. 列出所有单位

```powershell
node "...\cli.js" --list-units
```

带正则过滤:
```powershell
node "...\cli.js" --list-units --filter "^Larva"
```

### 2. 列出所有能力

```powershell
node "...\cli.js" --list-abilities --filter "Train$"
```

### 3. 查询单位完整关系（text 格式）

```powershell
node "...\cli.js" Larva
node "...\cli.js" Barracks --depth 2
```

### 4. 查询单位完整关系（json 格式）

```powershell
node "...\cli.js" Marine --format json
```

### 5. 只加载指定 mod（跳过默认链）

```powershell
node "...\cli.js" Drone --only-mod "E:\...\core.sc2mod" --only-mod "E:\...\liberty.sc2mod" --only-mod "E:\...\MyMod.SC2Mod"
```

### 6. 追加 mod 到默认链

```powershell
node "...\cli.js" Drone --mod "E:\...\ExtraMod.SC2Mod"
```

### 7. 跳过 galaxy 运行时解析（加快加载）

```powershell
node "...\cli.js" Larva --no-galaxy
```

### 8. 输出到文件

```powershell
node "...\cli.js" Larva --out "E:\...\larva.txt"
node "...\cli.js" --list-units --out "E:\...\units.txt"
```

## Parameters

| 参数 | 说明 |
|------|------|
| `--list-units` | 列出所有单位 ID + 名称 |
| `--list-abilities` | 列出所有能力 ID |
| `--filter REGEX` | 配合 --list-* 使用，正则过滤（不区分大小写） |
| `<UnitID>` | 位置参数：查询指定单位 |
| `--depth N` | 关系展开深度（默认 1，建议 hero 用 3） |
| `--format text\|json` | 输出格式（默认 text） |
| `--mod PATH` | 追加 mod 路径（在默认基础 mod 之后） |
| `--only-mod PATH` | 只使用指定的 mod（跳过默认基础 mod，可重复） |
| `--no-galaxy` | 跳过 galaxy 脚本运行时解析 |
| `--out FILE` | 输出到文件（默认 stdout） |

## Relationship Output (per unit)

每个查询单位会输出:

- **基本信息**: unitId, name, race, parent, attributes
- **科技树状态**: galaxy 运行时 `TechTreeUnitAllow` 的解锁/锁定状态
- **能力** (AbilArray + CardLayouts + galaxy 运行时注入): 标记 `[运行时]` 的为 `UnitAbilityAdd` 动态注入
- **可生产** (CAbilTrain): 该单位能训练的单位
- **可建造** (CAbilBuild): 该单位能建造的建筑
- **可研究** (CAbilResearch): 该单位能研究的升级
- **可变异为** (CAbilMorph): 该单位能变异成的单位
- **武器** (WeaponArray)
- **被生产** (反向): 谁能生产这个单位
- **被建造** (反向): 谁能建造这个单位
- **变异来源** (反向): 谁能变异成这个单位
- **卡牌布局** (CardLayouts): 按 (Row, Column) 去重

## Merge Semantics

- `id` / `index` / `Row+Column` / `value` / `Link` 关键属性匹配
- `removed="1"` 删除匹配元素
- 递归合并子元素
- Parent 继承链：子类优先，保留父类独有数据

## PowerShell Wrapper Pattern

批量扫描多个指挥官:

```powershell
$CLI = "E:\Code\MyMod\SC2\tools\sc2-galaxy-toolkit\packages\sc2-unit-explorer\lib\src\cli.js"

# 列出所有单位
& node $CLI --list-units --out "units.txt" 2>$null

# 查询单个单位详情
& node $CLI Larva --out "larva.txt" 2>$null
& node $CLI Barracks --depth 2 --format json --out "barracks.json" 2>$null

# 批量查询
$units = @("Larva", "Drone", "SCV", "Probe", "Barracks", "Gateway")
foreach ($u in $units) {
    & node $CLI $u --depth 1 2>$null | Out-File -FilePath "detail_$u.txt" -Encoding utf8 -Append
}
```

## Output Redirection

- `--out FILE` 直接写入文件（UTF-8）
- 或用 PowerShell 管道: `2>$null | Out-File -FilePath <path> -Encoding utf8`
- `2>$null` 抑制 stderr（加载日志、警告）

## Known Limitations

- 本地化文本需要 mod 的 `zhCN.SC2Data/LocalizedData/GameStrings.txt`，缺失时显示原始 ID
- `--depth 3` 在大型 mod（3000+ 单位）下较慢，建议批量扫描用 `--depth 1`，hero 单位用 `--depth 3`
- Binder/Checker 暂未集成（sc2-galaxy-lang 的类型检查需要完整 SymbolStore），当前仅用 AST 遍历

## Build (开发用)

如需修改源码后重新构建:

```powershell
cd "E:\Code\MyMod\SC2\tools\sc2-galaxy-toolkit"
pnpm -r run build
```

## Reference Implementations

现有包装脚本（基于旧 Python 版，可参考改造）:
- `合作指挥官-起义狂潮/scripts/scan_crys_with_abathur.ps1` — 扫描 mod 原创指挥官
- `其他mod/RevolutionOverdrive缝合版/_scan_all_factions.ps1` — 批量扫描 5 个阵营
