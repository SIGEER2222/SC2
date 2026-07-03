# emptytest 测试图加载指挥官所有单位

## 日期
2026-07-03

## 背景
将空白地图 `Mods/emptytest.SC2Map` 改造成测试图：根据 `-Commanders` 参数指定指挥官，在地图上动态生成该指挥官的所有建筑/单位实例，方便人工排查。

## 实施方案
1. **数据层**: Python 脚本 `scripts/_gen_emptytest_catalog.py` 扫描 `CommanderCatalog.SC2Mod\Base.SC2Data\GameData\UnitData_*.xml`，按种族归属分配 `Shared_*` 文件单位到对应指挥官，生成 `Mods/emptytest.SC2Map\Base.SC2Data\LibEmptyTestCatalog.galaxy` 查表库。
2. **代码层**: `MapScript.galaxy` include CoopZeroPop 7vs1 框架所需的所有运行时库 + `LibEmptyTestCatalog`，新增 spawn 触发器调用 `libKPVP_gf_CodexPrimaryCommanderName()` 取当前指挥官后，按查表在地图上排布生成实例。
3. **依赖层**: `launch-7vs1-coop-test.ps1` 的 `Sync-LiveMapRuntimeLibraries` 函数已自动注入 CoopZeroPop + CommanderCatalog 依赖。

## 关键经验

### 1. Galaxy 数组声明语法（重要）
Galaxy 数组声明语法是 `type[N] varname;`，**不是** C 风格的 `type varname[N];`。

正确：
```c
string[19] gv_commanders;
int[19] gv_counts;
```

错误（会触发"Galaxy数组的定义需要在类型后添加维度"编译错误）：
```c
string gv_commanders[19];    // ❌ C 风格
int gv_counts[19];            // ❌
```

参考其他库的真实写法（如 `LibE0EAE146_h.galaxy` 第 41 行 `string[9] libE0EAE146_gv_xmProgressionSelectedBlessing;`）。

### 2. Galaxy 不支持 const 数组初始化列表
Galaxy 的 `const` 只能用于标量，不能用 `const type[N] var = [...];` 形式初始化数组。

错误：
```c
const string[19] gv_c_commanders = [    // ❌ 编译失败
    "Abathur",
    ...
];
```

正确做法：用普通数组 + 在 `_InitLib()` 函数里逐个赋值：
```c
string[19] gv_commanders;

void libX_InitLib () {
    gv_commanders[0] = "Abathur";
    gv_commanders[1] = "Alarak";
    ...
}
```

### 3. CommanderCatalog Shared_* 文件按种族归属分配
`CommanderCatalog.SC2Mod\Base.SC2Data\GameData\` 下有大量 `UnitData_Shared_*.xml` 文件，包含多个指挥官共享的单位定义。归属规则：

| 文件 | 接收单位的所有指挥官 |
|------|---------------------|
| `Shared_Protoss` | Artanis, Vorazun, Zeratul, Karax, Alarak, Fenix |
| `Shared_Terran_A_G` + `Shared_Terran_H` + `Shared_Terran_I_V` | Raynor, Nova, Swann, Tychus, Horner, Mengsk, Stukov |
| `Shared_Zerg` | Kerrigan, Abathur, AbathurReborn, Zagara, Dehaka, Stukov |
| `Shared_InfestedTerran` | Stukov 专属 |
| `Shared_Neutral_H` + `Shared_Neutral_I_M` + `Shared_Neutral_N_Z` | 所有指挥官（中立单位） |
| `Shared_PurifierZerg` | 跳过（只含 MISSILE 不可生成） |

### 4. 启动脚本 Sync 函数会删除地图自带 Lib*.galaxy
`launch-7vs1-coop-test.ps1` 的 `Sync-LiveMapRuntimeLibraries` 函数会先删除地图 `Base.SC2Data` 下所有 `Lib*.galaxy`，再从 CoopZeroPop 复制 runtime 库。

如果地图自带测试库（如 `LibEmptyTestCatalog.galaxy`），需要修改删除逻辑加 `-notlike` 例外：
```powershell
Get-ChildItem -LiteralPath $mapBaseDataRoot -Filter 'Lib*.galaxy' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike 'LibEmptyTest*.galaxy' } | ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Force
}
```

### 5. 从 Bank 读取当前指挥官
7vs1 框架的 `libKPVP_gf_CodexPrimaryCommanderName()` 函数从 `CampaignXCore` bank（玩家 1）的 `XMRuntimeControl` section 读取 `CommanderP1` 或 `PrimaryCommander` key，返回指挥官短名（如 `"Kerrigan"`、`"Tychus"`、`"TestZerg"`）。

`-Commanders @("ZergKerrigan")` 参数会通过启动脚本写入 bank，运行时可通过这个 API 读取。

### 6. 文件名 → 指挥官短名映射需手动维护
`UnitData_*.xml` 文件名和指挥官短名（Bank 中的 PrimaryCommander 值）不完全一致：

| 文件名 | 指挥官短名 |
|--------|-----------|
| `UnitData_Kerrigan.xml` | Kerrigan |
| `UnitData_Raynor.xml` + `UnitData_RaynorX.xml` | Raynor（合并去重） |
| `UnitData_TychusXM.xml` | Tychus（文件名带 XM 后缀） |
| `UnitData_Reborn.xml` | AbathurReborn（不是 Reborn） |
| `UnitData_Stetmann.xml` | Stetmann |

需要在 Python 脚本的 `COMMANDER_NAME_MAP` 字典中维护映射关系。

## 文件清单
- `scripts/_gen_emptytest_catalog.py` - 生成脚本（扫描 XML 生成 galaxy 库）
- `Mods/emptytest.SC2Map/Base.SC2Data/LibEmptyTestCatalog.galaxy` - 自动生成的查表库（168 KB，19 个指挥官共 3500+ 单位）
- `Mods/emptytest.SC2Map/MapScript.galaxy` - 测试图主脚本（含 spawn 触发器）
- `scripts/launch-7vs1-coop-test.ps1` - 启动脚本（修改 Sync 函数保留测试库）

## 测试结果
- ZergKerrigan 测试通过：60.6 秒加载完成，无 ScriptError，游戏进程存活
- Kerrigan 清单含 181 个单位（33 个 Kerrigan 专属 + 9 个 Shared_Zerg + 139 个 Shared_Neutral_*）

## 用法
```powershell
.\scripts\launch-7vs1-coop-test.ps1 `
  -MapSource ".\Mods\emptytest.SC2Map" `
  -LiveMapName "emptytest.SC2Map" `
  -Commanders @("ZergKerrigan")
```

修改 `-Commanders` 参数测试不同指挥官。重新生成清单后需要重启游戏。

## 已知局限
1. 部分指挥官（Stetmann 61 单位）未加入 Shared_* 分组，清单可能不全。Stetmann 的种族归属不明确（既非纯 Zerg 也非纯 Terran），目前只列其专属文件单位。
2. 清单含部分非"主要"单位（如 Cocoon、Burrowed、Uprooted 等状态变体），地图上排布可能拥挤。
3. Raynor 单位数最多（295 个），在地图上排布为 19 行 × 16 列，会占用较大区域。
