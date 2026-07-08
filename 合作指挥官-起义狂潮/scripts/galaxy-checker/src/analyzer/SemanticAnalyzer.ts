// src/analyzer/SemanticAnalyzer.ts
import { parse } from '../parser/index.js';
import { SymbolTable, Scope } from './SymbolTable.js';
import { RuleEngine } from './RuleEngine.js';
import type { Issue } from '../types.js';
import type * as ast from '../parser/ast.js';

export function analyze(
  source: string,
  filename: string,
  globalTable?: SymbolTable
): Issue[] {
  const { ast: program, errors } = parse(source, filename);
  const issues: Issue[] = [...errors];

  const engine = new RuleEngine();
  const table = globalTable ?? new SymbolTable();

  // 第一遍：收集顶层声明
  for (const decl of program.body) {
    collectTopLevel(decl, table, engine, filename, issues);
  }

  // 第二遍：分析函数体
  for (const decl of program.body) {
    if (decl.type === 'FunctionDeclaration' && decl.body) {
      analyzeFunction(decl, table, engine, filename, issues);
    }
  }

  return issues;
}

function collectTopLevel(
  decl: ast.TopLevelDeclaration,
  table: SymbolTable,
  engine: RuleEngine,
  filename: string,
  issues: Issue[]
): void {
  try {
    switch (decl.type) {
      case 'FunctionDeclaration':
        table.declareFunction({
          name: decl.name,
          returnType: decl.returnType,
          params: decl.params.map(p => ({ type: p.type, name: p.name })),
          isNative: decl.isNative,
        });
        break;
      case 'VariableDeclaration':
        table.declareGlobalVariable(decl.varType, decl.name, decl.isArray);
        break;
    }
  } catch {
    // 重复声明，Task 14 会细化处理，这里先忽略避免崩溃
  }
}

function analyzeFunction(
  fn: ast.FunctionDeclaration,
  table: SymbolTable,
  engine: RuleEngine,
  filename: string,
  issues: Issue[]
): void {
  const scope = table.createFunctionScope();
  try {
    for (const p of fn.params) {
      scope.declareVariable(p.type, p.name, p.isArray);
    }
  } catch {
    // 参数重复，忽略
  }

  if (fn.body) {
    walkStatements(fn.body, scope, table, engine, filename, issues);
  }
}

function walkStatements(
  stmt: ast.Statement,
  scope: Scope,
  table: SymbolTable,
  engine: RuleEngine,
  filename: string,
  issues: Issue[]
): void {
  if (!stmt) return;
  switch (stmt.type) {
    case 'VariableDeclaration':
      try { scope.declareVariable(stmt.varType, stmt.name, stmt.isArray); } catch {}
      if (stmt.init) checkExpression(stmt.init, scope, table, engine, filename, issues);
      break;
    case 'ExpressionStatement':
      checkExpression(stmt.expression, scope, table, engine, filename, issues);
      break;
    case 'IfStatement':
      checkExpression(stmt.test, scope, table, engine, filename, issues);
      checkVoidInCondition(stmt.test, table, engine, filename, issues);
      walkStatements(stmt.consequent, scope, table, engine, filename, issues);
      if (stmt.alternate) walkStatements(stmt.alternate, scope, table, engine, filename, issues);
      break;
    case 'WhileStatement':
      checkExpression(stmt.test, scope, table, engine, filename, issues);
      checkVoidInCondition(stmt.test, table, engine, filename, issues);
      walkStatements(stmt.body, scope, table, engine, filename, issues);
      break;
    case 'ForStatement': {
      const forScope = scope.createChild();
      if (stmt.init) walkStatements(stmt.init, forScope, table, engine, filename, issues);
      if (stmt.test) {
        checkExpression(stmt.test, forScope, table, engine, filename, issues);
        checkVoidInCondition(stmt.test, table, engine, filename, issues);
      }
      if (stmt.update) checkExpression(stmt.update, forScope, table, engine, filename, issues);
      walkStatements(stmt.body, forScope, table, engine, filename, issues);
      break;
    }
    case 'ReturnStatement':
      if (stmt.argument) checkExpression(stmt.argument, scope, table, engine, filename, issues);
      break;
    case 'BlockStatement': {
      const blockScope = scope.createChild();
      for (const s of stmt.body) {
        walkStatements(s, blockScope, table, engine, filename, issues);
      }
      break;
    }
  }
}

function checkExpression(
  expr: ast.Expression,
  scope: Scope,
  table: SymbolTable,
  engine: RuleEngine,
  filename: string,
  issues: Issue[]
): void {
  if (!expr) return;
  switch (expr.type) {
    case 'Identifier':
      if (!scope.lookupVariable(expr.name)) {
        if (engine.isRuleEnabled('SEM_UNDECLARED_VARIABLE')) {
          issues.push(
            engine.makeIssue(
              'SEM_UNDECLARED_VARIABLE',
              filename,
              (expr as any).start?.line ?? 0,
              (expr as any).start?.column ?? 0,
              `未声明的变量 '${expr.name}'`
            )!
          );
        }
      }
      break;
    case 'BinaryExpression':
      checkExpression(expr.left, scope, table, engine, filename, issues);
      checkExpression(expr.right, scope, table, engine, filename, issues);
      break;
    case 'UnaryExpression':
      checkExpression(expr.argument, scope, table, engine, filename, issues);
      break;
    case 'AssignmentExpression':
      checkExpression(expr.left, scope, table, engine, filename, issues);
      checkExpression(expr.right, scope, table, engine, filename, issues);
      break;
    case 'CallExpression':
      if (expr.callee.type === 'Identifier') {
        const fnName = expr.callee.name;
        const fn = scope.lookupFunction(fnName);
        if (!fn && engine.isRuleEnabled('SEM_UNDECLARED_FUNCTION')) {
          issues.push(
            engine.makeIssue(
              'SEM_UNDECLARED_FUNCTION',
              filename,
              (expr as any).start?.line ?? 0,
              (expr as any).start?.column ?? 0,
              `未声明的函数 '${fnName}()'`
            )!
          );
        }
        if (fn) {
          const expected = fn.params.length;
          const actual = expr.arguments.length;
          if (expected !== actual && engine.isRuleEnabled('SEM_ARGUMENT_COUNT_MISMATCH')) {
            issues.push(
              engine.makeIssue(
                'SEM_ARGUMENT_COUNT_MISMATCH',
                filename,
                (expr as any).start?.line ?? 0,
                (expr as any).start?.column ?? 0,
                `函数 '${fnName}()' 期望 ${expected} 个参数，实际 ${actual} 个`
              )!
            );
          }
        }
      } else {
        // callee 非 Identifier（如 MemberExpression obj.method()），递归检查
        checkExpression(expr.callee, scope, table, engine, filename, issues);
      }
      for (const a of expr.arguments) {
        checkExpression(a, scope, table, engine, filename, issues);
      }
      break;
    case 'MemberExpression':
      checkExpression(expr.object, scope, table, engine, filename, issues);
      break;
    case 'IndexExpression':
      checkExpression(expr.object, scope, table, engine, filename, issues);
      checkExpression(expr.index, scope, table, engine, filename, issues);
      break;
    case 'ConditionalExpression':
      checkExpression(expr.test, scope, table, engine, filename, issues);
      checkExpression(expr.consequent, scope, table, engine, filename, issues);
      checkExpression(expr.alternate, scope, table, engine, filename, issues);
      break;
  }
}

function checkVoidInCondition(
  expr: ast.Expression,
  table: SymbolTable,
  engine: RuleEngine,
  filename: string,
  issues: Issue[]
): void {
  if (expr.type === 'CallExpression' && expr.callee.type === 'Identifier') {
    const fn = table.lookupFunction(expr.callee.name);
    if (fn && fn.returnType === 'void' && engine.isRuleEnabled('SEM_VOID_IN_CONDITION')) {
      issues.push(
        engine.makeIssue(
          'SEM_VOID_IN_CONDITION',
          filename,
          (expr as any).start?.line ?? 0,
          (expr as any).start?.column ?? 0,
          `void 返回函数 '${fn.name}()' 不能用在条件表达式`
        )!
      );
    }
  }
}
