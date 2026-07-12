# RuntimeProbe galaxy 注入修复

## 任务类型
SC2 地图/Mod 运行时修复 - ScriptError 排查与修复

## 时间戳
2026-07-12 14:00 (Asia/Shanghai)

## 任务内容

### 问题背景
进图测试发现 ScriptError: "无法找到 Include 文件 LibC0F50AA6"，经过多轮排查发现根因是 MapScript.galaxy 引用了 include "LibRuntimeProbe_h"，但 launch 脚本的 Sync-LiveMapRuntimeLibraries 函数未将 RuntimeProbe mod 的 Base.SC2Data 目录加入 $RuntimeBaseRoots，导致 LibRuntimeProbe_h.galaxy 和 LibRuntimeProbe.galaxy 未被复制到地图目录。

### 排查过程
1. **尝试1（CommanderUnits 全量加载）**：失败 - ScriptError 仍存在
2. **尝试2（ComponentList 添加 Type="trig"）**：失败 - ScriptError 仍存在
3. **尝试3（删除 ComponentList 文件）**：失败 - 证明问题不在 ComponentList
4. **尝试4（添加 RuntimeProbe 到 RuntimeBaseRoots）**：部分修复 - ScriptError 从"无法找到 Include 文件"变为"函数已声明但尚未定义"
5. **尝试5（include 不带 _h 后缀）**：成功 - ScriptError 完全消除

### 根因分析
1. **galaxy 文件未注入**：launch 脚本未将 RuntimeProbe mod 目录加入 RuntimeBaseRoots
2. **include 后缀错误**：include "LibRuntimeProbe_h" 只加载声明文件，不加载实现文件。正确做法是 include "LibRuntimeProbe"（不带_h后缀），引擎会自动加载 _h.galaxy（声明）和 .galaxy（实现）两个文件，与其他 Lib 的 include 模式一致

### 修复内容
1. launch-7vs1-coop-test.ps1：添加 $runtimeProbeBaseData 变量并加入 Sync-LiveMapRuntimeLibraries 的 RuntimeBaseRoots 参数
2. MapScript.galaxy：include "LibRuntimeProbe_h" 改为 include "LibRuntimeProbe"
3. 删除 19 个 CommanderUnits ComponentList.SC2Components（让引擎自动加载所有文件）
4. 新增 RuntimeProbe.SC2Mod 的 ComponentList/DocumentHeader/DocumentInfo/GameData.xml

## 任务结果
- **ScriptError 完全消除**
- **游戏正常运行 104 秒**，内存 2.78GB
- **RuntimeProbe.SC2Bank 已生成**：heartbeat=1, phase=initlib_ok
- 提交 6602345b（25 files changed），已推送到 origin/fix_003

## 验证证据
- GameLogs 目录中无 ScriptError 文件（只有正常日志：Alerts/UI/Graphics/SystemInfo）
- C:\Users\22448\Documents\StarCraft II\Banks\RuntimeProbe.SC2Bank 已生成（367 bytes）
- 地图 Base.SC2Data 目录中 LibRuntimeProbe_h.galaxy 和 LibRuntimeProbe.galaxy 都已正确复制

## 任务备注

### 经验教训
1. **SC2 galaxy include 模式**：include "LibName" 不带 _h 后缀时，引擎会自动查找 LibName_h.galaxy 和 LibName.galaxy 两个文件。显式带 _h 后缀会导致只加载声明文件
2. **Sync-LiveMapRuntimeLibraries 的 RuntimeBaseRoots**：新增 mod 如果包含 MapScript.galaxy 引用的 galaxy 库，必须将其 Base.SC2Data 目录加入此参数
3. **ComponentList 不是 galaxy 搜索的关键**：删除 ComponentList 后引擎会自动加载所有文件，包括 galaxy 文件
4. **ScriptError 报错行号可能不准确**：报错行号 13（LibC0F50AA6），但实际缺失的是第19行（LibRuntimeProbe_h）

### 后续待办
- RuntimeProbe heartbeat=1 表示 InitLib 已执行，但 StartProbe（周期性扫描）可能未触发
- 需要验证 heartbeat 是否会增加到 2（表示周期性 tick 开始）
- RuntimeProbe 的完整功能验证（单位扫描、升级扫描、生产者扫描）待后续任务