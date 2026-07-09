import { readFileSync, existsSync, readdirSync, statSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SC2_DOCUMENTS = join(process.env.USERPROFILE || 'C:\\Users\\22448', 'Documents', 'StarCraft II');
const BANK_FILE = 'CampaignXCore.SC2Bank';

// 与 PowerShell Get-ScoreConfig 一致
const FIRST_CLEAR_POINTS = 3;
const BONUS_OBJECTIVE_POINT_VALUE = 1;

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
 * 与 PowerShell Normalize-BankMapId 一致：取路径最后一段并去掉 .SC2Map 后缀
 */
export function normalizeBankMapId(mapId) {
  let value = String(mapId ?? '').trim().replace(/\\/g, '/');
  if (!value) return '';
  if (value.includes('/')) {
    const segments = value.split('/');
    value = segments[segments.length - 1];
  }
  return value.replace(/\.SC2Map$/i, '');
}

/**
 * 与 PowerShell Normalize-CommanderClearKey 一致："Commander:MapId"（MapId 规范化）
 */
export function normalizeCommanderClearKey(keyName) {
  const value = String(keyName ?? '');
  if (!value.trim()) return '';
  const separatorIndex = value.indexOf(':');
  if (separatorIndex < 0) return value.trim();
  const commander = value.slice(0, separatorIndex).trim();
  const mapId = normalizeBankMapId(value.slice(separatorIndex + 1));
  if (!commander || !mapId) return value.trim();
  return `${commander}:${mapId}`;
}

/**
 * 解析 Bank XML，提取所有 Section/Key 的 int 与 string 值
 * @param {string} xmlText
 * @returns {Map<string, Map<string, {int: number|null, string: string}>>}
 */
export function parseBankXml(xmlText) {
  const sections = new Map();

  const sectionRegex = /<Section\s+name="([^"]+)"[^>]*>([\s\S]*?)<\/Section>/g;
  let sectionMatch;
  while ((sectionMatch = sectionRegex.exec(xmlText)) !== null) {
    const sectionName = sectionMatch[1];
    const sectionBody = sectionMatch[2];

    const keys = sections.get(sectionName) || new Map();
    const keyRegex = /<Key\s+name="([^"]+)"[^>]*>\s*<Value\s+([^>]*?)\/>\s*<\/Key>/g;
    let keyMatch;
    while ((keyMatch = keyRegex.exec(sectionBody)) !== null) {
      const keyName = decodeEntities(keyMatch[1]);
      const attrsText = keyMatch[2];
      const attrs = {};
      const attrRegex = /(\w+)="([^"]*)"/g;
      let attrMatch;
      while ((attrMatch = attrRegex.exec(attrsText)) !== null) {
        attrs[attrMatch[1]] = decodeEntities(attrMatch[2]);
      }
      const intParsed = Number.parseInt(attrs.int ?? '', 10);
      keys.set(keyName, {
        int: Number.isNaN(intParsed) ? null : intParsed,
        string: attrs.string ?? '',
      });
    }

    if (keys.size > 0) {
      sections.set(sectionName, keys);
    }
  }

  return sections;
}

function getObjectiveStateRecord(keyName, state) {
  let value = String(keyName ?? '');
  if (!value.trim()) return null;
  if (value.startsWith('ObjectiveState/')) {
    value = value.slice('ObjectiveState/'.length);
  }
  // 与 PowerShell Split(":", 4) 一致：最多 4 段，索引段之后的冒号保留在第 4 段
  const parts = value.split(':');
  if (parts.length < 4) return null;
  const commander = parts[0].trim();
  const mapId = normalizeBankMapId(parts[1]);
  const objectiveType = parts[2].trim();
  const indexText = parts.slice(3).join(':').trim();
  if (!/^-?\d+$/.test(indexText)) return null;
  const objectiveIndex = Number.parseInt(indexText, 10);
  if (!commander || !mapId) return null;
  return {
    key: `${commander}:${mapId}:${objectiveType}:${objectiveIndex}`,
    commander,
    mapId,
    objectiveType,
    objectiveIndex,
    state,
  };
}

function buildPointLedger({ commanderClearKeys, commanderBonusScores, objectiveStates }) {
  const firstClearCount = commanderClearKeys.length;
  const commanderBonusPoints = commanderBonusScores.reduce((sum, item) => sum + (Number(item.bonusScore) || 0), 0);
  const objectiveCompletedCount = objectiveStates.filter((o) => o.state === 2).length;
  const firstClearPoints = firstClearCount * FIRST_CLEAR_POINTS;
  const bonusObjectiveCount = Math.max(commanderBonusPoints, objectiveCompletedCount);
  const bonusObjectivePoints = bonusObjectiveCount * BONUS_OBJECTIVE_POINT_VALUE;
  return {
    firstClearCount,
    firstClearPoints,
    bonusObjectiveCount,
    bonusObjectivePoints,
    earnedPoints: firstClearPoints + bonusObjectivePoints,
    objectiveStateSource: objectiveStates.length > 0 ? 'ObjectiveState' : 'CommanderBonus',
  };
}

function emptyCompletion() {
  const completion = {
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
    lastClearTime: null,
  };
  completion.pointLedger = buildPointLedger(completion);
  return completion;
}

/**
 * 从若干 bank 文件内容构建 completion 快照（移植自 PowerShell Get-CompletionSnapshot）
 * @param {Array<{xmlText: string, path: string, mtime: Date}>} banks
 * @returns {Object}
 */
export function buildCompletionFromBanks(banks) {
  if (!banks || banks.length === 0) {
    return emptyCompletion();
  }

  const mapClearIdSet = new Set();
  const commanderClearKeySet = new Set();
  const mapBonusScores = new Map(); // normalized mapId -> max score
  const commanderBonusScores = new Map(); // normalized key -> max score
  const objectiveStateMap = new Map(); // key -> record
  const unlockedBonusSet = new Set();
  const unlockedPrestigeSet = new Set();

  let selectedBankPath = '';
  let selectedBankWriteTime = null;
  let lastMap = '';
  let lastCommander = '';
  let lastClearTime = null;
  let totalWins = 0;

  for (const bank of banks) {
    let sections;
    try {
      sections = parseBankXml(bank.xmlText);
    } catch {
      continue;
    }

    const progression = sections.get('Progression') || new Map();
    if (selectedBankWriteTime === null || bank.mtime > selectedBankWriteTime) {
      selectedBankPath = bank.path;
      selectedBankWriteTime = bank.mtime;
      lastMap = progression.get('LastMap')?.string || '';
      lastCommander = progression.get('LastCommander')?.string || '';
      lastClearTime = progression.get('LastClearTime')?.int ?? null;
      const latestTotalWins = progression.get('TotalWins')?.int ?? 0;
      if (latestTotalWins > totalWins) totalWins = latestTotalWins;
    }

    for (const sectionName of ['MapClear', 'Finished']) {
      for (const [keyName, value] of sections.get(sectionName) || new Map()) {
        const normalizedMapId = normalizeBankMapId(keyName);
        if ((value.int ?? 0) > 0 && normalizedMapId) {
          mapClearIdSet.add(normalizedMapId);
        }
      }
    }

    for (const [keyName, value] of sections.get('CommanderClear') || new Map()) {
      const normalizedKey = normalizeCommanderClearKey(keyName);
      if ((value.int ?? 0) > 0 && normalizedKey) {
        commanderClearKeySet.add(normalizedKey);
      }
    }

    for (const [keyName, value] of sections.get('Bon') || new Map()) {
      const normalizedMapId = normalizeBankMapId(keyName);
      const score = value.int ?? 0;
      if (score > 0 && normalizedMapId) {
        if (!mapBonusScores.has(normalizedMapId) || score > mapBonusScores.get(normalizedMapId)) {
          mapBonusScores.set(normalizedMapId, score);
        }
      }
    }

    for (const [keyName, value] of sections.get('CommanderBonus') || new Map()) {
      const normalizedKey = normalizeCommanderClearKey(keyName);
      const score = value.int ?? 0;
      if (score > 0 && normalizedKey) {
        if (!commanderBonusScores.has(normalizedKey) || score > commanderBonusScores.get(normalizedKey)) {
          commanderBonusScores.set(normalizedKey, score);
        }
      }
    }

    for (const [keyName, value] of progression) {
      if (!keyName.startsWith('ObjectiveState')) continue;
      const state = value.int ?? 0;
      if (state <= 0) continue;
      const record = getObjectiveStateRecord(keyName, state);
      if (record) {
        objectiveStateMap.set(record.key, record);
      }
    }

    for (const [keyName, value] of sections.get('UnlockedBonus') || new Map()) {
      if ((value.int ?? 0) > 0 && keyName.trim()) {
        unlockedBonusSet.add(keyName);
      }
    }

    for (const [keyName, value] of sections.get('UnlockedPrestige') || new Map()) {
      const normalizedKey = normalizeCommanderClearKey(keyName);
      if ((value.int ?? 0) > 0 && normalizedKey) {
        unlockedPrestigeSet.add(normalizedKey);
      }
    }
  }

  const completion = {
    bankFound: true,
    bankPath: selectedBankPath,
    bankLastWriteTime: selectedBankWriteTime ? selectedBankWriteTime.toISOString() : null,
    lastMap: normalizeBankMapId(lastMap),
    lastCommander,
    totalWins,
    lastClearTime: lastClearTime > 0 ? lastClearTime : null,
    mapClearIds: [...mapClearIdSet].sort(),
    commanderClearKeys: [...commanderClearKeySet].sort(),
    mapBonusScores: [...mapBonusScores.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([mapId, bonusScore]) => ({ mapId, bonusScore })),
    commanderBonusScores: [...commanderBonusScores.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([key, bonusScore]) => {
        const separatorIndex = key.indexOf(':');
        return {
          key,
          commander: separatorIndex >= 0 ? key.slice(0, separatorIndex) : key,
          mapId: separatorIndex >= 0 ? key.slice(separatorIndex + 1) : '',
          bonusScore,
        };
      }),
    objectiveStates: [...objectiveStateMap.values()].sort((a, b) => a.key.localeCompare(b.key)),
    unlockedBonuses: [...unlockedBonusSet].sort(),
    unlockedPrestiges: [...unlockedPrestigeSet].sort(),
  };
  completion.pointLedger = buildPointLedger(completion);
  return completion;
}

/**
 * 加载 completion 快照
 * @returns {Object}
 */
export function loadCompletion() {
  const bankFiles = findBankFiles();
  const banks = [];
  for (const file of bankFiles) {
    try {
      banks.push({
        xmlText: readFileSync(file.path, 'utf8'),
        path: file.path,
        mtime: file.mtime,
      });
    } catch {}
  }
  return buildCompletionFromBanks(banks);
}
