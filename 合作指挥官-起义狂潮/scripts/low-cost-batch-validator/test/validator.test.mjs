import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  formatTextReport,
  parseCsv,
  validateTaskBatch,
} from "../validator.mjs";

const UNIT_HEADERS = [
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
];

function writeJson(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function write(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, value);
}

function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "low-cost-validator-"));
  const promptRoot = path.join(root, "tasks");
  const batchDir = path.join(root, "artifacts", "unit-diagnostic-matrix", "batch-test");
  fs.mkdirSync(promptRoot, { recursive: true });
  write(path.join(promptRoot, "02.md"), "# task\n");
  const manifestPath = path.join(promptRoot, "task-manifest.json");
  writeJson(manifestPath, {
    schemaVersion: 1,
    tasks: [
      {
        id: "unit-diagnostic-matrix",
        prompt: "02.md",
        outputs: [
          "raw/*.json",
          "unit-summary.csv",
          "issue-counts.csv",
          "needs-senior-review.md",
          "run-summary.json",
        ],
      },
    ],
  });
  return { root, manifestPath, batchDir };
}

function createValidUnitBatch(batchDir) {
  writeJson(path.join(batchDir, "raw", "case-a.json"), {
    status: "incomplete",
    complete: false,
    hasErrors: false,
    issues: [{ severity: "warning", code: "STATIC_RUNTIME_DIVERGENCE" }],
  });
  writeJson(path.join(batchDir, "raw", "case-a.meta.json"), {
    command: "node tool",
    exitCode: 1,
    stderr: "",
  });
  write(
    path.join(batchDir, "unit-summary.csv"),
    `${UNIT_HEADERS.join(",")}\ncase-a,target,cmd,unit,producer,incomplete,false,false,parent,1,1,1,train,cmd,true,0,1,1\n`,
  );
  write(
    path.join(batchDir, "issue-counts.csv"),
    "severity,code,count,caseIds\nwarning,STATIC_RUNTIME_DIVERGENCE,1,case-a\n",
  );
  write(
    path.join(batchDir, "needs-senior-review.md"),
    "- case-a: raw/case-a.json\n",
  );
  writeJson(path.join(batchDir, "run-summary.json"), {
    batchId: "batch-test",
    totalCases: 1,
    incomplete: 1,
    error: 0,
    outputs: [
      "raw/case-a.json",
      "unit-summary.csv",
      "issue-counts.csv",
      "needs-senior-review.md",
      "run-summary.json",
    ],
  });
}

function dependencyFixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "low-cost-validator-dependency-"));
  const promptRoot = path.join(root, "tasks");
  const batchDir = path.join(root, "artifacts", "dependency-inventory", "batch-test");
  fs.mkdirSync(promptRoot, { recursive: true });
  write(path.join(promptRoot, "01.md"), "# task\n");
  const manifestPath = path.join(promptRoot, "task-manifest.json");
  writeJson(manifestPath, {
    tasks: [
      {
        id: "dependency-inventory",
        prompt: "01.md",
        outputs: [
          "raw/*.json",
          "dependency-summary.csv",
          "issues.md",
          "run-summary.json",
        ],
      },
    ],
  });
  for (const [name, mode, count] of [
    ["declared", "declared", 5],
    ["effective", "effective", 34],
  ]) {
    writeJson(path.join(batchDir, "raw", `${name}.json`), {
      target: "same-target",
      mode,
      profile: null,
      commanders: [],
      loadOrder: Array.from({ length: count }, (_, index) => index),
    });
    writeJson(path.join(batchDir, "raw", `${name}.meta.json`), {
      target: "same-target",
      command: "node tool",
      exitCode: 0,
      stderr: "",
    });
  }
  write(
    path.join(batchDir, "dependency-summary.csv"),
    [
      "target,mode,profile,commanders,loadOrderCount,issueCount,errorCount,warningCount,incompleteCount,completeGuess",
      "same-target,declared,,,5,0,0,0,0,true",
      "same-target,effective,,,34,0,0,0,0,true",
      "",
    ].join("\n"),
  );
  write(path.join(batchDir, "issues.md"), "# none\n");
  writeJson(path.join(batchDir, "run-summary.json"), {
    batchId: "batch-test",
    targetsTotal: 2,
    outputs: [
      "raw/declared.json",
      "raw/effective.json",
      "dependency-summary.csv",
      "issues.md",
      "run-summary.json",
    ],
  });
  return { root, manifestPath, batchDir };
}

test("parseCsv supports quoted commas and escaped quotes", () => {
  const parsed = parseCsv('a,b\n"x,y","say ""hi"""\n');
  assert.deepEqual(parsed.headers, ["a", "b"]);
  assert.deepEqual(parsed.rows, [{ a: "x,y", b: 'say "hi"' }]);
});

test("valid unit batch passes", () => {
  const { root, manifestPath, batchDir } = fixture();
  try {
    createValidUnitBatch(batchDir);
    const result = validateTaskBatch({
      manifestPath,
      taskId: "unit-diagnostic-matrix",
      batchDir,
    });
    assert.deepEqual(result.issues, []);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test("dependency rows distinguish declared and effective modes for one target", () => {
  const { root, manifestPath, batchDir } = dependencyFixture();
  try {
    const result = validateTaskBatch({
      manifestPath,
      taskId: "dependency-inventory",
      batchDir,
    });
    assert.deepEqual(result.issues, []);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test("missing metadata, columns, review coverage, and counts are reported", () => {
  const { root, manifestPath, batchDir } = fixture();
  try {
    createValidUnitBatch(batchDir);
    fs.rmSync(path.join(batchDir, "raw", "case-a.meta.json"));
    write(path.join(batchDir, "unit-summary.csv"), "caseId,complete\ncase-a,true\n");
    write(path.join(batchDir, "needs-senior-review.md"), "# none\n");
    const summaryPath = path.join(batchDir, "run-summary.json");
    const summary = JSON.parse(fs.readFileSync(summaryPath, "utf8"));
    summary.totalCases = 2;
    summary.incomplete = 0;
    summary.outputs.push("raw/missing.json");
    writeJson(summaryPath, summary);

    const result = validateTaskBatch({
      manifestPath,
      taskId: "unit-diagnostic-matrix",
      batchDir,
    });
    const codes = new Set(result.issues.map((entry) => entry.code));
    assert.ok(codes.has("RAW_META_MISSING"));
    assert.ok(codes.has("CSV_REQUIRED_COLUMNS_MISSING"));
    assert.ok(codes.has("UNIT_REVIEW_COVERAGE_MISSING"));
    assert.ok(codes.has("RUN_SUMMARY_COUNT_MISMATCH"));
    assert.ok(codes.has("RUN_SUMMARY_OUTPUT_MISSING"));
    assert.match(formatTextReport(result), /low-cost-batch-validator: FAIL/);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
