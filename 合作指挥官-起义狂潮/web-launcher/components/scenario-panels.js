import { renderTestResult } from './test-result-panel.js';
import { escapeHtml } from '../lib/ui-helpers.js';

export async function renderScenarioCards() {
  const container = document.getElementById('scenario-cards');
  if (!container) return;

  try {
    const resp = await fetch('/api/bootstrap');
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    const json = await resp.json();
    // /api/bootstrap 返回平铺对象（无 ok/data 包装），仅显式 ok:false 视为错误
    if (json.ok === false) throw new Error(json.error || 'bootstrap 返回错误');
    const scenarios = json.scenariosB || [];

    if (scenarios.length === 0) {
      container.innerHTML = '<div class="scenario-card"><h3>暂无 Mod 测试地图</h3></div>';
      return;
    }

    container.innerHTML = scenarios.map(s => `
      <div class="scenario-card" data-id="${escapeHtml(s.id)}">
        <h3>${escapeHtml(s.displayName)}</h3>
        <div class="meta">
          类型: ${escapeHtml(s.type)} |
          启动: ${escapeHtml(s.launchMode)} |
          所需 mod: ${escapeHtml((s.requiredMods || []).join(', ') || '无')}
        </div>
        <div class="actions">
          <button class="test-btn" data-id="${escapeHtml(s.id)}">一键测试</button>
          <button class="sync-btn" data-id="${escapeHtml(s.id)}">仅同步</button>
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
    container.innerHTML = `<div class="scenario-card"><div class="error">加载失败: ${escapeHtml(e.message)}</div></div>`;
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
    panel.innerHTML = `<div class="test-result error">请求失败: ${escapeHtml(e.message)}</div>`;
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
      panel.innerHTML = `<div class="test-result success">同步完成: 复制 ${Number(json.data?.copied) || 0} 项</div>`;
    } else {
      panel.innerHTML = `<div class="test-result error">同步失败: ${escapeHtml(json.error || '未知错误')}</div>`;
    }
  } catch (e) {
    panel.innerHTML = `<div class="test-result error">请求失败: ${escapeHtml(e.message)}</div>`;
  }
}
