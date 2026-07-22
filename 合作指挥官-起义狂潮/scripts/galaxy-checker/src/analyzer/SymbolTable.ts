// src/analyzer/SymbolTable.ts
import type { FunctionSignature } from '../types.js';

export interface VariableSymbol {
  name: string;
  varType: string;
  isArray: boolean;
  sourceFile?: string;
}

// 内部存储类型：FunctionSignature + 可选来源文件（用于跨文件重复声明检测）
type StoredFunction = FunctionSignature & { sourceFile?: string };

export class Scope {
  private vars = new Map<string, VariableSymbol>();
  private funcs = new Map<string, StoredFunction>();
  private children: Scope[] = [];

  constructor(public parent: Scope | null) {}

  declareVariable(varType: string, name: string, isArray = false, onDuplicate?: () => void, sourceFile?: string): void {
    if (this.vars.has(name)) {
      onDuplicate?.();
      return;
    }
    this.vars.set(name, { name, varType, isArray, sourceFile });
  }

  declareFunction(sig: FunctionSignature, onDuplicate?: () => void, sourceFile?: string): void {
    if (this.funcs.has(sig.name)) {
      onDuplicate?.();
      return;
    }
    this.funcs.set(sig.name, { ...sig, sourceFile });
  }

  lookupVariable(name: string): VariableSymbol | null {
    if (this.vars.has(name)) return this.vars.get(name)!;
    return this.parent?.lookupVariable(name) ?? null;
  }

  lookupFunction(name: string): FunctionSignature | null {
    if (this.funcs.has(name)) return this.funcs.get(name)!;
    return this.parent?.lookupFunction(name) ?? null;
  }

  // 查询全局作用域中符号的来源文件（用于区分同文件二次扫描与跨文件冲突）
  getVariableSourceFile(name: string): string | undefined {
    const v = this.vars.get(name);
    if (v) return v.sourceFile;
    return this.parent?.getVariableSourceFile(name);
  }

  getFunctionSourceFile(name: string): string | undefined {
    const f = this.funcs.get(name);
    if (f) return f.sourceFile;
    return this.parent?.getFunctionSourceFile(name);
  }

  createChild(): Scope {
    const c = new Scope(this);
    this.children.push(c);
    return c;
  }

  getOwnFunctionNames(): string[] {
    return [...this.funcs.keys()];
  }

  getOwnVariableNames(): string[] {
    return [...this.vars.keys()];
  }
}

export class SymbolTable {
  private global = new Scope(null);

  declareFunction(sig: FunctionSignature, onDuplicate?: () => void, sourceFile?: string): void {
    this.global.declareFunction(sig, onDuplicate, sourceFile);
  }

  declareGlobalVariable(varType: string, name: string, isArray = false, onDuplicate?: () => void, sourceFile?: string): void {
    this.global.declareVariable(varType, name, isArray, onDuplicate, sourceFile);
  }

  lookupFunction(name: string): FunctionSignature | null {
    return this.global.lookupFunction(name);
  }

  lookupVariable(name: string): VariableSymbol | null {
    return this.global.lookupVariable(name);
  }

  getVariableSourceFile(name: string): string | undefined {
    return this.global.getVariableSourceFile(name);
  }

  getFunctionSourceFile(name: string): string | undefined {
    return this.global.getFunctionSourceFile(name);
  }

  getGlobalScope(): Scope {
    return this.global;
  }

  createFunctionScope(): Scope {
    return this.global.createChild();
  }
}
