import { escapeHtml } from "../lib/ui-helpers.js";

export function renderPrestigePanel({
  container,
  commander,
  activeMask,
  defaultMask,
  getPositivePrestigeTooltipText,
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
    const positiveTooltip = getPositivePrestigeTooltipText(prestige.tooltip || prestige.id);
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
      <div class="prestige-tip">${escapeHtml(positiveTooltip || prestige.id)}</div>
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
  onToggleBonus,
}) {
  if (!container) return;
  container.replaceChildren();

  const header = document.createElement("div");
  header.className = "extra-option-head";
  header.innerHTML = `
    <strong>已选加成</strong>
    <span class="badge">${selectedBonusIds.size}</span>
  `;
  container.append(header);

  for (const option of options) {
    const checked = selectedBonusIds.has(option.id);
    const card = document.createElement("div");
    card.className = "extra-option-item";
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
    container.append(card);
  }

  container.querySelectorAll(".generic-bonus-input").forEach((input) => {
    input.addEventListener("change", () => {
      onToggleBonus(String(input.dataset.bonusId || ""), input.checked);
    });
  });
}
