# AGENTS.md

## SC2 Repo Rules

- 结束前必须执行 `git pull`、`git commit`、`git push`。
- 不要跳过推送。
- commit 的说明请使用中文。
- 改动前先确认当前工作区状态，避免覆盖用户已有修改。
- 只做当前任务需要的最小改动，不要顺手重构无关内容。
- 编辑文件优先用 `apply_patch`。
- 如果发现远端有新提交，先快进同步，再继续修改。
- **编写/修改 galaxy 脚本（`.galaxy` / `_h.galaxy`）后，必须先调用 galaxy-checker 解析器验证再进图测试**：
  - 路径：`E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\galaxy-checker\dist\cli.mjs`
  - 用法：`node dist/cli.mjs "<目标 .galaxy 文件或 Base.SC2Data 目录>" --format text`
  - 扫描整个 mod 目录比单文件更准（能加载 `_h.galaxy` 声明和跨文件符号）：`node dist/cli.mjs "E:\...\某mod.SC2Mod\Base.SC2Data" --format text`
  - 解析器能识别 9 类错误（语法/语义/跨库引用/编码/BOM 等），行号定位精确到列，远优于 SC2 编译器（SC2 报"错误的参数集数"时常常滞后 1 行且不指明函数）。
  - 优先修复解析器报出的 `[ERROR]` 级问题（特别是 `SEM_ARGUMENT_COUNT_MISMATCH` / `SEM_UNDECLARED_*` / `XLIB_UNDEFINED_CROSS_REF` / `SYNTAX_NO_CONTINUE` / `PROJ_BOM_DETECTED`），确认 0 错误或剩余错误均为已知跨 mod 引用问题后再进图。
  - 若 `dist/` 不存在，先 `cd scripts/galaxy-checker && npm install && npm run build`。
- 涉及地图/触发器/运行时改动时，**必须实际进入地图测试**。按以下优先级逐步校验：
  - 如果游戏正在运行，必须重启游戏，把这个写到启动脚本里，启动后**必须**运行 `powershell -NoProfile -ExecutionPolicy Bypass -File E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\wait-for-game-ready.ps1` 并**等待脚本返回结果**，不可提前结束任务。
  - 智能等待逻辑（不会删除任何日志文件）：
    - **失败（exit 1）**：Alerts.txt 出现后 20 秒宽限期内出现新的 ScriptError，或游戏进程崩溃退出，脚本会输出完整的 ScriptError.txt 报错内容
    - **成功（exit 0）**：Alerts.txt 出现 + 20 秒宽限期无新 ScriptError + 游戏进程存活
    - **超时（exit 2）**：180 秒内未检测到 Alerts.txt，需人工确认
  - 如脚本返回非零退出码，必须先修复报错再结束。
- **测试非 7vs1 地图（如 `外部资源\TemplateMaps` 下的 MPQ 压缩地图）时的强制规则**：
  - **禁止**用 `launch-7vs1-coop-test.ps1` 启动这类地图。该脚本会向地图注入 70+ 个 `Lib*.galaxy` 运行时库（LibKPVP/LibKCOR/LibE0EAE146_* 等），与原地图 `MapScript.galaxy` 冲突，导致"脚本读取失败：函数已声明但尚未定义"致命错误。
  - **必须**用 `SC2Switcher_x64.exe` 直接加载原始 MPQ 文件（与 launch-7vs1-coop-test.ps1 启动方式一致）：
    ```powershell
    $switcher = "E:\SC2\SC2new\StarCraft II\Support64\SC2Switcher_x64.exe"
    $map = "E:\Code\MyMod\SC2\外部资源\TemplateMaps\<地图名>.SC2Map"
    Start-Process -FilePath $switcher -ArgumentList "`"$map`""
    ```
    注意：`SC2_x64.exe -loadmap` 参数会让进程立即退出；必须用 `SC2Switcher_x64.exe` 并直接传地图路径（不带 -loadmap）。
  - 启动后**必须走完整等待+检查流程**，不可启动后立即结束任务：
    - 等待至少 45 秒让游戏加载
    - 检查 `SC2_x64` 进程是否存活（进程退出=加载失败）
    - 检查 `C:\Users\22448\Documents\StarCraft II\GameLogs` 下是否有新的 `ScriptError.txt`
    - 如有报错先修复，否则报告测试结果（进程 PID、运行时长、是否有 ScriptError）
  - 如需查看地图内部结构，用 `mpyq` 解压 MPQ 到目录形式再分析：
    ```python
    from mpyq import MPQArchive
    archive = MPQArchive(r"<MPQ文件路径>")
    for name_bytes in archive.files: ...
    ```

每次出现报错并修复之后，总结经验到本地文档 E:\Code\MyMod\SC2\合作指挥官-起义狂潮\docs\经验总结


## 参考数据源
E:\Code\MyMod\SC2\其他mod\SC2GameData

## 工具脚本

### Galaxy 静态解析器（galaxy-checker）

**路径**：`E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\galaxy-checker\`

**用途**：静态解析 galaxy 脚本（`.galaxy` / `_h.galaxy`），无需启动游戏即可发现编译错误。**编写/修改 galaxy 脚本后必须先调用此工具验证**，避免把本可静态发现的错误拖到 30+ 秒的进图测试环节。

**核心能力**：
- Lexer / Parser（chevrotain 递归下降，C 优先级层次完整，支持 do-while / 位移 / 复合赋值 / 多维数组）
- SemanticAnalyzer（声明收集、跨文件全局符号表、native 表、类型检查、外部库识别）
- **catalog 引用校验**（CATALOG_INVALID_UNIT_REF）：检查 galaxy 脚本中传给 `UnitCreate`/`libNtve_gf_CreateUnitsWithDefaultFacing`/`UnitTypeGetProperty`/`CatalogFieldValueGet` 等 native 的字符串字面量是否在 GameData XML 中存在，能在不启动游戏的情况下发现 mod 依赖缺失或 ID 拼写错误
- 行号定位精确到列（优于 SC2 编译器，SC2 报错常常滞后 1 行且不指明函数）
- 15 条规则覆盖 10 类错误：SYNTAX（no-continue / no-local-init）、SEM（undeclared var/fn、arg-count、duplicate、void-in-condition、return/assign 类型）、XLIB（disallowed-native、undefined-cross-ref、missing-include）、PROJ（UTF-8 BOM、编码）、CATALOG（invalid-unit-ref）

**常用命令**：
```powershell
# 扫描单个文件
node scripts/galaxy-checker/dist/cli.mjs "路径/某文件.galaxy" --format text

# 扫描整个 mod 目录（推荐，能加载 _h.galaxy 声明和跨文件符号）
node scripts/galaxy-checker/dist/cli.mjs "路径/某mod.SC2Mod/Base.SC2Data" --format text

# JSON 格式输出
node scripts/galaxy-checker/dist/cli.mjs "路径" --format json
```

**规则说明**：规则配置在 `data/project-rules.json`，可启用/禁用单条规则或自定义严重级别。

**构建**（首次使用或修改了 `src/` 后）：`cd scripts/galaxy-checker && npm install && npm run build`，产物在 `dist/cli.mjs`。

**测试**：`cd scripts/galaxy-checker && npx vitest run`（132 个测试）。

**已知局限**：
- 单文件扫描会报大量 `SEM_UNDECLARED_VARIABLE` / `XLIB_UNDEFINED_CROSS_REF`（因 `_h.galaxy` 声明和 NativeLib 跨库符号未加载），扫描整个 `Base.SC2Data` 目录可消除大部分噪音
- 跨 mod 引用（如 CoreRuntime 的符号在 CommanderBridge 中引用）仍会报 `XLIB_UNDEFINED_CROSS_REF`，属已知问题，需结合上下文判断
- catalog 引用校验仅检查字符串字面量（变量传递的 ID 无法追踪）；catalog DB 需包含所有相关 mod 才能避免误报（运行 `python scripts/sc2_unit_explorer.py --export-catalog-ids --out scripts/galaxy-checker/data/catalog-ids.json` 重新生成）
- 不解析 Actor 数据

### SC2 单位关系图查询工具（sc2_unit_explorer.py）

**路径**：`E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\sc2_unit_explorer.py`

**用途**：静态分析 GameData XML + galaxy 脚本，图式地展开一个单位的所有关联信息，无需启动游戏。是迁移/调试指挥官单位时的首要分析工具，**后续需要不断完善**。

**核心能力**：
- 多层 mod 按 SC2 引擎规则合并（core→liberty→swarm→void→starcoop→CoopZeroPop→CommanderCatalog→XM）
- 宽容 XML 解析（修复 us-ascii 声明含中文、缺少 `<Catalog>` 包装等问题）
- 正确的合并语义（id/index/Row+Column/Link 关键字段、removed="1" 移除、InfoArray 多 `<Unit>` 子元素取最后非空值）
- parent 继承机制（子类未定义的数据从父类继承 AbilArray/CardLayouts/能力/武器/属性）
- galaxy 脚本运行时解析（三类动态修改）：
  - `UnitAbilityAdd` → 标记 `[运行时注入]` 能力
  - `TechTreeUnitAllow`/`gf_*Allow*Unit*`/`gf_*Block*Unit*` → 标记 `科技树:已解锁/锁定`
  - `TechTreeAbilityAllow`/`gf_*Allow*Abil*`/`gf_*Block*Abil*` → 能力解锁状态
- 本地化文本加载（GameStrings/ObjectStrings/TriggerStrings）
- 文本树 + JSON 双格式输出、`--depth` 递归展开、`--mod`/`--only-mod` 自定义加载路径

**覆盖的关系类型**：
| 单位类型 | 展开内容 |
|---------|---------|
| 工蜂/SCV/探针 | 可建造建筑（CAbilBuild） |
| 幼虫 | 可变异单位（CAbilTrain） |
| 建筑 | 可生产单位 + 可研究科技 + 附件 + 自身技能 |
| 兵种 | 拥有的技能（AbilArray）+ 卡牌按钮（CardLayouts）+ 武器 |
| 所有单位 | 反向：谁生产我 / 谁建造我 / 谁变异成我 |

**常用命令**：
```powershell
# 基础查询
python scripts/sc2_unit_explorer.py Larva
python scripts/sc2_unit_explorer.py Drone --depth 2
python scripts/sc2_unit_explorer.py BarracksRaynor

# 输出到文件
python scripts/sc2_unit_explorer.py MarineRaynor --out "docs/xxx.txt"

# JSON 格式
python scripts/sc2_unit_explorer.py Bunker --format json

# 列表查询
python scripts/sc2_unit_explorer.py --list-units --filter "^Raynor"
python scripts/sc2_unit_explorer.py --list-abilities --filter "Train$"

# 自定义 mod 加载
python scripts/sc2_unit_explorer.py Marine --mod "E:\path\OtherMod.SC2Mod"
python scripts/sc2_unit_explorer.py Marine --only-mod "E:\path\OtherMod.SC2Mod"
```

**已知局限与改进方向**（后续完善重点）：
1. **CatalogFieldValueSet 未解析**：galaxy 脚本动态修改的字段值（如射程、伤害、资源量）仍是 XML 原始值
2. **上下文推断简化**：`UnitAbilityAdd` 的单位类型通过同函数内最近的 `UnitGetType == "XXX"` 推断，不支持跨函数/跨 if 块的精确作用域
3. **ApplyTechFilter 未模拟**：无法输出"某指挥官实际可用的单位/能力清单"，只标记单个单位的锁定状态
4. **Actor 数据不解析**：仅用于显示模型
5. **galaxy 脚本路径限定**：只扫描 `mod\Base.SC2Data\*.galaxy`，不递归子目录

**相关文档**：
- 扫描对比报告：`docs/指挥官扫描对比/扫描对比报告.md`
- 运行时动态修改报告：`docs/指挥官扫描对比/运行时动态修改报告.md`

**维护规则**：
- 新增解析能力时，在"已知局限与改进方向"中移除已解决项
- 保留 `[运行时注入]` 和 `科技树:已解锁/锁定` 标记格式，已有文档依赖这些标记
