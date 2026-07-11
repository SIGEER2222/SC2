**Do NoT send optional commentary**

## Repository Safety

- 开始任何任务前运行 `git status --short --branch`，确认当前分支和已有修改。
- 保留用户和其他任务的现有修改；不得覆盖、回退或清理非本任务内容。
- 只做当前任务需要的最小改动，不重构无关代码。
- 创建、修改、移动、重命名或删除文件前必须加载并遵守 `$file-operations`。

## Sync And Delivery

- 修改仓库前检查远端状态；发现远端新提交时，仅在能保护现有修改的前提下快进同步。
- 无法安全同步时停止提交操作并报告阻塞，不得重写历史或覆盖现有修改。
- 只暂存和提交本任务产生的文件；commit 说明使用中文。
- 修改任务结束前执行 `git pull --ff-only`、创建提交并推送当前分支，不得跳过推送。
- 只读任务或没有文件变化的任务不得创建空提交。

## Mandatory Skill Routing

开始编辑前，按任务类型加载并遵守对应 Skill。一个任务命中多行时，要求叠加执行；不得只选最轻的一行。

| 任务类型 | 必须遵守 | 不可跳过的完成门禁 |
| --- | --- | --- |
| 任何创建、修改、移动、重命名或删除文件的任务 | `$file-operations`，并叠加命中的领域 Skill | 使用原生文件操作或 `apply_patch`；禁止 shell 内容写入；编辑后检查 diff |
| SC2 地图、Mod、GameData、触发器、依赖、Adapter、生成地图、启动或同步逻辑 | `$sc2-workflow` + `references/runtime-testing.md` | 运行时产物有变化时必须实际进图，等待测试流程结束 |
| `.galaxy` / `_h.galaxy` 修改或 ScriptError 调试 | `$sc2-workflow` + `references/galaxy-validation.md` + `references/runtime-testing.md` | 先完整运行 galaxy-checker，再进图；checker 漏报时先补规则和回归测试 |
| 单位不能生产、缺技能/按钮、科技不一致、静态与运行时不同 | `$sc2-workflow` + `references/unit-diagnostics.md` | 先完成依赖和有效单位诊断；发生运行时修改时再执行进图测试 |
| MPQ 地图/Mod 的检查、解包、重打包或容器改动 | `$sc2-workflow` + `references/tooling.md` + `references/runtime-testing.md` | 原文件只读；重打包或运行时内容变化后必须用正确启动器进图 |
| 本地化扫描或中文文本修复 | `$sc2-workflow` + `references/localization-scan.md` | 保持内部 ID 为 ASCII；修改地图/Mod 文本产物时按 runtime-testing 判断是否进图 |

### Hard Gates

- 未读取命中行要求的 Skill/reference 前不得开始编辑；文件缺失或无法读取时必须报告阻塞，不能凭记忆替代。
- `$file-operations` 是所有写任务的前置门禁；领域 Skill 不能替代它，也不能授权使用 shell 写文件。
- 静态检查不能替代进图测试；“用户没要求”“改动很小”“只改依赖/启动器”都不是跳过理由。
- 运行时测试必须等待对应流程返回；测试仍在运行、退出非零或存在新 ScriptError 时不得结束任务。
- 最终回复必须给出 `$sc2-workflow` 要求的验证证据；缺少地图、启动方式、等待结果、进程状态、ScriptError 状态或实际行为验证时，不得声称完成。
- 只有纯文档、纯只读分析、Skill 文件或不会改变地图/Mod/启动行为的独立工具改动可以免除进图测试。
- 每次修复新的游戏内报错后，将可复用经验写入 `合作指挥官-起义狂潮/docs/经验总结`。
