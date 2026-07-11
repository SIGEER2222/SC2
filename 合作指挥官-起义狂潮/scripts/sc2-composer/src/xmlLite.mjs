/**
 * 轻量 XML 解析器（针对 SC2 GameData XML）
 *
 * 只解析标签名、属性和层级关系，不处理文本内容（SC2 GameData 数据全在属性上）。
 * 容忍 BOM、UTF-16 编码、缺失 <Catalog> 根包装。
 *
 * 输出节点结构：{ tag, attrs, children, line, col, file }
 */

const ENTITY_MAP = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" };

export function decodeEntities(s) {
  if (!s.includes('&')) return s;
  return s.replace(/&(#x?[0-9a-fA-F]+|\w+);/g, (m, body) => {
    if (body[0] === '#') {
      const code = body[1] === 'x' || body[1] === 'X'
        ? parseInt(body.slice(2), 16)
        : parseInt(body.slice(1), 10);
      return Number.isFinite(code) ? String.fromCodePoint(code) : m;
    }
    return ENTITY_MAP[body] ?? m;
  });
}

/** 按 BOM 探测编码并解码 Buffer；返回 { text, encoding } */
export function decodeBuffer(buf) {
  if (buf.length >= 2) {
    if (buf[0] === 0xff && buf[1] === 0xfe) {
      return { text: buf.toString('utf16le', 2), encoding: 'utf-16le' };
    }
    if (buf[0] === 0xfe && buf[1] === 0xff) {
      const swapped = Buffer.from(buf.subarray(2));
      swapped.swap16();
      return { text: swapped.toString('utf16le'), encoding: 'utf-16be' };
    }
  }
  let text = buf.toString('utf8');
  if (text.charCodeAt(0) === 0xfeff) text = text.slice(1);
  return { text, encoding: 'utf-8' };
}

function buildLineStarts(text) {
  const starts = [0];
  for (let i = 0; i < text.length; i++) {
    if (text.charCodeAt(i) === 10) starts.push(i + 1);
  }
  return starts;
}

function makeLocator(text) {
  const starts = buildLineStarts(text);
  return (pos) => {
    let lo = 0, hi = starts.length - 1;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (starts[mid] <= pos) lo = mid; else hi = mid - 1;
    }
    return { line: lo + 1, col: pos - starts[lo] + 1 };
  };
}

const ATTR_RE = /([A-Za-z_][\w.\-:]*)\s*=\s*(?:"([^"]*)"|'([^']*)')/g;

/**
 * 解析 XML 文本。
 * @param {string} text
 * @param {string} file 用于填充节点 file 字段与 issue 定位
 * @returns {{ roots: object[], issues: object[] }}
 */
export function parseXml(text, file = '<memory>') {
  const locate = makeLocator(text);
  const issues = [];
  const virtualRoot = { tag: '#document', attrs: {}, children: [], line: 1, col: 1, file };

  const stack = [virtualRoot];
  let i = 0;
  const n = text.length;

  while (i < n) {
    // 跳过非标签文本
    while (i < n && text[i] !== '<') i++;
    if (i >= n) break;

    // 处理注释 <!-- ... -->
    if (text.startsWith('<!--', i)) {
      const end = text.indexOf('-->', i + 4);
      i = end < 0 ? n : end + 3;
      continue;
    }

    // 处理 XML 声明 <?xml ... ?>
    if (text.startsWith('<?', i)) {
      const end = text.indexOf('?>', i + 2);
      i = end < 0 ? n : end + 2;
      continue;
    }

    // 处理 CDATA <![CDATA[ ... ]]>
    if (text.startsWith('<![CDATA[', i)) {
      const end = text.indexOf(']]>', i + 9);
      i = end < 0 ? n : end + 3;
      continue;
    }

    // 处理 DOCTYPE
    if (text.startsWith('<!', i)) {
      const end = text.indexOf('>', i + 2);
      i = end < 0 ? n : end + 1;
      continue;
    }

    const tagStart = i + 1;
    // 自闭合标签
    const selfCloseEnd = text.indexOf('/>', tagStart);
    const closeEnd = text.indexOf('>', tagStart);

    // 判断是否是结束标签
    if (text[tagStart] === '/') {
      const end = closeEnd < 0 ? n : closeEnd;
      const tagName = text.slice(tagStart + 1, end).trim().replace(/\/$/, '');
      if (stack.length > 1) {
        const top = stack[stack.length - 1];
        if (top.tag === tagName) {
          stack.pop();
        } else {
          // 标签不匹配，尝试恢复
          issues.push({
            line: locate(i).line, col: locate(i).col, code: 'XML-TAG-MISMATCH',
            message: `闭合标签 </${tagName}> 与当前打开的 <${top.tag}> 不匹配`,
          });
        }
      }
      i = end + 1;
      continue;
    }

    // 解析开始标签
    const end = closeEnd < 0 ? n : closeEnd;
    const isSelfClosing = selfCloseEnd >= 0 && selfCloseEnd < closeEnd;
    const tagContent = text.slice(tagStart, isSelfClosing ? selfCloseEnd : end).trim();
    const spaceIdx = tagContent.search(/[\s]/);
    const tagName = spaceIdx < 0 ? tagContent : tagContent.slice(0, spaceIdx);
    const attrText = spaceIdx < 0 ? '' : tagContent.slice(spaceIdx + 1);

    const attrs = {};
    ATTR_RE.lastIndex = 0;
    let m;
    while ((m = ATTR_RE.exec(attrText)) !== null) {
      attrs[m[1]] = decodeEntities(m[2] ?? m[3] ?? '');
    }

    const node = {
      tag: tagName,
      attrs,
      children: [],
      line: locate(i).line,
      col: locate(i).col,
      file,
    };

    stack[stack.length - 1].children.push(node);
    if (!isSelfClosing) {
      stack.push(node);
    }

    i = (isSelfClosing ? selfCloseEnd : end) + 1;
  }

  return { roots: virtualRoot.children, issues };
}

/**
 * 从 XML 根节点中提取所有指定类型的元素（深度优先）。
 * @param {object[]} roots
 * @param {string} tag 要查找的标签名
 * @returns {object[]}
 */
export function findAll(roots, tag) {
  const result = [];
  const visit = (nodes) => {
    for (const node of nodes) {
      if (node.tag === tag) result.push(node);
      if (node.children?.length) visit(node.children);
    }
  };
  visit(roots);
  return result;
}

/**
 * 判断 XML 内容是否是空的 <Catalog/> 或 <Catalog></Catalog>。
 * @param {object[]} roots
 * @returns {boolean}
 */
export function isEmptyCatalog(roots) {
  if (roots.length === 0) return true;
  const catalog = roots.find((n) => n.tag === 'Catalog');
  if (!catalog) return true;
  return (catalog.children?.length ?? 0) === 0;
}

/**
 * 提取 GameData.xml 中的 <Includes> 引用列表。
 * 支持两种格式：
 *   1. <Includes><Catalog path="GameData/X.xml"/></Includes>  （数据空间指南格式，根元素是 Includes）
 *   2. <Catalog><Includes><CatalogPath path="GameData/X.xml"/></Includes></Catalog>  （嵌套格式）
 * @param {object[]} roots
 * @returns {string[]} 引用的 path 列表
 */
export function extractIncludes(roots) {
  if (roots.length === 0) return [];

  // 格式 1：根元素是 <Includes>
  const includesRoot = roots.find((n) => n.tag === 'Includes');
  if (includesRoot) {
    return (includesRoot.children ?? [])
      .filter((c) => c.tag === 'Catalog')
      .map((c) => c.attrs.path)
      .filter(Boolean);
  }

  // 格式 2：<Catalog><Includes><CatalogPath .../></Includes></Catalog>
  const catalog = roots.find((n) => n.tag === 'Catalog');
  if (!catalog) return [];
  const includesNode = catalog.children?.find((c) => c.tag === 'Includes');
  if (!includesNode) return [];
  return (includesNode.children ?? [])
    .filter((c) => c.tag === 'CatalogPath')
    .map((c) => c.attrs.path)
    .filter(Boolean);
}
