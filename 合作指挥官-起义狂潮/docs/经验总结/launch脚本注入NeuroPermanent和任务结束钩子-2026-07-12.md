# 任务总结：launch 脚本注入 NeuroPermanent bank 和任务结束钩子

- **任务类型**：SC2 启动脚本修改（PowerShell）
- **时间戳**：2026-07-12
- **任务耗时**：约 10 分钟

## 任务内容

为 NeuroBridge7vs1 的新功能（对话推送、永久能力、任务间隙）在 `launch-7vs1-coop-test.ps1` 中添加注入逻辑：

1. **Step N4 扩展**：在 BankList.xml patch 中，除已有的 NeuroIntegration bank 外，追加 NeuroPermanent bank 声明（用于跨任务持久化）。将文件写入移至两个 bank 添加之后，确保两者都写入。

2. **Step N5 扩展**：新增 N5c 子步骤，注入 Phase D 任务结束触发器：
   - 在 MapScript.galaxy 的 InitLibs() 函数之后注入触发器函数定义 `libNeuroBridge7vs1_gt_MissionEnd_Func`
   - 监听 `TriggerAddEventPlayerLeft` 的 Victory/Defeat 事件
   - 胜利时调用 `libNeuroBridge7vs1_gf_OnMissionVictory`，失败时调用 `libNeuroBridge7vs1_gf_OnMissionDefeat`

## 任务结果

- 修改文件：`合作指挥官-起义狂潮/scripts/launch-7vs1-coop-test.ps1`（+41 -2）
- 验证：`-NoLaunch -EnableNeuro -SkipPythonRuntime` 模式通过，输出包含：
  - `Added NeuroPermanent bank declaration`
  - `Added Phase D mission end hook`
- 二次运行同样通过（live 目录每次重置，patch 重新应用）
- Git 提交：`ea5ecade`，已推送到 `origin/fix_003`

## 任务备注

- Phase B（对话推送）按任务要求未在 launch 脚本中注入，作为 NeuroBridge7vs1 API 留待未来手动调用
- 注入的任务结束钩子使用 `EventPlayerLeft` 事件捕获胜利/失败，这是 galaxy 中检测游戏结束的标准方式
- 触发器注册放在文件作用域（InitLibs 函数之后），在全局初始化阶段执行，早于 InitLib 调用，但不影响功能（回调在游戏结束时才触发）
