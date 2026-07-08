import { escapeHtml } from "../lib/ui-helpers.js";

export function renderGenericBonusPanel({
  container,
  options,
  selectedBonusIds,
  levelValues,
  onToggleBonus,
  onSetBonusLevel,
}) {
  if (!container) return;
  container.replaceChildren();

  const selectedCount = options.reduce((count, option) => {
    if (Number.isFinite(option.maxLevel) && option.maxLevel > 0) {
      return count + ((Number(levelValues?.[option.id] || 0) > 0) ? 1 : 0);
    }
    return count + (selectedBonusIds.has(option.id) ? 1 : 0);
  }, 0);

  const header = document.createElement("div");
  header.className = "extra-option-head";
  header.innerHTML = `
    <strong>已选加成</strong>
    <span class="badge">${selectedCount}</span>
  `;
  container.append(header);

  for (const option of options) {
    const checked = selectedBonusIds.has(option.id);
    const isLevelable = Number.isFinite(option.maxLevel) && option.maxLevel > 0;
    const level = isLevelable ? Math.max(0, Math.min(option.maxLevel, Number(levelValues?.[option.id] || 0))) : 0;
    const card = document.createElement("div");
    card.className = "extra-option-item";
    if (isLevelable) {
      card.innerHTML = `
        <div class="generic-bonus-level-row">
          <div class="extra-option-main">
            <span class="extra-option-name">
              <strong>${escapeHtml(option.name)}</strong>
              <span class="badge">${escapeHtml(option.id)}</span>
            </span>
          </div>
          <div class="generic-bonus-level-controls">
            <button type="button" class="mini generic-bonus-level-button" data-bonus-id="${escapeHtml(option.id)}" data-level-delta="-1">-</button>
            <span class="generic-bonus-level-value">${level}</span>
            <button type="button" class="mini generic-bonus-level-button" data-bonus-id="${escapeHtml(option.id)}" data-level-delta="1">+</button>
          </div>
        </div>
        <div class="extra-option-desc">${escapeHtml(option.description)} 当前点数 ${level}/${option.maxLevel}。</div>
      `;
    } else {
      card.innerHTML = `
        <label class="extra-option-toggle">
          <input class="generic-bonus-input" type="checkbox" data-bonus-id="${escapeHtml(option.id)}" ${checked ? "checked" : ""}>
          <span class="extra-option-main">
            <span class="extra-option-name">
              <strong>${escapeHtml(option.name)}</strong>
              <span class="badge">${escapeHtml(option.id)}</span>
            </span>
          </span>
        </label>
        <div class="extra-option-desc">${escapeHtml(option.description)}</div>
      `;
    }
    container.append(card);
  }

  container.querySelectorAll(".generic-bonus-input").forEach((input) => {
    input.addEventListener("change", () => {
      onToggleBonus(String(input.dataset.bonusId || ""), input.checked);
    });
  });
  container.querySelectorAll(".generic-bonus-level-button").forEach((button) => {
    button.addEventListener("click", () => {
      const bonusId = String(button.dataset.bonusId || "");
      const delta = Number(button.dataset.levelDelta || 0);
      const currentLevel = Number(levelValues?.[bonusId] || 0);
      onSetBonusLevel(bonusId, currentLevel + delta);
    });
  });
}

export function renderStartTalentPanel({
  container,
  commander,
  activeMask,
  defaultMask,
  enabled,
  onSelectMode,
  onToggleTalent,
}) {
  if (!container) return;
  container.replaceChildren();

  const talents = commander?.startTalents?.talents ?? [];

  const summary = document.createElement("div");
  summary.className = "prestige-summary-card";
  summary.innerHTML = `
    <div class="prestige-summary-copy">
      <strong>开局天赋</strong>
    </div>
    <div class="prestige-summary-actions">
      <button type="button" class="mini" data-talent-select="default">按默认</button>
      <button type="button" class="mini" data-talent-select="all">全选</button>
      <button type="button" class="mini" data-talent-select="none">全清</button>
    </div>
  `;
  container.append(summary);

  if (talents.length === 0) {
    const empty = document.createElement("div");
    empty.className = "extra-option-empty";
    empty.textContent = "当前指挥官暂无可选开局天赋。";
    container.append(empty);
    return;
  }

  for (const talent of talents) {
    const card = document.createElement("div");
    card.className = "prestige-item";
    const checked = (activeMask & talent.bitMask) === talent.bitMask;
    const defaultSelected = (defaultMask & talent.bitMask) === talent.bitMask;
    card.innerHTML = `
      <label class="prestige-toggle">
        <input class="start-talent-toggle-input" type="checkbox" data-bit-mask="${talent.bitMask}" ${checked ? "checked" : ""} ${!enabled ? "disabled" : ""}>
        <span class="prestige-toggle-main">
          <span class="prestige-name">
            <strong>${escapeHtml(talent.name || talent.id)}</strong>
            <span class="badge">掩码 ${talent.bitMask}</span>
          </span>
          <span class="prestige-tags">
            <em class="${defaultSelected ? "status-ok" : ""}">${defaultSelected ? "默认启用" : "默认未选"}</em>
            <em>${escapeHtml(talent.id)}</em>
          </span>
        </span>
      </label>
      <div class="prestige-tip">
        <div class="prestige-tip-positive">${escapeHtml(talent.description || talent.id)}</div>
      </div>
    `;
    container.append(card);
  }

  container.querySelectorAll("[data-talent-select]").forEach((button) => {
    button.addEventListener("click", () => {
      onSelectMode(button.dataset.talentSelect);
    });
  });

  container.querySelectorAll(".start-talent-toggle-input").forEach((input) => {
    input.addEventListener("change", () => {
      onToggleTalent();
    });
  });
}

export function renderVoicePackPanel({
  container,
  voicePacks,
  selectedVoicePackId,
  selectedCommanderRace,
  onSelectVoicePack,
}) {
  if (!container) return;
  container.replaceChildren();

  for (const voicePack of voicePacks) {
    const card = document.createElement("button");
    card.type = "button";
    const selected = voicePack.id === selectedVoicePackId;
    const rewardId = voicePack.rewardIds?.[selectedCommanderRace] || "-";
    card.className = `voice-pack-card${selected ? " selected" : ""}`;
    card.innerHTML = `
      <span class="voice-pack-card-head">
        <strong>${escapeHtml(voicePack.name || voicePack.id)}</strong>
        <span class="badge">${escapeHtml(voicePack.id)}</span>
      </span>
      <span class="voice-pack-card-meta">
        <em>${escapeHtml(voicePack.typeName || "语音包")}</em>
        <em>${escapeHtml(voicePack.releaseDate || "-")}</em>
      </span>
      <span class="voice-pack-card-desc">${escapeHtml(voicePack.storeName || voicePack.description || "")}</span>
      <span class="voice-pack-card-reward">当前种族奖励：${escapeHtml(rewardId)}</span>
    `;
    card.addEventListener("click", () => onSelectVoicePack(voicePack.id));
    container.append(card);
  }
}
