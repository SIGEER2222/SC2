// src/cli.ts
import Module from 'node:module';
// V8 字节码缓存：首跑后 CLI 冷启动可减少 100ms+（Node >= 22.8，旧版忽略）
try { (Module as any).enableCompileCache?.(); } catch { /* ignore */ }

const { check } = await import('./index.js');
const { IssueReporter } = await import('./reporter/IssueReporter.js');

const args = process.argv.slice(2);
if (args.length === 0 || args.includes('--help')) {
  console.error(`用法: galaxy-check <file|dir> [options]
选项:
  --format <json|text>    输出格式，默认 json
  --rules <path>          项目规则 JSON 路径
  --native-lib <path>     NativeLib.galaxy 路径
  --catalog-db <path>     catalog ID JSON 路径（默认 data/catalog-ids.json）
  --no-global-symbols     跳过全局符号表构建
  --help                  显示帮助`);
  process.exit(2);
}

const target = args[0];
const formatIdx = args.indexOf('--format');
const rawFormat = formatIdx >= 0 ? args[formatIdx + 1] : 'json';
const format: 'json' | 'text' = rawFormat === 'text' ? 'text' : 'json';

const rulesIdx = args.indexOf('--rules');
const nativeLibIdx = args.indexOf('--native-lib');
const catalogDbIdx = args.indexOf('--catalog-db');

try {
  const result = check(target, {
    rulesPath: rulesIdx >= 0 ? args[rulesIdx + 1] : undefined,
    nativeLibPath: nativeLibIdx >= 0 ? args[nativeLibIdx + 1] : undefined,
    catalogDbPath: catalogDbIdx >= 0 ? args[catalogDbIdx + 1] : undefined,
    noGlobalSymbols: args.includes('--no-global-symbols'),
  });
  const reporter = new IssueReporter(format);
  const output = reporter.report(result.issues, result.filesChecked);
  console.log(output);
  process.exit(result.summary.errors > 0 ? 1 : 0);
} catch (e: any) {
  console.error(`工具异常: ${e.message}`);
  console.error(e.stack);
  process.exit(2);
}
