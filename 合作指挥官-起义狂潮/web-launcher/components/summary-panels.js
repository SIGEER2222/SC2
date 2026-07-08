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
  talentSummary,
  scoreSummaryText,
}) {
  selectionSummaryElement.textContent = `${commanderLabel} / ${mapLabel} / ${mutatorCount} 因子 / ${genericBonusCount} 加成 / ${commanderOverrideCount} 升级`;
  summaryCommanderElement.textContent = commanderLabel;
  summaryMapElement.textContent = mapLabel;
  summaryMasteryElement.textContent = `天赋 开关${talentSummary?.activeSwitchCount ?? 0}/等级${talentSummary?.totalLevel ?? 0}`;
  summaryMutatorsElement.textContent = `${mutatorCount} / ${genericBonusCount}`;
  summaryPointsElement.textContent = scoreSummaryText;
  prestigeFusionStatusElement.textContent = `天赋 开关${talentSummary?.activeSwitchCount ?? 0}项 / 等级合计${talentSummary?.totalLevel ?? 0}`;
  prestigeFusionStatusElement.classList.toggle("status-ok", (talentSummary?.activeSwitchCount ?? 0) > 0 || (talentSummary?.totalLevel ?? 0) > 0);
  prestigeFusionStatusElement.classList.toggle("status-warn", (talentSummary?.activeSwitchCount ?? 0) === 0 && (talentSummary?.totalLevel ?? 0) === 0);
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
  talentSummary,
  mutatorCount,
  genericBonusCount,
  mutatorPreset,
  mutatorIdsText,
  genericBonusLabels,
  modeLabel,
  overrideLabels,
}) {
  setElementDetail(summaryCommanderElement, ["指挥官", commanderLabel, commanderId]);
  setElementDetail(summaryMapElement, ["地图", mapLabel, mapId]);
  setElementDetail(
    summaryMasteryElement,
    ["天赋", `开关 ${talentSummary?.activeSwitchCount ?? 0} 项`, `等级合计=${talentSummary?.totalLevel ?? 0}；明细=[${(talentSummary?.levelValues || []).join(",")}]；已激活=${(talentSummary?.activeNames || []).join("、") || "无"}`],
  );
  setElementDetail(
    summaryMutatorsElement,
    ["因子", `${mutatorCount} 个 / ${genericBonusCount} 加成`, `预设=${mutatorPreset}；ID=${mutatorIdsText}；加成=${genericBonusLabels.join("、") || "无"}`],
  );
  setElementDetail(
    summaryModeElement,
    ["模式", modeLabel, `额外=${overrideLabels.join("、") || "无"}；通用=${genericBonusLabels.join("、") || "无"}；天赋开关=${talentSummary?.activeSwitchCount ?? 0}；天赋等级=${talentSummary?.totalLevel ?? 0}`],
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
