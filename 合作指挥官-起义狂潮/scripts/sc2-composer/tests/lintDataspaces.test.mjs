/**
 * lintDataspaces.mjs unit tests.
 *
 * Run: node --test tests/lintDataspaces.test.mjs
 */

import { describe, test } from 'node:test';
import { strict as assert } from 'node:assert';
import {
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { lintMod, lintProject } from '../src/lintDataspaces.mjs';

describe('lintMod', () => {
  test('passes a complete DataCenter with included data spaces and exports', async () => {
    const root = makeTempDir();
    try {
      const modDir = createMod(root, 'CommanderUnits_Test.SC2Mod', {
        dataCenter: {
          schemaVersion: 1,
          id: 'Commander.TestCommander',
          type: 'CommanderDataCenter',
          owner: 'TestCommander',
          gameDataEntry: 'Base.SC2Data/GameData.xml',
          spaces: [
            {
              path: 'GameData/TestUnits.xml',
              owns: ['CUnit'],
              catalogIds: ['TestMarine'],
            },
            {
              path: 'GameData/TestAbilities.xml',
              owns: ['CAbil'],
              catalogIds: ['TestBuildMarine'],
            },
          ],
          exports: {
            units: ['TestMarine'],
            abilities: ['TestBuildMarine'],
          },
        },
        gameDataXml: [
          '<?xml version="1.0" encoding="utf-8"?>',
          '<Includes>',
          '  <Catalog path="GameData/TestUnits.xml"/>',
          '  <Catalog path="GameData/TestAbilities.xml"/>',
          '</Includes>',
        ].join('\n'),
        spaces: {
          'TestUnits.xml': '<Catalog><CUnit id="TestMarine"/></Catalog>',
          'TestAbilities.xml': '<Catalog><CAbilTrain id="TestBuildMarine"/></Catalog>',
        },
      });

      const issues = await lintMod(modDir);
      assert.deepEqual(issues, []);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  test('reports DC-008 when DataCenter space is not included by GameData.xml', async () => {
    const root = makeTempDir();
    try {
      const modDir = createMod(root, 'CommanderUnits_Test.SC2Mod', {
        dataCenter: {
          schemaVersion: 1,
          id: 'Commander.TestCommander',
          type: 'CommanderDataCenter',
          gameDataEntry: 'Base.SC2Data/GameData.xml',
          spaces: [
            {
              path: 'GameData/TestUnits.xml',
              owns: ['CUnit'],
            },
          ],
        },
        gameDataXml: [
          '<?xml version="1.0" encoding="utf-8"?>',
          '<Includes>',
          '  <Catalog path="GameData/OtherUnits.xml"/>',
          '</Includes>',
        ].join('\n'),
        spaces: {
          'TestUnits.xml': '<Catalog><CUnit id="TestMarine"/></Catalog>',
          'OtherUnits.xml': '<Catalog/>',
        },
      });

      const issues = await lintMod(modDir);
      assertIssue(issues, 'DC-008', 'error');
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  test('reports DC-006 when exports reference missing catalog ids', async () => {
    const root = makeTempDir();
    try {
      const modDir = createMod(root, 'CommanderUnits_Test.SC2Mod', {
        dataCenter: {
          schemaVersion: 1,
          id: 'Commander.TestCommander',
          type: 'CommanderDataCenter',
          gameDataEntry: 'Base.SC2Data/GameData.xml',
          spaces: [
            {
              path: 'GameData/TestUnits.xml',
              owns: ['CUnit'],
            },
          ],
          exports: {
            units: ['MissingMarine'],
          },
        },
        gameDataXml: [
          '<?xml version="1.0" encoding="utf-8"?>',
          '<Includes>',
          '  <Catalog path="GameData/TestUnits.xml"/>',
          '</Includes>',
        ].join('\n'),
        spaces: {
          'TestUnits.xml': '<Catalog><CUnit id="TestMarine"/></Catalog>',
        },
      });

      const issues = await lintMod(modDir);
      assertIssue(issues, 'DC-006', 'error');
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  test('reports DC-004 when included data spaces coexist with unreferenced XML files', async () => {
    const root = makeTempDir();
    try {
      const modDir = createMod(root, 'CommanderUnits_Test.SC2Mod', {
        dataCenter: {
          schemaVersion: 1,
          id: 'Commander.TestCommander',
          type: 'CommanderDataCenter',
          gameDataEntry: 'Base.SC2Data/GameData.xml',
          spaces: [
            {
              path: 'GameData/TestUnits.xml',
              owns: ['CUnit'],
            },
          ],
        },
        gameDataXml: [
          '<?xml version="1.0" encoding="utf-8"?>',
          '<Includes>',
          '  <Catalog path="GameData/TestUnits.xml"/>',
          '</Includes>',
        ].join('\n'),
        spaces: {
          'TestUnits.xml': '<Catalog><CUnit id="TestMarine"/></Catalog>',
          'StrayUnits.xml': '<Catalog><CUnit id="StrayMarine"/></Catalog>',
        },
      });

      const issues = await lintMod(modDir);
      assertIssue(issues, 'DC-004', 'warning');
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  test('reports DC-007 for empty GameData.xml and automatic GameData XML loading without DataCenter', async () => {
    const root = makeTempDir();
    try {
      const modDir = createMod(root, 'CommanderUnits_Test.SC2Mod', {
        dataCenter: null,
        gameDataXml: '<Catalog/>',
        spaces: {
          'UnitData.xml': '<Catalog><CUnit id="TestMarine"/></Catalog>',
        },
      });

      const issues = await lintMod(modDir);
      assertIssue(issues, 'DC-007', 'info');
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });
});

describe('lintProject', () => {
  test('recursively scans nested SC2Mod directories', async () => {
    const root = makeTempDir();
    try {
      const projectRoot = join(root, 'Project');
      const nestedRoot = join(projectRoot, 'Mods', 'Commanders', 'Test');
      mkdirSync(nestedRoot, { recursive: true });
      createMod(nestedRoot, 'CommanderUnits_Test.SC2Mod', {
        dataCenter: null,
        gameDataXml: '<Catalog/>',
        spaces: {
          'UnitData.xml': '<Catalog><CUnit id="TestMarine"/></Catalog>',
        },
      });

      const result = await lintProject(projectRoot);
      assert.equal(result.modCount, 1);
      assertIssue(result.issues, 'DC-007', 'info');
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });
});

function makeTempDir() {
  return mkdtempSync(join(tmpdir(), 'sc2-composer-lint-'));
}

function createMod(root, modName, { dataCenter, gameDataXml, spaces }) {
  const modDir = join(root, modName);
  const baseDir = join(modDir, 'Base.SC2Data');
  const gameDataDir = join(baseDir, 'GameData');
  mkdirSync(gameDataDir, { recursive: true });

  if (dataCenter !== null) {
    writeFileSync(join(modDir, 'DataCenter.json'), JSON.stringify(dataCenter, null, 2), 'utf8');
  }
  writeFileSync(join(baseDir, 'GameData.xml'), `${gameDataXml}\n`, 'utf8');

  for (const [name, content] of Object.entries(spaces)) {
    writeFileSync(join(gameDataDir, name), `${content}\n`, 'utf8');
  }

  return modDir;
}

function assertIssue(issues, code, severity) {
  assert.ok(
    issues.some((issue) => issue.code === code && issue.severity === severity),
    `expected ${severity} ${code}, got: ${JSON.stringify(issues, null, 2)}`,
  );
}
