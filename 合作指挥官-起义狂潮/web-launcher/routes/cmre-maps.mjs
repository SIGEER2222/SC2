import { Router } from 'express';
import { existsSync, readdirSync } from 'fs';
import { join, dirname, resolve } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const WORKSPACE_ROOT = resolve(join(__dirname, '..', '..'));
const MAPS_DIR = join(WORKSPACE_ROOT, 'Maps', 'CMRE');

const router = Router();

/**
 * GET /api/cmre-maps
 * 返回 CMRE 地图列表，扫描 Maps/CMRE/ 目录下的 .SC2Map 目录
 * 每个条目包含：id、mapId、mapName、mapFile、mapFamily
 */
router.get('/cmre-maps', (req, res) => {
  if (!existsSync(MAPS_DIR)) {
    return res.json({ ok: true, maps: [] });
  }

  const dirs = readdirSync(MAPS_DIR, { withFileTypes: true })
    .filter(dir => dir.isDirectory() && dir.name.endsWith('.SC2Map'));

  const maps = [];
  for (const dir of dirs) {
    const id = dir.name.replace(/\.SC2Map$/, '');
    maps.push({
      id,
      mapId: id,
      mapName: id,
      mapFile: dir.name,
      mapFamily: 'CMRE',
    });
  }

  // 按字母排序
  maps.sort((a, b) => a.id.localeCompare(b.id));

  res.json({ ok: true, maps });
});

export { router as cmreMapsRouter };
