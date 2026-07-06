import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DEFAULT_MAPS_JSON = join(__dirname, '..', 'maps.json');

/**
 * 加载所有场景
 * @param {string} [mapsJsonPath]
 * @returns {Array}
 */
export function loadScenarios(mapsJsonPath = DEFAULT_MAPS_JSON) {
  const content = readFileSync(mapsJsonPath, 'utf8');
  const data = JSON.parse(content);
  return data.scenarios || [];
}

/**
 * 按 id 查找场景
 * @param {string} mapsJsonPath
 * @param {string} id
 * @returns {Object|null}
 */
export function getScenario(mapsJsonPath, id) {
  const list = loadScenarios(mapsJsonPath);
  return list.find(s => s.id === id) || null;
}

/**
 * 按 tab 过滤场景
 * @param {string} mapsJsonPath
 * @param {string} tab - 'A' or 'B'
 * @returns {Array}
 */
export function getScenariosByTab(mapsJsonPath, tab) {
  const list = loadScenarios(mapsJsonPath);
  return list.filter(s => s.tab === tab);
}
