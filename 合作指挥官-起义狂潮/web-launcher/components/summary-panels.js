import { setElementDetail } from "../lib/ui-helpers.js";

export function updateSummaryPanel({
  selectionSummaryElement,
  summaryCommanderElement,
  summaryMapElement,
  summaryMasteryElement,
  summaryMutatorsElement,
  prestigeFusionStatusElement,
  copySummaryButton,
  commanderLabel,
  mapLabel,
  mutatorCount,
  genericBonusCount,
  commanderOverrideCount,
  masteryLevel,
  masteryValues,
  prestigeMaskMode,
  selectedPrestigeCount,
  prestigeBonusMask,
  enablePrestiges,
}) {
  selectionSummaryElement.textContent = `${commanderLabel} / ${mapLabel} / ${mutatorCount} 因子 / ${genericBonusCount} 加成 / ${commanderOverrideCount} 升级`;
  summaryCommanderElement.textContent = commanderLabel;
  summaryMapElement.textContent = mapLabel;
  summaryMasteryElement.textContent = `${masteryLevel} / ${masteryValues.join(",")}`;
  summaryMutatorsElement.textContent = `${mutatorCount} / ${genericBonusCount}`;
  prestigeFusionStatusElement.textContent = enablePrestiges
    ? `${prestigeMaskMode === "default" ? "默认整合" : "手动拆分"} / ${selectedPrestigeCount} 项 / mask ${prestigeBonusMask}`
    : "融合关闭";
  prestigeFusionStatusElement.classList.toggle("status-ok", enablePrestiges && prestigeBonusMask > 0);
  prestigeFusionStatusElement.classList.toggle("status-warn", !enablePrestiges || prestigeBonusMask === 0);
  copySummaryButton.disabled = false;
}

export function updateSummaryDetailPanel({
  summaryCommanderElement,
  summaryMapElement,
  summaryMasteryElement,
  summaryMutatorsElement,
  summaryModeElement,
  commanderLabel,
  commanderId,
  mapLabel,
  mapId,
  masteryLevel,
  masteryValues,
  enableMasteries,
  mutatorCount,
  genericBonusCount,
  mutatorPreset,
  mutatorIdsText,
  genericBonusLabels,
  modeLabel,
  prestigeProfileLabel,
  prestigeBonusMask,
  prestigeNames,
  overrideLabels,
}) {
  setElementDetail(summaryCommanderElement, ["指挥官", commanderLabel, commanderId]);
  setElementDetail(summaryMapElement, ["地图", mapLabel, mapId]);
  setElementDetail(
    summaryMasteryElement,
    ["精通", `等级 ${masteryLevel}`, `启用=${enableMasteries ? "是" : "否"}；加点=[${masteryValues.join(",")}]`],
  );
  setElementDetail(
    summaryMutatorsElement,
    ["因子", `${mutatorCount} 个 / ${genericBonusCount} 加成`, `preset=${mutatorPreset}；ids=${mutatorIdsText}；加成=${genericBonusLabels.join("、") || "无"}`],
  );
  setElementDetail(
    summaryModeElement,
    ["模式", modeLabel, `融合=${prestigeProfileLabel}；mask=${prestigeBonusMask}；项=${prestigeNames.join("、") || "无"}；额外=${overrideLabels.join("、") || "无"}；通用=${genericBonusLabels.join("、") || "无"}；point=-1`],
  );
}

export function updateBootstrapStripPanel({
  commanderCountElement,
  mapCountElement,
  mutatorCountElement,
  completionStatusElement,
  resourcePlanElement,
  commanderCount,
  mapCount,
  mutatorCount,
  completion,
  completionStatusText,
  resourcePlanText,
}) {
  commanderCountElement.textContent = String(commanderCount);
  mapCountElement.textContent = String(mapCount);
  mutatorCountElement.textContent = String(mutatorCount);
  completionStatusElement.textContent = completionStatusText;
  completionStatusElement.title = completion.bankPath || "";
  resourcePlanElement.textContent = resourcePlanText;
}

export function updateMasteryPairStatusPanel({ element, pairSums }) {
  element.classList.remove("status-error");
  element.classList.add("status-ok");
  element.textContent = pairSums.map((item) => `C${item.category}:${item.total}`).join(" / ");
}
