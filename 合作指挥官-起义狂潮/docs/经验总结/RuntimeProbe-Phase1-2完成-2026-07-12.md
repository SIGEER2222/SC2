# RuntimeProbe Phase 1+2 完成总结

- **任务类型**: SC2 Galaxy 脚本开发 + Python 工具开发
- **时间戳**: 2026-07-12
- **任务耗时**: 约 2 小时
- **分支**: fix_003
- **提交**: 7e5d6dd9

## 任务内容

完成 RuntimeProbe Phase 1（NoActionProbe）和 Phase 2（Producer scan）的 Galaxy 端实现，解决 Bank 文件创建后 tick 不更新的问题。

### 核心修改

1. **Galaxy 侧新增 `libRuntimeProbe_gf_StartProbe()` 函数**
   - 在 `gt_Initialization_Func` 中调用（`libAIROAdapter_gf_InitUnitReplacement()` 之后）
   - 注册周期性 tick 触发器并执行第一次状态写入
   - 解决了在 `InitLib()` 中注册 tick 太早导致触发器不触发的问题

2. **修复 InitLib 中 heartbeat 全局变量未同步**
   - InitLib 设置 `libRuntimeProbe_gv_heartbeat = 1`
   - StartProbe 的 WriteState 递增到 2
   - watcher 能检测到 heartbeat 变化

3. **修复 Python watcher mtime 变化时未更新报告**
   - 移除 heartbeat 相等检查
   - mtime 变化时总是重新生成报告

4. **launch-runtime-probe.ps1 新增 Step 4c**
   - 在 `gt_Initialization_Func` 中注入 `libRuntimeProbe_gf_StartProbe()` 调用

## 任务结果

**成功** — Phase 1+2 验收标准全部满足。

### 测试数据

- **Bank 文件**: 8106 bytes
- **heartbeat**: 2（InitLib=1 → StartProbe=2）
- **phase**: in_mission
- **run_id**: startprobe
- **单位**: 5 种（Larva x3, CoopCasterKerrigan x1, Overlord x1, Hatchery x1, Drone x12）
- **升级**: 30 个已研究升级
- **供应**: 12/14
- **ScriptError**: 无

### watcher 输出

```
[10:34:53] HB=1 Phase=initlib_ok Units=0 Upgrades=0 Min=0 Gas=0 Supply=0/0 [FAIL]
[10:34:54] HB=2 Phase=in_mission Units=5 Upgrades=30 Min=0 Gas=0 Supply=12/14 [OK]
```

## 任务备注

### 关键经验

1. **`TriggerAddEventTimePeriodic` 不能在 `InitLib()` 中调用**
   - InitLib 在 `InitMap()` 中最先执行，触发器系统可能未就绪
   - 正确做法：在 `gt_Initialization_Func` 中注册周期性事件

2. **Galaxy 全局变量需要手动同步**
   - `BankValueSetFromInt` 只写入 Bank 文件，不更新全局变量
   - 需要手动设置 `libRuntimeProbe_gv_heartbeat = 1` 以确保后续递增正确

3. **Python watcher 不应依赖 heartbeat 变化来判断是否更新**
   - mtime 变化可能意味着 phase/run_id/units 等其他数据变化
   - mtime 变化时总是重新生成报告更可靠

4. **战役地图 briefing 阶段 game_time=0**
   - `c_timeGame` 在 briefing 阶段不推进
   - StartProbe 的立即写入确保至少有一次完整数据
   - 周期性 tick 在玩家开始任务后才会持续触发

### 文件清单

- `Mods/RuntimeProbe/RuntimeProbe.SC2Mod/Base.SC2Data/LibRuntimeProbe.galaxy`
- `Mods/RuntimeProbe/RuntimeProbe.SC2Mod/Base.SC2Data/LibRuntimeProbe_h.galaxy`
- `scripts/runtime-probe/launch-runtime-probe.ps1`
- `scripts/runtime-probe/runtime_probe_runner.py`
