# Protoss_Temple_Survival

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/Protoss_Temple_Survival.SC2Map` |
| 类型 | 测试/第三方 |
| MapScript.galaxy 行数 | 713 |
| 触发器总数(gt_*_Func) | 18 |
| 全局变量数(gv_) | 8 |
| include 库 | `TriggerLibs/NativeLib`、`TriggerLibs/LibertyLib`、`TriggerLibs/CampaignLib` |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `timer` | 2 |
| `int` | 2 |
| `unit` | 2 |
| `unitgroup` | 2 |

本图特有变量(8 个):

- `timer gv_zergGlobalTimer`
- `timer gv_bossTimer`
- `int gv_player1`
- `int gv_player2`
- `unit gv_boss`
- `unit gv_zeratul`
- `unitgroup gv_nexusGroup`
- `unitgroup gv_stoneZealot`

## 触发器清单

### 进攻波次(8)

- `gt_StartWaveSet` — Start Wave Set
- `gt_RepeatingAttackWave` — Repeating Attack Wave
- `gt_ZergWave1G` — Zerg Wave 1G
- `gt_ZergWave2G` — Zerg Wave 2G
- `gt_ZergWave3G` — Zerg Wave 3G
- `gt_ZergWave4G` — Zerg Wave 4G
- `gt_ZergWave5G` — Zerg Wave 5G
- `gt_Bosswave` — Boss wave

### 胜负(2)

- `gt_Defeat`
- `gt_Victory`

### 其他(8)

- `gt_MapStart` — Map Start
- `gt_LightCycle` — Light Cycle
- `gt_BreakFree` — Break Free
- `gt_StoneZealotOff` — Stone Zealot Off
- `gt_NexusSwitch` — Nexus Switch
- `gt_IdleUnits` — Idle Units
- `gt_ZergAir1G` — Zerg Air 1G
- `gt_ZergAir2G` — Zerg Air 2G

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

本图不属于 _7vs1 战役改造框架,未做公共/特有触发器区分,请直接参考上方触发器清单。

