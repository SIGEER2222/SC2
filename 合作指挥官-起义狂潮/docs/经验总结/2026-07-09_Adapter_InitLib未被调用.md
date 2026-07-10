# Adapter Galaxy InitLib 未被调用导致触发器不执行

## 问题现象

7vs1 地图中 Alenger8 adapter 的 MapInit 触发器代码（升级、单位解锁、能力解锁、单位生成）全部不执行，表现为：
- 建造面板按钮缺失
- 调试生成的单位不出现
- 但游戏加载无 ScriptError（adapter galaxy 编译成功）

## 根因

7vs1 地图 `MapScript.galaxy` 的 `InitLibs()` 只调用 6 个标准库：
```galaxy
void InitLibs () {
    libNtve_InitLib();
    libLbty_InitLib();
    libCamp_InitLib();
    libA070801C_InitLib();
    lib67C0F0E7_InitLib();
    libE0EAE146_InitLib();
}
```

**adapter 的 `libA8ADAPTER_InitLib()` 从未被调用**，导致：
1. `libA8ADAPTER_InitTriggers()` 不执行
2. `TriggerCreate("libA8ADAPTER_gt_MapInit_Func")` 不执行
3. `TriggerAddEventMapInit(...)` 不执行
4. MapInit 触发器函数从未被引擎调用

### TriggerLibs 机制的误区

adapter 虽然通过 GameData.xml 注册了 `<TriggerLibs Id="A8ADAPTER"/>`，但 **TriggerLibs 只让引擎 include galaxy 文件（加载函数和变量声明），不会自动调用 InitLib**。InitLib 必须由 MapScript.galaxy 的 InitLibs() 或其他被调用的 InitLib 显式调用。

## 修复方案

新建 `LibE0EAE146_AdapterBootstrap.galaxy`（放在 CoreRuntime 中），include 所有 adapter，在 InitLib 中调用所有 adapter 的 InitLib。然后让 `LibE0EAE146.galaxy` include bootstrap 并在 `libE0EAE146_InitLib()` 中调用 `libE0EAE146_AdapterBootstrap_InitLib()`。

### 涉及文件

1. `CoreRuntime.SC2Mod/Base.SC2Data/LibE0EAE146_AdapterBootstrap_h.galaxy`（新建）：声明 InitLib 函数
2. `CoreRuntime.SC2Mod/Base.SC2Data/LibE0EAE146_AdapterBootstrap.galaxy`（新建）：include 所有 adapter，调用所有 adapter 的 InitLib
3. `CoreRuntime.SC2Mod/Base.SC2Data/LibE0EAE146.galaxy`（修改）：添加 include 和 InitLib 调用
4. `scripts/launch-7vs1-coop-test.ps1`（修改）：把 `Alenger*Adapter.SC2Mod/Base.SC2Data` 加入 galaxy 注入源

### galaxy 注入

adapter 的 galaxy 文件需要被注入到地图 Base.SC2Data 目录，否则 include 无法解析。launch 脚本的 `Sync-LiveMapRuntimeLibraries` 需要包含 adapter 的 Base.SC2Data 目录。

## 验证

修复后测试 Alenger8：
- 游戏加载成功（54.7 秒）
- 游戏进程稳定运行 >140 秒
- ScriptError 只有 Dehaka 相关的非致命警告（LibDF8E6945），无 Alenger8 adapter 错误
- adapter 代码编译成功，触发器被创建并执行

## 关键教训

1. **TriggerLibs ≠ 自动调用 InitLib**：TriggerLibs 只加载 galaxy 文件，不自动调用 InitLib
2. **mod galaxy 的 InitLib 必须被显式调用**：要么在 MapScript.galaxy 的 InitLibs() 中调用，要么在被调用的 InitLib 中调用
3. **galaxy 编译成功不代表代码执行了**：没有 ScriptError 只代表编译通过，不代表触发器被创建或执行
4. **调试单位生成时用 RegionEntireMap() 获取地图中心坐标**，避免 hardcode 坐标在地图外
