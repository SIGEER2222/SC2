// src/analyzer/SemanticAnalyzer.ts
import { parse } from '../parser/index.js';
import { SymbolTable, Scope } from './SymbolTable.js';
import { RuleEngine } from './RuleEngine.js';
import { NativeFunctionTable } from './NativeFunctionTable.js';
import type { Issue, CatalogDb } from '../types.js';
import type * as ast from '../parser/ast.js';

// 分析上下文：目录模式（外部全局符号表）下已知的本地库前缀集合。
// 引用完全未知库（如游戏自带 libNtve）时跳过报错，避免海量误报。
interface AnalyzeContext {
  hasGlobalTable: boolean;
  libPrefixes: Set<string>;
  catalogDb?: CatalogDb;
}

const LIB_PREFIX_RE = /^(lib[0-9A-Za-z]*)_/;

// 游戏自带常量（c_ 前缀，定义在 NativeLib/natives.galaxy 中，本地不可见）
function isGameConstant(name: string): boolean {
  return name.startsWith('c_');
}

// Galaxy 隐式类型放宽：int 可赋给 fixed（字面量与表达式均会自动提升）
function isAssignable(from: string, to: string): boolean {
  if (from === to) return true;
  if (from === 'int' && to === 'fixed') return true;
  return false;
}

export function analyze(
  source: string,
  filename: string,
  globalTable?: SymbolTable,
  nativeTable?: NativeFunctionTable,
  engine?: RuleEngine,
  parsed?: { ast: ast.Program; errors: Issue[] },
  catalogDb?: CatalogDb
): Issue[] {
  const { ast: program, errors } = parsed ?? parse(source, filename);
  const issues: Issue[] = [...errors];

  const eng = engine ?? new RuleEngine();
  const table = globalTable ?? new SymbolTable();

  // 第一遍：收集顶层声明。
  // 若使用外部全局符号表（目录扫描），本文件的顶层符号已被 ProjectLoader 收集过，
  // 再次声明必然"重复"，此时静默跳过而非误报 SEM_DUPLICATE_DECLARATION。
  const reportTopLevelDuplicates = globalTable === undefined;
  for (const decl of program.body) {
    collectTopLevel(decl, table, eng, filename, issues, reportTopLevelDuplicates);
  }

  // 已知本地库前缀（libXXX_）：用于区分本地跨库引用与外部库（游戏/其他 Mod）
  const libPrefixes = new Set<string>();
  const globalScope = table.getGlobalScope();
  for (const n of [...globalScope.getOwnFunctionNames(), ...globalScope.getOwnVariableNames()]) {
    const m = n.match(LIB_PREFIX_RE);
    if (m) libPrefixes.add(m[1]);
  }
  const ctx: AnalyzeContext = { hasGlobalTable: globalTable !== undefined, libPrefixes, catalogDb };

  // 第二遍：分析函数体
  for (const decl of program.body) {
    if (decl.type === 'FunctionDeclaration' && decl.body) {
      analyzeFunction(decl, table, nativeTable, eng, filename, issues, ctx);
    }
  }

  return issues;
}

// 外部库引用（前缀完全不在本地符号表中）在目录模式下跳过检查
function isExternalLibRef(name: string, ctx: AnalyzeContext): boolean {
  if (!ctx.hasGlobalTable) return false;
  const m = name.match(LIB_PREFIX_RE);
  return m !== null && !ctx.libPrefixes.has(m[1]);
}

function collectTopLevel(
  decl: ast.TopLevelDeclaration,
  table: SymbolTable,
  engine: RuleEngine,
  filename: string,
  issues: Issue[],
  reportDuplicates = true
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
          if (reportDuplicates && engine.isRuleEnabled('SEM_DUPLICATE_DECLARATION')) {
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
        if (reportDuplicates && engine.isRuleEnabled('SEM_DUPLICATE_DECLARATION')) {
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
  issues: Issue[],
  ctx: AnalyzeContext
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
    walkStatements(fn.body, fn, scope, table, nativeTable, engine, filename, issues, ctx);
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
  issues: Issue[],
  ctx: AnalyzeContext
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
      if (stmt.init) checkExpression(stmt.init, scope, table, nativeTable, engine, filename, issues, ctx);
      break;
    case 'ExpressionStatement':
      checkExpression(stmt.expression, scope, table, nativeTable, engine, filename, issues, ctx);
      break;
    case 'IfStatement':
      checkExpression(stmt.test, scope, table, nativeTable, engine, filename, issues, ctx);
      checkVoidInCondition(stmt.test, table, engine, filename, issues);
      walkStatements(stmt.consequent, fn, scope, table, nativeTable, engine, filename, issues, ctx);
      if (stmt.alternate) walkStatements(stmt.alternate, fn, scope, table, nativeTable, engine, filename, issues, ctx);
      break;
    case 'WhileStatement':
    case 'DoWhileStatement':
      checkExpression(stmt.test, scope, table, nativeTable, engine, filename, issues, ctx);
      checkVoidInCondition(stmt.test, table, engine, filename, issues);
      walkStatements(stmt.body, fn, scope, table, nativeTable, engine, filename, issues, ctx);
      break;
    case 'ForStatement': {
      const forScope = scope.createChild();
      if (stmt.init) walkStatements(stmt.init, fn, forScope, table, nativeTable, engine, filename, issues, ctx);
      if (stmt.test) {
        checkExpression(stmt.test, forScope, table, nativeTable, engine, filename, issues, ctx);
        checkVoidInCondition(stmt.test, table, engine, filename, issues);
      }
      if (stmt.update) checkExpression(stmt.update, forScope, table, nativeTable, engine, filename, issues, ctx);
      walkStatements(stmt.body, fn, forScope, table, nativeTable, engine, filename, issues, ctx);
      break;
    }
    case 'ReturnStatement': {
      if (stmt.argument && fn.returnType !== 'void') {
        const t = inferType(stmt.argument, scope, nativeTable);
        if (t && !isAssignable(t, fn.returnType) && engine.isRuleEnabled('SEM_RETURN_TYPE_MISMATCH')) {
          issues.push(
            engine.makeIssue('SEM_RETURN_TYPE_MISMATCH', filename,
              (stmt as any).start?.line ?? 0, (stmt as any).start?.column ?? 0,
              `return 类型应为 ${fn.returnType}，实际 ${t}`)!
          );
        }
      }
      if (stmt.argument) checkExpression(stmt.argument, scope, table, nativeTable, engine, filename, issues, ctx);
      break;
    }
    case 'BlockStatement': {
      const blockScope = scope.createChild();
      for (const s of stmt.body) {
        walkStatements(s, fn, blockScope, table, nativeTable, engine, filename, issues, ctx);
      }
      break;
    }
  }
}

// ---------------------------------------------------------------------------
// catalog 引用校验
// ---------------------------------------------------------------------------
// galaxy 脚本中常把 catalog ID 作为字符串字面量传给 native 函数（如单位类型、
// 升级 ID）。这些 ID 必须在 GameData XML 中存在，否则运行时会静默失败
// （单位不生成、属性查询返回空等）。此校验通过预导出的 catalog ID 集合
// 检查字符串字面量是否指向有效条目，能在不启动游戏的情况下发现 mod 依赖
// 缺失或 ID 拼写错误。

// native 函数名 → 哪些位置的参数是 catalog ID（0-based），以及对应的 catalog 类型
// 'any' 表示跨所有已导出的 catalog 类型查找（适用于 CatalogField* 系列，
//   其 catalog 类型由 int 参数决定，无法静态解析）
type CatalogRefSpec = { pos: number; catalog: keyof import('../types.js').CatalogDb | 'any' };
const CATALOG_REF_FUNCS: Record<string, CatalogRefSpec[]> = {
  // 单位类型字符串（Unit catalog）
  UnitCreate: [{ pos: 1, catalog: 'Unit' }],
  UnitTypeFromString: [{ pos: 0, catalog: 'Unit' }],
  UnitTypeGetName: [{ pos: 0, catalog: 'Unit' }],
  UnitTypeGetGenderCode: [{ pos: 0, catalog: 'Unit' }],
  UnitTypeGetProperty: [{ pos: 0, catalog: 'Unit' }],
  UnitTypeGetCost: [{ pos: 0, catalog: 'Unit' }],
  UnitTypeTestFlag: [{ pos: 0, catalog: 'Unit' }],
  UnitTypeTestAttribute: [{ pos: 0, catalog: 'Unit' }],
  UnitTypeIsAffectedByUpgrade: [{ pos: 0, catalog: 'Unit' }, { pos: 1, catalog: 'Upgrade' }],
  UnitTypeAnimationLoad: [{ pos: 0, catalog: 'Unit' }],
  // 官方库包装的单位创建函数（libNtve_gf_*）
  libNtve_gf_CreateUnitsWithDefaultFacing: [{ pos: 1, catalog: 'Unit' }],
  // Catalog 系列的 entry 参数（第 2 个参数，index=1）
  CatalogFieldValueGet: [{ pos: 1, catalog: 'any' }],
  CatalogFieldValueGetAsInt: [{ pos: 1, catalog: 'any' }],
  CatalogFieldValueGetFlagsAsInt: [{ pos: 1, catalog: 'any' }],
  CatalogFieldValueSet: [{ pos: 1, catalog: 'any' }],
  CatalogFieldValueModify: [{ pos: 1, catalog: 'any' }],
  CatalogFieldValueCount: [{ pos: 1, catalog: 'any' }],
};

function checkCatalogRef(
  expr: ast.CallExpression,
  ctx: AnalyzeContext,
  engine: RuleEngine,
  filename: string,
  issues: Issue[]
): void {
  if (!ctx.catalogDb) return;
  if (!engine.isRuleEnabled('CATALOG_INVALID_UNIT_REF')) return;
  if (expr.callee.type !== 'Identifier') return;
  const specs = CATALOG_REF_FUNCS[expr.callee.name];
  if (!specs) return;

  for (const spec of specs) {
    const arg = expr.arguments[spec.pos];
    if (!arg || arg.type !== 'Literal' || arg.literalType !== 'string') continue;
    const id = arg.value as string;
    if (!id) continue;

    const exists = spec.catalog === 'any'
      ? Object.values(ctx.catalogDb).some(set => set?.has(id) ?? false)
      : ctx.catalogDb[spec.catalog]?.has(id) ?? false;

    if (!exists) {
      const catLabel = spec.catalog === 'any' ? 'catalog' : spec.catalog;
      issues.push(
        engine.makeIssue(
          'CATALOG_INVALID_UNIT_REF',
          filename,
          (arg as any).start?.line ?? (expr as any).start?.line ?? 0,
          (arg as any).start?.column ?? (expr as any).start?.column ?? 0,
          `字符串 '${id}' 在 ${catLabel} 中找不到，可能是 mod 依赖缺失或 ID 拼写错误（函数 ${expr.callee.name}）`
        )!
      );
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
  issues: Issue[],
  ctx: AnalyzeContext
): void {
  if (!expr) return;
  switch (expr.type) {
    case 'Identifier':
      if (!scope.lookupVariable(expr.name)) {
        // 游戏常量（c_*）与外部库符号无法本地验证，跳过
        if (isGameConstant(expr.name) || isExternalLibRef(expr.name, ctx)) break;
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
      checkExpression(expr.left, scope, table, nativeTable, engine, filename, issues, ctx);
      checkExpression(expr.right, scope, table, nativeTable, engine, filename, issues, ctx);
      // text 类型不能用 + 拼接（Galaxy 限制：只能 string + string）
      // 检测 text + X、X + text 报 SEM_INVALID_TEXT_CONCAT
      if (expr.operator === '+' && engine.isRuleEnabled('SEM_INVALID_TEXT_CONCAT')) {
        const lt = inferType(expr.left, scope, nativeTable);
        const rt = inferType(expr.right, scope, nativeTable);
        if (lt === 'text' || rt === 'text') {
          // 优先用 BinaryExpression 的运算符位置；缺失时回退到 left 操作数位置
          const binStart = (expr as any).start;
          const leftStart = (expr.left as any).start;
          const line = binStart?.line || leftStart?.line || 0;
          const column = binStart?.column || leftStart?.column || 0;
          issues.push(
            engine.makeIssue(
              'SEM_INVALID_TEXT_CONCAT',
              filename,
              line,
              column,
              `text 类型不能用 + 拼接，请用 string 拼接后再用 StringToText() 转换（${lt ?? '?'} + ${rt ?? '?'}）`
            )!
          );
        }
      }
      break;
    case 'UnaryExpression':
      checkExpression(expr.argument, scope, table, nativeTable, engine, filename, issues, ctx);
      break;
    case 'AssignmentExpression':
      checkExpression(expr.left, scope, table, nativeTable, engine, filename, issues, ctx);
      checkExpression(expr.right, scope, table, nativeTable, engine, filename, issues, ctx);
      if (expr.left.type === 'Identifier') {
        const lv = scope.lookupVariable(expr.left.name);
        if (lv) {
          const rt = inferType(expr.right, scope, nativeTable);
          if (rt && !isAssignable(rt, lv.varType) && engine.isRuleEnabled('SEM_ASSIGNMENT_TYPE_MISMATCH')) {
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
      // catalog 引用校验：检查传给 catalog native 的字符串字面量是否指向有效条目
      checkCatalogRef(expr, ctx, engine, filename, issues);
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
        } else if (nativeTable?.isNative(fnName)) {
          // 已知 native：只做参数数量对照
          const sig = nativeTable.lookup(fnName)!;
          if (sig.params.length !== expr.arguments.length && engine.isRuleEnabled('SEM_ARGUMENT_COUNT_MISMATCH')) {
            issues.push(
              engine.makeIssue(
                'SEM_ARGUMENT_COUNT_MISMATCH',
                filename,
                (expr as any).start?.line ?? 0,
                (expr as any).start?.column ?? 0,
                `native '${fnName}()' 期望 ${sig.params.length} 个参数，实际 ${expr.arguments.length} 个`
              )!
            );
          }
        } else if (fnName.startsWith('lib') && fnName.includes('_') && engine.isRuleEnabled('XLIB_UNDEFINED_CROSS_REF')) {
          // 跨库引用未定义（libXXX_ 形式），替代 SEM_UNDECLARED_FUNCTION 更精确。
          // 外部库（前缀不在本地符号表，如游戏自带 libNtve）无法验证，跳过。
          if (!isExternalLibRef(fnName, ctx)) {
            issues.push(
              engine.makeIssue(
                'XLIB_UNDEFINED_CROSS_REF',
                filename,
                (expr as any).start?.line ?? 0,
                (expr as any).start?.column ?? 0,
                `跨库引用未定义 '${fnName}()'`
              )!
            );
          }
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
        checkExpression(expr.callee, scope, table, nativeTable, engine, filename, issues, ctx);
      }
      for (const a of expr.arguments) {
        checkExpression(a, scope, table, nativeTable, engine, filename, issues, ctx);
      }
      break;
    case 'MemberExpression':
      checkExpression(expr.object, scope, table, nativeTable, engine, filename, issues, ctx);
      break;
    case 'IndexExpression':
      checkExpression(expr.object, scope, table, nativeTable, engine, filename, issues, ctx);
      checkExpression(expr.index, scope, table, nativeTable, engine, filename, issues, ctx);
      break;
    case 'ConditionalExpression':
      checkExpression(expr.test, scope, table, nativeTable, engine, filename, issues, ctx);
      checkExpression(expr.consequent, scope, table, nativeTable, engine, filename, issues, ctx);
      checkExpression(expr.alternate, scope, table, nativeTable, engine, filename, issues, ctx);
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
// nativeTable 可选：传入后可推断 native 函数调用（如 StringToText 返回 text）的返回类型
function inferType(expr: ast.Expression, scope: Scope, nativeTable?: NativeFunctionTable): string | null {
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
        // 优先查本地符号表，再查 native 表
        const fn = scope.lookupFunction(expr.callee.name);
        if (fn) return fn.returnType;
        const native = nativeTable?.lookup(expr.callee.name);
        return native?.returnType ?? null;
      }
      return null;
    case 'BinaryExpression':
      if (['==', '!=', '<', '>', '<=', '>=', '&&', '||'].includes(expr.operator)) return 'bool';
      if (expr.operator === '+') {
        const lt = inferType(expr.left, scope, nativeTable);
        const rt = inferType(expr.right, scope, nativeTable);
        // text 类型优先（text + X 实际非法，但推断为 text 便于上游规则检测）
        if (lt === 'text' || rt === 'text') return 'text';
        if (lt === 'string' || rt === 'string') return 'string';
      }
      return inferType(expr.left, scope, nativeTable) ?? inferType(expr.right, scope, nativeTable);
    case 'UnaryExpression':
      if (expr.operator === '!') return 'bool';
      return inferType(expr.argument, scope, nativeTable);
    default:
      return null;
  }
}
