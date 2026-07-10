# AGENTS.md

**Do NoT send optional commentary**

## Repository Safety

- 开始任何任务前运行 `git status --short --branch`，确认当前分支和已有修改。
- 手工编辑文件优先使用 `apply_patch`。

## Sync And Delivery

- 修改仓库前检查远端状态；发现远端新提交时，仅在能保护现有修改的前提下快进同步。
- 无法安全同步时停止提交操作并报告阻塞，不得重写历史或覆盖现有修改。
- 只暂存和提交本任务产生的文件；commit 说明使用中文。
- 修改任务结束前执行 `git pull --ff-only`、创建提交并推送当前分支，不得跳过推送。
- 只读任务或没有文件变化的任务不得创建空提交。

## SC2 Workflow

- 涉及 SC2 地图、Mod、GameData、Galaxy、触发器、依赖或游戏内验证时，使用项目 Skill `$sc2-workflow`。
- SC2 的诊断、工具命令、静态检查和进图测试细节以该 Skill 为唯一流程来源。
