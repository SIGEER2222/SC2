import { escapeHtml } from "../lib/ui-helpers.js";
import { renderCodexCommanderSelector } from "./codex-commander-selector.js";
import { renderCodexItemGrid } from "./codex-item-grid.js";

const CODEX_MANIFEST_PATH = "/exported-commander-codex/manifest.json";

const internalState = {
  manifest: null,
  loading: false,
  error: null,
  selectedRuntime: "",
  activeCategory: "all",
  searchQuery: "",
  commanders: [],
};

export async function loadCodexManifest() {
  if (internalState.manifest) {
    return internalState.manifest;
  }
  if (internalState.loading) {
    return new Promise((resolve) => {
      const check = () => {
        if (internalState.manifest || internalState.error) {
          resolve(internalState.manifest);
        } else {
          setTimeout(check, 50);
        }
      };
      check();
    });
  }

  internalState.loading = true;
  try {
    const response = await fetch(CODEX_MANIFEST_PATH);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const data = await response.json();
    internalState.manifest = data;
    internalState.commanders = (data.commanders || []).map((c) => ({
      ...c,
      image: c.image ? `/exported-commander-codex/portraits/${c.image}` : "",
    }));
    if (internalState.commanders.length > 0 && !internalState.selectedRuntime) {
      internalState.selectedRuntime = internalState.commanders[0].runtime;
    }
    return data;
  } catch (error) {
    internalState.error = error;
    console.warn("Failed to load codex manifest:", error);
    return null;
  } finally {
    internalState.loading = false;
  }
}

export function getCodexCommanders() {
  return internalState.commanders;
}

export function getCurrentCodexCommander() {
  return internalState.commanders.find((c) => c.runtime === internalState.selectedRuntime) || null;
}

export function getCodexItems(runtime = internalState.selectedRuntime) {
  const commander = internalState.manifest?.commanders?.find((c) => c.runtime === runtime);
  if (!commander) return [];
  const prefix = `/exported-commander-codex/${runtime}/`;
  const items = [];
  for (const unit of commander.units || []) {
    items.push({
      ...unit,
      type: "unit",
      race: commander.race || "",
      image: unit.image ? `${prefix}${unit.image}` : "",
    });
  }
  for (const building of commander.buildings || []) {
    items.push({
      ...building,
      type: "building",
      race: commander.race || "",
      image: building.image ? `${prefix}${building.image}` : "",
    });
  }
  for (const ability of commander.abilities || []) {
    items.push({
      ...ability,
      type: "ability",
      race: commander.race || "",
      image: ability.image ? `${prefix}${ability.image}` : "",
    });
  }
  return items;
}

export function renderCodexPanel({
  container,
  commanderSelectorContainer,
  countElement = null,
  onCommanderChange = null,
}) {
  container.replaceChildren();

  if (!internalState.manifest) {
    const loading = document.createElement("div");
    loading.className = "empty-state";
    loading.textContent = "加载图鉴数据中...";
    container.append(loading);
    return;
  }

  if (internalState.commanders.length === 0) {
    const empty = document.createElement("div");
    empty.className = "empty-state";
    empty.textContent = "暂无图鉴数据";
    container.append(empty);
    return;
  }

  renderCodexCommanderSelector({
    container: commanderSelectorContainer,
    commanders: internalState.commanders,
    selectedRuntime: internalState.selectedRuntime,
    onSelectCommander: (runtime) => {
      internalState.selectedRuntime = runtime;
      internalState.activeCategory = "all";
      internalState.searchQuery = "";
      if (typeof onCommanderChange === "function") {
        onCommanderChange(runtime);
      }
      refreshGrid(container, countElement);
    },
  });

  refreshGrid(container, countElement);
}

function refreshGrid(container, countElement) {
  const items = getCodexItems(internalState.selectedRuntime);

  let gridContainer = container.querySelector(".codex-grid-host");
  if (!gridContainer) {
    gridContainer = document.createElement("div");
    gridContainer.className = "codex-grid-host";
    container.append(gridContainer);
  }

  renderCodexItemGrid({
    container: gridContainer,
    items,
    activeCategory: internalState.activeCategory,
    searchQuery: internalState.searchQuery,
    countElement,
    onCategoryChange: (cat) => {
      internalState.activeCategory = cat;
      refreshGrid(container, countElement);
    },
    onSearchChange: (query) => {
      internalState.searchQuery = query;
      refreshGrid(container, countElement);
    },
  });
}
