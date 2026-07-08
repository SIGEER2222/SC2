// src/parser/GalaxyParser.ts
import { EmbeddedActionsParser, type IToken } from 'chevrotain';
import * as tok from '../lexer/tokens.js';
import { GALAXY_TYPES } from '../types.js';
import type * as ast from './ast.js';

export class GalaxyParser extends EmbeddedActionsParser {
  constructor() {
    super(tok.allTokens, { recoveryEnabled: true, nodeLocationTracking: 'full' });
    this.performSelfAnalysis();
  }

  // 顶层规则
  // 注：functionDeclaration 与 globalVarDeclaration 共享前缀（如 [static, type, Identifier]），
  // 但 4-token lookahead 能通过第 4 个 token（`(` vs `;`/`[`/`=`）区分两者。
  // 因此用 IGNORE_AMBIGUITIES 抑制歧义检测器的误报，解析路径仍由 lookahead 正确路由。
  public program = this.RULE('program', () => {
    const body: ast.TopLevelDeclaration[] = [];
    this.MANY(() => {
      this.OR({
        IGNORE_AMBIGUITIES: true,
        DEF: [
          { ALT: () => body.push(this.SUBRULE(this.includeDirective) as any) },
          { ALT: () => body.push(this.SUBRULE(this.functionDeclaration) as any) },
          { ALT: () => body.push(this.SUBRULE(this.globalVarDeclaration) as any) },
          { ALT: () => body.push(this.SUBRULE(this.structDeclaration) as any) },
          { ALT: () => body.push(this.SUBRULE(this.enumDeclaration) as any) },
          { ALT: () => body.push(this.SUBRULE(this.typedefDeclaration) as any) },
        ],
      });
    });
    return { type: 'Program', body } as ast.Program;
  });

  // include "path";
  private includeDirective = this.RULE('includeDirective', () => {
    this.CONSUME(tok.Include);
    const pathTok = this.CONSUME(tok.String);
    this.CONSUME(tok.Semicolon);
    return {
      type: 'Include',
      path: pathTok.image.slice(1, -1),
    } as ast.IncludeDirective;
  });

  // 类型名：Galaxy 类型关键字 或 Identifier（struct/typedef 别名）
  private typeName = this.RULE('typeName', () => {
    // 用 OR 列出所有类型关键字
    const typeAlternatives = GALAXY_TYPES.map(t => ({
      ALT: () => {
        const tk = this.CONSUME((tok.TypeTokens as any)[GALAXY_TYPES.indexOf(t)]);
        return tk.image;
      },
    }));
    typeAlternatives.push({
      ALT: () => {
        const tk = this.CONSUME(tok.Identifier);
        return tk.image;
      },
    });
    return this.OR(typeAlternatives);
  });

  // 函数声明
  private functionDeclaration = this.RULE('functionDeclaration', () => {
    let isNative = false;
    let isStatic = false;

    this.OPTION(() => {
      this.CONSUME(tok.Native);
      isNative = true;
    });
    this.OPTION2(() => {
      this.CONSUME(tok.Static);
      isStatic = true;
    });

    const returnType = this.SUBRULE(this.typeName);
    const nameTok = this.CONSUME(tok.Identifier);
    this.CONSUME(tok.LParen);

    const params: { type: string; name: string; isArray?: boolean }[] = [];
    this.OPTION3(() => {
      params.push(this.SUBRULE(this.paramDeclaration));
      this.MANY(() => {
        this.CONSUME(tok.Comma);
        params.push(this.SUBRULE2(this.paramDeclaration));
      });
    });

    this.CONSUME(tok.RParen);

    let body: ast.BlockStatement | null = null;
    if (!isNative) {
      body = this.SUBRULE(this.blockStatement) as any;
    } else {
      this.CONSUME(tok.Semicolon);
    }

    return {
      type: 'FunctionDeclaration',
      returnType,
      name: nameTok.image,
      params,
      body,
      isNative,
      isStatic,
    } as ast.FunctionDeclaration;
  });

  // 参数声明
  private paramDeclaration = this.RULE('paramDeclaration', () => {
    const type = this.SUBRULE(this.typeName);
    const nameTok = this.CONSUME(tok.Identifier);
    let isArray = false;
    this.OPTION(() => {
      this.CONSUME(tok.LBracket);
      this.CONSUME(tok.RBracket);
      isArray = true;
    });
    // 仅在数组参数时携带 isArray，避免污染普通参数的 toEqual 断言
    const result: { type: string; name: string; isArray?: boolean } = {
      type,
      name: nameTok.image,
    };
    if (isArray) result.isArray = true;
    return result;
  });

  // 全局变量声明
  private globalVarDeclaration = this.RULE('globalVarDeclaration', () => {
    return this.SUBRULE(this.varDeclaration);
  });

  // 变量声明（语句和顶层共用）
  // Galaxy 数组语法：type[size] name，数组维度紧跟类型之后、变量名之前
  private varDeclaration = this.RULE('varDeclaration', () => {
    let isConst = false;
    let isStatic = false;
    this.OPTION(() => {
      this.CONSUME(tok.Const);
      isConst = true;
    });
    this.OPTION2(() => {
      this.CONSUME(tok.Static);
      isStatic = true;
    });

    const varType = this.SUBRULE(this.typeName);

    let isArray = false;
    this.OPTION3(() => {
      this.CONSUME(tok.LBracket);
      this.OPTION4(() => {
        this.CONSUME(tok.Integer);
      });
      this.CONSUME(tok.RBracket);
      isArray = true;
    });

    const nameTok = this.CONSUME(tok.Identifier);

    let init: ast.Expression | null = null;
    this.OPTION5(() => {
      this.CONSUME(tok.Equals);
      init = this.SUBRULE(this.assignmentExpression) as any;
    });

    this.CONSUME(tok.Semicolon);

    return {
      type: 'VariableDeclaration',
      varType,
      name: nameTok.image,
      isArray,
      init,
      isConst,
      isStatic,
    } as ast.VariableDeclaration;
  });

  // block 语句
  private blockStatement = this.RULE('blockStatement', () => {
    this.CONSUME(tok.LBrace);
    const body: ast.Statement[] = [];
    this.MANY(() => {
      body.push(this.SUBRULE(this.statement) as any);
    });
    this.CONSUME(tok.RBrace);
    return { type: 'BlockStatement', body } as ast.BlockStatement;
  });

  // 语句
  // 注：varDeclaration 与 expressionStatement 都可能以 Identifier 开头
  // （typedef 类型变量声明 vs 标识符表达式），靠后续 token（`;`/`[`/`=` vs 运算符/`(`/`.`）
  // 区分，因此用 IGNORE_AMBIGUITIES 抑制检测器误报。
  private statement = this.RULE('statement', () => {
    // expressionStatement 在 varDeclaration 之前：避免 `a[0] = 1;` 被误解析为
    // varDeclaration（a 当类型名）。Chevrotain OR 会 backtracking，typedef 变量声明
    // `MyType x = 1;` 在 expressionStatement 失败后（primaryExpression 不接受两个
    // 连续 Identifier）会 fall through 到 varDeclaration 成功匹配。
    return this.OR({
      IGNORE_AMBIGUITIES: true,
      DEF: [
        { ALT: () => this.SUBRULE(this.expressionStatement) as any },
        { ALT: () => this.SUBRULE(this.varDeclaration) as any },
        { ALT: () => this.SUBRULE(this.ifStatement) as any },
        { ALT: () => this.SUBRULE(this.whileStatement) as any },
        { ALT: () => this.SUBRULE(this.forStatement) as any },
        { ALT: () => this.SUBRULE(this.returnStatement) as any },
        { ALT: () => this.SUBRULE(this.breakStatement) as any },
        { ALT: () => this.SUBRULE(this.continueStatement) as any },
        { ALT: () => this.SUBRULE(this.blockStatement) as any },
      ],
    });
  });

  private expressionStatement = this.RULE('expressionStatement', () => {
    const expr = this.SUBRULE(this.expression);
    this.CONSUME(tok.Semicolon);
    return { type: 'ExpressionStatement', expression: expr } as ast.ExpressionStatement;
  });

  private ifStatement = this.RULE('ifStatement', () => {
    this.CONSUME(tok.If);
    this.CONSUME(tok.LParen);
    const test = this.SUBRULE(this.expression);
    this.CONSUME(tok.RParen);
    const consequent = this.SUBRULE(this.statement);
    let alternate: ast.Statement | null = null;
    this.OPTION(() => {
      this.CONSUME(tok.Else);
      alternate = this.SUBRULE2(this.statement) as any;
    });
    return { type: 'IfStatement', test, consequent, alternate } as ast.IfStatement;
  });

  private whileStatement = this.RULE('whileStatement', () => {
    this.CONSUME(tok.While);
    this.CONSUME(tok.LParen);
    const test = this.SUBRULE(this.expression);
    this.CONSUME(tok.RParen);
    const body = this.SUBRULE(this.statement);
    return { type: 'WhileStatement', test, body } as ast.WhileStatement;
  });

  private forStatement = this.RULE('forStatement', () => {
    this.CONSUME(tok.For);
    this.CONSUME(tok.LParen);
    // 简化处理：init 可能是 varDecl 或表达式或空
    let init: ast.Statement | null = null;
    this.OPTION(() => {
      // 这里简化：尝试 varDeclaration，如果不行就 expression
      init = this.SUBRULE(this.varDeclaration) as any;
    });
    let test: ast.Expression | null = null;
    this.OPTION2(() => {
      test = this.SUBRULE(this.expression) as any;
    });
    this.CONSUME(tok.Semicolon);
    let update: ast.Expression | null = null;
    this.OPTION3(() => {
      update = this.SUBRULE2(this.expression) as any;
    });
    this.CONSUME(tok.RParen);
    const body = this.SUBRULE(this.statement);
    return { type: 'ForStatement', init, test, update, body } as ast.ForStatement;
  });

  private returnStatement = this.RULE('returnStatement', () => {
    this.CONSUME(tok.Return);
    let argument: ast.Expression | null = null;
    this.OPTION(() => {
      argument = this.SUBRULE(this.expression) as any;
    });
    this.CONSUME(tok.Semicolon);
    return { type: 'ReturnStatement', argument } as ast.ReturnStatement;
  });

  private breakStatement = this.RULE('breakStatement', () => {
    this.CONSUME(tok.Break);
    this.CONSUME(tok.Semicolon);
    return { type: 'BreakStatement' } as ast.BreakStatement;
  });

  private continueStatement = this.RULE('continueStatement', () => {
    this.CONSUME(tok.Continue);
    this.CONSUME(tok.Semicolon);
    return { type: 'ContinueStatement' } as ast.ContinueStatement;
  });

  // 表达式入口
  private expression = this.RULE('expression', () => {
    return this.SUBRULE(this.assignmentExpression);
  });

  // 赋值（右结合）
  private assignmentExpression = this.RULE('assignmentExpression', () => {
    const left = this.SUBRULE(this.conditionalExpression);
    let result: ast.Expression = left;
    this.OPTION(() => {
      const opTok = this.OR1([
        { ALT: () => this.CONSUME(tok.Equals) },
        { ALT: () => this.CONSUME(tok.PlusEquals) },
        { ALT: () => this.CONSUME(tok.MinusEquals) },
        { ALT: () => this.CONSUME(tok.StarEquals) },
        { ALT: () => this.CONSUME(tok.SlashEquals) },
      ]);
      const right = this.SUBRULE(this.assignmentExpression);
      result = {
        type: 'AssignmentExpression',
        operator: opTok!.image,
        left: result,
        right,
      } as ast.AssignmentExpression;
    });
    return result;
  });

  // 三元
  private conditionalExpression = this.RULE('conditionalExpression', () => {
    const test = this.SUBRULE(this.logicalOrExpression);
    let result: ast.Expression = test;
    this.OPTION(() => {
      this.CONSUME(tok.Question);
      const consequent = this.SUBRULE(this.expression);
      this.CONSUME(tok.Colon);
      const alternate = this.SUBRULE(this.conditionalExpression);
      result = {
        type: 'ConditionalExpression',
        test: result,
        consequent,
        alternate,
      } as ast.ConditionalExpression;
    });
    return result;
  });

  // 逻辑或
  private logicalOrExpression = this.RULE('logicalOrExpression', () => {
    let left = this.SUBRULE(this.logicalAndExpression);
    this.MANY(() => {
      const opTok = this.CONSUME(tok.PipePipe);
      const right = this.SUBRULE2(this.logicalAndExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok.image,
        left,
        right,
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 逻辑与
  private logicalAndExpression = this.RULE('logicalAndExpression', () => {
    let left = this.SUBRULE(this.equalityExpression);
    this.MANY(() => {
      const opTok = this.CONSUME(tok.AmpersandAmpersand);
      const right = this.SUBRULE2(this.equalityExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok.image,
        left,
        right,
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 相等
  private equalityExpression = this.RULE('equalityExpression', () => {
    let left = this.SUBRULE(this.relationalExpression);
    this.MANY(() => {
      const opTok = this.OR1([
        { ALT: () => this.CONSUME(tok.EqualsEquals) },
        { ALT: () => this.CONSUME(tok.ExclamationEquals) },
      ]);
      const right = this.SUBRULE2(this.relationalExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok!.image,
        left,
        right,
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 关系
  private relationalExpression = this.RULE('relationalExpression', () => {
    let left = this.SUBRULE(this.additiveExpression);
    this.MANY(() => {
      const opTok = this.OR1([
        { ALT: () => this.CONSUME(tok.Less) },
        { ALT: () => this.CONSUME(tok.Greater) },
        { ALT: () => this.CONSUME(tok.LessEquals) },
        { ALT: () => this.CONSUME(tok.GreaterEquals) },
      ]);
      const right = this.SUBRULE2(this.additiveExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok!.image,
        left,
        right,
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 加减
  private additiveExpression = this.RULE('additiveExpression', () => {
    let left = this.SUBRULE(this.multiplicativeExpression);
    this.MANY(() => {
      const opTok = this.OR1([
        { ALT: () => this.CONSUME(tok.Plus) },
        { ALT: () => this.CONSUME(tok.Minus) },
      ]);
      const right = this.SUBRULE2(this.multiplicativeExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok!.image,
        left,
        right,
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 乘除模
  private multiplicativeExpression = this.RULE('multiplicativeExpression', () => {
    let left = this.SUBRULE(this.unaryExpression);
    this.MANY(() => {
      const opTok = this.OR1([
        { ALT: () => this.CONSUME(tok.Star) },
        { ALT: () => this.CONSUME(tok.Slash) },
        { ALT: () => this.CONSUME(tok.Percent) },
      ]);
      const right = this.SUBRULE2(this.unaryExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok!.image,
        left,
        right,
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 一元
  private unaryExpression = this.RULE('unaryExpression', () => {
    let prefix = '';
    this.OPTION(() => {
      prefix = (this.OR1([
        { ALT: () => this.CONSUME(tok.Plus) },
        { ALT: () => this.CONSUME(tok.Minus) },
        { ALT: () => this.CONSUME(tok.Exclamation) },
        { ALT: () => this.CONSUME(tok.Tilde) },
      ]) as IToken)!.image;
    });
    const arg = this.SUBRULE(this.postfixExpression);
    if (prefix) {
      return {
        type: 'UnaryExpression',
        operator: prefix,
        argument: arg,
        prefix: true,
      } as ast.UnaryExpression;
    }
    return arg;
  });

  // 后缀：调用 / 成员 / 下标
  private postfixExpression = this.RULE('postfixExpression', () => {
    let expr = this.SUBRULE(this.primaryExpression);
    this.MANY(() => {
      this.OR([
        {
          ALT: () => {
            this.CONSUME(tok.LParen);
            const args: ast.Expression[] = [];
            this.OPTION(() => {
              args.push(this.SUBRULE(this.expression) as any);
              this.MANY2(() => {
                this.CONSUME(tok.Comma);
                args.push(this.SUBRULE2(this.expression) as any);
              });
            });
            this.CONSUME(tok.RParen);
            expr = {
              type: 'CallExpression',
              callee: expr,
              arguments: args,
            } as ast.CallExpression;
          },
        },
        {
          ALT: () => {
            this.CONSUME(tok.Dot);
            const propTok = this.CONSUME(tok.Identifier);
            expr = {
              type: 'MemberExpression',
              object: expr,
              property: { type: 'Identifier', name: propTok.image } as ast.Identifier,
              computed: false,
            } as ast.MemberExpression;
          },
        },
        {
          ALT: () => {
            this.CONSUME(tok.LBracket);
            const idx = this.SUBRULE3(this.expression);
            this.CONSUME(tok.RBracket);
            expr = {
              type: 'IndexExpression',
              object: expr,
              index: idx,
            } as ast.IndexExpression;
          },
        },
      ]);
    });
    return expr;
  });

  // 基础表达式
  private primaryExpression = this.RULE('primaryExpression', () => {
    return this.OR([
      { ALT: () => this.SUBRULE(this.literal) as any },
      {
        ALT: () => {
          const idTok = this.CONSUME(tok.Identifier);
          return { type: 'Identifier', name: idTok.image } as ast.Identifier;
        },
      },
      {
        ALT: () => {
          this.CONSUME(tok.LParen);
          const expr = this.SUBRULE(this.expression);
          this.CONSUME(tok.RParen);
          return expr;
        },
      },
    ]);
  });

  // 字面量
  private literal = this.RULE('literal', () => {
    return this.OR([
      {
        ALT: () => {
          const t = this.CONSUME(tok.Integer);
          return {
            type: 'Literal',
            value: parseInt(t.image, 10),
            literalType: 'integer' as const,
          } as ast.Literal;
        },
      },
      {
        ALT: () => {
          const t = this.CONSUME(tok.Fixed);
          return {
            type: 'Literal',
            value: parseFloat(t.image),
            literalType: 'fixed' as const,
          } as ast.Literal;
        },
      },
      {
        ALT: () => {
          const t = this.CONSUME(tok.String);
          return {
            type: 'Literal',
            value: t.image.slice(1, -1),
            literalType: 'string' as const,
          } as ast.Literal;
        },
      },
      {
        ALT: () => {
          const t = this.CONSUME(tok.Char);
          return {
            type: 'Literal',
            value: t.image.slice(1, -1),
            literalType: 'char' as const,
          } as ast.Literal;
        },
      },
      {
        ALT: () => {
          this.CONSUME(tok.True);
          return {
            type: 'Literal',
            value: true,
            literalType: 'bool' as const,
          } as ast.Literal;
        },
      },
      {
        ALT: () => {
          this.CONSUME(tok.False);
          return {
            type: 'Literal',
            value: false,
            literalType: 'bool' as const,
          } as ast.Literal;
        },
      },
      {
        ALT: () => {
          this.CONSUME(tok.Null);
          return {
            type: 'Literal',
            value: null,
            literalType: 'null' as const,
          } as ast.Literal;
        },
      },
    ]);
  });

  // struct（简化）
  private structDeclaration = this.RULE('structDeclaration', () => {
    this.CONSUME(tok.Struct);
    const nameTok = this.CONSUME(tok.Identifier);
    this.CONSUME(tok.LBrace);
    const members: any[] = [];
    this.MANY(() => {
      members.push(this.SUBRULE(this.varDeclaration) as any);
    });
    this.CONSUME(tok.RBrace);
    return { type: 'StructDeclaration', name: nameTok.image, members } as ast.StructDeclaration;
  });

  // enum（简化）
  private enumDeclaration = this.RULE('enumDeclaration', () => {
    this.CONSUME(tok.Enum);
    const nameTok = this.CONSUME(tok.Identifier);
    this.CONSUME(tok.LBrace);
    const members: string[] = [];
    this.MANY(() => {
      const m = this.CONSUME2(tok.Identifier);
      members.push(m.image);
      this.OPTION(() => this.CONSUME(tok.Comma));
    });
    this.CONSUME(tok.RBrace);
    return { type: 'EnumDeclaration', name: nameTok.image, members } as ast.EnumDeclaration;
  });

  // typedef（简化）
  private typedefDeclaration = this.RULE('typedefDeclaration', () => {
    this.CONSUME(tok.Typedef);
    const nameTok = this.CONSUME(tok.Identifier);
    const alias = this.SUBRULE(this.typeName);
    this.CONSUME(tok.Semicolon);
    return {
      type: 'TypedefDeclaration',
      name: nameTok.image,
      alias,
    } as ast.TypedefDeclaration;
  });
}

// 单例
const parserInstance = new GalaxyParser();

export function getParser(): GalaxyParser {
  return parserInstance;
}
