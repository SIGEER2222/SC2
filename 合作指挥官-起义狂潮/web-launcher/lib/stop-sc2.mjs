import { execSync } from 'child_process';

/**
 * 杀掉所有 SC2 进程（SC2_x64.exe 和 SC2Switcher_x64.exe）
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

  return { killed, pids };
}
