import { test } from 'node:test';
import assert from 'node:assert';
import {
  buildCompletionFromBanks,
  normalizeBankMapId,
  normalizeCommanderClearKey,
  parseBankXml,
} from '../lib/completion-loader.mjs';

const SAMPLE_BANK = `<?xml version="1.0" encoding="utf-8"?>
<Bank version="1">
  <Section name="MapClear">
    <Key name="Maps/ttosh02_7vs1.SC2Map"><Value int="1"/></Key>
    <Key name="thanson01_7vs1"><Value int="0"/></Key>
  </Section>
  <Section name="Finished">
    <Key name="thanson02_7vs1.SC2Map"><Value int="1"/></Key>
  </Section>
  <Section name="CommanderClear">
    <Key name="Raynor:Maps/ttosh02_7vs1.SC2Map"><Value int="1"/></Key>
    <Key name="Kerrigan:ttosh02_7vs1"><Value int="1"/></Key>
    <Key name="Zagara:ttosh02_7vs1"><Value int="0"/></Key>
  </Section>
  <Section name="Bon">
    <Key name="ttosh02_7vs1.SC2Map"><Value int="2"/></Key>
  </Section>
  <Section name="CommanderBonus">
    <Key name="Raynor:ttosh02_7vs1.SC2Map"><Value int="3"/></Key>
  </Section>
  <Section name="UnlockedBonus">
    <Key name="ChronoBoost"><Value int="1"/></Key>
    <Key name="ZeroSupply"><Value int="0"/></Key>
  </Section>
  <Section name="UnlockedPrestige">
    <Key name="Raynor:ttosh02_7vs1.SC2Map"><Value int="1"/></Key>
  </Section>
  <Section name="Progression">
    <Key name="LastMap"><Value string="Maps/ttosh02_7vs1.SC2Map"/></Key>
    <Key name="LastCommander"><Value string="Raynor"/></Key>
    <Key name="TotalWins"><Value int="7"/></Key>
    <Key name="LastClearTime"><Value int="12345"/></Key>
    <Key name="ObjectiveState/Raynor:ttosh02_7vs1:Bonus:0"><Value int="2"/></Key>
    <Key name="ObjectiveState/Raynor:ttosh02_7vs1:Bonus:1"><Value int="3"/></Key>
    <Key name="ObjectiveState/bad-key"><Value int="2"/></Key>
  </Section>
</Bank>`;

function buildSample() {
  return buildCompletionFromBanks([
    { xmlText: SAMPLE_BANK, path: 'C:/fake/CampaignXCore.SC2Bank', mtime: new Date('2026-01-01T00:00:00Z') },
  ]);
}

test('normalizeBankMapId: 去路径与 .SC2Map 后缀', () => {
  assert.strictEqual(normalizeBankMapId('Maps\\ttosh02_7vs1.SC2Map'), 'ttosh02_7vs1');
  assert.strictEqual(normalizeBankMapId('ttosh02_7vs1'), 'ttosh02_7vs1');
  assert.strictEqual(normalizeBankMapId(''), '');
});

test('normalizeCommanderClearKey: Commander:MapId 规范化', () => {
  assert.strictEqual(normalizeCommanderClearKey('Raynor:Maps/ttosh02_7vs1.SC2Map'), 'Raynor:ttosh02_7vs1');
  assert.strictEqual(normalizeCommanderClearKey('NoSeparator'), 'NoSeparator');
});

test('parseBankXml: 同时提取 int 与 string 值', () => {
  const sections = parseBankXml(SAMPLE_BANK);
  assert.strictEqual(sections.get('Progression').get('LastMap').string, 'Maps/ttosh02_7vs1.SC2Map');
  assert.strictEqual(sections.get('Progression').get('TotalWins').int, 7);
  assert.strictEqual(sections.get('MapClear').get('thanson01_7vs1').int, 0);
});

test('buildCompletionFromBanks: 空列表返回 bankFound=false 且积分为 0', () => {
  const completion = buildCompletionFromBanks([]);
  assert.strictEqual(completion.bankFound, false);
  assert.strictEqual(completion.pointLedger.earnedPoints, 0);
  assert.deepStrictEqual(completion.mapBonusScores, []);
});

test('buildCompletionFromBanks: mapClearIds 来自 MapClear+Finished 且过滤 0 值', () => {
  const completion = buildSample();
  assert.deepStrictEqual(completion.mapClearIds, ['thanson02_7vs1', 'ttosh02_7vs1']);
});

test('buildCompletionFromBanks: commanderClearKeys 来自 CommanderClear 并规范化', () => {
  const completion = buildSample();
  assert.deepStrictEqual(completion.commanderClearKeys, ['Kerrigan:ttosh02_7vs1', 'Raynor:ttosh02_7vs1']);
});

test('buildCompletionFromBanks: 奖励分条目形态为 {mapId,bonusScore} / {commander,mapId,bonusScore}', () => {
  const completion = buildSample();
  assert.deepStrictEqual(completion.mapBonusScores, [{ mapId: 'ttosh02_7vs1', bonusScore: 2 }]);
  assert.deepStrictEqual(completion.commanderBonusScores, [{
    key: 'Raynor:ttosh02_7vs1',
    commander: 'Raynor',
    mapId: 'ttosh02_7vs1',
    bonusScore: 3,
  }]);
});

test('buildCompletionFromBanks: objectiveStates 来自 Progression 的 ObjectiveState/* 键', () => {
  const completion = buildSample();
  assert.strictEqual(completion.objectiveStates.length, 2);
  const first = completion.objectiveStates[0];
  assert.strictEqual(first.commander, 'Raynor');
  assert.strictEqual(first.mapId, 'ttosh02_7vs1');
  assert.strictEqual(first.objectiveType, 'Bonus');
  assert.strictEqual(first.state, 2);
});

test('buildCompletionFromBanks: 解锁列表过滤 0 值并规范化威望键', () => {
  const completion = buildSample();
  assert.deepStrictEqual(completion.unlockedBonuses, ['ChronoBoost']);
  assert.deepStrictEqual(completion.unlockedPrestiges, ['Raynor:ttosh02_7vs1']);
});

test('buildCompletionFromBanks: 积分账本按指挥官通关数计首通、奖励取 max(奖励分合计, 完成目标数)', () => {
  const completion = buildSample();
  const ledger = completion.pointLedger;
  // 2 个指挥官通关 * 3 分
  assert.strictEqual(ledger.firstClearCount, 2);
  assert.strictEqual(ledger.firstClearPoints, 6);
  // commanderBonus 合计 3 vs state==2 目标 1 个 → 取 3
  assert.strictEqual(ledger.bonusObjectiveCount, 3);
  assert.strictEqual(ledger.bonusObjectivePoints, 3);
  assert.strictEqual(ledger.earnedPoints, 9);
  assert.strictEqual(ledger.objectiveStateSource, 'ObjectiveState');
});

test('buildCompletionFromBanks: progression 来自最新 bank，聚合数据跨 bank 合并', () => {
  const olderBank = `<Bank><Section name="Progression">
    <Key name="LastMap"><Value string="old_map.SC2Map"/></Key>
    <Key name="TotalWins"><Value int="3"/></Key>
  </Section>
  <Section name="CommanderClear">
    <Key name="Nova:told01_7vs1"><Value int="1"/></Key>
  </Section></Bank>`;
  const completion = buildCompletionFromBanks([
    { xmlText: olderBank, path: 'C:/fake/old.SC2Bank', mtime: new Date('2020-01-01T00:00:00Z') },
    { xmlText: SAMPLE_BANK, path: 'C:/fake/new.SC2Bank', mtime: new Date('2026-01-01T00:00:00Z') },
  ]);
  assert.strictEqual(completion.bankPath, 'C:/fake/new.SC2Bank');
  assert.strictEqual(completion.lastMap, 'ttosh02_7vs1');
  assert.ok(completion.commanderClearKeys.includes('Nova:told01_7vs1'));
  assert.strictEqual(completion.pointLedger.firstClearCount, 3);
});
