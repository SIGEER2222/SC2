# RuntimeProbe ClearBankSection 与科技数据解析修复 - 2026-07-12

## 任务类型
SC2 Mod 运行时探测修复 + galaxy 脚本修复 + Python 数据解析修复

## 时间戳
2026-07-12 19:30 - 20:00 (Beijing time)

## 任务内容

用户反馈"确实是替换了，但是科技什么的都还不全"，要求检查面板、基地位置、建筑可生产单位的科技完整性。

### 发现的问题

1. **ClearBankSection 触发器错误（核心 bug）**
   - 现象：ScriptError 日志显示 `libRuntimeProbe_gt_Loop_Func` 在 `libRuntimeProbe_gf_ClearBankSection` line 86 报错 5 次
   - 错误：`无法从''的参数中获取'bank section'(值：)`
   - 原因：逐个 `BankKeyRemove` 在某些 key 上会导致触发器错误，使 Loop_Func 的 BankSave 失败
   - 后果：heartbeat 停在 2，Bank 数据停留在 StartProbe 首次扫描（虫族未清理时的状态）

2. **normalize_probe.py 数据解析缺失**
   - 现象：latest-report.json 中 `probe_producers: []` 为空数组，`probe_tech` 未出现
   - 原因：`build_verification_report` 硬编码 `probe_producers: []`，未解析 Bank 中的 probe_producers 和 probe_tech section

3. **ScanProducers 检测错误能力**
   - 现象：BarracksRaynorX 的 trainable 为空
   - 原因：ScanProducers 对 BarracksRaynorX 和 Barracks 都检测原版 `BarracksTrain`，但 RaynorApplyTechFilter 已屏蔽原版能力
   - 正确做法：BarracksRaynorX 应检测 `BarracksTrainRaynorX`

### 修复内容

#### 1. LibRuntimeProbe.galaxy - ClearBankSection 修复
```galaxy
// 旧：逐个 BankKeyRemove（导致触发器错误）
while (lv_count > 0) {
    lv_keyName = BankKeyName(libRuntimeProbe_gv_bank, lp_section, lv_count);
    if (lv_keyName != "") {
        BankKeyRemove(libRuntimeProbe_gv_bank, lp_section, lv_keyName);
    }
    lv_count = BankKeyCount(libRuntimeProbe_gv_bank, lp_section);
}

// 新：原子删除
BankSectionRemove(libRuntimeProbe_gv_bank, lp_section);
```

#### 2. LibRuntimeProbe.galaxy - ScanProducers BarracksRaynorX 修复
```galaxy
// 旧：BarracksRaynorX 和 Barracks 都检测 BarracksTrain
else if ((libRuntimeProbe_gv_producerTypes[lv_j] == "BarracksRaynorX") ||
         (libRuntimeProbe_gv_producerTypes[lv_j] == "Barracks")) {
    lv_abil = "BarracksTrain";
    ...
}

// 新：BarracksRaynorX 检测 BarracksTrainRaynorX
else if (libRuntimeProbe_gv_producerTypes[lv_j] == "BarracksRaynorX") {
    lv_abil = "BarracksTrainRaynorX";
    ...
}
else if (libRuntimeProbe_gv_producerTypes[lv_j] == "Barracks") {
    lv_abil = "BarracksTrain";  // 原版，已被 TechFilter 屏蔽，trainable 预期为空
    ...
}
```

#### 3. bank_io.py - 新增 parse_producer_value 函数
解析 `producer_count:1,trainable:BarracksTrainRaynor:0,blocked:,queue:,last_order:None` 格式，处理 trainable 字段中的冒号分隔。

#### 4. normalize_probe.py - 新增 probe_producers 和 probe_tech 解析
- `normalize_probe_producers`: 解析 `p_<player>_<unit_type>` key
- `normalize_probe_tech`: 解析 `a_<abil>_<cmdIdx>` (能力可用性) 和 `up_<upgrade>` (升级完成数量)
- `build_verification_report`: 集成新解析函数，添加 probe_replacement
- `report_to_markdown`: 添加 Probe Replacement、Probe Producers、Probe Tech section

## 任务结果

### 验证证据

**第一次测试（修复前）**：
- heartbeat 停在 2，game_time=0
- probe_replacement: FAILED_ZERG_RESIDUAL (zerg=32, terran=19)
- probe_producers 报告为空（Bank 有 12 条目但未解析）
- ScriptError: ClearBankSection line 86 报错 5 次

**第二次测试（ClearBankSection 修复后）**：
- heartbeat 2→28 正常递增
- HB=3 起虫族清理完成 (zerg=0, terran=20)
- probe_replacement: SUCCESS
- 但 BarracksRaynorX trainable 仍为空

**第三次测试（ScanProducers 修复后）**：
- heartbeat 2→29 正常递增
- probe_replacement: SUCCESS (zerg=0, terran=20)
- BarracksRaynorX: trainable=BarracksTrainRaynorX:0 ✓
- BarracksRaynor: trainable=BarracksTrainRaynor:0 ✓
- CommandCenterRaynor: trainable=CommandCenterTrainRaynor:0 ✓
- 107 abilities, 0 blocked ✓
- 5 个未研究升级（HiSecAutoTracking, NeosteelFrame, 武器/护甲等级1）— 正常，需玩家手动研究

### 单位清单（最终）
8 种单位类型：
- Barracks x1（原版，TechFilter 屏蔽原版单位）
- BarracksRaynor x1（生产 MarineRaynor）
- BarracksRaynorX x1（生产 MarineRaynorX，需 TechLab 才能生产 Marauder/Medic/Firebat）
- CommandCenterRaynor x1（升级为 OrbitalCommandRaynor）
- CoopCasterRaynor x2（施法单位）
- MarineRaynor x1
- RaynorCommando x1
- SCVRaynor x12

### 科技结论
- **107 个关键能力全部可用，0 个被屏蔽** — 科技过滤完全正常
- **5 个升级未研究**是正常的，需要玩家手动研究
- trainable 只显示 cmd 0 是因为 BarracksRaynorX 没有 TechLab 附件，MarauderRaynorX/MedicRaynorX/FirebatRaynorX 需要 TechLab — 正常游戏机制

## 任务耗时
约 30 分钟

## 任务备注
- commit: `2a235932` 推送到 `origin/fix_003`
- 3 files changed, 805 insertions(+), 4 deletions(-)
- galaxy-checker 验证：0 错误, 0 警告
- ScriptError 仅剩非致命的战役图触发器警告（CatalogFieldValueModify 参数越界、PointWithOffsetPolar 等），与本次修复无关
- AlertError 有 EvolveToBrutaliskRoachVile 缺失训练信息，是 Reborn 地图自带的虫族进化路径问题，不影响 Raynor 指挥官
