// src/fixer/Fixer.ts
import { readFileSync, writeFileSync } from 'node:fs';
import { basename } from 'node:path';
import type { Issue, FixEdit, FixResult } from '../types.js';

/**
 * 解析函数调用的参数列表，返回每个参数的文本范围。
 * 正确处理嵌套括号、字符串字面量。
 */
function parseCallArgs(source: string, callStart: number): { args: Array<{ start: number; end: number; text: string }>; callEnd: number } | null {
  // callStart 指向 '(' 的位置
  if (source[callStart] !== '(') return null;
  const args: Array<{ start: number; end: number; text: string }> = [];
  let depth = 0;
  let i = callStart;
  let argStart = callStart + 1;

  while (i < source.length) {
    const ch = source[i];
    // 跳过字符串字面量
    if (ch === '"') {
      i++;
      while (i < source.length && source[i] !== '"') {
        if (source[i] === '\\') i++; // 跳过转义
        i++;
      }
      i++;
      continue;
    }
    if (ch === '(') depth++;
    else if (ch === ')') {
      depth--;
      if (depth === 0) {
        // 最后一个参数
        if (argStart < i) {
          args.push({ start: argStart, end: i, text: source.slice(argStart, i).trim() });
        }
        return { args, callEnd: i + 1 };
      }
    } else if (ch === ',' && depth === 1) {
      args.push({ start: argStart, end: i, text: source.slice(argStart, i).trim() });
      argStart = i + 1;
    }
    i++;
  }
  return null;
}

/**
 * 查找文件中所有 UnitCreate( 调用的位置。
 */
function findUnitCreateCalls(source: string): Array<{ nameStart: number; callStart: number; line: number; column: number }> {
  const calls: Array<{ nameStart: number; callStart: number; line: number; column: number }> = [];
  const regex = /\bUnitCreate\s*\(/g;
  let m: RegExpExecArray | null;
  while ((m = regex.exec(source)) !== null) {
    const nameStart = m.index;
    // 找到 '(' 的位置
    const callStart = source.indexOf('(', nameStart + m[0].length - 1);
    if (callStart === -1) continue;
    // 计算行号和列号
    const before = source.slice(0, nameStart);
    const line = before.split('\n').length;
    const lastNewline = before.lastIndexOf('\n');
    const column = lastNewline === -1 ? nameStart + 1 : nameStart - lastNewline;
    calls.push({ nameStart, callStart, line, column });
  }
  return calls;
}

/**
 * XLIB_DISCOURAGED_NATIVE fixer：
 * 将 UnitCreate(count, unitType, createStyle, player, pos, angle)
 * 替换为 libNtve_gf_CreateUnitsAtPoint2(count, unitType, player, pos, angle)
 *
 * 签名差异：UnitCreate 有 6 个参数（含 createStyle），
 * libNtve_gf_CreateUnitsAtPoint2 有 5 个参数（无 createStyle）。
 *
 * 安全约束：libNtve_gf_CreateUnitsAtPoint2 内部使用 c_unitCreateIgnorePlacement，
 * 因此只有当原调用的 createStyle 参数为 c_unitCreateIgnorePlacement 时才安全转换。
 * 其他 createStyle 值（如 0=c_unitCreateConstruct）会改变放置验证行为，必须跳过。
 *
 * 仅当调用恰好 6 个参数且 createStyle 匹配时自动修复，其他情况跳过（需人工确认）。
 */
export function fixDiscouragedUnitCreate(filePath: string): FixEdit[] {
  const source = readFileSync(filePath, 'utf-8').replace(/^\uFEFF/, '');
  const calls = findUnitCreateCalls(source);
  const edits: FixEdit[] = [];

  for (const call of calls) {
    const parsed = parseCallArgs(source, call.callStart);
    if (!parsed || parsed.args.length !== 6) continue;

    // 安全检查：只有 createStyle = c_unitCreateIgnorePlacement 时才转换
    // libNtve_gf_CreateUnitsAtPoint2 内部硬编码使用 c_unitCreateIgnorePlacement
    const createStyle = parsed.args[2].text.trim();
    if (createStyle !== 'c_unitCreateIgnorePlacement') continue;

    // 构造新调用：去掉第 3 个参数（createStyle，index=2）
    const newArgs = [
      parsed.args[0].text,
      parsed.args[1].text,
      parsed.args[3].text,
      parsed.args[4].text,
      parsed.args[5].text,
    ].join(', ');

    const oldText = source.slice(call.nameStart, parsed.callEnd);
    const newText = `libNtve_gf_CreateUnitsAtPoint2(${newArgs})`;

    edits.push({
      file: basename(filePath),
      line: call.line,
      column: call.column,
      oldText,
      newText,
      ruleCode: 'XLIB_DISCOURAGED_NATIVE',
      description: `包装 UnitCreate() 为 libNtve_gf_CreateUnitsAtPoint2()（createStyle=c_unitCreateIgnorePlacement，安全转换）`,
    });
  }
  return edits;
}

/**
 * 对单个文件应用所有 fix edits。
 * 返回实际应用的 edit 列表。
 */
export function applyEdits(filePath: string, edits: FixEdit[]): FixEdit[] {
  if (edits.length === 0) return [];
  let source = readFileSync(filePath, 'utf-8').replace(/^\uFEFF/, '');
  const applied: FixEdit[] = [];

  // 按位置倒序排列，从后往前替换避免偏移
  const sorted = [...edits].sort((a, b) => b.line - a.line || b.column - a.column);

  for (const edit of sorted) {
    // 在 source 中查找 oldText
    const idx = source.indexOf(edit.oldText);
    if (idx === -1) continue;
    source = source.slice(0, idx) + edit.newText + source.slice(idx + edit.oldText.length);
    applied.push(edit);
  }

  if (applied.length > 0) {
    // 写回文件（无 BOM）
    writeFileSync(filePath, source, 'utf-8');
  }
  return applied;
}

/**
 * 主 fixer 入口：对一组文件执行指定规则的自动修复。
 * dryRun=true 时只返回预览 edit，不写回文件。
 */
export function runFixer(files: string[], ruleCode: string, dryRun = false): FixResult {
  const applied: FixEdit[] = [];
  const skipped: Array<{ issue: Issue; reason: string }> = [];
  const filesChanged = new Set<string>();

  for (const file of files) {
    let edits: FixEdit[] = [];
    if (ruleCode === 'XLIB_DISCOURAGED_NATIVE') {
      edits = fixDiscouragedUnitCreate(file);
    }
    if (edits.length > 0) {
      if (dryRun) {
        // dry-run 模式：只收集 edit 不写文件
        applied.push(...edits);
      } else {
        const appliedEdits = applyEdits(file, edits);
        applied.push(...appliedEdits);
        if (appliedEdits.length > 0) filesChanged.add(file);
      }
    }
  }

  return { applied, skipped, filesChanged: dryRun ? [] : [...filesChanged] };
}
