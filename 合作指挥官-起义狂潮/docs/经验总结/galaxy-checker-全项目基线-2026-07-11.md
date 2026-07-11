# galaxy-checker 全项目基线 — 2026-07-11

## 快照信息

| 项目 | 值 |
|------|-----|
| 扫描日期 | 2026-07-11 |
| 扫描范围 | `合作指挥官-起义狂潮/Mods/` 全目录 |
| 文件数 | 179 个 `Lib*.galaxy` |
| symbol-root | `Mods/` 自身（跨 mod 符号可见） |
| CompositionPlan | 未加载（无 `CompositionPlan.json`） |
| 报告文件 | `scripts/galaxy-checker/reports/baseline-full.json` |

## 错误分布

| 规则 | 数量 | 级别 | 置信度 | 可自动修 | runtimeRisk |
|------|------|------|--------|----------|-------------|
| CATALOG_INVALID_UNIT_REF | 2330 | warning | medium | 否 | low |
| XLIB_DISCOURAGED_NATIVE | 108 | warning | high | 是 | low |
| XLIB_MISSING_INCLUDE | 84 | warning | low | 否 | medium |
| SYNTAX_PARSE_ERROR | 3 | **error** | high | 否 | **high** |
| SEM_UNDECLARED_FUNCTION | 2 | **error** | low | 否 | high |
| **合计** | **2527** | 5e/2522w | — | 108 | — |

## Legacy Debt 分类

### A. 真实错误 — 必须修复（high confidence error）

**SYNTAX_PARSE_ERROR × 3**：`_h.galaxy` 头文件末尾多余分号导致解析失败。

| 文件 | 行 | 问题 |
|------|-----|------|
| Lib48DF4533_h.galaxy | 12 | `Expecting EOF but found ';'` |
| LibA070801C_h.galaxy | 92 | `Expecting EOF but found ';'` |
| LibKRTC_h.galaxy | 49 | `Expecting EOF but found ';'` |

**影响**：头文件解析失败会导致其中声明的函数/变量符号全部丢失，引发连锁误报。
**修复方式**：删除 `_h.galaxy` 文件末尾的多余分号。

### B. 疑似误报 — 需上下文确认（low confidence error）

**SEM_UNDECLARED_FUNCTION × 2**：`Lib48DF4533.galaxy:15960-15961` 引用 `TriggerAddEventActivityChanged` / `TriggerAddEventRoomChanged`。

- confidence=low（未加载 CompositionPlan 上下文）
- 这些函数来自 SwarmStory 战役库，当前 symbol-root 下不可见
- 加载完整依赖上下文后应消失

### C. 可自动修复的 Legacy Debt（high confidence warning, autoFixable）

**XLIB_DISCOURAGED_NATIVE × 108**：直接调用 `UnitCreate()` 而非 `libNtve_gf_CreateUnitsAtPoint2()` 包装。

| 文件 | 数量 |
|------|------|
| LibKRTC.galaxy | 49 |
| LibKMIS.galaxy | 24 |
| LibA070801C.galaxy | 16 |
| LibE0EAE146.galaxy | 6 |
| LibE0EAE146_HeroStructures.galaxy | 4 |
| LibE0EAE146_MengskRuntime.galaxy | 4 |
| LibE0EAE146_ZeratulRuntime.galaxy | 3 |
| LibE0EAE146_HeroRevive.galaxy | 2 |

**修复方式**：`node dist/cli.mjs <目录> --fix XLIB_DISCOURAGED_NATIVE`

### D. 上下文相关误报（low confidence warning）

**XLIB_MISSING_INCLUDE × 84**：include 文件未找到，集中在 `LibE0EAE146.galaxy`(52)。

- confidence=low（未加载 CompositionPlan 上下文）
- 大部分是引用游戏自带库（libNtve 等）或外部 mod 库
- 加载完整依赖上下文后应大幅减少

### E. Catalog 引用校验（medium confidence warning）

**CATALOG_INVALID_UNIT_REF × 2330**：catalog ID 字符串在 `catalog-ids.json` 中找不到。

- confidence=medium（catalog 数据库不完整时可能误报）
- 当前 `data/catalog-ids.json` 只包含部分导出 ID
- 需要扩充 catalog 数据库后重新评估真实错误率

## 新代码硬门禁规则

以下规则在新代码中**不得新增**，galaxy-checker 作为 AI 写 Galaxy 后的硬门禁：

| 规则 | 阈值 | 说明 |
|------|------|------|
| SYNTAX_PARSE_ERROR | **0** | 语法错误必须为零，任何新增都是阻塞 |
| SEM_UNDECLARED_FUNCTION | **0**（high confidence） | 新代码不得引用未声明函数 |
| SEM_UNDECLARED_VARIABLE | **0**（high confidence） | 新代码不得引用未声明变量 |
| SEM_DUPLICATE_DECLARATION | **0** | 新代码不得重复声明 |
| SEM_RETURN_TYPE_MISMATCH | **0** | 新代码不得有返回类型不匹配 |
| XLIB_DISCOURAGED_NATIVE | **0 新增** | 新代码不得直接调用 UnitCreate，必须用包装函数 |
| PROJ_UTF8_BOM | **0** | 新文件不得有 BOM |

## 基线对比基准

当前基线作为 legacy debt 快照。后续每次 galaxy-checker 扫描应与基线对比：

- **errors 不得增加**：5 个 legacy error 可保留但不得新增
- **XLIB_DISCOURAGED_NATIVE 只减不增**：108 个 legacy 可逐步用 Fixer 清理
- **XLIB_MISSING_INCLUDE 忽略 low confidence**：加 CompositionPlan 后重新评估
- **CATALOG_INVALID_UNIT_REF 需扩充数据库后重新基线**

## 下一步

1. 修复 3 个 SYNTAX_PARSE_ERROR（删除多余分号）
2. 用 `--fix XLIB_DISCOURAGED_NATIVE` 批量清理 108 个 UnitCreate 调用
3. 创建 `CompositionPlan.json` 使 checker 能自动加载完整依赖上下文
4. 扩充 `data/catalog-ids.json` 减少 CATALOG_INVALID_UNIT_REF 误报
5. 建立基线对比脚本，CI 中自动检测新增问题
