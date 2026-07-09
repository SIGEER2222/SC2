# 光晕测试 by Pirate

> 本文档由 `scripts/build-map-docs.mjs` 自动生成,请勿手工编辑自动段落;"特有机制"小节欢迎人工补充后另存他处或改用独立文档。

## 概览

| 项目 | 值 |
| --- | --- |
| 地图目录 | `Maps/光晕测试 by Pirate.SC2Map` |
| 类型 | 测试/第三方 |
| MapScript.galaxy 行数 | 429 |
| 触发器总数(gt_*_Func) | 9 |
| 全局变量数(gv_) | 14 |
| include 库 | `TriggerLibs/NativeLib` |

## 全局变量摘要

按类型统计:

| 类型 | 数量 |
| --- | --- |
| `int` | 9 |
| `string[]` | 5 |

本图特有变量(14 个):

- `int gv_debugSliderHaloEmission`
- `int gv_debugSliderHaloWidth`
- `int gv_debugSliderHaloType`
- `int gv_debugSliderHaloRasterMode`
- `int gv_debugSliderHaloColor`
- `int gv_debugButtonHaloReset`
- `int gv_debugButtonHaloOn`
- `int gv_debugButtonHaloOff`
- `int gv_debugHaloFrame`
- `string[] gv_sceneHaloWidth`
- `string[] gv_sceneHaloType`
- `string[] gv_sceneHaloRasterMode`
- `string[] gv_sceneHaloEmission`
- `string[] gv_sceneHaloColor`

## 触发器清单

### 初始化(1)

- `gt_Init`

### 其他(8)

- `gt_DebugFrameSetHaloWidth`
- `gt_DebugFrameSetHaloEmission`
- `gt_DebugFrameSetHaloType`
- `gt_DebugFrameSetHaloRasterMode`
- `gt_DebugFrameSetHaloColor`
- `gt_DebugFrameButtonHaloOn`
- `gt_DebugFrameButtonHaloOff`
- `gt_DebugFrameButtonHaloReset`

## 特有机制(待人工补充)

<!-- 请在此补充该图的特有玩法/机制说明 -->

本图不属于 _7vs1 战役改造框架,未做公共/特有触发器区分,请直接参考上方触发器清单。

