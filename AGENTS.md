# AGENTS.md

- 回复简洁，避免发送不影响任务执行的可省略旁白。

## Repository Safety

- 开始任何任务前运行 `git status --short --branch`，确认当前分支和已有修改。
- 保留用户和其他任务的现有修改；不得覆盖、回退或清理非本任务内容。
- 只做当前任务需要的最小改动，不重构无关代码。
- 手工编辑文件优先使用 `apply_patch`。
- 禁止使用 `git reset --hard`、`git checkout --`、强制推送或其他可能丢失现有工作的操作。

## Sync And Delivery

- 修改仓库前检查远端状态；发现远端新提交时，仅在能保护现有修改的前提下快进同步。
- 无法安全同步时停止提交操作并报告阻塞，不得重写历史或覆盖现有修改。
- 只暂存和提交本任务产生的文件；commit 说明使用中文。
- 修改任务结束前执行 `git pull --ff-only`、创建提交并推送当前分支，不得跳过推送。
- 只读任务或没有文件变化的任务不得创建空提交。

## SC2 Workflow

- 涉及 SC2 地图、Mod、GameData、Galaxy、触发器、依赖或游戏内验证时，使用项目 Skill `$sc2-workflow`。
- `$sc2-workflow` 用于补充诊断和命令细节，不能替代下方的强制进图测试门禁。

## Mandatory In-Game Test Gate

以下任一内容发生修改后，任务结束前必须实际启动对应地图并完成进图测试：

- `.SC2Map`、`.SC2Mod` 容器或其解包目录中的任何运行时文件。
- `GameData` XML、`.galaxy`、`_h.galaxy`、`Triggers`、`DocumentInfo`、`DocumentHeader`。
- 地图依赖、依赖顺序、MapProfile、CommanderProfile、Adapter、CompositionPlan 或生成地图。
- 启动器、同步器、安装器、地图生成器等会改变 live 地图、live Mod 或启动参数的脚本。
- 单位、技能、科技、UI、玩家槽位、联盟、任务流程、Bank、胜负、触发器或其他游戏内行为。

只有纯文档、纯只读分析、不会影响上述运行时产物的独立工具改动可以免除进图测试。不能因为“用户没有明确要求测试”“静态检查已通过”“改动看起来很小”或“只改了依赖/启动脚本”而跳过进图。

### Required Order

1. 修改 Galaxy 后，先用 `galaxy-checker` 扫描完整 Mod 或地图依赖范围，并完整查看全部 `[ERROR]`。
2. 静态检查通过后再启动地图；静态检查不能代替进图测试。
3. 如果游戏正在运行，先结束旧游戏进程，再重新启动，避免复用旧进程或旧日志。
4. 使用与地图类型匹配的启动方式。
5. 启动后必须运行 `scripts/wait-for-game-ready.ps1`，等待脚本结束，不得提前结束任务。
6. 等待脚本非零退出时，必须先修复问题并重新执行静态检查和进图测试。
7. 不得在游戏或等待脚本仍运行、结果尚未返回时声称任务完成。

### Launcher Selection

- 7vs1 地图使用其专用启动器，并在启动完成后执行标准等待脚本。
- 非 7vs1 地图、原始 MPQ 战役地图和外部模板地图禁止使用 `launch-7vs1-coop-test.ps1`。
- 非 7vs1 地图必须使用 `SC2Switcher_x64.exe` 直接传入地图路径，不使用 `SC2_x64.exe -loadmap`：

```powershell
$switcher = "E:\SC2\SC2new\StarCraft II\Support64\SC2Switcher_x64.exe"
$map = "<目标地图绝对路径>"
Start-Process -FilePath $switcher -ArgumentList "`"$map`""
```

启动后必须执行并等待：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\wait-for-game-ready.ps1"
```

### Success Criteria

只有同时满足以下条件才算进图测试通过：

- `wait-for-game-ready.ps1` 返回退出码 0。
- `SC2_x64` 进程仍然存活。
- Alerts 出现后的宽限期内没有新增 `ScriptError`。
- 没有脚本读取失败、函数未定义、参数数量错误或依赖缺失。
- 本次改动对应的核心游戏行为已经实际观察或由运行时探针确认。

对于非 7vs1 MPQ 地图，还必须确认游戏至少完成地图加载阶段，并检查 `C:\Users\22448\Documents\StarCraft II\GameLogs` 是否产生新的 `ScriptError.txt`。

### Completion Evidence

最终回复必须列出：

- 实际测试的地图。
- 使用的启动器或启动命令。
- `wait-for-game-ready.ps1` 的退出码。
- 游戏进程 PID 或存活状态。
- 是否发现新的 `ScriptError`。
- 实际验证的游戏内行为。

缺少上述证据时，不得写“已完成”“测试通过”或同等结论；应明确标记为未完成并继续测试。

### Checker Coverage And Experience Capture

- 如果进图出现 ScriptError 但 `galaxy-checker` 没有检测出来，必须先为 checker 增加对应规则或回归样例，再继续修复地图。
- 每次出现游戏内报错并完成修复后，将原因、修复方法和验证结果写入 `合作指挥官-起义狂潮/docs/经验总结`。
