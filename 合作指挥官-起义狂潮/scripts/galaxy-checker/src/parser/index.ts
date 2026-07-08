// src/parser/index.ts
import { tokenize } from '../lexer/tokens.js';
import { getParser } from './GalaxyParser.js';
import type { Program } from './ast.js';
import type { Issue } from '../types.js';

const parser = getParser();

export interface ParseResult {
  ast: Program;
  errors: Issue[];
  cst: any;
}

export function parse(source: string, filename: string = '<inline>'): ParseResult {
  const lexResult = tokenize(source);
  const errors: Issue[] = [];

  parser.input = lexResult;
  let cst: any;
  let parserErrors: any[] = [];
  try {
    cst = parser.program();
    parserErrors = parser.errors;
  } catch (e) {
    // parser 抛异常时（如 recovery 失败），构造空 program + error issue，
    // 避免整个 check 崩溃。linter 应容错：一个文件解析失败不应阻塞其他文件。
    cst = { type: 'Program', body: [] } as Program;
    errors.push({
      file: filename,
      line: 0,
      column: 0,
      ruleCode: 'SYNTAX_PARSE_ERROR',
      severity: 'error',
      message: `parser 内部错误: ${e instanceof Error ? e.message : String(e)}`,
    });
  } finally {
    // 清理单例 parser 运行时状态（RULE_STACK 等），避免跨调用状态污染。
    // 某文件让 parser 抛异常后若不 reset，后续 parse 会因残留状态出错。
    parser.reset();
  }

  for (const err of parserErrors) {
    errors.push({
      file: filename,
      line: err.token?.startLine ?? 0,
      column: err.token?.startColumn ?? 0,
      ruleCode: 'SYNTAX_PARSE_ERROR',
      severity: 'error',
      message: err.message,
    });
  }

  // Chevrotain 的 program 规则返回值就是 AST（方式 A）。
  // 若 recovery 失败导致 cst 为 undefined，构造空 program 兜底，避免下游崩溃。
  const ast = (cst ?? { type: 'Program', body: [] }) as unknown as Program;

  return { ast, errors, cst };
}
