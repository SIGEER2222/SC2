import { escapeHtml, initials } from "../lib/ui-helpers.js";

export function renderMutatorGrid({
  container,
  mutators,
  selectedMutatorIds,
  getMutatorCategoryLabel,
  getMutatorTierLabel,
  onToggleMutator,
}) {
  container.replaceChildren();

  if (mutators.length === 0) {
    const empty = document.createElement("div");
    empty.className = "empty-state";
    empty.textContent = "没有匹配的因子";
    container.append(empty);
    return;
  }

  for (const mutator of mutators) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `mutator-card${selectedMutatorIds.has(mutator.id) ? " selected" : ""}`;
    button.title = mutator.icon || mutator.id;
    const imageToneClass = mutator.imageSource === "icon-exact"
      ? "status-ok"
      : mutator.imageSource === "icon-fallback"
        ? "status-warn"
        : "";
    const art = mutator.image
      ? `<img src="${escapeHtml(mutator.image)}" alt="${escapeHtml(mutator.name || mutator.id)}">`
      : escapeHtml(initials(mutator.name || mutator.id));
    button.innerHTML = `
      <span class="mutator-icon">${art}</span>
      <span>
        <span class="mutator-title">${escapeHtml(mutator.name || mutator.id)}</span>
        <span class="mutator-id">${escapeHtml(mutator.id)}</span>
        <span class="mutator-tags">
          <em>${escapeHtml(getMutatorCategoryLabel(mutator.category || "other"))}</em>
          <em>${escapeHtml(getMutatorTierLabel(mutator.tier || "normal"))}</em>
        </span>
      </span>
      <span class="mutator-art-status">
        <em class="${imageToneClass}">${escapeHtml(mutator.imageSourceLabel || "未标记")}</em>
      </span>
      <span class="mutator-desc">${escapeHtml(mutator.description || mutator.icon || "")}</span>
    `;
    button.addEventListener("click", () => {
      onToggleMutator(mutator.id);
    });
    container.append(button);
  }
}

export function renderSelectedMutatorPanel({
  container,
  statusElement,
  searchElement,
  clearMatchedButton,
  toggleButton,
  selectedMutatorIds,
  matchedMutators,
  query,
  expanded,
  onRemoveMutator,
}) {
  container.replaceChildren();

  container.classList.toggle("collapsed", !expanded);
  statusElement.textContent = selectedMutatorIds.size === 0
    ? "未选择因子"
    : query
      ? `匹配 ${matchedMutators.length}/${selectedMutatorIds.size}`
      : `已选 ${selectedMutatorIds.size}`;
  searchElement.disabled = selectedMutatorIds.size === 0;
  clearMatchedButton.disabled = !query || matchedMutators.length === 0;
  toggleButton.disabled = selectedMutatorIds.size <= 8 && !query;
  toggleButton.textContent = expanded ? "收起" : "展开";

  if (selectedMutatorIds.size === 0) {
    const empty = document.createElement("span");
    empty.className = "selected-empty";
    empty.textContent = "未选择因子";
    container.append(empty);
    return;
  }

  if (matchedMutators.length === 0) {
    const empty = document.createElement("span");
    empty.className = "selected-empty";
    empty.textContent = "已选因子中没有匹配项";
    container.append(empty);
    return;
  }

  for (const { id, mutator } of matchedMutators) {
    const chip = document.createElement("button");
    chip.type = "button";
    chip.className = "mutator-chip";
    chip.title = id;
    chip.innerHTML = `<span>${escapeHtml(mutator?.name ?? id)}</span><strong>×</strong>`;
    chip.addEventListener("click", () => {
      onRemoveMutator(id);
    });
    container.append(chip);
  }
}
