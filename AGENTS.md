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
  - 启动后等待 120 秒，检查 `C:\Users\22448\Documents\StarCraft II\GameLogs` 目录是否有报错日志。
  - 如有报错先修复再结束。

## TRAE 辅助脚本

以下命令在 TRAE 中需要二次确认，应使用包装脚本绕过：

| 原命令 | 包装脚本 | 用法示例 |
|--------|----------|----------|
| `Remove-Item` | `scripts/trae-rm.ps1` | `powershell -File scripts/trae-rm.ps1 "file.txt"` |
| `Remove-Item -Recurse` | `scripts/trae-rmdir.ps1` | `powershell -File scripts/trae-rmdir.ps1 "dir"` |
| `git checkout <分支>` | `scripts/trae-checkout.ps1` | `powershell -File scripts/trae-checkout.ps1 "dev"` |
| `git checkout -- <文件>` | `scripts/trae-checkout-file.ps1` | `powershell -File scripts/trae-checkout-file.ps1 "file.txt"` |
| `git restore <文件>` | `scripts/trae-restore.ps1` | `powershell -File scripts/trae-restore.ps1 "file.txt"` |
| `git clean -fd` | `scripts/trae-clean.ps1` | `powershell -File scripts/trae-clean.ps1` |

每次出现报错并修复之后，总结经验到本地文档 E:\Code\MyMod\SC2\合作指挥官-起义狂潮\docs\经验总结
