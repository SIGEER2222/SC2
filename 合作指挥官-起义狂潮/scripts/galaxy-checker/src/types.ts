// src/types.ts
export type Severity = 'error' | 'warning' | 'info';

// 置信度：low=可能误报（缺依赖上下文）/ medium=需人工确认 / high=确信真实问题
export type Confidence = 'low' | 'medium' | 'high';

// 运行时风险：none=不影响运行 / low=风格问题 / medium=运行时降级 / high=ScriptError
export type RuntimeRisk = 'none' | 'low' | 'medium' | 'high';

export interface Issue {
  file: string;
  line: number;
  column: number;
  ruleCode: string;
  severity: Severity;
  message: string;
  // 工程化扩展字段（ADR 冻结）
  confidence?: Confidence;
  autoFixable?: boolean;
  runtimeRisk?: RuntimeRisk;
  // CI 模式门禁：true=阻塞提交，false=可延期清理
  blocking?: boolean;
  sourceDependency?: string;   // 导致此 issue 的依赖 mod（若可确定）
  suggestedOwner?: string;     // 建议修复责任方
}

export interface CheckResult {
  filesChecked: number;
  issues: Issue[];
  summary: { errors: number; warnings: number; infos: number };
  // 工程化扩展：带上下文信息的报告
  compositionId?: string;
  contextLoaded?: boolean;      // 是否加载了 CompositionPlan 上下文
}

export interface CheckOptions {
  rulesPath?: string;
  nativeLibPath?: string;
  globalSymbolGlobs?: string[];
  noGlobalSymbols?: boolean;
  symbolRoots?: string[];
  catalogDbPath?: string;
  // 新增：CompositionPlan 集成
  compositionPlanPath?: string;
}

// Catalog ID 数据库：从 sc2_unit_explorer.py --export-catalog-ids 导出的 JSON
// 用于校验 galaxy 脚本中传给 catalog native 的字符串字面量是否指向有效条目
// 使用 Set 实现 O(1) 查找（JSON 中的数组在 index.ts 加载时转换为 Set）
export interface CatalogDb {
  Unit?: Set<string>;
  Abil?: Set<string>;
  Upgrade?: Set<string>;
  Behavior?: Set<string>;
  Effect?: Set<string>;
  Button?: Set<string>;
  // any: 所有 C* 元素 ID 的并集（含 CWeapon/CActor/CValidator 等未单独跟踪的类型）
  // 用于 CatalogFieldValueGet/Set/Modify 等跨 catalog 查询
  any?: Set<string>;
}

// Galaxy 类型枚举（来自设计文档 §14.1）
export const GALAXY_TYPES = [
  'void', 'int', 'bool', 'unit', 'point', 'string', 'real', 'fixed', 'wave',
  'group', 'region', 'location', 'timer', 'trigger', 'bank', 'text',
  'unitfilter', 'unitgroup', 'playergroup', 'actor', 'sound', 'effect',
  'behavior', 'abilcmd', 'order', 'pathing', 'doodad', 'camera', 'quest',
  'dialog', 'image', 'movie', 'model', 'footprint', 'object',
  'transmissionsource', 'transmission', 'planet', 'conversation',
  'accomplishment', 'score', 'airgroup', 'groundgroup', 'anygroup',
] as const;

export type GalaxyType = typeof GALAXY_TYPES[number];

export interface FunctionSignature {
  name: string;
  returnType: string;
  params: { type: string; name: string }[];
  isNative: boolean;
}

// Fixer 相关类型
export interface FixEdit {
  file: string;
  line: number;
  column: number;
  oldText: string;
  newText: string;
  ruleCode: string;
  description: string;
}

export interface FixResult {
  applied: FixEdit[];
  skipped: Array<{ issue: Issue; reason: string }>;
  filesChanged: string[];
}

// 基线对比相关类型
export interface BaselineEntry {
  file: string;
  line: number;
  ruleCode: string;
  message: string;
}

export interface CompareResult {
  newIssues: Issue[];
  resolvedIssues: BaselineEntry[];
  unchangedCount: number;
  baselineTotal: number;
  currentTotal: number;
  currentResult: CheckResult;
}

// ScriptError 关联相关类型
export interface ScriptErrorEntry {
  rawLine: string;
  lineNumber: number;
  galaxyFile?: string;
  galaxyLine?: number;
  triggerName?: string;
  errorMessage?: string;
  correlatedIssue?: Issue;
  suggestions?: string[];
}

export interface CorrelationResult {
  totalErrors: number;
  parsed: ScriptErrorEntry[];
  correlated: number;
  unresolved: number;
  galaxyFilesChecked: Set<string>;
}
