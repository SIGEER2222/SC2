# Alenger3 指挥官 CommanderAchUnit 注册修复

## 日期
2026-07-06

## 问题描述
将 3疯批帝国 mod 移植为起义狂潮项目的 Alenger3 指挥官后，7vs1 测试地图启动时持续报 ScriptError：
```
'gt_Initialization_Func'出现触发器错误：无法找到目录条目''
   Near line 5125 in libNtve_gf_CreateUnitsWithDefaultFacing() in TriggerLibs/NativeLib.galaxy
'gt_Initialization_Func'出现触发器错误：指定的单位类型无效: ''
```

## 根本原因
`libE0EAE146_gf_InitializeBase` 函数（LibE0EAE146.galaxy 第 1604 行）在地图初始化时会调用：
- `libNtve_gf_CreateUnitsWithDefaultFacing(1, libE0EAE146_gf_CommanderAchUnit("CommandCenter"), ...)` （第 1665 行）
- `libNtve_gf_CreateUnitsWithDefaultFacing(1, libE0EAE146_gf_CommanderAchUnit("Worker"), ...)` （第 1686/1694 行）
- `libNtve_gf_CreateUnitsWithDefaultFacing(1, libE0EAE146_gf_CommanderAchUnit("SecondUnit"), ...)` （第 1698 行）

`libE0EAE146_gf_CommanderAchUnit` 函数（LibE0EAE146_RuntimeSafety.galaxy 第 571-1419 行）负责根据当前指挥官返回对应的基础单位 ID（主基地/工人/第二单位）。该函数有多个指挥官分支（Raynor/Kerrigan/Abathur/Mengsk/Tychus 等），但**没有 Alenger3 分支**。

函数末尾的默认 fallback 逻辑：
1. `UserDataGetUnit("CommanderAch", ...)` - Alenger3 未在 CommanderAch UserData 中注册，返回空
2. Terran 指挥官列表（第 1182 行）- 不包含 Alenger3
3. Zerg 指挥官列表（第 1232 行）- 不包含 Alenger3
4. Protoss 指挥官列表（第 1304 行）- 不包含 Alenger3
5. 最终 `return lv_unit;` - lv_unit 初始值为空字符串

因此 `libNtve_gf_CreateUnitsWithDefaultFacing(1, "", ...)` 被调用，触发 ScriptError。

## 修复方案
在 `libE0EAE146_gf_CommanderAchUnit` 函数末尾（Protoss 分支之后、`return lv_unit;` 之前）添加 Alenger3 分支：

```galaxy
// Alenger3 (3疯批帝国): 使用 mod 自带单位作为开局基础
if (lv_commander == "Alenger3") {
    if (lp_field == "CommandCenter") {
        lv_unit = libE0EAE146_gf_CatalogUnitOrEmpty("3diguoqianshaojidi");
        if (lv_unit != "") {
            return lv_unit;
        }
        return libE0EAE146_gf_CatalogUnitOrEmpty("CommandCenter");
    }
    if (lp_field == "Worker") {
        lv_unit = libE0EAE146_gf_CatalogUnitOrEmpty("3diguolaogong");
        if (lv_unit != "") {
            return lv_unit;
        }
        return libE0EAE146_gf_CatalogUnitOrEmpty("SCV");
    }
    if (lp_field == "SecondUnit") {
        lv_unit = libE0EAE146_gf_CatalogUnitOrEmpty("3diguojianzhengzhe");
        if (lv_unit != "") {
            return lv_unit;
        }
        return libE0EAE146_gf_CatalogUnitOrEmpty("Marine");
    }
}
```

## 单位 ID 说明
从 Alenger3 mod（3疯批帝国.SC2Mod）的 UnitData.xml 和 RaceData.xml 中提取：
- `3diguoqianshaojidi`（帝国前哨基地）：建筑，有 Structure 属性、TownAlert/TownCamera 标志、ResourceDropOff，是主基地
- `3diguolaogong`（帝国劳工）：工人单位
- `3diguojianzhengzhe`（帝国见证者）：第二单位（战斗单位）

## 诊断过程
1. 验证 Alenger3.SC2Mod 已正确安装到游戏目录
2. 验证 DocumentHeader 和 DocumentInfo 都包含 Alenger3.SC2Mod 依赖
3. 验证 UnitData.xml 中存在 `3diguojianzhengzhe` 和 `3liequanbudui` 等单位 ID
4. 发现 `gf_CommanderStartSquadsCreateUnitsResolved4` 在单位类型为空时会 return（第 789-791 行），不会调用 `libNtve_gf_CreateUnitsWithDefaultFacing`，所以错误不来自 CommanderStartSquads 分支
5. 追踪 `gt_Initialization_Func` → `libE0EAE146_gf_InitializeConfiguredMapScenario` → `libE0EAE146_gf_InitializeMapBaseScenario` → `libE0EAE146_gf_InitializeBase`
6. 在 `libE0EAE146_gf_InitializeBase` 中找到 3 处直接调用 `libNtve_gf_CreateUnitsWithDefaultFacing` 传入 `libE0EAE146_gf_CommanderAchUnit(...)` 返回值
7. 确认 `libE0EAE146_gf_CommanderAchUnit` 没有 Alenger3 分支

## 经验总结
1. **新指挥官注册 checklist**：除了 RuntimeSafety 双向映射、LibKPVP_Commander bank key、CommanderStartSquads 开局队伍外，**必须**在 `libE0EAE146_gf_CommanderAchUnit` 中注册 CommandCenter/Worker/SecondUnit 映射，否则地图初始化时会因单位类型为空报 ScriptError
2. **ScriptError "无法找到目录条目''"**：通常意味着 `libNtve_gf_CreateUnitsWithDefaultFacing` 或类似函数被传入了空字符串作为单位类型参数。需要追踪调用栈找出空字符串的来源
3. **`gf_CommanderStartSquadsCreateUnitsResolved4` 是安全的**：它在单位类型为空时会 return，不会触发 ScriptError。但 `libE0EAE146_gf_InitializeBase` 中的 3 处调用是直接传参，没有空字符串保护
4. **mod 自包含单位的 fallback 设计**：注册新指挥官时，主单位用 mod 自带 ID，fallback 用标准单位（CommandCenter/SCV/Marine），确保即使 mod 未加载也能生成基础单位

## 相关文件
- `Mods/7vs1/CoopZeroPop.SC2Mod/Base.SC2Data/LibE0EAE146_RuntimeSafety.galaxy`（修改）
- `Mods/7vs1/CoopZeroPop.SC2Mod/Base.SC2Data/LibE0EAE146.galaxy`（参考，第 1604-1782 行 InitializeBase 函数）
- `Mods/7vs1/CoopZeroPop.SC2Mod/Base.SC2Data/LibE0EAE146_CommanderStartSquads.galaxy`（参考，第 785-794 行 CreateUnitsResolved4 函数）
- `Mods/7vs1/Alenger3.SC2Mod/Base.SC2Data/GameData/UnitData.xml`（单位 ID 来源）

## 测试结果
- wait-for-game-ready.ps1: exit 0
- Alerts.txt appeared: 是
- ScriptError: Not detected
- 游戏进程存活: 44.2 秒
