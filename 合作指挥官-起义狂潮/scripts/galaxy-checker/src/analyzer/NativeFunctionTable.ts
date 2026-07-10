// src/analyzer/NativeFunctionTable.ts
import { readFileSync } from 'node:fs';
import { resolveDataFile } from '../dataPath.js';
import { parse } from '../parser/index.js';
import type { FunctionSignature } from '../types.js';

export interface BlacklistFile {
  version: string;
  disallowedNatives: string[];
  discouragedNatives?: string[];
  notes?: Record<string, string>;
}

const DEFAULT_BLACKLIST_PATH = resolveDataFile('native-blacklist.json');

export class NativeFunctionTable {
  private natives = new Map<string, FunctionSignature>();
  private disallowed = new Set<string>();
  private discouraged = new Set<string>();
  private notes = new Map<string, string>();

  constructor(blacklist?: BlacklistFile | string) {
    let file: BlacklistFile;
    if (!blacklist) {
      file = JSON.parse(readFileSync(DEFAULT_BLACKLIST_PATH, 'utf-8'));
    } else if (typeof blacklist === 'string') {
      file = JSON.parse(readFileSync(blacklist, 'utf-8'));
    } else {
      file = blacklist;
    }
    for (const name of file.disallowedNatives) {
      this.disallowed.add(name);
    }
    for (const name of file.discouragedNatives ?? []) {
      this.discouraged.add(name);
    }
    if (file.notes) {
      for (const [k, v] of Object.entries(file.notes)) {
        this.notes.set(k, v);
      }
    }
  }

  loadFromString(source: string): void {
    // 快路径：native 与 TriggerLib 函数原型用正则批量提取（比全量 parse 快约 10 倍），
    // 一条都匹配不到时回退到完整 parser（处理非常规格式）
    const noComments = source
      .replace(/\/\*[\s\S]*?\*\//g, ' ')
      .replace(/\/\/[^\n]*/g, ' ');
    const re = /\b(native\s+)?(\w+)\s+(\w+)\s*\(([^)]*)\)\s*;/g;
    let matched = 0;
    for (const m of noComments.matchAll(re)) {
      matched++;
      const [, nativeKeyword, returnType, name, rawParams] = m;
      const params: { type: string; name: string }[] = [];
      for (const p of rawParams.split(',')) {
        const tokens = p.trim().split(/\s+/).filter(Boolean);
        if (tokens.length >= 2) params.push({ type: tokens[0], name: tokens[1] });
        else if (tokens.length === 1 && tokens[0] !== '') params.push({ type: tokens[0], name: '' });
      }
      this.natives.set(name, { name, returnType, params, isNative: nativeKeyword !== undefined });
    }
    if (matched > 0) return;

    const { ast } = parse(source, '<native>');
    for (const decl of ast.body) {
      if (decl.type === 'FunctionDeclaration' && decl.isNative) {
        this.natives.set(decl.name, {
          name: decl.name,
          returnType: decl.returnType,
          params: decl.params.map(p => ({ type: p.type, name: p.name })),
          isNative: true,
        });
      }
    }
  }

  loadFromFile(path: string): void {
    this.loadFromString(readFileSync(path, 'utf-8'));
  }

  lookup(name: string): FunctionSignature | undefined {
    return this.natives.get(name);
  }

  isNative(name: string): boolean {
    return this.natives.has(name);
  }

  isDisallowed(name: string): boolean {
    return this.disallowed.has(name);
  }

  isDiscouraged(name: string): boolean {
    return this.discouraged.has(name);
  }

  getNote(name: string): string | undefined {
    return this.notes.get(name);
  }
}
