import { Router } from 'express';
import { getScenariosByTab } from '../services/scenario-registry.mjs';
import { readFileSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const MAPS_JSON = join(__dirname, '..', 'maps.json');
const METADATA_PATH = join(__dirname, '..', '..', 'Shared', 'CommanderPower', 'commander-power-metadata.json');

const router = Router();

router.get('/bootstrap', (req, res) => {
  const scenariosA = getScenariosByTab(MAPS_JSON, 'A');
  const scenariosB = getScenariosByTab(MAPS_JSON, 'B');

  let commanderMetadata = null;
  if (existsSync(METADATA_PATH)) {
    try {
      commanderMetadata = JSON.parse(readFileSync(METADATA_PATH, 'utf8'));
    } catch {
      commanderMetadata = null;
    }
  }

  res.json({
    ok: true,
    data: {
      scenariosA,
      scenariosB,
      commanderMetadata,
    },
  });
});

export { router as bootstrapRouter };
