import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { writeFileSync, mkdirSync } from 'fs';
import { loadCommanders } from '../lib/commanders-loader.mjs';
import { loadMaps } from '../lib/maps-loader.mjs';
import { loadMutators } from '../lib/mutators-loader.mjs';
import { loadVoicePacks } from '../lib/voicepacks-loader.mjs';
import { loadCompletion } from '../lib/completion-loader.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const LAUNCH_7VS1_PS1 = join(__dirname, '..', '..', 'scripts', 'launch-7vs1-coop-test.ps1');
const LAUNCH_XM_PS1 = join(__dirname, '..', '..', 'scripts', 'launch-xm-scenario.ps1');
const TMP_DIR = join(__dirname, '..', '.tmp');

// 与 PowerShell 版 allowedGenericBonuses 保持一致
const ALLOWED_GENERIC_BONUSES = new Set([
  'DoubleMinerals', 'DoubleVespene', 'RichResources', 'GuardianShell',
  'CreepRegeneration', 'MechanicalRepair', 'ChronoBoost', 'AbathurBiomassDrop',
  'AllyEarlyDamageReduction', 'AllySustainBoost', 'MaxSupply50', 'ZeroSupply',
]);

const LEVELABLE_GENERIC_BONUSES = new Set(['DoubleMinerals', 'DoubleVespene']);

// 与 PowerShell Get-ScoreConfig 一致
const SCORE_CONFIG = {
  firstCommanderMapClearPoints: 3,
  bonusObjectivePointValue: 1,
  mutatorTierPoints: { normal: 1, medium: 2, hard: 3 },
  mutatorOverrides: [
    { id: 'Random', points: 0 },
    { id: 'CycleRandom', points: 0 },
  ],
  genericBonusCosts: [
    { id: 'DoubleMinerals', costMode: 'perLevel', costPerLevel: 1 },
    { id: 'DoubleVespene', costMode: 'perLevel', costPerLevel: 1 },
    { id: 'RichResources', costMode: 'fixed', cost: 2 },
    { id: 'GuardianShell', costMode: 'fixed', cost: 2 },
    { id: 'CreepRegeneration', costMode: 'fixed', cost: 1 },
    { id: 'MechanicalRepair', costMode: 'fixed', cost: 1 },
    { id: 'ChronoBoost', costMode: 'fixed', cost: 2 },
    { id: 'AbathurBiomassDrop', costMode: 'fixed', cost: 2 },
    { id: 'AllyEarlyDamageReduction', costMode: 'fixed', cost: 2 },
    { id: 'AllySustainBoost', costMode: 'fixed', cost: 3 },
    { id: 'MaxSupply50', costMode: 'fixed', cost: 1 },
    { id: 'ZeroSupply', costMode: 'fixed', cost: 3 },
  ],
};

function getMutatorScorePoints(mutator) {
  const override = SCORE_CONFIG.mutatorOverrides.find(o => o.id === mutator.id);
  if (override) return override.points;
  const tier = mutator.tier || 'normal';
  if (tier === 'hard') return SCORE_CONFIG.mutatorTierPoints.hard;
  if (tier === 'medium') return SCORE_CONFIG.mutatorTierPoints.medium;
  return SCORE_CONFIG.mutatorTierPoints.normal;
}

function getGenericBonusScoreCost(id, level = 0) {
  const rule = SCORE_CONFIG.genericBonusCosts.find(r => r.id === id);
  if (!rule) return 0;
  if (rule.costMode === 'perLevel') {
    return Math.max(0, level) * Math.max(0, rule.costPerLevel);
  }
  return Math.max(0, rule.cost);
}

function clampInt(value, min, max, fallback) {
  const n = Number.parseInt(value, 10);
  if (Number.isFinite(n)) return Math.max(min, Math.min(max, n));
  return fallback;
}

/**
 * 计算启动积分摘要（移植自 PowerShell Get-LaunchScoreSummary）
 */
function getLaunchScoreSummary(request) {
  const completion = loadCompletion();
  const ledger = completion.pointLedger || {};
  const earnedPoints = Number.parseInt(ledger.earnedPoints, 10) || 0;

  const mutatorIds = [...new Set((request.mutators || []).map(String))];
  const mutatorMap = new Map(loadMutators().map(m => [m.id, m]));
  const mutatorBreakdown = mutatorIds.map(id => ({
    id,
    points: getMutatorScorePoints(mutatorMap.get(id) || { id, tier: 'normal' }),
  }));
  const mutatorPoints = mutatorBreakdown.reduce((s, b) => s + b.points, 0);

  const bonusIds = [...new Set((request.genericBonuses || []).map(String))];
  const levels = request.genericBonusLevels || {};
  const bonusBreakdown = bonusIds.map(id => {
    const level = clampInt(levels[id], 0, 9, 0);
    return { id, level, cost: getGenericBonusScoreCost(id, level) };
  });
  const bonusCost = bonusBreakdown.reduce((s, b) => s + b.cost, 0);

  return {
    completion,
    earnedPoints,
    earnedBreakdown: ledger,
    mutatorPoints,
    bonusCost,
    balanceAfterSelection: earnedPoints + mutatorPoints - bonusCost,
    mutatorBreakdown,
    bonusBreakdown,
  };
}

/**
 * 校验并构造 launch-7vs1-coop-test.ps1 的参数列表
 * 移植自 PowerShell ConvertTo-LaunchArgumentList
 * @returns {{args: string[], score: object}}
 */
export function buildLaunchArgs(request) {
  const commanders = loadCommanders();
  const maps = loadMaps();
  const mutators = loadMutators();
  const voicePacks = loadVoicePacks();

  const commander = String(request.commander || '');
  const mapId = String(request.map || '');
  if (!commander || !commanders.find(c => c.runtime === commander)) {
    throw new Error(`Unknown commander: ${commander}`);
  }
  const mapItem = maps.find(m => m.id === mapId);
  if (!mapItem) {
    throw new Error(`Unknown map: ${mapId}`);
  }

  const allowedMutatorIds = new Set(mutators.map(m => m.id));
  const allowedVoicePackIds = new Set(voicePacks.map(v => v.id));

  // 精通等级和精通槽位（向后兼容：旧 payload 可能包含，新 payload 不再使用）
  const masteryLevel = clampInt(request.masteryLevel, 0, 30, 30);
  const masteries = [30, 30, 30, 30, 30, 30];
  if (Array.isArray(request.masteries)) {
    for (let i = 0; i < Math.min(6, request.masteries.length); i++) {
      masteries[i] = clampInt(request.masteries[i], 0, 30, 30);
    }
  }

  // 因子校验
  const selectedMutators = [];
  for (const m of request.mutators || []) {
    const id = String(m);
    if (!id) continue;
    if (!allowedMutatorIds.has(id)) throw new Error(`Unknown mutator: ${id}`);
    if (!selectedMutators.includes(id)) selectedMutators.push(id);
  }

  // 通用加成校验 + 等级规范化（与 PowerShell 行为一致）
  const selectedGenericBonuses = [];
  const selectedGenericBonusLevels = {};
  for (const b of request.genericBonuses || []) {
    const id = String(b);
    if (!id) continue;
    if (!ALLOWED_GENERIC_BONUSES.has(id)) throw new Error(`Unknown generic bonus: ${id}`);
    if (!selectedGenericBonuses.includes(id)) selectedGenericBonuses.push(id);
  }
  if (request.genericBonusLevels && typeof request.genericBonusLevels === 'object') {
    for (const [id, levelVal] of Object.entries(request.genericBonusLevels)) {
      if (!ALLOWED_GENERIC_BONUSES.has(id)) {
        throw new Error(`Unknown generic bonus level target: ${id}`);
      }
      if (!LEVELABLE_GENERIC_BONUSES.has(id)) {
        throw new Error(`Generic bonus '${id}' does not support levels.`);
      }
      const level = clampInt(levelVal, 0, 9, 0);
      if (level > 0) {
        selectedGenericBonusLevels[id] = level;
        if (!selectedGenericBonuses.includes(id)) selectedGenericBonuses.push(id);
      } else {
        delete selectedGenericBonusLevels[id];
      }
    }
  }
  // 已选中但未指定等级的可分级加成，默认等级为 1
  for (const id of LEVELABLE_GENERIC_BONUSES) {
    if (selectedGenericBonuses.includes(id) && !(id in selectedGenericBonusLevels)) {
      selectedGenericBonusLevels[id] = 1;
    }
  }

  // 语音包校验
  let voicePackId = String(request.voicePack || 'Default');
  if (voicePackId === '') voicePackId = 'Default';
  if (!allowedVoicePackIds.has(voicePackId)) {
    throw new Error(`Unknown voice pack: ${voicePackId}`);
  }

  // 指挥官覆盖（commanderOverrides 数组，每个形如 runtime.Key=value）
  const selectedCommanderOverrides = [];
  for (const entry of request.commanderOverrides || []) {
    const text = String(entry);
    if (!text) continue;
    if (!/^[^.]+\.[^=]+=.+$/.test(text)) {
      throw new Error(`Invalid commander override: ${text}`);
    }
    if (!selectedCommanderOverrides.includes(text)) {
      selectedCommanderOverrides.push(text);
    }
  }

  // 启动天赋：若启用且 mask > 0，自动追加一条 commander.StartTalentMask=N 覆盖项
  const enableStartTalents = request.enableStartTalents !== false;
  const startTalentMask = clampInt(request.startTalentMask, 0, Number.MAX_SAFE_INTEGER, 0);
  if (enableStartTalents && startTalentMask > 0) {
    const overrideText = `${commander}.StartTalentMask=${startTalentMask}`;
    if (!selectedCommanderOverrides.includes(overrideText)) {
      selectedCommanderOverrides.push(overrideText);
    }
  }

  // 威望/精通开关（向后兼容变量，不再输出到 args）
  const mutatorPreset = clampInt(request.mutatorPreset, 0, 3, 0);
  const noLaunch = request.noLaunch === true;

  // 构造参数列表（按 PowerShell 版顺序）
  // - launchMode='xm-scenario'：使用 launch-xm-scenario.ps1（轻量，仅写 Bank + SC2Switcher），用 -MapPath
  // - 其他：使用 launch-7vs1-coop-test.ps1（注入 70+ 库），用 -MapSource + -LiveMapName
  const isXmScenario = mapItem.launchMode === 'xm-scenario';
  const launchScript = isXmScenario ? LAUNCH_XM_PS1 : LAUNCH_7VS1_PS1;
  const args = [
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', launchScript,
  ];
  if (isXmScenario) {
    args.push('-MapPath', mapItem.path);
  } else {
    args.push('-MapSource', mapItem.path, '-LiveMapName', mapItem.id);
  }
  args.push(
    '-Commanders', commander,
  );

  // 天赋选择写入临时 JSON 文件
  if (request.talentSelections && typeof request.talentSelections === 'object') {
    mkdirSync(TMP_DIR, { recursive: true });
    const talentFilePath = join(TMP_DIR, `talent-selections-${Date.now()}.json`);
    writeFileSync(talentFilePath, JSON.stringify(request.talentSelections), 'utf8');
    args.push('-TalentSelectionsFile', talentFilePath);
  }

  for (const overrideText of selectedCommanderOverrides) {
    args.push('-CommanderPowerOverride');
    args.push(overrideText);
  }

  if (selectedMutators.length > 0) {
    args.push('-Mutators');
    args.push(selectedMutators.join(','));
  }

  if (selectedGenericBonuses.length > 0) {
    args.push('-GenericBonuses');
    const serialized = selectedGenericBonuses.map(id => {
      if (id in selectedGenericBonusLevels) {
        return `${id}=${selectedGenericBonusLevels[id]}`;
      }
      return id;
    });
    args.push(serialized.join(','));
  }

  args.push('-VoicePack');
  args.push(voicePackId);

  args.push('-MutatorPreset');
  args.push(String(mutatorPreset));

  if (noLaunch) {
    args.push('-NoLaunch');
  }

  const score = getLaunchScoreSummary({
    ...request,
    genericBonuses: selectedGenericBonuses,
    genericBonusLevels: selectedGenericBonusLevels,
    mutators: selectedMutators,
  });

  return { args, score };
}

/**
 * 生成命令行字符串（用于 preview 端点展示）
 */
export function buildCommandLine(args) {
  const parts = args.map(a => {
    if (/[\s"]/.test(a)) {
      return '"' + a.replace(/"/g, '\\"') + '"';
    }
    return a;
  });
  return 'pwsh ' + parts.join(' ');
}
