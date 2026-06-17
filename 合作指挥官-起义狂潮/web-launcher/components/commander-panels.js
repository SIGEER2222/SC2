import { escapeHtml } from "../lib/ui-helpers.js";

export function renderPrestigePanel({
  container,
  commander,
  activeMask,
  defaultMask,
  getPrestigeTooltipParts,
  onSelectMode,
  onTogglePrestige,
}) {
  container.replaceChildren();

  const summary = document.createElement("div");
  summary.className = "prestige-summary-card";
  summary.innerHTML = `
    <div class="prestige-summary-copy">
      <strong>威望拆分</strong>
    </div>
    <div class="prestige-summary-actions">
      <button type="button" class="mini" data-prestige-select="default">按默认整合</button>
      <button type="button" class="mini" data-prestige-select="all">全选</button>
      <button type="button" class="mini" data-prestige-select="none">全清</button>
    </div>
  `;
  container.append(summary);

  for (const prestige of commander.prestiges ?? []) {
    const card = document.createElement("div");
    card.className = "prestige-item";
    const checked = (activeMask & prestige.bitMask) === prestige.bitMask;
    const defaultSelected = (defaultMask & prestige.bitMask) === prestige.bitMask;
    const tooltipParts = getPrestigeTooltipParts ? getPrestigeTooltipParts(prestige.tooltip || prestige.id) : { positive: prestige.id, negative: "" };
    const positiveTooltip = tooltipParts.positive || prestige.id;
    const negativeTooltip = tooltipParts.negative || "";
    card.innerHTML = `
      <label class="prestige-toggle">
        <input class="prestige-toggle-input" type="checkbox" data-slot="${prestige.slot}" data-bit-mask="${prestige.bitMask}" ${checked ? "checked" : ""}>
        <span class="prestige-toggle-main">
          <span class="prestige-name">
            <strong>P${prestige.slot + 1} ${escapeHtml(prestige.name || prestige.id)}</strong>
            <span class="badge">mask ${prestige.bitMask}</span>
          </span>
          <span class="prestige-tags">
            <em class="${defaultSelected ? "status-ok" : ""}">${defaultSelected ? "默认整合内" : "默认未选"}</em>
            <em>${escapeHtml(prestige.id)}</em>
          </span>
        </span>
      </label>
      <div class="prestige-tip">
        <div class="prestige-tip-positive">${escapeHtml(positiveTooltip)}</div>
        ${negativeTooltip ? `<div class="prestige-tip-negative">${escapeHtml(negativeTooltip)}</div>` : ""}
      </div>
    `;
    container.append(card);
  }

  container.querySelectorAll("[data-prestige-select]").forEach((button) => {
    button.addEventListener("click", () => {
      onSelectMode(button.dataset.prestigeSelect);
    });
  });

  container.querySelectorAll(".prestige-toggle-input").forEach((input) => {
    input.addEventListener("change", () => {
      onTogglePrestige();
    });
  });
}

export function renderExtraOptionPanel({
  container,
  allOptions,
  activeOptions,
  selectedOverrideValues,
  prestigeEnabled,
  onToggleOverride,
}) {
  if (!container) return;
  container.replaceChildren();

  const header = document.createElement("div");
  header.className = "extra-option-head";
  header.innerHTML = `
    <strong>额外升级</strong>
    <span class="badge">${activeOptions.length}</span>
  `;
  container.append(header);

  if (allOptions.length === 0) {
    const empty = document.createElement("div");
    empty.className = "extra-option-empty";
    empty.textContent = "当前指挥官没有可选的威望额外升级。";
    container.append(empty);
    return;
  }

  if (activeOptions.length === 0) {
    const empty = document.createElement("div");
    empty.className = "extra-option-empty";
    empty.textContent = prestigeEnabled
      ? "当前所选威望没有额外升级。"
      : "启用融合威望后才可选择额外升级。";
    container.append(empty);
    return;
  }

  for (const option of activeOptions) {
    const card = document.createElement("div");
    card.className = "extra-option-item";
    const checked = selectedOverrideValues.has(option.overrideValue);
    card.innerHTML = `
      <label class="extra-option-toggle">
        <input class="extra-option-input" type="checkbox" data-override-value="${escapeHtml(option.overrideValue)}" ${checked ? "checked" : ""}>
        <span class="extra-option-main">
          <span class="extra-option-name">
            <strong>${escapeHtml(option.name || option.id)}</strong>
            <span class="badge">P${Number(option.prestigeSlot) + 1}</span>
          </span>
          <span class="extra-option-tags">
            <em>${escapeHtml(option.prestigeName || option.prestigeId || "")}</em>
            <em>${escapeHtml(option.id)}</em>
          </span>
        </span>
      </label>
      <div class="extra-option-desc">${escapeHtml(option.description || option.overrideValue || option.id)}</div>
    `;
    container.append(card);
  }

  container.querySelectorAll(".extra-option-input").forEach((input) => {
    input.addEventListener("change", () => {
      onToggleOverride(String(input.dataset.overrideValue || ""), input.checked);
    });
  });
}

export function renderMasteryGridPanel({ container, commander }) {
  container.replaceChildren();
  const masteries = [...(commander.masteries ?? [])].sort((a, b) => a.slot - b.slot);

  for (const mastery of masteries) {
    const card = document.createElement("label");
    card.className = "mastery-card";
    card.innerHTML = `
      <span class="mastery-title">${escapeHtml(mastery.name || mastery.id)}</span>
      <span class="mastery-meta">C${mastery.category} / ${escapeHtml(mastery.id)}</span>
      <input class="mastery-input" type="number" value="30" data-slot="${mastery.slot}">
    `;
    container.append(card);
  }
}

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
      <span class="voice-pack-card-reward">当前种族奖励: ${escapeHtml(rewardId)}</span>
    `;
    card.addEventListener("click", () => onSelectVoicePack(voicePack.id));
    container.append(card);
  }
}
