# Reborn 地图 ScriptError 编译错误修复

## 问题

`zexpedition03_reborn_port` 地图启动后 SC2 报告 ScriptError，galaxy 脚本编译失败：

```
LibE0EAE146.galaxy (3),  无法找到Include文件: include "Lib67C0F0E7"
LibE0EAE146.galaxy (15), 无法找到Include文件: include "LibE0EAE146_MutatorRuntime"
LibE0EAE146.galaxy (22), 解析函数行出错: include "LibE0EAE146_BiomassRules"
LibE0EAE146_AdapterBootstrap.galaxy (7-17), 无法找到Include文件: include "LibA1ADAPTER" ... "LibA13ADAPTER"
脚本读取失败：解析函数行出错
```

虽然 SC2 进程仍在运行（CPU/内存增长），但脚本逻辑不会正确执行。**ScriptError 是首要诊断指标**——只要存在 ScriptError，即使游戏不崩溃也视为编译失败。

## 根因

`launch-reborn-commander.ps1` 存在三个问题：

### 1. AdapterBootstrap include 失败
`LibE0EAE146_AdapterBootstrap.galaxy` include 了 11 个 `LibA*ADAPTER` 库，这些库分别在各自的 `Alenger*Adapter.SC2Mod` 中。启动脚本未同步这些 Adapter mod，导致 `LibA*ADAPTER.galaxy` 未被复制到地图 `Base.SC2Data` 目录。

### 2. Clean-MapRuntimeLibraries 误删地图自带库
Clean 函数无差别删除所有 `Lib*.galaxy` 文件，包括地图自带的 `Lib48DF4533.galaxy` 和 `Lib48DF4533_h.galaxy`。这些是地图原始库文件，不在任何 7vs1 mod 中，删除后无法恢复，导致 `MapScript.galaxy` 的 include 链断裂。

参考脚本 `launch-7vs1-coop-test.ps1` 的 Clean 函数保留了 `LibEmptyTest*.galaxy`，Reborn 脚本没有类似的保留逻辑。

### 3. CommanderUnits_RaynorX 未同步
`LibE0EAE146.galaxy` 第 41 行 include `LibE0EAE147_RaynorXRuntime`，该文件在 `CommanderUnits_RaynorX.SC2Mod` 中，但启动脚本的 `$allCommanderUnitsMods` 列表没有包含此 mod。

## 修复

### 修复 1：同步 Alenger*Adapter mods
在启动脚本添加 11 个 Adapter mod 的同步：
```powershell
$adapterMods = @(
    "7vs1\Alenger1Adapter.SC2Mod"
    ...
    "7vs1\Alenger13Adapter.SC2Mod"
)
foreach ($mod in $adapterMods) { Sync-Mod $mod }
```

### 修复 2：Clean 函数保留地图自带 galaxy 文件
修改 `Clean-MapRuntimeLibraries`，构建源地图 galaxy 文件名集合，只删除运行时注入的文件：
```powershell
$sourceMapBaseData = Join-Path $ProjRoot "Maps\$MapName\Base.SC2Data"
$preserveNames = @{}
if (Test-Path $sourceMapBaseData) {
    $sourceGalaxyFiles = Get-ChildItem $sourceMapBaseData -File -Filter "*.galaxy"
    foreach ($gf in $sourceGalaxyFiles) { $preserveNames[$gf.Name] = $true }
}
# 删除时跳过 preserveNames 中的文件
```

### 修复 3：添加 CommanderUnits_RaynorX 同步
在 `$allCommanderUnitsMods` 数组中添加 `"7vs1\CommanderUnits_RaynorX.SC2Mod"`。

## 验证

修复后重新启动，等待 120 秒，检查 GameLogs：
- **无 ScriptError.txt**（编译成功）
- SC2 进程正常运行（2.8GB 内存）
- Alerts.txt 只有非致命的 "技能过多" data 警告

## 可复用经验

1. **ScriptError 优先于一切**：游戏运行不等于脚本正确。只要有 ScriptError，脚本逻辑就不会执行。诊断 SC2 mod 问题时首先检查 `C:\Users\22448\Documents\StarCraft II\GameLogs\*ScriptError.txt`。

2. **include 解析顺序**：SC2 编译器按顺序解析 include，前一个失败可能导致后续 include 全部报告"无法找到"。看到大量"无法找到 Include 文件"时，先修复第一个错误的 include，可能级联解决其他错误。

3. **Clean 函数必须保留地图自带文件**：任何 Clean 函数都要参考 `launch-7vs1-coop-test.ps1` 的实现——构建"源地图自有文件"白名单，只清理运行时注入的文件。无差别删除 `Lib*.galaxy` 会破坏地图原始 include 链。

4. **CommanderUnits 列表必须完整**：`LibE0EAE146.galaxy` 的 include 列表决定了需要同步的 CommanderUnits mods。任何新增的 `include "LibE0EAE147_*"` 都要确认对应 mod 在同步列表中。参考 `launch-7vs1-coop-test.ps1` 的 `Get-SplitCatalogModDependencies` 函数获取完整列表。

5. **galaxy 文件注入机制**：SC2 在地图 `Base.SC2Data/` 和 mod 的 `Base.SC2Data/` 中搜索 include 文件。Reborn 地图采用"复制 galaxy 到地图目录"的方式（与参考 7vs1 地图"空 Base.SC2Data + mod 依赖链"不同），需要确保所有 include 的 galaxy 文件都被复制到地图目录。
