import { renderQuickPickers as renderQuickPickersComponent } from "./components/quick-pickers.js";
import {
  renderMutatorGrid as renderMutatorGridComponent,
  renderSelectedMutatorPanel as renderSelectedMutatorPanelComponent,
} from "./components/mutator-panels.js";
import {
  renderGenericBonusPanel as renderGenericBonusPanelComponent,
  renderStartTalentPanel as renderStartTalentPanelComponent,
  renderVoicePackPanel as renderVoicePackPanelComponent,
} from "./components/commander-panels.js";
import { renderTalentPanel as renderTalentPanelComponent } from "./components/talent-panel.js";
import {
  renderLaunchHistoryPanel as renderLaunchHistoryPanelComponent,
  renderMutatorPresetOptionsPanel as renderMutatorPresetOptionsPanelComponent,
  renderRecentConfigsPanel as renderRecentConfigsPanelComponent,
  renderScenarioPresetsPanel as renderScenarioPresetsPanelComponent,
} from "./components/list-panels.js";
import {
  updateBootstrapStripPanel as updateBootstrapStripPanelComponent,
  updateScorePanel as updateScorePanelComponent,
  updateSummaryDetailPanel as updateSummaryDetailPanelComponent,
  updateSummaryPanel as updateSummaryPanelComponent,
} from "./components/summary-panels.js";
import { escapeHtml, getStatusToneClass, initials } from "./lib/ui-helpers.js";

const DEFAULT_ACTIVE_SHEET = "mutators";
const SHEET_IDS = new Set(["mutators", "talents", "startTalents", "voicepacks", "bonuses", "output"]);

const state = {
  data: null,
  selectedMutators: new Set(),
  selectedCommanderOverrides: new Set(),
  selectedGenericBonuses: new Set(),
  selectedVoicePackId: "Default",
  genericBonusLevels: {
    DoubleMinerals: 0,
    DoubleVespene: 0,
  },
  selectedMutatorPanelExpanded: false,
  talentSelections: {},
  startTalentMaskMode: "default",
  activeSheet: DEFAULT_ACTIVE_SHEET,
  autosaveTimer: null,
  launchPollTimer: null,
  bootstrapRetryTimer: null,
  serviceUnavailable: false,
  lastLogPaths: null,
  lastValidatedSignature: "",
  lastValidationDetail: null,
  lastValidatedPayload: null,
};

const STORAGE_KEY = "sc2-7vs1-web-launcher-config";
const RECENT_KEY = "sc2-7vs1-web-launcher-recent";
const MUTATOR_PRESET_KEY = "sc2-7vs1-web-launcher-mutator-presets";
const LAUNCH_HISTORY_KEY = "sc2-7vs1-web-launcher-launch-history";
const SCENARIO_PRESET_KEY = "sc2-7vs1-web-launcher-scenario-presets";
const UI_STATE_KEY = "sc2-7vs1-web-launcher-ui-state";
const MAX_RECENT = 6;
const MAX_LAUNCH_HISTORY = 8;
const MAX_SCENARIO_PRESETS = 16;
const SERVICE_RETRY_MS = 1500;
const GENERIC_BONUS_OPTIONS = [
  { id: "DoubleMinerals", name: "矿物储量倍率", description: "每加 1 点，所有矿点当前与上限储量额外增加 100%。1 级为 x2，9 级为 x10。", maxLevel: 9 },
  { id: "DoubleVespene", name: "瓦斯储量倍率", description: "每加 1 点，所有气矿当前与上限储量额外增加 100%。1 级为 x2，9 级为 x10。", maxLevel: 9 },
  { id: "RichResources", name: "高产矿脉与瓦斯", description: "提高资源采集效率并保留当前储量，晶体矿脉与瓦斯节点替换为高产模型。" },
  { id: "GuardianShell", name: "守护者之壳", description: "获得阿塔尼斯的守护者之壳被动。" },
  { id: "CreepRegeneration", name: "菌毯回血", description: "获得凯瑞甘菌毯回血效果。" },
  { id: "MechanicalRepair", name: "机械维修", description: "机械单位周期性自我修复。" },
  { id: "ChronoBoost", name: "时空加速", description: "基地旁控制建筑获得一次全图时空加速主动技能。" },
  { id: "AbathurBiomassDrop", name: "生物质掉落", description: "引入阿巴瑟的生物质特性：敌方非建筑单位死亡时掉落可拾取的生物质。" },
  { id: "AllyEarlyDamageReduction", name: "盟友开局减伤", description: "有剧情盟友的地图中，真实盟友单位在开局 5 分钟内受到伤害降低 90%。" },
  { id: "AllySustainBoost", name: "盟友持续强化", description: "有剧情盟友的地图中，真实盟友获得通用攻防升级，并周期性补满生命和护盾。" },
  { id: "MaxSupply50", name: "人口上限+50", description: "人口上限额外增加 50。" },
  { id: "ZeroSupply", name: "单位0人口", description: "启用公共层 0/200 供给脚本：定时把人口上限设为 200，并将现有单位改为不占人口。" },
];
const LEVELABLE_GENERIC_BONUS_IDS = new Set(
  GENERIC_BONUS_OPTIONS.filter((item) => Number.isFinite(item.maxLevel) && item.maxLevel > 0).map((item) => item.id),
);

function createDefaultGenericBonusLevels() {
  return {
    DoubleMinerals: 0,
    DoubleVespene: 0,
  };
}

function clampGenericBonusLevel(id, value) {
  const option = GENERIC_BONUS_OPTIONS.find((item) => item.id === id);
  const maxLevel = Number.isFinite(option?.maxLevel) ? option.maxLevel : 0;
  return clampNumber(value, 0, maxLevel, 0);
}

function normalizeGenericBonusLevels(levels = {}, genericBonuses = []) {
  const normalized = createDefaultGenericBonusLevels();
  for (const id of LEVELABLE_GENERIC_BONUS_IDS) {
    if (Object.prototype.hasOwnProperty.call(levels || {}, id)) {
      normalized[id] = clampGenericBonusLevel(id, levels[id]);
    } else if ((genericBonuses || []).includes(id)) {
      normalized[id] = 1;
    }
  }
  return normalized;
}

function getSelectedGenericBonusIds(selectedBonusIds = state.selectedGenericBonuses, genericBonusLevels = state.genericBonusLevels) {
  const ids = new Set(selectedBonusIds || []);
  for (const id of LEVELABLE_GENERIC_BONUS_IDS) {
    if (clampGenericBonusLevel(id, genericBonusLevels?.[id] ?? 0) > 0) {
      ids.add(id);
    } else {
      ids.delete(id);
    }
  }
  return [...ids].sort();
}

function getGenericBonusDisplayName(id, genericBonusLevels = state.genericBonusLevels) {
  const label = getGenericBonusLabel(id);
  if (LEVELABLE_GENERIC_BONUS_IDS.has(id)) {
    const level = clampGenericBonusLevel(id, genericBonusLevels?.[id] ?? 0);
    if (level > 0) {
      return `${label} Lv${level}`;
    }
  }
  return label;
}

function normalizeActiveSheet(value) {
  const sheet = String(value || "").trim();
  return SHEET_IDS.has(sheet) ? sheet : DEFAULT_ACTIVE_SHEET;
}

function syncActiveSheetUI() {
  const activeSheet = normalizeActiveSheet(state.activeSheet);
  state.activeSheet = activeSheet;
  for (const tab of el.sheetTabs) {
    const sheet = normalizeActiveSheet(tab.dataset.sheetTab);
    const selected = sheet === activeSheet;
    tab.classList.toggle("active", selected);
    tab.setAttribute("aria-selected", selected ? "true" : "false");
    tab.tabIndex = selected ? 0 : -1;
  }
  for (const panel of el.sheetPanels) {
    const sheet = normalizeActiveSheet(panel.dataset.sheetPanel);
    panel.hidden = sheet !== activeSheet;
  }
}

function setActiveSheet(sheet, options = {}) {
  const nextSheet = normalizeActiveSheet(sheet);
  const changed = state.activeSheet !== nextSheet;
  state.activeSheet = nextSheet;
  syncActiveSheetUI();
  if (options.persist !== false && changed) {
    writeUiState({ activeSheet: state.activeSheet });
  }
}

const el = {
  dataStatus: document.querySelector("#dataStatus"),
  selectionSummary: document.querySelector("#selectionSummary"),
  summaryCommander: document.querySelector("#summaryCommander"),
  summaryMap: document.querySelector("#summaryMap"),
  summaryMastery: document.querySelector("#summaryMastery"),
  summaryMutators: document.querySelector("#summaryMutators"),
  summaryPoints: document.querySelector("#summaryPoints"),
  summaryMode: document.querySelector("#summaryMode"),
  summaryValidation: document.querySelector("#summaryValidation"),
  copySummaryButton: document.querySelector("#copySummaryButton"),
  configIssues: document.querySelector("#configIssues"),
  voicePackList: document.querySelector("#voicePackList"),
  voicePackBadge: document.querySelector("#voicePackBadge"),
  voicePackCurrentLabel: document.querySelector("#voicePackCurrentLabel"),
  voicePackRaceReward: document.querySelector("#voicePackRaceReward"),
  voicePackMode: document.querySelector("#voicePackMode"),
  sheetTabs: [...document.querySelectorAll("[data-sheet-tab]")],
  sheetPanels: [...document.querySelectorAll("[data-sheet-panel]")],
  bootstrapCommanderCount: document.querySelector("#bootstrapCommanderCount"),
  bootstrapMapCount: document.querySelector("#bootstrapMapCount"),
  bootstrapMutatorCount: document.querySelector("#bootstrapMutatorCount"),
  bootstrapCompletionStatus: document.querySelector("#bootstrapCompletionStatus"),
  bootstrapScoreStatus: document.querySelector("#bootstrapScoreStatus"),
  bootstrapResourcePlanText: document.querySelector("#bootstrapResourcePlanText"),
  commanderSelect: document.querySelector("#commanderSelect"),
  mapSelect: document.querySelector("#mapSelect"),
  commanderQuickList: document.querySelector("#commanderQuickList"),
  commanderQuickCount: document.querySelector("#commanderQuickCount"),
  mapQuickList: document.querySelector("#mapQuickList"),
  commanderId: document.querySelector("#commanderId"),
  scenarioPresetName: document.querySelector("#scenarioPresetName"),
  scenarioPresets: document.querySelector("#scenarioPresets"),
  saveScenarioPreset: document.querySelector("#saveScenarioPreset"),
  clearScenarioPresets: document.querySelector("#clearScenarioPresets"),
  recentConfigs: document.querySelector("#recentConfigs"),
  clearRecentButton: document.querySelector("#clearRecentButton"),
  talentPanel: document.querySelector("#talentPanel"),
  prestigeFusionStatus: document.querySelector("#prestigeFusionStatus"),
  genericBonusList: document.querySelector("#genericBonusList"),
  scoreBudgetBadge: document.querySelector("#scoreBudgetBadge"),
  scoreAvailablePoints: document.querySelector("#scoreAvailablePoints"),
  scoreMutatorPoints: document.querySelector("#scoreMutatorPoints"),
  scoreBonusCost: document.querySelector("#scoreBonusCost"),
  scoreBalanceAfter: document.querySelector("#scoreBalanceAfter"),
  scoreCommanderProgress: document.querySelector("#scoreCommanderProgress"),
  scoreDetailText: document.querySelector("#scoreDetailText"),
  scoreRuleText: document.querySelector("#scoreRuleText"),
  startTalentList: document.querySelector("#startTalentList"),
  startTalentStatus: document.querySelector("#startTalentStatus"),
  startTalentMaskBadge: document.querySelector("#startTalentMaskBadge"),
  startTalentMask: document.querySelector("#startTalentMask"),
  enableStartTalents: document.querySelector("#enableStartTalents"),
  mutatorSearch: document.querySelector("#mutatorSearch"),
  mutatorPreset: document.querySelector("#mutatorPreset"),
  mutatorGrid: document.querySelector("#mutatorGrid"),
  mutatorCount: document.querySelector("#mutatorCount"),
  clearMutators: document.querySelector("#clearMutators"),
  dryRunToggle: document.querySelector("#dryRunToggle"),
  refreshButton: document.querySelector("#refreshButton"),
  saveConfigButton: document.querySelector("#saveConfigButton"),
  resetConfigButton: document.querySelector("#resetConfigButton"),
  previewButton: document.querySelector("#previewButton"),
  validateButton: document.querySelector("#validateButton"),
  validateLaunchButton: document.querySelector("#validateLaunchButton"),
  launchButton: document.querySelector("#launchButton"),
  launchState: document.querySelector("#launchState"),
  outputLog: document.querySelector("#outputLog"),
  stdoutPathText: document.querySelector("#stdoutPathText"),
  stderrPathText: document.querySelector("#stderrPathText"),
  copyCommandButton: document.querySelector("#copyCommandButton"),
  copyLogPathsButton: document.querySelector("#copyLogPathsButton"),
  copyOutputButton: document.querySelector("#copyOutputButton"),
  clearOutputButton: document.querySelector("#clearOutputButton"),
  exportPayloadButton: document.querySelector("#exportPayloadButton"),
  copyPayloadButton: document.querySelector("#copyPayloadButton"),
  applyPayloadButton: document.querySelector("#applyPayloadButton"),
  clearPayloadButton: document.querySelector("#clearPayloadButton"),
  payloadText: document.querySelector("#payloadText"),
  payloadStatus: document.querySelector("#payloadStatus"),
  selectedMutators: document.querySelector("#selectedMutators"),
  selectedMutatorSearch: document.querySelector("#selectedMutatorSearch"),
  selectedMutatorStatus: document.querySelector("#selectedMutatorStatus"),
  clearMatchedMutators: document.querySelector("#clearMatchedMutators"),
  toggleSelectedMutators: document.querySelector("#toggleSelectedMutators"),
  mutatorImportText: document.querySelector("#mutatorImportText"),
  applyMutatorImport: document.querySelector("#applyMutatorImport"),
  appendMutatorImport: document.querySelector("#appendMutatorImport"),
  mutatorPresetName: document.querySelector("#mutatorPresetName"),
  savedMutatorPreset: document.querySelector("#savedMutatorPreset"),
  saveMutatorPreset: document.querySelector("#saveMutatorPreset"),
  applyMutatorPreset: document.querySelector("#applyMutatorPreset"),
  deleteMutatorPreset: document.querySelector("#deleteMutatorPreset"),
  mutatorFilter: document.querySelector("#mutatorFilter"),
  mutatorCategoryFilter: document.querySelector("#mutatorCategoryFilter"),
  mutatorTierFilter: document.querySelector("#mutatorTierFilter"),
  randomMutatorCount: document.querySelector("#randomMutatorCount"),
  randomMutators: document.querySelector("#randomMutators"),
  appendRandomMutators: document.querySelector("#appendRandomMutators"),
  randomMutators3: document.querySelector("#randomMutators3"),
  randomMutators5: document.querySelector("#randomMutators5"),
  randomMutators10: document.querySelector("#randomMutators10"),
  copyMutatorIds: document.querySelector("#copyMutatorIds"),
  clearMutatorFilters: document.querySelector("#clearMutatorFilters"),
  mutatorPoolStatus: document.querySelector("#mutatorPoolStatus"),
  launchHistory: document.querySelector("#launchHistory"),
  clearLaunchHistory: document.querySelector("#clearLaunchHistory"),
};

function clampNumber(value, min, max, fallback) {
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed)) return fallback;
  return Math.max(min, Math.min(max, parsed));
}

function parseLooseInteger(value, fallback = 0) {
  const parsed = Number.parseInt(value, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

function normalizeText(value) {
  return String(value || "").replace(/\s+/g, " ").trim();
}

function normalizeVoicePackId(value) {
  const id = String(value || "").trim();
  if (!id) return "Default";
  return state.data?.voicePacks?.some((item) => item.id === id) ? id : "Default";
}

function getCommanderRaceFromRuntime(runtime) {
  const text = String(runtime || "");
  if (text.startsWith("Terran")) return "Terran";
  if (text.startsWith("Protoss")) return "Protoss";
  if (text.startsWith("Zerg")) return "Zerg";
  return "";
}

function getSelectedCommanderRace() {
  return getCommanderRaceFromRuntime(el.commanderSelect?.value);
}

function getVoicePackById(id = state.selectedVoicePackId) {
  return state.data?.voicePacks?.find((item) => item.id === id) || null;
}

function getVoicePackLabel(id = state.selectedVoicePackId) {
  const voicePack = getVoicePackById(id);
  return voicePack?.name || id || "Default";
}

function getCommanderStartTalents(commander = getCommander()) {
  if (!commander) return { defaultMask: 0, talents: [] };
  return commander.startTalents ?? { defaultMask: 0, talents: [] };
}

function getCommanderDefaultStartTalentMask(commander = getCommander()) {
  const talents = getCommanderStartTalents(commander);
  return Number(talents.defaultMask) || 0;
}

function getStartTalentMaxMask(commander = getCommander()) {
  const talents = getCommanderStartTalents(commander);
  let maxMask = 0;
  for (const talent of talents.talents ?? []) {
    maxMask |= Number(talent.bitMask) || 0;
  }
  return maxMask;
}

function getUnlockedBonusSet() {
  return new Set(state.data?.completion?.unlockedBonuses || []);
}

function getUnlockedPrestigeSet() {
  return new Set((state.data?.completion?.unlockedPrestiges || []).map((item) => normalizeCommanderMapClearKey(item)));
}

function isGenericBonusUnlocked(bonusId) {
  return true;
}

function isCommanderPrestigeUnlocked(prestige, commander = getCommander()) {
  return true;
}

function getCommanderOverrideLabels(overrides = [], commanderRuntime = null) {
  return [...overrides].map((overrideValue) => String(overrideValue || ""));
}

function getTalentSummary(runtime) {
  const selections = state.talentSelections?.[runtime] || {};
  const commander = state.data?.commanders?.find((item) => item.runtime === runtime);
  const talents = commander?.talents || [];
  let activeSwitchCount = 0;
  let totalLevel = 0;
  const levelValues = [];
  const activeNames = [];
  for (const talent of talents) {
    if (talent.type === "switch") {
      if (Number(selections[talent.id] || 0) === 1) {
        activeSwitchCount += 1;
        activeNames.push(talent.name || talent.id);
      }
    } else if (talent.type === "level") {
      const level = Math.max(0, Math.min(Number(talent.maxLevel) || 0, Number(selections[talent.id] || 0)));
      totalLevel += level;
      levelValues.push(level);
    }
  }
  return { activeSwitchCount, totalLevel, levelValues, activeNames };
}

function writeOutput(value) {
  const stamp = new Date().toLocaleTimeString("zh-CN", { hour12: false });
  let text = "";
  if (typeof value === "string") {
    text = value;
  } else {
    text = JSON.stringify(value, null, 2);
  }
  el.outputLog.textContent = `[${stamp}]\n${text}`;
  el.copyOutputButton.disabled = false;
}

function readUiState() {
  try {
    const parsed = JSON.parse(localStorage.getItem(UI_STATE_KEY) || "{}");
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
  } catch {
    localStorage.removeItem(UI_STATE_KEY);
    return {};
  }
}

function writeUiState(partial) {
  localStorage.setItem(UI_STATE_KEY, JSON.stringify({
    ...readUiState(),
    ...partial,
  }));
}

function scheduleAutosave() {
  if (!state.data) return;
  if (state.autosaveTimer) {
    clearTimeout(state.autosaveTimer);
  }
  state.autosaveTimer = setTimeout(() => {
    state.autosaveTimer = null;
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(buildLaunchPayload()));
      writeUiState({
        selectedMutatorPanelExpanded: state.selectedMutatorPanelExpanded,
        startTalentMaskMode: state.startTalentMaskMode,
        activeSheet: state.activeSheet,
      });
    } catch (error) {
      writeOutput(`自动保存失败：${error.message}`);
    }
  }, 100);
}

function setPayloadStatus(text, kind = "") {
  el.payloadStatus.className = kind ? `payload-status ${kind}` : "payload-status";
  el.payloadStatus.textContent = text;
}

async function copyText(value) {
  try {
    await navigator.clipboard.writeText(value);
  } catch {
    const textArea = document.createElement("textarea");
    textArea.value = value;
    document.body.append(textArea);
    textArea.select();
    document.execCommand("copy");
    textArea.remove();
  }
}

async function copyOutputLog() {
  const text = el.outputLog.textContent.trim();
  if (!text || text === "等待操作") return;
  await copyText(text);
  el.launchState.textContent = "输出已复制";
}

function setLastLogPaths(stdout, stderr) {
  state.lastLogPaths = {
    stdout: stdout || "",
    stderr: stderr || "",
  };
  el.stdoutPathText.textContent = state.lastLogPaths.stdout ? `stdout: ${state.lastLogPaths.stdout}` : "stdout: -";
  el.stderrPathText.textContent = state.lastLogPaths.stderr ? `stderr: ${state.lastLogPaths.stderr}` : "stderr: -";
  el.stdoutPathText.title = state.lastLogPaths.stdout || "";
  el.stderrPathText.title = state.lastLogPaths.stderr || "";
  el.copyLogPathsButton.disabled = !state.lastLogPaths.stdout && !state.lastLogPaths.stderr;
}

async function copyLogPaths() {
  if (!state.lastLogPaths) return;
  const lines = [
    state.lastLogPaths.stdout ? `stdout=${state.lastLogPaths.stdout}` : "",
    state.lastLogPaths.stderr ? `stderr=${state.lastLogPaths.stderr}` : "",
  ].filter(Boolean);
  if (lines.length === 0) return;
  await copyText(lines.join("\n"));
  el.launchState.textContent = "日志路径已复制";
}

function clearOutputLog() {
  el.outputLog.textContent = "等待操作";
  el.copyOutputButton.disabled = true;
  el.copyCommandButton.disabled = true;
  el.copyCommandButton.dataset.command = "";
  setLastLogPaths("", "");
  el.launchState.textContent = "输出已清空";
}

function formatLaunchStatus(status) {
  const lines = [
    `PID: ${status.pid || "-"}`,
    `状态: ${status.running ? "运行中" : "已结束"}`,
    `退出码: ${status.exitCode ?? "-"}`,
    `检查时间: ${status.checkedAt || "-"}`,
    "",
    `[stdout] ${status.stdout?.path || ""}`,
    status.stdout?.tail || "(空)",
    "",
    `[stderr] ${status.stderr?.path || ""}`,
    status.stderr?.tail || "(空)",
  ];
  return lines.join("\n");
}

function getStatusStderr(status) {
  return String(status?.stderr?.tail || "").trim();
}

function getStatusStdout(status) {
  return String(status?.stdout?.tail || "").trim();
}

function isDryRunComplete(status) {
  const stdout = getStatusStdout(status);
  // launch-7vs1-coop-test.ps1 输出 "Mutator preset:" / "Mutators:"；
  // launch-xm-scenario.ps1（*_xm.SC2Map 地图）不输出因子行，结束标记是 "=== Done ==="
  return stdout.includes("Mutator preset:") || stdout.includes("Mutators:") || stdout.includes("=== Done ===");
}

function setStatus(text, className = "") {
  el.dataStatus.className = className ? `subtle ${className}` : "subtle";
  el.dataStatus.textContent = text;
}

function isFetchFailure(error) {
  const message = String(error?.message || error || "");
  return error instanceof TypeError || message.includes("Failed to fetch") || message.includes("NetworkError");
}

async function apiFetchJson(path, options = {}) {
  let response;
  try {
    response = await fetch(path, options);
  } catch (error) {
    throw new Error(`本地启动器不可用: ${error?.message || error}`);
  }

  let result = null;
  try {
    result = await response.json();
  } catch {
    result = null;
  }

  if (!response.ok || (result && result.ok === false)) {
    throw new Error(result?.error || `${path} ${response.status}`);
  }

  return result;
}

function setServiceUnavailable(message = "本地启动器离线") {
  state.serviceUnavailable = true;
  setStatus(message, "status-error");
  el.launchState.textContent = "服务离线";
  updateConfigActionButtons(true);
}

function clearServiceUnavailable() {
  state.serviceUnavailable = false;
}

function scheduleBootstrapRetry() {
  if (state.bootstrapRetryTimer) {
    return;
  }

  state.bootstrapRetryTimer = setTimeout(() => {
    state.bootstrapRetryTimer = null;
    loadBootstrap().catch(() => {
      scheduleBootstrapRetry();
    });
  }, SERVICE_RETRY_MS);
}

function getMapLabel(id) {
  const map = state.data?.maps.find((item) => item.id === id);
  return map?.title || map?.displayName || id;
}

function getCommanderLabel(id) {
  const commander = state.data?.commanders.find((item) => item.runtime === id);
  return commander?.displayName || id;
}

function getMutatorLabel(id) {
  const mutator = state.data?.mutators.find((item) => item.id === id);
  return mutator?.name || id;
}

function formatTime(value) {
  const date = value ? new Date(value) : new Date();
  if (Number.isNaN(date.getTime())) return "-";
  return date.toLocaleString("zh-CN", { hour12: false });
}

function formatShortTime(value) {
  const date = value ? new Date(value) : new Date();
  if (Number.isNaN(date.getTime())) return "-";
  return date.toLocaleTimeString("zh-CN", { hour12: false });
}

function getCommander() {
  if (!state.data) return null;
  return state.data.commanders.find((item) => item.runtime === el.commanderSelect.value) ?? null;
}

function normalizeMapBankId(mapId) {
  const value = String(mapId || "").trim().replace(/\\/g, "/");
  if (!value) return "";
  const withoutFileExt = value.replace(/\.SC2Map$/i, "");
  const segments = withoutFileExt.split("/").filter(Boolean);
  return segments.length > 0 ? segments[segments.length - 1] : withoutFileExt;
}

function normalizeCommanderMapClearKey(key) {
  const value = String(key || "").trim();
  if (!value) return "";
  const separatorIndex = value.indexOf(":");
  if (separatorIndex < 0) return value;
  const commander = value.slice(0, separatorIndex).trim();
  const mapId = normalizeMapBankId(value.slice(separatorIndex + 1));
  if (!commander || !mapId) return value;
  return `${commander}:${mapId}`;
}

function getScoreRules() {
  return state.data?.scoreSystem || {
    firstCommanderMapClearPoints: 3,
    bonusObjectivePointValue: 1,
    mutatorTierPoints: { normal: 1, medium: 2, hard: 3 },
    mutatorOverrides: [
      { id: "Random", points: 0 },
      { id: "CycleRandom", points: 0 },
    ],
    genericBonusCosts: [
      { id: "DoubleMinerals", costMode: "perLevel", costPerLevel: 1 },
      { id: "DoubleVespene", costMode: "perLevel", costPerLevel: 1 },
      { id: "RichResources", costMode: "fixed", cost: 2 },
      { id: "GuardianShell", costMode: "fixed", cost: 2 },
      { id: "CreepRegeneration", costMode: "fixed", cost: 1 },
      { id: "MechanicalRepair", costMode: "fixed", cost: 1 },
      { id: "ChronoBoost", costMode: "fixed", cost: 2 },
      { id: "AbathurBiomassDrop", costMode: "fixed", cost: 2 },
      { id: "AllyEarlyDamageReduction", costMode: "fixed", cost: 2 },
      { id: "AllySustainBoost", costMode: "fixed", cost: 3 },
      { id: "MaxSupply50", costMode: "fixed", cost: 1 },
      { id: "ZeroSupply", costMode: "fixed", cost: 3 },
    ],
  };
}

function getMapBonusScore(mapId) {
  const normalizedMapId = normalizeMapBankId(mapId);
  for (const entry of state.data?.completion?.mapBonusScores || []) {
    if (normalizeMapBankId(entry?.mapId) === normalizedMapId) {
      return clampNumber(entry?.bonusScore, 0, 99, 0);
    }
  }
  return 0;
}

function getCommanderBonusScore(mapId, commander = getCommander()) {
  const normalizedMapId = normalizeMapBankId(mapId);
  const bankCommander = commander?.bankCommander || "";
  if (!bankCommander || !normalizedMapId) return 0;
  for (const entry of state.data?.completion?.commanderBonusScores || []) {
    if ((entry?.commander || "") !== bankCommander) continue;
    if (normalizeMapBankId(entry?.mapId) !== normalizedMapId) continue;
    return clampNumber(entry?.bonusScore, 0, 99, 0);
  }
  return 0;
}

function getCommanderObjectiveStateStats(mapId, commander = getCommander()) {
  const normalizedMapId = normalizeMapBankId(mapId);
  const bankCommander = commander?.bankCommander || "";
  let completed = 0;
  let failed = 0;
  for (const record of state.data?.completion?.objectiveStates || []) {
    if ((record?.commander || "") !== bankCommander) continue;
    if (normalizeMapBankId(record?.mapId) !== normalizedMapId) continue;
    const stateValue = Number(record?.state || 0);
    if (stateValue === 2) completed += 1;
    if (stateValue === 3) failed += 1;
  }
  return { completed, failed };
}

function getMutatorScorePoints(mutatorId) {
  const rules = getScoreRules();
  const override = (rules.mutatorOverrides || []).find((item) => item.id === mutatorId);
  if (override) {
    return clampNumber(override.points, 0, 99, 0);
  }
  const mutator = state.data?.mutators.find((item) => item.id === mutatorId);
  const tier = mutator?.tier || "normal";
  return clampNumber(rules.mutatorTierPoints?.[tier], 0, 99, 1);
}

function getGenericBonusScoreCost(bonusId, level = 0) {
  const rules = getScoreRules();
  const rule = (rules.genericBonusCosts || []).find((item) => item.id === bonusId);
  if (!rule) return 0;
  if (rule.costMode === "perLevel") {
    return Math.max(0, Number(level || 0)) * Math.max(0, Number(rule.costPerLevel || 0));
  }
  return Math.max(0, Number(rule.cost || 0));
}

function getScoreState(payload = buildLaunchPayload()) {
  const completion = state.data?.completion || {};
  const ledger = completion.pointLedger || {};
  const mutatorIds = Array.isArray(payload.mutators) ? payload.mutators : [];
  const genericBonuses = Array.isArray(payload.genericBonuses) ? payload.genericBonuses : [];
  const genericBonusLevels = normalizeGenericBonusLevels(payload.genericBonusLevels || {}, genericBonuses);
  const mutatorBreakdown = mutatorIds
    .slice()
    .sort()
    .map((id) => ({
      id,
      points: getMutatorScorePoints(id),
      label: getMutatorLabel(id),
    }));
  const bonusBreakdown = genericBonuses
    .slice()
    .sort()
    .map((id) => ({
      id,
      level: clampGenericBonusLevel(id, genericBonusLevels[id]),
      cost: getGenericBonusScoreCost(id, genericBonusLevels[id]),
      label: getGenericBonusDisplayName(id, genericBonusLevels),
    }));
  const mutatorPoints = mutatorBreakdown.reduce((sum, item) => sum + item.points, 0);
  const bonusCost = bonusBreakdown.reduce((sum, item) => sum + item.cost, 0);
  const earnedPoints = Number(ledger.earnedPoints || 0);
  const commander = getCommander();
  const selectedMapId = payload.map;
  const commanderCleared = completion.bankFound === true
    && new Set((completion.commanderClearKeys || []).map((item) => normalizeCommanderMapClearKey(item)))
      .has(normalizeCommanderMapClearKey(`${commander?.bankCommander || ""}:${selectedMapId}`));
  const objectiveStats = getCommanderObjectiveStateStats(selectedMapId, commander);
  const commanderBonusScore = getCommanderBonusScore(selectedMapId, commander);
  const mapBonusScore = getMapBonusScore(selectedMapId);
  return {
    earnedPoints,
    firstClearCount: Number(ledger.firstClearCount || 0),
    firstClearPoints: Number(ledger.firstClearPoints || 0),
    bonusObjectiveCount: Number(ledger.bonusObjectiveCount || 0),
    bonusObjectivePoints: Number(ledger.bonusObjectivePoints || 0),
    objectiveStateSource: ledger.objectiveStateSource || "CommanderBonus",
    mutatorPoints,
    bonusCost,
    balanceAfterSelection: earnedPoints + mutatorPoints - bonusCost,
    mutatorBreakdown,
    bonusBreakdown,
    commanderCleared,
    commanderBonusScore,
    mapBonusScore,
    objectiveStats,
  };
}

function getScoreRuleText() {
  const rules = getScoreRules();
  const mutatorRules = rules.mutatorTierPoints || {};
  const bonusRules = (rules.genericBonusCosts || []).map((item) => {
    if (item.costMode === "perLevel") {
      return `${getGenericBonusLabel(item.id)} 每级 ${item.costPerLevel} 分`;
    }
    return `${getGenericBonusLabel(item.id)} ${item.cost} 分`;
  });
  return [
    `首通 ${rules.firstCommanderMapClearPoints} 分/指挥官地图`,
    `奖励分 ${rules.bonusObjectivePointValue} 分/点`,
    `因子 普通=${mutatorRules.normal ?? 1} / 中等=${mutatorRules.medium ?? 2} / 困难=${mutatorRules.hard ?? 3}`,
    `加成 ${bonusRules.join("；")}`,
  ].join(" · ");
}

function getMapCompletionState(mapId, commander = getCommander()) {
  const completion = state.data?.completion;
  const normalizedMapId = normalizeMapBankId(mapId);
  if (completion?.bankFound !== true) {
    return {
      label: "未读取存档",
      tone: "warn",
      detail: "未找到 CampaignXCore.SC2Bank，当前无法判断这张地图是否已通关。",
    };
  }
  const bankCommander = commander?.bankCommander || "";
  const commanderMapKey = bankCommander ? `${bankCommander}:${normalizedMapId}` : "";
  const mapClearIds = new Set((completion?.mapClearIds || []).map((item) => normalizeMapBankId(item)));
  const commanderClearKeys = new Set((completion?.commanderClearKeys || []).map((item) => normalizeCommanderMapClearKey(item)));
  const mapCleared = mapClearIds.has(normalizedMapId);
  const commanderCleared = commanderMapKey ? commanderClearKeys.has(commanderMapKey) : false;
  const commanderBonusScore = getCommanderBonusScore(normalizedMapId, commander);
  const mapBonusScore = getMapBonusScore(normalizedMapId);
  const objectiveStats = getCommanderObjectiveStateStats(normalizedMapId, commander);
  const bonusCount = Math.max(commanderBonusScore, objectiveStats.completed, mapBonusScore);
  const bonusLabel = bonusCount > 0
    ? commanderBonusScore > 0 || objectiveStats.completed > 0
      ? `奖励 ${bonusCount}`
      : `奖励 ${bonusCount} (地图)`
    : "奖励 0";

  if (commanderCleared) {
    return {
      label: "当前指挥官已通关",
      tone: "ok",
      detail: `来自指挥官通关记录：${commanderMapKey}`,
      meta: bonusLabel,
    };
  }
  if (mapCleared) {
    return {
      label: "地图已通关",
      tone: "warn",
      detail: `来自地图通关记录：${normalizedMapId}。当前地图有通关记录，但未找到当前指挥官专属通关标记。`,
      meta: bonusLabel,
    };
  }
  return {
    label: "未通关",
    tone: "error",
    detail: `存档已读取，但未找到 ${normalizedMapId} 或 ${commanderMapKey || "当前指挥官"} 的通关标记。`,
    meta: bonusLabel,
  };
}

function getGenericBonusMap() {
  return new Map(GENERIC_BONUS_OPTIONS.map((item) => [item.id, item]));
}

function getGenericBonusLabel(id) {
  return getGenericBonusMap().get(id)?.name || id;
}

function renderGenericBonuses() {
  renderGenericBonusPanelComponent({
    container: el.genericBonusList,
    options: GENERIC_BONUS_OPTIONS,
    selectedBonusIds: state.selectedGenericBonuses,
    levelValues: state.genericBonusLevels,
    onToggleBonus: (bonusId, checked) => {
      if (!bonusId) return;
      if (checked) {
        state.selectedGenericBonuses.add(bonusId);
        if (LEVELABLE_GENERIC_BONUS_IDS.has(bonusId) && clampGenericBonusLevel(bonusId, state.genericBonusLevels[bonusId]) === 0) {
          state.genericBonusLevels[bonusId] = 1;
        }
      } else {
        state.selectedGenericBonuses.delete(bonusId);
        if (LEVELABLE_GENERIC_BONUS_IDS.has(bonusId)) {
          state.genericBonusLevels[bonusId] = 0;
        }
      }
      updateSummary();
      scheduleAutosave();
    },
    onSetBonusLevel: (bonusId, nextLevel) => {
      if (!bonusId || !LEVELABLE_GENERIC_BONUS_IDS.has(bonusId)) return;
      const level = clampGenericBonusLevel(bonusId, nextLevel);
      state.genericBonusLevels[bonusId] = level;
      if (level > 0) {
        state.selectedGenericBonuses.add(bonusId);
      } else {
        state.selectedGenericBonuses.delete(bonusId);
      }
      renderGenericBonuses();
      updateSummary();
      scheduleAutosave();
    },
  });
}

function renderVoicePacks() {
  if (!state.data || !el.voicePackList) return;
  const selectedCommanderRace = getSelectedCommanderRace();
  renderVoicePackPanelComponent({
    container: el.voicePackList,
    voicePacks: state.data.voicePacks || [],
    selectedVoicePackId: state.selectedVoicePackId,
    selectedCommanderRace,
    onSelectVoicePack: (voicePackId) => {
      state.selectedVoicePackId = normalizeVoicePackId(voicePackId);
      renderVoicePacks();
      updateSummary();
      scheduleAutosave();
    },
  });
}

function populateSelect(select, items, getValue, getLabel) {
  select.replaceChildren();
  for (const item of items) {
    const option = document.createElement("option");
    option.value = getValue(item);
    option.textContent = getLabel(item);
    select.append(option);
  }
}

function getMapPack(id) {
  const text = String(id || "");
  const match = text.match(/^t([a-z]+)\d/i);
  return match ? match[1].toLowerCase() : "other";
}

function getMapPackLabel(pack) {
  return {
    hanson: "汉森",
    horner: "霍纳",
    raynor: "雷诺",
    tosh: "托什",
    tychus: "泰凯斯",
    valerian: "瓦伦里安",
    zeratul: "泽拉图",
    zerg: "虫群",
    other: "其他",
  }[pack] || pack;
}

function getMutatorCategoryLabel(category) {
  return {
    random: "随机/轮换",
    environment: "环境压力",
    enemy: "敌军强化",
    economy: "经济/操作",
    defense: "防御/反制",
    other: "其他",
  }[category] || category;
}

function getMutatorTierLabel(tier) {
  return {
    normal: "普通",
    medium: "中等",
    hard: "高压",
  }[tier] || tier;
}

function populateMutatorFilters() {
  if (!state.data) return;
  const categories = [...new Set(state.data.mutators.map((item) => item.category || "other"))].sort();
  const tiers = [...new Set(state.data.mutators.map((item) => item.tier || "normal"))].sort();
  populateSelect(
    el.mutatorCategoryFilter,
    ["all", ...categories],
    (item) => item,
    (item) => (item === "all" ? "全部" : getMutatorCategoryLabel(item)),
  );
  populateSelect(
    el.mutatorTierFilter,
    ["all", ...tiers],
    (item) => item,
    (item) => (item === "all" ? "全部" : getMutatorTierLabel(item)),
  );
}

function pickRandom(items) {
  if (!items || items.length === 0) return null;
  return items[Math.floor(Math.random() * items.length)];
}

function selectCommander(runtime) {
  if (!runtime || !state.data?.commanders.some((item) => item.runtime === runtime)) return false;
  el.commanderSelect.value = runtime;
  renderCommanderDetails();
  renderQuickPickers();
  return true;
}

function selectMap(id) {
  if (!id || !state.data?.maps.some((item) => item.id === id)) return false;
  el.mapSelect.value = id;
  updateSummary();
  renderQuickPickers();
  return true;
}

function getFilteredCommanders() {
  if (!state.data) return [];
  return state.data.commanders;
}

function getFilteredMaps() {
  if (!state.data) return [];
  return state.data.maps;
}

function renderQuickPickers() {
  if (!state.data) return;
  renderQuickPickersComponent({
    commanderContainer: el.commanderQuickList,
    mapContainer: el.mapQuickList,
    commanderCountElement: el.commanderQuickCount,
    commanders: getFilteredCommanders(),
    allCommandersCount: state.data.commanders.length,
    maps: getFilteredMaps(),
    selectedCommanderRuntime: el.commanderSelect.value,
    selectedMapId: el.mapSelect.value,
    getMapCompletionState,
    onSelectCommander: selectCommander,
    onSelectMap: selectMap,
  });
}

function renderTalents(commander) {
  if (!commander) return;
  const runtime = commander.runtime || "";
  const selections = state.talentSelections[runtime] || {};
  renderTalentPanelComponent({
    container: el.talentPanel,
    commander,
    selections,
    onToggleTalent: (talentId, checked) => {
      if (!runtime || !talentId) return;
      if (!state.talentSelections[runtime]) state.talentSelections[runtime] = {};
      state.talentSelections[runtime][talentId] = checked ? 1 : 0;
      renderTalents(commander);
      updateSummary();
      scheduleAutosave();
    },
    onSetTalentLevel: (talentId, level) => {
      if (!runtime || !talentId) return;
      if (!state.talentSelections[runtime]) state.talentSelections[runtime] = {};
      state.talentSelections[runtime][talentId] = level;
      renderTalents(commander);
      updateSummary();
      scheduleAutosave();
    },
    onToggleExtraOption: (talentId, optionId, checked) => {
      if (!runtime || !talentId || !optionId) return;
      if (!state.talentSelections[runtime]) state.talentSelections[runtime] = {};
      const key = `${talentId}.extra:${optionId}`;
      state.talentSelections[runtime][key] = checked ? 1 : 0;
      renderTalents(commander);
      updateSummary();
      scheduleAutosave();
    },
  });
}

function renderStartTalents(commander) {
  const defaultMask = getCommanderDefaultStartTalentMask(commander);
  const maxMask = getStartTalentMaxMask(commander);
  // 掩码是位集合，跨指挥官残留的掩码要按位裁剪而不是取数值较小者
  const activeMask = (Number(el.startTalentMask.value) || 0) & maxMask;
  const enabled = el.enableStartTalents.checked;
  renderStartTalentPanelComponent({
    container: el.startTalentList,
    commander,
    activeMask,
    defaultMask,
    enabled,
    onSelectMode: (mode) => {
      const inputs = [...document.querySelectorAll(".start-talent-toggle-input")];
      if (mode === "default") {
        for (const input of inputs) {
          const bitMask = Number(input.dataset.bitMask) || 0;
          input.checked = (defaultMask & bitMask) === bitMask;
        }
        syncStartTalentMaskFromUI("default");
      } else if (mode === "all") {
        for (const input of inputs) input.checked = true;
        syncStartTalentMaskFromUI("custom");
      } else if (mode === "none") {
        for (const input of inputs) input.checked = false;
        syncStartTalentMaskFromUI("custom");
      }
      updateSummary();
    },
    onToggleTalent: () => {
      syncStartTalentMaskFromUI("custom");
      updateSummary();
    },
  });
  const selectedCount = (commander?.startTalents?.talents ?? []).filter(
    (talent) => (activeMask & Number(talent.bitMask)) === Number(talent.bitMask),
  ).length;
  if (el.startTalentStatus) {
    el.startTalentStatus.textContent = `已选 ${selectedCount}`;
  }
  if (el.startTalentMaskBadge) {
    el.startTalentMaskBadge.textContent = String(activeMask);
  }
}

function syncStartTalentMaskFromUI(mode) {
  const inputs = [...document.querySelectorAll(".start-talent-toggle-input")];
  let mask = 0;
  for (const input of inputs) {
    if (input.checked) {
      mask |= Number(input.dataset.bitMask) || 0;
    }
  }
  el.startTalentMask.value = String(mask);
  if (mode === "default" || mode === "custom") {
    state.startTalentMaskMode = mode;
  }
  scheduleAutosave();
}

function renderCommanderDetails() {
  const commander = getCommander();
  if (!commander) return;

  el.commanderId.textContent = commander.runtime;
  el.commanderId.title = commander.integrationNote || "";
  if (state.startTalentMaskMode === "default") {
    el.startTalentMask.value = String(getCommanderDefaultStartTalentMask(commander));
  }
  renderTalents(commander);
  renderStartTalents(commander);
  updateSummary();
}

function renderMutators() {
  if (!state.data) return;

  const mutators = getFilteredMutators();
  const randomPool = getRandomMutatorPool();
  const randomPoolCount = randomPool.length;
  const appendableRandomPoolCount = randomPool.filter((item) => !state.selectedMutators.has(item.id)).length;
  const hasFilter = hasActiveMutatorFilter();

  renderMutatorGridComponent({
    container: el.mutatorGrid,
    mutators,
    selectedMutatorIds: state.selectedMutators,
    getMutatorCategoryLabel,
    getMutatorTierLabel,
    onToggleMutator: (mutatorId) => {
      if (state.selectedMutators.has(mutatorId)) {
        state.selectedMutators.delete(mutatorId);
      } else {
        state.selectedMutators.add(mutatorId);
      }
      renderMutators();
      updateSummary();
    },
  });

  el.mutatorCount.textContent = `${state.selectedMutators.size}/${state.data.mutators.length} · 显示 ${mutators.length}`;
  el.mutatorPoolStatus.textContent = randomPoolCount === 0
    ? "随机池: 0 (先清除筛选)"
    : `随机池: ${randomPoolCount}${hasFilter ? " (已筛选)" : ""}`;
  el.mutatorPoolStatus.className = randomPoolCount === 0
    ? "mutator-pool-status status-error"
    : hasFilter ? "mutator-pool-status status-warn" : "mutator-pool-status status-ok";
  el.clearMutatorFilters.disabled = !hasFilter;
  el.randomMutators.disabled = randomPoolCount === 0;
  el.appendRandomMutators.disabled = appendableRandomPoolCount === 0;
  el.randomMutators3.disabled = randomPoolCount === 0;
  el.randomMutators5.disabled = randomPoolCount === 0;
  el.randomMutators10.disabled = randomPoolCount === 0;
  el.copyMutatorIds.disabled = state.selectedMutators.size === 0;
  renderSelectedMutators();
  renderMutatorPresets();
}

function hasActiveMutatorFilter() {
  return Boolean(
    el.mutatorSearch.value.trim() ||
    el.mutatorFilter.value !== "all" ||
    el.mutatorCategoryFilter.value !== "all" ||
    el.mutatorTierFilter.value !== "all",
  );
}

function getFilteredMutators() {
  if (!state.data) return [];
  const query = el.mutatorSearch.value.trim().toLowerCase();
  const filter = el.mutatorFilter.value;
  const category = el.mutatorCategoryFilter.value;
  const tier = el.mutatorTierFilter.value;
  return state.data.mutators.filter((item) => {
    if (filter === "selected" && !state.selectedMutators.has(item.id)) return false;
    if (filter === "unselected" && state.selectedMutators.has(item.id)) return false;
    if (category !== "all" && (item.category || "other") !== category) return false;
    if (tier !== "all" && (item.tier || "normal") !== tier) return false;
    if (!query) return true;
    return [item.id, item.name, item.description, getMutatorCategoryLabel(item.category), getMutatorTierLabel(item.tier)].some((value) =>
      String(value || "").toLowerCase().includes(query),
    );
  });
}

function getRandomMutatorPool() {
  return getFilteredMutators().filter((item) => item.id !== "Random");
}

function clearMutatorFilters() {
  el.mutatorSearch.value = "";
  el.mutatorFilter.value = "all";
  el.mutatorCategoryFilter.value = "all";
  el.mutatorTierFilter.value = "all";
  renderMutators();
  el.launchState.textContent = "因子筛选已清除";
}

function renderSelectedMutators() {
  const selected = getSelectedMutatorRecords();
  const matched = getMatchedSelectedMutators(selected);
  const query = getSelectedMutatorQuery();
  renderSelectedMutatorPanelComponent({
    container: el.selectedMutators,
    statusElement: el.selectedMutatorStatus,
    searchElement: el.selectedMutatorSearch,
    clearMatchedButton: el.clearMatchedMutators,
    toggleButton: el.toggleSelectedMutators,
    selectedMutatorIds: state.selectedMutators,
    matchedMutators: matched,
    query,
    expanded: state.selectedMutatorPanelExpanded,
    onRemoveMutator: (mutatorId) => {
      state.selectedMutators.delete(mutatorId);
      renderMutators();
      updateSummary();
    },
  });
}

function getSelectedMutatorRecords() {
  if (!state.data) return [];
  const byId = new Map(state.data.mutators.map((item) => [item.id, item]));
  return [...state.selectedMutators].map((id) => ({
    id,
    mutator: byId.get(id) || null,
  }));
}

function getSelectedMutatorQuery() {
  return el.selectedMutatorSearch.value.trim().toLowerCase();
}

function getMatchedSelectedMutators(records = getSelectedMutatorRecords()) {
  const query = getSelectedMutatorQuery();
  if (!query) return records;
  return records.filter(({ id, mutator }) =>
    [id, mutator?.name, mutator?.description, getMutatorCategoryLabel(mutator?.category), getMutatorTierLabel(mutator?.tier)].some((value) =>
      String(value || "").toLowerCase().includes(query),
    ),
  );
}

function clearMatchedSelectedMutators() {
  if (!getSelectedMutatorQuery()) return;
  const matched = getMatchedSelectedMutators();
  for (const { id } of matched) {
    state.selectedMutators.delete(id);
  }
  el.selectedMutatorSearch.value = "";
  if (state.selectedMutators.size === 0) {
    state.selectedMutatorPanelExpanded = false;
  }
  renderMutators();
  updateSummary();
  scheduleAutosave();
  el.launchState.textContent = `已清除 ${matched.length} 个匹配因子`;
}

function resetSelectedMutatorView() {
  el.selectedMutatorSearch.value = "";
  state.selectedMutatorPanelExpanded = false;
}

function getConfigSummaryText() {
  const payload = buildLaunchPayload();
  return getPayloadSummaryText(payload);
}

function getPayloadSummaryText(payload) {
  const mutators = Array.isArray(payload.mutators) ? payload.mutators : [];
  const genericBonuses = Array.isArray(payload.genericBonuses) ? payload.genericBonuses : [];
  const genericBonusLevels = normalizeGenericBonusLevels(payload.genericBonusLevels || {}, genericBonuses);
  const scoreState = getScoreState(payload);
  const overrideLabels = getCommanderOverrideLabels(payload.commanderOverrides || [], payload.commander);
  const talentSummary = getTalentSummary(payload.commander);
  return [
    `指挥官=${getCommanderLabel(payload.commander)}(${payload.commander})`,
    `地图=${getMapLabel(payload.map)}(${payload.map})`,
    `天赋=开关${talentSummary.activeSwitchCount}项/等级合计${talentSummary.totalLevel}`,
    `额外升级=${overrideLabels.length === 0 ? "无" : overrideLabels.join(",")}`,
    `语音=${getVoicePackLabel(payload.voicePack || "Default")}(${payload.voicePack || "Default"})`,
    `通用加成=${genericBonuses.length === 0 ? "无" : genericBonuses.map((id) => getGenericBonusDisplayName(id, genericBonusLevels)).join(",")}`,
    `因子=${mutators.length === 0 ? "无" : mutators.join(",")}`,
    `积分=${scoreState.earnedPoints}+${scoreState.mutatorPoints}-${scoreState.bonusCost}=${scoreState.balanceAfterSelection}`,
    `模式=${payload.noLaunch ? "验证" : "启动"}`,
  ].join(" | ");
}

function getPayloadModeBadge(payload = {}) {
  return payload.noLaunch ? "安装" : "启动";
}

function getPayloadMutatorBadge(payload = {}) {
  return `${(payload.mutators || []).length} 因子`;
}

function getPayloadMasteryBadge(payload = {}) {
  const talentSummary = getTalentSummary(payload.commander);
  return `天赋 开关${talentSummary.activeSwitchCount}/等级${talentSummary.totalLevel}`;
}

function getHistoryStatusClass(item) {
  const result = item.result || {};
  if (result.finalStatus?.timedOut) return "status-warn";
  if (result.exitCode === 0) return "status-ok";
  if (result.exitCode !== null && result.exitCode !== undefined) return "status-error";
  return "status-warn";
}

function getValidationSignature(payload = buildLaunchPayload()) {
  return JSON.stringify({
    commander: payload.commander,
    map: payload.map,
    talentSelections: payload.talentSelections || {},
    commanderOverrides: [...(payload.commanderOverrides || [])].sort(),
    voicePack: normalizeVoicePackId(payload.voicePack),
    genericBonuses: [...(payload.genericBonuses || [])].sort(),
    genericBonusLevels: normalizeGenericBonusLevels(payload.genericBonusLevels || {}, payload.genericBonuses || []),
    mutators: [...(payload.mutators || [])].sort(),
    mutatorPreset: payload.mutatorPreset,
    startTalentMask: payload.startTalentMask,
    enableStartTalents: payload.enableStartTalents,
  });
}

function normalizeLaunchPayload(payload = buildLaunchPayload()) {
  return {
    commander: payload.commander,
    map: payload.map,
    talentSelections: payload.talentSelections || {},
    commanderOverrides: [...(payload.commanderOverrides || [])].sort(),
    voicePack: normalizeVoicePackId(payload.voicePack),
    genericBonuses: [...(payload.genericBonuses || [])].sort(),
    genericBonusLevels: normalizeGenericBonusLevels(payload.genericBonusLevels || {}, payload.genericBonuses || []),
    mutators: [...(payload.mutators || [])].sort(),
    mutatorPreset: payload.mutatorPreset,
    startTalentMask: payload.startTalentMask,
    enableStartTalents: payload.enableStartTalents,
    noLaunch: payload.noLaunch === true,
  };
}

function setValidationSummary(text, className = "") {
  el.summaryValidation.className = ["badge", className].filter(Boolean).join(" ");
  el.summaryValidation.textContent = text;
}

function setValidatedConfig(payload, result = {}, finalStatus = null, source = "验证") {
  state.lastValidatedSignature = getValidationSignature(payload);
  state.lastValidatedPayload = normalizeLaunchPayload(payload);
  state.lastValidationDetail = {
    source,
    pid: result?.pid || finalStatus?.pid || null,
    checkedAt: finalStatus?.checkedAt || new Date().toISOString(),
    stdout: finalStatus?.stdout?.path || result?.stdout || "",
    stderr: finalStatus?.stderr?.path || result?.stderr || "",
  };
  updateValidationSummary();
}

function clearValidatedConfig() {
  state.lastValidatedSignature = "";
  state.lastValidationDetail = null;
  state.lastValidatedPayload = null;
  updateValidationSummary();
}

function getValidationDetailText() {
  const detail = state.lastValidationDetail;
  if (!detail) return "";
  return [
    `${detail.source || "验证"}: ${formatTime(detail.checkedAt)}`,
    detail.pid ? `PID ${detail.pid}` : "",
    detail.stdout ? `stdout=${detail.stdout}` : "",
    detail.stderr ? `stderr=${detail.stderr}` : "",
  ].filter(Boolean).join("\n");
}

function getValidationChangeSummary(currentPayload = normalizeLaunchPayload()) {
  const previous = state.lastValidatedPayload;
  if (!previous) return "";
  const changes = [];
  if (previous.commander !== currentPayload.commander) {
    changes.push(`指挥官: ${getCommanderLabel(previous.commander)} -> ${getCommanderLabel(currentPayload.commander)}`);
  }
  if (previous.map !== currentPayload.map) {
    changes.push(`地图: ${getMapLabel(previous.map)} -> ${getMapLabel(currentPayload.map)}`);
  }
  if (JSON.stringify(previous.talentSelections || {}) !== JSON.stringify(currentPayload.talentSelections || {})) {
    const prevSummary = getTalentSummary(previous.commander);
    const currSummary = getTalentSummary(currentPayload.commander);
    changes.push(`天赋: 开关${prevSummary.activeSwitchCount}/等级${prevSummary.totalLevel} -> 开关${currSummary.activeSwitchCount}/等级${currSummary.totalLevel}`);
  }
  if ((previous.commanderOverrides || []).join(",") !== (currentPayload.commanderOverrides || []).join(",")) {
    changes.push(`额外升级: ${(previous.commanderOverrides || []).length} -> ${(currentPayload.commanderOverrides || []).length}`);
  }
  if ((previous.voicePack || "Default") !== (currentPayload.voicePack || "Default")) {
    changes.push(`语音包: ${getVoicePackLabel(previous.voicePack || "Default")} -> ${getVoicePackLabel(currentPayload.voicePack || "Default")}`);
  }
  if ((previous.genericBonuses || []).join(",") !== (currentPayload.genericBonuses || []).join(",")) {
    changes.push(`通用加成: ${(previous.genericBonuses || []).length} -> ${(currentPayload.genericBonuses || []).length}`);
  }
  if (JSON.stringify(previous.genericBonusLevels || {}) !== JSON.stringify(currentPayload.genericBonusLevels || {})) {
    changes.push(`资源倍率点数: ${JSON.stringify(previous.genericBonusLevels || {})} -> ${JSON.stringify(currentPayload.genericBonusLevels || {})}`);
  }
  if (previous.mutatorPreset !== currentPayload.mutatorPreset) {
    changes.push(`因子预设: ${previous.mutatorPreset} -> ${currentPayload.mutatorPreset}`);
  }
  if (previous.mutators.join(",") !== currentPayload.mutators.join(",")) {
    changes.push(`因子: ${previous.mutators.length} -> ${currentPayload.mutators.length}`);
  }
  return changes.length > 0 ? `变更:\n${changes.join("\n")}` : "";
}

function getLaunchModeLabels(payload = buildLaunchPayload()) {
  const dryRun = payload.noLaunch === true;
  return {
    mode: dryRun ? "验证" : "启动",
    launch: dryRun ? "验证" : "启动",
    validateLaunch: dryRun ? "验证后安装" : "验证后启动",
    pending: dryRun ? "验证中" : "启动中",
    started: dryRun ? "验证中" : "",
    running: dryRun ? "验证中" : "",
  };
}

function updateLaunchModeLabels(payload = buildLaunchPayload()) {
  const labels = getLaunchModeLabels(payload);
  el.summaryMode.textContent = labels.mode;
  el.launchButton.textContent = labels.launch;
  el.validateLaunchButton.textContent = labels.validateLaunch;
}

function updateValidationSummary() {
  if (!state.data) {
    setValidationSummary("未验证");
    el.summaryValidation.title = "";
    el.summaryValidation.removeAttribute("aria-label");
    return;
  }

  if (!state.lastValidatedSignature) {
    setValidationSummary("未验证", "status-warn");
    el.summaryValidation.title = "";
    el.summaryValidation.setAttribute("aria-label", "当前配置未验证");
    return;
  }

  const currentSignature = getValidationSignature();
  if (state.lastValidatedSignature === currentSignature) {
    const detail = getValidationDetailText();
    const suffix = state.lastValidationDetail?.checkedAt ? ` ${formatShortTime(state.lastValidationDetail.checkedAt)}` : "";
    setValidationSummary(`已验证${suffix}`, "status-ok validation-ok");
    el.summaryValidation.title = detail || "当前配置已通过验证";
    el.summaryValidation.setAttribute("aria-label", detail || "当前配置已通过验证");
  } else {
    setValidationSummary("已变更", "status-warn");
    const detail = getValidationDetailText();
    const changes = getValidationChangeSummary();
    el.summaryValidation.title = [detail, changes, "当前配置已变更，需要重新验证"].filter(Boolean).join("\n");
    el.summaryValidation.setAttribute("aria-label", changes ? `当前配置已变更，需要重新验证。${changes.replace(/\n/g, " ")}` : "当前配置已变更，需要重新验证");
  }
}

function getConfigIssues(payload = buildLaunchPayload()) {
  const issues = [];
  const commanderExists = state.data?.commanders.some((item) => item.runtime === payload.commander);
  const mapExists = state.data?.maps.some((item) => item.id === payload.map);
  if (!commanderExists) issues.push(`未知指挥官: ${payload.commander || "-"}`);
  if (!mapExists) issues.push(`未知地图: ${payload.map || "-"}`);
  return issues;
}

function updateConfigIssues(payload = buildLaunchPayload()) {
  if (!state.data) {
    el.configIssues.textContent = "配置未就绪";
    el.configIssues.className = "config-issues status-warn";
    updateConfigActionButtons(true);
    return;
  }

  const issues = getConfigIssues(payload);
  if (issues.length === 0) {
    el.configIssues.textContent = "配置可启动";
    el.configIssues.className = "config-issues status-ok";
  } else {
    el.configIssues.textContent = `需处理: ${issues.join("；")}`;
    el.configIssues.className = "config-issues status-error";
  }
  updateConfigActionButtons();
}

function updateConfigActionButtons(forceDisabled = false) {
  const disabled = forceDisabled || state.serviceUnavailable || Boolean(state.launchPollTimer) || !state.data || getConfigIssues().length > 0;
  el.previewButton.disabled = disabled;
  el.validateButton.disabled = disabled;
  el.validateLaunchButton.disabled = disabled;
  el.launchButton.disabled = disabled;
  updateRowSubmitButtons();
}

function updateRowSubmitButtons() {
  document.querySelectorAll(".row-submit-action").forEach((button) => {
    button.disabled = Boolean(state.launchPollTimer);
  });
}

function assertLaunchPayloadValid(payload = buildLaunchPayload()) {
  const issues = getConfigIssues(payload);
  if (issues.length > 0) {
    const message = `配置存在问题，已拦截:\n${issues.join("\n")}`;
    el.launchState.textContent = "配置错误";
    updateConfigIssues(payload);
    writeOutput(message);
    return false;
  }
  return true;
}

async function copyConfigSummary() {
  if (!state.data) return;
  await copyText(getConfigSummaryText());
  el.launchState.textContent = "摘要已复制";
}

function updateSummaryDetails(payload = buildLaunchPayload()) {
  const mutatorIds = payload.mutators.length === 0 ? "无" : payload.mutators.join(", ");
  const genericBonusLevels = normalizeGenericBonusLevels(payload.genericBonusLevels || {}, payload.genericBonuses || []);
  const genericBonusLabels = (payload.genericBonuses || []).map((id) => getGenericBonusDisplayName(id, genericBonusLevels));
  const overrideLabels = getCommanderOverrideLabels(payload.commanderOverrides || [], payload.commander);
  const selectedRace = getSelectedCommanderRace();
  const voicePack = getVoicePackById(payload.voicePack || "Default");
  const voicePackReward = voicePack?.rewardIds?.[selectedRace] || "-";
  const talentSummary = getTalentSummary(payload.commander);
  updateSummaryDetailPanelComponent({
    summaryCommanderElement: el.summaryCommander,
    summaryMapElement: el.summaryMap,
    summaryMasteryElement: el.summaryMastery,
    summaryMutatorsElement: el.summaryMutators,
    summaryModeElement: el.summaryMode,
    commanderLabel: getCommanderLabel(payload.commander),
    commanderId: payload.commander,
    mapLabel: getMapLabel(payload.map),
    mapId: payload.map,
    talentSummary,
    mutatorCount: payload.mutators.length,
    genericBonusCount: genericBonusLabels.length,
    mutatorPreset: payload.mutatorPreset,
    mutatorIdsText: mutatorIds,
    genericBonusLabels,
    modeLabel: payload.noLaunch ? "验证安装" : "正式启动",
    overrideLabels,
  });
  if (el.voicePackBadge) {
    el.voicePackBadge.textContent = getVoicePackLabel(payload.voicePack || "Default");
  }
  if (el.voicePackCurrentLabel) {
    el.voicePackCurrentLabel.textContent = getVoicePackLabel(payload.voicePack || "Default");
  }
  if (el.voicePackRaceReward) {
    el.voicePackRaceReward.textContent = voicePackReward;
  }
  if (el.voicePackMode) {
    el.voicePackMode.textContent = (payload.voicePack || "Default") === "Default" ? "指挥官默认" : "按存档覆盖";
  }
}

function updateScorePanel(payload = buildLaunchPayload()) {
  if (!state.data) return;
  const scoreState = getScoreState(payload);
  const commander = getCommander();
  const mapLabel = getMapLabel(payload.map);
  const commanderProgressText = commander
    ? `${commander.displayName || commander.runtime} / ${mapLabel || payload.map || "-"} / ${scoreState.commanderCleared ? "已首通" : "未首通"} / 奖励 ${Math.max(scoreState.commanderBonusScore, scoreState.objectiveStats.completed)}`
    : "等待选择";
  const detailParts = [
    `首通 ${scoreState.firstClearCount} 次 = ${scoreState.firstClearPoints} 分`,
    `奖励 ${scoreState.bonusObjectiveCount} 点 = ${scoreState.bonusObjectivePoints} 分`,
    `当前因子 +${scoreState.mutatorPoints}`,
    `当前加成 -${scoreState.bonusCost}`,
  ];
  if (scoreState.objectiveStats.failed > 0) {
    detailParts.push(`失败目标 ${scoreState.objectiveStats.failed}`);
  }
  updateScorePanelComponent({
    budgetBadgeElement: el.scoreBudgetBadge,
    availablePointsElement: el.scoreAvailablePoints,
    mutatorPointsElement: el.scoreMutatorPoints,
    bonusCostElement: el.scoreBonusCost,
    balanceAfterElement: el.scoreBalanceAfter,
    commanderProgressElement: el.scoreCommanderProgress,
    detailElement: el.scoreDetailText,
    ruleElement: el.scoreRuleText,
    earnedPoints: scoreState.earnedPoints,
    mutatorPoints: scoreState.mutatorPoints,
    bonusCost: scoreState.bonusCost,
    balanceAfter: scoreState.balanceAfterSelection,
    commanderProgressText,
    detailText: detailParts.join(" · "),
    ruleText: getScoreRuleText(),
  });
}

function updateSummary() {
  if (!state.data) {
    el.selectionSummary.textContent = "未就绪";
    el.copySummaryButton.disabled = true;
    if (el.summaryPoints) el.summaryPoints.textContent = "0";
    setValidationSummary("未验证");
    el.configIssues.textContent = "配置未就绪";
    el.configIssues.className = "config-issues status-warn";
    return;
  }

  const payload = buildLaunchPayload();
  const commander = getCommander();
  const map = getMapLabel(el.mapSelect.value) || "-";
  const scoreState = getScoreState(payload);
  const mutatorCount = state.selectedMutators.size;
  const commanderOverrideCount = state.selectedCommanderOverrides.size;
  const genericBonusCount = (payload.genericBonuses || []).length;
  const talentSummary = getTalentSummary(payload.commander);
  updateSummaryPanelComponent({
    selectionSummaryElement: el.selectionSummary,
    summaryCommanderElement: el.summaryCommander,
    summaryMapElement: el.summaryMap,
    summaryMasteryElement: el.summaryMastery,
    summaryMutatorsElement: el.summaryMutators,
    summaryPointsElement: el.summaryPoints,
    prestigeFusionStatusElement: el.prestigeFusionStatus,
    copySummaryButton: el.copySummaryButton,
    commanderLabel: commander?.displayName ?? "-",
    mapLabel: map,
    mutatorCount,
    genericBonusCount,
    commanderOverrideCount,
    talentSummary,
    scoreSummaryText: `${scoreState.earnedPoints}+${scoreState.mutatorPoints}-${scoreState.bonusCost}=${scoreState.balanceAfterSelection}`,
  });
  updateLaunchModeLabels(payload);
  updateSummaryDetails(payload);
  updateScorePanel(payload);
  renderVoicePacks();
  updateValidationSummary();
  updateConfigIssues();
  scheduleAutosave();
}

function updateBootstrapStrip() {
  if (!state.data) return;
  if (!el.bootstrapCommanderCount || !el.bootstrapMapCount || !el.bootstrapMutatorCount || !el.bootstrapCompletionStatus || !el.bootstrapScoreStatus || !el.bootstrapResourcePlanText) {
    return;
  }

  const completion = state.data.completion || {};
  const completionStatus = [];
  const scoreStatus = [];
  if (completion.bankFound) {
    completionStatus.push(`已读取 Bank`);
    if (completion.lastCommander || completion.lastMap) {
      completionStatus.push(`最近进度 ${completion.lastCommander || "-"}/${completion.lastMap || "-"}`);
    }
    if (completion.bankLastWriteTime) {
      completionStatus.push(`更新时间 ${formatShortTime(completion.bankLastWriteTime)}`);
    }
    scoreStatus.push(`已得 ${completion.pointLedger?.earnedPoints || 0} 分`);
    scoreStatus.push(`首通 ${completion.pointLedger?.firstClearCount || 0}`);
    scoreStatus.push(`奖励 ${completion.pointLedger?.bonusObjectiveCount || 0}`);
  } else {
    completionStatus.push("未找到 CampaignXCore.SC2Bank");
    scoreStatus.push("积分从 0 开始");
  }
  const resourcePlan = state.data.resourcePlan || {};
  updateBootstrapStripPanelComponent({
    commanderCountElement: el.bootstrapCommanderCount,
    mapCountElement: el.bootstrapMapCount,
    mutatorCountElement: el.bootstrapMutatorCount,
    completionStatusElement: el.bootstrapCompletionStatus,
    scoreStatusElement: el.bootstrapScoreStatus,
    resourcePlanElement: el.bootstrapResourcePlanText,
    commanderCount: state.data.counts?.commanders ?? state.data.commanders?.length ?? 0,
    mapCount: state.data.counts?.maps ?? state.data.maps?.length ?? 0,
    mutatorCount: state.data.counts?.mutators ?? state.data.mutators?.length ?? 0,
    completion,
    completionStatusText: completionStatus.join(" · "),
    scoreStatusText: scoreStatus.join(" · "),
    resourcePlanText: [
    resourcePlan.text || "数据索引已就绪",
    resourcePlan.icons || "",
    resourcePlan.audio || "",
  ].filter(Boolean).join(" · "),
  });
}

function applyPayload(payload, options = {}) {
  if (!state.data || !payload) return false;
  const report = {
    ok: true,
    unknownCommander: null,
    unknownMap: null,
    unknownMutators: [],
    unknownCommanderOverrides: [],
    unknownGenericBonuses: [],
  };

  if (state.data.commanders.some((item) => item.runtime === payload.commander)) {
    el.commanderSelect.value = payload.commander;
  } else if (payload.commander) {
    report.unknownCommander = payload.commander;
  }
  if (state.data.maps.some((item) => item.id === payload.map)) {
    el.mapSelect.value = payload.map;
  } else if (payload.map) {
    report.unknownMap = payload.map;
  }

  el.enableStartTalents.checked = payload.enableStartTalents !== false;
  el.startTalentMask.value = String(Number(payload.startTalentMask) || 0);
  el.mutatorPreset.value = String(clampNumber(payload.mutatorPreset, 0, 3, 0));
  el.dryRunToggle.checked = payload.noLaunch === true;

  if (payload.talentSelections && typeof payload.talentSelections === "object") {
    state.talentSelections = JSON.parse(JSON.stringify(payload.talentSelections));
  } else {
    state.talentSelections = {};
  }

  renderCommanderDetails();

  const allowedMutators = new Set(state.data.mutators.map((item) => item.id));
  const allowedGenericBonuses = new Set(GENERIC_BONUS_OPTIONS.map((item) => item.id));
  state.selectedMutators.clear();
  state.selectedCommanderOverrides.clear();
  state.selectedGenericBonuses.clear();
  state.selectedVoicePackId = normalizeVoicePackId(payload.voicePack || state.data.defaults.voicePack || "Default");
  state.genericBonusLevels = createDefaultGenericBonusLevels();
  resetSelectedMutatorView();
  if (Array.isArray(payload.mutators)) {
    for (const id of payload.mutators) {
      if (allowedMutators.has(id)) {
        state.selectedMutators.add(id);
      } else {
        report.unknownMutators.push(id);
      }
    }
  }
  if (Array.isArray(payload.genericBonuses)) {
    for (const id of payload.genericBonuses) {
      if (allowedGenericBonuses.has(id)) {
        state.selectedGenericBonuses.add(id);
      } else {
        report.unknownGenericBonuses.push(id);
      }
    }
  }
  state.genericBonusLevels = normalizeGenericBonusLevels(payload.genericBonusLevels || {}, payload.genericBonuses || []);
  for (const id of LEVELABLE_GENERIC_BONUS_IDS) {
    const level = clampGenericBonusLevel(id, state.genericBonusLevels[id]);
    if (level > 0) {
      state.selectedGenericBonuses.add(id);
    } else {
      state.selectedGenericBonuses.delete(id);
    }
  }

  if (Array.isArray(payload.commanderOverrides)) {
    for (const overrideValue of payload.commanderOverrides) {
      const overrideText = String(overrideValue || "");
      if (overrideText) {
        state.selectedCommanderOverrides.add(overrideText);
      }
    }
  }

  renderGenericBonuses();
  renderMutators();
  renderQuickPickers();
  updateSummary();
  if (options.persist !== false) {
    scheduleAutosave();
  }
  if (report.unknownCommander || report.unknownMap || report.unknownMutators.length > 0 || report.unknownCommanderOverrides.length > 0 || report.unknownGenericBonuses.length > 0) {
    report.ok = false;
  }
  if (options.returnReport) return report;
  return true;
}

function getDefaultPayload() {
  return {
    commander: state.data.defaults.commander,
    map: state.data.defaults.map,
    talentSelections: state.data.defaults.talentSelections || {},
    enableStartTalents: true,
    startTalentMask: 0,
    commanderOverrides: [...(state.data.defaults.commanderOverrides || [])],
    voicePack: normalizeVoicePackId(state.data.defaults.voicePack || "Default"),
    genericBonuses: [...(state.data.defaults.genericBonuses || [])],
    genericBonusLevels: normalizeGenericBonusLevels(state.data.defaults.genericBonusLevels || {}, state.data.defaults.genericBonuses || []),
    mutators: [],
    mutatorPreset: state.data.defaults.mutatorPreset,
    noLaunch: false,
  };
}

function parsePayloadText() {
  const raw = el.payloadText.value.trim();
  if (!raw) {
    setPayloadStatus("等待配置");
    return null;
  }

  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("JSON 根节点必须是对象");
    }
    setPayloadStatus("JSON 可应用", "status-ok");
    return parsed;
  } catch (error) {
    setPayloadStatus(`JSON 无效：${error.message}`, "status-error");
    return null;
  }
}

function exportCurrentPayload() {
  const payload = buildLaunchPayload();
  exportPayloadToEditor(payload, "已导出当前配置");
  writeOutput({ exportedPayload: payload });
}

function exportPayloadToEditor(payload, statusText = "已导出配置") {
  el.payloadText.value = JSON.stringify(payload, null, 2);
  el.copyPayloadButton.disabled = false;
  el.applyPayloadButton.disabled = false;
  setPayloadStatus(statusText, "status-ok");
  el.launchState.textContent = "已导出配置";
}

async function copyPayloadJson() {
  const raw = el.payloadText.value.trim();
  if (!raw) return;
  await copyText(raw);
  setPayloadStatus("JSON 已复制", "status-ok");
  el.launchState.textContent = "已复制 JSON";
}

function applyPayloadJson() {
  const payload = parsePayloadText();
  if (!payload) return;

  const report = applyPayload(payload, { returnReport: true });
  el.copyPayloadButton.disabled = false;
  el.applyPayloadButton.disabled = false;
  if (report.ok) {
    setPayloadStatus("JSON 已应用", "status-ok");
    el.launchState.textContent = "已应用配置";
  } else {
    setPayloadStatus("JSON 已部分应用", "status-error");
    el.launchState.textContent = "部分应用";
  }
  writeOutput({ appliedPayload: buildLaunchPayload(), importReport: report });
}

function clearPayloadJson() {
  el.payloadText.value = "";
  el.copyPayloadButton.disabled = true;
  el.applyPayloadButton.disabled = true;
  setPayloadStatus("等待配置");
}

function saveConfig() {
  const payload = buildLaunchPayload();
  localStorage.setItem(STORAGE_KEY, JSON.stringify(payload));
  writeUiState({
    selectedMutatorPanelExpanded: state.selectedMutatorPanelExpanded,
    startTalentMaskMode: state.startTalentMaskMode,
    activeSheet: state.activeSheet,
  });
  addRecentConfig(payload);
  el.launchState.textContent = "已保存";
  writeOutput({ saved: payload });
}

function readStorageArray(key) {
  try {
    const parsed = JSON.parse(localStorage.getItem(key) || "[]");
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    localStorage.removeItem(key);
    return [];
  }
}

function writeStorageArray(key, items) {
  localStorage.setItem(key, JSON.stringify(items));
}

function readRecentConfigs() {
  return readStorageArray(RECENT_KEY);
}

function writeRecentConfigs(items) {
  localStorage.setItem(RECENT_KEY, JSON.stringify(items.slice(0, MAX_RECENT)));
  renderRecentConfigs();
}

function recentKey(payload) {
  return getValidationSignature(payload);
}

function scenarioKey(payload) {
  const genericBonusLevels = normalizeGenericBonusLevels(payload.genericBonusLevels || {}, payload.genericBonuses || []);
  return [
    payload.commander,
    payload.map,
    JSON.stringify(payload.talentSelections || {}),
    (payload.commanderOverrides || []).join(","),
    (payload.genericBonuses || []).join(","),
    JSON.stringify(genericBonusLevels),
    (payload.mutators || []).join(","),
    payload.mutatorPreset,
    payload.enableStartTalents,
    payload.startTalentMask,
    payload.noLaunch,
  ].join("|");
}

function addRecentConfig(payload) {
  const record = {
    savedAt: new Date().toISOString(),
    payload,
  };
  const key = recentKey(payload);
  const next = [record, ...readRecentConfigs().filter((item) => recentKey(item.payload || {}) !== key)];
  writeRecentConfigs(next);
}

function renderRecentConfigs() {
  const items = readRecentConfigs();
  renderRecentConfigsPanelComponent({
    container: el.recentConfigs,
    items,
    getCommanderLabel,
    getMapLabel,
    getPayloadModeBadge,
    getPayloadMutatorBadge,
    getPayloadMasteryBadge,
    formatTime,
    getPayloadSummaryText,
    onApply: (payload) => {
      applyPayload(payload);
      el.launchState.textContent = "已套用";
      writeOutput({ appliedRecent: payload });
    },
    onValidate: async (payload) => {
      await validatePayload(payload, "最近验证");
    },
    onExportJson: (payload) => {
      exportPayloadToEditor(payload, "已导出最近配置");
      writeOutput({ exportedRecent: payload });
    },
  });
  updateRowSubmitButtons();
}

function readScenarioPresets() {
  return readStorageArray(SCENARIO_PRESET_KEY).filter(
    (item) => item && typeof item.id === "string" && item.payload && typeof item.payload === "object",
  );
}

function writeScenarioPresets(items) {
  localStorage.setItem(SCENARIO_PRESET_KEY, JSON.stringify(items.slice(0, MAX_SCENARIO_PRESETS)));
  renderScenarioPresets();
}

function defaultScenarioName(payload) {
  const commander = getCommanderLabel(payload.commander);
  const map = getMapLabel(payload.map);
  const mutatorCount = (payload.mutators || []).length;
  const genericBonusCount = getSelectedGenericBonusIds(new Set(payload.genericBonuses || []), normalizeGenericBonusLevels(payload.genericBonusLevels || {}, payload.genericBonuses || [])).length;
  return `${commander} / ${map} / ${mutatorCount} 因子 / ${genericBonusCount} 加成`;
}

function saveScenarioPreset() {
  const payload = buildLaunchPayload();
  const typedName = el.scenarioPresetName.value.trim();
  const name = typedName || defaultScenarioName(payload);
  const record = {
    id: `${name}|${scenarioKey(payload)}`.slice(0, 180),
    name,
    savedAt: new Date().toISOString(),
    payload,
  };
  const next = [
    record,
    ...readScenarioPresets().filter(
      (item) => item.name !== record.name && scenarioKey(item.payload || {}) !== scenarioKey(payload),
    ),
  ];
  writeScenarioPresets(next);
  el.launchState.textContent = "场景已保存";
  writeOutput({ savedScenarioPreset: record });
}

function renderScenarioPresets() {
  const items = readScenarioPresets();
  renderScenarioPresetsPanelComponent({
    container: el.scenarioPresets,
    items,
    defaultScenarioName,
    getCommanderLabel,
    getMapLabel,
    getPayloadModeBadge,
    getPayloadMutatorBadge,
    getPayloadMasteryBadge,
    getPayloadSummaryText,
    formatTime,
    onApply: (item, payload) => {
      applyPayload(payload);
      el.launchState.textContent = "场景已套用";
      writeOutput({ appliedScenarioPreset: item.name, payload });
    },
    onLaunch: async (payload) => {
      if (applyPayload(payload)) {
        await launchGame();
      }
    },
    onValidate: async (payload) => {
      await validatePayload(payload, "场景验证");
    },
    onExportJson: (item, payload) => {
      exportPayloadToEditor(payload, "已导出场景配置");
      writeOutput({ exportedScenarioPreset: item.name, payload });
    },
    onRemove: (item) => {
      writeScenarioPresets(readScenarioPresets().filter((candidate) => candidate.id !== item.id));
      el.launchState.textContent = "场景已删除";
    },
  });
  updateRowSubmitButtons();
}

function readMutatorPresets() {
  return readStorageArray(MUTATOR_PRESET_KEY).filter(
    (item) => item && typeof item.id === "string" && Array.isArray(item.mutators),
  );
}

function writeMutatorPresets(items) {
  writeStorageArray(MUTATOR_PRESET_KEY, items);
  renderMutatorPresets();
}

function renderMutatorPresets() {
  if (!el.savedMutatorPreset) return;
  renderMutatorPresetOptionsPanelComponent({
    selectElement: el.savedMutatorPreset,
    applyButton: el.applyMutatorPreset,
    deleteButton: el.deleteMutatorPreset,
    presets: readMutatorPresets(),
  });
}

function saveCurrentMutatorPreset() {
  const mutators = [...state.selectedMutators];
  const typedName = el.mutatorPresetName.value.trim();
  const name = typedName || `${mutators.length} 因子组合`;
  const id = typedName || mutators.join("|") || "empty";
  const preset = {
    id: `${id}`.slice(0, 80),
    name,
    mutators,
    savedAt: new Date().toISOString(),
  };
  const next = [
    preset,
    ...readMutatorPresets().filter((item) => item.id !== preset.id && item.name !== preset.name),
  ].slice(0, 12);

  writeMutatorPresets(next);
  el.savedMutatorPreset.value = preset.id;
  renderMutatorPresets();
  el.launchState.textContent = "组合已保存";
  writeOutput({ savedMutatorPreset: preset });
}

function applySelectedMutatorPreset() {
  const preset = readMutatorPresets().find((item) => item.id === el.savedMutatorPreset.value);
  if (!preset || !state.data) return;

  const allowedMutators = new Set(state.data.mutators.map((item) => item.id));
  state.selectedMutators.clear();
  resetSelectedMutatorView();
  for (const id of preset.mutators) {
    if (allowedMutators.has(id)) state.selectedMutators.add(id);
  }
  renderMutators();
  updateSummary();
  el.launchState.textContent = "组合已套用";
  writeOutput({
    appliedMutatorPreset: preset.name,
    mutators: [...state.selectedMutators].map((id) => `${getMutatorLabel(id)} (${id})`),
  });
}

function deleteSelectedMutatorPreset() {
  const selectedId = el.savedMutatorPreset.value;
  if (!selectedId) return;
  writeMutatorPresets(readMutatorPresets().filter((item) => item.id !== selectedId));
  el.launchState.textContent = "组合已删除";
}

function readLaunchHistory() {
  return readStorageArray(LAUNCH_HISTORY_KEY);
}

function writeLaunchHistory(items) {
  localStorage.setItem(LAUNCH_HISTORY_KEY, JSON.stringify(items.slice(0, MAX_LAUNCH_HISTORY)));
  renderLaunchHistory();
}

function addLaunchHistory(payload, result, finalStatus = null) {
  const id = `${Date.now()}-${result?.pid || "nopid"}-${Math.random().toString(16).slice(2)}`;
  const record = {
    id,
    launchedAt: new Date().toISOString(),
    payload,
    result: {
      ok: result?.ok !== false,
      pid: result?.pid || null,
      stdout: result?.stdout || "",
      stderr: result?.stderr || "",
      noLaunch: payload.noLaunch === true,
      exitCode: finalStatus?.exitCode ?? null,
      completedAt: finalStatus?.checkedAt || null,
      finalStatus,
    },
  };
  writeLaunchHistory([record, ...readLaunchHistory()]);
  return id;
}

function updateLaunchHistoryStatus(recordId, finalStatus) {
  if (!recordId || !finalStatus) return;
  const next = readLaunchHistory().map((item) => {
    if (item.id !== recordId) return item;
    return {
      ...item,
      result: {
        ...(item.result || {}),
        exitCode: finalStatus.exitCode ?? null,
        completedAt: finalStatus.checkedAt || null,
        finalStatus,
      },
    };
  });
  writeLaunchHistory(next);
}

function getLaunchHistoryStatusLabel(item) {
  const result = item.result || {};
  if (result.noLaunch) {
    if (result.exitCode === 0) return "验证通过";
    if (result.exitCode !== null && result.exitCode !== undefined) return `退出码 ${result.exitCode}`;
    return "验证中";
  }
  if (result.exitCode === 0) return "启动成功";
  if (result.finalStatus?.timedOut) return "轮询超时";
  if (result.exitCode !== null && result.exitCode !== undefined) return `退出码 ${result.exitCode}`;
  return `PID ${result.pid || "-"}`;
}

function getHistoryLogPaths(result = {}) {
  const stdout = result.finalStatus?.stdout?.path || result.stdout || "";
  const stderr = result.finalStatus?.stderr?.path || result.stderr || "";
  return { stdout, stderr };
}

function isSuccessfulHistoryValidation(result = {}) {
  const finalStatus = result.finalStatus || {};
  return result.noLaunch === true
    && Number(result.exitCode) === 0
    && Number(finalStatus.exitCode) === 0
    && isDryRunComplete(finalStatus)
    && !getStatusStderr(finalStatus);
}

function renderLaunchHistory() {
  const items = readLaunchHistory();
  renderLaunchHistoryPanelComponent({
    container: el.launchHistory,
    items,
    getCommanderLabel,
    getMapLabel,
    formatTime,
    getLaunchHistoryStatusLabel,
    getHistoryStatusClass,
    getPayloadModeBadge,
    getPayloadSummaryText,
    getHistoryLogPaths,
    onApply: (item, payload) => {
      applyPayload(payload);
      if (isSuccessfulHistoryValidation(item.result || {})) {
        setValidatedConfig(buildLaunchPayload(), item.result || {}, item.result?.finalStatus || null, "历史验证");
      } else {
        clearValidatedConfig();
      }
      el.launchState.textContent = "历史已套用";
      writeOutput({ appliedLaunchHistory: payload, result: item.result });
    },
    onShowLogs: (item, payload, mutators, genericBonuses) => {
      const logPaths = getHistoryLogPaths(item.result || {});
      setLastLogPaths(logPaths.stdout, logPaths.stderr);
      const genericBonusLevels = normalizeGenericBonusLevels(payload.genericBonusLevels || {}, genericBonuses || []);
      writeOutput({
        launchedAt: item.launchedAt,
        commander: payload.commander,
        map: payload.map,
        mutators: mutators.map((id) => `${getMutatorLabel(id)} (${id})`),
        genericBonuses: genericBonuses.map((id) => `${getGenericBonusDisplayName(id, genericBonusLevels)} (${id})`),
        result: item.result,
        finalStatus: item.result?.finalStatus || null,
        logPaths,
      });
      el.launchState.textContent = "历史日志已载入";
    },
    onValidate: async (payload) => {
      await validatePayload(payload, "历史验证");
    },
    onExportJson: (item, payload) => {
      exportPayloadToEditor(payload, "已导出历史配置");
      writeOutput({ exportedLaunchHistory: item.launchedAt, payload, result: item.result });
    },
  });
  updateRowSubmitButtons();
}

function loadSavedConfig() {
  const raw = localStorage.getItem(STORAGE_KEY);
  if (!raw) return false;
  try {
    return applyPayload(JSON.parse(raw));
  } catch (error) {
    localStorage.removeItem(STORAGE_KEY);
    writeOutput(`保存的配置无效，已清除：${error.message}`);
    return false;
  }
}

function resetConfig() {
  localStorage.removeItem(STORAGE_KEY);
  localStorage.removeItem(UI_STATE_KEY);
  applyPayload(getDefaultPayload());
  state.selectedMutatorPanelExpanded = false;
  state.startTalentMaskMode = "default";
  state.activeSheet = DEFAULT_ACTIVE_SHEET;
  syncActiveSheetUI();
  el.launchState.textContent = "默认";
  writeOutput("已恢复默认配置");
}

function randomizeMutators(countOverride = null, append = false) {
  if (!state.data) return;
  const hasOverride = typeof countOverride === "number";
  const count = !hasOverride
    ? clampNumber(el.randomMutatorCount.value, 1, 10, 3)
    : clampNumber(countOverride, 1, 10, 3);
  el.randomMutatorCount.value = String(count);
  const pool = getRandomMutatorPool();
  if (pool.length === 0) {
    el.launchState.textContent = "随机池为空";
    writeOutput("当前因子筛选没有可随机的因子；请清除筛选或放宽条件。");
    return;
  }
  const candidates = append
    ? pool.filter((item) => !state.selectedMutators.has(item.id))
    : pool;
  if (candidates.length === 0) {
    el.launchState.textContent = "没有可追加因子";
    writeOutput("当前筛选池内的因子都已选中；请放宽筛选或清空部分已选因子。");
    return;
  }
  const shuffled = [...candidates].sort(() => Math.random() - 0.5);
  const picked = shuffled.slice(0, count);

  if (!append) state.selectedMutators.clear();
  for (const item of picked) {
    state.selectedMutators.add(item.id);
  }

  renderMutators();
  updateSummary();
  scheduleAutosave();
  el.launchState.textContent = append
    ? `追加 ${picked.length} 因子`
    : `随机 ${picked.length} 因子`;
  writeOutput({
    [append ? "appendedRandomMutators" : "randomMutators"]: picked.map((item) => `${getMutatorLabel(item.id)} (${item.id})`),
    selectedMutators: [...state.selectedMutators].map((id) => `${getMutatorLabel(id)} (${id})`),
    filteredPool: pool.length,
    candidatePool: candidates.length,
  });
}

async function copySelectedMutatorIds() {
  const ids = [...state.selectedMutators];
  if (ids.length === 0) return;
  await copyText(ids.join(","));
  el.launchState.textContent = "因子 ID 已复制";
}

function normalizeImportKey(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_\-\u4e00-\u9fa5]+/g, "");
}

function parseMutatorImport() {
  if (!state.data) return { matched: [], unknown: [] };
  const idByKey = new Map();
  for (const item of state.data.mutators) {
    for (const key of [item.id, item.name]) {
      const normalized = normalizeImportKey(key);
      if (normalized) idByKey.set(normalized, item.id);
    }
  }
  const tokens = el.mutatorImportText.value
    .replace(/\\[rnt]/gi, " ")
    .split(/[\s,;，；、|]+/)
    .map((item) => item.trim())
    .filter(Boolean);
  const matched = [];
  const unknown = [];
  for (const token of tokens) {
    const id = idByKey.get(normalizeImportKey(token));
    if (id) {
      if (!matched.includes(id)) matched.push(id);
    } else if (!unknown.includes(token)) {
      unknown.push(token);
    }
  }
  return { matched, unknown };
}

function applyMutatorImport(replace) {
  const { matched, unknown } = parseMutatorImport();
  if (replace) {
    state.selectedMutators.clear();
    resetSelectedMutatorView();
  }
  for (const id of matched) {
    state.selectedMutators.add(id);
  }
  renderMutators();
  updateSummary();
  scheduleAutosave();
  el.launchState.textContent = unknown.length > 0 ? "部分未识别" : "因子已导入";
  writeOutput({
    importedMutators: matched.map((id) => `${getMutatorLabel(id)} (${id})`),
    unknownMutators: unknown,
    mode: replace ? "replace" : "append",
  });
}

function buildLaunchPayload() {
  return {
    commander: el.commanderSelect.value,
    map: el.mapSelect.value,
    talentSelections: state.talentSelections,
    enableStartTalents: el.enableStartTalents.checked,
    startTalentMask: Number(el.startTalentMask.value) || 0,
    commanderOverrides: [...state.selectedCommanderOverrides].sort(),
    voicePack: normalizeVoicePackId(state.selectedVoicePackId),
    genericBonuses: getSelectedGenericBonusIds(),
    genericBonusLevels: normalizeGenericBonusLevels(state.genericBonusLevels, getSelectedGenericBonusIds()),
    mutators: [...state.selectedMutators],
    mutatorPreset: clampNumber(el.mutatorPreset.value, 0, 3, 0),
    noLaunch: el.dryRunToggle.checked,
  };
}

async function loadBootstrap() {
  clearServiceUnavailable();
  el.launchButton.disabled = true;
  el.previewButton.disabled = true;
  el.validateButton.disabled = true;
  el.saveConfigButton.disabled = true;
  el.resetConfigButton.disabled = true;
  el.exportPayloadButton.disabled = true;
  el.applyPayloadButton.disabled = true;
  el.validateLaunchButton.disabled = true;
  setStatus("加载中");
  try {
    state.data = await apiFetchJson("/api/bootstrap?v=20260617-voicepacks", { cache: "no-store" });
    state.selectedMutators.clear();
    state.selectedGenericBonuses.clear();
    state.selectedVoicePackId = normalizeVoicePackId(state.data?.defaults?.voicePack || "Default");
    state.genericBonusLevels = createDefaultGenericBonusLevels();

    populateSelect(
      el.commanderSelect,
      state.data.commanders,
      (item) => item.runtime,
      (item) => `${item.displayName} (${item.runtime})`,
    );
    populateSelect(
      el.mapSelect,
      state.data.maps,
      (item) => item.id,
      (item) => item.displayName,
    );

    populateMutatorFilters();
    const uiState = readUiState();
    state.selectedMutatorPanelExpanded = uiState.selectedMutatorPanelExpanded === true;
    state.startTalentMaskMode = uiState.startTalentMaskMode || "default";
    state.activeSheet = normalizeActiveSheet(uiState.activeSheet);
    if (!loadSavedConfig()) {
      applyPayload(getDefaultPayload());
    }
    syncActiveSheetUI();
    updateBootstrapStrip();
    renderRecentConfigs();
    renderScenarioPresets();
    renderMutatorPresets();
    renderLaunchHistory();

    el.saveConfigButton.disabled = false;
    el.resetConfigButton.disabled = false;
    el.exportPayloadButton.disabled = false;
    el.applyPayloadButton.disabled = el.payloadText.value.trim().length === 0;
    el.copyPayloadButton.disabled = el.payloadText.value.trim().length === 0;
    updateConfigActionButtons();
    setStatus(
      `已载入 ${state.data.counts.commanders} 指挥官 / ${state.data.counts.maps} 地图 / ${state.data.counts.mutators} 因子`,
      "status-ok",
    );
    writeOutput({
      workspaceRoot: state.data.workspaceRoot,
      launchScript: state.data.launchScript,
      resourcePlan: state.data.resourcePlan,
      completion: state.data.completion,
      scoreSystem: state.data.scoreSystem,
    });
  } catch (error) {
    state.data = null;
    setServiceUnavailable(error.message || "本地启动器离线");
    writeOutput(error.stack || error.message);
    scheduleBootstrapRetry();
  }
}

function setLaunchControlsDisabled(disabled) {
  if (disabled) {
    el.previewButton.disabled = true;
    el.launchButton.disabled = true;
    el.validateButton.disabled = true;
    el.validateLaunchButton.disabled = true;
    return;
  }
  updateConfigActionButtons();
}

async function pollLaunchStatus(launchResult) {
  try {
    return await apiFetchJson("/api/launch-status", {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=utf-8" },
      body: JSON.stringify({
        pid: launchResult.pid,
        stdout: launchResult.stdout,
        stderr: launchResult.stderr,
      }),
    });
  } catch (error) {
    if (isFetchFailure(error)) {
      setServiceUnavailable(error.message || "本地启动器离线");
      scheduleBootstrapRetry();
    }
    throw error;
  }
}

async function waitForLaunchCompletion(launchResult, options = {}) {
  const maxAttempts = options.maxAttempts ?? 120;
  const intervalMs = options.intervalMs ?? 500;
  const requireDryRunMarker = options.requireDryRunMarker === true;
  const runningLabel = options.runningLabel || "";

  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    const status = await pollLaunchStatus(launchResult);
    setLastLogPaths(status.stdout?.path, status.stderr?.path);
    el.launchState.textContent = status.running ? (runningLabel || `PID ${status.pid}`) : "已结束";
    writeOutput(formatLaunchStatus(status));
    if (!status.running) {
      if (status.exitCode !== null && status.exitCode !== undefined && Number(status.exitCode) !== 0) {
        throw new Error(`启动脚本退出码非 0: ${status.exitCode}`);
      }
      if (requireDryRunMarker && !isDryRunComplete(status)) {
        throw new Error("dry-run 未写出完整验证日志");
      }
      const stderr = getStatusStderr(status);
      if (stderr) {
        throw new Error(`stderr 非空，验证失败:\n${stderr}`);
      }
      return status;
    }
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }

  throw new Error("等待启动进程结束超时");
}

async function submitLaunch(payload, labels = {}) {
  if (state.launchPollTimer) {
    el.launchState.textContent = "启动运行中";
    writeOutput("已有启动进程正在轮询状态；请等待结束后再提交新的启动或验证。");
    return null;
  }
  if (!assertLaunchPayloadValid(payload)) {
    return null;
  }
  setLaunchControlsDisabled(true);
  el.launchState.textContent = labels.pending || "启动中";
  writeOutput({ request: payload });

  try {
    const result = await apiFetchJson("/api/launch", {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=utf-8" },
      body: JSON.stringify(payload),
    });
    el.launchState.textContent = labels.started || `PID ${result.pid}`;
    setLastLogPaths(result.stdout, result.stderr);
    let finalStatus = null;
    if (payload.noLaunch) {
      writeOutput(result);
      finalStatus = await waitForLaunchCompletion(result, {
        requireDryRunMarker: true,
        runningLabel: labels.running || "",
      });
      setValidatedConfig(payload, result, finalStatus, labels.validationSource || "验证");
      el.launchState.textContent = "验证通过";
    } else {
      writeOutput(result);
    }
    addRecentConfig(payload);
    const historyId = addLaunchHistory(payload, result, finalStatus);
    if (!payload.noLaunch) {
      beginLaunchPolling(result, historyId);
    }
    return {
      ...result,
      finalStatus,
      historyId,
    };
  } catch (error) {
    if (isFetchFailure(error)) {
      setServiceUnavailable(error.message || "本地启动器离线");
      scheduleBootstrapRetry();
    } else {
      el.launchState.textContent = "错误";
    }
    writeOutput(error.stack || error.message);
    return null;
  } finally {
    if (payload.noLaunch || !state.launchPollTimer) {
      setLaunchControlsDisabled(false);
    }
  }
}

async function launchGame() {
  const payload = buildLaunchPayload();
  const labels = getLaunchModeLabels(payload);
  await submitLaunch(payload, {
    pending: labels.pending,
    started: labels.started,
    running: labels.running,
  });
}

async function validateCurrentConfig() {
  const payload = {
    ...buildLaunchPayload(),
    noLaunch: true,
  };
  await submitLaunch(payload, {
    pending: "验证中",
    started: "dry-run",
  });
}

async function validateThenLaunch() {
  const payload = buildLaunchPayload();
  if (payload.noLaunch) {
    await submitLaunch(payload, {
      pending: "安装验证中",
      started: "安装中",
      running: "安装验证中",
    });
    return;
  }

  const validationPayload = {
    ...payload,
    noLaunch: true,
  };
  const validationResult = await submitLaunch(validationPayload, {
    pending: "验证中",
    started: "dry-run",
  });
  if (!validationResult) {
    return;
  }
  await submitLaunch(
    {
      ...payload,
      noLaunch: false,
    },
    {
      pending: "验证通过，启动中",
    },
  );
}

async function validatePayload(payload, pending = "验证中") {
  if (!applyPayload(payload)) return;
  await submitLaunch(
    {
      ...buildLaunchPayload(),
      noLaunch: true,
    },
    {
      pending,
      started: "dry-run",
    },
  );
}

function beginLaunchPolling(launchResult, historyId = null) {
  if (state.launchPollTimer) {
    clearInterval(state.launchPollTimer);
    state.launchPollTimer = null;
  }

  let attempts = 0;
  const poll = async () => {
    attempts += 1;
    try {
      const status = await pollLaunchStatus(launchResult);
      el.launchState.textContent = status.running ? `PID ${status.pid}` : "已结束";
      setLastLogPaths(status.stdout?.path, status.stderr?.path);
      writeOutput(formatLaunchStatus(status));
      if (!status.running || attempts >= 60) {
        if (!status.running) {
          updateLaunchHistoryStatus(historyId, status);
        } else {
          const timedOutStatus = {
            ...status,
            timedOut: true,
            checkedAt: status.checkedAt || new Date().toISOString(),
          };
          updateLaunchHistoryStatus(historyId, timedOutStatus);
          el.launchState.textContent = "轮询超时";
          writeOutput(`${formatLaunchStatus(status)}\n\n轮询已达到上限，已停止自动刷新。`);
        }
        clearInterval(state.launchPollTimer);
        state.launchPollTimer = null;
        setLaunchControlsDisabled(false);
      }
    } catch (error) {
      clearInterval(state.launchPollTimer);
      state.launchPollTimer = null;
      setLaunchControlsDisabled(false);
      el.launchState.textContent = "状态错误";
      writeOutput(error.stack || error.message);
    }
  };

  poll();
  state.launchPollTimer = setInterval(poll, 1000);
  updateRowSubmitButtons();
}

async function previewLaunch() {
  const payload = buildLaunchPayload();
  if (!assertLaunchPayloadValid(payload)) {
    return;
  }
  el.previewButton.disabled = true;
  el.launchState.textContent = "预览";
  writeOutput({ request: payload });

  try {
    const result = await apiFetchJson("/api/preview", {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=utf-8" },
      body: JSON.stringify(payload),
    });
    el.launchState.textContent = "参数有效";
    el.copyCommandButton.disabled = !result.commandLine;
    el.copyCommandButton.dataset.command = result.commandLine || "";
    writeOutput(result);
  } catch (error) {
    if (isFetchFailure(error)) {
      setServiceUnavailable(error.message || "本地启动器离线");
      scheduleBootstrapRetry();
    } else {
      el.launchState.textContent = "错误";
    }
    writeOutput(error.stack || error.message);
  } finally {
    updateConfigActionButtons();
  }
}

async function copyPreviewCommand() {
  const command = el.copyCommandButton.dataset.command || "";
  if (!command) return;

  await copyText(command);
  el.launchState.textContent = "已复制";
}

el.commanderSelect.addEventListener("change", () => {
  renderCommanderDetails();
  renderQuickPickers();
  scheduleAutosave();
});
el.mapSelect.addEventListener("change", () => {
  updateSummary();
  renderQuickPickers();
  scheduleAutosave();
});
el.enableStartTalents.addEventListener("change", () => {
  renderStartTalents(getCommander());
  updateSummary();
  scheduleAutosave();
});
el.mutatorSearch.addEventListener("input", renderMutators);
el.mutatorFilter.addEventListener("change", renderMutators);
el.mutatorCategoryFilter.addEventListener("change", renderMutators);
el.mutatorTierFilter.addEventListener("change", renderMutators);
el.mutatorPreset.addEventListener("change", () => {
  updateSummary();
  scheduleAutosave();
});
for (const tab of el.sheetTabs) {
  tab.addEventListener("click", () => {
    setActiveSheet(tab.dataset.sheetTab);
  });
}
el.selectedMutatorSearch.addEventListener("input", renderSelectedMutators);
el.clearMatchedMutators.addEventListener("click", clearMatchedSelectedMutators);
el.toggleSelectedMutators.addEventListener("click", () => {
  state.selectedMutatorPanelExpanded = !state.selectedMutatorPanelExpanded;
  renderSelectedMutators();
  scheduleAutosave();
});
el.dryRunToggle.addEventListener("change", () => {
  updateSummary();
  scheduleAutosave();
});
el.clearMutatorFilters.addEventListener("click", clearMutatorFilters);
el.applyMutatorImport.addEventListener("click", () => applyMutatorImport(true));
el.appendMutatorImport.addEventListener("click", () => applyMutatorImport(false));
el.mutatorImportText.addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    applyMutatorImport(true);
  }
});
el.clearMutators.addEventListener("click", () => {
  state.selectedMutators.clear();
  resetSelectedMutatorView();
  renderMutators();
  updateSummary();
  scheduleAutosave();
});
el.clearRecentButton.addEventListener("click", () => writeRecentConfigs([]));
el.saveScenarioPreset.addEventListener("click", saveScenarioPreset);
el.clearScenarioPresets.addEventListener("click", () => writeScenarioPresets([]));
el.saveMutatorPreset.addEventListener("click", saveCurrentMutatorPreset);
el.savedMutatorPreset.addEventListener("change", renderMutatorPresets);
el.applyMutatorPreset.addEventListener("click", applySelectedMutatorPreset);
el.deleteMutatorPreset.addEventListener("click", deleteSelectedMutatorPreset);
el.clearLaunchHistory.addEventListener("click", () => writeLaunchHistory([]));
el.refreshButton.addEventListener("click", loadBootstrap);
el.saveConfigButton.addEventListener("click", saveConfig);
el.resetConfigButton.addEventListener("click", resetConfig);
el.previewButton.addEventListener("click", previewLaunch);
el.validateButton.addEventListener("click", validateCurrentConfig);
el.validateLaunchButton.addEventListener("click", validateThenLaunch);
el.copyCommandButton.addEventListener("click", copyPreviewCommand);
el.copyLogPathsButton.addEventListener("click", copyLogPaths);
el.copyOutputButton.addEventListener("click", copyOutputLog);
el.clearOutputButton.addEventListener("click", clearOutputLog);
el.copySummaryButton.addEventListener("click", copyConfigSummary);
el.exportPayloadButton.addEventListener("click", exportCurrentPayload);
el.copyPayloadButton.addEventListener("click", copyPayloadJson);
el.applyPayloadButton.addEventListener("click", applyPayloadJson);
el.clearPayloadButton.addEventListener("click", clearPayloadJson);
el.payloadText.addEventListener("input", () => {
  const hasText = el.payloadText.value.trim().length > 0;
  el.copyPayloadButton.disabled = !hasText;
  el.applyPayloadButton.disabled = !hasText || !state.data;
  if (hasText) {
    parsePayloadText();
  } else {
    setPayloadStatus("等待配置");
  }
});
el.launchButton.addEventListener("click", launchGame);
el.randomMutators.addEventListener("click", () => randomizeMutators());
el.appendRandomMutators.addEventListener("click", () => randomizeMutators(null, true));
el.randomMutators3.addEventListener("click", () => randomizeMutators(3));
el.randomMutators5.addEventListener("click", () => randomizeMutators(5));
el.randomMutators10.addEventListener("click", () => randomizeMutators(10));
el.copyMutatorIds.addEventListener("click", copySelectedMutatorIds);

loadBootstrap();

// === Tab 切换 ===
document.querySelectorAll('.tab').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.tab').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    const tab = btn.dataset.tab;
    document.querySelectorAll('[data-tab-content]').forEach(c => {
      c.hidden = c.dataset.tabContent !== tab;
    });
    if (tab === 'B') {
      import('./components/scenario-panels.js').then(m => m.renderScenarioCards());
    }
    if (tab === 'C') {
      initRebornTab();
    }
  });
});

// === Reborn 战役 Tab ===
let rebornState = {
  selectedCommander: null,
  selectedMapId: null,
  selectedMapFile: null,
  commanders: null,
  maps: null,
  pollTimer: null,
};

async function initRebornTab() {
  const rebornStatus = document.getElementById('rebornStatus');
  const rebornLaunchButton = document.getElementById('rebornLaunchButton');
  rebornLaunchButton.disabled = true;
  rebornStatus.textContent = '加载中';

  try {
    // 并行加载指挥官（复用 bootstrap）和地图列表
    if (!state.data) {
      rebornStatus.textContent = '等待主数据加载';
      return;
    }
    rebornState.commanders = state.data.commanders;

    if (!rebornState.maps) {
      const mapsResp = await fetch('/api/reborn-maps');
      const mapsData = await mapsResp.json();
      rebornState.maps = mapsData.maps || [];
      // 默认选中第一张地图（zexpedition03）
      if (rebornState.maps.length > 0) {
        rebornState.selectedMapId = rebornState.maps[0].id;
        rebornState.selectedMapFile = rebornState.maps[0].mapFile;
      }
    }

    renderRebornCommanders();
    renderRebornMaps();
    updateRebornSummary();
    rebornStatus.textContent = `已加载 ${rebornState.commanders.length} 个指挥官, ${rebornState.maps.length} 张地图`;
  } catch (e) {
    rebornStatus.textContent = `加载失败: ${e.message}`;
  }

  // 避免重复绑定
  rebornLaunchButton.removeEventListener('click', launchRebornGame);
  rebornLaunchButton.addEventListener('click', launchRebornGame);
}

function renderRebornCommanders() {
  const container = document.getElementById('rebornCommanderList');
  if (!container) return;
  container.replaceChildren();
  const commanders = rebornState.commanders || [];
  if (commanders.length === 0) {
    container.textContent = '无指挥官数据';
    return;
  }
  const raceOrder = ['Terran', 'Protoss', 'Zerg', 'Other'];
  const raceGroups = new Map(raceOrder.map(r => [r, []]));
  for (const cmd of commanders) {
    const race = getCommanderRaceSimple(cmd.runtime);
    const bucket = raceGroups.get(race) || raceGroups.get('Other');
    bucket.push(cmd);
  }
  for (const race of raceOrder) {
    const group = raceGroups.get(race) || [];
    if (group.length === 0) continue;
    const section = document.createElement('section');
    section.className = 'commander-race-group';
    section.dataset.race = race;
    const heading = document.createElement('h3');
    heading.className = 'commander-race-label';
    heading.textContent = { Terran: '人类', Protoss: '星灵', Zerg: '异虫', Other: '其他' }[race];
    section.append(heading);
    for (const cmd of group) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'commander-card';
      btn.dataset.runtime = cmd.runtime;
      if (rebornState.selectedCommander === cmd.runtime) {
        btn.classList.add('selected');
      }
      // 复用 7vs1 tab 的图标加载逻辑
      const art = cmd.image
        ? `<img src="${escapeHtml(cmd.image)}" alt="${escapeHtml(cmd.displayName || cmd.runtime)}">`
        : `<span class="commander-card-fallback">${escapeHtml(initials(cmd.displayName || cmd.runtime))}</span>`;
      const raceLabel = { Terran: '人类', Protoss: '星灵', Zerg: '异虫', Other: '其他' }[race];
      btn.innerHTML = `
        <span class="commander-card-art">${art}</span>
        <span class="commander-card-body">
          <span class="commander-card-top">
            <strong>${escapeHtml(cmd.displayName || cmd.runtime)}</strong>
            <em>${escapeHtml(cmd.runtime)}</em>
          </span>
          <span class="commander-card-badges">
            <em>${escapeHtml(raceLabel)}</em>
          </span>
        </span>
      `;
      btn.addEventListener('click', () => {
        rebornState.selectedCommander = cmd.runtime;
        renderRebornCommanders();
        updateRebornSummary();
        updateRebornLaunchButton();
      });
      section.append(btn);
    }
    container.append(section);
  }
}

function renderRebornMaps() {
  const container = document.getElementById('rebornMapList');
  if (!container) return;
  container.replaceChildren();
  const maps = rebornState.maps || [];
  if (maps.length === 0) {
    container.textContent = '无地图数据';
    return;
  }
  for (const map of maps) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'map-card quick-pick-item';
    if (rebornState.selectedMapId === map.id) {
      btn.classList.add('selected');
    }
    btn.innerHTML = `
      <span class="quick-pick-icon map-card-icon">${escapeHtml(initials(map.mapName || map.id))}</span>
      <span class="map-card-copy">
        <strong>${escapeHtml(map.mapName || map.id)}</strong>
        <em>${escapeHtml(map.id)}</em>
      </span>
    `;
    btn.addEventListener('click', () => {
      rebornState.selectedMapId = map.id;
      rebornState.selectedMapFile = map.mapFile;
      renderRebornMaps();
      updateRebornSummary();
      updateRebornLaunchButton();
    });
    container.append(btn);
  }
}

function updateRebornSummary() {
  const summaryCommander = document.getElementById('rebornSummaryCommander');
  const summaryMap = document.getElementById('rebornSummaryMap');
  const summary = document.getElementById('rebornSummary');
  if (summaryCommander) {
    summaryCommander.textContent = rebornState.selectedCommander || '-';
  }
  if (summaryMap) {
    const map = rebornState.maps?.find(m => m.id === rebornState.selectedMapId);
    summaryMap.textContent = map ? map.mapName : '-';
  }
  if (summary) {
    const ready = rebornState.selectedCommander && rebornState.selectedMapId;
    summary.textContent = ready ? '就绪' : '未就绪';
    summary.className = ready ? 'badge status-ok' : 'badge';
  }
}

function updateRebornLaunchButton() {
  const btn = document.getElementById('rebornLaunchButton');
  if (!btn) return;
  btn.disabled = !(rebornState.selectedCommander && rebornState.selectedMapId);
}

function getCommanderRaceSimple(runtime) {
  if (runtime.startsWith('Terran')) return 'Terran';
  if (runtime.startsWith('Protoss')) return 'Protoss';
  if (runtime.startsWith('Zerg')) return 'Zerg';
  return 'Other';
}

async function launchRebornGame() {
  const btn = document.getElementById('rebornLaunchButton');
  const stateLabel = document.getElementById('rebornLaunchState');
  const output = document.getElementById('rebornOutput');
  if (!rebornState.selectedCommander) return;
  if (rebornState.pollTimer) {
    stateLabel.textContent = '已有启动进程运行中';
    return;
  }
  btn.disabled = true;
  stateLabel.textContent = '启动中...';
  output.textContent = `启动指挥官: ${rebornState.selectedCommander}\n地图: ${rebornState.selectedMapFile || '默认'}\n`;
  try {
    const result = await apiFetchJson('/api/reborn-launch', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify({
        commander: rebornState.selectedCommander,
        mapName: rebornState.selectedMapFile || '',
      }),
    });
    output.textContent += `进程 PID: ${result.pid}\n`;
    stateLabel.textContent = `PID ${result.pid}`;
    pollRebornLaunch(result);
  } catch (e) {
    output.textContent += `错误: ${e.message}\n`;
    stateLabel.textContent = '错误';
    btn.disabled = false;
  }
}

function pollRebornLaunch(result) {
  const btn = document.getElementById('rebornLaunchButton');
  const stateLabel = document.getElementById('rebornLaunchState');
  const output = document.getElementById('rebornOutput');
  let attempts = 0;
  const maxAttempts = 120;
  rebornState.pollTimer = setInterval(async () => {
    attempts++;
    try {
      const status = await apiFetchJson('/api/reborn-launch-status', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=utf-8' },
        body: JSON.stringify({ pid: result.pid, stdout: result.stdout, stderr: result.stderr }),
      });
      if (status.stdout?.tail) {
        output.textContent = `启动指挥官: ${rebornState.selectedCommander}\n进程 PID: ${result.pid}\n${status.stdout.tail}`;
      }
      if (!status.running && status.exitCode !== null) {
        clearInterval(rebornState.pollTimer);
        rebornState.pollTimer = null;
        if (status.exitCode === 0) {
          stateLabel.textContent = '启动成功（游戏运行中）';
          output.textContent += '\n=== 启动完成 ===\n';
        } else {
          stateLabel.textContent = `进程退出，退出码: ${status.exitCode}`;
          output.textContent += `\n=== 进程退出，退出码: ${status.exitCode} ===\n`;
          if (status.stderr?.tail) {
            output.textContent += `stderr:\n${status.stderr.tail}\n`;
          }
        }
        btn.disabled = false;
      }
      if (attempts >= maxAttempts) {
        clearInterval(rebornState.pollTimer);
        rebornState.pollTimer = null;
        stateLabel.textContent = '轮询超时';
        btn.disabled = false;
      }
    } catch (e) {
      // 忽略轮询错误，继续重试
    }
  }, 2000);
}
