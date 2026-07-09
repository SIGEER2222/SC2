// src/analyzer/SymbolTable.ts
import type { FunctionSignature } from '../types.js';

export interface VariableSymbol {
  name: string;
  varType: string;
  isArray: boolean;
}

export class Scope {
  private vars = new Map<string, VariableSymbol>();
  private funcs = new Map<string, FunctionSignature>();
  private children: Scope[] = [];

  constructor(public parent: Scope | null) {}

  declareVariable(varType: string, name: string, isArray = false, onDuplicate?: () => void): void {
    if (this.vars.has(name)) {
      onDuplicate?.();
      return;
    }
    this.vars.set(name, { name, varType, isArray });
  }

  declareFunction(sig: FunctionSignature, onDuplicate?: () => void): void {
    if (this.funcs.has(sig.name)) {
      onDuplicate?.();
      return;
    }
    this.funcs.set(sig.name, sig);
  }

  lookupVariable(name: string): VariableSymbol | null {
    if (this.vars.has(name)) return this.vars.get(name)!;
    return this.parent?.lookupVariable(name) ?? null;
  }

  lookupFunction(name: string): FunctionSignature | null {
    if (this.funcs.has(name)) return this.funcs.get(name)!;
    return this.parent?.lookupFunction(name) ?? null;
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

  declareFunction(sig: FunctionSignature, onDuplicate?: () => void): void {
    this.global.declareFunction(sig, onDuplicate);
  }

  declareGlobalVariable(varType: string, name: string, isArray = false, onDuplicate?: () => void): void {
    this.global.declareVariable(varType, name, isArray, onDuplicate);
  }

  lookupFunction(name: string): FunctionSignature | null {
    return this.global.lookupFunction(name);
  }

  lookupVariable(name: string): VariableSymbol | null {
    return this.global.lookupVariable(name);
  }

  getGlobalScope(): Scope {
    return this.global;
  }

  createFunctionScope(): Scope {
    return this.global.createChild();
  }
}
