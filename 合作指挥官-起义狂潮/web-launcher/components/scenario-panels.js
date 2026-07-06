import { renderTestResult } from './test-result-panel.js';

export async function renderScenarioCards() {
  const container = document.getElementById('scenario-cards');
  if (!container) return;

  try {
    const resp = await fetch('/api/bootstrap');
    const json = await resp.json();
    if (!json.ok) throw new Error(json.error);
    const scenarios = json.data.scenariosB || [];

    if (scenarios.length === 0) {
      container.innerHTML = '<div class="scenario-card"><h3>暂无 Mod 测试地图</h3></div>';
      return;
    }

    container.innerHTML = scenarios.map(s => `
      <div class="scenario-card" data-id="${s.id}">
        <h3>${s.displayName}</h3>
        <div class="meta">
          类型: ${s.type} |
          启动: ${s.launchMode} |
          所需 mod: ${(s.requiredMods || []).join(', ') || '无'}
        </div>
        <div class="actions">
          <button class="test-btn" data-id="${s.id}">一键测试</button>
          <button class="sync-btn" data-id="${s.id}">仅同步</button>
        </div>
      </div>
    `).join('');

    container.querySelectorAll('.test-btn').forEach(btn => {
      btn.addEventListener('click', () => runTest(btn.dataset.id));
    });
    container.querySelectorAll('.sync-btn').forEach(btn => {
      btn.addEventListener('click', () => runSync(btn.dataset.id));
    });
  } catch (e) {
    container.innerHTML = `<div class="scenario-card"><div class="error">加载失败: ${e.message}</div></div>`;
  }
}

async function runTest(scenarioId) {
  const panel = document.getElementById('test-result-panel');
  if (!panel) return;
  panel.innerHTML = '<div class="test-result">测试中...</div>';

  try {
    const resp = await fetch(`/api/scenario/${scenarioId}/test`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userSelection: {} }),
    });
    const json = await resp.json();
    renderTestResult(json, panel);
  } catch (e) {
    panel.innerHTML = `<div class="test-result error">请求失败: ${e.message}</div>`;
  }
}

async function runSync(scenarioId) {
  const panel = document.getElementById('test-result-panel');
  if (!panel) return;
  panel.innerHTML = '<div class="test-result">同步中...</div>';

  try {
    const resp = await fetch('/api/sync-all', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ scenarioIds: [scenarioId] }),
    });
    const json = await resp.json();
    if (json.ok) {
      panel.innerHTML = `<div class="test-result success">同步完成: 复制 ${json.data.copied} 项</div>`;
    } else {
      panel.innerHTML = `<div class="test-result error">同步失败: ${json.error}</div>`;
    }
  } catch (e) {
    panel.innerHTML = `<div class="test-result error">请求失败: ${e.message}</div>`;
  }
}
