// src/analyzer/IssueEnricher.ts
import { readFileSync, existsSync } from 'node:fs';
import { resolveDataFile } from '../dataPath.js';
import type { Issue, Confidence, RuntimeRisk } from '../types.js';

interface RuleMeta {
  confidence: Confidence;
  autoFixable: boolean;
  runtimeRisk: RuntimeRisk;
  suggestedOwner: string;
  notes?: string;
}

interface RuleMetadataFile {
  version: string;
  rules: Record<string, RuleMeta>;
  contextDependentRules: string[];
  contextUpgradeConfidence: Record<string, Confidence>;
}

const DEFAULT_METADATA_PATH = resolveDataFile('rule-metadata.json');

let cachedMetadata: RuleMetadataFile | null = null;
let cachedMetadataPath: string | null = null;

function loadMetadata(path?: string): RuleMetadataFile | null {
  const resolved = path && existsSync(path) ? path
    : existsSync(DEFAULT_METADATA_PATH) ? DEFAULT_METADATA_PATH : null;
  if (resolved === null) return null;
  if (cachedMetadata && cachedMetadataPath === resolved) return cachedMetadata;
  try {
    cachedMetadata = JSON.parse(readFileSync(resolved, 'utf-8')) as RuleMetadataFile;
    cachedMetadataPath = resolved;
    return cachedMetadata;
  } catch {
    return null;
  }
}

/**
 * 为 issue 注入工程化元数据（confidence/autoFixable/runtimeRisk/suggestedOwner）。
 * 当 contextLoaded=true 时，上下文相关规则的 confidence 升级为 high。
 */
export function enrichIssues(
  issues: Issue[],
  options: { contextLoaded?: boolean; metadataPath?: string } = {}
): Issue[] {
  const meta = loadMetadata(options.metadataPath);
  if (!meta) return issues;

  const contextSet = new Set(meta.contextDependentRules);
  const upgrade = meta.contextUpgradeConfidence;

  return issues.map(issue => {
    const ruleMeta = meta.rules[issue.ruleCode];
    if (!ruleMeta) return issue;

    let confidence = ruleMeta.confidence;
    // 上下文已加载时，上下文相关规则的 confidence 升级
    if (options.contextLoaded && contextSet.has(issue.ruleCode)) {
      confidence = upgrade[confidence] ?? 'high';
    }

    return {
      ...issue,
      confidence,
      autoFixable: ruleMeta.autoFixable,
      runtimeRisk: ruleMeta.runtimeRisk,
      suggestedOwner: ruleMeta.suggestedOwner,
    };
  });
}
