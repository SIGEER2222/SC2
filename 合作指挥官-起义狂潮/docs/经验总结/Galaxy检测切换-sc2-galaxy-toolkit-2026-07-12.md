# Galaxy 检测切换总结

- 任务类型：工作流改造 / 静态检测接入
- 时间：2026-07-12
- 任务内容：将项目 Galaxy 静态检测主路线接入 `sc2-galaxy-toolkit`，并保留 `galaxy-checker` 作为双跑对照
- 任务结果：已完成最小接入、测试补齐、双跑链路打通；真实项目样本验证显示 `toolkit` 当前存在大量依赖上下文缺失导致的误报，暂不适合作为唯一判定依据
- 耗时：本轮会话内完成

## 本轮改动

- 新增 `scripts/sc2-editor-toolkit/src/toolkitGalaxyChecker.mjs`
  - 将 `tools/sc2-galaxy-toolkit` 的解析/诊断能力包装为可编排模块
- 新增 `scripts/sc2-editor-toolkit/toolkit-galaxy-check.mjs`
  - 提供可直接执行的 CLI 入口
- 修改 `scripts/sc2-editor-toolkit/src/workflow.mjs`
  - `.galaxy` 变更现在会双跑：
    - `toolkit-galaxy-check`
    - `galaxy-checker`
  - 增加双跑结果对比汇总
- 修改 `Shared/Workflow/sc2-workflow.json`
  - `validation.galaxyChecker` 指向 toolkit 入口
  - 新增 `validation.legacyGalaxyChecker`
- 新增测试 `scripts/sc2-editor-toolkit/tests/toolkitGalaxyChecker.test.mjs`
- 更新测试 `scripts/sc2-editor-toolkit/tests/workflow.test.mjs`
- 新增设计文档 `docs/superpowers/specs/2026-07-12-toolkit-galaxy-validation-switch-design.md`

## 验证结果

### 1. 单元/集成测试

- 已执行：`node --test "tests/**/*.test.mjs"`
- 结果：`45/45` 通过

### 2. toolkit 入口独立验证

- 已执行：`node toolkit-galaxy-check.mjs <Base.SC2Data> --format json`
- 结果：可正常输出结构化 JSON

### 3. 真实项目双跑验证

- 已执行：`node cli.mjs check <某个 .galaxy 文件> --run --format json`
- 结果：
  - 新入口和旧 checker 都被成功调起
  - 双跑链路成立
  - `toolkit` 在 `CoreRuntime.SC2Mod/Base.SC2Data` 上报出大量错误

## 当前关键结论

- `sc2-galaxy-toolkit` 已经成功接入当前项目工作流。
- 但它目前对真实项目的 Galaxy 运行环境理解不完整，缺少原生函数、依赖包、TriggerLib / Native 上下文。
- 因此当前大量报出：
  - `Undeclared symbol`
  - `Given filename couldn't be matched`
  - 一系列由缺失上下文引发的连锁类型错误

## 后续建议

- 下一步不要直接删除 `galaxy-checker`
- 优先补 `toolkit` 的运行上下文装载能力：
  - Native / TriggerLib 基础符号
  - Mod / Map 依赖链
  - 文件名与文档名映射
- 在误报数量明显下降前，保留双跑模式作为过渡方案

## 备注

- 本轮没有进行进图运行时验证，因为改动范围为离线静态检查工作流与工具接入，不涉及地图/Mod 运行产物变更。
