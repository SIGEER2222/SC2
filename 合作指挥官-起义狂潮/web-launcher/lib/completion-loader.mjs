import { readFileSync, existsSync, readdirSync, statSync } from 'fs';
import { join, basename, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SC2_DOCUMENTS = join(process.env.USERPROFILE || 'C:\\Users\\22448', 'Documents', 'StarCraft II');
const BANK_FILE = 'CampaignXCore.SC2Bank';

/**
 * 递归查找所有 CampaignXCore.SC2Bank 文件
 * @returns {Array<{path: string, mtime: Date}>}
 */
function findBankFiles() {
  const results = [];

  // 主路径：Banks\
  const mainBank = join(SC2_DOCUMENTS, 'Banks', BANK_FILE);
  if (existsSync(mainBank)) {
    try {
      const st = statSync(mainBank);
      results.push({ path: mainBank, mtime: st.mtime });
    } catch {}
  }

  // 账户级路径：Accounts\...\CampaignXCore.SC2Bank
  const accountsDir = join(SC2_DOCUMENTS, 'Accounts');
  if (existsSync(accountsDir)) {
    try {
      const accountDirs = readdirSync(accountsDir, { withFileTypes: true });
      for (const dir of accountDirs) {
        if (!dir.isDirectory()) continue;
        const accountBank = join(accountsDir, dir.name, BANK_FILE);
        if (existsSync(accountBank)) {
          // 排除 backup 目录
          if (accountBank.toLowerCase().includes('\\backup\\')) continue;
          try {
            const st = statSync(accountBank);
            results.push({ path: accountBank, mtime: st.mtime });
          } catch {}
        }
      }
    } catch {}
  }

  // 按 mtime 倒序
  results.sort((a, b) => b.mtime - a.mtime);
  return results;
}

/**
 * 简易 XML 文本转义
 */
function decodeEntities(text) {
  if (!text) return '';
  return text
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');
}

/**
 * 解析 Bank XML，提取所有 Section/Key/Value
 * @param {string} xmlText
 * @returns {Map<string, Map<string, string>>} section -> key -> value
 */
function parseBankXml(xmlText) {
  const sections = new Map();

  // 匹配 <Section name="X">...</Section>
  const sectionRegex = /<Section\s+name="([^"]+)"[^>]*>([\s\S]*?)<\/Section>/g;
  let sectionMatch;
  while ((sectionMatch = sectionRegex.exec(xmlText)) !== null) {
    const sectionName = sectionMatch[1];
    const sectionBody = sectionMatch[2];

    const keys = new Map();
    // 匹配 <Key name="Y"><Value int="N"/></Key> 或 <Key name="Y"><Value string="..."/></Key>
    const keyRegex = /<Key\s+name="([^"]+)"[^>]*>\s*<Value\s+(?:int|string|fixed|flags|text)="([^"]*)"[^>]*\s*\/>\s*<\/Key>/g;
    let keyMatch;
    while ((keyMatch = keyRegex.exec(sectionBody)) !== null) {
      const keyName = keyMatch[1];
      const value = decodeEntities(keyMatch[2]);
      keys.set(keyName, value);
    }

    if (keys.size > 0) {
      sections.set(sectionName, keys);
    }
  }

  return sections;
}

/**
 * 加载 completion 快照
 * @returns {Object}
 */
export function loadCompletion() {
  const bankFiles = findBankFiles();
  if (bankFiles.length === 0) {
    return {
      bankFound: false,
      bankPath: '',
      bankLastWriteTime: null,
      lastMap: '',
      lastCommander: '',
      mapClearIds: [],
      commanderClearKeys: [],
      mapBonusScores: [],
      commanderBonusScores: [],
      objectiveStates: [],
      unlockedBonuses: [],
      unlockedPrestiges: [],
      totalWins: 0,
      lastClearTime: 0,
      pointLedger: {
        firstClearCount: 0,
        firstClearPoints: 0,
        bonusObjectiveCount: 0,
        bonusObjectivePoints: 0,
        earnedPoints: 0,
        objectiveStateSource: 'ObjectiveState',
      },
    };
  }

  const selected = bankFiles[0];
  let sections = new Map();
  try {
    const xmlText = readFileSync(selected.path, 'utf8');
    sections = parseBankXml(xmlText);
  } catch {}

  // 提取各种数据
  const mapClearIds = [];
  const commanderClearKeys = [];
  const mapBonusScores = [];
  const commanderBonusScores = [];
  const objectiveStates = [];
  const unlockedBonuses = [];
  const unlockedPrestiges = [];

  const mapClear = sections.get('MapClear') || new Map();
  for (const [key] of mapClear) {
    mapClearIds.push(key);
    commanderClearKeys.push(key);
  }

  const unlockedBonusSection = sections.get('UnlockedBonuses') || new Map();
  for (const [key, value] of unlockedBonusSection) {
    if (value === '1' || value === 'true') unlockedBonuses.push(key);
  }

  const unlockedPrestigeSection = sections.get('UnlockedPrestiges') || new Map();
  for (const [key, value] of unlockedPrestigeSection) {
    if (value === '1' || value === 'true') unlockedPrestiges.push(key);
  }

  const objectiveSection = sections.get('ObjectiveState') || new Map();
  for (const [key, value] of objectiveSection) {
    const parts = key.split(':');
    if (parts.length >= 4) {
      objectiveStates.push({
        key,
        commander: parts[0] || '',
        mapId: parts[1] || '',
        objectiveType: parts[2] || '',
        objectiveIndex: parseInt(parts[3] || '0', 10),
        state: parseInt(value || '0', 10),
      });
    }
  }

  const mapBonusSection = sections.get('MapBonusScore') || new Map();
  for (const [key, value] of mapBonusSection) {
    mapBonusScores.push({ key, score: parseInt(value || '0', 10) });
  }

  const cmdrBonusSection = sections.get('CommanderBonusScore') || new Map();
  for (const [key, value] of cmdrBonusSection) {
    commanderBonusScores.push({ key, score: parseInt(value || '0', 10) });
  }

  const progression = sections.get('Progression') || new Map();
  const lastMap = progression.get('LastMap') || '';
  const lastCommander = progression.get('LastCommander') || '';
  const lastClearTime = parseInt(progression.get('LastClearTime') || '0', 10);
  const totalWins = parseInt(progression.get('TotalWins') || '0', 10);

  const firstClearCount = mapClearIds.length;
  const firstClearPoints = firstClearCount * 3;
  const bonusObjectiveCount = objectiveStates.filter(
    (o) => o.objectiveType === 'Bonus' && o.state >= 2,
  ).length;
  const bonusObjectivePoints = bonusObjectiveCount * 1;
  const earnedPoints = firstClearPoints + bonusObjectivePoints;

  return {
    bankFound: true,
    bankPath: selected.path,
    bankLastWriteTime: selected.mtime.toISOString(),
    lastMap,
    lastCommander,
    mapClearIds,
    commanderClearKeys,
    mapBonusScores,
    commanderBonusScores,
    objectiveStates,
    unlockedBonuses,
    unlockedPrestiges,
    totalWins,
    lastClearTime,
    pointLedger: {
      firstClearCount,
      firstClearPoints,
      bonusObjectiveCount,
      bonusObjectivePoints,
      earnedPoints,
      objectiveStateSource: 'ObjectiveState',
    },
  };
}
