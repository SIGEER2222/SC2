// src/analyzer/SemanticAnalyzer.ts
import { parse } from '../parser/index.js';
import { SymbolTable, Scope } from './SymbolTable.js';
import { RuleEngine } from './RuleEngine.js';
import { NativeFunctionTable } from './NativeFunctionTable.js';
import type { Issue } from '../types.js';
import type * as ast from '../parser/ast.js';

export function analyze(
  source: string,
  filename: string,
  globalTable?: SymbolTable,
  nativeTable?: NativeFunctionTable,
  engine?: RuleEngine
): Issue[] {
  const { ast: program, errors } = parse(source, filename);
  const issues: Issue[] = [...errors];

  const eng = engine ?? new RuleEngine();
  const table = globalTable ?? new SymbolTable();

  // 第一遍：收集顶层声明
  for (const decl of program.body) {
    collectTopLevel(decl, table, eng, filename, issues);
  }

  // 第二遍：分析函数体
  for (const decl of program.body) {
    if (decl.type === 'FunctionDeclaration' && decl.body) {
      analyzeFunction(decl, table, nativeTable, eng, filename, issues);
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
  switch (decl.type) {
    case 'FunctionDeclaration':
      table.declareFunction(
        {
          name: decl.name,
          returnType: decl.returnType,
          params: decl.params.map(p => ({ type: p.type, name: p.name })),
          isNative: decl.isNative,
        },
        () => {
          if (engine.isRuleEnabled('SEM_DUPLICATE_DECLARATION')) {
            issues.push(
              engine.makeIssue(
                'SEM_DUPLICATE_DECLARATION',
                filename,
                (decl as any).start?.line ?? 0,
                (decl as any).start?.column ?? 0,
                `函数 '${decl.name}' 重复定义`
              )!
            );
          }
        }
      );
      break;
    case 'VariableDeclaration':
      table.declareGlobalVariable(decl.varType, decl.name, decl.isArray, () => {
        if (engine.isRuleEnabled('SEM_DUPLICATE_DECLARATION')) {
          issues.push(
            engine.makeIssue(
              'SEM_DUPLICATE_DECLARATION',
              filename,
              (decl as any).start?.line ?? 0,
              (decl as any).start?.column ?? 0,
              `变量 '${decl.name}' 重复定义`
            )!
          );
        }
      });
      break;
  }
}

function analyzeFunction(
  fn: ast.FunctionDeclaration,
  table: SymbolTable,
  nativeTable: NativeFunctionTable | undefined,
  engine: RuleEngine,
  filename: string,
  issues: Issue[]
): void {
  const scope = table.createFunctionScope();
  for (const p of fn.params) {
    scope.declareVariable(p.type, p.name, p.isArray, () => {
      if (engine.isRuleEnabled('SEM_DUPLICATE_DECLARATION')) {
        issues.push(
          engine.makeIssue(
            'SEM_DUPLICATE_DECLARATION',
            filename,
            (p as any).start?.line ?? 0,
            (p as any).start?.column ?? 0,
            `参数 '${p.name}' 重复定义`
          )!
        );
      }
    });
  }

  if (fn.body) {
    walkStatements(fn.body, fn, scope, table, nativeTable, engine, filename, issues);
  }
}

function walkStatements(
  stmt: ast.Statement,
  fn: ast.FunctionDeclaration,
  scope: Scope,
  table: SymbolTable,
  nativeTable: NativeFunctionTable | undefined,
  engine: RuleEngine,
  filename: string,
  issues: Issue[]
): void {
  if (!stmt) return;
  switch (stmt.type) {
    case 'VariableDeclaration':
      scope.declareVariable(stmt.varType, stmt.name, stmt.isArray, () => {
        if (engine.isRuleEnabled('SEM_DUPLICATE_DECLARATION')) {
          issues.push(
            engine.makeIssue(
              'SEM_DUPLICATE_DECLARATION',
              filename,
              (stmt as any).start?.line ?? 0,
              (stmt as any).start?.column ?? 0,
              `变量 '${stmt.name}' 重复定义`
            )!
          );
        }
      });
      if (stmt.init) checkExpression(stmt.init, scope, table, nativeTable, engine, filename, issues);
      break;
    case 'ExpressionStatement':
      checkExpression(stmt.expression, scope, table, nativeTable, engine, filename, issues);
      break;
    case 'IfStatement':
      checkExpression(stmt.test, scope, table, nativeTable, engine, filename, issues);
      checkVoidInCondition(stmt.test, table, engine, filename, issues);
      walkStatements(stmt.consequent, fn, scope, table, nativeTable, engine, filename, issues);
      if (stmt.alternate) walkStatements(stmt.alternate, fn, scope, table, nativeTable, engine, filename, issues);
      break;
    case 'WhileStatement':
      checkExpression(stmt.test, scope, table, nativeTable, engine, filename, issues);
      checkVoidInCondition(stmt.test, table, engine, filename, issues);
      walkStatements(stmt.body, fn, scope, table, nativeTable, engine, filename, issues);
      break;
    case 'ForStatement': {
      const forScope = scope.createChild();
      if (stmt.init) walkStatements(stmt.init, fn, forScope, table, nativeTable, engine, filename, issues);
      if (stmt.test) {
        checkExpression(stmt.test, forScope, table, nativeTable, engine, filename, issues);
        checkVoidInCondition(stmt.test, table, engine, filename, issues);
      }
      if (stmt.update) checkExpression(stmt.update, forScope, table, nativeTable, engine, filename, issues);
      walkStatements(stmt.body, fn, forScope, table, nativeTable, engine, filename, issues);
      break;
    }
    case 'ReturnStatement': {
      if (stmt.argument && fn.returnType !== 'void') {
        const t = inferType(stmt.argument, scope);
        if (t && t !== fn.returnType && engine.isRuleEnabled('SEM_RETURN_TYPE_MISMATCH')) {
          issues.push(
            engine.makeIssue('SEM_RETURN_TYPE_MISMATCH', filename,
              (stmt as any).start?.line ?? 0, (stmt as any).start?.column ?? 0,
              `return 类型应为 ${fn.returnType}，实际 ${t}`)!
          );
        }
      }
      if (stmt.argument) checkExpression(stmt.argument, scope, table, nativeTable, engine, filename, issues);
      break;
    }
    case 'BlockStatement': {
      const blockScope = scope.createChild();
      for (const s of stmt.body) {
        walkStatements(s, fn, blockScope, table, nativeTable, engine, filename, issues);
      }
      break;
    }
  }
}

function checkExpression(
  expr: ast.Expression,
  scope: Scope,
  table: SymbolTable,
  nativeTable: NativeFunctionTable | undefined,
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
      checkExpression(expr.left, scope, table, nativeTable, engine, filename, issues);
      checkExpression(expr.right, scope, table, nativeTable, engine, filename, issues);
      break;
    case 'UnaryExpression':
      checkExpression(expr.argument, scope, table, nativeTable, engine, filename, issues);
      break;
    case 'AssignmentExpression':
      checkExpression(expr.left, scope, table, nativeTable, engine, filename, issues);
      checkExpression(expr.right, scope, table, nativeTable, engine, filename, issues);
      if (expr.left.type === 'Identifier') {
        const lv = scope.lookupVariable(expr.left.name);
        if (lv) {
          const rt = inferType(expr.right, scope);
          if (rt && rt !== lv.varType && engine.isRuleEnabled('SEM_ASSIGNMENT_TYPE_MISMATCH')) {
            issues.push(
              engine.makeIssue('SEM_ASSIGNMENT_TYPE_MISMATCH', filename,
                (expr as any).start?.line ?? 0, (expr as any).start?.column ?? 0,
                `变量 ${lv.name} 类型 ${lv.varType}，赋值类型 ${rt}`)!
            );
          }
        }
      }
      break;
    case 'CallExpression':
      if (expr.callee.type === 'Identifier') {
        const fnName = expr.callee.name;
        const fn = scope.lookupFunction(fnName);
        if (fn) {
          // 参数数量检查
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
        } else if (nativeTable?.isDisallowed(fnName) && engine.isRuleEnabled('XLIB_DISALLOWED_NATIVE')) {
          // 黑名单 native 函数
          const note = nativeTable.getNote(fnName);
          issues.push(
            engine.makeIssue(
              'XLIB_DISALLOWED_NATIVE',
              filename,
              (expr as any).start?.line ?? 0,
              (expr as any).start?.column ?? 0,
              `调用了不允许的 native 函数 '${fnName}()'${note ? ' (' + note + ')' : ''}`
            )!
          );
        } else if (fnName.startsWith('lib') && fnName.includes('_') && engine.isRuleEnabled('XLIB_UNDEFINED_CROSS_REF')) {
          // 跨库引用未定义（libXXX_ 形式），替代 SEM_UNDECLARED_FUNCTION 更精确
          issues.push(
            engine.makeIssue(
              'XLIB_UNDEFINED_CROSS_REF',
              filename,
              (expr as any).start?.line ?? 0,
              (expr as any).start?.column ?? 0,
              `跨库引用未定义 '${fnName}()'`
            )!
          );
        } else if (engine.isRuleEnabled('SEM_UNDECLARED_FUNCTION')) {
          // 普通未声明函数
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
      } else {
        // callee 非 Identifier（如 MemberExpression obj.method()），递归检查
        checkExpression(expr.callee, scope, table, nativeTable, engine, filename, issues);
      }
      for (const a of expr.arguments) {
        checkExpression(a, scope, table, nativeTable, engine, filename, issues);
      }
      break;
    case 'MemberExpression':
      checkExpression(expr.object, scope, table, nativeTable, engine, filename, issues);
      break;
    case 'IndexExpression':
      checkExpression(expr.object, scope, table, nativeTable, engine, filename, issues);
      checkExpression(expr.index, scope, table, nativeTable, engine, filename, issues);
      break;
    case 'ConditionalExpression':
      checkExpression(expr.test, scope, table, nativeTable, engine, filename, issues);
      checkExpression(expr.consequent, scope, table, nativeTable, engine, filename, issues);
      checkExpression(expr.alternate, scope, table, nativeTable, engine, filename, issues);
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

// 粗粒度类型推断：返回 Galaxy 类型字符串或 null（无法推断时跳过检查）
function inferType(expr: ast.Expression, scope: Scope): string | null {
  switch (expr.type) {
    case 'Literal':
      return expr.literalType === 'integer' ? 'int'
        : expr.literalType === 'fixed' ? 'fixed'
        : expr.literalType === 'string' ? 'string'
        : expr.literalType === 'char' ? 'string'
        : expr.literalType === 'bool' ? 'bool'
        : null;
    case 'Identifier': {
      const v = scope.lookupVariable(expr.name);
      return v?.varType ?? null;
    }
    case 'CallExpression':
      if (expr.callee.type === 'Identifier') {
        const fn = scope.lookupFunction(expr.callee.name);
        return fn?.returnType ?? null;
      }
      return null;
    case 'BinaryExpression':
      if (['==', '!=', '<', '>', '<=', '>=', '&&', '||'].includes(expr.operator)) return 'bool';
      if (expr.operator === '+') {
        const lt = inferType(expr.left, scope);
        const rt = inferType(expr.right, scope);
        if (lt === 'string' || rt === 'string') return 'string';
      }
      return inferType(expr.left, scope) ?? inferType(expr.right, scope);
    case 'UnaryExpression':
      if (expr.operator === '!') return 'bool';
      return inferType(expr.argument, scope);
    default:
      return null;
  }
}
