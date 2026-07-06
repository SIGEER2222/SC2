import { spawn } from 'child_process';
import { existsSync, readFileSync, readdirSync, statSync } from 'fs';
import { join } from 'path';

/**
 * 解析 wait-for-game-ready.ps1 的退出码
 */
export function parseWaitExitCode(code) {
  if (code === 0) return { ok: true };
  if (code === 1) return { ok: false, reason: 'script_error' };
  if (code === 2) return { ok: false, reason: 'timeout' };
  return { ok: false, reason: 'unknown' };
}

/**
 * 构造 SC2Switcher 启动命令
 */
export function buildLaunchCommand({ mapPath, switcherPath }) {
  return {
    executable: switcherPath,
    args: [mapPath],
  };
}

function findLatestLog(gameLogsPath, pattern) {
  if (!existsSync(gameLogsPath)) return null;
  try {
    const files = readdirSync(gameLogsPath)
      .filter(f => f.includes(pattern))
      .map(f => {
        const p = join(gameLogsPath, f);
        return { name: f, path: p, mtime: statSync(p).mtimeMs };
      })
      .sort((a, b) => b.mtime - a.mtime);
    return files[0] || null;
  } catch {
    return null;
  }
}

/**
 * 启动游戏并等待 scripterror 检测完成
 */
export async function launchAndWait(opts) {
  const {
    mapPath,
    switcherPath = 'E:/SC2/SC2new/StarCraft II/Support64/SC2Switcher_x64.exe',
    gameLogsPath = 'C:/Users/22448/Documents/StarCraft II/GameLogs',
    waitForGameReadyScript = null,
    maxWaitSeconds = 180,
    gracePeriodSeconds = 20,
  } = opts;

  const startMs = Date.now();
  const cmd = buildLaunchCommand({ mapPath, switcherPath });

  const child = spawn(cmd.executable, cmd.args, {
    detached: false,
    windowsHide: false,
  });

  const pid = child.pid;

  if (!waitForGameReadyScript) {
    return {
      ok: true,
      exitCode: 0,
      pid,
      scriptErrorContent: null,
      alertsPath: null,
      durationMs: Date.now() - startMs,
    };
  }

  // 给 SC2Switcher 启动 SC2_x64 留出时间，避免 wait 脚本一开始就因检测不到进程而误判退出
  await new Promise((r) => setTimeout(r, 3000));

  // spawn wait-for-game-ready.ps1
  const waitChild = spawn('pwsh', [
    '-NoProfile',
    '-File',
    waitForGameReadyScript,
    '-MaxWaitSeconds', String(maxWaitSeconds),
    '-GracePeriodSeconds', String(gracePeriodSeconds),
  ], { windowsHide: true });

  const exitCode = await new Promise((resolve) => {
    waitChild.on('exit', resolve);
    waitChild.on('error', () => resolve(99));
  });

  // 读取 ScriptError 内容
  const scriptErrorLog = findLatestLog(gameLogsPath, 'ScriptError');
  let scriptErrorContent = null;
  if (scriptErrorLog) {
    try {
      scriptErrorContent = readFileSync(scriptErrorLog.path, 'utf8');
    } catch {
      scriptErrorContent = null;
    }
  }

  const alertsLog = findLatestLog(gameLogsPath, 'Alerts');
  const parsed = parseWaitExitCode(exitCode);

  return {
    ok: parsed.ok,
    exitCode,
    pid,
    scriptErrorContent,
    alertsPath: alertsLog ? alertsLog.path : null,
    durationMs: Date.now() - startMs,
  };
}
