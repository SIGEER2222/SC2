import { Router } from 'express';
import { getScenariosByTab } from '../services/scenario-registry.mjs';
import { loadCommanders } from '../lib/commanders-loader.mjs';
import { loadMaps } from '../lib/maps-loader.mjs';
import { loadMutators } from '../lib/mutators-loader.mjs';
import { loadVoicePacks } from '../lib/voicepacks-loader.mjs';
import { loadCompletion } from '../lib/completion-loader.mjs';
import { dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const MAPS_JSON = `${__dirname}/../maps.json`;

const router = Router();

// 硬编码配置（移植自 PowerShell Get-ScoreConfig + Get-BootstrapData）
function getScoreSystem() {
  return {
    version: '2026-06-16',
    firstCommanderMapClearPoints: 3,
    bonusObjectivePointValue: 1,
    mutatorTierPoints: { normal: 1, medium: 2, hard: 3 },
    mutatorOverrides: [
      { id: 'Random', points: 0, note: '随机入口不单独计分' },
      { id: 'CycleRandom', points: 0, note: '轮换随机不单独计分' },
    ],
    genericBonusCosts: [
      { id: 'DoubleMinerals', costMode: 'perLevel', costPerLevel: 1, label: '矿物储量倍率' },
      { id: 'DoubleVespene', costMode: 'perLevel', costPerLevel: 1, label: '瓦斯储量倍率' },
      { id: 'RichResources', costMode: 'fixed', cost: 2, label: '高产矿脉与瓦斯' },
      { id: 'GuardianShell', costMode: 'fixed', cost: 2, label: '守护者之壳' },
      { id: 'CreepRegeneration', costMode: 'fixed', cost: 1, label: '菌毯回血' },
      { id: 'MechanicalRepair', costMode: 'fixed', cost: 1, label: '机械维修' },
      { id: 'ChronoBoost', costMode: 'fixed', cost: 2, label: '时空加速' },
      { id: 'AbathurBiomassDrop', costMode: 'fixed', cost: 2, label: '生物质掉落' },
      { id: 'AllyEarlyDamageReduction', costMode: 'fixed', cost: 2, label: '盟友开局减伤' },
      { id: 'AllySustainBoost', costMode: 'fixed', cost: 3, label: '盟友持续强化' },
      { id: 'MaxSupply50', costMode: 'fixed', cost: 1, label: '人口上限+50' },
      { id: 'ZeroSupply', costMode: 'fixed', cost: 3, label: '单位0人口' },
    ],
  };
}

function getResourcePlan() {
  return {
    text: '指挥官 / 因子文字与协议元数据已接入',
    icons: '本地缓存真实 SC2 贴图；优先命中提取图标，缺失项回退到同主题游戏贴图',
    audio: '已支持通过 Bank 覆盖官方语音包；当前自动枚举本地官方语音包',
  };
}

router.get('/bootstrap', (req, res) => {
  const scenariosA = getScenariosByTab(MAPS_JSON, 'A');
  const scenariosB = getScenariosByTab(MAPS_JSON, 'B');

  const commanders = loadCommanders();
  const maps = loadMaps();
  const mutators = loadMutators();
  const voicePacks = loadVoicePacks();
  const completion = loadCompletion();

  const defaults = {
    commander: commanders.length > 0 ? commanders[0].runtime : '',
    map: maps.length > 0 ? 'ttosh02_7vs1.SC2Map' : '',
    masteryLevel: 15,
    masterySlots: [15, 15, 15, 15, 15, 15],
    prestigeBonusMask: 7,
    prestigePointIndex: -1,
    enableMasteries: true,
    enablePrestiges: true,
    commanderOverrides: [],
    voicePack: 'Default',
    genericBonuses: [],
    genericBonusLevels: {},
    mutatorPreset: 0,
  };

  const counts = {
    commanders: commanders.length,
    maps: maps.length,
    mutators: mutators.length,
  };

  res.json({
    ok: true,
    data: {
      generatedAt: new Date().toISOString(),
      workspaceRoot: __dirname,
      launchScript: '',
      counts,
      defaults,
      commanders,
      maps,
      mutators,
      voicePacks,
      completion,
      scoreSystem: getScoreSystem(),
      resourcePlan: getResourcePlan(),
      scenariosA,
      scenariosB,
    },
  });
});

export { router as bootstrapRouter };
