# 重生虫心搬运 — Phase 2 冲突分析报告

> 日期：2026-07-11
> 状态：完成

## 2.1 概览

Reborn 主 Mod (`crys_the_swarm_reborn.SC2Mod`) 与 7vs1 Runtime（CoreRuntime + CommanderBridge + BaseCatalogPatch + SharedUnits + CoopZeroPop + ExternalRefs）的有效 Catalog 冲突统计：

| Catalog | 总数 | 重定义 | Reborn独有 | 7vs1独有 | 一致 |
|---------|------|--------|-----------|---------|------|
| Unit | 2765 | **293** | 234 | 54 | 2184 |
| Ability | 1961 | 84 | 250 | 105 | 1522 |
| Behavior | 2104 | 15 | 355 | 27 | 1707 |
| Effect | 7481 | 53 | 877 | 8 | 6543 |
| Weapon | 799 | 59 | 187 | 0 | 553 |
| Upgrade | 1343 | 90 | 116 | 91 | 1046 |
| Actor | 11108 | 80 | 714 | 124 | 10190 |
| Button | 3418 | 33 | 690 | 41 | 2654 |
| Requirement | 1847 | 21 | 156 | 53 | 1617 |
| Validator | 3004 | 2 | 160 | 0 | 2842 |
| Model | 11032 | 1 | 579 | 0 | 10452 |
| Mover | 263 | 0 | 10 | 0 | 253 |
| Sound | 17193 | 1 | 24 | 0 | 17168 |
| Tactical | 88 | 0 | 9 | 0 | 79 |
| **合计** | | **732** | **4361** | **503** | |

## 2.2 Unit 冲突分类（293）

### 分类 A：SC2 原生单位双方重定义（~180）
SC2 原生单位被 Reborn 和 7vs1 各自修改。例：
- 虫族：Roach, Hydralisk, Baneling, Infestor, Brood*, Lurker, Queen, Drone, Nydus, Creep*, Swarm*, Greater*
- 人族：Ghost, Barracks, Factory, Hellion, Marine*
- 神族：DarkTemplar, HighTemplar, Mothership
- HotS 变体：HotSHunter, HotSRaptor, HotSSwarml

**策略**：这些是 Reborn 地图运行的基础。RebornBridge 不覆盖这些条目，让 Reborn 的定义通过。7vs1 需要在 Reborn 之上叠加自己的修改。

### 分类 B：Reborn 原创单位（234）
Reborn 独有的单位，7vs1 中没有。例：
- Abrogator, AcidFiend, Archangel, AshWorm2, BaneHost, BaneHostBurrowed
- CharDevourer, CharHatchery, CharInfestor, CharQueen
- 各种进化变体（zevolution*）

**策略**：直接保留，不需要任何补丁。RebornBridge 透传。

### 分类 C：7vs1 原创单位（54）
7vs1 独有的单位，Reborn 中没有。例：
- RaynorX 系列（BarracksRaynorX, FactoryRaynorX, MarineRaynorX...）
- GenericBonusController
- 指挥官变体单位

**策略**：需要 7vs1 加载在 Reborn 之后，这些单位由 7vs1 Runtime 提供。

### 分类 D：指挥官特定冲突（~30）
双方都定义了相同指挥官的单位但内容不同：
- Mengsk*（15）、Primal*（9）、Dehaka*（7）、Nova*（5）、SI_*（4）

**策略**：如果使用 7vs1 指挥官系统，则 7vs1 指挥官定义覆盖 Reborn。如果 Reborn 有自己的指挥官系统，则需在 Bridge 中映射。

## 2.3 补丁路径设计

### 依赖加载顺序

```
SC2 官方 (core, liberty, swarm, void, starcoop)
  → Reborn 主 Mod (crys_the_swarm_reborn)
  → 7vs1 Runtime (CoreRuntime, CommanderBridge, BaseCatalogPatch, SharedUnits, CoopZeroPop)
  → RebornBridge.SC2Mod（补丁层）
  → 逐地图补丁
  → 地图本地数据
```

### RebornBridge 分层策略

| 层 | 内容 | 优先级 |
|----|------|--------|
| L0 | 空骨架（已创建） | Phase 1 |
| L1 | SC2 原生单位差异补丁 | 低（先让 Reborn 定义通过） |
| L2 | 7vs1 运行时兼容 | 中（确保 7vs1 系统可用） |
| L3 | 指挥官单位映射 | 高（如果 Reborn 有指挥官系统） |
| L4 | 逐地图特殊补丁 | 最高（地图特定需求） |

### 渐进式补丁策略

1. **先不添加任何补丁**（当前状态），让 RebornBridge 保持空骨架
2. **进图测试**，观察具体哪个阶段出错
3. **按需添加补丁**，仅修复实际出错的条目
4. **避免批量覆盖**，防止引入新的兼容性问题

### 关键冲突条目（待手动审查）

- 293 个 Unit 重定义中，约 180 个是 SC2 原生单位 → 大部分可能不需要补丁（Reborn 定义足够）
- 84 个 Ability 重定义 → 需要逐个检查是否影响地图逻辑
- 15 个 Behavior 重定义 → 少量，影响可控
- 90 个 Upgrade 重定义 → 科技树冲突，需要仔细处理

## 2.4 下一步

进入 Phase 3：在 RebornBridge 中逐步添加最小补丁，从低风险条目开始，每次添加后进图验证。

### 新增文件

| 文件 | 说明 |
|------|------|
| `scripts/reborn/catalog_diff.py` | Catalog 对比工具 |
| `scripts/reborn/analyze_conflicts.py` | 冲突分析脚本 |
| `docs/reborn-port/catalog-diff.json` | 完整冲突数据 |