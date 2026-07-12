# 任务总结：NeuroBridge7vs1 玩家行为 Context 迁移

## 任务类型

- SC2 Galaxy 脚本开发
- Neuro 7vs1 桥接增强
- Galaxy 校验 + 进图验证

## 时间

- 日期：2026-07-12
- 完成时间：约 20:30

## 任务内容

将 `SC2-Neuro-WoL-Integration` 中高价值、低风险的玩家行为上下文能力，轻量迁移到 `NeuroBridge7vs1`，优先补充：

- 玩家聊天消息
- 玩家基础指令意图（移动 / 停止 / 巡逻 / 保持 / 攻击）
- 当前选中单位摘要
- 经济快照摘要
- 简化战斗摘要

本次不迁移高风险的连续微操控制，也不新增通用坐标移动 / 点选目标等执行型 action。

## 具体改动

### 1. 头文件声明扩展

修改文件：

- `Mods/Neuro/NeuroBridge7vs1.SC2Mod/Base.SC2Data/LibNeuroBridge7vs1_h.galaxy`

新增：

- 活动追踪初始化标记
- 聊天 / 技能 / 死亡事件触发器声明
- 待冲刷 context 缓冲变量
- 选中、经济、战斗统计状态
- 新增辅助函数声明

### 2. 7vs1 桥接实现扩展

修改文件：

- `Mods/Neuro/NeuroBridge7vs1.SC2Mod/Base.SC2Data/LibNeuroBridge7vs1.galaxy`

新增实现：

- `libNeuroBridge7vs1_gf_InitActivityTracking`
- `libNeuroBridge7vs1_gt_PlayerChatMessage_Func`
- `libNeuroBridge7vs1_gt_UnitAbility_Func`
- `libNeuroBridge7vs1_gt_UnitDies_Func`
- `libNeuroBridge7vs1_gf_BuildSelectedUnitsContext`
- `libNeuroBridge7vs1_gf_UpdateSelectionContext`
- `libNeuroBridge7vs1_gf_UpdateEconomyContext`
- `libNeuroBridge7vs1_gf_UpdateCombatContext`
- `libNeuroBridge7vs1_gf_FlushPendingContexts`

同时在：

- `MapInit` 阶段挂载活动追踪触发器
- `execute_actions_map` 中增加统一 context 冲刷

## 验证结果

### 1. Galaxy Checker

执行：

```powershell
node "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\galaxy-checker\dist\cli.mjs" `
  "e:\Code\MyMod\SC2\合作指挥官-起义狂潮\Mods\Neuro\NeuroBridge7vs1.SC2Mod\Base.SC2Data" `
  --format text
```

结果：

- 0 错误
- 1 警告：`LibEFA54406_h` 在单独检查该 Mod 目录时未解析到 include

说明：

- 该警告来自单独检查桥接 Mod 目录，属于依赖解析范围问题，不是本次新增代码的语法错误。

### 2. 进图验证

执行：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ".\scripts\launch-7vs1-neuro.ps1" `
  -Commanders @("TerranRaynor") -SkipPythonRuntime
```

观察结果：

- 启动脚本执行完成
- 地图已安装到：
  - `E:\SC2\SC2new\StarCraft II\Maps\7vs1\7vs1CoopTest.SC2Map`
- 注入完成：
  - `LibEFA54406.galaxy`
  - `LibEFA54406_h.galaxy`
  - `LibNeuroBridge7vs1.galaxy`
  - `LibNeuroBridge7vs1_h.galaxy`
- `SC2_x64` 进程处于运行状态

### 3. ScriptError 检查

检查 `c:\Users\22448\Documents\StarCraft II\GameLogs` 后：

- 本次启动后未生成新的 `ScriptError.txt`
- 最新仍为旧文件：`2026-07-12 20.14.15 ScriptError.txt`

说明：

- 说明本次新增的 `NeuroBridge7vs1` context 逻辑未在当前启动链中引入新的脚本崩溃。

## 任务结果

- 已完成玩家行为 context 的第一轮轻量迁移
- 已确认桥接层可随 7vs1 启动链正常注入
- 已确认未新增新的 ScriptError

## 任务耗时

- 约 45 分钟

## 备注

- 当前实现仍是“感知增强”，不是完整 RTS 操控代理
- 后续若继续推进，建议优先补：
  1. 更精细的选中单位聚合
  2. 建造 / 生产 / 科技变化摘要
  3. 更准确的玩家命令捕捉方式
  4. Python 侧联调，确认这些 context 已被 Neuro runtime 消费
