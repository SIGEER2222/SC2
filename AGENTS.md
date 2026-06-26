# AGENTS.md

## SC2 Repo Rules

- 结束前必须执行 `git pull`、`git commit`、`git push`。
- 不要跳过推送。
- commit 的说明请使用中文。
- 改动前先确认当前工作区状态，避免覆盖用户已有修改。
- 只做当前任务需要的最小改动，不要顺手重构无关内容。
- 编辑文件优先用 `apply_patch`。
- 如果发现远端有新提交，先快进同步，再继续修改。
- 涉及地图/触发器/运行时改动时，优先实际进图测试：
  - 运行 `E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\launch-7vs1-coop-test.ps1` 启动游戏测试。
  - 启动后等待 60 秒，检查 `C:\Users\22448\Documents\StarCraft II\GameLogs` 目录是否有报错日志。
  - 如有报错先修复再结束。
