# SC2 战役诊断工作流设计

## 目标

把“单位造不出、造出后没技能、静态数据与运行时不一致、依赖覆盖错误”等问题，从反复
人工搜索改造成可积累、可验证、可低成本批处理的诊断系统。

成功标准：

- 先判断依赖加载环境，再判断 Catalog 最终值，最后判断 Galaxy 运行时修改。
- 机械证据收集可交给低成本模型，输出由确定性 validator 验收。
- 高能力模型只处理所有权、根因、修复层级、回归设计和进图结果。
- 每次漏报或误报都转化为解析器规则、测试夹具或任务契约。

## 架构

1. **依赖解析层**
   - `sc2-editor-toolkit inspect --effective` 产生地图的实际加载顺序。
   - 父级有的数据由子级继承；同 ID 按后加载定义覆盖。
   - `external/missing/legacy/needs-selection` 必须保留为不完整边界。
2. **静态 Catalog 层**
   - `trace/compare/diagnose-unit` 合并 parent、数组字段、按钮、生产命令和 Requirement。
   - 输出定义历史，不只输出最终值，便于定位覆盖来源。
3. **Galaxy 层**
   - `galaxy-checker` 检查语法、语义、参数、跨文件符号和 Catalog 字面量引用。
   - `--symbol-root` 加载父级/依赖 Mod 符号；目标目录与依赖目录分离。
   - 编译错误与项目策略分级：伪 native 为 error，`UnitCreate` 等策略为 warning。
4. **运行时证据层**
   - 扫描 `UnitAbilityAdd`、TechTree allow/block、CatalogField 修改等可静态识别事件。
   - `runtime.scan.complete=false` 只能表示存在分析边界，不能推导“运行时没有修改”。
5. **批处理与验收层**
   - 任务定义在 `docs/低成本模型任务包/`。
   - 输入定义在 `docs/低成本模型任务输入/<batch>/`。
   - 产物写入 `docs/低成本模型产物/<task>/<batch>/`。
   - `low-cost-batch-validator` 校验文件、CSV、raw/meta、计数和 senior-review 覆盖。
6. **工作流入口**
   - 项目 skill：`.codex/skills/sc2-workflow/`。
   - 根 `AGENTS.md` 只保留安全、交付和 skill 路由，详细命令下沉到 skill references。

## 单位诊断决策顺序

1. 确认地图 declared/effective 依赖和指挥官 profile。
2. 确认生产者最终 `CardLayouts` 与训练能力 `InfoArray`。
3. 确认目标单位 parent 链、`AbilArray`、按钮和 Requirement。
4. 传入明确 `expectedAbilities`，避免“命令成功但未验证目标技能”。
5. 对比静态能力与运行时 allow/add/remove/catalog mutation。
6. 有不完整依赖时保留 `complete=false`，不得给出确定性缺失结论。
7. 修改 Galaxy 后先 checker，再按地图类型执行进图验证。

## 自我迭代闭环

每次问题按以下方式沉淀：

- **checker 误报**：加入官方合法样例和负向回归，修规则假设。
- **checker 漏报**：先补最小失败夹具，再修 AST/语义分析。
- **依赖误判**：补 effective 依赖样例或 symbol-root 联合扫描测试。
- **单位诊断误判**：保存目标 ID、生产者、预期技能和定义历史为 fixture。
- **低成本产物错误**：新增 validator 规则，禁止只靠提示词约束。
- **进图 ScriptError**：先增强 checker 规则，再记录到 `docs/经验总结/`。

## 高低成本模型边界

低成本模型负责：

- 批量运行只读命令、保存完整日志和 meta。
- 机械展开依赖、Catalog、单位矩阵、MPQ 和本地化候选。
- 按固定 schema 汇总，不判断正确所有者。

高能力模型负责：

- 判断覆盖层、父子依赖和修复归属。
- 修改解析器、XML、Galaxy、触发器和启动流程。
- 设计回归测试、解释运行时差异、执行进图验证。
- 审查 validator 通过后的证据并提交推送。

## 当前落地

- Galaxy 合法语法回归：`continue`、局部初始化、`text + text`。
- 官方 TriggerLib 函数签名：`SoundPlay*`。
- 全局数组维度与初始化表达式的未声明符号检查。
- 多 `--symbol-root` 联合符号表。
- native error / policy warning 分级。
- batch-01 产物 validator，可确定性发现 33 个契约问题。
- batch-02 已补齐任务 04/05 输入，并为单位用例加入预期技能。
