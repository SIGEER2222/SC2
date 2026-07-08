// src/analyzer/NativeFunctionTable.ts
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from '../parser/index.js';
import type { FunctionSignature } from '../types.js';

export interface BlacklistFile {
  version: string;
  disallowedNatives: string[];
  notes?: Record<string, string>;
}

const DEFAULT_BLACKLIST_PATH = join(
  dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
  'data',
  'native-blacklist.json'
);

export class NativeFunctionTable {
  private natives = new Map<string, FunctionSignature>();
  private disallowed = new Set<string>();
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
    if (file.notes) {
      for (const [k, v] of Object.entries(file.notes)) {
        this.notes.set(k, v);
      }
    }
  }

  loadFromString(source: string): void {
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

  getNote(name: string): string | undefined {
    return this.notes.get(name);
  }
}
