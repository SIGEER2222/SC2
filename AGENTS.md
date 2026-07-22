**Do NoT send optional commentary**

## Mandatory Skill Routing

开始编辑前，按任务类型加载并遵守对应 Skill。一个任务命中多行时，要求叠加执行；不得只选最轻的一行。

| 任务类型 | 必须遵守 | 不可跳过的完成门禁 |
| --- | --- | --- |
| 任何创建、修改、移动、重命名或删除文件的任务 | `$file-operations`，并叠加命中的领域 Skill | 使用原生文件操作或 `apply_patch`；禁止 shell 内容写入；编辑后检查 diff |
| SC2 地图、Mod、GameData、触发器、依赖、Adapter、生成地图、启动或同步逻辑 | `$sc2-workflow` + `references/galaxy-validation.md` + `references/runtime-testing.md` | patch live mod / sync map 后、SC2 启动前必须对受影响的 `Base.SC2Data` 运行 galaxy-checker，`summary.errors === 0` 才允许进图；运行时产物有变化时必须实际进图，等待测试流程结束 |
| `.galaxy` / `_h.galaxy` 修改或 ScriptError 调试 | `$sc2-workflow` + `references/galaxy-validation.md` + `references/runtime-testing.md` | 先完整运行 galaxy-checker（含 native API 与 catalog 引用验证），多 mod 场景必须传所有依赖 mod 的 `--symbol-root`，`summary.errors === 0` 再进图；checker 漏报时先补规则和回归测试 |
| 单位不能生产、缺技能/按钮、科技不一致、静态与运行时不同 | `$sc2-workflow` + `references/unit-diagnostics.md` | 先完成依赖和有效单位诊断；发生运行时修改时再执行进图测试 |
| MPQ 地图/Mod 的检查、解包、重打包或容器改动 | `$sc2-workflow` + `references/tooling.md` + `references/runtime-testing.md` | 原文件只读；重打包或运行时内容变化后必须用正确启动器进图 |
| 本地化扫描或中文文本修复 | `$sc2-workflow` + `references/localization-scan.md` | 保持内部 ID 为 ASCII；修改地图/Mod 文本产物时按 runtime-testing 判断是否进图 |

## Galaxy 静态验证强制门禁（Pre-launch Gate）

任何改动落地到 live mod / map 的 `Base.SC2Data` 后、SC2 启动前，必须执行 galaxy-checker 静态验证。运行时 `ScriptError` 暴露的语法/语义/跨库引用/native API 问题，都应在静态阶段被发现，不允许"先进图看错误再回头修"。

### 必跑命令（目录模式 + 多 mod 符号根）

```powershell
# CMRE + 7vs1 overlay 多 mod 场景示例
node "合作指挥官-起义狂潮/scripts/galaxy-checker/dist/cli.mjs" `
  "E:\SC2\SC2new\StarCraft II\Mods\CMRE\CMRE_Core_Triggers.SC2Mod\Base.SC2Data" `
  --symbol-root "E:\SC2\SC2new\StarCraft II\Mods\CMRE\CMRE_Core_Data.SC2Mod\Base.SC2Data" `
  --symbol-root "E:\SC2\SC2new\StarCraft II\Mods\7vs1\7vs1Base.SC2Mod\Base.SC2Data" `
  --format text
```

- 必须用**目录模式**（传 `Base.SC2Data` 目录），单文件模式会丢失跨文件符号产生大量误报。
- 多 mod 场景必须为每个依赖 mod 传一次 `--symbol-root`，否则 `XLIB_UNDEFINED_CROSS_REF` / `SEM_UNDECLARED_FUNCTION` 会误报。
- 退出码 0 才允许进图；非 0 必须先修复 error 级 issue，warning 级 issue 需评估后再决定。

### 必须覆盖的验证维度

galaxy-checker 一次运行同时覆盖以下维度，不可只跑语法：

1. **Galaxy 语法/语义**：`SEM_VOID_IN_CONDITION`（void 用在条件，如 `if (voidFn() == true)`，正是 cmui_customization.galaxy:1890 的错误类型）、`SEM_ARGUMENT_COUNT_MISMATCH`、`SEM_DUPLICATE_DECLARATION`、`SEM_LOCAL_DECLARATION_AFTER_STATEMENT`。
2. **跨库符号可见性**：`SEM_UNDECLARED_FUNCTION` / `XLIB_UNDEFINED_CROSS_REF`（多 mod 编译器对 `_h.galaxy` 前向声明可见性缺陷的核心规则，cmui_customization.galaxy:2432 的 `libCOMU_gf_CT_DisableMutatorVariant` 错误即属此类）。
3. **SC2 native API**：`XLIB_DISALLOWED_NATIVE`（黑名单 native，error）/ `XLIB_DISCOURAGED_NATIVE`（不推荐 native，warning）。基于 `data/natives.galaxy`（2874 个 native 签名）+ `data/native-blacklist.json`。
4. **Catalog 引用**：`CATALOG_INVALID_UNIT_REF`（字符串字面量引用的单位/技能 ID 在 catalog 中找不到，提示 mod 依赖缺失或 ID 拼写错误）。基于 `data/catalog-ids*.json`。
5. **工程级**：`PROJ_UTF8_BOM`（UTF-8 BOM 会导致库初始化失败）、`PROJ_ENCODING_INVALID`。

### 启动器集成要求

`launch-cmre.ps1` 等 patch live mod 的启动器，必须在 patch 完成后、`SC2Switcher` 启动前调用 galaxy-checker 验证 patched 目录。`summary.errors > 0` 时必须中止启动并报告 issue，不允许带着已知静态错误进图。
