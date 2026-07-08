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
  const cst = parser.program();
  const parserErrors = parser.errors;

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

  // Chevrotain 的 program 规则返回值就是 AST（方式 A）
  const ast = cst as unknown as Program;

  return { ast, errors, cst };
}
