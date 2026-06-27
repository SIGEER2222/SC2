import { escapeHtml, getCommanderRace, getCommanderRaceLabel } from "../lib/ui-helpers.js";

export function renderCodexCommanderSelector({
  container,
  commanders,
  selectedRuntime,
  onSelectCommander,
}) {
  container.replaceChildren();

  if (!commanders || commanders.length === 0) {
    const empty = document.createElement("div");
    empty.className = "empty-state";
    empty.textContent = "暂无指挥官数据";
    container.append(empty);
    return;
  }

  const grid = document.createElement("div");
  grid.className = "codex-commander-grid";
  grid.setAttribute("role", "tablist");
  grid.setAttribute("aria-label", "指挥官选择");

  for (const commander of commanders) {
    const runtime = commander.runtime || "";
    const name = commander.displayName || commander.name || runtime;
    const race = getCommanderRace(runtime);
    const raceLabel = getCommanderRaceLabel(race);
    const selected = runtime === selectedRuntime;

    const button = document.createElement("button");
    button.type = "button";
    button.className = `codex-commander-chip${selected ? " active" : ""}`;
    button.dataset.runtime = runtime;
    button.setAttribute("role", "tab");
    button.setAttribute("aria-selected", selected ? "true" : "false");
    button.title = `${name} (${raceLabel})`;

    const imageHtml = commander.image
      ? `<img src="${escapeHtml(commander.image)}" alt="${escapeHtml(name)}" class="codex-commander-chip-icon">`
      : `<span class="codex-commander-chip-icon placeholder">${escapeHtml(name.slice(0, 2))}</span>`;

    button.innerHTML = `
      ${imageHtml}
      <span class="codex-commander-chip-name">${escapeHtml(name)}</span>
    `;

    button.addEventListener("click", () => {
      if (typeof onSelectCommander === "function") {
        onSelectCommander(runtime);
      }
    });

    grid.append(button);
  }

  container.append(grid);
}
