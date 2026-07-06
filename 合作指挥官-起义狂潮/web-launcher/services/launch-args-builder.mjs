import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const LAUNCH_7VS1_PS1 = join(__dirname, '..', '..', 'scripts', 'launch-7vs1-coop-test.ps1');

/**
 * 构造启动参数
 * @param {Object} ctx
 * @param {Object} ctx.scenario - maps.json 中的场景对象
 * @param {Object} ctx.userSelection - 用户选择（覆盖 defaultArgs）
 * @returns {string[]|null} PowerShell 调用参数，或 null（不需要 PS 脚本）
 */
export function buildLaunchArgs({ scenario, userSelection = {} }) {
  if (scenario.launchMode === 'sc2-switcher') {
    return null;
  }

  const merged = { ...scenario.defaultArgs, ...userSelection };

  const args = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', LAUNCH_7VS1_PS1];

  if (merged.commander) {
    args.push('-Commander', merged.commander);
  }
  if (merged.prestige) {
    args.push('-Prestige', String(merged.prestige));
  }
  if (merged.masteryLevel !== undefined) {
    args.push('-MasteryLevel', String(merged.masteryLevel));
  }
  if (merged.mutators && merged.mutators.length > 0) {
    args.push('-Mutators', merged.mutators.join(','));
  }
  if (merged.mapPath) {
    args.push('-MapPath', merged.mapPath);
  } else if (scenario.mapPath) {
    args.push('-MapPath', scenario.mapPath);
  }

  return args;
}
