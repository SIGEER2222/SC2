# Runtime Validation

Run an in-game test after changing a map, trigger, GameData, Galaxy, dependency selection, or
runtime behavior. Toolkit, test, Skill, and documentation-only changes do not require launching
the game.

## 7vs1 Maps

Use the repository's dedicated 7vs1 launcher and effective dependency profile.

1. Restart the game if an SC2 process is already running.
2. Launch the target through the project script.
3. Run and wait for:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File `
     "E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\wait-for-game-ready.ps1"
   ```

4. Interpret exit codes:
   - `0`: Alerts appeared, the grace period had no new ScriptError, and the process remains alive.
   - `1`: a new ScriptError appeared or the game process exited.
   - `2`: Alerts did not appear before timeout.
5. Treat every nonzero result as failed verification and fix the reported problem.

Starting the game without waiting for the script is not verification.

## Ordinary MPQ Maps

Do not use the 7vs1 launcher for compressed maps. Injected project libraries can conflict with the
map's own `MapScript.galaxy`.

Launch the original MPQ directly:

```powershell
$switcher = "E:\SC2\SC2new\StarCraft II\Support64\SC2Switcher_x64.exe"
$map = "E:\Code\MyMod\SC2\外部资源\TemplateMaps\<地图名>.SC2Map"
Start-Process -FilePath $switcher -ArgumentList "`"$map`""
```

Do not use `SC2_x64.exe -loadmap`.

After launch:

1. Wait at least 45 seconds.
2. Confirm the `SC2_x64` process is alive.
3. Inspect new files under `C:\Users\22448\Documents\StarCraft II\GameLogs`.
4. Report PID, observed runtime, and whether a new `ScriptError.txt` exists.
5. Fix every ScriptError before completion.
