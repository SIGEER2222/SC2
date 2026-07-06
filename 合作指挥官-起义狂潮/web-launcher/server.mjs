import express from 'express';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import { bootstrapRouter } from './routes/bootstrap.mjs';
import { syncRouter } from './routes/sync.mjs';
import { scenarioRouter } from './routes/scenario.mjs';

// 进程级保护：未捕获的异常不退出进程
process.on('uncaughtException', (err) => {
  console.error('[uncaughtException]', err);
});
process.on('unhandledRejection', (err) => {
  console.error('[unhandledRejection]', err);
});

const __dirname = dirname(fileURLToPath(import.meta.url));
const PORT = 17761;

const app = express();
app.use(express.json());
app.use(express.static(__dirname));
app.use('/api', bootstrapRouter, syncRouter, scenarioRouter);

// 错误处理（必须放在路由之后，4 个参数才被识别为错误处理器）
app.use((err, req, res, next) => {
  if (err && err.status === 400 && 'body' in err) {
    return res.status(400).json({ ok: false, error: 'JSON 解析错误: ' + err.message });
  }
  console.error('Unhandled error:', err);
  res.status(500).json({ ok: false, error: String(err?.message || err) });
});

app.listen(PORT, '127.0.0.1', () => {
  console.log(`SC2 web-launcher: http://127.0.0.1:${PORT}/`);
});
