import { Router } from 'express';
import { spawn, execSync } from 'child_process';
import { existsSync, readFileSync, mkdirSync, openSync } from 'fs';
import { join, dirname, resolve } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const WORKSPACE_ROOT = resolve(__dirname, '..', '..');
const LOGS_ROOT = join(WORKSPACE_ROOT, 'logs');
const LAUNCH_AIRO_PS1 = join(__dirname, '..', '..', 'scripts', 'airo', 'launch-airo-campaign.ps1');

if (!existsSync(LOGS_ROOT)) mkdirSync(LOGS_ROOT, { recursive: true });

// 跟踪已启动的 AIRO 进程：pid -> { process, stdoutPath, stderrPath }
const airoLaunchProcesses = new Map();

const router = Router();

/**
 * POST /api/airo-launch
 * 启动 AI 起义狂潮战役（spawn pwsh + launch-airo-campaign.ps1）
 */
router.post('/airo-launch', (req, res) => {
  const request = req.body || {};
  const commander = String(request.commander || '').trim();
  const mapName = String(request.mapName || '').trim();
  const dryRun = Boolean(request.dryRun);
  const noLaunch = Boolean(request.noLaunch);

  if (!commander) {
    return res.status(400).json({ ok: false, error: '缺少 commander 参数' });
  }

  const args = [
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', LAUNCH_AIRO_PS1,
    '-Commander', commander,
  ];

  if (mapName) {
    args.push('-MapName', mapName);
  }
  if (dryRun) {
    args.push('-DryRun');
  }
  if (noLaunch) {
    args.push('-NoLaunch');
  }

  const stamp = new Date().toISOString().replace(/[:.]/g, '-').replace('T', '-').slice(0, 19);
  const stdoutPath = join(LOGS_ROOT, `web-launcher-airo-${stamp}.out.log`);
  const stderrPath = join(LOGS_ROOT, `web-launcher-airo-${stamp}.err.log`);

  let child;
  try {
    const outFd = openSync(stdoutPath, 'w');
    const errFd = openSync(stderrPath, 'w');
    child = spawn('pwsh', args, {
      cwd: WORKSPACE_ROOT,
      detached: false,
      windowsHide: true,
      stdio: ['ignore', outFd, errFd],
    });
  } catch (e) {
    return res.status(500).json({ ok: false, error: `启动进程失败: ${String(e.message || e)}` });
  }

  const pid = child.pid;
  airoLaunchProcesses.set(String(pid), { process: child, stdoutPath, stderrPath });

  child.on('exit', () => {
    if (airoLaunchProcesses.size > 32) {
      for (const [key, entry] of airoLaunchProcesses) {
        if (key !== String(pid) && entry.process.exitCode !== null) {
          airoLaunchProcesses.delete(key);
          break;
        }
      }
    }
  });
  child.on('error', () => {
    airoLaunchProcesses.delete(String(pid));
  });

  return res.json({
    ok: true,
    pid,
    startedAt: new Date().toISOString(),
    stdout: stdoutPath,
    stderr: stderrPath,
    arguments: args,
  });
});

/**
 * POST /api/airo-launch-status
 * 查询 AIRO 进程是否还在运行，并返回 stdout/stderr 尾部 80 行
 */
router.post('/airo-launch-status', (req, res) => {
  const request = req.body || {};
  const pidValue = Number.parseInt(request.pid, 10) || 0;
  const processKey = String(pidValue);

  let trackedProcess = airoLaunchProcesses.get(processKey)?.process;
  let running = false;
  let exitCode = null;

  if (trackedProcess) {
    running = !trackedProcess.killed && trackedProcess.exitCode === null && trackedProcess.signalCode === null;
    if (!running) {
      exitCode = trackedProcess.exitCode ?? null;
    }
  } else if (pidValue > 0) {
    try {
      const out = execSync(`tasklist /FI "PID eq ${pidValue}" /FO CSV /NH`, {
        encoding: 'utf8',
        windowsHide: true,
      });
      running = out.includes(String(pidValue));
    } catch {
      running = false;
    }
  }

  return res.json({
    ok: true,
    pid: pidValue,
    running,
    checkedAt: new Date().toISOString(),
    exitCode,
    stdout: {
      path: String(request.stdout || ''),
      tail: readLogTail(String(request.stdout || '')),
    },
    stderr: {
      path: String(request.stderr || ''),
      tail: readLogTail(String(request.stderr || '')),
    },
  });
});

/**
 * 读取日志文件尾部 N 行
 * 安全校验：路径必须在 LOGS_ROOT 下
 */
function readLogTail(path, tail = 80) {
  if (!path) return '';
  const fullPath = resolve(path);
  const logsRootFull = resolve(LOGS_ROOT);
  if (!fullPath.toLowerCase().startsWith(logsRootFull.toLowerCase())) {
    return '';
  }
  if (!existsSync(fullPath)) return '';
  try {
    const text = readFileSync(fullPath, 'utf8');
    const lines = text.split(/\r?\n/);
    return lines.slice(Math.max(0, lines.length - tail)).join('\n');
  } catch {
    return '';
  }
}

export { router as airoLaunchRouter };
