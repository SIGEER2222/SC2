# Runtime Testing

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
