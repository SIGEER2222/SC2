import { readdirSync, existsSync, readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const WORKSPACE_ROOT = join(__dirname, '..', '..');
const MAPS_ROOT = join(WORKSPACE_ROOT, 'Maps');

/**
 * 从 GameStrings.txt 读取地图显示名
 * @param {string} mapDir 地图目录绝对路径
 * @returns {string} 地图名（未找到则返回空字符串）
 */
function readMapTitle(mapDir) {
  const gameStringsPath = join(mapDir, 'zhCN.SC2Data', 'LocalizedData', 'GameStrings.txt');
  if (!existsSync(gameStringsPath)) return '';

  try {
    const text = readFileSync(gameStringsPath, 'utf8');
    const lines = text.split(/\r?\n/);
    for (const line of lines) {
      // 查找 DocInfo/Name= 行
      const match = line.match(/^DocInfo\/Name=(.+)$/);
      if (match) return match[1].trim();
    }
  } catch {
    // 读取失败返回空
  }
  return '';
}

/**
 * 加载所有 7vs1 与 XM 地图
 * - `*_7vs1.SC2Map`：通过 launch-7vs1-coop-test.ps1 启动（注入 70+ 库）
 * - `*_xm.SC2Map`：通过 launch-xm-scenario.ps1 启动（轻量，仅写 Bank + SC2Switcher）
 * @returns {Array} 地图数组
 */
export function loadMaps() {
  if (!existsSync(MAPS_ROOT)) return [];

  const maps = [];
  const entries = readdirSync(MAPS_ROOT, { withFileTypes: true });

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;

    // 同时匹配 7vs1 与 XM 地图目录
    let launchMode = null;
    if (entry.name.endsWith('_7vs1.SC2Map')) {
      launchMode = '7vs1';
    } else if (entry.name.endsWith('_xm.SC2Map')) {
      launchMode = 'xm-scenario';
    } else {
      continue;
    }

    const mapDir = join(MAPS_ROOT, entry.name);
    const title = readMapTitle(mapDir);
    const displayName = title ? `${title} (${entry.name})` : entry.name;

    maps.push({
      id: entry.name,
      displayName,
      title,
      path: mapDir,
      launchMode,
    });
  }

  return maps;
}
