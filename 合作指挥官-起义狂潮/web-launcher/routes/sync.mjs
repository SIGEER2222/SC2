import { Router } from 'express';
import { syncMods, syncMaps, syncAll } from '../lib/sync-mods-and-maps.mjs';
import { stopAllSc2 } from '../lib/stop-sc2.mjs';
import { loadScenarios } from '../services/scenario-registry.mjs';
import { fileURLToPath } from 'url';
import { dirname, join, resolve } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const MAPS_JSON = join(__dirname, '..', 'maps.json');
const WORKSPACE_ROOT = resolve(__dirname, '..', '..');
const SC2_ROOT = 'E:/SC2/SC2new/StarCraft II';

const router = Router();

function resolveModNames(scenarioIds) {
  if (!scenarioIds || scenarioIds.length === 0) return [];
  const scenarios = loadScenarios(MAPS_JSON);
  const names = new Set();
  for (const id of scenarioIds) {
    const s = scenarios.find(x => x.id === id);
    if (s && s.requiredMods) {
      for (const m of s.requiredMods) names.add(m);
    }
  }
  return Array.from(names);
}

function resolveMapPaths(scenarioIds) {
  if (!scenarioIds || scenarioIds.length === 0) return [];
  const scenarios = loadScenarios(MAPS_JSON);
  const paths = new Set();
  for (const id of scenarioIds) {
    const s = scenarios.find(x => x.id === id);
    if (s && s.mapPath) paths.add(s.mapPath);
  }
  return Array.from(paths);
}

router.post('/sync-mods', (req, res) => {
  try {
    const { scenarioIds } = req.body || {};
    const modNames = resolveModNames(scenarioIds);
    const result = syncMods({
      modNames,
      workspaceRoot: WORKSPACE_ROOT,
      sc2Root: SC2_ROOT,
    });
    res.json({ ok: true, data: result });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e) });
  }
});

router.post('/sync-maps', (req, res) => {
  try {
    const { scenarioIds } = req.body || {};
    const mapPaths = resolveMapPaths(scenarioIds);
    const result = syncMaps({
      mapPaths,
      workspaceRoot: WORKSPACE_ROOT,
      sc2Root: SC2_ROOT,
    });
    res.json({ ok: true, data: result });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e) });
  }
});

router.post('/sync-all', (req, res) => {
  try {
    const { scenarioIds } = req.body || {};
    const modNames = resolveModNames(scenarioIds);
    const mapPaths = resolveMapPaths(scenarioIds);
    const result = syncAll({
      modNames,
      mapPaths,
      workspaceRoot: WORKSPACE_ROOT,
      sc2Root: SC2_ROOT,
    });
    res.json({ ok: true, data: result });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e) });
  }
});

router.post('/stop-sc2', async (req, res) => {
  try {
    const result = await stopAllSc2();
    res.json({ ok: true, data: result });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e) });
  }
});

export { router as syncRouter };
