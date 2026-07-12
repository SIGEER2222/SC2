# sc2-galaxy-toolkit 检测切换设计

- **日期**：2026-07-12
- **状态**：已确认方案，待实现
- **目标**：将项目的 Galaxy 静态检测主路线从 `galaxy-checker` 迁移到 `sc2-galaxy-toolkit`

## 1. 背景

当前项目工作流把 Galaxy 检测入口固定在 `scripts/galaxy-checker/dist/cli.mjs`。
但本任务的目标是改为以 `tools/sc2-galaxy-toolkit` 为检测能力来源。

已确认现状：

- `sc2-galaxy-toolkit` 具备 Galaxy 解析器、类型检查器和诊断汇总能力。
- `sc2-galaxy-toolkit` 当前更偏向 LSP/库形态，没有可直接替换现有工作流的离线批量检查 CLI。
- 项目现有工作流和验证计划代码均依赖 `galaxy-checker` 的 CLI 路径与调用方式。

## 2. 设计目标

- 使用 `sc2-galaxy-toolkit` 作为 Galaxy 静态检测的实际能力来源。
- 不直接硬删 `galaxy-checker`，先保留它作为对照与回退。
- 以最小改动接入现有工作流，优先保持调用方式和输出消费方式稳定。
- 先双跑对比，再决定是否彻底切主入口。

## 3. 方案选择

已选方案：**双跑对比**

理由：

- 直接硬切风险高，因为 `toolkit` 缺少现成离线 CLI。
- 先做适配层最稳，可以把 `toolkit` 的库能力转换成当前项目能消费的命令行输出。
- 双跑可以快速发现误报、漏报、路径解析或依赖装载差异，避免一刀切后调试成本过高。

## 4. 实现设计

### 4.1 新增 toolkit 适配入口

新增一个项目内的适配脚本，职责如下：

- 调用 `tools/sc2-galaxy-toolkit` 中的 Galaxy 解析/诊断能力。
- 接收与当前工作流接近的输入参数，优先支持对 `Base.SC2Data` 或单文件的检查。
- 输出统一格式结果，至少包含：
  - 文件
  - 行列
  - 严重级别
  - 消息
  - 汇总统计

适配脚本不负责重写全部诊断逻辑，只负责把 `toolkit` 的库接口包装成可执行命令。

### 4.2 工作流改造为双跑

对现有工作流改造为双跑模式：

- 主检测器：`sc2-galaxy-toolkit`
- 次检测器：`galaxy-checker`

双跑模式下：

- 先跑 toolkit 适配入口
- 再跑旧 checker
- 汇总两边结果
- 输出清晰的差异摘要，便于判断是否具备切主条件

### 4.3 配置改造

调整项目工作流配置与验证计划生成逻辑，使其支持：

- `primaryGalaxyChecker`
- `secondaryGalaxyChecker`
- 或等价的双跑配置字段

要求：

- 默认优先使用 toolkit
- 允许保留旧 checker 作为 secondary
- 后续切主时只需改配置，不必再改路由代码

## 5. 输出设计

双跑阶段输出需要满足两类消费：

- 机器消费：结构化 JSON
- 人工查看：简洁文本摘要

至少包括：

- toolkit 结果摘要
- galaxy-checker 结果摘要
- 仅 toolkit 报出的项
- 仅 galaxy-checker 报出的项
- 同位置但消息不同的项

## 6. 验证策略

分三步验证：

1. 小样本验证
   - 选一个已知有报错或已知可通过的 Galaxy 文件/目录
   - 确认 toolkit 适配入口可稳定运行并产出结果

2. 真实项目双跑
   - 对当前项目真实 `Base.SC2Data` 跑 toolkit 与旧 checker
   - 对比误报、漏报、耗时、路径解析是否正常

3. 工作流回归
   - 确认改造后的工作流仍能生成验证计划
   - 确认调用链不因切换入口而中断

## 7. 风险

- `toolkit` 当前不是现成 CLI，适配层可能需要补少量运行时桥接代码。
- `toolkit` 和旧 checker 的诊断模型不同，短期内会出现结果不一致。
- 现有工作流默认围绕 `galaxy-checker` 设计，改造时需避免破坏其他验证动作。

## 8. 完成标准

达到以下条件才算本轮完成：

- 可以从项目工作流中调用 `sc2-galaxy-toolkit` 做 Galaxy 检测。
- 双跑模式可稳定输出 toolkit 与旧 checker 的结果。
- 至少完成一轮真实项目样本对比。
- 给出是否可以切主入口的结论，或明确列出阻塞项。
