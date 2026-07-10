#!/usr/bin/env node
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  formatTextReport,
  validateBatchSet,
  validateTaskBatch,
} from "./validator.mjs";

function usage() {
  return [
    "Usage:",
    "  node cli.mjs <batch-directory> [--task <task-id>] [--manifest <path>] [--format text|json]",
    "  node cli.mjs --batch <batch-id> [--artifacts-root <path>] [--manifest <path>] [--format text|json]",
  ].join("\n");
}

function parseArgs(argv) {
  const parsed = { format: "text", positional: [] };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (!arg.startsWith("--")) {
      parsed.positional.push(arg);
      continue;
    }
    const key = arg.slice(2);
    if (!["task", "manifest", "format", "batch", "artifacts-root"].includes(key)) {
      throw new Error(`Unknown option: ${arg}`);
    }
    const value = argv[index + 1];
    if (!value || value.startsWith("--")) throw new Error(`Missing value for ${arg}`);
    parsed[key] = value;
    index += 1;
  }
  if (!["text", "json"].includes(parsed.format)) {
    throw new Error("--format must be text or json");
  }
  return parsed;
}

try {
  const args = parseArgs(process.argv.slice(2));
  const scriptDir = path.dirname(fileURLToPath(import.meta.url));
  const manifestPath = path.resolve(
    args.manifest ?? path.join(scriptDir, "../../docs/低成本模型任务包/task-manifest.json"),
  );
  let report;

  if (args.batch) {
    if (args.positional.length > 0) throw new Error("Do not combine a batch directory with --batch");
    const artifactsRoot = path.resolve(
      args["artifacts-root"] ?? path.join(scriptDir, "../../docs/低成本模型产物"),
    );
    report = validateBatchSet({
      manifestPath,
      artifactsRoot,
      batchId: args.batch,
    });
  } else {
    if (args.positional.length !== 1) throw new Error(usage());
    const batchDir = path.resolve(args.positional[0]);
    const taskId = args.task ?? path.basename(path.dirname(batchDir));
    report = validateTaskBatch({ manifestPath, taskId, batchDir });
  }

  process.stdout.write(
    args.format === "json"
      ? `${JSON.stringify(report, null, 2)}\n`
      : `${formatTextReport(report)}\n`,
  );
  process.exitCode = report.issues.length === 0 ? 0 : 1;
} catch (error) {
  process.stderr.write(`${error.message}\n${usage()}\n`);
  process.exitCode = 2;
}
