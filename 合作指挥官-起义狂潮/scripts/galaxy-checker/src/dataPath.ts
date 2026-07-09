// src/dataPath.ts
// 定位 data/ 目录下的资源文件。
// 源码布局（src/analyzer/*.js → ../../data）与 esbuild 单文件产物
// （dist/cli.mjs → ../data）深度不同，向上逐级探测。
import { existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

export function resolveDataFile(name: string): string {
  let dir = dirname(fileURLToPath(import.meta.url));
  for (let i = 0; i < 4; i++) {
    const candidate = join(dir, 'data', name);
    if (existsSync(candidate)) return candidate;
    dir = dirname(dir);
  }
  // 找不到时返回默认布局路径，让调用方的 readFileSync 报出可读错误
  return join(dirname(fileURLToPath(import.meta.url)), '..', 'data', name);
}
