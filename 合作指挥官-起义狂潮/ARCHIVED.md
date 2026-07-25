# ARCHIVED

本仓库（合作指挥官-起义狂潮）已于 2026-07-25 归档。

## 归档原因

CMRE 框架运行时内容已完整迁入 SC2VibeTools 项目：
- 目标路径：`e:\Code\MyMod\SC2VibeTools\cmre-runtime\`
- 包含：Maps/CMRE（15 张合作地图）、Mods/CMRE（5 个核心 mod + 启动器改版）、Shared（CommanderPower/Commanders/Launcher/Mutators/Balance/Alenger3）、scripts（commander-power-metadata.ps1 + sc2/ + sc2-launcher/ + wait-for-game-ready.ps1）
- launcher（`launch-cmre-alenger.ps1`）默认 `$LegacyRoot` 已改为指向 `SC2VibeTools\cmre-runtime`，不再依赖本仓库

## 后续维护

所有 CMRE 框架运行时相关改动请在 SC2VibeTools 仓库进行：

```
e:\Code\MyMod\SC2VibeTools\
  cmre-runtime\          CMRE 框架运行时根（原 合作指挥官-起义狂潮 的 CMRE 部分）
  sc2-porting-workspace\ 移植产物（Alenger mods/Adapters + packages + launcher）
```

## 未迁入内容（保留在本仓库）

以下内容不属于 CMRE 框架运行时，未迁入 SC2VibeTools：
- `Maps/AIRO/`、`Maps/*_7vs1.SC2Map`、`Maps/zstory*.SC2Map` 等非 CMRE 地图
- `Mods/AIRO/`、`Mods/kit_mutations.SC2Mod`、`Mods/crys_swarm_assets.SC2Mod`
- `Mods/7vs1/Alenger*.SC2Mod/`（旧仓库里只剩 Triggers 空壳，主内容已迁出）
- `scripts/` 下大量非 CMRE 启动器（launch-abathur-*、launch-7vs1-*、launch-reborn-* 等）
- `scripts/airo/`、`scripts/reborn/`、`scripts/runtime-probe/` 等非 CMRE 工具

## Git 状态

- 最后一次提交：`d0ceed8d 修复 commander-power-metadata 中 Alenger4/10/11 的映射`
- 远程：`origin https://github.com/SIGEER2222/SC2.git`
- 分支：`fix_003`

如需查阅历史 CMRE 框架改动，请在本仓库 git log 中搜索。
