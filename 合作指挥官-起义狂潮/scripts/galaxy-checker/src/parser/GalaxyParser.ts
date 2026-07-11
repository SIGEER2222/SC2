// src/parser/GalaxyParser.ts
import { EmbeddedActionsParser, type IToken } from 'chevrotain';
import * as tok from '../lexer/tokens.js';
import { GALAXY_TYPES } from '../types.js';
import type * as ast from './ast.js';

// 从 IToken 构造 Position。
// SemanticAnalyzer / RuleEngine 通过 node.start.line 报告 issue 行号，
// 旧版未给节点附加 start，导致所有 semantic issue 输出 line=0。
// 此处给会产生 issue 的节点（声明、return、continue、Identifier、CallExpression、
// AssignmentExpression、BinaryExpression）附加 start，其他节点保持原样以减小改动面。
// BinaryExpression 的 start 取运算符 token 位置，便于定位 text + text 等拼接错误。
function posOf(t: IToken): ast.Position {
  return {
    line: t.startLine ?? 0,
    column: t.startColumn ?? 0,
    offset: t.startOffset ?? 0,
  };
}

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

  // include "path"
  // Galaxy 真实代码 include 指令不带分号（如 `include "TriggerLibs/NativeLib"`），
  // 但兼容带分号的写法（测试用），分号可选。
  private includeDirective = this.RULE('includeDirective', () => {
    this.CONSUME(tok.Include);
    const pathTok = this.CONSUME(tok.String);
    this.OPTION(() => {
      this.CONSUME(tok.Semicolon);
    });
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
    // LA(1) 指向 RULE 入口下一个待消费 token（native/static/类型关键字），用作声明起始位置。
    const startTok = this.LA(1);

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

    // body 或分号二选一（必须在规则顶层调用 OR，不能放在 if/else 内，
    // 否则 Chevrotain 自动 lookahead 计算会失败）：
    //   - 有 body：函数定义（native 也可走此分支，linter 宽松处理）
    //   - 仅分号：函数原型/forward declaration
    //     · native 函数：`native void f(...);`
    //     · 非 native 函数原型：`void f();`（Galaxy 头文件 *_h.galaxy 大量使用，
    //       声明函数签名，body 留待 .galaxy 实现文件提供）
    // 两个 ALT 首 token 不同（LBrace vs Semicolon），无歧义，无需 IGNORE_AMBIGUITIES。
    let body: ast.BlockStatement | null = null;
    this.OR({
      DEF: [
        { ALT: () => { body = this.SUBRULE(this.blockStatement) as any; } },
        { ALT: () => { this.CONSUME(tok.Semicolon); } },
      ],
    });

    return {
      type: 'FunctionDeclaration',
      returnType,
      name: nameTok.image,
      params,
      body,
      isNative,
      isStatic,
      start: posOf(startTok),
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
  // Galaxy 数组语法：type[size] name，数组维度紧跟类型之后、变量名之前。
  // 真实项目存在常量表达式维度（如 `unit[gv_MAXPLAYERS + 1] gv_casters`）
  // 和多维数组（如 `fixed[a][b] gv_timers`），旧版仅支持单维 Integer/Identifier，
  // 导致大量声明解析失败。此处改为：维度为可选表达式，且支持连续多个 `[...]`。
  private varDeclaration = this.RULE('varDeclaration', () => {
    let isConst = false;
    let isStatic = false;
    const startTok = this.LA(1);

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
    const arrayDimensions: (ast.Expression | null)[] = [];
    this.OPTION3(() => {
      this.CONSUME(tok.LBracket);
      // 维度可为空（`type[] name`）、字面量、标识符或算术表达式（`gv_MAX + 1`）
      let dimension: ast.Expression | null = null;
      this.OPTION4(() => {
        dimension = this.SUBRULE(this.expression) as ast.Expression;
      });
      this.CONSUME(tok.RBracket);
      arrayDimensions.push(dimension);
      isArray = true;
      // 多维：`type[a][b] name`
      this.MANY2(() => {
        this.CONSUME2(tok.LBracket);
        let nextDimension: ast.Expression | null = null;
        this.OPTION5(() => {
          nextDimension = this.SUBRULE2(this.expression) as ast.Expression;
        });
        this.CONSUME2(tok.RBracket);
        arrayDimensions.push(nextDimension);
      });
    });

    const nameTok = this.CONSUME(tok.Identifier);

    let init: ast.Expression | null = null;
    this.OPTION6(() => {
      this.CONSUME(tok.Equals);
      init = this.SUBRULE(this.assignmentExpression) as any;
    });

    this.CONSUME(tok.Semicolon);

    return {
      type: 'VariableDeclaration',
      varType,
      name: nameTok.image,
      isArray,
      arrayDimensions,
      init,
      isConst,
      isStatic,
      start: posOf(startTok),
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
        { ALT: () => this.SUBRULE(this.doWhileStatement) as any },
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

  // do-while 语句：Galaxy 编辑器导出的循环结构常见形式之一。
  // 旧版 Parser 缺此 RULE，导致含 do-while 的整文件降级为空 Program。
  private doWhileStatement = this.RULE('doWhileStatement', () => {
    this.CONSUME(tok.Do);
    const body = this.SUBRULE(this.statement);
    this.CONSUME(tok.While);
    this.CONSUME(tok.LParen);
    const test = this.SUBRULE(this.expression);
    this.CONSUME(tok.RParen);
    this.CONSUME(tok.Semicolon);
    return { type: 'DoWhileStatement', test, body } as ast.DoWhileStatement;
  });

  private forStatement = this.RULE('forStatement', () => {
    this.CONSUME(tok.For);
    this.CONSUME(tok.LParen);
    // init：支持三种形式，三种 ALT 都消费到第一个分号之后，
    // 保证 test 后的分号始终是第二个分号，分号计数统一：
    //   1) 表达式（如 i = 1）+ ;   —— Galaxy 编译器生成 for 的最常见形式
    //      （Galaxy 禁止局部变量 = 初始化，循环变量需先声明再赋值）
    //   2) 变量声明（如 int i = 0）—— varDeclaration 规则自带末尾 ;
    //   3) 空 init：仅消费 ;      —— 对应 for (; test; update)
    // 这样 `for (;;)`、`for (i=1; i<=8; i+=1)`、`for (; i<10; i++)`、
    // `for (int i=0; i<10; i++)` 均可解析。
    let init: ast.Statement | null = null;
    init = this.OR({
      IGNORE_AMBIGUITIES: true,
      DEF: [
        {
          ALT: () => {
            const e = this.SUBRULE(this.expression);
            this.CONSUME(tok.Semicolon);
            return { type: 'ExpressionStatement', expression: e } as ast.ExpressionStatement;
          },
        },
        { ALT: () => this.SUBRULE(this.varDeclaration) as any },
        { ALT: () => { this.CONSUME2(tok.Semicolon); return null; } },
      ],
    }) as ast.Statement | null;
    let test: ast.Expression | null = null;
    this.OPTION(() => {
      test = this.SUBRULE2(this.expression) as any;
    });
    this.CONSUME3(tok.Semicolon);
    let update: ast.Expression | null = null;
    this.OPTION2(() => {
      update = this.SUBRULE3(this.expression) as any;
    });
    this.CONSUME(tok.RParen);
    const body = this.SUBRULE(this.statement);
    return { type: 'ForStatement', init, test, update, body } as ast.ForStatement;
  });

  private returnStatement = this.RULE('returnStatement', () => {
    const retTok = this.CONSUME(tok.Return);
    let argument: ast.Expression | null = null;
    this.OPTION(() => {
      argument = this.SUBRULE(this.expression) as any;
    });
    this.CONSUME(tok.Semicolon);
    return { type: 'ReturnStatement', argument, start: posOf(retTok) } as ast.ReturnStatement;
  });

  private breakStatement = this.RULE('breakStatement', () => {
    this.CONSUME(tok.Break);
    this.CONSUME(tok.Semicolon);
    return { type: 'BreakStatement' } as ast.BreakStatement;
  });

  private continueStatement = this.RULE('continueStatement', () => {
    const contTok = this.CONSUME(tok.Continue);
    this.CONSUME(tok.Semicolon);
    return { type: 'ContinueStatement', start: posOf(contTok) } as ast.ContinueStatement;
  });

  // 表达式入口
  private expression = this.RULE('expression', () => {
    return this.SUBRULE(this.assignmentExpression);
  });

  // 赋值（右结合）
  // 补充 |= &= 复合赋值（^= 因 Galaxy 实际较少使用暂不添加，token 已就位可后续扩展），
  // 旧版只支持 = += -= *= /=，导致位掩码赋值（如 `x |= (1 << i)`）无法解析。
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
        { ALT: () => this.CONSUME(tok.PipeEquals) },
        { ALT: () => this.CONSUME(tok.AmpersandEquals) },
      ]);
      const right = this.SUBRULE(this.assignmentExpression);
      // 继承左侧表达式的 start：赋值表达式的定位通常指向被赋值的左值。
      const start = (left as any).start;
      result = {
        type: 'AssignmentExpression',
        operator: opTok!.image,
        left: result,
        right,
        start,
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
        start: posOf(opTok),
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 逻辑与
  private logicalAndExpression = this.RULE('logicalAndExpression', () => {
    let left = this.SUBRULE(this.bitwiseOrExpression);
    this.MANY(() => {
      const opTok = this.CONSUME(tok.AmpersandAmpersand);
      const right = this.SUBRULE2(this.bitwiseOrExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok.image,
        left,
        right,
        start: posOf(opTok),
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 位运算或 |（C 优先级：高于 &&，低于 ^）
  // Galaxy 大量使用 a | b | c 形式（如 c_placementTestPowerMask | c_placementTestFogMask）
  private bitwiseOrExpression = this.RULE('bitwiseOrExpression', () => {
    let left = this.SUBRULE(this.bitwiseXorExpression);
    this.MANY(() => {
      const opTok = this.CONSUME(tok.Pipe);
      const right = this.SUBRULE2(this.bitwiseXorExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok.image,
        left,
        right,
        start: posOf(opTok),
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 位运算异或 ^
  private bitwiseXorExpression = this.RULE('bitwiseXorExpression', () => {
    let left = this.SUBRULE(this.bitwiseAndExpression);
    this.MANY(() => {
      const opTok = this.CONSUME(tok.Caret);
      const right = this.SUBRULE2(this.bitwiseAndExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok.image,
        left,
        right,
        start: posOf(opTok),
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 位运算与 &（C 优先级：高于 ^，低于 ==）
  private bitwiseAndExpression = this.RULE('bitwiseAndExpression', () => {
    let left = this.SUBRULE(this.equalityExpression);
    this.MANY(() => {
      const opTok = this.CONSUME(tok.Ampersand);
      const right = this.SUBRULE2(this.equalityExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok.image,
        left,
        right,
        start: posOf(opTok),
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
        start: posOf(opTok!),
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 关系
  private relationalExpression = this.RULE('relationalExpression', () => {
    let left = this.SUBRULE(this.shiftExpression);
    this.MANY(() => {
      const opTok = this.OR1([
        { ALT: () => this.CONSUME(tok.Less) },
        { ALT: () => this.CONSUME(tok.Greater) },
        { ALT: () => this.CONSUME(tok.LessEquals) },
        { ALT: () => this.CONSUME(tok.GreaterEquals) },
      ]);
      const right = this.SUBRULE2(this.shiftExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok!.image,
        left,
        right,
        start: posOf(opTok!),
      } as ast.BinaryExpression;
    });
    return left;
  });

  // 位移 << >>（C 优先级：高于关系运算、低于加法）
  // 旧版 Parser 缺失此层，导致 (1 << a) 等位掩码表达式无法解析。
  private shiftExpression = this.RULE('shiftExpression', () => {
    let left = this.SUBRULE(this.additiveExpression);
    this.MANY(() => {
      const opTok = this.OR1([
        { ALT: () => this.CONSUME(tok.ShiftLeft) },
        { ALT: () => this.CONSUME(tok.ShiftRight) },
      ]);
      const right = this.SUBRULE2(this.additiveExpression);
      left = {
        type: 'BinaryExpression',
        operator: opTok!.image,
        left,
        right,
        start: posOf(opTok!),
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
        start: posOf(opTok!),
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
        start: posOf(opTok!),
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
            // CallExpression 的定位继承 callee 的 start（通常是函数名 Identifier），
            // 使 SEM_UNDECLARED_FUNCTION / SEM_ARGUMENT_COUNT_MISMATCH 等报错指向函数名行。
            expr = {
              type: 'CallExpression',
              callee: expr,
              arguments: args,
              start: (expr as any).start,
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
          // Identifier 附加 start，使 SEM_UNDECLARED_VARIABLE 报错能定位到引用行。
          return { type: 'Identifier', name: idTok.image, start: posOf(idTok) } as ast.Identifier;
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
  // Galaxy 语法要求 struct 定义后跟分号：struct Foo { ... };
  private structDeclaration = this.RULE('structDeclaration', () => {
    this.CONSUME(tok.Struct);
    const nameTok = this.CONSUME(tok.Identifier);
    this.CONSUME(tok.LBrace);
    const members: any[] = [];
    this.MANY(() => {
      members.push(this.SUBRULE(this.varDeclaration) as any);
    });
    this.CONSUME(tok.RBrace);
    this.CONSUME(tok.Semicolon);
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
