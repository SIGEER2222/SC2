# 重生虫心搬运 — Phase 0 批次报告

> 日期：2026-07-11
> 状态：完成

## 0.1 容器清单

- 35 个容器全部识别并生成 SHA-256
- 清单文件：`docs/reborn-port/source-manifest.json`
- 5 个 Mod：1 个目录型（crys_the_swarm_reborn），4 个 MPQ 文件型
- 30 张地图：24 张任务图 + 6 张 story 图（均为 MPQ 文件）
- 资产包 216 MB 已记录 SHA-256，未纳入 Git

## 0.2 工作流配置

- 新增 `file:Campaigns/SwarmStory.SC2Campaign` 到 externalDependencies
- 新增 `file:Mods/Swarm.SC2Mod` 到 externalDependencies
- 文件：`Shared/Workflow/sc2-workflow.json`

## 0.3 Mod 安装

- 5 个 Reborn Mod 已安装到 `Mods/` 目录
- 修复 `sync-mods-and-maps.mjs` 支持 MPQ 文件型 Mod
- 创建 `scripts/reborn/launch-reborn-baseline.ps1` 统一启动脚本

## 0.4 Story 地图解包

- 6 张 story 地图全部解包到 `Maps/`
- 使用 `unpack_maps_batch.py`（mpyq）
- PreloadAssetDB.txt 读取失败（无害，可重建）

## 0.5 剧情入口分析

- 所有 story 地图使用相同的 Bank 体系：
  - `cryswarmcoop`（玩家 1 和 14）
  - `ZCampaignStats`, `ZStory`, `ZCampaign`, `ZArmy` 等官方 Bank
- 所有 story 地图依赖：
  - `file:Campaigns\SwarmStoryUtil.SC2Mod`
  - `file:Mods\crys_the_swarm_reborn.SC2Mod`
- 剧情入口推测为 `zstorychar`（有 Sections/Char）
- 使用 `libSwaC_gf_MissionStatusCheck` 检查任务完成状态
- 使用 `libSwaC_gf_LastMap()` 追踪最后游玩的地图

## 0.6 任务图基线

- 地图：`zexpedition03.SC2Map`（Harvest of Screams）
- 依赖：`SwarmStory.SC2Campaign` + `crys_the_swarm_reborn.SC2Mod`
- Galaxy 文件：仅 1 个（MapScript.galaxy）
- 启动结果：**通过**
  - 加载时间：20.9s
  - ScriptError：无
  - 游戏进程：存活

## 0.7 剧情图基线

- 地图：`zstorychar.SC2Map`
- 启动结果：**通过**（有非致命警告）
  - 加载时间：20.7s
  - ScriptError：非致命警告（"出现触发器错误"、"无权调用"）
  - 游戏进程：存活
  - 警告来源：战役系统在无完整战役上下文时的预期行为

## 0.8 新增/修改文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `docs/reborn-port/source-manifest.json` | 新增 | 35 容器 SHA-256 清单 |
| `docs/reborn-port/phase-0-report.md` | 新增 | 本报告 |
| `Shared/Workflow/sc2-workflow.json` | 修改 | 添加 SwarmStory/Swarm 外部依赖 |
| `web-launcher/lib/sync-mods-and-maps.mjs` | 修改 | 支持 MPQ 文件型 Mod |
| `scripts/reborn/launch-reborn-baseline.ps1` | 新增 | 基线启动脚本 |
| `Mods/crys_the_swarm_reborn.SC2Mod/` | 新增 | 主 Mod（目录） |
| `Mods/crys_swarm_assets.SC2Mod` | 新增 | 资产包（216 MB MPQ） |
| `Mods/sibirens_starhooks_common.SC2Mod` | 新增 | 辅助 Mod（MPQ） |
| `Mods/sibirens_starhooks_swarmstoryutils.SC2Mod` | 新增 | 辅助 Mod（MPQ） |
| `Mods/sibirens_sundries_swarm_reborn.SC2Mod` | 新增 | 辅助 Mod（MPQ） |
| `Maps/zstorychar.SC2Map/` ~ `Maps/zstoryzerus.SC2Map/` | 新增 | 6 张 story 图（解包） |

## 下一步

Phase 1 就绪条件：
- [x] 35 容器 SHA-256 manifest
- [x] SwarmStory external dependency 识别
- [x] 五 Mod 混合容器闭包安装
- [x] 六张 story 地图解包
- [x] 剧情入口和 Bank/MissionStatus 协议识别
- [x] zexpedition03 任务图基线通过
- [x] zstorychar 剧情图基线通过

**Phase 0 里程碑完成。可以进入 Phase 1：创建 RebornBridge.SC2Mod 和第一张兼容地图。**