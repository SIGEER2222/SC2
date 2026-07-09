# 海克斯天赋独立 Mod（HexTalents.SC2Mod）接入说明

**日期**：2026-07-08
**Mod 路径**：`Mods/7vs1/HexTalents.SC2Mod`
**数据源**：`解包数据/海克斯合作PVP0.110.SC2Mod`（LibKPVP 天赋逻辑 + GameData 移植）
**定位**：依赖指挥官体系（StarCoop + BaseCatalogPatch/CommanderUnits 层）的高层独立天赋 mod，可被任意 7vs1 地图挂载。**未修改** launch-7vs1-coop-test.ps1、CoreRuntime、CoopZeroPop、CommanderUnits_* 的任何现有文件。

## 一、Mod 结构

```
Mods/7vs1/HexTalents.SC2Mod/
├── DocumentInfo                    # ExtensionMod；依赖 VoidMulti + StarCoop + BaseCatalogPatch
├── DocumentHeader                  # 复制自 ExternalRefs.SC2Mod（依赖表：VoidMulti + StarCoop）
├── ComponentList.SC2Components
├── DocumentInfo.version / GameData.version / GameText.version
├── Base.SC2Data/
│   ├── LibHXT_h.galaxy             # 声明头（前缀 libHXT_，与 libE0EAE146_ 不冲突）
│   ├── LibHXT.galaxy               # 运行时实现（init 入口 libHXT_InitLib / libHXT_InitHexTalents）
│   └── GameData/
│       ├── GameData.xml            # 空 Catalog（目录内 *_HexTalents.xml 由引擎自动加载，同 ExternalRefs 模式）
│       ├── BehaviorData_HexTalents.xml   # TNX_Ability_total（核心 buff）、TNX_missingdummy（缩小立场闪避）
│       ├── UpgradeData_HexTalents.xml    # 27 个通用 TNX 升级 + 15 个指挥官天赋升级
│       ├── EffectData_HexTalents.xml     # KerriganSuicideNukeSet（坑道虫核爆）
│       ├── UnitData_HexTalents.xml       # TNX_MULEParty（矿骡派对奖励矿骡）
│       ├── AbilData_HexTalents.xml       # MULEGather4（矿骡采集，可采矿+采气）
│       └── ActorData_HexTalents.xml      # TNX_MULEParty 外观（复用标准 MULE 模型）
├── enUS.SC2Data/LocalizedData/GameStrings.txt
└── zhCN.SC2Data/LocalizedData/GameStrings.txt
```

## 二、Bank 协议（与天赋系统重设计规格一致）

Bank 文件：`CampaignXCore.SC2Bank`（`scripts/sc2/campaignxcore-bank.ps1` 已支持写入）。

| Section | 键 | 含义 |
|---------|----|------|
| `XMRuntimeControl` | `CommanderP<n>` / `PrimaryCommander` | 玩家 n 的指挥官短名（Raynor/Kerrigan/...），mod 自行解析为运行时名 |
| `CommanderTalents` | `_Common.<TalentId>=<v>` | 通用海克斯天赋（对所有玩家生效） |
| `CommanderTalents` | `<CommanderRuntimeName>.<TalentId>=<v>` | 指挥官专属海克斯天赋（也可作为单玩家的通用天赋键） |

开关型天赋 v=1；可叠加天赋（`HexTalent_ShrinkField`、`HexNovaAirlift`、`HexKerriganCheapNydus`、`HexKaraxFreeChrono`、`HexVorazunCharge`、`HexZeratulLegions`、`HexStukovTimedLife`）v=层数，运行时会按各自上限截断。

写入示例（TalentSelectionsFile JSON，经 `-TalentSelectionsFile` 传给启动脚本）：

```json
{
  "_Common": { "HexTalent_HealthBonus": 1, "HexTalent_ShrinkField": 3 },
  "TerranRaynor": { "HexRaynorInfantryArmor": 1, "HexRaynorTankAntiAir": 1 }
}
```

## 三、地图接入方式

引擎侧共 3 步（均为地图/接线侧改动，本 mod 自身零耦合）：

1. **声明依赖**：在地图 `DocumentInfo` 的 `<Dependencies>` 中追加
   `<Value>file:Mods/7vs1/HexTalents.SC2Mod</Value>`
   （必须排在 CoopZeroPop / BaseCatalogPatch / CommanderUnits_* 之后，保证专属天赋引用的指挥官数据已加载。）
2. **引入脚本**：地图 `MapScript.galaxy` 顶部 include 区追加：

   ```galaxy
   include "LibHXT"
   ```

3. **调用入口**：地图 `InitLibs()`（或任意 map init 时机、指挥官初始化完成之后）追加：

   ```galaxy
   libHXT_InitLib();
   ```

   入口有重入保护（`libHXT_gv_initialized`），重复调用无副作用。init 时会：
   - 从 Bank 解析每个活跃人类玩家的指挥官；
   - 应用通用天赋（TechTree 升级 / 矿骡生成 / 施法范围 / 缩小立场）；
   - 应用该指挥官的专属天赋（CatalogReferenceModify / TechTree 调用）；
   - 注册"单位创建"触发器，给新单位挂 `TNX_Ability_total`（及缩小立场 buff、施法范围补丁），并对场上已有单位补挂一次。

## 四、launch-7vs1-coop-test.ps1 待接线清单（勿由本任务修改，供另一 agent 合并）

1. **依赖注入**：在 `Get-SplitCatalogModDependencies` 列表末尾追加
   `"file:Mods/7vs1/HexTalents.SC2Mod"`（脚本会自动完成 workspace→SC2 安装目录的拷贝与地图 DocumentInfo 注入）。
2. **galaxy 注入**：`Sync-LiveMapRuntimeLibraries` 的 `RuntimeBaseRoots` 数组追加
   `Mods/7vs1/HexTalents.SC2Mod/Base.SC2Data`（现在只扫 CoopZeroPop、CommanderUnits_*、kit_mutations，不会带上 LibHXT*.galaxy）。
3. **MapScript 接线**：按第三节给地图脚本加 `include "LibHXT"` + `libHXT_InitLib()`（如项目已有向 MapScript 注入 include 的机制，走该机制）。
4. **CoopZeroPop 去重**（挂载本 mod 后执行，避免双份数据/双次应用）：
   - 删除 `CoopZeroPop.SC2Mod/Base.SC2Data/GameData/UpgradeData.xml` 中"海克斯天赋 HexTalents"区块（TNX_00~TNX_002 共 24 条）与 `BehaviorData.xml` 中 `TNX_Ability_total` 区块；
   - 删除 `LibE0EAE146_HexTalents.galaxy` 及 `LibE0EAE146.galaxy` 中对它的 include 与 `libE0EAE146_hexTalents_InitVariables()/InitTriggers()` 调用（旧 StartTalentMask 掩码机制由本 mod 的 `CommanderTalents` Bank 键替代）；CoreRuntime 同名副本同理。
   - 过渡期两边并存是安全的：同 id 数据按 mod 加载顺序合并；旧掩码不写 `StartTalentMask` 时旧逻辑不生效；`TNX_Ability_total` buff 挂载有 `UnitBehaviorCount` 判重。
   - 注意：CoopZeroPop 旧副本中 `TNX_00` 的数值是 1（+100%），源 mod 与本 mod 均为 0.15（+15%）。若本 mod 加载序在 CoopZeroPop 之后则以 0.15 为准；去重后自然消除。
5. **webui**：`web-launcher` 的天赋面板可直接读 `Shared/Talents/_Common.json`（本次已按规格 §5.2 填充 31 个通用天赋，`type=common`），指挥官专属海克斯天赋后续可按需并入 `Shared/Talents/<Commander>.json`（id 均以 `Hex` 前缀，与 prestige/mastery 节点不冲突，`build-talent-catalog.ps1` 显式跳过 `_Common.json`，不会重复生成）。

## 五、天赋清单

### 通用天赋（31 个；Bank 键 `_Common.<TalentId>`）

| TalentId | 名称 | 稀有度 | 实现 |
|---|---|---|---|
| HexTalent_MuleParty | 矿骡派对 | 白 | 生成 6 只 TNX_MULEParty + TNX_MULEParty_Mine |
| HexTalent_HealthBonus | 强健体魄 | 白 | TNX_012 |
| HexTalent_MoveSpeedBonus | 飞毛腿 | 白 | TNX_01 |
| HexTalent_DamageBonus | 锋利 | 白 | TNX_00 |
| HexTalent_ArmorBonus | 龟壳 | 白 | TNX_013 |
| HexTalent_EnergyBonus | 能量水晶 | 白 | TNX_014 |
| HexTalent_LifeLeech | 蚊子嘴 | 白 | TNX_015 |
| HexTalent_AttackSpeedBonus1 | 慢脚 | 白 | TNX_016 |
| HexTalent_EnergyRegen | 小充电宝 | 白 | TNX_017 |
| HexTalent_StructureDamage | 拆迁狂 | 白 | TNX_018 |
| HexTalent_SightRangeBonus | 瞄准镜 | 白 | TNX_019 |
| HexTalent_RegenBonus | 恢复力 | 白 | TNX_0110 |
| HexTalent_SpellRange1 | 巫术手杖 | 白 | galaxy 施法范围 +1 |
| HexTalent_WeaponRangeBonus | 狙击镜 | 蓝 | TNX_0111 |
| HexTalent_NoArmorType | 裸衣 | 蓝 | TNX_0112 |
| HexTalent_SpellDamageLeech | 灵能汲取 | 蓝 | TNX_0113 |
| HexTalent_Berserker | 狂战士 | 蓝 | TNX_0114 |
| HexTalent_Detector | 灵能侦测器 | 蓝 | TNX_0115 |
| HexTalent_AstralBody | 星界躯体 | 蓝 | TNX_0116 |
| HexTalent_StrongRegen | 强效恢复 | 蓝 | TNX_0117 |
| HexTalent_GlassCannon | 玻璃大炮 | 蓝 | TNX_0118 |
| HexTalent_SpellRange2 | 聚能器 | 蓝 | galaxy 施法范围 +2 |
| HexTalent_EnergyRegen2 | 充电宝 | 蓝 | TNX_0172（本次新增移植） |
| HexTalent_CooldownSpeed | 思维加速 | 蓝 | TNX_01622（本次新增移植） |
| HexTalent_LifeFountain | 生命源泉 | 红 | TNX_0119 |
| HexTalent_Heroic | 英雄史诗 | 红 | TNX_01122 |
| HexTalent_Telescope | 天文望远镜 | 红 | TNX_01112 |
| HexTalent_BladesOfTheDestroyer | 破军之刃 | 红 | TNX_002 |
| HexTalent_QuickShooter | 快枪手 | 红 | TNX_0162 |
| HexTalent_SpellRange4 | 灵能矩阵 | 红 | galaxy 施法范围 +4 |
| HexTalent_ShrinkField | 缩小立场 | 红 | galaxy（TNX_missingdummy 闪避 + UnitSetScale，最多 3 层） |

未移植：质变：稀有 / 质变：传说 / 质变：混沌（随机抽取型元天赋，属于选择期逻辑，应由 webui 在写 Bank 时随机展开为具体天赋）。

### 指挥官专属天赋（43 个；Bank 键 `<CommanderRuntimeName>.<TalentId>`）

| 指挥官 | 已移植 TalentId（名称） | 未移植（见第六节） |
|---|---|---|
| TerranRaynor | HexRaynorInfantryArmor(枪兵滚毒爆) / HexRaynorCheapBio(好兄弟无穷无尽) / HexRaynorBuilders(SCV升级) / HexRaynorSolarPunch(太阳拳) / HexRaynorTankAntiAir(城市化拼图) | 牛牛出击、城市化基石 |
| TerranSwann | HexSwannCyclone(飙车流) / HexSwannFortressAntiAir(要塞能对空) / HexSwannDrill(1470亿瓦) | 多重钻机 |
| TerranNova | HexNovaNukeReady(核弹骑脸) / HexNovaMarineLight(枪兵甩狗) / HexNovaTankArmored(隔山打牛) / HexNovaAirlift(快速空运,≤3层) / HexNovaMassProduction(超级量产化) | — |
| TerranHorner | HexHornerCheapMercs(佣兵头头) / HexHornerTurretGround(高炮放平) / HexHornerHappyShips(泰伦快乐船) / HexHornerReaperAntiAir(收割者小宝贝) / HexHornerMassFleet(量产型帝国舰队) | 零点轰炸 |
| TerranTychus | HexTychusMoreOutlaws(人多力量大) | — |
| TerranMengsk | HexMengskMechs(机械教) / HexMengskBunkers(地堡阵) | 帝国禁军 |
| ZergKerrigan | HexKerriganChainDamage(就是干) / HexKerriganCheapNydus(怂,≤4层) / HexKerriganNydusNuke(坑道虫爆爆乐) | — |
| ZergZagara | HexZagaraFastDrop(滚滚红尘+1) / HexZagaraFrenzySpeed(声东击西) / HexZagaraFreeBanelings(滚滚红尘) | 智能喷射体 |
| ZergAbathur | HexAbathurMend(奶) / HexAbathurLeviathan(色) | 终极宿主、爆裂孢子、究极进化 |
| ZergStukov | HexStukovCivilians(草船借箭) / HexStukovBanshee(隐形女妖屠龙) / HexStukovTimedLife(末日维护者) | — |
| ZergDehaka | HexDehakaTougher(正面更硬了) / HexDehakaStronger(进攻更强了) | 认知障碍、超级吞噬 |
| ZergStetmann | HexStetmannCheapSatellite(卫星点灯) / HexStetmannBanelingLord(爆虫领主) / HexStetmannInfiniteGary(艾无限) | — |
| ProtossArtanis | HexArtanisImmortalDad(不朽爸爸) / HexArtanisCheapStorm(电中做自己) / HexArtanisGuardianShell(春哥盾) | 阿塔尼斯下船、至高荣耀、太阳轰炸引导员 |
| ProtossAlarak | HexAlarakTough(B格第一人) / HexAlarakMechs(机械供奉) / HexAlarakWave(化骨绵掌) / HexAlarakUltimateFear(终极恐惧) / HexAlarakEndlessNut(停不下来的坚果) | 榨取力量、主教庇佑 |
| ProtossKarax | HexKaraxColossusAir(巨像能对空) / HexKaraxFreeChrono(随心所欲,≤4层) | 超载电池 |
| ProtossFenix | HexFenixMelee(近战增强) / HexFenixDragoon(远程增强) / HexFenixArbiter(法术增强) | 量产菲尼克斯 |
| ProtossVorazun | HexVorazunCharge(万叉奔腾,≤2层) | 死亡漩涡 |
| ProtossZeratul | HexZeratulLegions(传奇军团,≤2层) | 深度考古研究 |

## 六、未移植天赋与原因（后续批次候选）

以下 17 个天赋依赖源 mod 的大块自定义数据链（新单位/技能/效果开关/专用触发器），一次性硬搬会引入较大回归风险，本批次未移植；每项括号内为源数据入口（`解包数据/海克斯合作PVP0.110.SC2Mod`）：

- 雷诺-牛牛出击（TaurenSpaceMarine 单位 + BarracksTrain Train7 槽位补丁）、城市化基石（TNX_BunkerTransport / HeavyCommanderCenterTransport 自定义装载技能链）
- 斯旺-多重钻机（TNX_MultiDrakken + SCV 建造钻机的单位/技能/触发器）
- 霍纳-零点轰炸（HornerAllFire + IsHornerTalentHave 验证器 + HornerBombInvulnerable 行为 + HHBomberAreaBombSearchAreaSwitch 效果链）
- 蒙斯克-帝国禁军（tnx_buylevel 技能 + 4/5 级军阶数据 + UI Layout）
- 扎加拉-智能喷射体（SmartBileLauncherZagaraBombardment 自定义武器链）
- 阿巴瑟-终极宿主（TalentAbathurSuZhu + 蝗虫 AOE/特种蟑螂链 + 需求树）、爆裂孢子（TNXGuardianMPWeaponDamageAoE 效果）、究极进化（生物质拾取/技能链）
- 德哈卡-认知障碍（DehakaCognitiveimpairment 标记 + 属性判定触发逻辑）、超级吞噬（吞噬快照触发器 + TNX_DehakaSuperConsumAddition）
- 阿塔尼斯-下船（TalentArtanisComing + 英雄单位召唤触发）、至高荣耀（TalentGoldenBeetle + 金甲虫弹射狂热者触发）、太阳轰炸引导员（TalentArtanisUnitHorner + ArtanisUnitsDeath 效果事件触发）
- 阿拉纳克-榨取力量（依赖源 mod 内部"供奉我力量系数"全局变量体系）、主教庇佑（ArtanisProtectU 行为补丁 + AlarakSupplicantDevotionCDR_ExtraTalent 效果 + 验证器/需求链）
- 凯拉克斯-超载电池（TNX_KaraxProtossUrbanization 引用 ShieldBatteryRechargeEx5，该效果在 StarCoop 标准数据中不存在，需一并移植）
- 菲尼克斯-量产菲尼克斯（massproductfenix + Gateway/Stargate/RoboticsFacility 训练槽补丁 + 能量体系触发）
- 沃拉尊-死亡漩涡（TNX_VorazunDeathWhirlpool 行为/效果链 + 黑洞挂 buff 触发）
- 泽拉图-深度考古研究（神器碎片拾取计数触发体系）

## 七、已知差异与说明

- **随机/抽取机制**：源 mod 是"升级时三选一抽取"，本项目按重设计规格改为 webui 预选 + Bank 直读，天赋即选即生效。
- **量产型帝国舰队**：升级只影响生产充能与价格；源 mod 中对"已在冷却中的星港"即时刷新充能的 `libKMIS_gf_CM_ModifyCooldown` 调用未移植（仅影响选天赋瞬间已存在的冷却）。
- **超级量产化（诺娃）**：同上，未移植 `CM_Nova_IterateExistingBuildings` 对已建成建筑的即时充能刷新；P1 威望互斥折扣分支已完整移植。
- **缩小立场**：闪避按源 mod 公式（每层将"未闪避概率"×0.9，即 1-0.9^层）实现于 `TNX_missingdummy` 的 DamageResponse.Chance；体积用 `UnitSetScale`（模型缩放），未移植源 mod 的碰撞半径缩减（TNX_missingdummy2.RadiusMultiplier）。
- **英雄史诗减伤**：需要 `TNX_Ability_total` 带 `DamageResponse(Chance=1)`。本 mod 的 BehaviorData 已补上（CoopZeroPop 旧副本缺失该节点，两 mod 合并后生效）。
- **锋利数值**：CoopZeroPop 旧副本 TNX_00=+100% 疑为笔误，本 mod 按源 mod 恢复为 +15%。
- **要塞能对空/巨像能对空**：源 mod 走"解锁研究按钮"（EngineeringBayResearch/RoboticsBayResearch 自定义研究槽），本 mod 简化为选中天赋直接应用对应升级（免费、即时），研究入口按钮未移植。
- **通用天赋作用对象**：`_Common.<id>` 键对所有活跃人类玩家生效；如需只给单个玩家，可写 `<CommanderRuntimeName>.<id>`（仅当该玩家使用该指挥官时生效）。

## 八、验证

- `galaxy-checker`（`npx tsx src/cli.ts "…\HexTalents.SC2Mod\Base.SC2Data" --format text`）：**0 错误 / 0 警告**（LibHXT.galaxy + LibHXT_h.galaxy 整目录全局符号检查）。
- 全部 XML 通过 .NET XmlDocument 解析；`_Common.json` 通过 JSON 解析。
- 所有新建文本文件均为 UTF-8 无 BOM（与项目现有 galaxy/XML 一致，避免库初始化失败）。
- 未进行游戏内实测（本任务约束不动 launch 脚本/地图接线；接线后建议按第三、四节挂载并用 `wait-for-game-ready.ps1` 验证）。
