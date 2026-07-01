# AGENTS.md

## SC2 Repo Rules

- 结束前必须执行 `git pull`、`git commit`、`git push`。
- 不要跳过推送。
- commit 的说明请使用中文。
- 改动前先确认当前工作区状态，避免覆盖用户已有修改。
- 只做当前任务需要的最小改动，不要顺手重构无关内容。
- 编辑文件优先用 `apply_patch`。
- 如果发现远端有新提交，先快进同步，再继续修改。
- 涉及地图/触发器/运行时改动时，**必须实际进入地图测试**，不可只做静态分析或快速编译就结束。按以下优先级逐步校验：
  1. **静态分析（秒级）**：先运行 `python E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\validate-galaxy-scripts.py`，检测 BOM、括号不匹配、禁用原生函数、include 缺失、跨库引用不一致等低级错误。
  2. **快速编译验证（约 20-30 秒）**：静态分析通过后，运行 `powershell -NoProfile -ExecutionPolicy Bypass -File E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\quick-compile-check.ps1`，利用游戏编译阶段检测语法和链接错误，比完整进图快很多。
  3. **完整进图测试（强制）**：以上都通过后，**必须**运行 `E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\launch-7vs1-coop-test.ps1` 启动游戏测试。
  - 启动后**必须**运行 `powershell -NoProfile -ExecutionPolicy Bypass -File E:\Code\MyMod\SC2\合作指挥官-起义狂潮\scripts\wait-for-game-ready.ps1` 并**等待脚本返回结果**，不可提前结束任务。
  - 智能等待逻辑（不会删除任何日志文件）：
    - **失败（exit 1）**：Alerts.txt 出现后 20 秒宽限期内出现新的 ScriptError，或游戏进程崩溃退出，脚本会输出完整的 ScriptError.txt 报错内容
    - **成功（exit 0）**：Alerts.txt 出现 + 20 秒宽限期无新 ScriptError + 游戏进程存活
    - **超时（exit 2）**：180 秒内未检测到 Alerts.txt，需人工确认
  - 如脚本返回非零退出码，必须先修复报错再结束。

## 禁止执行的危险命令

**以下命令严禁直接执行，必须调用 `safe-operations` Skill 并使用对应的包装脚本：**

| 禁止的原生命令 | 包装脚本 | 用法示例 |
|---------------|----------|----------|
| `Remove-Item` | `scripts/trae-rm.ps1` | `powershell -File scripts/trae-rm.ps1 "file.txt"` |
| `Remove-Item -Recurse` | `scripts/trae-rmdir.ps1` | `powershell -File scripts/trae-rmdir.ps1 "dir"` |
| `git checkout <分支>` | `scripts/trae-checkout.ps1` | `powershell -File scripts/trae-checkout.ps1 "dev"` |
| `git checkout -- <文件>` | `scripts/trae-checkout-file.ps1` | `powershell -File scripts/trae-checkout-file.ps1 "file.txt"` |
| `git restore <文件>` | `scripts/trae-restore.ps1` | `powershell -File scripts/trae-restore.ps1 "file.txt"` |
| `git clean -fd` | `scripts/trae-clean.ps1` | `powershell -File scripts/trae-clean.ps1` |
| `git add <文件>` | `scripts/trae-add.ps1` | `powershell -File scripts/trae-add.ps1 "file.txt"` |

**注意**：请勿使用 `git add .`、`git add -A` 或 `git add *`，必须明确指定要暂存的具体文件路径。

**违反此规则将导致不可预知的后果，包括但不限于：**
- 意外删除重要文件
- 分支切换导致工作区混乱
- 未提交的修改丢失
- 未跟踪的新文件被清理

每次出现报错并修复之后，总结经验到本地文档 E:\Code\MyMod\SC2\合作指挥官-起义狂潮\docs\经验总结

官方数据地址 E:\Code\MyMod\SC2\合作指挥官-起义狂潮\游戏数据\官方SC2原始文本镜像

## 参考数据源

| 路径 | 内容 | 用途 |
|------|------|------|
| `E:\Code\MyMod\SC2\sc2-data-trigger` | 完整官方触发器/GameData 镜像，包含 core/swarm/void/liberty 等所有资料片 mod | 触发器逻辑、GameData XML 参考 |
| `E:\Code\MyMod\SC2\合作指挥官-起义狂潮\游戏数据\官方SC2原始文本镜像\mods\starcoop` | 合作指挥官 starcoop mod，包含 commanders/ 子目录（18个指挥官独立mod） | 指挥官特定数据、天赋/技能定义 |
| `E:\Code\MyMod\SC2\解包数据\海克斯合作PVP0.110.SC2Mod` | 海克斯合作 PVP mod 解包数据 | Hex 天赋/技能系统参考 |


## 工具脚本

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
- 修改后必须验证 Larva/Drone/Barracks/Marine/SCV 五个基准单位的输出仍正确
- 新增解析能力时，在"已知局限与改进方向"中移除已解决项
- 保留 `[运行时注入]` 和 `科技树:已解锁/锁定` 标记格式，已有文档依赖这些标记
