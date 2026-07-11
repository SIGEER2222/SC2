# Reborn 启动器 Legacy 依赖回归修复

## 问题

7vs1 地图可以正确使用指挥官进图，Reborn `*_reborn_port` 地图不行。工程化拆分后 legacy 启动路径出现两处回归。

## 根因

### 1. Alenger 依赖被缩减为 AlengerCommon

Legacy 模式只同步 `AlengerCommon.SC2Mod`，`DocumentHeader` 也只写入 `baseDeps + AlengerCommon + CommanderUnits`。

但 Galaxy 注入仍复制全部 24 个 Alenger + Adapter 的 `Lib*.galaxy`（满足 `LibE0EAE146_AdapterBootstrap` 硬编码 include）。Catalog 依赖与注入 galaxy 不匹配，指挥官运行时初始化失败。

7vs1 启动器始终同步全量 Alenger mod 并写入完整依赖链，因此正常。

### 2. `$Plan` 参数与 `$plan` 变量冲突

新增 `-Plan` 参数时声明为 `[string]$Plan`。PowerShell 变量名大小写不敏感，`$plan = New-LauncherPlan ...` 实际写入 `$Plan`，对象被强制转为字符串。

后果：`$runtimeDeps = @($plan.documentRewrite.DocumentHeader)` 在 legacy 模式下得到空依赖，CheckOnly 显示 `documentRewrite: 0 deps`。

## 修复

`scripts/reborn/launch-reborn-commander.ps1`：

1. Legacy mod sync：`Sync-ModSet -ModRelPaths $alengerConfig.mods`（24 个 Alenger）
2. Legacy runtimeDeps：`@($launcherPlan.documentRewrite.DocumentHeader)`（37 条完整依赖）
3. 内部变量统一为 `$launcherPlan`，避免与 `-Plan` 参数冲突

`scripts/sc2-launcher/common.ps1`：

4. `Wait-GameReady` 改用 `Start-Process -Wait -PassThru` 返回子进程 exit code，避免 stdout 被误当作返回值

## 验证

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/reborn/launch-reborn-commander.ps1 -Commander TerranRaynor -CheckOnly
# documentRewrite: 37 deps, galaxyInjection: 58 files

pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/reborn/launch-reborn-commander.ps1 -Commander TerranRaynor
# exit 0, Alerts.txt 出现, 无 ScriptError, 149.7s
```

地图：`zexpedition03_reborn_port.SC2Map`，指挥官：`TerranRaynor`。

## 可复用经验

1. **Alenger 必须全量依赖**：只要 CoreRuntime 的 AdapterBootstrap 硬编码 include 全量 Adapter，Catalog 依赖就必须包含全部 24 个 Alenger mod，不能只写 AlengerCommon。
2. **PowerShell 参数命名**：不要用 `$Plan` 这类与内部 `$plan` 仅大小写不同的参数名；带 `[string]` 约束时会把对象赋值强制转字符串。
3. **Legacy 与 Plan 模式应共用 launcher-plan 计算的 document deps**，避免两套逻辑漂移。
