import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { existsSync } from 'fs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SERVER_PATH = join(__dirname, '..', 'web-launcher', 'server.mjs');
const PORT = 17761;

if (!existsSync(SERVER_PATH)) {
  console.error('找不到 web-launcher/server.mjs:', SERVER_PATH);
  process.exit(1);
}

// 检查 node_modules
const nodeModules = join(dirname(SERVER_PATH), 'node_modules');
if (!existsSync(nodeModules)) {
  console.error('未安装依赖，请先执行: cd web-launcher && npm install');
  process.exit(1);
}

console.log('启动 SC2 web-launcher...');
const child = spawn('node', [SERVER_PATH], {
  stdio: 'inherit',
  windowsHide: false,
});

// 自动打开浏览器
setTimeout(async () => {
  try {
    const open = (await import('open')).default;
    await open(`http://127.0.0.1:${PORT}/`);
  } catch {
    console.log(`请手动访问: http://127.0.0.1:${PORT}/`);
  }
}, 1000);

child.on('exit', (code) => process.exit(code ?? 0));
