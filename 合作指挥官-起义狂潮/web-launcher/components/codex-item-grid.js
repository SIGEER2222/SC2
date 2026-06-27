import { escapeHtml } from "../lib/ui-helpers.js";
import { createCodexItemCard } from "./codex-item-card.js";

const DEFAULT_CATEGORIES = [
  { key: "all", label: "全部" },
  { key: "unit", label: "单位" },
  { key: "building", label: "建筑" },
  { key: "ability", label: "顶部技能" },
];

export function renderCodexItemGrid({
  container,
  items = [],
  categories = DEFAULT_CATEGORIES,
  activeCategory = "all",
  searchQuery = "",
  onCategoryChange = null,
  onSearchChange = null,
  onItemClick = null,
  countElement = null,
}) {
  container.replaceChildren();

  const header = document.createElement("div");
  header.className = "codex-grid-header";

  const tabs = document.createElement("nav");
  tabs.className = "codex-category-tabs";
  tabs.setAttribute("role", "tablist");

  for (const cat of categories) {
    const count = cat.key === "all"
      ? items.length
      : items.filter((item) => item.type === cat.key).length;
    const tab = document.createElement("button");
    tab.type = "button";
    tab.className = `codex-category-tab${activeCategory === cat.key ? " active" : ""}`;
    tab.dataset.category = cat.key;
    tab.setAttribute("role", "tab");
    tab.setAttribute("aria-selected", activeCategory === cat.key ? "true" : "false");
    tab.innerHTML = `
      <span>${escapeHtml(cat.label)}</span>
      <span class="badge">${count}</span>
    `;
    tab.addEventListener("click", () => {
      if (typeof onCategoryChange === "function") {
        onCategoryChange(cat.key);
      }
    });
    tabs.append(tab);
  }

  const searchWrap = document.createElement("label");
  searchWrap.className = "search codex-search";
  searchWrap.innerHTML = `
    <span>搜索</span>
    <input type="search" autocomplete="off" placeholder="按名称或 ID 搜索" value="${escapeHtml(searchQuery)}">
  `;
  const searchInput = searchWrap.querySelector("input");
  searchInput.addEventListener("input", (e) => {
    if (typeof onSearchChange === "function") {
      onSearchChange(e.target.value);
    }
  });

  header.append(tabs, searchWrap);

  const gridWrap = document.createElement("div");
  gridWrap.className = "codex-grid-wrap";

  const filteredItems = filterItems(items, activeCategory, searchQuery);

  if (countElement) {
    countElement.textContent = `${filteredItems.length}/${items.length}`;
  }

  if (filteredItems.length === 0) {
    const empty = document.createElement("div");
    empty.className = "empty-state";
    empty.textContent = "没有匹配的条目";
    gridWrap.append(empty);
  } else {
    const grid = document.createElement("div");
    grid.className = "codex-item-grid";
    for (const item of filteredItems) {
      const card = createCodexItemCard(item, {
        clickable: typeof onItemClick === "function",
        onClick: onItemClick,
      });
      grid.append(card);
    }
    gridWrap.append(grid);
  }

  container.append(header, gridWrap);
}

function filterItems(items, category, query) {
  const q = String(query || "").trim().toLowerCase();
  return items.filter((item) => {
    if (category !== "all" && item.type !== category) {
      return false;
    }
    if (!q) return true;
    const name = String(item.name || "").toLowerCase();
    const id = String(item.id || "").toLowerCase();
    const desc = String(item.description || "").toLowerCase();
    return name.includes(q) || id.includes(q) || desc.includes(q);
  });
}
