/**
 * 宽容 XML 解析器（针对 SC2 GameData XML 的已知怪癖）
 *
 * 与通用 XML 解析器的区别：
 *   1. 忽略 XML 声明中的 encoding（部分文件声明 us-ascii 但内容含中文）→ 统一按 UTF-8 解码
 *   2. 容忍缺失 <Catalog> 根包装（多个顶层元素并列）
 *   3. 容忍 BOM、UTF-16 编码（按 BOM 探测）
 *   4. 标签不闭合 / 多余闭合标签时尽量恢复而不是整体失败
 *   5. 每个元素记录源文件与行号（供 issue 定位，编辑器式体验）
 *
 * 输出节点结构：{ tag, attrs, children, line, col, file }
 * 文本节点被丢弃（SC2 GameData 全部数据在属性上）。
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
      // Node 无内建 utf16be：手动交换字节
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
 *   issues 为解析级问题：{ line, col, code, message }（severity 由上层决定）
 */
export function parseXml(text, file = '<memory>') {
  const locate = makeLocator(text);
  const issues = [];
  const virtualRoot = { tag: '#document', attrs: {}, children: [], line: 1, col: 1, file };
  const stack = [virtualRoot];
  let pos = 0;
  const len = text.length;

  // 编码声明与实际内容不符检测
  const declMatch = /^\uFEFF?\s*<\?xml[^?]*encoding\s*=\s*["']([^"']+)["']/i.exec(text);
  if (declMatch) {
    const declared = declMatch[1].toLowerCase();
    if ((declared === 'us-ascii' || declared === 'ascii') && /[^\x00-\x7F]/.test(text)) {
      issues.push({
        line: 1, col: 1, code: 'XML_ENCODING_MISMATCH',
        message: `XML 声明编码为 ${declMatch[1]}，但内容含非 ASCII 字符（已按 UTF-8 解析）`,
      });
    }
  }

  while (pos < len) {
    const lt = text.indexOf('<', pos);
    if (lt < 0) break;
    pos = lt;

    // 注释
    if (text.startsWith('<!--', pos)) {
      const end = text.indexOf('-->', pos + 4);
      if (end < 0) {
        const { line, col } = locate(pos);
        issues.push({ line, col, code: 'XML_PARSE_ERROR', message: '注释未闭合（到文件末尾）' });
        break;
      }
      pos = end + 3;
      continue;
    }
    // 处理指令 <?xml ... ?>
    if (text.startsWith('<?', pos)) {
      const end = text.indexOf('?>', pos + 2);
      pos = end < 0 ? len : end + 2;
      continue;
    }
    // <!DOCTYPE / <![CDATA[
    if (text.startsWith('<!', pos)) {
      if (text.startsWith('<![CDATA[', pos)) {
        const end = text.indexOf(']]>', pos + 9);
        pos = end < 0 ? len : end + 3;
      } else {
        const end = text.indexOf('>', pos + 2);
        pos = end < 0 ? len : end + 1;
      }
      continue;
    }
    // 闭合标签
    if (text.startsWith('</', pos)) {
      const end = text.indexOf('>', pos + 2);
      if (end < 0) break;
      const name = text.slice(pos + 2, end).trim();
      // 在栈中向上找匹配
      let found = -1;
      for (let i = stack.length - 1; i >= 1; i--) {
        if (stack[i].tag === name) { found = i; break; }
      }
      if (found < 0) {
        const { line, col } = locate(pos);
        issues.push({ line, col, code: 'XML_PARSE_ERROR', message: `多余的闭合标签 </${name}>（已忽略）` });
      } else {
        if (found !== stack.length - 1) {
          const { line, col } = locate(pos);
          const unclosed = stack.slice(found + 1).map(n => n.tag).join(', ');
          issues.push({ line, col, code: 'XML_PARSE_ERROR', message: `标签未闭合：${unclosed}（在 </${name}> 处自动闭合）` });
        }
        stack.length = found;
      }
      pos = end + 1;
      continue;
    }

    // 开始标签
    const nameMatch = /^<([A-Za-z_][\w.\-:]*)/.exec(text.slice(pos, pos + 256));
    if (!nameMatch) {
      const { line, col } = locate(pos);
      issues.push({ line, col, code: 'XML_PARSE_ERROR', message: `无法识别的标记 "${text.slice(pos, pos + 20).replace(/\s+/g, ' ')}..."（跳过）` });
      pos += 1;
      continue;
    }
    const tag = nameMatch[1];
    // 找标签结束的 '>'（跳过引号内的 '>'）
    let i = pos + nameMatch[0].length;
    let quote = null;
    let gtPos = -1;
    for (; i < len; i++) {
      const ch = text[i];
      if (quote) {
        if (ch === quote) quote = null;
      } else if (ch === '"' || ch === "'") {
        quote = ch;
      } else if (ch === '>') {
        gtPos = i;
        break;
      } else if (ch === '<') {
        break; // 标签未闭合，下一个标签开始了
      }
    }
    const { line, col } = locate(pos);
    if (gtPos < 0) {
      issues.push({ line, col, code: 'XML_PARSE_ERROR', message: `标签 <${tag}> 缺少 ">"（尝试恢复）` });
      gtPos = i < len ? i - 1 : len - 1;
    }
    const attrText = text.slice(pos + nameMatch[0].length, gtPos);
    const selfClosing = /\/\s*$/.test(attrText);
    const attrs = {};
    ATTR_RE.lastIndex = 0;
    let m;
    while ((m = ATTR_RE.exec(attrText)) !== null) {
      attrs[m[1]] = decodeEntities(m[2] ?? m[3] ?? '');
    }
    const node = { tag, attrs, children: [], line, col, file };
    stack[stack.length - 1].children.push(node);
    if (!selfClosing) stack.push(node);
    pos = gtPos + 1;
  }

  if (stack.length > 1) {
    const unclosed = stack.slice(1).map(n => `${n.tag}(第${n.line}行)`).join(', ');
    issues.push({ line: locate(len - 1).line, col: 1, code: 'XML_PARSE_ERROR', message: `文件结束时仍有未闭合标签：${unclosed}` });
  }

  return { roots: virtualRoot.children, issues };
}

/**
 * 解析一份 GameData XML：处理 <Catalog> 包装缺失，返回顶层条目元素列表。
 * @returns {{ entries: object[], consts: object[], issues: object[] }}
 */
export function parseCatalogXml(text, file = '<memory>') {
  const { roots, issues } = parseXml(text, file);
  const entries = [];
  const consts = [];
  let sawCatalog = false;
  let sawBareEntry = false;

  const collect = (elem) => {
    if (elem.tag === 'const') consts.push(elem);
    else entries.push(elem);
  };

  for (const root of roots) {
    if (root.tag === 'Catalog') {
      sawCatalog = true;
      for (const child of root.children) collect(child);
    } else {
      sawBareEntry = true;
      collect(root);
    }
  }
  if (sawBareEntry) {
    issues.push({
      line: 1, col: 1, code: 'XML_MISSING_CATALOG_ROOT',
      message: sawCatalog
        ? '存在 <Catalog> 之外的顶层元素（已一并收录）'
        : '缺少 <Catalog> 根包装（已自动包装解析）',
    });
  }
  return { entries, consts, issues };
}
