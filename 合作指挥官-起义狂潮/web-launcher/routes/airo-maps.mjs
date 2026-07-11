import { Router } from 'express';
import { existsSync, readFileSync, readdirSync } from 'fs';
import { join, dirname, resolve } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const WORKSPACE_ROOT = resolve(join(__dirname, '..', '..'));
const MAP_PROFILES_DIR = join(WORKSPACE_ROOT, 'Mods', 'AIRO', 'MapProfiles');

const router = Router();

/**
 * GET /api/airo-maps
 * 返回 AIRO 地图列表，扫描 Mods/AIRO/MapProfiles/*.json
 * 排除 defaults.json
 * 每个条目包含：id、mapId、mapName、mapFile、mapFamily
 */
router.get('/airo-maps', (req, res) => {
  if (!existsSync(MAP_PROFILES_DIR)) {
    return res.json({ ok: true, maps: [] });
  }

  const files = readdirSync(MAP_PROFILES_DIR).filter(
    (f) => f.endsWith('.json') && f !== 'defaults.json'
  );

  const maps = [];
  for (const file of files) {
    const filePath = join(MAP_PROFILES_DIR, file);
    try {
      const data = JSON.parse(readFileSync(filePath, 'utf8'));
      const id = file.replace(/\.json$/, '');
      maps.push({
        id,
        mapId: data.mapId || id,
        mapName: data.mapName || id,
        mapFile: data.mapFile || `${id}.SC2Map`,
        mapFamily: data.mapFamily || 'AIRO',
      });
    } catch {
      // 跳过解析失败的文件
    }
  }

  // traynor01 排第一（默认地图），其余按字母排序
  maps.sort((a, b) => {
    if (a.id === 'traynor01') return -1;
    if (b.id === 'traynor01') return 1;
    return a.id.localeCompare(b.id);
  });

  res.json({ ok: true, maps });
});

export { router as airoMapsRouter };
