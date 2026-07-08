// src/lexer/tokens.ts
import { createToken, Lexer, type IToken } from 'chevrotain';
import { GALAXY_TYPES } from '../types.js';

function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

// 标识符（必须先定义，让其他关键字用 longer_alt 引用它）
const Identifier = createToken({ name: 'Identifier', pattern: /[a-zA-Z_][a-zA-Z0-9_]*/ });

// 关键字
const If = createToken({ name: 'If', pattern: /if/, longer_alt: Identifier });
const Else = createToken({ name: 'Else', pattern: /else/, longer_alt: Identifier });
const While = createToken({ name: 'While', pattern: /while/, longer_alt: Identifier });
const For = createToken({ name: 'For', pattern: /for/, longer_alt: Identifier });
const Return = createToken({ name: 'Return', pattern: /return/, longer_alt: Identifier });
const Break = createToken({ name: 'Break', pattern: /break/, longer_alt: Identifier });
const Continue = createToken({ name: 'Continue', pattern: /continue/, longer_alt: Identifier });
const Struct = createToken({ name: 'Struct', pattern: /struct/, longer_alt: Identifier });
const Enum = createToken({ name: 'Enum', pattern: /enum/, longer_alt: Identifier });
const Typedef = createToken({ name: 'Typedef', pattern: /typedef/, longer_alt: Identifier });
const Include = createToken({ name: 'Include', pattern: /include/, longer_alt: Identifier });
const Const = createToken({ name: 'Const', pattern: /const/, longer_alt: Identifier });
const Native = createToken({ name: 'Native', pattern: /native/, longer_alt: Identifier });
const Static = createToken({ name: 'Static', pattern: /static/, longer_alt: Identifier });
const True = createToken({ name: 'True', pattern: /true/, longer_alt: Identifier });
const False = createToken({ name: 'False', pattern: /false/, longer_alt: Identifier });
const Null = createToken({ name: 'Null', pattern: /null/, longer_alt: Identifier });

// 类型关键字
const TypeTokens = GALAXY_TYPES.map(t =>
  createToken({ name: capitalize(t), pattern: new RegExp(`\\b${t}\\b`), longer_alt: Identifier })
);

// 字面量（Fixed 必须在 Integer 之前：更具体的 token 先定义，
// 避免 Chevrotain 优化路径下 Integer 先消费数字导致 Fixed 失配）
const Fixed = createToken({ name: 'Fixed', pattern: /[0-9]+\.[0-9]+f?/ });
const Integer = createToken({ name: 'Integer', pattern: /[0-9]+/ });
const String = createToken({ name: 'String', pattern: /"(?:[^"\\]|\\.)*"/ });
const Char = createToken({ name: 'Char', pattern: /'(?:[^'\\]|\\.)'/ });

// 注释（先于运算符，避免 // 被识别为斜杠）
// 注释保留在 tokens 中（不设 SKIPPED），便于后续 RuleEngine 利用注释位置信息
const LineComment = createToken({
  name: 'LineComment',
  pattern: /\/\/[^\n\r]*/,
});
const BlockComment = createToken({
  name: 'BlockComment',
  pattern: /\/\*[\s\S]*?\*\//,
});

// 运算符（多字符先于单字符）
const EqualsEquals = createToken({ name: 'EqualsEquals', pattern: /==/ });
const ExclamationEquals = createToken({ name: 'ExclamationEquals', pattern: /!=/ });
const LessEquals = createToken({ name: 'LessEquals', pattern: /<=/ });
const GreaterEquals = createToken({ name: 'GreaterEquals', pattern: />=/ });
const AmpersandAmpersand = createToken({ name: 'AmpersandAmpersand', pattern: /&&/ });
const PipePipe = createToken({ name: 'PipePipe', pattern: /\|\|/ });
const PlusPlus = createToken({ name: 'PlusPlus', pattern: /\+\+/ });
const MinusMinus = createToken({ name: 'MinusMinus', pattern: /--/ });
const PlusEquals = createToken({ name: 'PlusEquals', pattern: /\+=/ });
const MinusEquals = createToken({ name: 'MinusEquals', pattern: /-=/ });
const StarEquals = createToken({ name: 'StarEquals', pattern: /\*=/ });
const SlashEquals = createToken({ name: 'SlashEquals', pattern: /\/=/ });
const Arrow = createToken({ name: 'Arrow', pattern: /->/ });

const LBrace = createToken({ name: 'LBrace', pattern: /{/ });
const RBrace = createToken({ name: 'RBrace', pattern: /}/ });
const LParen = createToken({ name: 'LParen', pattern: /\(/ });
const RParen = createToken({ name: 'RParen', pattern: /\)/ });
const LBracket = createToken({ name: 'LBracket', pattern: /\[/ });
const RBracket = createToken({ name: 'RBracket', pattern: /\]/ });

const Semicolon = createToken({ name: 'Semicolon', pattern: /;/ });
const Comma = createToken({ name: 'Comma', pattern: /,/ });
const Dot = createToken({ name: 'Dot', pattern: /\./ });
const Colon = createToken({ name: 'Colon', pattern: /:/ });
const Question = createToken({ name: 'Question', pattern: /\?/ });

const Equals = createToken({ name: 'Equals', pattern: /=/ });
const Exclamation = createToken({ name: 'Exclamation', pattern: /!/ });
const Less = createToken({ name: 'Less', pattern: /</ });
const Greater = createToken({ name: 'Greater', pattern: />/ });
const Plus = createToken({ name: 'Plus', pattern: /\+/ });
const Minus = createToken({ name: 'Minus', pattern: /-/ });
const Star = createToken({ name: 'Star', pattern: /\*/ });
const Slash = createToken({ name: 'Slash', pattern: /\// });
const Percent = createToken({ name: 'Percent', pattern: /%/ });
const Ampersand = createToken({ name: 'Ampersand', pattern: /&/ });
const Pipe = createToken({ name: 'Pipe', pattern: /\|/ });
const Caret = createToken({ name: 'Caret', pattern: /\^/ });
const Tilde = createToken({ name: 'Tilde', pattern: /~/ });

// 空白（跳过，不出现在 tokens 中）
const WhiteSpace = createToken({
  name: 'WhiteSpace',
  pattern: /[ \t\n\r]+/,
  group: Lexer.SKIPPED,
});

// 所有 token（顺序重要！）
// Chevrotain 要求：关键字先于 Identifier 才能用 longer_alt 区分
// 但实际上 longer_alt 的语义是"如果匹配到关键字但后面有更长的标识符，就用 longer_alt"
// Chevrotain 文档示例都是关键字在 Identifier 之前定义
const allTokens = [
  WhiteSpace,
  LineComment,
  BlockComment,
  // 关键字先于 Identifier
  If, Else, While, For, Return, Break, Continue,
  Struct, Enum, Typedef, Include, Const, Native, Static,
  True, False, Null,
  ...TypeTokens,
  Identifier,
  Fixed, Integer, String, Char,
  // 多字符运算符先于单字符
  EqualsEquals, ExclamationEquals, LessEquals, GreaterEquals,
  AmpersandAmpersand, PipePipe, PlusPlus, MinusMinus,
  PlusEquals, MinusEquals, StarEquals, SlashEquals, Arrow,
  LBrace, RBrace, LParen, RParen, LBracket, RBracket,
  Semicolon, Comma, Dot, Colon, Question,
  Equals, Exclamation, Less, Greater, Plus, Minus, Star, Slash,
  Percent, Ampersand, Pipe, Caret, Tilde,
];

const GalaxyLexer = new Lexer(allTokens, {
  ensureOptimizations: false,
  recoveryEnabled: true,
});

export function tokenize(source: string): IToken[] {
  const result = GalaxyLexer.tokenize(source);
  return result.tokens;
}

export {
  allTokens,
  If, Else, While, For, Return, Break, Continue,
  Struct, Enum, Typedef, Include, Const, Native, Static,
  True, False, Null,
  Identifier, Integer, Fixed, String, Char,
  LineComment, BlockComment,
  EqualsEquals, ExclamationEquals, LessEquals, GreaterEquals,
  AmpersandAmpersand, PipePipe, PlusPlus, MinusMinus,
  PlusEquals, MinusEquals, StarEquals, SlashEquals, Arrow,
  LBrace, RBrace, LParen, RParen, LBracket, RBracket,
  Semicolon, Comma, Dot, Colon, Question,
  Equals, Exclamation, Less, Greater, Plus, Minus, Star, Slash,
  Percent, Ampersand, Pipe, Caret, Tilde,
  TypeTokens,
};
