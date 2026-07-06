export function renderTestResult(json, container) {
  if (!json.ok) {
    container.innerHTML = `
      <div class="test-result error">
        <h3>测试失败（请求错误）</h3>
        <pre>${escapeHtml(json.error || '未知错误')}</pre>
      </div>`;
    return;
  }

  const data = json.data;
  const cls = data.ok ? 'success' : (data.exitCode === 2 ? 'timeout' : 'error');
  const title = data.ok ? '测试成功' : (data.exitCode === 2 ? '测试超时' : '测试失败');

  const stepsHtml = data.steps ? Object.entries(data.steps).map(([k, v]) => {
    const extra = [];
    if (v.killed !== undefined) extra.push(`killed ${v.killed}`);
    if (v.copied !== undefined) extra.push(`copied ${v.copied}`);
    if (v.exitCode !== undefined) extra.push(`exit ${v.exitCode}`);
    return `<div>${k}: ${v.durationMs}ms${extra.length ? ' (' + extra.join(', ') + ')' : ''}</div>`;
  }).join('') : '';

  const scriptErrorHtml = data.scriptErrorContent
    ? `<h4>ScriptError 内容：</h4><pre>${escapeHtml(data.scriptErrorContent)}</pre>`
    : '';

  container.innerHTML = `
    <div class="test-result ${cls}">
      <h3>${title}</h3>
      <div>PID: ${data.pid ?? 'N/A'} | 总耗时: ${data.durationMs}ms</div>
      <div class="steps">${stepsHtml}</div>
      ${scriptErrorHtml}
    </div>`;
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}
