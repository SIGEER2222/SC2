import { describe, it, expect, beforeAll } from 'vitest';
import { ProjectLoader } from '../src/analyzer/ProjectLoader.js';
import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

describe('ProjectLoader', () => {
  let tmpProject: string;

  beforeAll(() => {
    tmpProject = join(tmpdir(), `galaxy-project-${Date.now()}`);
    mkdirSync(tmpProject, { recursive: true });
    writeFileSync(join(tmpProject, 'LibFoo.galaxy'), 'void foo() {} int gv_foo;');
    writeFileSync(join(tmpProject, 'LibBar.galaxy'), 'void bar() {}');
    writeFileSync(join(tmpProject, 'not-a-lib.galaxy'), 'void ignored() {}');
  });

  it('扫描 Lib*.galaxy 文件', () => {
    const loader = new ProjectLoader(tmpProject);
    const files = loader.collectGalaxyFiles();
    expect(files.map(f => f.split(/[\\/]/).pop()).sort()).toEqual(['LibBar.galaxy', 'LibFoo.galaxy']);
  });

  it('构建全局符号表', () => {
    const loader = new ProjectLoader(tmpProject);
    const table = loader.buildGlobalSymbolTable();
    expect(table.lookupFunction('foo')).toBeDefined();
    expect(table.lookupFunction('bar')).toBeDefined();
    expect(table.lookupVariable('gv_foo')).toBeDefined();
  });
});
