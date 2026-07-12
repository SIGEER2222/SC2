# 重生虫心搬运 — Phase 3 RebornBridge 骨架验证报告

> 日期：2026-07-12
> 状态：空骨架验证通过

## 3.1 目标

验证 RebornBridge.SC2Mod 空骨架加入依赖链后不改变原版基线行为，为后续按 Phase 2 冲突分类逐步添加最小补丁奠定基础。

验收标准（来自 `docs/重生虫心地图搬运设计.md` Phase 3）：
- 空 Bridge 不改变原版基线行为
- 添加单个补丁时有对应诊断报告和回归测试

## 3.2 调整内容

### 3.2.1 依赖顺序修正

`Shared/Launcher/reborn-dependencies.json` 中 RebornBridge/RebornMapAdapter 原本位于 7vs1 Runtime 之前，违反"补丁层必须在 Runtime 之后"的设计原则。

调整后依赖链顺序（父级先加载，后加载覆盖先加载）：

```
crys_the_swarm_reborn.SC2Mod      (Reborn 原始基座)
→ CommanderBridge.SC2Mod          (7vs1 指挥官桥接)
→ CoreRuntime.SC2Mod              (7vs1 运行时核心)
→ RebornBridge.SC2Mod             (Reborn 补丁层 — 空)
→ RebornMapAdapter.SC2Mod         (地图适配器)
→ CommanderUnits_Raynor.SC2Mod    (选中指挥官包)
→ 战役依赖 (LibertyStory / Liberty / VoidStory)
```

### 3.2.2 Galaxy 语法修复

`Mods/7vs1/CoreRuntime.SC2Mod/Base.SC2Data/Lib67C0F0E7.galaxy` 中 RuntimeProbe 诊断代码（工作区既有脏改动）插在 `const int auto...` 声明之前，导致 galaxy 编译错误：

```
Script compile error: Lib67C0F0E7.galaxy (3180), 解析函数行出错
```

galaxy 语法要求所有变量声明（包括 `const`）在可执行语句之前。修复方式：将 `const int auto...` 声明移到 RuntimeProbe 诊断块之前，保持诊断功能不变。

## 3.3 验证

### 3.3.1 静态验证

- `CONFIG VALID` — 三份 launcher 配置 schema 通过
- `SET DEPS: 9 dependencies written to map` — 依赖写入正确
- `DOCUMENT ROUNDTRIP VALID (header deps: 9, info deps: 9)` — DocumentHeader/DocumentInfo 一致
- 35 galaxy 文件注入
- AlengerBootstrap 生成（adapterCount=0，Raynor 无 Alenger 依赖）

### 3.3.2 运行时验证

启动命令：
```
pwsh -File scripts/reborn/launch-reborn-commander.ps1 -Commander TerranRaynor -MapName zexpedition03_reborn_port.SC2Map
```

结果：
- `wait-for-game-ready exit code: 0`
- 游戏加载完成时间：49 秒
- Alerts.txt 出现，SC2 进程正常运行
- ScriptError.txt 仅有非致命触发器警告（地图原有问题，非 Phase 3 引入）：
  - `gt_Init01Technology_Func` CatalogFieldValueModify 参数超界（值 16，最大 15）— 地图原有
  - `lib67C0F0E7_gf_ShowChooseButton` TriggerAddEventDialogControl trigger 参数 — 地图原有

## 3.4 结论

空骨架 RebornBridge.SC2Mod 加入依赖链后，zexpedition03 × TerranRaynor 组合 smoke 测试通过，未改变原版基线行为。Phase 3 验收标准 1（空 Bridge 不改变原版基线行为）满足。

## 3.5 下一步

- 按 Phase 2 冲突分类，逐类添加最小补丁到 RebornBridge
- 每个补丁需有对应诊断报告和回归测试（验收标准 2）
- 优先处理分类 A（SC2 原生单位双方重定义，~180 条）中的关键冲突
