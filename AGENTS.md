# AGENTS.md

## SC2 Repo Rules

- 结束前必须执行 `git pull`、`git commit`、`git push`。
- 不要跳过推送。
- commit 的说明请使用中文。
- 改动前先确认当前工作区状态，避免覆盖用户已有修改。
- 只做当前任务需要的最小改动，不要顺手重构无关内容。
- 编辑文件优先用 `apply_patch`。
- 如果发现远端有新提交，先快进同步，再继续修改。
- 涉及地图/触发器/运行时改动时，按以下优先级逐步校验：
  1. **静态分析（秒级）**：先运行 `python E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\validate-galaxy-scripts.py`，检测 BOM、括号不匹配、禁用原生函数、include 缺失、跨库引用不一致等低级错误。
  2. **快速编译验证（约 20-30 秒）**：静态分析通过后，运行 `powershell -NoProfile -ExecutionPolicy Bypass -File E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\quick-compile-check.ps1`，利用游戏编译阶段检测语法和链接错误，比完整进图快很多。
  3. **完整进图测试**：以上都通过后，再运行 `E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\launch-7vs1-coop-test.ps1` 启动游戏测试。
  - 启动后运行 `powershell -NoProfile -ExecutionPolicy Bypass -File E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\wait-for-game-ready.ps1` 智能等待加载完成并检测错误。
  - 智能等待通过以下硬性条件判断：
    - **失败（立即终止）**：ScriptError.txt 出现脚本编译/运行错误，或游戏进程崩溃退出
    - **成功（进入游戏）**：游戏进程存活 + Alerts.txt 10 秒无新内容（加载完成）+ 无严重脚本错误
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

官方数据地址 E:\Code\MyMod\SC2\合作指挥官-起义狂潮\游戏数据\官方SC2原始文本镜像

## 参考数据源

| 路径 | 内容 | 用途 |
|------|------|------|
| `E:\Code\MyMod\SC2\sc2-data-trigger` | 完整官方触发器/GameData 镜像，包含 core/swarm/void/liberty 等所有资料片 mod | 触发器逻辑、GameData XML 参考 |
| `E:\Code\MyMod\SC2\合作指挥官-起义狂潮\游戏数据\官方SC2原始文本镜像\mods\starcoop` | 合作指挥官 starcoop mod，包含 commanders/ 子目录（18个指挥官独立mod） | 指挥官特定数据、天赋/技能定义 |
| `E:\Code\MyMod\SC2\解包数据\海克斯合作PVP0.110.SC2Mod` | 海克斯合作 PVP mod 解包数据 | Hex 天赋/技能系统参考 |
