# 任务总结：RuntimeProbe Wait循环修复 + Neuro集成

- 任务类型：galaxy代码修复 + 脚本开发 + 进图测试
- 时间戳：2026-07-12 15:45
- 分支：fix_003
- 提交：88f91b7a

## 任务内容

### 1. 地图依赖扫描（已完成）
- 扫描95个DocumentInfo文件，31张地图有过量依赖
- 28张7vs1地图依赖CoopZeroPop(待删除)+CommanderCatalog(不存在)+kit_mutations(已合并)
- 报告已生成并提交（commit af599634, 96e9da03）

### 2. 修复周期性tick不触发
- **问题**：TriggerAddEventTimePeriodic在7vs1地图中所有位置(InitLib/StartProbe)和时间类型(c_timeGame/c_timeReal)下均不触发，heartbeat卡在2
- **根因**：7vs1地图自动进入游戏（cinematic/briefing机制），TriggerAddEventTimePeriodic在此环境下不工作
- **修复**：用Wait(3.0, c_timeReal)循环替代TriggerAddEventTimePeriodic
  - 将Tick_Func替换为Loop_Func（while(true) + Wait循环）
  - StartProbe通过TriggerExecute(..., false, false)异步启动Loop
  - 与7vs1地图自身模式一致（gt_StartGame_Func大量使用Wait+c_timeReal）

### 3. Neuro集成
- launch-7vs1-coop-test.ps1新增6步Neuro集成逻辑（-EnableNeuro开关控制）
  - Step 1: 追加Neuro依赖到地图DocumentInfo
  - Step 2: 复制NeuroIntegration和NeuroBridge7vs1 mod到SC2运行时
  - Step 3: 注入LibEFA54406和LibNeuroBridge7vs1 galaxy文件到地图
  - Step 4: Patch BankList.xml添加NeuroIntegration bank声明
  - Step 5: Patch MapScript.galaxy添加Neuro includes和InitLib调用
  - Step 6: 启动Python运行时（可选Gary模式）
- 修复NeuroBridge7vs1的MapInit触发器和变量声明

## 任务结果

### 进图测试验证（2026-07-12 15:42）
- **heartbeat = 9**（之前卡在2，现在每3秒递增）
- **game_time = 32**（之前卡在0，现在正常推进）
- **unit_scan_id = 8**（已执行8次周期扫描）
- **检测到10种单位**：CommandCenterRaynor, MULE, BarracksRaynor, BarracksRaynorX, OrbitalCommandRaynor, MarineRaynor, RaynorCommando, Barracks, SCVRaynor(12个), CoopCasterRaynor(2个)
- **检测到20个升级**：Stimpack, ShieldWall, CommanderLevel等
- **检测到6个生产建筑**：OrbitalCommandRaynor, Barracks, CoopCasterRaynor, BarracksRaynor, BarracksRaynorX, CommandCenterRaynor
- **无ScriptError**
- **Neuro集成5步全部成功**：依赖追加、mod复制、galaxy注入、BankList patch、MapScript patch
- galaxy-checker: 0错误0警告

### 提交信息
- commit 88f91b7a pushed to origin/fix_003
- 7 files changed, 432 insertions(+), 127 deletions(-)
- 修改文件：
  - LibRuntimeProbe.galaxy + LibRuntimeProbe_h.galaxy（Wait循环）
  - MapScript.galaxy（注释更新）
  - launch-7vs1-coop-test.ps1（Neuro集成6步）
  - launch-7vs1-neuro.ps1（参考脚本）
  - LibNeuroBridge7vs1.galaxy + _h.galaxy（Neuro桥接修复）

## 任务备注

### 关键经验
- **TriggerAddEventTimePeriodic在7vs1地图中不工作**：无论放在InitLib还是StartProbe，无论用c_timeGame还是c_timeReal，周期性触发器都不触发。根因可能是7vs1战役图的触发器事件系统与自定义对战地图不同
- **Wait循环是7vs1地图的可靠周期执行机制**：7vs1地图自身大量使用Wait（gt_StartGame_Func中有多个Wait(8.0, c_timeReal)），这是更可靠的方案
- **TriggerExecute(..., false, false)可异步启动Wait循环**：第一个false表示不等待完成，第二个false表示不测试条件
- **Neuro集成可通过-EnableNeuro开关控制**：与现有RuntimeProbe集成无冲突

### 地图依赖扫描结果摘要
- 31张地图有过量依赖（28张7vs1 + abathur_test_map + zexpedition03_reborn_port + 1张路径错误）
- 过量mod：CoopZeroPop(29张引用)、CommanderCatalog(29张)、kit_mutations(30张)
- 修复建议：7vs1地图删除3个过量依赖，由launch脚本动态注入CoreRuntime+CommanderBridge+按需CommanderUnits