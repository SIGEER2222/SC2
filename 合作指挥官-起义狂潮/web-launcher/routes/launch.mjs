import { Router } from 'express';
import { spawn, execSync } from 'child_process';
import { existsSync, readFileSync, mkdirSync, openSync } from 'fs';
import { join, dirname, resolve } from 'path';
import { fileURLToPath } from 'url';
import { buildLaunchArgs, buildCommandLine } from '../services/launch-args-builder.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const WORKSPACE_ROOT = resolve(__dirname, '..', '..');
const LOGS_ROOT = join(WORKSPACE_ROOT, 'logs');

if (!existsSync(LOGS_ROOT)) mkdirSync(LOGS_ROOT, { recursive: true });

// 跟踪已启动的进程：pid -> { process, stdoutPath, stderrPath }
const launchProcesses = new Map();

const router = Router();

/**
 * POST /api/launch
 * 启动一局游戏（spawn pwsh + launch-7vs1-coop-test.ps1）
 */
router.post('/launch', (req, res) => {
  const request = req.body || {};

  let args, score;
  try {
    ({ args, score } = buildLaunchArgs(request));
  } catch (e) {
    return res.status(400).json({ ok: false, error: String(e.message || e) });
  }

  const stamp = new Date().toISOString().replace(/[:.]/g, '-').replace('T', '-').slice(0, 19);
  const stdoutPath = join(LOGS_ROOT, `web-launcher-${stamp}.out.log`);
  const stderrPath = join(LOGS_ROOT, `web-launcher-${stamp}.err.log`);

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
  launchProcesses.set(String(pid), { process: child, stdoutPath, stderrPath });

  // 进程退出后保留跟踪条目：/api/launch-status 需要读取 exitCode 来做
  // 「exit 0 才算验证通过」的判定；若在 exit 时删除条目，轮询到的永远是
  // tasklist 回退路径（running=false, exitCode=null），退出码会丢失。
  child.on('exit', () => {
    // 防止跟踪表无限增长：超过 32 条时淘汰最早的已结束条目
    if (launchProcesses.size > 32) {
      for (const [key, entry] of launchProcesses) {
        if (key !== String(pid) && entry.process.exitCode !== null) {
          launchProcesses.delete(key);
          break;
        }
      }
    }
  });
  child.on('error', () => {
    launchProcesses.delete(String(pid));
  });

  return res.json({
    ok: true,
    pid,
    startedAt: new Date().toISOString(),
    stdout: stdoutPath,
    stderr: stderrPath,
    arguments: args,
    score,
  });
});

/**
 * POST /api/preview
 * 不实际启动，只返回将执行的命令行和积分摘要（dryRunToggle 使用）
 */
router.post('/preview', (req, res) => {
  const request = req.body || {};

  let args, score;
  try {
    ({ args, score } = buildLaunchArgs(request));
  } catch (e) {
    return res.status(400).json({ ok: false, error: String(e.message || e) });
  }

  return res.json({
    ok: true,
    checkedAt: new Date().toISOString(),
    executable: 'pwsh',
    arguments: args,
    score,
    commandLine: buildCommandLine(args),
  });
});

/**
 * POST /api/launch-status
 * 查询进程是否还在运行，并返回 stdout/stderr 尾部 80 行
 */
router.post('/launch-status', (req, res) => {
  const request = req.body || {};
  const pidValue = Number.parseInt(request.pid, 10) || 0;
  const processKey = String(pidValue);

  let trackedProcess = launchProcesses.get(processKey)?.process;
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
 * 读取日志文件尾部 N 行（移植自 PowerShell Get-LogTail）
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

export { router as launchRouter };
