import { setElementDetail } from "../lib/ui-helpers.js";

export function updateSummaryPanel({
  selectionSummaryElement,
  summaryCommanderElement,
  summaryMapElement,
  summaryMasteryElement,
  summaryMutatorsElement,
  summaryPointsElement,
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
  scoreSummaryText,
}) {
  selectionSummaryElement.textContent = `${commanderLabel} / ${mapLabel} / ${mutatorCount} 因子 / ${genericBonusCount} 加成 / ${commanderOverrideCount} 升级`;
  summaryCommanderElement.textContent = commanderLabel;
  summaryMapElement.textContent = mapLabel;
  summaryMasteryElement.textContent = `${masteryLevel} / ${masteryValues.join(",")}`;
  summaryMutatorsElement.textContent = `${mutatorCount} / ${genericBonusCount}`;
  summaryPointsElement.textContent = scoreSummaryText;
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
  scoreStatusElement,
  resourcePlanElement,
  commanderCount,
  mapCount,
  mutatorCount,
  completion,
  completionStatusText,
  scoreStatusText,
  resourcePlanText,
}) {
  commanderCountElement.textContent = String(commanderCount);
  mapCountElement.textContent = String(mapCount);
  mutatorCountElement.textContent = String(mutatorCount);
  completionStatusElement.textContent = completionStatusText;
  completionStatusElement.title = completion.bankPath || "";
  scoreStatusElement.textContent = scoreStatusText;
  scoreStatusElement.title = `积分来源：${completion.pointLedger?.objectiveStateSource || "CommanderBonus"}`;
  resourcePlanElement.textContent = resourcePlanText;
}

export function updateMasteryPairStatusPanel({ element, pairSums }) {
  element.classList.remove("status-error");
  element.classList.add("status-ok");
  element.textContent = pairSums.map((item) => `C${item.category}:${item.total}`).join(" / ");
}

export function updateScorePanel({
  budgetBadgeElement,
  availablePointsElement,
  mutatorPointsElement,
  bonusCostElement,
  balanceAfterElement,
  commanderProgressElement,
  detailElement,
  ruleElement,
  earnedPoints,
  mutatorPoints,
  bonusCost,
  balanceAfter,
  commanderProgressText,
  detailText,
  ruleText,
}) {
  const affordable = balanceAfter >= 0;
  budgetBadgeElement.className = `badge ${affordable ? "status-ok" : "status-error"}`;
  budgetBadgeElement.textContent = affordable ? "积分可用" : "积分不足";
  availablePointsElement.textContent = String(earnedPoints);
  mutatorPointsElement.textContent = `+${mutatorPoints}`;
  bonusCostElement.textContent = `-${bonusCost}`;
  balanceAfterElement.textContent = String(balanceAfter);
  commanderProgressElement.textContent = commanderProgressText;
  detailElement.className = `config-issues ${affordable ? "status-ok" : "status-error"}`;
  detailElement.textContent = detailText;
  ruleElement.textContent = ruleText;
}
