import { Router } from 'express';
import { spawn, execSync } from 'child_process';
import { existsSync, readFileSync, mkdirSync, openSync } from 'fs';
import { join, dirname, resolve } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const WORKSPACE_ROOT = resolve(__dirname, '..', '..');
const LOGS_ROOT = join(WORKSPACE_ROOT, 'logs');
const LAUNCH_REBORN_PS1 = join(__dirname, '..', '..', 'scripts', 'reborn', 'launch-reborn-commander.ps1');

if (!existsSync(LOGS_ROOT)) mkdirSync(LOGS_ROOT, { recursive: true });

// 跟踪已启动的 Reborn 进程：pid -> { process, stdoutPath, stderrPath }
const rebornLaunchProcesses = new Map();

const router = Router();

/**
 * POST /api/reborn-launch
 * 启动 Reborn 战役（spawn pwsh + launch-reborn-commander.ps1）
 */
router.post('/reborn-launch', (req, res) => {
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
    '-File', LAUNCH_REBORN_PS1,
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
  const stdoutPath = join(LOGS_ROOT, `web-launcher-reborn-${stamp}.out.log`);
  const stderrPath = join(LOGS_ROOT, `web-launcher-reborn-${stamp}.err.log`);

  let child;
  try {
    // 用 stdio 重定向到文件，与 PowerShell 版 Start-Process -RedirectStandardOutput/StdError 等价
    const outFd = openSync(stdoutPath, 'w');
    const errFd = openSync(stderrPath, 'w');
    child = spawn('pwsh', args, {
      cwd: WORKSPACE_ROOT,
      detached: false,
      windowsHide: true,
      stdio: ['ignore', outFd, errFd],
    });
    // 子进程会继承 fd，父进程可以关闭自己的引用
    // 注意：不 close fd，避免子进程还没写完就被关闭
  } catch (e) {
    return res.status(500).json({ ok: false, error: `启动进程失败: ${String(e.message || e)}` });
  }

  const pid = child.pid;
  rebornLaunchProcesses.set(String(pid), { process: child, stdoutPath, stderrPath });

  // 进程退出后保留跟踪条目：/api/reborn-launch-status 需要读取 exitCode 来做
  // 「exit 0 才算启动成功」的判定；若在 exit 时删除条目，轮询到的永远是
  // tasklist 回退路径（running=false, exitCode=null），退出码会丢失。
  child.on('exit', () => {
    // 防止跟踪表无限增长：超过 32 条时淘汰最早的已结束条目
    if (rebornLaunchProcesses.size > 32) {
      for (const [key, entry] of rebornLaunchProcesses) {
        if (key !== String(pid) && entry.process.exitCode !== null) {
          rebornLaunchProcesses.delete(key);
          break;
        }
      }
    }
  });
  child.on('error', () => {
    rebornLaunchProcesses.delete(String(pid));
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
 * POST /api/reborn-launch-status
 * 查询 Reborn 进程是否还在运行，并返回 stdout/stderr 尾部 80 行
 */
router.post('/reborn-launch-status', (req, res) => {
  const request = req.body || {};
  const pidValue = Number.parseInt(request.pid, 10) || 0;
  const processKey = String(pidValue);

  let trackedProcess = rebornLaunchProcesses.get(processKey)?.process;
  let running = false;
  let exitCode = null;

  if (trackedProcess) {
    running = !trackedProcess.killed && trackedProcess.exitCode === null && trackedProcess.signalCode === null;
    if (!running) {
      exitCode = trackedProcess.exitCode ?? null;
    }
  } else if (pidValue > 0) {
    // 已不在跟踪表中，检查进程是否仍在运行（通过 tasklist）
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
 * 读取日志文件尾部 N 行（移植自 launch.mjs 的 readLogTail）
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

export { router as rebornLaunchRouter };
