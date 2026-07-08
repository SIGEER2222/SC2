// src/analyzer/RuleEngine.ts
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { Issue, Severity } from '../types.js';
import { parse } from '../parser/index.js';
import type { Node, ContinueStatement, VariableDeclaration } from '../parser/ast.js';

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

const DEFAULT_RULES_PATH = join(
  dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
  'data',
  'project-rules.json'
);

const DEFAULT_MESSAGE: Record<string, string> = {
  SYNTAX_NO_CONTINUE: 'Galaxy 不支持 continue 语句',
  SYNTAX_NO_LOCAL_INIT_ASSIGN: 'Galaxy 局部变量不能用 = 初始化',
  SEM_VOID_IN_CONDITION: 'void 返回函数不能用在条件表达式',
  XLIB_DISALLOWED_NATIVE: '调用了不允许的 native 函数',
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

export function checkRules(source: string, filename: string): Issue[] {
  const engine = new RuleEngine();
  const { ast, errors } = parse(source, filename);
  const issues: Issue[] = [...errors];

  walk(ast, (node, parent) => {
    if (node.type === 'ContinueStatement' && engine.isRuleEnabled('SYNTAX_NO_CONTINUE')) {
      const n = node as ContinueStatement & { start?: { line: number; column: number } };
      issues.push(
        engine.makeIssue(
          'SYNTAX_NO_CONTINUE',
          filename,
          n.start?.line ?? 0,
          n.start?.column ?? 0
        )!
      );
    }

    if (
      node.type === 'VariableDeclaration' &&
      parent?.type !== 'Program' &&
      (node as VariableDeclaration).init !== null &&
      engine.isRuleEnabled('SYNTAX_NO_LOCAL_INIT_ASSIGN')
    ) {
      const n = node as VariableDeclaration & { start?: { line: number; column: number } };
      issues.push(
        engine.makeIssue(
          'SYNTAX_NO_LOCAL_INIT_ASSIGN',
          filename,
          n.start?.line ?? 0,
          n.start?.column ?? 0
        )!
      );
    }
  });

  return issues;
}

function walk(node: Node, cb: (n: Node, parent: Node | null) => void, parent: Node | null = null) {
  if (!node || typeof node !== 'object') return;
  cb(node, parent);
  for (const key of Object.keys(node)) {
    if (key === 'type' || key === 'start' || key === 'end') continue;
    const val = (node as any)[key];
    if (Array.isArray(val)) {
      for (const child of val) {
        if (child && typeof child === 'object' && typeof child.type === 'string') {
          walk(child, cb, node);
        }
      }
    } else if (val && typeof val === 'object' && typeof val.type === 'string') {
      walk(val, cb, node);
    }
  }
}
