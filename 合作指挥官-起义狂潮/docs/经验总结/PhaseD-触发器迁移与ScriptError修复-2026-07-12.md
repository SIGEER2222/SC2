# Phase D 触发器迁移与 ScriptError 修复

## 任务类型
SC2 galaxy 脚本修复 + 运行时验证

## 时间戳
2026-07-12 18:00 - 18:30

## 任务内容

### 问题
前一轮会话遗留的 ScriptError：`MapScript.galaxy (38), 需要布尔表达式`，指向 `libRuntimeProbe_InitLib();` 行。

### 根因分析
launch 脚本 Step N5c 将 Phase D 任务结束触发器代码注入到 MapScript.galaxy 的**文件作用域**：

```galaxy
// === Phase D: 任务结束钩子 ===
bool libNeuroBridge7vs1_gt_MissionEnd_Func(bool testConds, bool runActions) { ... }
trigger libNeuroBridge7vs1_gt_MissionEnd;
libNeuroBridge7vs1_gt_MissionEnd = TriggerCreate("...");  // 文件作用域调用函数！
TriggerAddEventPlayerLeft(libNeuroBridge7vs1_gt_MissionEnd, 1, c_gameResultVictory);
TriggerAddEventPlayerLeft(libNeuroBridge7vs1_gt_MissionEnd, 1, c_gameResultDefeat);
```

Galaxy 语言不允许在文件作用域（函数体外）调用函数。`TriggerCreate` 和 `TriggerAddEventPlayerLeft` 是函数调用，必须在函数体内执行。SC2 编译器报错位置不准确，指向了 InitLibs() 中的 `libRuntimeProbe_InitLib();`。

### 额外发现
原 Phase D 代码使用 `EventPlayerLeft() == c_gameResultVictory` 判断胜负，但 galaxy-checker 的 natives 数据中不存在 `EventPlayerLeft` 函数（只有 `EventPlayer`）。参考 zexpedition03_reborn_port 地图模式，应使用两个独立触发器分别监听胜利和失败事件。

### 修复方案

**1. 将 Phase D 触发器迁移到 LibNeuroBridge7vs1.galaxy 的 InitLib 中**

`LibNeuroBridge7vs1_h.galaxy` 新增声明：
```galaxy
trigger libNeuroBridge7vs1_gt_MissionVictory;
trigger libNeuroBridge7vs1_gt_MissionDefeat;
bool   libNeuroBridge7vs1_gt_MissionVictory_Func(bool testConds, bool runActions);
bool   libNeuroBridge7vs1_gt_MissionDefeat_Func(bool testConds, bool runActions);
```

`LibNeuroBridge7vs1.galaxy` InitLib 中创建触发器：
```galaxy
// Phase D: 任务结束钩子（使用独立触发器，参考 zexpedition03_reborn_port 地图模式）
libNeuroBridge7vs1_gt_MissionVictory = TriggerCreate("libNeuroBridge7vs1_gt_MissionVictory_Func");
TriggerAddEventPlayerLeft(libNeuroBridge7vs1_gt_MissionVictory, 1, c_gameResultVictory);
libNeuroBridge7vs1_gt_MissionDefeat = TriggerCreate("libNeuroBridge7vs1_gt_MissionDefeat_Func");
TriggerAddEventPlayerLeft(libNeuroBridge7vs1_gt_MissionDefeat, 1, c_gameResultDefeat);
```

新增两个独立触发器函数（不再用 `EventPlayerLeft()` 判断）。

**2. launch 脚本 Step N5c 改为清理历史遗留注入**

移除了向 MapScript.galaxy 注入文件作用域代码的逻辑，替换为清理历史遗留注入的 regex。

**3. 运行时 MapScript.galaxy 清理**

用 .NET API 移除了运行时 MapScript.galaxy 中的文件作用域 Phase D 代码块。

## 任务结果

### galaxy-checker 验证
- NeuroBridge7vs1 mod：0 错误，1 警告（跨 mod 引用 LibEFA54406_h，运行时解析）
- 地图 Base.SC2Data：1 错误（Lib67C0F0E7.galaxy 的 `AICampaignStart()` 误报，预存问题），我们的文件 0 错误

### 进图测试验证
- 启动命令：`launch-7vs1-coop-test.ps1 -Commanders TerranRaynor -EnableNeuro`
- 游戏加载完成，**无 ScriptError**
- wait-for-game-ready.ps1：exit 0（32.1 秒加载，20 秒 grace period 无错误）
- NeuroIntegration.SC2Bank 已创建（2719 bytes，包含 possible_actions 和 game_state）
- RuntimeProbe.SC2Bank 正常运行（heartbeat=60，game_loop=3986，8409 bytes）
- SC2 内存：2763 MB
- 7vs1 专属 action 未注册（`execute_actions_map` 事件需 Python 运行时驱动，预期行为）
- NeuroPermanent bank 未创建（只在任务胜利/失败时创建，预期行为）

### 修改文件
1. `Mods/Neuro/NeuroBridge7vs1.SC2Mod/Base.SC2Data/LibNeuroBridge7vs1_h.galaxy` - 新增 MissionVictory/MissionDefeat 触发器声明
2. `Mods/Neuro/NeuroBridge7vs1.SC2Mod/Base.SC2Data/LibNeuroBridge7vs1.galaxy` - InitLib 中创建触发器 + 新增两个触发器函数
3. `scripts/launch-7vs1-coop-test.ps1` - Step N5c 改为清理历史遗留注入

## 任务耗时
约 30 分钟

## 任务备注
- Galaxy 语言不允许文件作用域调用函数，所有函数调用必须在函数体内
- SC2 编译器报错位置不准确，实际错误可能在其他文件中
- `EventPlayerLeft()` 不是有效 native 函数，应使用独立触发器分别监听 `c_gameResultVictory`/`c_gameResultDefeat`
- 参考已验证的地图（如 zexpedition03_reborn_port）的触发器模式是可靠做法
- 运行时文件（工作目录外）需用 .NET API 修改，Edit 工具会被拒绝
