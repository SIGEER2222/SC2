import { execSync } from 'child_process';

function sleep(ms) {
  // execSync 是同步阻塞的，但本模块被 async 包裹，用 execSync 的 ping 实现同步等待
  execSync(`ping -n ${Math.max(1, Math.floor(ms / 1000) + 1)} 127.0.0.1 > nul`, {
    windowsHide: true,
    stdio: 'pipe',
  });
}

function waitForProcessesGone(names, maxWaitMs = 10000, pollIntervalMs = 300) {
  const deadline = Date.now() + maxWaitMs;
  while (Date.now() < deadline) {
    let anyRunning = false;
    for (const name of names) {
      try {
        const output = execSync(`tasklist /FI "IMAGENAME eq ${name}" /FO CSV /NH`, {
          encoding: 'utf8',
          windowsHide: true,
        });
        if (output.includes(name)) {
          anyRunning = true;
          break;
        }
      } catch {
        // tasklist 异常视为已退出
      }
    }
    if (!anyRunning) return true;
    sleep(pollIntervalMs);
  }
  return false;
}

/**
 * 杀掉所有 SC2 进程（SC2_x64.exe 和 SC2Switcher_x64.exe），并等待它们真正退出
 * @returns {Promise<{killed: number, pids: number[]}>}
 */
export async function stopAllSc2() {
  const processNames = ['SC2_x64.exe', 'SC2Switcher_x64.exe'];
  const pids = [];

  for (const name of processNames) {
    try {
      const output = execSync(`tasklist /FI "IMAGENAME eq ${name}" /FO CSV /NH`, {
        encoding: 'utf8',
        windowsHide: true,
      });
      const lines = output.trim().split('\n').filter(l => l.includes(name));
      for (const line of lines) {
        const match = line.match(/"(\d+)"/);
        if (match) pids.push(parseInt(match[1], 10));
      }
    } catch {
      // tasklist 失败（如未找到进程），忽略
    }
  }

  let killed = 0;
  for (const pid of pids) {
    try {
      execSync(`taskkill /F /PID ${pid}`, { windowsHide: true });
      killed++;
    } catch {
      // 进程可能已退出
    }
  }

  // 等待进程真正退出，避免下一局启动时文件锁/显存未释放导致立即崩溃
  if (killed > 0) {
    waitForProcessesGone(processNames, 10000, 300);
    // 额外留 1.5s 让 Windows 释放文件句柄和 EXE 锁
    sleep(1500);
  }

  return { killed, pids };
}
