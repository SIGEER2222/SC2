# Alenger3Adapter 能力解锁缺失导致建筑/单位 link 不显示

## 日期
2026-07-10

## 问题描述
在 7v1 战役地图中，Alenger3 的建筑和单位能正常生成（无 ScriptError），但：
- 建筑上的技能按钮（训练/升空等）不显示
- 可建造的单位不显示
- 单位自身的技能不显示
即"link 没有连起来"

## 根本原因
**Alenger3Adapter 的能力解锁列表不完整。**

7v1 框架的科技树封锁机制（`libE0EAE146_gf_ApplyOriginal7v1OpenerTech`）只为标准指挥官（Raynor/Swann/Nova/Mengsk 等）解锁能力，**没有任何 Alenger 指挥官的分支**。

Alenger3Adapter（`LibA3ADAPTER.galaxy`）的 MapInit 触发器只解锁了建造能力（`3jianzao1`/`3jianzao2`），完全没有解锁：
- 训练能力（`3xunlian1`/`3xunlian2A`/`3xunlian2B`/`3xunlian3A`/`3xunlian3B`/`3xunlian4A`/`3xunlian4B`）
- 升空/降落能力（`3shengkong1-4`/`3zhuolu1-4`）
- 变形/模式切换（`3jijiamoshi`/`3zhanjimoshi` 等 20 个）
- 效果/技能（`3hedandahepao`/`3zhiliao` 等 44 个）
- 增强/运输能力

未显式解锁的能力按钮在 7v1 框架下不会显示在命令卡上。

## 对比验证
- **Alenger1Adapter**（`LibA1ADAPTER.galaxy`）：正确地为所有自定义能力（建造/训练/研究/变异，cmd 0-31）调用了 `TechTreeAbilityAllow(..., true)`，所以 Alenger1 的 link 正常
- **Alenger6Adapter**：同样有完整的能力解锁模式
- **Alenger3Adapter**：只有建造能力的数据驱动解锁，缺少训练/研究/变异/单位技能

## 修复方案
在 `LibA3ADAPTER.galaxy` 的 MapInit 函数中，在数据驱动的 build_allows 循环之后，添加一个硬编码的能力解锁块，仿照 Alenger1Adapter 的模式：
- 遍历 cmd 0-31
- 对所有 Alenger3 自定义能力（约 80 个，排除 CAbilBehavior）调用 `TechTreeAbilityAllow(lp_player, AbilityCommand("能力ID", lv_i), true)`
- 对不存在的 cmd，引擎会自动忽略，无副作用

同时修复了 galaxy-checker 报出的 `SYNTAX_NO_LOCAL_INIT_ASSIGN` 错误（`int lp_player = 1;` → 先声明后赋值）。

## 验证结果
- galaxy-checker：0 错误 0 警告
- 游戏加载成功（exit 0，进程存活）
- Alerts.txt（9390 行）中**无任何 Alenger3 相关警告**
- ScriptError.txt 只有 BarracksRaynor 找不到的错误（Raynor 指挥官问题，与 Alenger3 无关）

## 经验教训
1. **7v1 框架的科技树封锁机制**：`ApplyOriginal7v1OpenerTech` 只覆盖标准指挥官，Alenger 系列指挥官必须在自己的 Adapter 中显式解锁所有能力
2. **能力解锁模式**：使用 `for (lv_i = 0; lv_i <= 31; lv_i += 1)` 循环对所有能力 cmd 解锁，是最简单可靠的方式
3. **诊断方法**：Alerts.txt 中搜索指挥官相关关键词（如 `3xunlian`/`3jianzao`），如果没有匹配项说明没有数据警告，能力解锁生效
4. **CAbilBehavior 不需要 TechTreeAbilityAllow**：只有 CAbilBuild/CAbilTrain/CAbilMorph/CAbilEffectTarget/CAbilEffectInstant/CAbilAugment/CAbilTransport/CAbilMorphPlacement 等有命令按钮的能力需要解锁

## 相关文件
- 修改：`Mods/7vs1/Alenger3Adapter.SC2Mod/Base.SC2Data/LibA3ADAPTER.galaxy`
- 参考：`Mods/7vs1/Alenger1Adapter.SC2Mod/Base.SC2Data/LibA1ADAPTER.galaxy`
- 数据源：`Shared/Alenger3/adapter-data.json`（build_allows 仅有建造能力，需要补充或由 galaxy 硬编码补充）
