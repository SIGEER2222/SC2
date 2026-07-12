#!/usr/bin/env node
import { checkGalaxyWithToolkit, renderToolkitGalaxyResult } from './src/toolkitGalaxyChecker.mjs';

function parseArgs(argv) {
  const positional = [];
  const flags = {};
  let index = 0;
  while (index < argv.length) {
    const value = argv[index];
    if (value.startsWith('--')) {
      const name = value.slice(2);
      if (index + 1 < argv.length && !argv[index + 1].startsWith('--')) {
        flags[name] = argv[index + 1];
        index += 2;
      } else {
        flags[name] = true;
        index += 1;
      }
      continue;
    }
    positional.push(value);
    index += 1;
  }
  return { positional, flags };
}

async function main() {
  const { positional, flags } = parseArgs(process.argv.slice(2));
  if (positional.length !== 1) {
    console.error('用法: node toolkit-galaxy-check.mjs <Base.SC2Data 路径> [--format json|text] [--toolkit-root <路径>]');
    return 2;
  }

  const result = await checkGalaxyWithToolkit({
    baseDataRoot: positional[0],
    toolkitRoot: typeof flags['toolkit-root'] === 'string' ? flags['toolkit-root'] : undefined,
  });

  if (flags.format === 'text') console.log(renderToolkitGalaxyResult(result));
  else console.log(JSON.stringify(result, null, 2));

  return result.summary.errors > 0 ? 1 : 0;
}

try {
  process.exit(await main());
} catch (error) {
  console.error(`toolkit-galaxy-check 失败: ${error.message}`);
  console.error(error.stack);
  process.exit(2);
}
