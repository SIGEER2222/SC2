// src/analyzer/ProjectLoader.ts
import { readdirSync, readFileSync } from 'node:fs';
import { join, basename } from 'node:path';
import { parse } from '../parser/index.js';
import { SymbolTable } from './SymbolTable.js';

export class ProjectLoader {
  constructor(private rootDir: string) {}

  collectGalaxyFiles(): string[] {
    return this.walkFiles(name => name.startsWith('Lib'));
  }

  // 符号收集范围比 lint 范围更宽：目录下所有 .galaxy（含 TriggerLibs/AI 等）
  // 都可能提供被 Lib* 引用的函数/常量
  collectAllGalaxyFiles(): string[] {
    return this.walkFiles(() => true);
  }

  private walkFiles(filter: (name: string) => boolean): string[] {
    const out: string[] = [];
    const walk = (dir: string) => {
      const entries = readdirSync(dir, { withFileTypes: true });
      for (const e of entries) {
        const full = join(dir, e.name);
        if (e.isDirectory()) {
          walk(full);
        } else if (e.isFile() && e.name.endsWith('.galaxy') && filter(e.name)) {
          out.push(full);
        }
      }
    };
    walk(this.rootDir);
    return out;
  }

  buildGlobalSymbolTable(): SymbolTable {
    const table = new SymbolTable();
    for (const file of this.collectAllGalaxyFiles()) {
      // 去掉 BOM，否则首 token 失配导致整个文件符号丢失
      const source = readFileSync(file, 'utf-8').replace(/^\uFEFF/, '');
      const { ast: program } = parse(source, basename(file));
      // 仅收集顶层声明，不分析函数体；跨文件重复声明静默跳过（Task 14 onDuplicate 行为：不传回调即静默跳过）
      for (const decl of program.body) {
        if (decl.type === 'FunctionDeclaration') {
          table.declareFunction({
            name: decl.name,
            returnType: decl.returnType,
            params: decl.params.map(p => ({ type: p.type, name: p.name })),
            isNative: decl.isNative,
          });
        } else if (decl.type === 'VariableDeclaration') {
          table.declareGlobalVariable(decl.varType, decl.name, decl.isArray);
        }
      }
    }
    return table;
  }
}
