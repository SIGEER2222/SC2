// src/types.ts
export type Severity = 'error' | 'warning' | 'info';

export interface Issue {
  file: string;
  line: number;
  column: number;
  ruleCode: string;
  severity: Severity;
  message: string;
}

export interface CheckResult {
  filesChecked: number;
  issues: Issue[];
  summary: { errors: number; warnings: number; infos: number };
}

export interface CheckOptions {
  rulesPath?: string;
  nativeLibPath?: string;
  globalSymbolGlobs?: string[];
  noGlobalSymbols?: boolean;
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
