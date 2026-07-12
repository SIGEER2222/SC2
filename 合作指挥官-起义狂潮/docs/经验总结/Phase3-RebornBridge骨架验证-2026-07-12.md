# Phase 3 RebornBridge 骨架验证任务总结

- **任务类型**：SC2 地图搬运 — Phase 3 RebornBridge 最小骨架验证
- **时间戳**：2026-07-12 23:00 ~ 2026-07-12 23:20
- **任务耗时**：约 20 分钟
- **分支**：fix_003

## 任务内容

1. 调整 `Shared/Launcher/reborn-dependencies.json` 中 RebornBridge/RebornMapAdapter 的依赖顺序，将其移到 7vs1 Runtime（CoreRuntime + CommanderBridge）之后，符合"补丁层必须在 Runtime 之后"的设计原则
2. 修复 `Lib67C0F0E7.galaxy` 中 RuntimeProbe 诊断代码导致的 galaxy 语法错误（const 声明位置）
3. 进图验证 zexpedition03 × TerranRaynor 组合 smoke 测试
4. 创建 Phase 3 验证报告 `docs/reborn-port/phase-3-report.md`
5. 更新 `docs/PROJECT_STATUS.md` 验证状态

## 任务结果

- **smoke 测试通过**：`wait-for-game-ready exit code: 0`，游戏加载完成（49 秒）
- **无致命 ScriptError**：仅有地图原有的非致命触发器警告
- **依赖链正确**：9 依赖写入，DocumentHeader/DocumentInfo roundtrip valid
- **35 galaxy 文件注入**，AlengerBootstrap 生成（adapterCount=0）
- Phase 3 验收标准 1（空 Bridge 不改变原版基线行为）满足

## 任务备注

- `Lib67C0F0E7.galaxy` 的 RuntimeProbe 诊断代码是工作区既有脏改动（其他任务添加），本任务只修复语法错误，不提交该文件
- 实际提交文件：`reborn-dependencies.json`、`phase-3-report.md`、`PROJECT_STATUS.md`、本任务总结
- 游戏崩溃问题排查：SC2Switcher 启动 SC2 时若已有 SC2 进程在运行，可能加载错误地图；需先关闭现有 SC2 进程再启动
- 下一步：按 Phase 2 冲突分类逐类添加最小补丁到 RebornBridge，每个补丁需有诊断报告和回归测试
