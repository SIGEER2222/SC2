import { escapeHtml, initials } from "../lib/ui-helpers.js";

export function createCodexItemCard(item, options = {}) {
  const { clickable = false, onClick = null } = options;

  const tag = clickable ? "button" : "div";
  const el = document.createElement(tag);
  if (tag === "button") {
    el.type = "button";
  }
  el.className = "codex-item-card";
  el.dataset.itemId = item.id || "";
  el.dataset.itemType = item.type || "";

  const name = item.name || item.id || "未知";
  const description = item.description || item.tooltip || "";
  const image = item.image || "";

  const artHtml = image
    ? `<img class="codex-item-icon" src="${escapeHtml(image)}" alt="${escapeHtml(name)}" loading="lazy">`
    : `<span class="codex-item-icon placeholder">${escapeHtml(initials(name))}</span>`;

  const typeLabel = getTypeLabel(item.type);
  const raceLabel = item.race ? getRaceLabel(item.race) : "";

  const tagsHtml = [typeLabel, raceLabel].filter(Boolean).map((t) => `<em>${escapeHtml(t)}</em>`).join("");

  el.innerHTML = `
    <span class="codex-item-art">${artHtml}</span>
    <span class="codex-item-body">
      <span class="codex-item-name">${escapeHtml(name)}</span>
      ${item.id ? `<span class="codex-item-id">${escapeHtml(item.id)}</span>` : ""}
      ${tagsHtml ? `<span class="codex-item-tags">${tagsHtml}</span>` : ""}
    </span>
    ${description ? `<span class="codex-item-desc">${escapeHtml(description)}</span>` : ""}
  `;

  if (clickable && typeof onClick === "function") {
    el.addEventListener("click", () => onClick(item));
  }

  return el;
}

function getTypeLabel(type) {
  return {
    unit: "单位",
    building: "建筑",
    ability: "技能",
    upgrade: "升级",
    behavior: "行为",
  }[type] || type || "";
}

function getRaceLabel(race) {
  return {
    Terran: "人族",
    Protoss: "神族",
    Zerg: "虫族",
    Neutral: "中立",
  }[race] || race || "";
}
