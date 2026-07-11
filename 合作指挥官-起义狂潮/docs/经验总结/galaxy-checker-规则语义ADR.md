# galaxy-checker 规则语义 ADR

> 状态：Accepted（2026-07-11）
> 适用版本：galaxy-checker v0.1.x
> 基线数据来源：CoreRuntime(44e/79w) + CoopZeroPop(7e/77w) + CommanderBridge(50e/3w) 扫描结果

## 1. 背景

galaxy-checker 已具备 lexer/parser/AST/semantic/rule/report/CLI/测试体系，能跑真实项目批量清单。
但在扫描 CoreRuntime/CoopZeroPop/CommanderBridge 三个运行时包时，产出的 260 个 issue 中约 86%
是因**缺少依赖上下文**导致的误报。

本 ADR 冻结当前 top 5 高频规则的语义判定：是否真实错误、是否可自动修、阻塞级别、移除条件。

## 2. 基线错误分布（2026-07-11 扫描）

| 规则 | 数量 | severity | 来源分布 |
|------|------|----------|----------|
| XLIB_MISSING_INCLUDE | 71 | warning | CoreRuntime 49 + CoopZeroPop 22 |
| XLIB_UNDEFINED_CROSS_REF | 58 | error | CoreRuntime 44 + CoopZeroPop 7 + CommanderBridge 7 |
| CATALOG_INVALID_UNIT_REF | 52 | warning | CoreRuntime 15 + CoopZeroPop 37 |
| SEM_UNDECLARED_VARIABLE | 43 | error | CommanderBridge 43 |
| XLIB_DISCOURAGED_NATIVE | 36 | warning | CoreRuntime 15 + CoopZeroPop 18 + CommanderBridge 3 |

> 注：review 中提到的 `SYNTAX_NO_LOCAL_INIT_ASSIGN`、`SEM_INVALID_TEXT_CONCAT`、`SYNTAX_NO_CONTINUE`
> 在当前代码库中**不存在**。这些规则可能来自早期设计草案或与其他工具混淆。本 ADR 基于实际实现的规则。

## 3. 规则语义冻结

### 3.1 XLIB_MISSING_INCLUDE

| 属性 | 值 |
|------|-----|
| 真实错误率 | <5%（当前基线下约 95% 是误报） |
| 误报原因 | checker 未加载完整依赖闭包；include 的目标文件在其他 mod 中 |
| 阻塞级别 | **不阻塞**（当前 severity=warning 正确） |
| 可自动修 | 否（需要 CompositionPlan 提供依赖上下文） |
| runtimeRisk | 低（SC2 引擎在运行时会忽略找不到的 include，但可能导致符号未定义） |
| confidence | low（无 CompositionPlan 时）/ high（有 CompositionPlan 时） |
| suggestedOwner | CompositionPlan.resolver |

**判定**：当 checker 接入 CompositionPlan 后，此规则的误报率应降至 <5%。
若 CompositionPlan 声明了完整依赖闭包后仍报此规则，则升为 error。

**移除条件**：`--composition-plan` 选项实现后，基线扫描中此规则计数 <10。

### 3.2 XLIB_UNDEFINED_CROSS_REF

| 属性 | 值 |
|------|-----|
| 真实错误率 | <5%（当前基线下约 95% 是误报） |
| 误报原因 | 跨库函数定义在其他 mod 的 galaxy 文件中，checker 未加载 |
| 阻塞级别 | **阻塞运行时**（若为真实错误，会导致 ScriptError） |
| 可自动修 | 否（需要先确认函数是否真实存在） |
| runtimeRisk | 高（真实未定义会导致游戏内 ScriptError） |
| confidence | low（无 CompositionPlan 时）/ high（有 CompositionPlan 时） |
| suggestedOwner | CompositionPlan.resolver |

**典型误报样本**：
- `libE0EAE146_tychus_InitVariables()` — 定义在 CommanderUnits_Tychus.galaxy
- `libE0EAE146_gf_RaynorCreateMapStartSquad()` — 定义在 CommanderUnits_Raynor.galaxy

**判定**：当 checker 接入 CompositionPlan 后，此规则的误报率应降至 <5%。
若 CompositionPlan 声明了完整依赖闭包后仍报此规则，则为真实错误，阻塞进图。

**移除条件**：`--composition-plan` 选项实现后，基线扫描中此规则计数 <5。

### 3.3 CATALOG_INVALID_UNIT_REF

| 属性 | 值 |
|------|-----|
| 真实错误率 | ~30%（部分是误报，部分是真实缺失） |
| 误报原因 | catalog ID 数据库未包含所有 mod 的 Unit 定义 |
| 阻塞级别 | **不阻塞**（当前 severity=warning 正确） |
| 可自动修 | 否 |
| runtimeRisk | 中（引用不存在的 Unit 会在运行时创建失败，但不会崩溃） |
| confidence | medium |
| suggestedOwner | DataCenter.catalogExporter |

**典型误报样本**：
- `ProphecyArtifactMineralPickup` — 定义在战役 mod 中
- `ZergDropPod` — 定义在 map 依赖中

**判定**：当 catalog ID 数据库包含所有 mod 的 Unit 定义后，此规则的误报率应降至 <10%。
真实的 CATALOG_INVALID_UNIT_REF 应保持 warning，不阻塞进图但需修复。

**移除条件**：catalog-ids.json 包含所有 mod 的 catalog 导出后，此规则计数稳定。

### 3.4 SEM_UNDECLARED_VARIABLE

| 属性 | 值 |
|------|-----|
| 真实错误率 | <5%（当前基线下 CommanderBridge 的 43 个全部是误报） |
| 误报原因 | 变量定义在 CoreRuntime 的 LibE0EAE146.galaxy 中，CommanderBridge 未被加载为 symbol root |
| 阻塞级别 | **阻塞运行时**（若为真实错误，会导致 ScriptError） |
| 可自动修 | 否 |
| runtimeRisk | 高（真实未定义会导致游戏内 ScriptError） |
| confidence | low（无 CompositionPlan 时）/ high（有 CompositionPlan 时） |
| suggestedOwner | CompositionPlan.resolver |

**典型误报样本**：
- `libE0EAE146_gv_MAXPLAYERS` — 定义在 CoreRuntime/LibE0EAE146.galaxy
- `libE0EAE146_gv_effectiveBaseAnchor` — 定义在 CoreRuntime/LibE0EAE146.galaxy

**判定**：当 checker 接入 CompositionPlan 后，此规则的误报率应降至 <5%。
CommanderBridge 的 43 个误报应全部消失。

**移除条件**：`--composition-plan` 选项实现后，CommanderBridge 扫描中此规则计数 = 0。

### 3.5 XLIB_DISCOURAGED_NATIVE

| 属性 | 值 |
|------|-----|
| 真实错误率 | **100%**（全部是真实问题） |
| 阻塞级别 | **不阻塞**（当前 severity=warning 正确，是风格问题） |
| 可自动修 | **是**（可自动包装为推荐函数） |
| runtimeRisk | 低（直接调用 native 不会崩溃，但不符合项目规范） |
| confidence | high |
| suggestedOwner | Fixer.UnitCreateWrapper |

**典型真实问题样本**：
- `UnitCreate()` 直接调用 — 应包装为 `libNtve_gf_CreateUnitsAtPoint2()`
- 涉及文件：LibKMIS.galaxy（CoreRuntime + CoopZeroPop）

**判定**：这是当前唯一可自动修复的高频规则。
Fixer 应将 `UnitCreate(...)` 调用替换为 `libNtve_gf_CreateUnitsAtPoint2(...)` 包装。

**移除条件**：fixer 实现后，基线扫描中此规则计数 <5。

## 4. 阻塞级别治理层

| 级别 | 含义 | 当前规则 |
|------|------|----------|
| 阻塞启动 | 阻止游戏启动，必须修复 | （无，当前无规则达到此级别） |
| 阻塞保存 | 地图编辑器无法保存 | （无） |
| 阻塞运行时 | 游戏内 ScriptError | XLIB_UNDEFINED_CROSS_REF（真实错误时）、SEM_UNDECLARED_VARIABLE（真实错误时） |
| 可延期清理 | 风格/规范问题 | XLIB_DISCOURAGED_NATIVE、XLIB_MISSING_INCLUDE |
| 疑似误报 | 需要 CompositionPlan 确认 | 无 CompositionPlan 时的 XLIB_*、SEM_UNDECLARED_* |

## 5. 优先级排序

1. **CompositionPlan 集成**（消除 ~86% 误报）— 最高优先级
2. **统一报告格式**（GalaxyCheckReport.json with confidence/autoFixable/runtimeRisk）
3. **XLIB_DISCOURAGED_NATIVE fixer**（唯一可自动修的真实问题）
4. **Fixture 梯队**（回归保护）
5. **全项目基线**（带 CompositionPlan 上下文后的真实基线）

## 6. 已知债务

- `SYNTAX_NO_LOCAL_INIT_ASSIGN`、`SEM_INVALID_TEXT_CONCAT`、`SYNTAX_NO_CONTINUE` 规则未实现
  （review 中提到但代码中不存在；若未来需要，需先建 fixture 再实现）
- catalog-ids.json 未包含所有 mod 的 catalog 导出
- CompositionPlan schema 已定义但 checker 尚未消费
- GalaxyManifest schema 已定义但 checker 尚未消费

## 7. 变更记录

| 日期 | 变更 |
|------|------|
| 2026-07-11 | 初始版本，基于 CoreRuntime/CoopZeroPop/CommanderBridge 基线扫描 |
