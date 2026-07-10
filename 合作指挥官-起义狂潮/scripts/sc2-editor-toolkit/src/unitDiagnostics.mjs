import fs from 'node:fs';
import path from 'node:path';
import { CatalogStore } from './catalog.mjs';
import { loadModIntoStore } from './modLoader.mjs';

function issue(severity, code, message, evidence = {}) {
  return { severity, code, message, ...evidence };
}

function children(node, tag) {
  return node?.children.filter(child => child.tag === tag && child.attrs.removed !== '1') ?? [];
}

function scalar(node, name) {
  if (!node) return null;
  if (node.attrs[name] !== undefined) return node.attrs[name];
  let value = null;
  for (const child of children(node, name)) {
    value = child.attrs.value ?? child.attrs[name] ?? value;
  }
  return value;
}

function lastChildValue(node, tag, attributes) {
  let value = null;
  for (const child of children(node, tag)) {
    for (const attribute of attributes) {
      if (child.attrs[attribute] !== undefined && child.attrs[attribute] !== '') {
        value = child.attrs[attribute];
        break;
      }
    }
  }
  return value;
}

function unitRef(node) {
  return node?.attrs.Unit ??
    node?.attrs.unit ??
    lastChildValue(node, 'Unit', ['value', 'Unit', 'unit']);
}

function unique(values) {
  return [...new Set(values.filter(Boolean))];
}

function unitAbilities(node) {
  return unique(children(node, 'AbilArray').map(child => child.attrs.Link));
}

function unitCards(node) {
  const cards = [];
  for (const layout of children(node, 'CardLayouts')) {
    for (const button of children(layout, 'LayoutButtons')) {
      const abilCmd = scalar(button, 'AbilCmd');
      const [abilityId, command] = abilCmd?.includes(',')
        ? abilCmd.split(',', 2).map(value => value.trim())
        : [null, null];
      cards.push({
        cardId: layout.attrs.CardId ?? '',
        index: button.attrs.index ?? null,
        abilityId,
        command,
        face: scalar(button, 'Face'),
        type: scalar(button, 'Type'),
        requirements: scalar(button, 'Requirements'),
        state: scalar(button, 'State'),
        row: scalar(button, 'Row'),
        column: scalar(button, 'Column'),
        file: button.file,
        line: button.line,
      });
    }
  }
  return cards;
}

function productionSlots(entry) {
  if (!entry || !['CAbilTrain', 'CAbilBuild', 'CAbilMorph'].includes(entry.tag)) return [];
  const relation = entry.tag === 'CAbilTrain'
    ? 'train'
    : entry.tag === 'CAbilBuild'
      ? 'build'
      : 'morph';
  const slots = [];
  for (const info of children(entry.node, 'InfoArray')) {
    const targetUnit = unitRef(info) ?? (relation === 'morph' ? unitRef(entry.node) : null);
    if (!targetUnit) continue;
    slots.push({
      relation,
      abilityId: entry.id,
      abilityTag: entry.tag,
      command: info.attrs.index ?? '',
      targetUnit,
      buttonFace: lastChildValue(info, 'Button', ['DefaultButtonFace', 'Face']),
      requirements: scalar(info, 'Requirements') ??
        lastChildValue(info, 'Button', ['Requirements']),
      state: lastChildValue(info, 'Button', ['State']),
      file: info.file,
      line: info.line,
    });
  }
  if (relation === 'morph' && slots.length === 0) {
    const targetUnit = unitRef(entry.node);
    if (targetUnit) {
      slots.push({
        relation,
        abilityId: entry.id,
        abilityTag: entry.tag,
        command: '',
        targetUnit,
        buttonFace: null,
        requirements: null,
        state: null,
        file: entry.node.file,
        line: entry.node.line,
      });
    }
  }
  return slots;
}

function loadGraphStore(graph) {
  const store = new CatalogStore();
  const issues = [];
  const warnings = [];
  for (const packageRoot of graph.loadOrder) {
    const loaded = loadModIntoStore(packageRoot, store);
    issues.push(...loaded.fileIssues);
    warnings.push(...loaded.warnings);
  }
  return { store, issues, warnings };
}

function resolvedUnit(store, unitId) {
  const entry = store.resolveEntry('Unit', unitId);
  if (!entry) return {
    found: false,
    id: unitId,
    parentChain: [],
    unresolvedParent: null,
    staticAbilities: [],
    cards: [],
  };
  return {
    found: true,
    id: unitId,
    tag: entry.tag,
    sources: entry.sources,
    parentChain: entry.parentChain,
    parentCircular: entry.parentCircular,
    unresolvedParent: entry.unresolvedParent,
    staticAbilities: unitAbilities(entry.node),
    cards: unitCards(entry.node),
  };
}

function collectGalaxyFiles(root, output = []) {
  if (!fs.existsSync(root)) return output;
  for (const name of fs.readdirSync(root)) {
    const file = path.join(root, name);
    const stat = fs.statSync(file);
    if (stat.isDirectory()) collectGalaxyFiles(file, output);
    else if (name.toLowerCase().endsWith('.galaxy')) output.push(file);
  }
  return output;
}

function event(kind, targetType, targetId, value, file, line, text, confidence = 'direct') {
  return { kind, targetType, targetId, value, file, line, text: text.trim(), confidence };
}

function scanRuntime(graph, unitId, relevantAbilityIds) {
  const events = [];
  const relevantAbilities = new Set(relevantAbilityIds);
  for (const packageRoot of graph.loadOrder) {
    const baseData = path.join(packageRoot, 'Base.SC2Data');
    for (const file of collectGalaxyFiles(baseData)) {
      const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
      let currentUnits = [];
      lines.forEach((line, index) => {
        const stripped = line.trim();
        if (stripped.startsWith('//')) return;
        if (line.includes('UnitGetType') || line.includes('lv_type')) {
          const matches = [...line.matchAll(/==\s*"([^"]+)"/g)].map(match => match[1]);
          if (matches.length > 0) currentUnits = matches;
        }

        for (const match of line.matchAll(
          /\b((?:[A-Za-z_][A-Za-z0-9_]*)?TechTreeUnitAllow)\s*\([^,]+,\s*"([^"]+)"\s*,\s*(true|false)/g,
        )) {
          if (match[2] === unitId) {
            events.push(event(
              'unit-tech', 'Unit', match[2], match[3] === 'true',
              file, index + 1, line,
            ));
          }
        }
        for (const match of line.matchAll(/\b([A-Za-z_][A-Za-z0-9_]*Allow[A-Za-z0-9_]*Unit[A-Za-z0-9_]*)\s*\([^,]+,\s*"([^"]+)"/g)) {
          if (match[2] === unitId) events.push(event('unit-tech', 'Unit', match[2], true, file, index + 1, line));
        }
        for (const match of line.matchAll(/\b([A-Za-z_][A-Za-z0-9_]*Block[A-Za-z0-9_]*Unit[A-Za-z0-9_]*)\s*\([^,]+,\s*"([^"]+)"/g)) {
          if (match[2] === unitId) events.push(event('unit-tech', 'Unit', match[2], false, file, index + 1, line));
        }

        for (const match of line.matchAll(
          /\b((?:[A-Za-z_][A-Za-z0-9_]*)?TechTreeAbilityAllow)\s*\([^,]+,\s*AbilityCommand\s*\(\s*"([^"]+)"[^)]*\)\s*,\s*(true|false)/g,
        )) {
          if (relevantAbilities.has(match[2])) {
            events.push(event(
              'ability-tech', 'Abil', match[2], match[3] === 'true',
              file, index + 1, line,
            ));
          }
        }
        for (const match of line.matchAll(/\b([A-Za-z_][A-Za-z0-9_]*Allow[A-Za-z0-9_]*Abil[A-Za-z0-9_]*)\s*\([^,]+,\s*"([^"]+)"/g)) {
          if (relevantAbilities.has(match[2])) events.push(event('ability-tech', 'Abil', match[2], true, file, index + 1, line));
        }
        for (const match of line.matchAll(/\b([A-Za-z_][A-Za-z0-9_]*Block[A-Za-z0-9_]*Abil[A-Za-z0-9_]*)\s*\([^,]+,\s*"([^"]+)"/g)) {
          if (relevantAbilities.has(match[2])) events.push(event('ability-tech', 'Abil', match[2], false, file, index + 1, line));
        }

        for (const match of line.matchAll(/\b((?:[A-Za-z_][A-Za-z0-9_]*)?UnitAbility(Add|Remove))\s*\([^,]+,\s*"([^"]+)"/g)) {
          if (!currentUnits.includes(unitId)) continue;
          events.push(event(
            match[2] === 'Add' ? 'ability-add' : 'ability-remove',
            'Unit',
            unitId,
            match[3],
            file,
            index + 1,
            line,
            'context-inferred',
          ));
        }

        if (/\bCatalogFieldValueSet(?:AsInt|AsFixed)?\s*\(/.test(line) && line.includes(`"${unitId}"`)) {
          events.push(event('catalog-field-set', 'Unit', unitId, null, file, index + 1, line));
        }
        for (const abilityId of relevantAbilities) {
          if (
            /\bCatalogFieldValueSet(?:AsInt|AsFixed)?\s*\(/.test(line) &&
            line.includes(`"${abilityId}"`)
          ) {
            events.push(event('catalog-field-set', 'Abil', abilityId, null, file, index + 1, line));
          }
        }
      });
    }
  }

  const unitTechEvents = events.filter(item => item.kind === 'unit-tech');
  const abilityTech = {};
  for (const abilityId of relevantAbilities) {
    const matches = events.filter(item =>
      item.kind === 'ability-tech' && item.targetId === abilityId
    );
    if (matches.length > 0) {
      abilityTech[abilityId] = {
        allowed: matches.at(-1).value,
        history: matches,
      };
    }
  }
  return {
    events,
    unitTech: unitTechEvents.length > 0
      ? { allowed: unitTechEvents.at(-1).value, history: unitTechEvents }
      : { allowed: null, history: [] },
    abilityTech,
    addedAbilities: unique(events
      .filter(item => item.kind === 'ability-add')
      .map(item => item.value)),
    removedAbilities: unique(events
      .filter(item => item.kind === 'ability-remove')
      .map(item => item.value)),
    catalogMutations: events.filter(item => item.kind === 'catalog-field-set'),
    scan: {
      mode: 'literal-and-local-context-scan',
      complete: false,
      limitations: [
        'cross-function-data-flow',
        'dynamic-id',
        'generated-string',
        'ambiguous-unit-context',
      ],
    },
  };
}

function incompleteDependencies(graph) {
  const statuses = new Set(['external', 'missing', 'legacy', 'needs-selection']);
  const seen = new Set();
  return graph.edges.filter(edge => {
    if (!statuses.has(edge.status)) return false;
    const key = `${edge.status}\u0000${edge.ref}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

export function diagnoseUnit({
  graph,
  unitId,
  producerId = null,
  expectedAbilities = [],
}) {
  const loaded = loadGraphStore(graph);
  const { store } = loaded;
  const unit = resolvedUnit(store, unitId);
  const producer = producerId ? resolvedUnit(store, producerId) : null;
  const targetSlots = [];
  for (const [abilityId] of store.ids('Abil')) {
    const entry = store.resolveEntry('Abil', abilityId);
    for (const slot of productionSlots(entry)) {
      if (slot.targetUnit === unitId) targetSlots.push(slot);
    }
  }

  const producerModels = [];
  if (producerId) {
    if (producer?.found) producerModels.push(producer);
  } else {
    const targetAbilityIds = new Set(targetSlots.map(slot => slot.abilityId));
    for (const [candidateId] of store.ids('Unit')) {
      const candidate = resolvedUnit(store, candidateId);
      if (candidate.staticAbilities.some(abilityId => targetAbilityIds.has(abilityId))) {
        producerModels.push(candidate);
      }
    }
  }

  const candidates = [];
  for (const producerModel of producerModels) {
    for (const slot of targetSlots) {
      if (!producerModel.staticAbilities.includes(slot.abilityId)) continue;
      const button = producerModel.cards.find(card =>
        card.abilityId === slot.abilityId &&
        (!slot.command || card.command === slot.command)
      ) ?? null;
      candidates.push({
        ...slot,
        producerId: producerModel.id,
        buttonVisible: Boolean(button),
        button,
        requirements: button?.requirements ?? slot.requirements,
        state: button?.state ?? slot.state,
      });
    }
  }
  const selectedCandidates = producerId
    ? candidates.filter(candidate => candidate.producerId === producerId)
    : candidates;
  const selected = selectedCandidates.find(candidate => candidate.buttonVisible) ??
    selectedCandidates[0] ??
    null;

  const relevantAbilities = unique([
    ...unit.staticAbilities,
    ...expectedAbilities,
    ...targetSlots.map(slot => slot.abilityId),
  ]);
  const runtime = scanRuntime(graph, unitId, relevantAbilities);
  const effectiveAbilities = new Set(unit.staticAbilities);
  for (const abilityId of runtime.addedAbilities) effectiveAbilities.add(abilityId);
  for (const abilityId of runtime.removedAbilities) effectiveAbilities.delete(abilityId);
  unit.runtimeAddedAbilities = runtime.addedAbilities;
  unit.runtimeRemovedAbilities = runtime.removedAbilities;
  unit.effectiveAbilities = [...effectiveAbilities];

  const issues = [];
  if (!unit.found) {
    issues.push(issue('error', 'UNIT_NOT_FOUND', `未找到单位 ${unitId}`));
  }
  if (unit.unresolvedParent) {
    issues.push(issue(
      'error',
      'UNIT_PARENT_UNRESOLVED',
      `${unitId} 的 parent ${unit.unresolvedParent} 未加载`,
      { parent: unit.unresolvedParent },
    ));
  }
  if (unit.parentCircular) {
    issues.push(issue(
      'error',
      'UNIT_PARENT_CIRCULAR',
      `${unitId} 的 parent 链存在循环`,
      { parentChain: unit.parentChain },
    ));
  }
  if (producerId && !producer?.found) {
    issues.push(issue('error', 'PRODUCER_NOT_FOUND', `未找到生产者 ${producerId}`));
  }
  if (producer?.unresolvedParent) {
    issues.push(issue(
      'error',
      'PRODUCER_PARENT_UNRESOLVED',
      `${producerId} 的 parent ${producer.unresolvedParent} 未加载`,
      { parent: producer.unresolvedParent },
    ));
  }
  if (producer?.parentCircular) {
    issues.push(issue(
      'error',
      'PRODUCER_PARENT_CIRCULAR',
      `${producerId} 的 parent 链存在循环`,
      { parentChain: producer.parentChain },
    ));
  }
  if (targetSlots.length === 0) {
    issues.push(issue(
      'error',
      'PRODUCTION_SLOT_MISSING',
      `没有 Train/Build/Morph InfoArray 指向 ${unitId}`,
    ));
  } else if (!producerId && candidates.length === 0) {
    issues.push(issue(
      'error',
      'PRODUCTION_PRODUCER_MISSING',
      `没有已加载单位拥有能生产 ${unitId} 的能力`,
      { expectedProductionAbilities: unique(targetSlots.map(slot => slot.abilityId)) },
    ));
  } else if (producerId && producer?.found && selected === null) {
    issues.push(issue(
      'error',
      'PRODUCER_MISSING_PRODUCTION_ABILITY',
      `${producerId} 未拥有能生产 ${unitId} 的能力`,
      { expectedProductionAbilities: unique(targetSlots.map(slot => slot.abilityId)) },
    ));
  }
  if (selected && !selected.buttonVisible) {
    issues.push(issue(
      'error',
      'PRODUCTION_BUTTON_MISSING',
      `${producerId ?? selected.producerId} 拥有 ${selected.abilityId}，但卡牌没有 ${selected.command} 按钮`,
      { production: selected },
    ));
  }
  if (selected?.requirements || selected?.state === 'Restricted') {
    issues.push(issue(
      'warning',
      'PRODUCTION_REQUIREMENT_GATED',
      `${selected.abilityId},${selected.command} 受 Requirement/State 限制`,
      { requirements: selected.requirements, state: selected.state, production: selected },
    ));
  }
  if (runtime.unitTech.allowed === false) {
    issues.push(issue(
      'error',
      'UNIT_TECH_LOCKED_RUNTIME',
      `${unitId} 被 Galaxy 运行时锁定`,
      { runtime: runtime.unitTech.history.at(-1) },
    ));
  }
  if (selected && runtime.abilityTech[selected.abilityId]?.allowed === false) {
    issues.push(issue(
      'error',
      'PRODUCTION_ABILITY_LOCKED_RUNTIME',
      `${selected.abilityId} 被 Galaxy 运行时锁定`,
      { runtime: runtime.abilityTech[selected.abilityId].history.at(-1) },
    ));
  }

  for (const abilityId of expectedAbilities) {
    const abilityEntry = store.resolveEntry('Abil', abilityId);
    if (!abilityEntry) {
      issues.push(issue(
        'error',
        'ABILITY_DEFINITION_MISSING',
        `预期能力 ${abilityId} 没有 Catalog 定义`,
        { abilityId },
      ));
    }
    if (!effectiveAbilities.has(abilityId)) {
      issues.push(issue(
        'error',
        'EXPECTED_ABILITY_MISSING',
        `${unitId} 的静态能力和运行时注入中都没有 ${abilityId}`,
        { abilityId },
      ));
      continue;
    }
    if (!unit.staticAbilities.includes(abilityId) && runtime.addedAbilities.includes(abilityId)) {
      issues.push(issue(
        'info',
        'EXPECTED_ABILITY_RUNTIME_ONLY',
        `${abilityId} 仅通过 UnitAbilityAdd 注入`,
        { abilityId },
      ));
    }
    if (!unit.cards.some(card => card.abilityId === abilityId)) {
      issues.push(issue(
        'warning',
        'EXPECTED_ABILITY_BUTTON_MISSING',
        `${unitId} 拥有 ${abilityId}，但静态 CardLayouts 没有对应 AbilCmd`,
        { abilityId },
      ));
    }
    if (runtime.abilityTech[abilityId]?.allowed === false) {
      issues.push(issue(
        'error',
        'EXPECTED_ABILITY_LOCKED_RUNTIME',
        `${abilityId} 被 Galaxy 运行时锁定`,
        { abilityId, runtime: runtime.abilityTech[abilityId].history.at(-1) },
      ));
    }
  }

  if (
    runtime.addedAbilities.length > 0 ||
    runtime.removedAbilities.length > 0 ||
    runtime.catalogMutations.length > 0 ||
    runtime.unitTech.history.length > 0 ||
    Object.keys(runtime.abilityTech).length > 0
  ) {
    issues.push(issue(
      'warning',
      'STATIC_RUNTIME_DIVERGENCE',
      `${unitId} 的运行时状态与纯 XML 静态视图不同`,
      {
        addedAbilities: runtime.addedAbilities,
        removedAbilities: runtime.removedAbilities,
        catalogMutations: runtime.catalogMutations,
      },
    ));
  }

  const missingDependencies = incompleteDependencies(graph);
  if (missingDependencies.length > 0) {
    issues.push(issue(
      'warning',
      'DIAGNOSIS_INCOMPLETE_DEPENDENCIES',
      '依赖链不完整，诊断结果可能缺少父级定义或运行时脚本',
      { incompleteDependencies: missingDependencies },
    ));
  }

  const hasErrors = issues.some(item => item.severity === 'error');
  return {
    schemaVersion: 1,
    target: graph.target,
    unitId,
    producerId,
    expectedAbilities,
    status: hasErrors
      ? 'error'
      : missingDependencies.length > 0
        ? 'incomplete'
        : 'ok',
    complete: missingDependencies.length === 0,
    hasErrors,
    unit,
    producer,
    production: {
      targetSlots,
      candidates,
      selected,
    },
    runtime,
    incompleteDependencies: missingDependencies,
    loadIssues: loaded.issues,
    loadWarnings: loaded.warnings,
    issues,
  };
}
