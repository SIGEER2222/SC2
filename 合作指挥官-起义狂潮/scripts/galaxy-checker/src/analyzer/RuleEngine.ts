// src/analyzer/RuleEngine.ts
import { readFileSync } from 'node:fs';
import { resolveDataFile } from '../dataPath.js';
import type { Issue, Severity } from '../types.js';
import { parse } from '../parser/index.js';
import type { Node } from '../parser/ast.js';

export interface RuleConfig {
  severity: Severity | 'off';
  message?: string;
}

export interface RuleDefinition {
  code: string;
  severity: Severity | 'off';
  message: string;
}

export interface RulesFile {
  version: string;
  rules: Record<string, RuleConfig>;
  nativeBlacklistFile?: string;
  globalSymbolGlobs?: string[];
  nativeLibPath?: string;
}

const DEFAULT_RULES_PATH = resolveDataFile('project-rules.json');

const DEFAULT_MESSAGE: Record<string, string> = {
  SEM_VOID_IN_CONDITION: 'void 返回函数不能用在条件表达式',
  XLIB_DISALLOWED_NATIVE: '调用了不允许的 native 函数',
  XLIB_DISCOURAGED_NATIVE: '调用了项目不推荐的 native 函数',
  PROJ_UTF8_BOM: '文件含 UTF-8 BOM',
  PROJ_ENCODING_INVALID: '文件编码非 UTF-8',
};

export class RuleEngine {
  private rules: Map<string, RuleDefinition> = new Map();

  constructor(rulesFile?: RulesFile | string) {
    let file: RulesFile;
    if (!rulesFile) {
      file = JSON.parse(readFileSync(DEFAULT_RULES_PATH, 'utf-8'));
    } else if (typeof rulesFile === 'string') {
      file = JSON.parse(readFileSync(rulesFile, 'utf-8'));
    } else {
      file = rulesFile;
    }

    for (const [code, cfg] of Object.entries(file.rules)) {
      this.rules.set(code, {
        code,
        severity: cfg.severity,
        message: cfg.message ?? DEFAULT_MESSAGE[code] ?? code,
      });
    }
  }

  getRule(code: string): RuleDefinition | undefined {
    // 未配置的规则返回 off（而非 undefined），便于调用方统一处理
    return this.rules.get(code) ?? { code, severity: 'off', message: code };
  }

  getEnabledRules(): RuleDefinition[] {
    return Array.from(this.rules.values()).filter(r => r.severity !== 'off');
  }

  isRuleEnabled(code: string): boolean {
    const r = this.rules.get(code);
    return r !== undefined && r.severity !== 'off';
  }

  makeIssue(
    code: string,
    file: string,
    line: number,
    column: number,
    overrideMessage?: string
  ): Issue | null {
    const rule = this.rules.get(code);
    if (!rule || rule.severity === 'off') return null;
    return {
      file,
      line,
      column,
      ruleCode: code,
      severity: rule.severity as Severity,
      message: overrideMessage ?? rule.message,
    };
  }
}

// parsed 可传入已解析结果，避免与语义分析重复 parse（大文件 parse 是主要耗时）
export function checkRules(
  source: string,
  filename: string,
  parsed?: { ast: Node; errors: Issue[] }
): Issue[] {
  const { errors } = parsed ?? parse(source, filename);
  return [...errors];
}
