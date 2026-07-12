import { execSync } from 'child_process';
import { join, resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { existsSync, readFileSync } from 'fs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const WORKSPACE_ROOT = resolve(__dirname, '..', '..');
const CLI_PATH = join(WORKSPACE_ROOT, 'scripts', 'sc2-editor-toolkit', 'cli.mjs');

// 默认配置
const DEFAULT_CONFIG = {
  enablePreLaunchValidation: true,
};

// 加载配置
function loadValidationConfig() {
  const configPath = join(WORKSPACE_ROOT, 'web-launcher', 'config.json');
  if (!existsSync(configPath)) {
    return DEFAULT_CONFIG;
  }
  try {
    const config = JSON.parse(readFileSync(configPath, 'utf8'));
    return { ...DEFAULT_CONFIG, ...config };
  } catch {
    return DEFAULT_CONFIG;
  }
}

/**
 * 运行启动前校验
 * @returns {{ ok: boolean, message?: string, validationResult?: any }}
 */
export function runPreLaunchValidation() {
  const config = loadValidationConfig();
  if (!config.enablePreLaunchValidation) {
    return { ok: true };
  }

  try {
    const result = execSync(
      `node "${CLI_PATH}" check --changed --run --format json`,
      {
        cwd: WORKSPACE_ROOT,
        encoding: 'utf8',
        windowsHide: true,
      }
    );
    const validationResult = JSON.parse(result.trim());
    if (validationResult.ok) {
      return { ok: true, validationResult };
    }
    return {
      ok: false,
      message: '启动前校验失败，请修复问题后重试',
      validationResult,
    };
  } catch (e) {
    return {
      ok: false,
      message: `运行校验失败: ${e.message}`,
      error: e,
    };
  }
}
