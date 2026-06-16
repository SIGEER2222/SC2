import {
  escapeHtml,
  getCommanderRace,
  getCommanderRaceLabel,
  getStatusToneClass,
  initials,
} from "../lib/ui-helpers.js";

export function renderQuickPickers({
  commanderContainer,
  mapContainer,
  commanderCountElement,
  commanders,
  allCommandersCount,
  maps,
  selectedCommanderRuntime,
  selectedMapId,
  getMapCompletionState,
  onSelectCommander,
  onSelectMap,
}) {
  commanderContainer.replaceChildren();
  mapContainer.replaceChildren();
  commanderCountElement.textContent = `${commanders.length}/${allCommandersCount}`;

  if (commanders.length === 0) {
    const empty = document.createElement("div");
    empty.className = "quick-pick-empty";
    empty.textContent = "无匹配指挥官";
    commanderContainer.append(empty);
  }

  const raceOrder = ["Terran", "Protoss", "Zerg", "Other"];
  const raceGroups = new Map(raceOrder.map((race) => [race, []]));
  for (const commander of commanders) {
    const race = getCommanderRace(commander.runtime);
    const bucket = raceGroups.get(race) || raceGroups.get("Other");
    bucket.push(commander);
  }

  for (const race of raceOrder) {
    const groupCommanders = raceGroups.get(race) || [];
    if (groupCommanders.length === 0) {
      continue;
    }

    const group = document.createElement("section");
    group.className = "commander-race-group";
    group.dataset.race = race;
    group.innerHTML = `
      <div class="commander-race-head">
        <strong class="commander-race-title">${escapeHtml(getCommanderRaceLabel(race))}</strong>
        <span class="badge">${groupCommanders.length}</span>
      </div>
      <div class="commander-race-row"></div>
    `;

    const row = group.querySelector(".commander-race-row");
    for (const commander of groupCommanders) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = `commander-card${commander.runtime === selectedCommanderRuntime ? " selected" : ""}`;
      button.title = commander.integrationNote || commander.runtime;
      const raceLabel = getCommanderRaceLabel(getCommanderRace(commander.runtime));
      const toneClass = getStatusToneClass(commander.integrationTone);
      const portraitToneClass = commander.imageSource === "portrait-exact"
        ? "status-ok"
        : commander.imageSource === "portrait-fallback"
          ? "status-warn"
          : "";
      const art = commander.image
        ? `<img src="${escapeHtml(commander.image)}" alt="${escapeHtml(commander.displayName || commander.runtime)}">`
        : `<span class="commander-card-fallback">${escapeHtml(initials(commander.displayName || commander.runtime))}</span>`;
      button.innerHTML = `
        <span class="commander-card-art">${art}</span>
        <span class="commander-card-body">
          <span class="commander-card-top">
            <strong>${escapeHtml(commander.displayName || commander.runtime)}</strong>
            <em>${escapeHtml(commander.runtime)}</em>
          </span>
          <span class="commander-card-badges">
            <em>${escapeHtml(raceLabel)}</em>
            <em class="${toneClass}">${escapeHtml(commander.integrationStatus || "未标记")}</em>
            <em class="${portraitToneClass}">${escapeHtml(commander.imageSourceLabel || "未标记")}</em>
          </span>
        </span>
      `;
      button.addEventListener("click", () => {
        onSelectCommander(commander.runtime);
      });
      row.append(button);
    }

    commanderContainer.append(group);
  }

  if (maps.length === 0) {
    const empty = document.createElement("div");
    empty.className = "quick-pick-empty";
    empty.textContent = "无匹配地图";
    mapContainer.append(empty);
  }

  for (const map of maps) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `quick-pick-item map-card${map.id === selectedMapId ? " selected" : ""}`;
    const completion = getMapCompletionState(map.id);
    button.innerHTML = `
      <span class="quick-pick-icon map-card-icon">${initials(map.title || map.displayName || map.id)}</span>
      <span class="map-card-copy">
        <strong>${escapeHtml(map.title || map.displayName || map.id)}</strong>
        <em>${escapeHtml(map.id)}</em>
        <span class="map-card-status ${getStatusToneClass(completion.tone)}" title="${escapeHtml(completion.detail || completion.label)}">${escapeHtml(completion.label)}</span>
        <span class="map-card-meta">${escapeHtml(completion.meta || "")}</span>
      </span>
    `;
    button.addEventListener("click", () => {
      onSelectMap(map.id);
    });
    mapContainer.append(button);
  }
}
