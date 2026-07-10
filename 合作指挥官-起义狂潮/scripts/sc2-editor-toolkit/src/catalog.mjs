/**
 * Catalog 数据模型与 SC2 引擎合并语义
 *
 * 合并语义移植自 scripts/sc2_unit_explorer.py（Python 版已在真实 mod 上验证），
 * 并保留每个节点的 file/line 供 issue 定位：
 *   - 顶层条目按 (catalog, id) 合并，后加载的 mod 覆盖/叠加前者
 *   - 子元素按关键属性匹配：id > index > Row+Column > Array.value > Link
 *   - 无关键属性的叶子标量按同 tag 覆盖
 *   - removed="1" 从已合并结果中移除匹配子元素
 *   - 无关键属性的子元素视为追加
 */

// 精确 tag → catalog（优先于前缀匹配）
const EXACT_TAG_CATALOG = {
  CRequirement: 'Requirement',
  CUnit: 'Unit',
  CButton: 'Button',
  CUpgrade: 'Upgrade',
  CMover: 'Mover',
  CSound: 'Sound',
  CModel: 'Model',
  CAlert: 'Alert',
  CHerd: 'Herd',
  CLoot: 'Loot',
  CSkin: 'Skin',
};

// 前缀 → catalog（最长优先匹配）。
// 注意：CRequirementXxx（如 CRequirementCountUnit/CRequirementAnd）是
// RequirementNode catalog，与 CRequirement（精确）分属两个 catalog。
const PREFIX_TAG_CATALOG = [
  ['CRequirementNode', 'RequirementNode'],
  ['CRequirement', 'RequirementNode'],
  ['CValidator', 'Validator'],
  ['CAccumulator', 'Accumulator'],
  ['CBehavior', 'Behavior'],
  ['CEffect', 'Effect'],
  ['CWeapon', 'Weapon'],
  ['CTurret', 'Turret'],
  ['CTargetSort', 'TargetSort'],
  ['CTargetFind', 'TargetFind'],
  ['CKinetic', 'Kinetic'],
  ['CMover', 'Mover'],
  ['CActor', 'Actor'],
  ['CAbil', 'Abil'],
  ['CUnit', 'Unit'],
  ['CUpgrade', 'Upgrade'],
  ['CButton', 'Button'],
  ['CSound', 'Sound'],
  ['CModel', 'Model'],
];

/** CUnit → Unit, CEffectDamage → Effect, CFooBar → FooBar(通用回退), 非 C 开头 → null */
export function catalogForTag(tag) {
  if (EXACT_TAG_CATALOG[tag]) return EXACT_TAG_CATALOG[tag];
  for (const [prefix, cat] of PREFIX_TAG_CATALOG) {
    if (tag.startsWith(prefix)) return cat;
  }
  if (/^C[A-Z]/.test(tag)) return tag.slice(1); // 未知类：catalog 名 = 去掉 C 前缀
  return null;
}

export function deepClone(node) {
  return {
    tag: node.tag,
    attrs: { ...node.attrs },
    children: node.children.map(deepClone),
    line: node.line,
    col: node.col,
    file: node.file,
  };
}

/** 返回子元素用于匹配的关键属性名（SC2 合并语义） */
export function keyAttrs(elem) {
  if ('id' in elem.attrs) return ['id'];
  if ('index' in elem.attrs) return ['index'];
  if ('Row' in elem.attrs && 'Column' in elem.attrs) return ['Row', 'Column'];
  if ('value' in elem.attrs && elem.children.length === 0 && elem.tag.endsWith('Array')) return ['value'];
  if ('Link' in elem.attrs) return ['Link'];
  return [];
}

function matchKey(a, b, keys) {
  if (keys.length === 0) return false;
  return keys.every(k => a.attrs[k] === b.attrs[k]);
}

/** 将 src 的子元素合并进 dst（dst 会被修改；src 不动） */
export function mergeElement(dst, src) {
  // 先处理 removed="1"（移除 dst 中匹配的子元素，且不追加自身）
  for (const srcChild of src.children) {
    if (srcChild.attrs.removed === '1') {
      const keys = keyAttrs(srcChild);
      dst.children = dst.children.filter(
        d => !(d.tag === srcChild.tag && matchKey(d, srcChild, keys))
      );
    }
  }
  for (const srcChild of src.children) {
    if (srcChild.attrs.removed === '1') continue;
    const keys = keyAttrs(srcChild);
    const match = keys.length > 0
      ? dst.children.find(d => d.tag === srcChild.tag && matchKey(d, srcChild, keys))
      : srcChild.children.length === 0
        ? dst.children.find(d =>
            d.tag === srcChild.tag &&
            d.children.length === 0 &&
            keyAttrs(d).length === 0
          )
        : null;
    if (match) {
      for (const [k, v] of Object.entries(srcChild.attrs)) {
        if (k !== 'removed') match.attrs[k] = v;
      }
      mergeElement(match, srcChild);
    } else {
      dst.children.push(deepClone(srcChild));
    }
  }
}

/** CardLayouts 无 index 时引擎按 index="0" 处理（否则多 mod 的 CardLayouts 无法对齐合并） */
export function normalizeEntry(elem) {
  for (const child of elem.children) {
    if (child.tag === 'CardLayouts' && !('index' in child.attrs)) {
      child.attrs.index = '0';
    }
  }
}

/**
 * Catalog 存储：{catalog → Map<id, entry>}
 * entry = { tag, id, node, sources: [{file, line, tag}] }
 * sources 记录每次（重新）定义/修改的位置，用于 duplicate/conflict 检查与归属判断。
 */
export class CatalogStore {
  constructor() {
    /** @type {Map<string, Map<string, {tag:string,id:string,node:object,sources:object[]}>>} */
    this.catalogs = new Map();
  }

  getEntry(catalog, id) {
    return this.catalogs.get(catalog)?.get(id);
  }

  has(catalog, id) {
    return this.catalogs.get(catalog)?.has(id) ?? false;
  }

  ids(catalog) {
    return this.catalogs.get(catalog) ?? new Map();
  }

  /** 合并一个顶层条目元素（含 file/line 元数据） */
  addEntry(elem) {
    const catalog = catalogForTag(elem.tag);
    if (!catalog || !elem.attrs.id) return null;
    const id = elem.attrs.id;
    let map = this.catalogs.get(catalog);
    if (!map) {
      map = new Map();
      this.catalogs.set(catalog, map);
    }
    normalizeEntry(elem);
    const existing = map.get(id);
    if (existing) {
      for (const [k, v] of Object.entries(elem.attrs)) {
        if (k !== 'removed') existing.node.attrs[k] = v;
      }
      mergeElement(existing.node, elem);
      existing.sources.push({ file: elem.file, line: elem.line, tag: elem.tag });
      return existing;
    }
    const entry = {
      tag: elem.tag,
      id,
      node: deepClone(elem),
      sources: [{ file: elem.file, line: elem.line, tag: elem.tag }],
    };
    map.set(id, entry);
    return entry;
  }

  /** 解析 parent 链（返回按 child→ancestor 顺序的 entry 数组，检测环） */
  parentChain(catalog, id) {
    const chain = [];
    const seen = new Set();
    let cur = this.getEntry(catalog, id);
    while (cur) {
      if (seen.has(cur.id)) return { chain, circular: true };
      seen.add(cur.id);
      chain.push(cur);
      const parentId = cur.node.attrs.parent;
      if (!parentId) break;
      cur = this.getEntry(catalog, parentId);
    }
    return { chain, circular: false };
  }

  /** 展开 parent 继承后的条目；返回 null 表示目标不存在。 */
  resolveEntry(catalog, id) {
    const target = this.getEntry(catalog, id);
    if (!target) return null;
    const parent = this.parentChain(catalog, id);
    const last = parent.chain.at(-1);
    const unresolvedParent = last?.node.attrs.parent &&
      !this.getEntry(catalog, last.node.attrs.parent)
      ? last.node.attrs.parent
      : null;
    let node = null;
    for (const entry of [...parent.chain].reverse()) {
      if (!node) {
        node = deepClone(entry.node);
        continue;
      }
      for (const [key, value] of Object.entries(entry.node.attrs)) {
        if (key !== 'removed') node.attrs[key] = value;
      }
      mergeElement(node, entry.node);
      node.file = entry.node.file;
      node.line = entry.node.line;
      node.col = entry.node.col;
      node.tag = entry.node.tag;
    }
    return {
      tag: target.tag,
      id,
      node,
      sources: target.sources,
      parentChain: parent.chain.map(entry => entry.id),
      parentCircular: parent.circular,
      unresolvedParent,
    };
  }
}
