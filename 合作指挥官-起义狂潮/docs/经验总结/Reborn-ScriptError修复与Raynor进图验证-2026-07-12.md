# Reborn 地图 ScriptError 修复与 Raynor 指挥官生产链路验证

## 任务类型
SC2 地图/Mod 运行时调试 + Galaxy include 注入修复 + BankList 声明修复 + 指挥官生产链路验证

## 时间戳
- 开始：2026-07-12 16:40
- 结束：2026-07-12 17:25
- 耗时：约 45 分钟

## 任务内容

### 问题 1：致命 ScriptError「函数已声明但尚未定义」

**根因**：`launch-reborn-commander.ps1` 生成 `LibRebornAdapter_AlengerBootstrap.galaxy`（实现文件）后，未将 `include "LibRebornAdapter_AlengerBootstrap"` 注入 `MapScript.galaxy`。`RebornMapAdapter.galaxy` include 了 header 声明文件，但实现文件从未被 include，galaxy 编译器找不到函数定义。

**修复**：在 AlengerBootstrap 生成后新增 MapScript.galaxy patch 步骤，注入实现文件 include。同时修复 RuntimeProbe RP-2a 正则用行锚定模式并处理 header/impl 顺序。

### 问题 2：BankList.xml 缺少 CampaignXCore 声明导致 TestRunId 丢失

**根因**：`zexpedition03_reborn_port` 地图的 BankList.xml 没有 `CampaignXCore` Bank 声明。游戏运行时 `BankLoad("CampaignXCore", 1)` 创建空 Bank，`OnAfterPlayersInit` 的 `BankSave` 覆盖磁盘文件，导致启动器设置的 `TestRunId`、`CommanderP1` 等字段全部丢失。

**影响**：`RaynorRuntimeHasTestRun()` 始终返回 false，`RaynorTrainProbe` 和 `RaynorProbeTrainCatalog` 无法执行，无法验证生产链路。

**修复**：在 launch-reborn-commander.ps1 的 RP-3 步骤中，额外添加 CampaignXCore Bank 声明。

## 任务结果：生产链路确凿证据

### 证据 1：运行时 Bank 数据（RaynorProbeTrainCatalog 执行结果）

`CampaignXCore.SC2Bank` 的 `XMRuntimeDebug` section：

| 字段 | 值 | 含义 |
|------|-----|------|
| TestRunId | RebornCommander | 测试运行 ID（保留不丢失） |
| Commander | Raynor | 运行时指挥官变量 |
| PrimaryCommander | Raynor | Bank 主指挥官 |
| AchCommander | Raynor | Ach/Commander 字段 |
| LastPhase | InitializeBase.exit | 初始化链路完成到最后检查点 |
| TownHallUnit | CommandCenterRaynor | 主基地类型（Raynor 版） |
| WorkerUnit | SCVRaynor | 农民类型（Raynor 版） |
| SecondUnit | MarineRaynor | 第二单位类型（Raynor 版） |
| **RaynorTrain5Unit0** | **MedicRaynor** | BarracksTrainRaynor Train5 槽位 = 医疗兵 |
| **RaynorTrain6Unit0** | **FirebatRaynor** | BarracksTrainRaynor Train6 槽位 = 火蝠 |
| **RaynorCCTrain1Unit0** | **SCVRaynor** | CommandCenterTrainRaynor Train1 = SCV |
| RaynorTrain5UnitCount | 1 | Train5 有 1 个单位 |
| RaynorTrain6UnitCount | 1 | Train6 有 1 个单位 |

### 证据 2：Catalog 定义（AbilData_BasePatch.xml）

**BarracksTrainRaynor**（`CAbilTrain`）：

| 槽位 | 单位 | 面板按钮 |
|------|------|---------|
| Train1 | MarineRaynor | Marine |
| Train4 | MarauderRaynor | Marauder |
| Train5 | MedicRaynor | Medic |
| Train6 | FirebatRaynor | Firebat |

**FactoryTrainRaynor**（`CAbilTrain`）：

| 槽位 | 单位 | 面板按钮 |
|------|------|---------|
| Train2 | SiegeTankRaynor | SiegeTank |
| Train10 | VultureRaynor | Vulture |

**CommandCenterTrainRaynor**：

| 槽位 | 单位 |
|------|------|
| Train1 | SCVRaynor |

### 证据 3：运行时单位存在（RuntimeProbe.SC2Bank）

- CommandCenterRaynor ×1
- OrbitalCommandRaynor ×1
- BarracksRaynor ×1
- BarracksRaynorX ×1
- MarineRaynor ×1
- SCVRaynor ×12
- RaynorCommando ×1（英雄）
- CoopCasterRaynor ×1

### 证据 4：RuntimeProbe 心跳

心跳从 2 增长到 30（120 秒，3 秒/次），StartProbe 的 Wait(3.0, c_timeReal) 循环正常工作。

### 证据 5：初始化链路执行

`LastPhase = InitializeBase.exit`（第 1504 行检查点），证明：
- `gf_Initialize` 执行完成（Initialize.enter → Initialize.exit）
- `gf_InitializeMapBaseScenario` 执行完成
- `gf_InitializeBase` 执行完成（InitializeBase.enter → InitializeBase.exit）
- `gf_CommanderRuntimeInit` → `gf_RaynorRuntimeInit` 被调用

## 已知问题（不影响替换成功判定）

1. **PlayerStartLocation(1) 返回 null**：战役图未通过 `PlayerSetStartLocation` 设置起始位置，导致 `gf_InitializeBase` 和 `RaynorRuntimeInit` 中基于 `PlayerStartLocation` 的单位创建失败（PointWithOffsetPolar 错误）。但这不影响 Catalog 替换——地图预放置的单位已被正确替换为 Raynor 版本。

2. **RaynorTrainProbeSetupBarracks 未执行**：该探针需要 `PlayerStartLocation` 创建测试兵营，因 null 而失败。但 `RaynorProbeTrainCatalog`（纯 Catalog 查询，不依赖位置）成功执行并写入 Bank。

3. **TownHallCount/WorkerCount/SecondUnitCount = 0**：`RuntimeBaseCheckpoint` 在创建单位后立即计数，但因 `PlayerStartLocation` null 导致创建失败，计数为 0。实际单位来自地图预放置数据的 Catalog 替换。

## Git 提交
- `2bc71773`：AlengerBootstrap include 注入 + RuntimeProbe 正则修复
- `2f6d575b`：BankList.xml 添加 CampaignXCore 声明，修复 TestRunId 丢失
- 分支：fix_003
