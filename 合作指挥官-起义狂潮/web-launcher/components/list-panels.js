import { escapeHtml, renderRowBadgesHtml, setElementDetail } from "../lib/ui-helpers.js";

export function renderRecentConfigsPanel({
  container,
  items,
  getCommanderLabel,
  getMapLabel,
  getPayloadModeBadge,
  getPayloadMutatorBadge,
  getPayloadMasteryBadge,
  formatTime,
  getPayloadSummaryText,
  onApply,
  onValidate,
  onExportJson,
}) {
  container.replaceChildren();
  if (items.length === 0) {
    const empty = document.createElement("span");
    empty.className = "recent-empty";
    empty.textContent = "暂无";
    container.append(empty);
    return;
  }

  for (const item of items) {
    const payload = item.payload || {};
    const row = document.createElement("div");
    row.className = "recent-item";

    const button = document.createElement("button");
    button.type = "button";
    button.className = "recent-main";
    button.innerHTML = `
      <strong>${escapeHtml(getCommanderLabel(payload.commander))} / ${escapeHtml(getMapLabel(payload.map))}</strong>
      <span>${escapeHtml(formatTime(item.savedAt))}</span>
      ${renderRowBadgesHtml([
        { text: getPayloadModeBadge(payload), className: payload.noLaunch ? "status-warn" : "" },
        { text: getPayloadMutatorBadge(payload) },
        { text: `${(payload.genericBonuses || []).length} 加成` },
        { text: getPayloadMasteryBadge(payload) },
      ])}
    `;
    setElementDetail(button, ["最近配置", formatTime(item.savedAt), getPayloadSummaryText(payload)]);
    button.addEventListener("click", () => onApply(payload));

    const validate = document.createElement("button");
    validate.type = "button";
    validate.className = "mini row-submit-action";
    validate.textContent = "验证";
    validate.addEventListener("click", async () => onValidate(payload));

    const json = document.createElement("button");
    json.type = "button";
    json.className = "mini";
    json.textContent = "JSON";
    json.addEventListener("click", () => onExportJson(payload));

    const actions = document.createElement("div");
    actions.className = "row-actions";
    actions.append(validate, json);
    row.append(button, actions);
    container.append(row);
  }
}

export function renderScenarioPresetsPanel({
  container,
  items,
  defaultScenarioName,
  getCommanderLabel,
  getMapLabel,
  getPayloadModeBadge,
  getPayloadMutatorBadge,
  getPayloadMasteryBadge,
  getPayloadSummaryText,
  formatTime,
  onApply,
  onLaunch,
  onValidate,
  onExportJson,
  onRemove,
}) {
  if (!container) return;
  container.replaceChildren();
  if (items.length === 0) {
    const empty = document.createElement("span");
    empty.className = "scenario-empty";
    empty.textContent = "暂无";
    container.append(empty);
    return;
  }

  for (const item of items) {
    const payload = item.payload || {};
    const row = document.createElement("div");
    row.className = "scenario-item";

    const main = document.createElement("button");
    main.type = "button";
    main.className = "scenario-main";
    main.innerHTML = `
      <strong>${escapeHtml(item.name || defaultScenarioName(payload))}</strong>
      <span>${escapeHtml(getCommanderLabel(payload.commander))} · ${escapeHtml(getMapLabel(payload.map))}</span>
      ${renderRowBadgesHtml([
        { text: getPayloadModeBadge(payload), className: payload.noLaunch ? "status-warn" : "" },
        { text: getPayloadMutatorBadge(payload) },
        { text: `${(payload.genericBonuses || []).length} 加成` },
        { text: getPayloadMasteryBadge(payload) },
      ])}
    `;
    setElementDetail(main, ["场景预设", item.name || defaultScenarioName(payload), formatTime(item.savedAt), getPayloadSummaryText(payload)]);
    main.addEventListener("click", () => onApply(item, payload));

    const launch = document.createElement("button");
    launch.type = "button";
    launch.className = "mini row-submit-action";
    launch.textContent = "启动";
    launch.addEventListener("click", async () => onLaunch(payload));

    const validate = document.createElement("button");
    validate.type = "button";
    validate.className = "mini row-submit-action";
    validate.textContent = "验证";
    validate.addEventListener("click", async () => onValidate(payload));

    const json = document.createElement("button");
    json.type = "button";
    json.className = "mini";
    json.textContent = "JSON";
    json.addEventListener("click", () => onExportJson(item, payload));

    const remove = document.createElement("button");
    remove.type = "button";
    remove.className = "mini";
    remove.textContent = "删除";
    remove.addEventListener("click", () => onRemove(item));

    const actions = document.createElement("div");
    actions.className = "row-actions";
    actions.append(launch, validate, json, remove);
    row.append(main, actions);
    container.append(row);
  }
}

export function renderMutatorPresetOptionsPanel({
  selectElement,
  applyButton,
  deleteButton,
  presets,
}) {
  const previous = selectElement.value;
  selectElement.replaceChildren();

  const emptyOption = document.createElement("option");
  emptyOption.value = "";
  emptyOption.textContent = presets.length === 0 ? "暂无组合" : "选择组合";
  selectElement.append(emptyOption);

  for (const preset of presets) {
    const option = document.createElement("option");
    option.value = preset.id;
    option.textContent = `${preset.name} (${preset.mutators.length})`;
    selectElement.append(option);
  }

  if (presets.some((item) => item.id === previous)) {
    selectElement.value = previous;
  }

  const hasSelection = Boolean(selectElement.value);
  applyButton.disabled = !hasSelection;
  deleteButton.disabled = !hasSelection;
}

export function renderLaunchHistoryPanel({
  container,
  items,
  getCommanderLabel,
  getMapLabel,
  formatTime,
  getLaunchHistoryStatusLabel,
  getHistoryStatusClass,
  getPayloadModeBadge,
  getPayloadSummaryText,
  getHistoryLogPaths,
  onApply,
  onShowLogs,
  onValidate,
  onExportJson,
}) {
  if (!container) return;
  container.replaceChildren();
  if (items.length === 0) {
    const empty = document.createElement("span");
    empty.className = "history-empty";
    empty.textContent = "暂无";
    container.append(empty);
    return;
  }

  for (const item of items) {
    const payload = item.payload || {};
    const mutators = payload.mutators || [];
    const genericBonuses = payload.genericBonuses || [];
    const row = document.createElement("div");
    row.className = "history-item";

    const main = document.createElement("button");
    main.type = "button";
    main.className = "history-main";
    main.innerHTML = `
      <strong>${escapeHtml(getCommanderLabel(payload.commander))} / ${escapeHtml(getMapLabel(payload.map))}</strong>
      <span>${escapeHtml(formatTime(item.launchedAt))}</span>
      ${renderRowBadgesHtml([
        { text: getLaunchHistoryStatusLabel(item), className: getHistoryStatusClass(item) },
        { text: getPayloadModeBadge(payload), className: payload.noLaunch ? "status-warn" : "" },
        { text: `${mutators.length} 因子` },
        { text: `${genericBonuses.length} 加成` },
      ])}
    `;
    setElementDetail(main, ["启动历史", getLaunchHistoryStatusLabel(item), formatTime(item.launchedAt), getPayloadSummaryText(payload)]);
    main.addEventListener("click", () => onApply(item, payload));

    const detail = document.createElement("button");
    detail.type = "button";
    detail.className = "mini";
    detail.textContent = "日志";
    const historyLogPaths = getHistoryLogPaths(item.result || {});
    setElementDetail(detail, [
      "日志",
      historyLogPaths.stdout ? `stdout=${historyLogPaths.stdout}` : "",
      historyLogPaths.stderr ? `stderr=${historyLogPaths.stderr}` : "",
    ]);
    detail.addEventListener("click", () => onShowLogs(item, payload, mutators, genericBonuses));

    const validate = document.createElement("button");
    validate.type = "button";
    validate.className = "mini row-submit-action";
    validate.textContent = "验证";
    validate.addEventListener("click", async () => onValidate(payload));

    const json = document.createElement("button");
    json.type = "button";
    json.className = "mini";
    json.textContent = "JSON";
    json.addEventListener("click", () => onExportJson(item, payload));

    const actions = document.createElement("div");
    actions.className = "row-actions";
    actions.append(detail, validate, json);
    row.append(main, actions);
    container.append(row);
  }
}
