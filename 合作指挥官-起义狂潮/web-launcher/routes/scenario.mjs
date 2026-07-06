import { Router } from 'express';
import { loadScenarios, getScenario } from '../services/scenario-registry.mjs';
import { syncAll } from '../lib/sync-mods-and-maps.mjs';
import { stopAllSc2 } from '../lib/stop-sc2.mjs';
import { launchAndWait } from '../lib/launch-and-wait.mjs';
import { buildLaunchArgs } from '../services/launch-args-builder.mjs';
import { fileURLToPath } from 'url';
import { dirname, join, resolve } from 'path';
import { spawn } from 'child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const MAPS_JSON = join(__dirname, '..', 'maps.json');
const WORKSPACE_ROOT = resolve(__dirname, '..', '..');
const SC2_ROOT = 'E:/SC2/SC2new/StarCraft II';
const SWITCHER_PATH = 'E:/SC2/SC2new/StarCraft II/Support64/SC2Switcher_x64.exe';
const GAME_LOGS_PATH = 'C:/Users/22448/Documents/StarCraft II/GameLogs';
const WAIT_PS1 = join(__dirname, '..', '..', 'scripts', 'wait-for-game-ready.ps1');

const router = Router();

router.get('/scenarios', (req, res) => {
  const list = loadScenarios(MAPS_JSON);
  res.json({ ok: true, data: list });
});

router.post('/scenario/:id/test', async (req, res) => {
  const scenarioId = req.params.id;
  const scenario = getScenario(MAPS_JSON, scenarioId);
  if (!scenario) {
    return res.status(404).json({ ok: false, error: `场景不存在: ${scenarioId}` });
  }

  const userSelection = req.body?.userSelection || {};
  const steps = {};
  const startMs = Date.now();

  try {
    // 1. 杀进程
    const stopStart = Date.now();
    const stopResult = await stopAllSc2();
    steps.stop = { durationMs: Date.now() - stopStart, killed: stopResult.killed };

    // 2. 同步 mods + maps
    const syncStart = Date.now();
    const syncResult = syncAll({
      modNames: scenario.requiredMods || [],
      mapPaths: [scenario.mapPath].filter(Boolean),
      workspaceRoot: WORKSPACE_ROOT,
      sc2Root: SC2_ROOT,
      modSources: scenario.modSources || {},
    });
    steps.sync = { durationMs: Date.now() - syncStart, copied: syncResult.copied };

    // 3. 启动
    const launchStart = Date.now();
    let launchResult;
    const args = buildLaunchArgs({ scenario, userSelection });
    if (args) {
      // 7vs1-launcher 模式：spawn pwsh + launch-7vs1-coop-test.ps1
      const child = spawn('pwsh', args, { windowsHide: false });
      const pid = child.pid;
      const waitResult = await launchAndWait({
        mapPath: resolve(WORKSPACE_ROOT, scenario.mapPath || ''),
        switcherPath: SWITCHER_PATH,
        gameLogsPath: GAME_LOGS_PATH,
        waitForGameReadyScript: WAIT_PS1,
        maxWaitSeconds: 180,
        gracePeriodSeconds: 20,
      });
      launchResult = { ...waitResult, pid };
    } else {
      // sc2-switcher 模式：直接 SC2Switcher <mapPath>
      launchResult = await launchAndWait({
        mapPath: resolve(WORKSPACE_ROOT, scenario.mapPath),
        switcherPath: SWITCHER_PATH,
        gameLogsPath: GAME_LOGS_PATH,
        waitForGameReadyScript: WAIT_PS1,
        maxWaitSeconds: 180,
        gracePeriodSeconds: 20,
      });
    }
    steps.launch = { durationMs: Date.now() - launchStart, args: args || ['<switcher>', scenario.mapPath] };
    steps.wait = { durationMs: launchResult.durationMs, exitCode: launchResult.exitCode };

    return res.json({
      ok: true,
      data: {
        ok: launchResult.ok,
        exitCode: launchResult.exitCode,
        pid: launchResult.pid,
        scriptErrorContent: launchResult.scriptErrorContent,
        alertsPath: launchResult.alertsPath,
        durationMs: Date.now() - startMs,
        steps,
      },
    });
  } catch (e) {
    return res.status(500).json({
      ok: false,
      error: String(e),
      data: { steps, durationMs: Date.now() - startMs },
    });
  }
});

export { router as scenarioRouter };
