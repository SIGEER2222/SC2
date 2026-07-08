// src/analyzer/ProjectLoader.ts
import { readdirSync, readFileSync } from 'node:fs';
import { join, basename } from 'node:path';
import { parse } from '../parser/index.js';
import { SymbolTable } from './SymbolTable.js';

export class ProjectLoader {
  constructor(private rootDir: string) {}

  collectGalaxyFiles(): string[] {
    const out: string[] = [];
    const walk = (dir: string) => {
      const entries = readdirSync(dir, { withFileTypes: true });
      for (const e of entries) {
        const full = join(dir, e.name);
        if (e.isDirectory()) {
          walk(full);
        } else if (e.isFile() && e.name.endsWith('.galaxy') && e.name.startsWith('Lib')) {
          out.push(full);
        }
      }
    };
    walk(this.rootDir);
    return out;
  }

  buildGlobalSymbolTable(): SymbolTable {
    const table = new SymbolTable();
    for (const file of this.collectGalaxyFiles()) {
      const source = readFileSync(file, 'utf-8');
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
