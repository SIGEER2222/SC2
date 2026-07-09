/**
 * 跨 catalog 引用提取规则表（模拟银河编辑器"数据完整性"检查的引用维度）
 *
 * 规则匹配三元组 (条目类 tag 前缀, 后代元素 tag, 属性名) → 目标 catalog。
 * 声明式表 + 少量特殊逻辑（AbilCmd 拆分、CUpgrade 的 Reference 三段式、
 * CRequirementCountXxx 按类名决定 Count.Link 目标）。
 *
 * 提取结果：{ target, id, file, line, via }
 *   via：人类可读的字段路径（如 "AbilArray/@Link"）
 */

// entry: 条目类 tag 前缀（'*' 任意）；elem: 后代元素 tag（'#entry' 表示条目根元素）；
// attr: 属性名；target: 目标 catalog；split: 多值分隔正则（可选）
const RULES = [
  // ---- 通用 ----
  { entry: '*', elem: 'LayoutButtons', attr: 'Face', target: 'Button' },
  { entry: '*', elem: 'LayoutButtons', attr: 'Requirements', target: 'Requirement' },

  // ---- CUnit ----
  { entry: 'CUnit', elem: 'AbilArray', attr: 'Link', target: 'Abil' },
  { entry: 'CUnit', elem: 'WeaponArray', attr: 'Link', target: 'Weapon' },
  { entry: 'CUnit', elem: 'BehaviorArray', attr: 'Link', target: 'Behavior' },
  { entry: 'CUnit', elem: 'TurretArray', attr: 'Link', target: 'Turret' },
  { entry: 'CUnit', elem: 'GlossaryStrongArray', attr: 'value', target: 'Unit' },
  { entry: 'CUnit', elem: 'GlossaryWeakArray', attr: 'value', target: 'Unit' },
  { entry: 'CUnit', elem: 'GlossaryAliasArray', attr: 'value', target: 'Unit' },

  // ---- CAbil* ----
  { entry: 'CAbil', elem: 'InfoArray', attr: 'Unit', target: 'Unit', split: /,/ },
  { entry: 'CAbil', elem: 'InfoArray', attr: 'Upgrade', target: 'Upgrade' },
  { entry: 'CAbil', elem: 'Unit', attr: 'value', target: 'Unit', split: /,/ },
  { entry: 'CAbil', elem: 'Button', attr: 'DefaultButtonFace', target: 'Button' },
  { entry: 'CAbil', elem: 'Button', attr: 'Requirements', target: 'Requirement' },
  { entry: 'CAbil', elem: 'CmdButtonArray', attr: 'DefaultButtonFace', target: 'Button' },
  { entry: 'CAbil', elem: 'CmdButtonArray', attr: 'Requirements', target: 'Requirement' },
  { entry: 'CAbil', elem: 'Effect', attr: 'value', target: 'Effect' },
  { entry: 'CAbil', elem: 'EffectArray', attr: 'value', target: 'Effect' },
  { entry: 'CAbil', elem: 'ValidatorArray', attr: 'value', target: 'Validator' },
  { entry: 'CAbilMorph', elem: 'InfoArray', attr: 'unit', target: 'Unit' },
  { entry: 'CAbilMorph', elem: '#entry', attr: 'unit', target: 'Unit' },

  // ---- CEffect* ----
  { entry: 'CEffect', elem: 'EffectArray', attr: 'value', target: 'Effect' },
  { entry: 'CEffect', elem: 'PeriodicEffectArray', attr: 'value', target: 'Effect' },
  { entry: 'CEffect', elem: 'CaseArray', attr: 'Effect', target: 'Effect' },
  { entry: 'CEffect', elem: 'CaseArray', attr: 'Validator', target: 'Validator' },
  { entry: 'CEffect', elem: 'CaseDefault', attr: 'value', target: 'Effect' },
  { entry: 'CEffect', elem: 'AreaArray', attr: 'Effect', target: 'Effect' },
  { entry: 'CEffect', elem: 'ImpactEffect', attr: 'value', target: 'Effect' },
  { entry: 'CEffect', elem: 'LaunchEffect', attr: 'value', target: 'Effect' },
  { entry: 'CEffect', elem: 'FinishEffect', attr: 'value', target: 'Effect' },
  { entry: 'CEffect', elem: 'InitialEffect', attr: 'value', target: 'Effect' },
  { entry: 'CEffect', elem: 'ExpireEffect', attr: 'value', target: 'Effect' },
  { entry: 'CEffect', elem: 'TeleportEffect', attr: 'value', target: 'Effect' },
  { entry: 'CEffect', elem: 'SpawnEffect', attr: 'value', target: 'Effect' },
  { entry: 'CEffect', elem: 'Behavior', attr: 'value', target: 'Behavior' },
  { entry: 'CEffect', elem: 'BehaviorLink', attr: 'value', target: 'Behavior' },
  { entry: 'CEffect', elem: 'ValidatorArray', attr: 'value', target: 'Validator' },
  { entry: 'CEffect', elem: 'TargetValidatorArray', attr: 'value', target: 'Validator' },
  { entry: 'CEffect', elem: 'PreloadValidatorArray', attr: 'value', target: 'Validator' },
  { entry: 'CEffect', elem: 'AmmoUnit', attr: 'value', target: 'Unit' },
  { entry: 'CEffect', elem: 'SpawnUnit', attr: 'value', target: 'Unit' },
  { entry: 'CEffect', elem: 'Movers', attr: 'Link', target: 'Mover' },
  { entry: 'CEffectCreateUnit', elem: 'CreateFlags', attr: '', target: '' }, // 占位：无引用
  { entry: 'CEffectMorph', elem: 'MorphUnit', attr: 'value', target: 'Unit' },

  // ---- CBehavior* ----
  { entry: 'CBehavior', elem: 'InitialEffect', attr: 'value', target: 'Effect' },
  { entry: 'CBehavior', elem: 'PeriodicEffect', attr: 'value', target: 'Effect' },
  { entry: 'CBehavior', elem: 'PeriodicEffectArray', attr: 'value', target: 'Effect' },
  { entry: 'CBehavior', elem: 'ExpireEffect', attr: 'value', target: 'Effect' },
  { entry: 'CBehavior', elem: 'RefreshEffect', attr: 'value', target: 'Effect' },
  { entry: 'CBehavior', elem: 'Handled', attr: 'value', target: 'Effect' }, // DamageResponse/Handled
  { entry: 'CBehavior', elem: 'ValidatorArray', attr: 'value', target: 'Validator' },
  { entry: 'CBehavior', elem: 'RemoveValidatorArray', attr: 'value', target: 'Validator' },
  { entry: 'CBehavior', elem: 'DisableValidatorArray', attr: 'value', target: 'Validator' },
  { entry: 'CBehavior', elem: 'AbilLinkEnableArray', attr: 'value', target: 'Abil' },
  { entry: 'CBehavior', elem: 'AbilLinkDisableArray', attr: 'value', target: 'Abil' },
  { entry: 'CBehavior', elem: 'WeaponEnableArray', attr: 'value', target: 'Weapon' },
  { entry: 'CBehavior', elem: 'WeaponDisableArray', attr: 'value', target: 'Weapon' },
  { entry: 'CBehavior', elem: 'BehaviorLinkEnableArray', attr: 'value', target: 'Behavior' },
  { entry: 'CBehavior', elem: 'BehaviorLinkDisableArray', attr: 'value', target: 'Behavior' },
  { entry: 'CBehavior', elem: 'Requirements', attr: 'value', target: 'Requirement' },

  // ---- CWeapon* ----
  { entry: 'CWeapon', elem: 'Effect', attr: 'value', target: 'Effect' },
  { entry: 'CWeapon', elem: 'DisplayEffect', attr: 'value', target: 'Effect' },
  { entry: 'CWeapon', elem: 'PreEffect', attr: 'value', target: 'Effect' },
  { entry: 'CWeapon', elem: 'TargetSorts', attr: 'Link', target: 'TargetSort' },
  { entry: 'CWeapon', elem: 'SortValidators', attr: 'value', target: 'Validator' },
  { entry: 'CWeapon', elem: 'Icon', attr: '', target: '' }, // 占位：资源路径非 catalog 引用

  // ---- CUpgrade ----
  { entry: 'CUpgrade', elem: 'AffectedUnitArray', attr: 'value', target: 'Unit' },
  // EffectArray/@Reference 三段式在 extractRefs 中特殊处理

  // ---- CRequirement（精确类）----
  { entry: 'CRequirement', elem: 'NodeArray', attr: 'Link', target: 'RequirementNode' },

  // ---- CValidator* ----
  { entry: 'CValidator', elem: 'CombineArray', attr: 'value', target: 'Validator' },
  { entry: 'CValidator', elem: 'Behavior', attr: 'value', target: 'Behavior' },
  { entry: 'CValidatorPlayerRequirement', elem: 'Value', attr: 'value', target: 'Requirement' },
  { entry: 'CValidatorUnitAbil', elem: 'AbilLink', attr: 'value', target: 'Abil' },
  { entry: 'CValidatorEffect', elem: 'WhichEffect', attr: '', target: '' }, // 占位：token 非引用

  // ---- CActor* ----
  { entry: 'CActor', elem: '#entry', attr: 'unitName', target: 'Unit', split: /[,;]/ },
  { entry: 'CActor', elem: 'UnitName', attr: 'value', target: 'Unit', split: /[,;]/ },
];

// 有效规则（去掉占位）
const ACTIVE_RULES = RULES.filter(r => r.target && r.attr);

// CRequirementCountXxx 的 Count.Link 目标推断
const COUNT_TARGET = [
  ['CRequirementCountUnit', 'Unit'],
  ['CRequirementCountUpgrade', 'Upgrade'],
  ['CRequirementCountBehavior', 'Behavior'],
  ['CRequirementCountAbil', 'Abil'],
  ['CRequirementCountEffect', 'Effect'],
];

// id 合法性粗判：跳过空串与明显非 id 的值
function looksLikeId(v) {
  return v !== '' && !/[\s]/.test(v);
}

function ruleMatches(rule, entryTag, elemTag) {
  if (rule.elem !== elemTag) return false;
  if (rule.entry === '*') return true;
  return entryTag.startsWith(rule.entry);
}

/**
 * 从合并后的条目节点提取全部跨 catalog 引用。
 * @param {object} entryNode 顶层条目元素（合并后）
 * @returns {{target:string,id:string,file:string,line:number,via:string}[]}
 */
export function extractRefs(entryNode) {
  const refs = [];
  const entryTag = entryNode.tag;

  const pushRef = (target, rawValue, node, via, split) => {
    if (rawValue == null) return;
    const values = split ? rawValue.split(split) : [rawValue];
    for (const v of values.map(s => s.trim())) {
      if (!looksLikeId(v)) continue;
      refs.push({ target, id: v, file: node.file, line: node.line, via });
    }
  };

  // 条目根元素上的属性规则（#entry）+ parent
  if (entryNode.attrs.parent) {
    refs.push({
      target: '#same', id: entryNode.attrs.parent,
      file: entryNode.file, line: entryNode.line, via: '@parent',
    });
  }
  for (const rule of ACTIVE_RULES) {
    if (rule.elem !== '#entry') continue;
    if (rule.entry !== '*' && !entryTag.startsWith(rule.entry)) continue;
    if (rule.attr in entryNode.attrs) {
      pushRef(rule.target, entryNode.attrs[rule.attr], entryNode, `@${rule.attr}`, rule.split);
    }
  }

  const walk = (node) => {
    for (const child of node.children) {
      if (child.attrs.removed === '1') continue;

      // 声明式规则
      for (const rule of ACTIVE_RULES) {
        if (rule.elem === '#entry') continue;
        if (!ruleMatches(rule, entryTag, child.tag)) continue;
        if (rule.attr in child.attrs) {
          pushRef(rule.target, child.attrs[rule.attr], child, `${child.tag}/@${rule.attr}`, rule.split);
        }
      }

      // 特殊：LayoutButtons/@AbilCmd = "AbilId,CmdIndex"
      if (child.tag === 'LayoutButtons' && child.attrs.AbilCmd) {
        const abilId = child.attrs.AbilCmd.split(',')[0].trim();
        if (looksLikeId(abilId)) {
          refs.push({ target: 'Abil', id: abilId, file: child.file, line: child.line, via: 'LayoutButtons/@AbilCmd' });
        }
      }

      // 特殊：@Reference="Catalog,Id,FieldPath"（CUpgrade EffectArray 等）
      if (child.attrs.Reference) {
        const parts = child.attrs.Reference.split(',');
        if (parts.length >= 2) {
          const cat = parts[0].trim();
          const id = parts[1].trim();
          if (looksLikeId(cat) && looksLikeId(id)) {
            refs.push({ target: cat, id, file: child.file, line: child.line, via: `${child.tag}/@Reference` });
          }
        }
      }

      // 特殊：CRequirementCountXxx 的 Count/@Link
      if (child.tag === 'Count' && child.attrs.Link && entryTag.startsWith('CRequirement')) {
        for (const [prefix, target] of COUNT_TARGET) {
          if (entryTag.startsWith(prefix)) {
            pushRef(target, child.attrs.Link, child, 'Count/@Link');
            break;
          }
        }
      }

      // 特殊：CRequirement 逻辑节点的 OperandArray → RequirementNode
      // （纯数字 value 是常量节点 id，通常定义在官方 core 数据里，跳过以降噪）
      if (child.tag === 'OperandArray' && entryTag.startsWith('CRequirement')) {
        const v = (child.attrs.value ?? child.attrs.Link ?? '').trim();
        if (looksLikeId(v) && !/^\d+$/.test(v)) {
          refs.push({ target: 'RequirementNode', id: v, file: child.file, line: child.line, via: 'OperandArray' });
        }
      }

      walk(child);
    }
  };
  walk(entryNode);
  return refs;
}

/** 支持校验的目标 catalog 集合（用于 README/自检） */
export function coveredTargets() {
  const set = new Set(ACTIVE_RULES.map(r => r.target));
  set.add('Abil'); set.add('RequirementNode');
  set.delete('#same');
  return [...set].sort();
}
