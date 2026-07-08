import { readFileSync, existsSync, readdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const WORKSPACE_ROOT = join(__dirname, '..', '..');
const TALENTS_DIR = join(WORKSPACE_ROOT, 'Shared', 'Talents');

/**
 * Load talent configs from Shared/Talents/*.json
 *
 * Returns a Map keyed by commander runtime name (e.g. "ZergAbathur") to a talent
 * config object with shape:
 *   { commander, display_name, talents: [...] }
 *
 * Each talent entry is normalized to camelCase fields:
 *   { id, type, name, description, category, maxLevel?, upgrade?, pointIncrement?,
 *     valueFormat?, upgrades[], suppressUpgrades[], supplementUpgrades[],
 *     enableUnits[], disableUnits[], enableAbils[], disableAbils[], extraOptions[] }
 */
export function loadTalentsCatalog() {
  const catalog = new Map();

  if (!existsSync(TALENTS_DIR)) {
    return catalog;
  }

  const files = readdirSync(TALENTS_DIR).filter(f => f.toLowerCase().endsWith('.json'));
  for (const file of files) {
    const fullPath = join(TALENTS_DIR, file);
    try {
      const raw = JSON.parse(readFileSync(fullPath, 'utf8'));
      if (!raw || !raw.commander) continue;

      const commander = String(raw.commander);
      const talents = (raw.talents || []).map(normalizeTalentEntry);
      catalog.set(commander, {
        commander,
        displayName: raw.display_name || commander,
        talents,
      });
    } catch (err) {
      console.warn(`[talents-loader] Failed to parse ${file}: ${err.message}`);
    }
  }

  return catalog;
}

function normalizeTalentEntry(raw) {
  const entry = {
    id: String(raw.id || ''),
    type: String(raw.type || 'switch'),
    name: String(raw.name || raw.id || ''),
    description: String(raw.description || ''),
    category: String(raw.category || ''),
  };

  if (raw.max_level != null) entry.maxLevel = Number(raw.max_level);
  if (raw.upgrade != null) entry.upgrade = String(raw.upgrade);
  if (raw.point_increment != null) entry.pointIncrement = Number(raw.point_increment);
  if (raw.value_format != null) entry.valueFormat = String(raw.value_format);

  entry.upgrades = stringifyArray(raw.upgrades);
  entry.suppressUpgrades = stringifyArray(raw.suppress_upgrades);
  entry.supplementUpgrades = stringifyArray(raw.supplement_upgrades);
  entry.enableUnits = stringifyArray(raw.enable_units);
  entry.disableUnits = stringifyArray(raw.disable_units);
  entry.enableAbils = stringifyArray(raw.enable_abils);
  entry.disableAbils = stringifyArray(raw.disable_abils);

  entry.extraOptions = (raw.extra_options || []).map(opt => ({
    id: String(opt.id || ''),
    name: String(opt.name || opt.id || ''),
    description: String(opt.description || ''),
    upgrade: String(opt.upgrade || ''),
  }));

  return entry;
}

function stringifyArray(value) {
  if (!Array.isArray(value)) return [];
  return value.map(v => String(v));
}
