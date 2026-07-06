import { readFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const WORKSPACE_ROOT = join(__dirname, '..', '..');
const METADATA_PATH = join(WORKSPACE_ROOT, 'Shared', 'CommanderPower', 'commander-power-metadata.json');

/**
 * 加载语音包数据
 * @returns {Array}
 */
export function loadVoicePacks() {
  // 默认项
  const defaultPack = {
    id: 'Default',
    name: '默认',
    storeName: '指挥官默认语音包',
    description: '沿用当前指挥官的默认语音包。',
    typeName: 'Default',
    releaseDate: '',
    rewardIds: {},
  };

  // 1. 读取 metadata 获取 localized_zh_path
  if (!existsSync(METADATA_PATH)) return [defaultPack];

  let metadata;
  try {
    metadata = JSON.parse(readFileSync(METADATA_PATH, 'utf8'));
  } catch {
    return [defaultPack];
  }

  const localizedPath = metadata.source?.localized_zh_path;
  if (!localizedPath || !existsSync(localizedPath)) return [defaultPack];

  // 2. 派生三个源文件路径
  // localized_zh_path 例子：...\liberty.sc2mod\zhcn.sc2data\localizeddata\gamestrings.txt
  // 取其父目录，再上溯三级（绕过 localizeddata → zhcn.sc2data → liberty.sc2mod）
  const libertyModRoot = join(dirname(dirname(dirname(localizedPath))));
  const gameStringsProductPath = join(
    libertyModRoot,
    '..',
    'core.sc2mod',
    'zhcn.sc2data',
    'localizeddata',
    'gamestringsproduct.txt',
  );
  const voicePackDataPath = join(
    libertyModRoot,
    'base.sc2data',
    'gamedata',
    'voicepackdata.xml',
  );
  const rewardDataPath = join(
    libertyModRoot,
    'base.sc2data',
    'gamedata',
    'rewarddata.xml',
  );

  if (!existsSync(gameStringsProductPath) || !existsSync(voicePackDataPath) || !existsSync(rewardDataPath)) {
    return [defaultPack];
  }

  // 3. 解析 gamestringsproduct.txt
  const voicePackNames = new Map();
  const voicePackStoreNames = new Map();
  const voicePackTypeNames = new Map();
  try {
    const text = readFileSync(gameStringsProductPath, 'utf8');
    const lines = text.split(/\r?\n/);
    for (const line of lines) {
      if (!line || line.startsWith('#')) continue;
      const idx = line.indexOf('=');
      if (idx < 1) continue;
      const key = line.substring(0, idx);
      const value = line.substring(idx + 1);

      const nameMatch = key.match(/^VoicePack\/Name\/(.+)$/);
      if (nameMatch) {
        voicePackNames.set(nameMatch[1], value);
        continue;
      }
      const storeNameMatch = key.match(/^VoicePack\/StoreName\/(.+)$/);
      if (storeNameMatch) {
        voicePackStoreNames.set(storeNameMatch[1], value);
        continue;
      }
      const typeNameMatch = key.match(/^VoicePack\/TypeName\/(.+)$/);
      if (typeNameMatch) {
        voicePackTypeNames.set(typeNameMatch[1], value);
        continue;
      }
    }
  } catch {
    return [defaultPack];
  }

  // 4. 解析 voicepackdata.xml
  const voicePackMeta = new Map();
  try {
    const xmlText = readFileSync(voicePackDataPath, 'utf8');
    // 匹配 <CVoicePack id="X"><TypeName value="Y"/><ReleaseDate value="Z"/></CVoicePack>
    const cvoiceRegex = /<CVoicePack\s+id="([^"]+)"[^>]*>([\s\S]*?)<\/CVoicePack>/g;
    let match;
    while ((match = cvoiceRegex.exec(xmlText)) !== null) {
      const id = match[1];
      const body = match[2];
      let typeName = '';
      let releaseDate = '';
      const typeMatch = body.match(/<TypeName\s+value="([^"]+)"\s*\/>/);
      if (typeMatch) typeName = typeMatch[1];
      const dateMatch = body.match(/<ReleaseDate\s+value="([^"]+)"\s*\/>/);
      if (dateMatch) releaseDate = dateMatch[1];
      voicePackMeta.set(id, { typeName, releaseDate });
    }
  } catch {}

  // 5. 解析 rewarddata.xml
  const rewardMap = new Map(); // voicepack id -> {Terran, Protoss, Zerg}
  try {
    const xmlText = readFileSync(rewardDataPath, 'utf8');
    // 匹配 <CRewardVoicePack id="X" voicepack="Y"/>
    const rewardRegex = /<CRewardVoicePack\s+id="([^"]+)"\s+voicepack="([^"]+)"[^>]*\/>/g;
    let match;
    while ((match = rewardRegex.exec(xmlText)) !== null) {
      const rewardId = match[1];
      const voicePackId = match[2];
      // 根据 rewardId 前缀判断种族
      let race = '';
      if (rewardId.startsWith('Terran') || rewardId.startsWith('VoicePackTerran')) race = 'Terran';
      else if (rewardId.startsWith('Protoss') || rewardId.startsWith('VoicePackProtoss')) race = 'Protoss';
      else if (rewardId.startsWith('Zerg') || rewardId.startsWith('VoicePackZerg')) race = 'Zerg';

      if (race) {
        if (!rewardMap.has(voicePackId)) {
          rewardMap.set(voicePackId, { Terran: '', Protoss: '', Zerg: '' });
        }
        rewardMap.get(voicePackId)[race] = rewardId;
      }
    }
  } catch {}

  // 6. 组装 voicePack 列表
  const packs = [defaultPack];
  const ids = new Set([...voicePackNames.keys(), ...voicePackMeta.keys()]);
  const sortedIds = [...ids].sort((a, b) => {
    const sa = voicePackStoreNames.get(a) || voicePackNames.get(a) || a;
    const sb = voicePackStoreNames.get(b) || voicePackNames.get(b) || b;
    return sa.localeCompare(sb);
  });

  for (const id of sortedIds) {
    if (id === 'Default') continue;
    const meta = voicePackMeta.get(id) || {};
    packs.push({
      id,
      name: voicePackNames.get(id) || id,
      storeName: voicePackStoreNames.get(id) || '',
      description: '',
      typeName: meta.typeName || voicePackTypeNames.get(id) || '',
      releaseDate: meta.releaseDate || '',
      rewardIds: rewardMap.get(id) || {},
    });
  }

  return packs;
}
