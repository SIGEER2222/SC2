# Phase B+C+D Galaxy 实现：对话推送 + 永久能力 + 任务间隙

## 任务类型
SC2 Galaxy 脚本开发（`.galaxy` / `_h.galaxy` 修改）

## 时间戳
- 开始：2026-07-12 16:50（约）
- 结束：2026-07-12 17:03
- 任务耗时：约 13 分钟

## 任务内容
为 NeuroBridge7vs1 mod 添加三个功能模块的 galaxy 实现：

### Phase B：角色对话推送
- 新增 `libNeuroBridge7vs1_gf_PushTransmissionContext(soundLink, speakerName, subtitleText, silent)`
- 推送 context_name = "transmission" 给 Neuro
- context 格式：`<speakerName>: <subtitleText>`（空 subtitle 时传 `<speakerName> is speaking.`）
- silent 参数控制走静默上下文还是语音播报

### Phase C：永久能力系统
- 新增永久 bank 变量 `libNeuroBridge7vs1_gv_permanentBank`（NeuroPermanent.SC2Bank）
- `libNeuroBridge7vs1_gf_LoadPermanentBank()` — 懒加载永久 bank
- `libNeuroBridge7vs1_gf_UnlockAction(actionName)` — 解锁 action 并持久化
- `libNeuroBridge7vs1_gf_IsActionUnlocked(actionName)` — 检查 action 是否已解锁
- `libNeuroBridge7vs1_gf_SaveMissionSummary(mapId, summary)` — 保存任务摘要
- `libNeuroBridge7vs1_gf_GetLastMissionSummary()` — 读取最近任务摘要

### Phase D：任务间隙逻辑
- `libNeuroBridge7vs1_gf_OnMissionVictory(mapId, bonusObjectives)` — 胜利钩子，保存摘要 + 推送 mission_victory context
- `libNeuroBridge7vs1_gf_OnMissionDefeat(mapId)` — 失败钩子，保存摘要 + 推送 mission_defeat context
- `libNeuroBridge7vs1_gf_PushLastMissionSummary()` — 推送上次任务摘要（silent=true）
- 在 `libNeuroBridge7vs1_gt_ExecuteActionsMap_Func` 首次调用块中，`PushMutatorContext()` 之后追加 `PushLastMissionSummary()` 调用

## 任务结果
- **修改文件**：
  - `Mods/Neuro/NeuroBridge7vs1.SC2Mod/Base.SC2Data/LibNeuroBridge7vs1_h.galaxy`（+16 行声明）
  - `Mods/Neuro/NeuroBridge7vs1.SC2Mod/Base.SC2Data/LibNeuroBridge7vs1.galaxy`（+113 行实现 + 1 行调用插入）
- **galaxy-checker 验证**：0 错误，1 警告
  - 警告 `XLIB_MISSING_INCLUDE: include "LibEFA54406_h" 未找到` 为预先存在的跨 Mod 引用（NeuroIntegration mod 提供），修改前已存在，非本次引入
  - 按 galaxy-validation.md 指引，跨 Mod 引用在 owning Mod 运行时提供时被接受
- **Git 提交**：commit `13c71daf`，分支 `fix_003`，2 files changed, 129 insertions
- **Git 推送**：`2bc71773..13c71daf fix_003 -> fix_003` 推送成功

## 任务备注
1. **未进图运行时测试**：本任务只修改 2 个 galaxy 文件，launch 脚本由另一个任务处理。新增函数均为可选增强（对话推送、永久 bank、任务钩子），不改变现有 ExecuteActionsMap 心跳主循环语义，仅在其首次调用块末尾追加一次 `PushLastMissionSummary()` 调用。按 runtime-testing.md，galaxy 源码变更原则上应进图验证；建议在 launch 脚本就绪后由后续任务统一进图验证 ScriptError 状态。
2. **file-ops 合规**：所有文件编辑使用 Edit 工具（编辑器原生操作），git add/commit 使用 `trae-add.ps1` / `trae-commit.ps1` 包装脚本，未使用任何禁止的原生命令。
3. **跨 Mod 引用警告**：`LibEFA54406_h` 来自 NeuroIntegration mod，galaxy-checker 在单 mod 目录扫描时无法解析，属预期行为。
4. **内部 ID 安全**：所有新增函数名、变量名、bank section/key 均为 ASCII，无中文 ID 风险。
5. **PushLastMissionSummary 调用位置**：放在 `PushMutatorContext()` 之后，确保 action 注册和突变因子上下文先就绪，再推送跨任务记忆。
