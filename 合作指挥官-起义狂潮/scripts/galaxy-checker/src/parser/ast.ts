// src/parser/ast.ts
export interface Position {
  line: number;
  column: number;
  offset: number;
}

export interface Node {
  type: string;
  start?: Position;
  end?: Position;
}

// 顶层声明
export interface Program extends Node {
  type: 'Program';
  body: TopLevelDeclaration[];
}

export type TopLevelDeclaration =
  | FunctionDeclaration
  | VariableDeclaration
  | IncludeDirective
  | StructDeclaration
  | EnumDeclaration
  | TypedefDeclaration;

export interface IncludeDirective extends Node {
  type: 'Include';
  path: string;
}

export interface FunctionDeclaration extends Node {
  type: 'FunctionDeclaration';
  returnType: string;
  name: string;
  params: { type: string; name: string; isArray?: boolean }[];
  body: BlockStatement | null;
  isNative: boolean;
  isStatic: boolean;
}

export interface VariableDeclaration extends Node {
  type: 'VariableDeclaration';
  varType: string;
  name: string;
  isArray?: boolean;
  arrayDimensions: (Expression | null)[];
  init: Expression | null;
  isConst: boolean;
  isStatic: boolean;
}

export interface StructDeclaration extends Node {
  type: 'StructDeclaration';
  name: string;
  members: (VariableDeclaration | FunctionDeclaration)[];
}

export interface EnumDeclaration extends Node {
  type: 'EnumDeclaration';
  name: string;
  members: string[];
}

export interface TypedefDeclaration extends Node {
  type: 'TypedefDeclaration';
  name: string;
  alias: string;
}

// 语句
export interface BlockStatement extends Node {
  type: 'BlockStatement';
  body: Statement[];
}

export type Statement =
  | VariableDeclaration
  | ExpressionStatement
  | IfStatement
  | WhileStatement
  | DoWhileStatement
  | ForStatement
  | ReturnStatement
  | BreakStatement
  | ContinueStatement
  | BlockStatement;

export interface ExpressionStatement extends Node {
  type: 'ExpressionStatement';
  expression: Expression;
}

export interface IfStatement extends Node {
  type: 'IfStatement';
  test: Expression;
  consequent: Statement;
  alternate: Statement | null;
}

export interface WhileStatement extends Node {
  type: 'WhileStatement';
  test: Expression;
  body: Statement;
}

export interface DoWhileStatement extends Node {
  type: 'DoWhileStatement';
  test: Expression;
  body: Statement;
}

export interface ForStatement extends Node {
  type: 'ForStatement';
  init: Statement | null;
  test: Expression | null;
  update: Expression | null;
  body: Statement;
}

export interface ReturnStatement extends Node {
  type: 'ReturnStatement';
  argument: Expression | null;
}

export interface BreakStatement extends Node {
  type: 'BreakStatement';
}

export interface ContinueStatement extends Node {
  type: 'ContinueStatement';
}

// 表达式
export type Expression =
  | Identifier
  | Literal
  | BinaryExpression
  | UnaryExpression
  | AssignmentExpression
  | CallExpression
  | MemberExpression
  | IndexExpression
  | ConditionalExpression;

export interface Identifier extends Node {
  type: 'Identifier';
  name: string;
}

export interface Literal extends Node {
  type: 'Literal';
  value: string | number | boolean | null;
  literalType: 'integer' | 'fixed' | 'string' | 'char' | 'bool' | 'null';
}

export interface BinaryExpression extends Node {
  type: 'BinaryExpression';
  operator: string;
  left: Expression;
  right: Expression;
}

export interface UnaryExpression extends Node {
  type: 'UnaryExpression';
  operator: string;
  argument: Expression;
  prefix: boolean;
}

export interface AssignmentExpression extends Node {
  type: 'AssignmentExpression';
  operator: string;
  left: Expression;
  right: Expression;
}

export interface CallExpression extends Node {
  type: 'CallExpression';
  callee: Expression;
  arguments: Expression[];
}

export interface MemberExpression extends Node {
  type: 'MemberExpression';
  object: Expression;
  property: Expression;
  computed: boolean;
}

export interface IndexExpression extends Node {
  type: 'IndexExpression';
  object: Expression;
  index: Expression;
}

export interface ConditionalExpression extends Node {
  type: 'ConditionalExpression';
  test: Expression;
  consequent: Expression;
  alternate: Expression;
}
