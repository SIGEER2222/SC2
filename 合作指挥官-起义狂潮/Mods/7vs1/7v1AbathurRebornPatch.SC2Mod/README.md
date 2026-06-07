# 7v1AbathurRebornPatch.SC2Mod

测试线下的本地目录式独立 Mod。

来源：

- 基于 `游戏数据/其他mod数据/7vs1母巢之战合作指挥官bate版_SC2Replay_94137/s2ma_packages/pkg15_abathur_reborn_patch/extract`

用途：

- 给 `7vs1混合地图测试/Maps/*.SC2Map` 提供“重生阿巴瑟”的私有 Catalog 和最小运行时入口
- 保持重生阿巴瑟主体逻辑独立，不把数据直接揉进 `CoopZeroPop.SC2Mod`

当前边界：

- 不修改原 replay 拆包的 `pkg01/pkg03`
- 不替代 `CoopZeroPop.SC2Mod` 的 `LibKPVP/LibKCOR/LibKCUI/LibKMIS`
- 当前只提供独立指挥官数据和 `LibA1BA7A9F` 最小运行时入口；真正的 7v1 指挥官分发仍需地图或测试脚本显式挂载/桥接
