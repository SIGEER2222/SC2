// src/cli.ts
import { check } from './index.js';
import { IssueReporter } from './reporter/IssueReporter.js';

const args = process.argv.slice(2);
if (args.length === 0 || args.includes('--help')) {
  console.error(`用法: galaxy-check <file|dir> [options]
选项:
  --format <json|text>    输出格式，默认 json
  --rules <path>          项目规则 JSON 路径
  --native-lib <path>     NativeLib.galaxy 路径
  --no-global-symbols      跳过全局符号表构建
  --quiet                 仅输出 issue，无汇总行
  --help                  显示帮助`);
  process.exit(2);
}

const target = args[0];
const formatIdx = args.indexOf('--format');
const rawFormat = formatIdx >= 0 ? args[formatIdx + 1] : 'json';
const format: 'json' | 'text' = rawFormat === 'text' ? 'text' : 'json';

try {
  const result = check(target);
  const reporter = new IssueReporter(format);
  const output = reporter.report(result.issues, result.filesChecked);
  console.log(output);
  process.exit(result.summary.errors > 0 ? 1 : 0);
} catch (e: any) {
  console.error(`工具异常: ${e.message}`);
  console.error(e.stack);
  process.exit(2);
}
