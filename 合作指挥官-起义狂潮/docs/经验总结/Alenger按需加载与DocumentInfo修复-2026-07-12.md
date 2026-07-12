# Alenger mod 按需加载与 CommanderUnits DocumentInfo 修复

## 任务类型
SC2 Mod 依赖优化（延续上一轮基础 mod 合并）

## 时间戳
2026-07-12

## 任务内容
在上一轮 mod 依赖优化（合并 BaseCatalogPatch/SharedUnits/ExternalRefs 到 CoreRuntime，kit_mutations 到 CommanderBridge）基础上，继续完成三项优化：

### 1. Alenger mod 按需加载
- 在 `scripts/launch-7vs1-coop-test.ps1` 新增 `Get-AlengerModsForCommanders` 函数
- 读取 `Shared/Launcher/alenger-mods.json` 的 `commanderToAlenger` 映射，根据选中指挥官返回所需 Alenger mod 依赖路径
- 指挥官 ID 规范化：去掉种族前缀（Terran/Zerg/Protoss）后匹配配置 key（如 `TerranAlenger3` → `Alenger3`）
- 替换原 24 行硬编码全量 Alenger 依赖为按需加载循环
- 未指定指挥官时返回全量依赖（向后兼容）

### 2. CommanderUnits DocumentInfo 修复（19 个文件）
- 19 个 `CommanderUnits_*/DocumentInfo` 原引用已合并的 `BaseCatalogPatch.SC2Mod`
- 原使用 `<Dependency value="..."/>` 格式（`Get-DocumentInfoDependencies` 函数不解析）
- 统一改为 `<Value>file:Mods/7vs1/CoreRuntime.SC2Mod</Value>` 格式
- 补全 `<Flags><Value>ExtensionMod</Value></Flags>` 声明

### 3. HexTalents DocumentInfo 修复
- `BaseCatalogPatch` 替换为 `CoreRuntime`，保留 VoidMulti 和 StarCoop 官方依赖

## 任务结果
- 提交 `e39618e4`，21 files changed, 156 insertions(+), 101 deletions(-)
- 推送到 `origin/fix_003`（4963b56f..e39618e4）
- 进图测试验证（`-Preset Default -NoLaunch`）：
  - Alenger 按需加载生效：TerranRaynor 非 Alenger 指挥官，0 个 Alenger mod 被加载
  - CommanderUnits 按需加载生效：只有 CommanderUnits_Raynor 被加载
  - 基础 mod 只有 CommanderBridge（CoreRuntime 作为 extension mod 安装）

## 任务耗时
约 2 小时（含编码问题排查与进图测试）

## 任务备注
### 遇到的问题
1. **PowerShell 5.x 编码问题**：UTF-8 无 BOM 的 `.ps1` 文件包含中文路径时，PowerShell 5.x 按 ANSI 编码解释导致路径乱码。解决：改用 Python 脚本执行批量修改
2. **PowerShell 内联命令 `$` 变量被剥离**：通过 `powershell -Command "..."` 执行时 shell 包装层剥离 `$` 变量。解决：创建独立 `.ps1` 脚本文件通过 `-File` 参数执行
3. **数组参数被 shell 展平**：`-Commanders @("A","B")` 被处理成单个字符串。解决：改用 `-Preset Default` 参数

### 优化效果
- 上一轮将基础 mod 从 7 个降到 2 个（CoreRuntime + CommanderBridge），SC2 内存从 2.2GB 降到 2GB
- 本轮将 26 个 Alenger mod 从全量加载改为按需加载，非 Alenger 指挥官场景下减少 26 个 mod 加载
- DocumentInfo 依赖声明统一为可解析的 `<Value>` 格式，消除对已合并 mod 的悬空引用
