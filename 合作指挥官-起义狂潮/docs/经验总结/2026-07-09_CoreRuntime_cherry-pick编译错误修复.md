# CoreRuntime cherry-pick 后编译错误修复

## 日期
2026-07-09

## 问题描述
将 fix_004 分支的提交 cherry-pick 到 fix_003 后，扩展 mod 从 CoopZeroPop 切换到 CoreRuntime，但 CoreRuntime 缺少多个必要的符号声明和库引用，导致游戏脚本编译失败，出现一连串错误。

## 错误链（按修复顺序）
1. `LibCOMI.galaxy (1009) InitProtCounters 未定义` → CampaignAI.galaxy 缺少桩函数
2. `LibE0EAE146_AlarakRuntime.galaxy (18) 无效的参数列表` → GameData.xml 缺少 TriggerLibs 注册
3. `LibKMIS.galaxy (4378) 解析函数行出错` → SoACasterUnitSet 调用前缀错误 + 函数未定义
4. `LibKCUI.galaxy (2774) 初始化变量时出错` → libKMIS_gv_cMC_SOATARGETCOUNTMAX 未声明
5. `LibE0EAE146_KaraxRuntime.galaxy (297) 解析函数行出错` → libKMIS_gv_cM_SoATargetingOrder 未声明 + LibE0EAE146_h 不 include LibKMIS_h
6. `LibE0EAE146_KaraxRuntime.galaxy (304) 解析函数行出错` → libE0EAE146_gt_CM_SoAOrbitalStrikeActivatedKarax 触发器未声明
7. `LibE0EAE146_StukovRuntime.galaxy (95) 解析函数行出错` → LibE0EAE146.galaxy 缺少 6 个库 include
8. `LibE0EAE146_NovaRuntime.galaxy (242) 解析函数行出错` → libKMIS_gv_cM_SoATargetingExecuteCommand 未声明
9. `函数已声明但尚未定义` → libKMIS_gf_CM_SoATargetingModeEnter 有声明无定义

## 修复内容

### 1. GameData.xml 添加 TriggerLibs 注册
CoreRuntime 的 GameData.xml 原本只注册 81FF3B49，缺少 KPVP/KCOR/KMIS/KCUI。
```xml
<TriggerLibs index="2" Id="KPVP" IncludePath=""/>
<TriggerLibs index="3" Id="KCOR" IncludePath=""/>
<TriggerLibs index="4" Id="KMIS" IncludePath=""/>
<TriggerLibs index="5" Id="KCUI" IncludePath=""/>
```

### 2. CampaignAI.galaxy 桩函数
创建空桩函数覆盖官方 CampaignAI.galaxy，避免 AICounterUnitSetup 不兼容错误，同时提供 LibCOMI 调用所需的 5 个函数定义。

### 3. LibE0EAE146.galaxy 添加缺失的 include
CoopZeroPop 有 10 个库 include（排除死代码 LibDA886FA0），CoreRuntime 只有 4 个。添加 6 个缺失的：
- LibC0F50AA6（Mengsk hash 库）
- LibDF8E6945（Dehaka hash 库）
- LibBE3BBD9F（Stukov creep 库）
- Lib0940FFB7（Nova hash 库）
- Lib4B62E36B（Swann hash 库）
- Lib975E2FE9（Stetmann hash 库）

同时添加对应的 InitVariables 调用。

### 4. LibE0EAE146_h.galaxy 添加 include "LibKMIS_h"
CoopZeroPop 通过 `include "LibKPVP_h"` → KCOR → KMIS 链间接解析 KMIS 符号。CoreRuntime 直接 `include "LibKMIS_h"`。

### 5. LibKMIS_h.galaxy 恢复完整 SOA 声明集
从 CoopZeroPop 复制 38 行 SOA 相关声明（常量、变量、函数声明、触发器声明）。CoreRuntime 原本完全缺少这些声明。

### 6. LibKMIS.galaxy 添加函数定义
- `libKMIS_gf_CM_SoACasterUnitSet`：从 CoopZeroPop 复制
- `libKMIS_gf_CM_SoATargetingModeEnter`：简化版实现（不引用 SetFogAlphaOverTime 等外部依赖）
- 将 SoACasterUnitSet 调用从 `libE0EAE146_` 前缀改回 `libKMIS_` 前缀

### 7. 新增文件
- `LibE0EAE146_CommanderPowerProfile.galaxy`：从 CoopZeroPop 复制
- `DocumentHeader`：CoreRuntime 和 CommanderBridge 各一份

## 核心经验

### cherry-pick 架构切换的陷阱
cherry-pick 将扩展 mod 从 CoopZeroPop 切换到 CoreRuntime，但 CoreRuntime 是新建的 mod，缺少 CoopZeroPop 中长期积累的：
- TriggerLibs 注册
- 库 include 语句
- 符号声明（特别是 SOA Targeting 相关的 38 行声明）
- 桩函数文件（CampaignAI.galaxy）
- DocumentHeader

### SOA Targeting 符号迁移不完整
cherry-pick 试图将 SOA Targeting 从 `libKMIS_` 前缀迁移到 `libE0EAE146_` 前缀，但：
1. 只修改了一处调用（SoACasterUnitSet）
2. 三层架构新建的 Runtime 文件（KaraxRuntime、FenixRuntime、NovaRuntime）仍引用 `libKMIS_` SOA 变量
3. SOATargeting 的 include 被移除，但 LibKMIS 中的符号引用仍在

解决方案：在 LibKMIS_h.galaxy 中恢复完整的 SOA 声明集，在 LibKMIS.galaxy 中提供函数定义。

### 错误链式排查法
SC2 编译错误是级联的：一个文件的语法错误会导致后续文件报错。排查时应：
1. 每次只修复第一个错误
2. 重启游戏测试
3. 重复直到无编译错误
4. 最终检查运行时警告

### 加载时间超时问题
26 个 mod 依赖链的加载时间可能超过 wait-for-game-ready.ps1 的 180 秒超时。解决方案：直接等待 240 秒后检查 GameLogs 目录。
