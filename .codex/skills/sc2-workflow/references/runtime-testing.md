# Runtime Testing

## Test Lock Convention (测试锁约定)

**所有启动 SC2 进程的 launch 脚本必须先获取测试锁，测试完成后释放。**

同一时间只允许一个测试会话启动游戏，避免多个 AI/脚本互相覆盖 SC2 进程导致测试结果混乱。

### 锁机制

- 锁文件: `out/.test.lock` (JSON)
- 超时: 3 分钟（180 秒），超时自动释放
- 持有者进程退出时锁自动失效
- 模块: `scripts/sc2-launcher/test-lock.ps1`

### 集成方式

```powershell
. (Join-Path $LauncherScriptsRoot "test-lock.ps1")

$lockCtx = $null
try {
    $lockCtx = Acquire-TestLock -TestType "reborn_commander" -MapName $MapName -Commander $Commander
} catch {
    Write-Host "[TestLock] 获取锁失败: $_" -ForegroundColor Red
    exit 1
}

try {
    # ... 启动游戏、等待、测试 ...
    # 长时间测试可续期: Renew-TestLock -LockContext $lockCtx -AdditionalSeconds 600
} finally {
    Release-TestLock -LockContext $lockCtx
}
```

### 锁失败时

如果 `Acquire-TestLock` 抛出异常，说明有其他测试正在运行。**不得强制抢占**，应：
1. 输出当前持有者信息
2. 退出脚本（exit 1）
3. 等待当前测试完成或锁过期（最多 3 分钟）

### 查看锁状态

```powershell
. (Join-Path $PSScriptRoot "sc2-launcher\test-lock.ps1")
Get-TestLockStatus
```

---

Choose the launcher by target type. The wrong launcher can create failures that do not exist in the
original map.

## 7vs1 Maps

Use the repository's dedicated 7vs1 launcher and effective dependency profile.

1. Restart the game when an SC2 process is already running.
2. Launch the target through the project script.
3. Run and wait for:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File `
     "E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\wait-for-game-ready.ps1"
   ```

4. Interpret the result:
   - exit 0: Alerts appeared, the grace period produced no new ScriptError, and the process lives.
   - exit 1: a new ScriptError appeared or the game process exited.
   - exit 2: no Alerts file appeared before timeout.
5. Treat every nonzero result as failed verification and fix the reported error before finishing.

The wait script must complete. Starting the game without waiting is not a runtime verification.

## Ordinary MPQ Maps

Never use the 7vs1 launcher for compressed maps such as `外部资源/TemplateMaps`. It injects project
runtime libraries that can conflict with the map's own `MapScript.galaxy`.

Launch the original MPQ directly:

```powershell
$switcher = "E:\SC2\SC2new\StarCraft II\Support64\SC2Switcher_x64.exe"
$map = "E:\Code\MyMod\SC2\外部资源\TemplateMaps\<地图名>.SC2Map"
Start-Process -FilePath $switcher -ArgumentList "`"$map`""
```

Do not use `SC2_x64.exe -loadmap`; that process exits immediately in this environment.

After launch:

1. Wait at least 45 seconds.
2. Confirm the `SC2_x64` process is still alive.
3. Inspect newly created files under
   `C:\Users\22448\Documents\StarCraft II\GameLogs`.
4. Report the process PID, observed runtime, and whether a new `ScriptError.txt` exists.
5. Fix any ScriptError before completion.

## When Runtime Testing Is Not Required

Do not launch the game when only toolkit source, tests, Skill files, configuration documentation, or
design documentation changed and no map/runtime behavior changed.
