import { renderTestResult } from './test-result-panel.js';
import { escapeHtml } from '../lib/ui-helpers.js';

const modtestState = {
  scenarios: [],
  search: '',
  typeFilter: 'all',
  lastResult: null,
  running: false,
};

const el = {
  status: null,
  refreshButton: null,
  syncAllButton: null,
  stopSc2Button: null,
  scenarioCount: null,
  modCount: null,
  mapCount: null,
  filterSummary: null,
  issues: null,
  lastResult: null,
  visibleCount: null,
  search: null,
  typeFilter: null,
  clearFilters: null,
  cards: null,
  resultHost: null,
  outputLog: null,
  copyOutputButton: null,
  clearOutputButton: null,
  launchState: null,
  bootstrapScenarioCount: null,
  bootstrapModCount: null,
  bootstrapMapCount: null,
};

function bindElements() {
  el.status = document.getElementById('modtestStatus');
  el.refreshButton = document.getElementById('modtestRefreshButton');
  el.syncAllButton = document.getElementById('modtestSyncAllButton');
  el.stopSc2Button = document.getElementById('modtestStopSc2Button');
  el.scenarioCount = document.getElementById('modtestScenarioCount');
  el.modCount = document.getElementById('modtestModCount');
  el.mapCount = document.getElementById('modtestMapCount');
  el.filterSummary = document.getElementById('modtestFilterSummary');
  el.issues = document.getElementById('modtestIssues');
  el.lastResult = document.getElementById('modtestLastResult');
  el.visibleCount = document.getElementById('modtestVisibleCount');
  el.search = document.getElementById('modtestSearch');
  el.typeFilter = document.getElementById('modtestTypeFilter');
  el.clearFilters = document.getElementById('modtestClearFilters');
  el.cards = document.getElementById('scenario-cards');
  el.resultHost = document.getElementById('test-result-panel');
  el.outputLog = document.getElementById('modtestOutputLog');
  el.copyOutputButton = document.getElementById('modtestCopyOutputButton');
  el.clearOutputButton = document.getElementById('modtestClearOutputButton');
  el.launchState = document.getElementById('modtestLaunchState');
  el.bootstrapScenarioCount = document.getElementById('modtestBootstrapScenarioCount');
  el.bootstrapModCount = document.getElementById('modtestBootstrapModCount');
  el.bootstrapMapCount = document.getElementById('modtestBootstrapMapCount');
}

let wired = false;

function wireEvents() {
  if (wired) return;
  wired = true;
  bindElements();
  if (!el.cards) return;

  el.refreshButton?.addEventListener('click', () => loadModtestScenarios(true));
  el.syncAllButton?.addEventListener('click', runSyncAll);
  el.stopSc2Button?.addEventListener('click', runStopSc2);
  el.search?.addEventListener('input', () => {
    modtestState.search = el.search.value.trim().toLowerCase();
    renderScenarioCards();
  });
  el.typeFilter?.addEventListener('change', () => {
    modtestState.typeFilter = el.typeFilter.value;
    renderScenarioCards();
  });
  el.clearFilters?.addEventListener('click', () => {
    modtestState.search = '';
    modtestState.typeFilter = 'all';
    if (el.search) el.search.value = '';
    if (el.typeFilter) el.typeFilter.value = 'all';
    renderScenarioCards();
  });
  el.copyOutputButton?.addEventListener('click', copyModtestOutput);
  el.clearOutputButton?.addEventListener('click', clearModtestOutput);
}

function collectScenarioStats(scenarios) {
  const modNames = new Set();
  const mapPaths = new Set();
  for (const scenario of scenarios) {
    for (const mod of scenario.requiredMods || []) modNames.add(mod);
    if (scenario.mapPath) mapPaths.add(scenario.mapPath);
  }
  return {
    modCount: modNames.size,
    mapCount: mapPaths.size,
    modNames: [...modNames],
    mapPaths: [...mapPaths],
  };
}

function updateSummary(scenarios) {
  const stats = collectScenarioStats(scenarios);
  const filtered = getFilteredScenarios();

  if (el.scenarioCount) el.scenarioCount.textContent = String(scenarios.length);
  if (el.modCount) el.modCount.textContent = String(stats.modCount);
  if (el.mapCount) el.mapCount.textContent = String(stats.mapCount);
  if (el.visibleCount) el.visibleCount.textContent = String(filtered.length);
  if (el.bootstrapScenarioCount) el.bootstrapScenarioCount.textContent = String(scenarios.length);
  if (el.bootstrapModCount) el.bootstrapModCount.textContent = String(stats.modCount);
  if (el.bootstrapMapCount) el.bootstrapMapCount.textContent = String(stats.mapCount);
  if (el.syncAllButton) el.syncAllButton.disabled = scenarios.length === 0 || modtestState.running;

  const filterParts = [];
  if (modtestState.search) filterParts.push(`搜索 "${modtestState.search}"`);
  if (modtestState.typeFilter !== 'all') filterParts.push(`类型 ${modtestState.typeFilter}`);
  if (el.filterSummary) {
    el.filterSummary.textContent = filterParts.length > 0 ? filterParts.join(' · ') : '全部';
  }

  if (el.issues) {
    if (scenarios.length === 0) {
      el.issues.textContent = '暂无 Mod 测试场景，请检查 maps.json';
      el.issues.className = 'config-issues status-warn';
    } else if (filtered.length === 0) {
      el.issues.textContent = '当前筛选无匹配场景';
      el.issues.className = 'config-issues status-warn';
    } else {
      el.issues.textContent = `共 ${scenarios.length} 个场景，当前显示 ${filtered.length} 个`;
      el.issues.className = 'config-issues status-ok';
    }
  }

  if (el.status && scenarios.length > 0) {
    el.status.textContent = `已加载 ${scenarios.length} 个 Mod 测试场景`;
  }
}

function getFilteredScenarios() {
  return modtestState.scenarios.filter((scenario) => {
    if (modtestState.typeFilter !== 'all' && scenario.type !== modtestState.typeFilter) {
      return false;
    }
    if (!modtestState.search) return true;
    const haystack = [
      scenario.id,
      scenario.displayName,
      scenario.type,
      scenario.launchMode,
      scenario.mapPath,
      ...(scenario.requiredMods || []),
    ].join(' ').toLowerCase();
    return haystack.includes(modtestState.search);
  });
}

function renderScenarioCard(scenario) {
  const mods = scenario.requiredMods || [];
  const modBadges = mods.length > 0
    ? mods.map((mod) => `<em>${escapeHtml(mod)}</em>`).join('')
    : '<em class="muted-badge">无依赖 mod</em>';

  return `
    <article class="scenario-card" data-id="${escapeHtml(scenario.id)}">
      <div class="scenario-card-head">
        <h3>${escapeHtml(scenario.displayName || scenario.id)}</h3>
        <span class="badge">${escapeHtml(scenario.type || 'modtest')}</span>
      </div>
      <div class="meta">
        <div><strong>ID</strong> ${escapeHtml(scenario.id)}</div>
        <div><strong>地图</strong> ${escapeHtml(scenario.mapPath || '-')}</div>
        <div><strong>启动</strong> ${escapeHtml(scenario.launchMode || '-')}</div>
      </div>
      <div class="scenario-mod-badges">${modBadges}</div>
      <div class="actions">
        <button type="button" class="primary test-btn" data-id="${escapeHtml(scenario.id)}" ${modtestState.running ? 'disabled' : ''}>一键测试</button>
        <button type="button" class="secondary sync-btn" data-id="${escapeHtml(scenario.id)}" ${modtestState.running ? 'disabled' : ''}>仅同步</button>
      </div>
    </article>
  `;
}

function renderScenarioCards() {
  if (!el.cards) return;
  const filtered = getFilteredScenarios();
  updateSummary(modtestState.scenarios);

  if (filtered.length === 0) {
    el.cards.innerHTML = '<div class="scenario-card empty-card"><h3>没有匹配的场景</h3></div>';
    return;
  }

  el.cards.innerHTML = filtered.map(renderScenarioCard).join('');

  el.cards.querySelectorAll('.test-btn').forEach((btn) => {
    btn.addEventListener('click', () => runTest(btn.dataset.id));
  });
  el.cards.querySelectorAll('.sync-btn').forEach((btn) => {
    btn.addEventListener('click', () => runSync(btn.dataset.id));
  });
}

async function copyText(value) {
  try {
    await navigator.clipboard.writeText(value);
  } catch {
    const textArea = document.createElement('textarea');
    textArea.value = value;
    document.body.append(textArea);
    textArea.select();
    document.execCommand('copy');
    textArea.remove();
  }
}

function appendOutput(text) {
  if (!el.outputLog) return;
  const current = el.outputLog.textContent.trim();
  const next = current === '等待操作' ? text : `${current}\n${text}`;
  el.outputLog.textContent = next;
  if (el.copyOutputButton) el.copyOutputButton.disabled = false;
}

function setLaunchState(text, tone = '') {
  if (!el.launchState) return;
  el.launchState.textContent = text;
  el.launchState.className = tone ? `badge ${tone}` : 'badge';
}

function setLastResultBadge(ok, title) {
  if (!el.lastResult) return;
  el.lastResult.textContent = title;
  el.lastResult.className = ok ? 'badge status-ok' : 'badge status-error';
}

async function copyModtestOutput() {
  const parts = [];
  if (el.resultHost?.textContent.trim()) parts.push(el.resultHost.textContent.trim());
  if (el.outputLog?.textContent.trim() && el.outputLog.textContent.trim() !== '等待操作') {
    parts.push(el.outputLog.textContent.trim());
  }
  if (parts.length === 0) return;
  await copyText(parts.join('\n\n'));
  setLaunchState('输出已复制', 'status-ok');
}

function clearModtestOutput() {
  if (el.resultHost) el.resultHost.replaceChildren();
  if (el.outputLog) el.outputLog.textContent = '等待操作';
  if (el.copyOutputButton) el.copyOutputButton.disabled = true;
  setLaunchState('输出已清空');
}

function setRunning(running) {
  modtestState.running = running;
  if (el.syncAllButton) el.syncAllButton.disabled = running || modtestState.scenarios.length === 0;
  renderScenarioCards();
}

export async function initModtestTab() {
  wireEvents();
  await loadModtestScenarios(false);
}

export async function loadModtestScenarios(force = false) {
  wireEvents();
  if (!el.cards) return;

  if (el.status) el.status.textContent = '加载中';
  if (force) clearModtestOutput();

  try {
    const resp = await fetch('/api/bootstrap');
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    const json = await resp.json();
    if (json.ok === false) throw new Error(json.error || 'bootstrap 返回错误');

    modtestState.scenarios = json.scenariosB || [];
    renderScenarioCards();

    if (el.status) {
      el.status.textContent = modtestState.scenarios.length > 0
        ? `已加载 ${modtestState.scenarios.length} 个 Mod 测试场景`
        : '暂无 Mod 测试场景';
    }
  } catch (e) {
    if (el.status) el.status.textContent = `加载失败: ${e.message}`;
    if (el.cards) {
      el.cards.innerHTML = `<div class="scenario-card"><div class="error">加载失败: ${escapeHtml(e.message)}</div></div>`;
    }
    if (el.issues) {
      el.issues.textContent = `加载失败: ${e.message}`;
      el.issues.className = 'config-issues status-error';
    }
  }
}

async function runStopSc2() {
  setRunning(true);
  setLaunchState('停止 SC2...');
  appendOutput('[stop] 正在停止 SC2 进程...');
  try {
    const resp = await fetch('/api/stop-sc2', { method: 'POST' });
    const json = await resp.json();
    if (json.ok) {
      const killed = Number(json.data?.killed) || 0;
      appendOutput(`[stop] 完成，结束 ${killed} 个进程`);
      setLaunchState(`已停止 ${killed} 个进程`, 'status-ok');
    } else {
      appendOutput(`[stop] 失败: ${json.error || '未知错误'}`);
      setLaunchState('停止失败', 'status-error');
    }
  } catch (e) {
    appendOutput(`[stop] 请求失败: ${e.message}`);
    setLaunchState('停止失败', 'status-error');
  } finally {
    setRunning(false);
  }
}

async function runSyncAll() {
  const ids = modtestState.scenarios.map((s) => s.id);
  if (ids.length === 0) return;
  setRunning(true);
  setLaunchState('同步全部...');
  appendOutput(`[sync-all] 开始同步 ${ids.length} 个场景`);
  if (el.resultHost) {
    el.resultHost.innerHTML = '<div class="test-result">同步全部 mod 与地图...</div>';
  }
  try {
    const resp = await fetch('/api/sync-all', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ scenarioIds: ids }),
    });
    const json = await resp.json();
    if (json.ok) {
      const copied = Number(json.data?.copied) || 0;
      appendOutput(`[sync-all] 完成，复制 ${copied} 项`);
      if (el.resultHost) {
        el.resultHost.innerHTML = `<div class="test-result success"><h3>同步完成</h3><div>复制 ${copied} 项</div></div>`;
      }
      setLastResultBadge(true, '同步成功');
      setLaunchState('同步完成', 'status-ok');
    } else {
      appendOutput(`[sync-all] 失败: ${json.error || '未知错误'}`);
      if (el.resultHost) {
        el.resultHost.innerHTML = `<div class="test-result error"><h3>同步失败</h3><pre>${escapeHtml(json.error || '未知错误')}</pre></div>`;
      }
      setLastResultBadge(false, '同步失败');
      setLaunchState('同步失败', 'status-error');
    }
  } catch (e) {
    appendOutput(`[sync-all] 请求失败: ${e.message}`);
    if (el.resultHost) {
      el.resultHost.innerHTML = `<div class="test-result error"><h3>请求失败</h3><pre>${escapeHtml(e.message)}</pre></div>`;
    }
    setLastResultBadge(false, '同步失败');
    setLaunchState('同步失败', 'status-error');
  } finally {
    setRunning(false);
  }
}

async function runTest(scenarioId) {
  if (!el.resultHost) return;
  setRunning(true);
  setLaunchState('测试中...');
  appendOutput(`[test] 开始测试场景 ${scenarioId}`);
  el.resultHost.innerHTML = '<div class="test-result">测试中...</div>';

  try {
    const resp = await fetch(`/api/scenario/${scenarioId}/test`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userSelection: {} }),
    });
    const json = await resp.json();
    renderTestResult(json, el.resultHost);

    const data = json.data || {};
    const ok = Boolean(json.ok && data.ok);
    const title = ok ? '测试成功' : (data.ok === false ? '测试失败' : '请求错误');
    setLastResultBadge(ok, title);
    appendOutput(`[test] ${scenarioId}: ${title} (exit ${data.exitCode ?? 'N/A'}, ${data.durationMs ?? '-'}ms)`);
    setLaunchState(title, ok ? 'status-ok' : 'status-error');
    modtestState.lastResult = { scenarioId, ok, data };
  } catch (e) {
    el.resultHost.innerHTML = `<div class="test-result error">请求失败: ${escapeHtml(e.message)}</div>`;
    setLastResultBadge(false, '请求失败');
    appendOutput(`[test] ${scenarioId}: 请求失败 ${e.message}`);
    setLaunchState('请求失败', 'status-error');
  } finally {
    setRunning(false);
  }
}

async function runSync(scenarioId) {
  if (!el.resultHost) return;
  setRunning(true);
  setLaunchState('同步中...');
  appendOutput(`[sync] 开始同步场景 ${scenarioId}`);
  el.resultHost.innerHTML = '<div class="test-result">同步中...</div>';

  try {
    const resp = await fetch('/api/sync-all', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ scenarioIds: [scenarioId] }),
    });
    const json = await resp.json();
    if (json.ok) {
      const copied = Number(json.data?.copied) || 0;
      el.resultHost.innerHTML = `<div class="test-result success"><h3>同步完成</h3><div>复制 ${copied} 项</div></div>`;
      appendOutput(`[sync] ${scenarioId}: 复制 ${copied} 项`);
      setLastResultBadge(true, '同步成功');
      setLaunchState('同步完成', 'status-ok');
    } else {
      el.resultHost.innerHTML = `<div class="test-result error"><h3>同步失败</h3><pre>${escapeHtml(json.error || '未知错误')}</pre></div>`;
      appendOutput(`[sync] ${scenarioId}: 失败 ${json.error || '未知错误'}`);
      setLastResultBadge(false, '同步失败');
      setLaunchState('同步失败', 'status-error');
    }
  } catch (e) {
    el.resultHost.innerHTML = `<div class="test-result error">请求失败: ${escapeHtml(e.message)}</div>`;
    appendOutput(`[sync] ${scenarioId}: 请求失败 ${e.message}`);
    setLaunchState('请求失败', 'status-error');
  } finally {
    setRunning(false);
  }
}

// 兼容旧调用名
export { initModtestTab as renderScenarioCards };
