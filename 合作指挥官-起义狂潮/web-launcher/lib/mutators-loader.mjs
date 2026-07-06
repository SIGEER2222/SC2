import { readFileSync, existsSync, statSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const WORKSPACE_ROOT = join(__dirname, '..', '..');
const MUTATORS_MOD_ROOT = join(WORKSPACE_ROOT, 'Mods', 'kit_mutations.SC2Mod');
const GAME_DATA_XML = join(MUTATORS_MOD_ROOT, 'Base.SC2Data', 'GameData.xml');
const GAME_DATA_DIR = join(MUTATORS_MOD_ROOT, 'Base.SC2Data', 'GameData');
const MUTATOR_STRINGS = join(MUTATORS_MOD_ROOT, 'zhCN.SC2Data', 'LocalizedData', 'GameStrings.txt');
const ASSETS_CACHE_MUTATORS = join(__dirname, '..', 'assets-cache', 'mutators');

// 解析真实图标 URL：若 assets-cache/mutators/{Id}.png 存在则返回带版本号的 URL
function resolveMutatorImage(id) {
  const fileName = `${id}.png`;
  const filePath = join(ASSETS_CACHE_MUTATORS, fileName);
  if (!existsSync(filePath)) {
    return { image: '', iconReady: false, imageSource: 'missing', imageSourceLabel: '未命中' };
  }
  let version = '';
  try {
    version = `?v=${statSync(filePath).mtimeMs}`;
  } catch {
    version = '';
  }
  return {
    image: `/assets-cache/mutators/${fileName}${version}`,
    iconReady: true,
    imageSource: 'icon-exact',
    imageSourceLabel: '真实图标',
  };
}

// category 硬编码分类（移植自 PowerShell Get-MutatorClass）
const CATEGORY_MAP = {
  environment: new Set([
    'BlackFog', 'TimeWarp', 'Magnificent', 'FireFight', 'LavaBurst', 'TemporalField',
    'Tornadoes', 'OrbitalStrike', 'PurifierBeam', 'Blizzard', 'Nukes', 'UberDarkness',
    'Vertigo', 'AfraidOfTheDark',
  ]),
  enemy: new Set([
    'WalkingInfested', 'InfestedTerranSpawner', 'UnitSpeed', 'Avenger', 'SideStep',
    'DeathAOE', 'DropPods', 'SpawnBroodlings', 'LongRange', 'ReducedVision',
    'HybridNuke', 'AllEnemiesCloaked', 'JustDie', 'Reanimators', 'LifeLeech',
    'OopsAllCasters', 'UndyingEvil', 'Polarity', 'Evolve', 'HeroesFromTheStorm',
    'Inspiration', 'HardenedWill', 'Sluggish', 'DamageReflect', 'DeathPull',
    'Propagate', 'MomentOfSilence',
  ]),
  economy: new Set([
    'Entomb', 'LazyWorkers', 'NoResources', 'OrderCosts', 'TrickOrTreat',
    'FoodHunt', 'SharedSupply', 'RedEnvelopes', 'KillBots', 'BoomBots', 'MissileBarrage',
  ]),
  defense: new Set([
    'Barrier', 'ConcussiveAttacks', 'StoneZealots', 'PhotonOverload', 'SpiderMines',
    'DamageBounce', 'Plague', 'StructureSteal', 'GiftFight', 'KillKarma', 'Insubordination',
  ]),
  random: new Set(['Random', 'CycleRandom']),
};

const TIER_HARD = new Set([
  'VoidRifts', 'Nukes', 'MissileBarrage', 'Polarity', 'Propagate', 'KillBots',
  'BoomBots', 'MomentOfSilence', 'HeroesFromTheStorm', 'JustDie', 'Avenger',
  'LifeLeech', 'Evolve', 'DamageReflect', 'DeathPull', 'Plague',
]);

const TIER_MEDIUM = new Set([
  'BlackFog', 'TimeWarp', 'UnitSpeed', 'Magnificent', 'DeathAOE', 'DropPods',
  'LaserDrill', 'LongRange', 'ReducedVision', 'HybridNuke', 'AllEnemiesCloaked',
  'TemporalField', 'Tornadoes', 'OrbitalStrike', 'PurifierBeam', 'Blizzard', 'Fear',
  'PhotonOverload', 'SpiderMines', 'Reanimators', 'OrderCosts', 'UndyingEvil',
  'UberDarkness', 'FoodHunt', 'SharedSupply', 'DamageBounce', 'StructureSteal',
  'GiftFight', 'KillKarma', 'AfraidOfTheDark', 'Insubordination',
]);

function getMutatorClass(id) {
  let category = 'other';
  if (CATEGORY_MAP.random.has(id)) category = 'random';
  else if (CATEGORY_MAP.environment.has(id)) category = 'environment';
  else if (CATEGORY_MAP.enemy.has(id)) category = 'enemy';
  else if (CATEGORY_MAP.economy.has(id)) category = 'economy';
  else if (CATEGORY_MAP.defense.has(id)) category = 'defense';

  let tier = 'normal';
  if (TIER_HARD.has(id)) tier = 'hard';
  else if (TIER_MEDIUM.has(id)) tier = 'medium';

  return { category, tier };
}

/**
 * 简单的 SC2 富文本剥离（移植自 PowerShell ConvertFrom-SC2Text）
 */
function convertFromSC2Text(text) {
  if (!text) return '';
  let clean = text.replace(/<n\s*\/>/g, ' ');
  clean = clean.replace(/<[^>]+>/g, '');
  clean = clean.replace(/\s+/g, ' ');
  return clean.trim();
}

/**
 * 解析 GameStrings.txt 为 Map（键小写以实现大小写不敏感查找）
 */
function loadStringMap(path) {
  const map = new Map();
  if (!existsSync(path)) return map;

  const text = readFileSync(path, 'utf8');
  const lines = text.split(/\r?\n/);
  for (const line of lines) {
    if (!line || line.startsWith('#')) continue;
    const idx = line.indexOf('=');
    if (idx < 1) continue;
    const key = line.substring(0, idx).toLowerCase();
    const value = convertFromSC2Text(line.substring(idx + 1));
    map.set(key, value);
  }
  return map;
}

/**
 * 简易 XML 解析：从 XML 字符串中提取 CUser id="Mutators" 的所有 Instance
 * 不依赖第三方库，用正则提取（mutator XML 结构规整）
 */
function parseMutatorInstances(xmlText) {
  const instances = [];

  // 找到 <CUser id="Mutators">...</CUser> 块
  const cuserMatch = xmlText.match(/<CUser\s+id="Mutators"[^>]*>([\s\S]*?)<\/CUser>/);
  if (!cuserMatch) return instances;

  const cuserBody = cuserMatch[1];

  // 找到所有 <Instances Id="...">...</Instances> 块
  const instanceRegex = /<Instances\s+Id="([^"]+)"[^>]*>([\s\S]*?)<\/Instances>/g;
  let match;
  while ((match = instanceRegex.exec(cuserBody)) !== null) {
    const id = match[1];
    if (!id || id === '[Default]') continue;

    const body = match[2];

    // 检查是否有 CustomAllowed=1
    const customAllowedMatch = body.match(/<Int\s+Int="1"[^>]*>\s*<Field\s+Id="CustomAllowed"\s*\/>\s*<\/Int>/);
    if (!customAllowedMatch) continue;

    // 提取图标
    let icon = '';
    const iconMatch = body.match(/<Image\s+Image="([^"]+)"[^>]*>\s*<Field\s+Id="Icon"\s*\/>\s*<\/Image>/);
    if (iconMatch) icon = iconMatch[1];

    instances.push({ id, icon });
  }

  return instances;
}

/**
 * 加载所有 mutators
 * @returns {Array} mutator 数组
 */
export function loadMutators() {
  if (!existsSync(GAME_DATA_XML)) return [];

  // 1. 读取 GameData.xml 的 Includes 列表
  const gameDataXml = readFileSync(GAME_DATA_XML, 'utf8');
  const includeRegex = /<Catalog\s+path="([^"]+)"\s*\/>/g;
  const includePaths = [];
  let match;
  while ((match = includeRegex.exec(gameDataXml)) !== null) {
    // 剥离 'GameData/' 前缀
    const relPath = match[1].replace(/^GameData\//, '');
    includePaths.push(relPath);
  }

  // 2. 遍历所有分片，提取 CUser id="Mutators" 的 Instance
  const instances = [];
  for (const relPath of includePaths) {
    const fullPath = join(GAME_DATA_DIR, relPath);
    if (!existsSync(fullPath)) continue;

    const xmlText = readFileSync(fullPath, 'utf8');
    const parsed = parseMutatorInstances(xmlText);
    instances.push(...parsed);
  }

  // 3. 加载本地化字符串
  const stringMap = loadStringMap(MUTATOR_STRINGS);

  // 4. 组装 mutator 对象
  const mutators = [];
  for (const inst of instances) {
    const nameKey = `UserData/Mutators/${inst.id}_Name`.toLowerCase();
    const descKey = `UserData/Mutators/${inst.id}_Description`.toLowerCase();
    const name = stringMap.get(nameKey) || inst.id;
    const description = stringMap.get(descKey) || '';
    const { category, tier } = getMutatorClass(inst.id);

    mutators.push({
      id: inst.id,
      name,
      description,
      icon: inst.icon || '',
      ...resolveMutatorImage(inst.id),
      category,
      tier,
    });
  }

  return mutators;
}
