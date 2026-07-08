import { escapeHtml } from "../lib/ui-helpers.js";

const CATEGORY_BADGES = {
  prestige: "威望",
  mastery: "精通",
  common: "通用",
};

function getCategoryBadge(category) {
  return CATEGORY_BADGES[category] || category || "通用";
}

function getSelectionValue(selections, key) {
  return Number(selections?.[key] || 0);
}

function clampLevel(value, maxLevel) {
  const max = Math.max(0, Number(maxLevel) || 0);
  const n = Number.parseInt(value, 10);
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(max, n));
}

function formatValuePreview(valueFormat, level, pointIncrement) {
  if (!valueFormat) return "";
  const actual = level * (Number(pointIncrement) || 1);
  return valueFormat.replace(/~A~/g, String(actual));
}

/**
 * 渲染统一天赋面板
 * @param {Object} options
 * @param {HTMLElement} options.container - DOM 容器
 * @param {Object} options.commander - commander 对象（含 runtime 和 talents）
 * @param {Object} options.selections - 当前选择状态 { [talentId]: number, [talentId+'.extra:'+optionId]: number }
 * @param {Function} options.onToggleTalent - switch 切换回调 (talentId, checked) => void
 * @param {Function} options.onSetTalentLevel - level 变更回调 (talentId, level) => void
 * @param {Function} options.onToggleExtraOption - extra_option 切换回调 (talentId, optionId, checked) => void
 */
export function renderTalentPanel({
  container,
  commander,
  selections,
  onToggleTalent,
  onSetTalentLevel,
  onToggleExtraOption,
}) {
  if (!container) return;
  container.replaceChildren();

  const talents = commander?.talents ?? [];

  // 顶部摘要卡片
  const summary = document.createElement("div");
  summary.className = "prestige-summary-card";
  summary.innerHTML = `
    <div class="prestige-summary-copy">
      <strong>指挥官天赋</strong>
    </div>
    <div class="prestige-summary-actions">
      <button type="button" class="mini" data-talent-select="all">全选</button>
      <button type="button" class="mini" data-talent-select="none">全清</button>
      <button type="button" class="mini" data-talent-select="default">默认</button>
    </div>
  `;
  container.append(summary);

  if (talents.length === 0) {
    const empty = document.createElement("div");
    empty.className = "extra-option-empty";
    empty.textContent = "该指挥官无天赋配置。";
    container.append(empty);
    return;
  }

  // 按顺序渲染每个天赋卡片
  for (const talent of talents) {
    const card = document.createElement("div");
    card.className = "prestige-item talent-item";
    card.dataset.talentType = talent.type;

    if (talent.type === "level") {
      appendLevelTalentCard(card, talent, selections);
    } else {
      appendSwitchTalentCard(card, talent, selections);
    }

    container.append(card);
  }

  // 绑定事件
  bindTalentPanelEvents(container, talents, selections, onToggleTalent, onSetTalentLevel, onToggleExtraOption);
}

function appendSwitchTalentCard(card, talent, selections) {
  const checked = getSelectionValue(selections, talent.id) === 1;
  card.innerHTML = `
    <label class="prestige-toggle">
      <input class="talent-toggle-input" type="checkbox" data-talent-id="${escapeHtml(talent.id)}" ${checked ? "checked" : ""}>
      <span class="prestige-toggle-main">
        <span class="prestige-name">
          <strong>${escapeHtml(talent.name || talent.id)}</strong>
          <span class="badge">${escapeHtml(getCategoryBadge(talent.category))}</span>
        </span>
        <span class="prestige-tags">
          <em>${escapeHtml(talent.id)}</em>
        </span>
      </span>
    </label>
    ${talent.description ? `<div class="prestige-tip"><div class="prestige-tip-positive">${escapeHtml(talent.description)}</div></div>` : ""}
  `;

  // switch 天赋的 extra_options
  if (Array.isArray(talent.extraOptions) && talent.extraOptions.length > 0) {
    const extraContainer = document.createElement("div");
    extraContainer.className = "extra-option-list talent-extra-option-list";
    for (const option of talent.extraOptions) {
      const optionChecked = getSelectionValue(selections, `${talent.id}.extra:${option.id}`) === 1;
      const optionCard = document.createElement("div");
      optionCard.className = "extra-option-item";
      optionCard.innerHTML = `
        <label class="extra-option-toggle">
          <input class="talent-extra-option-input" type="checkbox" data-talent-id="${escapeHtml(talent.id)}" data-option-id="${escapeHtml(option.id)}" ${optionChecked ? "checked" : ""}>
          <span class="extra-option-main">
            <span class="extra-option-name">
              <strong>${escapeHtml(option.name || option.id)}</strong>
              <span class="badge">额外</span>
            </span>
          </span>
        </label>
        <div class="extra-option-desc">${escapeHtml(option.description || option.id)}</div>
      `;
      extraContainer.append(optionCard);
    }
    card.append(extraContainer);
  }
}

function appendLevelTalentCard(card, talent, selections) {
  const maxLevel = Number(talent.maxLevel) || 0;
  const currentLevel = clampLevel(getSelectionValue(selections, talent.id), maxLevel);
  const valuePreview = formatValuePreview(talent.valueFormat, currentLevel, talent.pointIncrement);

  card.innerHTML = `
    <div class="prestige-toggle-main">
      <span class="prestige-name">
        <strong>${escapeHtml(talent.name || talent.id)}</strong>
        <span class="badge">${escapeHtml(getCategoryBadge(talent.category))}</span>
      </span>
      <span class="prestige-tags">
        <em>${escapeHtml(talent.id)}</em>
        ${talent.valueFormat ? `<em>${escapeHtml(talent.valueFormat)}</em>` : ""}
      </span>
    </div>
    ${talent.description ? `<div class="prestige-tip"><div class="prestige-tip-positive">${escapeHtml(talent.description)}</div></div>` : ""}
    <div class="generic-bonus-level-row">
      <div class="generic-bonus-level-controls">
        <button type="button" class="mini talent-level-button" data-talent-id="${escapeHtml(talent.id)}" data-level-delta="-1">-</button>
        <span class="generic-bonus-level-value" data-talent-id="${escapeHtml(talent.id)}">${currentLevel}</span>
        <button type="button" class="mini talent-level-button" data-talent-id="${escapeHtml(talent.id)}" data-level-delta="1">+</button>
        <input class="talent-level-input" type="number" min="0" max="${maxLevel}" value="${currentLevel}" data-talent-id="${escapeHtml(talent.id)}">
        <span class="badge">/${maxLevel}</span>
      </div>
      ${valuePreview ? `<span class="badge talent-value-preview">${escapeHtml(valuePreview)}</span>` : ""}
    </div>
  `;
}

function bindTalentPanelEvents(container, talents, selections, onToggleTalent, onSetTalentLevel, onToggleExtraOption) {
  // 全选/全清/默认
  container.querySelectorAll("[data-talent-select]").forEach((button) => {
    button.addEventListener("click", () => {
      const mode = button.dataset.talentSelect;
      for (const talent of talents) {
        if (talent.type === "switch") {
          const target = mode === "all" ? true : false;
          onToggleTalent(talent.id, target);
        } else if (talent.type === "level") {
          const maxLevel = Number(talent.maxLevel) || 0;
          const target = mode === "all" ? maxLevel : 0;
          onSetTalentLevel(talent.id, target);
        }
        // extra_options 跟随 switch 状态
        if (talent.type === "switch" && Array.isArray(talent.extraOptions)) {
          for (const option of talent.extraOptions) {
            const target = mode === "all" ? true : false;
            onToggleExtraOption(talent.id, option.id, target);
          }
        }
      }
    });
  });

  // switch 复选框
  container.querySelectorAll(".talent-toggle-input").forEach((input) => {
    input.addEventListener("change", () => {
      onToggleTalent(input.dataset.talentId, input.checked);
    });
  });

  // level 加减按钮
  container.querySelectorAll(".talent-level-button").forEach((button) => {
    button.addEventListener("click", () => {
      const talentId = button.dataset.talentId;
      const delta = Number(button.dataset.levelDelta || 0);
      const talent = talents.find((t) => t.id === talentId);
      const maxLevel = Number(talent?.maxLevel) || 0;
      const currentLevel = clampLevel(getSelectionValue(selections, talentId), maxLevel);
      const nextLevel = clampLevel(currentLevel + delta, maxLevel);
      onSetTalentLevel(talentId, nextLevel);
    });
  });

  // level 数字输入框
  container.querySelectorAll(".talent-level-input").forEach((input) => {
    input.addEventListener("change", () => {
      const talentId = input.dataset.talentId;
      const talent = talents.find((t) => t.id === talentId);
      const maxLevel = Number(talent?.maxLevel) || 0;
      const nextLevel = clampLevel(input.value, maxLevel);
      onSetTalentLevel(talentId, nextLevel);
    });
  });

  // extra_option 复选框
  container.querySelectorAll(".talent-extra-option-input").forEach((input) => {
    input.addEventListener("change", () => {
      onToggleExtraOption(input.dataset.talentId, input.dataset.optionId, input.checked);
    });
  });
}
