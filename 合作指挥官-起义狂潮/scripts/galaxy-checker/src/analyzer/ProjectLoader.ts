// src/analyzer/ProjectLoader.ts
import { readdirSync, readFileSync } from 'node:fs';
import { join, basename, relative } from 'node:path';
import { parse } from '../parser/index.js';
import { SymbolTable } from './SymbolTable.js';

export class ProjectLoader {
  private rootDirs: string[];

  constructor(rootDir: string | string[]) {
    this.rootDirs = Array.isArray(rootDir) ? rootDir : [rootDir];
  }

  collectGalaxyFiles(): string[] {
    return this.walkFiles(name => name.startsWith('Lib'));
  }

  // 符号收集范围比 lint 范围更宽：目录下所有 .galaxy（含 TriggerLibs/AI 等）
  // 都可能提供被 Lib* 引用的函数/常量
  collectAllGalaxyFiles(): string[] {
    return this.walkFiles(() => true);
  }

  // 根目录按 SC2 的依赖加载顺序传入。后加载的同相对路径资源覆盖先加载资源。
  collectEffectiveGalaxyFiles(): string[] {
    const effectiveFiles = new Map<string, string>();
    for (const rootDir of this.rootDirs) {
      const files = this.collectAllGalaxyFilesForRoot(rootDir);
      for (const file of files) {
        const virtualPath = relative(rootDir, file).replace(/\\/g, '/').toLowerCase();
        effectiveFiles.set(virtualPath, file);
      }
    }
    return [...effectiveFiles.entries()]
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([, file]) => file);
  }

  private walkFiles(filter: (name: string) => boolean): string[] {
    const out = new Set<string>();
    const walk = (dir: string) => {
      const entries = readdirSync(dir, { withFileTypes: true });
      for (const e of entries) {
        const full = join(dir, e.name);
        if (e.isDirectory()) {
          walk(full);
        } else if (e.isFile() && e.name.endsWith('.galaxy') && filter(e.name)) {
          out.add(full);
        }
      }
    };
    for (const rootDir of this.rootDirs) {
      walk(rootDir);
    }
    return [...out];
  }

  private collectAllGalaxyFilesForRoot(rootDir: string): string[] {
    const out: string[] = [];
    const walk = (dir: string) => {
      const entries = readdirSync(dir, { withFileTypes: true });
      for (const entry of entries) {
        const full = join(dir, entry.name);
        if (entry.isDirectory()) {
          walk(full);
        } else if (entry.isFile() && entry.name.endsWith('.galaxy')) {
          out.push(full);
        }
      }
    };
    walk(rootDir);
    return out;
  }

  buildGlobalSymbolTable(): SymbolTable {
    return this.buildSymbolTable(this.collectAllGalaxyFiles());
  }

  buildEffectiveGlobalSymbolTable(): SymbolTable {
    return this.buildSymbolTable(this.collectEffectiveGalaxyFiles());
  }

  private buildSymbolTable(files: string[]): SymbolTable {
    const table = new SymbolTable();
    for (const file of files) {
      // 去掉 BOM，否则首 token 失配导致整个文件符号丢失
      const source = readFileSync(file, 'utf-8').replace(/^\uFEFF/, '');
      const { ast: program } = parse(source, basename(file));
      // 仅收集顶层声明，不分析函数体；跨文件重复声明静默跳过（onDuplicate 不传回调）
      // 记录 sourceFile 供 SemanticAnalyzer 区分"同文件二次扫描"与"跨文件声明冲突"
      for (const decl of program.body) {
        if (decl.type === 'FunctionDeclaration') {
          table.declareFunction({
            name: decl.name,
            returnType: decl.returnType,
            params: decl.params.map(p => ({ type: p.type, name: p.name })),
            isNative: decl.isNative,
          }, undefined, file);
        } else if (decl.type === 'VariableDeclaration') {
          table.declareGlobalVariable(decl.varType, decl.name, decl.isArray, undefined, file);
        }
      }
    }
    return table;
  }
}
