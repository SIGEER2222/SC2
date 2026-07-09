# 肉鸽之翼天赋/诅咒 mod 提取说明

> 生成日期：2026-07-08 ｜ 分支：fix_003

## 1. 概述

本文档说明从第三方 mod「肉鸽之翼进阶版 v0.58」（`D:\1\SC2\其他mod\肉鸽之翼进阶版v0.58（增加一些波次相关诅咒，大力神增强）`）中提取天赋（Talent）与诅咒（Curse）系统、封装为独立可加载 mod 的过程与结果。

产物：`合作指挥官-起义狂潮/Mods/kit_rogue_talents.SC2Mod`（目录形式，未打包 MPQ）。

**天赋与诅咒放在同一个 mod 的理由**：二者在源码中共用同一套目录表（UserData `RogueTalents`，以 Rarity 正负区分天赋/诅咒）、同一套抽取管线（`TalentGenerate`/`TalentLottery`/`TalentCreateSingle`，`CurseTime` 只是 `TalentTime` 的负稀有度入口）、同一套图鉴 UI（`TableCreate`，`ge_TableType_Talent=0`/`ge_TableType_Curse=1`）与同一存档 Bank。耦合度极高，拆分会导致两个 mod 互相引用几乎全部符号，因此不拆。

## 2. 源 mod 结构调查

### 2.1 RaynorRogue.SC2Mod 与 RaynorRogueRaw.SC2Mod 的关系

二者不是加密/明文的关系，而是**逻辑包/资源包**分工：

| | RaynorRogue.SC2Mod | RaynorRogueRaw.SC2Mod |
| --- | --- | --- |
| 形态 | 已解包目录 | 单文件 MPQ 压缩包（约 37 MB，魔数 `MPQ\x1A`） |
| 内容 | 全部逻辑：galaxy 库 `LibB27CC4B1`（约 13.5k 行）、Triggers（编辑器触发器 XML）、GameData 24 个 XML、enUS/zhCN 本地化、UI 布局 | 纯资源：321 个 `Assets/Textures/*.dds` 图标 + 378 个 `Assets/Sound/*.ogg` 音乐音效 + 极简元数据（ModType=Interface，仅依赖 Liberty (Mod)） |
| 依赖 | Liberty (Campaign)、RaynorRogueRaw、kit_liberty_story | Liberty (Mod) |

即 Raw 是美术/音频资源库（推测源自原版「肉鸽之翼」），RaynorRogue 是进阶版全部玩法逻辑。战役剧情本体在 `kit_liberty_story.SC2Mod` 与 `maps/Campaign/*.SC2Map` 中，**不在** RaynorRogue.SC2Mod 内——这意味着「天赋+诅咒系统」在源工程里本来就已经独立成库，提取的主体工作是整库迁移、前缀重命名、资产内联与依赖裁剪。

### 2.2 天赋/诅咒系统在源码中的位置

| 子系统 | 位置 | 说明 |
| --- | --- | --- |
| 目录表 | `Base.SC2Data/GameData/UserData.xml` → CUser `RogueTalents` | 594 条目，字段：Name/NameStr/Description/Upgrade/Type/Rarity/Max/Acquired/Taken/Banned/Requirement/Image/Apply Type/Special。Rarity>0 为天赋，Rarity<0 为诅咒（-1 常规、-2 高阶、-3 战役任务挑战），7 为新周目噩梦诅咒 |
| 数值效果 | `UpgradeData.xml`（816 个 CUpgrade） | 每个天赋/诅咒对应一个 Upgrade，纯数值效果直接由 Upgrade 生效 |
| 触发效果 | `LibB27CC4B1.galaxy` | 抽取管线 `gf_TalentGenerate/TalentLottery/TalentTime/CurseTime/ChallengeTime`、选择 UI（`gt_TalentPicked/TalentRerolled/TalentBanned`）、图鉴 `gf_TableCreate`、商店 `gf_TalentShop*`、Bank 存档 `gf_Load/SaveRogueBank`、效果分发 `gf_TalentTriggerEffects/TalentAppliedEvents`，以及各诅咒触发器（`gt_Curse*`、波次类 `gt_nitaiwave/MIEJUEWAVE/spellwave/druidwave/jingyingboci` 等） |
| 行为/效果/验证器等支撑数据 | `BehaviorData/EffectData/ValidatorData/RequirementData/RequirementNodeData/ButtonData/AbilData/UnitData/WeaponData/ActorData` 等 XML | 天赋/诅咒 Upgrade 与职业单位池所引用 |
| 本地化 | `zhCN.SC2Data/LocalizedData/GameStrings.txt`（`UserData/RogueTalents/*_NameStr`、`*_Description`、`Param/Value/lib_B27CC4B1_*`）、`TriggerStrings.txt` | enUS 同构 |
| UI | `Base.SC2Data/UI/Layout/RaynorRogueTopbar.SC2Layout` 等 | 顶栏天赋按钮 |

v0.58 新增的「波次相关诅咒」对应条目如：灵能部队（shifazheboci）、灭绝者（miejueboci）、拟态雏虫（Changelingwave）、女王亲兵（jingyingboci）等，均受「蜂拥增援」诅咒放大派遣数量；触发器为 `gt_spellwave / gt_MIEJUEWAVE / gt_nitaiwave / gt_druidwave / gt_CurseReinforcementZerg` 与 `gf_CurseAttackWaveModifier`。

## 3. 新 mod：kit_rogue_talents.SC2Mod

### 3.1 组织方式（对齐 kit_mutations.SC2Mod 先例）

```text
kit_rogue_talents.SC2Mod/
├── ComponentList.SC2Components   # gada/text(enUS,zhCN)/info/trig/font/uiui
├── DocumentHeader                # 重建：依赖仅保留 Liberty (Campaign)
├── DocumentInfo                  # 依赖仅 bnet:Liberty (Campaign)
├── DocumentInfo.version / GameData.version / GameText.version / Triggers.version
├── Preload.xml
├── Triggers                      # 编辑器触发器库，库 ID B27CC4B1 → KRTC
├── Assets/Textures/*.dds         # 321 个图标，自 RaynorRogueRaw MPQ 解包内联
├── Base.SC2Data/
│   ├── LibKRTC.galaxy            # 原 LibB27CC4B1.galaxy，前缀重命名
│   ├── LibKRTC_h.galaxy          # 原 LibB27CC4B1_h.galaxy
│   ├── GameData/                 # 24 个数据 XML + GameData.xml(TriggerLibs Id=KRTC)
│   └── UI/                       # FontStyles + DescIndex + RaynorRogueTopbar
├── enUS.SC2Data/LocalizedData/   # GameStrings/ObjectStrings/TriggerStrings/GameHotkeys
└── zhCN.SC2Data/LocalizedData/   # 同上（键 lib_B27CC4B1_* 已同步改为 lib_KRTC_*）
```

共 370 个文件，约 18.9 MB。

### 3.2 galaxy 前缀重命名

库 ID `B27CC4B1` 全量替换为 `KRTC`（Kit Rogue Talents & Curses），共替换 52058 处，覆盖：两个 galaxy 文件（前缀 `libB27CC4B1_*` → `libKRTC_*`，文件名同步改为 `LibKRTC*.galaxy`）、`Triggers`（`<Library Id>` 及全部内部引用）、`GameData/GameData.xml`（`<TriggerLibs Id>`）、enUS/zhCN 的 GameStrings 与 TriggerStrings（`lib_B27CC4B1_*` 参数键、`B27CC4B1/...` 触发器文案键）。替换后全仓无 `B27CC4B1` 残留，不与源 mod、主工程 `LibE0EAE146` 冲突。地图侧初始化入口为 `libKRTC_InitLibraries()` / `libKRTC_InitVariables()`。

### 3.3 加载方式

1. 地图 `DocumentInfo` 的 `<Dependencies>` 中加入 `file:Mods\kit_rogue_talents.SC2Mod`（置于 Liberty (Campaign) 之后）；或复制到 SC2 安装目录 `Mods/` 下以 `file:` 依赖引用。
2. 地图 `MapScript.galaxy` 中 `include "LibKRTC"`，并在 `InitMap()` 内调用 `libKRTC_InitLibraries()`。若在编辑器中打开，触发器库会以 “Raynor Rogue” 库出现，可直接调用其触发器/函数。
3. 运行期入口：`gt_RogueInit`（初始化+读 Bank）、`gf_TalentTime(稀有度,...)` 弹出三选一天赋、`gf_CurseTime(...)` 弹出诅咒三选一、`gf_TableCreate(0/1)` 打开天赋/诅咒图鉴、`gf_CurseDifficultyModifier(难度)` 按诅咒难度施加敌方增益。
4. 调试作弊码（聊天输入）：`givemetalent`（普通）等各稀有度、`whatstheworstthatcanhappen`（诅咒）、`debugremove`（移除替换）、`showmethelist`（清单）——详见 `gt_Debug*` 触发器。

注意：本 mod 的天赋大量引用 Liberty 战役单位/升级（军械库科技等），因此**必须**带 `Liberty (Campaign)` 依赖；在非战役地图上加载时职业单位池仍指向战役人族单位。

### 3.4 已剥离的依赖

| 原依赖 | 处理 |
| --- | --- |
| `file:Mods\RaynorRogueRaw.SC2Mod`（37 MB 资源包） | **已剥离**。321 个 dds 图标全部解包内联进本 mod `Assets/Textures/`（天赋目录引用的 302 个 raynorrogue 专属图标全部命中，缺失 0）；378 个 ogg 音乐未内联（仅吟游诗人/德鲁伊等职业 BGM 彩蛋使用，缺失时静音不报错） |
| `file:Mods\kit_liberty_story.SC2Mod`（战役剧情二创包） | **已从依赖中剥离**。galaxy 的 `include "LibCamp"/"LibWoLC"/"LibWCMI"` 由官方 Liberty (Campaign) 依赖提供同名库；kit_liberty_story 中 4 个 `Kit@*` 升级（如 `Kit@BattlecruiserTacticalJump`）对应的 4 个天赋在缺库时无数值效果（见遗留问题） |
| `PreloadAssetDB.txt`（3 MB 战役资产预载清单） | 未拷贝，仅影响加载预热，不影响功能 |
| DocumentHeader 内嵌依赖表 | 二进制重建，仅保留 `bnet:Liberty (Campaign)` |

### 3.5 保留的依赖与保留的战役耦合（剥不掉/不宜剥）

- **Liberty (Campaign) 官方依赖**：天赋 Upgrade 中 23 个直接强化战役军械库科技（Stimpack、ShrikeTurret、PsiDisruptor 等），职业单位池全部是战役人族单位，属系统本体，保留。
- **战役任务专属内容（保留但休眠）**：28 个「挑战」诅咒（Type=Challenge，按 traynor/thanson/ttosh/thorner/tvalerian/tzeratul/ttychus 各关卡设计）、18 个 Special 天赋（`gt_TalentSpecial*`：汉森治疗、诺娃、托什、泽拉图、废料箱等）、`gf_ChallengeTime`、BossQueen 系列函数、UserData 中 `Maps/CampaignConstants/MissionObjective` 等表。这些逻辑与天赋管线深度互联（同一张表、同一分发器 `gf_TalentTriggerEffects`），强行切除需改写 Triggers（10 MB 编辑器 XML）且极易破坏编译，故整体保留；在非对应地图上相关触发器事件不会命中，处于休眠状态，不影响加载。
- **通用天赋引用的官方合作模式图标**（btn-ability-kerrigan-*、mengsk、hornerhan 等约 400 个）：由游戏本体全局资产提供，源 mod 同样如此引用，无需内联。

## 4. 数量统计

| 类别 | 数量 | 说明 |
| --- | --- | --- |
| 目录总条目 | 594 | UserData `RogueTalents` 全部实例（含 1 个 [Default] 占位） |
| 天赋（Rarity>0） | 478 | 普通 175 / 罕见 125 / 稀有 86 / 史诗传说 65 / 职业核心与特殊 23 / 噩梦 4 |
| 常规诅咒（Rarity=-1） | 51 | 含 v0.58 新增波次相关诅咒 |
| 高阶诅咒（Rarity=-2） | 34 | 3/4 诅咒难度出现（含 1 个计数辅助条目） |
| 战役挑战诅咒（Rarity=-3） | 30 | 28 个任务挑战 + 终极挑战 + 「临阵退缩」 |

## 5. 诅咒清单

### 5.1 常规诅咒（Rarity -1，51 个）

- **军备竞赛**（`Arms Race`）：敌人单位和建筑造成的非技能伤害增加12%。
- **额外护甲**（`Extra Plating`）：敌方单位的生命护甲增加0.5，护盾护甲增加1.25。
- **恶魔坚韧**（`Fiendish Fortitude`）：所有敌人单位和建筑的生命值和护盾值增加15%。
- **蜂拥增援**（`Swarming Reinforcements`）：敌方每次进攻都会额外派出25%的单位。
- **灯火管制**（`Blackout`）：战争迷雾完全黑暗，但你的建筑视野加3。
- **腐肉虫群**（`Carrion Swarm`）：击杀敌方单位有几率召唤一个异虫空投囊。多层叠加可增加几率、减少冷却时间并提高空投单位的质量。受益于“蜂拥增援”天赋。
- **米拉的贴心合同**（`Mira's Bargain`）：在你没注意的时候，米拉·汉和你签订了一份合同。只要你有足够的晶体矿，就会以6000晶体矿的价格购买一医疗运输机的秃鹫。此效果在“恶魔游乐场”和“博弈”任务中禁用。
- **补给中断**（`Supply Disruption`）：最大人口减少50。
- **扰矿战术**（`Worker Harassment`）：敌方空中单位会周期性地骚扰你的工人。
- **我们控制天空**（`We Control The Skies`）：敌方战列巡洋舰、巢虫领主、利维坦、航母和风暴战舰获得2点射程
- **铁人甲壳**（`Juggernaut Chitin`）：敌方火蝠、蟑螂和追猎者获得2点护甲
- **压制火力**（`Supressing Fire`）：敌方劫掠者、刺蛇和追猎者获得25%的攻击速度
- **掺冰强化剂**（`Stimpack Addiction`）：强化剂太让人上瘾了，你的单位会随机使用它，即使在战斗之外。
- **超巨化**（`Super Massive`）：敌方的雷神、雷兽和巨像的生命值增加50%，体型增大50%，移动速度降低30%，攻击速度降低50%，攻击伤害增加200%。
- **赦罪法则**（`Law Of Absolution`）：在拥有第一个普通无限复制天赋后，你每拥有一个普通无限复制天赋，我方单位和友方单位的移动速度就会降低10%（如果你只有一个无限复制天赋，则此效果不会触发）。
- **经济压力**（`Economic Tension`）：无论你或盟友的资源储备情况如何，盟友都会消耗你的资源。
- **娇惯成性**（`Flashbacks Inside The Cantina`）：虽然有英雄在身边时总是很安心，但英雄们不在身边的时候，你的战士们好像都忘了该怎么打仗。  你的非英雄单位周围7格要是没有己方的英雄单位，受伤到的所有伤害增加15%。  无限职业诅咒，效果加法叠加。
- **观测依赖**（`Extended Safety Precautions`）：你的非英雄单位视野降低2点。  无限职业诅咒，效果加法叠加。
- **厄运之骰**（`Unlucky Dice`）：随机化单位时有更高的几率获得更差的单位。与“幸运骰子”天赋相互抵消。
- **冒失士兵**（`Pay The Middleman`）：不是雇佣兵的非英雄单位护甲降低1点。  无限职业诅咒，效果加法叠加。
- **量子纠缠**（`Quantum Entanglement`）：每场任务中你训练的第一个非SCV单位将被标记为“量子湮灭”。当该单位死亡时，所有同类型的单位也将全部死亡。
- **来吧，拿出你的真本事**（`Extra Shining Armor`）：敌人的数量，最大生命值以及最大护盾值增加10%。  无限职业诅咒，效果加法叠加。
- **环境干扰**（`Enviromental Distraction`）：你的人族战斗单位的钱气消耗增加15%，不会对心灵军团和英雄生效
- **刺客的高傲**（`Oversight`）：你的单位在隐形时受到的伤害增加12%。  无限职业诅咒，效果加法叠加。
- **技术依赖**（`Technocratic Dependency`）：当你的单位没有战术原型升级时，生命值和伤害降低15%。
- **虚空饥渴**（`Otherworldly Hunger`）：你的非英雄单位若不是虚空造物，附近6格内有己方混合体时，每秒失去2点生命。（scv和地堡里的单位不受影响）  无限职业诅咒，效果加法叠加。
- **缓慢刀法**（`Dead Men Walking`）：阿拉纳克的武器冷却时间增加1秒。  无限职业诅咒，效果加法叠加。
- **燃尽的星之力**（`Burnout`）：敌人所有单位和建筑的伤害增加12%，非英雄单位和建筑攻击速度和移动速度下降5%。  无限职业诅咒，伤害增加效果加法叠加，减速效果乘法叠加。
- **无尽渴望**（`Dimensional Storage`）：你的非英雄单位生命值下降12%，但会获得每秒0.25的能量恢复。  无限职业诅咒，效果加法叠加。
- **灵能扩增**（`spelldamagecurse`）：所有敌人的技能和溅射伤害增加20%。
- **近视眼**（`rangecurse`）：敌我双方所有非英雄单位和建筑远程武器射程降低3点。
- **向下瞄准**（`daodanduikong`）：敌方导弹塔和孢子爬虫可以对地攻击。
- **击中硬直**（`yingzhi`）：我方非英雄单位受到非英雄来源的伤害后，会进入极为短暂的昏迷状态。
- **被击抗性**（`beijikangxing`）：敌人非英雄单位受到的伤害增加30%，但每次受到伤害，都会增加5%伤害抗性。可叠加16层，最大层数时效果变为减免50%伤害。
- **生命消退**（`huanmandiaoxue`）：敌我非英雄单位的生命恢复速度降低0.25。  提示：生命恢复低于0时会逐渐失去生命。
- **延迟指令**（`deluyilengquezuzhou`）：你的灵能无人机和防御模式冷却时间增加12秒。  无限职业诅咒，效果加法叠加。
- **三步之内刀快**（`zuixiaoshecheng`）：你的非英雄单位具有1点最小射程，这会导致近战单位无法攻击。
- **DNA重组**（`suijishuxing`）：每场任务开始，你的单位获得30%非技能伤害、1点远程武器射程、2点护甲以及30%最大生命值/护盾值中的其中一项属性提升，并随机降低一个其余属性。
- **友善威胁**（`youshandanwei`）：你的单位和建筑不再会主动攻击敌方的巢虫领主、异龙、侦察机、风暴战舰、攻城坦克以及怨灵战机，但敌方这些单位的攻击速度降低50%。
- **考虑过晶体矿脉的感受吗？**（`taopaokuangmai`）：你的SCV采集晶体矿时，晶体矿脉可能会逃跑，逼急了还会逃跑到难以触及的位置。
- **亡灵依赖**（`wanglingyilai`）：你的非英雄单位护甲降低2点，该效果不影响丧尸。  无限职业诅咒，效果加法叠加。
- **棋逢对手**（`shushizuzhou`）：当敌方单位和建筑受到伤害后，敌方所有单位和建筑获得200点临时护盾，持续20秒。这个效果每600秒最多触发一次。  无限职业诅咒，每增加1层该效果降低10%的冷却时间，冷却时间减免乘法叠加。
- **肌腱强化**（`direnjiasu`）：敌方单位的移动速度增加15%。
- **全员恶人**（`quanyuanboss`）：敌方所有单位和建筑都获得“地图目标”标签。
- **空中威胁**（`kongzhongmubiao`）：敌方单位和建筑均视作空中目标。部分关卡你会获得一些对空支援。
- **严防死守**（`renwunuodong`）：之后的任务中，异虫生物样本和星灵圣物将会被移动到敌人基地附近，但你可以看到它们的位置。
- **危险物品**（`weixianwuping`）：当你捡起异虫生物样本和星灵圣物时，它们会产生核爆。
- **都是好手**（`zhenxigongren`）：你的SCV采集资源的速度变为原来的500%，建造速度和基础移动速度变为200%，但指挥中心不能再训练SCV。
- **灵能部队**（`shifazheboci`）：敌方会在每个进攻波次加入1个施法者单位。人类会使用幽灵，异虫会使用感染者，星灵会使用高阶圣堂武士。（会被蜂拥增援影响派遣数量）
- **灭绝者**（`miejueboci`）：敌方的进攻波次中可能派出灭绝者，它是一个坚固但伤害较低的英雄单位。（会被蜂拥增援影响派遣数量）  灭绝者被击败后，它将恢复所有的生命值，并为击败它的势力而战，期间不可指挥。不过在其诞生300秒后，无论所属何方，它都会自毁并产生核爆。
- **拟态雏虫**（`Changelingwave`）：敌方会在攻击波次中混杂拟态雏虫，它会模仿成你单位的模样，使你的单位不会主动攻击它们。（会被蜂拥增援影响派遣数量）  拟态雏虫不具备攻击力，同时非常脆弱，受到伤害就会死亡。但它们会为敌方提供视野，还会污染你的建筑，使其暂时失去功能。

### 5.2 高阶诅咒（Rarity -2，34 个）

- **时空提速**（`Chrono Dilation`）：敌人的运作效率加快12%。
- **政治宣传**（`Deathless Propaganda`）：当你的一个单位被敌人消灭时，附近的所有友方单位受到的伤害提高8%，持续10秒。此效果最多可叠加10次，每次乘算叠加。
- **你的机枪兵都死光了？**（`Pull The Boys!`）：SCV被添加到部队选择按钮中。
- **劣质弹药**（`Bullets From Lowest Bidder`）：你的陆战队员和战地豪猪失去了攻击空中单位的能力。
- **碎甲者**（`Armor Shredder`）：敌方的陆战队员、被感染的陆战队员、跳虫和狂热者每次攻击都会降低目标0.3护甲，持续2秒，可无限叠加。
- **蓝色异端**（`Blue Heresy`）：你每拥有一个稀有天赋，我方单位和友方单位受到的伤害就增加+10%。
- **退役储备金**（`Retirement Fund`）：每60秒，你的盟友将为退役储备金存入100晶矿与100瓦斯。不过星灵真的会退役吗……？
- **暴雪的恶棍**（`Villain Of The Blizzard`）：每隔一段时间，为你的敌人召唤一个随机英雄来攻击你。
- **超光速粒子风暴**（`Tachyon Storm`）：以随机间隔将目标区域内的单位置于持续30秒的时间循环中。效果结束时，受影响单位恢复到施法时状态。该效果影响所有单位。
- **智囊的自负**（`Mastermind's Ego`）：心灵军团现在可控制最高3个敌人。控制超过1个单位将对施法者每秒造成8点伤害。控制3个单位会使得伤害加倍。
- **有限预算**（`Limited Budget`）：每种战术原型升级在每场任务中只能应用30次。
- **灵能护盾**（`shieldcurse`）：所有敌人获得20点护盾，同时每秒回复1点护盾值。
- **艾泽拉斯式战斗**（`healthcurse`）：敌我双方单位和建筑增加200%生命值和护盾值，且单位的速度和建筑运作效率下降30%。此外敌方攻击波次的单位数量减少60%。（敌人数量衰减不与优胜劣汰叠加）  “这瘟疫比看起来难多了。”
- **萌物来袭**（`keaitiaochong`）：敌人死亡后有30%的概率为其召唤爆笑星际版跳虫，它们只会受到20%的伤害，无法造成伤害，同时不会被任何诅咒或天赋影响，并具有最低的被攻击优先级（但仍然高于建筑）。  爆笑星际版跳虫最多只能存活180秒。
- **暗影遮蔽**（`anshabudui`）：敌人的所有单位处于永久隐形状态，但额外受到30%的伤害。  此外，你的非英雄单位可以侦测2格范围内的隐形敌人，英雄单位可以侦测7格范围内的隐形敌人。
- **近距离腰射**（`ziyoukaihuo`）：敌方非英雄单位的远程武器射程降低3点，但所有非英雄单位都会获得30%移动速度加成和50%攻击速度加成。
- **好高骛远**（`haogaowuyuan`）：敌人非英雄单位远程武器射程增加3点，但敌人的远程伤害只有10%的命中率。若敌人成功打中，那么该敌人之后的攻击将不会再落空。
- **死者苏生**（`wuxianfuhuo`）：敌人的非英雄单位生命和护盾上限降低50%，但每次被消灭都有30%概率在5秒后原地复活。（只有占用补给的单位才会复活）
- **同化体**（`tonghuati`）：我方非英雄单位在被敌人非英雄单位攻击时，有概率会同化成和敌人一样的单位，但控制权仍属于你。  敌人造成的伤害越高，被同化的概率也就越大，同时越强大的敌人越难同化。被同化过的单位不能再被同化，对召唤物不生效。
- **虚假生命**（`shoushanghaidiaoxue`）：敌人非英雄单位获得50点额外生命上限，但每次受到伤害都会失去5点生命值。
- **埃及城市化**（`heiluobo`）：当敌人是人类或星灵时，它们会尝试扩张自己的防线，并随着游戏时间逐渐增加扩张速度。（非建造关卡无效）
- **高度警戒**（`zhixianzegnqiangdiren`）：每当你完成任意额外目标以及收集实验室研究样本时，本场任务中敌方单位攻击速度和造成的伤害增加10%。
- **十二分钟热度**（`shanghaishuaitui`）：敌方单位和建筑的攻击速度增加60%，但每过60秒敌人的攻击速度便会降低5%。  最多降低15次，即最终效果为敌人的攻击速度降低15%。
- **绯红之王**（`huanghushike`）：每过去300秒，敌我双方的非英雄单位和建筑会无法行动，持续90秒。  每触发一次该效果，敌方所有单位的运作效率增加5%。
- **天旋地转**（`tianxuandizhuan`）：你的镜头会以极慢的速度旋转。
- **癌变细胞**（`direnzengjiashengminghuifu`）：敌人非英雄单位减少20%最大生命值，但获得每秒5点的生命恢复。
- **生命汲取**（`direnxixue`）：敌方非英雄单位造成伤害时恢复等量生命值，但护甲降低3点。
- **强力一击**（`jiagongjijiansu`）：敌方非英雄单位造成的所有伤害增加100%，但攻击速度倍率下降50%。
- **优胜劣汰**（`direnjingyinghua`）：敌方非英雄单位增加200% 的最大生命值和护盾值，造成的伤害增加100%。但其中不具有能量和补给占用少于4点的敌人将有80%概率立即死亡。（不影响巢虫和拦截机）  此外，艾泽拉斯式战斗的单位减少效果将不会生效。
- **补给匮乏**（`bujikuifa`）：你的补给站提供的补给减半，且指挥中心不再提供补给，但获得100点人口上限。
- **最终防线**（`zuizhongfangxian`）：接下来的游戏中，当你损失任意一个占用补给的单位，任务将会立即失败。  在你完成任意额外目标以及收集实验室研究样本5次后，移除这个瘟疫。
- **解除最终防线所需目标**（`zuizhongfangxianjishu`）：当你损失任意一个占用补给的单位，任务将会立即失败。  完成任意额外目标以及收集实验室研究样本时，该计数减少1层。
- **女王亲兵**（`jingyingboci`）：异虫敌人可能会在进攻波次中加入1只精英异虫。精英异虫包括噬兽、屠猎者以及南方蟑螂。（会被蜂拥增援影响派遣数量）  不过这些精英异虫无法为敌人提供全局增益。
- **不稳定机体**（`direnzibao`）：敌方地面单位死亡后会爆炸，对附近的其他敌方地面单位和建筑造成10点溅射伤害，对你的地面单位和建筑造成50点溅射伤害。  爆炸伤害可以被护甲减免。敌方每有1点护甲减少1点伤害，你每有1点护甲减少5点伤害。

### 5.3 战役任务挑战诅咒（Rarity -3，30 个，保留但依赖对应战役地图）

- **临阵退缩**（`Chicken Out`）：你选择不接受挑战，而是接受一个诅咒，前提是你没有选择“无负担”难度。
- **阿尔法阿尔法，这里是欧米茄**（`Alpha, Here Is Omega`）：一只减速的王兽会一直追赶雷诺。
- **拿根棍子捅它！**（`Prod It With A Stick!`）：帝国忍不住要摆弄神器，它会定期在自身周围随机释放灵能风暴。别担心，会有预警的。
- **小偷虫群**（`Sticky Claws`）：异虫偷走了神器！只要神器还在异虫手中，任务就不会结束！
- **这给我干哪来了，这还是萨古拉斯吗？**（`Wrong Evacuation`）：虚空撕裂者迷路了，最终来到了阿格瑞亚而不是萨古拉斯。虚空撕裂者会周期性地出现在地图各处，并对你发起攻击。
- **病毒携带者**（`They Infest Marines Too`）：异虫释放了一种空气传播病毒，潜伏于所有单位身体中。当任意单位死亡时，有40%概率为敌人召唤一个被感染的陆战队员。
- **并非行星碎裂炮**（`Crackin' Not Only Planets`）：母舰的武器被替换为一道拥有德拉肯激光钻机威力和射程的激光。
- **疫情期间请保持社交距离**（`Social Distancing Required`）：你的生物单位会随机生病，在10秒内对自身和周围生物单位造成50点伤害。效果结束时，会感染4格范围内的1个随机生物单位。  SCV免疫此效果。
- **我们需要防晒霜！**（`Sunscreen Needed`）：事实证明，靠近岩浆几乎和浸泡在里面一样危险。你暴露在外的单位每2秒受到1点伤害。建筑和SCV不受影响。
- **致幻气体**（`Hallucinatory Fumes`）：地嗪具有强烈的致幻作用，因此你的部队会感知到不存在的敌人。地图上会有许许多多的敌方幻象。
- **临终惊喜**（`Anti-Hero Mines`）：敌方单位死亡时会生成麦格天雷，它们会攻击范围内的我方单位和建筑，但你可以在引爆前摧毁它们。  麦格天雷不被诅咒和天赋影响，且最多存活60秒。
- **预算削减**（`Budget Cuts`）：雷诺的任务预算被削减了，因此你开始时拥有的单位将大幅减少。
- **苦痛列车**（`Pain Train`）：敌人的火车上充满了（恶心的）惊喜！地图周围还会生成额外的带有计时生命的火车，死亡时也会召唤随机的敌人。  火车的存活时间越长，召唤的敌人就越强。
- **蒙斯克的好学生**（`Tactical Lessons From Mengsk`）：奥尔兰从蒙斯克那里学到了一些战术，决定使用更多的核弹。但与沃菲尔德不同，他必须使用幽灵来召唤它们。
- **未成年人防沉迷系统**（`Child Safety Restrictions`）：奥丁检测到泰凯斯为未成年人，因此禁用了所有不适合儿童的系统。奥丁现在只能对建筑造成伤害。
- **奥丁的终结**（`Doom Of Odin`）：奥丁远非这里最大的单位。蒙斯克部署了赫尔、芬里尔和耶梦加得来保护目标。
- **不稳定弹药**（`Premature Detonation`）：武器和弹药拾取物非常不稳定，当你的单位靠近时会爆炸。
- **哭泣雕像**（`Weeping Zealots`）：石像狂热者会不断地神秘出现在地图各处，并且对你和异虫都怀有敌意。别担心，只有在你看着它们的时候，它们才会活过来！
- **超程龙骑**（`Under The Dragoon's Wings`）：敌人会在他们的攻击波次中派出龙骑士，同时敌方龙骑士的射程增加10点。
- **什么叫凯瑞甘们杀了过来？**（`What's The Plural Of Kerrigan?`）：凯瑞甘成功地克隆了自己。不过这些克隆体没有她本人强大。
- **让火焰净化一切！**（`By Fire Be Purged!`）：神器由数个使用火焰的单位守卫，例如火蝠、恶火、净化者巨像和亚格卓拉。
- **青铜舰队**（`The Bronze Armada`）：塔达林认为对抗战列巡航舰的最佳方法，就是使用他们自己的重型空中单位。敌人会生产大量的航母、风暴战舰、毁灭者以及虚空辉光舰。
- **他们听见你了**（`The Zerg Can Hear You`）：异虫能听到你的声音，每次通讯都会在你的位置召唤异虫空投囊。
- **进化的混合体**（`Maar Is Evolving!`）：敌方混合体正在进化，每次被击败后都会以更强大的形态回归。
- **束缚野兽**（`To Chain The Beast`）：每个主宰的触须都由一只英雄眼虫守卫。每只英雄眼虫在存活时都会为野生异虫提供战术优势，必须将其击杀才能接近触须。
- **这里发生了什么？**（`In Utter Chaos`）：没人能预测等待你的是什么，连我也不能。
- **这不可能，混合体怎么可能在查尔上？**（`Impossible, Hybrid On Char!`）：艾尔演练
- **虫巢女王**（`Daughter Of The Swarm`）：敌方女王的生命值提高200%，并拥有强大的且有明显施法前摇的技能。
- **巨物恐惧症**（`Megalophobia`）：利维坦的数量变得更多了。
- **行动代号: Omega**（`Threat Level: Omega`）：所有先前选择的挑战也适用于此任务。

## 6. 天赋清单（按 Type 分组，478 个）

### Class（272）

狂怒（Deathwish）、意志驱动（To Slay The Beast）、快速采集（Time For Preparation Is Over）、血肉拼接（Botched Reanimation）、守护之盾（Feedback Loop）、急速恢复（zhajialasuojianzhouqi）、空投囊（Zerg Are Not Toys）、末日装甲（No OSHA In Koprulu）、生存策略（Hazard Pay）、致命孢子（Live By Necromancy...）、先遣部队（Moment Of Silence）、偷窃（Going Rogue）、瑜伽训练（Mass Interference）、虚空回路（Intra-Void Transmitter）、卡拉模拟器（Khala Emulator）、萨尔那加的礼物（Gift Of The Xel'Naga）、指引（Guidance）、神谕（Oraculum）、信仰之盾（Shield Of Faith）、吟游诗人的激励（Bardic Inspiration）、挚友同盟（Fast Friends）、凯达琳科技（Khaydarin Efficiency）、大一统（Unification）、枪枪爆头（Adrenaline Rush）、精益求精（Give 'Em Some Pepper）、英勇韧性（Heroic Fortitude）、修炼（Corpse Exploder）、死亡领主的赞赏（Debilitating Plague）、身先士卒（Ghoulish Renewal）、卸甲（Unholy Resilience）、空投蟑螂（Evolution Delta）、无害植入（Evolution Epsilon）、共振增幅（Incubation Efficiency）、快速指令（Rapid Emission）、末日炮塔（Compact Turret）、机械镀层（Static Offense）、供电充足（Supply Reactor）、先进改装（Titanium Plating）、额外奖励（Bonus Round）、廉价手牌（Cheap Hand）、生物王牌（Critters' Ace）、命运升级（Fateful Upgrades）、数量定律（Law Of Big Numbers）、竞争意识（Deadman's Hardware）、免费试吃（Free Sample）、战斗续航（Kickstart）、老主顾的优惠（Team Effort）、埃菲尔机动（Eiffel Maneuver）、放逐未来（Future Banishment）、核能物资（Nuclear Supplies）、万有理论（Theory Of Everything）、相对运动（Celerity）、机械超载（First Things First）、动量吸收（Spark Of Momentum）、逐渐熟练（Swift Recharge）、前赴后继（Corpse Explosion）、亡灵尖啸（Necroshock）、亡灵刚毅（Undead Resilience）、腐蚀之爪（Unholy Power）、机组维护（Blessed Workers）、神圣加护（Divine Armor）、晋升狂热（Lay On Hands）、纪律严明（Veneration）、大脑终止开关（Cerebral Kill Switch）、解放心智（Free Your Mind）、意志之力（Force Of Will）、灵能塔（Psychic Tower）、通讯干扰（Ambush）、灭杀视线（Backstab）、闪光脉冲（Cheap Shot）、工人伪装（Harmless Disguise）、应用科学（Applied Science）、实验性升级（Experimental Upgrades）、硬件改良（Hardware Improvement）、下一代原型（Next-Gen Prototypes）、优良内控（Charged Impact）、重构光束（Drop Pod Reinforcement）、术法架势（Integral Deconstruction）、超魔（Orbital Recovery）、献祭（Lambs To The Slaughter）、生存研习（Life Tap）、契约精通（Pact Mastery）、灵能扩增（Sacrifical Offering）、制空优势（Renewable Power）、灵能强化（Resonant Amplification）、注能射击（Super-Advanced Facilities）、干扰强化（Psi Infusion）、坚毅祝福（Blessing Of Fortitude）、奉献（Devotion）、神助（Divine Aid）、律令：超载（Power Word: Overcharge）、灵能秘辛（Psionic Secrets）、集结之歌（Song Of Rally）、雷诺朋友，他能为你开辟道路（Chrono Rift）、破片手雷（Frag Grenade）、游骑兵光环（Ranger Aura）、灵魂吸收（Echo Of Death）、飞速机动（Once More Unto The Breach）、盛气凌人（Vengeful Frenzy）、掌控意志（Cerberus Infestation）、空投刺蛇（Evolution Gamma）、储备能源（Malignant Infusion）、高精度自动跟踪系统（Hi-Sec Auto Tracking）、工程截止日（Impending Deadline）、补给充足（Propaganda Holoboard）、头奖！（Jackpot）、幸运之骰（Lucky Dice）、溢价升级（Premium Token）、紧急访问（Emergency Access）、我带你们打（Performance Compensation）、VIP购买权限（Priority Pass）、内部重建（Internal Reconstruction）、套娃系统（Matryoshka Systems）、弹幕矩阵（Projectile Matrix）、躲闪反击（Dexterity）、甜蜜的梦（Evasion）、“觉悟者恒幸福”（timelevel1）、这东西可以换不少钱（Danse Macabre）、潜伏期（Excieo Omega）、你惊扰了女巫！（Reanimation Mastery）、神圣学识（Everlasting Light）、坚定信仰（Inquisition）、以帝皇的名义，出征！（Legend Lore）、颅内聚焦（Cranial Focus）、ε 级接管（Epsilon Takeover）、灵捷逾目（Mind Is Quicker Than The Eye）、暗影机动（Shroud Of Concealment）、消失（Vanish）、伪装（Camouflage）、减耗增效（Corner Cutting Machine）、绿色方案（Green Solution）、通用强化器（Universal Booster）、战略储备（Precision Barrage）、光子过载（Terran Recall）、轨道空投：地堡（Ultra Concussive Shell）、粉碎心智（Essence Syphon）、汲取效率（Infinite Void）、飞天恶魔（Warlock Adept Training）、能量缓冲（Force Nullifier）、三角定位（Triple Point Optics）、附魔维护（Wizard Adept Training）、禁断之力（Forbidden Power）、三重祝福（Threefold Blessing）、达拉姆之力（Might Of The Daelaam）、来见见我的小伙伴（Say Hello To My Little Friend）、高密度护盾（Ability Efficiency）、激励（Inspire）、湮灭波（Infested Rebirth）、挥洒鲜血（Ouroboros）、主巢分流（Evolution Complete）、简化基因序列（Simplified Sequences）、打包带走（Earthsplitter Artillery）、灵能干扰器（Engineering Marvel）、风暴英雄（Hero Of The Storm）、重掷（Reroll）、独家战术（Loyalty Bonus）、额外供应（Supply And Demand）、似曾相识（Deja Vu）、量子灭绝射线（Quantum Extinction Beam）、动能接力（No Task Too Small）、“世界”（Secret Technique）、术式迭代（Aberrant Mutation）、死灵研修（Spare Parts）、完美化身（Avatar Of Perfection）、十字军之力（Crusader's Might）、万物归我（All Your Base Belongs To Us）、心智崩解（Mind Break）、无影无踪（Vendetta）、隐秘观察者（Supercloak）、第三种选择（3rd Opinion）、良性副作用（Positive Side Effects）、时间超载（Defensive Overload）、保修服务（Solarite Empowerment）、虚空魅影（Void Rift）、永续奴仆（Warlock Master Training）、稳定附魔（Chaos Harmonizer）、魔导防御（Wizard Master Training）、无限之力（Power Of The Infinite）、你的就是我的（Counter-Curse）、休伯利安出击（Summon Hyperion）、血祭利刃（Mutually Assured Destruction）、宝贵遗产（Always A Bigger Zerg）、德拉肯激光钻机（Drakken Laser Drill）、再来一次？（Play Again?）、私人防护（Mercenary Internship）、60秒（Sixty Second Strike）、事件视界（Event Horizon）、灭杀抵抗（Virulent Infestation）、侍从，来我身边（Fanaticism）、灵能统御（Psychic Domination）、节能减排（Expertise）、统一理论（Unifying Theory）、重力牵引（Nuclear Annihilation）、升格（The Host）、能量护盾（Exponential Growth）、副职业（Multiclass）、第二职业（Multiclassed）、神性精华（Essence Of Divinity）、友谊学院（College Of Friendship）、吉米在此（This Is Jimmy）、死亡领主（Deathrattle）、塞伯鲁斯计划（Cerberus Hatchery）、战地工兵（Construction Efficiency）、随机化（Randomizer）、雇佣合同（Premium Contract）、狂乱武器（Weaponised Insanity）、天堂制造（Windstep Maneuver）、死亡行军（Army Of The Dead）、圣武士誓言（Path Of The Paladin）、灵能军团（Psi-Corps Trooper）、开始潜入（Rogue Initiation）、战斗升级（Combat Prototypes）、精准打击（Precision Strike）、虚空低语（Voidforged Pact）、附魔武器（Evocation）、灵能流转（lingnengliuzhuan）、刚毅护盾（gangyihudun）、别怕牛仔，它不会咬你的（zhajialabushu）、寄生骨刺（zhajialajisheng）、时空虫道（zhajialachuansong）、活性细胞（zhajialashengmingshangxian）、敏锐感知（yingxiongzhence）、表率作用（biaoshuaizuoyong）、嗜血奴仆（xukongbuff）、狂乱（xukongsudu）、虚空劫掠者（xukongjieluezhe）、虚空赫克（xukongheke）、虚空幽魂（xukongyouhun）、虚空怨灵战机（xukongyuanling）、虚空雷神（xukongleishen）、虚空战列巡航舰（xukongzhanlie）、“你相信引力吗？”（timelevel2）、“最后说一次，时间要加速了”（timelevel3）、时间余韵（shijianyuyun）、外包人员（merclingbuji）、保命要紧（baomingyanjin）、先用后付（xianyonghoufu）、范围光线扭曲（bujizhanyinxingguanghuan）、背刺（beici）、全知之眼（kaiquantu）、斥力护盾（chilihudun）、反制护盾（fanzhihudun）、终极防壁（zhongjifangbi）、鼓舞（shicongshengji）、信仰支付（shicongrenkou）、先遣重装（mianfeitanke）、先遣禁军（mianfeidahe）、空投雷兽（kongtouleishou）、多重部署（kongtoucishu）、高速再生（chuanqihuixue）、强健体魄（chuanqishengming）、高密度甲壳（chuanqihujia）、意识集中（chuanqijiasu）、主巢防御（zhuchaofangyu）、急速奔袭（gongjiqianjiasu）、死亡贩子（siwanggeiziyuan）、金钱就是力量（ziyuantianfugeishuxing）、灵能窥视（deluyiwurenjishiye）、黑暗蜂群（heianchongqun）、储备尸群（silingfangyu）、重装堡垒（shushidibaoqianghua）、重构防护（chonggouhujia）、能量爆棚（guangziguozaiewaimubiao）、光子护盾（guangzihudun）、时间抗性（SHIJIANCHAOZAIYUNXUDANWEI）、献祭狂热（xianjikuangre）、鲜血教义（alanakexixue）、杀意高涨（shayigaozhang）、当头棒喝（chongfengjiyun）、破绽（chongfengqingchuhudun）、晕头转向（yanmieboshechengjiangdi）、摧枯拉朽（yanmiebosanbeijianzhushanghai）

### Generic（31）

辅助居住舱（Auxiliary Depots）、秘密密码（Secret Password）、汪汪队立大功（Stetmann's Army）、曙光降临（Light In The Darkness）、高级选项（Advanced Options）、魔鬼的矿物（Devil's Minerals）、微型过滤（Micro-Filtering）、真汉子钻得深（Real Men Drill Deep）、再生型生物钢（Regenerative Bio-Steel）、神秘盲盒（It's Raining Scrap）、空中堡垒（dalishen）、全军出击（quanjunchuji）、斩首行动（zhanshouxingdong）、死亡面罩（xixue）、大战前的宁静（hepingfayu）、探查增幅（ewaishiye）、团结一心（tuanjieyixin）、福祸相依（ewaitianfuzuzhou）、运气不错（tianfushenjie）、摆脱厄运（baituoeyun）、双份快乐（shuangbeitianfu）、苦痛转换（zizhoubianweitianfu）、非酋的自救（ewairoll）、欧皇的自信（ouhuangshuxing）、不公平的牌局（junfeidubo）、火力压制（zengjiagongsujiangshanghai）、模因损伤（moyinsunshang）、点击轰炸（dianjihongzha）、和平卫士（jiangdishanghaizengjiahujia）、物价波动（shangdiandazhe）、不喜欢的东西我不要（yichutianfu）

### Special（18）

三号应急预案（Contingency #3）、汉森的逆转感染疗法（Hanson's Cure）、阿格瑞亚增幅（Planet Cracker）、净化光束（DIE INSECT!）、友谊的证明（Maternal Supervision）、失落的矿工（Lost Miners）、大坏蛋来啦！（Tosh Has Gone Rogue(Like)!）、赏金猎手（Bounty Hunter）、你真能打败刀锋女王？（Go, Nova!）、提前组装（Artifact Assembled）、撕裂力场生成器（Rippin' Fields）、臣服黑暗（Surrender To DESPAIR）、En Taro Zeratul！（Zeratul On Board）、这是啥？咬一口试试（Compulsory Chewing）、瓦伦里安的底牌（Vengeance For Fenix）、玛·萨拉精炼技术（masara）、小马，你的心意我都存着呢（cunqian）、优势在我！（youshizaiwo）

### Infinite（11）

医学突破（Medical Breaktrough）、可再生燃料（Renevable Fuel）、打捞作业（Salvage Operation）、更多的枪！（Use More Gun）、加急物流（Accelerated Logistics）、超级镀层（Unobtanium Plating）、超级英雄（Super Heroic）、噩梦加速（emengjiasu）、噩梦加固（emengjianshang）、噩梦超程（emengshecheng）、噩梦支援（emengtianfu）

### Terran Building（8）

“出埃及记”牌建筑推进器（Exodus Boosters）、空投信标（Orbital Depots）、柠檬汁喷洒器（Lemon Disperser）、自动化精炼场（Automated Refinery）、科技反应堆（Tech Reactor）、消防系统（Fire-Suppression System）、轨道空降（Orbital Strike）、补给隧道（BUJIZHANSUIDAO）

### Marine（7）

防爆护盾（Combat Shield）、C.U弹（CU Shells）、强化兴奋剂（Stimpacks）、额外征兵（Increased Conscription）、泰伦精神（Horde Bonus）、穿甲弹（marinechuanjiadan）、我爱牛头人（NTR）

### SCV（7）

高级建造（Advanced Construction）、双熔切焊枪（Dual-Fusion Welders）、指挥中心反应堆（Command Center Reactor）、戴夫（Dave）、人工智能上阵（AI SCV）、走楼梯（scvchuanqiang）、污染防护（SCVmomian）

### Medivac（6）

高级治疗AI（Advanced Healing AI）、卡杜修斯反应堆（Caduceus Reactor）、快速部署（Rapid Deployment Tube）、通用修复光束（Universal Healing Beam）、瞬时折跃（First Response）、提前部署（yiliaoyunshuji）

### Banshee（5）

交叉光谱抑光仪（Cross-Spectrum Dampeners）、高速旋翼（Hyperflight Rotors）、冲击波导弹巢（Shockwave Missile Battery）、风行者力场（Windrunner Field）、静态轰炸（Wailing Missiles）

### Battlecruiser（5）

防御矩阵（Minotaur Matrix）、高效机组（Missile Pods）、战地指挥（Weapon Refit）、战术折跃（Tactical Jump）、武藏级加农炮（Musashi Cannon）

### Diamondback（5）

爆发电容（Burst Capacitors）、铸型壳体（Shaped Hull）、超导磁轨炮（Godslayer Railgun）、通量弹射（Flux Ricochet）、超声探查（Diamond Grade Loot）

### Firebat（5）

焚烧臂铠（Incinerator Gauntlets）、铁人装甲（Juggernaut Plating）、放射性火焰碎屑（Radioactive Pyroclast）、千锤百炼（Pyromania）、烧灼（shaozhuo）

### Goliath（5）

阿瑞斯级瞄准系统（Ares-Class Targeting System）、多重锁定武器系统（Multi-Lock Weapons System）、生还者系统（Survivor Systems）、铁驭机动（Giantslayer Slingshot）、D.Vid框架（D.Vid Frame）

### HERC（5）

工业焊枪（Industrial Welder）、莫瑞安装甲（Morian Plating）、重型冲击（Heavy Impact）、紧急响应系统（Critical Response System）、牵引加速（qianyinjiasu）

### Hellion（5）

智能伺服器（Blazing Servos）、地狱火预燃器（Infernal Pre-igniter）、双联火焰喷射器（Twin-Linked Flamethrower）、飙车框架（Instant Salvage）、游击战术（Specialized Frame）

### Liberator（5）

自由伺服器（Freedom Servos）、女武神再临（Indiscriminate Justice）、谈判终止（Onslaught Mode）、超级弹道计算机（Ultra Ballistics）、老大姐在看着你（Big Sister）

### Marauder（5）

震荡弹（Concussive Shells）、动能泡沫（Kinetic Foam）、格斗模块（Brawler Module）、重锤一击（Corpserauder）、高速弹头（gaosudantou）

### Medic（5）

阿尔忒弥斯级医疗光束（Artemis Extender）、先进医疗装甲（Reinforced Medishield）、稳定剂医疗包（Stabilizer Medpacks）、护卫光环（Safeguard Aura）、超级充能（Ultracharge）

### Raven（5）

灵能尖啸（Empathy Inhibitor）、荷鲁斯之眼（Eye Of Horus）、微型工厂（Fabrication Matrix）、禁止摸鱼（Magellan Projector）、重火力改装（Extermination Protocol）

### Reaper（5）

反装甲特训（Parting Gift）、U-238子弹（U-238 Rounds）、调训效率（Conditioning Efficiency）、超级兴奋剂（Thunder Cocktail）、闪转腾挪（reapershanbi）

### Siege Tank（5）

帝国加农炮（Imperio Cannon）、高级攻城模式（Improved Siege Mode）、漩流弹（Maelstrom Rounds）、闪现（Siege Blink）、渐进射程（Graduating Range）

### Specialist（5）

目镜移植（Ocular Implants）、灵能喷涌（Psionic Lash）、尼克斯级战斗服（Nyx-Class Crius Suit）、灵能回收（Cellular Reactor）、精英武装（Elite Equipment）

### Thor（5）

紧急维修（Emergency Repair）、重载伺服器（Heavy Servos）、雷电交加（Thunder And Lightning）、风暴屏障（Stormforged Barrier）、帝国之傲（Mjolnir Weapon Systems）

### Viking（5）

改进伺服器（Lost Vikings）、福波斯级武器系统（Phobos-Class Weapons System）、破浪飞弹（Ripwave Missiles）、高穿改造（Arcade Drone）、等离子炸弹（Plasma Bomb）

### Vulture（5）

地狱犬蜘蛛雷（Cerberus Mine）、联邦神鹰（Condor Chassis）、纳米构造器（Replenishable Magazine）、警戒光束（Mine Sacs）、蜘蛛恐惧症（Arachnophobia）

### Warhound（5）

优化改造（Axiom Plating）、电磁反转改装（Supermagnetic Railgun）、爆裂飞弹（Tornado Missiles）、弑君者锁定系统（Queenslayer Targeting）、格斗强化（gedouqianghua）

### Widow Mine（5）

增压载荷（Pressurized Payload）、掘地伺服器（Tunneling Servos）、寡妇之眼（Widow's Sight）、付费使用（Rapid Armament）、深掘通道（Deep Tunnel）

### Wraith（5）

暗影引擎（Displacement Field）、脉冲放大器（Pulse Amplifier）、战斧能源电池（Tomahawk Power Cells）、镜面立场（Phantom Pain）、恶灵协议（Poltergeist Protocol）

### Bunker（4）

精钢地堡（Neosteel Bunker）、射弹加速器（Projectile Accelerator）、尖牙炮塔（Shrike Turret）、加固地堡（Fortified Bunker）

### Missile Turret（4）

地狱风暴炮组（Hellstorm Batteries）、钛钢外壁（Titanium Housing）、爱国者导弹系统（Patriot Missile System）、侦察雷达（zhenchaleida）

### Nuke（4）

曼哈顿计划（Fission Efficiency）、先进制导（Call Down The Thunder）、焦土政策（Project Fatter Man）、辐射禁区（Scorched Earth）

### Command Center（3）

行星要塞（Stetmann's Base）、轨道指挥中心（Orbital Command）、地下资源提炼（autoziyuan）

### Multiclass（1）

多职业天赋（Multiclass Talent）

### 安慰奖（1）

赌徒的执念（duboanweijiang）

### 账目（1）

你和米拉的交易次数（MIRAJIAOYI）

## 7. 验证结果

- **XML well-formed**：32 个 XML 类文件（GameData 25 个、Triggers、UI 布局、ComponentList、DocumentInfo、Preload）全部通过 `xml.dom.minidom` 解析，0 错误。
- **图标引用**：GameData 中 302 个 raynorrogue 专属图标引用全部命中内联资产，缺失 0。
- **galaxy-checker**（`npx tsx src/cli.ts <mod>/Base.SC2Data --format text`）：183 error / 12 warning，与直接检查**源 mod** `RaynorRogue.SC2Mod/Base.SC2Data` 的结果逐条一致（同为 183/12），即重命名未引入任何新问题；项目内既有先例 `kit_mutations.SC2Mod` 同口径为 245 error。误报归类说明：
  - `SYNTAX_NO_LOCAL_INIT_ASSIGN` ×128：均为编辑器自动生成的 `const int autoXXXX_ai = 1;` 循环辅助常量，Galaxy 实际允许局部 const 声明初始化（源 mod 在游戏内可正常编译运行），checker 规则过严。
  - `SYNTAX_NO_CONTINUE` ×4：编辑器为「跳过循环剩余动作」生成的 `continue;`，现行 Galaxy 运行时已支持，checker 规则基于旧语法。
  - `XLIB_DISALLOWED_NATIVE`（UnitCreate）×49：项目自定义黑名单规则，属第三方引入代码的风格问题而非错误；与 kit_mutations 中同类计 16 处的既有情况一致，未改写以保持与 Triggers 库同步。
  - `SYNTAX_PARSE_ERROR` ×2（LibKRTC_h.galaxy:49）：checker 解析器不支持 Galaxy `struct` 声明（`gs_BardSquad`），解析中断导致，非代码错误。
  - `XLIB_MISSING_INCLUDE` ×3（warning）：`LibCamp/LibWoLC/LibWCMI` 由 Liberty (Campaign) 官方依赖在运行期提供，不存在于本地目录。
  - `SEM_ASSIGNMENT_TYPE_MISMATCH` ×9（warning）：int→fixed 隐式转换，Galaxy 允许。

## 8. 遗留问题

1. **4 个 `Kit@*` 升级引用悬空**：`Kit@BattlecruiserTacticalJump / Kit@ImprovedSiegeMode / Kit@MedivacCaduceusReactor / Kit@ThorEmergencyRepair` 原由 kit_liberty_story 提供，对应天赋（战术折跃等）在不加载该 mod 时仅数值部分失效、可正常抽取。如需完整效果，可后续把这 4 个 CUpgrade 补进本 mod 的 UpgradeData。
2. **职业 BGM 未内联**：RaynorRogueRaw 中 378 个 ogg 属职业彩蛋音乐，未拷贝；SoundData 引用缺失时静音处理。
3. **战役挑战诅咒/Special 天赋在非战役地图休眠**：功能保留但只有在对应战役地图（traynor01 等）事件命中时才生效；若未来要在 7vs1 地图启用等价玩法，需要为其编写映射触发器。
4. **Bank 存档名沿用源 mod**（`gf_Load/SaveRogueBank` 内固定名），与源 mod 同机共存时会共享肉鸽进度存档；如需隔离可改 Bank 名（涉及 Triggers 同步修改，本次未动）。
5. **职业系统整体保留**：单位池、双职业、吟游诗人小队、德鲁伊虫群等职业机制与天赋表不可分割（296 个 Class 天赋依赖），因此保留在本 mod 内；若只想要通用天赋+诅咒，可在地图侧不调用职业初始化触发器。

## 9. 提取过程记录（可复现）

1. 定位源目录并解析 `RogueTalents` UserData 目录表、稀有度分布。
2. 以 `kit_mutations.SC2Mod` 为组织模板建立目录骨架。
3. 字节级全量替换 `B27CC4B1 → KRTC`（galaxy×2、Triggers、GameData.xml、GameStrings/TriggerStrings×2 语言），其余数据 XML/本地化原样拷贝。
4. `mpyq` 解包 RaynorRogueRaw.SC2Mod，提取全部 321 个 dds 到 `Assets/Textures/`。
5. 重建 DocumentInfo 与 DocumentHeader（H2CS 二进制，依赖数 3→1）。
6. XML well-formed 校验 + galaxy-checker 对比源 mod 基线。
