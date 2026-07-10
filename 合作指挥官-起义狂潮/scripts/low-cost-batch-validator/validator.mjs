import fs from "node:fs";
import path from "node:path";

const REVIEW_UNIT_CODES = new Set([
  "UNIT_PARENT_UNRESOLVED",
  "UNIT_PARENT_CIRCULAR",
  "PRODUCER_PARENT_UNRESOLVED",
  "PRODUCER_PARENT_CIRCULAR",
  "STATIC_RUNTIME_DIVERGENCE",
]);

const TASK_CONTRACTS = {
  "dependency-inventory": {
    required: ["raw/*.json", "dependency-summary.csv", "issues.md", "run-summary.json"],
    csv: {
      "dependency-summary.csv": [
        "target",
        "mode",
        "profile",
        "commanders",
        "loadOrderCount",
        "issueCount",
        "errorCount",
        "warningCount",
        "incompleteCount",
        "completeGuess",
      ],
    },
    pairing: "json-meta",
  },
  "unit-diagnostic-matrix": {
    required: [
      "raw/*.json",
      "unit-summary.csv",
      "issue-counts.csv",
      "needs-senior-review.md",
      "run-summary.json",
    ],
    csv: {
      "unit-summary.csv": [
        "caseId",
        "target",
        "commander",
        "unit",
        "producer",
        "status",
        "complete",
        "hasErrors",
        "parentChain",
        "staticAbilityCount",
        "effectiveAbilityCount",
        "productionCandidateCount",
        "selectedProductionAbility",
        "selectedCommand",
        "buttonVisible",
        "runtimeEventCount",
        "issueCount",
        "exitCode",
      ],
      "issue-counts.csv": ["severity", "code", "count", "caseIds"],
    },
    pairing: "json-meta",
  },
  "galaxy-error-inventory": {
    required: [
      "raw/*.txt",
      "errors.csv",
      "error-counts.csv",
      "needs-senior-review.md",
      "run-summary.json",
    ],
    csv: {
      "errors.csv": [
        "baseData",
        "ruleCode",
        "file",
        "line",
        "column",
        "message",
        "rawOutputFile",
      ],
      "error-counts.csv": ["baseData", "ruleCode", "count"],
    },
    pairing: "galaxy",
  },
  "catalog-trace-compare": {
    required: [
      "raw/*.json",
      "catalog-summary.csv",
      "incomplete-boundaries.csv",
      "needs-senior-review.md",
      "run-summary.json",
    ],
    csv: {
      "catalog-summary.csv": [
        "caseId",
        "mode",
        "catalog",
        "id",
        "found",
        "status",
        "complete",
        "leftDefinitionCount",
        "rightDefinitionCount",
        "parentChain",
        "leftRuntimeMutationCount",
        "rightRuntimeMutationCount",
        "fieldDifferenceCount",
        "exitCode",
      ],
      "incomplete-boundaries.csv": [
        "caseId",
        "side",
        "ref",
        "status",
        "unresolvedParent",
      ],
    },
    pairing: "json-meta",
  },
  "localized-name-candidates": {
    required: [
      "raw/*.txt",
      "name-candidates.csv",
      "unmatched.txt",
      "needs-senior-review.md",
      "run-summary.json",
    ],
    csv: {
      "name-candidates.csv": [
        "query",
        "matchedText",
        "internalId",
        "catalogHint",
        "file",
        "line",
        "evidence",
        "confidence",
      ],
    },
  },
  "mpq-inventory": {
    required: [
      "raw/*.json",
      "map-summary.csv",
      "dependency-text.md",
      "run-summary.json",
    ],
    csv: {
      "map-summary.csv": [
        "map",
        "sizeBytes",
        "fileCount",
        "hasDocumentInfo",
        "hasMapScript",
        "gameDataXmlCount",
        "galaxyFileCount",
        "extractedTextBytes",
        "errorCount",
      ],
    },
  },
  "validation-doc-audit": {
    required: [
      "raw/*",
      "validation-summary.csv",
      "stale-doc-candidates.csv",
      "needs-senior-review.md",
      "run-summary.json",
    ],
    csv: {
      "validation-summary.csv": [
        "check",
        "command",
        "exitCode",
        "durationMs",
        "passCount",
        "failCount",
        "errorSummary",
        "rawOutput",
      ],
      "stale-doc-candidates.csv": ["category", "file", "line", "text", "reason"],
    },
    pairing: "validation",
  },
};

function normalizeRelative(value) {
  return value.replaceAll("\\", "/").replace(/^\.\//, "");
}

function issue(taskId, batchDir, code, message, relativePath = "") {
  return {
    severity: "error",
    taskId,
    code,
    path: relativePath || normalizeRelative(path.basename(batchDir)),
    message,
  };
}

function readText(filePath) {
  return fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, "");
}

function readJson(filePath) {
  return JSON.parse(readText(filePath));
}

function walkFiles(root) {
  if (!fs.existsSync(root)) return [];
  const result = [];
  const stack = [root];
  while (stack.length > 0) {
    const current = stack.pop();
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const absolute = path.join(current, entry.name);
      if (entry.isDirectory()) stack.push(absolute);
      else if (entry.isFile()) result.push(absolute);
    }
  }
  return result;
}

function globRegex(spec) {
  const escaped = normalizeRelative(spec)
    .replace(/[.+?^${}()|[\]\\]/g, "\\$&")
    .replaceAll("*", "[^/]*");
  return new RegExp(`^${escaped}$`);
}

function matchFiles(batchDir, spec) {
  const regex = globRegex(spec);
  return walkFiles(batchDir).filter((filePath) =>
    regex.test(normalizeRelative(path.relative(batchDir, filePath))),
  );
}

function isInside(root, candidate) {
  const relative = path.relative(root, candidate);
  return relative !== "" && !relative.startsWith("..") && !path.isAbsolute(relative);
}

export function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = "";
  let quoted = false;
  const input = text.replace(/^\uFEFF/, "");

  for (let index = 0; index < input.length; index += 1) {
    const char = input[index];
    if (quoted) {
      if (char === '"') {
        if (input[index + 1] === '"') {
          field += '"';
          index += 1;
        } else {
          quoted = false;
        }
      } else {
        field += char;
      }
      continue;
    }

    if (char === '"') quoted = true;
    else if (char === ",") {
      row.push(field);
      field = "";
    } else if (char === "\n") {
      row.push(field.replace(/\r$/, ""));
      if (row.some((value) => value !== "")) rows.push(row);
      row = [];
      field = "";
    } else {
      field += char;
    }
  }

  if (quoted) throw new Error("unterminated quoted CSV field");
  row.push(field.replace(/\r$/, ""));
  if (row.some((value) => value !== "")) rows.push(row);
  if (rows.length === 0) return { headers: [], rows: [] };

  const headers = rows[0];
  return {
    headers,
    rows: rows.slice(1).map((values) =>
      Object.fromEntries(headers.map((header, index) => [header, values[index] ?? ""])),
    ),
  };
}

function loadCsv(taskId, batchDir, fileName, issues) {
  const absolute = path.join(batchDir, fileName);
  if (!fs.existsSync(absolute)) return null;
  try {
    return parseCsv(readText(absolute));
  } catch (error) {
    issues.push(
      issue(taskId, batchDir, "CSV_PARSE_FAILED", error.message, fileName),
    );
    return null;
  }
}

function validateCsvSchemas(taskId, batchDir, contract, issues) {
  const loaded = new Map();
  for (const [fileName, expectedHeaders] of Object.entries(contract.csv ?? {})) {
    const parsed = loadCsv(taskId, batchDir, fileName, issues);
    if (!parsed) continue;
    loaded.set(fileName, parsed);
    const missing = expectedHeaders.filter((header) => !parsed.headers.includes(header));
    if (missing.length > 0) {
      issues.push(
        issue(
          taskId,
          batchDir,
          "CSV_REQUIRED_COLUMNS_MISSING",
          `Missing columns: ${missing.join(", ")}`,
          fileName,
        ),
      );
    }
  }
  return loaded;
}

function validateRequiredOutputs(task, batchDir, contract, issues) {
  const specs = [...new Set([...(task.outputs ?? []), ...(contract.required ?? [])])];
  for (const spec of specs) {
    if (matchFiles(batchDir, spec).length === 0) {
      issues.push(
        issue(
          task.id,
          batchDir,
          "REQUIRED_OUTPUT_MISSING",
          `No artifact matches required output "${spec}"`,
          spec,
        ),
      );
    }
  }
}

function validateRunSummary(task, batchDir, issues) {
  const summaryPath = path.join(batchDir, "run-summary.json");
  if (!fs.existsSync(summaryPath)) return null;
  let summary;
  try {
    summary = readJson(summaryPath);
  } catch (error) {
    issues.push(
      issue(task.id, batchDir, "RUN_SUMMARY_INVALID_JSON", error.message, "run-summary.json"),
    );
    return null;
  }

  if (summary.batchId && summary.batchId !== path.basename(batchDir)) {
    issues.push(
      issue(
        task.id,
        batchDir,
        "RUN_SUMMARY_BATCH_MISMATCH",
        `batchId is "${summary.batchId}", expected "${path.basename(batchDir)}"`,
        "run-summary.json",
      ),
    );
  }

  if (!Array.isArray(summary.outputs)) {
    issues.push(
      issue(
        task.id,
        batchDir,
        "RUN_SUMMARY_OUTPUTS_MISSING",
        "outputs must be an array of artifact paths",
        "run-summary.json",
      ),
    );
    return summary;
  }

  for (const output of summary.outputs) {
    if (typeof output !== "string" || output.trim() === "") {
      issues.push(
        issue(
          task.id,
          batchDir,
          "RUN_SUMMARY_OUTPUT_INVALID",
          "outputs contains a non-string or empty path",
          "run-summary.json",
        ),
      );
      continue;
    }
    const absolute = path.resolve(batchDir, output);
    if (!isInside(batchDir, absolute)) {
      issues.push(
        issue(
          task.id,
          batchDir,
          "RUN_SUMMARY_OUTPUT_ESCAPES_BATCH",
          `Output path escapes the batch directory: ${output}`,
          "run-summary.json",
        ),
      );
    } else if (!fs.existsSync(absolute)) {
      issues.push(
        issue(
          task.id,
          batchDir,
          "RUN_SUMMARY_OUTPUT_MISSING",
          `Listed output does not exist: ${output}`,
          normalizeRelative(output),
        ),
      );
    }
  }
  return summary;
}

function rawJsonFiles(batchDir) {
  const rawDir = path.join(batchDir, "raw");
  if (!fs.existsSync(rawDir)) return [];
  return fs
    .readdirSync(rawDir)
    .filter((name) => name.endsWith(".json") && !name.endsWith(".meta.json"))
    .map((name) => path.join(rawDir, name));
}

function validateMetaFile(taskId, batchDir, metaPath, requiredFields, issues) {
  if (!fs.existsSync(metaPath)) {
    issues.push(
      issue(
        taskId,
        batchDir,
        "RAW_META_MISSING",
        `Missing metadata file for raw artifact: ${path.basename(metaPath)}`,
        normalizeRelative(path.relative(batchDir, metaPath)),
      ),
    );
    return null;
  }
  let meta;
  try {
    meta = readJson(metaPath);
  } catch (error) {
    issues.push(
      issue(
        taskId,
        batchDir,
        "RAW_META_INVALID_JSON",
        error.message,
        normalizeRelative(path.relative(batchDir, metaPath)),
      ),
    );
    return null;
  }
  const missing = requiredFields.filter(
    (field) => !Object.prototype.hasOwnProperty.call(meta, field),
  );
  if (missing.length > 0) {
    issues.push(
      issue(
        taskId,
        batchDir,
        "RAW_META_FIELDS_MISSING",
        `Missing metadata fields: ${missing.join(", ")}`,
        normalizeRelative(path.relative(batchDir, metaPath)),
      ),
    );
  }
  return meta;
}

function validatePairing(taskId, batchDir, pairing, issues) {
  const rawDir = path.join(batchDir, "raw");
  if (!fs.existsSync(rawDir)) return;
  const names = fs.readdirSync(rawDir);

  if (pairing === "json-meta") {
    for (const name of names.filter(
      (value) => value.endsWith(".json") && !value.endsWith(".meta.json"),
    )) {
      const stem = name.slice(0, -".json".length);
      validateMetaFile(
        taskId,
        batchDir,
        path.join(rawDir, `${stem}.meta.json`),
        ["command", "exitCode", "stderr"],
        issues,
      );
    }
  } else if (pairing === "galaxy") {
    for (const name of names.filter(
      (value) => value.endsWith(".txt") && !value.endsWith(".stderr.txt"),
    )) {
      const stem = name.slice(0, -".txt".length);
      const stderrPath = path.join(rawDir, `${stem}.stderr.txt`);
      if (!fs.existsSync(stderrPath)) {
        issues.push(
          issue(
            taskId,
            batchDir,
            "RAW_STDERR_MISSING",
            `Missing stderr file for ${name}`,
            normalizeRelative(path.relative(batchDir, stderrPath)),
          ),
        );
      }
      validateMetaFile(
        taskId,
        batchDir,
        path.join(rawDir, `${stem}.meta.json`),
        ["command", "exitCode", "startTime", "endTime"],
        issues,
      );
    }
  } else if (pairing === "validation") {
    for (const name of names.filter((value) => value.endsWith(".stdout.txt"))) {
      const stem = name.slice(0, -".stdout.txt".length);
      const stderrPath = path.join(rawDir, `${stem}.stderr.txt`);
      if (!fs.existsSync(stderrPath)) {
        issues.push(
          issue(
            taskId,
            batchDir,
            "RAW_STDERR_MISSING",
            `Missing stderr file for ${name}`,
            normalizeRelative(path.relative(batchDir, stderrPath)),
          ),
        );
      }
      validateMetaFile(
        taskId,
        batchDir,
        path.join(rawDir, `${stem}.meta.json`),
        ["command", "exitCode", "durationMs"],
        issues,
      );
    }
  }
}

function parseBoolean(value) {
  if (typeof value === "boolean") return value;
  if (typeof value !== "string") return null;
  if (value.toLowerCase() === "true") return true;
  if (value.toLowerCase() === "false") return false;
  return null;
}

function checkCount(taskId, batchDir, summary, field, actual, issues) {
  if (summary && Number.isFinite(Number(summary[field])) && Number(summary[field]) !== actual) {
    issues.push(
      issue(
        taskId,
        batchDir,
        "RUN_SUMMARY_COUNT_MISMATCH",
        `${field}=${summary[field]}, but raw artifacts imply ${actual}`,
        "run-summary.json",
      ),
    );
  }
}

function loadRawJson(taskId, batchDir, issues) {
  const result = [];
  for (const filePath of rawJsonFiles(batchDir)) {
    try {
      result.push({ filePath, value: readJson(filePath) });
    } catch (error) {
      issues.push(
        issue(
          taskId,
          batchDir,
          "RAW_JSON_INVALID",
          error.message,
          normalizeRelative(path.relative(batchDir, filePath)),
        ),
      );
    }
  }
  return result;
}

function validateDependency(taskId, batchDir, summary, csvs, issues) {
  const raw = loadRawJson(taskId, batchDir, issues);
  const table = csvs.get("dependency-summary.csv");
  checkCount(taskId, batchDir, summary, "targetsTotal", raw.length, issues);
  if (table && table.rows.length !== raw.length) {
    issues.push(
      issue(
        taskId,
        batchDir,
        "SUMMARY_RAW_ROW_COUNT_MISMATCH",
        `dependency-summary.csv has ${table.rows.length} rows, raw has ${raw.length}`,
        "dependency-summary.csv",
      ),
    );
  }
  if (!table) return;
  const rowKey = (value) =>
    [
      value.target ?? "",
      value.mode ?? "",
      value.profile ?? "",
      Array.isArray(value.commanders)
        ? value.commanders.join(",")
        : value.commanders ?? "",
    ].join("\u0000");
  const rowsByTarget = new Map(table.rows.map((row) => [rowKey(row), row]));
  for (const { filePath, value } of raw) {
    const row = rowsByTarget.get(rowKey(value));
    if (!row) {
      issues.push(
        issue(
          taskId,
          batchDir,
          "RAW_CASE_MISSING_FROM_SUMMARY",
          `No dependency-summary.csv row for target ${value.target ?? "<missing>"}`,
          normalizeRelative(path.relative(batchDir, filePath)),
        ),
      );
      continue;
    }
    if (Array.isArray(value.loadOrder) && Number(row.loadOrderCount) !== value.loadOrder.length) {
      issues.push(
        issue(
          taskId,
          batchDir,
          "SUMMARY_FIELD_MISMATCH",
          `loadOrderCount=${row.loadOrderCount}, raw=${value.loadOrder.length}`,
          "dependency-summary.csv",
        ),
      );
    }
  }
}

function validateUnit(taskId, batchDir, summary, csvs, issues) {
  const raw = loadRawJson(taskId, batchDir, issues);
  const table = csvs.get("unit-summary.csv");
  const reviewPath = path.join(batchDir, "needs-senior-review.md");
  const review = fs.existsSync(reviewPath) ? readText(reviewPath) : "";

  checkCount(taskId, batchDir, summary, "totalCases", raw.length, issues);
  checkCount(
    taskId,
    batchDir,
    summary,
    "incomplete",
    raw.filter(({ value }) => value.complete === false).length,
    issues,
  );
  checkCount(
    taskId,
    batchDir,
    summary,
    "error",
    raw.filter(({ value }) => value.hasErrors === true || value.status === "error").length,
    issues,
  );

  if (table && table.rows.length !== raw.length) {
    issues.push(
      issue(
        taskId,
        batchDir,
        "SUMMARY_RAW_ROW_COUNT_MISMATCH",
        `unit-summary.csv has ${table.rows.length} rows, raw has ${raw.length}`,
        "unit-summary.csv",
      ),
    );
  }
  const rowsByCase = new Map((table?.rows ?? []).map((row) => [row.caseId, row]));
  const expectedIssueCounts = new Map();

  for (const { filePath, value } of raw) {
    const caseId = path.basename(filePath, ".json");
    const row = rowsByCase.get(caseId);
    if (!row) {
      issues.push(
        issue(
          taskId,
          batchDir,
          "RAW_CASE_MISSING_FROM_SUMMARY",
          `No unit-summary.csv row for ${caseId}`,
          normalizeRelative(path.relative(batchDir, filePath)),
        ),
      );
    } else {
      const rowComplete = parseBoolean(row.complete);
      if (rowComplete !== null && rowComplete !== value.complete) {
        issues.push(
          issue(
            taskId,
            batchDir,
            "SUMMARY_FIELD_MISMATCH",
            `${caseId} complete=${row.complete}, raw=${value.complete}`,
            "unit-summary.csv",
          ),
        );
      }
      const rawIssueCount = Array.isArray(value.issues) ? value.issues.length : 0;
      if (Number(row.issueCount) !== rawIssueCount) {
        issues.push(
          issue(
            taskId,
            batchDir,
            "SUMMARY_FIELD_MISMATCH",
            `${caseId} issueCount=${row.issueCount}, raw=${rawIssueCount}`,
            "unit-summary.csv",
          ),
        );
      }
    }

    const reviewRequired =
      value.complete === false ||
      (value.issues ?? []).some((entry) => REVIEW_UNIT_CODES.has(entry.code));
    if (reviewRequired && !review.includes(caseId)) {
      issues.push(
        issue(
          taskId,
          batchDir,
          "UNIT_REVIEW_COVERAGE_MISSING",
          `${caseId} requires senior review but is not listed`,
          "needs-senior-review.md",
        ),
      );
    }

    for (const entry of value.issues ?? []) {
      const key = `${entry.severity ?? ""}\u0000${entry.code ?? ""}`;
      const aggregate = expectedIssueCounts.get(key) ?? { count: 0, caseIds: [] };
      aggregate.count += 1;
      aggregate.caseIds.push(caseId);
      expectedIssueCounts.set(key, aggregate);
    }
  }

  const issueTable = csvs.get("issue-counts.csv");
  if (issueTable) {
    const actual = new Map(
      issueTable.rows.map((row) => [
        `${row.severity}\u0000${row.code}`,
        { count: Number(row.count), caseIds: row.caseIds.split(/[;,]\s*/).filter(Boolean) },
      ]),
    );
    for (const [key, expected] of expectedIssueCounts) {
      const found = actual.get(key);
      if (!found || found.count !== expected.count) {
        const [severity, code] = key.split("\u0000");
        issues.push(
          issue(
            taskId,
            batchDir,
            "ISSUE_AGGREGATE_MISMATCH",
            `${severity}/${code} count is ${found?.count ?? "missing"}, expected ${expected.count}`,
            "issue-counts.csv",
          ),
        );
      }
    }
  }
}

function validateGalaxy(taskId, batchDir, summary, csvs, issues) {
  const rawDir = path.join(batchDir, "raw");
  const rawFiles = fs.existsSync(rawDir)
    ? fs
        .readdirSync(rawDir)
        .filter((name) => name.endsWith(".txt") && !name.endsWith(".stderr.txt"))
        .map((name) => path.join(rawDir, name))
    : [];
  const errorLines = rawFiles.flatMap((filePath) =>
    readText(filePath)
      .split(/\r?\n/)
      .filter((line) => line.includes("[ERROR]")),
  );
  const errorsTable = csvs.get("errors.csv");
  checkCount(taskId, batchDir, summary, "directoriesScanned", rawFiles.length, issues);
  checkCount(taskId, batchDir, summary, "totalErrors", errorLines.length, issues);
  if (errorsTable && errorsTable.rows.length !== errorLines.length) {
    issues.push(
      issue(
        taskId,
        batchDir,
        "SUMMARY_RAW_ROW_COUNT_MISMATCH",
        `errors.csv has ${errorsTable.rows.length} rows, raw logs have ${errorLines.length} [ERROR] lines`,
        "errors.csv",
      ),
    );
  }
  if (errorsTable && summary?.ruleCodeCounts) {
    const counts = new Map();
    for (const row of errorsTable.rows) {
      counts.set(row.ruleCode, (counts.get(row.ruleCode) ?? 0) + 1);
    }
    for (const [code, expected] of Object.entries(summary.ruleCodeCounts)) {
      if ((counts.get(code) ?? 0) !== Number(expected)) {
        issues.push(
          issue(
            taskId,
            batchDir,
            "RULE_COUNT_MISMATCH",
            `${code} count is ${counts.get(code) ?? 0}, run-summary says ${expected}`,
            "run-summary.json",
          ),
        );
      }
    }
  }
}

function validateMpq(taskId, batchDir, summary, csvs, issues) {
  const raw = loadRawJson(taskId, batchDir, issues);
  const table = csvs.get("map-summary.csv");
  checkCount(taskId, batchDir, summary, "mapsTotal", raw.length, issues);
  if (table && table.rows.length !== raw.length) {
    issues.push(
      issue(
        taskId,
        batchDir,
        "SUMMARY_RAW_ROW_COUNT_MISMATCH",
        `map-summary.csv has ${table.rows.length} rows, raw has ${raw.length}`,
        "map-summary.csv",
      ),
    );
  }
  for (const { filePath, value } of raw) {
    if (
      (value.hasDocumentInfo === true || value.hasMapScript === true) &&
      Number(value.extractedTextBytes) === 0
    ) {
      issues.push(
        issue(
          taskId,
          batchDir,
          "MPQ_TEXT_NOT_EXTRACTED",
          "Text entries were detected but extractedTextBytes is zero",
          normalizeRelative(path.relative(batchDir, filePath)),
        ),
      );
    }
  }
}

function validateAudit(taskId, batchDir, summary, csvs, issues) {
  const table = csvs.get("validation-summary.csv");
  if (!table) return;
  checkCount(taskId, batchDir, summary, "checksExecuted", table.rows.length, issues);
  const checks = new Set(table.rows.map((row) => row.check));
  for (const requested of summary?.checksRequested ?? []) {
    if (!checks.has(requested)) {
      issues.push(
        issue(
          taskId,
          batchDir,
          "REQUESTED_CHECK_MISSING",
          `Requested check "${requested}" has no validation-summary.csv row`,
          "validation-summary.csv",
        ),
      );
    }
  }
  for (const row of table.rows) {
    const rawOutput = row.rawOutput;
    if (!rawOutput) continue;
    const absolute = path.resolve(batchDir, rawOutput);
    if (!isInside(batchDir, absolute) || !fs.existsSync(absolute)) continue;
    const size = fs.statSync(absolute).size;
    const assertedTests = Number(row.passCount || 0) + Number(row.failCount || 0);
    const minimum = assertedTests > 0 ? 100 : row.check === "diff-check" ? 0 : 32;
    if (size < minimum) {
      issues.push(
        issue(
          taskId,
          batchDir,
          "VALIDATION_RAW_OUTPUT_SUSPICIOUSLY_SMALL",
          `${row.check} raw output is ${size} bytes; expected at least ${minimum}`,
          normalizeRelative(rawOutput),
        ),
      );
    }
  }
}

function validateTaskSpecific(taskId, batchDir, summary, csvs, issues) {
  if (taskId === "dependency-inventory") {
    validateDependency(taskId, batchDir, summary, csvs, issues);
  } else if (taskId === "unit-diagnostic-matrix") {
    validateUnit(taskId, batchDir, summary, csvs, issues);
  } else if (taskId === "galaxy-error-inventory") {
    validateGalaxy(taskId, batchDir, summary, csvs, issues);
  } else if (taskId === "mpq-inventory") {
    validateMpq(taskId, batchDir, summary, csvs, issues);
  } else if (taskId === "validation-doc-audit") {
    validateAudit(taskId, batchDir, summary, csvs, issues);
  }
}

export function loadManifest(manifestPath) {
  const manifest = readJson(manifestPath);
  if (!Array.isArray(manifest.tasks)) {
    throw new Error("task-manifest.json must contain a tasks array");
  }
  return manifest;
}

export function validateTaskBatch({ manifestPath, taskId, batchDir }) {
  const absoluteBatch = path.resolve(batchDir);
  const issues = [];
  const manifest = loadManifest(manifestPath);
  const task = manifest.tasks.find((entry) => entry.id === taskId);
  const contract = TASK_CONTRACTS[taskId];

  if (!task) {
    return {
      taskId,
      batchDir: absoluteBatch,
      issues: [
        issue(taskId, absoluteBatch, "TASK_NOT_IN_MANIFEST", "Task is not in task-manifest.json"),
      ],
    };
  }
  if (!contract) {
    return {
      taskId,
      batchDir: absoluteBatch,
      issues: [issue(taskId, absoluteBatch, "TASK_CONTRACT_MISSING", "No validator contract")],
    };
  }
  if (!fs.existsSync(absoluteBatch)) {
    return {
      taskId,
      batchDir: absoluteBatch,
      issues: [
        issue(taskId, absoluteBatch, "TASK_BATCH_MISSING", "Batch directory does not exist"),
      ],
    };
  }

  const promptPath = path.resolve(path.dirname(manifestPath), task.prompt);
  if (!fs.existsSync(promptPath)) {
    issues.push(
      issue(
        taskId,
        absoluteBatch,
        "TASK_PROMPT_MISSING",
        `Prompt file does not exist: ${task.prompt}`,
        task.prompt,
      ),
    );
  }

  validateRequiredOutputs(task, absoluteBatch, contract, issues);
  const summary = validateRunSummary(task, absoluteBatch, issues);
  const csvs = validateCsvSchemas(taskId, absoluteBatch, contract, issues);
  validatePairing(taskId, absoluteBatch, contract.pairing, issues);
  validateTaskSpecific(taskId, absoluteBatch, summary, csvs, issues);

  return { taskId, batchDir: absoluteBatch, issues };
}

export function validateBatchSet({ manifestPath, artifactsRoot, batchId }) {
  const manifest = loadManifest(manifestPath);
  const results = manifest.tasks.map((task) =>
    validateTaskBatch({
      manifestPath,
      taskId: task.id,
      batchDir: path.join(artifactsRoot, task.id, batchId),
    }),
  );
  return {
    batchId,
    artifactsRoot: path.resolve(artifactsRoot),
    results,
    issues: results.flatMap((result) => result.issues),
  };
}

export function formatTextReport(report) {
  const issues = report.issues ?? [];
  const lines = [
    `low-cost-batch-validator: ${issues.length === 0 ? "PASS" : "FAIL"}`,
    `issues: ${issues.length}`,
  ];
  for (const entry of issues) {
    lines.push(
      `[${entry.code}] ${entry.taskId} ${entry.path}: ${entry.message}`,
    );
  }
  return lines.join("\n");
}
